#!/usr/bin/env python3
"""Official GPT-2 (small / distilgpt2) compiler for NMAForge Product Top.

Pipeline: FP32 model -> calibration -> SmoothQuant (alpha 0.5) folded into the
LN gamma/beta encoding (c_attn, c_fc) and the V columns (attention c_proj) ->
power-of-two INT8 quantization -> bit-exact integer forward (`nmaf.intops`,
also the accuracy model) -> descriptor program with streamed weights.

Decoder block schedule over rows pos0..pos0+T-1 (D=768, H=12, hd=64, FF=3072).
Prefill runs all prompt rows from pos0 = 0; a decode step runs the 4-token
group holding the new token (the GEMM row granule is 4, so earlier rows of the
group are recomputed bit-identically from their embeddings and no hidden
state is stored).  Per-head INT8 K/V caches of KMAX tokens live in DDR.
  LN1 per row -> 4-row temp -> rounded REQUANT pack (A layout)
  per head h (own power-of-two scales for Wq/Wk/Wv/Wo slices):
    Q = X Wq_h' (log2e/8 folded) -> pack
    K = X Wk_h -> pack into the SPAD K cache at row pos0 (loaded rows < pos0)
    V^T = Wv_h^T X^T (packed X is the B operand of X^T) -> pack -> 2D DMA store
      into the DDR V^T cache columns, then the whole cache is loaded back
    S = Q K^T (Q8.8 log2 domain) -> causal Softmax 0x39 per row (aux0 = pos)
    -> rounded REQUANT to Q7, zero-padded to KMAX -> AV at K = KMAX -> pack
    partial_h = AV_h Wo_h at the common accumulator scale 2^E_o
    ACC = partial_0 (+ bias, V bias folded in) ; ACC += partial_h (RESIDUAL)
    new K rows -> DMA store to the DDR K cache
  ACC = ACC >> s_o (RESIDUAL(ACC, ACC, s_o + 1), or -s_o doublings) ; X += ACC
  LN2 -> pack; per 64-column FF chunk c (own scales):
    FC1_c -> LUT gelu_new + pack (SFU flags[7]) -> partial_c = H_c W2_c
    accumulated at 2^E_2 like the attention projection ; X += ACC >> s_2
Token embedding (wte + wpe) and the final LN + LM head run on the host.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent))
from nmaf import intops as I                                   # noqa: E402
from nmaf.program import FLAG_GEMM_ACC, Program                # noqa: E402
from cimforge_mapper import (FLAG_BIAS, FLAG_PACK_I8, FLAG_PACK_I8_TILE_A,  # noqa: E402
                             OP_CAUSAL_SOFTMAX, OP_GEMM, OP_GELU, OP_LAYERNORM,
                             OP_REQUANT, OP_RESIDUAL)

torch.set_grad_enabled(False)
LOG2E = 1.4426950408889634
FLAG7 = 1 << 7
PACK = FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A
F_RES = 8                             # residual stream Q.F
LN_RB = 4                             # LN rounding bits
CH = 64                               # FF chunk width = head dim
RES_ROWS = 8                          # RESIDUAL chunk (8 x 768 elements)
MAX_ACC_SHIFT = 12                    # accumulator grid at most 2^12 finer than X


def p2(x: float) -> int:
    """Exponent e with 2^e >= x (power-of-two scale, e may be negative)."""
    return int(math.ceil(math.log2(max(float(x), 1e-30))))


def half(sh: int) -> int:
    return (1 << (sh - 1)) if sh > 0 else 0


def gelu_new(x):
    return 0.5 * x * (1.0 + torch.tanh(math.sqrt(2.0 / math.pi) * (x + 0.044715 * x ** 3)))


def gelu_new_np(x):
    return 0.5 * x * (1.0 + np.tanh(math.sqrt(2.0 / math.pi) * (x + 0.044715 * x ** 3)))


# ------------------------------------------------------------------ float model
class FloatGpt2:
    def __init__(self, model_dir: Path):
        from safetensors.numpy import load_file
        raw = load_file(str(model_dir / "model.safetensors"))
        self.sd = {k.removeprefix("transformer."): torch.from_numpy(v.copy()).float()
                   for k, v in raw.items()}
        cfg = json.loads((model_dir / "config.json").read_text())
        self.L, self.H = cfg["n_layer"], cfg["n_head"]
        self.D = self.sd["wte.weight"].shape[1]
        self.HD, self.FF = self.D // self.H, 4 * self.D
        self.name = cfg.get("_name_or_path") or model_dir.parent.parent.name

    def g(self, i, n):
        return self.sd[f"h.{i}.{n}"]

    def embed(self, ids):
        return self.sd["wte.weight"][ids] + self.sd["wpe.weight"][:len(ids)]

    def ln(self, x, prefix):
        return torch.nn.functional.layer_norm(x, (self.D,), self.sd[prefix + ".weight"],
                                              self.sd[prefix + ".bias"], 1e-5)

    def layer(self, i, x, obs=None):
        D, H, HD, T = self.D, self.H, self.HD, x.shape[0]
        g = lambda n: self.g(i, n)

        def rec(k, v, groups=0):
            if obs is None:
                return
            if groups:
                q = torch.quantile(v.reshape(-1, groups, v.shape[-1] // groups).transpose(0, 1)
                                   .reshape(groups, -1).abs(), 0.9999, dim=1)
            else:
                q = torch.quantile(v.abs().flatten()[:2_000_000], 0.9999)
            obs[k] = torch.maximum(obs[k], q) if k in obs else q

        def chan(k, v):
            if obs is not None:
                c = v.abs().amax(0)
                obs["chan." + k] = torch.maximum(obs["chan." + k], c) if "chan." + k in obs else c

        def hess(k, v, blk=0):
            """GPTQ input Hessians X^T X (float64); blk > 0 keeps only the
            diagonal blk x blk blocks (one per head / FF chunk weight slice)."""
            if obs is None or not obs.get("_hess"):
                return
            v = v.double()
            h = (torch.einsum("tgi,tgj->gij", v.reshape(T, -1, blk), v.reshape(T, -1, blk))
                 if blk else v.T @ v)
            obs["H." + k] = obs["H." + k] + h if "H." + k in obs else h

        a = self.ln(x, f"h.{i}.ln_1"); rec("ln1", a); chan("c_attn", a); hess("ln1", a)
        w, b = g("attn.c_attn.weight"), g("attn.c_attn.bias")
        sc = LOG2E / math.sqrt(HD)
        q = (a @ w[:, :D] + b[:D]) * sc
        k = a @ w[:, D:2 * D] + b[D:2 * D]
        v = a @ w[:, 2 * D:]                               # V bias folded into c_proj bias
        rec("q", q, H); rec("k", k, H); rec("v", v, H)
        mask = torch.ones(T, T, dtype=torch.bool).tril()
        att = torch.zeros(T, D)
        for h in range(H):
            cs = slice(h * HD, (h + 1) * HD)
            s = (q[:, cs] @ k[:, cs].T).masked_fill(~mask, float("-inf"))
            att[:, cs] = torch.softmax(s * math.log(2.0), -1) @ v[:, cs]
        rec("att", att, H); chan("c_proj", att); hess("att", att, HD)
        wo, bo = g("attn.c_proj.weight"), g("attn.c_proj.bias")
        x = x + att @ wo + (bo + b[2 * D:] @ wo)
        m = self.ln(x, f"h.{i}.ln_2"); rec("ln2", m); chan("c_fc", m); hess("ln2", m)
        u = m @ g("mlp.c_fc.weight") + g("mlp.c_fc.bias"); rec("fc1", u, self.FF // CH)
        u = gelu_new(u); rec("gelu", u, self.FF // CH); hess("gelu", u, CH)
        return x + u @ g("mlp.c_proj.weight") + g("mlp.c_proj.bias")

    def head(self, x):
        return self.ln(x, "ln_f") @ self.sd["wte.weight"].T

    def forward(self, ids, obs=None):
        x = self.embed(ids)
        for i in range(self.L):
            x = self.layer(i, x, None if obs is None else obs[i])
        return self.head(x)

    def smooth(self, obs, alpha=0.5):
        """Fold SmoothQuant factors into LN gamma/beta, the V columns and weights."""
        D = self.D
        def factor(xa, w):
            wa = w.abs().amax(1).clamp(min=1e-5)
            return (xa.clamp(min=1e-5) ** alpha / wa ** (1 - alpha)).clamp(1e-2, 1e2)
        for i in range(self.L):
            for ln, lin, key in ((f"h.{i}.ln_1", f"h.{i}.attn.c_attn", "c_attn"),
                                 (f"h.{i}.ln_2", f"h.{i}.mlp.c_fc", "c_fc")):
                sj = factor(obs[i]["chan." + key], self.sd[lin + ".weight"])
                self.sd[ln + ".weight"] /= sj
                self.sd[ln + ".bias"] /= sj
                self.sd[lin + ".weight"] *= sj[:, None]
            p = f"h.{i}.attn"
            sj = factor(obs[i]["chan.c_proj"], self.sd[p + ".c_proj.weight"])
            self.sd[p + ".c_attn.weight"][:, 2 * D:] /= sj[None, :]
            self.sd[p + ".c_attn.bias"][2 * D:] /= sj
            self.sd[p + ".c_proj.weight"] *= sj[:, None]


# ------------------------------------------------------------------ quantized layer
def wq_pow2(w: np.ndarray):
    """Per-tensor power-of-two INT8 weight (symmetric, +-127)."""
    ew = p2(np.abs(w).max() / 127.0)
    return np.clip(np.round(w / 2.0 ** ew), -127, 127).astype(np.int64), ew


GPTQ_DAMP = 0.01                      # Hessian damping, fraction of mean diagonal


def wq_i4blk(w: np.ndarray, hess: np.ndarray | None = None):
    """INT4 block-exponent weight (0x60 flags[1] stream): one power-of-two
    scale per aligned 4x4 block (= one packed SPAD line), limited to the 5
    levels [E, E+4] (E = Emax - 4) so the expanded value w4 << (e - E) fits
    INT8.  Returns the expanded INT8 values and E (w ~= w8 * 2^E).

    With `hess` (input Hessian X^T X, [K, K]) the block scales stay those of
    the original weight, but rows (inputs) are rounded in order and each
    row's rounding error is propagated to the remaining rows (GPTQ)."""
    K, N = w.shape
    b = w.reshape(K // 4, 4, N // 4, 4)
    amax = np.abs(b).max(axis=(1, 3), keepdims=True)
    e = np.ceil(np.log2(np.maximum(amax, 1e-30) / 7.0))
    E = int(e.max()) - 4                          # (an MSE-chosen lower base that
    e = np.maximum(e, E)                          #  clips outlier blocks was worse)
    if hess is None:
        w4 = np.clip(np.round(b / 2.0 ** e), -8, 7)
        w8 = (w4 * 2.0 ** (e - E)).astype(np.int64)
        return w8.reshape(K, N), E
    s = np.repeat(np.repeat(2.0 ** e, 4, axis=1), 4, axis=3).reshape(K, N)   # per-element scale
    h = np.array(hess, np.float64, copy=True)
    dead = np.diag(h) <= 0
    h[dead, dead] = 1.0
    h += GPTQ_DAMP * np.mean(np.diag(h)) * np.eye(K)
    u = np.linalg.cholesky(np.linalg.inv(h)).T                 # upper Cholesky of H^-1
    wk = np.array(w, np.float64, copy=True)
    wk[dead, :] = 0.0
    q = np.zeros((K, N))
    for k in range(K):
        q[k] = np.clip(np.round(wk[k] / s[k]), -8, 7) * s[k]
        err = (wk[k] - q[k]) / u[k, k]
        wk[k + 1:] -= np.outer(u[k, k + 1:], err)
    w8 = np.round(q / 2.0 ** E).astype(np.int64)
    return w8, E


class QuantLayer:
    """Integer constants and shifts for one decoder block."""

    def __init__(self, fm: FloatGpt2, i: int, obs: dict, int4: frozenset = frozenset()):
        D, H, HD, FF = fm.D, fm.H, fm.HD, fm.FF
        wq8 = globals()["wq_pow2"]
        hs = lambda k, j=None: (None if "H." + k not in obs else
                                (obs["H." + k] if j is None else obs["H." + k][j]).numpy())
        wq_attn = (lambda w_, h_=None: wq_i4blk(w_, h_)) if "attn" in int4 else \
            (lambda w_, h_=None: wq8(w_))
        wq_ffn = (lambda w_, h_=None: wq_i4blk(w_, h_)) if "ffn" in int4 else \
            (lambda w_, h_=None: wq8(w_))
        self.D, self.H, self.HD, self.FF, self.NC = D, H, HD, FF, FF // CH
        g = lambda n: fm.g(i, n).double().numpy()
        ex = lambda v: p2(float(v) / 127.0)
        exs = lambda v: [ex(t) for t in v]
        self.e = e = {"ln1": ex(obs["ln1"]), "ln2": ex(obs["ln2"]), "q": exs(obs["q"]),
                      "k": exs(obs["k"]), "v": exs(obs["v"]), "att": exs(obs["att"]),
                      "fc1": exs(obs["fc1"]), "gelu": exs(obs["gelu"])}

        def ln_params(n, eo):
            gm, bt = g(n + ".weight"), g(n + ".bias")
            gq = np.round(gm * 32768.0 * 2 ** LN_RB / 2.0 ** eo).astype(np.int64)
            bq = np.round(bt * 2 ** LN_RB / 2.0 ** eo).astype(np.int64) + half(LN_RB)
            return gq, bq
        self.ln1 = ln_params("ln_1", e["ln1"])
        self.ln2 = ln_params("ln_2", e["ln2"])

        w, b = g("attn.c_attn.weight"), g("attn.c_attn.bias")
        sc = LOG2E / math.sqrt(HD)
        self.wq, self.wk, self.wvt, self.wo = [], [], [], []
        self.bq, self.bk, self.bo = [], [], []
        self.sh_q, self.sh_k, self.sh_v, self.sh_s, self.sh_a, self.sh_o = ([] for _ in range(6))
        wo_f, bo_f = g("attn.c_proj.weight"), g("attn.c_proj.bias")
        bo_f = bo_f + b[2 * D:] @ wo_f
        ewo, wo_q = [], []
        for h in range(H):
            cs = slice(h * HD, (h + 1) * HD)
            wq_, ewq = wq_attn(w[:, cs] * sc, hs("ln1"))
            wk_, ewk = wq_attn(w[:, D:][:, cs], hs("ln1"))
            wv_, ewv = wq_attn(w[:, 2 * D:][:, cs], hs("ln1"))
            if e["q"][h] + e["k"][h] > -8:               # Q8.8 scores need 2^(eq+ek) <= 2^-8
                e["q"][h] = -8 - e["k"][h]
            shq = e["q"][h] - (e["ln1"] + ewq)
            shk = e["k"][h] - (e["ln1"] + ewk)
            self.wq.append(wq_); self.wk.append(wk_); self.wvt.append(np.ascontiguousarray(wv_.T))
            self.sh_q.append(shq); self.sh_k.append(shk)
            self.sh_v.append(e["v"][h] - (e["ln1"] + ewv))
            self.sh_s.append(-8 - (e["q"][h] + e["k"][h]))
            self.sh_a.append(e["att"][h] - (-7 + e["v"][h]))
            self.bq.append(np.round(b[cs] * sc / 2.0 ** (e["ln1"] + ewq)).astype(np.int64) + half(shq))
            self.bk.append(np.round(b[D:][cs] / 2.0 ** (e["ln1"] + ewk)).astype(np.int64) + half(shk))
            q_, ew = wq_attn(wo_f[cs, :], hs("att", h))
            wo_q.append(q_); ewo.append(ew)
        prod = [e["att"][h] + ewo[h] for h in range(H)]
        self.E_o = max(max(prod), -F_RES - MAX_ACC_SHIFT)
        self.s_o = -F_RES - self.E_o
        for h in range(H):
            sh = self.E_o - prod[h]
            bias = np.full(D, half(sh), np.int64)
            if h == 0:
                bias += (np.round(bo_f / 2.0 ** self.E_o).astype(np.int64) + half(self.s_o)) << sh
            self.wo.append(wo_q[h]); self.sh_o.append(sh); self.bo.append(bias)

        w1, b1, w2, b2 = (g("mlp.c_fc.weight"), g("mlp.c_fc.bias"),
                          g("mlp.c_proj.weight"), g("mlp.c_proj.bias"))
        self.w1, self.b1, self.lut, self.sh_l, self.w2, self.b2, self.sh_2 = ([] for _ in range(7))
        prod2, w2_q = [], []
        for c in range(self.NC):
            cs = slice(c * CH, (c + 1) * CH)
            q1, ew1 = wq_ffn(w1[:, cs], hs("ln2"))
            self.w1.append(q1)
            self.b1.append(np.round(b1[cs] / 2.0 ** (e["ln2"] + ew1)).astype(np.int64))
            self.sh_l.append(e["fc1"][c] - (e["ln2"] + ew1))
            codes = np.arange(-128, 128) * 2.0 ** e["fc1"][c]
            self.lut.append(np.clip(np.round(gelu_new_np(codes) / 2.0 ** e["gelu"][c]),
                                    -128, 127).astype(np.int64))
            q2, ew2 = wq_ffn(w2[cs, :], hs("gelu", c))
            w2_q.append(q2); prod2.append(e["gelu"][c] + ew2)
        self.E_2 = max(max(prod2), -F_RES - MAX_ACC_SHIFT)
        self.s_2 = -F_RES - self.E_2
        for c in range(self.NC):
            sh = self.E_2 - prod2[c]
            bias = np.full(D, half(sh), np.int64)
            if c == 0:
                bias += (np.round(b2 / 2.0 ** self.E_2).astype(np.int64) + half(self.s_2)) << sh
            self.w2.append(w2_q[c]); self.sh_2.append(sh); self.b2.append(bias)

        shifts = {"sh_q": self.sh_q, "sh_k": self.sh_k, "sh_v": self.sh_v, "sh_s": self.sh_s,
                  "sh_a": self.sh_a, "sh_o": self.sh_o, "sh_l": self.sh_l, "sh_2": self.sh_2,
                  "s_o": [abs(self.s_o) + 1], "s_2": [abs(self.s_2) + 1], "ln_rb": [LN_RB]}
        for nm, v in shifts.items():
            if min(v) < 0 or max(v) > 31:
                raise ValueError(f"layer {i}: illegal shift {nm}={v}")
        for nm, v in (("ln1.gamma", self.ln1[0]), ("ln2.gamma", self.ln2[0]),
                      ("ln1.beta", self.ln1[1]), ("ln2.beta", self.ln2[1])):
            if np.abs(v).max() >= 2 ** 31:
                raise ValueError(f"layer {i}: {nm} exceeds INT32")
        self.stats = {"acc_peak": 0, "ln_sat": 0, "ln_elems": 0}

    def shift_table(self) -> dict:
        return {k: getattr(self, k) for k in ("sh_q", "sh_k", "sh_v", "sh_s", "sh_a", "sh_o",
                                              "sh_l", "sh_2", "s_o", "s_2", "E_o", "E_2")}

    def _ln(self, x, params):
        sm = x.sum(-1, keepdims=True)
        d = x - np.where(sm >= 0, sm // x.shape[-1], -((-sm) // x.shape[-1]))
        raw = (d * params[0][None, :]) >> 15
        self.stats["ln_sat"] += int((np.abs(raw) >= 2 ** 31).sum())
        self.stats["ln_elems"] += raw.size
        return I.requant(I.layernorm_rows(x, *params), LN_RB)

    @staticmethod
    def rescale(acc, s):
        """ACC >> s via RESIDUAL(ACC, ACC, s + 1); a negative s is -s doublings."""
        if s > 0:
            return I.residual(acc, acc, s + 1)
        for _ in range(-s):
            acc = I.residual(acc, acc, 0)
        return acc

    def _acc(self, acc, part):
        acc = part if acc is None else I.residual(acc, part)
        self.stats["acc_peak"] = max(self.stats["acc_peak"], int(np.abs(acc).max()))
        return acc

    # ------------------------------------------------ bit-exact integer forward
    def new_cache(self, kmax: int) -> list:
        """Per-head INT8 K and V caches, rows = token positions."""
        return [{"k": np.zeros((kmax, self.HD), np.int64), "v": np.zeros((kmax, self.HD), np.int64)}
                for _ in range(self.H)]

    def forward(self, x: np.ndarray, pos0: int = 0, kv: list | None = None,
                trace: dict | None = None) -> np.ndarray:
        """x: INT32 residual rows for positions pos0..pos0+R-1 at 2^-F_RES (R and pos0
        multiples of 4).  kv: per-head caches [KMAX, hd], rows pos0.. updated in place.
        Probabilities are zero-padded to KMAX so AV always runs at K = KMAX."""
        rows = x.shape[0]
        kv = self.new_cache(pos0 + rows) if kv is None else kv
        kmax, n = kv[0]["k"].shape[0], pos0 + rows
        assert rows % 4 == 0 and pos0 % 4 == 0 and n <= kmax
        xp = self._ln(x, self.ln1)
        acc = None
        for h in range(self.H):
            c = kv[h]
            q8 = I.requant(I.gemm(xp, self.wq[h], self.bq[h], self.sh_q[h]), 0)
            c["k"][pos0:n] = I.requant(I.gemm(xp, self.wk[h], self.bk[h], self.sh_k[h]), 0)
            vt8 = I.requant(I.gemm(self.wvt[h], xp.T, np.full(rows, half(self.sh_v[h])),
                                   self.sh_v[h]), 0)
            c["v"][pos0:n] = vt8.T
            s = I.gemm(q8, c["k"][:n].T, np.full(n, half(self.sh_s[h])), self.sh_s[h])
            pr = I.causal_softmax_rows(s, pos0)
            p8 = np.zeros((rows, kmax), np.int64)
            p8[:, :n] = I.requant(pr, 8, round_nearest=True)
            av8 = I.requant(I.gemm(p8, c["v"], np.full(self.HD, half(self.sh_a[h])), self.sh_a[h]), 0)
            acc = self._acc(acc, I.gemm(av8, self.wo[h], self.bo[h], self.sh_o[h]))
            if trace is not None and h == 0:
                trace.update(xp=xp, q8=q8, kc=c["k"].copy(), vt8=vt8, s=s, pr=pr, p8=p8, av8=av8)
        if self.stats["acc_peak"] << max(0, -self.s_o) >= 2 ** 30:
            raise OverflowError("attention accumulator exceeds 2^30")
        x1 = I.residual(x, self.rescale(acc, self.s_o))
        x2p = self._ln(x1, self.ln2)
        acc = None
        for c in range(self.NC):
            u = I.gemm(x2p, self.w1[c], self.b1[c], 0)
            h8 = I.lut_act(u, self.sh_l[c], self.lut[c])
            acc = self._acc(acc, I.gemm(h8, self.w2[c], self.b2[c], self.sh_2[c]))
            if trace is not None and c == 0:
                trace.update(h8=h8)
        if self.stats["acc_peak"] << max(0, -self.s_2) >= 2 ** 30:
            raise OverflowError("FFN accumulator exceeds 2^30")
        out = I.residual(x1, self.rescale(acc, self.s_2))
        if trace is not None:
            trace.update(x1=x1, x2p=x2p, out=out)
        return out


def quant_embed(fm: FloatGpt2, ids, pos0: int = 0) -> np.ndarray:
    e = fm.sd["wte.weight"][ids] + fm.sd["wpe.weight"][pos0:pos0 + len(ids)]
    return np.round(e.double().numpy() * 2 ** F_RES).astype(np.int64)


def head_logits(fm: FloatGpt2, x_int: np.ndarray) -> torch.Tensor:
    return fm.head(torch.from_numpy(x_int.astype(np.float64) / 2 ** F_RES).float())


# ------------------------------------------------------------------ emission
def put_weight(P: Program, name: str, packed_words: np.ndarray, kind: str):
    """Packed INT8 operand words -> DDR; INT4 block-exponent super-blocks
    (256-byte aligned) when the program streams this kind of weight as INT4."""
    if kind in getattr(P, "weight_i4", ()):
        w = np.asarray(packed_words, np.int64).reshape(-1)
        b = np.stack([(w >> (8 * k)) & 0xFF for k in range(4)], 1).reshape(-1, 16)
        P.ddr_put(name, I.pack_i4_stream(np.where(b >= 128, b - 256, b)), align=256)
    else:
        P.ddr_put(name, packed_words)


def put_layer(P: Program, ql: QuantLayer, li: int, kmax: int):
    """DDR image of one block: weights/biases plus zeroed per-head K/V caches."""
    base, HD = f"L{li}", ql.HD
    P.ddr_put(f"{base}.ln1", np.concatenate(ql.ln1)); P.ddr_put(f"{base}.ln2", np.concatenate(ql.ln2))
    for h in range(ql.H):
        put_weight(P, f"{base}.wq{h}", I.pack_b(ql.wq[h]), "attn")
        put_weight(P, f"{base}.wk{h}", I.pack_b(ql.wk[h]), "attn")
        put_weight(P, f"{base}.wvt{h}", I.pack_a(ql.wvt[h]), "attn")
        put_weight(P, f"{base}.wo{h}", I.pack_b(ql.wo[h]), "attn")
        P.ddr_put(f"{base}.hb{h}", np.concatenate([
            ql.bq[h], ql.bk[h], np.full(kmax, half(ql.sh_v[h])), np.full(kmax, half(ql.sh_s[h])),
            np.full(HD, half(ql.sh_a[h])), ql.bo[h]]))
        P.ddr_put(f"{base}.kc{h}", np.zeros(kmax * HD // 4, np.int64))   # packed-A K [kmax, hd]
        P.ddr_put(f"{base}.vc{h}", np.zeros(kmax * HD // 4, np.int64))   # packed-A V^T [hd, kmax]
    for c in range(ql.NC):
        put_weight(P, f"{base}.w1c{c}", I.pack_b(ql.w1[c]), "ffn")
        put_weight(P, f"{base}.w2c{c}", I.pack_b(ql.w2[c]), "ffn")
        P.ddr_put(f"{base}.cb{c}", np.concatenate([ql.b1[c], I.pack_lut(ql.lut[c]), ql.b2[c]]))


def emit_layer(P: Program, ql: QuantLayer, li: int, R: dict, x_in: np.ndarray, pos0: int,
               kv: list, kmax: int, tag: str, check: str, gemm_acc: bool = True):
    """One block over rows pos0..pos0+T-1 (prefill: all prompt rows; decode: the
    4-token group holding the new token).  K/V caches live in DDR per head."""
    D, H, HD, T = ql.D, ql.H, ql.HD, x_in.shape[0]
    n = pos0 + T
    tr = {}
    out = ql.forward(x_in, pos0, kv, tr)
    base, mem = f"{tag}.L{li}", f"L{li}"
    ai4 = "attn" in getattr(P, "weight_i4", ())
    fi4 = "ffn" in getattr(P, "weight_i4", ())

    def nxt(kind):
        """Rotate through the kind's SPAD slots (one slot each, except two
        weight slots, without --overlap; deeper pools with it)."""
        slots, rot = R[kind + "_slots"], R["_rot"]
        rot[kind] = (rot.get(kind, -1) + 1) % len(slots)
        return slots[rot[kind]]

    def layernorm(dst, lnb):
        idx = None
        for r in range(T):
            P.emit(f"{base}.ln.r{r}", OP_LAYERNORM, R["X"] + r * D * 4, R["LNT"] + (r % 4) * D * 4,
                   src1=lnb, bias=lnb + D * 4, k_or_length=D, flags=FLAG_BIAS, aux0=1)
            if r % 4 == 3:
                idx = P.emit(f"{base}.lnpack.g{r // 4}", OP_REQUANT, R["LNT"], dst + (r // 4) * D * 4,
                             m=4, n=D, k_or_length=4 * D, flags=PACK, shift=LN_RB, aux0=1)
        return idx

    def pack(name, src, dst, m, n_, shift=0, flags=PACK):
        return P.emit(name, OP_REQUANT, src, dst, m=m, n=n_, k_or_length=m * n_, flags=flags,
                      shift=shift, aux0=1)

    def gemm(name, a, b, dst, bias, m, n_, k, shift, acc=False):
        return P.emit(name, OP_GEMM, a, dst, src1=b, bias=bias,
                      flags=FLAG_BIAS | (FLAG_GEMM_ACC if acc else 0), m=m, n=n_,
                      k_or_length=k // 4, shift=shift, aux0=1)

    def resid(name, dst, a, b, shift=0):
        """Row-chunked RESIDUAL: one op stays below the dispatcher's 65535-cycle
        dependency-wait limit seen by its successor."""
        idx = None
        for r0 in range(0, T, RES_ROWS):
            o = r0 * D * 4
            idx = P.emit(f"{name}.r{r0}", OP_RESIDUAL, a + o, dst + o, src1=b + o,
                         k_or_length=min(RES_ROWS, T - r0) * D, shift=shift, aux0=1)
        return idx

    def rescale(name, s):
        for j in range(1 if s > 0 else -s):
            resid(f"{name}.rescale{j}", R["ACC"], R["ACC"], R["ACC"], s + 1 if s > 0 else 0)

    dbg = check == "debug" and li == 0
    lnb = nxt("LN")
    P.dma(f"{mem}.ln1", lnb)
    idx = layernorm(R["XP"], lnb)
    if dbg:
        P.checkpoint(idx, R["XP"], I.pack_a(tr["xp"]))
    for h in range(H):
        wq, wk, hb, KC, VC = nxt("W"), nxt("W"), nxt("HB"), nxt("KC"), nxt("VC")
        BQ, BK = hb, hb + HD * 4
        BVR = BK + HD * 4
        BSR = BVR + kmax * 4
        BAR = BSR + kmax * 4
        BO = BAR + HD * 4
        P.dma(f"{mem}.wq{h}", wq, expand_i4=ai4); P.dma(f"{mem}.wk{h}", wk, expand_i4=ai4)
        P.dma(f"{mem}.hb{h}", hb)
        if pos0:
            P.dma(f"{mem}.kc{h}", KC, pos0 * HD // 4)
        gemm(f"{base}.h{h}.q", R["XP"], wq, R["PROJ"], BQ, T, HD, D, ql.sh_q[h])
        pack(f"{base}.h{h}.qpack", R["PROJ"], R["Q8"], T, HD)
        gemm(f"{base}.h{h}.k", R["XP"], wk, R["PROJ"], BK, T, HD, D, ql.sh_k[h])
        ik = pack(f"{base}.h{h}.kpack", R["PROJ"], KC + pos0 * HD, T, HD)
        wv, wo = nxt("W"), nxt("W")
        P.dma(f"{mem}.wvt{h}", wv, expand_i4=ai4); P.dma(f"{mem}.wo{h}", wo, expand_i4=ai4)
        gemm(f"{base}.h{h}.vt", wv, R["XP"], R["PROJ"], BVR, HD, T, D, ql.sh_v[h])
        iv = pack(f"{base}.h{h}.vtpack", R["PROJ"], R["VT8"], HD, T)
        # V^T group columns -> DDR cache rows (2D store), then the whole cache back.
        P.dma(f"{mem}.vc{h}", R["VT8"], T, offset=pos0 * 4, rows=HD // 4,
              ext_stride=kmax * 4, spad_stride=T * 4, store=True)
        P.dma(f"{mem}.vc{h}", VC)
        i_s = gemm(f"{base}.h{h}.s", R["Q8"], KC, R["SC"], BSR, T, n, HD, ql.sh_s[h])
        for r in range(T):
            i_sm = P.emit(f"{base}.h{h}.sm{r}", OP_CAUSAL_SOFTMAX, R["SC"] + r * n * 4,
                          R["PR"] + r * kmax * 4, k_or_length=n, aux0=pos0 + r)
        pack(f"{base}.h{h}.p8", R["PR"], R["P8"], T, kmax, shift=8, flags=PACK | FLAG7)
        gemm(f"{base}.h{h}.av", R["P8"], VC, R["AVO"], BAR, T, HD, kmax, ql.sh_a[h])
        i_av = pack(f"{base}.h{h}.avpack", R["AVO"], R["AV8"], T, HD)
        if gemm_acc:            # ACC = sat32(ACC + head output) in the GEMM epilogue
            idx = gemm(f"{base}.h{h}.wo", R["AV8"], wo, R["ACC"], BO, T, D, HD, ql.sh_o[h],
                       acc=h > 0)
        else:
            dst = R["ACC"] if h == 0 else R["PART"]
            idx = gemm(f"{base}.h{h}.wo", R["AV8"], wo, dst, BO, T, D, HD, ql.sh_o[h])
            if h:
                idx = resid(f"{base}.h{h}.acc", R["ACC"], R["ACC"], R["PART"])
        if dbg and h == 0:
            P.checkpoint(ik, KC, I.pack_a(tr["kc"][:n]))
            P.checkpoint(iv, R["VT8"], I.pack_a(tr["vt8"]))
            P.checkpoint(i_s, R["SC"], I.words_i32(tr["s"]))
            pr = np.zeros((T, kmax), np.int64); pr[:, :n] = tr["pr"]
            P.checkpoint(i_sm, R["PR"], I.words_i32(pr))
            P.checkpoint(i_av, R["AV8"], I.pack_a(tr["av8"]))
        P.dma(f"{mem}.kc{h}", KC + pos0 * HD, T * HD // 4, offset=pos0 * HD, store=True)
    rescale(f"{base}.attn", ql.s_o)
    idx = resid(f"{base}.res1", R["X"], R["X"], R["ACC"])
    if check == "debug" or li == 0:
        P.checkpoint(idx, R["X"], I.words_i32(tr["x1"]))
    lnb = nxt("LN")
    P.dma(f"{mem}.ln2", lnb)
    idx = layernorm(R["XP"], lnb)
    if dbg:
        P.checkpoint(idx, R["XP"], I.pack_a(tr["x2p"]))
    for c in range(ql.NC):
        w1, w2, cb = nxt("W"), nxt("W"), nxt("CB")
        P.dma(f"{mem}.w1c{c}", w1, expand_i4=fi4); P.dma(f"{mem}.w2c{c}", w2, expand_i4=fi4)
        P.dma(f"{mem}.cb{c}", cb)
        gemm(f"{base}.c{c}.fc1", R["XP"], w1, R["H1"], cb, T, CH, D, 0)
        ig = P.emit(f"{base}.c{c}.gelu", OP_GELU, R["H1"], R["H8"], src1=cb + CH * 4, m=T, n=CH,
                    k_or_length=T * CH, flags=PACK | FLAG7, shift=ql.sh_l[c], aux0=1)
        if dbg and c == 0:
            P.checkpoint(ig, R["H8"], I.pack_a(tr["h8"]))
        if gemm_acc:
            gemm(f"{base}.c{c}.fc2", R["H8"], w2, R["ACC"], cb + (CH + 64) * 4, T, D, CH,
                 ql.sh_2[c], acc=c > 0)
        else:
            dst = R["ACC"] if c == 0 else R["PART"]
            gemm(f"{base}.c{c}.fc2", R["H8"], w2, dst, cb + (CH + 64) * 4, T, D, CH, ql.sh_2[c])
            if c:
                resid(f"{base}.c{c}.acc", R["ACC"], R["ACC"], R["PART"])
    rescale(f"{base}.ffn", ql.s_2)
    idx = resid(f"{base}.res2", R["X"], R["X"], R["ACC"])
    P.checkpoint(idx, R["X"], I.words_i32(out))
    return out


def allocate(P: Program, T: int, D: int, HD: int, kmax: int, pools: dict | None = None) -> dict:
    """SPAD map.  Without pools this is the Round 36 map (two weight slots,
    one LN/HB/CB/K/V slot).  `pools` gives the slot count per kind for the
    overlap schedule, where DMA into a free slot runs ahead of compute."""
    pools = pools or {"W": 2, "LN": 1, "HB": 1, "CB": 1, "KC": 1, "VC": 1}
    R = {"_rot": {}}
    for nm, sz in (("X", T * D * 4), ("ACC", T * D * 4), ("PART", T * D * 4), ("XP", T * D),
                   ("LNT", 4 * D * 4)):
        R[nm] = P.alloc(nm, sz)
    w_bytes = D * HD
    if getattr(P, "weight_i4", ()):                # INT4 streams land in 480-byte super-blocks
        w_bytes = -(-w_bytes // 480) * 480
    sizes = {"W": w_bytes, "LN": 2 * D * 4, "HB": (HD + HD + kmax + kmax + HD + D) * 4,
             "CB": (CH + 64 + D) * 4, "KC": kmax * HD, "VC": kmax * HD}
    for kind in ("W", "LN", "HB", "CB"):
        R[kind + "_slots"] = [P.alloc(f"{kind}{i}", sizes[kind]) for i in range(pools[kind])]
    R["PR"] = P.alloc("PR", T * kmax * 4)          # columns >= current length stay zero
    for kind in ("KC", "VC"):
        R[kind + "_slots"] = [P.alloc(f"{kind}{i}", sizes[kind]) for i in range(pools[kind])]
    u0 = P.next_addr                               # attention / FFN scratch union
    for nm, sz in (("PROJ", T * HD * 4), ("Q8", T * HD), ("VT8", T * HD), ("SC", T * kmax * 4),
                   ("P8", T * kmax), ("AVO", T * HD * 4), ("AV8", T * HD)):
        R[nm] = P.alloc(nm, sz)
    attn_end, P.next_addr = P.next_addr, u0
    for nm, sz in (("H1", T * CH * 4), ("H8", T * CH)):
        R[nm] = P.alloc(nm, sz)
    P.next_addr = max(P.next_addr, attn_end)
    for hb in R["HB_slots"]:
        for off in (0, HD, 2 * HD, 2 * HD + kmax, 2 * HD + 2 * kmax, 3 * HD + 2 * kmax):
            assert (hb + 4 * off) % 16 == 0
    for cb in R["CB_slots"]:
        assert cb % 16 == 0 and (cb + CH * 4) % 16 == 0 and (cb + (CH + 64) * 4) % 16 == 0
    return R


def allocate_overlap(P: Program, T: int, D: int, HD: int, kmax: int) -> dict:
    """Largest weight-slot pool that fits below the queue rings."""
    for w in (8, 6, 5, 4, 3, 2):
        saved = (P.next_addr, dict(P.regions))
        try:
            return allocate(P, T, D, HD, kmax,
                            {"W": w, "LN": 2, "HB": 2, "CB": 2, "KC": 2, "VC": 2})
        except ValueError:
            P.next_addr, P.regions = saved
    return allocate(P, T, D, HD, kmax)


# ------------------------------------------------------------------ data / metrics
def load_tokens(model_dir: Path, wikitext: Path) -> np.ndarray:
    import pyarrow.parquet as pq
    from transformers import GPT2TokenizerFast
    text = "\n\n".join(pq.read_table(wikitext).column("text").to_pylist())
    return np.array(GPT2TokenizerFast.from_pretrained(str(model_dir))(text)["input_ids"], np.int64)


def windows(tokens, ctx, n, start=0):
    return [torch.from_numpy(tokens[start + w * ctx: start + w * ctx + ctx + 1].copy())
            for w in range(n) if start + w * ctx + ctx + 1 <= len(tokens)]


def int_forward(fm, qls, ids):
    x = quant_embed(fm, ids)
    for q in qls:
        x = q.forward(x)
    return head_logits(fm, x)


def ppl(logit_fn, wins) -> float:
    nll = cnt = 0
    for w in wins:
        nll += torch.nn.functional.cross_entropy(logit_fn(w[:-1]), w[1:], reduction="sum").item()
        cnt += w.numel() - 1
    return math.exp(nll / cnt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", type=Path, required=True)
    ap.add_argument("--wikitext", type=Path, required=True)
    ap.add_argument("--layers", type=int, default=1, help="decoder blocks placed on the NPU")
    ap.add_argument("--tokens", type=int, default=32, help="WikiText prompt length (no --prompt)")
    ap.add_argument("--prompt", default="", help="text prompt instead of WikiText tokens")
    ap.add_argument("--calib-windows", type=int, default=8)
    ap.add_argument("--calib-ctx", type=int, default=256)
    ap.add_argument("--smooth", type=float, default=0.5)
    ap.add_argument("--ppl-windows", type=int, default=0)
    ap.add_argument("--ppl-ctx", type=int, default=256)
    ap.add_argument("--decode-steps", type=int, default=0, help="greedy decode steps after prefill")
    ap.add_argument("--kmax", type=int, default=64, help="KV-cache capacity (tokens)")
    ap.add_argument("--check", default="layer", choices=("layer", "debug"))
    ap.add_argument("--no-program", action="store_true")
    ap.add_argument("--overlap", action="store_true",
                    help="program format v3: CMDQ DMA (0x60) overlapped with compute")
    ap.add_argument("--hoist", type=int, default=48,
                    help="max descriptors a DMA load may be moved ahead (--overlap)")
    ap.add_argument("--int4-weights", choices=("none", "ffn", "all"), default="none",
                    help="stream these Linear weights as INT4 block-exponent super-blocks "
                         "(0x60 flags[1]): ffn = MLP only, all = MLP + attention")
    ap.add_argument("--no-gptq", action="store_true",
                    help="round INT4 weights to nearest instead of GPTQ error propagation")
    ap.add_argument("--no-gemm-acc", action="store_true",
                    help="legacy head/chunk sums: GEMM to PART + RESIDUAL (no 0x30 flags[7])")
    ap.add_argument("--out", type=Path, required=True)
    a = ap.parse_args()
    assert a.ppl_ctx % 4 == 0

    tokens = load_tokens(a.model_dir, a.wikitext)
    fm = FloatGpt2(a.model_dir)
    ref = FloatGpt2(a.model_dir)                       # unsmoothed FP32 reference
    calib = windows(tokens, a.calib_ctx, a.calib_windows,
                    start=len(tokens) - (a.calib_windows + 1) * (a.calib_ctx + 1))
    evalw = windows(tokens, a.ppl_ctx, a.ppl_windows) if a.ppl_windows else []

    from transformers import GPT2LMHeadModel
    hf = GPT2LMHeadModel.from_pretrained(str(a.model_dir)).eval()
    probe = torch.from_numpy(tokens[:64].copy())
    diff = (hf(probe[None]).logits[0] - ref.forward(probe)).abs().max().item()
    if diff > 1e-3:
        raise SystemExit(f"explicit forward differs from Hugging Face: {diff}")

    t0 = time.time()
    obs = [dict() for _ in range(fm.L)]
    for w in calib:
        fm.forward(w[:-1], obs)
    gptq = a.int4_weights != "none" and not a.no_gptq
    if a.smooth:
        fm.smooth(obs, a.smooth)
        obs = [dict(_hess=gptq) for _ in range(fm.L)]
        for w in calib:
            fm.forward(w[:-1], obs)
    smoothed_diff = (fm.forward(probe) - ref.forward(probe)).abs().max().item()
    i4_kinds = {"none": frozenset(), "ffn": frozenset({"ffn"}),
                "all": frozenset({"ffn", "attn"})}[a.int4_weights]
    qls = [QuantLayer(fm, i, obs[i], int4=i4_kinds) for i in range(fm.L)]
    result = {"model": fm.name, "d_model": fm.D, "n_layer": fm.L, "n_head": fm.H,
              "f_res": F_RES, "ln_round_bits": LN_RB, "smooth_alpha": a.smooth, "int4_gptq": gptq,
              "calib": f"{len(calib)}x{a.calib_ctx} WikiText-2 test tail",
              "hf_fp32_max_logit_diff": diff, "smoothed_fp32_max_logit_diff": smoothed_diff,
              "layers_on_npu": a.layers, "torch_threads": torch.get_num_threads(),
              "shifts": [q.shift_table() for q in qls]}
    print(f"GPT2_QUANT_READY model={fm.name} calib_s={time.time() - t0:.1f} hf_diff={diff:.2e} "
          f"smooth_diff={smoothed_diff:.2e}", flush=True)

    if evalw:
        t0 = time.time()
        p_fp = ppl(ref.forward, evalw)
        p_int = ppl(lambda ids: int_forward(fm, qls, ids), evalw)
        lsat = sum(q.stats["ln_sat"] for q in qls) / max(1, sum(q.stats["ln_elems"] for q in qls))
        result.update(ppl_ctx=a.ppl_ctx, ppl_windows=len(evalw), fp32_ppl=p_fp, int_ppl=p_int,
                      ln_post_gamma_saturation=lsat,
                      acc_peak=max(q.stats["acc_peak"] for q in qls))
        print(f"GPT2_INT_PPL model={fm.name} ctx={a.ppl_ctx} windows={len(evalw)} fp32={p_fp:.3f} "
              f"int={p_int:.3f} ln_sat={lsat:.2e} s={time.time() - t0:.0f}", flush=True)

    if a.no_program:
        a.out.mkdir(parents=True, exist_ok=True)
        (a.out / "quant_report.json").write_text(json.dumps(result, indent=2) + "\n")
        return
    from transformers import GPT2TokenizerFast
    tok = GPT2TokenizerFast.from_pretrained(str(a.model_dir))
    prompt = tok(a.prompt)["input_ids"] if a.prompt else [int(t) for t in tokens[:a.tokens]]
    Lp, S, kmax, L = len(prompt), a.decode_steps, a.kmax, fm.L
    T = (Lp + 3) // 4 * 4                              # prefill rows (padding rows are zero)
    assert Lp + S <= kmax and kmax % 4 == 0
    P = Program(overlap=a.overlap, hoist=a.hoist)
    if i4_kinds and not a.overlap and not a.no_program:
        raise SystemExit("--int4-weights needs --overlap (queued DMA)")
    P.weight_i4 = i4_kinds
    R = (allocate_overlap if a.overlap else allocate)(P, T, fm.D, fm.HD, kmax)
    P.ddr_put("zeros_pr", np.zeros(T * kmax, np.int64))
    P.dma("zeros_pr", R["PR"])
    for li in range(a.layers):
        put_layer(P, qls[li], li, kmax)
    kv = [q.new_cache(kmax) for q in qls]

    def block(xb, pos0, tag, R):
        """First a.layers blocks on the NPU program, the rest in the host Golden."""
        x = xb
        x_npu = None
        for li in range(L):
            if li < a.layers:
                x = emit_layer(P, qls[li], li, R, x, pos0, kv[li], kmax, tag,
                               a.check if tag == "P" else "layer",
                               gemm_acc=not a.no_gemm_acc)
                x_npu = x
            else:
                x = qls[li].forward(x, pos0, kv[li])
        return x_npu, x

    seq = list(prompt)
    xb = np.zeros((T, fm.D), np.int64)
    xb[:Lp] = quant_embed(fm, torch.tensor(seq))
    P.ddr_put("x.P", I.words_i32(xb)); P.dma("x.P", R["X"])
    x_npu, x = block(xb, 0, "P", R)
    Rd = R
    if a.overlap and S and T > 4:
        # Decode runs four rows: give it its own SPAD map with deeper slot pools.
        P.alloc_reset("dec.")
        Rd = allocate_overlap(P, 4, fm.D, fm.HD, kmax)
        P.dma("zeros_pr", Rd["PR"], 4 * kmax)
    prefill_pred = head_logits(fm, x)[:Lp].argmax(-1)
    seq.append(int(prefill_pred[-1]))
    for st in range(S):
        t = Lp + st
        pos0, j = t // 4 * 4, t % 4
        xb = np.zeros((4, fm.D), np.int64)
        xb[:j + 1] = quant_embed(fm, torch.tensor(seq[pos0:t + 1]), pos0)
        P.ddr_put(f"x.S{st}", I.words_i32(xb)); P.dma(f"x.S{st}", Rd["X"])
        x_npu, x = block(xb, pos0, f"S{st}", Rd)
        seq.append(int(head_logits(fm, x)[j].argmax()))
    P.final_rows(Rd["X"], I.words_i32(x_npu), fm.D, x_npu.shape[0])

    ref_seq = list(prompt)
    for _ in range(S + 1):                              # FP32 greedy, full recompute
        ref_seq.append(int(ref.forward(torch.tensor(ref_seq))[-1].argmax()))
    lf = ref.forward(torch.tensor(prompt)).argmax(-1)
    result.update(kmax=kmax, decode_steps=S, prompt_tokens=Lp, prefill_rows=T,
                  prefill_next_token_agreement_vs_fp32=float((prefill_pred == lf).float().mean()),
                  prompt=tok.decode(prompt), int_generated=tok.decode(seq[Lp:]),
                  fp32_generated=tok.decode(ref_seq[Lp:]), int_generated_ids=seq[Lp:],
                  fp32_generated_ids=ref_seq[Lp:],
                  greedy_match_tokens=int(next((i for i, (u, v) in enumerate(zip(seq[Lp:], ref_seq[Lp:]))
                                                if u != v), S + 1)))
    result.update(overlap=a.overlap, weight_slots=len(R["W_slots"]),
                  decode_weight_slots=len(Rd["W_slots"]),
                  hoist=a.hoist if a.overlap else 0, gemm_acc=not a.no_gemm_acc,
                  int4_weights=a.int4_weights)
    man = P.write(a.out, result)
    print("GPT2_PROGRAM_READY " + json.dumps({k: man.get(k) for k in (
        "descriptors", "segments", "dma_loads", "dma_stores", "dma_bytes", "spad_high_water",
        "checkpoint_words", "final_words", "ddr_bytes", "greedy_match_tokens", "weight_slots",
        "decode_weight_slots",
        "queued_dma", "hoisted_dma", "event_bits_peak", "dependency_waits")}), flush=True)
    print(f"GPT2_GENERATION int={result['int_generated']!r} fp32={result['fp32_generated']!r}")


if __name__ == "__main__":
    main()
