#!/usr/bin/env python3
"""Bounded software-only H64 context-128 quality experiment.

Starts from the fixed Round 27 H64 FP32 checkpoint, interpolates its learned
position table, fine-tunes one fixed seed on the train split, and evaluates a
single frozen candidate on the independent validation/test split. It does not
generate Product descriptors and cannot qualify RTL context-128 support.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from train_h64_byte_lm import CONTEXT, H64ByteDecoder, VOCAB  # noqa: E402
from round30_fixed_checkpoint_qat import metric, sha_bytes, sha_file  # noqa: E402


def make_starts(lo: int, hi: int, length: int, count: int) -> np.ndarray:
    last = hi - length - 1
    if last <= lo or count <= 0:
        raise ValueError("split too small for requested windows")
    starts = np.linspace(lo, last, count, dtype=np.int64)
    if len(np.unique(starts)) != count:
        raise ValueError("duplicate evaluation start")
    return starts


def batched_logits(model, x: np.ndarray, batch: int = 2) -> np.ndarray:
    out = []
    model.eval()
    with torch.no_grad():
        for i in range(0, len(x), batch):
            out.append(model(torch.from_numpy(x[i:i + batch])).cpu().numpy())
    return np.concatenate(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt")
    ap.add_argument("--split-manifest", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round27_extended_train/corpus_split.json")
    ap.add_argument("--checkpoint", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round27_extended_train/seed_20261223/fp32_before_qat.pt")
    ap.add_argument("--out", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round30_context128")
    ap.add_argument("--seed", type=int, default=20263028)
    ap.add_argument("--steps", type=int, default=200)
    ap.add_argument("--batch", type=int, default=2)
    ap.add_argument("--validation-windows", type=int, default=64)
    ap.add_argument("--test-windows", type=int, default=128)
    args = ap.parse_args()
    torch.set_num_threads(1)
    torch.manual_seed(args.seed)
    rng = np.random.default_rng(args.seed)
    raw_bytes = args.corpus.read_bytes()
    raw = np.frombuffer(raw_bytes, dtype=np.uint8).copy()
    split = json.loads(args.split_manifest.read_text())
    corpus_hash = sha_bytes(raw_bytes)
    if split["corpus_sha256"] != corpus_hash:
        raise SystemExit("corpus hash mismatch")
    train_lo, train_hi = split["ranges_half_open"]["train"]
    val_lo, val_hi = split["ranges_half_open"]["validation"]
    test_lo, test_hi = split["ranges_half_open"]["test"]

    checkpoint_data = torch.load(args.checkpoint, map_location="cpu", weights_only=False)
    source = H64ByteDecoder().cpu()
    source.load_state_dict(checkpoint_data["state_dict"])
    long_model = H64ByteDecoder().cpu()
    long_model.position = nn.Embedding(128, 64)
    state = checkpoint_data["state_dict"]
    long_state = {k: v for k, v in state.items() if k != "position.weight"}
    long_model.load_state_dict(long_state, strict=False)
    old_pos = state["position.weight"].float().T.unsqueeze(0)
    with torch.no_grad():
        long_model.position.weight.copy_(F.interpolate(old_pos, size=128, mode="linear", align_corners=True)[0].T)

    optimizer = torch.optim.AdamW(long_model.parameters(), lr=2e-5, weight_decay=0.001)
    curve = []
    started = time.time()
    long_model.train()
    for step in range(args.steps):
        starts = rng.integers(train_lo, train_hi - 128 - 1, size=args.batch)
        x = np.stack([raw[int(s):int(s) + 128] for s in starts]).astype(np.int64)
        y = np.stack([raw[int(s) + 1:int(s) + 129] for s in starts]).astype(np.int64)
        logits = long_model(torch.from_numpy(x))
        loss = F.cross_entropy(logits.reshape(-1, VOCAB), torch.from_numpy(y).reshape(-1))
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(long_model.parameters(), 1.0)
        optimizer.step()
        if (step + 1) % 25 == 0 or step + 1 == args.steps:
            curve.append({"step": step + 1, "train_ce": float(loss.detach())})
            print(f"CONTEXT128 seed={args.seed} step={step+1}/{args.steps} train_ce={float(loss.detach()):.5f}", flush=True)

    # Same target positions, sampled from the same long windows: compare the
    # final 16 predictions where both models receive causally valid context.
    val_starts = make_starts(val_lo, val_hi, 128, args.validation_windows)
    test_starts = make_starts(test_lo, test_hi, 128, args.test_windows)

    def evaluate(starts: np.ndarray) -> dict:
        x128 = np.stack([raw[int(s):int(s) + 128] for s in starts]).astype(np.int64)
        y128 = np.stack([raw[int(s) + 1:int(s) + 129] for s in starts]).astype(np.int64)
        short_x = x128[:, -CONTEXT:]
        short_y = y128[:, -CONTEXT:]
        long_logits = batched_logits(long_model, x128)[:, -CONTEXT:]
        short_logits = batched_logits(source, short_x)
        bigram = np.ones((VOCAB, VOCAB), dtype=np.float64)
        tr = raw[train_lo:train_hi]
        np.add.at(bigram, (tr[:-1], tr[1:]), 1.0)
        bigram /= bigram.sum(axis=1, keepdims=True)
        bg_logits = np.log(bigram[x128[:, -CONTEXT:]])
        return {"context16_checkpoint": metric(short_logits, short_y),
                "context128_finetuned": metric(long_logits, short_y),
                "bigram": metric(bg_logits, short_y),
                "context128_vs_context16_top1_agreement": float(np.mean(
                    np.argmax(long_logits, -1) == np.argmax(short_logits, -1)))}

    val = evaluate(val_starts)
    # This single fixed candidate is frozen before the independent test is read.
    args.out.mkdir(parents=True, exist_ok=True)
    ckpt_path = args.out / "h64_context128_fp32.pt"
    torch.save({"state_dict": long_model.state_dict(), "seed": args.seed,
                "steps": args.steps, "context": 128, "source_checkpoint_sha256": sha_file(args.checkpoint),
                "corpus_sha256": corpus_hash}, ckpt_path)
    test = evaluate(test_starts)
    with (args.out / "train_curve.csv").open("w", encoding="utf-8") as stream:
        stream.write("step,train_ce\n")
        for row in curve:
            stream.write(f"{row['step']},{row['train_ce']:.9f}\n")
    params = sum(p.numel() for p in long_model.parameters())
    manifest = {"status": "SOFTWARE_ONLY_CONTEXT128_EXPLORATORY_NO_RTL_CLAIM",
                "architecture": {"hidden": 64, "heads": 4, "layers": 4, "ffn": 256,
                                 "context": 128, "vocab": 256},
                "seed": args.seed, "steps": args.steps, "batch": args.batch,
                "optimizer": "AdamW lr=2e-5 weight_decay=0.001; fine-tune from fixed H64 context16 FP32 checkpoint",
                "position_init": "linear interpolation from learned 16-row source table to 128 rows",
                "source_checkpoint_sha256": sha_file(args.checkpoint), "checkpoint_sha256": sha_file(ckpt_path),
                "corpus_sha256": corpus_hash, "split_manifest_sha256": sha_file(args.split_manifest),
                "split_ranges_half_open": split["ranges_half_open"],
                "validation_starts_sha256": sha_bytes(val_starts.astype("<i8").tobytes()),
                "test_starts_sha256": sha_bytes(test_starts.astype("<i8").tobytes()),
                "evaluation": "common target positions at final 16 bytes of each held-out 128-byte window",
                "validation_metrics": val, "test_metrics_once_frozen": test,
                "test_used_for_selection": False,
                "parameters": params,
                "estimated_int8_weight_bytes": 225792,
                "kv_cache_bytes_context128": 2 * 4 * 64 * 128,
                "product_rtl_context128": "NOT_RUN; descriptor/ABI/address/queue support unqualified",
                "spad_peak_live": "NOT_ESTIMATED; requires Product Runtime and lifetime plan",
                "descriptor_count": "NOT_ESTIMATED; requires Product Mapper support",
                "estimated_latency": "NOT_ESTIMATED; no Product Top run",
                "elapsed_seconds": time.time() - started,
                "tool_versions": {"python": sys.version.split()[0], "torch": torch.__version__, "numpy": np.__version__}}
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("ROUND30_CONTEXT128_SOFTWARE_DONE " + json.dumps(manifest, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
