#!/usr/bin/env python3
"""Generate replayable BF16 dot transactions using the independent exact model."""

from __future__ import annotations

import argparse
import random
from pathlib import Path

from fp_reference import bf16_dot


def random_finite_bf16(rng: random.Random) -> int:
    """Return a seeded finite BF16 value, including zeros/subnormals/signs."""
    sign = rng.randrange(2) << 15
    category = rng.randrange(5)
    if category == 0:
        return sign
    if category == 1:
        return sign | rng.randrange(1, 0x80)
    exponent = rng.randrange(1, 0xFF)
    fraction = rng.randrange(0x80)
    return sign | (exponent << 7) | fraction


def directed_cases() -> list[tuple[list[int], list[int]]]:
    """Guarantee key length, sign, and IEEE-class bins are represented."""
    return [
        ([0x0000], [0x3F80]),  # zero
        ([0x8001, 0x3F80], [0x3F80, 0xBF80]),  # subnormal, length 2
        ([0xBF80, 0x4000, 0x3F80], [0x3F80, 0x4000, 0xBF80]),  # length 3
        ([0x7F80, 0x3F80, 0x4000, 0xBF80], [0x3F80, 0xBF80, 0x4000, 0x3F80]),  # infinity, length 4
        ([0x7FC1], [0x3F80]),  # NaN canonicalization
        ([0x7F80], [0x0000]),  # invalid infinity-times-zero -> canonical NaN
        ([0x3F80, 0x4000], [0x4040, 0x4080]),  # specified result 11.0
    ]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=20261013)
    parser.add_argument("--count", type=int, default=64, help="number of random transactions")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.count < 0:
        parser.error("--count must be non-negative")

    rng = random.Random(args.seed)
    transactions = directed_cases()
    for _ in range(args.count):
        length = rng.randint(1, 4)
        transactions.append(
            ([random_finite_bf16(rng) for _ in range(length)],
             [random_finite_bf16(rng) for _ in range(length)])
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as vectors:
        for a_values, b_values in transactions:
            a_padded = a_values + [0x7F80] * (4 - len(a_values))
            b_padded = b_values + [0x0000] * (4 - len(b_values))
            expected = bf16_dot(a_values, b_values)
            fields = [str(len(a_values))]
            fields.extend(f"{value:04x}" for value in a_padded)
            fields.extend(f"{value:04x}" for value in b_padded)
            fields.append(f"{expected:08x}")
            vectors.write(" ".join(fields) + "\n")

    print(
        f"Generated {len(transactions)} BF16 dot transactions "
        f"(seed={args.seed}, random={args.count}) -> {args.output}"
    )


if __name__ == "__main__":
    main()
