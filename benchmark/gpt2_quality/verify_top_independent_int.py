#!/usr/bin/env python3
"""Compare H64 Product Top logit dumps against the separate integer model."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np

from product_integer_reference import infer


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def argmax_lowest(row: list[int]) -> int:
    return max(range(len(row)), key=lambda idx: (row[idx], -idx))


def read_dump(path: Path) -> tuple[list[int], list[int]]:
    values: dict[int, int] = {}
    with path.open(newline="") as stream:
        for fields in csv.reader(stream, delimiter=" "):
            fields = [x for x in fields if x]
            if not fields:
                continue
            if len(fields) != 3:
                raise ValueError(f"malformed logit line: {fields}")
            index, _address, word = int(fields[0]), int(fields[1], 16), int(fields[2], 16)
            if index in values:
                raise ValueError(f"duplicate logit index {index}")
            values[index] = word - (1 << 32) if word & 0x80000000 else word
    if set(values) != set(range(256)):
        raise ValueError(f"expected 256 logits in {path}, got {len(values)}")
    return list(range(256)), [values[i] for i in range(256)]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    top = json.loads((args.run / "autoregressive_result.json").read_text())
    prompt = [int(x) for x in top["prompt_tokens"]]
    generated = [int(x) for x in top["generated_tokens"]]
    with np.load(args.package, allow_pickle=False) as archive:
        model = {name: archive[name] for name in archive.files}
    records = []
    for index, context in enumerate(top["contexts"]):
        tokens = prompt + generated[:index]
        row_index, actual = read_dump(args.run / f"rtl_logits_context{index}.csv")
        expected_all, _trace = infer(model, tokens)
        expected = [int(x) for x in expected_all[-1].tolist()]
        differences = [(i, expected[i], actual[i]) for i in row_index
                       if expected[i] != actual[i]]
        records.append({"context": index, "tokens": tokens,
                        "rtl_row": int(context["row"]),
                        "logits": len(actual), "bit_exact": not differences,
                        "mismatch_count": len(differences),
                        "first_mismatch": differences[0] if differences else None,
                        "independent_argmax": argmax_lowest(expected),
                        "rtl_argmax": argmax_lowest(actual)})
        if differences:
            raise SystemExit(f"context {index}: first INT reference mismatch {differences[0]}")
        if records[-1]["independent_argmax"] != generated[index]:
            raise SystemExit(f"context {index}: independent INT argmax disagrees with feedback token")
    result = {"status": "PRODUCT_TOP_VS_INDEPENDENT_INT_REFERENCE_PASS",
              "source_sha": "f7e65ed02b64dfd1faf49e7a9a25222f5b6bd560",
              "model_npz_sha256": sha(args.package),
              "rtl_run_log_sha256": sha(args.run / "run.log"),
              "contexts": records}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "contexts": len(records),
                      "logits_bit_exact": all(x["bit_exact"] for x in records),
                      "out": str(args.out)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
