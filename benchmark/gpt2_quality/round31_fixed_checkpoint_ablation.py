#!/usr/bin/env python3
"""Round 31 fixed-checkpoint validation-only integerization ablation.

This runner deliberately never opens the held-out test range. It evaluates the
same trained checkpoint and the same spaced validation windows for all
software contracts, and emits per-tensor numerical/range diagnostics.
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
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from round21_contract_ablation import CONTRACTS, fp_trace, infer  # noqa: E402
from round30_fixed_checkpoint_qat import (  # noqa: E402
    bigram_logits, metric, sample_starts, windows,
)
from train_h64_byte_lm import CONTEXT, H64ByteDecoder  # noqa: E402
from train_round24_integer_qat import IntegerLayerNormQAT  # noqa: E402


SCALES = {
    "embedding_position": 8, "ln1": 1, "q": 32, "k": 32, "v": 32,
    "scores": 256, "probabilities_q15": 32768, "attention": 32,
    "projection": 8, "residual1": 8, "ln2": 1, "up": 256,
    "gelu": 256, "gelu_i8": 8, "down": 8, "residual2": 8,
    "final_ln": 1, "logits": 32,
}
INT8_NAMES = {"q", "k", "v", "attention", "gelu_i8"}

# Storage width is part of the tensor contract.  Several INT8 tensors are held
# in int32 NumPy arrays by the software reference, while some int32 accumulators
# happen to have values inside the INT8 numeric range.  Never infer storage
# width from observed extrema.
TENSOR_FORMATS = {
    "embedding_position": (32, True),
    "ln1": (32, True), "ln2": (32, True), "final_ln": (32, True),
    "q": (8, True), "k": (8, True), "v": (8, True),
    "scores": (32, True), "probabilities_q15": (32, False),
    "attention": (8, True), "projection": (32, True),
    "residual1": (32, True), "up": (32, True), "gelu": (32, True),
    "gelu_i8": (8, True), "down": (32, True), "residual2": (32, True),
    "logits": (32, True),
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_state(path: Path) -> dict:
    value = torch.load(path, map_location="cpu", weights_only=False)
    return value["state_dict"]


def stats(reference: np.ndarray, integer: np.ndarray, scale: float,
          tensor_name: str, scale_semantics_valid: bool) -> dict:
    ref = np.asarray(reference, dtype=np.float64).reshape(-1)
    raw = np.asarray(integer).reshape(-1)
    got = raw.astype(np.float64) / scale
    delta = got - ref
    dot = float(np.dot(ref, got))
    denom = float(np.linalg.norm(ref) * np.linalg.norm(got))
    bits, signed = TENSOR_FORMATS.get(tensor_name, (32, True))
    out = {
        "elements": int(ref.size),
        "logical_storage": ("int%d" % bits) if signed else ("uint%d" % bits),
        "logical_storage_bits": bits,
        "signed": signed,
        "python_container_dtype": str(raw.dtype),
        "declared_real_units_per_code": float(scale),
        "scale_semantics_valid_for_contract": bool(scale_semantics_valid),
        "reference_min": float(ref.min()), "reference_max": float(ref.max()),
        "integer_code_min": int(raw.min()), "integer_code_max": int(raw.max()),
        "integer_dequant_min": float(got.min()), "integer_dequant_max": float(got.max()),
        "mae": float(np.mean(np.abs(delta))),
        "rmse": float(np.sqrt(np.mean(delta * delta))),
        "max_abs_error": float(np.max(np.abs(delta))),
        "cosine_similarity": dot / denom if denom else (1.0 if not ref.size else 0.0),
        "zero_ratio": float(np.mean(raw == 0)),
    }
    if bits == 8 and signed:
        # The trace exposes post-clip codes, not each pre-clip accumulator.
        # Endpoint occupancy is therefore reported as a rail-code fraction,
        # not mislabeled as a true saturation-event rate.
        out["clip_event_ratio"] = None
        out["rail_code_ratio"] = float(np.mean((raw == -128) | (raw == 127)))
        hist, _ = np.histogram(raw.astype(np.int16), bins=np.arange(-128, 130))
        out["histogram_code_bins"] = hist.astype(int).tolist()
        out["histogram_code_edges"] = list(range(-128, 129))
    else:
        out["clip_event_ratio"] = None
        out["rail_code_ratio"] = (float(np.mean((raw == -(1 << 31)) | (raw == (1 << 31) - 1)))
                                  if bits == 32 and signed else None)
        hist, edges = np.histogram(got, bins=64)
        out["histogram_code_bins"] = hist.astype(int).tolist()
        out["histogram_code_edges"] = (edges * scale).astype(float).tolist()
    return out


def fp_layer_from(model: H64ByteDecoder, x: torch.Tensor, first_layer: int) -> torch.Tensor:
    """Continue the decoder in FP32 from an already materialized residual."""
    batch, length, _ = x.shape
    mask = torch.triu(torch.ones(length, length, dtype=torch.bool), diagonal=1)
    with torch.no_grad():
        for layer in model.layers[first_layer:]:
            n1 = layer["ln1"](x)
            q = layer["q"](n1).view(batch, length, 4, 16).transpose(1, 2)
            k = layer["k"](n1).view(batch, length, 4, 16).transpose(1, 2)
            v = layer["v"](n1).view(batch, length, 4, 16).transpose(1, 2)
            scores = (q @ k.transpose(-1, -2)) / 4.0
            prob = scores.masked_fill(mask[None, None], float("-inf")).softmax(-1)
            attended = (prob @ v).transpose(1, 2).contiguous().view(batch, length, 64)
            residual = x + layer["o"](attended)
            ffn = layer["down"](torch.nn.functional.gelu(layer["up"](layer["ln2"](residual)),
                                                         approximate="tanh"))
            x = residual + ffn
        return model.lm_head(model.final_ln(x))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--split-manifest", type=Path, required=True)
    ap.add_argument("--source-checkpoint", type=Path, required=True)
    ap.add_argument("--qat-checkpoint", type=Path, required=True)
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--windows", type=int, default=128)
    ap.add_argument("--seed", type=int, default=20263101)
    args = ap.parse_args()
    torch.set_num_threads(1)
    raw_bytes = args.corpus.read_bytes()
    raw = np.frombuffer(raw_bytes, dtype=np.uint8).copy()
    split = json.loads(args.split_manifest.read_text())
    if hashlib.sha256(raw_bytes).hexdigest() != split["corpus_sha256"]:
        raise ValueError("corpus/split manifest SHA mismatch")
    train_lo, train_hi = split["ranges_half_open"]["train"]
    val_lo, val_hi = split["ranges_half_open"]["validation"]
    test_lo, test_hi = split["ranges_half_open"]["test"]
    if not (train_hi < val_lo and val_hi < test_lo):
        raise ValueError("frozen split ranges overlap")
    starts = sample_starts(val_lo, val_hi, args.windows, args.seed)
    xs, ys = windows(raw, starts)
    # Only validation bytes enter this run. Test bytes are not loaded or scored.
    base = H64ByteDecoder().cpu()
    base.load_state_dict(load_state(args.source_checkpoint))
    fp_model = base.eval()
    qat_base = H64ByteDecoder().cpu()
    qat_base.load_state_dict(load_state(args.qat_checkpoint))
    qat_model = qat_base.eval()
    fake = IntegerLayerNormQAT(qat_base).eval()
    with np.load(args.package, allow_pickle=False) as data:
        package = {k: data[k].copy() for k in data.files}
    for li in range(4):
        package.setdefault(f"l{li}.up_q8_8", package[f"l{li}.up"].copy())

    with torch.no_grad():
        fp_logits = fp_model(torch.from_numpy(xs)).cpu().numpy()
        qat_logits = qat_model(torch.from_numpy(xs)).cpu().numpy()
        fake_logits = fake(torch.from_numpy(xs)).cpu().numpy()
    bg = bigram_logits(raw[train_lo:train_hi], xs)
    quality = {
        "fp32": metric(fp_logits, ys), "qat_float": metric(qat_logits, ys),
        "fake_quant": metric(fake_logits, ys), "bigram": metric(bg, ys),
    }
    trace_rows: list[dict] = []
    contract_quality: dict[str, dict] = {}
    for contract_name, contract in CONTRACTS.items():
        all_int_logits, aggregate_ref, aggregate_qat_float = [], {}, {}
        aggregate_got, aggregate_fake = {}, {}
        prefix_logits = {n: [] for n in range(1, 5)}
        fake_all_logits = []
        for row in xs:
            ilogits, itrace = infer(package, row.astype(int).tolist(), contract)
            ftrace = fp_trace(fp_model, row.astype(int).tolist())
            qfloat_trace = fp_trace(qat_model, row.astype(int).tolist())
            all_int_logits.append(ilogits)
            if contract_name == "residual_gelu_aligned":
                with torch.no_grad():
                    fake_logits_row, qat_trace = fake(torch.from_numpy(row[None, :]), return_trace=True)
                fake_all_logits.append(fake_logits_row.cpu().numpy()[0])
            else:
                qat_trace = {}
            for key, ref in ftrace.items():
                aggregate_ref.setdefault(key, []).append(np.asarray(ref))
            for key, ref in qfloat_trace.items():
                aggregate_qat_float.setdefault(key, []).append(np.asarray(ref))
            for key, val in itrace.items():
                aggregate_got.setdefault(key, []).append(np.asarray(val))
            for key, val in qat_trace.items():
                if key in ftrace:
                    qval = val.detach().cpu().numpy()
                    if qval.shape and qval.shape[0] == 1:
                        qval = qval[0]
                    aggregate_fake.setdefault(key, []).append(np.asarray(qval))
            if contract_name == "residual_gelu_aligned":
                # Progressive prefix integerization: use actual integer
                # residual2 at each boundary, then continue later layers in
                # FP32. This localizes where quality first degrades without
                # pretending it is a Product-RTL run.
                for n in range(1, 5):
                    boundary = np.asarray(itrace[f"l{n-1}.residual2"], dtype=np.float32) / 8.0
                    cont = fp_layer_from(qat_model, torch.from_numpy(boundary[None, ...]), n)
                    prefix_logits[n].append(cont.cpu().numpy()[0])
        ilogits = np.asarray(all_int_logits, dtype=np.int32)
        fake_all_logits = np.asarray(fake_all_logits)
        int_quality = metric(ilogits.astype(np.float64) / contract["scales"]["logit_dequant"], ys)
        contract_quality[contract_name] = {
            **int_quality,
            "logit_top1_agreement_vs_fp32": float(np.mean(np.argmax(ilogits, -1) == np.argmax(fp_logits, -1))),
            "logit_top1_agreement_vs_qat_float": float(np.mean(np.argmax(ilogits, -1) == np.argmax(qat_logits, -1))),
            "fake_quant_logit_top1_agreement": float(np.mean(np.argmax(fake_all_logits, -1) == np.argmax(ilogits, -1))) if contract_name == "residual_gelu_aligned" else None,
        }
        if contract_name == "residual_gelu_aligned":
            contract_quality[contract_name]["progressive_integerized_prefix"] = {
                str(n): metric(np.asarray(prefix_logits[n]), ys) for n in range(1, 5)
            }
            contract_quality[contract_name]["progressive_integerized_prefix_note"] = (
                "Integer residual2 after layer N-1 feeds remaining QAT-checkpoint floating layers; software diagnostic only, not RTL execution."
            )
        per_tensor = {}
        for key, refs in aggregate_ref.items():
            got_key = key
            if key.endswith("probabilities"):
                got_key = key + "_q15"
            if got_key not in aggregate_got:
                continue
            name = key.split(".")[-1]
            tensor_name = got_key.split(".")[-1]
            scale = SCALES.get(tensor_name, 1)
            ref_arr = np.concatenate([v.reshape(-1) for v in refs])
            got_arr = np.concatenate([v.reshape(-1) for v in aggregate_got[got_key]])
            scale_semantics_valid = contract_name == "residual_gelu_aligned"
            met = stats(ref_arr, got_arr, scale, tensor_name, scale_semantics_valid)
            qfloat_arr = np.concatenate([v.reshape(-1) for v in aggregate_qat_float[key]])
            qfloat_stats = stats(qfloat_arr, got_arr, scale, tensor_name, scale_semantics_valid)
            met["qat_float_mae"] = qfloat_stats["mae"]
            met["qat_float_rmse"] = qfloat_stats["rmse"]
            met["qat_float_cosine_similarity"] = qfloat_stats["cosine_similarity"]
            if contract_name == "residual_gelu_aligned" and key in aggregate_fake:
                fake_arr = np.concatenate([v.reshape(-1) for v in aggregate_fake[key]])
                met["qat_fake_mae"] = float(np.mean(np.abs(got_arr.astype(np.float64) / scale - fake_arr.astype(np.float64))))
                met["qat_fake_rmse"] = float(np.sqrt(np.mean((got_arr.astype(np.float64) / scale - fake_arr.astype(np.float64)) ** 2)))
            per_tensor[key] = met
            trace_rows.append({"contract": contract_name, "tensor": key,
                               **{k: v for k, v in met.items() if not isinstance(v, list)}})
        contract_quality[contract_name]["first_layer_relative_to_fp32"] = {
            name: {"mae": values.get("mae"), "cosine_similarity": values.get("cosine_similarity")}
            for name, values in per_tensor.items() if name.startswith("l0.")
        }
        contract_quality[contract_name]["tensor_error"] = per_tensor

    # Reproduce Fake Quant vs independent integer equality on the same frozen
    # validation windows. A mismatch is recorded, never hidden.
    fake_trace_checks = []
    for i in range(min(8, len(xs))):
        with torch.no_grad():
            _, ftrace = fake(torch.from_numpy(xs[i:i+1]), return_trace=True)
        _, itrace = infer(package, xs[i].astype(int).tolist(), CONTRACTS["residual_gelu_aligned"])
        node_mismatch = {}
        for li in range(4):
            for tensor, scale in (("ln1", 1), ("q", 32), ("k", 32), ("v", 32),
                                  ("scores", 256), ("attention", 32), ("projection", 8),
                                  ("residual1", 8), ("ln2", 1), ("up", 256),
                                  ("gelu", 256), ("gelu_i8", 8), ("down", 8), ("residual2", 8)):
                fk, ik = f"l{li}.{tensor}", f"l{li}.{tensor}"
                if fk not in ftrace or ik not in itrace:
                    continue
                fa = ftrace[fk].detach().cpu().numpy()
                if fa.shape and fa.shape[0] == 1: fa = fa[0]
                fi = np.rint(fa * scale).astype(np.int64)
                ii = np.asarray(itrace[ik], dtype=np.int64)
                node_mismatch[fk] = int(np.count_nonzero(fi != ii)) if fi.shape == ii.shape else -1
        fake_trace_checks.append(node_mismatch)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    result = {
        "status": "SOFTWARE_VALIDATION_ABLATION_ONLY_PRODUCT_TOP_NOT_RERUN",
        "seed": args.seed, "windows": len(xs), "context": CONTEXT,
        "validation_starts_sha256": hashlib.sha256(starts.astype("<i8").tobytes()).hexdigest(),
        "corpus_sha256": sha(args.corpus), "split_manifest_sha256": sha(args.split_manifest),
        "source_checkpoint_sha256": sha(args.source_checkpoint),
        "qat_checkpoint_sha256": sha(args.qat_checkpoint), "package_sha256": sha(args.package),
        "validation_range": [val_lo, val_hi], "test_range_not_read": [test_lo, test_hi],
        "quality": quality, "contracts": contract_quality,
        "fake_quant_vs_integer_trace": {
            "windows": len(fake_trace_checks),
            "mismatch_count_by_node": {k: sum(x.get(k, 0) for x in fake_trace_checks)
                                        for k in sorted({k for row in fake_trace_checks for k in row})},
            "all_exact": all(all(v == 0 for v in x.values()) for x in fake_trace_checks),
        },
        "tool_versions": {"python": sys.version.split()[0], "numpy": np.__version__, "torch": torch.__version__},
        "tensor_format_contract": TENSOR_FORMATS,
        "quantization_scale_contract": SCALES,
        "interpretation": "All contract comparisons use the same fixed QAT checkpoint and validation windows. Storage width is declared by tensor semantics, never inferred from observed numerical range. INT8 endpoint-code occupancy is reported as rail_code_ratio; true pre-clip saturation events are NOT_RUN because the current trace lacks pre-clip values. The frozen and exploratory shift variants do not preserve the validated residual/GELU scale alignment, so their tensor dequantization errors are marked scale_semantics_valid_for_contract=false. Progressive integerized-prefix and alternative-contract results are software-only; Product RTL is not changed or newly qualified by this run. Test split was not read.",
    }
    (args.out_dir / "round31_validation_ablation.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    with (args.out_dir / "round31_layer_tensor_error.csv").open("w", newline="", encoding="utf-8") as f:
        fields = sorted({k for row in trace_rows for k in row})
        writer = csv.DictWriter(f, fieldnames=fields); writer.writeheader(); writer.writerows(trace_rows)
    print(json.dumps({"status": result["status"], "quality": quality,
                      "contracts": {k: {kk: vv for kk, vv in v.items() if kk != "tensor_error" and kk != "first_layer_relative_to_fp32"}
                                    for k, v in contract_quality.items()},
                      "fake_quant_vs_integer_trace": result["fake_quant_vs_integer_trace"],
                      "output": str(args.out_dir)}, sort_keys=True))


if __name__ == "__main__":
    main()
