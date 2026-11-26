#!/usr/bin/env python3
"""Evaluate a saved H64 package with FP32 and Product-contract INT8 refs."""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from product_integer_reference import infer as product_int_infer  # noqa: E402
from train_h64_byte_lm import (  # noqa: E402
    CONTEXT, FFN, HEAD_DIM, HEADS, HIDDEN, LAYERS, VOCAB,
    H64ByteDecoder, metrics_from_logits,
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tensor_stats(value: np.ndarray) -> dict:
    x = np.asarray(value, dtype=np.int64)
    return {"shape": list(x.shape), "min": int(x.min()), "max": int(x.max()),
            "mean_abs": float(np.mean(np.abs(x))),
            "note": "mixed integer domains; an INT8 saturation ratio is not applicable"}


def file_sha(path: Path | None) -> str | None:
    return sha(path) if path is not None else None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--dataset-name", default="Provided byte-level corpus")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261121)
    ap.add_argument("--windows", type=int, default=64)
    ap.add_argument("--top-result", type=Path)
    ap.add_argument("--top-run-log", type=Path)
    ap.add_argument("--top-compile-log", type=Path)
    ap.add_argument("--source-sha", default="UNRECORDED")
    args = ap.parse_args()

    torch.set_num_threads(1)
    ckpt = torch.load(args.fp32, map_location="cpu", weights_only=False)
    fp_model = H64ByteDecoder().cpu()
    fp_model.load_state_dict(ckpt["state_dict"])
    fp_model.eval()
    with np.load(args.package, allow_pickle=False) as archive:
        qmodel = {name: archive[name] for name in archive.files}

    raw = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()
    test = raw[int(len(raw) * 0.9):]
    lo, hi = int(len(test) * 0.05), len(test) - CONTEXT - 1
    rng = np.random.default_rng(args.seed)
    starts = rng.integers(lo, hi, size=args.windows)
    xs = np.stack([test[s:s + CONTEXT] for s in starts]).astype(np.int64)
    ys = np.stack([test[s + 1:s + CONTEXT + 1] for s in starts]).astype(np.int64)

    with torch.no_grad():
        fp_logits = fp_model(torch.from_numpy(xs)).cpu().numpy()
    int_logits = []
    aggregate: dict[str, list[np.ndarray]] = {}
    for x in xs:
        logits, trace = product_int_infer(qmodel, x.astype(np.int32).tolist())
        int_logits.append(logits)
        for name, value in trace.items():
            aggregate.setdefault(name, []).append(np.asarray(value))
    int_logits = np.asarray(int_logits)

    # LM head weights are Q5 (round(real*32)); final LN is in unit-gamma
    # activation space, so divide logits by 32 for the reported cross-entropy.
    # Argmax is unchanged by this dequantization.
    int_dequant = int_logits.astype(np.float64) / 32.0
    fp_metrics = metrics_from_logits(fp_logits, ys)
    int_metrics = metrics_from_logits(int_dequant, ys)

    # A character/byte bigram baseline uses only the first 90% training split.
    train = raw[:int(len(raw) * 0.9)]
    freq = np.ones((256, 256), dtype=np.int64)
    np.add.at(freq, (train[:-1], train[1:]), 1)
    predictor = np.argmax(freq, axis=1)
    bigram_accuracy = float(np.mean(predictor[xs] == ys))

    layers = {}
    for name, values in aggregate.items():
        if name == "embedding_position":
            continue
        arr = np.concatenate([x.reshape(-1) for x in values])
        layers[name] = tensor_stats(arr)

    top = {"status": "NOT_RUN", "source_sha": args.source_sha,
           "run_log": str(args.top_run_log) if args.top_run_log else None,
           "compile_log": str(args.top_compile_log) if args.top_compile_log else None,
           "run_log_sha256": file_sha(args.top_run_log),
           "compile_log_sha256": file_sha(args.top_compile_log)}
    if args.top_result is not None:
        top_result = json.loads(args.top_result.read_text(encoding="utf-8"))
        top.update({"status": top_result.get("status", "UNKNOWN"),
                    "result_json": str(args.top_result),
                    "result_json_sha256": sha(args.top_result),
                    "generated_tokens": top_result.get("generated_tokens"),
                    "contexts_bit_exact": sum(bool(x.get("golden_bit_exact"))
                                               for x in top_result.get("contexts", [])),
                    "context_count": len(top_result.get("contexts", []))})
    result = {
        "status": "SOFTWARE_QUALITY_EVALUATION_WITH_TOP_EVIDENCE" if args.top_result else
                  "SOFTWARE_QUALITY_EVALUATION_ONLY_TOP_NOT_RUN",
        "dataset": {"name": args.dataset_name, "sha256": sha(args.corpus),
                    "split": "first 90 percent train, final 10 percent held-out"},
        "model": {"fp32_sha256": sha(args.fp32), "int8_sha256": sha(args.package),
                  "seed": int(ckpt["seed"]),
                  "train_steps": int(ckpt.get("steps", ckpt.get("fp_steps", -1))),
                  "architecture": ckpt.get("architecture", {
                      "hidden": HIDDEN, "heads": HEADS, "head_dim": HEAD_DIM,
                      "layers": LAYERS, "ffn": FFN, "vocab": VOCAB,
                      "context": CONTEXT})},
        "evaluation": {"seed": args.seed, "windows": args.windows,
                       "tokens": int(args.windows * CONTEXT),
                       "prompt_length": CONTEXT},
        "quality": {"fp32": fp_metrics,
                    "product_contract_int8": int_metrics,
                    "int8_logit_dequantization": "INT32 logits / 32 (LM-head Q5 weight scale); argmax unchanged",
                    "bigram_baseline_accuracy_same_windows": bigram_accuracy,
                    "fp32_int8_top1_agreement": float(np.mean(
                        np.argmax(fp_logits, axis=-1) == np.argmax(int_logits, axis=-1))),
                    "int8_minus_fp32_accuracy_points": float(
                        100 * (int_metrics["next_byte_accuracy"] - fp_metrics["next_byte_accuracy"]))},
        "integer_trace_stats": layers,
        "top_rtl": top,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": result["status"], "quality": result["quality"],
                      "model_sha256": result["model"]["int8_sha256"],
                      "out": str(args.out)}, sort_keys=True))


if __name__ == "__main__":
    main()
