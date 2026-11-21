#!/usr/bin/env python3
"""Round 28 paired held-out audit for the frozen clean-split H64 candidates.

The final test windows are reconstructed from corpus_split.json and are not
used for candidate selection.  Bootstrap resampling is clustered by window so
the eight adjacent byte targets in one context are not treated as independent.
This script reports software quality only; Product Top qualification is a
separate VCS run.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from round27_clean_split_experiment import (  # noqa: E402
    CONTEXT, H64ByteDecoder, IntegerLayerNormQAT, bigram, get_windows,
    integer_logits, metrics, sha_bytes, sha_file, torch_logits,
)
from round21_contract_ablation import CONTRACTS  # noqa: E402


def per_window(logits: np.ndarray, targets: np.ndarray, scale: float = 1.0):
    z = logits.astype(np.float64) / scale
    z = z - z.max(axis=-1, keepdims=True)
    log_norm = np.log(np.exp(z).sum(axis=-1))
    selected = np.take_along_axis(z, targets[..., None], axis=-1)[..., 0]
    ce = log_norm - selected
    acc = np.mean(np.argmax(z, axis=-1) == targets, axis=-1)
    return acc, np.mean(ce, axis=-1)


def bootstrap_ci(values: np.ndarray, rng: np.random.Generator,
                 draws: int = 20_000) -> tuple[float, float]:
    boot = np.empty(draws, dtype=np.float64)
    n = len(values)
    for index in range(draws):
        boot[index] = np.mean(values[rng.integers(0, n, size=n)])
    lo, hi = np.quantile(boot, [0.025, 0.975])
    return float(lo), float(hi)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--evidence", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261223)
    ap.add_argument("--bootstrap-seed", type=int, default=20261128)
    args = ap.parse_args()
    torch.set_num_threads(1)

    evidence = args.evidence.resolve()
    raw_bytes = args.corpus.read_bytes()
    raw = np.frombuffer(raw_bytes, dtype=np.uint8).copy()
    split = json.loads((evidence / "corpus_split.json").read_text())
    if split["corpus_sha256"] != sha_bytes(raw_bytes):
        raise SystemExit("corpus hash differs from frozen split manifest")
    train_lo, train_hi = split["ranges_half_open"]["train"]
    test_lo, test_hi = split["ranges_half_open"]["test"]
    train = raw[train_lo:train_hi]
    test_count = 512
    test_x, test_y, starts = get_windows(raw, test_lo, test_hi, test_count, 20261211)
    start_sha = sha_bytes(starts.astype("<i8").tobytes())

    seed_dir = evidence / f"seed_{args.seed}"
    fp = torch.load(seed_dir / "fp32_before_qat.pt", map_location="cpu", weights_only=False)
    qf = torch.load(seed_dir / "qat_float.pt", map_location="cpu", weights_only=False)
    fp_model = H64ByteDecoder().cpu(); fp_model.load_state_dict(fp["state_dict"])
    qf_model = H64ByteDecoder().cpu(); qf_model.load_state_dict(qf["state_dict"])
    fake_model = IntegerLayerNormQAT(H64ByteDecoder().cpu())
    fake_model.model.load_state_dict(fp["state_dict"])
    package_path = seed_dir / "product_int8.npz"
    with np.load(package_path, allow_pickle=False) as npz:
        package = {key: npz[key].copy() for key in npz.files}
    for layer in range(4):
        package[f"l{layer}.up_q8_8"] = package[f"l{layer}.up"].copy()

    print(f"R28_EVAL_START seed={args.seed} windows={test_count} targets={test_count*CONTEXT}", flush=True)
    fp_logits = torch_logits(fp_model, test_x)
    qf_logits = torch_logits(qf_model, test_x)
    fake_logits = torch_logits(fake_model, test_x)
    int_logits = integer_logits(package, test_x)
    bg_metrics, bg_logits = bigram(train, test_x, test_y)

    rows = {}
    for name, logits, scale in (
        ("fp32", fp_logits, 1.0), ("qat_float", qf_logits, 1.0),
        ("fake_quant", fake_logits, 1.0), ("product_int8", int_logits, 32.0),
        ("bigram", bg_logits, 1.0),
    ):
        rows[name] = per_window(logits, test_y, scale)

    product_acc, product_ce = rows["product_int8"]
    bigram_acc, bigram_ce = rows["bigram"]
    delta_acc = product_acc - bigram_acc
    delta_ce = product_ce - bigram_ce
    rng = np.random.default_rng(args.bootstrap_seed)
    acc_ci = bootstrap_ci(delta_acc, rng)
    ce_ci = bootstrap_ci(delta_ce, rng)
    product_level_ci = bootstrap_ci(product_acc, rng)
    int_global = metrics(int_logits.astype(np.float64) / 32.0, test_y)
    fp_global = metrics(fp_logits, test_y)
    qat_global = metrics(qf_logits, test_y)
    fake_global = metrics(fake_logits, test_y)
    bg_global = metrics(bg_logits, test_y)
    agreement = float(np.mean(np.argmax(int_logits, axis=-1) ==
                              np.argmax(fp_logits, axis=-1)))

    args.out.mkdir(parents=True, exist_ok=True)
    csv_path = args.out / "round28_paired_windows.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["window_index", "start_byte", "fp32_acc", "fp32_ce",
                         "qat_float_acc", "qat_float_ce", "fake_quant_acc",
                         "fake_quant_ce", "product_int8_acc", "product_int8_ce",
                         "bigram_acc", "bigram_ce", "paired_acc_delta",
                         "paired_ce_delta"])
        for i, start in enumerate(starts):
            writer.writerow([i, int(start), rows["fp32"][0][i], rows["fp32"][1][i],
                             rows["qat_float"][0][i], rows["qat_float"][1][i],
                             rows["fake_quant"][0][i], rows["fake_quant"][1][i],
                             product_acc[i], product_ce[i], bigram_acc[i], bigram_ce[i],
                             delta_acc[i], delta_ce[i]])

    report = {
        "status": "SOFTWARE_PAIRED_QUALITY_AUDIT_COMPLETE_PRODUCT_TOP_REQUIRED",
        "source_note": "frozen Round27 three-seed clean-split training evidence, re-audited in Round28 worktree",
        "seed": args.seed,
        "corpus_sha256": sha_bytes(raw_bytes),
        "package_sha256": sha_file(package_path),
        "test_window_count": test_count,
        "targets_per_window": CONTEXT,
        "test_start_sha256": start_sha,
        "independent_sampling_unit": "window; bootstrap resamples whole context windows",
        "bootstrap": {"seed": args.bootstrap_seed, "draws": 20_000,
                      "product_minus_bigram_accuracy_pp_mean": float(delta_acc.mean()*100),
                      "product_minus_bigram_accuracy_pp_ci95": [acc_ci[0]*100, acc_ci[1]*100],
                      "product_minus_bigram_ce_nats_mean": float(delta_ce.mean()),
                      "product_minus_bigram_ce_nats_ci95": list(ce_ci),
                      "product_accuracy_ci95": list(product_level_ci)},
        "heldout_metrics": {"fp32": fp_global, "qat_float": qat_global,
                            "fake_quant": fake_global, "product_int8": int_global,
                            "bigram": bg_global,
                            "product_fp32_top1_agreement": agreement},
        "three_seed_aggregate_from_frozen_source": json.loads(
            (evidence / "summary.json").read_text())["test_metrics_by_seed"],
        "paired_csv_sha256": sha_file(csv_path),
        "contract": CONTRACTS["residual_gelu_aligned"],
        "limits": [
            "This is byte-level Tiny-Shakespeare H64 research, not pretrained GPT-2.",
            "Only one validation-selected seed is paired-resampled here; three-seed metrics remain separately reported.",
            "A Product Top exact-logit pass establishes implementation correctness, not language-model quality closure.",
        ],
    }
    json_path = args.out / "round28_paired_quality.json"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("ROUND28_PAIRED_QUALITY_AUDIT_PASS " + json.dumps({
        "seed": args.seed, "test_windows": test_count, "targets": test_count*CONTEXT,
        "product_acc": int_global["accuracy"], "bigram_acc": bg_global["accuracy"],
        "paired_acc_delta_pp_ci95": report["bootstrap"]["product_minus_bigram_accuracy_pp_ci95"],
        "product_ce": int_global["cross_entropy_nats"],
        "bigram_ce": bg_global["cross_entropy_nats"],
        "paired_ce_delta_ci95": ce_ci,
        "product_sha256": report["package_sha256"],
    }, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
