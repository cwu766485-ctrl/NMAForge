#!/usr/bin/env python3
"""Hash and sanity-check the frozen Round 27 GPT-2 evidence package."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "benchmark/gpt2_quality/results/round27_long_train"
SUMMARY = OUT / "round27_final_summary.json"
MANIFEST = OUT / "round27_evidence_manifest.json"


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
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true", help="write the evidence manifest")
    args = ap.parse_args()

    summary = json.loads(SUMMARY.read_text())
    top = OUT / "top_run"
    result = json.loads((top / "autoregressive_result.json").read_text())
    seed = int(summary["selected_seed"])
    selected = OUT / f"seed_{seed}"
    selected_manifest = json.loads((selected / "manifest.json").read_text())
    artifact_paths = [
        OUT / "corpus_split.json",
        OUT / "round27_clean_split_metrics.csv",
        SUMMARY,
        selected / "manifest.json",
        selected / "fp32_before_qat.pt",
        selected / "qat_float.pt",
        selected / "product_int8.npz",
        top / "four_layer_manifest.json",
        top / "autoregressive_plan.json",
        top / "autoregressive_result.json",
        top / "product_int8.npz",
        top / "compile.log.gz",
        top / "run.log.gz",
        *(top / f"rtl_logits_context{i}.csv" for i in range(4)),
    ]
    for candidate_seed in summary["training_seeds"]:
        candidate = OUT / f"seed_{candidate_seed}"
        artifact_paths.extend([
            candidate / "manifest.json",
            candidate / "fp32_before_qat.pt",
            candidate / "qat_float.pt",
            candidate / "product_int8.npz",
        ])
    artifacts = {
        str(path.relative_to(ROOT)): sha(path)
        for path in sorted(set(artifact_paths))
    }

    if sha(selected / "product_int8.npz") != summary["selected_product_package_sha256"]:
        raise SystemExit("selected package SHA mismatch against summary")
    if selected_manifest["package_sha256"] != sha(selected / "product_int8.npz"):
        raise SystemExit("selected package SHA mismatch against seed manifest")
    if result["status"] != "FOUR_LAYER_TOP_AUTOREGRESSIVE_GOLDEN_PASS":
        raise SystemExit(f"unexpected Top result status: {result['status']}")
    if len(result["contexts"]) != 4 or not all(
        c["golden_bit_exact"] and c["logit_count"] == 256 for c in result["contexts"]
    ):
        raise SystemExit("one or more 256-logit contexts failed independent INT Golden")
    run_log = read_text(top / "run.log.gz")
    required_markers = [
        "H64_AUTOREGRESSIVE_SEQUENCE_PASS generated_tokens=4",
        "reset_events=0 host_intermediate_words=0 mode=prefix_recompute",
    ]
    if not all(marker in run_log for marker in required_markers):
        raise SystemExit("Top run log is missing the expected persistent-session markers")
    if summary["status"] != "PARTIAL_MODEL_QUALITY_BELOW_BIGRAM_PRODUCT_TOP_AUTOREGRESSIVE_GOLDEN_PASS":
        raise SystemExit(f"unexpected quality disposition: {summary['status']}")

    record = {
        "status": summary["status"],
        "branch": "research/nmaforge-v1.2-round27-gpt2",
        "tested_source_sha": summary["source_sha"],
        "run_id": "R27-GPT2-H64-CLEAN-SPLIT-SEED20261212-TOP",
        "seed": seed,
        "tools": {"vcs": "V-2023.12-SP1_Full64", "python": "3.12.13",
                  "numpy": "2.5.4", "pytorch": "2.6.0+cpu"},
        "corpus_sha256": summary["corpus_sha256"],
        "test_windows_sha256": summary["test_windows_sha256"],
        "selected_model": {
            "source_fp32_checkpoint_sha256": summary["selected_fp32_checkpoint_sha256"],
            "qat_checkpoint_sha256": summary["selected_qat_checkpoint_sha256"],
            "product_package_sha256": summary["selected_product_package_sha256"],
        },
        "top_result": result,
        "quality": summary["metrics_mean_and_seed_std"],
        "artifacts_sha256": artifacts,
        "limitations": [
            "trained Tiny Shakespeare byte decoder; not imported pretrained GPT-2 weights",
            "four-token feedback uses prefix recompute in one Top instance, not query-only KV decode",
            "Product INT8 held-out accuracy is below train-only bigram; model quality is PARTIAL",
            "cycle counter is not complete host-to-host latency",
        ],
    }
    if args.write:
        MANIFEST.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
    else:
        saved = json.loads(MANIFEST.read_text())
        if saved != record:
            raise SystemExit("saved manifest differs from recomputed evidence")
    print(f"ROUND27_GPT2_EVIDENCE_PASS artifacts={len(artifacts)} "
          f"contexts=4 logits_each=256 top=PASS quality=PARTIAL")


if __name__ == "__main__":
    main()
