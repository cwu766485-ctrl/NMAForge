#!/usr/bin/env python3
"""Layerwise diagnosis of the frozen Round 20 H64 INT8 contract.

This is an analysis script only: it does not change the product reference,
exported model, or RTL. It reports saturation at every INT8 boundary and
paired FP32/INT32 trace error for a fixed held-out sample set.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from product_integer_reference import infer as int_infer, gemm, layernorm, gelu_q8_8  # noqa: E402
from train_h64_byte_lm import H64ByteDecoder, CONTEXT  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stats(x: np.ndarray) -> dict:
    a = np.asarray(x, dtype=np.float64).reshape(-1)
    return {"count": int(a.size), "min": float(a.min()), "max": float(a.max()),
            "mean_abs": float(np.mean(np.abs(a))),
            "rms": float(np.sqrt(np.mean(a * a))),
            "sat_i8_ratio": float(np.mean((a <= -128) | (a >= 127)))}


def pair_stats(ref: np.ndarray, got: np.ndarray) -> dict:
    a = np.asarray(ref, dtype=np.float64).reshape(-1)
    b = np.asarray(got, dtype=np.float64).reshape(-1)
    if a.shape != b.shape:
        return {"shape_mismatch": [list(np.shape(ref)), list(np.shape(got))]}
    # Use documented contract scales when possible. A fitted positive scale is
    # diagnostic only and is reported separately; it is not a new Golden.
    scale = float(np.dot(a, b) / max(np.dot(b, b), 1e-30))
    err = a - b
    fit_err = a - scale * b
    return {"reference": stats(a), "integer_raw": stats(b),
            "mae_same_domain": float(np.mean(np.abs(err))),
            "rmse_same_domain": float(np.sqrt(np.mean(err * err))),
            "best_fit_scale_integer_to_reference_diagnostic_only": scale,
            "mae_after_fit_diagnostic_only": float(np.mean(np.abs(fit_err))),
            "rmse_after_fit_diagnostic_only": float(np.sqrt(np.mean(fit_err * fit_err)))}


def fp_trace(model: H64ByteDecoder, tokens: list[int]) -> dict[str, np.ndarray]:
    """Return named float stage tensors using the exact FP model block order."""
    x = (model.embedding(torch.tensor(tokens))[None, :, :] +
         model.position(torch.arange(len(tokens)))[None, :, :])
    tr: dict[str, np.ndarray] = {"embedding_position": x.detach().numpy()[0]}
    with torch.no_grad():
        for li, layer in enumerate(model.layers):
            p = f"l{li}."
            n1 = layer["ln1"](x)
            q = layer["q"](n1).view(1, len(tokens), 4, 16).transpose(1, 2)
            k = layer["k"](n1).view(1, len(tokens), 4, 16).transpose(1, 2)
            v = layer["v"](n1).view(1, len(tokens), 4, 16).transpose(1, 2)
            scores = q @ k.transpose(-1, -2) / 4.0
            mask = torch.triu(torch.ones(len(tokens), len(tokens), dtype=torch.bool), 1)
            probs = scores.masked_fill(mask[None, None], float("-inf")).softmax(-1)
            att = (probs @ v).transpose(1, 2).contiguous().view(1, len(tokens), 64)
            proj = layer["o"](att)
            r1 = x + proj
            n2 = layer["ln2"](r1)
            up = layer["up"](n2)
            gelu = F.gelu(up, approximate="tanh")
            down = layer["down"](gelu)
            r2 = r1 + down
            for name, val in (("ln1", n1), ("q", q.transpose(1, 2).reshape(1, len(tokens), 64)),
                              ("k", k.transpose(1, 2).reshape(1, len(tokens), 64)),
                              ("v", v.transpose(1, 2).reshape(1, len(tokens), 64)),
                              ("scores", scores), ("probabilities", probs),
                              ("attention", att), ("projection", proj),
                              ("residual1", r1), ("ln2", n2), ("up", up),
                              ("gelu", gelu), ("down", down), ("residual2", r2)):
                tr[p + name] = val.detach().numpy()[0]
            x = r2
        final = model.final_ln(x)
        logits = model.lm_head(final)
        tr["final_ln"] = final.detach().numpy()[0]
        tr["logits"] = logits.detach().numpy()[0]
    return tr


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261121)
    ap.add_argument("--windows", type=int, default=128)
    args = ap.parse_args()
    torch.set_num_threads(1)
    ckpt = torch.load(args.fp32, map_location="cpu", weights_only=False)
    fp = H64ByteDecoder().cpu().eval()
    fp.load_state_dict(ckpt["state_dict"])
    with np.load(args.package, allow_pickle=False) as f:
        q = {k: f[k] for k in f.files}
    raw = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()
    test = raw[int(len(raw) * 0.9):]
    lo, hi = int(len(test) * 0.05), len(test) - CONTEXT - 1
    rng = np.random.default_rng(args.seed)
    starts = rng.integers(lo, hi, size=args.windows)

    int_aggr: dict[str, list[np.ndarray]] = {}
    fp_aggr: dict[str, list[np.ndarray]] = {}
    saturation: dict[str, list[np.ndarray]] = {}
    first_bad: dict[str, float] = {}
    int_top1 = fp_top1 = agree = total = 0
    for start in starts:
        tokens = test[start:start + CONTEXT].astype(int).tolist()
        with torch.no_grad():
            fp_logits = fp(torch.tensor(tokens)[None, :]).numpy()[0]
        _, it = int_infer(q, tokens)
        ft = fp_trace(fp, tokens)
        for name, arr in it.items():
            int_aggr.setdefault(name, []).append(np.asarray(arr))
            if name in ft and ft[name].shape == np.asarray(arr).shape:
                fp_aggr.setdefault(name, []).append(ft[name])
        # Count actual signed INT8 boundaries in the frozen contract.
        boundaries = {"embedding_i8": np.clip(it["embedding_position"], -128, 127),
                      "l0_ln1_i8": np.clip(it["l0.ln1"], -128, 127)}
        for li in range(4):
            for name in ("q", "k", "v", "attention", "gelu", "final_ln"):
                key = (f"l{li}.{name}" if name != "final_ln" else "final_ln")
                if key in it:
                    boundaries[f"l{li}_{name}_i8"] = np.clip(it[key], -128, 127)
            if f"l{li}.ln2" in it:
                boundaries[f"l{li}_ln2_i8"] = np.clip(it[f"l{li}.ln2"], -128, 127)
            for name in ("q", "k", "v", "o", "up", "down"):
                wkey = f"l{li}.{name}"
                saturation.setdefault(f"weight_{wkey}_i8", []).append(q[wkey])
        for name, arr in boundaries.items():
            saturation.setdefault(name, []).append(np.asarray(arr))
        fp_top1 += int(np.argmax(fp_logits, axis=-1)[-1] == int(test[start + CONTEXT]))
        int_top1 += int(np.argmax(it["logits"], axis=-1)[-1] == int(test[start + CONTEXT]))
        agree += int(np.argmax(fp_logits, axis=-1)[-1] == np.argmax(it["logits"], axis=-1)[-1])
        total += 1

    sat_report = {}
    for name, arrays in saturation.items():
        a = np.concatenate([np.asarray(x).reshape(-1) for x in arrays]).astype(np.int64)
        if name.startswith("weight_"):
            sat_report[name] = {"count": int(a.size), "min": int(a.min()), "max": int(a.max()),
                                "at_i8_endpoint_ratio": float(np.mean((a == -128) | (a == 127)))}
        else:
            sat_report[name] = {"count": int(a.size), "at_i8_endpoint_ratio": float(np.mean((a == -128) | (a == 127))),
                                "clipped_input_ratio": float(np.mean((a <= -128) | (a >= 127)))}
    paired = {}
    for name, arrays in fp_aggr.items():
        paired[name] = pair_stats(np.concatenate([x.reshape(-1) for x in arrays]),
                                  np.concatenate([x.reshape(-1) for x in int_aggr[name]]))
    out = {"status": "ANALYSIS_ONLY_NO_GOLDEN_OR_RTL_CHANGE",
           "source_sha": "ac088cf06c5188a814dc7753033bafc249ad265d",
           "fp32_sha256": sha(args.fp32), "int8_package_sha256": sha(args.package),
           "corpus_sha256": sha(args.corpus), "evaluation": {"seed": args.seed,
           "windows": args.windows, "targets": total,
           "fp32_next_byte_accuracy": fp_top1 / total,
           "int8_product_ref_next_byte_accuracy": int_top1 / total,
           "fp32_vs_int8_top1_agreement": agree / total},
           "quantization_contract": {"embedding_position_scale": 8,
             "matrix_weight_scale": 32, "layernorm_gamma_scale": 32,
             "layernorm_beta_scale": 8, "matrix_post_shifts": {"qkv": 0,"o": 0,"up": 0,"down": 0,"qk": 2,"av": 7,"lm_head": 0}},
           "int8_boundary_saturation": sat_report,
           "fp32_vs_int_reference_trace": paired}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": out["status"], "evaluation": out["evaluation"],
                      "saturation": sat_report, "out": str(args.out)}, sort_keys=True))


if __name__ == "__main__":
    main()
