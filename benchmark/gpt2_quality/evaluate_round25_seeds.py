#!/usr/bin/env python3
"""Evaluate Round-25 QAT seeds on one fixed held-out target set.

The corpus is split at the fixed 90% boundary. Sampling uses only the final
10%, after excluding its first 5% buffer as prior reports did. Each candidate
is compared on exactly the same contexts and targets. This is software quality
evidence; Product Top qualification is a separate run.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from product_integer_reference import infer as int_infer  # noqa: E402
from train_h64_byte_lm import CONTEXT, H64ByteDecoder, metrics_from_logits  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evaluate_logits(logits: np.ndarray, targets: np.ndarray) -> dict[str, float]:
    return metrics_from_logits(logits, targets)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--seed-root", type=Path, required=True)
    ap.add_argument("--seeds", type=int, nargs="+", required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--sample-seed", type=int, default=20261128)
    ap.add_argument("--windows", type=int, default=4096)
    ap.add_argument("--cache-dir", type=Path, default=Path("/tmp/round25_gpt2_eval_cache"))
    args = ap.parse_args()

    torch.set_num_threads(1)
    torch.manual_seed(0)
    raw = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()
    cut = int(len(raw) * 0.9)
    heldout = raw[cut:]
    lo = int(len(heldout) * 0.05)
    hi = len(heldout) - CONTEXT - 1
    if hi <= lo or args.windows <= 0:
        raise ValueError("held-out corpus is too small for the requested sample")
    rng = np.random.default_rng(args.sample_seed)
    starts = rng.integers(lo, hi, size=args.windows, endpoint=False)
    xs = np.stack([heldout[s:s + CONTEXT] for s in starts]).astype(np.int64)
    ys = heldout[starts + CONTEXT].astype(np.int64)
    sample_hash = hashlib.sha256(starts.astype("<u8").tobytes() + ys.tobytes()).hexdigest()

    source = torch.load(args.source_fp32, map_location="cpu", weights_only=False)
    fp_model = H64ByteDecoder().eval()
    fp_model.load_state_dict(source["state_dict"])
    with torch.no_grad():
        fp_logits = fp_model(torch.from_numpy(xs)).cpu().numpy()[:, -1, :]
    fp_metrics = evaluate_logits(fp_logits, ys)

    train = raw[:cut]
    counts = np.ones((256, 256), dtype=np.int64)
    np.add.at(counts, (train[:-1], train[1:]), 1)
    bigram_next = np.argmax(counts, axis=1)
    bigram_predictions = bigram_next[xs[:, -1]]
    bigram_accuracy = float(np.mean(bigram_predictions == ys))

    args.out_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    details: dict[str, dict] = {}
    for seed in args.seeds:
        seed_dir = args.seed_root / f"seed_{seed}"
        manifest_path = seed_dir / "manifest.json"
        package = seed_dir / "round24_integer_qat_model.npz"
        checkpoint = seed_dir / "round24_integer_qat_fp32.pt"
        manifest = json.loads(manifest_path.read_text())
        if manifest["source_fp32_sha256"] != sha(args.source_fp32):
            raise ValueError(f"seed {seed} used a different FP32 source")
        qcheckpoint = torch.load(checkpoint, map_location="cpu", weights_only=False)
        qat_model = H64ByteDecoder().eval()
        qat_model.load_state_dict(qcheckpoint["state_dict"])
        with torch.no_grad():
            qat_logits = qat_model(torch.from_numpy(xs)).cpu().numpy()[:, -1, :]

        with np.load(package, allow_pickle=False) as archive:
            qmodel = {key: archive[key].copy() for key in archive.files}
        args.cache_dir.mkdir(parents=True, exist_ok=True)
        cache_path = args.cache_dir / f"seed_{seed}_{sample_hash}.npz"
        package_hash = sha(package)
        int_logits = None
        if cache_path.exists():
            with np.load(cache_path, allow_pickle=False) as cached:
                if (str(cached["sample_hash"].item()) == sample_hash and
                        str(cached["package_hash"].item()) == package_hash):
                    int_logits = cached["int_logits"].copy()
        if int_logits is None or int_logits.shape != fp_logits.shape:
            # Re-evaluate when no matching cache exists. Save after each seed
            # so a later report/serialization fix does not discard minutes of
            # deterministic integer inference work.
            int_logits = np.empty_like(fp_logits, dtype=np.int32)
            for i, context in enumerate(xs):
                logits, _trace = int_infer(qmodel, context.astype(np.int32).tolist())
                int_logits[i] = np.asarray(logits[-1], dtype=np.int32)
            np.savez_compressed(cache_path, sample_hash=np.array(sample_hash),
                                package_hash=np.array(package_hash), int_logits=int_logits)
        # LM head package is Q5; scale affects CE but not greedy token selection.
        int_metrics = evaluate_logits(int_logits.astype(np.float64) / 32.0, ys)
        qat_metrics = evaluate_logits(qat_logits, ys)
        row = {
            "seed": seed,
            "source_sha256": sha(args.source_fp32),
            "checkpoint_sha256": sha(checkpoint),
            "package_sha256": sha(package),
            "fp32_accuracy": fp_metrics["next_byte_accuracy"],
            "qat_float_accuracy": qat_metrics["next_byte_accuracy"],
            "qat_float_ce": qat_metrics["cross_entropy_nats"],
            "qat_float_ppl": qat_metrics["perplexity"],
            "int8_accuracy": int_metrics["next_byte_accuracy"],
            "int8_ce": int_metrics["cross_entropy_nats"],
            "int8_ppl": int_metrics["perplexity"],
            "bigram_accuracy": bigram_accuracy,
            "fp32_int8_top1_agreement": float(np.mean(np.argmax(fp_logits, axis=-1) == np.argmax(int_logits, axis=-1))),
            "qat_float_validation_accuracy": manifest["validation"]["qat_float"]["accuracy"],
            "int8_validation_accuracy": manifest["validation"]["int8"]["accuracy"],
            "test_windows": len(ys),
            "test_sample_sha256": sample_hash,
        }
        rows.append(row)
        details[str(seed)] = {"metrics": row,
                              "validation": manifest["validation"],
                              "qat_float_test": qat_metrics,
                              "int8_test": int_metrics}

    fields = list(rows[0])
    csv_path = args.out_dir / "round25_gpt2_quality_by_seed.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    numeric = ["qat_float_accuracy", "qat_float_ce", "qat_float_ppl",
               "int8_accuracy", "int8_ce", "int8_ppl", "fp32_int8_top1_agreement"]
    summary = {
        "status": "SOFTWARE_HELDOUT_EVALUATION_ONLY_TOP_QUALIFICATION_SEPARATE",
        "source_fp32_sha256": sha(args.source_fp32),
        "corpus_sha256": sha(args.corpus),
        "split": "first 90% training/development; final 10% held-out; first 5% of held-out excluded",
        "sample": {"seed": args.sample_seed, "windows": len(ys), "context": CONTEXT,
                    "target_count": len(ys), "starts_and_target_sha256": sample_hash},
        "fp32": fp_metrics,
        "bigram_accuracy_same_sample": bigram_accuracy,
        "seed_results": details,
        "aggregate": {name: {"mean": float(np.mean([r[name] for r in rows])),
                             "std_population": float(np.std([r[name] for r in rows])),
                             "min": float(np.min([r[name] for r in rows])),
                             "max": float(np.max([r[name] for r in rows]))}
                      for name in numeric},
        "artifacts": {"csv": csv_path.name},
        "limitations": ["byte-level Tiny Shakespeare task, not a general language benchmark",
                        "three QAT seeds share one recovered source checkpoint and fixed corpus split",
                        "Product RTL qualification must be performed on the selected package separately"],
    }
    json_path = args.out_dir / "round25_gpt2_quality_summary.json"
    json_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": summary["status"], "fp32": fp_metrics,
                      "bigram_accuracy": bigram_accuracy,
                      "aggregate": summary["aggregate"],
                      "out": str(json_path)}, sort_keys=True))


if __name__ == "__main__":
    main()
