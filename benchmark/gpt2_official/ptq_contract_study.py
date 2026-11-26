#!/usr/bin/env python3
"""Official GPT-2 / distilgpt2 quantization study against the NMAForge contract.

The model forward is written out explicitly (validated against Hugging Face
at FP32) so every NMAForge numeric contract can be switched in independently:

  w8      INT8 weights: per-channel float scale ("pc") or power-of-two scale
          per 16-output-channel group ("g16p2", what the existing per-tile
          GEMM descriptors + REQUANT shift can express)
  a8      static per-tensor INT8 activations on every GEMM input
          (float scale "f" or power-of-two "p2"), calibrated on held-out text
  res     residual stream held on a Q.RES_FRAC fixed-point INT32 grid
  ln      LayerNorm via the bit-exact ai_tensor_sfu LAYERNORM_Q15 contract
          (integer mean/variance/isqrt/2^30 reciprocal); output requantized
          into the next GEMM's INT8 input scale through gamma/beta encoding
  sm      Softmax via the exp2 PWL Q15 contract on Q8.8 log2-domain scores;
          probabilities fed to AV as Q7 (">>8", current H64 mapping) or Q15
  gelu    GELU via the SFU Q8.8 piecewise contract, or a 256-entry INT8 LUT
          (co-design alternative)
  smooth  SmoothQuant alpha: per-input-channel factors migrate activation
          outliers into weights.  For c_attn/c_fc they fold into the LN
          gamma/beta encoding, for attention c_proj into the V columns, so the
          existing hardware contract is unchanged (zero hardware cost).

Outputs perplexity on WikiText-2 test (non-overlapping windows).
"""

from __future__ import annotations

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

torch.set_grad_enabled(False)
LOG2E = 1.4426950408889634


# ---------------------------------------------------------------- contracts
def exp2_pwl_q15(delta: torch.Tensor) -> torch.Tensor:
    """Vectorized ai_a3_reference.exp2_pwl_q15 / RTL exp2_q15 (int64)."""
    m = (-delta).clamp(min=0)
    ip = m >> 8
    fr = m & 255
    base = torch.where(ip >= 15, torch.zeros_like(ip), torch.tensor(32768) >> ip.clamp(max=15))
    nxt = base >> 1
    out = base - (((base - nxt) * fr) >> 8)
    out = torch.where(ip >= 15, torch.zeros_like(out), out)
    return torch.where(delta >= 0, torch.full_like(out, 32768), out)


def isqrt_t(v: torch.Tensor) -> torch.Tensor:
    r = torch.sqrt(v.to(torch.float64)).floor().to(torch.int64)
    r = torch.where(r * r > v, r - 1, r)
    r = torch.where((r + 1) * (r + 1) <= v, r + 1, r)
    return r


LN_STATS = {"elements": 0, "saturated": 0}


def layernorm_norm_first_t(x, gamma_q15, beta, eps=1):
    """Candidate contract: z = (x-mean)*2^30/std first (Q15 z), then gamma.

    Avoids the post-gamma INT32 saturation of the current contract when the
    input variance is large; intermediates fit in int64 for |x| < 2^31.
    """
    n = x.shape[-1]
    mean = torch.div(x.sum(-1, keepdim=True), n, rounding_mode="trunc")
    d = x - mean
    var = torch.div((d * d).sum(-1, keepdim=True), n, rounding_mode="floor")
    root = isqrt_t(var + eps).clamp(min=1)
    z_q15 = torch.div(d << 15, root, rounding_mode="floor")      # z in Q15
    out = (z_q15 * gamma_q15) >> 30                              # gamma in Q15 of s_out
    return (out + beta).clamp(-(1 << 31), (1 << 31) - 1)


def layernorm_q15_t(x: torch.Tensor, gamma_q15: torch.Tensor, beta: torch.Tensor,
                    eps: int = 1) -> torch.Tensor:
    """Bit-exact LAYERNORM_Q15 over the last dim of an int64 tensor."""
    n = x.shape[-1]
    s = x.sum(-1, keepdim=True)
    mean = torch.div(s, n, rounding_mode="trunc")
    d = x - mean
    var = torch.div((d * d).sum(-1, keepdim=True), n, rounding_mode="floor")
    root = isqrt_t(var + eps).clamp(min=1)
    recip = torch.div(torch.full_like(root, 1 << 30), root, rounding_mode="floor")
    i32min, i32max = -(1 << 31), (1 << 31) - 1
    raw = (d * gamma_q15) >> 15
    LN_STATS["elements"] += raw.numel()
    LN_STATS["saturated"] += int(((raw < i32min) | (raw > i32max)).sum())
    scaled = raw.clamp(i32min, i32max)
    norm = (scaled * recip) >> 30
    return (norm + beta).clamp(i32min, i32max)


