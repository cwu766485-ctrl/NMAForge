#!/usr/bin/env python3
"""DeiT-Tiny compiler for NMAForge Product Top (Round 35 numeric contract).

Pipeline: calibrate the official FP32 model -> power-of-two INT8 quantization
-> bit-exact integer forward (`nmaf.intops`, also the accuracy model) ->
descriptor program with streamed weights (`nmaf.program`).

Encoder layer schedule (D=192, H=3, hd=64, FF=768, T=197 tokens padded to 200):
  LN1 per valid row -> 4-row temp -> REQUANT pack (A layout)
  per head: Q = X Wq' (log2e/sqrt(hd) folded) -> pack; K -> pack;
            V^T = Wv^T X^T (packed X is the B operand of X^T) -> pack
            per 40-query block: S = Q K^T (Q8.8) -> Softmax(197) ->
            rounded REQUANT to Q7 -> AV -> pack into merged heads
  per 40-row block: Wo (V bias folded into bo) -> in-place RESIDUAL
  LN2 -> packed X2; per 24-row block: FC1 -> LUT GELU + pack -> FC2 -> RESIDUAL
The embedding (patch GEMM + cls/pos) is computed on the host as layer input.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "benchmark" / "deit_official"))
from nmaf import intops as I                                   # noqa: E402
from nmaf.program import FLAG_GEMM_ACC, Program                # noqa: E402
from cimforge_mapper import (FLAG_BIAS, FLAG_PACK_I8, FLAG_PACK_I8_TILE_A,  # noqa: E402
                             OP_GEMM, OP_GELU, OP_LAYERNORM, OP_REQUANT, OP_RESIDUAL,
                             OP_SOFTMAX)

D, H, HD, FF, T, TP = 192, 3, 64, 768, 197, 200
QB, FB = 40, 24                       # attention query block, FFN row block
LOG2E = 1.4426950408889634
FLAG7 = 1 << 7
F_RES = 10                            # residual stream Q.F
LN_RB = 4                             # LN rounding bits


def p2(x: float) -> int:
    """Exponent e with 2^e >= x (power-of-two scale, e may be negative)."""
    return int(math.ceil(math.log2(max(x, 1e-30))))


def gelu_erf(x):
    return 0.5 * x * (1.0 + torch.erf(x / math.sqrt(2.0)))


class FloatDeit:
    def __init__(self, sd):
        self.sd = {k.removeprefix("vit."): v.float() for k, v in sd.items()}

    def embed(self, img):
        p = img.unfold(1, 16, 16).unfold(2, 16, 16).permute(1, 2, 0, 3, 4).reshape(196, 768)
        w = self.sd["embeddings.patch_embeddings.projection.weight"].reshape(192, 768)
        e = p @ w.T + self.sd["embeddings.patch_embeddings.projection.bias"]
        return torch.cat([self.sd["embeddings.cls_token"][0], e], 0) + \
            self.sd["embeddings.position_embeddings"][0]

    def layer(self, i, x, obs=None):
        g = lambda n: self.sd[f"encoder.layer.{i}.{n}"]
        ln = lambda x, n: torch.nn.functional.layer_norm(x, (D,), g(n + ".weight"), g(n + ".bias"), 1e-12)
        def rec(k, v):
            if obs is not None:
                obs[k] = max(obs.get(k, 0.0), torch.quantile(v.abs().flatten(), 0.9999).item())
        a = ln(x, "layernorm_before"); rec("ln1", a)
        q = (a @ g("attention.attention.query.weight").T + g("attention.attention.query.bias")) * (LOG2E / 8.0)
        k = a @ g("attention.attention.key.weight").T + g("attention.attention.key.bias")
        v = a @ g("attention.attention.value.weight").T          # bias folded into Wo bias
        rec("q", q); rec("k", k); rec("v", v)
        att = torch.zeros(T, D)
        for h in range(H):
            s = q[:, h*HD:(h+1)*HD] @ k[:, h*HD:(h+1)*HD].T      # log2 domain
            p = torch.softmax(s * math.log(2.0), -1)
            att[:, h*HD:(h+1)*HD] = p @ v[:, h*HD:(h+1)*HD]
        rec("att", att)
        wo, bo = g("attention.output.dense.weight"), g("attention.output.dense.bias")
        bv = g("attention.attention.value.bias")
        x = x + att @ wo.T + (bo + wo @ bv)
        b = ln(x, "layernorm_after"); rec("ln2", b)
        u = b @ g("intermediate.dense.weight").T + g("intermediate.dense.bias"); rec("fc1", u)
        u = gelu_erf(u); rec("gelu", u)
        return x + u @ g("output.dense.weight").T + g("output.dense.bias")

    def head(self, x):
        h = torch.nn.functional.layer_norm(x[:1], (D,), self.sd["layernorm.weight"],
                                           self.sd["layernorm.bias"], 1e-12)
        return (h @ self.sd["classifier.weight"].T + self.sd["classifier.bias"])[0]


class QuantLayer:
    """Integer constants and shifts for one encoder layer."""

    def __init__(self, fm: FloatDeit, i: int, obs: dict):
        g = lambda n: fm.sd[f"encoder.layer.{i}.{n}"].double().numpy()
        e = {k: p2(v / 127.0) for k, v in obs.items()}             # activation exponents
        self.e = e
        def wq(w):                                                 # per-tensor pow2 INT8
            ew = p2(np.abs(w).max() / 127.0)
            return np.clip(np.round(w / 2.0 ** ew), -127, 127).astype(np.int64), ew
        # LN1/LN2: output codes at 2^e, LN produced at 2^(e-rb) with +half in beta.
        def ln_params(n, eo):
            gm, bt = g(n + ".weight"), g(n + ".bias")
            gq = np.round(gm * 32768.0 * 2 ** LN_RB / 2.0 ** eo).astype(np.int64)
            bq = np.round(bt * 2 ** LN_RB / 2.0 ** eo).astype(np.int64) + (1 << (LN_RB - 1))
            return gq, bq
        self.ln1 = ln_params("layernorm_before", e["ln1"])
        self.ln2 = ln_params("layernorm_after", e["ln2"])
        sc = LOG2E / 8.0
        self.wq, self.ewq = wq(g("attention.attention.query.weight").T * sc)   # [D, D]
        self.wk, self.ewk = wq(g("attention.attention.key.weight").T)
        self.wv, self.ewv = wq(g("attention.attention.value.weight").T)
        # Score Q8.8 needs 2^(eq+ek) <= 2^-8: shrink the Q scale if necessary.
        if e["q"] + e["k"] > -8:
            e["q"] = -8 - e["k"]
        self.sh_q = e["q"] - (e["ln1"] + self.ewq)
        self.sh_k = e["k"] - (e["ln1"] + self.ewk)
        self.sh_v = e["v"] - (e["ln1"] + self.ewv)
        self.sh_s = -8 - (e["q"] + e["k"])
        self.sh_a = e["att"] - (-7 + e["v"])
        def rbias(b, acc_e, sh):
            return np.round(b / 2.0 ** acc_e).astype(np.int64) + ((1 << (sh - 1)) if sh > 0 else 0)
        self.bq = rbias(g("attention.attention.query.bias") * sc, e["ln1"] + self.ewq, self.sh_q)
        self.bk = rbias(g("attention.attention.key.bias"), e["ln1"] + self.ewk, self.sh_k)
        self.bv_round = np.full(TP, (1 << (self.sh_v - 1)) if self.sh_v > 0 else 0, np.int64)
        self.bs_round = np.full(TP, (1 << (self.sh_s - 1)) if self.sh_s > 0 else 0, np.int64)
        self.ba_round = np.full(HD, (1 << (self.sh_a - 1)) if self.sh_a > 0 else 0, np.int64)
        wo = g("attention.output.dense.weight")
        self.wo, self.ewo = wq(wo.T)
        self.sh_o = -F_RES - (e["att"] + self.ewo)
        bo = g("attention.output.dense.bias") + wo @ g("attention.attention.value.bias")
        self.bo = rbias(bo, e["att"] + self.ewo, self.sh_o)
        self.w1, self.ew1 = wq(g("intermediate.dense.weight").T)
        self.b1 = np.round(g("intermediate.dense.bias") / 2.0 ** (e["ln2"] + self.ew1)).astype(np.int64)
        self.sh_l = e["fc1"] - (e["ln2"] + self.ew1)
        codes = np.arange(-128, 128) * 2.0 ** e["fc1"]
        gel = 0.5 * codes * (1.0 + np.vectorize(math.erf)(codes / math.sqrt(2.0)))
        self.lut = np.clip(np.round(gel / 2.0 ** e["gelu"]), -128, 127).astype(np.int64)
        self.w2, self.ew2 = wq(g("output.dense.weight").T)
        self.sh_2 = -F_RES - (e["gelu"] + self.ew2)
        self.b2 = rbias(g("output.dense.bias"), e["gelu"] + self.ew2, self.sh_2)
        for nm in ("sh_q", "sh_k", "sh_v", "sh_s", "sh_a", "sh_o", "sh_l", "sh_2"):
            if not 0 <= getattr(self, nm) <= 31:
                raise ValueError(f"layer {i}: illegal shift {nm}={getattr(self, nm)}")

    # ------------------------------------------------ bit-exact integer forward
    def forward(self, x: np.ndarray, trace: dict | None = None) -> np.ndarray:
        """x: INT32 residual [TP, D] at 2^-F_RES (padding rows arbitrary)."""
        xp = np.zeros((TP, D), np.int64)
        xp[:T] = I.requant(I.layernorm_rows(x[:T], *self.ln1), LN_RB)
        heads = np.zeros((TP, D), np.int64)
        for h in range(H):
            cs = slice(h * HD, (h + 1) * HD)
            q8 = I.requant(I.gemm(xp, self.wq[:, cs], self.bq[cs], self.sh_q), 0)
            k8 = I.requant(I.gemm(xp, self.wk[:, cs], self.bk[cs], self.sh_k), 0)
            vt8 = I.requant(I.gemm(self.wv[:, cs].T, xp.T, self.bv_round, self.sh_v), 0)
            s = I.gemm(q8, k8.T, self.bs_round, self.sh_s)
            pr = np.zeros((TP, TP), np.int64)
            pr[:T, :T] = I.softmax_rows(s[:T], T)
            p8 = I.requant(pr, 8, round_nearest=True)
            heads[:, cs] = I.requant(I.gemm(p8, vt8.T, self.ba_round, self.sh_a), 0)
            if trace is not None and h == 0:
                trace.update(q8=q8, k8=k8, vt8=vt8, s=s, pr=pr, p8=p8)
        wo = I.gemm(heads, self.wo, self.bo, self.sh_o)
        x1 = I.residual(x, wo)
        x2p = np.zeros((TP, D), np.int64)
        x2p[:T] = I.requant(I.layernorm_rows(x1[:T], *self.ln2), LN_RB)
        u = I.gemm(x2p, self.w1, self.b1, 0)
        h8 = I.lut_act(u, self.sh_l, self.lut)
        y = I.gemm(h8, self.w2, self.b2, self.sh_2)
        out = I.residual(x1, y)
        if trace is not None:
            trace.update(xp=xp, heads=heads, x1=x1, x2p=x2p, h8=h8, out=out)
        return out


def quant_embed(fm: FloatDeit, img) -> np.ndarray:
    x = np.zeros((TP, D), np.int64)
    x[:T] = np.round(fm.embed(img).double().numpy() * 2 ** F_RES).astype(np.int64)
    return x


def head_logits(fm: FloatDeit, x_int: np.ndarray) -> np.ndarray:
    x = torch.from_numpy(x_int[:T].astype(np.float64) / 2 ** F_RES).float()
    return fm.head(x).numpy()


# ------------------------------------------------------------------ emission
def emit_layer(P: Program, ql: QuantLayer, li: int, R: dict, x_in: np.ndarray, check: str,
               gemm_acc: bool = True):
    tr = {}
    out = ql.forward(x_in, tr)
    base = f"L{li}"
    # DDR blobs for this layer
    P.ddr_put(f"{base}.ln1g", ql.ln1[0]); P.ddr_put(f"{base}.ln1b", ql.ln1[1])
    P.ddr_put(f"{base}.ln2g", ql.ln2[0]); P.ddr_put(f"{base}.ln2b", ql.ln2[1])
    for h in range(H):
        cs = slice(h * HD, (h + 1) * HD)
        P.ddr_put(f"{base}.wq{h}", I.pack_b(ql.wq[:, cs])); P.ddr_put(f"{base}.bq{h}", ql.bq[cs])
        P.ddr_put(f"{base}.wk{h}", I.pack_b(ql.wk[:, cs])); P.ddr_put(f"{base}.bk{h}", ql.bk[cs])
        P.ddr_put(f"{base}.wvt{h}", I.pack_a(ql.wv[:, cs].T))
    P.ddr_put(f"{base}.bvr", ql.bv_round); P.ddr_put(f"{base}.bsr", ql.bs_round)
    P.ddr_put(f"{base}.bar", ql.ba_round)
    P.ddr_put(f"{base}.wo", I.pack_b(ql.wo)); P.ddr_put(f"{base}.bo", ql.bo)
    P.ddr_put(f"{base}.w1", I.pack_b(ql.w1)); P.ddr_put(f"{base}.b1", ql.b1)
    P.ddr_put(f"{base}.w2", I.pack_b(ql.w2)); P.ddr_put(f"{base}.b2", ql.b2)
    P.ddr_put(f"{base}.lut", I.pack_lut(ql.lut))

    for nm, reg in (("ln1g", "LN_G"), ("ln1b", "LN_B")):
        P.dma(f"{base}.{nm}", R[reg])
    for nm in ("bvr", "bsr", "bar"):
        P.dma(f"{base}.{nm}", R[nm.upper()])
    P.dma("zeros_pr", R["PR"])                                   # prob cols 197..199 = 0

    def layernorm(dst_packed):
        for r in range(T):
            P.emit(f"{base}.ln.r{r}", OP_LAYERNORM, R["X"] + r * D * 4, R["LNT"] + (r % 4) * D * 4,
                   src1=R["LN_G"], bias=R["LN_B"], k_or_length=D, flags=FLAG_BIAS, aux0=1)
            if r % 4 == 3 or r == T - 1:
                grp = r // 4
                P.emit(f"{base}.lnpack.g{grp}", OP_REQUANT, R["LNT"], dst_packed + grp * D * 4,
                       m=4, n=D, k_or_length=4 * D, flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                       shift=LN_RB, aux0=1)

    layernorm(R["XP"])
    for h in range(H):
        P.dma(f"{base}.wq{h}", R["WQ"]); P.dma(f"{base}.wk{h}", R["WK"])
        P.dma(f"{base}.wvt{h}", R["WVT"]); P.dma(f"{base}.bq{h}", R["BQ"])
        P.dma(f"{base}.bk{h}", R["BK"])
        for nm, w, b, sh, dst in (("q", "WQ", "BQ", ql.sh_q, "Q8"), ("k", "WK", "BK", ql.sh_k, "K8")):
            P.emit(f"{base}.h{h}.{nm}", OP_GEMM, R["XP"], R["PROJ"], src1=R[w], bias=R[b],
                   flags=FLAG_BIAS, m=TP, n=HD, k_or_length=D // 4, shift=sh, aux0=1)
            idx = P.emit(f"{base}.h{h}.{nm}pack", OP_REQUANT, R["PROJ"], R[dst], m=TP, n=HD,
                         k_or_length=TP * HD, flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        P.emit(f"{base}.h{h}.vt", OP_GEMM, R["WVT"], R["PROJ"], src1=R["XP"], bias=R["BVR"],
               flags=FLAG_BIAS, m=HD, n=TP, k_or_length=D // 4, shift=ql.sh_v, aux0=1)
        P.emit(f"{base}.h{h}.vtpack", OP_REQUANT, R["PROJ"], R["VT8"], m=HD, n=TP,
               k_or_length=HD * TP, flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        for b in range(TP // QB):
            r0 = b * QB
            P.emit(f"{base}.h{h}.b{b}.s", OP_GEMM, R["Q8"] + (r0 // 4) * HD * 4, R["SC"],
                   src1=R["K8"], bias=R["BSR"], flags=FLAG_BIAS, m=QB, n=TP, k_or_length=HD // 4,
                   shift=ql.sh_s, aux0=1)
            for r in range(QB):
                if r0 + r < T:
                    P.emit(f"{base}.h{h}.b{b}.sm{r}", OP_SOFTMAX, R["SC"] + r * TP * 4,
                           R["PR"] + r * TP * 4, k_or_length=T, aux0=1)
            P.emit(f"{base}.h{h}.b{b}.p8", OP_REQUANT, R["PR"], R["P8"], m=QB, n=TP,
                   k_or_length=QB * TP, flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A | FLAG7,
                   shift=8, aux0=1)
            P.emit(f"{base}.h{h}.b{b}.av", OP_GEMM, R["P8"], R["AVO"], src1=R["VT8"], bias=R["BAR"],
                   flags=FLAG_BIAS, m=QB, n=HD, k_or_length=TP // 4, shift=ql.sh_a, aux0=1)
            for gi in range(QB // 4):
                grp = r0 // 4 + gi
                P.emit(f"{base}.h{h}.b{b}.mg{gi}", OP_REQUANT, R["AVO"] + gi * 4 * HD * 4,
                       R["MRG"] + (grp * D + h * HD) * 4, m=4, n=HD, k_or_length=4 * HD,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        if h == 0 and li == 0 and check == "debug":
            P.checkpoint_packed_a_rows(idx, R["K8"], I.pack_a(tr["k8"]), HD, T)
    P.dma(f"{base}.wo", R["WO"]); P.dma(f"{base}.bo", R["BO"])
    for b in range(TP // QB):
        r0 = b * QB
        if gemm_acc:            # X rows = sat32(X + attention output) in the GEMM epilogue
            idx = P.emit(f"{base}.wo.b{b}", OP_GEMM, R["MRG"] + (r0 // 4) * D * 4,
                         R["X"] + r0 * D * 4, src1=R["WO"], bias=R["BO"],
                         flags=FLAG_BIAS | FLAG_GEMM_ACC, m=QB, n=D, k_or_length=D // 4,
                         shift=ql.sh_o, aux0=1)
            continue
        P.emit(f"{base}.wo.b{b}", OP_GEMM, R["MRG"] + (r0 // 4) * D * 4, R["SC"], src1=R["WO"],
               bias=R["BO"], flags=FLAG_BIAS, m=QB, n=D, k_or_length=D // 4, shift=ql.sh_o, aux0=1)
        idx = P.emit(f"{base}.res1.b{b}", OP_RESIDUAL, R["X"] + r0 * D * 4, R["X"] + r0 * D * 4,
                     src1=R["SC"], k_or_length=QB * D, aux0=1)
    if check == "debug" or li == 0:
        P.checkpoint_rows(idx, R["X"], tr["x1"], D, T)
    for nm, reg in (("ln2g", "LN_G"), ("ln2b", "LN_B")):
        P.dma(f"{base}.{nm}", R[reg])
    layernorm(R["XP"])
    P.dma(f"{base}.lut", R["LUT"]); P.dma(f"{base}.b1", R["B1"]); P.dma(f"{base}.b2", R["B2"])
    r0 = 0
    while r0 < TP:
        m = min(FB, TP - r0)
        P.dma(f"{base}.w1", R["W"])
        P.emit(f"{base}.fc1.r{r0}", OP_GEMM, R["XP"] + (r0 // 4) * D * 4, R["H1"], src1=R["W"],
               bias=R["B1"], flags=FLAG_BIAS, m=m, n=FF, k_or_length=D // 4, shift=0, aux0=1)
        P.emit(f"{base}.gelu.r{r0}", OP_GELU, R["H1"], R["H8"], src1=R["LUT"], m=m, n=FF,
               k_or_length=m * FF, flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A | FLAG7,
               shift=ql.sh_l, aux0=1)
        P.dma(f"{base}.w2", R["W"])
        if gemm_acc:
            idx = P.emit(f"{base}.fc2.r{r0}", OP_GEMM, R["H8"], R["X"] + r0 * D * 4, src1=R["W"],
                         bias=R["B2"], flags=FLAG_BIAS | FLAG_GEMM_ACC, m=m, n=D,
                         k_or_length=FF // 4, shift=ql.sh_2, aux0=1)
        else:
            P.emit(f"{base}.fc2.r{r0}", OP_GEMM, R["H8"], R["Y"], src1=R["W"], bias=R["B2"],
                   flags=FLAG_BIAS, m=m, n=D, k_or_length=FF // 4, shift=ql.sh_2, aux0=1)
            idx = P.emit(f"{base}.res2.r{r0}", OP_RESIDUAL, R["X"] + r0 * D * 4,
                         R["X"] + r0 * D * 4, src1=R["Y"], k_or_length=m * D, aux0=1)
        r0 += m
    P.checkpoint_rows(idx, R["X"], out, D, T)
    return out


def allocate(P: Program) -> dict:
    R = {}
    R["X"] = P.alloc("X", TP * D * 4)
    R["XP"] = P.alloc("XP", TP * D)
    R["LNT"] = P.alloc("LNT", 4 * D * 4)
    R["PR"] = P.alloc("PR", QB * TP * 4)
    for nm, sz in (("LN_G", D * 4), ("LN_B", D * 4), ("BVR", TP * 4), ("BSR", TP * 4),
                   ("BAR", HD * 4), ("BQ", HD * 4), ("BK", HD * 4), ("BO", D * 4),
                   ("B1", FF * 4), ("B2", D * 4), ("LUT", 256)):
        R[nm] = P.alloc(nm, sz)
    u0 = P.next_addr
    # attention phase
    for nm, sz in (("WQ", D * HD), ("WK", D * HD), ("WVT", D * HD), ("WO", D * D),
                   ("Q8", TP * HD), ("K8", TP * HD), ("VT8", TP * HD), ("PROJ", TP * HD * 4),
                   ("SC", QB * max(TP, D) * 4), ("P8", QB * TP), ("AVO", QB * HD * 4),
                   ("MRG", TP * D)):
        R[nm] = P.alloc(nm, sz)
    attn_end = P.next_addr
    P.next_addr = u0
    # FFN phase (reuses the attention scratch)
    for nm, sz in (("W", D * FF), ("H1", FB * FF * 4), ("H8", FB * FF), ("Y", FB * D * 4)):
        R[nm] = P.alloc(nm, sz)
    P.next_addr = max(P.next_addr, attn_end)
    return R


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", type=Path, required=True)
    ap.add_argument("--val-dir", type=Path, required=True)
    ap.add_argument("--layers", type=int, default=1)
    ap.add_argument("--calib", type=int, default=20)
    ap.add_argument("--image-index", type=int, default=0)
    ap.add_argument("--accuracy", type=int, default=0, help="images per class for integer accuracy")
    ap.add_argument("--no-gemm-acc", action="store_true",
                    help="legacy residual adds: GEMM to SC/Y + RESIDUAL (no 0x30 flags[7])")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--check", default="layer", choices=("layer", "debug"))
    ap.add_argument("--overlap", action="store_true",
                    help="program format v3: CMDQ DMA (0x60) overlapped with compute")
    ap.add_argument("--hoist", type=int, default=48,
                    help="max descriptors a DMA load may be moved ahead (--overlap)")
    a = ap.parse_args()
    from deit_contract_study import IMAGENETTE_TO_IMAGENET, load_image
    sd = torch.load(a.checkpoint, map_location="cpu", weights_only=True)
    fm = FloatDeit(sd)
    classes = sorted(IMAGENETTE_TO_IMAGENET.items())
    files = {w: sorted((a.val_dir / w).glob("*.JPEG")) for w, _ in classes}
    calib = [load_image(f) for w, _ in classes for f in files[w][-max(1, a.calib // 10):]]
    obs = [dict() for _ in range(12)]
    with torch.no_grad():
        for img in calib:
            x = fm.embed(img)
            for i in range(12):
                x = fm.layer(i, x, obs[i])
    qls = [QuantLayer(fm, i, obs[i]) for i in range(12)]

    result = {"model": "facebook/deit-tiny-patch16-224", "layers_on_npu": a.layers,
              "f_res": F_RES, "ln_round_bits": LN_RB,
              "shifts": [{k: getattr(q, k) for k in ("sh_q", "sh_k", "sh_v", "sh_s", "sh_a",
                                                      "sh_o", "sh_l", "sh_2")} for q in qls]}
    if a.accuracy:
        correct_i = correct_f = n = 0
        for w, idx in classes:
            for f in files[w][:a.accuracy]:
                img = load_image(f)
                x = quant_embed(fm, img)
                xf = fm.embed(img)
                for i in range(12):
                    x = qls[i].forward(x)
                    xf = fm.layer(i, xf)
                correct_i += int(np.argmax(head_logits(fm, x)) == idx)
                correct_f += int(fm.head(xf).argmax().item() == idx)
                n += 1
        result.update(accuracy_images=n, int_top1=correct_i / n, fp32_top1=correct_f / n)
        print(f"DEIT_INT_ACCURACY images={n} int_top1={100*correct_i/n:.2f}% fp32_top1={100*correct_f/n:.2f}%")

    P = Program(overlap=a.overlap, hoist=a.hoist)
    R = allocate(P)
    P.ddr_put("zeros_pr", np.zeros(QB * TP, np.int64))
    w0, idx0 = classes[a.image_index % 10]
    img = load_image(files[w0][a.image_index // 10])
    x = quant_embed(fm, img)
    P.ddr_put("x0", I.words_i32(x))
    P.dma("x0", R["X"])
    for li in range(a.layers):
        x = emit_layer(P, qls[li], li, R, x, a.check, gemm_acc=not a.no_gemm_acc)
    P.final_rows(R["X"], I.words_i32(x), D, T)
    if a.layers == 12:
        result["npu_program_top1_label"] = int(np.argmax(head_logits(fm, x)))
        result["label"] = idx0
    result.update(overlap=a.overlap, hoist=a.hoist if a.overlap else 0, gemm_acc=not a.no_gemm_acc)
    man = P.write(a.out, result)
    print("DEIT_PROGRAM_READY " + json.dumps({k: man.get(k) for k in (
        "descriptors", "segments", "dma_events", "dma_bytes", "spad_high_water",
        "checkpoint_words", "final_words", "ddr_bytes", "queued_dma", "hoisted_dma",
        "event_bits_peak", "dependency_waits")}))


if __name__ == "__main__":
    main()
