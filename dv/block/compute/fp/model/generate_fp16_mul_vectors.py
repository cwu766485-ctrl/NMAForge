#!/usr/bin/env python3
"""Generate FP16 x FP16 -> FP32 exact-product vectors."""

from __future__ import annotations

import argparse
import random
from pathlib import Path
from typing import Iterable, Tuple

import fp_reference as fp


Pair = Tuple[int, int]


def directed_pairs() -> Iterable[Pair]:
    return (
        (0x3C00, 0x4200),  # 1 * 3
        (0x4000, 0x4400),  # 2 * 4
        (0xBC00, 0x4000),  # -1 * 2
        (0x8000, 0x3C00),  # -0 * +1
        (0x0001, 0x3C00),  # minimum subnormal * 1
        (0x03FF, 0x3C00),  # maximum subnormal * 1
        (0x0400, 0x0400),  # minimum normal squared
        (0x7BFF, 0x7BFF),  # maximum finite squared (still FP32 finite)
        (0x7C00, 0x3C00),  # +Inf * finite
        (0xFC00, 0xBC00),  # -Inf * -1
        (0x7C00, 0x0000),  # invalid 0 * Inf
        (0x0000, 0xFC00),
        (0x7E01, 0x3C00),  # qNaN
        (0x7C01, 0xBC00),  # sNaN
        (0xFE01, 0x3C00),  # signed NaN
    )


def expected_result(a_bits: int, b_bits: int) -> int:
    a32 = fp.fp16_to_fp32_bits(a_bits)
    b32 = fp.fp16_to_fp32_bits(b_bits)
    return fp.fp32_mul_bits(a32, b32)


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
            vector_file.write(
                f"{a_bits:04x} {b_bits:04x} {expected_result(a_bits, b_bits):08x}\n"
            )
        for _ in range(args.random_cases):
            a_bits = rng.getrandbits(16)
            b_bits = rng.getrandbits(16)
            vector_file.write(
                f"{a_bits:04x} {b_bits:04x} {expected_result(a_bits, b_bits):08x}\n"
            )

    print(
        f"FP16_MUL_VECTOR_GEN seed={args.seed} directed={len(directed)} "
        f"random={args.random_cases} total={len(directed) + args.random_cases} "
        f"output={args.output}"
    )


if __name__ == "__main__":
    main()
