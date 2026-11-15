#!/usr/bin/env python3
"""Generate one real H64 FFN-up/GELU/requant Product-Top tile.

This is deliberately a tile-level Round 5 experiment.  Four model rows are
carried in a legal 16x16 Matrix tile; the remaining rows are zero padding.
Input, descriptors, and the streamed weight tile are all live in the external
DMA image.  Output tensors remain poison until the real Product Top executes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw/tools"))
sys.path.insert(0, str(ROOT / "dv/block/compute/matrix/ref"))
from cimforge_mapper import (  # noqa: E402
    Mapper, OP_GELU, OP_GEMM, OP_REQUANT, FLAG_PACK_I8,
    FLAG_PACK_I8_TILE_A, add_completion_order_chain, _pack_matrix_a_physical,
    _pack_matrix_b_physical,
)
from ai_a3_reference import gemm_i8_i32, gelu_q8_8, requant_i8  # noqa: E402

POISON = 0xA55AA55A
CAPACITY = 128 * 1024


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, value & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words), encoding="ascii")


def generate(out: Path, seed: int = 20261115) -> dict:
    del seed  # The deterministic tile is intentionally stable for replay.
    rows = [
        [3, -2, 1, 4] * 16,
        [-1, 2, -3, 1] * 16,
        [2, 1, -2, -1] * 16,
        [-3, 0, 2, 3] * 16,
    ]
    x16 = rows + [[0] * 64 for _ in range(12)]
    # Small signed weights keep the Q8.8 GELU path in both positive and
    # negative regions while remaining easy to audit independently.
    weight = [[((r * 5 + c * 3) % 9) - 4 for c in range(16)] for r in range(64)]

    mapper = Mapper(CAPACITY)
    mapper.next_addr = 0x2000
    mapper.task_id = 0x7100
    input_t = mapper.tensor(
        "h64_ffn_input_i8", (16, 64), "i8_packed", "matrix_a_tile",
        _pack_matrix_a_physical(x16), initialized=True,
    )
    weight_t = mapper.tensor(
        "h64_ffn_up_weight_tile_i8", (64, 16), "i8_packed", "matrix_b_tile",
        _pack_matrix_b_physical(weight), initialized=True,
    )
    up_t = mapper.tensor("h64_ffn_up_i32", (16, 16), "i32", "row-major",
                         [POISON] * 256, initialized=False)
    gelu_t = mapper.tensor("h64_ffn_gelu_i32", (16, 16), "i32", "row-major",
                           [POISON] * 256, initialized=False)
    out_t = mapper.tensor("h64_ffn_gelu_i8", (16, 16), "i8_packed",
                          "matrix_a_tile", [POISON] * 64, initialized=False)
    down_weight = [[((r * 7 + c * 2) % 7) - 3 for c in range(16)] for r in range(16)]
    down_weight_t = mapper.tensor(
        "h64_ffn_down_weight_tile_i8", (16, 16), "i8_packed", "matrix_b_tile",
        _pack_matrix_b_physical(down_weight), initialized=True,
    )
    down_t = mapper.tensor("h64_ffn_down_i32", (16, 16), "i32", "row-major",
                           [POISON] * 256, initialized=False)
    residual_base = [[value for value in row[:16]] for row in x16]
    residual_base_t = mapper.tensor(
        "h64_residual1_tile_i32", (16, 16), "i32", "row-major",
        [value for row in residual_base for value in row], initialized=True,
    )
    residual2_t = mapper.tensor("h64_ffn_residual2_i32", (16, 16), "i32",
                               "row-major", [POISON] * 256, initialized=False)

    mapper.add("h64_ffn_up_tile", OP_GEMM, input_t, up_t, src1=weight_t,
               m=16, n=16, k_or_length=16, batch_count=1, head_count=1)
    mapper.add("h64_ffn_gelu_tile", OP_GELU, up_t, gelu_t,
               m=16, n=16, k_or_length=256, aux0=1)
    mapper.add("h64_ffn_gelu_requant_tile", OP_REQUANT, gelu_t, out_t,
               m=16, n=16, k_or_length=256,
               flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
    mapper.add("h64_ffn_down_tile", OP_GEMM, out_t, down_t, src1=down_weight_t,
               m=16, n=16, k_or_length=4, batch_count=1, head_count=1)
    mapper.add("h64_ffn_residual2_tile", 0x34, down_t, residual2_t,
               src1=residual_base_t, k_or_length=256, aux0=1)
    add_completion_order_chain(mapper)

    desc_base = 0x1000
    cpl_base = 0x1800
    mapper.check_queues(desc_base, cpl_base)
    image: dict[int, int] = {}
    for tensor in mapper.tensors.values():
        for index, value in enumerate(tensor.values):
            image[tensor.addr + index * 4] = int(value) & 0xFFFFFFFF
    for index, desc in enumerate(mapper.descriptors):
        for word_index, value in enumerate(desc.words()):
            image[desc_base + index * 64 + word_index * 4] = value
        for word_index in range(4):
            image[cpl_base + index * 16 + word_index * 4] = POISON

    up = gemm_i8_i32(x16, weight)
    gelu = [[gelu_q8_8(value) for value in row] for row in up]
    output_i8 = [requant_i8(row, 0) for row in gelu]
    down = gemm_i8_i32(output_i8, down_weight)
    residual2 = [[down[row][col] + residual_base[row][col]
                  for col in range(16)] for row in range(16)]
    golden: dict[int, int] = {}
    for row in range(16):
        for col in range(16):
            golden[up_t.addr + 4 * (row * 16 + col)] = up[row][col] & 0xFFFFFFFF
            golden[gelu_t.addr + 4 * (row * 16 + col)] = gelu[row][col] & 0xFFFFFFFF
    packed = _pack_matrix_a_physical(output_i8)
    for index, value in enumerate(packed):
        golden[out_t.addr + index * 4] = value
    for row in range(16):
        for col in range(16):
            golden[down_t.addr + 4 * (row * 16 + col)] = down[row][col] & 0xFFFFFFFF
            golden[residual2_t.addr + 4 * (row * 16 + col)] = residual2[row][col] & 0xFFFFFFFF

    out.mkdir(parents=True, exist_ok=True)
    write_pairs(out / "model_memory.memh", image)
    write_pairs(out / "model_golden.memh", golden)
    manifest = {
        "model_scope": "H64 FFN up/down 16-channel tile + GELU + Residual 2",
        "descriptor_abi": "v7.4", "descriptor_bytes": 64,
        "descriptor_base": desc_base, "completion_base": cpl_base,
        "descriptor_count": len(mapper.descriptors), "input_tokens": 4,
        "shape": {"physical_m": 16, "useful_m": 4, "hidden": 64, "tile_n": 16},
        "executed_macs": 16 * 16 * (64 + 16),
        "useful_macs": 4 * 16 * (64 + 16),
        "padding_macs": 12 * 16 * (64 + 16),
        "physical_output_elements": 16 * 16,
        "useful_output_elements": 4 * 16,
        "spad_capacity_bytes": CAPACITY,
        "tensor_ranges": [
            {"name": input_t.name, "start": input_t.addr, "end_exclusive": input_t.addr + 1024,
             "live": "input through GEMM"},
            {"name": weight_t.name, "start": weight_t.addr, "end_exclusive": weight_t.addr + 1024,
             "live": "DMA completion through GEMM"},
            {"name": up_t.name, "start": up_t.addr, "end_exclusive": up_t.addr + 1024,
             "live": "GEMM completion through GELU"},
            {"name": gelu_t.name, "start": gelu_t.addr, "end_exclusive": gelu_t.addr + 1024,
             "live": "GELU completion through Requant"},
            {"name": out_t.name, "start": out_t.addr, "end_exclusive": out_t.addr + 256,
             "live": "Requant completion"},
            {"name": "CMDQ", "start": desc_base, "end_exclusive": desc_base + 3 * 64,
             "live": "command issue"},
            {"name": "CPLQ", "start": cpl_base, "end_exclusive": cpl_base + 3 * 16,
             "live": "retirement"},
        ],
        "dma_dependency": "external payload -> DMA done/status -> CMDQ doorbell",
        "dma_plan_source": "benchmark/representative/prepare_cnn_dma_payload.py",
        "golden_words": len(golden),
        "golden_sha256": hashlib.sha256((out / "model_golden.memh").read_bytes()).hexdigest(),
        "memory_sha256": hashlib.sha256((out / "model_memory.memh").read_bytes()).hexdigest(),
        "rtl_execution": "READY_FOR_REPRESENTATIVE_TOP_DMA",
        "limitations": [
            "One 16-channel FFN up/down tile only; full 256-wide FFN, KV cache and four layers are not run.",
            "Weight is deterministic signed INT8 research data, not a pretrained checkpoint.",
            "DMA setup and completion are explicit in the Product-Top testbench; no new product dependency opcode is added.",
        ],
        "descriptor_contract": [
            {"task_id": d.task_id, "opcode": d.op, "src0": d.src0, "src1": d.src1,
             "dst": d.dst, "m": d.m, "n": d.n, "length": d.k_or_length,
             "wait_mask": d.wait_mask, "signal_mask": d.signal_mask,
             "clear_mask": d.clear_mask} for d in mapper.descriptors
        ],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("H64_FFN_TILE_GENERATOR_PASS descriptors=%d golden_words=%d useful_macs=%d executed_macs=%d padding_macs=%d high_water=%d" %
          (len(mapper.descriptors), len(golden), manifest["useful_macs"],
           manifest["executed_macs"], manifest["padding_macs"],
           max(r["end_exclusive"] for r in manifest["tensor_ranges"])))
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261115)
    args = parser.parse_args()
    generate(args.out, args.seed)


if __name__ == "__main__":
    main()
