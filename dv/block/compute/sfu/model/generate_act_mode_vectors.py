#!/usr/bin/env python3
"""Directed/random vectors for the Round 35 SFU flag[7] modes.

  op 0x35 + flag[7]  LUT activation: code = sat8((x + 2^(s-1)) >> s),
                     out = LUT[code + 128] (signed INT8), LUT = 64 words at src1
  op 0x36 + flag[7]  REQUANT round-to-nearest: sat8((x + 2^(s-1)) >> s)

Output layout follows REQUANT: sign-extended words, linear packing (4 INT8 per
word, little-endian, partial last word zero-padded) or Matrix-A tile order
(word (r//4)*n + (c//4)*4 + r%4, byte c%4).
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path


def sat8(v: int) -> int:
    return max(-128, min(127, v))


def round_shift(x: int, s: int) -> int:
    return (x + ((1 << (s - 1)) if s else 0)) >> s


def gelu_lut(s_in: float, s_out: float) -> list[int]:
    out = []
    for code in range(-128, 128):
        x = code * s_in
        g = 0.5 * x * (1.0 + math.erf(x / math.sqrt(2.0)))
        out.append(sat8(round(g / s_out)))
    return out  # index code+128


def pack_words(values: list[int], pack: int, tile_a: int, n: int) -> list[int]:
    if not pack:
        return [v & 0xFFFFFFFF for v in values]
    words: dict[int, int] = {}
    for i, v in enumerate(values):
        if tile_a:
            r, c = divmod(i, n)
            w = (r // 4) * n + (c // 4) * 4 + (r % 4)
            lane = c % 4
        else:
            w, lane = divmod(i, 4)
        words[w] = words.get(w, 0) | ((v & 0xFF) << (8 * lane))
    return [words.get(w, 0) for w in range(max(words) + 1)]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=20261125)
    ap.add_argument("--random-cases", type=int, default=60)
    ap.add_argument("--output", required=True)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    cases = []

    def add(op, length, shift, pack, tile_a, m, n, inplace=False):
        span = rng.choice((1 << 10, 1 << 14, 1 << 20, 1 << 31))
        x = [rng.randint(-span, span - 1) for _ in range(length)]
        x[:6] = [(1 << 31) - 1, -(1 << 31), 0, 1, -1, (1 << shift) - 1][:min(6, length)]
        if op == 0x35:
            lut = gelu_lut(rng.choice((1 / 16, 1 / 32, 1 / 64)), rng.choice((1 / 32, 1 / 64)))
            vals = [lut[sat8(round_shift(v, shift)) + 128] for v in x]
        else:
            lut = [0] * 256
            vals = [sat8(round_shift(v, shift)) for v in x]
        cases.append((op, length, shift, pack, tile_a, m, n, int(inplace), x, lut,
                      pack_words(vals, pack, tile_a, n)))

    for op in (0x35, 0x36):
        for length in (1, 3, 4, 5, 16, 63, 64, 197, 256):
            for pack in (0, 1):
                add(op, length, rng.randint(0, 12), pack, 0, 0, 0)
        for m, n in ((4, 16), (8, 64), (16, 16), (4, 4), (12, 192)):
            add(op, m * n, rng.randint(0, 12), 1, 1, m, n)
        add(op, 100, 3, 0, 0, 0, 0, inplace=True)
    for _ in range(a.random_cases):
        op = rng.choice((0x35, 0x36))
        if rng.random() < 0.4:
            m, n = 4 * rng.randint(1, 8), 4 * rng.randint(1, 16)
            add(op, m * n, rng.randint(0, 31), 1, 1, m, n)
        else:
            add(op, rng.randint(1, 300), rng.randint(0, 31), rng.randint(0, 1), 0, 0, 0,
                inplace=rng.random() < 0.2)
    with Path(a.output).open("w") as f:
        f.write(f"{len(cases)}\n")
        for op, length, shift, pack, tile_a, m, n, inplace, x, lut, out in cases:
            if inplace and pack:
                inplace = 0
            f.write(" ".join(f"{v:x}" for v in (op, length, shift, pack, tile_a, m, n, inplace, len(out))) + "\n")
            for v in x:
                f.write(f"{v & 0xffffffff:08x}\n")
            for w in range(64):
                f.write(f"{sum((lut[4*w+b] & 0xff) << (8*b) for b in range(4)):08x}\n")
            for w in out:
                f.write(f"{w & 0xffffffff:08x}\n")
    print(f"SFU_ACT_MODE_VECTORS cases={len(cases)} seed={a.seed} output={a.output}")


if __name__ == "__main__":
    main()
