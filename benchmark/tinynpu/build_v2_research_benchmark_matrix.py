#!/usr/bin/env python3
"""Consolidate fixed NMAForge v2 benchmark records without changing endpoints."""

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BENCH = ROOT / "benchmark"
OUT_CSV = BENCH / "v2_research_benchmark_matrix_20261106.csv"
OUT_JSON = BENCH / "v2_research_benchmark_matrix_20261106.json"
TINY_SHA = "8216c22b762011aa20c05fc2768423fd12dda59d"
PRODUCT_RTL_SHA = "cd0a05d8ecd8cfb6c3f39b559788a2531e324b23"

FIELDS = [
    "run_id", "workload_family", "workload", "shape", "capacity_kib",
    "nmaforge_source_sha", "product_rtl_sha", "model_sha256",
    "test_data_sha256", "tiny_npu_reference_sha", "array_macs",
    "datatype", "useful_macs", "nma_total_cycles", "nma_command_cycles",
    "nma_compute_cycles", "nma_host_cycles", "nma_dma_cycles",
    "nma_graph_orchestration_cycles", "nma_prefill_cycles",
    "nma_decode_cycles", "decode_tokens", "nma_mac_per_cycle",
    "nma_pe_utilization_pct", "nma_spad_read_bytes", "nma_spad_write_bytes",
    "nma_host_layout_read_bytes", "nma_host_layout_write_bytes",
    "nma_ddr_traffic_bytes", "nma_stall_breakdown_json",
    "tiny_npu_measured_cycles", "tiny_npu_mac_per_cycle",
    "tiny_npu_pe_utilization_pct", "tiny_npu_spad_read_bytes",
    "tiny_npu_spad_write_bytes", "tiny_npu_common_memory_estimated_cycles",
    "golden_result", "classification_result", "seed", "measurement_status",
    "measurement_boundary", "evidence_path",
]


