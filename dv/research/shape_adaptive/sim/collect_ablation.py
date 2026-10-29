#!/usr/bin/env python3
"""Collect the fixed-bandwidth schedule model around the RTL GEMV kernel."""

import argparse
import csv
import json
import re
from datetime import datetime, timezone
from pathlib import Path


CASE_RE = re.compile(
    r"CASE_PASS,seed=(\d+),m=(\d+),n=(\d+),k=(\d+),mode=(\d+),"
    r"gemv=(\d+),cycles=(\d+),macs=(\d+),fold=(\d+)"
)
PASS_RE = re.compile(r"SHAPE_ADAPTIVE_PASS seed=(\d+) cases=12")


def ceil_div(value, divisor):
    return (value + divisor - 1) // divisor


def total_cycles(tiles, load_cycles, compute_cycles, prefetch):
    if not prefetch:
        return tiles * (load_cycles + compute_cycles)
    return load_cycles + tiles * compute_cycles + (tiles - 1) * max(0, load_cycles - compute_cycles)


def collect_log(path, expected_seed):
    text = path.read_text(encoding="utf-8", errors="replace")
    pass_seeds = {int(match.group(1)) for match in PASS_RE.finditer(text)}
    if pass_seeds != {expected_seed}:
        raise RuntimeError(f"missing PASS marker for seed {expected_seed}: {path}")
    if "ABORT_RESET_PASS" not in text or "BAD_CONFIG_PASS" not in text:
        raise RuntimeError(f"abort/reset or bad-config checker did not pass: {path}")

    cases = {}
    for match in CASE_RE.finditer(text):
        seed, m, n, k, mode, selected, cycles, macs, fold = map(int, match.groups())
        key = (seed, m, n, k)
        mode_cases = cases.setdefault(key, {})
        mode_cases[str(mode)] = {
            "selected_gemv": selected,
            "rtl_compute_cycles": cycles,
            "useful_macs": macs,
            "k_parallel": fold,
        }
    if len(cases) != 12 or any(set(result) != {"0", "1"} for result in cases.values()):
        raise RuntimeError(f"expected 12 baseline/GEMV case pairs, got {len(cases)} in {path}")
    return cases


