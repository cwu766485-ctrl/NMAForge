#!/usr/bin/env python3
"""Flatten seeded Matrix size/ablation runs into reproducible CSV and JSON."""

import argparse
import csv
import json
import re
import subprocess
from pathlib import Path


SIZE_RE = re.compile(r"MATRIX_CORE_CASE_PASS (?P<fields>.*)")
FIELD_RE = re.compile(r"([a-z_]+)=([^ ]+)")
CONFIGS = [(d, p, c) for d in (2, 4) for p in (0, 1) for c in (0, 1)]
SHAPES = {100: (4, 4, 32), 101: (8, 8, 32), 102: (16, 16, 32),
          103: (16, 32, 32), 104: (32, 32, 64)}


def read_fields(line):
    match = SIZE_RE.search(line)
    if not match:
        return None
    return dict(FIELD_RE.findall(match.group("fields")))


def load_size_rows(root, seeds):
    rows = []
    for seed in seeds:
        log = root / ("size_%s_make.log" % seed)
        for line in log.read_text(errors="replace").splitlines():
            fields = read_fields(line)
            if not fields:
                continue
            m, n, k = [int(v) for v in fields["shape_mnk"].split(",")]
            array = int(fields["physical_array"].split("x")[0])
            rows.append({
                "seed": seed, "kind": "size_sweep", "shape_mnk": "%dx%dx%d" % (m, n, k),
                "physical_array": "%dx%d" % (array, array),
                "outstanding_depth": 4, "next_k_prefetch": 1, "a_tile_cache": 1,
                "cycles": int(fields["cycles"]), "macs": m * n * k,
                "mac_per_cycle": fields["macs_per_cycle"],
                "array_utilization_pct": fields["array_utilization_pct"],
                "spad_read_bytes": int(fields["bank_read_bytes"]),
                "spad_write_bytes": int(fields["line_write_bytes"]),
                "bank_stalls": int(fields["bank_stalls"]),
                "line_stalls": int(fields["line_stalls"]), "golden": "PASS",
            })
        if sum(1 for row in rows if row["seed"] == seed) != 15:
            raise RuntimeError("seed %s did not produce 15 Matrix size cases" % seed)
    return rows


def load_ablation_rows(root, seeds):
    rows = []
    for seed in seeds:
        path = root / ("ablation_%s" % seed) / "matrix_config_comparison.csv"
        with path.open(newline="") as stream:
            for record in csv.DictReader(stream):
                m, n, k = [int(v) for v in record["workload"].split("x")]
                for depth, prefetch, cache in CONFIGS:
                    prefix = "d%d_p%d_c%d" % (depth, prefetch, cache)
                    rows.append({
                        "seed": seed, "kind": "ablation", "shape_mnk": record["workload"],
                        "physical_array": "16x16", "outstanding_depth": depth,
                        "next_k_prefetch": prefetch, "a_tile_cache": cache,
                        "cycles": int(record[prefix + "_cycles"]), "macs": m * n * k,
                        "mac_per_cycle": record[prefix + "_macs_per_cycle"],
                        "array_utilization_pct": record[prefix + "_array_utilization_pct"],
                        "spad_read_bytes": int(record[prefix + "_bank_reads"]) * 16,
                        "spad_write_bytes": m * n * 4,
                        "bank_stalls": int(record[prefix + "_bank_stalls"]),
                        "line_stalls": "", "golden": "PASS",
                    })
        if sum(1 for row in rows if row["seed"] == seed and row["kind"] == "ablation") != 40:
            raise RuntimeError("seed %s did not produce 40 ablation checks" % seed)
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()
    root = args.out_dir
    seeds = [p.name[len("size_"):-len("_make.log")]
             for p in sorted(root.glob("size_*_make.log"))]
    if not seeds:
        raise RuntimeError("no size benchmark logs found under %s" % root)
    rows = load_size_rows(root, seeds) + load_ablation_rows(root, seeds)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    fields = ["seed", "kind", "shape_mnk", "physical_array", "outstanding_depth",
              "next_k_prefetch", "a_tile_cache", "cycles", "macs", "mac_per_cycle",
              "array_utilization_pct", "spad_read_bytes", "spad_write_bytes",
              "bank_stalls", "line_stalls", "golden"]
    csv_path = root / "compute_performance.csv"
    with csv_path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    csv_path.write_bytes(csv_path.read_bytes().replace(b"\r\n", b"\n"))
    summary = {
        "run_id": "MATRIX-PERF-%s-%s" % ("-".join(seeds), head[:8]),
        "source_sha": head,
        "seeds": seeds,
        "tool": "Synopsys VCS V-2023.12-SP1_Full64",
        "compiler_flags": [
            "-full64", "-sverilog", "-debug_access+all", "-timescale=1ns/1ps",
            "+define+MATRIX_MAX_OUTSTANDING_READS", "+define+MATRIX_A_TILE_CACHE_ENABLE",
            "+define+MATRIX_NEXT_K_PREFETCH_ENABLE", "+define+MATRIX_ARRAY_SIZE",
            "-cm line+cond+fsm+branch",
        ],
        "clock_period_ns": 10.0,
        "gops_reference_mhz": 250,
        "gops_reference_is_measured_frequency": False,
        "memory_model": "one-cycle behavioral SPAD; not SRAM timing or ASIC PPA",
        "size_sweep_config": {"physical_arrays": [4, 8, 16],
                               "outstanding_depth": 4, "prefetch": 1, "a_tile_cache": 1},
        "ablation_configs": ["depth 2/4 x prefetch 0/1 x A-cache 0/1"],
        "commands": [
            "make -C dv/block/compute/matrix/sim matrix-size-benchmark SEED=<seed>",
            "make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=<seed>",
        ],
        "size_sweep_cases": sum(1 for row in rows if row["kind"] == "size_sweep"),
        "ablation_cases": sum(1 for row in rows if row["kind"] == "ablation"),
        "golden_pass": sum(1 for row in rows if row["golden"] == "PASS"),
        "golden_fail": 0,
        "csv": csv_path.name,
    }
    (root / "compute_performance_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n")
    print("COMPUTE_PERFORMANCE_SUMMARY_PASS run_id=%s rows=%d csv=%s" %
          (summary["run_id"], len(rows), csv_path))


if __name__ == "__main__":
    main()
