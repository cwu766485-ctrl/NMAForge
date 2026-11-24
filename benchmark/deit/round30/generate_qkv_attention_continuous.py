#!/usr/bin/env python3
"""Build a bounded three-head QKV->0x3b->QK/Softmax/AV Top runtime.

The initial Product workload computes Q/K/V with the existing 468-descriptor
Top path. This generator reads only that workload's *independent expected*
QKV output image to construct expected repack/attention words and descriptors.
It never places intermediate Q/K/V, score, probability, or AV activations in
the Product input image. The testbench must consume the live QKV SPAD outputs.
"""

from __future__ import annotations

import argparse
import dataclasses
import hashlib
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))

from cimforge_mapper import Descriptor, OP_GEMV_KFOLD, OP_SOFTMAX, OP_REQUANT  # noqa: E402

QKV_COUNT = 468
HEADS = 3
VALID_ROWS = 197
PHYSICAL_ROWS = 208
CHANNELS = 192
HEAD_DIM = 64
QUEUE_SIZE = 512
DESC_BASE = 0x36000
CPL_BASE = 0x3E000

# All temporary data is below the immutable QKV Product outputs at 0x16000.
# AV outputs remain live for all three heads; Q/K/V, score/probability and
# packed-A scratch are reused one head at a time. Softmax's zero-padding source
# lives in a separate read-only gap above the QKV outputs.
AV_BASE = 0x0000
Q_DENSE = 0x3000
K_MAJOR = 0x6400
V_MATRIX_B = 0x9800
SCORE_I32 = 0xD800
PROB_I32 = 0x10C00
PROB_PACKED_A = SCORE_I32
LOW_SCRATCH_LIMIT = 0x16000
ZERO_SOURCE = 0x33C00  # Reserved gap before the 512-entry descriptor ring.

SOURCE_BASES = {"query": 0x16000, "key": 0x20000, "value": 0x2A000}
REPACK_DESTS = {0: Q_DENSE, 1: K_MAJOR, 2: V_MATRIX_B}
REPACK_MODES = {"q_dense": 0, "k_major": 1, "v_matrix_b": 2}


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read_pairs(path: Path) -> dict[int, int]:
    fields = [line.strip() for line in path.read_text(encoding="ascii").splitlines()
              if line.strip()]
    count = int(fields[0], 16)
    if len(fields) != 1 + count * 2:
        raise ValueError("bad pair file %s: count=%d fields=%d" %
                         (path, count, len(fields)))
    return {int(fields[1 + 2 * i], 16): int(fields[2 + 2 * i], 16)
            for i in range(count)}


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    with path.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("%08x\n" % len(pairs))
        for address, value in sorted(pairs.items()):
            stream.write("%08x\n%08x\n" % (address & 0xFFFFFFFF,
                                             value & 0xFFFFFFFF))


def write_values(path: Path, values: list[int]) -> None:
    with path.open("w", encoding="ascii", newline="\n") as stream:
        for value in values:
            stream.write("%08x\n" % (value & 0xFFFFFFFF))


def write_checkpoint(path: Path, expected: dict[int, int]) -> None:
    words = [len(expected)]
    for address, value in sorted(expected.items()):
        words.extend((address, value))
    write_values(path, words)


