#!/usr/bin/env python3
"""Extract the bounded Top Matrix/DMA overlap probe into CSV and JSON."""

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


MARKERS = {
    "serialized": re.compile(r"^R20_DMA_SERIALIZED (.+)$", re.MULTILINE),
    "ping_pong": re.compile(r"^R9_MATRIX_DMA_OVERLAP_PASS (.+)$", re.MULTILINE),
}


def parse_fields(match, mode):
    values = dict(token.split("=", 1) for token in match.group(1).split())
    values["mode"] = mode
    for key, value in list(values.items()):
        if key in {"mode", "shape", "golden", "ddr_and_spad_golden"}:
            continue
        try:
            values[key] = int(value)
        except ValueError:
            pass
    return values


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--testbench", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--seed", type=int, required=True)
    parser.add_argument("--period-ns", type=float, default=10.0)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    text = args.log.read_text(encoding="utf-8", errors="replace")
    rows = []
    for mode, pattern in MARKERS.items():
        match = pattern.search(text)
        if not match:
            raise SystemExit(f"missing {mode} marker in {args.log}")
        rows.append(parse_fields(match, mode))
    for row in rows:
        if row.get("golden") != "bit-exact" and row.get("ddr_and_spad_golden") != "bit-exact":
            raise SystemExit(f"{row['mode']} Golden did not pass")
        if row["ar_bytes"] != 48 or row["aw_bytes"] != 192:
            raise SystemExit(f"{row['mode']} traffic differs from fixed probe")
        row["read_bytes_per_span_cycle"] = round(row["ar_bytes"] / row["read_span_cycles"], 6)
        row["write_bytes_per_span_cycle"] = round(row["aw_bytes"] / row["write_span_cycles"], 6)
        row["read_burst_bytes_per_cycle"] = round(
            row["ar_bytes"] / (row["ar_bursts"] * row["read_latency_avg"]), 6)
        row["write_burst_bytes_per_cycle"] = round(
            row["aw_bytes"] / (row["aw_bursts"] * row["write_latency_avg"]), 6)
    if rows[0]["total"] != 561 or rows[1]["total"] != 488:
        raise SystemExit("probe cycle baseline changed; inspect rather than updating silently")

    payload = {
        "run_id": args.run_id,
        "status": "PASS_GOLDEN_BOTH_MODES",
        "source_sha": args.source_sha,
        "testbench_sha256": sha256(args.testbench),
        "log_sha256": sha256(args.log),
        "seed": args.seed,
        "sim_clock_period_ns": args.period_ns,
        "timing_scope": "bounded 3-tile Matrix plus actual Top AXI DMA probe; behavioral external-memory model",
        "not_full_model_dma": "trained CNN Top runs still load the SPAD image by AXI-Lite host writes; do not interpret this probe as whole-model DMA timing",
        "rows": rows,
    }
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "dma_overlap.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    columns = list(dict.fromkeys(key for row in rows for key in row))
    with (args.out_dir / "dma_overlap.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)
    print("ROUND20_DMA_OVERLAP_SUMMARY_PASS " + json.dumps({
        "run_id": args.run_id, "serialized_cycles": rows[0]["total"],
        "ping_pong_cycles": rows[1]["total"],
        "read_bursts": rows[1]["ar_bursts"],
        "write_bursts": rows[1]["aw_bursts"],
        "json": str(args.out_dir / "dma_overlap.json"),
        "csv": str(args.out_dir / "dma_overlap.csv")
    }, sort_keys=True))


if __name__ == "__main__":
    main()
