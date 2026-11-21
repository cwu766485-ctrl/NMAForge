#!/usr/bin/env python3
"""Independently compare Round 22 Product-Top logits with INT reference.

The reference is run on every autoregressive prefix.  RTL dumps must contain
the 256 signed INT32 logits read back from Product-Top SPAD.  Argmax ties are
resolved to the lowest token ID, matching the Top testbench.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from round21_contract_ablation import CONTRACTS, infer  # noqa: E402


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def signed32(word: str) -> int:
    value = int(word, 16)
    return value - (1 << 32) if value & (1 << 31) else value


def load_logits(path: Path) -> tuple[list[int], list[int]]:
    indices: list[int] = []
    values: list[int] = []
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) != 3:
            raise ValueError(f"malformed logits row: {line!r}")
        indices.append(int(fields[0]))
        values.append(signed32(fields[2]))
    if indices != list(range(256)):
        raise ValueError(f"expected ordered 256 logits, got {len(indices)} rows")
    return indices, values


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--candidate", type=Path, required=True)
    ap.add_argument("--fp32-checkpoint", type=Path, required=True)
    ap.add_argument("--rtl-dir", type=Path, required=True)
    ap.add_argument("--prompt", default="1,7,42,3")
    ap.add_argument("--steps", type=int, default=4)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    torch.set_num_threads(1)
    checkpoint = torch.load(args.fp32_checkpoint, map_location="cpu", weights_only=False)
    with np.load(args.candidate, allow_pickle=False) as archive:
        q = {name: archive[name].copy() for name in archive.files}
    # The candidate stores FFN up weights in the opcode's Q8.8 representation.
    # Keep an explicit alias so the independent reference uses that exact data.
    for layer in range(4):
        q[f"l{layer}.up_q8_8"] = q[f"l{layer}.up"]

    tokens = [int(x) for x in args.prompt.split(",") if x.strip()]
    if not tokens or len(tokens) > 16 or any(x < 0 or x > 255 for x in tokens):
        raise SystemExit("prompt must contain 1..16 byte token IDs")
    steps: list[dict] = []
    for step in range(args.steps):
        if len(tokens) > 16:
            raise SystemExit("prefix exceeds H64 context capacity 16")
        expected_all, _trace = infer(q, tokens, CONTRACTS["residual_gelu_aligned"])
        expected = np.asarray(expected_all[-1], dtype=np.int64).tolist()
        path = args.rtl_dir / f"rtl_logits_context{step}.csv"
        indices, observed = load_logits(path)
        mismatches = [i for i, (a, b) in enumerate(zip(expected, observed)) if int(a) != b]
        expected_argmax = max(range(256), key=lambda i: int(expected[i]))
        observed_argmax = max(range(256), key=lambda i: observed[i])
        digest = hashlib.sha256(np.asarray(observed, dtype="<i4").tobytes()).hexdigest()
        steps.append({
            "step": step,
            "prefix_tokens": tokens.copy(),
            "rtl_dump": path.name,
            "rtl_dump_sha256": sha256(path),
            "logit_count": len(indices),
            "mismatch_count": len(mismatches),
            "first_mismatch": (None if not mismatches else {
                "token_id": mismatches[0],
                "expected": int(expected[mismatches[0]]),
                "observed": observed[mismatches[0]],
            }),
            "independent_argmax": expected_argmax,
            "rtl_argmax": observed_argmax,
            "rtl_logits_sha256_le_i32": digest,
            "bit_exact": not mismatches,
        })
        if mismatches:
            break
        tokens.append(observed_argmax)

    result = {
        "status": "PASS" if len(steps) == args.steps and all(x["bit_exact"] for x in steps)
                  else "FAIL",
        "reference": "benchmark/gpt2_quality/round21_contract_ablation.py::infer",
        "contract": "residual_gelu_aligned",
        "candidate_sha256": sha256(args.candidate),
        "fp32_checkpoint_sha256": sha256(args.fp32_checkpoint),
        "initial_prompt": [int(x) for x in args.prompt.split(",") if x.strip()],
        "generated_tokens": [x["rtl_argmax"] for x in steps],
        "tie_break": "lowest token ID (strict greater-than update)",
        "steps": steps,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
