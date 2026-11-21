#!/usr/bin/env python3
"""Append 0x3b Q/K/V layout conversions to a real Product-Top QKV workload.

The QKV descriptors, late-DMA events, packed Product-SPAD outputs and
independent integer Golden come from the fixed Round 26 full-projection
workload.  This script appends nine layout descriptors and retirement-time
SPAD checkpoints; it does not synthesize or rewrite Q/K/V activations.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


SPAD_BYTES = 256 * 1024
PHYSICAL_ROWS = 208
VALID_ROWS = 197
CHANNELS = 192
HEADS = 3
HEAD_DIM = CHANNELS // HEADS
QUEUE_SIZE = 512
QKV_DESC_COUNT = 468
REPACK_DESC_COUNT = 9
TOTAL_DESC_COUNT = QKV_DESC_COUNT + REPACK_DESC_COUNT
DESC_BASE = 0x36000
CPL_BASE = 0x3E000
OUTPUT_BASE = 0x00000
OUTPUT_SPAN = 0x4000
MODES = {"q_dense": 0, "k_major": 1, "v_matrix_b": 2}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read_memh_pairs(path: Path) -> Dict[int, int]:
    fields = [line.strip() for line in path.read_text(encoding="ascii").splitlines()
              if line.strip()]
    if not fields:
        raise ValueError(f"empty memh: {path}")
    count = int(fields[0], 16)
    if len(fields) != 1 + count * 2:
        raise ValueError(f"memh pair count mismatch {path}: header={count}, fields={len(fields)}")
    result: Dict[int, int] = {}
    for index in range(count):
        address = int(fields[1 + index * 2], 16)
        value = int(fields[2 + index * 2], 16)
        if address in result:
            raise ValueError(f"duplicate memory address {address:#x} in {path}")
        result[address] = value
    return result


def write_memh_pairs(path: Path, words: Dict[int, int]) -> None:
    with path.open("w", encoding="ascii", newline="\n") as stream:
        stream.write(f"{len(words):08x}\n")
        for address, value in sorted(words.items()):
            stream.write(f"{address:08x}\n{value & 0xffffffff:08x}\n")


def write_memh_values(path: Path, values: Iterable[int]) -> None:
    data = list(values)
    with path.open("w", encoding="ascii", newline="\n") as stream:
        for value in data:
            stream.write(f"{value & 0xffffffff:08x}\n")


def pack_i8(values: Iterable[int]) -> int:
    lanes = list(values)
    if len(lanes) != 4:
        raise ValueError(f"expected four byte lanes, got {len(lanes)}")
    return sum((int(value) & 0xff) << (8 * lane) for lane, value in enumerate(lanes))


def matrix_a_word(base: int, row: int, col: int) -> int:
    """Address of one 32-bit word in compact packed-INT8 Matrix-A tiles."""
    tile = (row // 16) * (CHANNELS // 16) + col // 16
    local_row = row & 15
    local_col = col & 15
    word_index = ((local_row // 4) * 16 + (local_col // 4) * 4
                  + (local_row & 3))
    return base + tile * 256 + word_index * 4


def descriptor(task_index: int, src: int, head: int, mode: int) -> List[int]:
    words = [0] * 16
    words[0] = ((0x7100 + task_index) << 16) | 0x3b
    words[1] = src
    words[4] = OUTPUT_BASE
    words[5] = (CHANNELS << 16) | PHYSICAL_ROWS
    words[6] = VALID_ROWS
    words[8] = (head << 2) | mode | 0x10  # packed INT8 Matrix-A source
    words[12] = PHYSICAL_ROWS
    words[15] = 7
    return words


def build_outputs(source_golden: Dict[int, int], source_bases: Dict[str, int],
                  layout: str) -> List[Tuple[int, Dict[int, int]]]:
    records: List[Tuple[int, Dict[int, int]]] = []
    for head in range(HEADS):
        source_name = ("query", "key", "value")[head]
        src_base = source_bases[source_name]

        def byte_at(row: int, feature: int) -> int:
            if row >= VALID_ROWS:
                return 0
            address = matrix_a_word(src_base, row, head * HEAD_DIM + feature)
            if address not in source_golden:
                raise ValueError(f"QKV Golden missing packed source word at {address:#x}")
            return (source_golden[address] >> (((head * HEAD_DIM + feature) & 3) * 8)) & 0xff

        selected_modes = list(MODES.items()) if layout == "all" else [(layout, MODES[layout])]
        for mode_name, mode in selected_modes:
            output: Dict[int, int] = {}
            if mode == 0:  # Dense Q, 208 x 64 bytes, row-major.
                for row in range(PHYSICAL_ROWS):
                    for feature_base in range(0, HEAD_DIM, 4):
                        address = OUTPUT_BASE + row * HEAD_DIM + feature_base
                        output[address] = pack_i8(byte_at(row, feature_base + lane)
                                                  for lane in range(4))
            elif mode == 1:  # K-major: feature rows, token columns.
                for row_base in range(0, PHYSICAL_ROWS, 4):
                    for feature in range(HEAD_DIM):
                        address = (OUTPUT_BASE + (row_base >> 4) * (HEAD_DIM << 4)
                                   + (feature << 4) + (row_base & 15))
                        output[address] = pack_i8(byte_at(row_base + lane, feature)
                                                  for lane in range(4))
            else:  # Matrix-B panel/bank lane order; each panel has a 4 KiB stride.
                for row_base in range(0, PHYSICAL_ROWS, 4):
                    for feature in range(HEAD_DIM):
                        panel = feature >> 4
                        col_in_panel = feature & 15
                        col_group = col_in_panel & 12
                        word_index = ((col_group // 4) * (PHYSICAL_ROWS // 4) * 4
                                      + (row_base // 4) * 4 + (col_in_panel & 3))
                        address = OUTPUT_BASE + panel * 4096 + word_index * 4
                        output[address] = pack_i8(byte_at(row_base + lane, feature)
                                                  for lane in range(4))

            if len(output) != 3328:
                raise ValueError(f"unexpected active output words layout={mode_name} head={head}: {len(output)}")
            if any(address < 0 or address + 4 > OUTPUT_BASE + OUTPUT_SPAN
                   for address in output):
                raise ValueError(f"output exceeds reusable 16 KiB buffer layout={mode_name} head={head}")
            if any(address % 4 for address in output):
                raise ValueError(f"unaligned output word layout={mode_name} head={head}")
            records.append((QKV_DESC_COUNT + head * len(MODES) + mode, output))
    return records


def generate(source_dir: Path, out_dir: Path, layout: str) -> dict:
    manifest_path = source_dir / "manifest.json"
    source_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    required_files = ("model_memory.memh", "model_golden.memh",
                      "dma_payload.memh", "late_dma_plan.memh")
    expected_hashes = source_manifest.get("artifacts", {})
    for name in required_files:
        path = source_dir / name
        if not path.is_file():
            raise FileNotFoundError(path)
        if name in expected_hashes and sha256(path) != expected_hashes[name]:
            raise ValueError(f"source artifact hash mismatch for {name}")

    execution = source_manifest.get("execution", {})
    shape = source_manifest.get("shape", {})
    if execution.get("descriptor_count") != QKV_DESC_COUNT:
        raise ValueError("expected fixed 468-descriptor Round 26 QKV Product workload")
    if (shape.get("valid_rows") != VALID_ROWS or
            shape.get("physical_rows") != PHYSICAL_ROWS or
            shape.get("hidden") != CHANNELS or shape.get("heads") != HEADS):
        raise ValueError(f"unexpected source model shape: {shape}")

    memory = read_memh_pairs(source_dir / "model_memory.memh")
    qkv_golden = read_memh_pairs(source_dir / "model_golden.memh")
    source_bases = {"query": 0x16000, "key": 0x20000, "value": 0x2a000}
    expected_base_map = source_manifest.get("spad", {}).get("allocations", {})
    for name, base in source_bases.items():
        key = f"{name}_output_tile_a"
        if expected_base_map.get(key, [None])[0] != base:
            raise ValueError(f"source manifest {key} does not match {base:#x}")
    if len(qkv_golden) != execution.get("golden_words"):
        raise ValueError("QKV Golden word count differs from source manifest")

    mode = MODES.get(layout, -1)
    repack_records = build_outputs(qkv_golden, source_bases, layout)
    for task_index, _expected_words in repack_records:
        head = (task_index - QKV_DESC_COUNT) // len(MODES)
        command_mode = (task_index - QKV_DESC_COUNT) % len(MODES)
        src_name = ("query", "key", "value")[head]
        words = descriptor(task_index, source_bases[src_name], head, command_mode)
        desc_addr = DESC_BASE + task_index * 64
        for word_index, word in enumerate(words):
            address = desc_addr + word_index * 4
            if address in memory:
                raise ValueError(f"new descriptor collides with pre-existing image word at {address:#x}")
            memory[address] = word

    # Checkpoint each result at retirement, before the next 0x3b command reuses
    # the same 16 KiB output range.
    checkpoint_values: List[int] = [REPACK_DESC_COUNT]
    for task_index, expected_words in repack_records:
        checkpoint_values.extend((task_index, len(expected_words)))
        for address, value in sorted(expected_words.items()):
            checkpoint_values.extend((address, value))
    if len(checkpoint_values) > 65536:
        raise ValueError(f"checkpoint memh exceeds TB capacity: {len(checkpoint_values)} words")

    out_dir.mkdir(parents=True, exist_ok=True)
    write_memh_pairs(out_dir / "model_memory.memh", memory)
    # Keep the original QKV output Golden. Repack outputs are checked at each
    # descriptor retirement using checkpoint_spad.memh.
    write_memh_pairs(out_dir / "model_golden.memh", qkv_golden)
    (out_dir / "checkpoint_spad.memh").write_text(
        "".join(f"{value & 0xffffffff:08x}\n" for value in checkpoint_values),
        encoding="ascii")
    for name in required_files[2:]:
        (out_dir / name).write_bytes((source_dir / name).read_bytes())

    allocations = [
        {"name": "deit_input_ln_from_prior_product_run", "base": 0x8000,
         "bytes": 197 * CHANNELS, "lifetime": "QKV command group"},
        {"name": "Q_output_matrix_a", "base": source_bases["query"],
         "bytes": 208 * CHANNELS, "lifetime": "all QKV + repack commands"},
        {"name": "K_output_matrix_a", "base": source_bases["key"],
         "bytes": 208 * CHANNELS, "lifetime": "all QKV + repack commands"},
        {"name": "V_output_matrix_a", "base": source_bases["value"],
         "bytes": 208 * CHANNELS, "lifetime": "all QKV + repack commands"},
        {"name": "repack_output_reused_per_descriptor", "base": OUTPUT_BASE,
         "bytes": OUTPUT_SPAN, "lifetime": "one descriptor; checked before reuse"},
        {"name": "cmdq", "base": DESC_BASE, "bytes": 32768,
         "lifetime": "512-entry ring; only one entry published per retirement"},
        {"name": "cplq", "base": CPL_BASE, "bytes": 8192,
         "lifetime": "512-entry ring"},
    ]
    manifest = {
        "run_kind": "round30_product_top_qkv_then_0x3b_repack_same_session",
        "status": "GENERATED_SOFTWARE_ORACLE_ONLY_AWAITING_VCS",
        "scope": "real 468 QKV descriptors followed by 9 repacks, same Product Top, no reset; attention consumer is not included",
        "source_round26_manifest_sha256": sha256(manifest_path),
        "source_artifacts_sha256": {name: sha256(source_dir / name) for name in required_files},
        "layout": layout,
        "mode": mode,
        "shape": {"valid_rows": VALID_ROWS, "physical_rows": PHYSICAL_ROWS,
                  "channels": CHANNELS, "heads": HEADS, "head_dim": HEAD_DIM},
        "source_bases": {name: hex(address) for name, address in source_bases.items()},
        "descriptor_base": hex(DESC_BASE), "completion_base": hex(CPL_BASE),
        "qkv_descriptor_count": QKV_DESC_COUNT,
        "repack_descriptor_count": len(repack_records),
        "descriptor_count": TOTAL_DESC_COUNT,
        "queue_size": QUEUE_SIZE,
        "repack_descriptor_indices": [entry[0] for entry in repack_records],
        "checkpoints": [{"descriptor_index": task, "words": len(words),
                          "output_base": hex(OUTPUT_BASE), "reused": True}
                         for task, words in repack_records],
        "golden_word_count_qkv": len(qkv_golden),
        "golden_word_count_repack_per_head": 3328,
        "checkpoint_file_words": len(checkpoint_values),
        "spad_bytes": SPAD_BYTES,
        "allocations": allocations,
        "data_high_water": 0x33c00,
        "useful_macs_qkv": execution["useful_macs"],
        "dma_events_qkv": execution["dma_events"],
        "dma_payload_bytes_qkv": execution["dma_payload_bytes"],
        "host_role": "load source memory/payload, publish descriptor ring, retire completions, and read-only checkpoint outputs; no Q/K/V tensor readback or rewrite",
        "outputs": {"Q": "dense row-major [208,64], rows 197..207 zero",
                    "K": "K-major [64,208], rows 197..207 zero",
                    "V": "Matrix-B panel/bank lane layout; active words checked, unwritten panel holes ignored"},
    }
    manifest["generated_artifacts_sha256"] = {
        name: sha256(out_dir / name) for name in
        ("model_memory.memh", "model_golden.memh", "checkpoint_spad.memh",
         "dma_payload.memh", "late_dma_plan.memh")}
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n",
                                            encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-workload", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--layout", choices=["all"] + sorted(MODES), default="all")
    args = parser.parse_args()
    print(json.dumps(generate(args.source_workload, args.out_dir, args.layout),
                     indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
