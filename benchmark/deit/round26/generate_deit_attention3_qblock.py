#!/usr/bin/env python3
"""Build a three-head 16-query Product-Top attention workload.

Inputs are Q/K/V values read back from a previous real Product-Top projection
run.  Host code performs only physical repacking and builds the independent
integer checker; QK, Softmax, probability packing, and AV execute in Product
RTL.  The staged projection/attention runs are separate Top invocations.
"""
from __future__ import annotations

import argparse
import dataclasses
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
sys.path.insert(0, str(ROOT / "benchmark" / "deit" / "round25"))
from cimforge_mapper import Descriptor  # noqa: E402
import generate_deit_attention_qblock as qblock  # noqa: E402

CAPACITY = 256 * 1024
QUEUE = 768
DESC_BASE = 0x31000
CPL_BASE = 0x3D000
PHYSICAL = 208
HIDDEN = 192
HEADS = 3
DIM = 64
QUERIES = 16
VALID = 197
Q_BASES = [0x1000 + h * 0x400 for h in range(HEADS)]
KEY_BASES = [0x2000 + h * 0x3400 for h in range(HEADS)]
V_BASES = [0xC000 + h * 0x4000 for h in range(HEADS)]
SCRATCH_BASES = [0x18000 + h * 0x8500 for h in range(HEADS)]
ZERO_SRC = 0x1C00
POISON = 0xA55AA55A


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_dump(path: Path) -> dict[int, int]:
    out: dict[int, int] = {}
    for line in path.read_text().splitlines():
        lane, address, value = line.split()
        # The dump contains separate AXI readback windows labelled A/B.  Keep
        # both windows, but ignore uninitialized words outside the Q/K/V
        # output ranges; every required projection address is checked below.
        if lane not in ("A", "B"):
            continue
        if any(c.lower() not in "0123456789abcdef" for c in value):
            continue
        out[int(address, 16)] = int(value, 16)
    return out


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(x, 16) for x in path.read_text().splitlines() if x.strip()]
    count = words[0]
    if len(words) != 1 + 2 * count:
        raise ValueError(f"bad pair image: {path}")
    return {words[1 + 2 * i]: words[2 + 2 * i] for i in range(count)}


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    with path.open("w", encoding="ascii") as f:
        f.write(f"{len(pairs):08x}\n")
        for a, v in sorted(pairs.items()):
            f.write(f"{a & 0xffffffff:08x}\n{v & 0xffffffff:08x}\n")


def write_words(path: Path, words: list[int]) -> None:
    path.write_text("".join(f"{w & 0xffffffff:08x}\n" for w in words),
                    encoding="ascii")


def extract_words(pairs: dict[int, int], base: int, count: int) -> list[int]:
    missing = [base + 4 * i for i in range(count) if base + 4 * i not in pairs]
    if missing:
        raise ValueError(f"packed operand has missing word 0x{missing[0]:08x}")
    return [pairs[base + 4 * i] for i in range(count)]


def map_desc(desc: Descriptor, head: int, global_index: int) -> Descriptor:
    name = desc.name
    sb = SCRATCH_BASES[head]
    changes: dict[str, int] = {"task_id": 0x7100 + global_index,
                               "name": f"round26_{name}"}
    if "_q" in name and name.endswith("_qk"):
        changes.update(src0=Q_BASES[head] + desc.src0 - qblock.Q_A,
                       src1=KEY_BASES[head] + desc.src1 - qblock.KEY_B,
                       dst=sb + desc.dst - qblock.SCALED)
    elif "_softmax_q" in name:
        changes.update(src0=sb + desc.src0 - qblock.SCALED,
                       dst=sb + 0x3400 + desc.dst - qblock.PROB)
    elif "_softmax_pad_zero" in name:
        changes.update(src0=ZERO_SRC + desc.src0 - qblock.ZERO_SRC,
                       dst=sb + 0x3400 + desc.dst - qblock.PROB)
    elif name.endswith("_prob_q15_to_matrix_a"):
        changes.update(src0=sb + 0x3400 + desc.src0 - qblock.PROB,
                       dst=sb + 0x6800 + desc.dst - qblock.PROB_A)
    elif "_av_n" in name:
        changes.update(src0=sb + 0x6800 + desc.src0 - qblock.PROB_A,
                       src1=V_BASES[head] + desc.src1 - qblock.V_B,
                       dst=sb + 0x7500 + desc.dst - qblock.AV)
    else:
        raise ValueError(f"unrecognized descriptor {name}")
    return dataclasses.replace(desc, **changes)


