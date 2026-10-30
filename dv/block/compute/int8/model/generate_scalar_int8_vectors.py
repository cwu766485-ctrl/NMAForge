#!/usr/bin/env python3
"""Generate reproducible Scalar INT8 RTL vectors and independent Golden data."""

from __future__ import annotations

import argparse
import hashlib
import random
from dataclasses import dataclass
from pathlib import Path


SRC0 = 0x1000
SRC1 = 0x2000
DST = 0x3000
BIAS = 0x4000


def signed8(value: int) -> int:
    value &= 0xFF
    return value - 256 if value & 0x80 else value


def pack4(lanes: tuple[int, int, int, int]) -> int:
    return sum((value & 0xFF) << (8 * lane) for lane, value in enumerate(lanes))


def unpack4(word: int) -> tuple[int, int, int, int]:
    return tuple(signed8(word >> (8 * lane)) for lane in range(4))


def quantize(acc: int, shift: int, activation: int) -> int:
    # Python's signed right shift is floor division, matching a two's-complement
    # arithmetic shift for negative values.
    value = acc >> shift
    if activation == 1:
        value = max(0, value)
    elif activation == 2:
        value = min(6, max(0, value))
    # Encodings 0 and 3 follow the current RTL's no-activation datapath.
    value = min(0x7FFFFFFF, max(-0x80000000, value))
    return value & 0xFFFFFFFF


def dot_words(lhs: list[int], rhs: list[int], bias: int) -> int:
    acc = bias
    for a_word, b_word in zip(lhs, rhs):
        acc += sum(a * b for a, b in zip(unpack4(a_word), unpack4(b_word)))
    return acc


@dataclass
class Case:
    name: str
    opcode: int
    length: int
    m_size: int
    n_size: int
    k_words: int
    scale_shift: int
    activation: int
    bias_enable: bool
    biases: list[int]
    a_words: list[int]
    b_words: list[int]
    outputs: list[int]


def make_vdot(
    name: str,
    a: list[tuple[int, int, int, int]],
    b: list[tuple[int, int, int, int]],
    *,
    shift: int = 0,
    activation: int = 0,
    bias: int = 0,
    bias_enable: bool | None = None,
) -> Case:
    a_words = [pack4(x) for x in a]
    b_words = [pack4(x) for x in b]
    value = quantize(dot_words(a_words, b_words, bias), shift, activation)
    if bias_enable is None:
        bias_enable = bias != 0
    return Case(name, 0x10, len(a_words), 0, 0, 0, shift, activation,
                bias_enable, [bias], a_words, b_words, [value])


def build_cases(seed: int) -> list[Case]:
    rng = random.Random(seed)
    cases = [
        make_vdot("vdot_signed_lane_order", [(-128, 127, -1, 1)],
                  [(1, -1, -128, 127)]),
        make_vdot("vdot_negative_arithmetic_shift", [(1, 1, 1, 0)],
                  [(-1, -1, -1, 0)], shift=1),
        make_vdot("vdot_max_product", [(-128, -128, -128, -128)] * 4,
                  [(-128, -128, -128, -128)] * 4),
        make_vdot("vdot_shift_31_negative", [(0, 0, 0, 0)],
                  [(127, -128, 3, -4)], shift=31, bias=-0x80000000, bias_enable=True),
        make_vdot("vdot_positive_saturation", [(1, 0, 0, 0)],
                  [(1, 0, 0, 0)], bias=0x7FFFFFFF, bias_enable=True),
        make_vdot("vdot_negative_saturation", [(1, 0, 0, 0)],
                  [(-1, 0, 0, 0)], bias=-0x80000000, bias_enable=True),
        make_vdot("vdot_relu_negative", [(2, 0, 0, 0)],
                  [(-2, 0, 0, 0)], activation=1),
        make_vdot("vdot_relu6_upper_clamp", [(5, 0, 0, 0)],
                  [(4, 0, 0, 0)], activation=2),
        make_vdot("vdot_relu6_lower_clamp", [(3, 0, 0, 0)],
                  [(-4, 0, 0, 0)], activation=2),
        make_vdot("vdot_reserved_activation_falls_through", [(3, 0, 0, 0)],
                  [(5, 0, 0, 0)], activation=3),
        make_vdot("vdot_bias_before_shift", [(1, 1, 1, 0)],
                  [(-2, -2, -1, 0)], shift=2, bias=11, bias_enable=True),
    ]

    random_a = [tuple(rng.randint(-128, 127) for _ in range(4)) for _ in range(17)]
    random_b = [tuple(rng.randint(-128, 127) for _ in range(4)) for _ in range(17)]
    cases.append(make_vdot("vdot_seeded_k17", random_a, random_b,
                           shift=7, bias=-913))

    # GEMV uses one K-word activation vector and one contiguous K-word weight
    # vector per output row. Bias is indexed by output row.
    k_words = 5
    m_size = 3
    vector = [pack4(tuple(rng.randint(-128, 127) for _ in range(4)))
              for _ in range(k_words)]
    rows = [[pack4(tuple(rng.randint(-128, 127) for _ in range(4)))
             for _ in range(k_words)] for _ in range(m_size)]
    row_bias = [0x7FFFFFF0, -0x7FFFFFF0, 37]
    gemv_outputs = [quantize(dot_words(vector, row_words, row_bias[row]), 3, 0)
                    for row, row_words in enumerate(rows)]
    cases.append(Case("gemv_m3_k5_bias", 0x11, 0, m_size, 0, k_words,
                      3, 0, True, row_bias, vector, [word for row in rows for word in row],
                      gemv_outputs))

    # GEMM's B operands are stored as one contiguous K-vector per output
    # column; output memory is row-major and bias is indexed by column.
    m_size, n_size, k_words = 2, 3, 4
    a_rows = [[pack4(tuple(rng.randint(-128, 127) for _ in range(4)))
               for _ in range(k_words)] for _ in range(m_size)]
    b_cols = [[pack4(tuple(rng.randint(-128, 127) for _ in range(4)))
               for _ in range(k_words)] for _ in range(n_size)]
    col_bias = [13, -29, 41]
    gemm_outputs = [
        quantize(dot_words(a_rows[row], b_cols[col], col_bias[col]), 2, 1)
        for row in range(m_size) for col in range(n_size)
    ]
    cases.append(Case("gemm_m2_n3_k4_relu_bias", 0x12, 0, m_size, n_size,
                      k_words, 2, 1, True, col_bias,
                      [word for row in a_rows for word in row],
                      [word for col in b_cols for word in col], gemm_outputs))
    return cases


