#!/usr/bin/env python3
"""Independently decode and verify the generated Matrix workload and Golden."""
import argparse
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
    memory = load_pairs(args.workload_dir / "model_memory.memh")
    golden = load_pairs(args.workload_dir / "model_golden.memh")
    commands = [[memory[DESC + i * 64 + j * 4] for j in range(16)] for i in range(4)]
    expected = [
        (0x7100, 0x30, INPUT, W1, RAW1, M, C, C, 0x00, 0, 1),
        (0x7101, 0x36, RAW1, 0, ACT1, M, C, M * C, 0x30, 1, 2),
        (0x7102, 0x30, ACT1, W2, RAW2, M, C, C, 0x00, 2, 1),
        (0x7103, 0x36, RAW2, 0, OUTPUT, 0, 0, M * C, 0x10, 1, 0),
    ]
    for index, (cmd, spec) in enumerate(zip(commands, expected)):
        task, op, src0, src1, dst, m, n, extent, flags, wait, signal = spec
        actual = (cmd[0] >> 16, cmd[0] & 0xFF, cmd[1], cmd[2], cmd[4],
                  cmd[5] & 0xFFFF, cmd[5] >> 16, cmd[6], cmd[7],
                  cmd[14] & 0xFFFF, cmd[14] >> 16)
        if actual != spec:
            raise ValueError("descriptor contract mismatch at index %d: %r" % (index, actual))
        if cmd[9] != (1 << 5 if op == 0x36 and index in (1, 3) else 0):
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

    x, w1 = decode_a(memory, INPUT), decode_b(memory, W1)
    raw1 = gemm(x, w1)
    act1 = [[min(127, max(0, value)) for value in row] for row in raw1]
    raw2 = gemm(act1, decode_b(memory, W2))
    output = [[min(127, max(0, value)) for value in row] for row in raw2]
    packed_act1 = pack_a(act1)
    packed_output = [sum((output[row][col + lane] & 255) << (lane * 8)
                         for lane in range(4))
                     for row in range(M) for col in range(0, C, 4)]
    recomputed = {}
    for index, row in enumerate(raw1):
        for col, value in enumerate(row):
            recomputed[RAW1 + 4 * (index * C + col)] = value & 0xFFFFFFFF
    for index, value in enumerate(packed_act1):
        recomputed[ACT1 + 4 * index] = value
    for index, row in enumerate(raw2):
        for col, value in enumerate(row):
            recomputed[RAW2 + 4 * (index * C + col)] = value & 0xFFFFFFFF
    for index, value in enumerate(packed_output):
        recomputed[OUTPUT + 4 * index] = value
    if recomputed != golden:
        differing = next(address for address in recomputed
                         if golden.get(address) != recomputed[address])
        raise ValueError("independent Golden mismatch at 0x%08x" % differing)
    print("REPRESENTATIVE_CNN_OFFLINE_GOLDEN_PASS descriptors=4 tensors=4 useful_macs=%d checked_words=%d" %
          (2 * M * C * C, len(golden)))


if __name__ == "__main__":
    main()
