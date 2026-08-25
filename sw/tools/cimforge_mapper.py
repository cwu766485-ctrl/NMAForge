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
    str(REPO_ROOT / "verif" / "block" / "compute" / "matrix" / "ref"),
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
OP_SOFTMAX = 0x32
OP_RESIDUAL = 0x34
OP_GELU = 0x35
OP_REQUANT = 0x36
OP_LAYERNORM = 0x38
FLAG_BIAS = 1 << 0
FLAG_TRANSPOSE_B = 1 << 2
FLAG_PACK_I8 = 1 << 4
DESC_VERSION = 7


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
    bias: int = 0
    wait_mask: int = 0
    signal_mask: int = 0
    clear_mask: int = 0

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
        words[9] = self.shift & 0x1F
        words[13] = (1 << 16) | 1  # one head, one batch
        words[14] = (self.signal_mask << 16) | self.wait_mask
        words[15] = (self.clear_mask << 16) | DESC_VERSION
        return [u32(word) for word in words]


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
        descriptor = Descriptor(
            name=name, task_id=self.task_id, op=op, src0=src0.addr,
            src1=src1, dst=dst.addr, bias=bias, **kwargs,
        )
        self.descriptors.append(descriptor)
        self.task_id += 1


def build_workload() -> tuple[Mapper, list[list[int]]]:
    mapper = Mapper()
    x = [
        [1, 2, 0, -1],
        [0, 1, 2, 1],
        [2, 0, 1, 1],
        [1, -1, 0, 2],
    ]
    identity = [[1 if row == col else 0 for col in range(4)] for row in range(4)]
    w_up = [[64 if row == col else 0 for col in range(4)] for row in range(4)]
    gamma = [32768] * 4
    beta = [0] * 4

    x8 = mapper.tensor("x_i8", (4, 4), "i8_packed", "row-major", pack_rows(x))
    x32 = mapper.tensor("x_i32", (4, 4), "i32", "row-major", flatten(x))
    wq = mapper.tensor("wq", (4, 4), "i8_packed", "column-major", pack_columns(identity))
    wk = mapper.tensor("wk", (4, 4), "i8_packed", "column-major", pack_columns(identity))
    wv = mapper.tensor("wv", (4, 4), "i8_packed", "column-major", pack_columns(identity))
    wo = mapper.tensor("wo", (4, 4), "i8_packed", "column-major", pack_columns(identity))
    wup = mapper.tensor("wup", (4, 4), "i8_packed", "column-major", pack_columns(w_up))
    wdown = mapper.tensor("wdown", (4, 4), "i8_packed", "column-major", pack_columns(identity))
    gamma_t = mapper.tensor("gamma", (4,), "i32", "vector", gamma)
    beta_t = mapper.tensor("beta", (4,), "i32", "vector", beta)

    def empty_i32(name: str) -> Tensor:
        # Poison every destination before execution.  This prevents a stale or
        # preloaded golden tensor from making the RTL check pass accidentally.
        return mapper.tensor(
            name, (4, 4), "i32", "row-major", [0x5A5AA5A5] * 16,
            initialized=False,
        )

    def empty_i8(name: str) -> Tensor:
        return mapper.tensor(
            name, (4, 4), "i8_packed", "row-major", [0xA55AA55A] * 4,
            initialized=False,
        )

    q32, q8 = empty_i32("q_i32"), empty_i8("q_i8")
    k32, k8 = empty_i32("k_i32"), empty_i8("k_i8")
    v32, v8 = empty_i32("v_i32"), empty_i8("v_i8")
    scores = empty_i32("scores")
    probs32, probs8 = empty_i32("prob_q15"), empty_i8("prob_i8")
    attention32, attention8 = empty_i32("attention_i32"), empty_i8("attention_i8")
    projected = empty_i32("projected")
    residual1, norm1, norm1_i8 = empty_i32("residual1"), empty_i32("norm1"), empty_i8("norm1_i8")
    ffn_up, gelu, gelu_i8 = empty_i32("ffn_up"), empty_i32("gelu"), empty_i8("gelu_i8")
    ffn_down, residual2, norm2 = empty_i32("ffn_down"), empty_i32("residual2"), empty_i32("norm2")

    def gemm(name: str, lhs: Tensor, rhs: Tensor, dst: Tensor, flags: int = 0) -> None:
        mapper.add(name, OP_GEMM, lhs, dst, src1=rhs, m=4, n=4,
                   k_or_length=1, flags=flags, aux0=1)

    def pack(name: str, src: Tensor, dst: Tensor, shift: int) -> None:
        mapper.add(name, OP_REQUANT, src, dst, k_or_length=16,
                   flags=FLAG_PACK_I8, shift=shift, aux0=1)

    gemm("q_projection", x8, wq, q32)
    pack("q_pack", q32, q8, 0)
    gemm("k_projection", x8, wk, k32)
    pack("k_pack", k32, k8, 0)
    gemm("v_projection", x8, wv, v32)
    pack("v_pack", v32, v8, 0)
    gemm("qk_transpose", q8, k8, scores)
    for row in range(4):
        mapper.add(
            f"softmax_row{row}", OP_SOFTMAX, scores, probs32,
            k_or_length=4, aux0=1,
        )
        mapper.descriptors[-1].src0 += row * 16
        mapper.descriptors[-1].dst += row * 16
    pack("prob_pack", probs32, probs8, 8)
    gemm("attention_value", probs8, v8, attention32, FLAG_TRANSPOSE_B)
    pack("attention_pack", attention32, attention8, 7)
    gemm("output_projection", attention8, wo, projected)
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
    gemm("ffn_down", gelu_i8, wdown, ffn_down)
    mapper.add("residual2", OP_RESIDUAL, ffn_down, residual2, src1=norm1,
               k_or_length=16, aux0=1)
    for row in range(4):
        mapper.add(f"layernorm2_row{row}", OP_LAYERNORM, residual2, norm2,
                   src1=gamma_t, bias=beta_t, k_or_length=4,
                   flags=FLAG_BIAS, aux0=1)
        mapper.descriptors[-1].src0 += row * 16
        mapper.descriptors[-1].dst += row * 16

    q = gemm_i8_i32(x, identity)
    key = gemm_i8_i32(x, identity)
    value = gemm_i8_i32(x, identity)
    q_i8 = [requant_i8(row, 0) for row in q]
    k_i8 = [requant_i8(row, 0) for row in key]
    v_i8 = [requant_i8(row, 0) for row in value]
    score_golden = gemm_i8_i32(q_i8, transpose(k_i8))
    probability_q15 = [softmax_q15(row) for row in score_golden]
    probability_i8 = [requant_i8(row, 8) for row in probability_q15]
    attended = gemm_i8_i32(probability_i8, v_i8)
    attended_i8 = [requant_i8(row, 7) for row in attended]
    projection = gemm_i8_i32(attended_i8, identity)
    residual_1 = [residual_i32(a, b) for a, b in zip(projection, x)]
    norm_1 = [layernorm_q15(row, gamma, beta) for row in residual_1]
    norm_1_i8 = [requant_i8(row, 0) for row in norm_1]
    expanded = gemm_i8_i32(norm_1_i8, w_up)
    activated = [[gelu_q8_8(value) for value in row] for row in expanded]
    activated_i8 = [requant_i8(row, 0) for row in activated]
    down = gemm_i8_i32(activated_i8, identity)
    residual_2 = [residual_i32(a, b) for a, b in zip(down, norm_1)]
    norm_2 = [layernorm_q15(row, gamma, beta) for row in residual_2]

    # Cross-check the standalone FFN composition helper on the same tensors.
    assert ffn_i8(norm_1_i8, w_up, identity, 0) == down
    validate_descriptor_chain(mapper)
    return mapper, norm_2


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
        if descriptor.op == OP_GEMM:
            require(
                descriptor.src0, descriptor.m * descriptor.k_or_length * 4,
                descriptor.name, "src0",
            )
            require(
                descriptor.src1, descriptor.n * descriptor.k_or_length * 4,
                descriptor.name, "src1",
            )
            output_bytes = descriptor.m * descriptor.n * 4
        else:
            require(
                descriptor.src0, descriptor.k_or_length * 4,
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
            descriptor.dst, output_bytes, descriptor.name
        )
        available.append(
            (
                descriptor.dst, descriptor.dst + output_bytes,
                f"{descriptor.name}->{tensor_name}",
            )
        )