def gelu_q8_8_t(q: torch.Tensor) -> torch.Tensor:
    mid = (q * (q + 512)) >> 10
    return torch.where(q <= -512, torch.zeros_like(q), torch.where(q >= 512, q, mid))


def gelu_new(x):
    return 0.5 * x * (1.0 + torch.tanh(math.sqrt(2.0 / math.pi) * (x + 0.044715 * x ** 3)))


def pow2_scale(scale: torch.Tensor) -> torch.Tensor:
    """Smallest power of two >= scale (no clipping beyond the float scale)."""
    return torch.pow(2.0, torch.ceil(torch.log2(scale)))


# ---------------------------------------------------------------- model
class Gpt2Int:
    def __init__(self, sd: dict, n_layer: int, n_head: int, cfg: dict):
        self.sd = {k: v.float().clone() for k, v in sd.items()}  # smoothing edits in place
        self.L, self.H, self.cfg = n_layer, n_head, cfg
        self.D = self.sd["wte.weight"].shape[1]
        self.act_absmax: dict[str, float] = {}
        self.chan_absmax: dict[str, torch.Tensor] = {}
        self.calibrating = False
        self.qw: dict[str, tuple[torch.Tensor, torch.Tensor]] = {}

    def apply_smoothing(self, alpha: float):
        """Fold SmoothQuant factors into LN gamma/beta, V columns and weights."""
        for i in range(self.L):
            for ln, lin in ((f"h.{i}.ln_1", f"h.{i}.attn.c_attn"), (f"h.{i}.ln_2", f"h.{i}.mlp.c_fc")):
                xa = self.chan_absmax[lin + ".in"].clamp(min=1e-5)
                wa = self.sd[lin + ".weight"].abs().amax(1).clamp(min=1e-5)
                sj = (xa ** alpha / wa ** (1 - alpha)).clamp(min=1e-2, max=1e2)
                self.sd[ln + ".weight"] /= sj
                self.sd[ln + ".bias"] /= sj
                self.sd[lin + ".weight"] *= sj[:, None]
            # attention output channels: scale V columns, compensate c_proj rows
            p = f"h.{i}.attn"
            xa = self.chan_absmax[p + ".c_proj.in"].clamp(min=1e-5)
            wa = self.sd[p + ".c_proj.weight"].abs().amax(1).clamp(min=1e-5)
            sj = (xa ** alpha / wa ** (1 - alpha)).clamp(min=1e-2, max=1e2)
            self.sd[p + ".c_attn.weight"][:, 2 * self.D:] /= sj[None, :]
            self.sd[p + ".c_attn.bias"][2 * self.D:] /= sj
            self.sd[p + ".c_proj.weight"] *= sj[:, None]

    def build_weights(self):
        if self.cfg["w8"]:
            for k, w in self.sd.items():
                if k.endswith(("attn.c_attn.weight", "attn.c_proj.weight",
                               "mlp.c_fc.weight", "mlp.c_proj.weight")):
                    self.qw[k] = self.quant_weight(w)  # Conv1D: [in, out]

    def quant_weight(self, w: torch.Tensor):
        mode = self.cfg["w8"]
        if mode == "pc":
            s = w.abs().amax(0, keepdim=True) / 127.0
        else:  # g16p2: power-of-two scale per 16 output channels
            g = w.abs().reshape(w.shape[0], -1, 16).amax((0, 2)) / 127.0
            s = pow2_scale(g).repeat_interleave(16)[None, :]
        s = s.clamp(min=1e-12)
        return torch.clamp(torch.round(w / s), -127, 127), s

    def act_scale(self, name: str) -> float | torch.Tensor:
        s = max(self.act_absmax[name], 1e-8) / 127.0
        return float(pow2_scale(torch.tensor(s))) if self.cfg["a8"] == "p2" else s

    def observe(self, name: str, x: torch.Tensor):
        if self.calibrating:
            if name.endswith(".in"):
                c = x.reshape(-1, x.shape[-1]).abs().amax(0)
                self.chan_absmax[name] = torch.maximum(self.chan_absmax.get(name, c), c)
            # 99.99th percentile of |x| is robust to single outliers.
            v = torch.quantile(x.abs().flatten()[:2_000_000].float(), 0.9999).item()
            self.act_absmax[name] = max(self.act_absmax.get(name, 0.0), v)

    def qact(self, name: str, x: torch.Tensor) -> torch.Tensor:
        self.observe(name, x)
        if not self.cfg["a8"] or self.calibrating:
            return x
        s = self.act_scale(name)
        return torch.clamp(torch.round(x / s), -128, 127) * s

    def linear(self, name: str, x: torch.Tensor, prefix: str) -> torch.Tensor:
        b = self.sd[prefix + ".bias"]
        key = prefix + ".weight"
        if self.cfg["w8"] and key in self.qw and not self.calibrating:
            wq, s = self.qw[key]
            return x @ (wq * s) + b
        return x @ self.sd[key] + b

    def res_round(self, x):
        if self.cfg["res"] and not self.calibrating:
            f = 2.0 ** self.cfg["res_frac"]
            return torch.round(x * f) / f
        return x

    def layernorm(self, name: str, x: torch.Tensor, prefix: str, out_name: str):
        g, b = self.sd[prefix + ".weight"], self.sd[prefix + ".bias"]
        if not self.cfg["ln"] or self.calibrating:
            y = torch.nn.functional.layer_norm(x, (self.D,), g, b, 1e-5)
            return y
        # Residual stream on the Q.res_frac integer grid; output encoded so the
        # SFU result is directly the next GEMM's INT8 code (scale s_out).
        f = 2.0 ** self.cfg["res_frac"]
        xi = torch.round(x * f).to(torch.int64)
        s_out = self.act_scale(out_name) if self.cfg["a8"] else 1.0 / 64.0
        # Rounding-offset encoding: produce the LN result at 2^rb finer scale
        # with +2^(rb-1) folded into beta, then the existing REQUANT/pack
        # arithmetic shift by rb yields round-to-nearest instead of floor.
        rb = self.cfg.get("ln_round_bits", 0)
        gq = torch.round(g * 32768.0 * (1 << rb) / s_out).to(torch.int64)
        bq = torch.round(b * (1 << rb) / s_out).to(torch.int64) + ((1 << rb) >> 1)
        eps = max(1, int(round(1e-5 * f * f)))
        if self.cfg["ln"] == "normfirst":
            yi = layernorm_norm_first_t(xi, gq, bq, eps)
        else:
            yi = layernorm_q15_t(xi, gq, bq, eps)
        yi = yi >> rb
        if self.cfg["a8"]:
            yi = yi.clamp(-128, 127)
        return yi.to(torch.float32) * s_out

    def attention(self, i: int, x: torch.Tensor) -> torch.Tensor:
        T = x.shape[0]
        p = f"h.{i}.attn"
        qkv = self.linear("c_attn", self.qact(f"{p}.c_attn.in", x), p + ".c_attn")
        q, k, v = qkv.split(self.D, dim=-1)
        hd = self.D // self.H
        q = q.view(T, self.H, hd).transpose(0, 1)
        k = k.view(T, self.H, hd).transpose(0, 1)
        v = v.view(T, self.H, hd).transpose(0, 1)
        q = self.qact(f"{p}.q", q)
        k = self.qact(f"{p}.k", k)
        v = self.qact(f"{p}.v", v)
        att = (q @ k.transpose(-1, -2)) / math.sqrt(hd)
        mask = torch.ones(T, T, dtype=torch.bool).tril()
        if self.cfg["sm"] and not self.calibrating:
            s88 = torch.round(att * LOG2E * 256.0).to(torch.int64)
            s88 = torch.where(mask, s88, torch.full_like(s88, -(1 << 40)))
            mx = s88.amax(-1, keepdim=True)
            e = exp2_pwl_q15(s88 - mx)
            e = torch.where(mask, e, torch.zeros_like(e))
            q15 = torch.div(e << 15, e.sum(-1, keepdim=True), rounding_mode="floor").clamp(0, 32768)
            if self.cfg["sm"] == "q7":
                probs = (q15 >> 8).clamp(0, 127).to(torch.float32) / 128.0
            elif self.cfg["sm"] == "q7r":     # rounding offset via REQUANT bias
                probs = ((q15 + 128) >> 8).clamp(0, 127).to(torch.float32) / 128.0
            elif self.cfg["sm"] == "u8r":     # unsigned Q8 operand (u8 x s8 MAC)
                probs = ((q15 + 64) >> 7).clamp(0, 255).to(torch.float32) / 256.0
            else:
                probs = q15.to(torch.float32) / 32768.0
        else:
            att = att.masked_fill(~mask, float("-inf"))
            probs = torch.softmax(att, dim=-1)
        y = (probs @ v).transpose(0, 1).reshape(T, self.D)
        return self.linear("c_proj", self.qact(f"{p}.c_proj.in", y), p + ".c_proj")

    def mlp(self, i: int, x: torch.Tensor) -> torch.Tensor:
        p = f"h.{i}.mlp"
        h = self.linear("c_fc", self.qact(f"{p}.c_fc.in", x), p + ".c_fc")
        if self.cfg["gelu"] == "pwl" and not self.calibrating:
            qh = torch.round(h * 256.0).clamp(-(1 << 31), (1 << 31) - 1).to(torch.int64)
            h = gelu_q8_8_t(qh).to(torch.float32) / 256.0
        elif self.cfg["gelu"] == "lut8" and not self.calibrating:
            # INT8 input code -> exact GELU -> INT8 output code (256-entry LUT).
            s_in = max(self.act_absmax.get(f"{p}.fc_out", 1.0), 1e-8) / 127.0
            codes = torch.clamp(torch.round(h / s_in), -128, 127)
            h = gelu_new(codes * s_in)
        else:
            self.observe(f"{p}.fc_out", h)
            h = gelu_new(h)
        return self.linear("c_proj", self.qact(f"{p}.c_proj.in", h), p + ".c_proj")

    def forward(self, ids: torch.Tensor) -> torch.Tensor:
        T = ids.shape[0]
        x = self.sd["wte.weight"][ids] + self.sd["wpe.weight"][:T]
        x = self.res_round(x)
        for i in range(self.L):
            a = self.layernorm("ln1", x, f"h.{i}.ln_1", f"h.{i}.attn.c_attn.in")
            x = self.res_round(x + self.attention(i, a))
            m = self.layernorm("ln2", x, f"h.{i}.ln_2", f"h.{i}.mlp.c_fc.in")
            x = self.res_round(x + self.mlp(i, m))
        x = torch.nn.functional.layer_norm(x, (self.D,), self.sd["ln_f.weight"],
                                           self.sd["ln_f.bias"], 1e-5)
        return x @ self.sd["wte.weight"].T


