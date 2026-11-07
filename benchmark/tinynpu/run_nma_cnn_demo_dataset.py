#!/usr/bin/env python3
"""Run every held-out tiny-CNN image through an already compiled Top testbench."""

import argparse
import csv
import hashlib
import json
import re
import subprocess
from pathlib import Path

import numpy as np

import generate_nma_cnn_workload as workload
from generate_nma_cnn_demo_golden import compute_logits


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--simv", required=True, type=Path)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--testset", required=True, type=Path)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=20261029)
    parser.add_argument("--spad-base-shift", type=lambda value: int(value, 0), default=0)
    parser.add_argument(
        "--linearized", action="store_true",
        help="use the optional 0x53 aux0[7] linear-row writeback path",
    )
    parser.add_argument(
        "--fused-native", action="store_true",
        help="fuse requant/activation while keeping native Matrix-A output layout",
    )
    args = parser.parse_args()
    if args.linearized and args.fused_native:
        raise SystemExit("--linearized and --fused-native are mutually exclusive")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    logs_dir = args.out_dir / "logs"
    inputs_dir = args.out_dir / "inputs"
    workload_dir = args.out_dir / "workloads"
    for path in (logs_dir, inputs_dir, workload_dir):
        path.mkdir(parents=True, exist_ok=True)

    with np.load(args.testset) as testset:
        inputs = testset["input_int8"].astype(np.int8)
        labels = testset["labels"].astype(np.int32)
        input_scale = float(testset["input_scale"].item())
    with np.load(args.model) as model:
        num_classes = int(model["fc_w"].shape[0])
    if inputs.shape != (len(labels), 1, 1, 8, 8):
        raise SystemExit("unexpected testset shape %s" % (inputs.shape,))

    rows = []
    for index, (sample, label) in enumerate(zip(inputs, labels)):
        stem = "sample_%03d" % index
        input_path = inputs_dir / (stem + ".npz")
        np.savez(input_path, input_int8=sample,
                 input_scale=np.asarray(input_scale, dtype=np.float32),
                 label=np.asarray(label, dtype=np.int32))
        independent_logits, independent_label = compute_logits(args.model, input_path)
        if independent_label != int(label):
            raise SystemExit("label mismatch at sample %d" % index)
        golden = independent_logits.tobytes()
        golden_path = inputs_dir / (stem + ".bin")
        golden_path.write_bytes(golden)

        image_words, expected_words, manifest, mapped_golden = workload.build(
            args.model, input_path, args.spad_base_shift)
        if mapped_golden != golden:
            raise SystemExit("independent Golden mismatch at sample %d" % index)
        case_dir = workload_dir / stem
        case_dir.mkdir(parents=True, exist_ok=True)
        memory_path = case_dir / "spad.memh"
        expected_path = case_dir / "expected.memh"
        workload.write_memh(memory_path, image_words)
        workload.write_memh(expected_path, expected_words)
        log_path = logs_dir / (stem + ".log")
        command = [
            str(args.simv.resolve()), "+ntb_random_seed=%d" % args.seed,
            "+AI_RANDOM_CASES=0", "+AI_SEED=%d" % args.seed,
            "+ACLK_PERIOD_NS=10.0", "+AI_TINYNPU_CNN_MATCH",
            "+AI_TINYNPU_CNN_CLASSES=%d" % num_classes,
            "+AI_TINYNPU_CNN_MEMORY=" + str(memory_path.resolve()),
            "+AI_TINYNPU_CNN_EXPECTED=" + str(expected_path.resolve()),
        ]
        if args.linearized:
            command.append("+AI_TINYNPU_CNN_LINEARIZED")
        elif args.fused_native:
            command.append("+AI_TINYNPU_CNN_FUSED_NATIVE")
        with log_path.open("w", encoding="utf-8") as console:
            result = subprocess.run(command, cwd=args.out_dir, stdout=console,
                                    stderr=subprocess.STDOUT, check=False)
        text = log_path.read_text(encoding="utf-8", errors="replace")
        match = re.search(r"NMA_CNN_RTL_METRICS outputs=(\d+) descriptors=(\d+) cycles=(\d+) host_layout_cycles=(\d+) host_layout_read_bytes=(\d+) host_layout_write_bytes=(\d+) compute_spad_read_bytes=(\d+) compute_spad_write_bytes=(\d+).*?model_macs=(\d+)", text)
        if result.returncode != 0 or "NMA_CNN_INFERENCE_PASS" not in text or match is None:
            raise SystemExit("Top CNN replay failed at sample %d; inspect %s" % (index, log_path))
        prediction = int(np.argmax(independent_logits))
        rows.append({
            "sample_index": index,
            "label": int(label),
            "prediction": prediction,
            "correct": int(prediction == int(label)),
            "logits_int8": ";".join(str(int(v)) for v in independent_logits),
            "rtl_golden": "PASS_ALL_INTERMEDIATES",
            "rtl_descriptors": int(match.group(2)),
            "rtl_compute_cycles": int(match.group(3)),
            "host_layout_cycles": int(match.group(4)),
            "host_layout_read_bytes": int(match.group(5)),
            "host_layout_write_bytes": int(match.group(6)),
            "compute_spad_read_bytes": int(match.group(7)),
            "compute_spad_write_bytes": int(match.group(8)),
            "model_macs": int(match.group(9)),
            "input_sha256": sha256(input_path),
            "golden_sha256": sha256(golden_path),
            "run_log": str(log_path),
        })
        if (index + 1) % 16 == 0 or index + 1 == len(labels):
            print("NMA_TRAINED_CNN_TOP_PROGRESS samples=%d/%d correct=%d" %
                  (index + 1, len(labels), sum(row["correct"] for row in rows)),
                  flush=True)

    csv_path = args.out_dir / "nma_tiny_cnn_demo_top_results.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    correct_count = sum(row["correct"] for row in rows)
    mode_name = ("LINEARIZED" if args.linearized else
                 "FUSED_NATIVE" if args.fused_native else "LEGACY_LAYOUT")
    summary = {
        "run_id": "V2-TRAINED-CNN-TOP-DATASET-%s-%s" % (
            args.candidate_sha[:7].upper(), mode_name),
        "candidate_sha": args.candidate_sha,
        "model_sha256": sha256(args.model),
        "testset_sha256": sha256(args.testset),
        "num_classes": num_classes,
        "class_labels": list(range(num_classes)),
        "architecture": "4 shared 3x3 INT8 conv filters + INT8 linear head, output groups of four",
        "spad_base_shift_bytes": args.spad_base_shift,
        "linearized_output_layout": args.linearized,
        "fused_native_output_layout": args.fused_native,
        "rtl_mode": ("0x53-linear-row" if args.linearized else
                     "0x53-fused-native" if args.fused_native else
                     "legacy-host-layout"),
        "samples": len(rows),
        "top_runs_passed": len(rows),
        "all_intermediate_goldens_exact": True,
        "correct": correct_count,
        "accuracy": correct_count / len(rows),
        "rtl_compute_cycles_per_sample": sorted(set(row["rtl_compute_cycles"] for row in rows)),
        "host_layout_cycles_per_sample": sorted(set(row["host_layout_cycles"] for row in rows)),
        "classification_source": "independent integer Golden logits, each Golden byte-compared by Top checker",
        "csv": csv_path.name,
        "logs_directory": str(logs_dir),
    }
    summary_path = args.out_dir / "nma_tiny_cnn_demo_top_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print("NMA_TRAINED_CNN_TOP_DATASET_PASS samples=%d correct=%d accuracy=%.6f run_id=%s" %
          (len(rows), correct_count, summary["accuracy"], summary["run_id"]))


if __name__ == "__main__":
    main()
