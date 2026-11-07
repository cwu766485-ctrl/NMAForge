#!/usr/bin/env python3
"""Deterministic descriptor mapper for a 4-token CIMForge Transformer block.

The workload is intentionally small enough for RTL simulation, but every edge
is real: Q/K/V projection, QK^T, row softmax, AV, output projection, residual,
LayerNorm, FFN GEMM/GELU/GEMM, residual and final LayerNorm.  The mapper owns
scratchpad allocation, tensor layout conversion and ABI-v7 descriptor encoding.
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(
    0,
    str(REPO_ROOT / "dv" / "block" / "compute" / "matrix" / "ref"),
)
from ai_a3_reference import (  # noqa: E402
    ffn_i8,
    gelu_q8_8,
    gemm_i8_i32,
    layernorm_q15,
    requant_i8,
    residual_i32,
    softmax_q15,
)


OP_GEMM = 0x30
OP_GEMV_KFOLD = 0x52
OP_GEMM_REQUANT_TILE_A = 0x53
OP_SOFTMAX = 0x32
OP_RESIDUAL = 0x34
OP_GELU = 0x35
OP_REQUANT = 0x36
OP_LAYERNORM = 0x38
OP_CAUSAL_SOFTMAX = 0x39
OP_KV_WRITE = 0x43
OP_KV_READ = 0x44
FLAG_BIAS = 1 << 0
FLAG_TRANSPOSE_A = 1 << 1
FLAG_TRANSPOSE_B = 1 << 2
FLAG_PACK_I8 = 1 << 4
FLAG_PACK_I8_TILE_A = 1 << 5
DESC_VERSION = 7
MODEL_WEIGHTS = {
    "wq": [
        [1, 0, 0, 1], [0, 1, 1, 0], [1, -1, 0, 0], [0, 0, 1, -1],
    ],
    "wk": [
        [1, 1, 0, 0], [0, 1, -1, 0], [0, 0, 1, 1], [1, 0, 0, -1],
    ],
    "wv": [
        [1, 0, 1, 0], [0, 1, 0, -1], [1, 1, 0, 0], [0, 0, 1, 1],
    ],
    "wo": [
        [1, 0, 0, 1], [0, 1, -1, 0], [1, 0, 1, 0], [0, 1, 0, 1],
    ],
    "wup": [[64, 0, 8, 0], [0, 64, 0, 8], [8, 0, 64, 0], [0, 8, 0, 64]],
    "wdown": [[1, 0, 1, 0], [0, 1, 0, 1], [1, -1, 0, 0], [0, 0, 1, -1]],
}


def align(value: int, alignment: int = 64) -> int:
    return (value + alignment - 1) & -alignment


def u32(value: int) -> int:
    return value & 0xFFFFFFFF


def flatten(matrix: list[list[int]]) -> list[int]:
    return [value for row in matrix for value in row]


def transpose(matrix: list[list[int]]) -> list[list[int]]:
    return [list(column) for column in zip(*matrix)]


def pack_i8(values: list[int]) -> int:
    if len(values) != 4:
        raise ValueError("one packed word requires four INT8 values")
    word = 0
    for lane, value in enumerate(values):
        if not -128 <= value <= 127:
            raise ValueError(f"INT8 value out of range: {value}")
        word |= (value & 0xFF) << (lane * 8)
    return word


def pack_rows(matrix: list[list[int]]) -> list[int]:
    return [pack_i8(row) for row in matrix]


def pack_columns(matrix: list[list[int]]) -> list[int]:
    return [pack_i8(column) for column in transpose(matrix)]


def pack_matrix_words(matrix: list[list[int]]) -> list[int]:
    values = flatten(matrix)
    return [pack_i8(values[index:index + 4])
            for index in range(0, len(values), 4)]


@dataclass
class Tensor:
    name: str
    addr: int
    shape: tuple[int, ...]
    dtype: str
    layout: str
    values: list[int]
    initialized: bool


@dataclass
class Descriptor:
    name: str
    task_id: int
    op: int
    src0: int
    src1: int
    dst: int
    m: int = 0
    n: int = 0
    k_or_length: int = 0
    flags: int = 0
    aux0: int = 0
    shift: int = 0
    activation: int = 0
    bias: int = 0
    wait_mask: int = 0
    signal_mask: int = 0
    clear_mask: int = 0
    src0_stride: int = 0
    src1_stride: int = 0
    dst_stride: int = 0
    batch_count: int = 1
    head_count: int = 1

    def words(self) -> list[int]:
        words = [0] * 16
        words[0] = (self.task_id << 16) | self.op
        words[1] = self.src0
        words[2] = self.src1
        words[3] = self.bias
        words[4] = self.dst
        words[5] = (self.n << 16) | self.m
        words[6] = self.k_or_length
        words[7] = self.flags
        words[8] = self.aux0
        words[9] = (self.shift & 0x1F) | ((self.activation & 0x3) << 5)
        words[10] = self.src0_stride
        words[11] = self.src1_stride
        words[12] = self.dst_stride
        # ABI-v7 word 13 stores head_count in the upper half and
        # batch_count in the lower half (see ai_desc_fetch).
        words[13] = (self.head_count << 16) | self.batch_count
        words[14] = (self.signal_mask << 16) | self.wait_mask
        words[15] = (self.clear_mask << 16) | DESC_VERSION
        return [u32(word) for word in words]


def validate_fused_tile_fields(descriptor: Descriptor) -> None:
    """Validate the ABI-v7 opt-in layout and forwarding bits for opcode 0x53."""
    capture = bool(descriptor.aux0 & (1 << 5))
    consume = bool(descriptor.aux0 & (1 << 6))
    linearized = bool(descriptor.aux0 & (1 << 7))
    if descriptor.aux0 & ~0xFF:
        raise ValueError(
            f"{descriptor.name}: fused Matrix aux0 must fit eight bits"
        )
    if linearized and (
        capture or consume or descriptor.n != 4 or descriptor.m > 64
        or descriptor.m % 4 or descriptor.dst_stride != 0
        or (descriptor.flags & (FLAG_TRANSPOSE_A | FLAG_TRANSPOSE_B))
    ):
        raise ValueError(
            f"{descriptor.name}: linear row layout requires M=4..64, N=4, "
            "one dense instance and no transpose/forwarding flags"
        )
    if descriptor.dst & 0xF or descriptor.dst_stride & 0xF:
        raise ValueError(
            f"{descriptor.name}: fused tile destination/stride must be 16-byte aligned"
        )
    if descriptor.m % 4 or descriptor.n % 4:
        raise ValueError(
            f"{descriptor.name}: fused Matrix-A tile shape must be 4-aligned"
        )
    if capture and (
        descriptor.m != 16 or descriptor.n != 16 or descriptor.dst_stride != 0
    ):
        raise ValueError(
            f"{descriptor.name}: tile capture requires dense 16x16 output"
        )
    if consume and (
        descriptor.m != 16
        or descriptor.k_or_length != 4
        or (descriptor.flags & FLAG_TRANSPOSE_A)
        or descriptor.src0_stride != 0
    ):
        raise ValueError(
            f"{descriptor.name}: tile consume requires M=16, K=4, dense non-transposed A"
        )


class Mapper:
    def __init__(self) -> None:
        self.next_addr = 0x10000
        self.tensors: dict[str, Tensor] = {}
        self.descriptors: list[Descriptor] = []
        self.task_id = 0x7000

    def tensor(
        self, name: str, shape: tuple[int, ...], dtype: str, layout: str,
        values: list[int] | None = None, initialized: bool = True,
    ) -> Tensor:
        count = 1
        for dimension in shape:
            count *= dimension
        stored_words = count // 4 if dtype == "i8_packed" else count
        if dtype == "i8_packed" and count % 4:
            raise ValueError("packed tensor element count must be divisible by four")
        addr = align(self.next_addr)
        self.next_addr = addr + stored_words * 4
        tensor = Tensor(
            name, addr, shape, dtype, layout, values or [], initialized
        )
        self.tensors[name] = tensor
        return tensor

    def add(self, name: str, op: int, src0: Tensor, dst: Tensor, **kwargs: int) -> None:
        src1 = kwargs.pop("src1", 0)
        if isinstance(src1, Tensor):
            src1 = src1.addr
        bias = kwargs.pop("bias", 0)
        if isinstance(bias, Tensor):
            bias = bias.addr
        src0_addr = src0.addr + kwargs.pop("src0_offset", 0)
        dst_addr = dst.addr + kwargs.pop("dst_offset", 0)
        descriptor = Descriptor(
            name=name, task_id=self.task_id, op=op, src0=src0_addr,
            src1=src1, dst=dst_addr, bias=bias, **kwargs,
        )
        self.descriptors.append(descriptor)
        self.task_id += 1


def causal_softmax_q15(scores: list[int], query_token: int) -> list[int]:
    if not 0 <= query_token < len(scores):
        raise ValueError("causal query token must be within score length")
    visible = softmax_q15(scores[: query_token + 1])
    return visible + [0] * (len(scores) - len(visible))


def build_workload(
    model: dict | None = None,
    decode_mapping_policy: str = "gemm",
) -> tuple[Mapper, dict[str, list]]:
    if decode_mapping_policy not in ("gemm", "gemv_qkv"):
        raise ValueError(f"unsupported decode mapping policy: {decode_mapping_policy}")
    mapper = Mapper()
    if model is None:
        x = [
            [1, 2, 0, -1],
            [0, 1, 2, 1],
            [2, 0, 1, 1],
            [1, -1, 0, 2],
        ]
        decode_token = [1, -1, 2, 0]
        model_weights = MODEL_WEIGHTS
    else:
        tokens = model.get("prefill_tokens")
        decode_id = model.get("decode_token")
        model_weights = model.get("weights")
        if not isinstance(tokens, list) or len(tokens) != 4 or any(
            not isinstance(token, int) or token not in range(4)
            for token in tokens
        ):
            raise ValueError("trained model prefill_tokens must be four IDs in [0, 3]")
        if not isinstance(decode_id, int) or decode_id not in range(4):
            raise ValueError("trained model decode_token must be an ID in [0, 3]")
        required = {"wq", "wk", "wv", "wo", "wup", "wdown"}
        if not isinstance(model_weights, dict) or set(model_weights) != required:
            raise ValueError("trained model must provide exactly six INT8 matrices")
        for name, matrix in model_weights.items():
            if (not isinstance(matrix, list) or len(matrix) != 4 or
                any(not isinstance(row, list) or len(row) != 4 for row in matrix) or
                any(not isinstance(value, int) or not -128 <= value <= 127
                    for row in matrix for value in row)):
                raise ValueError(f"trained model {name} must be a 4x4 INT8 matrix")
        x = [[int(token == lane) for lane in range(4)] for token in tokens]
        decode_token = [int(decode_id == lane) for lane in range(4)]
    wq, wk, wv = model_weights["wq"], model_weights["wk"], model_weights["wv"]
    wo, w_up, w_down = (
        model_weights["wo"], model_weights["wup"], model_weights["wdown"]
    )
    gamma = [32768] * 4
    beta = [0] * 4

    x8 = mapper.tensor("x_i8", (4, 4), "i8_packed", "row-major", pack_rows(x))
    x32 = mapper.tensor("x_i32", (4, 4), "i32", "row-major", flatten(x))
    wq_t = mapper.tensor("wq", (4, 4), "i8_packed", "column-major", pack_columns(wq))
    wk_t = mapper.tensor("wk", (4, 4), "i8_packed", "column-major", pack_columns(wk))
    wv_t = mapper.tensor("wv", (4, 4), "i8_packed", "column-major", pack_columns(wv))
    wo_t = mapper.tensor("wo", (4, 4), "i8_packed", "column-major", pack_columns(wo))
    wup = mapper.tensor("wup", (4, 4), "i8_packed", "column-major", pack_columns(w_up))
    wdown_t = mapper.tensor("wdown", (4, 4), "i8_packed", "column-major", pack_columns(w_down))
    gamma_t = mapper.tensor("gamma", (4,), "i32", "vector", gamma)
    beta_t = mapper.tensor("beta", (4,), "i32", "vector", beta)

    def empty_i32(
        name: str, shape: tuple[int, int] = (4, 4),
        zero_pad: bool = False,
    ) -> Tensor:
        # Poison every destination before execution.  This prevents a stale or
        # preloaded golden tensor from making the RTL check pass accidentally.
        # A one-row GEMV into a four-row decode tensor explicitly initializes
        # the three architecturally unused rows to zero; these are padding,
        # not computed or expected output data.
        return mapper.tensor(
            name, shape, "i32", "row-major",
            ([0] if zero_pad else [0x5A5AA5A5]) * (shape[0] * shape[1]),
            initialized=zero_pad,
        )

    def empty_i8(name: str, shape: tuple[int, int] = (4, 4)) -> Tensor:
        return mapper.tensor(
            name, shape, "i8_packed", "row-major",
            [0xA55AA55A] * (shape[0] * shape[1] // 4),
            initialized=False,
        )

    q32, q8 = empty_i32("q_i32"), empty_i8("q_i8")
    k32, k8 = empty_i32("k_i32"), empty_i8("k_i8")
    v32, v8 = empty_i32("v_i32"), empty_i8("v_i8")
    k_cache = mapper.tensor(
        "k_cache", (8, 4), "i8_packed", "row-major",
        [0x5A5AA5A5] * 5 + [0, 0, 0], initialized=True,
    )
    v_cache = mapper.tensor(
        "v_cache", (8, 4), "i8_packed", "row-major",
        [0xA55A5AA5] * 5 + [0, 0, 0], initialized=True,
    )
    k_prefill, v_prefill = empty_i8("k_prefill"), empty_i8("v_prefill")
    # The first four words are the prefill key/value rows. Decode reads these
    # back from KV SPAD so its attention operands exercise the real KV engine.
    k_decode, v_decode = empty_i8("k_decode"), empty_i8("v_decode")
    scores = empty_i32("scores")
    probs32, probs8 = empty_i32("prob_q15"), empty_i8("prob_i8")
    attention32, attention8 = empty_i32("attention_i32"), empty_i8("attention_i8")
    projected = empty_i32("projected")
    residual1, norm1, norm1_i8 = empty_i32("residual1"), empty_i32("norm1"), empty_i8("norm1_i8")
    ffn_up, gelu, gelu_i8 = empty_i32("ffn_up"), empty_i32("gelu"), empty_i8("gelu_i8")
    ffn_down, residual2, norm2 = empty_i32("ffn_down"), empty_i32("residual2"), empty_i32("norm2")

    def gemm(
        name: str, lhs: Tensor, rhs: Tensor, dst: Tensor,
        flags: int = 0, m: int = 4, n: int = 4, k: int = 1,
    ) -> None:
        mapper.add(name, OP_GEMM, lhs, dst, src1=rhs, m=m, n=n,
                   k_or_length=k, flags=flags, aux0=1)

    def gemv_rhs(name: str, matrix: list[list[int]]) -> Tensor:
        """Pack W[N,K] as the 0x52 dense K-major, N-padded operand."""
        n_dim = len(matrix)
        k_dim = len(matrix[0]) if matrix else 0
        if not (1 <= n_dim <= 16 and k_dim > 0 and
                all(len(row) == k_dim for row in matrix)):
            raise ValueError(f"{name}: opcode 0x52 requires N=1..16 and rectangular K")
        words: list[int] = []
        for k_index in range(k_dim):
            row = [matrix[n_index][k_index] for n_index in range(n_dim)]
            row.extend([0] * (16 - n_dim))
            words.extend(pack_i8(row[offset:offset + 4])
                         for offset in range(0, 16, 4))
        return mapper.tensor(
            name, (k_dim * 16,), "i8_packed", "k-major-n-padded", words
        )

    def gemv_qkv(name: str, lhs: Tensor, rhs: Tensor, dst: Tensor) -> None:
        if len(dst.shape) != 2 or dst.shape[0] != 4:
            raise ValueError(f"{name}: padded decode destination must have four rows")
        mapper.add(
            name, OP_GEMV_KFOLD, lhs, dst, src1=rhs.addr, m=1, n=4,
            k_or_length=4, batch_count=1, head_count=0,
        )

    def pack(name: str, src: Tensor, dst: Tensor, shift: int, length: int = 16,
             tile_a_shape: tuple[int, int] | None = None) -> None:
        flags = FLAG_PACK_I8
        m = n = 0
        if tile_a_shape is not None:
            m, n = tile_a_shape
            if m <= 0 or n <= 0 or m % 4 or n % 4 or length != m * n:
                raise ValueError("PACK_I8_TILE_A needs M,N multiples of four and length=M*N")
            flags |= FLAG_PACK_I8_TILE_A
        mapper.add(name, OP_REQUANT, src, dst, m=m, n=n,
                   k_or_length=length, flags=flags, shift=shift, aux0=1)

    def kv_write(
        name: str, src: Tensor, cache: Tensor, token: int,
        source_row: int | None = None,
    ) -> None:
        row = token if source_row is None else source_row
        mapper.add(name, OP_KV_WRITE, src, cache, src0_offset=row * 4,
                   k_or_length=1, aux0=token, src0_stride=4,
                   src1_stride=32)

    def kv_read(
        name: str, cache: Tensor, dst: Tensor, token: int,
        destination_row: int | None = None,
    ) -> None:
        row = token if destination_row is None else destination_row
        mapper.add(name, OP_KV_READ, cache, dst, dst_offset=row * 4,
                   k_or_length=1, aux0=token, src0_stride=4,
                   src1_stride=32)

    def add_causal_softmax_rows(
        source: Tensor, destination: Tensor, width: int,
        query_tokens: list[int], name: str,
    ) -> None:
        for row, query_token in enumerate(query_tokens):
            mapper.add(
                f"{name}_row{row}", OP_CAUSAL_SOFTMAX, source, destination,
                k_or_length=width, aux0=query_token,
                src0_offset=row * width * 4,
                dst_offset=row * width * 4,
            )

    decode_rows = [decode_token, [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
    decode_i8 = mapper.tensor(
        "decode_x_i8", (4, 4), "i8_packed", "row-major", pack_rows(decode_rows)
    )
    decode_i32 = mapper.tensor(
        "decode_x_i32", (4, 4), "i32", "row-major", flatten(decode_rows)
    )
    qkv_zero_pad = decode_mapping_policy == "gemv_qkv"
    qd32 = empty_i32("decode_q_i32", zero_pad=qkv_zero_pad)
    qd8 = empty_i8("decode_q_i8")
    kd32 = empty_i32("decode_k_i32", zero_pad=qkv_zero_pad)
    kd8 = empty_i8("decode_k_i8")
    vd32 = empty_i32("decode_v_i32", zero_pad=qkv_zero_pad)
    vd8 = empty_i8("decode_v_i8")
    decode_scores = empty_i32("decode_scores")
    decode_probs32 = empty_i32("decode_prob_q15")
    decode_probs8 = empty_i8("decode_prob_i8")
    decode_attention32 = empty_i32("decode_attention_i32")
    decode_attention8 = empty_i8("decode_attention_i8")
    decode_projected = empty_i32("decode_projected")
    decode_residual1 = empty_i32("decode_residual1")
    decode_norm1 = empty_i32("decode_norm1")
    decode_norm1_i8 = empty_i8("decode_norm1_i8")
    decode_ffn_up = empty_i32("decode_ffn_up")
    decode_gelu = empty_i32("decode_gelu")
    decode_gelu_i8 = empty_i8("decode_gelu_i8")
    decode_ffn_down = empty_i32("decode_ffn_down")
    decode_residual2 = empty_i32("decode_residual2")
    decode_norm2 = empty_i32("decode_norm2")

    gemm("q_projection", x8, wq_t, q32)
    pack("q_pack", q32, q8, 0)
    gemm("k_projection", x8, wk_t, k32)
    pack("k_pack", k32, k8, 0)
    gemm("v_projection", x8, wv_t, v32)
    pack("v_pack", v32, v8, 0)

    # Prefill stores each projected token key/value through the production KV
    # engine, then reads the cache back into the attention operands.
    for token in range(4):
        kv_write(f"prefill_kv_write_k{token}", k8, k_cache, token)
        kv_write(f"prefill_kv_write_v{token}", v8, v_cache, token)
    for token in range(4):
        kv_read(f"prefill_kv_read_k{token}", k_cache, k_prefill, token)
        kv_read(f"prefill_kv_read_v{token}", v_cache, v_prefill, token)

    # K rows are token-major with four feature bytes per word; the controller's
    # default B mapping consumes this layout as the logical K^T operand.
    gemm("qk_transpose", q8, k_prefill, scores)
    add_causal_softmax_rows(scores, probs32, 4, [0, 1, 2, 3], "prefill_causal_softmax")
    pack("prob_pack", probs32, probs8, 8)
    gemm("attention_value", probs8, v_prefill, attention32, FLAG_TRANSPOSE_B)
    pack("attention_pack", attention32, attention8, 7)
    gemm("output_projection", attention8, wo_t, projected)
    mapper.add("residual1", OP_RESIDUAL, projected, residual1, src1=x32,
               k_or_length=16, aux0=1)
    for row in range(4):
        mapper.add(f"layernorm1_row{row}", OP_LAYERNORM, residual1, norm1,
                   src1=gamma_t, bias=beta_t, k_or_length=4,
                   flags=FLAG_BIAS, aux0=1)
        mapper.descriptors[-1].src0 += row * 16
        mapper.descriptors[-1].dst += row * 16
    pack("norm1_pack", norm1, norm1_i8, 0)
    gemm("ffn_up", norm1_i8, wup, ffn_up)
    mapper.add("gelu", OP_GELU, ffn_up, gelu, k_or_length=16, aux0=1)
    pack("gelu_pack", gelu, gelu_i8, 0)
    gemm("ffn_down", gelu_i8, wdown_t, ffn_down)
    mapper.add("residual2", OP_RESIDUAL, ffn_down, residual2, src1=norm1,
               k_or_length=16, aux0=1)
    for row in range(4):
        mapper.add(f"layernorm2_row{row}", OP_LAYERNORM, residual2, norm2,
                   src1=gamma_t, bias=beta_t, k_or_length=4,
                   flags=FLAG_BIAS, aux0=1)
        mapper.descriptors[-1].src0 += row * 16
        mapper.descriptors[-1].dst += row * 16

    prefill_descriptor_count = len(mapper.descriptors)

    # Decode one new token after prefill. Its key/value update token slot 4;
    # attention then reads the latest four-token sliding context window.
    if qkv_zero_pad:
        wq_gemv = gemv_rhs("decode_wq_gemv", wq)
        wk_gemv = gemv_rhs("decode_wk_gemv", wk)
        wv_gemv = gemv_rhs("decode_wv_gemv", wv)
        gemv_qkv("decode_q_projection", decode_i8, wq_gemv, qd32)
    else:
        gemm("decode_q_projection", decode_i8, wq_t, qd32)
    pack("decode_q_pack", qd32, qd8, 0)
    if qkv_zero_pad:
        gemv_qkv("decode_k_projection", decode_i8, wk_gemv, kd32)
    else:
        gemm("decode_k_projection", decode_i8, wk_t, kd32)
    pack("decode_k_pack", kd32, kd8, 0)
    if qkv_zero_pad:
        gemv_qkv("decode_v_projection", decode_i8, wv_gemv, vd32)
    else:
        gemm("decode_v_projection", decode_i8, wv_t, vd32)
    pack("decode_v_pack", vd32, vd8, 0)
    kv_write("decode_kv_write_k4", kd8, k_cache, 4, source_row=0)
    kv_write("decode_kv_write_v4", vd8, v_cache, 4, source_row=0)
    for row, token in enumerate(range(1, 5)):
        kv_read(f"decode_kv_read_k{token}", k_cache, k_decode, token, row)
        kv_read(f"decode_kv_read_v{token}", v_cache, v_decode, token, row)
    gemm("decode_qk_transpose", qd8, k_decode, decode_scores)
    add_causal_softmax_rows(
        decode_scores, decode_probs32, 4, [3, 3, 3, 3], "decode_causal_softmax"
    )
    pack("decode_prob_pack", decode_probs32, decode_probs8, 8)
    gemm("decode_attention_value", decode_probs8, v_decode, decode_attention32,
         FLAG_TRANSPOSE_B)
    pack("decode_attention_pack", decode_attention32, decode_attention8, 7)
    gemm("decode_output_projection", decode_attention8, wo_t, decode_projected)
    mapper.add("decode_residual1", OP_RESIDUAL, decode_projected,
               decode_residual1, src1=decode_i32, k_or_length=16, aux0=1)
    for row in range(4):
        mapper.add(
            f"decode_layernorm1_row{row}", OP_LAYERNORM, decode_residual1,
            decode_norm1, src1=gamma_t, bias=beta_t, k_or_length=4,
            flags=FLAG_BIAS, aux0=1, src0_offset=row * 16,
            dst_offset=row * 16,
        )
    pack("decode_norm1_pack", decode_norm1, decode_norm1_i8, 0)
    gemm("decode_ffn_up", decode_norm1_i8, wup, decode_ffn_up)
    mapper.add("decode_gelu", OP_GELU, decode_ffn_up, decode_gelu,
               k_or_length=16, aux0=1)
    pack("decode_gelu_pack", decode_gelu, decode_gelu_i8, 0)
    gemm("decode_ffn_down", decode_gelu_i8, wdown_t, decode_ffn_down)
    mapper.add("decode_residual2", OP_RESIDUAL, decode_ffn_down,
               decode_residual2, src1=decode_norm1, k_or_length=16, aux0=1)
    for row in range(4):
        mapper.add(
            f"decode_layernorm2_row{row}", OP_LAYERNORM, decode_residual2,
            decode_norm2, src1=gamma_t, bias=beta_t, k_or_length=4,
            flags=FLAG_BIAS, aux0=1, src0_offset=row * 16,
            dst_offset=row * 16,
        )

    q = gemm_i8_i32(x, wq)
    key = gemm_i8_i32(x, wk)
    value = gemm_i8_i32(x, wv)
    q_i8 = [requant_i8(row, 0) for row in q]
    k_i8 = [requant_i8(row, 0) for row in key]
    v_i8 = [requant_i8(row, 0) for row in value]
    score_golden = gemm_i8_i32(q_i8, transpose(k_i8))
    probability_q15 = [causal_softmax_q15(row, row_index)
                       for row_index, row in enumerate(score_golden)]
    probability_i8 = [requant_i8(row, 8) for row in probability_q15]
    attended = gemm_i8_i32(probability_i8, v_i8)
    attended_i8 = [requant_i8(row, 7) for row in attended]
    projection = gemm_i8_i32(attended_i8, wo)
    residual_1 = [residual_i32(a, b) for a, b in zip(projection, x)]
    norm_1 = [layernorm_q15(row, gamma, beta) for row in residual_1]
    norm_1_i8 = [requant_i8(row, 0) for row in norm_1]
    expanded = gemm_i8_i32(norm_1_i8, w_up)
    activated = [[gelu_q8_8(value) for value in row] for row in expanded]
    activated_i8 = [requant_i8(row, 0) for row in activated]
    down = gemm_i8_i32(activated_i8, w_down)
    residual_2 = [residual_i32(a, b) for a, b in zip(down, norm_1)]
    norm_2 = [layernorm_q15(row, gamma, beta) for row in residual_2]

    # Cross-check the standalone FFN composition helper on the same tensors.
    assert ffn_i8(norm_1_i8, w_up, w_down, 0) == down

    decode_q = gemm_i8_i32(decode_rows, wq)
    decode_key = gemm_i8_i32(decode_rows, wk)
    decode_value = gemm_i8_i32(decode_rows, wv)
    decode_q_i8 = [requant_i8(row, 0) for row in decode_q]
    decode_key_i8 = [requant_i8(row, 0) for row in decode_key]
    decode_value_i8 = [requant_i8(row, 0) for row in decode_value]
    key_cache_golden = k_i8 + [decode_key_i8[0]] + [[0, 0, 0, 0] for _ in range(3)]
    value_cache_golden = v_i8 + [decode_value_i8[0]] + [[0, 0, 0, 0] for _ in range(3)]
    decode_key_window = key_cache_golden[1:5]
    decode_value_window = value_cache_golden[1:5]
    decode_scores_golden = gemm_i8_i32(
        decode_q_i8, transpose(decode_key_window)
    )
    decode_probs_golden = [causal_softmax_q15(row, 3)
                            for row in decode_scores_golden]
    decode_prob_i8 = [requant_i8(row, 8) for row in decode_probs_golden]
    decode_attended = gemm_i8_i32(decode_prob_i8, decode_value_window)
    decode_attended_i8 = [requant_i8(row, 7) for row in decode_attended]
    decode_projection = gemm_i8_i32(decode_attended_i8, wo)
    decode_residual_1 = [
        residual_i32(a, b) for a, b in zip(decode_projection, decode_rows)
    ]
    decode_norm_1 = [layernorm_q15(row, gamma, beta) for row in decode_residual_1]
    decode_norm_1_i8 = [requant_i8(row, 0) for row in decode_norm_1]
    decode_expanded = gemm_i8_i32(decode_norm_1_i8, w_up)
    decode_activated = [
        [gelu_q8_8(value) for value in row] for row in decode_expanded
    ]
    decode_activated_i8 = [requant_i8(row, 0) for row in decode_activated]
    decode_down = gemm_i8_i32(decode_activated_i8, w_down)
    decode_residual_2 = [
        residual_i32(a, b) for a, b in zip(decode_down, decode_norm_1)
    ]
    decode_norm_2 = [layernorm_q15(row, gamma, beta) for row in decode_residual_2]
    # The generated chain reuses destinations and crosses engines.  Publish a
    # two-token dependency chain so its reference result remains deterministic
    # with parallel dispatch enabled.  Independent software workloads can
    # leave these masks clear and use separate engine slots concurrently.
    for index, descriptor in enumerate(mapper.descriptors):
        if index:
            wait_token = 1 << ((index - 1) & 1)
            descriptor.wait_mask |= wait_token
            descriptor.clear_mask |= wait_token
        if index + 1 < len(mapper.descriptors):
            descriptor.signal_mask |= 1 << (index & 1)
    validate_descriptor_chain(mapper)
    expected = {
        "prefill_descriptor_count": prefill_descriptor_count,
        "decode_mapping_policy": decode_mapping_policy,
        "prefill_final": norm_2,
        "decode_final": decode_norm_2,
        "decode_q_i32": decode_q,
        "decode_q_i8_words": pack_matrix_words(decode_q_i8),
        "decode_k_i32": decode_key,
        "decode_k_i8_words": pack_matrix_words(decode_key_i8),
        "decode_v_i32": decode_value,
        "decode_v_i8_words": pack_matrix_words(decode_value_i8),
        "decode_scores": decode_scores_golden,
        "decode_prob_q15": decode_probs_golden,
        "decode_prob_i8_words": pack_matrix_words(decode_prob_i8),
        "decode_attention_i32": decode_attended,
        "decode_attention_i8_words": pack_matrix_words(decode_attended_i8),
        "decode_projected": decode_projection,
        "decode_residual1": decode_residual_1,
        "decode_norm1": decode_norm_1,
        "decode_norm1_i8_words": pack_matrix_words(decode_norm_1_i8),
        "decode_ffn_up": decode_expanded,
        "decode_gelu": decode_activated,
        "decode_gelu_i8_words": pack_matrix_words(decode_activated_i8),
        "decode_ffn_down": decode_down,
        "decode_residual2": decode_residual_2,
        "key_cache_words": [pack_i8(row) for row in key_cache_golden],
        "value_cache_words": [pack_i8(row) for row in value_cache_golden],
        "key_prefill_readback_words": [pack_i8(row) for row in k_i8],
        "value_prefill_readback_words": [pack_i8(row) for row in v_i8],
        "key_decode_readback_words": [pack_i8(row) for row in decode_key_window],
        "value_decode_readback_words": [pack_i8(row) for row in decode_value_window],
        "weights": model_weights,
    }
    if model is not None:
        labels = [(token + 1) % 4 for token in model["prefill_tokens"]]
        predicted = [max(range(4), key=row.__getitem__) for row in norm_2]
        decode_label = (model["decode_token"] + 1) % 4
        decode_prediction = max(range(4), key=decode_norm_2[0].__getitem__)
        expected["task_metrics"] = {
            "prefill_labels": labels,
            "prefill_predictions": predicted,
            "prefill_correct": sum(a == b for a, b in zip(labels, predicted)),
            "prefill_count": len(labels),
            "decode_label": decode_label,
            "decode_prediction": decode_prediction,
            "decode_correct": int(decode_label == decode_prediction),
        }
    return mapper, expected


def tensor_size_bytes(tensor: Tensor) -> int:
    count = 1
    for dimension in tensor.shape:
        count *= dimension
    return count if tensor.dtype == "i8_packed" else count * 4


def validate_descriptor_chain(mapper: Mapper) -> None:
    """Prove that every command reads initialized or previously produced data."""

    available = [
        (tensor.addr, tensor.addr + tensor_size_bytes(tensor), tensor.name)
        for tensor in mapper.tensors.values()
        if tensor.initialized
    ]

    def require(base: int, size: int, command: str, port: str) -> None:
        end = base + size
        covered = base
        for lo, hi, _ in sorted(available):
            if lo <= covered < hi:
                covered = hi
            if covered >= end:
                return
        raise ValueError(
            f"{command}.{port} reads 0x{base:x}..0x{end:x} "
            "before a producer has completed"
        )

    def allocation(base: int, size: int, command: str) -> str:
        for tensor in mapper.tensors.values():
            lo = tensor.addr
            hi = lo + tensor_size_bytes(tensor)
            if lo <= base and base + size <= hi:
                return tensor.name
        raise ValueError(
            f"{command}.dst 0x{base:x}..0x{base + size:x} is unallocated"
        )

    for descriptor in mapper.descriptors:
        source_base = descriptor.src0
        destination_base = descriptor.dst
        token_index = descriptor.aux0 & 0xFFFF
        head_index = (descriptor.aux0 >> 16) & 0xFFFF
        cache_offset = (
            token_index * descriptor.src0_stride
            + head_index * descriptor.src1_stride
        )
        if descriptor.op == OP_KV_WRITE:
            destination_base += cache_offset
        elif descriptor.op == OP_KV_READ:
            source_base += cache_offset
        if descriptor.op in (OP_GEMM, OP_GEMM_REQUANT_TILE_A):
            if descriptor.op == OP_GEMM_REQUANT_TILE_A:
                validate_fused_tile_fields(descriptor)
            require(
                source_base, descriptor.m * descriptor.k_or_length * 4,
                descriptor.name, "src0",
            )
            require(
                descriptor.src1, descriptor.n * descriptor.k_or_length * 4,
                descriptor.name, "src1",
            )
            output_bytes = descriptor.m * descriptor.n * (
                1 if descriptor.op == OP_GEMM_REQUANT_TILE_A else 4
            )
        elif descriptor.op == OP_GEMV_KFOLD:
            m, n, k = descriptor.m, descriptor.n, descriptor.k_or_length
            if not (1 <= m <= 16 and 1 <= n <= 16 and k > 0):
                raise ValueError(f"{descriptor.name}: illegal opcode 0x52 shape")
            if (descriptor.flags != 0 or descriptor.aux0 != 0 or
                    descriptor.batch_count > 1 or descriptor.head_count != 0 or
                    descriptor.src0_stride != 0 or descriptor.src1_stride != 0 or
                    descriptor.dst_stride != 0 or source_base & 0xF or
                    descriptor.src1 & 0xF or destination_base & 0x3):
                raise ValueError(f"{descriptor.name}: illegal opcode 0x52 fields")
            a_bytes = m * ((k + 15) & ~15)
            b_bytes = k * 16
            output_bytes = m * n * 4
            a_end, b_end, dst_end = source_base + a_bytes, descriptor.src1 + b_bytes, destination_base + output_bytes
            if max(a_end, b_end, dst_end) > 0x1_0000_0000:
                raise ValueError(f"{descriptor.name}: opcode 0x52 address range overflows")
            if ((destination_base < a_end and source_base < dst_end) or
                    (destination_base < b_end and descriptor.src1 < dst_end)):
                raise ValueError(f"{descriptor.name}: opcode 0x52 output aliases an operand")
            require(source_base, a_bytes, descriptor.name, "src0")
            require(descriptor.src1, b_bytes, descriptor.name, "src1")
        else:
            require(
                source_base, descriptor.k_or_length * 4,
                descriptor.name, "src0",
            )
            if descriptor.op == OP_RESIDUAL:
                require(
                    descriptor.src1, descriptor.k_or_length * 4,
                    descriptor.name, "src1",
                )
            if descriptor.op == OP_LAYERNORM:
                require(
                    descriptor.src1, descriptor.k_or_length * 4,
                    descriptor.name, "gamma",
                )
                if descriptor.flags & FLAG_BIAS:
                    require(
                        descriptor.bias, descriptor.k_or_length * 4,
                        descriptor.name, "beta",
                    )
            output_bytes = descriptor.k_or_length * 4
            if descriptor.op == OP_REQUANT and descriptor.flags & FLAG_PACK_I8:
                output_bytes = ((descriptor.k_or_length + 3) // 4) * 4

        tensor_name = allocation(
            destination_base, output_bytes, descriptor.name
        )
        available.append(
            (
                destination_base, destination_base + output_bytes,
                f"{descriptor.name}->{tensor_name}",
            )
        )


def tensor_storage_words(tensor: Tensor) -> list[int]:
    if tensor.dtype == "i8_packed":
        return [u32(value) for value in tensor.values]
    return [u32(value) for value in tensor.values]


def write_svh(path: Path, mapper: Mapper, expected: dict[str, list]) -> None:
    descriptor_base = align(mapper.next_addr, 0x1000)
    completion_base = align(descriptor_base + len(mapper.descriptors) * 64, 0x1000)
    lines = [
        "// Generated by sw/tools/cimforge_mapper.py; do not hand edit.",
        f"localparam [31:0] TRANSFORMER_DESC_BASE = 32'h{descriptor_base:08x};",
        f"localparam [31:0] TRANSFORMER_CPL_BASE = 32'h{completion_base:08x};",
        f"localparam integer TRANSFORMER_DESC_COUNT = {len(mapper.descriptors)};",
        f"localparam integer TRANSFORMER_PREFILL_DESC_COUNT = {expected['prefill_descriptor_count']};",
        f"localparam [15:0] TRANSFORMER_LAST_TASK_ID = 16'h{mapper.descriptors[-1].task_id:04x};",
        f"localparam [31:0] TRANSFORMER_LAST_RESULT = 32'h{u32(expected['decode_final'][-1][-1]):08x};",
        "",
        "task load_transformer_workload;",
        "  begin",
    ]
    for tensor in mapper.tensors.values():
        for index, word in enumerate(tensor_storage_words(tensor)):
            lines.append(
                f"    axi_write(SPAD_BASE + 32'h{tensor.addr + index * 4:08x}, "
                f"32'h{word:08x}); // {tensor.name}[{index}]"
            )
    for index, descriptor in enumerate(mapper.descriptors):
        base = descriptor_base + index * 64
        for word_index, word in enumerate(descriptor.words()):
            lines.append(
                f"    axi_write(SPAD_BASE + 32'h{base + word_index * 4:08x}, "
                f"32'h{word:08x}); // {descriptor.name}.word{word_index}"
            )
    lines += [
        "  end",
        "endtask",
        "",
        "task check_transformer_workload;",
        "  begin",
    ]
    for tensor_name, expected_name, label in (
        ("norm2", "prefill_final", "prefill final"),
        ("decode_norm2", "decode_final", "decode final"),
        ("decode_q_i32", "decode_q_i32", "decode Q projection"),
        ("decode_k_i32", "decode_k_i32", "decode K projection"),
        ("decode_v_i32", "decode_v_i32", "decode V projection"),
        ("decode_scores", "decode_scores", "decode attention score"),
        ("decode_prob_q15", "decode_prob_q15", "decode causal probability"),
        ("decode_attention_i32", "decode_attention_i32", "decode attention output"),
        ("decode_projected", "decode_projected", "decode output projection"),
        ("decode_residual1", "decode_residual1", "decode residual1"),
        ("decode_norm1", "decode_norm1", "decode layernorm1"),
        ("decode_ffn_up", "decode_ffn_up", "decode FFN up"),
        ("decode_gelu", "decode_gelu", "decode GELU"),
        ("decode_ffn_down", "decode_ffn_down", "decode FFN down"),
        ("decode_residual2", "decode_residual2", "decode residual2"),
    ):
        tensor = mapper.tensors[tensor_name]
        for index, value in enumerate(flatten(expected[expected_name])):
            lines.append(
                f"    expect_read(SPAD_BASE + 32'h{tensor.addr + index * 4:08x}, "
                f"32'h{u32(value):08x}, \"Transformer {label}[{index}]\");"
            )
    for tensor_name, expected_name, label in (
        ("decode_q_i8", "decode_q_i8_words", "decode Q packed"),
        ("decode_k_i8", "decode_k_i8_words", "decode K packed"),
        ("decode_v_i8", "decode_v_i8_words", "decode V packed"),
        ("decode_prob_i8", "decode_prob_i8_words", "decode probability packed"),
        ("decode_attention_i8", "decode_attention_i8_words", "decode attention packed"),
        ("decode_norm1_i8", "decode_norm1_i8_words", "decode norm1 packed"),
        ("decode_gelu_i8", "decode_gelu_i8_words", "decode GELU packed"),
    ):
        tensor = mapper.tensors[tensor_name]
        for index, value in enumerate(expected[expected_name]):
            lines.append(
                f"    expect_read(SPAD_BASE + 32'h{tensor.addr + index * 4:08x}, "
                f"32'h{u32(value):08x}, \"Transformer {label}[{index}]\");"
            )
    for tensor_name, expected_name in (
        ("k_cache", "key_cache_words"),
        ("v_cache", "value_cache_words"),
        ("k_prefill", "key_prefill_readback_words"),
        ("v_prefill", "value_prefill_readback_words"),
        ("k_decode", "key_decode_readback_words"),
        ("v_decode", "value_decode_readback_words"),
    ):
        tensor = mapper.tensors[tensor_name]
        for index, value in enumerate(expected[expected_name]):
            lines.append(
                f"    expect_read(SPAD_BASE + 32'h{tensor.addr + index * 4:08x}, "
                f"32'h{u32(value):08x}, \"Transformer {tensor_name}[{index}]\");"
            )
    lines += [
        "  end",
        "endtask",
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def write_manifest(
    path: Path, mapper: Mapper, expected: dict[str, list],
    model: dict | None = None, model_sha256: str | None = None,
) -> None:
    descriptor_base = align(mapper.next_addr, 0x1000)
    manifest = {
        "name": "transformer_micro_4x4_prefill_decode",
        "abi_version": 7,
        "abi_minor": 2,
        "prefill_tokens": 4,
        "decode_tokens": 1,
        "hidden": 4,
        "attention_heads": 1,
        "prefill_descriptor_count": expected["prefill_descriptor_count"],
        "decode_descriptor_count": len(mapper.descriptors) - expected["prefill_descriptor_count"],
        "decode_mapping_policy": expected["decode_mapping_policy"],
        "weight_provenance": (
            model.get("weight_provenance", "trained integer toy next-token model")
            if model is not None else
            "hand-authored deterministic non-identity INT8 test weights; not pretrained"
        ),
        "weights": {
            **expected["weights"],
        },
        "descriptor_base": descriptor_base,
        "descriptor_count": len(mapper.descriptors),
        "last_task_id": mapper.descriptors[-1].task_id,
        "pipeline": [descriptor.name for descriptor in mapper.descriptors],
        "tensors": {
            tensor.name: {
                "address": tensor.addr,
                "shape": tensor.shape,
                "dtype": tensor.dtype,
                "layout": tensor.layout,
                "initialized": tensor.initialized,
            }
            for tensor in mapper.tensors.values()
        },
        "expected_prefill_final": expected["prefill_final"],
        "expected_final": expected["decode_final"],
        "expected_kv": {
            "key_cache_words": expected["key_cache_words"],
            "value_cache_words": expected["value_cache_words"],
            "key_decode_readback_words": expected["key_decode_readback_words"],
            "value_decode_readback_words": expected["value_decode_readback_words"],
        },
        "limitations": ([
            "One attention head, hidden size 4, four-token prefill and one-token decode keep RTL runtime bounded.",
            "The task is a synthetic four-token cyclic next-token benchmark, not a pretrained language model.",
            "Task accuracy is scored from the final INT32 tensor after Top CMDQ execution; no host operation supplies hidden activations.",
            "Softmax Q0.15 probabilities are requantized to INT8 before attention-value GEMM.",
        ] if model is not None else [
            "One attention head, hidden size 4, four-token prefill and one-token decode keep RTL runtime bounded.",
            "The fixed non-identity INT8 weights are deterministic fixtures, not pretrained model weights.",
            "Softmax Q0.15 probabilities are requantized to INT8 before attention-value GEMM.",
            "The workload validates accelerator composition and KV address/data flow, not model accuracy.",
        ]),
    }
    if model is not None:
        manifest.update({
            "model_name": model.get("model_name"),
            "model_sha256": model_sha256,
            "training": model.get("training"),
            "task": model.get("task"),
            "prefill_tokens": model.get("prefill_tokens"),
            "decode_token": model.get("decode_token"),
            "task_metrics_from_independent_golden": expected.get("task_metrics"),
        })
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--svh", type=Path,
        default=(REPO_ROOT / "verif" / "subsystem" / "top_smoke" /
                 "fixtures" / "ai_transformer_workload.svh"),
    )
    parser.add_argument(
        "--manifest", type=Path,
        default=REPO_ROOT / "sw" / "workloads" / "transformer_micro" / "manifest.json",
    )
    parser.add_argument(
        "--model-json", type=Path,
        help="load trained INT8 weights and the model's fixed prefill/decode case",
    )
    parser.add_argument(
        "--decode-mapping-policy", choices=("gemm", "gemv_qkv"),
        default="gemm",
        help=("keep the legacy 0x30 decode mapping or select experimental 0x52 "
              "Q/K/V projections (current H4 Top Golden replay fails; do not use)"),
    )
    args = parser.parse_args()
    model = json.loads(args.model_json.read_text(encoding="utf-8")) if args.model_json else None
    model_sha256 = None
    if args.model_json:
        import hashlib
        model_sha256 = hashlib.sha256(args.model_json.read_bytes()).hexdigest()
    mapper, expected = build_workload(model, args.decode_mapping_policy)
    write_svh(args.svh, mapper, expected)
    write_manifest(args.manifest, mapper, expected, model, model_sha256)
    print(
        f"TRANSFORMER_MAPPER_PASS descriptors={len(mapper.descriptors)} "
        f"tensors={len(mapper.tensors)} dataflow=closed poison=enabled "
        f"decode_mapping={args.decode_mapping_policy} "
        f"prefill={expected['prefill_final']} decode={expected['decode_final']}"
        + (f" task_metrics={expected['task_metrics']} model_sha256={model_sha256}"
           if model is not None else "")
    )


if __name__ == "__main__":
    main()
