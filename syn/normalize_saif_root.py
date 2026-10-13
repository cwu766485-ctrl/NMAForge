#!/usr/bin/env python3
"""Retarget a backward SAIF captured below a testbench DUT to a DC top.

Only the two outer instance wrappers are changed.  Activity counters and all
paths below the DUT remain byte-for-byte intact, so the output is suitable for
``read_saif -instance <dc-top>`` without relying on tool-specific hierarchy
stripping.
"""

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--testbench", required=True)
    parser.add_argument("--dut", required=True)
    parser.add_argument("--top", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    text = args.input.read_text(encoding="utf-8")
    tb_open = f"(INSTANCE {args.testbench}\n"
    dut_open = f"  (INSTANCE {args.dut}\n"
    expected_prefix = tb_open + dut_open
    if expected_prefix not in text:
        raise SystemExit(
            "SAIF outer hierarchy does not match the requested "
            f"testbench/DUT pair: {args.testbench}/{args.dut}"
        )

    # Locate the matching close parenthesis for the testbench instance rather
    # than relying on a particular final NET/PORT section ordering.
    wrapper_start = text.index(tb_open)
    depth = 0
    wrapper_end = None
    for index in range(wrapper_start, len(text)):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                wrapper_end = index
                break
    if wrapper_end is None:
        raise SystemExit("Unbalanced testbench instance in SAIF")

    if text[wrapper_end : wrapper_end + 2] != ")\n":
        raise SystemExit("Unexpected testbench close formatting in SAIF")
    text = text[:wrapper_end] + text[wrapper_end + 2 :]
    text = text.replace(
        expected_prefix,
        f"(INSTANCE {args.top}\n",
        1,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
