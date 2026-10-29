#!/usr/bin/env python3
"""Map TinyNPU's pinned conv1x_mini tensors into an NMAForge top-level job."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import onnx
from onnx import numpy_helper


ADDR = {
    "im2col": 0x10000, "conv_weight": 0x11000, "conv_round_bias": 0x11100,
    "conv_raw": 0x12000, "conv_i8": 0x13000, "identity_b": 0x14000,
    "conv_bias": 0x14100, "conv_bias_relu": 0x15000,
    "conv_relu_i8": 0x16000, "fc_a": 0x18000, "fc_b": 0x19000,
    "fc_round_bias": 0x1A000, "fc_raw": 0x1B000, "fc_i8": 0x1C000,
    "fc_bias": 0x1C100, "fc_biased": 0x1D000, "final_i8": 0x1E000,
}
DESC_BASE = 0x20000
CPL_BASE = 0x21000


def quantize_int8(values):
    values = np.asarray(values, dtype=np.float32)
    max_abs = float(np.max(np.abs(values)))
    if max_abs < 1e-10:
        return np.zeros_like(values, dtype=np.int8), 1.0
    scale = max_abs / 127.0
    return np.clip(np.round(values / scale), -128, 127).astype(np.int8), scale


def pack_i8(values):
    values = [int(v) & 0xFF for v in values]
    if len(values) != 4:
        raise ValueError("pack_i8 requires four lanes")
    return sum(v << (8 * lane) for lane, v in enumerate(values))


def add_words(memory, base, values):
    for index, value in enumerate(values):
        address = base + index * 4
        if address in memory:
            raise ValueError("SPAD image address overlap: 0x%08x" % address)
        memory[address] = int(value) & 0xFFFFFFFF


def flatten_words(values):
    return [int(v) & 0xFFFFFFFF for v in np.asarray(values).reshape(-1)]


def rounded_requant(acc, shift):
    bump = 1 << (shift - 1) if shift else 0
    return (np.asarray(acc, dtype=np.int64) + bump) >> shift


def build(model_path):
    model = onnx.load(str(model_path))
    initializers = {item.name: numpy_helper.to_array(item)
                    for item in model.graph.initializer}
    conv_w, _ = quantize_int8(initializers["conv_w"])
    conv_b, _ = quantize_int8(initializers["conv_b"])
    fc_w, _ = quantize_int8(initializers["fc_w"])
    fc_b, _ = quantize_int8(initializers["fc_b"])

    np.random.seed(99)
    input_fp = np.random.randn(1, 1, 8, 8).astype(np.float32) * 0.5
    input_i8, input_scale = quantize_int8(input_fp)
    source = input_i8[0, 0]
    im2col = np.asarray([
        [source[row + rr, col + cc] for rr in range(3) for cc in range(3)]
        for row in range(6) for col in range(6)
    ], dtype=np.int8)

    conv_weights = conv_w.reshape(4, 9)
    conv_acc = im2col.astype(np.int64) @ conv_weights.astype(np.int64).T
    # TinyNPU rounds acc/16, saturates to INT8, adds quantized bias with
    # INT8 saturation, then the following ONNX ReLU clamps negative values.
    conv_rounded = rounded_requant(conv_acc, 4)
    conv_pre_bias_i8 = np.clip(conv_rounded, -128, 127).astype(np.int8)
    # Matrix bias/ReLU remains INT32 in NMAForge; the following SFU requant
    # performs TinyNPU's INT8 clamp. Keep both boundaries in the Golden.
    conv_bias_relu_i32 = np.maximum(
        conv_pre_bias_i8.astype(np.int16) + conv_b.astype(np.int16), 0
    ).astype(np.int32)
    conv_relu = np.clip(conv_bias_relu_i32, 0, 127).astype(np.int8)
    conv_relu_flat = conv_relu.reshape(6, 6, 4).reshape(-1)

    fc_weights = fc_w.reshape(4, 144)
    fc_acc = conv_relu_flat.astype(np.int64) @ fc_weights.astype(np.int64).T
    fc_rounded = rounded_requant(fc_acc, 8)
    fc_pre_bias_i8 = np.clip(fc_rounded, -128, 127).astype(np.int8)
    final_logits = np.clip(fc_pre_bias_i8.astype(np.int16) +
                           fc_b.astype(np.int16), -128, 127).astype(np.int8)
    golden_bytes = final_logits.astype(np.int8).tobytes()

    memory = {}
    # The matrix controller fetches each 16-row tile as four row groups. Each
    # SPAD line holds one K-word for four rows, so the A layout is
    # row-group-major, then K-word, then the four rows in that group.
    im2col_words = []
    for tile_row in range(0, 36, 16):
        for row_group in range(0, 16, 4):
            for k0 in range(0, 9, 4):
                for row_lane in range(4):
                    row = tile_row + row_group + row_lane
                    lanes = list(im2col[row, k0:k0 + 4]) if row < 36 else []
                    lanes += [0] * (4 - len(lanes))
                    im2col_words.append(pack_i8(lanes))
    add_words(memory, ADDR["im2col"], im2col_words)

    # B stores one packed K-word per output column in each 16-byte line.
    conv_b_words = []
    for k0 in range(0, 9, 4):
        for channel in range(4):
            lanes = list(conv_weights[channel, k0:k0 + 4])
            lanes += [0] * (4 - len(lanes))
            conv_b_words.append(pack_i8(lanes))
    add_words(memory, ADDR["conv_weight"], conv_b_words)
    add_words(memory, ADDR["conv_round_bias"], [8] * 4)
    add_words(memory, ADDR["identity_b"], [
        pack_i8([1 if k == n else 0 for k in range(4)]) for n in range(4)
    ])
    add_words(memory, ADDR["conv_bias"], conv_b)
    add_words(memory, ADDR["fc_a"], [0] * (4 * 36))

    fc_b_words = []
    for k0 in range(0, 144, 4):
        for n in range(4):
            fc_b_words.append(pack_i8(fc_weights[n, k0:k0 + 4]))
    add_words(memory, ADDR["fc_b"], fc_b_words)
    add_words(memory, ADDR["fc_round_bias"], [128] * 4)
    add_words(memory, ADDR["fc_bias"], fc_b)
    for key, count in (("conv_raw", 144), ("conv_i8", 36),
                       ("conv_bias_relu", 144), ("conv_relu_i8", 36),
                       ("fc_raw", 16), ("fc_i8", 4),
                       ("fc_biased", 16), ("final_i8", 4)):
        add_words(memory, ADDR[key], [0xA55AA55A] * count)

    image_words = [len(memory)]
    for address, value in sorted(memory.items()):
        image_words.extend([address, value])

    conv_round_flat = flatten_words(conv_rounded)
    conv_i8_words = [pack_i8(conv_pre_bias_i8.reshape(36, 4)[r]) for r in range(36)]
    conv_relu_flat_i32 = flatten_words(conv_bias_relu_i32.reshape(36, 4))
    conv_relu_words = [pack_i8(conv_relu.reshape(36, 4)[r]) for r in range(36)]
    fc_round_padded = np.zeros((4, 4), dtype=np.int64)
    fc_round_padded[0] = fc_rounded
    fc_round_words = flatten_words(fc_round_padded)
    fc_i8_words = [pack_i8(np.clip(fc_round_padded[r], -128, 127))
                   for r in range(4)]
    fc_biased_padded = np.tile(fc_b.astype(np.int32), (4, 1))
    fc_biased_padded[0] += np.clip(fc_rounded, -128, 127).astype(np.int32)
    fc_biased_flat = flatten_words(fc_biased_padded)
    fc_final_words = [pack_i8(np.clip(fc_biased_padded[r], -128, 127))
                      for r in range(4)]

    expected_arrays = [
        conv_round_flat, conv_i8_words, conv_relu_flat_i32, conv_relu_words,
        fc_round_words, fc_i8_words, fc_biased_flat, fc_final_words,
    ]
    expected_words = [sum(len(values) for values in expected_arrays)]
    for values in expected_arrays:
        expected_words.extend([len(values)])
        expected_words.extend(values)

    manifest = {
        "model": model_path.name,
        "model_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "input_seed": 99,
        "input_scale": input_scale,
        "input_int8_sha256": hashlib.sha256(input_i8.tobytes()).hexdigest(),
        "conv_weight_scale": float(np.max(np.abs(initializers["conv_w"]))) / 127.0,
        "fc_weight_scale": float(np.max(np.abs(initializers["fc_w"]))) / 127.0,
        "conv_shape": "8x8x1 -> 6x6x4, im2col GEMM K=9",
        "fc_shape": "1x144 x 144x4; padded hardware M=4",
        "golden_int8": [int(value) for value in final_logits],
        "golden_packed_word": pack_i8(final_logits),
        "golden_sha256": hashlib.sha256(golden_bytes).hexdigest(),
        "stage_order": ["Conv GEMM + round", "INT8 clamp", "Conv bias + ReLU",
                        "flatten/layout pack", "FC GEMM + round", "INT8 clamp",
                        "FC bias", "INT8 output"],
    }
    return image_words, expected_words, manifest, golden_bytes


def write_memh(path, words):
    path.write_text("".join("%08x\n" % (int(word) & 0xFFFFFFFF) for word in words))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--tiny-golden", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    image_words, expected_words, manifest, golden_bytes = build(args.model)
    tiny_golden = args.tiny_golden.read_bytes()
    if tiny_golden != golden_bytes:
        raise SystemExit("independent CNN Golden differs from pinned TinyNPU golden.bin")
    write_memh(args.out_dir / "nma_cnn_spad.memh", image_words)
    write_memh(args.out_dir / "nma_cnn_expected.memh", expected_words)
    (args.out_dir / "nma_cnn_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("NMA_CNN_WORKLOAD_PASS input_words=%d expected_words=%d outputs=%d model_sha256=%s" %
          (image_words[0], len(expected_words), len(manifest["golden_int8"]),
           manifest["model_sha256"]))


if __name__ == "__main__":
    main()
