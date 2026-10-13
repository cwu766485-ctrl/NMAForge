#!/usr/bin/env python3
"""Generate deterministic sequential FP32 accumulator transactions."""

from __future__ import annotations

import argparse
import random
from pathlib import Path

import fp_reference as fp


def directed_sequences() -> tuple[tuple[int, ...], ...]:
    # Includes canonicalized NaN/Inf, signed zeros, normals, subnormals,
    # cancellation, and values that expose per-step rather than final rounding.
    return (
        # Repeated half-ULP input distinguishes stepwise rounding from one
        # final rounding: 1 + half ULP stays even, the next tie rounds up.
        (0x3F800000, 0x33800000, 0x33800000),
        (0x00000000, 0x80000000, 0x80000000),
        (0x3F800000, 0xBF800000),
        (0x7F800000, 0x3F800000),
        (0xFF800000, 0x7F800000),
        (0x7FC00001, 0x3F800000),
        (0x00000001, 0x00000001, 0x007FFFFF, 0x00800000),
        (0x807FFFFF, 0x7F7FFFFF, 0x73000000, 0xFF7FFFFF),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=20261013)
    parser.add_argument("--random-cases", type=int, default=10000)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.random_cases < 0:
        parser.error("--random-cases must be nonnegative")

    rng = random.Random(args.seed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    accumulator = 0
    count = 0
    directed_count = sum(len(sequence) for sequence in directed_sequences())
    with args.output.open("w", encoding="ascii", newline="\n") as vectors:
        # mode: 0=hold, 1=clear, 2=accumulate. Clear is checked with both
        # enables asserted in the testbench, independently of vector contents.
        vectors.write(f"1 00000000 {accumulator:08x}\n")
        count += 1
        vectors.write(f"0 7f800000 {accumulator:08x}\n")
        count += 1
        for sequence in directed_sequences():
            accumulator = 0
            vectors.write(f"1 00000000 {accumulator:08x}\n")
            count += 1
            for product in sequence:
                accumulator = fp.fp32_add_bits(accumulator, product)
                vectors.write(f"2 {product:08x} {accumulator:08x}\n")
                count += 1
        # Break the random stream into bounded chains so one large term cannot
        # turn every later sample into an uninformative sticky infinity.
        # Every product still passes through the raw-bit oracle one step at a time.
        for index in range(args.random_cases):
            if index % 64 == 0:
                accumulator = 0
                vectors.write(f"1 00000000 {accumulator:08x}\n")
                count += 1
            product = rng.getrandbits(32)
            if ((product >> 23) & 0xFF) == 0xFF:
                product &= 0xFF7FFFFF
            accumulator = fp.fp32_add_bits(accumulator, product)
            vectors.write(f"2 {product:08x} {accumulator:08x}\n")
            count += 1
    print(f"FP32_ACCUM_VECTOR_GEN seed={args.seed} directed={directed_count} random={args.random_cases} total={count} output={args.output}")


if __name__ == "__main__":
    main()
