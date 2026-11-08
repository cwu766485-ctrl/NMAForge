#!/usr/bin/env python3
"""Generate a reproducible two-layer INT8 pointwise-CNN Top workload.

Uses only the Python standard library so workload generation is independent of
NumPy availability. The weights are fixed-seed inference weights, not trained.
"""
import argparse
import hashlib
import json
import random
import time
from pathlib import Path

M = 512
C = 16
SPAD = {
    "input": 0x00000,
    "w1": 0x02000,
    "raw1": 0x03000,
    "act1": 0x0B000,
    "w2": 0x0D000,
    "raw2": 0x0E000,
    "output": 0x16000,
    "desc": 0x19000,
    "cpl": 0x19200,
}
POISON = 0xA55AA55A


def pack(values):
    values = [int(value) for value in values]
    if len(values) != 4:
        raise ValueError("INT8 word requires four lanes")
    return sum((value & 0xFF) << (8 * lane) for lane, value in enumerate(values))


def add(memory, base, values):
    for index, value in enumerate(values):
        address = base + 4 * index
        if address in memory:
            raise ValueError("SPAD image overlap at 0x%08x" % address)
        memory[address] = int(value) & 0xFFFFFFFF


def pack_a(matrix):
    m, k = len(matrix), len(matrix[0])
    if m % 16 or k % 4:
        raise ValueError("A requires M%16=0 and K%4=0")
    return [
        pack(matrix[row][k0:k0 + 4])
        for tile in range(0, m, 16)
        for group in range(tile, tile + 16, 4)
        for k0 in range(0, k, 4)
        for row in range(group, group + 4)
    ]


def pack_b(matrix):
    k, n = len(matrix), len(matrix[0])
    if k % 4 or n % 16:
        raise ValueError("B requires K%4=0 and N%16=0")
    return [
        pack([matrix[k0 + lane][col] for lane in range(4)])
        for col_group in range(0, n, 4)
        for k0 in range(0, k, 4)
        for col in range(col_group, col_group + 4)
    ]


def desc(task, op, a, b, out, m, n, k, flags=0, activation=0):
    words = [0] * 16
    words[0] = (task << 16) | op
    words[1], words[2], words[4] = a, b, out
    words[5], words[6], words[7] = (n << 16) | m, k, flags
    words[9] = activation << 5
    words[13] = 0x00010001
    words[15] = 7
    return words


def scalar_golden(a, b):
    rows, inner, cols = len(a), len(b), len(b[0])
    result = [[0] * cols for _ in range(rows)]
    for row in range(rows):
        for col in range(cols):
            accumulator = sum(a[row][index] * b[index][col] for index in range(inner))
            if not -(1 << 31) <= accumulator < (1 << 31):
                raise OverflowError("INT32 accumulation overflow")
            result[row][col] = accumulator
    return result


def requant_i8(value):
    """Opcode 0x36 with shift zero: signed INT8 saturation, no activation."""
    return min(127, max(-128, int(value)))


