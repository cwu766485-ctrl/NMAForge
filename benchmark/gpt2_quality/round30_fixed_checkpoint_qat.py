#!/usr/bin/env python3
"""Bounded Round 30 QAT replay from the frozen Round 27 FP32 checkpoints.

This script trains only from the manifest's disjoint train interval. It selects
no candidate on the test split; all frozen candidates are evaluated once on a
fixed, spaced test-window set for seed stability. Product Top qualification is
separate and is never inferred from the Python integer reference.
"""
from __future__ import annotations

import argparse
import copy
import csv
import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F

HERE = Path(__file__).resolve().parent
# benchmark/gpt2_quality -> repository root is parents[1].
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from train_h64_byte_lm import CONTEXT, H64ByteDecoder, VOCAB  # noqa: E402
from train_round24_integer_qat import (  # noqa: E402
    IntegerLayerNormQAT, export_package,
)
from round21_contract_ablation import CONTRACTS, infer as int_infer  # noqa: E402


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def sample_starts(lo: int, hi: int, count: int, seed: int) -> np.ndarray:
    last = hi - CONTEXT - 1
    if count <= 0 or last <= lo:
        raise ValueError(f"invalid split/window count: [{lo},{hi}), count={count}")
    starts = np.linspace(lo, last, count, dtype=np.int64)
    np.random.default_rng(seed).shuffle(starts)
    if len(np.unique(starts)) != count:
        raise ValueError("window sampler produced duplicate starts")
    return starts


