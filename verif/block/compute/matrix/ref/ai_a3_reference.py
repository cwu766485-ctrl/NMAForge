#!/usr/bin/env python3
"""Bit-accurate reference functions for CIMForge A3/A4 tensor primitives."""

from __future__ import annotations

import argparse
import math
import random


INT32_MIN = -(1 << 31)
INT32_MAX = (1 << 31) - 1


def clamp(value: int, lower: int, upper: int) -> int:
    return min(max(value, lower), upper)


def trunc_div(numerator: int, denominator: int) -> int:
    """Signed integer division with SystemVerilog's truncation toward zero."""
    if denominator <= 0:
        raise ValueError("denominator must be positive")
    return numerator // denominator if numerator >= 0 else -((-numerator) // denominator)


def gemm_i8_i32(
    a: list[list[int]],
    b: list[list[int]],
    *,
    bias: list[int] | None = None,
    shift: int = 0,
    activation: str = "none",
) -> list[list[int]]:
    if not a or not b or len(a[0]) != len(b):
        raise ValueError("incompatible GEMM shapes")
    m, k, n = len(a), len(b), len(b[0])
    if any(len(row) != k for row in a) or any(len(row) != n for row in b):
        raise ValueError("ragged matrix")
    if bias is not None and len(bias) != n:
        raise ValueError("bias length must equal N")
    result: list[list[int]] = []
    for row in range(m):
        out_row: list[int] = []
        for col in range(n):
            value = sum(a[row][lane] * b[lane][col] for lane in range(k))
            if bias is not None:
                value += bias[col]
            value >>= shift
            if activation == "relu":
                value = max(value, 0)
            elif activation == "relu6":
                value = clamp(value, 0, 6)
            elif activation != "none":
                raise ValueError(f"unsupported activation {activation}")
            out_row.append(clamp(value, INT32_MIN, INT32_MAX))
        result.append(out_row)
    return result


def exp2_pwl_q15(delta_q8_8: int) -> int:
    """RTL PWL approximation of 2**delta, with delta expected <= 0."""
    if delta_q8_8 >= 0:
        return 1 << 15
    magnitude = -delta_q8_8
    integer = magnitude >> 8
    fraction = magnitude & 0xFF
    if integer >= 15:
        return 0
    base = (1 << 15) >> integer
    next_base = base >> 1
    return base - (((base - next_base) * fraction) >> 8)


