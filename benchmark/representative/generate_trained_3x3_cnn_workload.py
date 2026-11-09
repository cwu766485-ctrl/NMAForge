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
    # Match the training feature order: [kernel-position][input-channel].
    # Stacking at axis=2 would flatten [input-channel][kernel-position], which
    # silently permutes the deployed Conv1 input while preserving GEMM Golden.
    patches = np.stack(
        [planes[y:y + 14, x:x + 14, :].reshape(M, 4)
         for y in range(3) for x in range(3)], axis=2
    ).transpose(0, 2, 1).reshape(M, K1)
    columns = np.zeros((PAD_M, K1), dtype=np.int8)
    columns[:M] = np.rint(patches * 127.0).clip(-127, 127).astype(np.int8)
    im2col_seconds = time.perf_counter() - started

    model_weights = model["weights_int8"]
    weights1 = np.asarray(model_weights["conv1_k36_n64"], dtype=np.int8)
    weights2 = np.asarray(model_weights["conv2_k64_n16"], dtype=np.int8)
    if weights1.shape != (K1, N1) or weights2.shape != (K2, N2):
        raise ValueError("trained model weight shape violates Matrix mapping")
    golden_start = time.perf_counter()
    raw1 = signed_matrix_product(columns, weights1)
    # Legacy GEMM requests the legal Matrix post-process ReLU before the
    # INT32 write. Opcode 0x36 itself only shifts and saturates; it has no
    # activation control.
    raw1 = np.maximum(raw1, 0).astype(np.int32)
    shift1, shift2 = (int(model["quantization"]["conv1_shift"]),
                      int(model["quantization"]["conv2_shift"]))
    hidden = np.clip(raw1 >> shift1, 0, 127).astype(np.int8)
    raw2 = signed_matrix_product(hidden, weights2)
    output = np.clip(raw2 >> shift2, -128, 127).astype(np.int8)
    output_words = [
        pack4(output[row, col:col + 4])
        for row in range(PAD_M) for col in range(0, N2, 4)
    ]
    golden_seconds = time.perf_counter() - golden_start

    commands = []
    def append(index, op, a, b, out, m, n, k_or_length, **kwargs):
        wait = 0 if index == 0 else 1 << ((index - 1) & 1)
        command_count = {"legacy": 4, "first_fused": 3,
                         "both_fused_row_major": 2}[args.fusion_mode]
        signal = 0 if index == command_count - 1 else 1 << (index & 1)
        commands.append(make_desc(0x7100 + index, op, a, b, out, m, n,
                                  k_or_length, wait=wait, signal=signal,
                                  **kwargs))

    if args.fusion_mode == "legacy":
        append(0, 0x30, INPUT, W1, RAW1, PAD_M, N1, K1 // 4,
               activation=1)
        append(1, 0x36, RAW1, 0, ACT1, PAD_M, N1, PAD_M * N1,
               flags=0x30, shift=shift1)
        append(2, 0x30, ACT1, W2, RAW2, PAD_M, N2, K2 // 4)
        append(3, 0x36, RAW2, 0, OUTPUT, PAD_M, N2, PAD_M * N2,
               flags=0x10, shift=shift2)
    elif args.fusion_mode == "first_fused":
        append(0, 0x53, INPUT, W1, ACT1, PAD_M, N1, K1 // 4,
               aux0=shift1, activation=1)
        append(1, 0x30, ACT1, W2, RAW2, PAD_M, N2, K2 // 4)
        append(2, 0x36, RAW2, 0, OUTPUT, PAD_M, N2, PAD_M * N2,
               flags=0x10, shift=shift2)
    else:
        append(0, 0x53, INPUT, W1, ACT1, PAD_M, N1, K1 // 4,
               aux0=shift1, activation=1)
        append(1, 0x53, ACT1, W2, OUTPUT, PAD_M, N2, K2 // 4,
               aux0=0x80 | shift2)

    memory = {}
    add_words(memory, INPUT, pack_a(columns))
    add_words(memory, W1, pack_b(weights1))
    add_words(memory, RAW1, [POISON] * (PAD_M * N1))
    add_words(memory, ACT1, [POISON] * (PAD_M * N1 // 4))
    add_words(memory, W2, pack_b(weights2))
    add_words(memory, RAW2, [POISON] * (PAD_M * N2))
    add_words(memory, OUTPUT, [POISON] * (PAD_M * N2 // 4))
    for index, descriptor in enumerate(commands):
        add_words(memory, DESC + index * 64, descriptor)
        add_words(memory, CPL + index * 16, [POISON] * 4)

    expected = {}
    def expect_words(base, values):
        for index, value in enumerate(values):
            address = base + index * 4
            if address in expected:
                raise ValueError("duplicate Golden address 0x%08x" % address)
            expected[address] = int(value) & 0xFFFFFFFF

    if args.fusion_mode == "legacy":
        expect_words(RAW1, raw1.reshape(-1))
    else:
        expect_words(RAW1, [POISON] * (PAD_M * N1))
    expect_words(ACT1, pack_a(hidden))
    if args.fusion_mode != "both_fused_row_major":
        expect_words(RAW2, raw2.reshape(-1))
    else:
        expect_words(RAW2, [POISON] * (PAD_M * N2))
    expect_words(OUTPUT, output_words)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    image_path = args.out_dir / "model_memory.memh"
    golden_path = args.out_dir / "model_golden.memh"
    write_pair_file(image_path, memory)
    write_pair_file(golden_path, expected)
    prediction = int(output[:M, :10].astype(np.int32).mean(axis=0).argmax())
    useful_macs = M * (K1 * 63 + 1 + K2 * 10)
    manifest = {
        "model": model["model"], "model_file_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "deployed_weight_sha256": model["deployed_weight_sha256"],
        "dataset_sha256": dataset_hash, "sample_index": sample_index,
        "test_rank": args.test_rank, "true_label": int(dataset.target[sample_index]),
        "predicted_label": prediction, "sample_classification": "PASS" if prediction == int(dataset.target[sample_index]) else "FAIL",
        "quantized_heldout_accuracy": model["quantized_test_accuracy"],
        "seed": model["seed"], "fusion_mode": args.fusion_mode,
        "input_shape": [1, 16, 16, 4], "conv1_shape": [M, K1, N1],
        "conv2_shape": [M, K2, N2], "padded_matrix_m": PAD_M,
        "input_feature_order": "kernel-position then input-channel; matches train_digits_3x3_cnn.lower_images",
        "conv1_shift": shift1, "conv2_shift": shift2,
        "useful_macs_per_inference": useful_macs,
        "descriptor_count": len(commands), "descriptor_base": DESC,
        "completion_base": CPL, "spad_capacity_bytes": 128 * 1024,
        "spad_high_water_exclusive": max(memory) + 4,
        "preload_axi_words": len(memory), "preload_axi_bytes": len(memory) * 4,
        "host_im2col_seconds": im2col_seconds,
        "host_integer_golden_seconds": golden_seconds,
        "host_im2col_payload_bytes": PAD_M * K1,
        "valid_im2col_bytes": M * K1,
        "spad_input_pack_bytes": PAD_M * K1,
        "padding_rows": PAD_M - M,
        "host_fallback_compute": "none; conv GEMM and pointwise GEMM execute in Top RTL",
        "host_preprocessing": "8x8-to-16x16 nearest upsample, coordinate planes, 3x3 Im2col and input/weight packing",
        "host_postprocessing": "global average of 14x14 class scores and argmax",
        "independent_golden": "signed INT64 Python/NumPy accumulation checked for INT32 range, explicit requant/ReLU/saturation and memory-image compare",
        "memory_image_sha256": hashlib.sha256(image_path.read_bytes()).hexdigest(),
        "golden_file_sha256": hashlib.sha256(golden_path.read_bytes()).hexdigest(),
    }
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                                                 encoding="utf-8")
    print("R19_TRAINED_CNN_WORKLOAD_PASS mode=%s sample=%d label=%d prediction=%d descriptors=%d useful_macs=%d spad_high_water=0x%x golden_words=%d im2col_seconds=%.6f image_sha256=%s golden_sha256=%s" % (
        args.fusion_mode, sample_index, manifest["true_label"], prediction,
        len(commands), useful_macs, manifest["spad_high_water_exclusive"],
        len(expected), im2col_seconds, manifest["memory_image_sha256"],
        manifest["golden_file_sha256"]))


if __name__ == "__main__":
    main()
