#!/usr/bin/env python3
"""Generate a compact Product-Top CMDQ workload for research opcode 0x3b."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


SPAD_BYTES = 256 * 1024
M_SIZE = 16
N_SIZE = 48
HEAD_DIM = N_SIZE // 3
VALID_ROWS = 13
SRC_BASE = 0x1000
DST_BASE = 0x5000
DESC_BASE = 0x10000
CPL_BASE = 0x10400
QUEUE_SIZE = 16
MODES = {"q_dense": 0, "k_major": 1, "v_matrix_b": 2}


def tensor_value(row: int, col: int) -> int:
    return ((row * 11 + col * 7) % 101) - 50


def matrix_a_word(row: int, col: int) -> int:
    tile = (row // 16) * (N_SIZE // 16) + col // 16
    local_row = row & 15
    local_col = col & 15
    index = (local_row // 4) * 16 + (local_col // 4) * 4 + (local_row & 3)
    return SRC_BASE + tile * 1024 + index * 4


def pack_lanes(values: list[int]) -> int:
    return sum((value & 0xFF) << (8 * lane) for lane, value in enumerate(values))


def make_descriptor(task_id: int, src: int, dst: int, mode: int, head: int) -> list[int]:
    words = [0] * 16
    words[0] = ((0x7100 + task_id) << 16) | 0x3B
    words[1] = src
    words[4] = dst
    words[5] = (N_SIZE << 16) | M_SIZE
    words[6] = VALID_ROWS
    words[8] = (head << 2) | mode
    words[12] = M_SIZE
    words[15] = 7
    return words


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    image: dict[int, int] = {}
    golden: dict[int, int] = {}
    for row in range(VALID_ROWS):
        for col_base in range(0, N_SIZE, 4):
            word = pack_lanes([tensor_value(row, col_base + lane) for lane in range(4)])
            image[matrix_a_word(row, col_base)] = word

    descriptors: list[list[int]] = []
    output_ranges: list[dict[str, int | str]] = []
    task_id = 0
    for layout, mode in MODES.items():
        for head in range(3):
            # The V Matrix-B representation reserves one 4 KiB panel per
            # descriptor at M=16. Keep all destination modes on the same
            # non-overlapping 4 KiB grid so later mode outputs cannot alias it.
            dst = DST_BASE + task_id * 0x1000
            descriptors.append(make_descriptor(task_id, SRC_BASE, dst, mode, head))
            output_ranges.append({"layout": layout, "head": head, "base": dst})
            for row_base in range(0, M_SIZE, 4):
                for feature_base in range(0, HEAD_DIM, 4):
                    if mode == 0:
                        for row in range(row_base, row_base + 4):
                            values = [
                                tensor_value(row, head * HEAD_DIM + feature_base + lane)
                                if row < VALID_ROWS else 0
                                for lane in range(4)
                            ]
                            addr = dst + row * HEAD_DIM + feature_base
                            golden[addr] = pack_lanes(values)
                    elif mode == 1:
                        for feature in range(feature_base, feature_base + 4):
                            values = [
                                tensor_value(row, head * HEAD_DIM + feature)
                                if row < VALID_ROWS else 0
                                for row in range(row_base, row_base + 4)
                            ]
                            addr = dst + feature * M_SIZE + row_base
                            golden[addr] = pack_lanes(values)
                    else:
                        for feature in range(feature_base, feature_base + 4):
                            col_group = feature & 0xC
                            word_index = (
                                (col_group // 4) * (M_SIZE // 4) * 4
                                + (row_base // 4) * 4
                                + (feature & 3)
                            )
                            values = [
                                tensor_value(row, head * HEAD_DIM + feature)
                                if row < VALID_ROWS else 0
                                for row in range(row_base, row_base + 4)
                            ]
                            golden[dst + word_index * 4] = pack_lanes(values)
            task_id += 1

    descriptor_image: dict[int, int] = {}
    for descriptor_index, words in enumerate(descriptors):
        base = DESC_BASE + descriptor_index * 64
        for word_index, value in enumerate(words):
            descriptor_image[base + word_index * 4] = value
    image.update(descriptor_image)
    for address in golden:
        image[address] = 0xA55AA55A

    image_items = sorted(image.items())
    with (out_dir / "model_memory.memh").open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"{len(image_items):08x}\n")
        for address, value in image_items:
            stream.write(f"{address:08x}\n{value & 0xFFFFFFFF:08x}\n")
    golden_items = sorted(golden.items())
    with (out_dir / "model_golden.memh").open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"{len(golden_items):08x}\n")
        for address, value in golden_items:
            stream.write(f"{address:08x}\n{value & 0xFFFFFFFF:08x}\n")

    manifest = {
        "run_kind": "product_top_single_session_repack_only",
        "opcode": "0x3b",
        "spad_bytes": SPAD_BYTES,
        "m_size": M_SIZE,
        "n_size": N_SIZE,
        "valid_rows": VALID_ROWS,
        "head_dim": HEAD_DIM,
        "source_matrix_a_base": SRC_BASE,
        "destination_ranges": output_ranges,
        "descriptor_base": DESC_BASE,
        "completion_base": CPL_BASE,
        "descriptor_count": len(descriptors),
        "queue_size": QUEUE_SIZE,
        "golden_word_count": len(golden_items),
        "host_role": "preload source fixture and publish descriptors; no intermediate tensor repack on host",
        "model_path_status": "NOT_A_QKV_PRODUCER_OR_ATTENTION_MODEL_RUN",
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, sort_keys=True))


if __name__ == "__main__":
    main()
