#!/usr/bin/env python3
"""Round 23 fixed-point error and calibration audit (software-only).

Calibration samples are drawn only from the first 90% of the pinned corpus.
Held-out scoring uses the same deterministic 1,024 next-byte targets as Round
22.  No package, Golden, or Product RTL behavior is modified by this tool.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch

from round21_contract_ablation import CONTRACTS, fp_trace, infer
from train_round23_product_qat import ProductQAT
from train_h64_byte_lm import CONTEXT, H64ByteDecoder


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


SCALES = {"embedding_position": 8, "final_ln": 1, "logits": 32}
for _li in range(4):
    _p = f"l{_li}."
    SCALES.update({_p + "ln1": 1, _p + "q": 32, _p + "k": 32,
                   _p + "v": 32, _p + "scores": 256,
                   _p + "probabilities_q15": 32768, _p + "attention": 32,
                   _p + "projection": 8, _p + "residual1": 8,
                   _p + "ln2": 1, _p + "up": 256, _p + "gelu": 256,
                   _p + "gelu_i8": 8, _p + "down": 8, _p + "residual2": 8})


def cosine(a: np.ndarray, b: np.ndarray) -> float:
    a, b = a.reshape(-1).astype(np.float64), b.reshape(-1).astype(np.float64)
    denom = float(np.linalg.norm(a) * np.linalg.norm(b))
    return float(np.dot(a, b) / denom) if denom else 1.0


def compare(ref: np.ndarray, got_i: np.ndarray, scale: float) -> dict:
    a = ref.reshape(-1).astype(np.float64)
    b = got_i.reshape(-1).astype(np.float64) / scale
    err = b - a
    return {"elements": int(a.size), "fp32_min": float(a.min()),
            "fp32_max": float(a.max()), "int_dequant_min": float(b.min()),
            "int_dequant_max": float(b.max()), "mae": float(np.mean(np.abs(err))),
            "rmse": float(np.sqrt(np.mean(err * err))), "cosine_similarity": cosine(a, b),
            "normalized_rmse": float(np.sqrt(np.mean(err * err)) /
                                      max(float(np.sqrt(np.mean(a * a))), 1e-12))}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261121)
    ap.add_argument("--heldout-targets", type=int, default=1024)
    ap.add_argument("--calibration-windows", type=int, default=256)
    args = ap.parse_args()

    torch.set_num_threads(1)
    corpus = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()
    split = int(len(corpus) * 0.9)
    train, heldout = corpus[:split], corpus[split:]
    ckpt = torch.load(args.fp32, map_location="cpu", weights_only=False)
    model = H64ByteDecoder().cpu().eval()
    model.load_state_dict(ckpt["state_dict"])
    fake_model = ProductQAT(model).eval()
    with np.load(args.package, allow_pickle=False) as archive:
        q = {name: archive[name].copy() for name in archive.files}
    # Product opcode 0x35 consumes signed Q8.8 up weights.
    for li in range(4):
        w = ckpt["state_dict"][f"layers.{li}.up.weight"].cpu().numpy().T
        q[f"l{li}.up_q8_8"] = np.clip(np.rint(w.astype(np.float64) * 256), -128, 127).astype(np.int8)

    # Calibration and evaluation use disjoint corpus regions and independent RNG streams.
    cal_rng = np.random.default_rng(args.seed ^ 0xCA11B)
    cal_starts = cal_rng.integers(0, split - CONTEXT - 1, size=args.calibration_windows)
    test_rng = np.random.default_rng(args.seed)
    lo = int(len(heldout) * 0.05)
    test_starts = test_rng.integers(lo, len(heldout) - CONTEXT - 1,
                                    size=args.heldout_targets)
    contract = CONTRACTS["residual_gelu_aligned"]

    calibration_values: dict[str, list[np.ndarray]] = {}
    for start in cal_starts:
        toks = train[start:start + CONTEXT].astype(int).tolist()
        trace = fp_trace(model, toks)
        for name, value in trace.items():
            calibration_values.setdefault(name, []).append(np.asarray(value, dtype=np.float64))

    cal_summary = {}
    for name, arrays in calibration_values.items():
        data = np.concatenate([a.reshape(-1) for a in arrays])
        current = float(SCALES.get(name, 1))
        abs_data = np.abs(data)
        p999 = float(np.quantile(abs_data, 0.999))
        is_i8_endpoint = name.endswith((".q", ".k", ".v", ".attention", ".gelu_i8"))
        calibrated = (min(current, 127.0 / max(p999, 1e-12))
                      if is_i8_endpoint else None)
        cal_summary[name] = {"samples": int(data.size), "min": float(data.min()),
                             "max": float(data.max()), "abs_p99_9": p999,
                             "current_physical_scale": current,
                             "i8_quantized_endpoint": is_i8_endpoint,
                             "int8_range_saturation_at_current_scale":
                                 (float(np.mean((data * current < -128) | (data * current > 127)))
                                  if is_i8_endpoint else None),
                             "diagnostic_int8_scale_for_p99_9": calibrated,
                             "applied_to_product": False}

    refs: dict[str, list[np.ndarray]] = {}
    ints: dict[str, list[np.ndarray]] = {}
    fake_traces: dict[str, list[np.ndarray]] = {}
    logits_fp, logits_i, targets = [], [], []
    saturation: dict[str, list[int]] = {}
    for start in test_starts:
        toks = heldout[start:start + CONTEXT].astype(int).tolist()
        ftrace = fp_trace(model, toks)
        ilog, itrace = infer(q, toks, contract)
        with torch.no_grad():
            _, qtrace = fake_model(torch.tensor([toks], dtype=torch.long), return_trace=True)
        for name, value in ftrace.items():
            refs.setdefault(name, []).append(np.asarray(value))
        for name, value in itrace.items():
            ints.setdefault(name, []).append(np.asarray(value))
        for name, value in qtrace.items():
            fake_traces.setdefault(name, []).append(value.cpu().numpy())
        logits_fp.append(ftrace["logits"][-1])
        logits_i.append(ilog[-1])
        targets.append(int(heldout[start + CONTEXT]))
        for li in range(4):
            p = f"l{li}."
            ln1_i8 = np.clip(itrace[p + "ln1"], -128, 127)
            ln2_i8 = np.clip(itrace[p + "ln2"], -128, 127)
            saturation.setdefault(p + "ln1_input", []).extend(
                np.count_nonzero((itrace[p + "ln1"] < -128) | (itrace[p + "ln1"] > 127), axis=-1).tolist())
            saturation.setdefault(p + "ln2_input", []).extend(
                np.count_nonzero((itrace[p + "ln2"] < -128) | (itrace[p + "ln2"] > 127), axis=-1).tolist())
            for layer_name in ("q", "k", "v", "attention", "gelu_i8"):
                val = itrace[p + layer_name]
                saturation.setdefault(p + layer_name, []).append(
                    int(np.count_nonzero((val == -128) | (val == 127))))
            del ln1_i8, ln2_i8

    trace_metrics = {}
    for name in ints:
        ref_name = name.replace(".probabilities_q15", ".probabilities")
        if ref_name not in refs:
            continue
        a = np.concatenate([x.reshape(-1) for x in refs[ref_name]])
        b = np.concatenate([x.reshape(-1) for x in ints[name]])
        trace_metrics[name] = compare(a, b, SCALES.get(name, 1))

    fake_quant_metrics = {}
    for name, arrays in fake_traces.items():
        int_name = name.replace(".probabilities", ".probabilities_q15")
        if int_name not in ints:
            continue
        fake_real = np.concatenate([x.reshape(-1) for x in arrays]).astype(np.float64)
        integer = np.concatenate([x.reshape(-1) for x in ints[int_name]]).astype(np.float64)
        fake_quant_metrics[name] = compare(fake_real, integer, SCALES.get(int_name, 1))

    z = np.asarray(logits_i, dtype=np.float64) / 32.0
    z -= z.max(axis=-1, keepdims=True)
    ce = np.log(np.exp(z).sum(axis=-1)) - z[np.arange(len(targets)), targets]
    fp_argmax = np.argmax(np.asarray(logits_fp), axis=-1)
    int_argmax = np.argmax(np.asarray(logits_i), axis=-1)
    train_counts = np.ones((256, 256), dtype=np.int64)
    np.add.at(train_counts, (train[:-1], train[1:]), 1)
    bigram = np.argmax(train_counts, axis=1)
    bigram_acc = float(np.mean(bigram[heldout[test_starts + CONTEXT - 1]] ==
                               heldout[test_starts + CONTEXT]))

    weight_sat = {}
    for name, value in q.items():
        a = np.asarray(value)
        if a.dtype == np.int8:
            weight_sat[name] = float(np.mean((a == -128) | (a == 127)))
    out = {
        "status": "SOFTWARE_DIAGNOSTIC_ONLY; PRODUCT_TOP_EVIDENCE_REMAINS_ROUND22",
        "model_sha256": hashlib.sha256(args.fp32.read_bytes()).hexdigest(),
        "package_sha256": sha(args.package), "corpus_sha256": sha(args.corpus),
        "quant_contract": {"profile": "round21_residual_gelu_aligned",
                           "embedding_position_q": "Q3, scale 8",
                           "projection_weights": "signed INT8 Q5, scale 32",
                           "up_weights": "signed INT8 Q8.8, scale 256",
                           "layernorm_gamma": "signed INT32 Q5",
                           "layernorm_beta_package": "signed INT32 Q3; Product package values divided by 8",
                           "qkv_output": "signed INT8 Q5, GEMM shift 0",
                           "attention_scores": "Q8.8 score, GEMM shift 2",
                           "softmax_probability": "unsigned Q15; AV operand is probability >> 8",
                           "residual": "signed INT32 Q3; O shift 7, down shift 5",
                           "gelu": "Product Q8.8 piecewise integer GELU; GELU-to-I8 shift 5",
                           "logits": "signed INT32 Q5; CE dequantizes logits by 32"},
        "calibration": {"split": "first 90% corpus only; no held-out bytes used",
                        "seed": args.seed ^ 0xCA11B, "windows": args.calibration_windows,
                        "tensors": cal_summary,
                        "limitation": "diagnostic PTQ ranges only; Product descriptors expose fixed per-op shifts, not independent activation/per-channel scales"},
        "heldout": {"split": "last 10% corpus, first 5% of heldout excluded as in Round 22",
                    "seed": args.seed, "targets": len(targets),
                    "accuracy": float(np.mean(int_argmax == targets)),
                    "cross_entropy_nats": float(np.mean(ce)), "perplexity": float(np.exp(np.mean(ce))),
                    "fp32_accuracy_same_targets": float(np.mean(fp_argmax == targets)),
                    "fp32_int8_top1_agreement": float(np.mean(fp_argmax == int_argmax)),
                    "bigram_accuracy_same_targets": bigram_acc},
        "tensor_error_fp32_physical_units": trace_metrics,
        "tensor_error_fake_quant_vs_integer_physical_units": fake_quant_metrics,
        "int8_endpoint_saturation_ratio": {
            k: float(sum(counts) / max(1, np.asarray(ints[k.replace("_input", "")]).size))
            for k, counts in saturation.items()},
        "weight_endpoint_saturation_ratio": weight_sat,
        "limitations": ["No Product Top run was generated by this diagnostic.",
                        "Per-channel scale recommendations are not applied; they are not representable by the current Product descriptor contract."]}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": out["status"], "heldout": out["heldout"],
                      "model_sha256": out["model_sha256"], "package_sha256": out["package_sha256"]},
                     sort_keys=True))
    print(args.out)


if __name__ == "__main__":
    main()