def softmax_q15(scores_q8_8: list[int]) -> list[int]:
    if not scores_q8_8:
        raise ValueError("softmax vector must not be empty")
    maximum = max(scores_q8_8)
    exponentials = [exp2_pwl_q15(value - maximum) for value in scores_q8_8]
    total = sum(exponentials)
    if total == 0:
        raise AssertionError("stable softmax must have a non-zero denominator")
    return [clamp((value << 15) // total, 0, 1 << 15) for value in exponentials]


def rmsnorm_q15(values: list[int], gamma_q15: list[int], epsilon: int = 1) -> list[int]:
    if not values or len(values) != len(gamma_q15):
        raise ValueError("RMSNorm input and gamma lengths must match and be non-zero")
    mean_square = sum(value * value for value in values) // len(values)
    root = math.isqrt(mean_square + epsilon)
    root = max(root, 1)
    reciprocal_q30 = (1 << 30) // root
    result = []
    for value, gamma in zip(values, gamma_q15):
        scaled = clamp((value * gamma) >> 15, INT32_MIN, INT32_MAX)
        normalized = (scaled * reciprocal_q30) >> 30
        result.append(clamp(normalized, INT32_MIN, INT32_MAX))
    return result


def layernorm_q15(
    values: list[int], gamma_q15: list[int], beta: list[int] | None = None,
    epsilon: int = 1,
) -> list[int]:
    if not values or len(values) != len(gamma_q15):
        raise ValueError("LayerNorm input and gamma lengths must match and be non-zero")
    if beta is None:
        beta = [0] * len(values)
    if len(beta) != len(values):
        raise ValueError("LayerNorm beta length must match input")
    mean = trunc_div(sum(values), len(values))
    variance = sum((value - mean) ** 2 for value in values) // len(values)
    root = max(math.isqrt(variance + epsilon), 1)
    reciprocal_q30 = (1 << 30) // root
    result = []
    for value, gamma, offset in zip(values, gamma_q15, beta):
        scaled = clamp(((value - mean) * gamma) >> 15, INT32_MIN, INT32_MAX)
        normalized = (scaled * reciprocal_q30) >> 30
        result.append(clamp(normalized + offset, INT32_MIN, INT32_MAX))
    return result


def residual_i32(lhs: list[int], rhs: list[int], shift: int = 0) -> list[int]:
    if len(lhs) != len(rhs):
        raise ValueError("residual vectors must have equal lengths")
    return [clamp((a + b) >> shift, INT32_MIN, INT32_MAX) for a, b in zip(lhs, rhs)]


def gelu_q8_8(value: int) -> int:
    """A3's deliberately small piecewise-linear GELU approximation."""
    if value <= -512:
        return 0
    if value >= 512:
        return value
    return (value * (value + 512)) >> 10


def silu_q8_8(value: int) -> int:
    """A3's piecewise-linear SiLU approximation."""
    if value <= -768:
        return 0
    if value >= 768:
        return value
    return trunc_div(value * (value + 768), 1536)


def requant_i8(values: list[int], shift: int) -> list[int]:
    return [clamp(value >> shift, -128, 127) for value in values]


def qkv_projection_i8(
    activations: list[list[int]],
    weight_q: list[list[int]],
    weight_k: list[list[int]],
    weight_v: list[list[int]],
) -> tuple[list[list[int]], list[list[int]], list[list[int]]]:
    """Software composition represented by one A4 OP_QKV_PROJ macro."""
    return (
        gemm_i8_i32(activations, weight_q),
        gemm_i8_i32(activations, weight_k),
        gemm_i8_i32(activations, weight_v),
    )


def attention_head_q15(
    query: list[list[int]], key: list[list[int]], value: list[list[int]],
    score_shift: int = 0,
) -> list[list[int]]:
    """Reference QK^T -> row softmax Q15 -> AV for an A4 MHA child list."""
    if not query or not key or not value or len(query[0]) != len(key[0]):
        raise ValueError("invalid attention shapes")
    if len(key) != len(value):
        raise ValueError("key/value sequence lengths must match")
    scores = [
        [sum(q * k for q, k in zip(q_row, k_row)) >> score_shift for k_row in key]
        for q_row in query
    ]
    probabilities = [softmax_q15(row) for row in scores]
    width = len(value[0])
    return [
        [sum(prob[row] * value[row][col] for row in range(len(value))) >> 15
         for col in range(width)]
        for prob in probabilities
    ]


def ffn_i8(
    activations: list[list[int]], weight_up: list[list[int]],
    weight_down: list[list[int]], intermediate_shift: int,
) -> list[list[int]]:
    """GEMM -> GELU -> requant -> GEMM composition for OP_FFN."""
    expanded = gemm_i8_i32(activations, weight_up)
    activated_i8 = [requant_i8([gelu_q8_8(value) for value in row], intermediate_shift)
                    for row in expanded]
    return gemm_i8_i32(activated_i8, weight_down)


def randomized_self_test(cases: int, seed: int) -> None:
    rng = random.Random(seed)
    for _ in range(cases):
        m = n = 4
        k = rng.choice((4, 8, 12, 16))
        a = [[rng.randint(-128, 127) for _ in range(k)] for _ in range(m)]
        b = [[rng.randint(-128, 127) for _ in range(n)] for _ in range(k)]
        got = gemm_i8_i32(a, b)
        assert got == [
            [sum(a[row][lane] * b[lane][col] for lane in range(k)) for col in range(n)]
            for row in range(m)
        ]

        scores = [rng.randint(-2048, 2048) for _ in range(rng.randint(1, 32))]
        probabilities = softmax_q15(scores)
        assert all(0 <= value <= 32768 for value in probabilities)
        assert sum(probabilities) <= 32768
        assert sum(probabilities) >= 32768 - len(probabilities)
        assert probabilities[scores.index(max(scores))] == max(probabilities)

        values = [rng.randint(-32768, 32767) for _ in range(rng.randint(1, 32))]
        gamma = [rng.randint(-32768, 32767) for _ in values]
        norm = rmsnorm_q15(values, gamma, epsilon=rng.randint(1, 16))
        assert len(norm) == len(values)
        layer = layernorm_q15(values, gamma, epsilon=rng.randint(1, 16))
        assert len(layer) == len(values)

        lhs = [rng.randint(INT32_MIN, INT32_MAX) for _ in range(8)]
        rhs = [rng.randint(INT32_MIN, INT32_MAX) for _ in range(8)]
        assert all(INT32_MIN <= value <= INT32_MAX for value in residual_i32(lhs, rhs, rng.randrange(8)))
        assert all(-128 <= value <= 127 for value in requant_i8(lhs, rng.randrange(32)))

        for value in (rng.randint(-4096, 4096) for _ in range(8)):
            assert INT32_MIN <= gelu_q8_8(value) <= INT32_MAX
            assert INT32_MIN <= silu_q8_8(value) <= INT32_MAX

        tokens = [[rng.randint(-8, 7) for _ in range(4)] for _ in range(4)]
        weights = [
            [[rng.randint(-8, 7) for _ in range(4)] for _ in range(4)]
            for _ in range(3)
        ]
        q, key, value = qkv_projection_i8(tokens, *weights)
        assert len(q) == len(key) == len(value) == 4
        # Requantize projections to the INT8 boundary used by the RTL matrix
        # engine before composing the attention and FFN macro references.
        q8 = [requant_i8(row, 3) for row in q]
        k8 = [requant_i8(row, 3) for row in key]
        v8 = [requant_i8(row, 3) for row in value]
        attended = attention_head_q15(q8, k8, v8, score_shift=2)
        assert len(attended) == 4 and all(len(row) == 4 for row in attended)
        ffn = ffn_i8(tokens, weights[0], weights[1], intermediate_shift=4)
        assert len(ffn) == 4 and all(len(row) == 4 for row in ffn)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=20260722)
    args = parser.parse_args()
    randomized_self_test(args.cases, args.seed)
    print(f"A4_REFERENCE_PASS cases={args.cases} seed={args.seed}")


if __name__ == "__main__":
    main()
