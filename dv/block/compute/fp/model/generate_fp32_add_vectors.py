#!/usr/bin/env python3
"""Generate deterministic FP32 raw-bit addition vectors from fp_reference."""

from __future__ import annotations

import argparse
import random
from pathlib import Path
from typing import Iterable, Tuple

import fp_reference as fp


Pair = Tuple[int, int]


def directed_pairs() -> Iterable[Pair]:
    # Zeros, cancellation, normal/subnormal boundaries, RNE ties, overflow,
    # infinities, and both NaN encodings/signs.
    return (
        (0x00000000, 0x00000000), (0x80000000, 0x80000000),
        (0x00000000, 0x80000000), (0x80000000, 0x00000000),
        (0x3F800000, 0xBF800000), (0x40000000, 0xC0000000),
        (0x3F800000, 0x00000000), (0xBF800000, 0x80000000),
        (0x7F800000, 0x3F800000), (0xFF800000, 0xBF800000),
        (0x7F800000, 0xFF800000), (0xFF800000, 0x7F800000),
        (0x7FC00001, 0x3F800000), (0xFFABCDEF, 0x40000000),
        (0x7F800001, 0x3F800000), (0xFF800001, 0xBF800000),
        (0x00000001, 0x00000001), (0x00000001, 0x80000000),
        (0x00000001, 0x00000000), (0x007FFFFF, 0x00000001),
        (0x00800000, 0x807FFFFF), (0x00800000, 0x80000001),
        (0x007FFFFF, 0x807FFFFF), (0x00800000, 0x80000000),
        (0x3F800000, 0x33800000), # 1 + half ULP -> even 1
        (0x3F800001, 0x33800000), # odd tie rounds upward
        (0x3F800000, 0x34400000), # quarter ULP rounds down
        (0x3F800000, 0x34400001), # just above quarter ULP
        (0x7F7FFFFF, 0x7F7FFFFF), (0x7F7FFFFF, 0x73000000),
        (0xFF7FFFFF, 0xFF7FFFFF), (0xFF7FFFFF, 0xF3000000),
        (0x00800000, 0x00000001), (0x80800000, 0x80000001),
        (0x3F000000, 0x3F000000), (0xBF000000, 0xBF000000),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=20261013)
    parser.add_argument("--random-cases", type=int, default=10000)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.random_cases < 0:
        parser.error("--random-cases must be nonnegative")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    directed = tuple(directed_pairs())
    with args.output.open("w", encoding="ascii", newline="\n") as vector_file:
        for a_bits, b_bits in directed:
            vector_file.write(f"{a_bits:08x} {b_bits:08x} {fp.fp32_add_bits(a_bits, b_bits):08x}\n")
        for _ in range(args.random_cases):
            a_bits = rng.getrandbits(32)
            b_bits = rng.getrandbits(32)
            vector_file.write(f"{a_bits:08x} {b_bits:08x} {fp.fp32_add_bits(a_bits, b_bits):08x}\n")

    print(
        f"FP32_ADD_VECTOR_GEN seed={args.seed} directed={len(directed)} "
        f"random={args.random_cases} total={len(directed) + args.random_cases} "
        f"output={args.output}"
    )


if __name__ == "__main__":
    main()
