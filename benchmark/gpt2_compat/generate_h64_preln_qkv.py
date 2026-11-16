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
    OP_GELU, OP_GEMM, OP_KV_READ, OP_KV_WRITE, OP_LAYERNORM, OP_REQUANT, OP_RESIDUAL,
    _pack_matrix_a_physical, _pack_matrix_b_physical,
    add_completion_order_chain,
    kv_qk_compatible_append,
)
from ai_a3_reference import (  # noqa: E402
    gelu_q8_8, gemm_i8_i32, layernorm_q15, requant_i8, softmax_q15,
)
from gpt2_compat_golden import make_model  # noqa: E402

TOKENS = [1, 7, 42, 3]
ROWS = 16
HIDDEN = 64
KV_FLAG_MATRIX_B_APPEND = 0x01


def s32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, value & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words),
                     encoding="ascii")


def write_checkpoints(path: Path, checkpoints: list[dict]) -> None:
    words = [len(checkpoints)]
    for checkpoint in checkpoints:
        pairs = checkpoint["pairs"]
        words.extend((checkpoint["descriptor_index"], len(pairs)))
        for address, value in sorted(pairs.items()):
            words.extend((address, value & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words),
                     encoding="ascii")


def _tensor_bytes(tensor) -> int:
    return len(tensor.values) * 4


