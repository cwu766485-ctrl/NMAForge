#!/usr/bin/env python3
"""Generate deterministic BF16 multiplier vectors from fp_reference.py."""

from __future__ import annotations

import argparse
import random
from pathlib import Path
from typing import Iterable, Tuple

import fp_reference as fp


Pair = Tuple[int, int]


def directed_pairs() -> Iterable[Pair]:
    # Exact normal results, sign behavior, BF16 subnormals, FP32 gradual
    # underflow ties, output normal boundary, overflow, and all special classes.
    return (
        (0x3F80, 0x4040),  # 1 * 3
        (0x3F80, 0x3F80),
        (0x4000, 0x4080),  # 2 * 4
        (0xBF80, 0x4000),
        (0x8000, 0x3F80),  # -0 * +1
        (0x8000, 0xBF80),  # -0 * -1
        (0x3F80, 0x0000),
        (0x3F80, 0x8000),
        (0x0001, 0x3F80),  # minimum BF16 subnormal * 1
        (0x8001, 0x3F80),
        (0x007F, 0x3F80),  # maximum BF16 subnormal * 1
        (0x807F, 0x3F80),
        (0x0080, 0x0080),  # underflows FP32
        (0x0001, 0x3700),  # exact half of FP32 minimum subnormal -> even zero
        (0x0003, 0x3700),  # 1.5 subnormal quanta -> even 2
        (0x0005, 0x3700),  # 2.5 subnormal quanta -> even 2
        (0x8001, 0x3700),
        (0x0001, 0x4300),  # exact FP32 minimum normal
        (0x7F7F, 0x7F7F),  # overflow
        (0xFF7F, 0x7F7F),
        (0xFF7F, 0xFF7F),
        (0x7F80, 0x3F80),  # +Inf * finite
        (0xFF80, 0x3F80),  # -Inf * finite
        (0x7F80, 0xFF80),  # opposite-signed infinities multiply to -Inf
        (0x7F80, 0x0000),  # invalid 0 * Inf
        (0x0000, 0xFF80),
        (0x7FC0, 0x3F80),  # qNaN
        (0x7F81, 0xBF80),  # sNaN
        (0xFFC1, 0x3F80),  # signed/payload qNaN
        (0xFF81, 0x3F80),  # signed sNaN
        (0x0000, 0x0000),
        (0x8000, 0x8000),
    )


def expected_result(a_bits: int, b_bits: int) -> int:
    a32 = fp.bf16_to_fp32_bits(a_bits)
    b32 = fp.bf16_to_fp32_bits(b_bits)
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

    total = len(directed) + args.random_cases
    print(
        f"FP_VECTOR_GEN seed={args.seed} directed={len(directed)} "
        f"random={args.random_cases} total={total} output={args.output}"
    )


if __name__ == "__main__":
    main()
