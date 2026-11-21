#!/usr/bin/env python3
"""Generate real-top baseline or direct Residual->Requant SFU workload."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "sw/tools"))
sys.path.insert(0, str(ROOT / "dv/block/compute/matrix/ref"))
from cimforge_mapper import (  # noqa: E402
    FLAG_PACK_I8, Mapper, OP_REQUANT, OP_RESIDUAL, add_completion_order_chain,
)
from ai_a3_reference import requant_i8, residual_i32  # noqa: E402

OP_RESIDUAL_REQUANT_I8 = 0x3A
LENGTH = 64


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, value & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words),
                     encoding="ascii")


def generate(out: Path, fused: bool, seed: int = 20261115,
             length: int = LENGTH) -> dict:
    if length < 4 or length > 128 or length % 4:
        raise ValueError("length must be a multiple of four in [4, 128]")
    mapper = Mapper(128 * 1024)
    mapper.next_addr = 0x1000
    mapper.task_id = 0x7100
    lhs = [((index * 37 + seed) % 701) - 350 for index in range(length)]
    rhs = [((index * 53 + seed * 3) % 601) - 300 for index in range(length)]
    lhs_t = mapper.tensor("residual_lhs_i32", (length,), "i32", "row-major", lhs)
    rhs_t = mapper.tensor("residual_rhs_i32", (length,), "i32", "row-major", rhs)
    intermediate_t = mapper.tensor("residual_intermediate_i32", (length,), "i32",
                                   "row-major", [0xA55AA55A] * length, False)
    output_t = mapper.tensor("requant_output_i8_packed", (length,), "i8_packed",
                             "row-major", [0xA55AA55A] * (length // 4), False)

    sums = residual_i32(lhs, rhs, 0)
    output_values = requant_i8(sums, 3)
    golden: dict[int, int] = {}
    if fused:
        mapper.add("residual_requant_i8_direct", OP_RESIDUAL_REQUANT_I8,
                   lhs_t, output_t, src1=rhs_t, k_or_length=length,
                   flags=FLAG_PACK_I8, shift=3)
    else:
        mapper.add("residual_i32", OP_RESIDUAL, lhs_t, intermediate_t,
                   src1=rhs_t, k_or_length=length)
        mapper.add("requant_i8_pack", OP_REQUANT, intermediate_t, output_t,
                   k_or_length=length, flags=FLAG_PACK_I8, shift=3)
        for index, value in enumerate(sums):
            golden[intermediate_t.addr + index * 4] = value & 0xFFFFFFFF

    for word_index in range(length // 4):
        word = sum((output_values[word_index * 4 + lane] & 0xFF) << (lane * 8)
                   for lane in range(4))
        golden[output_t.addr + word_index * 4] = word
    add_completion_order_chain(mapper, event_bit=0)
    descriptor_base, completion_base = 0x4000, 0x5000
    mapper.check_queues(descriptor_base, completion_base)

    image: dict[int, int] = {}
    for tensor in (lhs_t, rhs_t, intermediate_t, output_t):
        for index, value in enumerate(tensor.values):
            image[tensor.addr + index * 4] = value & 0xFFFFFFFF
    for index, descriptor in enumerate(mapper.descriptors):
        for word_index, value in enumerate(descriptor.words()):
            image[descriptor_base + index * 64 + word_index * 4] = value
        for word_index in range(4):
            image[completion_base + index * 16 + word_index * 4] = 0xA55AA55A

    out.mkdir(parents=True, exist_ok=True)
    write_pairs(out / "model_memory.memh", image)
    write_pairs(out / "model_golden.memh", golden)
    manifest = {
        "mode": "direct_residual_requant" if fused else "residual_then_requant",
        "seed": seed, "descriptor_count": len(mapper.descriptors),
        "descriptor_base": descriptor_base, "completion_base": completion_base,
        "golden_words": len(golden), "length": length, "requant_shift": 3,
        "spad_capacity_bytes": 131072,
        "tensor_allocations": [
            {"name": tensor.name, "start": tensor.addr,
             "end_exclusive": tensor.addr + len(tensor.values) * 4,
             "bytes": len(tensor.values) * 4, "initialized": tensor.initialized}
            for tensor in (lhs_t, rhs_t, intermediate_t, output_t)
        ],
        "descriptor_contract": [
            {"name": d.name, "opcode": d.op, "src0": d.src0, "src1": d.src1,
             "dst": d.dst, "length": d.k_or_length, "flags": d.flags,
             "shift": d.shift, "wait_mask": d.wait_mask,
             "signal_mask": d.signal_mask}
            for d in mapper.descriptors
        ],
        "spad_access_bytes_expected": {
            "read": length * 4 * (2 if fused else 3),
            "write": (length // 4) * 4 + (0 if fused else length * 4),
        },
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n",
                                         encoding="utf-8")
    print(f"SFU_RESIDUAL_REQUANT_{'FUSED' if fused else 'BASELINE'}_GENERATOR_PASS "
          f"desc={len(mapper.descriptors)} golden_words={len(golden)}")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--fused", action="store_true")
    parser.add_argument("--seed", type=int, default=20261115)
    parser.add_argument("--length", type=int, default=LENGTH)
    args = parser.parse_args()
    generate(args.out, args.fused, args.seed, args.length)


if __name__ == "__main__":
    main()
