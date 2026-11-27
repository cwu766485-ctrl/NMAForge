#!/usr/bin/env python3
"""Random command set for the legacy-vs-stream SFU differential testbench.

Each case gives a command, its operand regions and an optional fault
injection.  The testbench runs the identical command on a legacy-only core
and a fast-path core with independent randomized SPAD timing and compares
status, result, element count and the complete final memory image.
"""

from __future__ import annotations

import argparse
import random
from pathlib import Path

OPS = ("residual", "gelu", "requant", "requant_pack", "requant_tile_a",
       "layernorm", "softmax", "causal_softmax")
CODE = {"residual": 0x34, "gelu": 0x35, "requant": 0x36, "requant_pack": 0x36,
        "requant_tile_a": 0x36, "layernorm": 0x38, "softmax": 0x32,
        "causal_softmax": 0x39}
# Word addresses inside the 16K-word model memory.
SRC0, SRC1, BETA, DST = 0x0400, 0x1400, 0x2400, 0x3000
INJ_NONE, INJ_PARITY, INJ_PROTECTION, INJ_ABORT = 0, 1, 2, 3


def length_for(rng: random.Random, op: str) -> int:
    pick = rng.random()
    if op == "requant_tile_a":
        m = 4 * rng.randint(1, 8)
        n = 4 * rng.randint(1, 16)
        return m * n
    if pick < 0.15:
        return rng.choice((1, 2, 3, 4, 5, 15, 16, 17, 32, 64, 197, 255, 256))
    if pick < 0.30 and op == "layernorm":
        # Round 38: the 1024-entry row cache keeps LN rows up to 1024 on the
        # stream path (GPT-2 D=768); longer rows fall back to the legacy FSM.
        return rng.choice((257, 384, 512, 768, 768, 1024, 1025, 1100))
    if pick < 0.22 and op in ("softmax", "causal_softmax"):
        return rng.choice((257, 300, 384))  # Softmax stream limit 256: legacy fallback
    return rng.randint(1, 256)


def case(rng: random.Random, op: str, inject: bool):
    n = length_for(rng, op)
    m_size = n_size = 0
    if op == "requant_tile_a":
        while True:
            m_size = 4 * rng.randint(1, 8)
            if n % m_size == 0 and (n // m_size) % 4 == 0:
                n_size = n // m_size
                break
    shift = rng.randint(0, 31) if op in ("residual",) else rng.randint(0, 20)
    eps = rng.randint(0, 40)
    beta_en = int(op == "layernorm" and rng.random() < 0.7)
    gamma = int(op == "layernorm" and rng.random() < 0.8)
    pack = int(op in ("requant_pack", "requant_tile_a"))
    tile_a = int(op == "requant_tile_a")
    src0, src1, beta, dst = SRC0, SRC1 if (op == "residual" or gamma) else 0, BETA, DST
    alias = rng.random()
    if op in ("residual", "gelu", "requant") and alias < 0.25:
        dst = src0                       # in-place
    elif op == "residual" and alias < 0.35:
        dst = src1                       # in-place on the second operand
    elif op in ("residual", "gelu", "requant", "softmax") and alias < 0.42:
        dst = src0 + rng.randint(1, 8)   # overlapping offset: legacy fallback
    if op == "causal_softmax":
        eps = rng.randint(0, max(0, n - 1))
    if op in ("softmax", "causal_softmax"):
        x = [rng.randint(-4096, 4096) for _ in range(n)]
    elif op == "layernorm":
        span = rng.choice((64, 8192, 1 << 20))
        x = [rng.randint(-span, span) for _ in range(n)]
    elif op == "gelu":
        x = [rng.randint(-2048, 2048) for _ in range(n)]
    else:
        x = [rng.randint(-(1 << 31), (1 << 31) - 1) for _ in range(n)]
    y = [rng.randint(-(1 << 31), (1 << 31) - 1) if op == "residual" else
         rng.randint(-32768, 32767) for _ in range(n)]
    b = [rng.randint(-64, 64) for _ in range(n)]
    inj_kind = rng.choice((INJ_PARITY, INJ_PROTECTION, INJ_ABORT)) if inject else INJ_NONE
    inj_at = rng.randint(0, max(0, n - 1))
    return (CODE[op], n, shift, eps, beta_en, pack, tile_a, m_size, n_size,
            src0, src1, beta, dst, inj_kind, inj_at, x, y, b)


# Rows whose exact softmax quotient is a multiple of the row sum while the
# 2^56 reciprocal is inexact: the stream path's one-step correction is
# required to reproduce the legacy divider here.
SOFTMAX_CORRECTION_ROWS = (
    [0, -31, -181], [0, -304, -713, -928, -782], [0, -445, -474, -722],
    [0, -155, -692], [0, -598, -293, -964, -466, -301],
    [0, -498, -589, -1425, -1674, -1137],
)
GELU_BOUNDARIES = [-2049, -2048, -1024, -513, -512, -511, -2, -1, 0, 1, 2,
                   511, 512, 513, 1024, 2047, 2048]
REQUANT_BOUNDARIES = [-(1 << 31), -32769, -32768, -129, -128, -127, -1, 0, 1,
                      126, 127, 128, 32767, 32768, (1 << 31) - 1]


def directed_cases():
    out = []
    def mk(code, x, y=None, shift=0, eps=1, pack=0):
        n = len(x)
        y = y if y is not None else [0] * n
        out.append((code, n, shift, eps, 0, pack, 0, 0, 0, SRC0, 0, BETA, DST,
                    INJ_NONE, 0, x, y, [0] * n))
    for row in SOFTMAX_CORRECTION_ROWS:
        mk(0x32, row)
        mk(0x39, row, eps=len(row) - 1)
        mk(0x32, [v - 1000 for v in row])            # shifted: same deltas
    mk(0x35, GELU_BOUNDARIES)
    for shift in (0, 1, 7, 8, 15, 31):
        mk(0x36, REQUANT_BOUNDARIES, shift=shift)
        mk(0x36, REQUANT_BOUNDARIES + [5], shift=shift, pack=1)
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261125)
    parser.add_argument("--cases", type=int, default=400)
    parser.add_argument("--fault-cases", type=int, default=60)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    rng = random.Random(args.seed)
    cases = [case(rng, OPS[i % len(OPS)], False) for i in range(args.cases)]
    cases += directed_cases()
    cases += [case(rng, rng.choice(OPS), True) for _ in range(args.fault_cases)]
    with Path(args.output).open("w", encoding="ascii") as f:
        f.write(f"{len(cases)}\n")
        for c in cases:
            f.write(" ".join(f"{v:x}" for v in c[:15]) + "\n")
            for vx, vy, vb in zip(c[15], c[16], c[17]):
                f.write(f"{vx & 0xffffffff:08x} {vy & 0xffffffff:08x} {vb & 0xffffffff:08x}\n")
    print(f"SFU_STREAM_EQUIV_VECTORS cases={len(cases)} fault_cases={args.fault_cases} "
          f"seed={args.seed} output={args.output}")


if __name__ == "__main__":
    main()
