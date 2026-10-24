#!/usr/bin/env python3
"""Generate deterministic, bit-aware vectors for every SFU opcode."""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

REF_DIR = Path(__file__).resolve().parents[2] / "matrix" / "ref"
sys.path.insert(0, str(REF_DIR))
import ai_a3_reference as ref  # noqa: E402


OPS = {
    "softmax": 0x32,
    "rmsnorm": 0x33,
    "residual": 0x34,
    "gelu": 0x35,
    "requant": 0x36,
    "silu": 0x37,
    "layernorm": 0x38,
    "causal_softmax": 0x39,
}
LENGTHS = (1, 2, 3, 4, 7, 8, 15, 16)
SHIFT_BOUNDARIES = (0, 1, 7, 8, 15, 16, 30, 31)


def build_case(rng: random.Random, name: str, length: int, case_id: int):
    op = OPS[name]
    shift = SHIFT_BOUNDARIES[case_id % len(SHIFT_BOUNDARIES)] \
        if name in ("residual", "requant") else 0
    epsilon = rng.randrange(1, 17)
    beta_enable = int(name == "layernorm" and bool(case_id & 1))
    packed = int(name == "requant" and bool(case_id & 1))
    # Query token is a zero-based inclusive causal boundary.  Exercise token
    # zero at singleton and non-trivial lengths; the remaining cases cover
    # later query positions without ever relying on an out-of-range index.
    query = (0 if length in (1, 7) else rng.randrange(1, length)) \
        if name == "causal_softmax" else 0

    if name in ("softmax", "causal_softmax"):
        x = [rng.randint(-4096, 4096) for _ in range(length)]
        if name == "softmax":
            expected = ref.softmax_q15(x)
        else:
            visible_count = min(query + 1, length)
            visible = ref.softmax_q15(x[:visible_count])
            expected = visible + [0] * (length - visible_count)
        y = [0] * length
        beta = [0] * length
    elif name == "rmsnorm":
        x = [rng.randint(-8192, 8192) for _ in range(length)]
        y = [rng.randint(-32768, 32767) for _ in range(length)]
        beta = [0] * length
        expected = ref.rmsnorm_q15(x, y, epsilon=epsilon)
    elif name == "layernorm":
        x = [rng.randint(-8192, 8192) for _ in range(length)]
        y = [rng.randint(-32768, 32767) for _ in range(length)]
        beta = [rng.randint(-32, 32) if beta_enable else 0 for _ in range(length)]
        expected = ref.layernorm_q15(x, y, beta, epsilon=epsilon)
    elif name == "residual":
        x = [rng.randint(-(1 << 31), (1 << 31) - 1) for _ in range(length)]
        y = [rng.randint(-(1 << 31), (1 << 31) - 1) for _ in range(length)]
        beta = [0] * length
        expected = ref.residual_i32(x, y, shift)
    elif name == "gelu":
        x = [rng.randint(-2048, 2048) for _ in range(length)]
        for index, boundary in enumerate((-513, -512, -511, -1, 0, 1, 511, 512, 513)):
            if index < length:
                x[index] = boundary
        y = [0] * length
        beta = [0] * length
        expected = [ref.gelu_q8_8(v) for v in x]
    elif name == "silu":
        x = [rng.randint(-2048, 2048) for _ in range(length)]
        for index, boundary in enumerate((-769, -768, -767, -1, 0, 1, 767, 768, 769)):
            if index < length:
                x[index] = boundary
        y = [0] * length
        beta = [0] * length
        expected = [ref.silu_q8_8(v) for v in x]
    elif name == "requant":
        x = [rng.randint(-(1 << 31), (1 << 31) - 1) for _ in range(length)]
        y = [0] * length
        beta = [0] * length
        expected = ref.requant_i8(x, shift)
    else:
        raise AssertionError(name)
    return (op, length, shift, epsilon, beta_enable, packed, query, x, y, beta, expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261021)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    cases = [build_case(rng, op, length, case_id)
             for case_id, (op, length) in enumerate(
                 (pair for op in OPS for pair in ((op, n) for n in LENGTHS)))]
    with Path(args.output).open("w", encoding="ascii") as stream:
        stream.write(f"{len(cases)}\n")
        for op, length, shift, epsilon, beta_enable, packed, query, x, y, beta, expected in cases:
            stream.write(f"{op:02x} {length} {shift} {epsilon} {beta_enable} {packed} {query}\n")
            for fields in zip(x, y, beta, expected):
                vx, vy, vb, ve = fields
                stream.write(f"{vx} {vy} {vb} {ve & 0xffffffff:08x}\n")
    print(f"SFU_VECTOR_FILE_PASS cases={len(cases)} seed={args.seed} output={args.output}")


if __name__ == "__main__":
    main()
