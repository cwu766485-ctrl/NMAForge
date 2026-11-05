#!/usr/bin/env python3
"""Merge per-seed product GEMV ablation CSVs into reproducible report files."""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


NUMERIC = (
    "physical_macs", "useful_macs", "command_cycles",
    "exclusive_state_partition_cycles", "mac_active_cycles",
    "useful_macs_per_command_cycle", "command_window_array_utilization_pct",
    "accepted_spad_reads", "spad_read_bytes", "spad_write_bytes",
    "prefetch_completed", "prefetch_overlap_cycles", "b_cache_fold_hits",
    "b_read_transactions_saved", "a_req_cycles", "a_wait_cycles",
    "b_req_cycles", "b_wait_cycles", "bias_req_cycles", "bias_wait_cycles",
    "prep_mac_cycles", "mac_state_cycles", "write_state_cycles",
    "next_state_cycles", "done_state_cycles", "error_state_cycles",
    "error_drain_state_cycles", "prefetch_wait_state_cycles",
    "arbiter_stall_cycles", "response_wait_cycles", "writeback_wait_cycles",
    "bank_stall_cycles", "line_stall_cycles", "outstanding_highwater",
    "fifo_full_cycles",
)
SHAPES = ((8, 19), (8, 65), (16, 19), (16, 65))


def read_inputs(paths: list[Path]) -> tuple[list[str], list[dict[str, str]]]:
    rows: list[dict[str, str]] = []
    fields: list[str] | None = None
    for path in paths:
        with path.open(newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream)
            if fields is None:
                fields = reader.fieldnames
            elif reader.fieldnames != fields:
                raise ValueError(f"CSV header mismatch: {path}")
            rows.extend(reader)
    if not fields:
        raise ValueError("no input CSV files")
    return list(fields), rows


def mean(rows: list[dict[str, str]], field: str) -> float:
    return sum(float(row[field]) for row in rows) / len(rows)


