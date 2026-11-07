#!/usr/bin/env python3
"""Join the Round 9 top-SFU FSM profile with generated Transformer descriptors."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import defaultdict
from pathlib import Path


PROFILE_RE = re.compile(r"^R9_SFU_COMMAND\s+(.*)$")
RETIRE_RE = re.compile(r"^TRANSFORMER_COMMAND_RETIRE index=(\d+) cycles=(\d+)$")
DESC_RE = re.compile(
    r"axi_write\(SPAD_BASE \+ 32'h[0-9a-fA-F]+, 32'h([0-9a-fA-F]+)\);"
    r" // ([\w]+)\.word0"
)

CSV_FIELDS = [
    "run_id",
    "source_commit",
    "testbench_blob_sha",
    "model_sha256",
    "seed",
    "vcs_version",
    "phase",
    "descriptor_index",
    "descriptor_name",
    "opcode",
    "length",
    "command_interval_cycles",
    "sfu_busy_cycles",
    "pass0_cycles",
    "pass1_cycles",
    "pass2_cycles",
    "math_cycles",
    "other_cycles",
    "spad_request_stall_cycles",
    "spad_response_wait_cycles",
    "spad_read_accepts",
    "spad_write_accepts",
    "divider_busy_cycles",
    "sqrt_busy_cycles",
    "exclusive_cycles_closed",
    "golden",
]


def parse_kv(text: str) -> dict[str, str]:
    return dict(re.findall(r"([a-zA-Z_][a-zA-Z0-9_]*)=([^ ]+)", text))


def load_descriptors(path: Path) -> list[dict[str, object]]:
    descriptors = []
    all_matches = DESC_RE.findall(path.read_text())
    for descriptor_index, (value, name) in enumerate(all_matches):
        descriptor_word0 = int(value, 16)
        opcode = descriptor_word0 & 0xFF
        if opcode in {0x32, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39}:
            descriptors.append(
                {
                    "descriptor_index": descriptor_index,
                    "name": name,
                    "opcode": f"0x{opcode:02x}",
                }
            )
    return descriptors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--fixture", required=True, type=Path)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--testbench-blob-sha", required=True)
    parser.add_argument("--model-sha256", required=True)
    parser.add_argument("--seed", required=True, type=int)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--vcs-version", required=True)
    parser.add_argument("--csv", required=True, type=Path)
    parser.add_argument("--json", required=True, type=Path)
    args = parser.parse_args()

    log_text = args.log.read_text(errors="replace")
    if "TRANSFORMER_TOP_ONLY_PASS" not in log_text:
        raise SystemExit("log lacks TRANSFORMER_TOP_ONLY_PASS")

    descriptors = load_descriptors(args.fixture)
    profiles = []
    for line in log_text.splitlines():
        match = PROFILE_RE.match(line)
        if match:
            profiles.append(parse_kv(match.group(1)))
    if len(descriptors) != len(profiles):
        raise SystemExit(
            f"descriptor/profile count mismatch: {len(descriptors)} != {len(profiles)}"
        )

    retires = {
        int(match.group(1)): int(match.group(2))
        for line in log_text.splitlines()
        if (match := RETIRE_RE.match(line))
    }
    if len(retires) != 86:
        raise SystemExit(f"expected 86 descriptor retire intervals, found {len(retires)}")

    sfus = []
    for descriptor, profile in zip(descriptors, profiles, strict=True):
        descriptor_index = int(descriptor["descriptor_index"])
        opcode = int(profile["opcode"], 16)
        if opcode != int(str(descriptor["opcode"]), 16):
            raise SystemExit(
                f"opcode mismatch at SFU profile {descriptor_index}: "
                f"{profile['opcode']} != {descriptor['opcode']}"
            )
        closed = sum(
            int(profile[key])
            for key in ("pass0", "pass1", "pass2", "math", "other")
        )
        if closed != int(profile["cycles_closed"]) or closed != int(profile["cycles"]):
            raise SystemExit(f"exclusive SFU cycle categories fail closure at {descriptor_index}")
        sfus.append(
            {
                "run_id": args.run_id,
                "source_commit": args.source_commit,
                "testbench_blob_sha": args.testbench_blob_sha,
                "model_sha256": args.model_sha256,
                "seed": args.seed,
                "vcs_version": args.vcs_version,
                "phase": "prefill" if descriptor_index < 46 else "decode",
                "descriptor_index": descriptor_index,
                "descriptor_name": descriptor["name"],
                "opcode": descriptor["opcode"],
                "length": int(profile["length"]),
                "command_interval_cycles": retires[descriptor_index],
                "sfu_busy_cycles": int(profile["cycles"]),
                "pass0_cycles": int(profile["pass0"]),
                "pass1_cycles": int(profile["pass1"]),
                "pass2_cycles": int(profile["pass2"]),
                "math_cycles": int(profile["math"]),
                "other_cycles": int(profile["other"]),
                "spad_request_stall_cycles": int(profile["spad_request_stall"]),
                "spad_response_wait_cycles": int(profile["spad_response_wait"]),
                "spad_read_accepts": int(profile["spad_read_accepts"]),
                "spad_write_accepts": int(profile["spad_write_accepts"]),
                "divider_busy_cycles": int(profile["divider_busy"]),
                "sqrt_busy_cycles": int(profile["sqrt_busy"]),
                "exclusive_cycles_closed": closed,
                "golden": "PASS",
            }
        )

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(sfus)

    grouped: dict[tuple[str, str], dict[str, int]] = defaultdict(
        lambda: defaultdict(int)
    )
    for row in sfus:
        totals = grouped[(str(row["phase"]), str(row["opcode"]))]
        for key in (
            "command_interval_cycles",
            "sfu_busy_cycles",
            "pass0_cycles",
            "pass1_cycles",
            "pass2_cycles",
            "math_cycles",
            "other_cycles",
            "spad_request_stall_cycles",
            "spad_response_wait_cycles",
            "spad_read_accepts",
            "spad_write_accepts",
            "divider_busy_cycles",
            "sqrt_busy_cycles",
        ):
            totals[key] += int(row[key])

    summary = {
        "status": "PASS",
        "run_id": args.run_id,
        "source_commit": args.source_commit,
        "testbench_blob_sha": args.testbench_blob_sha,
        "model_sha256": args.model_sha256,
        "seed": args.seed,
        "vcs_version": args.vcs_version,
        "profile_csv": str(args.csv),
        "commands": sfus,
        "phase_opcode_totals": [
            {"phase": phase, "opcode": opcode, **totals}
            for (phase, opcode), totals in sorted(grouped.items())
        ],
        "timing_endpoint": "per descriptor completion retirement; doorbell-to-CPLQ-tail top profile in VCS log",
        "notes": [
            "pass0/pass1/pass2/math/other are mutually exclusive FSM cycle buckets.",
            "SPAD wait, divider busy, and sqrt busy are overlapping observations and are not additive.",
            "Golden PASS is inherited from the complete trained H=4 Top run containing this SFU profile.",
        ],
    }
    args.json.write_text(json.dumps(summary, indent=2) + "\n")
    print(
        f"ROUND9_SFU_PROFILE_PASS commands={len(sfus)} "
        f"csv={args.csv} json={args.json}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
