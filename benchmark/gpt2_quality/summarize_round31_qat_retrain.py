#!/usr/bin/env python3
"""Summarize frozen Round 31 QAT candidate manifests without selecting on test."""

import argparse
import csv
import json
import math
from pathlib import Path


def mean_std(values):
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / len(values)
    return {"mean": mean, "population_std": math.sqrt(variance)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--results", type=Path, required=True)
    args = parser.parse_args()
    root = args.results
    manifests = sorted(root.glob("source_*/manifest.json"))
    if len(manifests) != 3:
        raise SystemExit(f"expected exactly 3 candidate manifests, found {len(manifests)}")

    rows = []
    candidates = []
    for path in manifests:
        data = json.loads(path.read_text())
        record = {
            "qat_seed": data["qat_seed"],
            "source_seed": data["source_seed"],
            "package_sha256": data["package_sha256"],
            "qat_checkpoint_sha256": data["qat_checkpoint_sha256"],
            "validation_windows": 128,
            "validation_targets": 2048,
            "test_windows": 512,
            "test_targets": 8192,
            "product_top_status": data["product_top_status"],
        }
        for split_name, key in (("validation", "validation_metrics"), ("test", "test_metrics_once_frozen")):
            metrics = data[key]
            for model_name in ("fp32", "qat_float", "product_int8_aligned", "bigram"):
                model = metrics[model_name]
                rows.append({
                    **record,
                    "split": split_name,
                    "model": model_name,
                    "accuracy_pct": 100.0 * model["accuracy"],
                    "cross_entropy_nats": model["cross_entropy_nats"],
                    "perplexity": model["perplexity"],
                    "int8_vs_fp32_top1_agreement_pct": 100.0 * metrics["agreement"]["int8_vs_fp32_top1"],
                })
        candidates.append({
            **record,
            "validation": data["validation_metrics"],
            "test_evaluated_after_validation_selection": data["test_metrics_once_frozen"],
            "trace_all_exact": data["test_metrics_once_frozen"]["trace_all_exact"],
            "trace_sample_windows": data["test_metrics_once_frozen"]["trace_sample_windows"],
        })

    csv_path = root / "round31_qat_seed_summary.csv"
    with csv_path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    summary_fields = (
        ("validation", "product_int8_aligned"),
        ("validation", "qat_float"),
        ("test", "product_int8_aligned"),
        ("test", "qat_float"),
    )
    aggregates = {}
    for split, model in summary_fields:
        matching = [row for row in rows if row["split"] == split and row["model"] == model]
        aggregates[f"{split}.{model}"] = {
            metric: mean_std([row[metric] for row in matching])
            for metric in ("accuracy_pct", "cross_entropy_nats", "perplexity")
        }

    result = {
        "status": "SOFTWARE_QAT_ONLY_PRODUCT_TOP_BLOCKED_ENV",
        "candidate_count": len(candidates),
        "selection_rule": "highest product-int8 validation accuracy; CE tie-break",
        "selected_qat_seed": 20263113,
        "validation_used_for_selection": True,
        "test_used_for_selection": False,
        "test_pristine_for_future_confirmation": False,
        "test_note": "All three candidates were evaluated on the held-out test after validation selection; do not treat this as an untouched future test.",
        "aggregate_population_statistics": aggregates,
        "candidates": candidates,
        "summary_csv": csv_path.name,
    }
    (root / "round31_qat_seed_summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"summary_csv": str(csv_path), "candidate_count": len(candidates), "status": result["status"]}))


if __name__ == "__main__":
    main()
