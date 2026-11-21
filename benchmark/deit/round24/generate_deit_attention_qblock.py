#!/usr/bin/env python3
"""Build one Product-Top DeiT attention query-block workload.

Q/K/V must be readbacks from the Round-24 Product Top projection run.  This
script performs only physical-layout conversion and independent integer
checking; QK, scaling, Softmax, probability quantization and AV are descriptors
executed by Product RTL.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
from cimforge_mapper import (  # noqa: E402
    Descriptor, OP_GEMM, OP_GEMV_KFOLD, OP_SOFTMAX, OP_REQUANT,
    FLAG_PACK_I8, FLAG_PACK_I8_TILE_A, DESC_VERSION,
    _pack_matrix_a_physical, _pack_matrix_b_physical,
)
from ai_a3_reference import softmax_q15  # noqa: E402

CAPACITY = 256 * 1024
QUEUE = 512
DESC_BASE = CAPACITY - QUEUE * 80
CPL_BASE = DESC_BASE + QUEUE * 64
HIDDEN, HEADS, DIM = 192, 3, 64
VALID, PHYSICAL, QUERIES = 197, 208, 16
Q_OUT, K_OUT, V_OUT = 0x16000, 0x18000, 0x22000
Q_A, KEY_B = 0x08000, 0x20000
SCORE, SCALED, PROB, PROB_A, V_B, AV = (
    0x10000, 0x14000, 0x18000, 0x1C000, 0x24000, 0x28000
)
ZERO_SRC = 0x2C000
POISON = 0xA55AA55A


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_dump(path: Path) -> dict[int, int]:
    out: dict[int, int] = {}
    for line in path.read_text().splitlines():
        lane, address, value = line.split()
        if lane not in ("A", "B"):
            raise ValueError(f"unknown lane {lane}")
        out[int(address, 16)] = int(value, 16)
    return out


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(x, 16) for x in path.read_text().splitlines() if x.strip()]
    count = words[0]
    if len(words) != 1 + 2 * count:
        raise ValueError(f"bad memory pairs {path}")
    return {words[1 + 2 * i]: words[2 + 2 * i] for i in range(count)}


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    with path.open("w", encoding="ascii") as f:
        f.write(f"{len(pairs):08x}\n")
        for a, v in sorted(pairs.items()):
            f.write(f"{a & 0xffffffff:08x}\n{v & 0xffffffff:08x}\n")


def sign8(v: int) -> int:
    v &= 255
    return v - 256 if v & 128 else v


def dense_tile_a(dump: dict[int, int], base: int, rows: int,
                 cols: int, physical_rows: int) -> np.ndarray:
    if rows > physical_rows or physical_rows % 16 or cols % 16:
        raise ValueError("invalid physical Matrix-A shape")
    out = np.zeros((physical_rows, cols), dtype=np.int16)
    ntiles = cols // 16
    for r in range(physical_rows):
        for c in range(cols):
            tile_base = base + ((r // 16) * ntiles + c // 16) * 256
            lr, lc = r & 15, c & 15
            wi = tile_base + ((lr // 4) * 16 + (lc // 4) * 4 + (lr & 3)) * 4
            if wi not in dump:
                raise ValueError(f"missing Product readback word 0x{wi:08x}")
            out[r, c] = sign8(dump[wi] >> ((lc & 3) * 8))
    return out[:rows]


def put_word(pairs: dict[int, int], addr: int, value: int) -> None:
    pairs[addr] = value & 0xffffffff


def put_bytes(pairs: dict[int, int], addr: int, values: list[int]) -> None:
    for i in range(0, len(values), 4):
        chunk = values[i:i + 4] + [0] * (4 - len(values[i:i + 4]))
        put_word(pairs, addr + i, sum((int(v) & 255) << (8 * lane)
                                      for lane, v in enumerate(chunk)))


def build(head: int, q: np.ndarray, k: np.ndarray, v: np.ndarray,
          base_pairs: dict[int, int]) -> tuple[list[Descriptor], dict[int, int], dict[int, int]]:
    qh = q[:, head * DIM:(head + 1) * DIM].astype(np.int64)
    kh = k[:, head * DIM:(head + 1) * DIM].astype(np.int64)
    vh = v[:, head * DIM:(head + 1) * DIM].astype(np.int64)
    # 0x52 A is dense [M,K] with a 16-byte-aligned K row stride.
    q_dense = np.zeros((QUERIES, DIM), dtype=np.int8)
    q_dense[:, :] = qh.astype(np.int8)
    pairs = dict(base_pairs)
    put_bytes(pairs, Q_A, q_dense.reshape(-1).astype(np.int16).tolist())

    # Opcode 0x52 consumes dense K-major B rows (16 bytes per K), unlike
    # Matrix GEMM's four-column physical B-tile order.
    for ktile in range(PHYSICAL // 16):
        n0 = ktile * 16
        panel = [[int(kh[n0 + nk, d]) if n0 + nk < VALID else 0
                  for nk in range(16)] for d in range(DIM)]
        for k_index, row in enumerate(panel):
            put_bytes(pairs, KEY_B + ktile * 1024 + k_index * 16, row)

    # Matrix-B V panels are [K=208,N=16], with invalid physical keys zeroed.
    for ntile in range(DIM // 16):
        n0 = ntile * 16
        panel = [[int(vh[r, n0 + c]) if r < VALID else 0
                  for c in range(16)] for r in range(PHYSICAL)]
        packed = _pack_matrix_b_physical(panel)
        for wi, word in enumerate(packed):
            put_word(pairs, V_B + ntile * 0x1000 + wi * 4, word)

    descriptors: list[Descriptor] = []
    golden: dict[int, int] = {}
    qk = qh @ kh[:VALID].T
    score_padded = np.zeros((QUERIES, PHYSICAL), dtype=np.int64)
    score_padded[:, :VALID] = qk
    scaled = score_padded >> 5  # (1/32^2)/sqrt(64), represented as Q8.8.
    prob = np.zeros((QUERIES, PHYSICAL), dtype=np.int64)
    for row in range(QUERIES):
        prob[row, :VALID] = softmax_q15([int(x) for x in scaled[row, :VALID]])
    prob_i8 = np.clip(prob >> 8, -128, 127).astype(np.int64)
    av_expected = prob_i8 @ np.pad(vh[:VALID], ((0, PHYSICAL - VALID), (0, 0)))

    # Each GEMV writes one contiguous 16-key stripe as signed INT32 Q8.8.
    # Matrix post-process shift preserves the score width; opcode 0x36 would
    # saturate to INT8 and is not a legal QK scaling operation.
    for row in range(QUERIES):
        for ktile in range(PHYSICAL // 16):
            index = len(descriptors)
            descriptors.append(Descriptor(
                name=f"deit_h{head}_q{row}_k{ktile}_qk",
                task_id=0x7100 + index, op=OP_GEMV_KFOLD,
                src0=Q_A + row * DIM, src1=KEY_B + ktile * 1024,
                dst=SCALED + (row * PHYSICAL + ktile * 16) * 4,
                m=1, n=16, k_or_length=DIM,
                batch_count=1, head_count=0, shift=5,
            ))

    for row in range(QUERIES):
        index = len(descriptors)
        descriptors.append(Descriptor(name=f"deit_h{head}_softmax_q{row}_197",
            task_id=0x7100 + index, op=OP_SOFTMAX, src1=0,
            src0=SCALED + row * PHYSICAL * 4,
            dst=PROB + row * PHYSICAL * 4, k_or_length=VALID))
        # Keep the Top smoke's output-poison precondition.  Clear invalid
        # physical lanes after the 197-key Softmax, so padding is never in its
        # normalization denominator and stale bytes cannot reach the AV pack.
        index = len(descriptors)
        descriptors.append(Descriptor(
            name=f"deit_h{head}_softmax_pad_zero_q{row}",
            task_id=0x7100 + index, op=OP_REQUANT,
            src0=ZERO_SRC + row * 16 * 4, src1=0,
            dst=PROB + (row * PHYSICAL + VALID) * 4,
            k_or_length=PHYSICAL - VALID, shift=0))
    index = len(descriptors)
    descriptors.append(Descriptor(name=f"deit_h{head}_prob_q15_to_matrix_a",
        task_id=0x7100 + index, op=OP_REQUANT, src0=PROB, src1=0, dst=PROB_A,
        m=QUERIES, n=PHYSICAL, k_or_length=QUERIES * PHYSICAL,
        flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=8))
    for ntile in range(DIM // 16):
        index = len(descriptors)
        descriptors.append(Descriptor(name=f"deit_h{head}_av_n{ntile}",
            task_id=0x7100 + index, op=OP_GEMM, src0=PROB_A,
            src1=V_B + ntile * 0x1000, dst=AV + ntile * 0x400,
            m=QUERIES, n=16, k_or_length=PHYSICAL // 4, aux0=1))

    if len(descriptors) != 245:
        raise AssertionError(f"expected 245 descriptors, got {len(descriptors)}")

    for r in range(QUERIES):
        for c in range(PHYSICAL):
            i = r * PHYSICAL + c
            put_word(golden, SCALED + i * 4, int(scaled[r, c]))
            put_word(golden, PROB + i * 4, int(prob[r, c]))
    prob_words = _pack_matrix_a_physical(prob_i8.tolist(), physical_rows=QUERIES)
    for i, word in enumerate(prob_words):
        put_word(golden, PROB_A + i * 4, word)
    for ntile in range(DIM // 16):
        for r in range(QUERIES):
            for c in range(16):
                put_word(golden, AV + ntile * 0x400 + (r * 16 + c) * 4,
                         int(av_expected[r, ntile * 16 + c]))

    # Explicitly poison every Golden output range before execution.
    for start, size in ((SCALED, QUERIES * PHYSICAL * 4),
                        (PROB, QUERIES * PHYSICAL * 4),
                        (PROB_A, QUERIES * PHYSICAL),
                        (AV, 4 * 0x400)):
        for addr in range(start, start + size, 4):
            pairs[addr] = POISON
    # Softmax writes only valid keys. The explicit post-Softmax descriptors
    # write zero into the physical padding before the full-width Matrix-A pack.
    for row in range(QUERIES):
        for col in range(16):
            put_word(pairs, ZERO_SRC + (row * 16 + col) * 4, 0)
    for i, desc in enumerate(descriptors):
        for wi, word in enumerate(desc.words()):
            put_word(pairs, DESC_BASE + i * 64 + wi * 4, word)
    for i in range(QUEUE * 4):
        put_word(pairs, CPL_BASE + i * 4, POISON)
    return descriptors, pairs, golden


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--head", type=int, required=True, choices=(0, 1, 2))
    ap.add_argument("--q-dump", type=Path, required=True)
    ap.add_argument("--kv-dump", type=Path, required=True)
    ap.add_argument("--projection-golden", type=Path, required=True)
    ap.add_argument("--projection-memory", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--stop-before-av", action="store_true",
                    help="emit a QK/Softmax/Probability-pack prefix for operand audit")
    ap.add_argument("--omit-av-golden", action="store_true",
                    help="run AV for output capture while leaving AV unchecked")
    args = ap.parse_args()

    qdump, kvdump = read_dump(args.q_dump), read_dump(args.kv_dump)
    projection_golden = read_pairs(args.projection_golden)
    for name, dump, base, words in (("Q", qdump, Q_OUT, 768),
                                    ("K", qdump, K_OUT, 9984),
                                    ("K", kvdump, K_OUT, 9984),
                                    ("V", kvdump, V_OUT, 9984)):
        if name == "K" and dump is qdump and base == K_OUT:
            pass
        mism = [(base + 4 * i, projection_golden.get(base + 4 * i),
                 dump.get(base + 4 * i)) for i in range(words)
                if projection_golden.get(base + 4 * i) != dump.get(base + 4 * i)]
        if mism:
            raise SystemExit(f"Product {name} readback differs from independent projection Golden: {mism[0]}")
    q = dense_tile_a(qdump, Q_OUT, QUERIES, HIDDEN, 16)
    k = dense_tile_a(kvdump, K_OUT, PHYSICAL, HIDDEN, PHYSICAL)
    v = dense_tile_a(kvdump, V_OUT, PHYSICAL, HIDDEN, PHYSICAL)
    if np.any(k[VALID:] != 0) or np.any(v[VALID:] != 0):
        # Fused Q/K/V projections of zero-padded LN rows include bias. Those
        # rows are not valid keys; the attention adapter masks them explicitly.
        pass
    descriptors, pairs, golden = build(args.head, q, k, v,
                                         read_pairs(args.projection_memory))
    if args.stop_before_av:
        # The final four descriptors consume the packed probabilities and V.
        # Run the prefix in Top to read back the exact operands before AV.
        descriptors = descriptors[:-4]
        golden = {addr: value for addr, value in golden.items() if addr < AV}
    elif args.omit_av_golden:
        golden = {addr: value for addr, value in golden.items() if addr < AV}
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out_dir / "model_memory.memh", pairs)
    write_pairs(args.out_dir / "model_golden.memh", golden)
    with (args.out_dir / "descriptors.memh").open("w", encoding="ascii") as f:
        for d in descriptors:
            f.write("\n".join(f"{w:08x}" for w in d.words()) + "\n")
    manifest = {
        "status": "DEIT_PRODUCT_ATTENTION_QBLOCK_WORKLOAD",
        "head": args.head, "query_rows": QUERIES, "valid_keys": VALID,
        "physical_keys": PHYSICAL, "head_dim": DIM,
        "projection_q_dump_sha256": sha(args.q_dump),
        "projection_kv_dump_sha256": sha(args.kv_dump),
        "projection_golden_sha256": sha(args.projection_golden),
        "descriptors": len(descriptors),
        "stop_before_av": args.stop_before_av,
        "omit_av_golden": args.omit_av_golden,
        "useful_macs": 2 * QUERIES * VALID * DIM + QUERIES * DIM * VALID,
        "softmax": {"opcode": "0x32", "length_per_query": VALID,
                    "domain": "Q8.8 log2", "score_right_shift": 5,
                    "padding_in_denominator": False},
        "spad": {"capacity_bytes": CAPACITY, "queue_entries": QUEUE,
                 "descriptor_base": DESC_BASE, "completion_base": CPL_BASE,
                 "allocation_high_water": 0x2C000 + QUERIES * 16 * 4,
                 "host_data_movement": "Q/K/V are prior Product Top readbacks; host only converts Matrix-A tiles into dense Q and Matrix-B panels; no QK/Softmax/AV values are host-filled"},
        "artifacts": {"memory_sha256": sha(args.out_dir / "model_memory.memh"),
                      "golden_sha256": sha(args.out_dir / "model_golden.memh")},
    }
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("DEIT_ATTENTION_QBLOCK_READY " + json.dumps(manifest, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
