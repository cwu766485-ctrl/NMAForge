#!/usr/bin/env python3
"""Generate staged Top-CMDQ material for true H16 incremental KV decode.

Tokens 0..3 populate KV through the product 0x43 engine. Tokens 4..7 are
host-supplied token IDs; each token's Q/K/V, attention, residual, LayerNorm,
and FFN tensors are produced and checked by Top RTL before the next stage.
This is a synthetic projection task, not a language model.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
sys.path.insert(0, str(ROOT / "dv" / "block" / "compute" / "matrix" / "ref"))

from cimforge_mapper import (  # noqa: E402
    DESC_VERSION, FLAG_BIAS, FLAG_PACK_I8, FLAG_PACK_I8_TILE_A,
    OP_CAUSAL_SOFTMAX, OP_GELU, OP_GEMM,
    OP_KV_READ, OP_KV_WRITE, OP_LAYERNORM, OP_REQUANT, OP_RESIDUAL,
    OP_GEMV_KFOLD,
    Mapper, Tensor, _pack_matrix_a_physical, _pack_matrix_b_physical,
    pack_i8, tensor_storage_words,
)
from ai_a3_reference import (  # noqa: E402
    gelu_q8_8, gemm_i8_i32, layernorm_q15, requant_i8, residual_i32,
    softmax_q15,
)

POISON = 0xA55AA55A
MASK32 = 0xFFFFFFFF
DESC_BASE_GUARD = 0x1000
CPL_OFFSET = 0x4000
KV_FLAG_MATRIX_B_APPEND = 0x01


def u32(value: int) -> int:
    return value & MASK32


def flatten(matrix: list[list[int]]) -> list[int]:
    return [item for row in matrix for item in row]


def transpose(matrix: list[list[int]]) -> list[list[int]]:
    return [list(col) for col in zip(*matrix)]


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for addr, value in sorted(pairs.items()):
        words.extend((addr, u32(value)))
    path.write_text("".join(f"{word & MASK32:08x}\n" for word in words),
                    encoding="ascii")


def add_i32(golden: dict[int, int], tensor: Tensor,
            matrix: list[list[int]]) -> None:
    for row, values in enumerate(matrix):
        for col, value in enumerate(values):
            golden[tensor.addr + 4 * (row * len(values) + col)] = u32(value)


def add_i32_prefix(golden: dict[int, int], tensor: Tensor,
                   values: list[int]) -> None:
    for index, value in enumerate(values):
        golden[tensor.addr + index * 4] = u32(value)


def add_i8_tile_a(golden: dict[int, int], tensor: Tensor,
                  matrix: list[list[int]]) -> None:
    words = _pack_matrix_a_physical(matrix, physical_rows=len(matrix))
    for index, word in enumerate(words):
        golden[tensor.addr + index * 4] = u32(word)


def empty_i32(mapper: Mapper, name: str, rows: int, cols: int,
              *, row0_poison_only: bool = False) -> Tensor:
    values = [POISON] * (rows * cols)
    if row0_poison_only:
        values[cols:] = [0] * ((rows - 1) * cols)
    return mapper.tensor(name, (rows, cols), "i32", "row-major", values,
                         initialized=True)


def empty_i8_tile(mapper: Mapper, name: str, rows: int, cols: int) -> Tensor:
    if rows % 4 or cols % 4:
        raise ValueError(f"{name}: Matrix-A tile dimensions must be 4-aligned")
    return mapper.tensor(name, (rows, cols), "i8_packed", "matrix_a_tile",
                         [POISON] * (rows * cols // 4), initialized=True)


def cache_words(rows_by_token: list[list[int]], *, key_layout: bool) -> list[int]:
    """Pack key as B[feature,token], value as B[token,feature]."""
    if len(rows_by_token) != 8 or any(len(row) != 8 for row in rows_by_token):
        raise ValueError("KV cache must be eight tokens by eight features")
    matrix = transpose(rows_by_token) if key_layout else rows_by_token
    return _pack_matrix_b_physical(matrix)


def descriptor_manifest(desc) -> dict[str, int | str]:
    return {
        "name": desc.name, "task_id": desc.task_id, "opcode": desc.op,
        "src0": desc.src0, "src1": desc.src1, "bias": desc.bias,
        "dst": desc.dst, "m": desc.m, "n": desc.n,
        "k_or_length": desc.k_or_length, "flags": desc.flags,
        "aux0": desc.aux0, "shift": desc.shift, "activation": desc.activation,
        "src0_stride": desc.src0_stride, "src1_stride": desc.src1_stride,
        "dst_stride": desc.dst_stride, "wait_mask": desc.wait_mask,
        "signal_mask": desc.signal_mask, "clear_mask": desc.clear_mask,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--projection-policy", choices=("gemm", "gemv_qkv"),
                        default="gemm")
    args = parser.parse_args()

    model_bytes = args.model.read_bytes()
    model = json.loads(model_bytes)
    if model.get("shape") != {
        "hidden": 16, "attention_heads": 2, "head_dim": 8,
        "layers": 1, "sequence_length": 8, "dtype": "signed INT8",
    }:
        raise ValueError("model must be H16, two heads, one layer, INT8")
    weights = model.get("weights", {})
    required = {"wq", "wk", "wv", "wo", "wup", "wdown"}
    if not required.issubset(weights):
        raise ValueError(f"model weights missing {sorted(required - set(weights))}")
    for name in required:
        matrix = weights[name]
        if (len(matrix) != 16 or any(len(row) != 16 for row in matrix) or
                any(not isinstance(x, int) or not -128 <= x <= 127
                    for row in matrix for x in row)):
            raise ValueError(f"{name}: expected 16x16 signed INT8 matrix")
    embeddings = model.get("embeddings")
    if len(embeddings) != 16 or any(len(row) != 16 for row in embeddings):
        raise ValueError("expected a 16x16 token embedding table")
    prefill_tokens = model.get("prefill_tokens", [])[:4]
    decode_tokens = model.get("incremental_decode_tokens",
                              model.get("prefill_tokens", [])[4:8])
    if (len(prefill_tokens) != 4 or len(decode_tokens) != 4 or
            any(not isinstance(t, int) or not 0 <= t < 16
                for t in prefill_tokens + decode_tokens)):
        raise ValueError("need four prefill and four incremental token IDs")
    gamma1 = model.get("gamma1_q15", [32768] * 16)
    beta1 = model.get("beta1", [0] * 16)
    gamma2 = model.get("gamma2_q15", [32768] * 16)
    beta2 = model.get("beta2", [0] * 16)

    mapper = Mapper()
    mapper.next_addr = 0x4000
    mapper.task_id = 0x7200
    stage_descs: list[tuple[str, list, dict[int, int], set[int], dict]] = []
    stage_index = 0

    weights_b: dict[tuple[str, int], Tensor] = {}
    for proj in ("q", "k", "v"):
        for head in range(2):
            panel = [row[head * 8:(head + 1) * 8] for row in weights[f"w{proj}"]]
            weights_b[(proj, head)] = mapper.tensor(
                f"weight_{proj}_head{head}", (16, 8), "i8_packed",
                "matrix_b_tile", _pack_matrix_b_physical(panel),
            )
    gemv_weights_b: dict[tuple[str, int], Tensor] = {}
    if args.projection_policy == "gemv_qkv":
        for proj in ("q", "k", "v"):
            for head in range(2):
                panel = [row[head * 8:(head + 1) * 8]
                         for row in weights[f"w{proj}"]]
                words = []
                for row in panel:
                    padded = row + [0] * 8
                    words.extend(pack_i8(padded[i:i + 4])
                                 for i in range(0, 16, 4))
                gemv_weights_b[(proj, head)] = mapper.tensor(
                    f"gemv_weight_{proj}_head{head}", (16 * 16,),
                    "i8_packed", "gemv_k_major_n16", words,
                )

    wo_b: dict[int, Tensor] = {}
    for head in range(2):
        panel = [row[:] for row in weights["wo"][head * 8:(head + 1) * 8]]
        wo_b[head] = mapper.tensor(
            f"weight_wo_head{head}", (8, 16), "i8_packed",
            "matrix_b_tile", _pack_matrix_b_physical(panel),
        )
    wup_b = mapper.tensor("weight_wup", (16, 16), "i8_packed",
                          "matrix_b_tile", _pack_matrix_b_physical(weights["wup"]))
    wdown_b = mapper.tensor("weight_wdown", (16, 16), "i8_packed",
                            "matrix_b_tile", _pack_matrix_b_physical(weights["wdown"]))
    gamma1_t = mapper.tensor("gamma1_q15", (16,), "i32", "vector", gamma1)
    beta1_t = mapper.tensor("beta1", (16,), "i32", "vector", beta1)
    gamma2_t = mapper.tensor("gamma2_q15", (16,), "i32", "vector", gamma2)
    beta2_t = mapper.tensor("beta2", (16,), "i32", "vector", beta2)
    key_cache = mapper.tensor("key_cache", (128,), "i8_packed",
                              "matrix_b_cache", [0] * 32, initialized=True)
    value_cache = mapper.tensor("value_cache", (128,), "i8_packed",
                                "matrix_b_cache", [0] * 32, initialized=True)
    key_state = [[[0] * 8 for _ in range(8)] for _ in range(2)]
    value_state = [[[0] * 8 for _ in range(8)] for _ in range(2)]

    def new_stage(name: str) -> tuple[int, dict[int, int], set[int]]:
        nonlocal stage_index
        mapper.task_id = 0x7200 + stage_index * 0x100
        return len(mapper.descriptors), {}, set()

    def output_i32(name: str, matrix: list[list[int]], golden: dict[int, int],
                   poison: set[int]) -> Tensor:
        tensor = empty_i32(mapper, name, len(matrix), len(matrix[0]))
        add_i32(golden, tensor, matrix)
        poison.update(tensor.addr + 4 * i for i in range(len(matrix) * len(matrix[0])))
        return tensor

    def project(
        stage_name: str, proj: str, head: int, lhs: Tensor,
        input_rows: list[list[int]], golden: dict[int, int], poison: set[int],
        *, gemv_lhs: Tensor | None = None, use_gemv: bool = False,
    ) -> tuple[Tensor, Tensor, list[list[int]]]:
        rhs = weights_b[(proj, head)]
        matrix = [row[head * 8:(head + 1) * 8] for row in weights[f"w{proj}"]]
        result = gemm_i8_i32(input_rows, matrix)
        if use_gemv:
            if gemv_lhs is None:
                raise ValueError("GEMV projection requires dense single-token A")
            raw = mapper.tensor(
                f"{stage_name}_{proj}_h{head}_i32", (4, 8), "i32", "row-major",
                [POISON] * 8 + [0] * 24, initialized=True,
            )
            mapper.add(
                f"{stage_name}_{proj}_h{head}_gemv", OP_GEMV_KFOLD,
                gemv_lhs, raw, src1=gemv_weights_b[(proj, head)].addr,
                m=1, n=8, k_or_length=16, batch_count=1, head_count=0,
            )
            poison.update(raw.addr + 4 * i for i in range(8))
        else:
            raw = empty_i32(mapper, f"{stage_name}_{proj}_h{head}_i32",
                            len(input_rows), 8)
            mapper.add(f"{stage_name}_{proj}_h{head}_gemm", OP_GEMM, lhs, raw,
                       src1=rhs, m=4, n=8, k_or_length=4, aux0=1)
            poison.update(raw.addr + 4 * i for i in range(32))
        add_i32(golden, raw, result)
        quant = [requant_i8(row, 0) for row in result]
        packed = empty_i8_tile(mapper, f"{stage_name}_{proj}_h{head}_i8", 4, 8)
        mapper.add(f"{stage_name}_{proj}_h{head}_requant", OP_REQUANT,
                   raw, packed, m=4, n=8, k_or_length=32,
                   flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        add_i8_tile_a(golden, packed, quant)
        poison.update(packed.addr + 4 * i for i in range(8))
        return raw, packed, quant

    def add_cache_append(
        stage_name: str, kind: str, head: int, token: int,
        source_row: int, packed: Tensor, cache: Tensor,
    ) -> None:
        if kind == "v":
            # AV consumes V as Matrix-B [token,feature]. The opt-in KV append
            # performs bounded byte-lane RMW scatter; legacy KV_WRITE is kept
            # for K, whose [feature,token] tile is consumed by QK.
            mapper.add(
                f"{stage_name}_kv_append_v_h{head}_t{token}", OP_KV_WRITE,
                packed, cache, src0_offset=source_row * 4, k_or_length=8,
                aux0=(head << 16) | token, flags=KV_FLAG_MATRIX_B_APPEND,
                src0_stride=16, src1_stride=64,
            )
            return
        for feature_group in range(2):
            # K uses physical B[feature,token] so QK consumes K^T directly.
            base_correction = (token // 4) * 16 + feature_group * 16
            mapper.add(
                f"{stage_name}_kv_append_k_h{head}_t{token}_g{feature_group}",
                OP_KV_WRITE, packed, cache,
                src0_offset=feature_group * 16 + source_row * 4,
                dst_offset=base_correction, k_or_length=1,
                aux0=(head << 16) | token, src0_stride=4, src1_stride=64,
            )

    def cache_golden(golden: dict[int, int]) -> None:
        for head in range(2):
            for cache, state in ((key_cache, key_state), (value_cache, value_state)):
                words = cache_words(state[head], key_layout=(cache is key_cache))
                for index, word in enumerate(words):
                    golden[cache.addr + head * 64 + index * 4] = u32(word)

    def finish_stage(
        name: str, start: int, golden: dict[int, int], poison: set[int],
        useful_macs: int, token_position: int | None, kv_before: str,
    ) -> None:
        nonlocal stage_index
        descs = mapper.descriptors[start:]
        if not descs or len(descs) > 128:
            raise ValueError(f"{name}: empty or oversized CMDQ stage")
        for index, desc in enumerate(descs):
            desc.wait_mask = 1 if index else 0
            desc.clear_mask = 1 if index else 0
            desc.signal_mask = 1 if index + 1 < len(descs) else 0
        stage_descs.append((name, descs, golden, poison, {
            "useful_macs": useful_macs, "token_position": token_position,
            "kv_before_sha256": kv_before,
        }))
        stage_index += 1

    def hash_cache() -> str:
        values: list[int] = []
        for head in range(2):
            values.extend(cache_words(key_state[head], key_layout=True))
            values.extend(cache_words(value_state[head], key_layout=False))
        raw = b"".join(u32(value).to_bytes(4, "little") for value in values)
        return hashlib.sha256(raw).hexdigest()

    # Prefill stage: four host-supplied tokens execute Q/K/V projections,
    # append their K/V into the real SPAD cache and read the full cache back.
    start, golden, poison = new_stage("prefill")
    x_rows = [embeddings[token] for token in prefill_tokens]
    x = mapper.tensor("prefill_input_i8", (4, 16), "i8_packed",
                      "matrix_a_tile", _pack_matrix_a_physical(x_rows, 4))
    qkv_packed: dict[tuple[str, int], Tensor] = {}
    qkv_quant: dict[tuple[str, int], list[list[int]]] = {}
    for proj in ("q", "k", "v"):
        for head in range(2):
            _, packed, quant = project("prefill", proj, head, x, x_rows, golden, poison)
            qkv_packed[(proj, head)] = packed
            qkv_quant[(proj, head)] = quant
            if proj == "k":
                for row, token in enumerate(prefill_tokens):
                    key_state[head][token] = quant[row][:]
            if proj == "v":
                for row, token in enumerate(prefill_tokens):
                    value_state[head][token] = quant[row][:]
    for head in range(2):
        for row, token in enumerate(prefill_tokens):
            add_cache_append("prefill", "k", head, token, row,
                             qkv_packed[("k", head)], key_cache)
            add_cache_append("prefill", "v", head, token, row,
                             qkv_packed[("v", head)], value_cache)
    prefill_reads: dict[tuple[str, int], Tensor] = {}
    for kind, cache, state in (("k", key_cache, key_state),
                               ("v", value_cache, value_state)):
        for head in range(2):
            readback = mapper.tensor(
                f"prefill_{kind}_readback_h{head}", (8, 8), "i8_packed",
                "matrix_b_tile", [POISON] * 16, initialized=True,
            )
            mapper.add(f"prefill_kv_read_{kind}_h{head}", OP_KV_READ,
                       cache, readback, k_or_length=16,
                       aux0=head << 16, src1_stride=64)
            for index, word in enumerate(
                cache_words(state[head], key_layout=(kind == "k"))
            ):
                golden[readback.addr + 4 * index] = u32(word)
            poison.update(readback.addr + 4 * index for index in range(16))
            prefill_reads[(kind, head)] = readback
    cache_golden(golden)
    prefill_kv_sha = hash_cache()
    finish_stage("prefill_kv_0_3", start, golden, poison,
                 useful_macs=3 * 4 * 16 * 16, token_position=None,
                 kv_before="0" * 64)

    token_records: list[dict] = []
    for step, token_id in enumerate(decode_tokens):
        token_position = 4 + step
        stage_name = f"decode_t{token_position}"
        kv_before = hash_cache()
        start, golden, poison = new_stage(stage_name)
        input_row = embeddings[token_id]
        input_rows = [input_row] + [[0] * 16 for _ in range(3)]
        input_i8 = mapper.tensor(
            f"{stage_name}_input_i8", (4, 16), "i8_packed",
            "matrix_a_tile", _pack_matrix_a_physical(input_rows, 4),
        )
        input_i32 = mapper.tensor(
            f"{stage_name}_input_i32", (4, 16), "i32", "row-major",
            flatten(input_rows),
        )
        gemv_input = None
        if args.projection_policy == "gemv_qkv":
            gemv_input = mapper.tensor(
                f"{stage_name}_input_gemv", (16,), "i8_packed", "dense_row",
                [pack_i8(input_row[i:i + 4]) for i in range(0, 16, 4)],
                initialized=True,
            )
        decode_q: dict[int, list[int]] = {}
        decode_packed: dict[tuple[str, int], Tensor] = {}
        decode_quant: dict[tuple[str, int], list[list[int]]] = {}
        for proj in ("q", "k", "v"):
            for head in range(2):
                raw, packed, quant = project(
                    stage_name, proj, head, input_i8, input_rows, golden, poison,
                    gemv_lhs=gemv_input,
                    use_gemv=(args.projection_policy == "gemv_qkv"),
                )
                decode_packed[(proj, head)] = packed
                decode_quant[(proj, head)] = quant
                if proj == "q":
                    decode_q[head] = quant[0][:]
                if proj == "k":
                    key_state[head][token_position] = quant[0][:]
                if proj == "v":
                    value_state[head][token_position] = quant[0][:]

        for head in range(2):
            add_cache_append(stage_name, "k", head, token_position, 0,
                             decode_packed[("k", head)], key_cache)
            add_cache_append(stage_name, "v", head, token_position, 0,
                             decode_packed[("v", head)], value_cache)

        kv_reads: dict[tuple[str, int], Tensor] = {}
        for kind, cache, state in (("k", key_cache, key_state),
                                   ("v", value_cache, value_state)):
            for head in range(2):
                readback = mapper.tensor(
                    f"{stage_name}_{kind}_readback_h{head}", (8, 8),
                    "i8_packed", "matrix_b_tile", [POISON] * 16,
                    initialized=True,
                )
                mapper.add(f"{stage_name}_kv_read_{kind}_h{head}", OP_KV_READ,
                           cache, readback, k_or_length=16,
                           aux0=head << 16, src1_stride=64)
                for index, word in enumerate(cache_words(state[head], key_layout=(kind == "k"))):
                    golden[readback.addr + 4 * index] = u32(word)
                poison.update(readback.addr + 4 * index for index in range(16))
                kv_reads[(kind, head)] = readback

        head_proj: dict[int, Tensor] = {}
        merged_rows = [[0] * 16 for _ in range(4)]
        softmax_golden_by_head: dict[int, list[int]] = {}
        for head in range(2):
            q_rows = [decode_q[head]] + [[0] * 8 for _ in range(3)]
            q_tile = mapper.tensor(
                f"{stage_name}_q_tile_h{head}", (4, 8), "i8_packed",
                "matrix_a_tile", _pack_matrix_a_physical(q_rows, 4),
            )
            scores = empty_i32(mapper, f"{stage_name}_scores_h{head}", 4, 8)
            mapper.add(f"{stage_name}_qk_h{head}", OP_GEMM,
                       q_tile, scores, src1=kv_reads[("k", head)],
                       m=4, n=8, k_or_length=2, aux0=1)
            key_rows = key_state[head]
            score_row = [sum(decode_q[head][f] * key_rows[t][f]
                             for f in range(8)) for t in range(8)]
            score_matrix = [score_row] + [[0] * 8 for _ in range(3)]
            add_i32(golden, scores, score_matrix)
            poison.update(scores.addr + 4 * i for i in range(32))

            probs = empty_i32(mapper, f"{stage_name}_prob_q15_h{head}", 4, 8,
                              row0_poison_only=True)
            mapper.add(f"{stage_name}_causal_softmax_h{head}",
                       OP_CAUSAL_SOFTMAX, scores, probs, k_or_length=8,
                       aux0=token_position)
            visible = softmax_q15(score_row[:token_position + 1])
            prob_row = visible + [0] * (8 - len(visible))
            softmax_golden_by_head[head] = prob_row
            add_i32_prefix(golden, probs, prob_row)
            poison.update(probs.addr + 4 * i for i in range(8))
            prob_rows = [prob_row] + [[0] * 8 for _ in range(3)]
            prob_i8_rows = [requant_i8(row, 8) for row in prob_rows]
            prob_i8 = empty_i8_tile(mapper, f"{stage_name}_prob_i8_h{head}", 4, 8)
            mapper.add(f"{stage_name}_prob_requant_h{head}", OP_REQUANT,
                       probs, prob_i8, m=4, n=8, k_or_length=32,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                       shift=8, aux0=1)
            add_i8_tile_a(golden, prob_i8, prob_i8_rows)
            poison.update(prob_i8.addr + 4 * i for i in range(8))

            av = empty_i32(mapper, f"{stage_name}_av_h{head}", 4, 8)
            mapper.add(f"{stage_name}_av_gemm_h{head}", OP_GEMM,
                       prob_i8, av, src1=kv_reads[("v", head)],
                       m=4, n=8, k_or_length=2, aux0=1)
            p_i8 = prob_i8_rows[0]
            v_rows = value_state[head]
            av_row = [sum(p_i8[t] * v_rows[t][col] for t in range(8))
                      for col in range(8)]
            av_matrix = [av_row] + [[0] * 8 for _ in range(3)]
            add_i32(golden, av, av_matrix)
            poison.update(av.addr + 4 * i for i in range(32))
            av_rows_i8 = [requant_i8(row, 7) for row in av_matrix]
            av_tile = empty_i8_tile(mapper, f"{stage_name}_av_i8_h{head}", 4, 8)
            mapper.add(f"{stage_name}_av_requant_h{head}", OP_REQUANT,
                       av, av_tile, m=4, n=8, k_or_length=32,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                       shift=7, aux0=1)
            add_i8_tile_a(golden, av_tile, av_rows_i8)
            poison.update(av_tile.addr + 4 * i for i in range(8))

            wo_panel = [row[:] for row in weights["wo"][head * 8:(head + 1) * 8]]
            projected = empty_i32(mapper, f"{stage_name}_wo_h{head}", 4, 16)
            mapper.add(f"{stage_name}_wo_gemm_h{head}", OP_GEMM,
                       av_tile, projected, src1=wo_b[head],
                       m=4, n=16, k_or_length=2, aux0=1)
            projected_rows = gemm_i8_i32(av_rows_i8, wo_panel)
            add_i32(golden, projected, projected_rows)
            poison.update(projected.addr + 4 * i for i in range(64))
            head_proj[head] = projected
            for row in range(4):
                for col in range(16):
                    merged_rows[row][col] += projected_rows[row][col]

        merged = empty_i32(mapper, f"{stage_name}_head_merge", 4, 16)
        mapper.add(f"{stage_name}_head_merge", OP_RESIDUAL,
                   head_proj[0], merged, src1=head_proj[1],
                   k_or_length=64, aux0=1)
        add_i32(golden, merged, merged_rows)
        poison.update(merged.addr + 4 * i for i in range(64))

        residual1_rows = [residual_i32(a, b) for a, b in zip(merged_rows, input_rows)]
        residual1 = empty_i32(mapper, f"{stage_name}_residual1", 4, 16)
        mapper.add(f"{stage_name}_residual1", OP_RESIDUAL,
                   merged, residual1, src1=input_i32, k_or_length=64, aux0=1)
        add_i32(golden, residual1, residual1_rows)
        poison.update(residual1.addr + 4 * i for i in range(64))

        norm1_rows = [layernorm_q15(row, gamma1, beta1) for row in residual1_rows]
        norm1 = empty_i32(mapper, f"{stage_name}_layernorm1", 4, 16)
        for row in range(4):
            mapper.add(f"{stage_name}_layernorm1_row{row}", OP_LAYERNORM,
                       residual1, norm1, src1=gamma1_t, bias=beta1_t,
                       k_or_length=16, flags=FLAG_BIAS, aux0=1,
                       src0_offset=row * 64, dst_offset=row * 64)
        add_i32(golden, norm1, norm1_rows)
        poison.update(norm1.addr + 4 * i for i in range(64))
        norm1_i8_rows = [requant_i8(row, 0) for row in norm1_rows]
        norm1_i8 = empty_i8_tile(mapper, f"{stage_name}_layernorm1_i8", 4, 16)
        mapper.add(f"{stage_name}_layernorm1_requant", OP_REQUANT,
                   norm1, norm1_i8, m=4, n=16, k_or_length=64,
                   flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        add_i8_tile_a(golden, norm1_i8, norm1_i8_rows)
        poison.update(norm1_i8.addr + 4 * i for i in range(16))

        ffn_up_rows = gemm_i8_i32(norm1_i8_rows, weights["wup"])
        ffn_up = empty_i32(mapper, f"{stage_name}_ffn_up", 4, 16)
        mapper.add(f"{stage_name}_ffn_up", OP_GEMM,
                   norm1_i8, ffn_up, src1=wup_b,
                   m=4, n=16, k_or_length=4, aux0=1)
        add_i32(golden, ffn_up, ffn_up_rows)
        poison.update(ffn_up.addr + 4 * i for i in range(64))
        gelu_rows = [[gelu_q8_8(value) for value in row] for row in ffn_up_rows]
        gelu = empty_i32(mapper, f"{stage_name}_gelu", 4, 16)
        mapper.add(f"{stage_name}_gelu", OP_GELU, ffn_up, gelu,
                   k_or_length=64, aux0=1)
        add_i32(golden, gelu, gelu_rows)
        poison.update(gelu.addr + 4 * i for i in range(64))
        gelu_i8_rows = [requant_i8(row, 0) for row in gelu_rows]
        gelu_i8 = empty_i8_tile(mapper, f"{stage_name}_gelu_i8", 4, 16)
        mapper.add(f"{stage_name}_gelu_requant", OP_REQUANT,
                   gelu, gelu_i8, m=4, n=16, k_or_length=64,
                   flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        add_i8_tile_a(golden, gelu_i8, gelu_i8_rows)
        poison.update(gelu_i8.addr + 4 * i for i in range(16))

        ffn_down_rows = gemm_i8_i32(gelu_i8_rows, weights["wdown"])
        ffn_down = empty_i32(mapper, f"{stage_name}_ffn_down", 4, 16)
        mapper.add(f"{stage_name}_ffn_down", OP_GEMM,
                   gelu_i8, ffn_down, src1=wdown_b,
                   m=4, n=16, k_or_length=4, aux0=1)
        add_i32(golden, ffn_down, ffn_down_rows)
        poison.update(ffn_down.addr + 4 * i for i in range(64))
        residual2_rows = [residual_i32(a, b) for a, b in zip(ffn_down_rows, norm1_rows)]
        residual2 = empty_i32(mapper, f"{stage_name}_residual2", 4, 16)
        mapper.add(f"{stage_name}_residual2", OP_RESIDUAL,
                   ffn_down, residual2, src1=norm1, k_or_length=64, aux0=1)
        add_i32(golden, residual2, residual2_rows)
        poison.update(residual2.addr + 4 * i for i in range(64))
        norm2_rows = [layernorm_q15(row, gamma2, beta2) for row in residual2_rows]
        norm2 = empty_i32(mapper, f"{stage_name}_layernorm2", 4, 16)
        for row in range(4):
            mapper.add(f"{stage_name}_layernorm2_row{row}", OP_LAYERNORM,
                       residual2, norm2, src1=gamma2_t, bias=beta2_t,
                       k_or_length=16, flags=FLAG_BIAS, aux0=1,
                       src0_offset=row * 64, dst_offset=row * 64)
        add_i32(golden, norm2, norm2_rows)
        poison.update(norm2.addr + 4 * i for i in range(64))

        cache_golden(golden)
        kv_after = hash_cache()
        # Q/K/V + per-head output projection + FFN + causal QK/AV.
        # This is a single query row: 2 heads * (QK + AV) * head_dim * visible_tokens.
        useful = (3 * 16 * 16 + 2 * 8 * 16 + 2 * 16 * 16 +
                  2 * 2 * 8 * (token_position + 1))
        finish_stage(stage_name, start, golden, poison, useful,
                     token_position, kv_before)
        token_records.append({
            "token_position": token_position, "token_id_host_supplied": token_id,
            "input_tensor_address": input_i8.addr,
            "final_tensor_address": norm2.addr,
            "final_tensor_row0_int32": norm2_rows[0],
            "kv_after_sha256": kv_after,
            "expected_tensor_words": len(golden),
            "descriptor_count": len(mapper.descriptors[start:]),
            "useful_macs": useful,
        })

    descriptor_base = (mapper.next_addr + 0xFFF) & ~0xFFF
    completion_base = descriptor_base + CPL_OFFSET
    if completion_base + 128 * 16 > 512 * 1024:
        raise ValueError("generated workload exceeds the configured 512 KiB SPAD")

    initial: dict[int, int] = {}
    for tensor in mapper.tensors.values():
        for index, word in enumerate(tensor_storage_words(tensor)):
            initial[tensor.addr + index * 4] = u32(word)
    for stage_idx, (name, descs, _, _, _) in enumerate(stage_descs):
        if len(descs) > 128:
            raise ValueError(f"{name}: exceeds 128-entry CMDQ")

    args.out.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out / "initial_memory.memh", initial)
    stage_manifest = []
    for index, (name, descs, golden, poison, metadata) in enumerate(stage_descs):
        prefix = f"stage_{index}_{name}"
        flat_desc = [len(descs), descriptor_base, completion_base]
        for desc in descs:
            flat_desc.extend(desc.words())
        (args.out / f"{prefix}_desc.memh").write_text(
            "".join(f"{word & MASK32:08x}\n" for word in flat_desc),
            encoding="ascii",
        )
        write_pairs(args.out / f"{prefix}_golden.memh", golden)
        write_pairs(args.out / f"{prefix}_poison.memh",
                    {addr: POISON for addr in poison})
        golden_path = args.out / f"{prefix}_golden.memh"
        desc_path = args.out / f"{prefix}_desc.memh"
        poison_path = args.out / f"{prefix}_poison.memh"
        cache_golden_words = sorted(
            (addr, value) for addr, value in golden.items()
            if key_cache.addr <= addr < value_cache.addr + 128
        )
        stage_manifest.append({
            "index": index, "name": name, "descriptor_count": len(descs),
            "first_task_id": descs[0].task_id, "last_task_id": descs[-1].task_id,
            "useful_macs": metadata["useful_macs"],
            "token_position": metadata["token_position"],
            "kv_before_sha256": metadata["kv_before_sha256"],
            "kv_after_sha256": (
                token_records[index - 1]["kv_after_sha256"] if index else prefill_kv_sha
            ),
            "descriptor_contract": [descriptor_manifest(d) for d in descs],
            "golden_words": len(golden), "poison_words": len(poison),
            "descriptor_sha256": hashlib.sha256(desc_path.read_bytes()).hexdigest(),
            "golden_sha256": hashlib.sha256(golden_path.read_bytes()).hexdigest(),
            "poison_sha256": hashlib.sha256(poison_path.read_bytes()).hexdigest(),
            "cache_expected_words": len(cache_golden_words),
        })

    initial_path = args.out / "initial_memory.memh"
    manifest = {
        "run_scope": "H16 2-head one-layer INT8 true incremental KV Append; tokens 0..3 populate KV; 4..7 run full decode block",
        "projection_policy": args.projection_policy,
        "model_name": model.get("model_name"),
        "model_scope": model.get("model_scope"),
        "model_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "training": model.get("training"),
        "seed": model.get("seed"),
        "host_fallback": [
            "model training and Independent Golden only",
            "token IDs 4..7 are supplied by the host; this is not autonomous next-token generation",
        ],
        "prefill_token_ids": prefill_tokens,
        "incremental_decode_token_ids_host_supplied": decode_tokens,
        "cache_contract": {
            "capacity_tokens": 8, "prefill_positions": [0, 1, 2, 3],
            "append_positions": [4, 5, 6, 7], "head_dim": 8,
            "heads": 2, "K_storage": "per-head Matrix-B physical [feature, token]",
            "V_storage": "per-head Matrix-B physical [token, feature]",
            "append_mechanism": "K uses legacy word-strided KV_WRITE; V uses opt-in ABI-v7 0x43 flags[0] byte-lane read/modify/write scatter",
            "token_stride_bytes": 4, "head_stride_bytes": 64,
            "readback": "full 16-word 8x8 Matrix-B tile after each append",
        },
        "descriptor_base": descriptor_base, "completion_base": completion_base,
        "descriptor_version": DESC_VERSION, "events": "one-bit ordered completion chain per batch",
        "initial_memory_sha256": hashlib.sha256(initial_path.read_bytes()).hexdigest(),
        "tensors": {
            tensor.name: {"address": tensor.addr, "shape": tensor.shape,
                          "dtype": tensor.dtype, "layout": tensor.layout}
            for tensor in mapper.tensors.values()
        },
        "stages": stage_manifest,
        "tokens": token_records,
        "rtl_testbench": "tb_ai_accel_smoke.run_h16_incremental_decode",
        "model_quality": "synthetic projection labels; not language-model accuracy",
        "tiny_npu_reference_sha256": "8216c22b762011aa20c05fc2768423fd12dda59d",
    }
    (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n",
                                             encoding="utf-8")
    print(
        f"H16_INCREMENTAL_GENERATOR_PASS stages={len(stage_descs)} "
        f"prefill_desc={stage_manifest[0]['descriptor_count']} "
        f"decode_steps=4 decode_desc={sum(s['descriptor_count'] for s in stage_manifest[1:])} "
        f"model_sha256={manifest['model_sha256']} "
        f"initial_memory_sha256={manifest['initial_memory_sha256']}"
    )


if __name__ == "__main__":
    main()