def na(value):
    return "N/A" if value is None or value == "" else value


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def matrix_rows():
    rows = []
    for filename in ("v2_tinynpu_gemm_current_20261106.csv",
                     "v2_tinynpu_gemv_current_20261106.csv"):
        for source in read_csv(BENCH / filename):
            stalls = {
                "bank": int(source["nmaforge_bank_stall_cycles"]),
                "line": int(source["nmaforge_line_stall_cycles"]),
                "prefetch_wait": int(source["nmaforge_prefetch_wait_cycles"]),
                "arbiter": int(source["nmaforge_arbiter_stall_cycles"]),
                "response_wait": int(source["nmaforge_response_wait_cycles"]),
                "writeback_wait": int(source["nmaforge_writeback_wait_cycles"]),
                "note": "event counters overlap; do not sum",
            }
            is_gemv = source["workload"] == "gemv"
            rows.append({
                "run_id": source["run_id"],
                "workload_family": source["workload"].upper(),
                "workload": source["workload"].upper() + " INT8 matched deterministic operands",
                "shape": "{}x{}x{}".format(source["shape_m"], source["shape_n"], source["shape_k"]),
                "capacity_kib": "N/A",
                "nmaforge_source_sha": source["nmaforge_sha"],
                "product_rtl_sha": source["nmaforge_product_rtl_sha"],
                "model_sha256": "N/A",
                "test_data_sha256": "N/A; deterministic formula in source record",
                "tiny_npu_reference_sha": source["tiny_npu_sha"],
                "array_macs": source["array_macs"],
                "datatype": "INT8 operands; INT32 Golden",
                "useful_macs": source["useful_macs"],
                "nma_total_cycles": source["nmaforge_cycles"],
                "nma_command_cycles": source["nmaforge_cycles"],
                "nma_compute_cycles": "N/A; Matrix command interval includes service/wait",
                "nma_host_cycles": "N/A",
                "nma_dma_cycles": "N/A",
                "nma_graph_orchestration_cycles": "N/A",
                "nma_prefill_cycles": "N/A",
                "nma_decode_cycles": "N/A",
                "decode_tokens": "N/A",
                "nma_mac_per_cycle": source["nmaforge_mac_per_cycle"],
                "nma_pe_utilization_pct": source["nmaforge_pe_utilization_pct"],
                "nma_spad_read_bytes": source["nmaforge_spad_read_bytes"],
                "nma_spad_write_bytes": source["nmaforge_spad_write_bytes"],
                "nma_host_layout_read_bytes": "N/A",
                "nma_host_layout_write_bytes": "N/A",
                "nma_ddr_traffic_bytes": "N/A",
                "nma_stall_breakdown_json": json.dumps(stalls, sort_keys=True),
                "tiny_npu_measured_cycles": source["tinynpu_direct_array_cycles"],
                "tiny_npu_mac_per_cycle": source["tinynpu_mac_per_cycle"],
                "tiny_npu_pe_utilization_pct": source["tinynpu_pe_utilization_pct"],
                "tiny_npu_spad_read_bytes": source["tinynpu_spad_read_bytes"] or "N/A",
                "tiny_npu_spad_write_bytes": source["tinynpu_spad_write_bytes"] or "N/A",
                "tiny_npu_common_memory_estimated_cycles": source["tinynpu_common_memory_estimated_cycles"],
                "golden_result": "NMAForge {}; TinyNPU {}".format(
                    source["golden_nmaforge"], source["golden_tinynpu"]),
                "classification_result": "N/A",
                "seed": source["nmaforge_seed"],
                "measurement_status": "NMA RTL measured; Tiny direct array measured; common-memory endpoint estimated",
                "measurement_boundary": source["measurement_boundary_nmaforge"] + " | " +
                                        source["measurement_boundary_tinynpu"],
                "evidence_path": filename,
            })

    capacity = json.loads((BENCH / "v2_spad_capacity_study_20261106.json").read_text())
    for source in capacity["results"]:
        if source["workload"].startswith("TinyNPU conv1x_mini") or \
                source["workload"].startswith("Trained 10-class Digits CNN"):
            trained = source["workload"].startswith("Trained 10-class")
            tiny = capacity.get("tiny_npu_mini_cnn", {})
            rows.append({
                "run_id": source["run_id"],
                "workload_family": "CNN",
                "workload": source["workload"],
                "shape": "Digits 8x8 CNN" if trained else "conv1x_mini.onnx; one deterministic input",
                "capacity_kib": source["capacity_kib"],
                "nmaforge_source_sha": source["source_sha"],
                "product_rtl_sha": capacity["product_rtl_sha"],
                "model_sha256": source["model_sha256"] or tiny.get("tiny_model_sha256", "N/A"),
                "test_data_sha256": source.get("testset_sha256") or "N/A; fixed single input",
                "tiny_npu_reference_sha": TINY_SHA if not trained else "N/A; this model not run on TinyNPU",
                "array_macs": 256,
                "datatype": "INT8; INT32 accumulator/Golden",
                "useful_macs": na(source["useful_macs"]),
                "nma_total_cycles": "N/A; host and compute intervals reported separately",
                "nma_command_cycles": "N/A",
                "nma_compute_cycles": source["rtl_compute_cycles"],
                "nma_host_cycles": source["host_layout_cycles"],
                "nma_dma_cycles": "N/A",
                "nma_graph_orchestration_cycles": "N/A",
                "nma_prefill_cycles": "N/A",
                "nma_decode_cycles": "N/A",
                "decode_tokens": "N/A",
                "nma_mac_per_cycle": na(source["mac_per_compute_cycle"]),
                "nma_pe_utilization_pct": ("{:.6f}".format(float(source["pe_utilization_estimate"]) * 100)
                                            if source["pe_utilization_estimate"] is not None else "N/A"),
                "nma_spad_read_bytes": na(source["spad_read_bytes"]),
                "nma_spad_write_bytes": na(source["spad_write_bytes"]),
                "nma_host_layout_read_bytes": na(source["host_layout_read_bytes"]),
                "nma_host_layout_write_bytes": na(source["host_layout_write_bytes"]),
                "nma_ddr_traffic_bytes": "N/A",
                "nma_stall_breakdown_json": "NOT_INSTRUMENTED_FOR_THIS_RUN",
                "tiny_npu_measured_cycles": "N/A; graph runtime not rerun in this study",
                "tiny_npu_mac_per_cycle": "N/A",
                "tiny_npu_pe_utilization_pct": "N/A",
                "tiny_npu_spad_read_bytes": "N/A",
                "tiny_npu_spad_write_bytes": "N/A",
                "tiny_npu_common_memory_estimated_cycles": "N/A",
                "golden_result": source["golden"],
                "classification_result": ("{}/{} = {:.2f}%".format(
                    source["correct"], source["samples"], float(source["accuracy"]) * 100)
                    if trained else "N/A"),
                "seed": "20261029",
                "measurement_status": "PASS; NMA Top behavioral-SPAD measured; Tiny timing NOT_RUN",
                "measurement_boundary": source["measurement_boundary"],
                "evidence_path": "v2_spad_capacity_study_20261106.json",
            })

    transformer = json.loads((BENCH / "v2_transformer_timing_f9f32f7.json").read_text())
    rows.append({
        "run_id": transformer["run_id"],
        "workload_family": "Transformer fixture",
        "workload": "Hand-authored fixed-weight ABI-v7 prefill/decode fixture; not trained model",
        "shape": "hidden=4; heads=1; 4-token prefill + 1-token decode",
        "capacity_kib": "N/A",
        "nmaforge_source_sha": transformer["source_test_sha"],
        "product_rtl_sha": transformer["product_rtl_sha"],
        "model_sha256": "N/A; deterministic fixture weights",
        "test_data_sha256": transformer["fixture_sha256"],
        "tiny_npu_reference_sha": "N/A; no TinyNPU run",
        "array_macs": 256,
        "datatype": "INT8",
        "useful_macs": "N/A",
        "nma_total_cycles": transformer["timing"]["total_cycles"],
        "nma_command_cycles": transformer["timing"]["total_cycles"],
        "nma_compute_cycles": "N/A; not separated from fetch/SPAD/completion",
        "nma_host_cycles": "N/A",
        "nma_dma_cycles": "N/A",
        "nma_graph_orchestration_cycles": "N/A",
        "nma_prefill_cycles": transformer["timing"]["prefill_cycles"],
        "nma_decode_cycles": transformer["timing"]["decode_cycles"],
        "decode_tokens": transformer["timing"]["decode_tokens"],
        "nma_mac_per_cycle": "N/A",
        "nma_pe_utilization_pct": "N/A",
        "nma_spad_read_bytes": "N/A",
        "nma_spad_write_bytes": "N/A",
        "nma_host_layout_read_bytes": "N/A",
        "nma_host_layout_write_bytes": "N/A",
        "nma_ddr_traffic_bytes": "N/A",
        "nma_stall_breakdown_json": "NOT_INSTRUMENTED_FOR_THIS_RUN",
        "tiny_npu_measured_cycles": "N/A",
        "tiny_npu_mac_per_cycle": "N/A",
        "tiny_npu_pe_utilization_pct": "N/A",
        "tiny_npu_spad_read_bytes": "N/A",
        "tiny_npu_spad_write_bytes": "N/A",
        "tiny_npu_common_memory_estimated_cycles": "N/A",
        "golden_result": "{}/{} intermediate/final/KV checks PASS".format(
            transformer["golden_checks_passed"], transformer["golden_checks_passed"]),
        "classification_result": "N/A; fixture is not trained",
        "seed": transformer["seed"],
        "measurement_status": "PASS_SCOPED fixture; trained Transformer requirement PARTIAL",
        "measurement_boundary": "Top CMDQ doorbell-to-completion; includes fetch/dispatch, compute, behavioral SPAD, completions; 1 decode token only",
        "evidence_path": "v2_transformer_timing_f9f32f7.json",
    })

    return rows