def compact_mapper_lifetimes(mapper: Mapper, capacity: int,
                             queue_slots: int) -> tuple[dict, int, int]:
    """Relocate virtual tensors into 128 KiB using descriptor live intervals."""
    descriptor_count = len(mapper.descriptors)
    if queue_slots <= descriptor_count:
        raise ValueError(
            f"CMDQ/CPLQ ring has {queue_slots} slots but workload needs "
            f"{descriptor_count} descriptors plus one spare slot"
        )
    queue_bytes = queue_slots * (64 + 16)
    desc_base = ((capacity - queue_bytes) // 64) * 64
    cpl_base = desc_base + queue_slots * 64
    if cpl_base + queue_slots * 16 > capacity:
        raise ValueError("CMDQ/CPLQ do not fit the SPAD reservation")

    original = {tensor.name: tensor.addr for tensor in mapper.tensors.values()}
    records = []
    for tensor in mapper.tensors.values():
        start = original[tensor.name]
        end = start + _tensor_bytes(tensor)
        producers = [i for i, d in enumerate(mapper.descriptors)
                     if start <= d.dst < end]
        consumers = [i for i, d in enumerate(mapper.descriptors)
                     if any(start <= address < end
                            for address in (d.src0, d.src1, d.bias) if address)]
        if not tensor.initialized and not producers:
            raise ValueError(f"{tensor.name}: uninitialized tensor has no producer")
        live_start = 0 if tensor.initialized else min(producers)
        live_end = max(producers + consumers, default=live_start)
        first_read = min(consumers, default=None)
        if (first_read is not None and not tensor.initialized and
                min(producers) >= first_read):
            first = mapper.descriptors[first_read]
            producer = mapper.descriptors[min(producers)]
            source_owners = [
                item.name for item in mapper.tensors.values()
                if item.addr <= first.src0 < item.addr + _tensor_bytes(item)
            ]
            raise ValueError(
                f"{tensor.name}: read precedes producer; first_read={first.name} "
                f"src0={first.src0:#x} src1={first.src1:#x}; "
                f"first_producer={producer.name} dst={producer.dst:#x}; "
                f"tensor=[{start:#x},{end:#x}) src0_owners={source_owners}"
            )
        records.append({"tensor": tensor, "old_start": start, "old_end": end,
                        "live_start": live_start, "live_end": live_end,
                        "producers": producers, "consumers": consumers})

    placed = []
    for record in sorted(records,
                         key=lambda r: (r["live_start"], -_tensor_bytes(r["tensor"]),
                                        r["tensor"].name)):
        size = _tensor_bytes(record["tensor"])
        candidate = 0x1000
        while True:
            candidate = (candidate + 63) & ~63
            conflicts = [other for other in placed
                         if not (record["live_end"] < other["live_start"] or
                                 other["live_end"] < record["live_start"])
                         and candidate < other["new_start"] + _tensor_bytes(other["tensor"])
                         and other["new_start"] < candidate + size]
            if not conflicts:
                break
            candidate = min(other["new_start"] + _tensor_bytes(other["tensor"])
                            for other in conflicts)
        if candidate + size > desc_base:
            peak = max(sum(_tensor_bytes(r["tensor"])
                           for r in records
                           if r["live_start"] <= index <= r["live_end"])
                       for index in range(descriptor_count))
            raise ValueError(
                f"unified live storage exceeds SPAD before queues: tensor={record['tensor'].name} "
                f"need_end={candidate + size} queue_base={desc_base} peak_live={peak}"
            )
        record["new_start"] = candidate
        placed.append(record)

    def relocate(address: int) -> int:
        if address == 0:
            return 0
        owners = [record for record in records
                  if record["old_start"] <= address < record["old_end"]]
        if len(owners) != 1:
            raise ValueError(f"descriptor address {address:#x} has {len(owners)} tensor owners")
        owner = owners[0]
        return owner["new_start"] + address - owner["old_start"]

    for descriptor in mapper.descriptors:
        descriptor.src0 = relocate(descriptor.src0)
        descriptor.src1 = relocate(descriptor.src1)
        descriptor.bias = relocate(descriptor.bias)
        descriptor.dst = relocate(descriptor.dst)
    for record in records:
        record["tensor"].addr = record["new_start"]

    allocation_records = []
    descriptor_names = [descriptor.name for descriptor in mapper.descriptors]
    for record in records:
        tensor = record["tensor"]
        allocation_records.append({
            "tensor_id": tensor.name,
            "logical_shape": list(tensor.shape),
            "dtype": tensor.dtype,
            "physical_layout": tensor.layout,
            "quantization_contract": ("signed INT8" if tensor.dtype == "i8_packed"
                                      else "signed INT32"),
            "alignment_bytes": 64,
            "address_range": [tensor.addr, tensor.addr + _tensor_bytes(tensor)],
            "start": tensor.addr, "end_exclusive": tensor.addr + _tensor_bytes(tensor),
            "size_bytes": _tensor_bytes(tensor),
            "live_start_descriptor": record["live_start"],
            "live_end_descriptor": record["live_end"],
            "last_consumer_descriptor": max(record["consumers"], default=None),
            "producer_descriptors": record["producers"],
            "producer_names": [descriptor_names[i] for i in record["producers"]],
            "consumer_descriptors": record["consumers"],
            "consumer_names": [descriptor_names[i] for i in record["consumers"]],
            "initialized_at_start": tensor.initialized,
            "initial_owner": "host_fixture" if tensor.initialized else None,
            "compute_write_owner": "product_top" if not tensor.initialized else None,
            "compute_read_owner": "product_top" if record["consumers"] else None,
            "dma_write_owner": None,
            "reuse_eligible_after_descriptor": record["live_end"],
        })
    peak_live = max(sum(_tensor_bytes(record["tensor"])
                        for record in records
                        if record["live_start"] <= index <= record["live_end"])
                    for index in range(descriptor_count))
    high_water = max((r["end_exclusive"] for r in allocation_records), default=0)
    for i, left in enumerate(allocation_records):
        for right in allocation_records[i + 1:]:
            address_overlap = left["start"] < right["end_exclusive"] and \
                              right["start"] < left["end_exclusive"]
            lifetime_overlap = (
                left["live_start_descriptor"] <= right["live_end_descriptor"] and
                right["live_start_descriptor"] <= left["live_end_descriptor"]
            )
            if address_overlap and lifetime_overlap:
                raise ValueError(f"illegal live alias: {left['tensor_id']} / {right['tensor_id']}")
    address_map = {record["old_start"]: record["new_start"] for record in records}
    return {"records": allocation_records, "peak_live_bytes": peak_live,
            "tensor_high_water": high_water, "_address_map": address_map,
            "_record_by_old_start": {record["old_start"]: record for record in records}}, \
        desc_base, cpl_base


def generate(out: Path, seed: int = 20261114, include_attention: bool = False,
             include_ffn: bool = False, include_kv_roundtrip: bool = False,
             include_kv_attention: bool = False,
             token_ids: list[int] | None = None,
             kv_k_write_mode: str = "token-append",
             kv_append_from: int = 0, *, layer_index: int = 0,
             input_hidden_i32: list[list[int]] | None = None,
             stream_norm_params: bool = False,
             include_final_lm_head: bool = False,
             queue_slots_override: int | None = None,
             model_override: dict[str, np.ndarray] | None = None) -> dict:
    if include_ffn and not include_attention:
        raise ValueError("full H64 Decoder requires Attention")
    if include_kv_attention and (not include_ffn or include_kv_roundtrip):
        raise ValueError("KV-backed attention requires full-decoder mode and excludes roundtrip mode")
    if include_final_lm_head and (not include_ffn or layer_index != 3):
        raise ValueError("final LN/LM head is only legal after the four-layer final decoder block")
    if kv_k_write_mode not in {
            "token-append", "qk-compatible-append", "matrix-a-tile", "matrix-a-word"}:
        raise ValueError("invalid KV K write mode")
    tokens = list(token_ids if token_ids is not None else TOKENS)
    if not tokens or any(token < 0 or token >= 256 for token in tokens):
        raise ValueError("token IDs must be a non-empty list in [0,255]")
    if not 0 <= kv_append_from < len(tokens):
        raise ValueError("kv_append_from must select an existing token")
    if not 0 <= layer_index < 4:
        raise ValueError("layer_index must be in [0,3]")
    if input_hidden_i32 is not None:
        if len(input_hidden_i32) != len(tokens) or any(
                len(row) != HIDDEN for row in input_hidden_i32):
            raise ValueError("inter-layer input must have one H64 row per token")
    if kv_append_from and (not include_kv_attention or kv_k_write_mode not in {
            "qk-compatible-append", "token-append"}):
        raise ValueError("incremental KV append requires supported cache-backed attention")
    model = make_model(seed) if model_override is None else {
        name: np.asarray(value).copy() for name, value in model_override.items()
    }
    if model_override is not None:
        expected_shapes = {"embedding": (256, 64), "position": (16, 64),
                           "final_gamma": (64,), "final_beta": (64,),
                           "lm_head": (64, 256)}
        for layer in range(4):
            prefix = f"l{layer}."
            expected_shapes.update({prefix + "q": (64, 64),
                                    prefix + "k": (64, 64),
                                    prefix + "v": (64, 64),
                                    prefix + "o": (64, 64),
                                    prefix + "up": (64, 256),
                                    prefix + "down": (256, 64),
                                    prefix + "ln1_gamma": (64,),
                                    prefix + "ln1_beta": (64,),
                                    prefix + "ln2_gamma": (64,),
                                    prefix + "ln2_beta": (64,)})
        if set(model) != set(expected_shapes):
            missing = sorted(set(expected_shapes) - set(model))
            extra = sorted(set(model) - set(expected_shapes))
            raise ValueError(f"model override keys differ: missing={missing}, extra={extra}")
        for name, shape in expected_shapes.items():
            if model[name].shape != shape:
                raise ValueError(f"model override {name} shape {model[name].shape} != {shape}")
    layer_params = {name: model[f"l{layer_index}.{name}"]
                    for name in ("ln1_gamma", "ln1_beta", "ln2_gamma", "ln2_beta",
                                 "q", "k", "v", "o", "up", "down")}
    if include_ffn:
        model_path = out / "canonical_h64_model.npz"
        out.mkdir(parents=True, exist_ok=True)
        np.savez_compressed(model_path, **model)
        model_sha256 = hashlib.sha256(model_path.read_bytes()).hexdigest()
    else:
        model_sha256 = None
    mapper = Mapper((1 << 20) if include_ffn else 128 * 1024)
    mapper.next_addr = 0x1000
    mapper.task_id = 0x7100

    embedding = np.zeros((ROWS, HIDDEN), dtype=np.int32)
    position = np.zeros((ROWS, HIDDEN), dtype=np.int32)
    for row, token in enumerate(tokens):
        if input_hidden_i32 is None:
            embedding[row] = model["embedding"][token].astype(np.int32)
            position[row] = model["position"][row].astype(np.int32)
        else:
            embedding[row] = np.asarray(input_hidden_i32[row], dtype=np.int32)
    combined = embedding + position
    embedding_t = mapper.tensor("embedding_lookup_i32", (ROWS, HIDDEN), "i32",
                                "row-major", embedding.reshape(-1).tolist())
    position_t = mapper.tensor("position_i32", (ROWS, HIDDEN), "i32",
                               "row-major", position.reshape(-1).tolist())
    combined_t = mapper.tensor("embedding_plus_position_i32", (ROWS, HIDDEN), "i32",
                               "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
    mapper.add("embedding_position_residual", OP_RESIDUAL, embedding_t, combined_t,
               src1=position_t, k_or_length=ROWS * HIDDEN, aux0=1)

    if include_ffn:
        gamma_values = [int(value) * 1024 for value in layer_params["ln1_gamma"]]
        beta_values = [int(value) for value in layer_params["ln1_beta"]]
        gamma2_values = [int(value) * 1024 for value in layer_params["ln2_gamma"]]
        beta2_values = [int(value) for value in layer_params["ln2_beta"]]
    else:
        gamma_values = [32768] * HIDDEN
        beta_values = [0] * HIDDEN
        gamma2_values, beta2_values = gamma_values, beta_values
    gamma_suffix = "_weight" if stream_norm_params else ""
    gamma_t = mapper.tensor(f"ln1_gamma_q15{gamma_suffix}", (HIDDEN,), "i32", "row-major", gamma_values)
    beta_t = mapper.tensor(f"ln1_beta_i32{gamma_suffix}", (HIDDEN,), "i32", "row-major", beta_values)
    gamma2_t = mapper.tensor(f"ln2_gamma_q15{gamma_suffix}", (HIDDEN,), "i32", "row-major", gamma2_values)
    beta2_t = mapper.tensor(f"ln2_beta_i32{gamma_suffix}", (HIDDEN,), "i32", "row-major", beta2_values)
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
    final_output_golden: dict[int, int] = {}
    final_checkpoint_specs: list[tuple[str, object, dict[int, int]]] = []
    for projection in ("q", "k", "v"):
        weights = layer_params[projection].astype(np.int32)
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
    attention_checkpoints = []
    attention_macs = 0
    if include_attention:
        norm_i8 = [[max(-128, min(127, int(value))) for value in row]
                   for row in norm]
        head_prob8: dict[int, list[list[int]]] = {}
        head_v8: dict[int, list[list[int]]] = {}
        kv_attention_cache = {}
        kv_attention_readback = {}
        kv_attention_expected = {}
        if include_kv_attention:
            for kind in ("k", "v"):
                cache_t = mapper.tensor(
                    f"l0.kv_attention_{kind}_cache_i8", (4, 16, 16),
                    "i8_packed", "matrix_b_head_token_feature",
                    [0xA55AA55A] * (4 * 64), True,
                )
                kv_attention_cache[kind] = cache_t
                kv_attention_readback[kind] = {}
                kv_attention_expected[kind] = {}
                for head in range(4):
                    readback_t = mapper.tensor(
                        f"l0.kv_attention_{kind}_read_h{head}", (16, 16),
                        "i8_packed", "matrix_b_tile", [0xA55AA55A] * 64, False,
                    )
                    kv_attention_readback[kind][head] = readback_t
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
            if include_ffn:
                for packed_tensor, values in ((q8_t, q_values), (k8_t, k_values)):
                    for word, value in enumerate(_pack_matrix_a_physical(values)):
                        attention_golden[packed_tensor.addr + word * 4] = value & 0xFFFFFFFF
                # Preserve an independent Product-Top observation point for
                # the packed Q operand. This distinguishes a projection/pack
                # discrepancy from a later QK datapath/layout discrepancy in
                # variable-length prefix replay.
                attention_checkpoints.append((q8_t.name, q8_t))

            if include_kv_attention:
                v_raw = projection_tiles[("v", head)]
                v_values = []
                for row in range(ROWS):
                    v_values.append(requant_i8([
                        s32(projection_golden[v_raw.addr + 4 * (row * 16 + col)])
                        for col in range(16)], 0))
                v_cache_src = mapper.tensor(
                    f"attn_v_h{head}_cache_source_i8", (ROWS, 16), "i8_packed",
                    "matrix_a_tile", [0xA55AA55A] * 64, False,
                )
                mapper.add(f"attn_v_h{head}_cache_requant", OP_REQUANT,
                           v_raw, v_cache_src, m=ROWS, n=16,
                           k_or_length=ROWS * 16,
                           flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                           shift=0, aux0=1)
                for word, value in enumerate(_pack_matrix_a_physical(v_values)):
                    attention_golden[v_cache_src.addr + word * 4] = value & 0xFFFFFFFF

                for kind, source, values in (("k", k8_t, k_values),
                                             ("v", v_cache_src, v_values)):
                    cache_t = kv_attention_cache[kind]
                    cache_bytes = bytearray()
                    head_word_start = head * 64
                    for word in cache_t.values[head_word_start:head_word_start + 64]:
                        cache_bytes.extend((word & 0xFFFFFFFF).to_bytes(4, "little"))
                    for token in range(len(tokens)):
                        source_row_offset = (token // 4) * 64 + (token % 4) * 4
                        if kind == "k":
                            if kv_k_write_mode == "qk-compatible-append":
                                if token >= kv_append_from:
                                    kv_qk_compatible_append(
                                        mapper,
                                        f"kv_attention_k_qk_append_h{head}_t{token}",
                                        source, cache_t, token=token, head=head,
                                        feature_count=16, head_stride=256,
                                        src_offset=source_row_offset,
                                    )
                                for feature_group in range(4):
                                    word_index = ((token // 4) * 4 + feature_group) * 4 + token % 4
                                    packed = sum(
                                        (value & 0xFF) << (lane * 8)
                                        for lane, value in enumerate(
                                            values[token][feature_group * 4:
                                                          feature_group * 4 + 4])
                                    )
                                    cache_bytes[word_index * 4:word_index * 4 + 4] = \
                                        (packed & 0xFFFFFFFF).to_bytes(4, "little")
                            elif kv_k_write_mode == "token-append":
                                if token >= kv_append_from:
                                    mapper.add(
                                        f"kv_attention_k_append_h{head}_t{token}",
                                        OP_KV_WRITE, source, cache_t,
                                        src0_offset=source_row_offset, k_or_length=16,
                                        flags=KV_FLAG_MATRIX_B_APPEND,
                                        aux0=(head << 16) | token,
                                        src0_stride=16, src1_stride=256,
                                    )
                                for feature, value in enumerate(values[token]):
                                    col_group, token_group = feature // 4, token // 4
                                    word_index = (col_group * 4 + token_group) * 4 + feature % 4
                                    byte_lane = token % 4
                                    cache_bytes[word_index * 4 + byte_lane] = value & 0xFF
                            elif kv_k_write_mode == "matrix-a-word":
                                for feature_group in range(4):
                                    matrix_a_word = ((token // 4) * 16 +
                                                     feature_group * 4 + token % 4)
                                    mapper.add(
                                        f"kv_attention_k_word_h{head}_t{token}_g{feature_group}",
                                        OP_KV_WRITE, source, cache_t,
                                        src0_offset=source_row_offset + feature_group * 16,
                                        dst_offset=(head * 64 + matrix_a_word) * 4,
                                        k_or_length=1,
                                    )
                                if token == 0:
                                    for word, value in enumerate(
                                            _pack_matrix_a_physical(values)):
                                        cache_bytes[word * 4:word * 4 + 4] = \
                                            (value & 0xFFFFFFFF).to_bytes(4, "little")
                            elif token == 0:
                                mapper.add(
                                    f"kv_attention_k_tile_write_h{head}",
                                    OP_KV_WRITE, source, cache_t,
                                    k_or_length=64, aux0=head << 16,
                                    src0_stride=0, src1_stride=256,
                                )
                                for word, value in enumerate(_pack_matrix_a_physical(values)):
                                    cache_bytes[word * 4:word * 4 + 4] = \
                                        (value & 0xFFFFFFFF).to_bytes(4, "little")
                        else:
                            if token >= kv_append_from:
                                mapper.add(
                                    f"kv_attention_v_append_h{head}_t{token}",
                                    OP_KV_WRITE, source, cache_t,
                                    src0_offset=source_row_offset, k_or_length=16,
                                    flags=KV_FLAG_MATRIX_B_APPEND,
                                    aux0=(head << 16) | token,
                                    src0_stride=16, src1_stride=256,
                                )
                            for feature, value in enumerate(values[token]):
                                col_group, token_group = feature // 4, token // 4
                                word_index = (col_group * 4 + token_group) * 4 + feature % 4
                                byte_lane = token % 4
                                cache_bytes[word_index * 4 + byte_lane] = value & 0xFF
                    expected_words = [int.from_bytes(cache_bytes[i:i + 4], "little")
                                      for i in range(0, len(cache_bytes), 4)]
                    cache_rows = [[0] * 16 for _ in range(16)]
                    for token in range(16):
                        for feature in range(16):
                            if kind == "k" and kv_k_write_mode in {
                                    "matrix-a-tile", "matrix-a-word",
                                    "qk-compatible-append"}:
                                word_index = ((token // 4) * 16 +
                                              (feature // 4) * 4 + token % 4)
                                byte_lane = feature % 4
                            else:
                                col_group, token_group = feature // 4, token // 4
                                word_index = (col_group * 4 + token_group) * 4 + feature % 4
                                byte_lane = token % 4
                            byte = cache_bytes[word_index * 4 + byte_lane]
                            cache_rows[token][feature] = byte - 256 if byte & 0x80 else byte
                    kv_attention_expected[kind][head] = cache_rows
                    if cache_rows[:len(tokens)] != values[:len(tokens)]:
                        raise ValueError(
                            f"head {head} {kind.upper()} cache unpack differs "
                            "from projected rows"
                        )
                    if kind == "v":
                        head_v8[head] = cache_rows
                    readback_t = kv_attention_readback[kind][head]
                    mapper.add(
                        f"kv_attention_{kind}_read_h{head}", OP_KV_READ,
                        cache_t, readback_t, k_or_length=64,
                        aux0=head << 16, src0_stride=0,
                        src1_stride=256,
                    )
                    for word, value in enumerate(expected_words):
                        attention_golden[cache_t.addr + head * 256 + word * 4] = value
                        attention_golden[readback_t.addr + word * 4] = value
                head_v8[head] = v_values
                scores = gemm_i8_i32(
                    q_values,
                    [list(row) for row in zip(*kv_attention_expected["k"][head])],
                    shift=2,
                )
            else:
                scores = gemm_i8_i32(q_values, [list(row) for row in zip(*k_values)], shift=2)
            score_t = mapper.tensor(f"attn_h{head}_scores_q8_8", (ROWS, ROWS), "i32",
                                    "row-major", [0xA55AA55A] * (ROWS * ROWS), False)
            mapper.add(f"attn_h{head}_qkt_scaled", OP_GEMM, q8_t, score_t,
                       src1=(kv_attention_readback["k"][head]
                             if include_kv_attention else k8_t),
                       m=ROWS, n=ROWS, k_or_length=4,
                       flags=0,
                       shift=2, aux0=1)
            for row in range(ROWS):
                for col in range(ROWS):
                    attention_golden[score_t.addr + 4 * (row * ROWS + col)] = \
                        scores[row][col] & 0xFFFFFFFF
            attention_checkpoints.append((score_t.name, score_t))

            prob_init = [0xA55AA55A] * (ROWS * ROWS)
            for row in range(len(tokens), ROWS):
                prob_init[row * ROWS:(row + 1) * ROWS] = [0] * ROWS
            prob_t = mapper.tensor(f"attn_h{head}_prob_q15", (ROWS, ROWS), "i32",
                                   "row-major", prob_init, True)
            probs = [[0] * ROWS for _ in range(ROWS)]
            for row in range(len(tokens)):
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
            for row in range(len(tokens), ROWS):
                for col in range(ROWS):
                    attention_golden[prob_t.addr + 4 * (row * ROWS + col)] = 0
            attention_checkpoints.append((prob_t.name, prob_t))

            p8 = [requant_i8(row, 8) for row in probs]
            p8_t = mapper.tensor(f"attn_h{head}_prob_i8", (ROWS, ROWS), "i8_packed",
                                 "matrix_a_tile", [0xA55AA55A] * 64, False)
            mapper.add(f"attn_h{head}_prob_requant", OP_REQUANT, prob_t, p8_t,
                       m=ROWS, n=ROWS, k_or_length=ROWS * ROWS,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                       shift=8, aux0=1)
            if include_ffn:
                for word, value in enumerate(_pack_matrix_a_physical(p8)):
                    attention_golden[p8_t.addr + word * 4] = value & 0xFFFFFFFF
            head_prob8[head] = p8

            if not include_kv_attention:
                v_weights = layer_params["v"].astype(np.int32)[:, head * 16:(head + 1) * 16]
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
                       src1=(kv_attention_readback["v"][head]
                             if include_kv_attention else
                             mapper.tensors[f"attn_h{head}_v_matrix_b"]),
                       m=ROWS, n=16, k_or_length=4, shift=7, aux0=1)
            av = gemm_i8_i32(head_prob8[head], head_v8[head], shift=7)
            for row in range(ROWS):
                for col in range(16):
                    attention_golden[av_t.addr + 4 * (row * 16 + col)] = \
                        av[row][col] & 0xFFFFFFFF
                    merged_i8[row][head * 16 + col] = max(-128, min(127, av[row][col]))
            attention_checkpoints.append((av_t.name, av_t))
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

        output_weights = layer_params["o"].astype(np.int32).tolist()
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
        norm2_matrix = np.zeros((ROWS, HIDDEN), dtype=np.int32)
        for row in range(ROWS):
            mapper.add(f"ln2_row{row}", OP_LAYERNORM, residual1_t, norm2_t,
                       src1=gamma2_t, bias=beta2_t, k_or_length=HIDDEN,
                       flags=FLAG_BIAS, aux0=1,
                       src0_offset=row * HIDDEN * 4,
                       dst_offset=row * HIDDEN * 4)
            norm2 = layernorm_q15(residual1[row].tolist(), gamma2_values, beta2_values)
            for col, value in enumerate(norm2):
                norm2_matrix[row, col] = int(value)
                attention_golden[norm2_t.addr + 4 * (row * HIDDEN + col)] = \
                    int(value) & 0xFFFFFFFF
        attention_macs = 98304 if include_kv_attention else 163840

    ffn_golden: dict[int, int] = {}
    kv_golden: dict[int, int] = {}
    kv_read_snapshots: list[tuple[int, str, str, list[int]]] = []
    up_checkpoint_tensors = []
    if include_ffn:
        ln2_i8 = [[max(-128, min(127, int(value))) for value in row]
                  for row in norm2_matrix]
        packed_ffn_values = _pack_matrix_a_physical(ln2_i8)
        packed_ffn_t = mapper.tensor(
            "l0.ffn_input_i8_matrix_a", (ROWS, HIDDEN), "i8_packed",
            "matrix_a_tile", [0xA55AA55A] * len(packed_ffn_values), False,
        )
        mapper.add("l0.ffn_input_requant_pack", OP_REQUANT, norm2_t,
                   packed_ffn_t, m=ROWS, n=HIDDEN, k_or_length=ROWS * HIDDEN,
                   flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                   shift=0, aux0=1)
        for word, value in enumerate(packed_ffn_values):
            ffn_golden[packed_ffn_t.addr + word * 4] = value & 0xFFFFFFFF

        up_tiles = []
        up_i8_values = []
        up_weight = layer_params["up"].astype(np.int32)
        for tile in range(16):
            columns = slice(tile * 16, (tile + 1) * 16)
            weight = up_weight[:, columns].tolist()
            weight_t = mapper.tensor(
                f"l0.ffn_up_weight_n{tile}", (HIDDEN, 16), "i8_packed",
                "matrix_b_tile", _pack_matrix_b_physical(weight), True,
            )
            up_t = mapper.tensor(f"l0.ffn_up_n{tile}_i32", (ROWS, 16), "i32",
                                 "row-major", [0xA55AA55A] * (ROWS * 16), False)
            gelu_t = mapper.tensor(f"l0.ffn_gelu_n{tile}_i32", (ROWS, 16), "i32",
                                   "row-major", [0xA55AA55A] * (ROWS * 16), False)
            out_t = mapper.tensor(f"l0.ffn_gelu_n{tile}_i8", (ROWS, 16), "i8_packed",
                                  "matrix_a_tile", [0xA55AA55A] * (ROWS * 16 // 4), False)
            mapper.add(f"l0.ffn_up_n{tile}", OP_GEMM, packed_ffn_t, up_t,
                       src1=weight_t, m=ROWS, n=16, k_or_length=HIDDEN // 4,
                       aux0=1)
            mapper.add(f"l0.ffn_gelu_n{tile}", OP_GELU, up_t, gelu_t,
                       m=ROWS, n=16, k_or_length=ROWS * 16, aux0=1)
            mapper.add(f"l0.ffn_requant_pack_n{tile}", OP_REQUANT, gelu_t, out_t,
                       m=ROWS, n=16, k_or_length=ROWS * 16,
                       flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
            up_values = gemm_i8_i32(ln2_i8, weight)
            gelu_values = [[gelu_q8_8(value) for value in row]
                           for row in up_values]
            out_values = [[max(-128, min(127, int(value))) for value in row]
                          for row in gelu_values]
            for row in range(ROWS):
                for col in range(16):
                    ffn_golden[up_t.addr + 4 * (row * 16 + col)] = \
                        up_values[row][col] & 0xFFFFFFFF
                    ffn_golden[gelu_t.addr + 4 * (row * 16 + col)] = \
                        gelu_values[row][col] & 0xFFFFFFFF
            for word, value in enumerate(_pack_matrix_a_physical(out_values)):
                ffn_golden[out_t.addr + 4 * word] = value & 0xFFFFFFFF
            up_tiles.append((out_t, weight_t))
            up_i8_values.append(out_values)
            if tile in (0, 15):
                up_checkpoint_tensors.append((tile, up_t, gelu_t, out_t))

        down_acc = mapper.tensor("l0.ffn_down_acc_i32", (ROWS, HIDDEN), "i32",
                                 "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
        down_partial = mapper.tensor("l0.ffn_down_partial_i32", (ROWS, HIDDEN), "i32",
                                     "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
        down_values = [[0] * HIDDEN for _ in range(ROWS)]
        last_partial_values = [[0] * HIDDEN for _ in range(ROWS)]
        down_weight = layer_params["down"].astype(np.int32)
        for tile in range(16):
            rows = slice(tile * 16, (tile + 1) * 16)
            weight = down_weight[rows, :].tolist()
            weight_t = mapper.tensor(
                f"l0.ffn_down_weight_k{tile}", (16, HIDDEN), "i8_packed",
                "matrix_b_tile", _pack_matrix_b_physical(weight), True,
            )
            output_t = down_acc if tile == 0 else down_partial
            mapper.add(f"l0.ffn_down_k{tile}", OP_GEMM, up_tiles[tile][0], output_t,
                       src1=weight_t, m=ROWS, n=HIDDEN, k_or_length=4, aux0=1)
            partial_values = gemm_i8_i32(up_i8_values[tile], weight)
            last_partial_values = partial_values
            for row in range(ROWS):
                for col in range(HIDDEN):
                    down_values[row][col] += partial_values[row][col]
            if tile:
                mapper.add(f"l0.ffn_down_accumulate_k{tile}", OP_RESIDUAL,
                           down_acc, down_acc, src1=down_partial,
                           k_or_length=ROWS * HIDDEN, aux0=1)
        residual2_t = mapper.tensor("l0.residual2_i32", (ROWS, HIDDEN), "i32",
                                    "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
        mapper.add("l0.ffn_residual2", OP_RESIDUAL, down_acc, residual2_t,
                   src1=residual1_t, k_or_length=ROWS * HIDDEN, aux0=1)
        for row in range(ROWS):
            for col in range(HIDDEN):
                offset = 4 * (row * HIDDEN + col)
                ffn_golden[down_acc.addr + offset] = down_values[row][col] & 0xFFFFFFFF
                ffn_golden[down_partial.addr + offset] = \
                    last_partial_values[row][col] & 0xFFFFFFFF
                ffn_golden[residual2_t.addr + offset] = \
                    (down_values[row][col] + int(residual1[row, col])) & 0xFFFFFFFF

    if include_final_lm_head:
        final_input = [[s32(ffn_golden[residual2_t.addr + 4 * (row * HIDDEN + col)])
                        for col in range(HIDDEN)] for row in range(ROWS)]
        final_gamma = [int(value) * 1024 for value in model["final_gamma"]]
        final_beta = [int(value) for value in model["final_beta"]]
        final_gamma_t = mapper.tensor("final_ln_gamma_q15_weight", (HIDDEN,), "i32",
                                      "row-major", final_gamma)
        final_beta_t = mapper.tensor("final_ln_beta_i32_weight", (HIDDEN,), "i32",
                                     "row-major", final_beta)
        final_ln_t = mapper.tensor("final_ln_i32", (ROWS, HIDDEN), "i32",
                                   "row-major", [0xA55AA55A] * (ROWS * HIDDEN), False)
        final_ln = np.zeros((ROWS, HIDDEN), dtype=np.int32)
        for row in range(ROWS):
            mapper.add(f"final_ln_row{row}", OP_LAYERNORM, residual2_t, final_ln_t,
                       src1=final_gamma_t, bias=final_beta_t,
                       k_or_length=HIDDEN, flags=FLAG_BIAS, aux0=1,
                       src0_offset=row * HIDDEN * 4,
                       dst_offset=row * HIDDEN * 4)
            final_ln[row] = layernorm_q15(final_input[row], final_gamma, final_beta)
            for col in range(HIDDEN):
                final_output_golden[final_ln_t.addr + 4 * (row * HIDDEN + col)] = \
                    int(final_ln[row, col]) & 0xFFFFFFFF

        final_ln_matrix_a = [[max(-128, min(127, int(value))) for value in row]
                             for row in final_ln]
        final_packed_words = _pack_matrix_a_physical(final_ln_matrix_a)
        final_packed_t = mapper.tensor(
            "final_ln_matrix_a_i8", (ROWS, HIDDEN), "i8_packed", "matrix_a_tile",
            [0xA55AA55A] * len(final_packed_words), False)
        mapper.add("final_ln_requant_pack_matrix_a", OP_REQUANT, final_ln_t,
                   final_packed_t, m=ROWS, n=HIDDEN,
                   k_or_length=ROWS * HIDDEN,
                   flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1)
        for word, value in enumerate(final_packed_words):
            final_output_golden[final_packed_t.addr + word * 4] = value & 0xFFFFFFFF

        logits_t = mapper.tensor("logits_i32_physical_16x256", (ROWS, 256), "i32",
                                 "matrix_n_tile_major_16x16",
                                 [0xA55AA55A] * (ROWS * 256), False)
        final_logits_i8 = np.asarray(final_ln_matrix_a, dtype=np.int8)
        lm_head = model["lm_head"].astype(np.int32)
        for tile in range(16):
            col0 = tile * 16
            b_rows = lm_head[:, col0:col0 + 16].tolist()
            weight_t = mapper.tensor(
                f"lm_head_weight_tile_n{tile}_weight", (HIDDEN, 16), "i8_packed",
                "matrix_b_tile", _pack_matrix_b_physical(b_rows))
            dst_offset = tile * ROWS * 16 * 4
            mapper.add(f"lm_head_gemm_n{tile}", OP_GEMM, final_packed_t, logits_t,
                       src1=weight_t, m=ROWS, n=16,
                       k_or_length=HIDDEN // 4, dst_offset=dst_offset, aux0=1)
            tile_logits = gemm_i8_i32(final_logits_i8.tolist(), b_rows)
            for row in range(ROWS):
                for col in range(16):
                    address = logits_t.addr + dst_offset + 4 * (row * 16 + col)
                    final_output_golden[address] = tile_logits[row][col] & 0xFFFFFFFF
        final_checkpoint_specs = [
            ("final_ln_i32", final_ln_t, final_output_golden),
            ("final_ln_matrix_a_i8", final_packed_t, final_output_golden),
            ("logits_i32_physical_16x256", logits_t, final_output_golden),
        ]

    if include_kv_roundtrip:
        if not include_ffn:
            raise ValueError("H64 KV roundtrip requires the full decoder workload")
        cache_words = ROWS * HIDDEN
        head_stride = 16 * 16 * 4
        token_stride = 16 * 4
        cache_tensors = {}
        readback_tensors = {}
        for kind in ("k", "v"):
            cache_tensors[kind] = mapper.tensor(
                f"l0.kv_{kind}_cache_i32", (4, 16, 16), "i32",
                "head-token-feature", [0xA55AA55A] * cache_words, False,
            )
            readback_tensors[kind] = mapper.tensor(
                f"l0.kv_{kind}_readback_i32", (16,), "i32", "feature-vector",
                [0xA55AA55A] * 16, False,
            )

        for kind in ("k", "v"):
            cache_t = cache_tensors[kind]
            read_t = readback_tensors[kind]
            for head in range(4):
                source_t = projection_tiles[(kind, head)]
                for token in range(len(tokens)):
                    source_offset = token * 16 * 4
                    task = f"l0.kv_{kind}_write_t{token}_h{head}"
                    mapper.add(task, OP_KV_WRITE, source_t, cache_t,
                               src0_offset=source_offset, k_or_length=16,
                               aux0=(head << 16) | token,
                               src0_stride=token_stride, src1_stride=head_stride)
                    values = [s32(projection_golden[
                        source_t.addr + source_offset + feature * 4])
                              for feature in range(16)]
                    base = cache_t.addr + head * head_stride + token * token_stride
                    for feature, value in enumerate(values):
                        kv_golden[base + feature * 4] = value & 0xFFFFFFFF

                    read_task = f"l0.kv_{kind}_read_t{token}_h{head}"
                    mapper.add(read_task, OP_KV_READ, cache_t, read_t,
                               k_or_length=16, aux0=(head << 16) | token,
                               src0_stride=token_stride, src1_stride=head_stride)
                    kv_read_snapshots.append((len(mapper.descriptors) - 1,
                                              read_task, read_t.name, values))
                    for feature, value in enumerate(values):
                        kv_golden[read_t.addr + feature * 4] = value & 0xFFFFFFFF

    add_completion_order_chain(mapper, event_bit=0)
    allocation = None
    checkpoint_records = []
    dma_weight_records = []
    if include_ffn:
        queue_slots = (queue_slots_override if queue_slots_override is not None else
                       (512 if include_final_lm_head else 256))
        if queue_slots not in (256, 512):
            raise ValueError("H64 runtime supports 256- or 512-entry queues")
        allocation, desc_base, cpl_base = compact_mapper_lifetimes(
            mapper, 128 * 1024, queue_slots
        )
        old_to_new = allocation.pop("_address_map")
        record_by_old_start = allocation.pop("_record_by_old_start")

        def relocate_golden(source: dict[int, int]) -> list[tuple[int, int, int]]:
            moved = []
            for address, value in source.items():
                starts = [start for start, record in record_by_old_start.items()
                          if start <= address < start + _tensor_bytes(record["tensor"])]
                if len(starts) != 1:
                    raise ValueError(f"Golden address {address:#x} has {len(starts)} tensor owners")
                old_start = starts[0]
                record = record_by_old_start[old_start]
                new_address = old_to_new[old_start] + address - old_start
                write_order = max(record["producers"], default=-1)
                moved.append((write_order, new_address, value))
            return moved

        base_golden = {}
        for row in range(ROWS):
            for col in range(HIDDEN):
                offset = 4 * (row * HIDDEN + col)
                base_golden[combined_t.addr + offset] = int(combined_rows[row, col]) & 0xFFFFFFFF
                base_golden[norm_t.addr + offset] = int(norm[row, col]) & 0xFFFFFFFF
        moved_golden = (relocate_golden(base_golden) +
                        relocate_golden(projection_golden) +
                        relocate_golden(attention_golden) +
                        relocate_golden(ffn_golden) +
                        relocate_golden(kv_golden) +
                        relocate_golden(final_output_golden))
        golden = {}
        for _, address, value in sorted(moved_golden):
            golden[address] = value

        old_start_by_name = {
            record["tensor"].name: old_start
            for old_start, record in record_by_old_start.items()
        }
        tensor_records = {record["tensor_id"]: record
                          for record in allocation["records"]}
        if include_kv_roundtrip:
            for kind, cache_t in cache_tensors.items():
                cache_record = tensor_records[cache_t.name]
                if cache_record["end_exclusive"] > 128 * 1024:
                    raise ValueError(
                        f"{kind} KV cache exceeds 128 KiB SPAD after compaction"
                    )

        def checkpoint_for(name: str, tensor, source_golden: dict[int, int]) -> dict:
            old_start = old_start_by_name[name]
            checkpoint_bytes = _tensor_bytes(tensor)
            selected_addresses = None
            if name.startswith("attn_q_h") and tensor.dtype == "i8_packed":
                # The variable-length session explicitly clears padded Q rows
                # after the Product Requant producer. Check only valid model
                # input rows here; the subsequent QK Golden checks the
                # resulting full physical tile after padding initialization.
                # Matrix-A rows are interleaved by 4x4 subtile, so valid rows
                # are not a contiguous byte range once the fifth row begins.
                row_count = len(tokens)
                k_groups = tensor.shape[1] // 4
                selected_addresses = {
                    old_start + (((row // 4) * k_groups + k_group) * 4 +
                                 (row % 4)) * 4
                    for row in range(row_count)
                    for k_group in range(k_groups)
                }
            old_end = old_start + checkpoint_bytes
            selected = {tensor.addr + address - old_start: value
                        for address, value in source_golden.items()
                        if ((address in selected_addresses) if selected_addresses is not None
                            else old_start <= address < old_end)}
            expected_words = (len(selected_addresses) if selected_addresses is not None
                              else checkpoint_bytes // 4)
            if len(selected) != expected_words:
                raise ValueError(f"checkpoint {name}: Golden words {len(selected)} != {expected_words}")
            allocation_record = tensor_records[name]
            return {"name": name,
                    "descriptor_index": max(allocation_record["producer_descriptors"]),
                    "pairs": selected}

        checkpoint_specs = [
            ("residual1_i32", residual1_t, attention_golden),
            ("ln2_output_i32", norm2_t, attention_golden),
            ("l0.ffn_input_i8_matrix_a", packed_ffn_t, ffn_golden),
        ]
        if include_kv_attention:
            for kind in ("k", "v"):
                for head in range(4):
                    checkpoint_specs.append((
                        kv_attention_readback[kind][head].name,
                        kv_attention_readback[kind][head], attention_golden,
                    ))
        if include_attention:
            for tensor_name, tensor in attention_checkpoints:
                checkpoint_specs.append((tensor_name, tensor, attention_golden))
        for tile, up_t, gelu_t, out_t in up_checkpoint_tensors:
            checkpoint_specs.extend((
                (f"l0.ffn_up_n{tile}_i32", up_t, ffn_golden),
                (f"l0.ffn_gelu_n{tile}_i32", gelu_t, ffn_golden),
                (f"l0.ffn_gelu_n{tile}_i8", out_t, ffn_golden),
            ))
        checkpoint_specs.extend((
            ("l0.ffn_down_acc_i32", down_acc, ffn_golden),
            ("l0.residual2_i32", residual2_t, ffn_golden),
        ))
        checkpoint_specs.extend(final_checkpoint_specs)
        checkpoint_records = [checkpoint_for(name, tensor, source)
                              for name, tensor, source in checkpoint_specs]
        for descriptor_index, name, readback_name, values in kv_read_snapshots:
            readback = mapper.tensors[readback_name]
            relocated_base = old_to_new[old_start_by_name[readback.name]]
            checkpoint_records.append({
                "name": name, "descriptor_index": descriptor_index,
                "pairs": {relocated_base + feature * 4: value & 0xFFFFFFFF
                          for feature, value in enumerate(values)},
            })
        for tensor in mapper.tensors.values():
            if "weight" not in tensor.name:
                continue
            allocation_record = tensor_records[tensor.name]
            allocation_record["initialized_at_start"] = False
            allocation_record["initial_owner"] = None
            allocation_record["compute_write_owner"] = None
            allocation_record["dma_write_owner"] = "external_axi4_dma"
            allocation_record["dma_completion_fence_before_first_consumer"] = True
            values = [int(value) & 0xFFFFFFFF for value in tensor.values]
            if tensor.addr & 0xF or len(values) % 4:
                raise ValueError(f"DMA weight tensor is not line aligned: {tensor.name}")
            dma_weight_records.append({"name": tensor.name, "spad_address": tensor.addr,
                                      "words": len(values), "values": values})
        dma_payload_words = []
        dma_plan_words = [len(dma_weight_records)]
        dma_plan = []
        for record in dma_weight_records:
            ext_addr = len(dma_payload_words) * 4
            dma_payload_words.extend(record["values"])
            length_words = record["words"]
            dma_plan_words.extend((ext_addr, record["spad_address"], length_words))
            dma_plan.append({"tensor": record["name"], "external_address": ext_addr,
                             "spad_address": record["spad_address"],
                             "length_words": length_words,
                             "length_bytes": length_words * 4})
        if len(dma_weight_records) > 85:
            raise ValueError("weight DMA plan exceeds representative testbench transaction limit")
        if len(dma_payload_words) > 32768:
            raise ValueError("weight DMA payload exceeds representative AXI memory capacity")
        (out / "dma_payload.memh").write_text(
            "".join(f"{word:08x}\n" for word in dma_payload_words), encoding="ascii")
        (out / "dma_plan.memh").write_text(
            "".join(f"{word & 0xFFFFFFFF:08x}\n" for word in dma_plan_words),
            encoding="ascii")
    else:
        desc_base, cpl_base = ((0x1A000, 0x1C000) if include_attention
                               else (0xC000, 0xD000))
        if mapper.next_addr > desc_base:
            raise ValueError("tensor allocations overlap the queue reservation")
    mapper.check_queues(desc_base, cpl_base)
    image: dict[int, int] = {}
    if not include_ffn:
        golden = dict(projection_golden)
    for row in range(ROWS):
        for col in range(HIDDEN):
            addr = embedding_t.addr + 4 * (row * HIDDEN + col)
            image[addr] = int(embedding[row, col]) & 0xFFFFFFFF
            image[position_t.addr + 4 * (row * HIDDEN + col)] = int(position[row, col]) & 0xFFFFFFFF
            if not include_ffn:
                golden[combined_t.addr + 4 * (row * HIDDEN + col)] = \
                    int(combined_rows[row, col]) & 0xFFFFFFFF
                norm_addr = norm_t.addr + 4 * (row * HIDDEN + col)
                golden[norm_addr] = int(norm[row, col]) & 0xFFFFFFFF
    if include_ffn:
        for tensor in mapper.tensors.values():
            if tensor.name in {embedding_t.name, position_t.name} or not tensor.initialized:
                continue
            for index, value in enumerate(tensor.values):
                image[tensor.addr + index * 4] = int(value) & 0xFFFFFFFF
        for tensor in mapper.tensors.values():
            if tensor.initialized:
                continue
            for index, value in enumerate(tensor.values):
                image.setdefault(tensor.addr + index * 4, int(value) & 0xFFFFFFFF)
    else:
        for tensor in mapper.tensors.values():
            if tensor.name in {embedding_t.name, position_t.name}:
                continue
            for index, value in enumerate(tensor.values):
                image[tensor.addr + index * 4] = int(value) & 0xFFFFFFFF
    if not include_ffn:
        for index, value in enumerate(packed_values):
            golden[packed_t.addr + index * 4] = int(value) & 0xFFFFFFFF
    for index, descriptor in enumerate(mapper.descriptors):
        for word_index, value in enumerate(descriptor.words()):
            image[desc_base + index * 64 + word_index * 4] = value
        for word_index in range(4):
            image[cpl_base + index * 16 + word_index * 4] = 0xA55AA55A

    out.mkdir(parents=True, exist_ok=True)
    write_pairs(out / "model_memory.memh", image)
    if include_ffn:
        write_checkpoints(out / "checkpoint_golden.memh", checkpoint_records)
    if not include_ffn:
        golden.update(projection_golden)
        golden.update(attention_golden)
    elif allocation is not None:
        allocation["queue_ranges"] = {
            "cmdq": [desc_base, desc_base + queue_slots * 64],
            "cplq": [cpl_base, cpl_base + queue_slots * 16],
        }
    write_pairs(out / "model_golden.memh", golden)
    executed_macs = 3 * ROWS * HIDDEN * HIDDEN + attention_macs
    attention_useful_macs = 0
    if include_attention:
        if include_kv_attention:
            attention_useful_macs = (len(tokens) * HIDDEN * HIDDEN +
                                     2 * 4 * 16 * len(tokens) * (len(tokens) + 1) // 2)
        else:
            attention_useful_macs = 34816
    useful_macs = 3 * len(tokens) * HIDDEN * HIDDEN + attention_useful_macs
    useful_output_elements = 3 * len(tokens) * HIDDEN
    physical_output_elements = 3 * ROWS * HIDDEN
    if include_ffn:
        executed_macs += 2 * ROWS * HIDDEN * 256
        useful_macs += 2 * len(tokens) * HIDDEN * 256
        useful_output_elements += len(tokens) * (256 + HIDDEN)
        physical_output_elements += ROWS * (256 + HIDDEN)
    manifest = {
        "scope": "Token embedding load + Position residual + H64 LayerNorm + Q/K/V projection" +
                 (" + four-head causal attention + output projection + Residual 1 + LayerNorm 2"
                  if include_attention else "") +
                 (" + packed FFN input + 256-wide FFN Up/GELU + FFN Down + Residual 2"
                  if include_ffn else "") +
                 (" + Product KV cache roundtrip of RTL-produced K/V projection words"
                  if include_kv_roundtrip else "") +
                 (" + Product KV write/read buffers consumed directly by causal QK/AV"
                  if include_kv_attention else ""),
        "seed": seed, "tokens": tokens, "layer_index": layer_index,
        "input_hidden_sha256": (hashlib.sha256(np.asarray(input_hidden_i32, dtype=np.int32).tobytes()).hexdigest()
                                if input_hidden_i32 is not None else None),
        "stream_norm_params": stream_norm_params, "descriptor_abi": "v7.4",
        "kv_append_from": kv_append_from,
        "canonical_model_file": "canonical_h64_model.npz" if include_ffn else None,
        "canonical_model_sha256": model_sha256,
        "descriptor_base": desc_base, "completion_base": cpl_base,
        "queue_size": (queue_slots if include_ffn else 128),
        "descriptor_count": len(mapper.descriptors), "golden_words": len(golden),
        "kv_roundtrip": ({
            "status": "PRODUCT_TOP_REQUIRED",
            "cache_shape_words": [4, 16, 16],
            "tokens_written_read": len(tokens), "heads_written_read": 4,
            "kv_write_descriptors": 2 * len(tokens) * 4,
            "kv_read_descriptors": 2 * 4,
            "readback_checkpoints": len(kv_read_snapshots),
            "token_stride_bytes": token_stride,
            "head_stride_bytes": head_stride,
        } if include_kv_roundtrip else None),
        "kv_attention": ({
            "status": "PRODUCT_TOP_REQUIRED",
            "cache_capacity_tokens": 16,
            "valid_token_count": len(tokens),
            "heads": 4,
            "head_dim": 16,
            "k_token_append_descriptors": ((len(tokens) - kv_append_from) * 4
                                            if kv_k_write_mode == "token-append" else 0),
            "k_qk_compatible_append_descriptors": ((len(tokens) - kv_append_from) * 4
                                            if kv_k_write_mode == "qk-compatible-append" else 0),
            "k_tile_write_descriptors": (4
                                         if kv_k_write_mode == "matrix-a-tile" else 0),
            "k_word_write_descriptors": (len(tokens) * 4 * 4
                                         if kv_k_write_mode == "matrix-a-word" else 0),
            "v_token_append_descriptors": (len(tokens) - kv_append_from) * 4,
            "read_descriptors": 2 * 4,
            "k_write_mode": kv_k_write_mode,
            "k_write_granularity": ("four QK-compatible packed words per token and head"
                                    if kv_k_write_mode == "qk-compatible-append" else
                                    "one Matrix-B token append per token and head"
                                    if kv_k_write_mode == "token-append" else
                                    "one complete Matrix-A packed K tile per head"
                                    if kv_k_write_mode == "matrix-a-tile" else
                                    "four single-word Matrix-A K-group writes per token and head"),
            "qk_matrix_source": ("Product KV_READ K buffer in QK-compatible Matrix-B K-transpose order"
                                 if kv_k_write_mode == "qk-compatible-append" else
                                 "Product KV_READ K buffer in Matrix-B token append order"
                                 if kv_k_write_mode == "token-append" else
                                 "Product KV_READ K buffer in Matrix-A tile order"),
            "av_matrix_source": "Product KV_READ V buffer",
            "future_token_slots": "initialized sentinel; masked by causal softmax",
        } if include_kv_attention else None),
        "executed_macs": executed_macs, "useful_macs": useful_macs,
        "attention_useful_macs": attention_useful_macs,
        "padding_macs": executed_macs - useful_macs,
        "useful_output_elements": useful_output_elements,
        "physical_output_elements": physical_output_elements,
        "golden_sha256": hashlib.sha256((out / "model_golden.memh").read_bytes()).hexdigest(),
        "memory_sha256": hashlib.sha256((out / "model_memory.memh").read_bytes()).hexdigest(),
        "spad_capacity_bytes": 131072,
        "high_water_bytes": max(image) + 4,
        "tensor_allocation": allocation,
        "intermediate_checkpoints": [
            {"tensor_id": item["name"],
             "descriptor_index": item["descriptor_index"],
             "golden_words": len(item["pairs"])}
            for item in checkpoint_records
        ],
        "dma_weight_streaming": ({
            "mode": "one AXI4 DMA transaction per initialized matrix weight tensor",
            "completion_fence": "DMA done/status checked before CMDQ publication",
            "image_excludes_dma_weight_ranges": True,
            "transactions": [{key: value for key, value in item.items()
                              if key != "values"} for item in dma_weight_records],
            "payload_bytes": sum(item["words"] * 4 for item in dma_weight_records),
            "payload_words": sum(item["words"] for item in dma_weight_records),
            "payload_sha256": hashlib.sha256((out / "dma_payload.memh").read_bytes()).hexdigest(),
            "plan_sha256": hashlib.sha256((out / "dma_plan.memh").read_bytes()).hexdigest(),
        } if include_ffn else None),
        "preload_mode": "host AXI-Lite fixture initialization; excluded from command_cycles",
        "formats": {"embedding_position": "signed INT32 container of selected INT8 values",
                    "LayerNorm gamma": "canonical signed INT8 gamma multiplied by 1024 to Q0.15",
                    "LayerNorm beta": "canonical signed INT32 beta",
                    "LayerNorm output": "INT32; product integer LayerNorm reference",
                    "Matrix input": "signed INT8 packed tile-A, arithmetic shift 0",
                    "Matrix accumulation": "signed INT32, ordered K accumulation",
                    "GELU": "product Q8.8 quadratic approximation",
                    "Requant": "arithmetic right shift then signed INT8 saturation; no rounding bias",
                    "LM logits": "16 physical N=16 GEMM tiles stored tile-major; Host may assemble each valid token row"},
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
    print(f"H64_PRELN_{'FULL_DECODER' if include_ffn else 'ATTENTION' if include_attention else 'QKV'}_GENERATOR_PASS desc={len(mapper.descriptors)} tokens={len(tokens)} "
          f"golden_words={len(golden)} high_water={manifest['high_water_bytes']}")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261114)
    parser.add_argument("--attention", action="store_true")
    parser.add_argument("--full-decoder", action="store_true")
    parser.add_argument("--kv-roundtrip", action="store_true",
                        help="append Product KV write/read of RTL-produced H64 K/V words")
    parser.add_argument("--kv-attention", action="store_true",
                        help="feed Product KV_READ buffers into H64 QK/AV attention")
    parser.add_argument("--tokens", default=None,
                        help="comma-separated token IDs; defaults to the four-token fixture")
    parser.add_argument("--kv-k-write-mode",
                        choices=("token-append", "qk-compatible-append",
                                 "matrix-a-tile", "matrix-a-word"),
                        default="token-append")
    parser.add_argument("--kv-append-from", type=int, default=0,
                        help="first token position whose K/V is written by this invocation")
    args = parser.parse_args()
    token_ids = ([int(value) for value in args.tokens.split(",")]
                 if args.tokens is not None else None)
    generate(args.out, args.seed, args.attention or args.full_decoder,
             args.full_decoder, args.kv_roundtrip, args.kv_attention, token_ids,
             args.kv_k_write_mode, args.kv_append_from)


if __name__ == "__main__":
    main()
