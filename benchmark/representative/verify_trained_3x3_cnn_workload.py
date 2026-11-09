#!/usr/bin/env python3
"""Independently decode packed SPAD operands and rebuild the CNN Golden."""

import argparse
import json
from pathlib import Path

import numpy as np


M, PAD_M, K1, N1, K2, N2 = 196, 208, 36, 64, 64, 16
INPUT, W1, RAW1, ACT1, W2, RAW2, OUTPUT = (
    0x00000, 0x02000, 0x03000, 0x10000, 0x14000, 0x15000, 0x19000
)
DESC, POISON = 0x1A000, 0xA55AA55A


def load_pairs(path):
    words = [int(line, 16) for line in path.read_text().splitlines()]
    count = words[0]
    if len(words) != 1 + 2 * count:
        raise ValueError("malformed address/value file: " + str(path))
    mapping = dict(zip(words[1::2], words[2::2]))
    if len(mapping) != count:
        raise ValueError("duplicate SPAD address in " + str(path))
    return mapping


def signed8(value):
    value &= 0xFF
    return value - 256 if value & 0x80 else value


def decode_a(memory, base, rows, inner):
    result = np.zeros((rows, inner), dtype=np.int8)
    groups = inner // 4
    for row in range(rows):
        tile, local = divmod(row, 16)
        row_group, row_lane = divmod(local, 4)
        for k_group in range(groups):
            index = tile * 16 * groups + row_group * 4 * groups + k_group * 4 + row_lane
            word = memory[base + index * 4]
            for lane in range(4):
                result[row, k_group * 4 + lane] = signed8(word >> (8 * lane))
    return result


def decode_b(memory, base, inner, cols):
    result = np.zeros((inner, cols), dtype=np.int8)
    groups = inner // 4
    for col_group in range(0, cols, 4):
        for k_group in range(groups):
            for lane in range(4):
                index = (col_group // 4) * groups * 4 + k_group * 4 + lane
                word = memory[base + index * 4]
                col = col_group + lane
                for byte_lane in range(4):
                    result[k_group * 4 + byte_lane, col] = signed8(word >> (8 * byte_lane))
    return result


def encode_a(matrix):
    values = []
    rows, inner = matrix.shape
    for tile in range(0, rows, 16):
        for group in range(tile, tile + 16, 4):
            for k0 in range(0, inner, 4):
                for row in range(group, group + 4):
                    word = 0
                    for lane in range(4):
                        word |= (int(matrix[row, k0 + lane]) & 0xFF) << (8 * lane)
                    values.append(word)
    return values


def encode_row_major(matrix):
    values = []
    for row in range(matrix.shape[0]):
        for col in range(0, matrix.shape[1], 4):
            values.append(sum((int(matrix[row, col + lane]) & 0xFF) << (lane * 8)
                              for lane in range(4)))
    return values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workload-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((args.workload_dir / "manifest.json").read_text())
    memory = load_pairs(args.workload_dir / "model_memory.memh")
    observed_golden = load_pairs(args.workload_dir / "model_golden.memh")
    expected_count = {"legacy": 4, "first_fused": 3,
                      "both_fused_row_major": 2}[manifest["fusion_mode"]]
    if manifest["descriptor_count"] != expected_count:
        raise ValueError("descriptor count does not match fusion mode")
    ops = []
    for index in range(expected_count):
        words = [memory[DESC + index * 64 + j * 4] for j in range(16)]
        ops.append(words[0] & 0xFF)
        if words[13] != 0x00010001 or words[15] & 0xFFFF != 7:
            raise ValueError("descriptor ABI fields invalid")
        if (words[5] & 0xFFFF) != PAD_M:
            raise ValueError("descriptor M does not match padded row count")
    expected_ops = {
        "legacy": [0x30, 0x36, 0x30, 0x36],
        "first_fused": [0x53, 0x30, 0x36],
        "both_fused_row_major": [0x53, 0x53],
    }[manifest["fusion_mode"]]
    if ops != expected_ops:
        raise ValueError("unexpected opcode sequence %r" % ops)
    if manifest["fusion_mode"] == "legacy":
        first_gemm = [memory[DESC], memory[DESC + 36]]
        if first_gemm[0] & 0xFF != 0x30 or ((first_gemm[1] >> 5) & 3) != 1:
            raise ValueError("legacy Conv1 must use Matrix ReLU before INT32 write")

    operand_a = decode_a(memory, INPUT, PAD_M, K1)
    weight1 = decode_b(memory, W1, K1, N1)
    weight2 = decode_b(memory, W2, K2, N2)
    raw1 = operand_a.astype(np.int64) @ weight1.astype(np.int64)
    if np.any(raw1 < -(1 << 31)) or np.any(raw1 >= (1 << 31)):
        raise OverflowError("independent Conv1 result exceeds INT32")
    raw1 = np.maximum(raw1, 0).astype(np.int32)
    hidden = np.clip(raw1 >> int(manifest["conv1_shift"]), 0, 127).astype(np.int8)
    raw2 = hidden.astype(np.int64) @ weight2.astype(np.int64)
    if np.any(raw2 < -(1 << 31)) or np.any(raw2 >= (1 << 31)):
        raise OverflowError("independent Conv2 result exceeds INT32")
    raw2 = raw2.astype(np.int32)
    output = np.clip(raw2 >> int(manifest["conv2_shift"]), -12