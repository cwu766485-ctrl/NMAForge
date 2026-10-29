#!/usr/bin/env python3
"""Collect Shape-Adaptive GEMV measurements through the real SPAD arbiter."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


MARKER = re.compile(r"([A-Za-z_]+)=([^\s]+)")
FIELDS = [
    "run_id", "source_sha", "regression_seed", "workload_seed", "shape_mnk",
    "macs", "baseline_cycles", "adaptive_cycles", "selected_gemv",
    "baseline_over_adaptive", "spad_read_bytes", "spad_write_bytes",
    "baseline_arbiter_wait_cycles", "adaptive_arbiter_wait_cycles",
    "contender_bank_pattern", "golden", "run_log",
]


def parse_fields(line: str) -> dict[str, str]:
    return dict(MARKER.findall(line))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--seeds", nargs="+", required=True, type=int)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--vcs-version", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()

    rows: list[dict[str, str]] = []
    for regression_seed in args.seeds:
        log = args.run_dir / f"seed_{regression_seed}.log"
        if not log.is_file():
            raise SystemExit(f"missing simulation log: {log}")
        text = log.read_text(encoding="utf-8", errors="replace")
        marker = f"SHAPE_ADAPTIVE_SPAD_PASS seed={regression_seed} shapes=4 aborts=3 reset=1"
        if marker not in text or "SHAPE_ADAPTIVE_SPAD_FAIL" in text or "ERROR:" in text:
            raise SystemExit(f"failed/missing closure marker in {log}")
        matches = [line for line in text.splitlines() if line.startswith("SPAD_COMPARE_PASS ")]
        if len(matches) != 4:
            raise SystemExit(f"expected four matched shape rows in {log}, got {len(matches)}")
        for line in matches:
            value = parse_fields(line)
            baseline = int(value["baseline_cycles"])
            adaptive = int(value["adaptive_cycles"])
            if baseline <= 0 or adaptive <= 0:
                raise SystemExit(f"non-positive cycle count in {log}: {line}")
            rows.append({
                "run_id": args.run_id,
                "source_sha": args.source_sha,
                "regression_seed": str(regression_seed),
                "workload_seed": value["seed"],
                "shape_mnk": f"{value['m']}x{value['n']}x{value['k']}",
                "macs": value["macs"],
                "baseline_cycles": str(baseline),
                "adaptive_cycles": str(adaptive),
                "selected_gemv": value["selected_gemv"],
                "baseline_over_adaptive": f"{baseline/adaptive:.4f}",
                "spad_read_bytes": value["reads"],
                "spad_write_bytes": value["writes"],
                "baseline_arbiter_wait_cycles": value["baseline_wait"],
                "adaptive_arbiter_wait_cycles": value["adaptive_wait"],
                "contender_bank_pattern": "same-bank" if value["dma_pattern"] == "0" else "rotating-bank",
                "golden": "PASS: complete 32-bit SPAD output image",
                "run_log": str(log),
            })

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    args.csv.write_bytes(args.csv.read_bytes().replace(b"\r\n", b"\n"))
    summary = {
        "run_id": args.run_id,
        "source_sha": args.source_sha,
        "vcs_version": args.vcs_version,
        "regression_seeds": args.seeds,
        "pass_count": len(rows),
        "workloads_per_seed": 4,
        "dimensions": "M=1/4/8/16, N=8, K=64; signed INT8 × INT8 -> signed INT64 accumulation",
        "memory": {
            "implementation": "ai_spad_arbiter + ai_scratchpad four-bank VCS behavioral RAM",
            "read_latency": "two registered scratchpad stages plus arbiter response tagging",
            "request_width": "32-bit scalar core/DMA requests",
            "input_layout": "dense row-major INT8 bytes in SPAD, unpacked into kernel MAX_K/MAX_N local-buffer strides",
        },
        "stress": {
            "contention": "continuous DMA reads through the production arbiter; same-bank and rotating-bank address patterns",
            "abort": "during input-read, kernel-compute, and result-writeback phases",
            "reset": "asserted with an accepted core read awaiting its response; verifies no stale writeback",
            "checker": "independent INT32 GEMM plus complete SPAD result-image and uncommitted sentinel checks",
        },
        "timing_limit": "research wrapper measures real arbiter/SPAD and kernel RTL; it is not connected to the production Matrix command path and is not an ASIC PPA result",
        "csv": str(args.csv),
    }
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