def int8_bytes(values):
    return bytes(int(value) & 0xFF for value in values)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261108)
    parser.add_argument("--fusion-mode", choices=("legacy", "first", "both"),
                        default="legacy",
                        help="legacy 0x30/0x36, first-layer 0x53, or both layers 0x53")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    started = time.perf_counter()
    rng = random.Random(args.seed)
    x = [[rng.randint(-8, 8) for _ in range(C)] for _ in range(M)]
    w1 = [[rng.randint(-3, 3) for _ in range(C)] for _ in range(C)]
    w2 = [[rng.randint(-3, 3) for _ in range(C)] for _ in range(C)]

    raw1 = scalar_golden(x, w1)
    act1 = [[requant_i8(value) for value in row] for row in raw1]
    raw2 = scalar_golden(act1, w2)
    output = [[requant_i8(value) for value in row] for row in raw2]

    memory = {}
    add(memory, SPAD["input"], pack_a(x))
    add(memory, SPAD["w1"], pack_b(w1))
    add(memory, SPAD["raw1"], [POISON] * (M * C))
    add(memory, SPAD["act1"], [POISON] * (M * C // 4))
    add(memory, SPAD["w2"], pack_b(w2))
    add(memory, SPAD["raw2"], [POISON] * (M * C))
    add(memory, SPAD["output"], [POISON] * (M * C // 4))

    # Tensor GEMM word6 counts packed K groups (four INT8 elements each),
    # unlike requant's scalar length field. Opcode 0x53 writes signed INT8
    # directly in Matrix-A tile layout, which the following GEMM consumes.
    commands_by_mode = {
        "legacy": [
            desc(0x7100, 0x30, SPAD["input"], SPAD["w1"], SPAD["raw1"], M, C, C // 4),
            desc(0x7101, 0x36, SPAD["raw1"], 0, SPAD["act1"], M, C, M * C, 0x30),
            desc(0x7102, 0x30, SPAD["act1"], SPAD["w2"], SPAD["raw2"], M, C, C // 4),
            desc(0x7103, 0x36, SPAD["raw2"], 0, SPAD["output"], 0, 0, M * C, 0x10),
        ],
        "first": [
            desc(0x7100, 0x53, SPAD["input"], SPAD["w1"], SPAD["act1"], M, C, C // 4),
            desc(0x7101, 0x30, SPAD["act1"], SPAD["w2"], SPAD["raw2"], M, C, C // 4),
            desc(0x7102, 0x36, SPAD["raw2"], 0, SPAD["output"], 0, 0, M * C, 0x10),
        ],
        "both": [
            desc(0x7100, 0x53, SPAD["input"], SPAD["w1"], SPAD["act1"], M, C, C // 4),
            desc(0x7101, 0x53, SPAD["act1"], SPAD["w2"], SPAD["output"], M, C, C // 4),
        ],
    }
    commands = commands_by_mode[args.fusion_mode]
    for index, words in enumerate(commands):
        wait = (1 << ((index - 1) & 1)) if index else 0
        signal = (1 << (index & 1)) if index < len(commands) - 1 else 0
        words[14] = (signal << 16) | wait
        words[15] = (wait << 16) | 7
        add(memory, SPAD["desc"] + index * 64, words)
        add(memory, SPAD["cpl"] + index * 16, [POISON] * 4)

    expected = []
    def expect(base, values):
        expected.extend((base + 4 * i, int(value) & 0xFFFFFFFF)
                        for i, value in enumerate(values))

    # Fused GEMM preserves its logical INT32 result for the independent
    # software Golden, but must leave the legacy raw tensor physically intact.
    if args.fusion_mode == "legacy":
        expect(SPAD["raw1"], [value for row in raw1 for value in row])
    else:
        expect(SPAD["raw1"], [POISON] * (M * C))
    expect(SPAD["act1"], pack_a(act1))
    if args.fusion_mode == "both":
        expect(SPAD["raw2"], [POISON] * (M * C))
        packed_output = pack_a(output)
    else:
        expect(SPAD["raw2"], [value for row in raw2 for value in row])
        packed_output = [pack([output[row][col] for col in range(i, i + 4)])
                         for row in range(M) for i in range(0, C, 4)]
    expect(SPAD["output"], packed_output)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    image = [len(memory)]
    for address, value in sorted(memory.items()):
        image.extend((address, value))
    golden = [len(expected)]
    for address, value in expected:
        golden.extend((address, value))

    def write_memh(path, words):
        path.write_text("".join("%08x\n" % (int(word) & 0xFFFFFFFF) for word in words),
                        encoding="ascii")

    image_path = args.out_dir / "model_memory.memh"
    golden_path = args.out_dir / "model_golden.memh"
    write_memh(image_path, image)
    write_memh(golden_path, golden)
    manifest = {
        "model": "nma_pointwise_cnn_32x16_16ch_2layer_linear_int8",
        "seed": args.seed,
        "fusion_mode": args.fusion_mode,
        "weight_provenance": "fixed-seed reproducible INT8 inference weights; not trained",
        "quantization": "signed INT8 activations/weights, INT32 accumulation, opcode 0x36 shift-0 signed saturation; no activation",
        "layers": ["Conv2D 1x1 16->16 + signed INT8 requant", "Conv2D 1x1 16->16 + signed INT8 requant"],
        "input_shape_nchw": [1, C, 32, 16],
        "spatial_positions": M,
        "useful_macs_per_inference": 2 * M * C * C,
        "descriptor_count": len(commands),
        "preload_spad_words": len(memory),
        "preload_spad_bytes": len(memory) * 4,
        "checked_golden_words": len(expected),
        "descriptor_base": SPAD["desc"],
        "completion_base": SPAD["cpl"],
        "spad_capacity_bytes": 128 * 1024,
        "spad_high_water_exclusive": max(memory) + 4,
        "input_sha256": hashlib.sha256(int8_bytes(value for row in x for value in row)).hexdigest(),
        "weight1_sha256": hashlib.sha256(int8_bytes(value for row in w1 for value in row)).hexdigest(),
        "weight2_sha256": hashlib.sha256(int8_bytes(value for row in w2 for value in row)).hexdigest(),
        "output_sha256": hashlib.sha256(int8_bytes(value for row in output for value in row)).hexdigest(),
        "raw1_int32_golden_sha256": hashlib.sha256(
            b"".join((int(value) & 0xFFFFFFFF).to_bytes(4, "little")
                     for row in raw1 for value in row)).hexdigest(),
        "raw2_int32_golden_sha256": hashlib.sha256(
            b"".join((int(value) & 0xFFFFFFFF).to_bytes(4, "little")
                     for row in raw2 for value in row)).hexdigest(),
        "output_physical_layout": "matrix_a_tile" if args.fusion_mode == "both" else "row_major_packed_i8",
        "legacy_output_layout_compatible": args.fusion_mode != "both",
        "independent_golden": "scalar Python integer accumulation; raw INT32 and packed INT8 tensor checks",
        "host_fallback_compute": "none; both convolution layers use ABI-v7 Matrix GEMM on Top RTL",
        "host_im2col": "none; 1x1 pointwise convolution maps directly to Matrix GEMM",
        "host_layout": "initial input/weight packing and descriptor creation; generation time is reported",
        "host_generation_seconds": time.perf_counter() - started,
        "memory_image_sha256": hashlib.sha256(image_path.read_bytes()).hexdigest(),
        "golden_file_sha256": hashlib.sha256(golden_path.read_bytes()).hexdigest(),
    }
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n",
                                                 encoding="utf-8")
    print("REPRESENTATIVE_CNN_WORKLOAD_PASS useful_macs=%d descriptors=%d spad_high_water=0x%x image_sha256=%s golden_sha256=%s" % (
        manifest["useful_macs_per_inference"], manifest["descriptor_count"],
        manifest["spad_high_water_exclusive"], manifest["memory_image_sha256"],
        manifest["golden_file_sha256"]))


if __name__ == "__main__":
    main()