def main():
    rows = matrix_rows()
    with OUT_CSV.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS, extrasaction="ignore",
                                lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    manifest = {
        "run_id": "V2-RESEARCH-BENCHMARK-MATRIX-20261106",
        "status": "FIXED_MATRIX_WITH_EXPLICIT_NA_AND_ESTIMATE_BOUNDARIES",
        "tiny_npu_reference_sha": TINY_SHA,
        "product_rtl_sha": PRODUCT_RTL_SHA,
        "rows": len(rows),
        "csv": OUT_CSV.name,
        "csv_sha256": hashlib.sha256(OUT_CSV.read_bytes()).hexdigest(),
        "inputs": [
            "v2_tinynpu_gemm_current_20261106.csv",
            "v2_tinynpu_gemv_current_20261106.csv",
            "v2_spad_capacity_study_20261106.json",
            "v2_transformer_timing_f9f32f7.json",
        ],
        "innovation_ablation_evidence": [
            "v2_p2_gemv_cache_prefetch_4way_85e7db2.csv",
            "v2_p2_tile_forward_3seed.csv",
            "docs/benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md",
        ],
        "limitations": [
            "TinyNPU GEMM/GEMV cycles are direct-array RTL; common-memory endpoint is estimated.",
            "CNN TinyNPU graph runtime is not measured in the capacity study; its Golden is independently matched.",
            "Transformer row is a fixed-weight fixture, not a trained model.",
            "Behavioral SPAD metrics are not ASIC PPA or physical SRAM measurements.",
            "N/A means the corresponding measurement was not collected; do not infer zero.",
        ],
    }
    OUT_JSON.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("wrote {} rows to {} and {}".format(len(rows), OUT_CSV, OUT_JSON))


if __name__ == "__main__":
    main()
