#!/usr/bin/env python3
"""Check whether the Product KV append layout is consumable by Matrix QK."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw/tools"))
from cimforge_mapper import _pack_matrix_b_physical  # noqa: E402


def pack_append_layout(key_rows: list[list[int]]) -> list[int]:
    """Model KV_WRITE flags=1 word/byte placement for [token, feature]."""
    tokens = len(key_rows)
    features = len(key_rows[0])
    if tokens % 4 or features % 4 or any(len(row) != features for row in key_rows):
        raise ValueError("append layout requires rectangular dimensions divisible by 4")
    words = [0] * (tokens * features // 4)
    for token, row in enumerate(key_rows):
        for feature, value in enumerate(row):
            word_index = ((feature // 4) * (tokens // 4) + token // 4) * 4 + feature % 4
            byte_lane = token % 4
            words[word_index] |= (value & 0xFF) << (byte_lane * 8)
    return words


def unpack_matrix_b(words: list[int], k_dim: int, n_dim: int) -> list[list[int]]:
    """Invert _pack_matrix_b_physical into logical B[K,N]."""
    result = [[0] * n_dim for _ in range(k_dim)]
    for col in range(n_dim):
        col_group, col_lane = divmod(col, 4)
        for reduction in range(k_dim):
            k_group, k_lane = divmod(reduction, 4)
            word_index = col_group * (k_dim // 4) * 4 + k_group * 4 + col_lane
            value = (words[word_index] >> (k_lane * 8)) & 0xFF
            result[reduction][col] = value - 256 if value & 0x80 else value
    return result


def pack_matrix_a_layout(rows: list[list[int]]) -> list[int]:
    """Model Matrix-A tile word order for K[token, feature]."""
    size = len(rows)
    if size % 4 or any(len(row) != size for row in rows):
        raise ValueError("Matrix-A layout checker requires a square multiple-of-four tile")
    words = []
    for row_group in range(0, size, 4):
        for feature_group in range(0, size, 4):
            for token in range(row_group, row_group + 4):
                value = 0
                for lane in range(4):
                    value |= (rows[token][feature_group + lane] & 0xFF) << (lane * 8)
                words.append(value)
    return words


def transpose_inside_4x4_tiles(matrix: list[list[int]]) -> list[list[int]]:
    """Model transpose_b's lane/word swap while retaining 4x4 tile positions."""
    size = len(matrix)
    result = [[0] * size for _ in range(size)]
    for row in range(size):
        for col in range(size):
            row_group, row_lane = divmod(row, 4)
            col_group, col_lane = divmod(col, 4)
            result[row][col] = matrix[row_group * 4 + col_lane][col_group * 4 + row_lane]
    return result


def first_word_mismatch(actual: list[int], expected: list[int]) -> tuple[int, int, int] | None:
    for index, (got, want) in enumerate(zip(actual, expected)):
        if got != want:
            return index, want, got
    return None


def run(seed: int, size: int) -> dict:
    if size % 4:
        raise ValueError("size must be divisible by four")
    rng = random.Random(seed)
    key = [[rng.randrange(-128, 128) for _ in range(size)] for _ in range(size)]

    # QK uses B[K,N] = K^T, so each column is one cached token and each
    # reduction row is one head feature.
    expected_b = [[key[token][feature] for token in range(size)]
                  for feature in range(size)]
    expected_words = _pack_matrix_b_physical(expected_b)
    append_words = pack_append_layout(key)
    matrix_a_words = pack_matrix_a_layout(key)
    append_as_matrix_b = unpack_matrix_b(append_words, size, size)
    append_repacked_words = _pack_matrix_b_physical(append_as_matrix_b)
    local_transpose_words = _pack_matrix_b_physical(
        transpose_inside_4x4_tiles(append_as_matrix_b)
    )

    raw_mismatch = first_word_mismatch(append_words, expected_words)
    qk_mismatch = first_word_mismatch(append_repacked_words, expected_words)
    transpose_mismatch = first_word_mismatch(local_transpose_words, expected_words)
    matrix_a_mismatch = first_word_mismatch(matrix_a_words, expected_words)
    full_transpose_pass = append_as_matrix_b == expected_b
    result = {
        "seed": seed,
        "size": size,
        "raw_word_count": len(expected_words),
        "raw_word_mismatches": sum(a != b for a, b in zip(append_words, expected_words)),
        "matrix_b_logical_mismatches": sum(
            append_as_matrix_b[r][c] != expected_b[r][c]
            for r in range(size) for c in range(size)
        ),
        "transpose_b_local_tile_mismatches": sum(
            a != b for a, b in zip(local_transpose_words, expected_words)
        ),
        "matrix_a_qk_word_mismatches": sum(
            a != b for a, b in zip(matrix_a_words, expected_words)
        ),
        "matrix_a_qk_layout_pass": matrix_a_words == expected_words,
        "full_transpose_pass": full_transpose_pass,
        "first_raw_word_mismatch": raw_mismatch,
        "first_qk_word_mismatch": qk_mismatch,
        "first_transpose_b_word_mismatch": transpose_mismatch,
    }
    if full_transpose_pass or result["matrix_b_logical_mismatches"] == 0:
        raise AssertionError("append layout unexpectedly equals the QK transpose layout")
    if result["transpose_b_local_tile_mismatches"] == 0:
        raise AssertionError("4x4-local transpose unexpectedly performed full tile-grid transpose")
    if not result["matrix_a_qk_layout_pass"]:
        raise AssertionError("Matrix-A KV write layout differs from canonical QK Matrix-B layout")
    print("H64_KV_QK_LAYOUT_CHECK "+json.dumps(result, sort_keys=True))
    print("H64_KV_QK_LAYOUT_ROOT_CAUSE_CONFIRMED")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261115)
    parser.add_argument("--size", type=int, default=16)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    result = run(args.seed, args.size)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                             encoding="ascii")


if __name__ == "__main__":
    main()