def tensor_storage_words(tensor: Tensor) -> list[int]:
    if tensor.dtype == "i8_packed":
        return [u32(value) for value in tensor.values]
    return [u32(value) for value in tensor.values]


def write_svh(path: Path, mapper: Mapper, expected: list[list[int]]) -> None:
    descriptor_base = align(mapper.next_addr, 0x1000)
    completion_base = align(descriptor_base + len(mapper.descriptors) * 64, 0x1000)
    lines = [
        "// Generated by sw/tools/cimforge_mapper.py; do not hand edit.",
        f"localparam [31:0] TRANSFORMER_DESC_BASE = 32'h{descriptor_base:08x};",
        f"localparam [31:0] TRANSFORMER_CPL_BASE = 32'h{completion_base:08x};",
        f"localparam integer TRANSFORMER_DESC_COUNT = {len(mapper.descriptors)};",
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
    norm2 = mapper.tensors["norm2"]
    for index, value in enumerate(flatten(expected)):
        lines.append(
            f"    expect_read(SPAD_BASE + 32'h{norm2.addr + index * 4:08x}, "
            f"32'h{u32(value):08x}, \"Transformer final[{index}]\");"
        )
    lines += [
        "  end",
        "endtask",
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def write_manifest(path: Path, mapper: Mapper, expected: list[list[int]]) -> None:
    descriptor_base = align(mapper.next_addr, 0x1000)
    manifest = {
        "name": "transformer_micro_4x4",
        "abi_version": 7,
        "abi_minor": 2,
        "tokens": 4,
        "hidden": 4,
        "descriptor_base": descriptor_base,
        "descriptor_count": len(mapper.descriptors),
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
        "expected_final": expected,
        "limitations": [
            "One attention head and one 4x4 tile are used to keep RTL runtime bounded.",
            "Softmax Q0.15 probabilities are requantized to INT8 before AV GEMM.",
            "The workload validates accelerator composition, not model accuracy.",
        ],
    }
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
    args = parser.parse_args()
    mapper, expected = build_workload()
    write_svh(args.svh, mapper, expected)
    write_manifest(args.manifest, mapper, expected)
    print(
        f"TRANSFORMER_MAPPER_PASS descriptors={len(mapper.descriptors)} "
        f"tensors={len(mapper.tensors)} dataflow=closed poison=enabled "
        f"final={expected}"
    )


if __name__ == "__main__":
    main()
