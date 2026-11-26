#!/usr/bin/env python3
"""Derive per-context scaling from the fixed Round 31 paired Product Top data."""
import argparse
import csv
import hashlib
import json
from pathlib import Path


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rows(path):
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--comparison-csv", type=Path, required=True)
    ap.add_argument("--prefix-csv", type=Path, required=True)
    ap.add_argument("--persistent-csv", type=Path, required=True)
    ap.add_argument("--paired-run-manifest", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    comparison = rows(args.comparison_csv)
    prefix = rows(args.prefix_csv)
    persistent = rows(args.persistent_csv)
    run = json.loads(args.paired_run_manifest.read_text())
    if not run["runs"]["prefix_recompute"]["all_4_contexts_256_logits_bit_exact"]:
        raise SystemExit("prefix-recompute run is not Golden-exact")
    if not run["runs"]["persistent_incremental_kv"]["all_4_contexts_256_logits_bit_exact"]:
        raise SystemExit("persistent-KV run is not Golden-exact")
    if not run["runs"]["persistent_incremental_kv"]["all_logits_sha256_match_prefix_recompute"]:
        raise SystemExit("the paired logits hashes do not match")
    if not (len(comparison) == len(prefix) == len(persistent) == 3):
        raise SystemExit("expected exactly three paired decode contexts")

    per_context = []
    for c, p, k in zip(comparison, prefix, persistent):
        context = int(c["context"])
        if context != int(p["context"]) or context != int(k["context"]):
            raise SystemExit("context rows are not aligned")
        cycle_saved = int(p["product_cycles"]) - int(k["product_cycles"])
        descriptor_saved = int(p["descriptor_publications"]) - int(k["descriptor_publications"])
        prior_prefix_tokens = int(c["valid_tokens"]) - 1
        if cycle_saved != int(c["cycles_saved"]):
            raise SystemExit("cycle delta disagrees with comparison CSV")
        if descriptor_saved != int(c["descriptors_saved"]):
            raise SystemExit("descriptor delta disagrees with comparison CSV")
        per_context.append({
            "context": context,
            "valid_tokens": int(c["valid_tokens"]),
            "prior_prefix_tokens_recomputed_by_baseline": prior_prefix_tokens,
            "cycles_saved": cycle_saved,
            "descriptors_saved": descriptor_saved,
            "cycles_saved_per_prior_prefix_token": cycle_saved / prior_prefix_tokens,
            "descriptors_saved_per_prior_prefix_token": descriptor_saved / prior_prefix_tokens,
            "prefix_cycles": int(p["product_cycles"]),
            "persistent_kv_cycles": int(k["product_cycles"]),
            "prefix_descriptors": int(p["descriptor_publications"]),
            "persistent_kv_descriptors": int(k["descriptor_publications"]),
            "logits_bit_exact": True,
            "host_intermediate_words": 0,
            "reset_events": 0,
        })

    cycle_unit = {round(x["cycles_saved_per_prior_prefix_token"], 8) for x in per_context}
    descriptor_unit = {round(x["descriptors_saved_per_prior_prefix_token"], 8) for x in per_context}
    if len(cycle_unit) != 1 or len(descriptor_unit) != 1:
        raise SystemExit("observed per-prefix-row savings are not constant")
    cycle_unit_value = per_context[0]["cycles_saved_per_prior_prefix_token"]
    descriptor_unit_value = per_context[0]["descriptors_saved_per_prior_prefix_token"]
    total_prefix = int(run["runs"]["prefix_recompute"]["extension_cycles"])
    total_persistent = int(run["runs"]["persistent_incremental_kv"]["extension_cycles"])
    total_saved = total_prefix - total_persistent
    result = {
        "status": "DERIVED_FROM_EXISTING_PRODUCT_TOP_RUNS_NO_NEW_SIMULATION",
        "paired_run_id": run["run_id"],
        "product_rtl_tree_sha": run["product_rtl_tree_sha"],
        "prefix_source_sha": run["runs"]["prefix_recompute"]["source_sha"],
        "persistent_source_sha": run["runs"]["persistent_incremental_kv"]["source_sha"],
        "abi": run["abi"],
        "model_package_sha256": run["model"]["package_sha256"],
        "configuration": run["configuration"],
        "timing_boundary": run["timing_boundary"],
        "input_artifacts": {
            str(args.comparison_csv): sha(args.comparison_csv),
            str(args.prefix_csv): sha(args.prefix_csv),
            str(args.persistent_csv): sha(args.persistent_csv),
            str(args.paired_run_manifest): sha(args.paired_run_manifest),
        },
        "per_context": per_context,
        "aggregate": {
            "prefix_recompute_cycles": total_prefix,
            "persistent_kv_cycles": total_persistent,
            "cycles_saved": total_saved,
            "cycle_reduction_pct": round(100.0 * total_saved / total_prefix, 4),
            "prefix_recompute_descriptors": int(run["runs"]["prefix_recompute"]["descriptor_publications"]),
            "persistent_kv_descriptors": int(run["runs"]["persistent_incremental_kv"]["descriptor_publications"]),
            "descriptors_saved": int(run["runs"]["comparison"]["descriptor_publications_saved"]),
            "descriptor_reduction_pct": run["runs"]["comparison"]["descriptor_publication_reduction_pct"],
        },
        "observed_scaling": {
            "cycles_saved_per_eliminated_prior_prefix_token": cycle_unit_value,
            "descriptors_saved_per_eliminated_prior_prefix_token": descriptor_unit_value,
            "decoder_layers": run["model"]["shape"]["decoder_layers"],
            "derived_cycles_per_layer_per_prefix_token": cycle_unit_value / run["model"]["shape"]["decoder_layers"],
            "derived_descriptors_per_layer_per_prefix_token": descriptor_unit_value / run["model"]["shape"]["decoder_layers"],
        },
        "interpretation": {
            "inference": "Across all three measured contexts, saved cycles and descriptor publications scale exactly with the number of old prefix rows that prefix-recompute reprocesses. This is consistent with work elimination from persistent KV, rather than faster execution of the same query rows.",
            "not_measured": ["per-engine cycle attribution", "KV read/write bytes by layer", "DMA traffic", "host-to-host latency", "silicon throughput"],
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
