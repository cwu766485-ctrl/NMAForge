#!/usr/bin/env python3
"""Build the R152 matrix benchmark evidence CSV from preserved VCS logs."""

import argparse
import csv
import re
from pathlib import Path
from typing import Dict, List, Optional, Pattern


CASE_RE = re.compile(r"MATRIX_CORE_CASE_PASS (?P<fields>.*)")
PROFILE_RE = re.compile(r"MATRIX_CORE_PROFILE (?P<fields>.*)")
PASS_RE = re.compile(r"MATRIX_SIZE_BENCHMARK_PASS (?P<fields>.*)")
TOKEN_RE = re.compile(r"([A-Za-z0-9_]+)=([^ ]+)")
CASE_NAMES = {
    100: "4x4x32",
    101: "8x8x32",
    102: "16x16x32",
    103: "16x32x32",
    104: "32x32x64",
}
CONFIGS = [(d, p, c) for d in (2, 4) for p in (0, 1) for c in (0, 1)]
COLUMNS = [
    "benchmark_type", "source_sha", "run_id", "seed", "physical_array",
    "outstanding_depth", "next_k_prefetch", "a_tile_cache", "case_id",
    "workload", "m", "n", "k", "cycles", "mac_count", "macs_per_cycle",
    "array_utilization_pct", "effective_gops_250mhz_assumption", "bank_reads",
    "bank_read_bytes", "line_write_bytes", "spad_bytes_total", "bank_stalls",
    "line_stalls", "arbiter_stall_cycles", "response_wait_cycles",
    "writeback_wait_cycles", "prefetch_wait_cycles", "outstanding_highwater",
    "fifo_full_cycles", "golden", "memory_model", "sim_period_ns", "run_log",
]


def tokens(pattern: Pattern[str], line: str) -> Optional[Dict[str, str]]:
    match = pattern.search(line)
    if match is None:
        return None
    return dict(TOKEN_RE.findall(match.group("fields")))


def parse_run(log_path: Path, seed: int, array: str, depth: int, prefetch: int, cache: int,
              source_sha: str, run_id: str, benchmark_type: str) -> List[Dict[str, str]]:
    content = log_path.read_text(errors="replace")
    pass_rows = [tokens(PASS_RE, line) for line in content.splitlines()]
    pass_rows = [row for row in pass_rows if row is not None]
    if len(pass_rows) != 1:
        raise ValueError(f"expected exactly one benchmark PASS marker: {log_path}")
    marker = pass_rows[0]
    expected = {
        "seed": str(seed), "physical_array": array,
        "outstanding_depth": str(depth), "next_k_prefetch": str(prefetch),
        "a_tile_cache": str(cache),
    }
    for key, value in expected.items():
        if marker.get(key) != value:
            raise ValueError(f"{log_path}: expected {key}={value}, got {marker.get(key)}")

    cases: dict[int, dict[str, str]] = {}
    profiles: dict[int, dict[str, str]] = {}
    for line in content.splitlines():
        row = tokens(CASE_RE, line)
        if row is not None and row.get("physical_array") == array:
            cases[int(row["id"])] = row
        row = tokens(PROFILE_RE, line)
        if row is not None:
            profiles[int(row["id"])] = row
    if set(cases) != set(CASE_NAMES) or set(profiles) != set(CASE_NAMES):
        raise ValueError(f"{log_path}: expected cases and profiles 100-104")

    result = []
    for case_id, name in CASE_NAMES.items():
        case = cases[case_id]
        profile = profiles[case_id]
        m, n, k = (int(value) for value in case["shape_mnk"].split(","))
        read_bytes = int(case["bank_read_bytes"])
        write_bytes = int(case["line_write_bytes"])
        result.append({
            "benchmark_type": benchmark_type,
            "source_sha": source_sha,
            "run_id": run_id,
            "seed": str(seed),
            "physical_array": array,
            "outstanding_depth": str(depth),
            "next_k_prefetch": str(prefetch),
            "a_tile_cache": str(cache),
            "case_id": str(case_id),
            "workload": name,
            "m": str(m), "n": str(n), "k": str(k),
            "cycles": case["cycles"],
            "mac_count": str(m * n * k),
            "macs_per_cycle": case["macs_per_cycle"],
            "array_utilization_pct": case["array_utilization_pct"],
            "effective_gops_250mhz_assumption": case["effective_gops_250mhz"],
            "bank_reads": case["bank_reads"],
            "bank_read_bytes": str(read_bytes),
            "line_write_bytes": str(write_bytes),
            "spad_bytes_total": str(read_bytes + write_bytes),
            "bank_stalls": case["bank_stalls"],
            "line_stalls": case["line_stalls"],
            "arbiter_stall_cycles": profile["arbiter_stall"],
            "response_wait_cycles": profile["response_wait"],
            "writeback_wait_cycles": profile["writeback_wait"],
            "prefetch_wait_cycles": profile["prefetch_wait"],
            "outstanding_highwater": profile["outstanding_highwater"],
            "fifo_full_cycles": profile["fifo_full"],
            "golden": "PASS",
            "memory_model": "behavioral SPAD; 1-cycle bank response",
            "sim_period_ns": "10",
            "run_log": str(log_path),
        })
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, action="append", required=True)
    parser.add_argument("--size-root", action="append", required=True,
                        help="SEED=PATH for matrix-size-benchmark output")
    parser.add_argument("--config-root", action="append", required=True,
                        help="SEED=PATH for matrix-config-comparison output")
    args = parser.parse_args()
    size_roots = {int(key): Path(value) for key, value in
                  (item.split("=", 1) for item in args.size_root)}
    config_roots = {int(key): Path(value) for key, value in
                    (item.split("=", 1) for item in args.config_root)}
    if set(size_roots) != set(args.seed) or set(config_roots) != set(args.seed):
        raise SystemExit("each requested seed must have exactly one size-root and config-root")

    rows: List[Dict[str, str]] = []
    for seed in args.seed:
        for physical in (4, 8, 16):
            rows.extend(parse_run(
                size_roots[seed] / f"array_{physical}" / "run.log", seed,
                f"{physical}x{physical}", 4, 1, 1, args.source_sha,
                f"R152-MATRIX-SIZE-3S-20261101-SEED{seed}", "array_size",
            ))
        for depth, prefetch, cache in CONFIGS:
            rows.extend(parse_run(
                config_roots[seed] / f"depth_{depth}" / f"prefetch_{prefetch}" /
                f"cache_{cache}" / "run.log", seed, "16x16", depth, prefetch,
                cache, args.source_sha,
                f"R152-MATRIX-ABLATION-3S-20261101-SEED{seed}", "config_ablation",
            ))
    if len(rows) != len(args.seed) * 55:
        raise SystemExit(f"expected {len(args.seed) * 55} rows, got {len(rows)}")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=COLUMNS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"R152 three-seed Matrix CSV: {args.out}; rows={len(rows)}")


if __name__ == "__main__":
    main()
