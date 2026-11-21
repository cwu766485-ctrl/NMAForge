#!/usr/bin/env python3
"""Check the fixed compact-SPAD regions that are simultaneously live in line-stall DV."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh"
SPAD_BYTES = 128 * 1024

REGIONS = {
    "MATRIX_LINE_STALL_CNM_A_LOCAL": 0x200,
    "MATRIX_LINE_STALL_CNM_B_LOCAL": 0x2000,
    "MATRIX_Y_LOCAL": 0x800,
    "MATRIX_LINE_STALL_CNM_Y_LOCAL": 0x40,
}


def localparams(text):
    pattern = re.compile(
        r"localparam\s+bit\s*\[31:0\]\s+(\w+)\s*=\s*32'h([0-9a-fA-F_]+)"
    )
    return {name: int(value.replace("_", ""), 16) for name, value in pattern.findall(text)}


def main():
    params = localparams(SOURCE.read_text())
    ranges = []
    for name, size in REGIONS.items():
        if name not in params:
            raise SystemExit(f"FAIL: missing allocation constant {name}")
        start = params[name]
        end = start + size
        if start < 0 or end > SPAD_BYTES:
            raise SystemExit(
                f"FAIL: {name} [{start:#07x},{end:#07x}) outside [0,{SPAD_BYTES:#07x})"
            )
        ranges.append((start, end, name))

    for index, (start, end, name) in enumerate(ranges):
        for other_start, other_end, other_name in ranges[index + 1 :]:
            if start < other_end and other_start < end:
                raise SystemExit(
                    f"FAIL: live regions overlap: {name} [{start:#07x},{end:#07x}) "
                    f"and {other_name} [{other_start:#07x},{other_end:#07x})"
                )

    b_base = params["MATRIX_LINE_STALL_CNM_B_LOCAL"]
    row8_lanes = [b_base + 0x80 + lane * 4 for lane in range(4)]
    b_end = b_base + REGIONS["MATRIX_LINE_STALL_CNM_B_LOCAL"]
    if not all(b_base <= addr and addr + 4 <= b_end for addr in row8_lanes):
        raise SystemExit("FAIL: CNM row-8 B operand lane falls outside the B allocation")
    y_start = params["MATRIX_LINE_STALL_CNM_Y_LOCAL"]
    y_end = y_start + REGIONS["MATRIX_LINE_STALL_CNM_Y_LOCAL"]
    if any(y_start <= addr < y_end for addr in row8_lanes):
        raise SystemExit("FAIL: line-stall CNM output aliases a row-8 B operand lane")

    for start, end, name in ranges:
        print(f"PASS: {name} [{start:#07x},{end:#07x})")
    print("PASS: CNM row-8 operand lanes " + ", ".join(f"{addr:#07x}" for addr in row8_lanes))
    print("COMPACT_SPAD_ALLOC_PASS: bounds, live-region overlap, row-8 operand/output separation")


if __name__ == "__main__":
    try:
        main()
    except (OSError, UnicodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
