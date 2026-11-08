#!/usr/bin/env python3
"""Independently decode and verify the generated Matrix workload and Golden."""
import argparse
import hashlib
import json
from pathlib import Path

M, C = 512, 16
INPUT, W1, RAW1, ACT1, W2, RAW2, OUTPUT = (
    0x00000, 0x02000, 0x03000, 0x0B000, 0x0D000, 0x0E000, 0x16000
)
DESC, CPL, POISON = 0x19000, 0x19200, 0xA55AA55A


def load_pairs(path):
    words = [int(line, 16) for line in path.read_text().splitlines()]
    count = words[0]
    if len(words) != 1 + 2 * count:
        raise ValueError("bad pair-file count: " + str(path))
    pairs = list(zip(words[1::2], words[2::2]))
    result = dict(pairs)
    if len(result) != count:
        raise ValueError("duplicate address in pair-file: " + str(path))
    return result


def signed_byte(value):
    value &= 255
    return value - 256 if value & 128 else value


def decode_a(memory, base):
    result = [[0] * C for _ in range(M)]
    words_per_tile = 16 * (C // 4)
    for row in range(M):
        tile, in_tile = divmod(row, 16)
        row_group, row_lane = divmod(in_tile, 4)
        for k_group in range(C // 4):
            word_index = tile * words_per_tile + row_group * 16 + k_group * 4 + row_lane
            word = memory[base + 4 * word_index]
            for lane in range(4):
                result[row][k_group * 4 + lane] = signed_byte(word >> (8 * lane))
    return result


def decode_b(memory, base):
    result = [[0] * C for _ in range(C)]
    for col_group in range(C // 4):
        for k_group in range(C // 4):
            for col_lane in range(4):
                word_index = col_group * (C // 4) * 4 + k_group * 4 + col_lane
                word = memory[base + 4 * word_index]
                col = col_group * 4 + col_lane
                for lane in range(4):
                    result[k_group * 4 + lane][col] = signed_byte(word >> (8 * lane))
    return result


def gemm(a, b):
    return [[sum(int(a[row][k]) * int(b[k][col]) for k in range(C))
             for col in range(C)] for row in range(M)]


def requant_i8(value):
    """Independent opcode 0x36 contract: shift-zero signed saturation."""
    return min(127, max(-128, int(value)))


def pack_a(matrix):
    result = []
    for tile in range(0, M, 16):
        for group in range(tile, tile + 16, 4):
            for k_group in range(0, C, 4):
                for row in range(group, group + 4):
                    result.append(sum((matrix[row][k_group + lane] & 255) << (lane * 8)
                                      for lane in range(4)))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workload-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((args.workload_dir / "manifest.json").read_text())
    mode = manifest.get("fusion_mode", "legacy")
    memory = load_pairs(args.workload_dir / "model_memory.memh")
    golden = load_pairs(args.workload_dir / "model_golden.memh")
    command_specs = {
        "legacy": [
            (0x7100, 0x30, INPUT, W1, RAW1, M, C, C // 4, 0x00, 0, 1),
            (0x7101, 0x36, RAW1, 0, ACT1, M, C, M * C, 0x30, 1, 2),
            (0x7102, 0x30, ACT1, W2, RAW2, M, C, C // 4, 0x00, 2, 1),
            (0x7103, 0x36, RAW2, 0, OUTPUT, 0, 0, M * C, 0x10, 1, 0),
        ],
        "first": [
            (0x7100, 0x53, INPUT, W1, ACT1, M, C, C // 4, 0x00, 0, 1),
            (0x7101, 0x30, ACT1, W2, RAW2, M, C, C // 4, 0x00, 1, 2),
            (0x7102, 0x36, RAW2, 0, OUTPUT, 0, 0, M * C, 0x10, 2, 0),
        ],
        "both": [
            (0x7100, 0x53, INPUT, W1, ACT1, M, C, C // 4, 0x00, 0, 1),
            (0x7101, 0x53, ACT1, W2, OUTPUT, M, C, C // 4, 0x00, 1, 0),
        ],
        "both_convert": [
            (0x7100, 0x53, INPUT, W1, ACT1, M, C, C // 4, 0x00, 0, 1),
            (0x7101, 0x53, ACT1, W2, RAW1, M, C, C // 4, 0x00, 1, 2),
            (0x7102, 0x30, RAW1, 0x0D100, RAW2, M, C, C // 4, 0x00, 2, 1),
            (0x7103, 0x36, RAW2, 0, OUTPUT, 0, 0, M * C, 0x10, 1, 0),
        ],
    }
    if mode not in command_specs:
        raise ValueError("unknown fusion mode: " + str(mode))
    specs = command_specs[mode]
    commands = [[memory[DESC + i * 64 + j * 4] for j in range(16)]
                for i in range(len(specs))]
    for index, (cmd, spec) in enumerate(zip(commands, specs)):
        task, op, src0, src1, dst, m, n, extent, flags, wait, signal = spec
        actual = (cmd[0] >> 16, cmd[0] & 0xFF, cmd[1], cmd[2], cmd[4],
                  cmd[5] & 0xFFFF, cmd[5] >> 16, cmd[6], cmd[7],
                  cmd[14] & 0xFFFF, cmd[14] >> 16)
        if actual != spec:
            raise ValueError("descriptor contract mismatch at index %d: %r" % (index, actual))
        if cmd[9] != 0:
            raise ValueError("descriptor activation mismatch at index %d" % index)
        if cmd[13] != 0x00010001 or cmd[15] != ((wait << 16) | 7):
            raise ValueError("descriptor ABI/event clear mismatch at index %d" % index)
    if max(memory) + 4 > 128 * 1024:
        raise ValueError("workload image exceeds the 128 KiB candidate")
    if len(golden) != M * C * 2 + (M * C // 4) * 2:
        raise ValueError("unexpected golden tensor word count")
    for base, words in ((RAW1, M * C), (ACT1, M * C // 4),
                        (RAW2, M * C), (OUTPUT, M * C // 4)):
        for index in range(words):
            if memory[base + index * 4] != POISON:
                raise ValueError("output pre-poison missing at 0x%08x" % (base + index * 4))
    if mode == "both_convert":
        identity = decode_b(memory, 0x0D100)
        expected_identity = [[int(row == col) for col in range(C)]
                             for row in range(C)]
        if identity != expected_identity:
            raise ValueError("layout-conversion identity weights are not exact")

    x, w1 = decode_a(memory, INPUT), decode_b(memory, W1)
    raw1 = gemm(x, w1)
    act1 = [[requant_i8(value) for value in row] for row in raw1]
    raw2 = gemm(act1, decode_b(memory, W2))
    output = [[requant_i8(value) for value in row] for row in raw2]
    packed_act1 = pack_a(act1)
    if mode == "both":
        packed_output = pack_a(output)
    else:
        packed_output = [sum((output[row][col + lane] & 255) << (lane * 8)
                             for lane in range(4))
                         for row in range(M) for col in range(0, C, 4)]
    recomputed = {}
    if mode == "legacy":
        raw1_physical = [value & 0xFFFFFFFF for row in raw1 for value in row]
    elif mode == "both_convert":
        tile_words = pack_a(output)
        raw1_physical = tile_words + [POISON] * (M * C - len(tile_words))
    else:
        raw1_physical = [POISON] * (M * C)
    for index, value in enumerate(raw1_physical):
        recomputed[RAW1 + 4 * index] = value
    for index, value in enumerate(packed_act1):
        recomputed[ACT1 + 4 * index] = value
    for index, row in enumerate(raw2):
        for col, value in enumerate(row):
            if mode == "both":
                physical_value = POISON
            elif mode == "both_convert":
                physical_value = output[index][col] & 0xFFFFFFFF
            else:
                physical_value = value & 0xFFFFFFFF
            recomputed[RAW2 + 4 * (index * C + col)] = physical_value
    for index, value in enumerate(packed_output):
        recomputed[OUTPUT + 4 * index] = value
    if recomputed != golden:
        differing = next(address for address in recomputed
                         if golden.get(address) != recomputed[address])
        raise ValueError("independent Golden mismatch at 0x%08x" % differing)
    raw1_digest = hashlib.sha256(
        b"".join((int(value) & 0xFFFFFFFF).to_bytes(4, "little")
                 for row in raw1 for value in row)).hexdigest()
    raw2_digest = hashlib.sha256(
        b"".join((int(value) & 0xFFFFFFFF).to_bytes(4, "little")
                 for row in raw2 for value in row)).hexdigest()
    if manifest.get("raw1_int32_golden_sha256") != raw1_digest or \
            manifest.get("raw2_int32_golden_sha256") != raw2_digest:
        raise ValueError("independent INT32 logical Golden hash mismatch")
    print("REPRESENTATIVE_CNN_OFFLINE_GOLDEN_PASS mode=%s descriptors=%d tensors=4 useful_macs=%d checked_words=%d output_layout=%s" %
          (mode, len(specs), 2 * M * C * C, len(golden),
           manifest.get("output_physical_layout")))


if __name__ == "__main__":
    main()