def append_dma_events(payload: list[int], events: list[tuple[int, int, int, int]],
                      words: list[int], dst: int, trigger: int,
                      event_chunk_words: int = 256) -> None:
    start = len(payload)
    payload.extend(words)
    for offset in range(0, len(words), event_chunk_words):
        count = min(event_chunk_words, len(words) - offset)
        events.append((trigger, (start + offset) * 4, dst + offset * 4, count))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--qkv-dump", type=Path, required=True)
    ap.add_argument("--qkv-golden", type=Path, required=True)
    ap.add_argument("--block", type=int, default=0, choices=range(13))
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()

    dump = read_dump(args.qkv_dump)
    golden_qkv = read_pairs(args.qkv_golden)
    # Three full physical projection matrices are checked against the original
    # independent QKV Golden before any operand is repacked for attention.
    projection_bytes = PHYSICAL * HIDDEN
    outputs = {"query": (0x16000, projection_bytes),
               "key": (0x20000, projection_bytes),
               "value": (0x2A000, projection_bytes)}
    matrices: dict[str, np.ndarray] = {}
    for name, (base, size) in outputs.items():
        mismatches = [(base + 4 * i, golden_qkv.get(base + 4 * i),
                       dump.get(base + 4 * i))
                      for i in range(size // 4)
                      if golden_qkv.get(base + 4 * i) != dump.get(base + 4 * i)]
        if mismatches:
            raise SystemExit(f"Product {name} projection Golden mismatch: {mismatches[0]}")
        matrix = qblock.dense_tile_a(dump, base, PHYSICAL, HIDDEN, PHYSICAL)
        matrices[name] = matrix

    qmat = matrices["query"]
    kmat = matrices["key"]
    vmat = matrices["value"]
    query_rows = qmat[args.block * QUERIES:(args.block + 1) * QUERIES]
    if query_rows.shape != (QUERIES, HIDDEN):
        raise SystemExit("invalid query block")

    descriptors: list[Descriptor] = []
    golden: dict[int, int] = {}
    payload: list[int] = []
    dma_events: list[tuple[int, int, int, int]] = []
    empty: dict[int, int] = {}
    for head in range(HEADS):
        before = len(descriptors)
        ds, local_pairs, local_golden = qblock.build(
            head, query_rows, kmat, vmat, empty)
        if len(ds) != 245:
            raise AssertionError(f"head {head}: expected 245 descriptors, got {len(ds)}")
        descriptors.extend(map_desc(d, head, before + i) for i, d in enumerate(ds))

        # Product Q/K/V readback is repacked to the documented GEMV/Matrix-B
        # physical layouts, then fetched through real AXI DMA/Fence in Top.
        append_dma_events(payload, dma_events,
                          extract_words(local_pairs, qblock.Q_A, 16 * DIM // 4),
                          Q_BASES[head], before)
        append_dma_events(payload, dma_events,
                          extract_words(local_pairs, qblock.KEY_B, PHYSICAL * DIM // 4),
                          KEY_BASES[head], before)
        for ntile in range(DIM // 16):
            panel = qblock.V_B + ntile * 0x1000
            words = extract_words(local_pairs, panel, PHYSICAL * 16 // 4)
            append_dma_events(payload, dma_events, words,
                              V_BASES[head] + ntile * 0x1000, before)

        sb = SCRATCH_BASES[head]
        for address, value in local_golden.items():
            if qblock.SCALED <= address < qblock.SCALED + QUERIES * PHYSICAL * 4:
                target = sb + address - qblock.SCALED
            elif qblock.PROB <= address < qblock.PROB + QUERIES * PHYSICAL * 4:
                target = sb + 0x3400 + address - qblock.PROB
            elif qblock.PROB_A <= address < qblock.PROB_A + QUERIES * PHYSICAL:
                target = sb + 0x6800 + address - qblock.PROB_A
            elif qblock.AV <= address < qblock.AV + 4 * 0x400:
                target = sb + 0x7500 + address - qblock.AV
            else:
                raise ValueError(f"unexpected Golden address 0x{address:08x}")
            if target in golden:
                raise AssertionError(f"Golden address overlap at 0x{target:08x}")
            golden[target] = value

    if len(descriptors) != 735 or len(dma_events) != 90:
        raise AssertionError(f"plan mismatch descriptors={len(descriptors)} DMA={len(dma_events)}")
    if len(payload) != 20736:
        raise AssertionError(f"payload mismatch words={len(payload)}")
    if [event[0] for event in dma_events] != sorted(event[0] for event in dma_events):
        raise AssertionError("DMA events not monotonic")

    data_high = SCRATCH_BASES[-1] + 0x8500
    if data_high != 0x30F00 or data_high > DESC_BASE:
        raise AssertionError(f"data/queue overlap: high=0x{data_high:x}")
    pairs: dict[int, int] = {}
    # Pad source is zero-initialized and its 16-word rows are shared by heads.
    for i in range(16 * 16):
        pairs[ZERO_SRC + i * 4] = 0
    # Operand destinations and outputs start poisoned so absent writes are
    # observable. DMA overwrites Q/K/V before the corresponding descriptors.
    for base, size in [(b, 16 * DIM) for b in Q_BASES] + \
                      [(b, PHYSICAL * DIM) for b in KEY_BASES] + \
                      [(b, 4 * 0x1000) for b in V_BASES]:
        for addr in range(base, base + size, 4):
            pairs[addr] = POISON
    for base in SCRATCH_BASES:
        for offset, size in ((0, QUERIES * PHYSICAL * 4),
                             (0x3400, QUERIES * PHYSICAL * 4),
                             (0x6800, QUERIES * PHYSICAL),
                             (0x7500, 4 * 0x400)):
            for addr in range(base + offset, base + offset + size, 4):
                pairs[addr] = POISON
    for i, desc in enumerate(descriptors):
        for wi, word in enumerate(desc.words()):
            pairs[DESC_BASE + i * 64 + wi * 4] = word
    for i in range(QUEUE * 4):
        pairs[CPL_BASE + i * 4] = POISON

    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out_dir / "model_memory.memh", pairs)
    write_pairs(args.out_dir / "model_golden.memh", golden)
    write_words(args.out_dir / "dma_payload.memh", payload)
    plan = [len(dma_events)]
    for event in dma_events:
        plan.extend(event)
    write_words(args.out_dir / "late_dma_plan.memh", plan)
    manifest = {
        "status": "DEIT_THREE_HEAD_PRODUCT_ATTENTION_QBLOCK",
        "qkv_dump_sha256": sha(args.qkv_dump),
        "qkv_golden_sha256": sha(args.qkv_golden),
        "block": args.block,
        "shape": {"heads": HEADS, "query_valid": max(0, min(QUERIES, VALID - args.block * QUERIES)),
                  "query_physical": QUERIES, "key_valid": VALID,
                  "key_physical": PHYSICAL, "head_dim": DIM},
        "descriptors": len(descriptors),
        "dma_events": len(dma_events),
        "dma_payload_bytes": len(payload) * 4,
        "useful_macs_qk_plus_av": 2 * HEADS * QUERIES * VALID * DIM,
        "executed_array_macs": 2 * HEADS * QUERIES * PHYSICAL * DIM,
        "padding_macs": 2 * HEADS * QUERIES * (PHYSICAL - VALID) * DIM,
        "softmax": {"opcode": "0x32", "length": VALID,
                    "valid_keys_share_one_normalization": True,
                    "physical_padding_in_denominator": False},
        "staging": "Q/K/V are Product Top readbacks, Golden-checked before host layout conversion; QK, Softmax, probability pack, and AV all run in Product RTL. Projection and attention are separate Top invocations.",
        "spad": {"capacity_bytes": CAPACITY, "queue_entries": QUEUE,
                 "descriptor_base": DESC_BASE, "completion_base": CPL_BASE,
                 "data_high_water": data_high,
                 "query_bases": Q_BASES, "key_bases": KEY_BASES,
                 "value_bases": V_BASES, "scratch_bases": SCRATCH_BASES,
                 "zero_source": ZERO_SRC},
        "artifacts": {name: sha(args.out_dir / name) for name in
                      ("model_memory.memh", "model_golden.memh", "dma_payload.memh", "late_dma_plan.memh")},
    }
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("DEIT_ATTENTION3_QBLOCK_READY " + json.dumps(manifest, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
