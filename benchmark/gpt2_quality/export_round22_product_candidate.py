#!/usr/bin/env python3
"""Export the bounded Round 21 scale-aligned experiment for Product Top.

This does not overwrite the frozen canonical package.  It materializes the
software candidate's LN beta and FFN-up Q8.8 operands while the descriptor
profile applies the declared attention/down/GELU shifts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--fp32", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    checkpoint = torch.load(args.fp32, map_location="cpu", weights_only=False)
    state = checkpoint["state_dict"]
    with np.load(args.package, allow_pickle=False) as archive:
        model = {name: archive[name].copy() for name in archive.files}
    original_keys = sorted(model)
    beta_keys = []
    for name in ("final_beta",) + tuple(
            f"l{layer}.{norm}_beta" for layer in range(4)
            for norm in ("ln1", "ln2")):
        before = model[name]
        model[name] = np.rint(before.astype(np.float64) / 8.0).astype(before.dtype)
        beta_keys.append(name)
    up_saturation = {}
    for layer in range(4):
        weight = state[f"layers.{layer}.up.weight"].detach().cpu().numpy().T
        q8_8 = np.clip(np.rint(weight.astype(np.float64) * 256.0), -128, 127).astype(np.int8)
        model[f"l{layer}.up"] = q8_8
        up_saturation[f"l{layer}.up"] = int(np.count_nonzero((weight * 256.0 < -128) |
                                                              (weight * 256.0 > 127)))
    if sorted(model) != original_keys:
        raise SystemExit("candidate export changed model package key set")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(args.out, **model)
    manifest = {
        "status": "PRODUCT_TOP_CANDIDATE_PACKAGE",
        "profile": "round21_residual_gelu_aligned",
        "source_package": str(args.package),
        "source_package_sha256": sha(args.package),
        "fp32_checkpoint": str(args.fp32),
        "fp32_checkpoint_sha256": sha(args.fp32),
        "candidate_package": str(args.out),
        "candidate_package_sha256": sha(args.out),
        "beta_transform": "round-to-even(beta / 8) for all LN beta vectors",
        "up_weight_transform": "round-to-even(fp32 up weight * 256), signed INT8 saturation",
        "up_weight_saturated_values": up_saturation,
        "descriptor_shifts": {"qkv": 0, "attention_output": 7,
                               "gelu_to_int8": 5, "ffn_down": 5,
                               "lm_head": 0},
        "compatibility": "candidate experiment only; does not modify product ABI defaults",
    }
    manifest_path = args.out.with_suffix(".json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("ROUND22_PRODUCT_CANDIDATE_EXPORTED " + json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
