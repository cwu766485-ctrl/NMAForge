#!/usr/bin/env python3
"""Compare independent H64 cache-backed and full-recompute integer Goldens."""

from __future__ import annotations

import argparse
import tempfile
from pathlib import Path

from generate_h64_preln_qkv import generate


COMPARE_TENSORS = [
    *(f"attn_h{head}_scores_q8_8" for head in range(4)),
    *(f"attn_h{head}_prob_q15" for head in range(4)),
    *(f"attn_h{head}_av_i32" for head in range(4)),
    "residual1_i32",
    "ln2_output_i32",
    "l0.ffn_down_acc_i32",
    "l0.residual2_i32",
]


def load_checkpoint_records(out: Path, manifest: dict) -> dict[str, list[int]]:
    words = [int(line, 16) for line in
             (out / "checkpoint_golden.memh").read_text(encoding="ascii").splitlines()]
    count = words[0]
    metadata = manifest["intermediate_checkpoints"]
    if count != len(metadata):
        raise ValueError(f"checkpoint count mismatch {count} != {len(metadata)}")
    records: dict[str, list[int]] = {}
    cursor = 1
    for item in metadata:
        descriptor_index, pair_count = words[cursor:cursor + 2]
        cursor += 2
        if descriptor_index != item["descriptor_index"] or pair_count != item["golden_words"]:
            raise ValueError(f"checkpoint metadata mismatch for {item['tensor_id']}")
        pairs = {words[cursor + index * 2]: words[cursor + index * 2 + 1]
                 for index in range(pair_count)}
        cursor += pair_count * 2
        records[item["tensor_id"]] = [pairs[address] for address in sorted(pairs)]
    if cursor != len(words):
        raise ValueError("trailing checkpoint data")
    return records


def selected_indices(name: str, token_count: int) -> list[int]:
    if "_scores_q8_8" in name or "_prob_q15" in name or "_av_i32" in name:
        width = 16
        if "_scores_q8_8" in name:
            return [row * width + col for row in range(token_count)
                    for col in range(row + 1)]
        return [row * width + col for row in range(token_count) for col in range(width)]
    if name in {"residual1_i32", "ln2_output_i32", "l0.ffn_down_acc_i32",
                "l0.residual2_i32"}:
        width = 64
        return list(range(token_count * width))
    return []


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261115)
    parser.add_argument("--tokens", default="1,7,42,3,5,8")
    parser.add_argument("--kv-k-write-mode",
                        choices=("token-append", "qk-compatible-append",
                                 "matrix-a-tile", "matrix-a-word"),
                        default="token-append")
    args = parser.parse_args()
    tokens = [int(value) for value in args.tokens.split(",")]
    with tempfile.TemporaryDirectory(prefix="nmaforge_h64_kv_golden_") as temp:
        root = Path(temp)
        full_dir, cache_dir = root / "full", root / "cache"
        full = generate(full_dir, args.seed, True, True, False, False, tokens)
        cache = generate(cache_dir, args.seed, True, True, False, True, tokens,
                         args.kv_k_write_mode)
        full_checkpoints = load_checkpoint_records(full_dir, full)
        cache_checkpoints = load_checkpoint_records(cache_dir, cache)
        for name in COMPARE_TENSORS:
            left = full_checkpoints[name]
            right = cache_checkpoints[name]
            indices = selected_indices(name, len(tokens))
            if not indices:
                indices = list(range(len(left)))
            mismatch = next((index for index in indices
                             if left[index] != right[index]), None)
            if mismatch is not None:
                index = mismatch
                raise SystemExit(
                    f"H64_CACHE_RECOMPUTE_MISMATCH tensor={name} word={index} "
                    f"full={left[index]:08x} cache={right[index]:08x}"
                )
            print(f"H64_CACHE_RECOMPUTE_TENSOR_PASS tensor={name} "
                  f"checked_words={len(indices)} total_words={len(left)}")
        print(
            "H64_CACHE_RECOMPUTE_GOLDEN_PASS "
            f"tokens={','.join(str(value) for value in tokens)} "
            f"seed={args.seed} tensors={len(COMPARE_TENSORS)} "
            f"full_desc={full['descriptor_count']} cache_desc={cache['descriptor_count']}"
        )


if __name__ == "__main__":
    main()
