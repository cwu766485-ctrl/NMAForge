#!/usr/bin/env python3
"""Generate replayable BF16/FP16 dot transactions from the exact reference."""

from __future__ import annotations

import argparse
import random
from pathlib import Path

import fp_reference as fp


def random_finite(rng: random.Random, fmt: fp.FPFormat) -> int:
    sign = rng.randrange(2) << (fmt.width - 1)
    category = rng.randrange(5)
    if category == 0:
        return sign
    if category == 1:
        return sign | rng.randrange(1, 1 << fmt.fraction_bits)
    exponent = rng.randrange(1, fmt.exponent_mask)
    fraction = rng.randrange(1 << fmt.fraction_bits)
    return sign | (exponent << fmt.fraction_bits) | fraction


def directed_cases(fmt: fp.FPFormat) -> list[tuple[list[int], list[int]]]:
    if fmt == fp.BF16:
        one, two, three, four = 0x3F80, 0x4000, 0x4040, 0x4080
        infinity, nan, minimum_subnormal = 0x7F80, 0x7FC1, 0x0001
        zero = 0x0000
    else:
        one, two, three, four = 0x3C00, 0x4000, 0x4200, 0x4400
        infinity, nan, minimum_subnormal = 0x7C00, 0x7E01, 0x0001
        zero = 0x0000
    return [
        ([zero], [one]),
        ([minimum_subnormal, one], [one, one]),
        ([one, two, 0xBC00], [three, four, one]),
        ([infinity, one, two, 0xBC00], [one, 0xBF80 if fmt == fp.BF16 else 0xBC00,
                                       two, one]),
        ([nan], [one]),
        ([one], [nan]),  # NaN in the B operand
        ([infinity], [zero]),
        ([zero], [infinity]),  # invalid 0 x Inf with operands reversed
        ([one], [infinity]),  # Inf in the B operand
        ([one, two], [three, four]),
    ]


def dot_result(fmt: fp.FPFormat, a_values: list[int], b_values: list[int]) -> int:
    if fmt == fp.BF16:
        return fp.bf16_dot(a_values, b_values)
    return fp.fp16_dot(a_values, b_values)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=20261013)
    parser.add_argument("--count", type=int, default=64,
                        help="number of random transactions per format")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.count < 0:
        parser.error("--count must be nonnegative")

    rng = random.Random(args.seed)
    transactions: list[tuple[int, list[int], list[int]]] = []
    for format_code, fmt in enumerate((fp.BF16, fp.FP16)):
        transactions.extend((format_code, a, b) for a, b in directed_cases(fmt))
        lengths = list(range(1, 17)) if args.count >= 16 else []
        lengths.extend(rng.randint(1, 16) for _ in range(args.count - len(lengths)))
        for length in lengths:
            transactions.append((format_code,
                                 [random_finite(rng, fmt) for _ in range(length)],
                                 [random_finite(rng, fmt) for _ in range(length)]))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as vectors:
        for format_code, a_values, b_values in transactions:
            fmt = fp.FP16 if format_code else fp.BF16
            pad_a = 0x7C00 if format_code else 0x7F80
            pad_b = 0x0000
            a_padded = a_values + [pad_a] * (16 - len(a_values))
            b_padded = b_values + [pad_b] * (16 - len(b_values))
            expected = dot_result(fmt, a_values, b_values)
            fields = [str(format_code), str(len(a_values))]
            fields.extend(f"{value:04x}" for value in a_padded)
            fields.extend(f"{value:04x}" for value in b_padded)
            fields.append(f"{expected:08x}")
            vectors.write(" ".join(fields) + "\n")

    print(f"MIXED_DOT_VECTOR_GEN seed={args.seed} per_format_random={args.count} "
          f"directed_per_format={len(directed_cases(fp.BF16))} "
          f"total={len(transactions)} output={args.output}")


if __name__ == "__main__":
    main()
