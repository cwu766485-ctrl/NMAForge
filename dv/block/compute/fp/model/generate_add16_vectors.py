#!/usr/bin/env python3
"""Generate deterministic BF16/FP16 add/sub vectors from the raw-bit oracle."""

from __future__ import annotations

import argparse
import random
from pathlib import Path
from typing import Iterable

import fp_reference as fp


Record = tuple[int, int, int, int]


def directed_records() -> Iterable[tuple[int, int, int, int, int]]:
    # fmt=0 is BF16, fmt=1 is FP16. Include tie-even/odd, gradual-underflow,
    # cancellation, overflow, signed-zero, infinities, and signaling/quiet NaNs.
    bf16 = [
        (0x3F80, 0x3B80, 0), (0x3F81, 0x3B80, 0),
        (0x3F80, 0x3B00, 0), (0x3F80, 0x3B01, 0),
        (0x0001, 0x0001, 0), (0x0001, 0x8001, 0),
        (0x0080, 0x8001, 0), (0x7F7F, 0x7F7F, 0),
        (0x3F80, 0xBF80, 0), (0x8000, 0x8000, 0),
        (0x0000, 0x8000, 0), (0x3F80, 0x3F80, 1),
        (0x7F80, 0xFF80, 0), (0x7FC1, 0x3F80, 0),
        (0x7F81, 0xBF80, 1), (0xFF80, 0x3F80, 1),
    ]
    fp16 = [
        (0x3C00, 0x1000, 0), (0x3C01, 0x1000, 0),
        (0x3C00, 0x0C00, 0), (0x3C00, 0x0C01, 0),
        (0x0001, 0x0001, 0), (0x0001, 0x8001, 0),
        (0x0400, 0x8001, 0), (0x7BFF, 0x7BFF, 0),
        (0x3C00, 0xBC00, 0), (0x8000, 0x8000, 0),
        (0x0000, 0x8000, 0), (0x3C00, 0x3C00, 1),
        (0x7C00, 0xFC00, 0), (0x7E01, 0x3C00, 0),
        (0x7C01, 0xBC00, 1), (0xFC00, 0x3C00, 1),
    ]
    for fmt_id, entries, oracle in (
        (0, bf16, fp.bf16_add_bits), (1, fp16, fp.fp16_add_bits)
    ):
        for a_bits, b_bits, subtract in entries:
            yield fmt_id, subtract, a_bits, b_bits, oracle(a_bits, b_bits, subtract=bool(subtract))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=20261013)
    parser.add_argument("--random-cases", type=int, default=10000,
                        help="random records per format")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.random_cases < 0:
        parser.error("--random-cases must be nonnegative")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(args.seed)
    directed = tuple(directed_records())
    emitted = 0
    with args.output.open("w", encoding="ascii", newline="\n") as vector_file:
        for fmt_id, subtract, a_bits, b_bits, expected in directed:
            vector_file.write(
                f"{fmt_id:x} {subtract:x} {a_bits:04x} {b_bits:04x} {expected:04x}\n"
            )
            emitted += 1
        for fmt_id, oracle in ((0, fp.bf16_add_bits), (1, fp.fp16_add_bits)):
            for _ in range(args.random_cases):
                a_bits = rng.getrandbits(16)
                b_bits = rng.getrandbits(16)
                subtract = rng.getrandbits(1)
                expected = oracle(a_bits, b_bits, subtract=bool(subtract))
                vector_file.write(
                    f"{fmt_id:x} {subtract:x} {a_bits:04x} {b_bits:04x} {expected:04x}\n"
                )
                emitted += 1

    print(
        f"FP16_BF16_ADDSUB_VECTOR_GEN seed={args.seed} directed={len(directed)} "
        f"random_per_format={args.random_cases} emitted_records={emitted} output={args.output}"
    )


if __name__ == "__main__":
    main()
