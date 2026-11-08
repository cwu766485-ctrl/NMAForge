#!/usr/bin/env python3
"""Create reproducible paired small-GEMV CSV/JSON from VCS and TinyNPU logs."""

import argparse
import csv
import json
import re
from pathlib import Path


FIELD_RE = re.compile(r"([A-Za-z_]+)=([^\s]+)")
STAGES = (
    "a_req", "a_wait", "b_req", "b_wait", "bias_req", "bias_wait",
    "prep_mac", "mac", "write", "next", "done", "error",
    "error_drain", "prefetch_wait",
)
CSV_FIELDS = (
    "run_id", "design", "source_sha", "reference_sha", "seed", "shape_mnk",
    "mapping", "physical_array", "macs", "rtl_cycles", "normalized_cycles",
    "mac_per_cycle", "pe_utilization_pct", "spad_read_bytes",
    "spad_write_bytes", "bank_stalls", "line_stalls", "a_req_cycles",
    "a_wait_cycles", "b_req_cycles", "b_wait_cycles", "prep_mac_cycles",
    "mac_cycles", "write_cycles", "next_cycles", "prefetch_wait_cycles",
    "arbiter_stall_cycles", "response_wait_cycles", "writeback_wait_cycles",
    "golden", "measurement_boundary",
)


def parse_fields(line):
    return dict(FIELD_RE.findall(line))


def find_line(path, prefix, shape):
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith(prefix) and "shape=" + shape in line:
            return line
    raise SystemExit("missing %s shape=%s in %s" % (prefix, shape, path))


def find_tiny(path, shape):
    normalized = shape.replace("x", ",")
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("TINYNPU_MATCHED_GEMV_PASS ") and "shape_mnk=" + normalized in line:
            return parse_fields(line)
    raise SystemExit("missing TinyNPU GEMV %s in %s" % (shape, path))


