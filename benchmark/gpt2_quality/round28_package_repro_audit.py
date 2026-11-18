#!/usr/bin/env python3
"""Re-export a frozen H64 QAT checkpoint and compare every Product INT8 tensor."""
from __future__ import annotations
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "benchmark" / "gpt2_quality"))
from train_h64_byte_lm import H64ByteDecoder  # noqa: E402
from train_round24_integer_qat import export_package  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", type=Path, required=True)
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--reexport", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    args = ap.parse_args()

    torch.set_num_threads(1)
    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=False)
    model = H64ByteDecoder().cpu().eval()
    model.load_state_dict(checkpoint["state_dict"], strict=True)
    export_package(model, args.reexport)

    saved = np.load(args.package, allow_pickle=False)
    rebuilt = np.load(args.reexport, allow_pickle=False)
    if set(saved.files) != set(rebuilt.files):
        raise SystemExit("package key sets differ")
    tensors = []
    for name in sorted(saved.files):
        a, b = saved[name], rebuilt[name]
        same = a.shape == b.shape and a.dtype == b.dtype and np.array_equal(a, b)
        tensors.append({
            "name": name, "shape": list(a.shape), "dtype": str(a.dtype),
            "equal": bool(same),
            "mismatch_count": int(np.count_nonzero(a != b)) if a.shape == b.shape else None,
        })
    result = {
        "status": "PASS" if all(t["equal"] for t in tensors) else "FAIL",
        "checkpoint": str(args.checkpoint), "checkpoint_sha256": sha(args.checkpoint),
        "package": str(args.package), "package_sha256": sha(args.package),
        "reexport": str(args.reexport), "reexport_sha256": sha(args.reexport),
        "archive_bytes_equal": args.package.read_bytes() == args.reexport.read_bytes(),
        "tensor_count": len(tensors), "all_tensors_equal": all(t["equal"] for t in tensors),
        "tensors": tensors,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "tensors"}, indent=2))
    return 0 if result["all_tensors_equal"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
