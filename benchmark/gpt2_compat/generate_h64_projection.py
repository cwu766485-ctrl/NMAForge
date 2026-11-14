#!/usr/bin/env python3
"""Build an executable H64 nonzero INT8 Matrix projection Top workload.

The 64-output projection is split into four legal 16x16 Matrix N tiles. Four
input rows are embedded; the remaining twelve physical rows are zero padded.
The generated workload is an actual ABI-v7 CMDQ image and is checked by Top.
"""
from __future__ import annotations
import argparse, hashlib, json, sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw/tools"))
sys.path.insert(0, str(ROOT / "dv/block/compute/matrix/ref"))
from cimforge_mapper import (Mapper, OP_GEMM, add_completion_order_chain,
    _pack_matrix_a_physical, _pack_matrix_b_physical, pack_i8)
from ai_a3_reference import gemm_i8_i32
from gpt2_compat_golden import make_model, sat_i8


def write_pairs(path: Path, pairs: dict[int, int]):
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, value & 0xffffffff))
    path.write_text("".join(f"{word & 0xffffffff:08x}\n" for word in words), encoding="ascii")


def generate(out: Path, seed: int = 20261114):
    tokens = [1, 7, 42, 3]
    model = make_model(seed)
    x4 = [sat_i8(model["embedding"][t].astype(np.int16) +
                 model["position"][i].astype(np.int16)).astype(int).tolist()
          for i, t in enumerate(tokens)]
    x16 = x4 + [[0] * 64 for _ in range(12)]
    weights = model["l0.q"]

    mapper = Mapper(128 * 1024)
    mapper.next_addr = 0x1000
    mapper.task_id = 0x7100
    a = mapper.tensor("h64_projection_input", (16, 64), "i8_packed", "matrix_a_tile",
                      _pack_matrix_a_physical(x16), initialized=True)
    outputs = []
    golden = {}
    all_macs = 0
    for tile in range(4):
        col0 = tile * 16
        b_rows = [[int(v) for v in row[col0:col0 + 16]] for row in weights]
        b = mapper.tensor(f"h64_projection_weight_n{tile}", (64, 16),
                          "i8_packed", "matrix_b_tile", _pack_matrix_b_physical(b_rows), initialized=True)
        dst = mapper.tensor(f"h64_projection_output_n{tile}", (16, 16),
                            "i32", "row-major", [0xA55AA55A] * 256, initialized=False)
        mapper.add(f"h64_projection_tile_n{tile}", OP_GEMM, a, dst, src1=b,
                   m=16, n=16, k_or_length=16, batch_count=1, head_count=1)
        outputs.append(dst)
        expected = gemm_i8_i32(x16, b_rows)
        for row in range(16):
            for col in range(16):
                golden[dst.addr + 4 * (row * 16 + col)] = expected[row][col] & 0xffffffff
        all_macs += 16 * 16 * 64

    add_completion_order_chain(mapper, event_bit=0)
    desc_base = 0x8000
    cpl_base = 0x9000
    mapper.check_queues(desc_base, cpl_base)
    image: dict[int, int] = {}
    for tensor in mapper.tensors.values():
        for index, value in enumerate(tensor.values):
            if tensor.dtype == "i8_packed":
                image[tensor.addr + index * 4] = int(value) & 0xffffffff
            else:
                image[tensor.addr + index * 4] = int(value) & 0xffffffff
    for index, desc in enumerate(mapper.descriptors):
        for word_index, value in enumerate(desc.words()):
            image[desc_base + index * 64 + word_index * 4] = value
        for word_index in range(4):
            image[cpl_base + index * 16 + word_index * 4] = 0xA55AA55A

    out.mkdir(parents=True, exist_ok=True)
    write_pairs(out / "model_memory.memh", image)
    write_pairs(out / "model_golden.memh", golden)
    manifest = {
        "model_scope": "H64 Q projection, four nonzero 16x16 Matrix N tiles",
        "seed": seed, "input_tokens": tokens, "descriptor_abi": "v7.4",
        "descriptor_bytes": 64, "descriptor_base": desc_base,
        "completion_base": cpl_base, "descriptor_count": len(mapper.descriptors),
        "useful_macs": all_macs, "matrix_shape_per_descriptor": {"M":16,"N":16,"K":64,"k_words":16},
        "input_address": a.addr, "input_bytes": 16*64,
        "output_ranges": [{"start":t.addr,"end_exclusive":t.addr+16*16*4} for t in outputs],
        "weight_ranges": [{"start":t.addr,"end_exclusive":t.addr+64*16} for t in mapper.tensors.values() if "weight_" in t.name],
        "spad_capacity_bytes": 131072, "high_water_bytes": cpl_base + 128*16,
        "golden_words": len(golden), "golden_hash": hashlib.sha256((out/"model_golden.memh").read_bytes()).hexdigest(),
        "memory_hash": hashlib.sha256((out/"model_memory.memh").read_bytes()).hexdigest(),
        "rtl_execution": "READY_FOR_REPRESENTATIVE_TOP",
        "limitations": ["Four of sixteen input rows carry nonzero tokens; twelve are legal zero padding.",
                         "This tests one H64 Q projection only, not attention, decoder block, or four-layer inference.",
                         "Weights are deterministic pseudo-weights, not pretrained model weights."],
        "descriptor_contract": [{"task_id":d.task_id,"opcode":d.op,"src0":d.src0,"src1":d.src1,"dst":d.dst,"m":d.m,"n":d.n,"k_words":d.k_or_length,"wait_mask":d.wait_mask,"signal_mask":d.signal_mask,"clear_mask":d.clear_mask} for d in mapper.descriptors],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("H64_PROJECTION_GENERATOR_PASS descriptors=4 shape=16x16x64 golden_words=%d high_water=%d" % (len(golden), manifest["high_water_bytes"]))
    return manifest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261114)
    args = ap.parse_args()
    generate(args.out, args.seed)


if __name__ == "__main__": main()
