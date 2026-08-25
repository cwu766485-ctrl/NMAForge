#!/usr/bin/env python3
"""Dependency-free golden model for CIMForge A2 INT8 compute operations.

The RTL consumes four signed INT8 lanes from each little-endian 32-bit word,
accumulates into a wide signed value, applies an arithmetic right shift,
activation and signed-int32 saturation, and writes one 32-bit result per output.
Conv3x3 uses an im2col patch; DWConv3x3 stores one patch per output channel.
"""

from __future__ import annotations

import argparse
import random
from typing import Iterable, Sequence


INT32_MIN = -(1 << 31)
INT32_MAX = (1 << 31) - 1


def as_i8(value: int) -> int:
    value &= 0xFF
    return value - 0x100 if value & 0x80 else value


def unpack_i8x4(word: int) -> list[int]:
    return [as_i8(word >> (8 * lane)) for lane in range(4)]


def pack_i8x4(values: Sequence[int]) -> int:
    padded = list(values[:4]) + [0] * (4 - len(values))
    return sum((value & 0xFF) << (8 * lane) for lane, value in enumerate(padded))


def dot_words(lhs: Sequence[int], rhs: Sequence[int]) -> int:
    if len(lhs) != len(rhs):
        raise ValueError("packed vectors must have equal word counts")
    return sum(
        a * b
        for lhs_word, rhs_word in zip(lhs, rhs)
        for a, b in zip(unpack_i8x4(lhs_word), unpack_i8x4(rhs_word))
    )


def postprocess(accumulator: int, shift: int = 0, activation: str = "none") -> int:
    if not 0 <= shift <= 31:
        raise ValueError("shift must be in [0, 31]")
    value = accumulator >> shift
    if activation == "relu":
        value = max(value, 0)
    elif activation == "relu6":
        value = min(max(value, 0), 6)
    elif activation != "none":
        raise ValueError(f"unsupported activation: {activation}")
    return min(max(value, INT32_MIN), INT32_MAX)


def conv3x3_im2col(
    patches: Sequence[Sequence[int]],
    weights: Sequence[Sequence[int]],
    biases: Sequence[int] | None = None,
    shift: int = 0,
    activation: str = "none",
) -> list[list[int]]:
    """Return MxN results for M packed patches and N packed kernels."""
    if not patches or not weights:
        raise ValueError("at least one patch and one kernel are required")
    biases = list(biases) if biases is not None else [0] * len(weights)
    if len(biases) != len(weights):
        raise ValueError("bias count must match output-channel count")
    return [
        [postprocess(dot_words(patch, kernel) + biases[channel], shift, activation)
         for channel, kernel in enumerate(weights)]
        for patch in patches
    ]


def dwconv3x3(
    patches: Sequence[Sequence[Sequence[int]]],
    weights: Sequence[Sequence[int]],
    biases: Sequence[int] | None = None,
    shift: int = 0,
    activation: str = "none",
) -> list[list[int]]:
    """Return MxC depthwise results for patches laid out as [pixel][channel]."""
    biases = list(biases) if biases is not None else [0] * len(weights)
    if len(biases) != len(weights):
        raise ValueError("bias count must match channel count")
    outputs: list[list[int]] = []
    for pixel in patches:
        if len(pixel) != len(weights):
            raise ValueError("each pixel must contain one patch per channel")
        outputs.append([
            postprocess(dot_words(pixel[channel], weights[channel]) + biases[channel],
                        shift, activation)
            for channel in range(len(weights))
        ])
    return outputs


def pack_vector(values: Iterable[int]) -> list[int]:
    values = list(values)
    return [pack_i8x4(values[index:index + 4]) for index in range(0, len(values), 4)]


def run_self_test(seed: int, cases: int) -> None:
    patch = pack_vector(range(1, 10))
    ones = pack_vector([1] * 9)
    minus_ones = pack_vector([-1] * 9)
    assert conv3x3_im2col([patch], [ones, minus_ones], [5, 40],
                          activation="relu6") == [[6, 0]]

    twos = pack_vector([2] * 9)
    assert dwconv3x3([[patch, twos]], [ones, ones]) == [[45, 18]]

    rng = random.Random(seed)
    activations = ("none", "relu", "relu6")
    for case_index in range(cases):
        lanes = rng.randint(1, 36)
        lhs_values = [rng.randint(-128, 127) for _ in range(lanes)]
        rhs_values = [rng.randint(-128, 127) for _ in range(lanes)]
        padded_lanes = ((lanes + 3) // 4) * 4
        expected = sum(
            (lhs_values + [0] * (padded_lanes - lanes))[index]
            * (rhs_values + [0] * (padded_lanes - lanes))[index]
            for index in range(padded_lanes)
        )
        assert dot_words(pack_vector(lhs_values), pack_vector(rhs_values)) == expected

        pixels = rng.randint(1, 3)
        channels = rng.randint(1, 4)
        shift = case_index % 4
        activation = activations[case_index % len(activations)]
        patch_values = [
            [rng.randint(-8, 7) for _ in range(9)] for _ in range(pixels)
        ]
        weight_values = [
            [rng.randint(-8, 7) for _ in range(9)] for _ in range(channels)
        ]
        biases = [rng.randint(-64, 63) for _ in range(channels)]
        conv_expected = [
            [postprocess(sum(a * b for a, b in zip(patch, kernel)) + biases[channel],
                         shift, activation)
             for channel, kernel in enumerate(weight_values)]
            for patch in patch_values
        ]
        assert conv3x3_im2col(
            [pack_vector(patch) for patch in patch_values],
            [pack_vector(kernel) for kernel in weight_values],
            biases, shift, activation,
        ) == conv_expected

        depthwise_values = [
            [[rng.randint(-8, 7) for _ in range(9)] for _ in range(channels)]
            for _ in range(pixels)
        ]
        dw_expected = [
            [postprocess(
                sum(a * b for a, b in zip(pixel[channel], weight_values[channel]))
                + biases[channel], shift, activation)
             for channel in range(channels)]
            for pixel in depthwise_values
        ]
        assert dwconv3x3(
            [[pack_vector(patch) for patch in pixel] for pixel in depthwise_values],
            [pack_vector(kernel) for kernel in weight_values],
            biases, shift, activation,
        ) == dw_expected

    print(f"PASS: CIMForge A2 golden model "
          f"({cases} random dot/Conv3x3/DWConv3x3 cases, seed={seed})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=20260715)
    parser.add_argument("--cases", type=int, default=200)
    args = parser.parse_args()
    run_self_test(args.seed, args.cases)


if __name__ == "__main__":
    main()
