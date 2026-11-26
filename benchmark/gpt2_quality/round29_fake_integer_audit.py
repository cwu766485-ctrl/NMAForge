#!/usr/bin/env python3
"""Round 29 audit: compare QAT's hard forward to its matching Product package.

The test reuses the frozen Round 28 clean-split test windows. It evaluates the
same QAT checkpoint in the fake-quant graph and the independent integer
reference, then compares every named activation after its declared physical
scale. It does not train, alter the package, or use the test set for selection.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from round21_contract_ablation import CONTRACTS, infer as integer_infer  # noqa: E402
from round27_clean_split_experiment import (  # noqa: E402
    CONTEXT, H64ByteDecoder, get_windows,
)
from train_round24_integer_qat import IntegerLayerNormQAT  # noqa: E402


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha_bytes(path.read_bytes())


def quantized_fake_stage(value: torch.Tensor, scale: int) -> np.ndarray:
    return torch.round(value.detach().cpu() * scale).to(torch.int64).numpy()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--evidence", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261211)
    ap.add_argument("--windows", type=int, default=512)
    args = ap.parse_args()

    torch.set_num_threads(1)
    evidence = args.evidence.resolve()
    seed_dir = evidence / "seed_20261223"
    fp_path = seed_dir / "fp32_before_qat.pt"
    qat_path = seed_dir / "qat_float.pt"
    package_path = seed_dir / "product_int8.npz"
    manifest_path = seed_dir / "manifest.json"
    split_path = evidence / "corpus_split.json"
    raw_bytes = args.corpus.read_bytes()
    raw = np.frombuffer(raw_bytes, dtype=np.uint8).copy()
    split = json.loads(split_path.read_text())
    if split["corpus_sha256"] != sha_bytes(raw_bytes):
        raise SystemExit("corpus SHA differs from frozen split manifest")
    if split["context"] != CONTEXT:
        raise SystemExit("frozen split context differs from model contract")
    test_lo, test_hi = split["ranges_half_open"]["test"]
    xs, targets, starts = get_windows(raw, test_lo, test_hi, args.windows, args.seed)

    checkpoint = torch.load(qat_path, map_location="cpu", weights_only=False)
    qat_model = H64ByteDecoder().cpu().eval()
    qat_model.load_state_dict(checkpoint["state_dict"])
    qat = IntegerLayerNormQAT(qat_model).eval()
    tokens = torch.from_numpy(xs.astype(np.int64))
    with torch.inference_mode():
        fake_logits, fake_trace = qat(tokens, return_trace=True)

    with np.load(package_path, allow_pickle=False) as npz:
        package = {key: npz[key].copy() for key in npz.files}
    # Independent INT reference consumes the same Q8.8 FFN-up tensor as the
    # Product opcode 0x35 path. Confirm the package exporter produced it.
    for layer in range(4):
        key = f"l{layer}.up"
        expected_up = np.clip(np.rint(
            checkpoint["state_dict"][f"layers.{layer}.up.weight"].cpu().numpy().T * 256),
            -128, 127).astype(np.int8)
        if not np.array_equal(package[key], expected_up):
            raise SystemExit(f"package tensor {key} differs from checkpoint export")
        package[f"l{layer}.up_q8_8"] = package[key]

    stages: dict[str, list[np.ndarray]] = {}
    stage_scales: dict[str, int] = {"embedding_position": 8, "final_ln": 1,
                                    "logits": 32}
    for layer in range(4):
        prefix = f"l{layer}."
        stage_scales.update({prefix + "ln1": 1, prefix + "q": 32,
                             prefix + "k": 32, prefix + "v": 32,
                             prefix + "scores": 256,
                             prefix + "attention": 32,
                             prefix + "projection": 8,
                             prefix + "residual1": 8,
                             prefix + "ln2": 1, prefix + "up": 256,
                             prefix + "gelu": 256,
                             prefix + "gelu_i8": 8,
                             prefix + "down": 8,
                             prefix + "residual2": 8})
        stages[prefix + "probabilities_q7"] = []
    for name, scale in stage_scales.items():
        stages[name] = quantized_fake_stage(fake_trace[name], scale)
    for layer in range(4):
        prefix = f"l{layer}."
        # QAT stores the Product's Q15>>8 probability as a Q7 float. The
        # independent reference exposes the full Q15 accumulator value.
        stages[prefix + "probabilities_q7"] = np.rint(
            fake_trace[prefix + "probabilities"].detach().cpu().numpy() * 128
        ).astype(np.int64)

    integer_trace: dict[str, list[np.ndarray]] = {}
    first: dict | None = None
    legacy_sat_mismatch = 0
    legacy_first: dict | None = None
    for wi, row in enumerate(xs):
        _, trace = integer_infer(package, row.astype(int).tolist(),
                                 CONTRACTS["residual_gelu_aligned"])
        for name, value in trace.items():
            mapped = name
            if name.endswith("probabilities_q15"):
                mapped = name[:-len("probabilities_q15")] + "probabilities_q7"
                value = np.clip(np.asarray(value, dtype=np.int64) >> 8, -128, 127)
            integer_trace.setdefault(mapped, []).append(np.asarray(value, dtype=np.int64))

            # Negative-control replay of the pre-Round-29 bug: omitted signed
            # INT8 saturation on Q15 probability >> 8 before AV.
            if name.endswith("probabilities_q15"):
                old_codes = np.asarray(trace[name], dtype=np.int64) >> 8
                mismatch = (old_codes < -128) | (old_codes > 127)
                count = int(np.count_nonzero(mismatch))
                if count:
                    legacy_sat_mismatch += count
                    if legacy_first is None:
                        loc = np.argwhere(mismatch)[0].tolist()
                        legacy_first = {"window": wi, "stage": name,
                                        "index": loc,
                                        "q15": int(np.asarray(trace[name])[tuple(loc)]),
                                        "pre_saturation_q7": int(old_codes[tuple(loc)]),
                                        "product_q7": int(np.clip(old_codes[tuple(loc)], -128, 127))}

        for name, fake_array in stages.items():
            if name not in integer_trace or len(integer_trace[name]) <= wi:
                continue
            expected = integer_trace[name][wi]
            observed = fake_array[wi]
            if expected.shape != observed.shape:
                raise SystemExit(f"shape mismatch {name}: {observed.shape} != {expected.shape}")
            delta = np.abs(observed - expected)
            count = int(np.count_nonzero(delta))
            if count and first is None:
                loc = np.argwhere(delta)[0].tolist()
                first = {"window": wi, "stage": name, "index": loc,
                         "expected": int(expected[tuple(loc)]),
                         "observed": int(observed[tuple(loc)]),
                         "max_abs_delta": int(delta.max())}

    stage_report = {}
    for name, observed in stages.items():
        expected_rows = integer_trace[name]
        a = np.concatenate([x.reshape(-1) for x in expected_rows])
        b = observed.reshape(-1)
        d = b - a
        stage_report[name] = {"elements": int(a.size),
                              "mismatches": int(np.count_nonzero(d)),
                              "max_abs_delta_codes": int(np.max(np.abs(d), initial=0))}

    int_logits = np.stack(integer_trace["logits"])
    fake_logits_codes = stages["logits"]
    if fake_logits_codes.shape != int_logits.shape:
        raise SystemExit("logit tensor shape mismatch")
    logits_mismatch = int(np.count_nonzero(fake_logits_codes != int_logits))

    def metrics(logits: np.ndarray) -> dict:
        z = logits.astype(np.float64) / 32.0
        z -= z.max(axis=-1, keepdims=True)
        logsum = np.log(np.exp(z).sum(axis=-1))
        selected = np.take_along_axis(z, targets[..., None], axis=-1)[..., 0]
        ce = logsum - selected
        return {"targets": int(targets.size),
                "accuracy": float(np.mean(np.argmax(z, axis=-1) == targets)),
                "cross_entropy_nats": float(np.mean(ce)),
                "perplexity": float(np.exp(np.mean(ce)))}

    report = {
        "status": "PASS" if first is None and logits_mismatch == 0 else "FAIL",
        "source_head": "745e8c0643e55d1ec5a6a5df46b6cd8da8f49532",
        "qat_checkpoint_sha256": sha_file(qat_path),
        "source_fp32_checkpoint_sha256": sha_file(fp_path),
        "package_sha256": sha_file(package_path),
        "corpus_sha256": sha_bytes(raw_bytes),
        "split_manifest_sha256": sha_file(split_path),
        "seed_manifest_sha256": sha_file(manifest_path),
        "test_windows": int(args.windows), "targets_per_window": CONTEXT,
        "test_start_seed": args.seed,
        "test_start_sha256": sha_bytes(starts.astype("<i8").tobytes()),
        "fake_vs_independent_integer_first_mismatch": first,
        "stage_comparison": stage_report,
        "logits_mismatches": logits_mismatch,
        "product_probability_saturation_negative_control": {
            "omitted_saturation_out_of_range_values": legacy_sat_mismatch,
            "first": legacy_first,
        },
        "heldout_metrics_same_qat_state": {
            "fake_quant": metrics(fake_logits_codes),
            "independent_product_integer": metrics(int_logits),
        },
        "interpretation": [
            "Round 28's 7.69% fake-quant number used the pre-QAT FP32 checkpoint while the compared Product INT8 package came from the QAT-updated checkpoint; those were different model states.",
            "The fake-quant forward also lacked Product INT8 saturation after Q15 probability >> 8. This audit includes that saturation and compares a single frozen QAT checkpoint against its matching package.",
            "Passing this numerical audit establishes fake-forward/reference agreement only; it does not close model quality or replace Product Top qualification.",
        ],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print("ROUND29_GPT2_INTEGER_FORWARD_AUDIT " + json.dumps({
        "status": report["status"], "windows": args.windows,
        "logit_mismatches": logits_mismatch, "first_mismatch": first,
        "same_state_fake_accuracy": report["heldout_metrics_same_qat_state"]["fake_quant"]["accuracy"],
        "same_state_int_accuracy": report["heldout_metrics_same_qat_state"]["independent_product_integer"]["accuracy"],
        "legacy_unsaturated_probability_codes": legacy_sat_mismatch,
    }, sort_keys=True), flush=True)
    if report["status"] != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
