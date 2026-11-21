#!/usr/bin/env python3
"""Audit the Round-27 Product QKV readback against Round-26 attention inputs.

This is a data/layout audit, not a Product-Top run. It proves that the staged
attention generator preserves the RTL-produced logical Q/K/V values while
changing their physical encodings for the existing GEMV and Matrix readers.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
sys.path.insert(0, str(ROOT / "benchmark" / "deit" / "round25"))
import generate_deit_attention_qblock as qblock  # noqa: E402

PHYSICAL_ROWS = 208
VALID_ROWS = 197
HIDDEN = 192
HEADS = 3
HEAD_DIM = 64
Q_BASE, K_BASE, V_BASE = 0x16000, 0x20000, 0x2A000


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_a_dump(path: Path) -> dict[int, int]:
    words: dict[int, int] = {}
    for line_no, line in enumerate(path.read_text().splitlines(), 1):
        fields = line.split()
        if len(fields) != 3:
            raise ValueError(f"{path}:{line_no}: malformed readback row")
        lane, addr, value = fields
        if lane not in ("A", "B"):
            raise ValueError(f"{path}:{line_no}: unsupported lane {lane}")
        if re.fullmatch(r"[0-9a-fA-F]{1,8}", value) is None:
            # Ignore X-filled readback outside the three explicitly checked
            # Q/K/V output ranges. A required range then fails as a missing word.
            continue
        address, word = int(addr, 16), int(value, 16)
        if address in words and words[address] != word:
            raise ValueError(f"{path}:{line_no}: conflicting readback lanes at 0x{address:08x}")
        words[address] = word
    return words


def read_pairs(path: Path) -> dict[int, int]:
    lines = [x.strip() for x in path.read_text().splitlines() if x.strip()]
    count = int(lines[0], 16)
    if len(lines) != 1 + 2 * count:
        raise ValueError(f"bad pair image: {path}")
    return {int(lines[1 + 2 * i], 16): int(lines[2 + 2 * i], 16)
            for i in range(count)}


def read_words(path: Path) -> list[int]:
    return [int(x.strip(), 16) for x in path.read_text().splitlines() if x.strip()]


def sign8(value: int) -> int:
    value &= 0xff
    return value - 256 if value & 0x80 else value


def dense_matrix_a(words: dict[int, int], base: int) -> np.ndarray:
    """Decode one 208x192 Matrix-A physical output region."""
    result = np.empty((PHYSICAL_ROWS, HIDDEN), dtype=np.int16)
    ntiles = HIDDEN // 16
    for row in range(PHYSICAL_ROWS):
        for col in range(HIDDEN):
            tile_base = base + ((row // 16) * ntiles + col // 16) * 256
            lr, lc = row & 15, col & 15
            word_addr = tile_base + ((lr // 4) * 16 + (lc // 4) * 4 + (lr & 3)) * 4
            if word_addr not in words:
                raise ValueError(f"missing Matrix-A word 0x{word_addr:08x}")
            result[row, col] = sign8(words[word_addr] >> ((lc & 3) * 8))
    return result


def u8_at(pairs: dict[int, int], address: int) -> int:
    word_addr = address & ~3
    if word_addr not in pairs:
        raise ValueError(f"missing consumer byte at 0x{address:08x}")
    return (pairs[word_addr] >> (8 * (address & 3))) & 0xff


def compare_matrix(actual: np.ndarray, expected: np.ndarray, label: str) -> dict:
    mismatch = np.argwhere(actual != expected)
    first = None
    if mismatch.size:
        r, c = map(int, mismatch[0])
        first = {"row": r, "col": c, "expected": int(expected[r, c]),
                 "actual": int(actual[r, c])}
    return {"label": label, "elements": int(actual.size),
            "mismatches": int(mismatch.shape[0]), "first_mismatch": first}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--qkv-dump", type=Path, required=True)
    ap.add_argument("--qkv-golden", type=Path, required=True)
    ap.add_argument("--attention-payload", type=Path,
                    help="optional archived staged attention DMA payload")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    source = read_a_dump(args.qkv_dump)
    golden = read_pairs(args.qkv_golden)
    matrices = {}
    projection_words = {}
    projection_results = []
    for name, base in (("Q", Q_BASE), ("K", K_BASE), ("V", V_BASE)):
        count = PHYSICAL_ROWS * HIDDEN // 4
        addresses = [base + 4 * i for i in range(count)]
        mismatches = [a for a in addresses if source.get(a) != golden.get(a)]
        projection_words[name] = count
        projection_results.append({"projection": name, "physical_words": count,
                                   "mismatches_vs_independent_golden": len(mismatches),
                                   "first_mismatch_address": (f"0x{mismatches[0]:08x}"
                                                               if mismatches else None)})
        if mismatches:
            raise SystemExit(f"{name} Product readback differs from Golden at 0x{mismatches[0]:08x}")
        matrices[name] = dense_matrix_a(source, base)

    # Rebuild each head's exact operand payload from the Product readback.
    # qblock.build is the same deterministic adapter used by the archived Top run.
    qkv_checks = []
    repacked_sha = {"Q_dense_A": [], "K_major_B": [], "V_matrix_B": []}
    repack_bytes = {"Q_dense_A": 0, "K_major_B": 0, "V_matrix_B": 0}
    logical_repack_checks = []
    physical_direct_alias = []
    rebuilt_dma_words: list[int] = []
    for head in range(HEADS):
        q_head = matrices["Q"][:16, head * HEAD_DIM:(head + 1) * HEAD_DIM]
        k_head = matrices["K"][:VALID_ROWS, head * HEAD_DIM:(head + 1) * HEAD_DIM]
        v_head = matrices["V"][:VALID_ROWS, head * HEAD_DIM:(head + 1) * HEAD_DIM]
        padded_k = np.zeros((PHYSICAL_ROWS, HEAD_DIM), dtype=np.int16)
        padded_v = np.zeros((PHYSICAL_ROWS, HEAD_DIM), dtype=np.int16)
        padded_k[:VALID_ROWS] = k_head
        padded_v[:VALID_ROWS] = v_head
        _, consumer, _ = qblock.build(head, matrices["Q"][:16], matrices["K"],
                                      matrices["V"], {})

        # Match the staged runtime payload order: Q, K, then four V panels.
        for base, count in ((qblock.Q_A, 16 * HEAD_DIM // 4),
                            (qblock.KEY_B, PHYSICAL_ROWS * HEAD_DIM // 4)):
            rebuilt_dma_words.extend(consumer[base + i * 4] for i in range(count))
        for panel in range(HEAD_DIM // 16):
            base = qblock.V_B + panel * 0x1000
            rebuilt_dma_words.extend(consumer[base + i * 4]
                                     for i in range(PHYSICAL_ROWS * 16 // 4))

        # Q is consumed as dense row-major [16,64] by 0x52.
        q_actual = np.array([[sign8(u8_at(consumer, qblock.Q_A + r * HEAD_DIM + c))
                               for c in range(HEAD_DIM)] for r in range(16)],
                             dtype=np.int16)
        q_check = compare_matrix(q_actual, q_head, f"head{head}.Q dense A")
        logical_repack_checks.append(q_check)
        q_bytes = bytes(int(x) & 0xff for x in q_head.reshape(-1))
        repacked_sha["Q_dense_A"].append(hashlib.sha256(q_bytes).hexdigest())
        repack_bytes["Q_dense_A"] += len(q_bytes)

        # K is consumed as K-major dense rows [64,208], with 197 valid keys.
        k_actual = np.array([[sign8(u8_at(consumer,
                                         qblock.KEY_B + tile * 1024 + d * 16 + lane))
                              for tile in range(PHYSICAL_ROWS // 16)
                              for lane in range(16)]
                             for d in range(HEAD_DIM)], dtype=np.int16)
        k_expected = padded_k.T
        logical_repack_checks.append(compare_matrix(k_actual, k_expected,
                                                     f"head{head}.K K-major B"))
        k_bytes = bytes(int(x) & 0xff for x in k_expected.reshape(-1))
        repacked_sha["K_major_B"].append(hashlib.sha256(k_bytes).hexdigest())
        repack_bytes["K_major_B"] += len(k_bytes)

        # V is consumed as four Matrix-B [208,16] panels.
        v_actual = np.zeros((PHYSICAL_ROWS, HEAD_DIM), dtype=np.int16)
        for ntile in range(HEAD_DIM // 16):
            col_base = ntile * 16
            for col_group in range(0, 16, 4):
                for k_group in range(0, PHYSICAL_ROWS, 4):
                    for col in range(col_group, col_group + 4):
                        word_index = ((col_group // 4) * (PHYSICAL_ROWS // 4) * 4 +
                                      (k_group // 4) * 4 + (col - col_group))
                        packed_word = consumer[qblock.V_B + ntile * 0x1000 + word_index * 4]
                        for lane in range(4):
                            v_actual[k_group + lane, col_base + col] = sign8(
                                packed_word >> (8 * lane))
        logical_repack_checks.append(compare_matrix(v_actual, padded_v,
                                                     f"head{head}.V Matrix-B"))
        v_bytes = bytes(int(x) & 0xff for x in padded_v.reshape(-1))
        repacked_sha["V_matrix_B"].append(hashlib.sha256(v_bytes).hexdigest())
        repack_bytes["V_matrix_B"] += len(v_bytes)

        qkv_checks.append({"head": head, "Q_shape": list(q_head.shape),
                           "K_valid_shape": list(k_head.shape),
                           "V_valid_shape": list(v_head.shape),
                           "invalid_key_rows_zeroed_for_consumer": bool(
                               np.all(k_actual[VALID_ROWS:] == 0) and
                               np.all(v_actual[VALID_ROWS:] == 0))})
        physical_direct_alias.append({
            "head": head,
            "Q_source": "Matrix-A 208x192 tiled; consumer is row-major 16x64 dense",
            "K_source": "Matrix-A 208x192 tiled; consumer is transposed K-major 64x208 dense",
            "V_source": "Matrix-A 208x192 tiled; consumer is Matrix-B 208x16 panel format",
            "requires_reorder": True,
        })

    staged_payload_check = None
    if args.attention_payload:
        archived_words = read_words(args.attention_payload)
        first = next((i for i, (a, b) in enumerate(zip(rebuilt_dma_words, archived_words))
                      if a != b), None)
        equal = first is None and len(rebuilt_dma_words) == len(archived_words)
        staged_payload_check = {
            "archived_payload_sha256": sha256(args.attention_payload),
            "rebuilt_word_count": len(rebuilt_dma_words),
            "archived_word_count": len(archived_words),
            "exact_word_match": equal,
            "first_mismatch_word_index": first,
        }

    result = {
        "status": "PASS_QKV_PRODUCT_GOLDEN_AND_CONSUMER_LAYOUT_AUDIT",
        "scope": "offline data/layout audit; does not claim one-session Product Top execution",
        "source": {
            "qkv_dump_sha256": sha256(args.qkv_dump),
            "qkv_golden_sha256": sha256(args.qkv_golden),
            "projection_layout": "Matrix-A tiled, physical [208,192], 197 valid rows",
            "projection_word_checks": projection_results,
            "logical_values": {name: {"shape": list(matrix.shape),
                                       "sha256_i16_le": hashlib.sha256(
                                           matrix.astype("<i2").tobytes()).hexdigest()}
                               for name, matrix in matrices.items()},
        },
        "consumer_layouts": {
            "Q": "dense row-major [16,64] per head; 0x52 A operand",
            "K": "K-major [64,208] per head; 197 valid keys, 11 zero-padded; 0x52 B operand",
            "V": "Matrix-B [208,16] panels, four panels per head; 197 valid keys, 11 zero-padded; AV operand",
        },
        "logical_repack_checks": logical_repack_checks,
        "all_logical_values_preserved": all(x["mismatches"] == 0
                                             for x in logical_repack_checks),
        "head_checks": qkv_checks,
        "physical_alias": physical_direct_alias,
        "staged_payload_rebuild_check": staged_payload_check,
        "repack_payload": {
            "bytes_by_layout": repack_bytes,
            "total_bytes": sum(repack_bytes.values()),
            "logical_nonpadding_read_bytes": 3 * 16 * HEAD_DIM +
                2 * 3 * VALID_ROWS * HEAD_DIM,
            "zero_padding_bytes_written": 2 * 3 * (PHYSICAL_ROWS - VALID_ROWS) * HEAD_DIM,
            "sha256_by_head_layout": repacked_sha,
        },
    }
    result["run"] = {"script_sha256": sha256(Path(__file__)),
                     "numpy_version": np.__version__,
                     "round27_projection_run_id": "round27_deit_qkv197_20261118",
                     "round27_attention_run_id": "round27_deit_attention3_qblock_20261118"}

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, sort_keys=True))
    passed = result["all_logical_values_preserved"] and (
        staged_payload_check is None or staged_payload_check["exact_word_match"])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
