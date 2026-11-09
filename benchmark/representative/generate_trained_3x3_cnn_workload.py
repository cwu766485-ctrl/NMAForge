#!/usr/bin/env python3
"""Lower one held-out trained Digits CNN sample to ABI-v7 Top descriptors."""

import argparse
import hashlib
import json
import time
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits


M, PAD_M = 196, 208
K1, N1, K2, N2 = 36, 64, 64, 16
INPUT, W1, RAW1, ACT1, W2, RAW2, OUTPUT = (
    0x00000, 0x02000, 0x03000, 0x10000, 0x14000, 0x15000, 0x19000
)
DESC, CPL, POISON = 0x1A000, 0x1A200, 0xA55AA55A
MODES = ("legacy", "first_fused", "both_fused_row_major")


def pack4(values):
    if len(values) != 4:
        raise ValueError("expected four byte lanes")
    return sum((int(value) & 0xFF) << (8 * lane)
               for lane, value in enumerate(values))


def pack_a(matrix):
    rows, inner = matrix.shape
    if rows % 16 or inner % 4:
        raise ValueError("Matrix-A packing requires M%16=0 and K%4=0")
    words = []
    for tile in range(0, rows, 16):
        for group in range(tile, tile + 16, 4):
            for k0 in range(0, inner, 4):
                for row in range(group, group + 4):
                    words.append(pack4(matrix[row, k0:k0 + 4]))
    return words


def pack_b(matrix):
    inner, cols = matrix.shape
    if inner % 4 or cols % 16:
        raise ValueError("Matrix-B packing requires K%4=0 and N%16=0")
    words = []
    for col_group in range(0, cols, 4):
        for k0 in range(0, inner, 4):
            for col in range(col_group, col_group + 4):
                words.append(pack4(matrix[k0:k0 + 4, col]))
    return words


def add_words(memory, base, values):
    for index, value in enumerate(values):
        address = base + index * 4
        if address in memory:
            raise ValueError("SPAD image overlap at 0x%08x" % address)
        memory[address] = int(value) & 0xFFFFFFFF


def make_desc(task, op, src0, src1, dst, m, n, k_or_length, *,
              flags=0, aux0=0, shift=0, activation=0, wait=0, signal=0):
    words = [0] * 16
    words[0] = (task << 16) | op
    words[1], words[2], words[4] = src0, src1, dst
    words[5] = (n << 16) | m
    words[6], words[7], words[8] = k_or_length, flags, aux0
    words[9] = (activation << 5) | shift
    words[13] = 0x00010001
    words[14] = (signal << 16) | wait
    words[15] = (wait << 16) | 7
    return words


def signed_matrix_product(a, b):
    # int64 reference accumulation is independent of DUT's 64-bit internal
    # accumulator and is checked before reducing to the specified INT32 word.
    product = a.astype(np.int64) @ b.astype(np.int64)
    if np.any(product < -(1 << 31)) or np.any(product >= (1 << 31)):
        raise OverflowError("INT32 GEMM Golden overflow")
    return product.astype(np.int32)


def write_pair_file(path, mapping):
    words = [len(mapping)]
    for address, value in sorted(mapping.items()):
        words.extend((address, int(value) & 0xFFFFFFFF))
    path.write_text("".join("%08x\n" % word for word in words),
                    encoding="ascii")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--fusion-mode", choices=MODES, default="legacy")
    parser.add_argument("--test-rank", type=int, default=0,
                        help="index in the frozen held-out test split")
    args = parser.parse_args()
    model_bytes = args.model.read_bytes()
    model = json.loads(model_bytes)
    dataset = load_digits()
    dataset_hash = hashlib.sha256(
        dataset.images.tobytes(order="C") +
        dataset.target.astype("<i8").tobytes()
    ).hexdigest()
    if dataset_hash != model["dataset_sha256"]:
        raise ValueError("Digits dataset SHA does not match trained model")
    test_indices = model["test_indices"]
    if args.test_rank < 0 or args.test_rank >= len(test_indices):
        raise ValueError("test-rank is outside the fixed held-out split")
    sample_index = int(test_indices[args.test_rank])

    started = time.perf_counter()
    image = dataset.images[sample_index].astype(np.float32) / 16.0
    image = np.repeat(np.repeat(image, 2, axis=0), 2, axis=1)
    coordinate = np.linspace(-1.0, 1.0, 16, dtype=np.float32)
    yy, xx = np.meshgrid(coordinate, coordinate, indexing="ij")
    planes = np.stack((image, np.ones_like(image), yy, xx), axis=-1)
    patches = np.stack(
        [planes[y:y + 14, x:x + 14, :].reshape(M, 4)
         for y in range(3) for x in range(3)], axis=2
    ).reshape(M, K1)
    columns = np.zeros((PAD_M, K1), dtype=np.int8)
    columns[:M] = np.rint(patches * 127.0).clip(-127, 127).astype(np.int8)
    im2col_seconds = time.perf_counter() - started

    model_weights = model["weights_int8"]
    weights1 = np.asarray(model_weights["conv1_k36_n64"], dtype=np.int8)
    weights2 = np.asarray(model_weights["conv2_k64_n16"], dtype=np.int8)
    if weights1.shape != (K1, N1) or weights2.shape != (K2, N2):
        raise ValueError("trained model weight shape violates Matrix mapp