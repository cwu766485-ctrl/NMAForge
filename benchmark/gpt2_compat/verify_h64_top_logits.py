#!/usr/bin/env python3
"""Check Product-Top SPAD logits against the independent generated Golden."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import struct
from pathlib import Path


def s32(word: int) -> int:
    word &= 0xFFFFFFFF
    return word - (1 << 32) if word & (1 << 31) else word


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(line.strip(), 16) for line in path.read_text().splitlines() if line.strip()]
    if not words:
        raise ValueError(f"empty pair file: {path}")
    count = words[0]
    if len(words) != 1 + 2 * count:
        raise ValueError(f"bad pair count in {path}: count={count} words={len(words)}")
    return {words[1 + 2 * i]: words[2 + 2 * i] for i in range(count)}


def argmax_lowest(values: list[int]) -> int:
    best_index = 0
    for index in range(1, len(values)):
        if values[index] > values[best_index]:
            best_index = index
    return best_index


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--row", type=int, required=True)
    args = parser.parse_args()
    stage = args.run / "stage3"
    manifest = json.loads((stage / "manifest.json").read_text())
    sequence_manifest = json.loads((args.run / "four_layer_manifest.json").read_text())
    allocation = next(item for item in sequence_manifest["allocation_records"]
                      if item["tensor_id"] == "logits_i32_physical_16x256")
    if not 0 <= args.row < len(manifest["tokens"]):
        raise ValueError(f"row {args.row} is not a valid prompt token row")
    golden = read_pairs(stage / "model_golden.memh")
    observed_rows: dict[int, tuple[int, int]] = {}
    with (args.run / "rtl_logits.csv").open(newline="") as stream:
        for record in csv.reader(stream, delimiter=" "):
            fields = [field for field in record if field]
            if not fields:
                continue
            if len(fields) != 3:
                raise ValueError(f"malformed RTL logit row: {record}")
            index = int(fields[0])
            address = int(fields[1], 16)
            value = int(fields[2], 16)
            if index in observed_rows:
                raise ValueError(f"duplicate observed logit {index}")
            observed_rows[index] = (address, value)
    if set(observed_rows) != set(range(256)):
        raise ValueError(f"expected 256 actual logits, got {len(observed_rows)}")

    actual: list[int] = []
    addresses: list[int] = []
    mismatches = []
    for index in range(256):
        tile, col = divmod(index, 16)
        address = allocation["start"] + (tile * 256 + args.row * 16 + col) * 4
        got_address, got_word = observed_rows[index]
        expected_word = golden.get(address)
        if got_address != address or expected_word is None or got_word != expected_word:
            mismatches.append({"index": index, "expected_address": address,
                               "observed_address": got_address,
                               "expected_word": expected_word,
                               "observed_word": got_word})
        actual.append(s32(got_word))
        addresses.append(address)
    if mismatches:
        raise SystemExit(f"FAIL: {len(mismatches)} actual RTL logit mismatches; first={mismatches[0]}")

    token = argmax_lowest(actual)
    golden_logits = [s32(golden[address]) for address in addresses]
    golden_token = argmax_lowest(golden_logits)
    if token != golden_token:
        raise SystemExit(f"FAIL: RTL argmax {token} != independent Golden argmax {golden_token}")
    packed = b"".join(struct.pack("<i", value) for value in actual)
    report = {
        "status": "TOP_LOGITS_AND_ARGMAX_PASS",
        "evidence_scope": "actual Product Top SPAD AXI-Lite readback after four-layer forward",
        "row": args.row,
        "prompt_tokens": manifest["tokens"],
        "logit_count": len(actual),
        "tie_break": "lowest token ID among equal signed INT32 logits",
        "argmax_token_id": token,
        "argmax_signed_int32": actual[token],
        "all_256_bit_exact": True,
        "actual_logits_sha256_le_i32": hashlib.sha256(packed).hexdigest(),
        "independent_golden_sha256": manifest["golden_sha256"],
        "source_memory_sha256": manifest["memory_sha256"],
        "logits_spad_base": allocation["start"],
        # The allocation manifest records placement/lifetime but not a layout
        # field.  The output format is defined by the H64 LM-head writer and
        # its independent Golden address formula above.
        "physical_layout": "matrix_n_tile_major_16x16_rows",
        "run_log": str(args.run / "run.log"),
        "rtl_dump": str(args.run / "rtl_logits.csv"),
    }
    output = args.run / "host_argmax.json"
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"H64_TOP_LOGITS_GOLDEN_PASS count=256 row={args.row} argmax={token} "
          f"logits_sha256={report['actual_logits_sha256_le_i32']} report={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