def make_summary(rows: list[dict[str, str]]) -> dict[str, object]:
    if len(rows) != 48:
        raise ValueError(f"expected 48 points, found {len(rows)}")
    source_shas = {row["rtl_sha"] for row in rows}
    test_shas = {row["test_sha"] for row in rows}
    seeds = sorted({int(row["seed"]) for row in rows})
    if len(source_shas) != 1 or len(test_shas) != 1 or source_shas != test_shas:
        raise ValueError("all points must use one matching RTL/test SHA")
    if len(seeds) != 3 or any(row["golden"] != "bit-exact" for row in rows):
        raise ValueError("expected three seeds and bit-exact Golden on every point")

    expected = {
        (m, n, k, cache, prefetch, seed)
        for m, k in SHAPES for n in (16,)
        for cache in (0, 1) for prefetch in (0, 1) for seed in seeds
    }
    observed = {
        (int(row["shape_m"]), int(row["shape_n"]), int(row["shape_k"]),
         int(row["b_fold_cache_enabled"]), int(row["next_k_prefetch_enabled"]),
         int(row["seed"]))
        for row in rows
    }
    if observed != expected or len(observed) != len(rows):
        raise ValueError("shape/config/seed matrix is incomplete or duplicated")
    for row in rows:
        if int(row["exclusive_state_partition_cycles"]) != int(row["command_cycles"]):
            raise ValueError(f"exclusive state partition does not close: {row['run_id']}")

    grouped: dict[tuple[int, int, int, int], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        key = (int(row["shape_m"]), int(row["shape_n"]), int(row["shape_k"]),
               int(row["b_fold_cache_enabled"]), int(row["next_k_prefetch_enabled"]))
        grouped[key].append(row)

    configs_by_shape = []
    for m, k in SHAPES:
        shape = f"{m}x16x{k}"
        baseline = grouped[(m, 16, k, 0, 0)]
        base_cycles = mean(baseline, "command_cycles")
        base_reads = mean(baseline, "spad_read_bytes")
        configs = []
        for cache, prefetch in ((0, 0), (1, 0), (0, 1), (1, 1)):
            points = grouped[(m, 16, k, cache, prefetch)]
            item: dict[str, object] = {
                "b_fold_cache": bool(cache),
                "next_k_prefetch": bool(prefetch),
                "seeds": seeds,
                "command_cycles": round(mean(points, "command_cycles"), 4),
                "cycles_min": min(int(row["command_cycles"]) for row in points),
                "cycles_max": max(int(row["command_cycles"]) for row in points),
                "exclusive_state_partition_cycles": round(mean(points, "exclusive_state_partition_cycles"), 4),
                "useful_macs_per_command_cycle": round(mean(points, "useful_macs_per_command_cycle"), 4),
                "command_window_array_utilization_pct": round(mean(points, "command_window_array_utilization_pct"), 4),
                "spad_read_bytes": round(mean(points, "spad_read_bytes"), 4),
                "spad_write_bytes": round(mean(points, "spad_write_bytes"), 4),
                "prefetch_overlap_cycles": round(mean(points, "prefetch_overlap_cycles"), 4),
                "b_cache_fold_hits": round(mean(points, "b_cache_fold_hits"), 4),
                "b_read_transactions_saved": round(mean(points, "b_read_transactions_saved"), 4),
                "arbiter_stall_cycles": round(mean(points, "arbiter_stall_cycles"), 4),
                "response_wait_cycles": round(mean(points, "response_wait_cycles"), 4),
                "writeback_wait_cycles": round(mean(points, "writeback_wait_cycles"), 4),
                "bank_stall_cycles": round(mean(points, "bank_stall_cycles"), 4),
                "line_stall_cycles": round(mean(points, "line_stall_cycles"), 4),
                "outstanding_highwater": round(mean(points, "outstanding_highwater"), 4),
                "fifo_full_cycles": round(mean(points, "fifo_full_cycles"), 4),
                "speedup_vs_cache0_prefetch0": round(base_cycles / mean(points, "command_cycles"), 4),
                "read_bytes_reduction_pct_vs_cache0_prefetch0": round(
                    100 * (base_reads - mean(points, "spad_read_bytes")) / base_reads, 4
                ),
            }
            configs.append(item)
        configs_by_shape.append({"shape": shape, "configurations": configs})

    return {
        "run_id": "V2-GEMV-FOUR-WAY-3SEED-410B81D",
        "source_sha": next(iter(source_shas)),
        "rtl_sha": next(iter(source_shas)),
        "test_sha": next(iter(test_shas)),
        "vcs": "V-2023.12-SP1_Full64",
        "python": "3.12",
        "array": "16x16; 256 INT8 MACs",
        "outstanding_read_depth": 4,
        "a_tile_cache_enabled": True,
        "memory_model": "registered four-bank behavioral SPAD with seed-controlled randomized ready/response latency",
        "seeds": seeds,
        "points": len(rows),
        "golden_pass_points": sum(row["golden"] == "bit-exact" for row in rows),
        "cycle_ratio_definition": "speedup_vs_cache0_prefetch0 = baseline command cycles / configuration command cycles; values above 1.0 mean fewer cycles than baseline",
        "counter_semantics": {
            "exclusive_state_partition": "A/B/bias request and wait, prep, MAC, write, next, done, error, error drain and prefetch-wait state counters are mutually exclusive and sum exactly to command_cycles on every point",
            "overlapping_observers": "MAC active, arbiter stall, response wait, writeback wait, bank stall, line stall, prefetch overlap, outstanding high-water and FIFO-full are observer/event counters; do not sum them into the state partition",
        },
        "configurations_by_shape": configs_by_shape,
    }


def make_svg(summary: dict[str, object], path: Path) -> None:
    panels = summary["configurations_by_shape"]
    colors = ("#64748b", "#0f9d8a", "#e28b22", "#5967c4")
    labels = ("B0/P0", "B1/P0", "B0/P1", "B1/P1")
    width, height, panel_w = 1120, 520, 270
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#ffffff"/>',
        '<text x="560" y="30" text-anchor="middle" font-family="sans-serif" font-size="20" font-weight="bold">v2 product GEMV: B-fold Cache × Next-K Prefetch</text>',
        '<text x="560" y="54" text-anchor="middle" font-family="sans-serif" font-size="12" fill="#475569">Mean command cycles across three seeds · 16×16 array · four-bank behavioral SPAD</text>',
    ]
    for p, panel in enumerate(panels):
        x0 = 20 + p * panel_w
        values = panel["configurations"]
        max_cycles = max(item["command_cycles"] for item in values)
        chart_top, chart_bottom = 95, 400
        svg.append(f'<text x="{x0 + 118}" y="82" text-anchor="middle" font-family="sans-serif" font-size="14" font-weight="bold">{panel["shape"]}</text>')
        svg.append(f'<line x1="{x0 + 28}" y1="{chart_bottom}" x2="{x0 + 238}" y2="{chart_bottom}" stroke="#94a3b8"/>')
        for i, item in enumerate(values):
            bar_h = (item["command_cycles"] / max_cycles) * (chart_bottom - chart_top)
            bx = x0 + 42 + i * 48
            by = chart_bottom - bar_h
            svg.append(f'<rect x="{bx}" y="{by:.1f}" width="30" height="{bar_h:.1f}" rx="3" fill="{colors[i]}"/>')
            svg.append(f'<text x="{bx + 15}" y="{by - 7:.1f}" text-anchor="middle" font-family="sans-serif" font-size="10">{item["command_cycles"]:.1f}</text>')
            svg.append(f'<text x="{bx + 15}" y="{chart_bottom + 18}" text-anchor="middle" font-family="sans-serif" font-size="9">{labels[i]}</text>')
        svg.append(f'<text x="{x0 + 133}" y="440" text-anchor="middle" font-family="sans-serif" font-size="11" fill="#475569">Cache / Prefetch</text>')
    for i, label in enumerate(labels):
        x = 275 + i * 145
        svg.append(f'<rect x="{x}" y="475" width="12" height="12" fill="{colors[i]}"/><text x="{x + 18}" y="486" font-family="sans-serif" font-size="11">{label}</text>')
    svg.append('</svg>')
    path.write_text("\n".join(svg) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-prefix", required=True, type=Path)
    parser.add_argument("inputs", nargs="+", type=Path)
    args = parser.parse_args()
    fields, rows = read_inputs(args.inputs)
    summary = make_summary(rows)
    args.output_prefix.parent.mkdir(parents=True, exist_ok=True)
    csv_path = args.output_prefix.with_suffix(".csv")
    json_path = args.output_prefix.with_name(args.output_prefix.name + "_summary.json")
    svg_path = args.output_prefix.with_suffix(".svg")
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    json_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    make_svg(summary, svg_path)
    print(f"GEMV_FOUR_WAY_MERGE_PASS points={len(rows)} golden={summary['golden_pass_points']} source_sha={summary['source_sha']}")
    print(f"csv={csv_path}\njson={json_path}\nsvg={svg_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
