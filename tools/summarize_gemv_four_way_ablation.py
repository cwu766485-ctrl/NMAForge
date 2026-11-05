#!/usr/bin/env python3
"""Summarize a matched GEMV B-fold-cache × next-K-prefetch ablation.

The script consumes existing VCS compile and run logs. It does not simulate,
interpolate missing measurements, or treat absent profile counters as zero. It
also requires the mutually exclusive command-state counters to close exactly.
"""

from __future__ import annotations

import argparse
import csv
import re
from dataclasses import dataclass
from pathlib import Path


PASS_RE = re.compile(
    r"^MATRIX_CORE_GEMV_KFOLD_MROWS_TAIL_PASS opcode=0x52 "
    r"shape=(?P<m>\d+)x16x(?P<k>\d+) cycles=(?P<cycles>\d+) "
    r"mac_cycles=(?P<mac_cycles>\d+) bank_reads=(?P<reads>\d+) "
    r"read_bytes=(?P<read_bytes>\d+) outputs=(?P<outputs>\d+) "
    r"lines=(?P<lines>\d+) prefetch_completed=(?P<prefetch_completed>\d+) "
    r"prefetch_overlap=(?P<prefetch_overlap>\d+) "
    r"b_cache_hits=(?P<b_cache_hits>\d+) "
    r"b_reads_saved=(?P<b_reads_saved>\d+) golden=bit-exact$",
    re.MULTILINE,
)

FIELDS = [
    "run_id",
    "rtl_sha",
    "test_sha",
    "seed",
    "shape_m",
    "shape_n",
    "shape_k",
    "b_fold_cache_enabled",
    "next_k_prefetch_enabled",
    "physical_macs",
    "useful_macs",
    "command_cycles",
    "exclusive_state_partition_cycles",
    "mac_active_cycles",
    "useful_macs_per_command_cycle",
    "command_window_array_utilization_pct",
    "accepted_spad_reads",
    "spad_read_bytes",
    "spad_write_bytes",
    "output_line_writes",
    "prefetch_completed",
    "prefetch_overlap_cycles",
    "b_cache_fold_hits",
    "b_read_transactions_saved",
    "a_req_cycles",
    "a_wait_cycles",
    "b_req_cycles",
    "b_wait_cycles",
    "bias_req_cycles",
    "bias_wait_cycles",
    "prep_mac_cycles",
    "mac_state_cycles",
    "write_state_cycles",
    "next_state_cycles",
    "done_state_cycles",
    "error_state_cycles",
    "error_drain_state_cycles",
    "prefetch_wait_state_cycles",
    "arbiter_stall_cycles",
    "response_wait_cycles",
    "writeback_wait_cycles",
    "bank_stall_cycles",
    "line_stall_cycles",
    "outstanding_highwater",
    "fifo_full_cycles",
    "golden",
    "simulator",
    "memory_model",
    "run_log",
    "compile_log",
]


@dataclass(frozen=True)
class Config:
    cache: int
    prefetch: int
    log: Path


