#!/usr/bin/env python3
"""Round 27: train/evaluate H64 Product-QAT with corpus-disjoint byte splits.

The corpus is split by raw byte ranges before sampling windows. CONTEXT bytes
are excluded at both boundaries so no sample crosses a partition. Training,
validation and final test are disjoint source intervals. All candidate seeds
and packages are frozen before test metrics are emitted.
"""
from __future__ import annotations

import argparse
import copy
import csv
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from train_h64_byte_lm import CONTEXT, H64ByteDecoder, VOCAB  # noqa: E402
from train_round24_integer_qat import (  # noqa: E402
    IntegerLayerNormQAT, export_package, windows as make_windows,
)
from round21_contract_ablation import CONTRACTS, infer as int_infer  # noqa: E402


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def metrics(logits: np.ndarray, targets: np.ndarray) -> dict[str, float]:
    z = logits.astype(np.float64)
    z -= z.max(axis=-1, keepdims=True)
    lse = np.log(np.exp(z).sum(axis=-1))
    selected = np.take_along_axis(z, targets[..., None], axis=-1)[..., 0]
    ce = lse - selected
    return {"accuracy": float(np.mean(np.argmax(logits, axis=-1) == targets)),
            "cross_entropy_nats": float(ce.mean()),
            "perplexity": float(np.exp(ce.mean()))}


def get_windows(raw: np.ndarray, lo: int, hi: int, count: int, seed: int):
    # hi is the exclusive partition boundary; reserve enough suffix for target.
    first = lo + CONTEXT
    last_start = hi - CONTEXT - 1
    if last_start <= first:
        raise ValueError("split too small for context guard")
    rng = np.random.default_rng(seed)
    starts = np.linspace(first, last_start, count, dtype=np.int64)
    # Apply a fixed random permutation so the audit is deterministic but not
    # ordered by corpus position when batch-evaluated.
    rng.shuffle(starts)
    xs, ys = make_windows(raw, starts)
    return xs, ys, starts


def bigram(train: np.ndarray, xs: np.ndarray, ys: np.ndarray) -> tuple[dict, np.ndarray]:
    counts = np.ones((VOCAB, VOCAB), dtype=np.float64)
    np.add.at(counts, (train[:-1], train[1:]), 1.0)
    prob = counts / counts.sum(axis=1, keepdims=True)
    # For each context position, predict the next byte from the previous byte.
    previous = xs
    target = ys
    selected = prob[previous, target]
    logits = np.log(prob[previous])
    return metrics(logits, target), logits


def torch_logits(model, xs: np.ndarray, batch: int = 16) -> np.ndarray:
    result = []
    model.eval()
    with torch.no_grad():
        for start in range(0, len(xs), batch):
            result.append(model(torch.from_numpy(xs[start:start + batch])).cpu().numpy())
    return np.concatenate(result, axis=0)


def integer_logits(package: dict[str, np.ndarray], xs: np.ndarray) -> np.ndarray:
    result = []
    contract = CONTRACTS["residual_gelu_aligned"]
    for index, row in enumerate(xs):
        logits, _ = int_infer(package, row.astype(int).tolist(), contract)
        result.append(logits)
        if (index + 1) % 32 == 0:
            print(f"INT_EVAL rows={index + 1}/{len(xs)}", flush=True)
    return np.asarray(result, dtype=np.int32)


def evaluate_split(fp32_model, qat_float_model, fake_quant_model,
                   package, xs, ys, train_bytes):
    fp_logits = torch_logits(fp32_model, xs)
    qat_float_logits = torch_logits(qat_float_model, xs)
    fake_logits = torch_logits(fake_quant_model, xs)
    int_values = integer_logits(package, xs)
    # Product LM-head is Q5; dividing by 32 preserves argmax and restores the
    # declared real-valued scale for CE/PPL.
    int_real = int_values.astype(np.float64) / 32.0
    fp = metrics(fp_logits, ys)
    qat_float = metrics(qat_float_logits, ys)
    fake = metrics(fake_logits, ys)
    quant = metrics(int_real, ys)
    bg, bg_logits = bigram(train_bytes, xs, ys)
    quant["fp32_top1_agreement"] = float(np.mean(
        np.argmax(int_values, axis=-1) == np.argmax(fp_logits, axis=-1)))
    qat_float["fp32_top1_agreement"] = float(np.mean(
        np.argmax(qat_float_logits, axis=-1) == np.argmax(fp_logits, axis=-1)))
    fake["fp32_top1_agreement"] = float(np.mean(
        np.argmax(fake_logits, axis=-1) == np.argmax(qat_float_logits, axis=-1)))
    return {"fp32": fp, "qat_float": qat_float, "fake_quant": fake,
            "product_int8": quant, "bigram": bg}


