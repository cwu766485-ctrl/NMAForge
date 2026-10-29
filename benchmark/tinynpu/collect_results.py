#!/usr/bin/env python3
"""Collect bounded Matrix/TinyNPU RTL benchmark logs into CSV and JSON."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


FIELD_RE = re.compile(r"([A-Za-z_]+)=([^\s]+)")
CSV_FIELDS = [
    "run_id", "design", "source_sha", "seed", "shape_mnk", "physical_array",
    "cycles_to_done", "cycles_to_last_output", "macs", "mac_per_cycle",
    "pe_utilization_pct", "spad_read_bytes", "spad_write_bytes", "bank_stalls",
    "line_stalls", "golden", "timing_boundary", "comparison_scope",
]
CNN_FIELDS = [
    "run_id", "design", "source_sha", "reference_sha", "seed", "model",
    "model_sha256", "input_sha256", "logical_macs", "outputs",
    "measured_cycles", "host_layout_cycles", "reported_phase_cycles",
    "spad_initialization_bytes", "compute_spad_read_bytes",
    "compute_spad_write_bytes", "host_layout_read_bytes",
    "host_layout_write_bytes", "golden", "measurement_boundary",
]


def fields(line: str) -> dict[str, str]:
    return dict(FIELD_RE.findall(line))


def require_line(path: Path, prefix: str) -> str:
    if not path.exists():
        raise SystemExit(f"missing run log: {path}")
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith(prefix):
            return line
    raise SystemExit(f"missing {prefix!r} marker in {path}")


def require_lines(path: Path, prefix: str) -> list[str]:
    if not path.exists():
        raise SystemExit(f"missing run log: {path}")
    matches = [line for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
               if line.startswith(prefix)]
    if not matches:
        raise SystemExit(f"missing {prefix!r} marker in {path}")
    return matches


def matrix_row(line: str, design: str, source_sha: str, seed: str,
               run_id: str, scope: str) -> dict[str, str]:
    value = fields(line)
    m, n, k = (int(part) for part in value["shape_mnk"].split(","))
    return {
        "run_id": run_id,
        "design": design,
        "source_sha": source_sha,
        "seed": seed,
        "shape_mnk": f"{m}x{n}x{k}",
        "physical_array": value["physical_array"],
        "cycles_to_done": value["cycles"],
        "cycles_to_last_output": value["cycles"],
        "macs": str(m * n * k),
        "mac_per_cycle": value["macs_per_cycle"],
        "pe_utilization_pct": value["array_utilization_pct"],
        "spad_read_bytes": value["bank_read_bytes"],
        "spad_write_bytes": value["line_write_bytes"],
        "bank_stalls": value["bank_stalls"],
        "line_stalls": value["line_stalls"],
        "golden": "PASS: all output words",
        "timing_boundary": "Matrix start accepted through final SPAD write and done",
        "comparison_scope": scope,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--nma-sha", required=True)
    parser.add_argument("--tiny-sha", required=True)
    parser.add_argument("--seed", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--size-root", type=Path, required=True)
    parser.add_argument("--match8", type=Path, required=True)
    parser.add_argument("--match16", type=Path, required=True)
    parser.add_argument("--tiny-gemm", type=Path, required=True)
    parser.add_argument("--tiny-engine", type=Path, required=True)
    parser.add_argument("--tiny-cnn", type=Path, required=True)
    parser.add_argument("--nma-cnn", type=Path, required=True)
    parser.add_argument("--nma-cnn-manifest", type=Path, required=True)
    parser.add_argument("--out-csv", type=Path, required=True)
    parser.add_argument("--out-cnn-csv", type=Path, required=True)
    parser.add_argument("--out-cnn-json", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    parser.add_argument("--vcs-version", default="V-2023.12-SP1_Full64")
    parser.add_argument("--verilator-version", required=True)
    args = parser.parse_args()

    rows: list[dict[str, str]] = []
    for size in (4, 8, 16):
        log = args.size_root / f"array_{size}" / "run.log"
        for case_id in range(100, 105):
            line = require_line(log, f"MATRIX_CORE_CASE_PASS id={case_id} ")
            rows.append(matrix_row(
                line, "NMAForge", args.nma_sha, args.seed, args.run_id,
                "size sweep; behavioral 1-cycle SPAD"))

    nma_match8 = require_line(args.match8, "MATRIX_CORE_CASE_PASS id=105 ")
    rows.append(matrix_row(
        nma_match8, "NMAForge", args.nma_sha, args.seed, args.run_id,
        "matched logical GEMM; NMAForge 8x8 controller + behavioral SPAD"))
    matched_shapes = ("16,16,16", "16,16,32", "32,32,64")
    nma_match_lines = {
        case_id: require_line(args.match16, f"MATRIX_CORE_CASE_PASS id={case_id} ")
        for case_id in (105, 106, 107)
    }
    nma_matches = dict(zip(matched_shapes,
                           (fields(nma_match_lines[case_id]) for case_id in (105, 106, 107))))
    nma_match_lines_by_shape = dict(zip(matched_shapes,
                                       (nma_match_lines[case_id] for case_id in (105, 106, 107))))
    tiny_match_lines = require_lines(args.tiny_gemm, "TINYNPU_MATCHED_GEMM_PASS ")
    tiny_matches = {fields(line)["shape_mnk"]: fields(line) for line in tiny_match_lines}
    if len(tiny_match_lines) != 3 or set(tiny_matches) != set(matched_shapes):
        raise SystemExit(f"TinyNPU matched shapes mismatch: {sorted(tiny_matches)}")

    for shape in matched_shapes:
        nma = nma_matches[shape]
        tiny = tiny_matches[shape]
        normalized_shape = shape.replace(",", "x")
        if nma["shape_mnk"] != shape:
            raise SystemExit(f"NMAForge matched case shape mismatch for {normalized_shape}")
        nma_m, nma_n, nma_k = (int(part) for part in nma["shape_mnk"].split(","))
        if nma["physical_array"] != "16x16" or nma_m * nma_n * nma_k != int(tiny["macs"]):
            raise SystemExit(f"matched design shape/MAC mismatch for {normalized_shape}")
        rows.append(matrix_row(
            nma_match_lines_by_shape[shape],
            "NMAForge", args.nma_sha, args.seed, args.run_id,
            "matched tiled GEMM; 16x16 controller + one-cycle behavioral SPAD"))
        tiny_m, tiny_n, tiny_k = (int(part) for part in tiny["shape_mnk"].split(","))
        rows.append({
            "run_id": args.run_id,
            "design": "TinyNPU",
            "source_sha": args.tiny_sha,
            "seed": "directed",
            "shape_mnk": normalized_shape,
            "physical_array": tiny["physical_array"],
            "cycles_to_done": "N/A",
            "cycles_to_last_output": tiny["cycles_input_to_array_stable"],
            "macs": tiny["macs"],
            "mac_per_cycle": tiny["mac_per_cycle"],
            "pe_utilization_pct": tiny["pe_utilization_pct"],
            "spad_read_bytes": "N/A",
            "spad_write_bytes": "N/A",
            "bank_stalls": "N/A",
            "line_stalls": "N/A",
            "golden": tiny["golden"],
            "timing_boundary": "first systolic input through all tiled accumulators stable; direct array wrapper",
            "comparison_scope": "same deterministic A/B and integer Golden; excludes TinyNPU memory path and is not latency-normalized to NMAForge controller",
        })
        if int(tiny["macs"]) != tiny_m * tiny_n * tiny_k:
            raise SystemExit(f"TinyNPU MAC count mismatch for {normalized_shape}")

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    args.out_csv.write_bytes(args.out_csv.read_bytes().replace(b"\r\n", b"\n"))

    engine_text = args.tiny_engine.read_text(encoding="utf-8", errors="replace")
    cnn_text = args.tiny_cnn.read_text(encoding="utf-8", errors="replace")
    engine_passes = len(re.findall(r"^(?:GELU|GEMM|Softmax|LayerNorm|Vec ADD|Chained): PASS$",
                                   engine_text, flags=re.MULTILINE))
    cycle_match = re.search(r"Graph execution DONE at cycle (\d+)", cnn_text)
    cnn_pass = "PASS: All 4 bytes match golden!" in cnn_text
    if engine_passes != 6 or cycle_match is None or not cnn_pass:
        raise SystemExit("TinyNPU engine/CNN reference regression marker missing")

    nma_cnn_line = require_line(args.nma_cnn, "NMA_CNN_RTL_METRICS ")
    require_line(args.nma_cnn, "NMA_CNN_INFERENCE_PASS ")
    nma_cnn = fields(nma_cnn_line)
    manifest = json.loads(args.nma_cnn_manifest.read_text(encoding="utf-8"))
    if len(manifest.get("golden_int8", [])) != 4:
        raise SystemExit("NMAForge CNN manifest is incomplete")
    nma_phases = int(nma_cnn["cycles"]) + int(nma_cnn["host_layout_cycles"])
    cnn_rows = [
        {
            "run_id": args.run_id,
            "design": "NMAForge",
            "source_sha": args.nma_sha,
            "reference_sha": args.tiny_sha,
            "seed": str(manifest["input_seed"]),
            "model": "conv1x_mini.onnx",
            "model_sha256": manifest["model_sha256"],
            "input_sha256": manifest["input_int8_sha256"],
            "logical_macs": nma_cnn["model_macs"],
            "outputs": nma_cnn["outputs"],
            "measured_cycles": nma_cnn["cycles"],
            "host_layout_cycles": nma_cnn["host_layout_cycles"],
            "reported_phase_cycles": str(nma_phases),
            "spad_initialization_bytes": nma_cnn["spad_initialization_bytes"],
            "compute_spad_read_bytes": nma_cnn["compute_spad_read_bytes"],
            "compute_spad_write_bytes": nma_cnn["compute_spad_write_bytes"],
            "host_layout_read_bytes": nma_cnn["host_layout_read_bytes"],
            "host_layout_write_bytes": nma_cnn["host_layout_write_bytes"],
            "golden": "PASS: all intermediate tensors and 4 output bytes",
            "measurement_boundary": "two CMDQ execution windows; excludes SPAD preload, descriptor programming and final host read; host layout is separate",
        },
        {
            "run_id": args.run_id,
            "design": "TinyNPU",
            "source_sha": args.tiny_sha,
            "reference_sha": args.tiny_sha,
            "seed": str(manifest["input_seed"]),
            "model": "conv1x_mini.onnx",
            "model_sha256": manifest["model_sha256"],
            "input_sha256": manifest["input_int8_sha256"],
            "logical_macs": nma_cnn["model_macs"],
            "outputs": "4",
            "measured_cycles": cycle_match.group(1),
            "host_layout_cycles": "N/A",
            "reported_phase_cycles": cycle_match.group(1),
            "spad_initialization_bytes": "N/A",
            "compute_spad_read_bytes": "N/A",
            "compute_spad_write_bytes": "N/A",
            "host_layout_read_bytes": "N/A",
            "host_layout_write_bytes": "N/A",
            "golden": "PASS: all 4 output bytes",
            "measurement_boundary": "TinyNPU ONNX graph smoke with graph dispatcher and testbench DMA/SRAM shim; testbench input setup excluded",
        },
    ]
    args.out_cnn_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_cnn_csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=CNN_FIELDS)
        writer.writeheader()
        writer.writerows(cnn_rows)
    args.out_cnn_csv.write_bytes(args.out_cnn_csv.read_bytes().replace(b"\r\n", b"\n"))

    cnn_summary = {
        "run_id": args.run_id,
        "nmaforge_source_sha": args.nma_sha,
        "tinynpu_source_sha": args.tiny_sha,
        "model": "conv1x_mini.onnx",
        "model_sha256": manifest["model_sha256"],
        "input_seed": manifest["input_seed"],
        "input_int8_sha256": manifest["input_int8_sha256"],
        "logical_macs": int(nma_cnn["model_macs"]),
        "golden": "both designs PASS; NMAForge checks every intermediate tensor and 4/4 final bytes",
        "nmaforge": {
            "descriptors": int(nma_cnn["descriptors"]),
            "compute_cycles": int(nma_cnn["cycles"]),
            "host_layout_cycles": int(nma_cnn["host_layout_cycles"]),
            "reported_phase_cycles": nma_phases,
            "host_layout_read_bytes": int(nma_cnn["host_layout_read_bytes"]),
            "host_layout_write_bytes": int(nma_cnn["host_layout_write_bytes"]),
            "compute_spad_read_bytes": int(nma_cnn["compute_spad_read_bytes"]),
            "compute_spad_write_bytes": int(nma_cnn["compute_spad_write_bytes"]),
            "spad_initialization_bytes": int(nma_cnn["spad_initialization_bytes"]),
            "measurement_boundary": "two CMDQ execution windows; excludes SPAD preload, descriptor programming and final host read",
        },
        "tinynpu": {
            "graph_cycles": int(cycle_match.group(1)),
            "measurement_boundary": "ONNX graph smoke with graph dispatcher and testbench DMA/SRAM shim",
        },
        "cycle_comparison": "No speedup computed: measurement windows, graph dispatch and memory setup differ.",
        "tools": {"vcs": args.vcs_version, "verilator": args.verilator_version},
    }
    args.out_cnn_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_cnn_json.write_text(json.dumps(cnn_summary, indent=2) + "\n", encoding="utf-8")

    summary = {
        "run_id": args.run_id,
        "nmaforge_source_sha": args.nma_sha,
        "nmaforge_matrix_rtl_basis": "same Matrix product RTL as audited candidate 9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9",
        "tinynpu_source_sha": args.tiny_sha,
        "seed": args.seed,
        "tools": {"vcs": args.vcs_version, "verilator": args.verilator_version},
        "matched_gemm": {
            "shapes": [shape.replace(",", "x") for shape in matched_shapes],
            "data_type": "signed INT8; INT32 accumulation",
            "operand_pattern": "same fixed A/B formulas in both testbenches",
            "golden": "all output words pass against independent INT32 GEMM on both designs",
            "cases": [
                {
                    "shape": shape.replace(",", "x"),
                    "nmaforge_cycles": int(nma_matches[shape]["cycles"]),
                    "nmaforge_spad_read_bytes": int(nma_matches[shape]["bank_read_bytes"]),
                    "nmaforge_spad_write_bytes": int(nma_matches[shape]["line_write_bytes"]),
                    "tinynpu_direct_array_cycles": int(tiny_matches[shape]["cycles_input_to_array_stable"]),
                    "comparison": "no speedup computed; NMAForge includes controller/SPAD while TinyNPU directly drives its systolic array",
                }
                for shape in matched_shapes
            ],
        },
        "matrix_size_sweep": {
            "shapes": ["4x4x32", "8x8x32", "16x16x32", "16x32x32", "32x32x64"],
            "physical_arrays": ["4x4", "8x8", "16x16"],
            "pass_count": 15,
            "memory": "one-cycle behavioral SPAD; not SRAM timing or ASIC PPA",
        },
        "tinynpu_reference": {
            "engine_regression": f"{engine_passes}/6 PASS",
            "onnx_model": "conv1x_mini.onnx: 8x8x1 -> 3x3 Conv -> ReLU -> Flatten -> GEMM",
            "cnn_graph_cycles": int(cycle_match.group(1)),
            "cnn_golden": "PASS, 4/4 output bytes exact",
            "nmaforge_same_graph_cnn": "PASS; see paired CNN CSV/JSON with separate engine and host-layout timing",
            "nmaforge_cnn_compute_cycles": int(nma_cnn["cycles"]),
            "nmaforge_cnn_host_layout_cycles": int(nma_cnn["host_layout_cycles"]),
            "nmaforge_cnn_spad_read_bytes": int(nma_cnn["compute_spad_read_bytes"]),
            "nmaforge_cnn_spad_write_bytes": int(nma_cnn["compute_spad_write_bytes"]),
            "cnn_speedup_claim": "not computed; design timing boundaries and graph/memory paths differ",
        },
        "csv_rows": len(rows),
    }
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