def make_row(seed, m, n, k, mode, prefetch, case):
    fold = case["k_parallel"]
    tiles = k if mode == 0 else ceil_div(k, fold)
    useful_macs = m * n * k
    tile_data_bytes = m + n if mode == 0 else fold * (m + n)
    words_per_tile = max(1, ceil_div(tile_data_bytes, 32))
    read_bytes = tiles * words_per_tile * 32
    logical_read_bytes = k * (m + n)
    load_cycles = words_per_tile
    rtl_compute_cycles = case["rtl_compute_cycles"]
    compute_cycles_per_tile = 1 if mode == 0 else 2  # GEMV multiply then registered reduction.
    modeled_cycles = total_cycles(tiles, load_cycles, compute_cycles_per_tile, bool(prefetch))
    array_util = 100.0 * useful_macs / (256 * modeled_cycles)
    compute_util = 100.0 * useful_macs / (256 * rtl_compute_cycles)
    return {
        "seed": seed,
        "shape_mnk": f"{m}x{n}x{k}",
        "mapping": "baseline" if mode == 0 else "gemv_fold",
        "bandwidth_aware_prefetch": prefetch,
        "k_parallel": fold,
        "physical_macs": 256,
        "useful_macs": useful_macs,
        "rtl_compute_cycles": rtl_compute_cycles,
        "fixed_bandwidth_load_cycles_per_tile": load_cycles,
        "schedule_cycles": modeled_cycles,
        "mac_per_schedule_cycle": round(useful_macs / modeled_cycles, 4),
        "compute_window_utilization_pct": round(compute_util, 3),
        "end_to_end_array_utilization_pct": round(array_util, 3),
        "logical_operand_read_bytes": logical_read_bytes,
        "modeled_spad_read_bytes_including_beat_padding": read_bytes,
        "modeled_spad_write_bytes_int32": m * n * 4,
        "valid_bandwidth_bytes_per_cycle": 32,
        "modeled_bank_stall_cycles": 0,
        "speedup_vs_baseline_same_prefetch": 1.0,
        "golden": "PASS",
        "timing_source": "RTL compute cycles + fixed-bandwidth analytical schedule model",
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--seeds", nargs="+", type=int, required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--vcs-version", required=True)
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()

    rows = []
    workload_keys = set()
    for seed in args.seeds:
        cases = collect_log(args.run_dir / f"seed_{seed}.log", seed)
        for (log_seed, m, n, k), mapping in sorted(cases.items(), key=lambda item: item[0][1:]):
            if log_seed != seed:
                raise RuntimeError(f"unexpected seed marker {log_seed} in run {seed}")
            workload_keys.add((m, n, k))
            for mode in (0, 1):
                expected_cycles = k if mode == 0 else 2 * ceil_div(k, 16 // m)
                if mapping[str(mode)]["rtl_compute_cycles"] != expected_cycles:
                    raise RuntimeError(f"RTL cycle counter mismatch for {(m, n, k, mode)}")
                if mapping[str(mode)]["useful_macs"] != m*n*k:
                    raise RuntimeError(f"RTL MAC counter mismatch for {(m, n, k, mode)}")
                for prefetch in (0, 1):
                    rows.append(make_row(seed, m, n, k, mode, prefetch, mapping[str(mode)]))

    if len(workload_keys) != 12 or len(rows) != len(args.seeds) * 12 * 4:
        raise RuntimeError(f"unexpected workload/ablation count: {len(workload_keys)} / {len(rows)}")

    row_index = {}
    for row in rows:
        key = (int(row["seed"]), str(row["shape_mnk"]),
               int(row["bandwidth_aware_prefetch"]), str(row["mapping"]))
        row_index[key] = row
    for row in rows:
        if row["mapping"] == "gemv_fold":
            key = (int(row["seed"]), str(row["shape_mnk"]),
                   int(row["bandwidth_aware_prefetch"]), "baseline")
            baseline = row_index[key]
            row["speedup_vs_baseline_same_prefetch"] = round(
                float(baseline["schedule_cycles"]) / float(row["schedule_cycles"]), 4)

    fields = list(rows[0])
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    paired = {}
    for row in rows:
        key = (int(row["seed"]), str(row["shape_mnk"]))
        paired.setdefault(key, {})[(str(row["mapping"]), int(row["bandwidth_aware_prefetch"]))] = row
    speedups = {0: [], 1: []}
    for modes in paired.values():
        for prefetch in (0, 1):
            baseline = modes[("baseline", prefetch)]
            gemv = modes[("gemv_fold", prefetch)]
            speedups[prefetch].append(
                float(baseline["schedule_cycles"]) / float(gemv["schedule_cycles"]))

    summary = {
        "run_id": f"SHAPE-ADAPTIVE-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{args.source_sha[:8]}",
        "source_sha": args.source_sha,
        "vcs_version": args.vcs_version,
        "seeds": args.seeds,
        "cases_per_seed": len(workload_keys),
        "ablation_rows": len(rows),
        "logical_workloads": [f"{m}x{n}x{k}" for m, n, k in sorted(workload_keys)],
        "matched_valid_bandwidth_bytes_per_cycle": 32,
        "physical_macs": 256,
        "golden": "PASS for all baseline and GEMV RTL outputs",
        "mean_gemv_speedup_over_baseline_at_matched_prefetch": round(
            sum(speedups[0] + speedups[1]) / (len(speedups[0]) + len(speedups[1])), 4),
        "max_speedup_prefetch_off": round(max(speedups[0]), 4),
        "max_speedup_prefetch_on": round(max(speedups[1]), 4),
        "mean_speedup_prefetch_off": round(sum(speedups[0]) / len(speedups[0]), 4),
        "mean_speedup_prefetch_on": round(sum(speedups[1]) / len(speedups[1]), 4),
        "latency_boundary": "RTL compute cycles plus explicit fixed-bandwidth schedule model; not measured integrated SPAD latency",
        "bank_conflicts": "ideal conflict-free interleaving assumed; bank stalls are zero by model construction",
        "outputs": "benchmark/shape_adaptive_ablation.csv",
        "raw_run_directory": str(args.run_dir),
    }
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"SHAPE_ADAPTIVE_BENCHMARK_PASS run_id={summary['run_id']} rows={len(rows)} "
          f"workloads={len(workload_keys)} max_speedup_prefetch_off={summary['max_speedup_prefetch_off']} "
          f"max_speedup_prefetch_on={summary['max_speedup_prefetch_on']}")


if __name__ == "__main__":
    main()
