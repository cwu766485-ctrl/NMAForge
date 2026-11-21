#!/usr/bin/env python3
"""Create a 197x192, three-head Product-Top 0x3b layout qualification image.

This is a repack-only boundary test. The Matrix-A source is preloaded, so it
does not claim a QKV producer or an Attention/model execution path.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


SPAD_BYTES = 256 * 1024
M_SIZE = 208
N_SIZE = 192
VALID_ROWS = 197
HEADS = 3
HEAD_DIM = N_SIZE // HEADS
SRC_BASE = 0x02000
DST_BASE = 0x29000
DESC_BASE = 0x3B000
CPL_BASE = 0x3B100
QUEUE_SIZE = 16
POISON = 0xA55AA55A
MODES = {"q_dense": 0, "k_major": 1, "v_matrix_b": 2}


def value(row: int, col: int) -> int:
    """Asymmetric signed INT8 source data; distinct row/column signatures."""
    return ((row * 37 + col * 19 + row * col * 3) % 251) - 125


def pack_lanes(values: list[int]) -> int:
    assert len(values) == 4
    return sum((x & 0xFF) << (8 * lane) for lane, x in enumerate(values))


def matrix_a_word(row: int, col: int) -> int:
    tile = (row // 16) * (N_SIZE // 16) + col // 16
    local_row = row & 15
    local_col = col & 15
    word_index = (local_row // 4) * 16 + (local_col // 4) * 4 + (local_row & 3)
    return SRC_BASE + tile * 1024 + word_index * 4


def write_memh(path: Path, words: dict[int, int]) -> None:
    rows = sorted(words.items())
    with path.open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"{len(rows):08x}\n")
        for address, data in rows:
            stream.write(f"{address:08x}\n{data & 0xFFFFFFFF:08x}\n")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def descriptor(task: int, head: int, mode: int, dst: int) -> list[int]:
    words = [0] * 16
    # Match the representative top-smoke completion contract: task IDs are
    # 0x7100 + descriptor index and are echoed in CPLQ word 0.
    words[0] = ((0x7100 + task) << 16) | 0x3B
    words[1] = SRC_BASE
    words[4] = dst
    words[5] = (N_SIZE << 16) | M_SIZE
    words[6] = VALID_ROWS
    words[8] = (head << 2) | mode
    words[12] = M_SIZE
    words[15] = 7
    return words


def generate(layout: str, out_dir: Path) -> dict[str, object]:
    mode = MODES[layout]
    head_dim = HEAD_DIM
    src_bytes = M_SIZE * N_SIZE * 4
    src_end = SRC_BASE + src_bytes
    dst_bytes = 4 * 4096 if mode == 2 else M_SIZE * head_dim
    assert src_end == DST_BASE

    # Allocate the complete padded physical source span as poison, then place
    # the producer-compatible sparse Matrix-A words for the 197 valid rows.
    image: dict[int, int] = {
        address: POISON for address in range(SRC_BASE, src_end, 4)
    }
    source_words: dict[int, int] = {}
    for row in range(VALID_ROWS):
        for col_base in range(0, N_SIZE, 4):
            address = matrix_a_word(row, col_base)
            word = pack_lanes([value(row, col_base + lane) for lane in range(4)])
            if address in source_words:
                raise ValueError(f"Matrix-A packing collision at {address:#x}")
            source_words[address] = word
            image[address] = word

    golden: dict[int, int] = {}
    output_allocations: list[dict[str, int | str]] = []
    for head in range(HEADS):
        dst = DST_BASE + head * 0x4000
        end = dst + dst_bytes
        if end > SPAD_BYTES:
            raise ValueError("output allocation exceeds 256 KiB SPAD")
        output_allocations.append({"head": head, "base": dst, "end_exclusive": end,
                                   "bytes": dst_bytes, "layout": layout})
        # Include untouched V panel holes in the golden as poison sentinels.
        for address in range(dst, end, 4):
            image[address] = POISON
            golden[address] = POISON

        def logical(row: int, feature: int) -> int:
            return value(row, head * head_dim + feature) if row < VALID_ROWS else 0

        # Independent physical-source reader: construct expected output from
        # words actually generated at Matrix-A addresses, then compare against
        # the logical INT8 tensor before writing the golden image.
        if mode == 0:  # Q dense row-major
            for row in range(M_SIZE):
                for feature_base in range(0, head_dim, 4):
                    address = matrix_a_word(row, head * head_dim + feature_base)
                    actual_word = source_words.get(address, 0) if row < VALID_ROWS else 0
                    expected_word = pack_lanes([
                        logical(row, feature_base + lane) for lane in range(4)
                    ])
                    if actual_word != expected_word:
                        raise ValueError(f"Q physical read mismatch row={row} feature={feature_base}")
                    golden[dst + row * head_dim + feature_base] = actual_word
        else:  # K-major or V Matrix-B panel; transpose each 4x4 source group.
            for row_base in range(0, M_SIZE, 4):
                for feature_base in range(0, head_dim, 4):
                    physical_words = []
                    for lane in range(4):
                        row = row_base + lane
                        if row < VALID_ROWS:
                            addr = matrix_a_word(row, head * head_dim + feature_base)
                            physical_words.append(source_words[addr])
                        else:
                            physical_words.append(0)
                    for feature_lane in range(4):
                        feature = feature_base + feature_lane
                        transposed = pack_lanes([
                            (word >> (feature_lane * 8)) & 0xFF
                            for word in physical_words
                        ])
                        expected = pack_lanes([
                            logical(row_base + lane, feature) for lane in range(4)
                        ])
                        if transposed != expected:
                            raise ValueError(
                                f"transpose physical read mismatch row={row_base} feature={feature}"
                            )
                        if mode == 1:
                            address = (dst + (row_base >> 4) * (head_dim << 4)
                                       + (feature << 4) + (row_base & 15))
                        else:
                            col_in_panel = feature & 15
                            col_group = col_in_panel & 12
                            word_index = ((col_group // 4) * (M_SIZE // 4) * 4
                                          + (row_base // 4) * 4
                                          + (col_in_panel & 3))
                            address = dst + (feature >> 4) * 4096 + word_index * 4
                        if address in golden and golden[address] != POISON:
                            raise ValueError(f"output address collision at {address:#x}")
                        golden[address] = transposed

    descriptors: dict[int, int] = {}
    for task, head in enumerate(range(HEADS)):
        words = descriptor(task, head, mode, DST_BASE + head * 0x4000)
        for wi, word in enumerate(words):
            descriptors[DESC_BASE + task * 64 + wi * 4] = word
    # Keep the completion slots explicit and non-overlapping with the tensor
    # allocations; hardware will replace them during retirement.
    for slot in range(HEADS * 4):
        descriptors[CPL_BASE + slot * 4] = POISON
    for address, word in descriptors.items():
        if address in image and SRC_BASE <= address < src_end:
            raise ValueError("descriptor overlaps the source SPAD allocation")
        image[address] = word

    # Check all planned half-open ranges pairwise.
    allocations = [(SRC_BASE, src_end, "source")]
    allocations += [(int(x["base"]), int(x["end_exclusive"]), f"head{x['head']}")
                    for x in output_allocations]
    allocations += [(DESC_BASE, DESC_BASE + HEADS * 64, "cmdq")]
    allocations += [(CPL_BASE, CPL_BASE + HEADS * 16, "cplq")]
    for i, (a0, a1, an) in enumerate(allocations):
        for b0, b1, bn in allocations[i + 1:]:
            if a0 < b1 and b0 < a1:
                raise ValueError(f"SPAD allocation overlap: {an} vs {bn}")

    out_dir.mkdir(parents=True, exist_ok=True)
    mem_path = out_dir / "model_memory.memh"
    gold_path = out_dir / "model_golden.memh"
    write_memh(mem_path, image)
    write_memh(gold_path, golden)
    manifest: dict[str, object] = {
        "run_kind": "round30_full_shape_0x3b_product_top_repack_only",
        "status": "GENERATED_SOFTWARE_ORACLE_ONLY_AWAITING_VCS",
        "opcode": "0x3b",
        "layout": layout,
        "mode": mode,
        "spad_bytes": SPAD_BYTES,
        "m_size_padded": M_SIZE,
        "valid_rows": VALID_ROWS,
        "n_size_total": N_SIZE,
        "heads": HEADS,
        "head_dim": HEAD_DIM,
        "source_base": SRC_BASE,
        "source_physical_span_bytes": src_bytes,
        "source_end_exclusive": src_end,
        "destination_allocations": output_allocations,
        "descriptor_base": DESC_BASE,
        "completion_base": CPL_BASE,
        "descriptor_count": HEADS,
        "queue_size": QUEUE_SIZE,
        "allocation_map": allocations,
        "image_word_count": len(image),
        "golden_word_count": len(golden),
        "matrix_a_source_words": len(source_words),
        "physical_padding_source_is_poison": True,
        "output_padding_rows_zero": True,
        "v_panel_holes_remain_poison": mode == 2,
        "host_role": "load fixture and publish descriptors only; no intermediate model tensor repacking",
        "scope_limit": "does_not_test_QKV_producer_or_attention_consumer_integration",
        "model_input_formula": "signed_int8((row*37 + col*19 + row*col*3) % 251 - 125)",
        "golden_method": "independent logical tensor plus physical Matrix-A address/byte-lane decode cross-check",
        "files": {"model_memory.memh_sha256": sha256(mem_path),
                  "model_golden.memh_sha256": sha256(gold_path)},
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--layout", choices=sorted(MODES), required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = generate(args.layout, args.out_dir)
    print(json.dumps(manifest, sort_keys=True))


if __name__ == "__main__":
    main()
