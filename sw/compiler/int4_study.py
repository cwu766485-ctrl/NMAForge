#!/usr/bin/env python3
"""INT4 weight-quantization study for GPT-2 small (fake quantization, FP32 math).

Answers which INT4 weight format keeps GPT-2 usable before any RTL is built.
Every Linear weight (c_attn, attn.c_proj, mlp.c_fc, mlp.c_proj) is replaced by
its quantize-dequantize image; activations stay FP32, so the numbers isolate
the weight-format error. Perplexity is measured on WikiText-2 test windows.

Formats (``--formats``):
  fp32                 reference
  i8_tensor            INT8, one power-of-two scale per tensor (current NPU format)
  i4_tensor            INT4, one power-of-two scale per tensor
  i4_chan              INT4, power-of-two scale per output channel
  i4_g<G>              INT4, power-of-two scale per group of G inputs (K) per channel
  i4_g<G>_fp           same groups, real-valued (non power-of-two) scale
  i4_hw                hardware INT4 stream: one power-of-two shift per 8(K) x 4(N)
                       block (two packed-B SPAD lines), shift range clamped to
                       [Emax-4, Emax] per tensor so the expanded value fits INT8

    python sw/compiler/int4_study.py --model-dir <gpt2 snapshot> --wikitext <parquet>
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import torch
from transformers import GPT2LMHeadModel, GPT2TokenizerFast


def qdq(w: torch.Tensor, bits: int, mode: str, group: int = 0, pow2: bool = True) -> torch.Tensor:
    """w is [K, N] (HF Conv1D layout: inputs x outputs)."""
    qmax = 2 ** (bits - 1) - 1
    K, N = w.shape
    if mode == "tensor":
        amax = w.abs().max().reshape(1, 1)
    elif mode == "chan":
        amax = w.abs().amax(0, keepdim=True)                      # per output channel
    else:                                                        # groups along K
        g = w.reshape(K // group, group, N)
        amax = g.abs().amax(1, keepdim=True)
    s = amax.clamp_min(1e-12) / qmax
    if pow2:
        s = 2.0 ** torch.ceil(torch.log2(s))
    if mode == "group":
        g = w.reshape(K // group, group, N)
        return (torch.clamp(torch.round(g / s), -qmax - 1, qmax) * s).reshape(K, N)
    return torch.clamp(torch.round(w / s), -qmax - 1, qmax) * s


def qdq_hw_cols(w: torch.Tensor, cols: int, levels: int, kb: int = 8) -> torch.Tensor:
    """qdq_hw applied per slice of `cols` output channels (the NPU quantizes
    and streams one head / FFN chunk per weight tile); levels=0: no clamp."""
    out = torch.empty_like(w)
    for c0 in range(0, w.shape[1], cols):
        out[:, c0:c0 + cols] = qdq_hw(w[:, c0:c0 + cols], levels, kb)
    return out


def qdq_hw(w: torch.Tensor, levels: int = 5, kb: int = 8) -> torch.Tensor:
    """INT4 with a power-of-two shift per 8x4 (K x N) block, expanded to INT8
    as w8 = w4 << sh, sh = e_blk - e_base in 0..4 (|w4 << 4| <= 128)."""
    K, N = w.shape
    b = w.reshape(K // kb, kb, N // 4, 4).permute(0, 2, 1, 3)     # [Kb, Nb, kb, 4]
    e = torch.ceil(torch.log2(b.abs().amax((2, 3), keepdim=True).clamp_min(1e-12) / 7))
    if levels:
        e = torch.clamp(e, min=float(e.max() - (levels - 1)))
    s = 2.0 ** e
    q = torch.clamp(torch.round(b / s), -8, 7) * s
    return q.permute(0, 2, 1, 3).reshape(K, N)


def apply_format(model, ref_state, fmt: str):
    model.load_state_dict(ref_state)
    if fmt == "fp32":
        return
    for name, p in model.named_parameters():
        if not name.endswith(".weight") or p.dim() != 2 or "wte" in name or "wpe" in name:
            continue
        w = p.data
        if fmt == "i8_tensor":
            q = qdq(w, 8, "tensor")
        elif fmt == "i4_tensor":
            q = qdq(w, 4, "tensor")
        elif fmt == "i4_chan":
            q = qdq(w, 4, "chan")
        elif fmt == "i4_hw":
            q = qdq_hw(w)
        elif fmt.startswith("i4_hw_c"):          # i4_hw_c<cols>_l<levels>[_k<kb>]
            parts = fmt[7:].split("_")
            cols, lv = int(parts[0]), int(parts[1][1:])
            kb = int(parts[2][1:]) if len(parts) > 2 else 8
            q = qdq_hw_cols(w, cols, lv, kb)
        elif fmt.startswith("i4_g"):
            body = fmt[4:]
            fp = body.endswith("_fp")
            G = int(body[:-3] if fp else body)
            q = qdq(w, 4, "group", G, pow2=not fp)
        else:
            raise ValueError(fmt)
        p.data.copy_(q)


@torch.no_grad()
def perplexity(model, ids: np.ndarray, ctx: int, windows: int) -> float:
    nll, cnt = 0.0, 0
    step = (len(ids) - ctx - 1) // windows
    for i in range(windows):
        x = torch.tensor(ids[i * step:i * step + ctx + 1])[None]
        out = model(x[:, :-1]).logits
        loss = torch.nn.functional.cross_entropy(out[0], x[0, 1:], reduction="sum")
        nll += float(loss); cnt += ctx
    return math.exp(nll / cnt)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--model-dir", type=Path, required=True)
    ap.add_argument("--wikitext", type=Path, required=True)
    ap.add_argument("--windows", type=int, default=40)
    ap.add_argument("--ctx", type=int, default=256)
    ap.add_argument("--formats", default="fp32,i8_tensor,i4_tensor,i4_chan,i4_g128,i4_g64,"
                                         "i4_g32,i4_g32_fp")
    ap.add_argument("--json", type=Path)
    a = ap.parse_args()
    torch.manual_seed(0)
    tok = GPT2TokenizerFast.from_pretrained(a.model_dir)
    text = "\n".join(pq.read_table(a.wikitext).column("text").to_pylist())
    ids = np.array(tok(text)["input_ids"])
    model = GPT2LMHeadModel.from_pretrained(a.model_dir).eval()
    ref = {k: v.clone() for k, v in model.state_dict().items()}
    res = {}
    for fmt in a.formats.split(","):
        apply_format(model, ref, fmt)
        res[fmt] = perplexity(model, ids, a.ctx, a.windows)
        print(f"INT4_STUDY fmt={fmt} ppl={res[fmt]:.3f}", flush=True)
    if a.json:
        a.json.write_text(json.dumps({"windows": a.windows, "ctx": a.ctx, "ppl": res}, indent=2))


if __name__ == "__main__":
    main()