def row_base(args, design, shape, mapping, macs):
    return {
        "run_id": args.run_id,
        "design": design,
        "source_sha": args.nma_sha if design == "NMAForge" else args.tiny_sha,
        "reference_sha": args.tiny_sha,
        "seed": args.seed,
        "shape_mnk": shape,
        "mapping": mapping,
        "physical_array": "16x16",
        "macs": str(macs),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--nma-sha", required=True)
    parser.add_argument("--tiny-sha", required=True)
    parser.add_argument("--seed", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--nma-log", type=Path, required=True)
    parser.add_argument("--tiny-log", type=Path, required=True)
    parser.add_argument("--vcs-version", required=True)
    parser.add_argument("--verilator-version", required=True)
    parser.add_argument("--out-csv", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    args = parser.parse_args()

    shapes = (
        ("1x13x17", 1 * 13 * 17, "MATRIX_CORE_GEMV_KFOLD_TAIL_PASS",
         "MATRIX_CORE_GEMV_TAIL_PROFILE"),
        ("8x16x19", 8 * 16 * 19, "MATRIX_CORE_GEMV_KFOLD_MROWS_TAIL_PASS",
         "MATRIX_CORE_GEMV_MROWS_PROFILE"),
        ("16x16x19", 16 * 16 * 19, "MATRIX_CORE_GEMV_KFOLD_MROWS_TAIL_PASS",
         "MATRIX_CORE_GEMV_MROWS_PROFILE"),
        ("16x16x65", 16 * 16 * 65, "MATRIX_CORE_GEMV_KFOLD_MROWS_TAIL_PASS",
         "MATRIX_CORE_GEMV_MROWS_PROFILE"),
    )
    nma_events = {}
    tiny_events = {}
    rows = []
    summaries = []
    for shape, macs, marker_prefix, profile_prefix in shapes:
        marker = find_line(args.nma_log, marker_prefix, shape)
        profile = find_line(args.nma_log, profile_prefix, shape)
        nma = parse_fields(marker)
        nma_profile = parse_fields(profile)
        tiny = find_tiny(args.tiny_log, shape)

        for field in ("cycles", "read_bytes", "outputs"):
            if field not in nma:
                raise SystemExit("missing NMAForge field %s for %s" % (field, shape))
        if nma.get("golden") != "bit-exact":
            raise SystemExit("NMAForge Golden marker did not pass for %s" % shape)
        if int(tiny["golden"].split("/")[0]) != int(tiny["golden"].split("/")[1]):
            raise SystemExit("TinyNPU output Golden count mismatch for %s" % shape)

        nma_cycles = int(nma["cycles"])
        tiny_cycles = int(tiny["cycles_input_to_array_stable"])
        read_bytes = int(nma["read_bytes"])
        if shape == "1x13x17":
            write_bytes = int(nma["lines"]) * 16 + int(nma["scalar"]) * 4
        else:
            write_bytes = int(nma["lines"]) * 16
        tiny_read_service = (read_bytes + 15) // 16 + 1
        tiny_write_service = (write_bytes + 15) // 16
        tiny_normalized = tiny_read_service + tiny_cycles + tiny_write_service + 2

        common_profile = {
            "a_req_cycles": nma_profile.get("a_req", "N/A"),
            "a_wait_cycles": nma_profile.get("a_wait", "N/A"),
            "b_req_cycles": nma_profile.get("b_req", "N/A"),
            "b_wait_cycles": nma_profile.get("b_wait", "N/A"),
            "prep_mac_cycles": nma_profile.get("prep_mac", "N/A"),
            "mac_cycles": nma_profile.get("mac", "N/A"),
            "write_cycles": nma_profile.get("write", "N/A"),
            "next_cycles": nma_profile.get("next", "N/A"),
            "prefetch_wait_cycles": nma_profile.get("prefetch_wait", "N/A"),
            "arbiter_stall_cycles": nma_profile.get("arbiter_stall", "N/A"),
            "response_wait_cycles": nma_profile.get("response_wait", "N/A"),
            "writeback_wait_cycles": nma_profile.get("writeback_wait", "N/A"),
        }
        profiled_state_cycles = sum(int(nma_profile.get(stage, "0")) for stage in STAGES)
        if profiled_state_cycles != nma_cycles:
            raise SystemExit("NMAForge exclusive state profile %d != command cycles %d for %s" %
                             (profiled_state_cycles, nma_cycles, shape))
        nma_row = row_base(args, "NMAForge", shape,
                           "0x52 K-fold product Matrix controller", macs)
        nma_row.update({
            "rtl_cycles": str(nma_cycles),
            "normalized_cycles": str(nma_cycles),
            "mac_per_cycle": "%.4f" % (macs / nma_cycles),
            "pe_utilization_pct": "%.2f" % (100.0 * macs / (256 * nma_cycles)),
            "spad_read_bytes": str(read_bytes),
            "spad_write_bytes": str(write_bytes),
            "bank_stalls": nma_profile.get("bank_stalls", "N/A"),
            "line_stalls": nma_profile.get("line_stalls", "N/A"),
            "golden": "PASS: all valid output words",
            "measurement_boundary": "Matrix core start through final output commit; registered four-bank behavioral SPAD with seeded readiness/latency",
            **common_profile,
        })
        tiny_row = row_base(args, "TinyNPU", shape,
                            "zero-padded inputs to direct shared 16x16 systolic array; no TinyNPU M=1 GEMV descriptor/SPAD path", macs)
        tiny_row.update({
            "rtl_cycles": str(tiny_cycles),
            "normalized_cycles": str(tiny_normalized),
            "mac_per_cycle": "%.4f" % (macs / tiny_cycles),
            "pe_utilization_pct": "%.2f" % (100.0 * macs / (256 * tiny_cycles)),
            "spad_read_bytes": "N/A; modeled %d" % read_bytes,
            "spad_write_bytes": "N/A; modeled %d" % write_bytes,
            "bank_stalls": "N/A",
            "line_stalls": "N/A",
            "golden": "PASS: %s/%s outputs" % tuple(tiny["golden"].split("/")),
            "measurement_boundary": "direct TinyNPU array RTL only; normalized endpoint adds serialized common-memory model and accumulator clear",
            **{key: "N/A" for key in common_profile},
        })
        rows.extend((nma_row, tiny_row))
        summaries.append({
            "shape": shape,
            "macs": macs,
            "golden": "PASS on both designs",
            "nmaforge_cycles": nma_cycles,
            "nmaforge_spad_read_bytes": read_bytes,
            "nmaforge_spad_write_bytes": write_bytes,
            "tinynpu_direct_array_cycles": tiny_cycles,
            "tinynpu_modeled_read_service_cycles": tiny_read_service,
            "tinynpu_modeled_write_service_cycles": tiny_write_service,
            "tinynpu_normalized_cycles": tiny_normalized,
            "nmaforge_over_tinynpu_normalized_ratio": round(nma_cycles / tiny_normalized, 4),
            "nmaforge_stage_profile": nma_profile,
            "stall_counter_note": "arbiter/response/writeback/prefetch counters can overlap and must not be summed",
        })

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    args.out_csv.write_bytes(args.out_csv.read_bytes().replace(b"\r\n", b"\n"))

    summary = {
        "run_id": args.run_id,
        "nmaforge_source_sha": args.nma_sha,
        "tinynpu_source_sha": args.tiny_sha,
        "seed": args.seed,
        "vcs_version": args.vcs_version,
        "verilator_version": args.verilator_version,
        "workload": "four signed INT8 GEMV shapes, INT32 accumulation, no bias/requant",
        "array": "one shared 16x16 / 256-MAC array on each design",
        "tiny_npu_mapping": "TinyNPU has no tested product GEMV descriptor or scratchpad interface; M=1/8 inputs are padded into the 16x16 direct systolic array",
        "common_memory_model": {
            "line_bytes": 16,
            "bandwidth_bytes_per_cycle": 16,
            "read_response_latency_cycles": 1,
            "schedule": "serialized operand read, measured array execution, output write, and two accumulator-clear cycles",
            "tiny_memory_service": "modeled only; TinyNPU wrapper exposes no SPAD interface",
        },
        "stall_counter_note": "state-cycle counters are separate from event/wait counters; arbiter, response, writeback and prefetch waits can overlap",
        "cases": summaries,
        "status": "PASS for listed Golden checks; not a common-memory RTL comparison or product-level TinyNPU sign-off",
    }
    args.out_json.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print("GEMV_COMPARE_PASS run_id=%s cases=%d" % (args.run_id, len(summaries)))


if __name__ == "__main__":
    main()
