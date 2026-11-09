#!/usr/bin/env python3
"""Pack non-sentinel CNN SPAD words into aligned DMA segments.

This prepares a behavioral-Top DMA preload experiment. Poison words are omitted
from the production payload; they remain an AXI-Lite testbench sentinel setup.
Each plan entry is (external byte address, SPAD byte address, 32-bit word count).
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

POISON = 0xA55AA55A
SPAD_BYTES = 128 * 1024
AXI_MEMORY_WORDS = 4096


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--memory-image", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    raw = args.memory_image.read_text(encoding="ascii").splitlines()
    if not raw:
        raise ValueError("empty SPAD image")
    pair_count = int(raw[0], 16)
    if len(raw) != 1 + pair_count * 2:
        raise ValueError(f"SPAD image pair count mismatch: {pair_count}")

    words: dict[int, int] = {}
    sentinel_words = 0
    for index in range(pair_count):
        address = int(raw[1 + index * 2], 16)
        value = int(raw[2 + index * 2], 16)
        if address & 3:
            raise ValueError(f"unaligned SPAD word address 0x{address:x}")
        if address >= SPAD_BYTES:
            raise ValueError(f"SPAD address outside 128 KiB: 0x{address:x}")
        if address in words:
            raise ValueError(f"duplicate SPAD address 0x{address:x}")
        words[address] = value
        sentinel_words += value == POISON

    active_lines = sorted({address & ~0xF for address, value in words.items()
                           if value != POISON})
    if not active_lines:
        raise ValueError("no live words to transfer")

    line_words: dict[int, list[int]] = {}
    for line in active_lines:
        addresses = [line + lane * 4 for lane in range(4)]
        if any(address not in words for address in addresses):
            raise ValueError(f"partially described live DMA line at 0x{line:08x}")
        line_words[line] = [words[address] for address in addresses]

    groups: list[list[int]] = []
    for address in active_lines:
        if not groups or address != groups[-1][-1] + 16:
            groups.append([address])
        else:
            groups[-1].append(address)

    payload_words: list[int] = []
    plan: list[dict[str, int]] = []
    plan_words: list[int] = [len(groups)]
    for group in groups:
        ext_byte = len(payload_words) * 4
        spad_byte = group[0]
        count_words = len(group) * 4
        if ext_byte & 0xF or spad_byte & 0xF or count_words & 3:
            raise ValueError("DMA plan lost 128-bit line alignment")
        plan.append({"external_address": ext_byte,
                     "spad_address": spad_byte,
                     "length_words": count_words,
                     "length_bytes": count_words * 4})
        plan_words.extend((ext_byte, spad_byte, count_words))
        for line in group:
            payload_words.extend(line_words[line])

    payload_bytes = len(payload_words) * 4
    if len(payload_words) > AXI_MEMORY_WORDS:
        raise ValueError("packed payload exceeds axi_memory_model WORDS")
    live_words = sum(value != POISON for value in words.values())
    if payload_bytes < live_words * 4:
        raise AssertionError("line transfer cannot be smaller than live word data")

    payload_path = args.out_dir / "dma_payload.memh"
    plan_path = args.out_dir / "dma_plan.memh"
    summary_path = args.out_dir / "dma_payload_summary.json"
    payload_path.write_text("".join(f"{word:08x}\n" for word in payload_words),
                            encoding="ascii")
    plan_path.write_text("".join(f"{word:08x}\n" for word in plan_words),
                         encoding="ascii")
    summary = {
        "status": "PASS_DMA_PAYLOAD_PLAN",
        "memory_image_sha256": sha256(args.memory_image),
        "payload_sha256": sha256(payload_path),
        "plan_sha256": sha256(plan_path),
        "image_pairs": pair_count,
        "live_words": live_words,
        "live_data_bytes": live_words * 4,
        "payload_bytes": payload_bytes,
        "payload_padding_bytes": payload_bytes - live_words * 4,
        "poison_words_test_only": sentinel_words,
        "poison_setup_bytes_test_only": sentinel_words * 4,
        "spad_capacity_bytes": SPAD_BYTES,
        "external_model_capacity_bytes": AXI_MEMORY_WORDS * 4,
        "dma_transactions": plan,
        "dma_plan_encoding": "word_count followed by (external byte address, SPAD byte address, 32-bit word count) triples",
    }
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(f"CNN_DMA_PAYLOAD_PLAN_PASS live_bytes={live_words * 4} "
          f"payload_bytes={payload_bytes} test_only_poison_bytes={sentinel_words * 4} "
          f"segments={len(groups)} payload_sha256={summary['payload_sha256']}")


if __name__ == "__main__":
    main()
