#!/usr/bin/env python3
"""Validate Round 27 extended GPT-2 quality and Product Top evidence."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "benchmark/gpt2_quality/results/round27_extended_train"
SUMMARY = OUT / "summary.json"
MANIFEST = OUT / "round27_extended_evidence_manifest.json"


def sha(path: Path) -> str:
    data = path.read_bytes()
    if path.suffix == ".gz":
        data = gzip.decompress(data)
    return hashlib.sha256(data).hexdigest()


def read_text(path: Path) -> str:
    data = path.read_bytes()
    if path.suffix == ".gz":
        data = gzip.decompress(data)
    return data.decode(errors="replace")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    summary = json.loads(SUMMARY.read_text())
    top_dir = OUT / "top_run"
    top = json.loads((top_dir / "autoregressive_result.json").read_text())
    seeds = summary["seeds"]
    seed_records = {
        int(seed): json.loads((OUT / f"seed_{seed}/manifest.json").read_text())
        for seed in seeds
    }
    selected_seed = max(
        seeds,
        key=lambda seed: seed_records[int(seed)]["validation_metrics"]["product_int8"]["accuracy"],
    )
    selected_package = OUT / f"seed_{selected_seed}/product_int8.npz"

    if summary["status"] != "SOFTWARE_CLEAN_SPLIT_EXPERIMENT_COMPLETE_PRODUCT_TOP_QUALIFICATION_REQUIRED":
        raise SystemExit(f"unexpected experiment status: {summary['status']}")
    if summary["corpus_sha256"] != "86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed":
        raise SystemExit("unexpected corpus SHA")
    if selected_seed != 20261223:
        raise SystemExit(f"selected seed is not validation-selected candidate: {selected_seed}")
    if summary["test_windows"] != 512 or summary["train_steps"] != 4000 or summary["qat_steps"] != 1200:
        raise SystemExit("experiment dimensions/steps differ from the recorded protocol")
    if sha(selected_package) != seed_records[int(selected_seed)]["package_sha256"]:
        raise SystemExit("selected product package hash mismatch")
    if top["status"] != "FOUR_LAYER_TOP_AUTOREGRESSIVE_GOLDEN_PASS":
        raise SystemExit(f"unexpected Top status: {top['status']}")
    if top["seed"] != selected_seed or len(top["contexts"]) != 4:
        raise SystemExit("Top run does not use the selected package/seed")
    if not all(row["golden_bit_exact"] and row["logit_count"] == 256 for row in top["contexts"]):
        raise SystemExit("one or more Product Top logit vectors failed the independent INT Golden")
    if top["mode"] != "four_layer_prefix_recompute_same_top_instance":
        raise SystemExit("unexpected Top execution mode")
    run_log = read_text(top_dir / "run.log.gz")
    required = (
        "H64_AUTOREGRESSIVE_SEQUENCE_PASS generated_tokens=4",
        "reset_events=0 host_intermediate_words=0 mode=prefix_recompute",
        "H64_FINAL_LOGITS_DUMP_PASS count=256 row=6",
        "H64_FOUR_LAYER_TOP_PASS layers=4",
    )
    if not all(marker in run_log for marker in required):
        raise SystemExit("Top run log is missing autoregressive/Golden PASS evidence")

    stages = ("fp32", "qat_float", "fake_quant", "product_int8")
    quality: dict[str, dict[str, float]] = {}
    for stage in stages:
        quality[stage] = {}
        for metric in ("accuracy", "cross_entropy_nats", "perplexity"):
            values = [row[stage][metric] for row in summary["test_metrics_by_seed"]]
            quality[stage][f"{metric}_mean"] = statistics.mean(values)
            quality[stage][f"{metric}_sample_std"] = statistics.stdev(values)
    bigram = summary["test_metrics_by_seed"][0]["bigram"]
    product_accuracy = quality["product_int8"]["accuracy_mean"]
    if not product_accuracy > bigram["accuracy"]:
        raise SystemExit("aggregate Product INT8 accuracy does not exceed train-only bigram")

    artifact_paths = [
        Path("benchmark/gpt2_quality/round27_clean_split_experiment.py"),
        Path("benchmark/gpt2_quality/verify_round27_extended_evidence.py"),
        Path("benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/corpus_split.json"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/round27_clean_split_metrics.csv"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/summary.json"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/training_console.log.gz"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/top_run/compile.log.gz"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/top_run/run.log.gz"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/top_run/autoregressive_result.json"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/top_run/autoregressive_plan.json"),
        Path("benchmark/gpt2_quality/results/round27_extended_train/top_run/four_layer_manifest.json"),
    ]
    for seed in seeds:
        prefix = Path(f"benchmark/gpt2_quality/results/round27_extended_train/seed_{seed}")
        artifact_paths.extend(prefix / name for name in
                              ("manifest.json", "fp32_before_qat.pt", "qat_float.pt", "product_int8.npz"))
    top_rel = Path("benchmark/gpt2_quality/results/round27_extended_train/top_run")
    artifact_paths.extend(top_rel / f"rtl_logits_context{i}.csv" for i in range(4))
    artifacts = {str(path): sha(ROOT / path) for path in sorted(set(artifact_paths))}

    record = {
        "status": "PRODUCT_TOP_PASS_MODEL_QUALITY_PARTIAL",
        "branch": "research/nmaforge-v1.2-round27-gpt2",
        "tested_source_sha": "901dd1d287413a4b8c51bd4f99c403842d6c30db",
        "run_id": "R27-GPT2-H64-EXTENDED-CLEAN-SPLIT-SEED20261223-TOP",
        "experiment": {
            "seeds": seeds,
            "fp32_steps": summary["train_steps"],
            "qat_steps": summary["qat_steps"],
            "validation_windows": summary["validation_windows"],
            "test_windows": summary["test_windows"],
            "scored_positions_per_window": 8,
            "test_sample_sha256": summary["test_sample_sha256"],
            "corpus_sha256": summary["corpus_sha256"],
        },
        "selected_by_validation_product_int8_accuracy": {
            "seed": selected_seed,
            "package_sha256": sha(selected_package),
            "validation_metrics": seed_records[int(selected_seed)]["validation_metrics"]["product_int8"],
        },
        "test_metrics_mean_and_sample_std": quality,
        "train_only_bigram": bigram,
        "top_result": top,
        "top_logs_sha256": {
            "compile.log": sha(top_dir / "compile.log.gz"),
            "run.log": sha(top_dir / "run.log.gz"),
        },
        "artifacts_sha256": artifacts,
        "limitations": [
            "Tiny Shakespeare byte-level H64 research decoder, not imported GPT-2 pretrained weights",
            "Product INT8 accuracy modestly exceeds bigram, but CE and perplexity remain worse than bigram",
            "Top autoregressive feedback uses prefix recomputation, not query-only incremental KV decode",
            "Top cycle counter is not complete host-to-host latency",
        ],
    }
    if args.write:
        MANIFEST.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    else:
        saved = json.loads(MANIFEST.read_text())
        if saved != record:
            raise SystemExit("saved evidence manifest differs from recomputed artifacts")
    print(f"ROUND27_EXTENDED_GPT2_EVIDENCE_PASS seed={selected_seed} "
          f"contexts=4 logits_each=256 product_acc={product_accuracy:.6f} "
          f"bigram_acc={bigram['accuracy']:.6f} artifacts={len(artifacts)} quality=PARTIAL")


if __name__ == "__main__":
    main()
