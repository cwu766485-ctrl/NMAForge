#!/usr/bin/env python3
"""Validate and summarize passive per-command profiles from Top UVM logs."""

import argparse
import csv
import json
import re
from pathlib import Path


MARKER = "V2_MATRIX_PROFILE_CSV,"
STATE_FIELDS = [
    "st_idle", "st_a_req", "st_a_wait", "st_b_req", "st_b_wait",
    "st_bias_req", "st_bias_wait", "st_prep_mac", "st_mac", "st_write",
    "st_next", "st_done", "st_error", "st_error_drain",
    "st_prefetch_wait",
]
INTEGER_FIELDS = [
    "seed", "internal_cycles", "doorbell_to_cpl_cycles", "exclusive_state_sum",
    "spad_read_bytes", "spad_write_bytes", *STATE_FIELDS,
    "arbiter_stall", "response_wait", "writeback_wait", "prefetch_a_req",
    "prefetch_a_drain", "prefetch_b_req", "prefetch_b_drain",
    "prefetch_overlap", "prefetch_wait", "prefetch_completed",
    "outstanding_highwater", "fifo_full", "a_tile_cache_hits",
]


def parse_profiles(log_path):
    text = log_path.read_text(errors="replace")
    matches = [line.split(MARKER, 1)[1].strip() for line in text.splitlines()
               if MARKER in line]
    if not matches:
        raise ValueError(f"{log_path}: no Matrix profile markers found")

    rows = []
    for match in matches:
        fields = {}
        for item in match.split(","):
            key, sep, value = item.partition("=")
            if not sep or key in fields:
                raise ValueError(f"{log_path}: malformed or duplicate profile field {item!r}")
            fields[key] = value

        missing = (set(INTEGER_FIELDS) | {"shape"}) - fields.keys()
        if missing:
            raise ValueError(f"{log_path}: missing profile fields {sorted(missing)}")
        if fields["shape"] != "16x32x64":
            raise ValueError(f"{log_path}: unexpected profile shape {fields['shape']}")
        fields.setdefault("profile", "standalone")
        for name in INTEGER_FIELDS:
            fields[name] = int(fields[name])

        state_sum = sum(fields[name] for name in STATE_FIELDS)
        if state_sum != fields["internal_cycles"] or state_sum != fields["exclusive_state_sum"]:
            raise ValueError(f"{log_path}: FSM state sum {state_sum} does not close to cycle counters")
        rows.append(fields)

    for marker in ("[COMPUTE_CLUSTER_REAL_UVM_PASS]", "[CLUSTER_A_CACHE_BASELINE_PASS]"):
        if marker not in text:
            raise ValueError(f"{log_path}: missing required pass marker {marker}")
    for severity in ("WARNING", "ERROR", "FATAL"):
        count = re.findall(rf"^UVM_{severity}\s*:\s*(\d+)\s*$", text, re.MULTILINE)
        if not count or any(int(value) != 0 for value in count):
            raise ValueError(f"{log_path}: UVM_{severity} summary missing or nonzero: {count}")
    for row in rows:
        row["test_status"] = "PASS"
        row["golden_output_words"] = 512
        row["uvm_warning"] = 0
        row["uvm_error"] = 0
        row["uvm_fatal"] = 0
        row["log_path"] = str(log_path)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-root", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--tree-sha", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--expected-seeds", default="20261125,20261126,20261127")
    parser.add_argument("--required-profiles", default="standalone")
    parser.add_argument("--vcs-version", default="V-2023.12-SP1_Full64")
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()

    expected_seeds = [int(seed) for seed in args.expected_seeds.split(",") if seed]
    seed_dirs = sorted(args.run_root.glob("seed_*"))
    if [int(path.name[len("seed_"):]) for path in seed_dirs] != expected_seeds:
        raise SystemExit(
            f"expected seed directories {expected_seeds}, found "
            f"{[path.name for path in seed_dirs]}"
        )
    required_profiles = set(
        profile for profile in args.required_profiles.split(",") if profile
    )
    rows = []
    for seed_dir, seed in zip(seed_dirs, expected_seeds):
        seed_rows = parse_profiles(seed_dir / "run.log")
        if any(row["seed"] != seed for row in seed_rows):
            raise SystemExit(f"seed directory {seed} contains a profile for another seed")
        profiles = [row["profile"] for row in seed_rows]
        if len(profiles) != len(set(profiles)):
            raise SystemExit(f"seed directory {seed} has duplicate profiles: {profiles}")
        if not required_profiles.issubset(set(profiles)):
            raise SystemExit(
                f"seed directory {seed} missing profiles: "
                f"{sorted(required_profiles - set(profiles))}"
            )
        rows.extend(seed_rows)

    macs = 16 * 32 * 64
    for row in rows:
        row["mac_operations"] = macs
        row["effective_mac_per_internal_cycle"] = round(macs / row["internal_cycles"], 6)
        row["effective_array_utilization_percent"] = round(
            100 * macs / (256 * row["internal_cycles"]), 6
        )
        row["effective_mac_per_doorbell_cycle"] = round(
            macs / row["doorbell_to_cpl_cycles"], 6
        )
        row["source_sha"] = args.source_sha
        row["tree_sha"] = args.tree_sha
        row["run_id"] = args.run_id
        row["vcs_version"] = args.vcs_version
        row["memory_model"] = "4-bank behavioral SPAD; registered one-cycle bank response"

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    columns = [
        "run_id", "source_sha", "tree_sha", "vcs_version", "seed", "profile", "shape",
        "test_status", "mac_operations", "internal_cycles", "doorbell_to_cpl_cycles",
        "effective_mac_per_internal_cycle", "effective_mac_per_doorbell_cycle",
        "effective_array_utilization_percent", "spad_read_bytes", "spad_write_bytes",
        "exclusive_state_sum", *STATE_FIELDS, "arbiter_stall", "response_wait",
        "writeback_wait", "prefetch_a_req", "prefetch_a_drain", "prefetch_b_req",
        "prefetch_b_drain", "prefetch_overlap", "prefetch_wait", "prefetch_completed",
        "outstanding_highwater", "fifo_full", "a_tile_cache_hits", "golden_output_words",
        "uvm_warning", "uvm_error", "uvm_fatal", "memory_model", "log_path",
    ]
    with args.csv.open("w", newline="") as stream:
        writer = csv.DictWriter(
            stream, fieldnames=columns, extrasaction="ignore", lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)

    output = {
        "run_id": args.run_id,
        "status": "PASS",
        "source_sha": args.source_sha,
        "tree_sha": args.tree_sha,
        "vcs_version": args.vcs_version,
        "memory_model": rows[0]["memory_model"],
        "workload": {"shape": "16x32x64", "mac_operations": macs, "physical_macs": 256},
        "method": {
            "internal_cycles": "Matrix cycle_count; exclusive FSM state counters are asserted to sum exactly",
            "doorbell_to_cpl_cycles": "Top testbench wall-clock cycles, including AXI-Lite doorbell and completion polling",
            "spad_bytes": "accepted Matrix banked reads and accepted Matrix line writes only",
            "stall_counters": "diagnostic event counts; may overlap and must not be summed",
            "array_utilization": "MAC operations / (256 physical MACs * Matrix internal cycles)",
        },
        "seed_ids": expected_seeds,
        "profiles": rows,
    }
    args.json.write_text(json.dumps(output, indent=2) + "\n")
    print(f"PASS: {len(rows)} command profiles; FSM cycles close; outputs={args.csv} {args.json}")


if __name__ == "__main__":
    main()