def token_hist(data: np.ndarray) -> list[int]:
    return np.bincount(data.astype(np.int64), minlength=VOCAB).tolist()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--seeds", type=int, nargs="+", default=[20261201, 20261202, 20261203])
    ap.add_argument("--fp-steps", type=int, default=500)
    ap.add_argument("--qat-steps", type=int, default=300)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--validation-windows", type=int, default=128)
    ap.add_argument("--test-windows", type=int, default=512)
    args = ap.parse_args()
    torch.set_num_threads(1)
    raw_bytes = args.corpus.read_bytes()
    raw = np.frombuffer(raw_bytes, dtype=np.uint8).copy()
    n = len(raw)
    train_end, val_end = int(n * 0.70), int(n * 0.85)
    # Keep CONTEXT+1 guard bytes around boundaries; no scored window can draw
    # context or target bytes from another partition.
    ranges = {"train": (0, train_end - CONTEXT - 1),
              "validation": (train_end + CONTEXT + 1, val_end - CONTEXT - 1),
              "test": (val_end + CONTEXT + 1, n)}
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "corpus_split.json").write_text(json.dumps({
        "corpus_sha256": sha_bytes(raw_bytes), "raw_bytes": n,
        "context": CONTEXT, "split_fraction": [0.70, 0.15, 0.15],
        "ranges_half_open": ranges,
        "guard_bytes_at_boundaries": CONTEXT + 1,
        "token_histograms": {
            "train": token_hist(raw[ranges["train"][0]:ranges["train"][1]]),
            "validation": token_hist(raw[ranges["validation"][0]:ranges["validation"][1]]),
            "test": token_hist(raw[ranges["test"][0]:ranges["test"][1]])},
        "status": "DISJOINT_SOURCE_INTERVALS_NO_CROSS_BOUNDARY_WINDOWS"
    }, indent=2, sort_keys=True) + "\n")

    vx, vy, vstarts = get_windows(raw, *ranges["validation"],
                                   args.validation_windows, 20261210)
    tx, ty, tstarts = get_windows(raw, *ranges["test"], args.test_windows, 20261211)
    train_bytes = raw[ranges["train"][0]:ranges["train"][1]]
    rows: list[dict] = []
    candidates = []
    wall_start = time.time()
    for seed in args.seeds:
        seed_dir = args.out_dir / f"seed_{seed}"
        seed_dir.mkdir(parents=True, exist_ok=True)
        torch.manual_seed(seed)
        rng = np.random.default_rng(seed)
        model = H64ByteDecoder().cpu()
        opt = torch.optim.AdamW(model.parameters(), lr=3e-4, weight_decay=0.01)
        model.train()
        for step in range(args.fp_steps):
            starts = rng.integers(0, len(train_bytes) - CONTEXT - 1, size=args.batch)
            x, y = make_windows(train_bytes, starts)
            xt, yt = torch.from_numpy(x), torch.from_numpy(y)
            logits = model(xt)
            loss = F.cross_entropy(logits.reshape(-1, VOCAB), yt.reshape(-1))
            opt.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            opt.step()
            if (step + 1) % 100 == 0 or step + 1 == args.fp_steps:
                print(f"seed={seed} FP32 step={step+1} train_ce={loss.item():.5f}", flush=True)
        fp_checkpoint = seed_dir / "fp32_before_qat.pt"
        torch.save({"state_dict": model.state_dict(), "seed": seed,
                    "fp_steps": args.fp_steps, "corpus_sha256": sha_bytes(raw_bytes)}, fp_checkpoint)
        fp32_model = copy.deepcopy(model).eval()
        qat = IntegerLayerNormQAT(model)
        qopt = torch.optim.AdamW(qat.parameters(), lr=5e-5, weight_decay=0.001)
        qat.train()
        for step in range(args.qat_steps):
            starts = rng.integers(0, len(train_bytes) - CONTEXT - 1, size=args.batch)
            x, y = make_windows(train_bytes, starts)
            xt, yt = torch.from_numpy(x), torch.from_numpy(y)
            logits = qat(xt)
            loss = F.cross_entropy(logits.reshape(-1, VOCAB), yt.reshape(-1))
            qopt.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(qat.parameters(), 1.0)
            qopt.step()
            if (step + 1) % 100 == 0 or step + 1 == args.qat_steps:
                print(f"seed={seed} QAT step={step+1} train_ce={loss.item():.5f}", flush=True)
        package_path = export_package(model, seed_dir / "product_int8.npz")
        with np.load(package_path, allow_pickle=False) as z:
            package = {key: z[key].copy() for key in z.files}
        # Keep the software helper's explicit alias, matching the R25 Top map.
        for layer in range(4):
            package[f"l{layer}.up_q8_8"] = package[f"l{layer}.up"].copy()
        qat_checkpoint = seed_dir / "qat_float.pt"
        torch.save({"state_dict": model.state_dict(), "seed": seed,
                    "fp_steps": args.fp_steps, "qat_steps": args.qat_steps}, qat_checkpoint)
        validation = evaluate_split(fp32_model, model, qat, package,
                                    vx, vy, train_bytes)
        manifest = {
            "seed": seed, "fp_steps": args.fp_steps, "qat_steps": args.qat_steps,
            "batch": args.batch, "corpus_sha256": sha_bytes(raw_bytes),
            "fp32_checkpoint_sha256": sha_file(fp_checkpoint),
            "qat_checkpoint_sha256": sha_file(qat_checkpoint),
            "package_sha256": sha_file(package_path),
            "validation_start_sha256": sha_bytes(vstarts.astype("<i8").tobytes()),
            "validation_metrics": validation,
            "contract": "H64/L4/4H/FFN256/ProductQAT/IntegerLayerNormQAT/residual_gelu_aligned",
        }
        (seed_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        candidates.append((seed, fp32_model, model, qat, package, manifest))
        print(f"FROZEN_CANDIDATE seed={seed} package_sha256={manifest['package_sha256']} "
              f"val_int8_acc={validation['product_int8']['accuracy']:.6f}", flush=True)

    # Candidates are frozen before touching the final test split. Evaluate every
    # frozen candidate once for seed-variance reporting; do not tune afterward.
    for seed, fp32_model, qat_float_model, fake_quant_model, package, manifest in candidates:
        test_metrics = evaluate_split(fp32_model, qat_float_model, fake_quant_model,
                                      package, tx, ty, train_bytes)
        manifest["test_metrics"] = test_metrics
        manifest["test_start_sha256"] = sha_bytes(tstarts.astype("<i8").tobytes())
        (args.out_dir / f"seed_{seed}" / "manifest.json").write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        for stage, metric_row in test_metrics.items():
            rows.append({"seed": seed, "stage": stage, **metric_row})
        print(f"TEST_FROZEN seed={seed} int8_acc={test_metrics['product_int8']['accuracy']:.6f} "
              f"bigram_acc={test_metrics['bigram']['accuracy']:.6f}", flush=True)

    csv_path = args.out_dir / "round27_clean_split_metrics.csv"
    keys = sorted({key for row in rows for key in row})
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=keys)
        writer.writeheader(); writer.writerows(rows)
    summary = {
        "status": "SOFTWARE_CLEAN_SPLIT_EXPERIMENT_COMPLETE_PRODUCT_TOP_QUALIFICATION_REQUIRED",
        "corpus_sha256": sha_bytes(raw_bytes), "seeds": args.seeds,
        "train_steps": args.fp_steps, "qat_steps": args.qat_steps,
        "validation_windows": args.validation_windows, "test_windows": args.test_windows,
        "test_sample_sha256": sha_bytes(tstarts.astype("<i8").tobytes()),
        "test_metrics_by_seed": [c[5]["test_metrics"] for c in candidates],
        "wall_seconds": time.time() - wall_start,
        "files": {"split": "corpus_split.json", "metrics": csv_path.name},
        "limitation": "Tiny Shakespeare byte-level H64 research model; not a pretrained GPT-2 checkpoint.",
    }
    (args.out_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print("ROUND27_CLEAN_SPLIT_DONE " + json.dumps(summary, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
