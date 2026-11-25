#!/usr/bin/env python3
"""Generate matched-length Transformer operator vectors for NMAForge and TinyNPU.

NMAForge vectors carry an independent bit-exact Golden from the SFU reference
model.  TinyNPU vectors carry INT8 inputs only; its outputs are checked by
``check_tiny.py`` against independent float references with the tolerances
documented in the README.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "dv" / "block" / "compute" / "matrix" / "ref"))
import ai_a3_reference as ref  # noqa: E402

LENGTHS = (64, 192, 197, 768)
NMA_OPS = {
    "gelu": 0x35,
    "softmax": 0x32,
    "layernorm": 0x38,
    "residual": 0x34,
    "requant": 0x36,
}
# TinyNPU engine selectors used by tb_tiny_ops_perf.sv.
TINY_OPS = {"gelu": 0, "softmax": 1, "layernorm": 2, "residual": 3}


def nma_case(rng: random.Random, name: str, length: int):
    shift, epsilon, beta_enable = 0, 1, 0
    y = [0] * length
    beta = [0] * length
    if name == "gelu":
        x = [rng.randint(-2048, 2048) for _ in range(length)]
        expected = [ref.gelu_q8_8(v) for v in x]
    elif name == "softmax":
        x = [rng.randint(-4096, 4096) for _ in range(length)]
        expected = ref.softmax_q15(x)
    elif name == "layernorm":
        beta_enable = 1
        x = [rng.randint(-8192, 8192) for _ in range(length)]
        y = [rng.randint(-32768, 32767) for _ in range(length)]
        beta = [rng.randint(-32, 32) for _ in range(length)]
        expected = ref.layernorm_q15(x, y, beta, epsilon=epsilon)
    elif name == "residual":
        x = [rng.randint(-(1 << 30), (1 << 30) - 1) for _ in range(length)]
        y = [rng.randint(-(1 << 30), (1 << 30) - 1) for _ in range(length)]
        expected = ref.residual_i32(x, y, shift)
    elif name == "requant":
        shift = 8
        x = [rng.randint(-(1 << 20), (1 << 20) - 1) for _ in range(length)]
        expected = ref.requant_i8(x, shift)
    else:
        raise AssertionError(name)
    return NMA_OPS[name], length, shift, epsilon, beta_enable, x, y, beta, expected


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261125)
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    rng = random.Random(args.seed)
    nma_cases = [nma_case(rng, name, n) for name in NMA_OPS for n in LENGTHS]
    # Calibration shapes taken from the archived Round31 GPT-2 Product Top
    # R9_SFU_COMMAND log (requant 256: 835, layernorm 64: 1421, residual
    # 1024: 7173, GELU 256: 1539, softmax 16: 196 cycles).
    cal = [("requant", 256), ("layernorm", 64), ("residual", 1024),
           ("gelu", 256), ("softmax", 16)]
    cal_cases = [nma_case(rng, name, n) for name, n in cal]
    with (out / "nma_calibration.txt").open("w", encoding="ascii") as stream:
        stream.write(f"{len(cal_cases)}\n")
        for op, length, shift, eps, beta_en, x, y, beta, expected in cal_cases:
            stream.write(f"{op:02x} {length} {shift} {eps} {beta_en}\n")
            for vx, vy, vb, ve in zip(x, y, beta, expected):
                stream.write(f"{vx & 0xffffffff:08x} {vy & 0xffffffff:08x} "
                             f"{vb & 0xffffffff:08x} {ve & 0xffffffff:08x}\n")
    with (out / "nma_vectors.txt").open("w", encoding="ascii") as stream:
        stream.write(f"{len(nma_cases)}\n")
        for op, length, shift, eps, beta_en, x, y, beta, expected in nma_cases:
            stream.write(f"{op:02x} {length} {shift} {eps} {beta_en}\n")
            for vx, vy, vb, ve in zip(x, y, beta, expected):
                stream.write(f"{vx & 0xffffffff:08x} {vy & 0xffffffff:08x} "
                             f"{vb & 0xffffffff:08x} {ve & 0xffffffff:08x}\n")

    trng = random.Random(args.seed + 1)
    tiny_cases = []
    for name in TINY_OPS:
        for n in LENGTHS:
            x = [trng.randint(-128, 127) for _ in range(n)]
            if name == "softmax":
                # Attention-like scores; full INT8 range would saturate exp.
                x = [trng.randint(-64, 63) for _ in range(n)]
            y = [trng.randint(-128, 127) if name == "residual" else
                 trng.randint(-32, 31) if name == "layernorm" else 0
                 for _ in range(n)]
            tiny_cases.append({"op": name, "sel": TINY_OPS[name], "length": n,
                               "x": x, "y": y})
    with (out / "tiny_vectors.txt").open("w", encoding="ascii") as stream:
        stream.write(f"{len(tiny_cases)}\n")
        for case in tiny_cases:
            stream.write(f"{case['sel']} {case['length']}\n")
            for vx, vy in zip(case["x"], case["y"]):
                stream.write(f"{vx & 0xff:02x} {vy & 0xff:02x}\n")
    (out / "tiny_vectors.json").write_text(json.dumps(tiny_cases))
    print(f"TRANSFORMER_OPS_VECTORS_PASS nma_cases={len(nma_cases)} "
          f"tiny_cases={len(tiny_cases)} seed={args.seed} out={out}")


if __name__ == "__main__":
    main()
