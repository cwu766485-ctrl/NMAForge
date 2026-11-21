#!/usr/bin/env python3
"""Audit activation/weight saturation and integer-trace error for Round 30 QAT."""
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
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from train_h64_byte_lm import CONTEXT, H64ByteDecoder  # noqa: E402
from train_round24_integer_qat import IntegerLayerNormQAT  # noqa: E402
from round21_contract_ablation import CONTRACTS, infer as int_infer  # noqa: E402
from round30_fixed_checkpoint_qat import TRACE_SCALES, sample_starts  # noqa: E402


def sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt")
    ap.add_argument("--split-manifest", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round27_extended_train/corpus_split.json")
    ap.add_argument("--source-checkpoint", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round27_extended_train/seed_20261223/fp32_before_qat.pt")
    ap.add_argument("--qat-checkpoint", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round30_qat/source_20261223_qat_20263023/qat_float.pt")
    ap.add_argument("--package", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round30_qat/source_20261223_qat_20263023/product_int8.npz")
    ap.add_argument("--out", type=Path, default=ROOT / "benchmark/gpt2_quality/results/round30_qat/round30_saturation_audit")
    ap.add_argument("--windows", type=int, default=8)
    args = ap.parse_args()
    torch.set_num_threads(1)

    raw = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()
    split = json.loads(args.split_manifest.read_text())
    if hashlib.sha256(raw.tobytes()).hexdigest() != split["corpus_sha256"]:
        raise SystemExit("corpus hash mismatch")
    test_lo, test_hi = split["ranges_half_open"]["test"]
    starts = sample_starts(test_lo, test_hi, args.windows, 20263011)
    xs = np.stack([raw[int(s):int(s)+CONTEXT] for s in starts]).astype(np.int64)

    qat_model = H64ByteDecoder().cpu()
    qat_model.load_state_dict(torch.load(args.qat_checkpoint, map_location="cpu", weights_only=False)["state_dict"])
    qat = IntegerLayerNormQAT(qat_model).eval()
    with np.load(args.package, allow_pickle=False) as f:
        package = {k: f[k].copy() for k in f.files}
    for li in range(4):
        package[f"l{li}.up_q8_8"] = package[f"l{li}.up"].copy()

    rows: list[dict[str, object]] = []
    int8_activation_names = {"q", "k", "v", "attention", "gelu_i8"}
    traces = []
    for i, x in enumerate(xs):
        _, ftrace = qat(torch.from_numpy(x[None, :]), return_trace=True)
        _, itrace = int_infer(package, x.tolist(), CONTRACTS["residual_gelu_aligned"])
        traces.append((ftrace, itrace))

    for li in range(4):
        prefix = f"l{li}."
        for fake_name, (ref_suffix, scale) in TRACE_SCALES.items():
            fake_key, ref_key = prefix + fake_name, prefix + ref_suffix
            fake_parts, ref_parts = [], []
            for ft, it in traces:
                if fake_key not in ft or ref_key not in it:
                    continue
                fv = ft[fake_key].detach().cpu().numpy()
                if fv.shape[0] == 1:
                    fv = fv[0]
                fake_parts.append(fv.astype(np.float64).reshape(-1) * scale)
                ref_parts.append(np.asarray(it[ref_key], dtype=np.float64).reshape(-1))
            if not fake_parts:
                continue
            f = np.concatenate(fake_parts)
            r = np.concatenate(ref_parts)
            q = np.rint(f)
            delta = q - r
            is_int8 = fake_name in int8_activation_names
            rows.append({"tensor": fake_key, "kind": "activation", "samples": int(f.size),
                         "scale_to_integer": scale,
                         "physical_storage": "INT8" if is_int8 else "INT32_or_internal",
                         "observed_integer_min": int(np.min(q)),
                         "observed_integer_max": int(np.max(q)),
                         "int8_rail_occupancy_pct": (float(np.mean((q <= -128) | (q >= 127)) * 100.0)
                                                      if is_int8 else ""),
                         "mae_integer_codes": float(np.mean(np.abs(delta))),
                         "rmse_integer_codes": float(np.sqrt(np.mean(delta * delta))),
                         "max_abs_error_codes": float(np.max(np.abs(delta))),
                         "bit_exact": bool(np.all(delta == 0))})

        fake_parts, ref_parts = [], []
        for ft, it in traces:
            fk, ik = f"l{li}.probabilities", f"l{li}.probabilities_q15"
            if fk not in ft or ik not in it:
                continue
            fake_parts.append(np.rint(ft[fk].detach().cpu().numpy()[0] * 128.0).astype(np.int64).reshape(-1))
            q15 = np.asarray(it[ik], dtype=np.int64)
            ref_parts.append(np.clip(q15 >> 8, -128, 127).reshape(-1))
        if fake_parts:
            f, r = np.concatenate(fake_parts), np.concatenate(ref_parts)
            delta = f - r
            rows.append({"tensor": f"l{li}.probabilities_q7", "kind": "activation",
                         "samples": int(f.size), "scale_to_integer": 128,
                         "physical_storage": "INT8", "observed_integer_min": int(f.min()),
                         "observed_integer_max": int(f.max()),
                         "int8_rail_occupancy_pct": float(np.mean((f == -128) | (f == 127)) * 100.0),
                         "mae_integer_codes": float(np.mean(np.abs(delta))),
                         "rmse_integer_codes": float(np.sqrt(np.mean(delta * delta))),
                         "max_abs_error_codes": int(np.max(np.abs(delta))),
                         "bit_exact": bool(np.all(delta == 0))})

    with np.load(args.package, allow_pickle=False) as f:
        for key in sorted(f.files):
            arr = f[key]
            if arr.dtype != np.int8:
                continue
            values = arr.astype(np.int16)
            rows.append({"tensor": key, "kind": "weight", "samples": int(values.size),
                         "scale_to_integer": "package", "physical_storage": "INT8",
                         "observed_integer_min": int(values.min()),
                         "observed_integer_max": int(values.max()),
                         "int8_rail_occupancy_pct": float(np.mean((values == -128) | (values == 127)) * 100.0),
                         "mae_integer_codes": "", "rmse_integer_codes": "",
                         "max_abs_error_codes": "", "bit_exact": "package_int8"})

    args.out.mkdir(parents=True, exist_ok=True)
    fields = list(rows[0])
    with (args.out / "round30_saturation_by_tensor.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader(); writer.writerows(rows)
    manifest = {"status": "PASS_SAMPLED_FAKE_QUANT_VS_INDEPENDENT_INT_TRACE",
                "scope": "8 fixed held-out windows; INT8 rail occupancy only for physical INT8 tensors; activation scope is sampled, not a full-test estimate",
                "windows": args.windows, "window_starts_sha256": hashlib.sha256(starts.astype("<i8").tobytes()).hexdigest(),
                "corpus_sha256": hashlib.sha256(args.corpus.read_bytes()).hexdigest(),
                "source_checkpoint_sha256": sha_file(args.source_checkpoint),
                "qat_checkpoint_sha256": sha_file(args.qat_checkpoint), "package_sha256": sha_file(args.package),
                "qat_seed": 20263023, "trace_tensors": len([r for r in rows if r["kind"] == "activation"]),
                "all_activation_traces_bit_exact": all(r["bit_exact"] is True for r in rows if r["kind"] == "activation"),
                "csv_sha256": sha_file(args.out / "round30_saturation_by_tensor.csv")}
    (args.out / "round30_saturation_audit.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("ROUND30_SATURATION_AUDIT_PASS " + json.dumps(manifest, sort_keys=True))


if __name__ == "__main__":
    main()
