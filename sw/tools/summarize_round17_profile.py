#!/usr/bin/env python3
"""Join Round 17 H16 descriptor, engine and SFU profiles from a Top VCS run."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path


def fields(line: str) -> dict[str, str]:
    return dict(re.findall(r"([a-zA-Z_][a-zA-Z0-9_]*)=([^ ]+)", line))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--vcs-version", required=True)
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--json", required=True, type=Path)
    args = parser.parse_args()

    run_dir = args.run_dir
    workload = run_dir / "workload"
    manifest = json.loads((workload / "manifest.json").read_text())
    log_text = (run_dir / "run.log").read_text(errors="replace")
    if "INCREMENTAL_DECODE_PASS " not in log_text:
        raise SystemExit("run log lacks four-step incremental decode PASS")

    intervals: dict[tuple[str, int], dict[str, str]] = {}
    stage_totals: dict[str, dict[str, str]] = {}
    matrix_by_stage: dict[str, list[dict[str, str]]] = defaultdict(list)
    kv_by_stage: dict[str, list[dict[str, str]]] = defaultdict(list)
    sfu_profiles: list[dict[str, str]] = []
    for line in log_text.splitlines():
        if line.startswith("R17_DESCRIPTOR_INTERVAL "):
            record = fields(line)
            intervals[(record["stage"], int(record["local_index"]))] = record
        elif line.startswith("R17_STAGE_OVERLAP "):
            record = fields(line)
            stage_totals[record["stage"]] = record
        elif line.startswith("R17_MATRIX_COMMAND "):
            record = fields(line)
            matrix_by_stage[record["stage"]].append(record)
        elif line.startswith("R17_KV_COMMAND "):
            record = fields(line)
            kv_by_stage[record["stage"]].append(record)
        elif line.startswith("R9_SFU_COMMAND "):
            sfu_profiles.append(fields(line))

    stage_pass = re.compile(
        r"^INCREMENTAL_H16_STAGE_PASS stage=(\S+) index=(\d+) desc=(\d+) "
        r"golden_words=(\d+) useful_macs=(\d+) cycles=(\d+) matrix_mac=(\d+) "
        r"matrix_wait=(\d+) matrix_rsp_wait=(\d+) matrix_writeback=(\d+) "
        r"matrix_other=(\d+) sfu=(\d+) kv=(\d+) dma_overlap=(\d+) "
        r"spad_read_bytes=(\d+) spad_write_bytes=(\d+)"
    )
    stage_summary = {}
    for line in log_text.splitlines():
        match = stage_pass.match(line)
        if match:
            values = match.groups()
            stage_summary[values[0]] = {
                "index": int(values[1]), "descriptor_count": int(values[2]),
                "golden_words": int(values[3]), "useful_macs": int(values[4]),
                "cycles": int(values[5]), "matrix_mac_cycles": int(values[6]),
                "matrix_request_wait_cycles": int(values[7]),
                "matrix_response_wait_cycles": int(values[8]),
                "matrix_writeback_cycles": int(values[9]),
                "matrix_other_cycles": int(values[10]),
                "sfu_cycles": int(values[11]), "kv_cycles": int(values[12]),
                "spad_read_bytes": int(values[14]),
                "spad_write_bytes": int(values[15]),
            }

    if len(stage_summary) != 5:
        raise SystemExit(f"expected five stage summaries, found {len(stage_summary)}")
    expected_total = sum(int(stage["descriptor_count"]) for stage in manifest["stages"])
    if len(intervals) != expected_total:
        raise SystemExit(f"descriptor intervals {len(intervals)} != {expected_total}")
    if len(stage_totals) != len(manifest["stages"]):
        raise SystemExit("missing stage overlap samples")

    expected_sfu = [
        (stage, descriptor)
        for stage in manifest["stages"]
        for descriptor in stage["descriptor_contract"]
        if descriptor["opcode"] in {0x32, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39}
    ]
    if len(sfu_profiles) != len(expected_sfu):
        raise SystemExit(
            f"SFU profiles {len(sfu_profiles)} != expected descriptors {len(expected_sfu)}"
        )

    rows: list[dict[str, object]] = []
    sfu_cursor = 0
    for stage in manifest["stages"]:
        stage_name = str(stage["name"])
        contracts = stage["descriptor_contract"]
        interval_sum = sum(
            int(intervals[(stage_name, index)]["cycles"])
            for index in range(len(contracts))
        )
        if interval_sum != stage_summary[stage_name]["cycles"]:
            raise SystemExit(
                f"completion intervals do not close stage {stage_name}: "
                f"{interval_sum} != {stage_summary[stage_name]['cycles']}"
            )
        overlap = int(stage_totals[stage_name]["cycles"])
        matrix_contracts = [d for d in contracts if d["opcode"] in {0x30, 0x31, 0x52, 0x53}]
        kv_contracts = [d for d in contracts if d["opcode"] in {0x43, 0x44}]
        matrix_records = matrix_by_stage[stage_name]
        kv_records = kv_by_stage[stage_name]
        if len(matrix_records) != len(matrix_contracts):
            raise SystemExit(
                f"matrix profiler count mismatch {stage_name}: "
                f"{len(matrix_records)} != {len(matrix_contracts)}"
            )
        if len(kv_records) != len(kv_contracts):
            raise SystemExit(
                f"KV profiler count mismatch {stage_name}: "
                f"{len(kv_records)} != {len(kv_contracts)}"
            )
        matrix_cursor = 0
        kv_cursor = 0
        for local_index, desc in enumerate(contracts):
            interval = intervals[(stage_name, local_index)]
            if int(interval["task_id"]) != int(desc["task_id"]):
                raise SystemExit(f"task ID mismatch {stage_name} descriptor {local_index}")
            if int(interval["opcode"], 16) != int(desc["opcode"]):
                raise SystemExit(f"opcode mismatch {stage_name} descriptor {local_index}")
            row: dict[str, object] = {
                "run_id": run_dir.name,
                "source_sha": args.source_sha,
                "model_sha256": manifest["model_sha256"],
                "seed": manifest["seed"],
                "vcs_version": args.vcs_version,
                "stage": stage_name,
                "phase": "prefill" if stage_name.startswith("prefill") else "decode",
                "descriptor_index": local_index,
                "task_id": desc["task_id"],
                "descriptor_name": desc["name"],
                "opcode": f"0x{desc['opcode']:02x}",
                "m": desc.get("m", ""), "n": desc.get("n", ""),
                "k_or_length": desc.get("k_or_length", ""),
                "flags": desc.get("flags", ""),
                "wait_mask": desc.get("wait_mask", ""),
                "signal_mask": desc.get("signal_mask", ""),
                "completion_interval_cycles": int(interval["cycles"]),
                "engine_busy_cycles": "",
                "dispatcher_completion_gap_cycles": "",
                "matrix_active_cycles": "", "matrix_request_wait_cycles": "",
                "matrix_response_wait_cycles": "", "matrix_writeback_cycles": "",
                "matrix_other_cycles": "", "sfu_pass0_cycles": "",
                "sfu_pass1_cycles": "", "sfu_pass2_cycles": "",
                "sfu_math_cycles": "", "sfu_other_cycles": "",
                "divider_busy_cycles_overlap": "", "sqrt_busy_cycles_overlap": "",
                "spad_request_stall_cycles_overlap": "",
                "spad_response_wait_cycles_overlap": "",
                "spad_read_bytes": "", "spad_write_bytes": "",
                "exclusive_engine_profile_closes": "N/A",
                "stage_engine_overlap_cycles": overlap,
                "golden": "PASS",
            }
            opcode = int(desc["opcode"])
            if opcode in {0x30, 0x31, 0x52, 0x53}:
                profile = matrix_records[matrix_cursor]
                matrix_cursor += 1
                engine_cycles = int(profile["cycles"])
                exclusive_sum = sum(int(profile[k]) for k in
                                    ("mac", "request_wait", "response_wait", "writeback", "other"))
                if exclusive_sum != engine_cycles or int(profile["exclusive_closed"]) != engine_cycles:
                    raise SystemExit(f"Matrix exclusive profile does not close {stage_name}/{local_index}")
                completion_gap = int(interval["cycles"]) - engine_cycles
                if overlap == 0 and completion_gap < 0:
                    raise SystemExit(f"Matrix engine time exceeds retirement interval {stage_name}/{local_index}")
                row.update({
                    "engine_busy_cycles": engine_cycles,
                    "dispatcher_completion_gap_cycles": (
                        completion_gap if overlap == 0 else ""
                    ),
                    "matrix_active_cycles": int(profile["mac"]),
                    "matrix_request_wait_cycles": int(profile["request_wait"]),
                    "matrix_response_wait_cycles": int(profile["response_wait"]),
                    "matrix_writeback_cycles": int(profile["writeback"]),
                    "matrix_other_cycles": int(profile["other"]),
                    "spad_read_bytes": int(profile["read_bytes"]),
                    "spad_write_bytes": int(profile["write_bytes"]),
                    "exclusive_engine_profile_closes": "PASS",
                })
            elif opcode in {0x32, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39}:
                profile = sfu_profiles[sfu_cursor]
                expected_stage, expected_desc = expected_sfu[sfu_cursor]
                sfu_cursor += 1
                if expected_stage["name"] != stage_name or expected_desc["name"] != desc["name"]:
                    raise SystemExit(f"SFU descriptor order mismatch {stage_name}/{local_index}")
                if (int(profile["opcode"], 16) != opcode or
                        int(profile["length"]) != int(desc["k_or_length"])):
                    raise SystemExit(f"SFU profile mismatch {stage_name}/{local_index}")
                engine_cycles = int(profile["cycles"])
                exclusive_sum = sum(int(profile[k]) for k in
                                    ("pass0", "pass1", "pass2", "math", "other"))
                if exclusive_sum != engine_cycles or int(profile["cycles_closed"]) != engine_cycles:
                    raise SystemExit(f"SFU exclusive profile does not close {stage_name}/{local_index}")
                completion_gap = int(interval["cycles"]) - engine_cycles
                if overlap == 0 and completion_gap < 0:
                    raise SystemExit(f"SFU engine time exceeds retirement interval {stage_name}/{local_index}")
                read_bytes = int(profile["spad_read_accepts"]) * 4
                write_bytes = int(profile["spad_write_accepts"]) * 4
                row.update({
                    "engine_busy_cycles": engine_cycles,
                    "dispatcher_completion_gap_cycles": (
                        completion_gap if overlap == 0 else ""
                    ),
                    "sfu_pass0_cycles": int(profile["pass0"]),
                    "sfu_pass1_cycles": int(profile["pass1"]),
                    "sfu_pass2_cycles": int(profile["pass2"]),
                    "sfu_math_cycles": int(profile["math"]),
                    "sfu_other_cycles": int(profile["other"]),
                    "divider_busy_cycles_overlap": int(profile["divider_busy"]),
                    "sqrt_busy_cycles_overlap": int(profile["sqrt_busy"]),
                    "spad_request_stall_cycles_overlap": int(profile["spad_request_stall"]),
                    "spad_response_wait_cycles_overlap": int(profile["spad_response_wait"]),
                    "spad_read_bytes": read_bytes,
                    "spad_write_bytes": write_bytes,
                    "exclusive_engine_profile_closes": "PASS",
                    "_expected_stage": expected_stage["name"],
                    "_expected_descriptor": expected_desc["name"],
                })
            elif opcode in {0x43, 0x44}:
                profile = kv_records[kv_cursor]
                kv_cursor += 1
                engine_cycles = int(profile["cycles"])
                completion_gap = int(interval["cycles"]) - engine_cycles
                if overlap == 0 and completion_gap < 0:
                    raise SystemExit(f"KV engine time exceeds retirement interval {stage_name}/{local_index}")
                row.update({
                    "engine_busy_cycles": engine_cycles,
                    "dispatcher_completion_gap_cycles": (
                        completion_gap if overlap == 0 else ""
                    ),
                    "spad_read_bytes": int(profile["read_bytes"]),
                    "spad_write_bytes": int(profile["write_bytes"]),
                    "exclusive_engine_profile_closes": "PARTIAL",
                })
            rows.append(row)

    # Remove private join keys from emitted records after validating SFU order.
    for row in rows:
        row.pop("_expected_stage", None)
        row.pop("_expected_descriptor", None)

    for stage in manifest["stages"]:
        name = str(stage["name"])
        scoped = [row for row in rows if row["stage"] == name]
        summary = stage_summary[name]
        checks = {
            "matrix_active_cycles": ("matrix_mac_cycles", None),
            "matrix_request_wait_cycles": ("matrix_request_wait_cycles", None),
            "matrix_response_wait_cycles": ("matrix_response_wait_cycles", None),
            "matrix_writeback_cycles": ("matrix_writeback_cycles", None),
            "matrix_other_cycles": ("matrix_other_cycles", None),
            "sfu_cycles": ("sfu_cycles", {0x32, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39}),
            "kv_cycles": ("kv_cycles", {0x43, 0x44}),
        }
        for field, (summary_field, opcode_filter) in checks.items():
            if opcode_filter is None:
                total = sum(int(row[field]) for row in scoped if row[field] != "")
            else:
                total = sum(int(row["engine_busy_cycles"]) for row in scoped
                            if int(str(row["opcode"]), 16) in opcode_filter)
            if total != summary[summary_field]:
                raise SystemExit(f"per-command {field} does not match stage {name}: {total} != {summary[summary_field]}")

    fieldnames = list(rows[0])
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    output = {
        "status": "PASS",
        "run_id": run_dir.name,
        "source_sha": args.source_sha,
        "model_sha256": manifest["model_sha256"],
        "seed": manifest["seed"],
        "vcs_version": args.vcs_version,
        "descriptor_count": len(rows),
        "stage_summaries": stage_summary,
        "multi_engine_overlap_cycles_by_stage": {
            name: int(record["cycles"]) for name, record in stage_totals.items()
        },
        "csv": str(args.csv),
        "timing_definition": "Per-descriptor completion-tail retirement interval; engine counters are sampled independently. Dispatcher/completion gap is emitted only when no engine overlap was observed in the stage.",
        "counter_semantics": [
            "Matrix MAC/request-wait/response-wait/writeback/other and SFU pass/math/other are exclusive engine-cycle buckets.",
            "Divider, sqrt, SPAD wait, and DMA observations overlap the exclusive buckets and are not additive.",
            "SPAD byte counts include accepted requests on the observed engine interfaces; they exclude the AXI preload image.",
            "The model contains 40 prefill descriptors and 50 descriptors per decode step; all descriptor intervals close to stage command cycles.",
        ],
        "commands": rows,
    }
    args.json.write_text(json.dumps(output, indent=2) + "\n")
    print(f"ROUND17_PROFILE_PASS descriptors={len(rows)} csv={args.csv} json={args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
