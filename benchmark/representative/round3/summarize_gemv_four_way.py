#!/usr/bin/env python3
"""Aggregate Round 3 GEMV cache/prefetch runs without copying local log paths."""

import argparse
import csv
import statistics
from pathlib import Path


DROP_COLUMNS = {"run_log", "compile_log"}
SUMMARY_FIELDS = [
    "shape_m",
    "shape_n",
    "shape_k",
    "b_fold_cache_enabled",
    "next_k_prefetch_enabled",
    "seeds",
    "cases",
    "mean_command_cycles",
    "min_command_cycles",
    "max_command_cycles",
    "mean_spad_read_bytes",
    "mean_spad_write_bytes",
    "mean_useful_macs_per_command_cycle",
    "mean_command_window_array_utilization_pct",
    "mean_prefetch_overlap_cycles",
    "mean_b_cache_fold_hits",
    "mean_b_read_transactions_saved",
    "paired_cycle_reduction_vs_off_off_pct",
    "all_bit_exact",
    "rtl_sha",
    "test_sha",
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument("--raw-out", required=True, type=Path)
    parser.add_argument("--summary-out", required=True, type=Path)
    args = parser.parse_args()

    inputs = sorted(args.input_dir.glob("summary_seed_*.csv"))
    if not inputs:
        raise SystemExit(f"no summary_seed_*.csv files in {args.input_dir}")

    rows = []
    for path in inputs:
        with path.open(newline="") as stream:
            rows.extend(csv.DictReader(stream))

    if len(rows) != 48:
        raise SystemExit(f"expected 48 rows (3 seeds x 4 shapes x 4 configs), got {len(rows)}")
    for row in rows:
        if row["golden"] != "bit-exact":
            raise SystemExit(f"non-passing Golden: {row['run_id']}={row['golden']}")

    fields = [field for field in rows[0] if field not in DROP_COLUMNS]
    args.raw_out.parent.mkdir(parents=True, exist_ok=True)
    with args.raw_out.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows({key: value for key, value in row.items() if key in fields} for row in rows)

    baseline = {}
    groups = {}
    for row in rows:
        key = (int(row["shape_m"]), int(row["shape_n"]), int(row["shape_k"]))
        cfg = (int(row["b_fold_cache_enabled"]), int(row["next_k_prefetch_enabled"]))
        groups.setdefault((key, cfg), []).append(row)
        if cfg == (0, 0):
            baseline[key] = row

    out = []
    for (shape, cfg), samples in sorted(groups.items()):
        cycles = [int(row["command_cycles"]) for row in samples]
        base_mean = statistics.mean(int(row["command_cycles"]) for row in groups[(shape, (0, 0))])
        mean_cycles = statistics.mean(cycles)
        first = samples[0]
        out.append(
            {
                "shape_m": shape[0],
                "shape_n": shape[1],
                "shape_k": shape[2],
                "b_fold_cache_enabled": cfg[0],
                "next_k_prefetch_enabled": cfg[1],
                "seeds": ";".join(sorted({row["seed"] for row in samples})),
                "cases": len(samples),
                "mean_command_cycles": f"{mean_cycles:.2f}",
                "min_command_cycles": min(cycles),
                "max_command_cycles": max(cycles),
                "mean_spad_read_bytes": f"{statistics.mean(int(row['spad_read_bytes']) for row in samples):.2f}",
                "mean_spad_write_bytes": f"{statistics.mean(int(row['spad_write_bytes']) for row in samples):.2f}",
                "mean_useful_macs_per_command_cycle": f"{statistics.mean(float(row['useful_macs_per_command_cycle']) for row in samples):.4f}",
                "mean_command_window_array_utilization_pct": f"{statistics.mean(float(row['command_window_array_utilization_pct']) for row in samples):.4f}",
                "mean_prefetch_overlap_cycles": f"{statistics.mean(int(row['prefetch_overlap_cycles']) for row in samples):.2f}",
                "mean_b_cache_fold_hits": f"{statistics.mean(int(row['b_cache_fold_hits']) for row in samples):.2f}",
                "mean_b_read_transactions_saved": f"{statistics.mean(int(row['b_read_transactions_saved']) for row in samples):.2f}",
                "paired_cycle_reduction_vs_off_off_pct": f"{(1.0 - mean_cycles / base_mean) * 100.0:.4f}",
                "all_bit_exact": all(row["golden"] == "bit-exact" for row in samples),
                "rtl_sha": first["rtl_sha"],
                "test_sha": first["test_sha"],
            }
        )

    with args.summary_out.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=SUMMARY_FIELDS)
        writer.writeheader()
        writer.writerows(out)
    print(f"GEMV_SUMMARY_PASS raw_rows={len(rows)} groups={len(out)} seeds={len(inputs)}")


if __name__ == "__main__":
    main()
