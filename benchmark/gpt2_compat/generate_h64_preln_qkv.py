#!/usr/bin/env python3
"""Generate a real-top H64 embedding-add, LayerNorm, and Q/K/V workload."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw/tools"))
sys.path.insert(0, str(ROOT / "dv/block/compute/matrix/ref"))
from cimforge_mapper import (  # noqa: E402
    FLAG_BIAS, FLAG_PACK_I8, FLAG_PACK_I8_TILE_A, Mapper, OP_CAUSAL_SOFTMAX,
    OP_GEMM, OP_LAYERNORM, OP_REQUANT, OP_RESIDUAL,
    _pack_matrix_a_physical, _pack_matrix_b_physical,
    add_completion_order_chain,
)
from ai_a3_reference import (  # noqa: E402
    gemm_i8_i32, layernorm_q15, requant_i8, softmax_q15,
)
from gpt2_compat_golden import make_model  # noqa: E402

TOKENS = [1, 7, 42, 3]
ROWS = 16
HIDDEN = 64


def s32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, value & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words),
                     encoding="ascii")


def generate(out: Path, seed: int = 20261114, include_attention: bool = False) -> dict:
    model = make_model(seed)
    mapper = Mapper(128 * 1024)
    mapper.next_addr = 0x1000
    mapper.task_id = 0x7100

    embedding = np.zeros((ROWS, HIDDEN), dtype=np.int32)
    position = np.zeros((ROWS, HIDDEN), dtype=np.int32)
    for row, token in enumerate(TOKENS):
        embedding[row] = model["embedding"][token].astype(np.int32)
        position[row] = model["position"][row].astype(np.int32)
    combined = embedding + position
    embedding_t = mapper.tensor("embedding_lookup_i32", (ROWS, HIDDEN), "i32",
                                "row-major", embedding.reshape(-1).tolist())
    position_t = mapper.tensor("position_i32", (ROWS, HIDDEN), "i32",
                               "row-major", position.reshape(-1).tolist())
    combined_t = mapper.tensor("embedding_plus_position_i32", (ROWS, HIDDEN), "i32",
                               "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
    mapper.add("embedding_position_residual", OP_RESIDUAL, embedding_t, combined_t,
               src1=position_t, k_or_length=ROWS * HIDDEN, aux0=1)

    gamma_values = [32768] * HIDDEN
    beta_values = [0] * HIDDEN
    gamma_t = mapper.tensor("ln1_gamma_q15", (HIDDEN,), "i32", "row-major", gamma_values)
    beta_t = mapper.tensor("ln1_beta_i32", (HIDDEN,), "i32", "row-major", beta_values)
    norm_t = mapper.tensor("preln_output_i32", (ROWS, HIDDEN), "i32", "row-major",
                           [0xA55AA55A] * (ROWS * HIDDEN), False)
    combined_rows = combined.reshape(ROWS, HIDDEN)
    norm = np.zeros_like(combined_rows)
    for row in range(ROWS):
        mapper.add(f"preln_row{row}", OP_LAYERNORM, combined_t, norm_t,
                   src1=gamma_t, bias=beta_t, k_or_length=HIDDEN,
                   flags=FLAG_BIAS, aux0=1,
                   src0_offset=row * HIDDEN * 4,
                   dst_offset=row * HIDDEN * 4)
        norm[row] = layernorm_q15(combined_rows[row].tolist(), gamma_values, beta_values)

    packed_values = _pack_matrix_a_physical(
        [[max(-128, min(127, int(value))) for value in row] for row in norm]
    )
    packed_t = mapper.tensor("preln_matrix_a_i8", (ROWS, HIDDEN), "i8_packed",
                             "matrix_a_tile", [0xA55AA55A] * len(packed_values), False)
    mapper.add("preln_requant_pack_matrix_a", OP_REQUANT, norm_t, packed_t,
               m=ROWS, n=HIDDEN, k_or_length=ROWS * HIDDEN,
               flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)

    projection_golden: dict[int, int] = {}
    projection_tiles = {}
    for projection in ("q", "k", "v"):
        weights = model[f"l0.{projection}"].astype(np.int32)
        for tile in range(4):
            col0 = tile * 16
            b_rows = weights[:, col0:col0 + 16].tolist()
            weight_words = _pack_matrix_b_physical(b_rows)
            weight_t = mapper.tensor(f"l0_{projection}_weight_n{tile}",
                                     (HIDDEN, 16), "i8_packed", "matrix_b_tile",
                                     weight_words)
            tile_t = mapper.tensor(f"l0_{projection}_out_n{tile}",
                                  (ROWS, 16), "i32", "row-major",
                                  [0xA55AA55A] * (ROWS * 16), False)
            mapper.add(f"l0_{projection}_gemm_n{tile}", OP_GEMM,
                       packed_t, tile_t, src1=weight_t,
                       m=ROWS, n=16, k_or_length=HIDDEN // 4, aux0=1)
            tile_result = gemm_i8_i32(
                [[max(-128, min(127, int(value))) for value in row] for row in norm], b_rows)
            for row in range(ROWS):
                for col in range(16):
                    projection_golden[tile_t.addr + 4 * (row * 16 + col)] = \
                        tile_result[row][col] & 0xFFFFFFFF
            projection_tiles[(projection, tile)] = tile_t

    attention_golden: dict[int, int] = {}
    attention_macs = 0
    if include_attention:
        norm_i8 = [[max(-128, min(127, int(value))) for value in row]
                   for row in norm]
        head_prob8: dict[int, list[list[int]]] = {}
        head_v8: dict[int, list[list[int]]] = {}
        for head in range(4):
            q_raw, k_raw = projection_tiles[("q", head)], projection_tiles[("k", head)]
            q_values, k_values = [], []
            for row in range(ROWS):
                q_values.append(requant_i8([
                    s32(projection_golden[q_raw.addr + 4 * (row * 16 + col)])
                    for col in range(16)], 0))
                k_values.append(requant_i8([
                    s32(projection_golden[k_raw.addr + 4 * (row * 16 + col)])
                    for col in range(16)], 0))

            q8_t = mapper.tensor(f"attn_q_h{head}_i8", (ROWS, 16), "i8_packed",
                                 "matrix_a_tile", [0xA55AA55A] * 64, False)
            k8_t = mapper.tensor(f"attn_k_h{head}_i8", (ROWS, 16), "i8_packed",
                                 "matrix_a_tile", [0xA55AA55A] * 64, False)
            mapper.add(f"attn_q_h{head}_requant", OP_REQUANT, q_raw, q8_t,
                       m=ROWS, n=16, k_or_length=ROWS * 16,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
            mapper.add(f"attn_k_h{head}_requant", OP_REQUANT, k_raw, k8_t,
                       m=ROWS, n=16, k_or_length=ROWS * 16,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)

            scores = gemm_i8_i32(q_values, [list(row) for row in zip(*k_values)], shift=2)
            score_t = mapper.tensor(f"attn_h{head}_scores_q8_8", (ROWS, ROWS), "i32",
                                    "row-major", [0xA55AA55A] * (ROWS * ROWS), False)
            mapper.add(f"attn_h{head}_qkt_scaled", OP_GEMM, q8_t, score_t,
                       src1=k8_t, m=ROWS, n=ROWS, k_or_length=4,
                       shift=2, aux0=1)
            for row in range(ROWS):
                for col in range(ROWS):
                    attention_golden[score_t.addr + 4 * (row * ROWS + col)] = \
                        scores[row][col] & 0xFFFFFFFF

            prob_init = [0xA55AA55A] * (ROWS * ROWS)
            for row in range(len(TOKENS), ROWS):
                prob_init[row * ROWS:(row + 1) * ROWS] = [0] * ROWS
            prob_t = mapper.tensor(f"attn_h{head}_prob_q15", (ROWS, ROWS), "i32",
                                   "row-major", prob_init, True)
            probs = [[0] * ROWS for _ in range(ROWS)]
            for row in range(len(TOKENS)):
                mapper.add(f"attn_h{head}_causal_softmax_t{row}",
                           OP_CAUSAL_SOFTMAX, score_t, prob_t,
                           k_or_length=ROWS, aux0=row,
                           src0_offset=row * ROWS * 4,
                           dst_offset=row * ROWS * 4)
                masked = [scores[row][col] if col <= row else -(1 << 31)
                          for col in range(ROWS)]
                probs[row] = softmax_q15(masked)
                for col in range(ROWS):
                    attention_golden[prob_t.addr + 4 * (row * ROWS + col)] = \
                        probs[row][col]

            p8 = [requant_i8(row, 8) for row in probs]
            p8_t = mapper.tensor(f"attn_h{head}_prob_i8", (ROWS, ROWS), "i8_packed",
                                 "matrix_a_tile", [0xA55AA55A] * 64, False)
            mapper.add(f"attn_h{head}_prob_requant", OP_REQUANT, prob_t, p8_t,
                       m=ROWS, n=ROWS, k_or_length=ROWS * ROWS,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                       shift=8, aux0=1)
            head_prob8[head] = p8

            v_weights = model["l0.v"].astype(np.int32)[:, head * 16:(head + 1) * 16]
            v_weight_transpose = v_weights.T.tolist()
            v_weight_t = mapper.tensor(f"attn_h{head}_vt_weight_a", (16, HIDDEN),
                                       "i8_packed", "matrix_a_tile",
                                       _pack_matrix_a_physical(v_weight_transpose))
            vt_t = mapper.tensor(f"attn_h{head}_vt_i32", (16, ROWS), "i32",
                                 "row-major", [0xA55AA55A] * (16 * ROWS), False)
            mapper.add(f"attn_h{head}_vt_projection", OP_GEMM,
                       v_weight_t, vt_t, src1=packed_t,
                       m=16, n=ROWS, k_or_length=HIDDEN // 4, aux0=1)
            vt = gemm_i8_i32(v_weight_transpose,
                             [list(row) for row in zip(*norm_i8)])
            for row in range(16):
                for col in range(ROWS):
                    attention_golden[vt_t.addr + 4 * (row * ROWS + col)] = \
                        vt[row][col] & 0xFFFFFFFF
            vt_i8 = [requant_i8(row, 0) for row in vt]
            v8_t = mapper.tensor(f"attn_h{head}_v_matrix_b", (ROWS, 16),
                                 "i8_packed", "matrix_b_tile",
                                 [0xA55AA55A] * 64, False)
            mapper.add(f"attn_h{head}_v_requant_b", OP_REQUANT,
                       vt_t, v8_t, m=16, n=ROWS,
                       k_or_length=ROWS * 16,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                       shift=0, aux0=1)
            head_v8[head] = [list(row) for row in zip(*vt_i8)]
            packed_v = _pack_matrix_a_physical(vt_i8)
            for word, value in enumerate(packed_v):
                attention_golden[v8_t.addr + word * 4] = value & 0xFFFFFFFF

        merged_t = mapper.tensor("attention_concat_i8", (ROWS, HIDDEN),
                                 "i8_packed", "matrix_a_tile",
                                 [0xA55AA55A] * (ROWS * HIDDEN // 4), False)
        merged_i8 = [[0] * HIDDEN for _ in range(ROWS)]
        for head in range(4):
            av_t = mapper.tensor(f"attn_h{head}_av_i32", (ROWS, 16), "i32",
                                 "row-major", [0xA55AA55A] * (ROWS * 16), False)
            mapper.add(f"attn_h{head}_av_q15", OP_GEMM,
                       mapper.tensors[f"attn_h{head}_prob_i8"], av_t,
                       src1=mapper.tensors[f"attn_h{head}_v_matrix_b"],
                       m=ROWS, n=16, k_or_length=4, shift=7, aux0=1)
            av = gemm_i8_i32(head_prob8[head], head_v8[head], shift=7)
            for row in range(ROWS):
                for col in range(16):
                    attention_golden[av_t.addr + 4 * (row * 16 + col)] = \
                        av[row][col] & 0xFFFFFFFF
                    merged_i8[row][head * 16 + col] = max(-128, min(127, av[row][col]))
            for row_group in range(ROWS // 4):
                mapper.add(f"attn_h{head}_av_requant_concat_rg{row_group}",
                           OP_REQUANT, av_t, merged_t, m=4, n=16,
                           k_or_length=4 * 16,
                           flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                           shift=0, aux0=1,
                           src0_offset=row_group * 4 * 16 * 4,
                           dst_offset=(row_group * 64 + head * 16) * 4)
                packed_group = _pack_matrix_a_physical(
                    [row[head * 16:(head + 1) * 16]
                     for row in merged_i8[row_group * 4:(row_group + 1) * 4]],
                    physical_rows=4)
                for word, value in enumerate(packed_group):
                    address = merged_t.addr + (row_group * 64 + head * 16 + word) * 4
                    attention_golden[address] = value & 0xFFFFFFFF

        output_weights = model["l0.o"].astype(np.int32).tolist()
        output_weight_t = mapper.tensor(
            "attn_o_weight_n64", (HIDDEN, HIDDEN), "i8_packed", "matrix_b_tile",
            _pack_matrix_b_physical(output_weights))
        output_t = mapper.tensor("attn_output_i32", (ROWS, HIDDEN), "i32",
                                 "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
        mapper.add("attn_output_projection_n64", OP_GEMM,
                   merged_t, output_t, src1=output_weight_t,
                   m=ROWS, n=HIDDEN, k_or_length=HIDDEN // 4, aux0=1)
        output_result = gemm_i8_i32(merged_i8, output_weights)
        for row in range(ROWS):
            for col in range(HIDDEN):
                attention_golden[output_t.addr + 4 * (row * HIDDEN + col)] = \
                    output_result[row][col] & 0xFFFFFFFF

        residual1_t = mapper.tensor("residual1_i32", (ROWS, HIDDEN), "i32",
                                   "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
        mapper.add("attn_residual1", OP_RESIDUAL, combined_t, residual1_t,
                   src1=output_t, k_or_length=ROWS * HIDDEN, aux0=1)
        residual1 = np.zeros((ROWS, HIDDEN), dtype=np.int32)
        for row in range(ROWS):
            for col in range(HIDDEN):
                value = int(combined_rows[row, col]) + int(output_result[row][col])
                residual1[row, col] = np.int32(s32(value))
                attention_golden[residual1_t.addr + 4 * (row * HIDDEN + col)] = \
                    int(residual1[row, col]) & 0xFFFFFFFF

        norm2_t = mapper.tensor("ln2_output_i32", (ROWS, HIDDEN), "i32",
                                "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
        for row in range(ROWS):
            mapper.add(f"ln2_row{row}", OP_LAYERNORM, residual1_t, norm2_t,
                       src1=gamma_t, bias=beta_t, k_or_length=HIDDEN,
                       flags=FLAG_BIAS, aux0=1,
                       src0_offset=row * HIDDEN * 4,
                       dst_offset=row * HIDDEN * 4)
            norm2 = layernorm_q15(residual1[row].tolist(), gamma_values, beta_values)
            for col, value in enumerate(norm2):
                attention_golden[norm2_t.addr + 4 * (row * HIDDEN + col)] = \
                    int(value) & 0xFFFFFFFF
        attention_macs = 163840

    add_completion_order_chain(mapper, event_bit=0)
    desc_base, cpl_base = ((0x1A000, 0x1C000) if include_attention
                           else (0xC000, 0xD000))
    if mapper.next_addr > desc_base:
        raise ValueError("tensor allocations overlap the queue reservation")
    mapper.check_queues(desc_base, cpl_base)
    image: dict[int, int] = {}
    golden: dict[int, int] = dict(projection_golden)
    for row in range(ROWS):
        for col in range(HIDDEN):
            addr = embedding_t.addr + 4 * (row * HIDDEN + col)
            image[addr] = int(embedding[row, col]) & 0xFFFFFFFF
            image[position_t.addr + 4 * (row * HIDDEN + col)] = int(position[row, col]) & 0xFFFFFFFF
            golden[combined_t.addr + 4 * (row * HIDDEN + col)] = \
                int(combined_rows[row, col]) & 0xFFFFFFFF
            norm_addr = norm_t.addr + 4 * (row * HIDDEN + col)
            golden[norm_addr] = int(norm[row, col]) & 0xFFFFFFFF
    for tensor in mapper.tensors.values():
        if tensor.name in {embedding_t.name, position_t.name}:
            continue
        for index, value in enumerate(tensor.values):
            image[tensor.addr + index * 4] = int(value) & 0xFFFFFFFF
    for index, value in enumerate(packed_values):
        golden[packed_t.addr + index * 4] = int(value) & 0xFFFFFFFF
    for index, descriptor in enumerate(mapper.descriptors):
        for word_index, value in enumerate(descriptor.words()):
            image[desc_base + index * 64 + word_index * 4] = value
        for word_index in range(4):
            image[cpl_base + index * 16 + word_index * 4] = 0xA55AA55A

    out.mkdir(parents=True, exist_ok=True)
    write_pairs(out / "model_memory.memh", image)
    golden = dict(golden)
    golden.update(projection_golden)
    golden.update(attention_golden)
    write_pairs(out / "model_golden.memh", golden)
    executed_macs = 3 * ROWS * HIDDEN * HIDDEN + attention_macs
    useful_macs = 3 * len(TOKENS) * HIDDEN * HIDDEN + \
                  (34816 if include_attention else 0)
    manifest = {
        "scope": "Token embedding load + Position residual + H64 LayerNorm + Q/K/V projection" +
                 (" + four-head causal attention + output projection + Residual 1 + LayerNorm 2"
                  if include_attention else ""),
        "seed": seed, "tokens": TOKENS, "descriptor_abi": "v7.4",
        "descriptor_base": desc_base, "completion_base": cpl_base,
        "descriptor_count": len(mapper.descriptors), "golden_words": len(golden),
        "executed_macs": executed_macs, "useful_macs": useful_macs,
        "padding_macs": executed_macs - useful_macs,
        "useful_output_elements": 3 * len(TOKENS) * HIDDEN,
        "physical_output_elements": 3 * ROWS * HIDDEN,
        "golden_sha256": hashlib.sha256((out / "model_golden.memh").read_bytes()).hexdigest(),
        "memory_sha256": hashlib.sha256((out / "model_memory.memh").read_bytes()).hexdigest(),
        "spad_capacity_bytes": 131072,
        "high_water_bytes": max(image) + 4,
        "preload_mode": "host AXI-Lite fixture initialization; excluded from command_cycles",
        "formats": {"embedding_position": "signed INT32 container of selected INT8 values",
                    "LayerNorm gamma": "Q0.15 32768", "LayerNorm output": "INT32",
                    "Matrix input": "signed INT8 packed tile-A, arithmetic shift 0"},
        "descriptor_contract": [
            {"task_id": d.task_id, "opcode": d.op, "name": d.name,
             "src0": d.src0, "src1": d.src1, "dst": d.dst,
             "length": d.k_or_length, "m": d.m, "n": d.n,
             "flags": d.flags, "wait_mask": d.wait_mask,
             "signal_mask": d.signal_mask} for d in mapper.descriptors
        ],
        "tensor_allocations": [
            {"name": tensor.name, "start": tensor.addr,
             "end_exclusive": tensor.addr + len(tensor.values) * 4,
             "bytes": len(tensor.values) * 4, "shape": tensor.shape,
             "dtype": tensor.dtype, "layout": tensor.layout,
             "initialized": tensor.initialized}
            for tensor in mapper.tensors.values()
        ],
        "limitations": ["Selected token embedding rows are fixture-loaded; Top has no embedding lookup opcode.",
                        "Pseudo-weights are deterministic, not pretrained GPT-2 weights.",
                        "Only four nonzero token rows are executed in 16-row physical tiles."],
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"H64_PRELN_{'ATTENTION' if include_attention else 'QKV'}_GENERATOR_PASS desc={len(mapper.descriptors)} tokens={len(TOKENS)} "
          f"golden_words={len(golden)} high_water={manifest['high_water_bytes']}")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261114)
    parser.add_argument("--attention", action="store_true")
    args = parser.parse_args()
    generate(args.out, args.seed, args.attention)


if __name__ == "__main__":
    main()