def read_config(config: Config, seed: int, rtl_sha: str, test_sha: str) -> list[dict[str, str]]:
    run_log = config.log.resolve()
    compile_log = run_log.parent / "compile.log"
    if not run_log.is_file() or not compile_log.is_file():
        raise ValueError(f"missing run/compile log: {run_log} / {compile_log}")

    compile_text = compile_log.read_text(encoding="utf-8", errors="replace")
    required_defines = {
        "MATRIX_NEXT_K_PREFETCH_ENABLE": config.prefetch,
        "MATRIX_GEMV_B_TILE_CACHE_ENABLE": config.cache,
        "MATRIX_ARRAY_SIZE": 16,
        "MATRIX_MAX_OUTSTANDING_READS": 4,
    }
    for name, expected in required_defines.items():
        if not re.search(rf"\+define\+{name}={expected}(?:\s|$)", compile_text):
            raise ValueError(
                f"{compile_log}: expected {name}={expected} for requested config"
            )

    run_text = run_log.read_text(encoding="utf-8", errors="replace")
    command = run_text.splitlines()[0] if run_text else ""
    if f"+SEED={seed}" not in command:
        raise ValueError(f"{run_log}: expected seed {seed} in run command")
    matches = list(PASS_RE.finditer(run_text))
    expected_shapes = [(8, 19), (8, 65), (16, 19), (16, 65)]
    found_shapes = [(int(match.group("m")), int(match.group("k"))) for match in matches]
    if found_shapes != expected_shapes:
        raise ValueError(
            f"{run_log}: expected M/K markers {expected_shapes}, found {found_shapes}"
        )
    profiles: dict[tuple[int, int], dict[str, int]] = {}
    for line in run_text.splitlines():
        prefix = "MATRIX_CORE_GEMV_MROWS_PROFILE shape="
        if not line.startswith(prefix):
            continue
        shape, _, payload = line[len(prefix):].partition(" ")
        m_text, _, k_text = shape.partition("x16x")
        values = {
            key: int(value)
            for key, value in re.findall(r"([a-z_]+)=([0-9]+)", payload)
        }
        profiles[(int(m_text), int(k_text))] = values
    if sorted(profiles) != expected_shapes:
        raise ValueError(
            f"{run_log}: expected per-command profile M/K markers {expected_shapes}, "
            f"found {sorted(profiles)}"
        )
    for m_rows, k in expected_shapes:
        if not re.search(
            rf"^MATRIX_GEMV_ABLATION_PASS shape=M{m_rows}x16x{k} seed={seed}$",
            run_text,
            re.MULTILINE,
        ):
            raise ValueError(f"{run_log}: missing successful ablation marker for K={k}")

    rows: list[dict[str, str]] = []
    for match in matches:
        values = {name: int(value) for name, value in match.groupdict().items()}
        k = values["k"]
        m_rows = values["m"]
        k_groups = (k + 3) // 4
        cache_groups = min(k_groups, 16)
        row_reuse_count = (m_rows // 4) - 1
        expected_saved_reads = (
            row_reuse_count * min(k, cache_groups * 4) if config.cache else 0
        )
        expected_cache_hits = row_reuse_count * cache_groups if config.cache else 0
        if (
            values["outputs"] != m_rows * 16
            or values["lines"] != m_rows * 4
            or values["reads"] * 16 != values["read_bytes"]
            or values["b_reads_saved"] != expected_saved_reads
            or values["b_cache_hits"] != expected_cache_hits
            or (config.prefetch == 0 and values["prefetch_completed"] != 0)
            or (config.prefetch == 1 and values["prefetch_completed"] == 0)
            or (config.prefetch == 0 and values["prefetch_overlap"] != 0)
            or (config.prefetch == 1 and values["prefetch_overlap"] == 0)
        ):
            raise ValueError(f"{run_log}: inconsistent metrics for K={k}: {values}")

        useful_macs = m_rows * 16 * k
        profile = profiles[(m_rows, k)]
        exclusive_state_fields = (
            "a_req", "a_wait", "b_req", "b_wait", "bias_req", "bias_wait",
            "prep_mac", "mac", "write", "next", "done", "error",
            "error_drain", "prefetch_wait",
        )
        state_partition_cycles = sum(
            profile[name] for name in exclusive_state_fields
        )
        if state_partition_cycles != values["cycles"]:
            raise ValueError(
                f"{run_log}: exclusive state partition does not close for "
                f"M={m_rows}, K={k}: {state_partition_cycles} != {values['cycles']}"
            )
        if profile["mac"] != values["mac_cycles"]:
            raise ValueError(
                f"{run_log}: MAC active/state counters disagree for "
                f"M={m_rows}, K={k}: {values['mac_cycles']} != {profile['mac']}"
            )
        rows.append(
            {
                "run_id": f"V2-GEMV-FOUR-WAY-S{seed}-K{k}-B{config.cache}-P{config.prefetch}",
                "rtl_sha": rtl_sha,
                "test_sha": test_sha,
                "seed": str(seed),
                "shape_m": str(m_rows),
                "shape_n": "16",
                "shape_k": str(k),
                "b_fold_cache_enabled": str(config.cache),
                "next_k_prefetch_enabled": str(config.prefetch),
                "physical_macs": "256",
                "useful_macs": str(useful_macs),
                "command_cycles": str(values["cycles"]),
                "exclusive_state_partition_cycles": str(state_partition_cycles),
                "mac_active_cycles": str(values["mac_cycles"]),
                "useful_macs_per_command_cycle": f"{useful_macs / values['cycles']:.4f}",
                "command_window_array_utilization_pct": (
                    f"{100.0 * useful_macs / (256 * values['cycles']):.4f}"
                ),
                "accepted_spad_reads": str(values["reads"]),
                "spad_read_bytes": str(values["read_bytes"]),
                "spad_write_bytes": str(values["lines"] * 16),
                "output_line_writes": str(values["lines"]),
                "prefetch_completed": str(values["prefetch_completed"]),
                "prefetch_overlap_cycles": str(values["prefetch_overlap"]),
                "b_cache_fold_hits": str(values["b_cache_hits"]),
                "b_read_transactions_saved": str(values["b_reads_saved"]),
                "a_req_cycles": str(profile["a_req"]),
                "a_wait_cycles": str(profile["a_wait"]),
                "b_req_cycles": str(profile["b_req"]),
                "b_wait_cycles": str(profile["b_wait"]),
                "bias_req_cycles": str(profile["bias_req"]),
                "bias_wait_cycles": str(profile["bias_wait"]),
                "prep_mac_cycles": str(profile["prep_mac"]),
                "mac_state_cycles": str(profile["mac"]),
                "write_state_cycles": str(profile["write"]),
                "next_state_cycles": str(profile["next"]),
                "done_state_cycles": str(profile["done"]),
                "error_state_cycles": str(profile["error"]),
                "error_drain_state_cycles": str(profile["error_drain"]),
                "prefetch_wait_state_cycles": str(profile["prefetch_wait"]),
                "arbiter_stall_cycles": str(profile["arbiter_stall"]),
                "response_wait_cycles": str(profile["response_wait"]),
                "writeback_wait_cycles": str(profile["writeback_wait"]),
                "bank_stall_cycles": str(profile["bank_stalls"]),
                "line_stall_cycles": str(profile["line_stalls"]),
                "outstanding_highwater": str(profile["outstanding_highwater"]),
                "fifo_full_cycles": str(profile["fifo_full"]),
                "golden": "bit-exact",
                "simulator": "Synopsys VCS V-2023.12-SP1_Full64",
                "memory_model": "registered four-bank behavioral SPAD; seed-controlled random ready/latency",
                "run_log": str(run_log),
                "compile_log": str(compile_log.resolve()),
            }
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", required=True, type=int)
    parser.add_argument("--rtl-sha", required=True)
    parser.add_argument("--test-sha", required=True)
    parser.add_argument("--p0-b0", required=True, type=Path, help="prefetch off, cache off run log")
    parser.add_argument("--p0-b1", required=True, type=Path, help="prefetch off, cache on run log")
    parser.add_argument("--p1-b0", required=True, type=Path, help="prefetch on, cache off run log")
    parser.add_argument("--p1-b1", required=True, type=Path, help="prefetch on, cache on run log")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    configs = [
        Config(0, 0, args.p0_b0),
        Config(0, 1, args.p1_b0),
        Config(1, 0, args.p0_b1),
        Config(1, 1, args.p1_b1),
    ]
    rows = [
        row
        for config in configs
        for row in read_config(config, args.seed, args.rtl_sha, args.test_sha)
    ]
    if len(rows) != 16:
        raise SystemExit(f"expected 16 measured rows, found {len(rows)}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"GEMV_FOUR_WAY_ABLATION_SUMMARY_PASS rows={len(rows)} seed={args.seed} output={args.output}")


if __name__ == "__main__":
    main()
