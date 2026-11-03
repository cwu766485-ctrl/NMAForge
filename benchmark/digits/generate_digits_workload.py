#!/usr/bin/env python3
"""Map the trained test set to ABI-v7 GEMM/ReLU/REQUANT descriptors."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))
from sw.tools.cimforge_mapper import (  # noqa: E402
    Descriptor, FLAG_BIAS, FLAG_PACK_I8, FLAG_PACK_I8_TILE_A,
)
from benchmark.digits.digits_quantized_golden import integer_infer  # noqa: E402


OP_GEMM = 0x30
OP_REQUANT = 0x36
ARRAY_M = 16
K = 64
K_WORDS = K // 4
BATCH = 16

# Addresses are offsets from SPAD_BASE, matching the other ABI-v7 mapper jobs.
W1_BASE = 0x10000
B1_BASE = 0x12000
W2_BASE = 0x13000
B2_BASE = 0x13400
HIDDEN_I32_BASE = 0x14000
HIDDEN_I8_TILE_BASE = 0x32000
DESC_BASE = 0x38000
CPL_BASE = 0x3A000
OUTPUT_BASE = 0x3B000
INPUT_BASE = 0x50000
TASK_BASE = 0xD000


def pack_i8(values) -> int:
    vals = [int(value) for value in values]
    if len(vals) != 4 or any(value < -128 or value > 127 for value in vals):
        raise ValueError("packed INT8 word requires four signed INT8 values")
    return sum((value & 0xFF) << (8 * lane) for lane, value in enumerate(vals))


def add_words(memory: dict[int, int], base: int, values) -> None:
    for index, value in enumerate(values):
        address = base + index * 4
        if address in memory:
            raise ValueError(f"overlapping mapped words at SPAD+0x{address:08x}")
        memory[address] = int(value) & 0xFFFFFFFF


def pack_a_rows(matrix: np.ndarray) -> list[int]:
    m, k = matrix.shape
    if m != ARRAY_M or k != K or k % 4:
        raise ValueError("unsupported A operand shape")
    # Matrix issues one banked read per 4-row group and K-word. Each response
    # contains the four row words for that K-word, so memory order is
    # [row_group][k_group][row_lane], matching banked_word_offset in the core.
    return [pack_i8(matrix[row_group + row_lane, k0 : k0 + 4])
            for row_group in range(0, m, 4)
            for k0 in range(0, k, 4)
            for row_lane in range(4)]


def pack_b_columns(matrix: np.ndarray, n_valid: int) -> list[int]:
    """Pack 16-column output macro-tile in the Matrix 4x4-group layout."""
    k, n_storage = matrix.shape
    if k != K or n_storage < n_valid or n_valid % 4:
        raise ValueError("unsupported B operand shape")
    words = []
    for n_tile in range(0, n_valid, ARRAY_M):
        tile_cols = min(ARRAY_M, n_valid - n_tile)
        for col_group in range(0, tile_cols, 4):
            for k0 in range(0, k, 4):
                for lane in range(4):
                    col = n_tile + col_group + lane
                    words.append(pack_i8(matrix[k0 : k0 + 4, col]))
    return words


def descriptor_words(*, task_id: int, opcode: int, src0: int, src1: int,
                     bias: int, dst: int, m: int, n: int, extent: int,
                     flags: int, shift: int = 0, activation: int = 0,
                     wait_mask: int = 0, signal_mask: int = 0,
                     clear_mask: int = 0) -> list[int]:
    desc = Descriptor(
        name=f"digits_{task_id:04x}", task_id=task_id, op=opcode,
        src0=src0, src1=src1, bias=bias, dst=dst, m=m, n=n,
        k_or_length=extent, flags=flags, shift=shift, activation=activation,
        wait_mask=wait_mask, signal_mask=signal_mask, clear_mask=clear_mask,
    )
    words = desc.words()
    if words[15] & 0xFFFF != 7:
        raise AssertionError("mapper did not emit ABI-v7 descriptor")
    return words


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=REPO_ROOT /
                        "benchmark/digits/artifacts/digits_mlp_int8.npz")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    with np.load(args.model) as model:
        x_q = model["test_images_q"].astype(np.int8)
        labels = model["test_labels"].astype(np.int64)
        w1 = model["w1_int8"].astype(np.int8)
        b1 = model["b1_acc_int32"].astype(np.int32)
        w2_10 = model["w2_int8"].astype(np.int8)[:, :10]
        b2_10 = model["b2_acc_int32"].astype(np.int32)[:10]
        shift1 = int(model["hidden_shift"])
        hidden_golden, logits_golden = integer_infer(x_q, model)
        batches = (len(labels) + BATCH - 1) // BATCH
        padded = np.zeros((batches * BATCH, 64), dtype=np.int8)
        padded[: len(labels)] = x_q
        padded_hidden, _padded_logits = integer_infer(padded, model)
        model_bytes = args.model.read_bytes()

    w2 = np.zeros((K, ARRAY_M), dtype=np.int8)
    w2[:, :10] = w2_10
    b2 = np.zeros(ARRAY_M, dtype=np.int32)
    b2[:10] = b2_10
    memory: dict[int, int] = {}
    add_words(memory, W1_BASE, pack_b_columns(w1, 64))
    add_words(memory, B1_BASE, b1)
    add_words(memory, W2_BASE, pack_b_columns(w2, ARRAY_M))
    add_words(memory, B2_BASE, b2)

    descriptors: list[list[int]] = []
    for batch_index in range(batches):
        batch_x = padded[batch_index * BATCH : (batch_index + 1) * BATCH]
        input_base = INPUT_BASE + batch_index * BATCH * 64
        output_base = OUTPUT_BASE + batch_index * BATCH * ARRAY_M * 4
        add_words(memory, input_base, pack_a_rows(batch_x))
        add_words(memory, output_base,
                  [0xA55AA55A] * (BATCH * ARRAY_M))

        hidden_i32_base = HIDDEN_I32_BASE + batch_index * BATCH * 64 * 4
        hidden_i8_tile_base = HIDDEN_I8_TILE_BASE + batch_index * BATCH * 64
        descriptors.append(descriptor_words(
            task_id=TASK_BASE + len(descriptors), opcode=OP_GEMM, src0=input_base,
            src1=W1_BASE, bias=B1_BASE, dst=hidden_i32_base,
            m=BATCH, n=64, extent=K_WORDS, flags=FLAG_BIAS,
            shift=shift1, activation=1, signal_mask=1,
        ))
        descriptors.append(descriptor_words(
            task_id=TASK_BASE + len(descriptors), opcode=OP_REQUANT,
            src0=hidden_i32_base, src1=0, bias=0, dst=hidden_i8_tile_base,
            m=BATCH, n=64, extent=BATCH * 64,
            flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
            wait_mask=1, signal_mask=2, clear_mask=1,
        ))
        descriptors.append(descriptor_words(
            task_id=TASK_BASE + len(descriptors),
            opcode=OP_GEMM,
            src0=hidden_i8_tile_base, src1=W2_BASE, bias=B2_BASE,
            dst=output_base, m=BATCH, n=ARRAY_M, extent=K_WORDS,
            flags=FLAG_BIAS, wait_mask=2, clear_mask=2,
        ))

    desc_count = len(descriptors)
    if desc_count >= 128:
        raise ValueError("CMDQ depth 128 is insufficient for this test split")
    add_words(memory, CPL_BASE, [0xC0DEC0DE] * (desc_count * 4))
    for desc_index, words in enumerate(descriptors):
        add_words(memory, DESC_BASE + desc_index * 64, words)

    image_path = args.out_dir / "digits_spad_writes.memh"
    image_words = [len(memory)]
    for address, value in sorted(memory.items()):
        image_words.extend((address, value))
    image_path.write_text("".join(f"{value & 0xFFFFFFFF:08x}\n"
                                   for value in image_words), encoding="ascii")

    hidden_words = [word for batch_index in range(batches)
                    for word in pack_a_rows(
                        padded_hidden[batch_index * BATCH : (batch_index + 1) * BATCH])]
    hidden_path = args.out_dir / "digits_hidden_expected.memh"
    hidden_path.write_text("".join(
        f"{value & 0xFFFFFFFF:08x}\n"
        for value in [len(hidden_words), *hidden_words]
    ), encoding="ascii")

    expected_path = args.out_dir / "digits_expected.memh"
    expected_words = [len(labels)]
    for index, label in enumerate(labels):
        expected_words.append(int(label))
        expected_words.extend(int(value) for value in logits_golden[index])
    expected_path.write_text("".join(f"{value & 0xFFFFFFFF:08x}\n"
                                      for value in expected_words), encoding="ascii")

    manifest = {
        "model": "sklearn_digits_mlp_int8",
        "model_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "abi_version": 7,
        "array_size": 16,
        "test_samples": int(len(labels)),
        "batch": BATCH,
        "batches": batches,
        "descriptor_count": desc_count,
        "descriptors_per_sample_batch": ["Matrix GEMM+Bias+ReLU", "SFU Requant Pack-I8 to Matrix A tile layout", "Matrix GEMM+Bias"],
        "execution_phases": [
            "CMDQ GEMM+Bias+ReLU -> SFU tiled Pack-I8 -> GEMM+Bias; dependency events serialize each batch without host intermediate writes",
        ],
        "hidden_shift": shift1,
        "input_base": INPUT_BASE,
        "weight1_base": W1_BASE,
        "bias1_base": B1_BASE,
        "hidden_i32_base": HIDDEN_I32_BASE,
        "hidden_i8_tile_base": HIDDEN_I8_TILE_BASE,
        "hidden_layout": "Matrix A [row_group][k_group][row_lane], generated by SFU descriptor flag bit 5",
        "weight2_base": W2_BASE,
        "bias2_base": B2_BASE,
        "output_base": OUTPUT_BASE,
        "descriptor_base": DESC_BASE,
        "completion_base": CPL_BASE,
        "memory_word_writes": len(memory),
        "image_memh": str(image_path),
        "hidden_expected_memh": str(hidden_path),
        "expected_memh": str(expected_path),
        "integer_golden_sha256": hashlib.sha256(logits_golden.tobytes()).hexdigest(),
        "integer_golden_accuracy": float(np.mean(np.argmax(logits_golden[:, :10], axis=1) == labels)),
        "rtl_execution": "not-run-by-generator",
    }
    manifest_path = args.out_dir / "digits_workload.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                             encoding="utf-8")
    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
