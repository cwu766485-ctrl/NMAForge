#!/usr/bin/env python3
"""Verify actual Product-Top logits for every autoregressive feedback step."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path


def s32(word: int) -> int:
    word &= 0xFFFFFFFF
    return word - (1 << 32) if word & 0x80000000 else word


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(line, 16) for line in path.read_text().splitlines() if line.strip()]
    if not words or len(words) != 1 + 2 * words[0]:
        raise ValueError(f"invalid Golden pair file: {path}")
    return dict(zip(words[1::2], words[2::2]))


def argmax_lowest(values: list[int]) -> int:
    best = 0
    for index in range(1, len(values)):
        if values[index] > values[best]:
            best = index
    return best


def verify_context(root: Path, context_index: int, row: int,
                   expected_token: int) -> dict:
    context = root if context_index == 0 else root / f"context{context_index}"
    manifest = json.loads((context / "four_layer_manifest.json").read_text())
    allocation = next(x for x in manifest["allocation_records"]
                      if x["tensor_id"] == "logits_i32_physical_16x256")
    golden = read_pairs(context / "stage3/model_golden.memh")
    dump = root / f"rtl_logits_context{context_index}.csv"
    observed: dict[int, tuple[int, int]] = {}
    with dump.open(newline="") as stream:
        for record in csv.reader(stream, delimiter=" "):
            fields = [field for field in record if field]
            if not fields:
                continue
            if len(fields) != 3:
                raise ValueError(f"malformed logit record {record}")
            index, address, word = int(fields[0]), int(fields[1], 16), int(fields[2], 16)
            if index in observed:
                raise ValueError(f"duplicate RTL logit index {index}")
            observed[index] = (address, word)
    if set(observed) != set(range(256)):
        raise ValueError(f"context {context_index} has {len(observed)} logits, expected 256")
    values = []
    mismatches = []
    for index in range(256):
        tile, column = divmod(index, 16)
        address = allocation["start"] + (tile * 256 + row * 16 + column) * 4
        got_address, got = observed[index]
        want = golden.get(address)
        if got_address != address or want is None or got != want:
            mismatches.append((index, address, got_address, want, got))
        values.append(s32(got))
    if mismatches:
        raise SystemExit(f"context {context_index}: {len(mismatches)} logit mismatch; first={mismatches[0]}")
    token = argmax_lowest(values)
    if token != expected_token:
        raise SystemExit(f"context {context_index}: RTL argmax={token}, plan={expected_token}")
    packed = b"".join(int(value).to_bytes(4, "little", signed=True) for value in values)
    return {"context": context_index, "row": row, "logit_count": 256,
            "golden_bit_exact": True, "argmax_token": token,
            "logits_sha256_le_i32": hashlib.sha256(packed).hexdigest(),
            "rtl_dump": str(dump)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", type=Path, required=True)
    args = parser.parse_args()
    plan = json.loads((args.run / "autoregressive_plan.json").read_text())
    results = []
    for step, record in enumerate(plan["generated_steps"]):
        results.append(verify_context(args.run, step, record["logits_row"],
                                      record["expected_argmax_token"]))
    log = (args.run / "run.log").read_text(errors="replace")
    if "H64_AUTOREGRESSIVE_SEQUENCE_PASS" not in log:
        raise SystemExit("missing Product-Top autoregressive completion marker")
    for step, result in enumerate(results):
        marker = f"H64_AR_LOGITS_ARGMAX_PASS step={step} token={result['argmax_token']} "
        if marker not in log:
            raise SystemExit(f"run log missing actual-RTL feedback evidence: {marker}")
    output = {"status": "FOUR_LAYER_TOP_AUTOREGRESSIVE_GOLDEN_PASS",
              "mode": plan["mode"], "seed": plan["seed"],
              "synthetic_model_quality_claim": False,
              "prompt_tokens": plan["prompt_tokens"],
              "generated_tokens": plan["expected_generated_tokens"],
              "contexts": results,
              "source_sha": "recorded by the enclosing run manifest"}
    (args.run / "autoregressive_result.json").write_text(json.dumps(output, indent=2) + "\n")
    print("H64_AUTOREGRESSIVE_GOLDEN_PASS " + json.dumps({
        "generated_tokens": output["generated_tokens"],
        "contexts": len(results),
        "all_logits_bit_exact": True,
        "result": str(args.run / "autoregressive_result.json")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
