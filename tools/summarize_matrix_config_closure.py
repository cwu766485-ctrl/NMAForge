#!/usr/bin/env python3
"""Aggregate same-workload Matrix configuration runs across fixed seeds."""

from __future__ import annotations

import argparse
import csv
import json
import re
import statistics
import xml.sax.saxutils as saxutils
from pathlib import Path


CONFIGS = [
    (depth, prefetch, cache)
    for depth in (2, 4)
    for prefetch in (0, 1)
    for cache in (0, 1)
]
WORKLOADS = {
    100: "4x4x32",
    101: "8x8x32",
    102: "16x16x32",
    103: "16x32x32",
    104: "32x32x64",
}
CASE_RE = re.compile(r"^MATRIX_CORE_CASE_PASS id=(\d+) (.*)$")
PROFILE_RE = re.compile(r"^MATRIX_CORE_PROFILE id=(\d+) (.*)$")
KV_RE = re.compile(r"([A-Za-z_]+)=([0-9]+(?:\.[0-9]+)?)")
PASS_RE = re.compile(
    r"^MATRIX_SIZE_BENCHMARK_PASS seed=(\d+) .*?physical_array=(\d+)x\d+ "
    r"outstanding_depth=(\d+) next_k_prefetch=(\d+) a_tile_cache=(\d+) "
    r"bank_response_latency=(\d+)"
)


def fields(payload: str) -> dict[str, float]:
    return {key: float(value) for key, value in KV_RE.findall(payload)}


def parse_run(root: Path, seed: int, depth: int, prefetch: int, cache: int) -> list[dict[str, object]]:
    path = root / f"depth_{depth}" / f"prefetch_{prefetch}" / f"cache_{cache}" / "run.log"
    text = path.read_text(errors="replace")
    marker = next((PASS_RE.match(line) for line in text.splitlines() if PASS_RE.match(line)), None)
    expected = (seed, 16, depth, prefetch, cache, 1)
    actual = tuple(map(int, marker.groups())) if marker else None
    if actual != expected:
        raise SystemExit(f"{path}: expected PASS marker {expected}, got {actual}")

    cases: dict[int, dict[str, float]] = {}
    profiles: dict[int, dict[str, float]] = {}
    for line in text.splitlines():
        match = CASE_RE.match(line)
        if match:
            cases[int(match.group(1))] = fields(match.group(2))
            continue
        match = PROFILE_RE.match(line)
        if match:
            profiles[int(match.group(1))] = fields(match.group(2))
    if set(cases) != set(WORKLOADS) or set(profiles) != set(WORKLOADS):
        raise SystemExit(
            f"{path}: expected 5 case/profile records; cases={sorted(cases)}, "
            f"profiles={sorted(profiles)}"
        )

    rows: list[dict[str, object]] = []
    for case_id, workload in WORKLOADS.items():
        case = cases[case_id]
        profile = profiles[case_id]
        if int(case["cycles"]) != int(profile["total"]):
            raise SystemExit(f"{path}: case/profile cycle mismatch for {workload}")
        read_bytes = int(case["bank_read_bytes"])
        write_bytes = int(case["line_write_bytes"])
        rows.append(
            {
                "seed": seed,
                "workload": workload,
                "array": "16x16",
                "outstanding_depth": depth,
                "prefetch": prefetch,
                "a_tile_cache": cache,
                "cycles": int(case["cycles"]),
                "mac_cycles": int(profile["mac"]),
                "macs_per_cycle": case["macs_per_cycle"],
                "array_utilization_pct": case["array_utilization_pct"],
                "spad_read_bytes": read_bytes,
                "spad_write_bytes": write_bytes,
                "spad_total_bytes": read_bytes + write_bytes,
                "bank_stall_cycles": int(case["bank_stalls"]),
                "response_wait_cycles": int(profile["response_wait"]),
                "arbiter_stall_cycles": int(profile["arbiter_stall"]),
                "writeback_wait_cycles": int(profile["writeback_wait"]),
                "prefetch_wait_cycles": int(profile["prefetch_wait"]),
                "fifo_full_cycles": int(profile["fifo_full"]),
                "outstanding_highwater": int(profile["outstanding_highwater"]),
                "a_tile_cache_hits": int(profile["a_tile_cache_hits"]),
                "line_write_stall_cycles": int(case["line_stalls"]),
            }
        )
    return rows


