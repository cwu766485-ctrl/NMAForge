#!/usr/bin/env python3
"""Independent integer reference for the current H64 Product-Top contract.

This file deliberately does not import ``ai_a3_reference`` or the workload
generator.  It implements the frozen SFU/Matrix integer operations directly
and is used to detect disagreement between model-quality evaluation and the
contract used to create Product-Top memories.
"""
from __future__ import annotations

import math
from typing import Any

import numpy as np

I32_MIN, I32_MAX = -(1 << 31), (1 << 31) - 1


def sat(value: int, lo: int, hi: int) -> int:
    return min(hi, max(lo, int(value)))


def sat32(value: int) -> int:
    return sat(value, I32_MIN, I32_MAX)


def sat8(value: int) -> int:
    return sat(value, -128, 127)


def dot(a: list[int], b: list[int], shift: int = 0) -> int:
    if len(a) != len(b):
        raise ValueError("dot operand lengths differ")
    return sat32(sum(int(x) * int(y) for x, y in zip(a, b)) >> shift)


def gemm(a: np.ndarray, b: np.ndarray, shift: int = 0) -> np.ndarray:
    aa, bb = np.asarray(a), np.asarray(b)
    if aa.ndim != 2 or bb.ndim != 2 or aa.shape[1] != bb.shape[0]:
        raise ValueError(f"incompatible GEMM shapes {aa.shape} and {bb.shape}")
    result = np.empty((aa.shape[0], bb.shape[1]), dtype=np.int64)
    for m in range(aa.shape[0]):
        for n in range(bb.shape[1]):
            result[m, n] = dot(aa[m].tolist(), bb[:, n].tolist(), shift)
    return result.astype(np.int32)


def layernorm(values: list[int], gamma_q5: list[int], beta_i32: list[int]) -> list[int]:
    n = len(values)
    if n == 0 or len(gamma_q5) != n or len(beta_i32) != n:
        raise ValueError("LayerNorm vectors must have equal nonzero length")
    total = sum(int(v) for v in values)
    mean = total // n if total >= 0 else -((-total) // n)  # truncation toward zero
    variance = sum((int(v) - mean) ** 2 for v in values) // n
    root = max(1, math.isqrt(variance + 1))
    inv_q30 = (1 << 30) // root
    out = []
    for x, gq5, beta in zip(values, gamma_q5, beta_i32):
        gamma_q15 = int(gq5) * 1024
        g = sat32(((int(x) - mean) * gamma_q15) >> 15)
        out.append(sat32(((g * inv_q30) >> 30) + int(beta)))
    return out


