#!/usr/bin/env python3
"""Summarize same-seed Matrix pipeline benchmark configurations."""

import argparse
import csv
import re
from pathlib import Path
from typing import Dict, Tuple


CASE_RE = re.compile(
    r"MATRIX_CORE_CASE_PASS id=(?P<case>\d+).*?"
    r"shape_mnk=(?P<m>\d+),(?P<n>\d+),(?P<k>\d+).*?"
    r"cycles=(?P<cycles>\d+).*?bank_reads=(?P<reads>\d+).*?"
    r"bank_stalls=(?P<stalls>\d+).*?macs_per_cycle=(?P<macs>[0-9.]+).*?"
    r"array_utilization_pct=(?P<util>[0-9.]+).*?"
    r"physical_array=(?P<array>\d+)x\d+"
)
PASS_RE = re.compile(
    r"MATRIX_SIZE_BENCHMARK_PASS seed=(?P<seed>\d+).*?"
    r"physical_array=(?P<array>\d+)x\d+ "
    r"outstanding_depth=(?P<depth>\d+) "
    r"next_k_prefetch=(?P<prefetch>\d+) a_tile_cache=(?P<cache>\d+)"
)
CASE_NAMES = {
    100: "4x4x32",
    101: "8x8x32",
    102: "16x16x32",
    103: "16x32x32",
    104: "32x32x64",
}
CONFIGS = [
    (depth, prefetch, cache)
    for depth in (2, 4)
    for prefetch in (0, 1)
    for cache in (0, 1)
]


def read_run(root: Path, seed: int, depth: int, prefetch: int, cache: int) -> Dict[int, Dict[str, str]]:
    log = root / f"depth_{depth}" / f"prefetch_{prefetch}" / f"cache_{cache}" / "run.log"
    if not log.is_file():
        raise SystemExit(f"missing benchmark log: {log}")
    content = log.read_text(errors="replace")
    pass_match = PASS_RE.search(content)
    if not pass_match:
        raise SystemExit(f"missing benchmark PASS marker: {log}")
    expected = (seed, 16, depth, prefetch, cache)
    observed = tuple(
        int(pass_match.group(key))
        for key in ("seed", "array", "depth", "prefetch", "cache")
    )
    if observed != expected:
        raise SystemExit(f"configuration mismatch in {log}: expected {expected}, got {observed}")

    cases: Dict[int, Dict[str, str]] = {}
    for line in content.splitlines():
        match = CASE_RE.search(line)
        if not match or int(match.group("array")) != 16:
            continue
        case_id = int(match.group("case"))
        if case_id in CASE_NAMES:
            cases[case_id] = match.groupdict()
    if set(cases) != set(CASE_NAMES):
        raise SystemExit(f"expected benchmark cases 100-104 in {log}, found {sorted(cases)}")
    return cases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--seed", type=int, required=True)
    args = parser.parse_args()

    results: Dict[Tuple[int, int, int], Dict[int, Dict[str, str]]] = {
        config: read_run(args.root, args.seed, *config)
        for config in CONFIGS
    }
    csv_path = args.root / "matrix_config_comparison.csv"
    args.root.mkdir(parents=True, exist_ok=True)
    columns = ["seed", "case", "workload"]
    for depth, prefetch, cache in CONFIGS:
        prefix = f"d{depth}_p{prefetch}_c{cache}"
        columns.extend([f"{prefix}_cycles", f"{prefix}_bank_reads", f"{prefix}_bank_stalls", f"{prefix}_macs_per_cycle", f"{prefix}_array_utilization_pct"])
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for case_id, workload in CASE_NAMES.items():
            row: Dict[str, object] = {"seed": args.seed, "case": case_id, "workload": workload}
            for config in CONFIGS:
                prefix = f"d{config[0]}_p{config[1]}_c{config[2]}"
                data = results[config][case_id]
                row[f"{prefix}_cycles"] = data["cycles"]
                row[f"{prefix}_bank_reads"] = data["reads"]
                row[f"{prefix}_bank_stalls"] = data["stalls"]
                row[f"{prefix}_macs_per_cycle"] = data["macs"]
                row[f"{prefix}_array_utilization_pct"] = data["util"]
            writer.writerow(row)

    print(f"Matrix configuration comparison: seed={args.seed}, physical_array=16x16")
    print("Workload | " + " | ".join(f"d{d}/p{p}/c{c}" for d, p, c in CONFIGS))
    print("--- | " + " | ".join("---:" for _ in CONFIGS))
    for case_id, workload in CASE_NAMES.items():
        baseline = int(results[(2, 0, 0)][case_id]["cycles"])
        values = []
        for config in CONFIGS:
            data = results[config][case_id]
            cycles = int(data["cycles"])
            delta = (cycles - baseline) * 100.0 / baseline
            values.append(f"{cycles} cyc / {data['reads']} reads ({delta:+.1f}%)")
        print(f"{workload} | " + " | ".join(values))
    print(f"CSV: {csv_path}")


if __name__ == "__main__":
    main()