def write_svg(summary: dict[str, object], output: Path) -> None:
    configs = summary["configs"]
    workload_summaries = summary["workloads"]
    width, height = 1120, 640
    left, top, group_h, bar_h, gap = 190, 68, 104, 9, 4
    plot_w = 800
    max_speedup = max(
        1.0,
        max(
            float(value)
            for item in workload_summaries
            for value in item["config_cycle_reduction_pct"].values()
        ),
    )
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#fff"/>',
        '<text x="28" y="34" font-family="Arial,sans-serif" font-size="21" font-weight="700">Matrix 16x16 configuration ablation — mean cycle reduction vs D2/P0/C0</text>',
        '<text x="28" y="54" font-family="Arial,sans-serif" font-size="12" fill="#555">Three fixed seeds; one-cycle behavioral SPAD response; values are RTL simulation cycles, not ASIC timing.</text>',
    ]
    colors = ["#a8b3bf", "#2c7fb8", "#41ab5d", "#238b45", "#8c96a3", "#8073ac", "#e08214", "#1b9e77"]
    for wi, workload in enumerate(workload_summaries):
        y0 = top + wi * group_h
        lines.append(
            f'<text x="28" y="{y0 + 18}" font-family="Arial,sans-serif" font-size="15" font-weight="700">{saxutils.escape(str(workload["workload"]))}</text>'
        )
        reductions = workload["config_cycle_reduction_pct"]
        for ci, config in enumerate(configs):
            reduction = float(reductions[config["id"]])
            y = y0 + ci * (bar_h + gap)
            bar_width = max(1.0, plot_w * max(0.0, reduction) / max_speedup)
            color = colors[ci]
            label = config["id"].replace("_", "/")
            lines.append(f'<text x="80" y="{y + 8}" font-family="Arial,sans-serif" font-size="10" fill="#333">{label}</text>')
            lines.append(f'<rect x="190" y="{y}" width="{bar_width:.1f}" height="{bar_h}" fill="{color}" rx="2"/>')
            lines.append(f'<text x="{198 + bar_width:.1f}" y="{y + 8}" font-family="Arial,sans-serif" font-size="10" fill="#333">{reduction:+.1f}%</text>')
    lines.extend(
        [
            '<text x="190" y="620" font-family="Arial,sans-serif" font-size="11" fill="#555">Cycle reduction is positive when the configuration is faster. Baseline bar is 0%.</text>',
            "</svg>",
        ]
    )
    output.write_text("\n".join(lines) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed-root", action="append", required=True, help="SEED=PATH, repeat for each seed")
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--tree-sha", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()

    seed_roots: list[tuple[int, Path]] = []
    for value in args.seed_root:
        seed, path = value.split("=", 1)
        seed_roots.append((int(seed), Path(path)))
    if len(seed_roots) < 3 or len({seed for seed, _ in seed_roots}) != len(seed_roots):
        raise SystemExit("provide at least three distinct fixed Seeds")

    rows: list[dict[str, object]] = []
    for seed, root in seed_roots:
        for depth, prefetch, cache in CONFIGS:
            rows.extend(parse_run(root, seed, depth, prefetch, cache))

    grouped: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        grouped.setdefault(str(row["workload"]), []).append(row)

    config_ids = [f"d{d}_p{p}_c{c}" for d, p, c in CONFIGS]
    workload_output: list[dict[str, object]] = []
    for workload, workload_rows in grouped.items():
        by_config: dict[str, list[dict[str, object]]] = {key: [] for key in config_ids}
        for row in workload_rows:
            key = f"d{row['outstanding_depth']}_p{row['prefetch']}_c{row['a_tile_cache']}"
            by_config[key].append(row)
        mean_cycles = {
            key: statistics.fmean(float(row["cycles"]) for row in values)
            for key, values in by_config.items()
        }
        baseline = mean_cycles["d2_p0_c0"]
        reduction = {key: (baseline - value) * 100.0 / baseline for key, value in mean_cycles.items()}
        workload_output.append(
            {
                "workload": workload,
                "mean_cycles": mean_cycles,
                "config_cycle_reduction_pct": reduction,
                "config_mean_spad_read_bytes": {
                    key: statistics.fmean(float(row["spad_read_bytes"]) for row in values)
                    for key, values in by_config.items()
                },
                "config_mean_spad_write_bytes": {
                    key: statistics.fmean(float(row["spad_write_bytes"]) for row in values)
                    for key, values in by_config.items()
                },
                "config_mean_mac_per_cycle": {
                    key: statistics.fmean(float(row["macs_per_cycle"]) for row in values)
                    for key, values in by_config.items()
                },
                "config_mean_array_utilization_pct": {
                    key: statistics.fmean(float(row["array_utilization_pct"]) for row in values)
                    for key, values in by_config.items()
                },
            }
        )

    summary: dict[str, object] = {
        "run_id": args.run_id,
        "source_sha": args.source_sha,
        "tree_sha": args.tree_sha,
        "seeds": [seed for seed, _ in seed_roots],
        "simulator": "Synopsys VCS V-2023.12-SP1_Full64",
        "array": "16x16, 256 INT8 MACs",
        "bank_response_latency_cycles": 1,
        "workload_count": len(WORKLOADS),
        "configuration_count": len(CONFIGS),
        "golden_points": len(rows),
        "all_runs_have_pass_markers": True,
        "configs": [
            {
                "id": f"d{depth}_p{prefetch}_c{cache}",
                "outstanding_depth": depth,
                "next_k_prefetch": bool(prefetch),
                "a_tile_cache": bool(cache),
            }
            for depth, prefetch, cache in CONFIGS
        ],
        "rows": rows,
        "workloads": workload_output,
        "counter_note": "Cycle total is the command wall-cycle count. Bank/response/arbiter/prefetch/writeback events may overlap and must not be summed. SPAD traffic is derived from measured bank read bytes and line write bytes in the testbench log.",
        "timing_limit": "250 MHz is only the benchmark's effective-GOPS reference conversion; no ASIC timing or PPA is measured.",
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.output_dir / f"{args.tag}.csv"
    json_path = args.output_dir / f"{args.tag}.json"
    svg_path = args.output_dir / f"{args.tag}.svg"
    columns = list(rows[0].keys())
    with csv_path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)
    json_path.write_text(json.dumps(summary, indent=2) + "\n")
    write_svg(summary, svg_path)
    print(f"Validated {len(rows)} Golden points across {len(seed_roots)} seeds and {len(CONFIGS)} configurations")
    print(f"CSV: {csv_path}")
    print(f"JSON: {json_path}")
    print(f"SVG: {svg_path}")


if __name__ == "__main__":
    main()