def write_descriptor_checkpoints(path: Path, golden: dict[int, int]) -> list[dict]:
    """Check the real Q/K/V projection outputs when their final descriptor retires.

    Each projection spans 9,984 words, so records are split to respect the
    testbench's 8,192-word per-record bound. These are read-only observations
    of Product SPAD after the corresponding producer completes.
    """
    records = []
    serialized = [0]
    for projection, name in enumerate(("query", "key", "value")):
        base = SOURCE_BASES[name]
        # QKV projections use 208 physical rows, including 11 producer padding
        # rows. Preserve every physical output word in the checkpoint audit.
        end = base + PHYSICAL_ROWS * CHANNELS
        expected = {address: value for address, value in golden.items()
                    if base <= address < end}
        if len(expected) != PHYSICAL_ROWS * CHANNELS // 4:
            raise ValueError("%s checkpoint word count=%d expected=%d" %
                             (name, len(expected), PHYSICAL_ROWS * CHANNELS // 4))
        ordered = sorted(expected.items())
        final_projection_desc = (projection + 1) * 156 - 1
        for chunk_index, first in enumerate(range(0, len(ordered), 8192)):
            chunk = ordered[first:first + 8192]
            serialized.extend((final_projection_desc, len(chunk)))
            for address, value in chunk:
                serialized.extend((address, value))
            records.append({
                "tensor": name,
                "descriptor_index": final_projection_desc,
                "chunk": chunk_index,
                "words": len(chunk),
                "address_range": [chunk[0][0], chunk[-1][0] + 4],
            })
    serialized[0] = len(records)
    write_values(path, serialized)
    if len(records) != 6:
        raise ValueError("expected six bounded Q/K/V checkpoint records")
    return records


def pack_i8(values: list[int]) -> int:
    if len(values) != 4:
        raise ValueError("packed INT8 word must have four lanes")
    return sum((int(value) & 0xFF) << (8 * lane)
               for lane, value in enumerate(values))


def build_repack_expected(tensor: "np.ndarray", head: int, mode: int) -> dict[int, int]:
    """Independent destination-layout oracle for one tensor and one head.

    The standalone Round30 repack helper enumerates Q/K/V by its outer
    ``head`` loop. That fixture indexing is not the same as this integrated
    descriptor sequence (which emits all three tensors for each head), so do
    not reuse its result index here.
    """
    expected: dict[int, int] = {}

    def byte_at(row: int, feature: int) -> int:
        if row >= VALID_ROWS:
            return 0
        return int(tensor[row, head * HEAD_DIM + feature])

    if mode == 0:  # Dense Q row-major, including zeroed physical rows.
        for row in range(PHYSICAL_ROWS):
            for feature_base in range(0, HEAD_DIM, 4):
                address = Q_DENSE + row * HEAD_DIM + feature_base
                expected[address] = pack_i8(
                    [byte_at(row, feature_base + lane) for lane in range(4)])
    elif mode == 1:  # K-major: [feature, token] in 16-token slabs.
        for row_base in range(0, PHYSICAL_ROWS, 4):
            for feature in range(HEAD_DIM):
                address = (K_MAJOR + (row_base >> 4) * (HEAD_DIM << 4)
                           + (feature << 4) + (row_base & 15))
                expected[address] = pack_i8(
                    [byte_at(row_base + lane, feature) for lane in range(4)])
    elif mode == 2:  # Matrix-B panel/bank physical byte lane order.
        for row_base in range(0, PHYSICAL_ROWS, 4):
            for feature in range(HEAD_DIM):
                panel = feature >> 4
                col_in_panel = feature & 15
                col_group = col_in_panel & 12
                word_index = ((col_group // 4) * (PHYSICAL_ROWS // 4) * 4
                              + (row_base // 4) * 4 + (col_in_panel & 3))
                address = V_MATRIX_B + panel * 4096 + word_index * 4
                expected[address] = pack_i8(
                    [byte_at(row_base + lane, feature) for lane in range(4)])
    else:
        raise ValueError("invalid repack mode %d" % mode)
    if len(expected) != 3328:
        raise ValueError("unexpected 0x3b output words mode=%d count=%d" %
                         (mode, len(expected)))
    return expected


def descriptor_words(descriptor: Descriptor | list[int], task_id: int) -> list[int]:
    """Return the 16-word ABI payload with a unique runtime task ID."""
    if isinstance(descriptor, list):
        words = list(descriptor)
    else:
        words = descriptor.words()
    if len(words) != 16:
        raise ValueError("descriptor must contain 16 words")
    # ABI word 0 is {task_id[15:0], reserved[7:0], opcode[7:0]}.
    words[0] = ((task_id & 0xFFFF) << 16) | (words[0] & 0xFFFF)
    return words


def write_descriptors(path: Path, descriptors: list[Descriptor | list[int]]) -> None:
    words = [len(descriptors)]
    # Task IDs are assigned globally by add_batch() so Completion retirement
    # remains unambiguous across streamed CMDQ batches. Re-numbering from
    # 0x8000 in every file would duplicate IDs at each publication boundary.
    for descriptor in descriptors:
        encoded = list(descriptor) if isinstance(descriptor, list) else descriptor.words()
        if len(encoded) != 16:
            raise ValueError("descriptor must contain 16 words")
        words.extend(encoded)
    write_values(path, words)


def validate_layout() -> None:
    spans = [
        ("AV all heads", AV_BASE, 3 * 0x1000),
        ("Q dense", Q_DENSE, PHYSICAL_ROWS * HEAD_DIM),
        ("K major", K_MAJOR, PHYSICAL_ROWS * HEAD_DIM),
        ("V Matrix-B", V_MATRIX_B, 4 * 0x1000),
        ("QK scores", SCORE_I32, 16 * PHYSICAL_ROWS * 4),
        ("Softmax probabilities", PROB_I32, 16 * PHYSICAL_ROWS * 4),
    ]
    for name, start, size in spans:
        if start < 0 or start + size > LOW_SCRATCH_LIMIT:
            raise ValueError("%s span exceeds low scratch: [%#x,%#x)" %
                             (name, start, start + size))
    if Q_DENSE + PHYSICAL_ROWS * HEAD_DIM != K_MAJOR:
        raise ValueError("Q/K scratch allocation is not adjacent as expected")
    if K_MAJOR + PHYSICAL_ROWS * HEAD_DIM != V_MATRIX_B:
        raise ValueError("K/V scratch allocation is not adjacent as expected")
    if SCORE_I32 + 16 * PHYSICAL_ROWS * 4 != PROB_I32:
        raise ValueError("score/probability scratch ranges overlap or gap unexpectedly")
    if PROB_I32 + 16 * PHYSICAL_ROWS * 4 != 0x14000:
        raise ValueError("probability scratch range does not end at 0x14000")


def generate(source: Path, out_dir: Path, query_blocks: int = 1) -> dict:
    validate_layout()
    if query_blocks not in (1, 13):
        raise ValueError("query_blocks must be 1 or 13 (all 197 valid rows)")
    qblock = load_module("round25_attention_qblock", ROOT / "benchmark/deit/round25/generate_deit_attention_qblock.py")

    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("execution", {}).get("descriptor_count") != QKV_COUNT:
        raise ValueError("source workload is not fixed 468-descriptor QKV Top input")
    shape = manifest.get("shape", {})
    if (shape.get("valid_rows") != VALID_ROWS or
            shape.get("physical_rows") != PHYSICAL_ROWS or
            shape.get("hidden") != CHANNELS or shape.get("heads") != HEADS):
        raise ValueError("unexpected QKV shape: %s" % shape)
    for filename, expected_hash in manifest.get("artifacts", {}).items():
        path = source / filename
        if expected_hash and sha256(path) != expected_hash:
            raise ValueError("source artifact hash mismatch: %s" % filename)

    source_golden = read_pairs(source / "model_golden.memh")
    source_memory = read_pairs(source / "model_memory.memh")
    # The reference decoder extracts signed bytes from the same physical QKV
    # Matrix-A Golden checked by the 468-descriptor Product run.
    q = qblock.dense_tile_a(source_golden, SOURCE_BASES["query"],
                            VALID_ROWS, CHANNELS, PHYSICAL_ROWS)
    k = qblock.dense_tile_a(source_golden, SOURCE_BASES["key"],
                            PHYSICAL_ROWS, CHANNELS, PHYSICAL_ROWS)
    v = qblock.dense_tile_a(source_golden, SOURCE_BASES["value"],
                            PHYSICAL_ROWS, CHANNELS, PHYSICAL_ROWS)
    # Projection rows 197..207 are physical Matrix-A padding and may contain
    # nonzero bias/output values. Opcode 0x3b's valid_rows contract must mask
    # them without consuming them; they are not required to be zero upstream.

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "batches").mkdir(exist_ok=True)

    # Use the verified free SPAD gap after Product QKV outputs and before the
    # descriptor ring. The source persists across all query blocks and cannot
    # be overwritten by earlier AV output tiles.
    zero_source_by_head = {head: ZERO_SOURCE for head in range(HEADS)}
    for address in range(ZERO_SOURCE, ZERO_SOURCE + 16 * 16 * 4, 4):
        if address in source_memory:
            raise ValueError("Softmax pad-zero source collides with QKV image at %#x" % address)
        source_memory[address] = 0
    write_pairs(out_dir / "model_memory.memh", source_memory)
    # QKV Golden remains unchanged; only the original 468 descriptor output is
    # checked by the first Product stage.
    write_pairs(out_dir / "model_golden.memh", source_golden)
    projection_checkpoints = write_descriptor_checkpoints(
        out_dir / "checkpoint_spad.memh", source_golden)

    all_descriptors = []
    batches = []
    attention_details = []

    def add_batch(name: str, descriptors: list[Descriptor], expected: dict[int, int],
                  phase: str, head: int) -> None:
        batch_index = len(batches)
        # Rewrite task IDs globally so completion retirement can be checked
        # across the initial QKV prefix and every queue wrap.
        unique = []
        first_task_id = 0x8000 + len(all_descriptors)
        for index, descriptor in enumerate(descriptors):
            task_id = first_task_id + index
            if isinstance(descriptor, list):
                words = descriptor_words(descriptor, task_id)
                unique.append(words)
            else:
                unique.append(dataclasses.replace(descriptor, task_id=task_id))
            all_descriptors.append(task_id)
        batch_dir = out_dir / "batches"
        write_descriptors(batch_dir / ("batch_%02d_desc.memh" % batch_index), unique)
        write_checkpoint(batch_dir / ("batch_%02d_golden.memh" % batch_index), expected)
        batches.append({
            "batch": batch_index, "name": name, "phase": phase, "head": head,
            "descriptor_count": len(unique),
            "task_id_first": first_task_id if unique else None,
            "task_id_last": first_task_id + len(unique) - 1 if unique else None,
            "golden_words": len(expected),
            "descriptor_file": "batches/batch_%02d_desc.memh" % batch_index,
            "golden_file": "batches/batch_%02d_golden.memh" % batch_index,
        })

    # All three 0x3b outputs are generated from the Product QKV Matrix-A
    # addresses. The same low scratch ranges are reused only after each head's
    # consumer stages have retired.
    for head in range(HEADS):
        repack_descriptors = []
        repack_expected = {}
        for mode in range(3):
            src_name = ("query", "key", "value")[mode]
            words = [0] * 16
            words[0] = ((0x7000 + len(batches) * 4 + mode) << 16) | 0x3B
            words[1] = SOURCE_BASES[src_name]
            words[4] = REPACK_DESTS[mode]
            words[5] = (CHANNELS << 16) | PHYSICAL_ROWS
            words[6] = VALID_ROWS
            words[8] = (head << 2) | mode | 0x10
            words[12] = PHYSICAL_ROWS
            words[15] = 7
            # Descriptor instance with explicit ABI fields; words are used
            # directly because 0x3b is research-only in this mapper revision.
            repack_descriptors.append(words)
            source_tensor = (q, k, v)[mode]
            repack_expected.update(build_repack_expected(source_tensor, head, mode))
        add_batch("head%d_qkv_repack" % head, repack_descriptors,
                  repack_expected, "repack", head)

        for query_block in range(query_blocks):
            q_start = query_block * 16
            query_tile = np.zeros((16, CHANNELS), dtype=np.int16)
            valid_in_tile = max(0, min(16, VALID_ROWS - q_start))
            if valid_in_tile:
                query_tile[:valid_in_tile] = q[q_start:q_start + valid_in_tile]
            attention_descs, _fixture_pairs, attention_golden = qblock.build(
                head, query_tile, k, v, {})
            qk_count = 16 * (PHYSICAL_ROWS // 16)
            qk = attention_descs[:qk_count]
            qk_mapped = [dataclasses.replace(
                d,
                src0=Q_DENSE + (q_start + i // 13) * HEAD_DIM,
                src1=K_MAJOR + (i % 13) * 1024,
                dst=SCORE_I32 + ((i // 13) * PHYSICAL_ROWS + (i % 13) * 16) * 4,
            ) for i, d in enumerate(qk)]
            score_expected = {SCORE_I32 + (addr - qblock.SCALED): value
                              for addr, value in attention_golden.items()
                              if qblock.SCALED <= addr < qblock.SCALED +
                              16 * PHYSICAL_ROWS * 4}
            add_batch("head%d_q%03d_qk" % (head, q_start), qk_mapped,
                      score_expected, "qk", head)

            softmax_zero = attention_descs[qk_count:qk_count + 32]
            softmax_zero_mapped = []
            for i, d in enumerate(softmax_zero):
                row = i // 2
                if i % 2 == 0:
                    softmax_zero_mapped.append(dataclasses.replace(
                        d, src0=SCORE_I32 + row * PHYSICAL_ROWS * 4,
                        dst=PROB_I32 + row * PHYSICAL_ROWS * 4))
                else:
                    softmax_zero_mapped.append(dataclasses.replace(
                        d, src0=zero_source_by_head[head] + row * 16 * 4,
                        dst=PROB_I32 + (row * PHYSICAL_ROWS + VALID_ROWS) * 4))
            prob_expected = {PROB_I32 + (addr - qblock.PROB): value
                             for addr, value in attention_golden.items()
                             if qblock.PROB <= addr < qblock.PROB +
                             16 * PHYSICAL_ROWS * 4}
            add_batch("head%d_q%03d_softmax_and_padding" % (head, q_start),
                      softmax_zero_mapped, prob_expected, "softmax", head)

            pack = attention_descs[qk_count + 32]
            pack_mapped = [dataclasses.replace(pack, src0=PROB_I32,
                                               dst=PROB_PACKED_A)]
            packed_expected = {PROB_PACKED_A + (addr - qblock.PROB_A): value
                               for addr, value in attention_golden.items()
                               if qblock.PROB_A <= addr < qblock.PROB_A +
                               16 * PHYSICAL_ROWS}
            add_batch("head%d_q%03d_probability_pack" % (head, q_start),
                      pack_mapped, packed_expected, "probability_pack", head)

            av_start = qk_count + 33
            av_descs = attention_descs[av_start:]
            av_base = AV_BASE + head * 0x1000
            av_mapped = [dataclasses.replace(
                d, src0=PROB_PACKED_A,
                src1=V_MATRIX_B + i * 0x1000,
                dst=av_base + i * 0x400,
            ) for i, d in enumerate(av_descs)]
            av_expected = {av_base + (addr - qblock.AV): value
                           for addr, value in attention_golden.items()
                           if qblock.AV <= addr < qblock.AV + 4 * 0x400}
            add_batch("head%d_q%03d_av" % (head, q_start), av_mapped,
                      av_expected, "av", head)
            attention_details.append({
                "head": head, "query_start": q_start,
                "valid_queries": valid_in_tile,
                "qk_descriptors": len(qk_mapped),
                "softmax_and_pad_descriptors": len(softmax_zero_mapped),
                "probability_pack_descriptors": len(pack_mapped),
                "av_descriptors": len(av_mapped),
                "qkv_source_addresses": SOURCE_BASES,
                "scratch": {"q_dense": Q_DENSE, "k_major": K_MAJOR,
                            "v_matrix_b": V_MATRIX_B, "score": SCORE_I32,
                            "probability": PROB_I32, "probability_packed_a": PROB_PACKED_A,
                            "av_output": av_base},
            })

    # The QKV source image is only initialization: it includes source inputs,
    # model weights and queue descriptors for the already-existing projection
    # path. Newly generated attention descriptors are published by AXI-Lite
    # at runtime, not host-preloaded as activations.
    manifest_out = {
        "status": "DEIT_R30_CONTINUOUS_QKV_REPACK_3HEAD_ATTENTION_FIXTURE",
        "seed": 300030,
        "source_qkv_manifest_sha256": sha256(source / "manifest.json"),
        "source_qkv_golden_sha256": sha256(source / "model_golden.memh"),
        "source_qkv_memory_sha256": sha256(source / "model_memory.memh"),
        "valid_tokens": VALID_ROWS, "physical_tokens": PHYSICAL_ROWS,
        "query_blocks": query_blocks,
        "valid_query_rows_covered": min(query_blocks * 16, VALID_ROWS),
        "all_valid_queries_covered": query_blocks == 13,
        "hidden": CHANNELS, "heads": HEADS, "head_dim": HEAD_DIM,
        "queue_size": QUEUE_SIZE,
        "descriptor_base": DESC_BASE, "completion_base": CPL_BASE,
        "initial_product_descriptors": QKV_COUNT,
        "projection_checkpoints": projection_checkpoints,
        "projection_checkpoint_file": "checkpoint_spad.memh",
        "streamed_attention_descriptors": len(all_descriptors),
        "total_descriptors": QKV_COUNT + len(all_descriptors),
        "batch_count": len(batches), "batches": batches,
        "attention": attention_details,
        "source_padding_contract": {
            "qkv_projection_padding_may_be_nonzero": True,
            "valid_token_rows": VALID_ROWS,
            "physical_rows": PHYSICAL_ROWS,
            "repack_valid_rows": "0x3b writes zero to destination rows [197,208) without reading source padding",
        },
        "allocation": {
            "immutable_qkv_sources": {"Q": [0x16000, 0x1FC00],
                                       "K": [0x20000, 0x29C00],
                                       "V": [0x2A000, 0x33C00]},
            "low_scratch_limit": LOW_SCRATCH_LIMIT,
            "persistent_av_bytes": 3 * 4096,
            "per_head_reused_ranges": {
                "q_dense": [Q_DENSE, Q_DENSE + PHYSICAL_ROWS * HEAD_DIM],
                "k_major": [K_MAJOR, K_MAJOR + PHYSICAL_ROWS * HEAD_DIM],
                "v_matrix_b": [V_MATRIX_B, V_MATRIX_B + 4 * 4096],
                "score_or_packed_probability": [SCORE_I32, PROB_I32],
                "probability": [PROB_I32, 0x14000],
            },
            "per_head_reused_bytes_excluding_shared_zero_source": (
                2 * PHYSICAL_ROWS * HEAD_DIM + 4 * 4096 +
                2 * 16 * PHYSICAL_ROWS * 4),
            "peak_live_bytes_in_low_scratch": 0x14000,
            "shared_read_only_zero_source": {
                "range": [ZERO_SOURCE, ZERO_SOURCE + 1024],
                "location": "reserved SPAD gap after immutable QKV outputs and before descriptor ring",
                "initialized_once_before_execution": True,
                "overwritten_by_attention_outputs": False,
                "shared_by_heads_and_query_blocks": True,
            },
            "queue_region": [DESC_BASE, 0x40000],
        },
        "runtime_contract": {
            "single_product_top": True,
            "reset_between_qkv_repack_attention": False,
            "host_intermediate_tensor_readback_words": 0,
            "host_intermediate_tensor_writeback_words": 0,
            "qkv_repack_consumer_dependency": "batch retirement and CPLQ_HEAD advancement",
            "head_lifetime": "Q/K/V/score/probability scratch reused after each head AV retirement",
            "attention": "%d query blocks of 16 rows x 197 valid keys; one Softmax(197) per query; padding is zeroed after Softmax and excluded from denominator" % query_blocks,
        },
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest_out, indent=2,
                                                         sort_keys=True) + "\n",
                                            encoding="utf-8")
    manifest_out["artifacts"] = {}
    for path in sorted(out_dir.rglob("*")):
        if path.is_file() and path.name != "manifest.json":
            manifest_out["artifacts"][str(path.relative_to(out_dir))] = sha256(path)
    (out_dir / "manifest.json").write_text(json.dumps(manifest_out, indent=2,
                                                         sort_keys=True) + "\n",
                                            encoding="utf-8")
    return manifest_out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-workload", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--query-blocks", type=int, default=1)
    args = parser.parse_args()
    result = generate(args.source_workload, args.out_dir, args.query_blocks)
    print("DEIT_R30_CONTINUOUS_ATTENTION_READY " +
          json.dumps(result, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