def vectorize(case: Case) -> tuple[dict[int, int], list[tuple[int, int]]]:
    memory: dict[int, int] = {}
    expected: list[tuple[int, int]] = []
    if case.opcode == 0x10:
        for index, word in enumerate(case.a_words):
            memory[SRC0 + 4 * index] = word
        for index, word in enumerate(case.b_words):
            memory[SRC1 + 4 * index] = word
        if case.bias_enable:
            for index, bias in enumerate(case.biases):
                memory[BIAS + 4 * index] = bias & 0xFFFFFFFF
        expected.append((DST, case.outputs[0]))
    elif case.opcode == 0x11:
        for index, word in enumerate(case.a_words):
            memory[SRC0 + 4 * index] = word
        for index, word in enumerate(case.b_words):
            memory[SRC1 + 4 * index] = word
        if case.bias_enable:
            for index, bias in enumerate(case.biases):
                memory[BIAS + 4 * index] = bias & 0xFFFFFFFF
        expected.extend((DST + 4 * index, value)
                        for index, value in enumerate(case.outputs))
    else:
        for index, word in enumerate(case.a_words):
            memory[SRC0 + 4 * index] = word
        for index, word in enumerate(case.b_words):
            memory[SRC1 + 4 * index] = word
        if case.bias_enable:
            for index, bias in enumerate(case.biases):
                memory[BIAS + 4 * index] = bias & 0xFFFFFFFF
        expected.extend((DST + 4 * index, value)
                        for index, value in enumerate(case.outputs))
    return memory, expected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261030)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    cases = build_cases(args.seed)
    with args.out.open("w", encoding="ascii") as stream:
        stream.write(f"COUNT {len(cases)}\n")
        for case_id, case in enumerate(cases):
            memory, expected = vectorize(case)
            stream.write(
                "CASE {} {} {:02x} {:08x} {:08x} {:08x} {:08x} {} {} {} {} {} {} {} {} {}\n".format(
                    case_id, case.name, case.opcode, SRC0, SRC1, DST, BIAS,
                    case.length, case.m_size, case.n_size, case.k_words,
                    case.scale_shift, case.activation, int(case.bias_enable),
                    len(memory), len(expected)))
            for address, value in sorted(memory.items()):
                stream.write(f"M {address:08x} {value:08x}\n")
            for address, value in expected:
                stream.write(f"E {address:08x} {value:08x}\n")
    digest = hashlib.sha256(args.out.read_bytes()).hexdigest()
    print(f"SCALAR_INT8_VECTOR_GEN cases={len(cases)} seed={args.seed} sha256={digest} out={args.out}")


if __name__ == "__main__":
    main()
