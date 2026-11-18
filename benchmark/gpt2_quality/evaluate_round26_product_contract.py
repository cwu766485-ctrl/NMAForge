#!/usr/bin/env python3
"""Round-26 fixed-sample quality audit using the exact Product integer contract.

This intentionally does not select a new checkpoint or tune on the final 10%
of the corpus. It re-evaluates the three archived Round-25 candidates on the
same deterministic target windows, with the same contract used by Product Top.
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
from round21_contract_ablation import CONTRACTS, infer as product_infer  # noqa: E402
from train_h64_byte_lm import CONTEXT, H64ByteDecoder, metrics_from_logits  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metrics(logits: np.ndarray, targets: np.ndarray, scale: float = 1.0) -> dict:
    return metrics_from_logits(logits.astype(np.float64) / scale, targets)


def distribution(values: np.ndarray) -> dict:
    counts = np.bincount(values.astype(np.int64), minlength=256).astype(np.float64)
    p = counts / counts.sum()
    nz = p[p > 0]
    return {"entropy_bits": float(-(nz * np.log2(nz)).sum()),
            "unique_symbols": int(np.count_nonzero(counts)),
            "top10_symbols": np.argsort(counts)[-10:][::-1].tolist(),
            "counts_sha256": hashlib.sha256(counts.astype("<u8").tobytes()).hexdigest()}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--seed-root", type=Path, required=True)
    ap.add_argument("--seeds", type=int, nargs="+", required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--sample-seed", type=int, default=20261128)
    ap.add_argument("--windows", type=int, default=512)
    ap.add_argument("--cache-dir", type=Path, default=Path("/tmp/round26_gpt2_eval_cache"))
    args = ap.parse_args()

    torch.set_num_threads(1)
    raw = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()
    split = int(len(raw) * 0.9)
    held = raw[split:]
    lower = int(len(held) * 0.05)
    upper = len(held) - CONTEXT - 1
    rng = np.random.default_rng(args.sample_seed)
    starts = rng.integers(lower, upper, size=args.windows, endpoint=False)
    xs = np.stack([held[s:s + CONTEXT] for s in starts]).astype(np.int64)
    ys = held[starts + CONTEXT].astype(np.int64)
    sample_hash = hashlib.sha256(starts.astype("<u8").tobytes() + ys.tobytes()).hexdigest()

    fp_ckpt = torch.load(args.source_fp32, map_location="cpu", weights_only=False)
    fp_model = H64ByteDecoder().eval()
    fp_model.load_state_dict(fp_ckpt["state_dict"])
    with torch.no_grad():
        fp_logits = fp_model(torch.from_numpy(xs))[:, -1, :].cpu().numpy()
    fp_metrics = metrics(fp_logits, ys)

    train = raw[:split]
    transitions = np.ones((256, 256), dtype=np.int64)
    np.add.at(transitions, (train[:-1], train[1:]), 1)
    bigram_pred = np.argmax(transitions, axis=1)[xs[:, -1]]
    bigram_accuracy = float(np.mean(bigram_pred == ys))

    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.cache_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    for seed in args.seeds:
        seed_dir = args.seed_root / f"seed_{seed}"
        manifest = json.loads((seed_dir / "manifest.json").read_text())
        package_path = seed_dir / "round24_integer_qat_model.npz"
        checkpoint_path = seed_dir / "round24_integer_qat_fp32.pt"
        if manifest["source_fp32_sha256"] != sha(args.source_fp32):
            raise ValueError(f"seed {seed} source checkpoint hash mismatch")
        with torch.no_grad():
            qfloat = H64ByteDecoder().eval()
            qckpt = torch.load(checkpoint_path, map_location="cpu", weights_only=False)
            qfloat.load_state_dict(qckpt["state_dict"])
            qfloat_logits = qfloat(torch.from_numpy(xs))[:, -1, :].cpu().numpy()

        with np.load(package_path, allow_pickle=False) as archive:
            qmodel = {name: archive[name].copy() for name in archive.files}
        # QAT package exports `up` at Q8.8 (scale 256). Product Top consumes the
        # canonical tensor directly; this alias is the ablation helper's ABI.
        for layer in range(4):
            qmodel[f"l{layer}.up_q8_8"] = qmodel[f"l{layer}.up"].copy()
        cache_key = f"seed_{seed}_{sample_hash}_{sha(package_path)}.npz"
        cache_path = args.cache_dir / cache_key
        int_logits = None
        if cache_path.exists():
            with np.load(cache_path, allow_pickle=False) as cache:
                int_logits = cache["logits"].copy()
        if int_logits is None or int_logits.shape != (len(ys), 16, 256):
            int_logits = np.empty((len(ys), CONTEXT, 256), dtype=np.int32)
            for i, context in enumerate(xs):
                all_logits, _ = product_infer(
                    qmodel, context.astype(np.int32).tolist(),
                    CONTRACTS["residual_gelu_aligned"])
                int_logits[i] = np.asarray(all_logits, dtype=np.int32)
                if (i + 1) % 64 == 0 or i + 1 == len(xs):
                    print(f"ROUND26_INT seed={seed} windows={i+1}/{len(xs)}", flush=True)
            np.savez_compressed(cache_path, logits=int_logits,
                                package_sha256=np.array(sha(package_path)),
                                sample_sha256=np.array(sample_hash))
        last_logits = int_logits[:, -1, :]
        qfloat_metric = metrics(qfloat_logits, ys)
        int_metric = metrics(last_logits, ys, scale=32.0)
        rows.append({
            "seed": seed,
            "source_fp32_sha256": sha(args.source_fp32),
            "checkpoint_sha256": sha(checkpoint_path),
            "package_sha256": sha(package_path),
            "test_sample_sha256": sample_hash,
            "test_windows": len(ys),
            "fp32_accuracy": fp_metrics["next_byte_accuracy"],
            "fp32_ce": fp_metrics["cross_entropy_nats"],
            "fp32_ppl": fp_metrics["perplexity"],
            "qat_float_accuracy": qfloat_metric["next_byte_accuracy"],
            "qat_float_ce": qfloat_metric["cross_entropy_nats"],
            "qat_float_ppl": qfloat_metric["perplexity"],
            "product_contract_int8_accuracy": int_metric["next_byte_accuracy"],
            "product_contract_int8_ce": int_metric["cross_entropy_nats"],
            "product_contract_int8_ppl": int_metric["perplexity"],
            "fp32_int8_top1_agreement": float(np.mean(
                np.argmax(fp_logits, axis=-1) == np.argmax(last_logits, axis=-1))),
            "qat_float_int8_top1_agreement": float(np.mean(
                np.argmax(qfloat_logits, axis=-1) == np.argmax(last_logits, axis=-1))),
            "bigram_accuracy": bigram_accuracy,
        })

    csv_path = args.out_dir / "round26_gpt2_quality_by_seed.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    # Split audit: Round-24 validation samples were drawn from the last fifth
    # of the first 90% corpus, while QAT batches were drawn across all of that
    # partition. This is a development-window overlap, not final-test access.
    train_window_count = split - CONTEXT - 1
    validation_lo = int(train_window_count * 0.80)
    validation_hi = train_window_count
    audit = {
        "status": "ROUND26_FIXED_SAMPLE_REEVALUATION_SOFTWARE_ONLY",
        "source_fp32_sha256": sha(args.source_fp32),
        "corpus_sha256": sha(args.corpus),
        "sample": {"seed": args.sample_seed, "windows": len(ys), "context": CONTEXT,
                   "start_target_sha256": sample_hash},
        "split": {"training_development_bytes": split, "heldout_bytes": len(held),
                  "training_start_range": [0, train_window_count],
                  "round24_validation_start_range_in_train_partition":
                      [validation_lo, validation_hi],
                  "validation_sampling_seed": 2026112401,
                  "validation_windows": 512,
                  "overlap_assessment": "validation windows are drawn from the QAT training byte partition; no final held-out bytes are used for training, but validation is not corpus-disjoint from training"},
        "same_sample_fp32": fp_metrics,
        "same_sample_bigram_accuracy": bigram_accuracy,
        "product_integer_contract": "round21_contract_ablation.CONTRACTS['residual_gelu_aligned']; package l*.up_q8_8 aliases l*.up; same Round-25 Product Top numerical profile",
        "seed_results": rows,
        "limitations": ["This is a fixed 512-window software quality audit, not a fresh Product Top run.",
                        "Byte-level Tiny Shakespeare is a narrow task.",
                        "The source FP32 model and QAT-updated Float quality are reported separately; neither is assumed to be a language-quality baseline.",
                        "Validation overlap weakens checkpoint selection evidence; final held-out sample remains separate."],
    }
    out_json = args.out_dir / "round26_gpt2_quality_audit.json"
    out_json.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": audit["status"], "fp32": fp_metrics,
                      "bigram_accuracy": bigram_accuracy,
                      "seeds": rows, "out": str(out_json)}, sort_keys=True))


if __name__ == "__main__":
    main()