def load(model_dir: Path):
    from safetensors.numpy import load_file
    raw = load_file(str(model_dir / "model.safetensors"))
    sd = {k.removeprefix("transformer."): torch.from_numpy(v.copy()) for k, v in raw.items()}
    cfg = json.loads((model_dir / "config.json").read_text())
    return sd, cfg["n_layer"], cfg["n_head"]


def windows(tokens: np.ndarray, ctx: int, n: int, start: int = 0):
    out = []
    for w in range(n):
        a = start + w * ctx
        if a + ctx + 1 > len(tokens):
            break
        out.append(torch.from_numpy(tokens[a:a + ctx + 1].astype(np.int64)))
    return out


def ppl(model: Gpt2Int, wins) -> float:
    nll, cnt = 0.0, 0
    for w in wins:
        logits = model.forward(w[:-1])
        nll += torch.nn.functional.cross_entropy(logits, w[1:], reduction="sum").item()
        cnt += w.numel() - 1
    return math.exp(nll / cnt)


CONFIGS = {
    "fp32":            dict(w8=None, a8=None, res=False, ln=False, sm=None, gelu=None),
    "w8a8_float":      dict(w8="pc", a8="f", res=False, ln=False, sm=None, gelu=None),
    "w8a8_pow2":       dict(w8="g16p2", a8="p2", res=False, ln=False, sm=None, gelu=None),
    "+res_ln_int":     dict(w8="g16p2", a8="p2", res=True, ln=True, sm=None, gelu=None),
    "+softmax_q7":     dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7", gelu=None),
    "+softmax_q15":    dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu=None),
    "full_contract_q7_pwl": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7", gelu="pwl"),
    "q15_pwlgelu":     dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="pwl"),
    "q15_lut8gelu":    dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="lut8"),
    "+res_only":       dict(w8="g16p2", a8="p2", res=True, ln=False, sm=None, gelu=None),
    "+ln_normfirst":   dict(w8="g16p2", a8="p2", res=True, ln="normfirst", sm=None, gelu=None),
    "nf_q15_lut8":     dict(w8="g16p2", a8="p2", res=True, ln="normfirst", sm="q15", gelu="lut8"),
    "nf_smooth_q15_lut8": dict(w8="g16p2", a8="p2", res=True, ln="normfirst", sm="q15", gelu="lut8", smooth=0.5),
    "nf_smooth_epilogue_q15_lut8": dict(w8="pc", a8="f", res=True, ln="normfirst", sm="q15", gelu="lut8", smooth=0.5),
    "ln_rnd":          dict(w8="g16p2", a8="p2", res=True, ln=True, sm=None, gelu=None, ln_round_bits=4),
    "ln_rnd_q7":       dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7", gelu=None, ln_round_bits=4),
    "ln_rnd_q15":      dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu=None, ln_round_bits=4),
    "ln_rnd_q15_pwl":  dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="pwl", ln_round_bits=4),
    "ln_rnd_q15_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="lut8", ln_round_bits=4),
    "ln_rnd_smooth_q15_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="lut8", ln_round_bits=4, smooth=0.5),
    "ln_rnd_smooth_epi_q15_lut8": dict(w8="pc", a8="f", res=True, ln=True, sm="q15", gelu="lut8", ln_round_bits=4, smooth=0.5),
    "ln_rnd_q7r":      dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7r", gelu=None, ln_round_bits=4),
    "ln_rnd_u8r":      dict(w8="g16p2", a8="p2", res=True, ln=True, sm="u8r", gelu=None, ln_round_bits=4),
    "ln_rnd_u8r_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="u8r", gelu="lut8", ln_round_bits=4),
    "ln_rnd_smooth_u8r_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="u8r", gelu="lut8", ln_round_bits=4, smooth=0.5),
    "ln_rnd_smooth_epi_u8r_lut8": dict(w8="pc", a8="f", res=True, ln=True, sm="u8r", gelu="lut8", ln_round_bits=4, smooth=0.5),
    "smooth_w8a8_pow2": dict(w8="g16p2", a8="p2", res=False, ln=False, sm=None, gelu=None, smooth=0.5),
    "smooth_q15_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="lut8", smooth=0.5),
    "smooth_epilogue_q15_lut8": dict(w8="pc", a8="f", res=True, ln=True, sm="q15", gelu="lut8", smooth=0.5),
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", type=Path, required=True)
    ap.add_argument("--wikitext", type=Path, required=True)
    ap.add_argument("--ctx", type=int, default=256)
    ap.add_argument("--windows", type=int, default=60)
    ap.add_argument("--calib-windows", type=int, default=8)
    ap.add_argument("--res-frac", type=int, default=8)
    ap.add_argument("--configs", default=",".join(CONFIGS))
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    import pyarrow.parquet as pq
    from transformers import GPT2TokenizerFast, GPT2LMHeadModel
    text = "\n\n".join(pq.read_table(args.wikitext).column("text").to_pylist())
    tok = GPT2TokenizerFast.from_pretrained(str(args.model_dir))
    tokens = np.array(tok(text)["input_ids"], dtype=np.int64)
    sd, n_layer, n_head = load(args.model_dir)
    # Held-out calibration text: the tail of the test split, disjoint from eval.
    calib = windows(tokens, args.ctx, args.calib_windows,
                    start=len(tokens) - (args.calib_windows + 1) * (args.ctx + 1))
    evalw = windows(tokens, args.ctx, args.windows)

    # FP32 forward must match the reference implementation.
    hf = GPT2LMHeadModel.from_pretrained(str(args.model_dir)).eval()
    ref = Gpt2Int(sd, n_layer, n_head, dict(CONFIGS["fp32"], res_frac=args.res_frac))
    diff = (hf(evalw[0][:-1][None]).logits[0] - ref.forward(evalw[0][:-1])).abs().max().item()
    if diff > 1e-3:
        raise SystemExit(f"explicit forward differs from Hugging Face: {diff}")

    results = {"model": args.model_dir.name, "ctx": args.ctx, "eval_windows": len(evalw),
               "eval_tokens": len(evalw) * args.ctx, "calib_windows": len(calib),
               "res_frac": args.res_frac, "hf_fp32_max_logit_diff": diff, "configs": {}}
    for name in args.configs.split(","):
        t0 = time.time()
        cfg = dict(CONFIGS[name], res_frac=args.res_frac)
        m = Gpt2Int(sd, n_layer, n_head, cfg)
        m.calibrating = True
        for w in calib:
            m.forward(w[:-1])
        if cfg.get("smooth"):
            m.apply_smoothing(cfg["smooth"])
            m.act_absmax.clear(); m.chan_absmax.clear()
            for w in calib:
                m.forward(w[:-1])
        m.calibrating = False
        m.build_weights()
        p = ppl(m, evalw)
        sat = LN_STATS["saturated"] / max(LN_STATS["elements"], 1)
        LN_STATS["saturated"] = LN_STATS["elements"] = 0
        results["configs"][name] = {"ppl": p, **CONFIGS[name], "ln_post_gamma_saturation": sat,
                                    "seconds": round(time.time() - t0, 1)}
        print(f"PTQ_RESULT model={args.model_dir.parent.parent.name} config={name} ppl={p:.3f} "
              f"ln_sat={sat:.5f} "
              f"seconds={time.time() - t0:.0f}", flush=True)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