def softmax_q15(row: list[int]) -> list[int]:
    if not row:
        raise ValueError("empty Softmax row")
    maximum = max(row)
    exps = []
    for value in row:
        delta = int(value) - maximum
        if delta >= 0:
            exp = 32768
        else:
            magnitude = -delta
            whole, fraction = magnitude >> 8, magnitude & 0xFF
            if whole >= 15:
                exp = 0
            else:
                base = 32768 >> whole
                exp = base - (((base - (base >> 1)) * fraction) >> 8)
        exps.append(exp)
    denominator = sum(exps)
    if denominator == 0:
        raise ArithmeticError("Softmax denominator is zero")
    return [min(32768, (e << 15) // denominator) for e in exps]


def gelu_q8_8(x: int) -> int:
    x = int(x)
    if x <= -512:
        return 0
    if x >= 512:
        return x
    return sat32((x * (x + 512)) >> 10)


def _matrix(model: dict[str, np.ndarray], key: str) -> np.ndarray:
    return np.asarray(model[key], dtype=np.int32)


def infer(model: dict[str, np.ndarray], tokens: list[int]) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    hidden = int(model["embedding"].shape[1])
    if hidden != 64 or len(tokens) > 16:
        raise ValueError("reference is scoped to H64 and context <=16")
    if any(t < 0 or t >= model["embedding"].shape[0] for t in tokens):
        raise ValueError("token ID outside embedding table")
    x = (model["embedding"][tokens].astype(np.int64) +
         model["position"][np.arange(len(tokens))].astype(np.int64))
    x = np.clip(x, I32_MIN, I32_MAX).astype(np.int32)
    trace: dict[str, np.ndarray] = {"embedding_position": x.copy()}

    for layer in range(4):
        p = f"l{layer}."
        ln1 = np.asarray([layernorm(row.tolist(), _matrix(model, p+"ln1_gamma").tolist(),
                                    _matrix(model, p+"ln1_beta").tolist()) for row in x], dtype=np.int32)
        a8 = np.clip(ln1, -128, 127).astype(np.int8)
        qkv = {}
        for name in ("q", "k", "v"):
            qkv[name] = np.clip(gemm(a8, _matrix(model, p+name)), -128, 127).astype(np.int8)

        heads = {name: qkv[name].reshape(len(tokens), 4, 16).transpose(1, 0, 2)
                 for name in ("q", "k", "v")}
        attended = np.zeros((len(tokens), 64), dtype=np.int64)
        scores_trace = []
        probs_trace = []
        for head in range(4):
            scores = gemm(heads["q"][head], heads["k"][head].T, shift=2)
            probs = np.zeros(scores.shape, dtype=np.int32)
            for r in range(len(tokens)):
                probs[r, :r+1] = softmax_q15(scores[r, :r+1].tolist())
            probs8 = np.clip(probs >> 8, -128, 127).astype(np.int8)
            av = gemm(probs8, heads["v"][head], shift=7)
            attended[:, head*16:(head+1)*16] = np.clip(av, -128, 127)
            scores_trace.append(scores)
            probs_trace.append(probs)
        output = gemm(attended.astype(np.int8), _matrix(model, p+"o"))
        residual1 = np.vectorize(sat32)(x.astype(np.int64) + output.astype(np.int64)).astype(np.int32)
        ln2 = np.asarray([layernorm(row.tolist(), _matrix(model, p+"ln2_gamma").tolist(),
                                    _matrix(model, p+"ln2_beta").tolist()) for row in residual1], dtype=np.int32)
        ffn_in = np.clip(ln2, -128, 127).astype(np.int8)
        up = gemm(ffn_in, _matrix(model, p+"up"))
        gelu = np.vectorize(gelu_q8_8, otypes=[np.int64])(up).astype(np.int32)
        gelu8 = np.clip(gelu, -128, 127).astype(np.int8)
        down_w = _matrix(model, p+"down")
        down = np.zeros((len(tokens), 64), dtype=np.int64)
        # The RTL divides the K dimension into sixteen 16-lane Matrix tiles;
        # each partial is accumulated through an INT32 residual operation.
        for tile in range(16):
            partial = gemm(gelu8[:, tile*16:(tile+1)*16], down_w[tile*16:(tile+1)*16])
            down = np.vectorize(sat32)(down + partial.astype(np.int64))
        residual2 = np.vectorize(sat32)(residual1.astype(np.int64) + down).astype(np.int32)
        for name, value in (("ln1", ln1), ("q", qkv["q"]), ("k", qkv["k"]),
                            ("v", qkv["v"]), ("scores", np.asarray(scores_trace)),
                            ("probabilities_q15", np.asarray(probs_trace)),
                            ("attention", attended.astype(np.int32)), ("projection", output),
                            ("residual1", residual1), ("ln2", ln2), ("up", up),
                            ("gelu", gelu), ("down", down.astype(np.int32)),
                            ("residual2", residual2)):
            trace[f"l{layer}.{name}"] = np.asarray(value).copy()
        x = residual2

    final_ln = np.asarray([layernorm(row.tolist(), _matrix(model, "final_gamma").tolist(),
                                     _matrix(model, "final_beta").tolist()) for row in x], dtype=np.int32)
    final8 = np.clip(final_ln, -128, 127).astype(np.int8)
    logits = gemm(final8, _matrix(model, "lm_head"))
    trace["final_ln"] = final_ln
    trace["logits"] = logits
    return logits, trace