def windows(raw: np.ndarray, starts: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    xs = np.stack([raw[int(s):int(s) + CONTEXT] for s in starts]).astype(np.int64)
    ys = np.stack([raw[int(s) + 1:int(s) + CONTEXT + 1] for s in starts]).astype(np.int64)
    return xs, ys


def metric(logits: np.ndarray, targets: np.ndarray) -> dict[str, float]:
    z = logits.astype(np.float64)
    z -= z.max(axis=-1, keepdims=True)
    lse = np.log(np.exp(z).sum(axis=-1))
    picked = np.take_along_axis(z, targets[..., None], axis=-1)[..., 0]
    ce = lse - picked
    return {"accuracy": float(np.mean(np.argmax(logits, axis=-1) == targets)),
            "cross_entropy_nats": float(ce.mean()), "perplexity": float(np.exp(ce.mean()))}


def torch_logits(model, xs: np.ndarray, batch: int = 8) -> np.ndarray:
    values = []
    model.eval()
    with torch.no_grad():
        for first in range(0, len(xs), batch):
            values.append(model(torch.from_numpy(xs[first:first + batch])).cpu().numpy())
    return np.concatenate(values, axis=0)


def int_logits(package: dict[str, np.ndarray], xs: np.ndarray, contract: dict) -> np.ndarray:
    out = []
    for i, row in enumerate(xs):
        logits, _ = int_infer(package, row.astype(int).tolist(), contract)
        out.append(logits)
        if (i + 1) % 64 == 0:
            # Contracts historically have no `name` field; the caller owns the
            # stable label so this diagnostic must not abort evaluation.
            print(f"INT_REFERENCE windows={i + 1}/{len(xs)} contract={contract.get('name', 'unnamed')}", flush=True)
    return np.asarray(out, dtype=np.int32)


def bigram_logits(train: np.ndarray, xs: np.ndarray) -> np.ndarray:
    counts = np.ones((VOCAB, VOCAB), dtype=np.float64)
    np.add.at(counts, (train[:-1], train[1:]), 1.0)
    p = counts / counts.sum(axis=1, keepdims=True)
    return np.log(p[xs])


TRACE_SCALES = {
    "embedding_position": ("embedding_position", 8),
    "ln1": ("ln1", 1), "q": ("q", 32), "k": ("k", 32), "v": ("v", 32),
    "scores": ("scores", 256), "attention": ("attention", 32),
    "projection": ("projection", 8), "residual1": ("residual1", 8),
    "ln2": ("ln2", 1), "up": ("up", 256), "gelu": ("gelu", 256),
    "gelu_i8": ("gelu_i8", 8), "down": ("down", 8),
    "residual2": ("residual2", 8),
}


def compare_trace(fake_trace: dict, int_trace: dict, samples: int) -> dict:
    stats: dict[str, dict[str, int]] = {}
    for li in range(4):
        prefix = f"l{li}."
        for fake_name, (ref_suffix, scale) in TRACE_SCALES.items():
            fake_key = prefix + fake_name
            ref_key = prefix + ref_suffix
            if fake_key not in fake_trace or ref_key not in int_trace:
                continue
            f = fake_trace[fake_key].detach().cpu().numpy()
            ref = np.asarray(int_trace[ref_key])
            if f.shape and f.shape[0] == 1:
                f = f[0]
            if fake_name == "scores" and ref.ndim == 3 and f.ndim == 4:
                pass
            q = np.rint(f.astype(np.float64) * scale).astype(np.int64)
            if q.shape != ref.shape:
                stats[fake_key] = {"shape_match": 0, "mismatch_elements": -1,
                                   "elements": int(q.size)}
                continue
            delta = q - ref.astype(np.int64)
            stats[fake_key] = {"shape_match": 1,
                               "mismatch_elements": int(np.count_nonzero(delta)),
                               "elements": int(delta.size),
                               "max_abs_error_codes": int(np.max(np.abs(delta))) if delta.size else 0}
    # ProductQAT exposes probabilities after Q15>>8 as signed Q7; the integer
    # trace stores Q15. Apply the physical saturating conversion before compare.
    for li in range(4):
        fk, ik = f"l{li}.probabilities", f"l{li}.probabilities_q15"
        if fk not in fake_trace or ik not in int_trace:
            continue
        f = fake_trace[fk].detach().cpu().numpy()[0]
        ref_q7 = np.clip(np.asarray(int_trace[ik], dtype=np.int64) >> 8, -128, 127)
        q = np.rint(f * 128.0).astype(np.int64)
        delta = q - ref_q7
        stats[f"l{li}.probabilities_q7"] = {
            "shape_match": int(q.shape == ref_q7.shape),
            "mismatch_elements": int(np.count_nonzero(delta)) if q.shape == ref_q7.shape else -1,
            "elements": int(q.size),
            "max_abs_error_codes": int(np.max(np.abs(delta))) if q.shape == ref_q7.shape and q.size else -1}
    for key in ("final_ln", "logits"):
        scale = 1 if key == "final_ln" else 32
        if key not in fake_trace or key not in int_trace:
            continue
        f = fake_trace[key].detach().cpu().numpy()[0]
        ref = np.asarray(int_trace[key])
        q = np.rint(f * scale).astype(np.int64)
        delta = q - ref.astype(np.int64)
        stats[key] = {"shape_match": int(q.shape == ref.shape),
                      "mismatch_elements": int(np.count_nonzero(delta)) if q.shape == ref.shape else -1,
                      "elements": int(q.size),
                      "max_abs_error_codes": int(np.max(np.abs(delta))) if q.shape == ref.shape and q.size else -1}
    return {"windows_sampled": samples, "nodes": stats,
            "all_shape_and_values_exact": all(x.get("shape_match") == 1 and
                x.get("mismatch_elements") == 0 for x in stats.values())}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt")
    ap.add_argument("--split-manifest", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round27_extended_train/corpus_split.json")
    ap.add_argument("--checkpoint-root", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round27_extended_train")
    ap.add_argument("--out-dir", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round30_qat")
    ap.add_argument("--qat-seeds", type=int, nargs="+", default=[20263021, 20263022, 20263023])
    ap.add_argument("--source-seeds", type=int, nargs="+", default=[20261221, 20261222, 20261223])
    ap.add_argument("--steps", type=int, default=200)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--lr", type=float, default=1e-5)
    ap.add_argument("--validation-windows", type=int, default=128)
    ap.add_argument("--test-windows", type=int, default=512)
    ap.add_argument("--trace-windows", type=int, default=8)
    args = ap.parse_args()
    if len(args.qat_seeds) != len(args.source_seeds) or not args.qat_seeds:
        raise ValueError("qat-seeds and source-seeds must have equal nonzero length")
    torch.set_num_threads(1)
    raw_bytes = args.corpus.read_bytes()
    raw = np.frombuffer(raw_bytes, dtype=np.uint8).copy()
    split = json.loads(args.split_manifest.read_text())
    corpus_hash = sha_bytes(raw_bytes)
    if split["corpus_sha256"] != corpus_hash:
        raise ValueError("corpus hash does not match frozen disjoint-split manifest")
    ranges = split["ranges_half_open"]
    train_lo, train_hi = ranges["train"]
    val_lo, val_hi = ranges["validation"]
    test_lo, test_hi = ranges["test"]
    if not (train_hi + 1 < val_lo and val_hi + 1 < test_lo):
        raise ValueError("split intervals overlap")
    train = raw[train_lo:train_hi]
    vx, vy = windows(raw, sample_starts(val_lo, val_hi, args.validation_windows, 20263010))
    tx, ty = windows(raw, sample_starts(test_lo, test_hi, args.test_windows, 20263011))
    val_starts = sample_starts(val_lo, val_hi, args.validation_windows, 20263010)
    test_starts = sample_starts(test_lo, test_hi, args.test_windows, 20263011)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    run = {"status": "SOFTWARE_QAT_EXPERIMENT_PRODUCT_TOP_NOT_RUN",
           "base_source_sha": __import__("subprocess").check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
           "corpus_sha256": corpus_hash, "split_manifest_sha256": sha_file(args.split_manifest),
           "split_ranges_half_open": ranges, "context": CONTEXT,
           "guard_bytes": split["guard_bytes_at_boundaries"],
           "train_target_bytes": int(len(train) - CONTEXT),
           "validation_windows": args.validation_windows, "test_windows": args.test_windows,
           "validation_starts_sha256": sha_bytes(val_starts.astype("<i8").tobytes()),
           "test_starts_sha256": sha_bytes(test_starts.astype("<i8").tobytes()),
           "qat_steps_per_seed": args.steps, "batch": args.batch, "learning_rate": args.lr,
           "seeds": [{"source_seed": int(source), "qat_seed": int(qat)}
                     for source, qat in zip(args.source_seeds, args.qat_seeds)],
           "tool_versions": {"torch": torch.__version__, "numpy": np.__version__,
              "python": sys.version.split()[0]}}
    (args.out_dir / "run_manifest.json").write_text(json.dumps(run, indent=2, sort_keys=True) + "\n")
    metric_rows: list[dict] = []
    frozen: list[dict] = []
    start_time = time.time()
    for source_seed, qat_seed in zip(args.source_seeds, args.qat_seeds):
        seed_dir = args.out_dir / f"source_{source_seed}_qat_{qat_seed}"
        seed_dir.mkdir(parents=True, exist_ok=True)
        source_manifest_path = args.checkpoint_root / f"seed_{source_seed}" / "manifest.json"
        source_manifest = json.loads(source_manifest_path.read_text())
        checkpoint = args.checkpoint_root / f"seed_{source_seed}" / "fp32_before_qat.pt"
        if sha_file(checkpoint) != source_manifest["fp32_checkpoint_sha256"]:
            raise ValueError(f"source checkpoint hash mismatch for {source_seed}")
        torch.manual_seed(qat_seed)
        model = H64ByteDecoder().cpu()
        ckpt = torch.load(checkpoint, map_location="cpu", weights_only=False)
        model.load_state_dict(ckpt["state_dict"])
        fp32_model = copy.deepcopy(model).eval()
        qat = IntegerLayerNormQAT(model)
        opt = torch.optim.AdamW(qat.parameters(), lr=args.lr, weight_decay=0.001)
        rng = np.random.default_rng(qat_seed)
        curve_path = seed_dir / "train_curve.csv"
        with curve_path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=["step", "train_ce"])
            writer.writeheader()
            qat.train()
            for step in range(args.steps):
                ix = rng.integers(train_lo, train_hi - CONTEXT - 1, size=args.batch)
                x = np.stack([raw[int(i):int(i) + CONTEXT] for i in ix]).astype(np.int64)
                y = np.stack([raw[int(i) + 1:int(i) + CONTEXT + 1] for i in ix]).astype(np.int64)
                logits = qat(torch.from_numpy(x))
                loss = F.cross_entropy(logits.reshape(-1, VOCAB), torch.from_numpy(y).reshape(-1))
                opt.zero_grad(set_to_none=True)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(qat.parameters(), 1.0)
                opt.step()
                if (step + 1) % 25 == 0 or step + 1 == args.steps:
                    writer.writerow({"step": step + 1, "train_ce": float(loss.detach())})
                    stream.flush()
                    print(f"QAT source={source_seed} seed={qat_seed} step={step+1}/{args.steps} ce={float(loss.detach()):.6f}", flush=True)
        package_path = export_package(model, seed_dir / "product_int8.npz")
        with np.load(package_path, allow_pickle=False) as f:
            package = {k: f[k].copy() for k in f.files}
        for li in range(4):
            package[f"l{li}.up_q8_8"] = package[f"l{li}.up"].copy()
        qat.eval()
        fp_val = metric(torch_logits(fp32_model, vx), vy)
        qat_float_val = metric(torch_logits(model, vx), vy)
        fake_logits_val = torch_logits(qat, vx)
        fake_val = metric(fake_logits_val, vy)
        val_aligned = int_logits(package, vx, CONTRACTS["residual_gelu_aligned"])
        int_aligned_val = metric(val_aligned.astype(np.float64) / 32.0, vy)
        bigram_val = metric(bigram_logits(train, vx), vy)
        val_logits = {"fp32": torch_logits(fp32_model, vx), "qat_float": torch_logits(model, vx),
                      "fake_quant": fake_logits_val, "product_int8": val_aligned / 32.0}
        val_agreements = {
            "qat_float_vs_fp32_top1": float(np.mean(np.argmax(val_logits["qat_float"], -1) == np.argmax(val_logits["fp32"], -1))),
            "fake_quant_vs_int8_top1": float(np.mean(np.argmax(val_logits["fake_quant"], -1) == np.argmax(val_logits["product_int8"], -1))),
            "int8_vs_fp32_top1": float(np.mean(np.argmax(val_logits["product_int8"], -1) == np.argmax(val_logits["fp32"], -1))),
        }
        state_path = seed_dir / "qat_float.pt"
        torch.save({"state_dict": model.state_dict(), "source_seed": source_seed,
                    "qat_seed": qat_seed, "qat_steps": args.steps,
                    "contract": "Round29_ProductQAT_with_IntegerLayerNormQAT"}, state_path)
        val = {"fp32": fp_val, "qat_float": qat_float_val, "fake_quant": fake_val,
               "product_int8_aligned": int_aligned_val, "bigram": bigram_val,
               "agreement": val_agreements}
        row = {"source_seed": source_seed, "qat_seed": qat_seed, "split": "validation"}
        for model_name, values in val.items():
            if isinstance(values, dict) and "accuracy" in values:
                row.update({f"{model_name}_{k}": v for k, v in values.items()})
        metric_rows.append(row)
        meta = {"source_seed": source_seed, "qat_seed": qat_seed, "source_checkpoint": str(checkpoint),
                "source_checkpoint_sha256": sha_file(checkpoint), "qat_checkpoint_sha256": sha_file(state_path),
                "package_sha256": sha_file(package_path), "train_curve_sha256": sha_file(curve_path),
                "validation_metrics": val, "training_steps": args.steps,
                "contract_ablation": {"frozen": "not selected on validation; evaluate frozen contract separately",
                                      "residual_gelu_aligned": val["product_int8_aligned"]},
                "product_top_status": "NOT_RUN"}
        (seed_dir / "manifest.json").write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
        frozen.append({"source_seed": source_seed, "qat_seed": qat_seed, "model": model,
                       "fp32": fp32_model, "qat": qat, "package": package,
                       "validation": val, "manifest": meta})
        print(f"FROZEN source={source_seed} qat={qat_seed} val_int8_acc={int_aligned_val['accuracy']:.6f} "
              f"val_int8_ce={int_aligned_val['cross_entropy_nats']:.5f}", flush=True)

    # Test is opened only after all candidate packages/checkpoints are frozen.
    # All candidates are evaluated once on identical spaced held-out windows.
    for item in frozen:
        source_seed, qat_seed = item["source_seed"], item["qat_seed"]
        model, fp32_model, qat, package = item["model"], item["fp32"], item["qat"], item["package"]
        fp = metric(torch_logits(fp32_model, tx), ty)
        qf = metric(torch_logits(model, tx), ty)
        fake_logits = torch_logits(qat, tx)
        fake = metric(fake_logits, ty)
        int_aligned = int_logits(package, tx, CONTRACTS["residual_gelu_aligned"])
        int_old = int_logits(package, tx, CONTRACTS["frozen"])
        aligned_m = metric(int_aligned.astype(np.float64) / 32.0, ty)
        old_m = metric(int_old.astype(np.float64) / 32.0, ty)
        bg = metric(bigram_logits(train, tx), ty)
        qat_float_test_logits = torch_logits(model, tx)
        fp32_test_logits = torch_logits(fp32_model, tx)
        agreements = {"qat_float_vs_fp32_top1": float(np.mean(np.argmax(qat_float_test_logits, -1) == np.argmax(fp32_test_logits, -1))),
                      "fake_quant_vs_int8_top1": float(np.mean(np.argmax(fake_logits, -1) == np.argmax(int_aligned, -1))),
                      "int8_vs_fp32_top1": float(np.mean(np.argmax(int_aligned, -1) == np.argmax(fp32_test_logits, -1)))}
        trace_stats = []
        for i in range(min(args.trace_windows, len(tx))):
            fake_logit, fake_trace = qat(torch.from_numpy(tx[i:i+1]), return_trace=True)
            int_logit, int_trace = int_infer(package, tx[i].astype(int).tolist(), CONTRACTS["residual_gelu_aligned"])
            trace_stats.append(compare_trace(fake_trace, int_trace, i + 1))
        mismatch_counts: dict[str, int] = {}
        for report in trace_stats:
            for node, stat in report["nodes"].items():
                mismatch_counts[node] = mismatch_counts.get(node, 0) + int(stat.get("mismatch_elements", -1) != 0)
        test = {"fp32": fp, "qat_float": qf, "fake_quant": fake,
                "product_int8_aligned": aligned_m, "product_int8_legacy_contract": old_m,
                "bigram": bg, "agreement": agreements,
                "trace_sample_windows": len(trace_stats),
                "trace_all_exact": all(x["all_shape_and_values_exact"] for x in trace_stats),
                "trace_window_node_mismatch_counts": mismatch_counts}
        item["manifest"]["test_metrics_once_frozen"] = test
        item["manifest"]["test_starts_sha256"] = sha_bytes(test_starts.astype("<i8").tobytes())
        (args.out_dir / f"source_{source_seed}_qat_{qat_seed}" / "manifest.json").write_text(
            json.dumps(item["manifest"], indent=2, sort_keys=True) + "\n")
        row = {"source_seed": source_seed, "qat_seed": qat_seed, "split": "test"}
        for model_name, values in test.items():
            if isinstance(values, dict) and "accuracy" in values:
                row.update({f"{model_name}_{k}": v for k, v in values.items()})
        metric_rows.append(row)
        print(f"TEST source={source_seed} qat={qat_seed} int8_acc={aligned_m['accuracy']:.6f} "
              f"bigram={bg['accuracy']:.6f} fake_trace_exact={test['trace_all_exact']}", flush=True)

    if metric_rows:
        fields = sorted({k for r in metric_rows for k in r})
        with (args.out_dir / "round30_qat_metrics.csv").open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=fields)
            writer.writeheader(); writer.writerows(metric_rows)
    run["elapsed_seconds"] = time.time() - start_time
    run["candidates"] = [{"source_seed": x["source_seed"], "qat_seed": x["qat_seed"],
                          "package_sha256": x["manifest"]["package_sha256"],
                          "validation_int8_accuracy": x["validation"]["product_int8_aligned"]["accuracy"],
                          "test_int8_accuracy": x["manifest"]["test_metrics_once_frozen"]["product_int8_aligned"]["accuracy"]}
                         for x in frozen]
    best = max(frozen, key=lambda x: (x["validation"]["product_int8_aligned"]["accuracy"],
                                    -x["validation"]["product_int8_aligned"]["cross_entropy_nats"]))
    run["validation_selected_candidate"] = {"source_seed": best["source_seed"], "qat_seed": best["qat_seed"],
                                             "package_sha256": best["manifest"]["package_sha256"],
                                             "rule": "highest validation product-int8 accuracy; CE tie-break"}
    run["test_used_for_selection"] = False
    (args.out_dir / "run_manifest.json").write_text(json.dumps(run, indent=2, sort_keys=True) + "\n")
    print("ROUND30_QAT_DONE " + json.dumps(run, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
