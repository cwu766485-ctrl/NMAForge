#!/usr/bin/env python3
"""Map TinyNPU's pinned conv1x_mini tensors into an NMAForge top-level job."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "sw/tools"))
from spad_memory_planner import SpadMemoryPlanner
import onnx
from onnx import numpy_helper


# Reserved maxima cover the existing four/ten-class fixtures, including packing
# and intermediates; a single allocator generates the TB layout image as well.
REGION_BYTES = {"im2col":576,"conv_weight":48,"conv_round_bias":16,
    "conv_raw":576,"conv_i8":144,"identity_b":16,"conv_bias":16,
    "conv_bias_relu":576,"conv_relu_i8":144,"fc_a":576,"fc_b":1728,
    "fc_round_bias":16,"fc_raw":192,"fc_i8":48,"fc_bias":48,
    "fc_biased":192,"final_i8":64,"descriptor":8192,"completion":2048}


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


def build(model_path, input_npz=None, spad_base_shift=0, spad_bytes=131072):
    if spad_base_shift != 0:
        raise ValueError("Manual base shifts are obsolete; use capacity-aware allocation")
    planner = SpadMemoryPlanner(spad_bytes)
    addr = {name:planner.reserve(name,size,256) for name,size in REGION_BYTES.items()}
    desc_base = addr["descriptor"]
    cpl_base = addr["completion"]
    if model_path.suffix == ".npz":
        with np.load(model_path) as weights:
            initializers = {name: weights[name] for name in
                            ("conv_w", "conv_b", "fc_w", "fc_b")}
            model_kind = str(weights["model_kind"].item()) if "model_kind" in weights else "quantized_weight_package"
    else:
        model = onnx.load(str(model_path))
        initializers = {item.name: numpy_helper.to_array(item)
                        for item in model.graph.initializer}
        model_kind = "onnx_reference_graph"
    conv_w, _ = quantize_int8(initializers["conv_w"])
    conv_b, _ = quantize_int8(initializers["conv_b"])
    fc_w, _ = quantize_int8(initializers["fc_w"])
    fc_b, _ = quantize_int8(initializers["fc_b"])

    input_label = None
    if input_npz is not None:
        with np.load(input_npz) as input_data:
            input_i8 = np.asarray(input_data["input_int8"])
            if input_i8.shape != (1, 1, 8, 8) or input_i8.dtype != np.int8:
                raise ValueError("input_npz input_int8 must be int8 with shape (1,1,8,8)")
            input_scale = float(input_data["input_scale"].item())
            input_label = int(input_data["label"].item())
        input_fp = input_i8.astype(np.float32)
    else:
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

    fc_weights = fc_w.reshape(-1, 144)
    num_classes = int(fc_weights.shape[0])
    if num_classes not in (4, 10):
        raise ValueError("CNN output classes must be 4 or 10")
    padded_classes = ((num_classes + 3) // 4) * 4
    fc_bias = fc_b.reshape(-1)
    fc_acc = conv_relu_flat.astype(np.int64) @ fc_weights.astype(np.int64).T
    fc_rounded = rounded_requant(fc_acc, 8)
    fc_pre_bias_i8 = np.clip(fc_rounded, -128, 127).astype(np.int8)
    final_logits = np.clip(fc_pre_bias_i8.astype(np.int16) +
                           fc_bias.astype(np.int16), -128, 127).astype(np.int8)
    golden_bytes = final_logits.astype(np.int8).tobytes()
    fc_weights_padded = np.zeros((padded_classes, 144), dtype=np.int8)
    fc_weights_padded[:num_classes] = fc_weights
    fc_bias_padded = np.zeros(padded_classes, dtype=np.int8)
    fc_bias_padded[:num_classes] = fc_bias
    fc_rounded_padded = np.zeros(padded_classes, dtype=np.int64)
    fc_rounded_padded[:num_classes] = fc_rounded

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
    add_words(memory, addr["im2col"], im2col_words)

    # B stores one packed K-word per output column in each 16-byte line.
    conv_b_words = []
    for k0 in range(0, 9, 4):
        for channel in range(4):
            lanes = list(conv_weights[channel, k0:k0 + 4])
            lanes += [0] * (4 - len(lanes))
            conv_b_words.append(pack_i8(lanes))
    add_words(memory, addr["conv_weight"], conv_b_words)
    add_words(memory, addr["conv_round_bias"], [8] * 4)
    add_words(memory, addr["identity_b"], [
        pack_i8([1 if k == n else 0 for k in range(4)]) for n in range(4)
    ])
    add_words(memory, addr["conv_bias"], conv_b)
    add_words(memory, addr["fc_a"], [0] * (4 * 36))

    fc_b_group_bytes = 4 * 36 * 4
    for group in range(padded_classes // 4):
        fc_b_words = []
        for k0 in range(0, 144, 4):
            for n in range(4):
                fc_b_words.append(pack_i8(
                    fc_weights_padded[group * 4 + n, k0:k0 + 4]))
        add_words(memory, addr["fc_b"] + group * fc_b_group_bytes, fc_b_words)
        add_words(memory, addr["fc_bias"] + group * 16,
                  fc_bias_padded[group * 4:group * 4 + 4])
    add_words(memory, addr["fc_round_bias"], [128] * 4)
    for key, count in (("conv_raw", 144), ("conv_i8", 36),
                       ("conv_bias_relu", 144), ("conv_relu_i8", 36),
                       ("fc_raw", 16), ("fc_i8", 4),
                       ("fc_biased", 16), ("final_i8", padded_classes)):
        add_words(memory, addr[key], [0xA55AA55A] * count)

    image_words = [len(memory)]
    for address, value in sorted(memory.items()):
        image_words.extend([address, value])

    conv_round_flat = flatten_words(conv_rounded)
    conv_i8_words = [pack_i8(conv_pre_bias_i8.reshape(36, 4)[r]) for r in range(36)]
    conv_relu_flat_i32 = flatten_words(conv_bias_relu_i32.reshape(36, 4))
    conv_relu_words = [pack_i8(conv_relu.reshape(36, 4)[r]) for r in range(36)]
    expected_arrays = [conv_round_flat, conv_i8_words,
                       conv_relu_flat_i32, conv_relu_words]
    fc_group_expected = []
    for group in range(padded_classes // 4):
        lo = group * 4
        hi = lo + 4
        rounded_group = fc_rounded_padded[lo:hi]
        bias_group = fc_bias_padded[lo:hi].astype(np.int32)
        round_matrix = np.zeros((4, 4), dtype=np.int64)
        round_matrix[0] = rounded_group
        round_words = flatten_words(round_matrix)
        i8_words = [pack_i8(np.clip(round_matrix[row], -128, 127))
                    for row in range(4)]
        biased_matrix = np.tile(bias_group, (4, 1))
        biased_matrix[0] += np.clip(rounded_group, -128, 127).astype(np.int32)
        biased_words = flatten_words(biased_matrix)
        final_words = [pack_i8(np.clip(biased_matrix[row], -128, 127))
                       for row in range(4)]
        fc_group_expected.append([round_words, i8_words, biased_words, final_words])
        expected_arrays.extend(fc_group_expected[-1])
    expected_words = [sum(len(values) for values in expected_arrays)]
    for values in expected_arrays:
        expected_words.extend([len(values)])
        expected_words.extend(values)

    descriptor_count = 4 + 4 * (padded_classes // 4)
    allocated_high_water = max(
        max(memory) + 4,
        desc_base + descriptor_count * 64,
        cpl_base + descriptor_count * 16,
    )
    manifest = {
        "model": model_path.name,
        "model_kind": model_kind,
        "model_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "input_seed": 99 if input_npz is None else None,
        "input_label": input_label,
        "input_npz_sha256": hashlib.sha256(input_npz.read_bytes()).hexdigest() if input_npz is not None else None,
        "input_scale": input_scale,
        "spad_base_shift_bytes": spad_base_shift,
        "spad_capacity_bytes": spad_bytes,
        "spad_reserved_high_water": planner.next_addr,
        "spad_allocations": planner.regions,
        "spad_address_map": addr,
        "spad_descriptor_base": desc_base,
        "spad_completion_base": cpl_base,
        "spad_descriptor_count": descriptor_count,
        "spad_max_allocated_exclusive": allocated_high_water,
        "input_int8_sha256": hashlib.sha256(input_i8.tobytes()).hexdigest(),
        "conv_weight_scale": float(np.max(np.abs(initializers["conv_w"]))) / 127.0,
        "fc_weight_scale": float(np.max(np.abs(initializers["fc_w"]))) / 127.0,
        "conv_shape": "8x8x1 -> 6x6x4, im2col GEMM K=9",
        "num_classes": num_classes,
        "padded_classes": padded_classes,
        "fc_shape": "1x144 x 144x%d; output groups of four on padded M=4 matrix" % num_classes,
        "golden_int8": [int(value) for value in final_logits],
        "golden_class_count": num_classes,
        "golden_sha256": hashlib.sha256(golden_bytes).hexdigest(),
        "fc_output_group_count": padded_classes // 4,
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
    parser.add_argument("--input-npz", type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--spad-base-shift", type=lambda value: int(value, 0), default=0,
                        help="deprecated; nonzero shifts are rejected; use --spad-bytes")
    parser.add_argument("--spad-bytes", type=int, default=131072)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    image_words, expected_words, manifest, golden_bytes = build(
        args.model, args.input_npz, args.spad_base_shift, args.spad_bytes)
    (args.out_dir / "nma_cnn_layout.memh").write_text("".join(
        "%08x\n" % manifest["spad_address_map"][name] for name in REGION_BYTES))
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
