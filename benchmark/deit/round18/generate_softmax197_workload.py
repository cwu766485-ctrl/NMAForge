#!/usr/bin/env python3
"""Build one Product Top 0x32 Softmax vector of the full DeiT key length."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
sys.path.insert(0, str(ROOT / "dv" / "block" / "compute" / "matrix" / "ref"))
from cimforge_mapper import Mapper, OP_SOFTMAX  # noqa: E402
from ai_a3_reference import softmax_q15  # noqa: E402


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, int(value) & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words), encoding="ascii")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--queue-size", type=int, default=512)
    parser.add_argument("--seed", type=int, default=20261118)
    args = parser.parse_args()
    if args.queue_size != 512:
        raise SystemExit("this Round 18 Top probe reserves the reviewed 512-entry queue")
    rng = np.random.default_rng(args.seed)
    scores = rng.integers(-768, 769, size=197, dtype=np.int32).tolist()
    mapper = Mapper(capacity_bytes=256 * 1024)
    mapper.next_addr = 0x1000
    mapper.task_id = 0x7100  # tb_ai_accel_smoke expects representative task IDs from 0x7100
    src = mapper.tensor("deit_softmax197_scores_q8_8", (197,), "i32", "row_major", scores)
    dst = mapper.tensor("deit_softmax197_probabilities_q0_15", (197,), "i32", "row_major",
                        [0xA55AA55A] * 197, initialized=False)
    mapper.add("deit_softmax197_full_key_row", OP_SOFTMAX, src, dst, k_or_length=197)

    pairs: dict[int, int] = {}
    for tensor in mapper.tensors.values():
        for index, value in enumerate(tensor.values):
            pairs[tensor.addr + 4 * index] = int(value) & 0xFFFFFFFF
    queue_bytes = args.queue_size * 80
    desc_base = 256 * 1024 - queue_bytes
    cpl_base = desc_base + args.queue_size * 64
    for index, descriptor in enumerate(mapper.descriptors):
        for word_index, value in enumerate(descriptor.words()):
            pairs[desc_base + index * 64 + word_index * 4] = value
    for index in range(args.queue_size):
        for word_index in range(4):
            pairs[cpl_base + index * 16 + word_index * 4] = 0xA55AA55A

    golden = softmax_q15(scores)
    golden_pairs = {dst.addr + 4 * index: value for index, value in enumerate(golden)}
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out_dir / "model_memory.memh", pairs)
    write_pairs(args.out_dir / "model_golden.memh", golden_pairs)
    manifest = {
        "status": "FULL_KEY_LENGTH_SOFTMAX_TOP_WORKLOAD_NOT_SIMULATED",
        "opcode": "0x32",
        "length": 197,
        "datatype": {"input": "signed Q8.8 encoded in int32", "output": "Q0.15 encoded in int32"},
        "seed": args.seed,
        "source_address": src.addr,
        "destination_address": dst.addr,
        "descriptor_count": 1,
        "descriptor_base": desc_base,
        "completion_base": cpl_base,
        "queue_entries": args.queue_size,
        "queue_bytes": queue_bytes,
        "golden_words": 197,
        "input_scores_sha256": hashlib.sha256(np.asarray(scores, dtype=np.int32).tobytes()).hexdigest(),
        "golden_sha256": hashlib.sha256(np.asarray(golden, dtype=np.int32).tobytes()).hexdigest(),
        "memory_image_sha256": sha(args.out_dir / "model_memory.memh"),
        "golden_image_sha256": sha(args.out_dir / "model_golden.memh"),
        "scope_limit": "isolated 0x32 full 197-element row only; does not prove three-head tiled attention or full DeiT encoder",
    }
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("DEIT_SOFTMAX197_WORKLOAD_PASS " + json.dumps({
        "seed": args.seed, "length": 197, "golden_words": len(golden),
        "queue_bytes": queue_bytes, "memory_sha256": manifest["memory_image_sha256"],
        "golden_sha256": manifest["golden_image_sha256"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
