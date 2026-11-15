#!/usr/bin/env python3
"""Generate a real H64 FFN-up/down, GELU and residual Product-Top workload.

This is deliberately a tile-level Round 5 experiment.  Four model rows are
carried in a legal 16x16 Matrix tile; the remaining rows are zero padding.
Input, descriptors, and streamed weight tiles are live in the external DMA
image. Output tensors remain poison until the real Product Top executes.
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
    Mapper, OP_GELU, OP_GEMM, OP_REQUANT, OP_RESIDUAL, FLAG_PACK_I8,
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


def tensor_lifetime_manifest(mapper: Mapper, desc_base: int, cpl_base: int) -> list[dict]:
    """Derive storage and command lifetime from the allocator and ABI descriptors."""
    last_descriptor = len(mapper.descriptors) - 1
    records: list[dict] = []
    for tensor in mapper.tensors.values():
        size = len(tensor.values) * 4
        start, end = tensor.addr, tensor.addr + size
        if size <= 0 or start < 0 or end > mapper.capacity_bytes:
            raise ValueError(f"{tensor.name}: invalid allocated interval [{start:#x},{end:#x})")
        if start % 16:
            raise ValueError(f"{tensor.name}: tensor start is not 16-byte aligned")
        producers = [i for i, d in enumerate(mapper.descriptors)
                     if start <= d.dst < end]
        consumers = [i for i, d in enumerate(mapper.descriptors)
                     if any(start <= address < end for address in (d.src0, d.src1, d.bias))]
        live_start = 0 if tensor.initialized else (min(producers) if producers else 0)
        live_end = max(consumers + producers, default=live_start)
        first_consumer = min(consumers, default=None)
        initialized_before_first_read = bool(
            tensor.initialized or
            (producers and first_consumer is not None and min(producers) < first_consumer)
        )
        records.append({
            "name": tensor.name, "start": start, "end_exclusive": end,
            "alignment": 16, "size_bytes": size,
            "live_start_descriptor": live_start,
            "live_end_descriptor": live_end,
            "producer": [mapper.descriptors[i].name for i in producers] or ["DMA/fixture"],
            "consumer": [mapper.descriptors[i].name for i in consumers],
            "read_owner": [mapper.descriptors[i].name for i in consumers],
            "write_owner": [mapper.descriptors[i].name for i in producers] or ["DMA/fixture"],
            "initialized_before_first_read": initialized_before_first_read,
            "initialized_by_dma_or_fixture": bool(tensor.initialized),
            "reuse_eligible_after_descriptor": live_end if live_end < last_descriptor else None,
        })

    records.extend([
        {"name": "CMDQ", "start": desc_base,
         "end_exclusive": desc_base + len(mapper.descriptors) * 64,
         "alignment": 64, "size_bytes": len(mapper.descriptors) * 64,
         "live_start_descriptor": 0, "live_end_descriptor": last_descriptor,
         "producer": ["DMA/fixture"], "consumer": ["Product Top descriptor fetch"],
         "read_owner": ["Product Top descriptor fetch"], "write_owner": ["DMA/fixture"],
         "initialized_before_first_read": True, "initialized_by_dma_or_fixture": True,
         "reuse_eligible_after_descriptor": last_descriptor},
        {"name": "CPLQ", "start": cpl_base,
         "end_exclusive": cpl_base + len(mapper.descriptors) * 16,
         "alignment": 16, "size_bytes": len(mapper.descriptors) * 16,
         "live_start_descriptor": 0, "live_end_descriptor": last_descriptor,
         "producer": ["Product Top completion writer"], "consumer": ["testbench completion checker"],
         "read_owner": ["testbench completion checker"], "write_owner": ["Product Top completion writer"],
         "initialized_before_first_read": True, "initialized_by_dma_or_fixture": True,
         "reuse_eligible_after_descriptor": last_descriptor},
    ])

    for index, left in enumerate(records):
        if left["start"] < 0 or left["end_exclusive"] > mapper.capacity_bytes:
            raise ValueError(f"{left['name']}: allocation exceeds SPAD bounds")
        if left["start"] % left["alignment"]:
            raise ValueError(f"{left['name']}: allocation alignment violation")
        for right in records[index + 1:]:
            address_overlap = left["start"] < right["end_exclusive"] and right["start"] < left["end_exclusive"]
            lifetime_overlap = left["live_start_descriptor"] <= right["live_end_descriptor"] and right["live_start_descriptor"] <= left["live_end_descriptor"]
            if address_overlap and lifetime_overlap:
                raise ValueError(f"live allocation alias: {left['name']} / {right['name']}")
    for record in records:
        if not record["initialized_before_first_read"] and record["consumer"]:
            raise ValueError(f"{record['name']}: read before producer/initialization")
    return records


def generate(out: Path, seed: int = 20261115) -> dict:
    del seed  # The deterministic tile is intentionally stable for replay.
    rows = [
        [3, -2, 1, 4] * 16,
        [-1, 2, -3, 1] * 16,
        [2, 1, -2, -1] * 16,
        [-3, 0, 2, 3] * 16,
    ]
    x16 = rows + [[0] * 64 for _ in range(12)]
    mapper = Mapper(CAPACITY)
    mapper.next_addr = 0x4000
    mapper.task_id = 0x7100
    input_t = mapper.tensor(
        "h64_ffn_input_i8", (16, 64), "i8_packed", "matrix_a_tile",
        _pack_matrix_a_physical(x16), initialized=True,
    )
    tile_records = []
    all_up: list[list[int]] = []
    all_gelu: list[list[int]] = []
    all_i8: list[list[int]] = []
    for tile in range(16):
        col0 = tile * 16
        weight = [[((r * 5 + c * 3 + tile * 7) % 9) - 4
                   for c in range(col0, col0 + 16)] for r in range(64)]
        weight_t = mapper.tensor(
            f"h64_ffn_up_weight_n{tile}_i8", (64, 16), "i8_packed",
            "matrix_b_tile", _pack_matrix_b_physical(weight), initialized=True,
        )
        up_t = mapper.tensor(f"h64_ffn_up_n{tile}_i32", (16, 16), "i32",
                             "row-major", [POISON] * 256, initialized=False)
        gelu_t = mapper.tensor(f"h64_ffn_gelu_n{tile}_i32", (16, 16), "i32",
                               "row-major", [POISON] * 256, initialized=False)
        out_t = mapper.tensor(f"h64_ffn_gelu_n{tile}_i8", (16, 16), "i8_packed",
                              "matrix_a_tile", [POISON] * 64, initialized=False)
        mapper.add(f"h64_ffn_up_n{tile}", OP_GEMM, input_t, up_t, src1=weight_t,
                   m=16, n=16, k_or_length=16, batch_count=1, head_count=1)
        mapper.add(f"h64_ffn_gelu_n{tile}", OP_GELU, up_t, gelu_t,
                   m=16, n=16, k_or_length=256, aux0=1)
        mapper.add(f"h64_ffn_gelu_requant_n{tile}", OP_REQUANT, gelu_t, out_t,
                   m=16, n=16, k_or_length=256,
                   flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        up = gemm_i8_i32(x16, weight)
        gelu = [[gelu_q8_8(value) for value in row] for row in up]
        output_i8 = [requant_i8(row, 0) for row in gelu]
        tile_records.append((weight_t, up_t, gelu_t, out_t, weight))
        all_up.append(up)
        all_gelu.append(gelu)
        all_i8.append(output_i8)
    down_acc = mapper.tensor(
        "h64_ffn_down_output_16x64_i32", (16, 64), "i32", "row-major",
        [POISON] * (16 * 64), initialized=False,
    )
    down_partial = mapper.tensor(
        "h64_ffn_down_partial_reused_16x64_i32", (16, 64), "i32", "row-major",
        [POISON] * (16 * 64), initialized=False,
    )
    residual_source = mapper.tensor(
        "h64_ffn_residual_source_i32", (16, 64), "i32", "row-major",
        [value for row in x16 for value in row], initialized=True,
    )
    residual2 = mapper.tensor(
        "h64_ffn_residual2_output_16x64_i32", (16, 64), "i32", "row-major",
        [POISON] * (16 * 64), initialized=False,
    )
    down_acc_golden = [[0 for _ in range(64)] for _ in range(16)]
    last_partial_golden = [[0 for _ in range(64)] for _ in range(16)]
    for tile in range(16):
        down_weight = [[((r * 3 + c * 5 + tile * 11) % 7) - 3
                        for c in range(64)] for r in range(16)]
        down_weight_t = mapper.tensor(
            f"h64_ffn_down_weight_k{tile}_i8", (16, 64), "i8_packed",
            "matrix_b_tile", _pack_matrix_b_physical(down_weight), initialized=True,
        )
        partial_dst = down_acc if tile == 0 else down_partial
        mapper.add(f"h64_ffn_down_k{tile}", OP_GEMM,
                   tile_records[tile][3], partial_dst, src1=down_weight_t,
                   m=16, n=64, k_or_length=4, batch_count=1, head_count=1)
        partial = gemm_i8_i32(all_i8[tile], down_weight)
        last_partial_golden = partial
        for row in range(16):
            for col in range(64):
                down_acc_golden[row][col] += partial[row][col]
        if tile > 0:
            mapper.add(f"h64_ffn_down_accumulate_k{tile}", OP_RESIDUAL,
                       down_acc, down_acc, src1=down_partial,
                       k_or_length=16 * 64, aux0=1)
    mapper.add("h64_ffn_residual2", OP_RESIDUAL, down_acc, residual2,
               src1=residual_source, k_or_length=16 * 64, aux0=1)
    add_completion_order_chain(mapper)

    desc_base = 0x1000
    cpl_base = 0x2400
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

    golden: dict[int, int] = {}
    for tile, (_, up_t, gelu_t, out_t, _) in enumerate(tile_records):
        for row in range(16):
            for col in range(16):
                golden[up_t.addr + 4 * (row * 16 + col)] = all_up[tile][row][col] & 0xFFFFFFFF
                golden[gelu_t.addr + 4 * (row * 16 + col)] = all_gelu[tile][row][col] & 0xFFFFFFFF
        packed = _pack_matrix_a_physical(all_i8[tile])
        for index, value in enumerate(packed):
            golden[out_t.addr + index * 4] = value
    for row in range(16):
        for col in range(64):
            value = down_acc_golden[row][col]
            offset = 4 * (row * 64 + col)
            golden[down_acc.addr + offset] = value & 0xFFFFFFFF
            golden[residual2.addr + offset] = (value + x16[row][col]) & 0xFFFFFFFF
            golden[down_partial.addr + offset] = last_partial_golden[row][col] & 0xFFFFFFFF

    out.mkdir(parents=True, exist_ok=True)
    write_pairs(out / "model_memory.memh", image)
    write_pairs(out / "model_golden.memh", golden)
    lifetime_records = tensor_lifetime_manifest(mapper, desc_base, cpl_base)
    manifest = {
        "model_scope": "H64 FFN 64->256->64, sixteen 16-channel Up tiles, GELU, packed Requant, K-tiled Down and Residual 2",
        "descriptor_abi": "v7.4", "descriptor_bytes": 64,
        "descriptor_base": desc_base, "completion_base": cpl_base,
        "descriptor_count": len(mapper.descriptors), "input_tokens": 4,
        "shape": {"physical_m": 16, "useful_m": 4, "hidden": 64, "tile_n": 16},
        "executed_macs": 16 * 16 * 64 * 16 * 2,
        "useful_macs": 4 * 256 * 64 * 2,
        "padding_macs": (16 - 4) * 256 * 64 * 2,
        "physical_output_elements": 16 * 16 * 16 + 16 * 64,
        "useful_output_elements": 4 * (256 + 64),
        "spad_capacity_bytes": CAPACITY,
        "tensor_ranges": lifetime_records,
        "planned_downstream_ranges": [],
        "allocation_checks": {"bounds": "PASS", "alignment": "PASS",
                              "live_alias": "PASS", "initialized_reads": "PASS"},
        "dma_dependency": "external payload -> DMA done/status -> CMDQ doorbell",
        "dma_plan_source": "benchmark/representative/prepare_cnn_dma_payload.py",
        "numeric_contract": {
            "input": "signed INT8, scale 1.0",
            "weights": "signed INT8, scale 1.0",
            "matrix_accumulation": "signed INT32 exact ordered sum; Up K=64, Down K=16 partials accumulated by ordered INT32 Residual without intermediate quantization",
            "gelu_input_output": "signed Q8.8 integer contract from ai_a3_reference.gelu_q8_8",
            "requant": "arithmetic right shift by 0 then clamp to [-128,127]",
            "rounding": "no rounding offset; arithmetic shift/truncation as RTL contract",
            "saturation": "signed INT8 clamp at packed Requant boundary",
        },
        "golden_words": len(golden),
        "golden_sha256": hashlib.sha256((out / "model_golden.memh").read_bytes()).hexdigest(),
        "memory_sha256": hashlib.sha256((out / "model_memory.memh").read_bytes()).hexdigest(),
        "rtl_execution": "READY_FOR_REPRESENTATIVE_TOP_DMA",
        "limitations": [
            "FFN input is deterministic signed INT8 fixture data, not Round 4 Attention plus LayerNorm 2 output; this is not a full Decoder Block run.",
            "KV cache, four layers and persistent decode are not run.",
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
    print("H64_FFN_GENERATOR_PASS up_tiles=16 down_k_tiles=16 descriptors=%d golden_words=%d useful_macs=%d executed_macs=%d padding_macs=%d high_water=%d" %
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
