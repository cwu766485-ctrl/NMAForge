#!/usr/bin/env python3
"""Model-free self-test program for queued DMA (CMDQ opcode 0x60).

Builds a program-format-v3 image that streams random INT32 tiles through
1D and 2D DMA loads, RESIDUAL compute, 2D DMA stores back to DDR and
reloads of the stored data, so it exercises:

  * DMA_COPY load/store, 1D and 2D (row strides on both sides);
  * footprint-derived RAW/WAR/WAW event dependencies, including a DDR
    store -> load round trip;
  * DMA hoisting over independent compute (rotating double buffers);
  * event-on-complete and the DDR-resident CMDQ ring.

Every round's result is checked bit-exactly (checkpoint at the end of the
round's segment) and the final accumulator is checked at program end.

    python sw/compiler/qdma_selftest.py --out /tmp/qdma_selftest
    make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/qdma_selftest
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from nmaf import intops as I            # noqa: E402
from nmaf.program import Program        # noqa: E402
from cimforge_mapper import OP_RESIDUAL  # noqa: E402

ROWS, COLS = 16, 64                     # one tile: 16 rows x 64 INT32 words
PITCH = 96                              # DDR row pitch (words) for 2D tiles


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--rounds", type=int, default=6)
    ap.add_argument("--seed", type=int, default=37)
    a = ap.parse_args()
    rng = np.random.default_rng(a.seed)
    n = ROWS * COLS

    P = Program(overlap=True, hoist=32)
    acc = P.alloc("ACC", n * 4)
    bufa = [P.alloc(f"A{i}", n * 4) for i in range(2)]
    bufb = [P.alloc(f"B{i}", n * 4) for i in range(2)]
    tmp = P.alloc("TMP", n * 4)
    back = P.alloc("BACK", n * 4)

    acc_v = rng.integers(-1 << 20, 1 << 20, n)
    P.ddr_put("acc0", acc_v)
    P.dma("acc0", acc)
    stored = []
    for r in range(a.rounds):
        av = rng.integers(-1 << 20, 1 << 20, n)
        bv = rng.integers(-1 << 20, 1 << 20, (ROWS, PITCH))
        P.ddr_put(f"a{r}", av)                                  # 1D tile
        P.ddr_put(f"b{r}", bv)                                  # pitched rows
        P.ddr_put(f"out{r}", np.zeros((ROWS, PITCH), np.int64))
        A, B = bufa[r % 2], bufb[r % 2]
        P.dma(f"a{r}", A)
        P.dma(f"b{r}", B, COLS, rows=ROWS, ext_stride=PITCH * 4, spad_stride=COLS * 4)
        # tmp = (A + B) >> 1 ; stored to DDR rows with pitch, then reloaded
        t = I.residual(av, bv[:, :COLS].reshape(-1), 1)
        P.emit(f"r{r}.sum", OP_RESIDUAL, A, tmp, src1=B, k_or_length=n, shift=1, aux0=1)
        P.dma(f"out{r}", tmp, COLS, rows=ROWS, ext_stride=PITCH * 4, spad_stride=COLS * 4,
              store=True)
        P.dma(f"out{r}", back, COLS, rows=ROWS, ext_stride=PITCH * 4, spad_stride=COLS * 4)
        # acc += back - also reads A again so A's next reload waits (WAR)
        acc_v = I.residual(acc_v, t)
        P.emit(f"r{r}.acc", OP_RESIDUAL, acc, acc, src1=back, k_or_length=n, aux0=1)
        idx = P.emit(f"r{r}.mix", OP_RESIDUAL, A, tmp, src1=acc, k_or_length=n, shift=2, aux0=1)
        mix = I.residual(av, acc_v, 2)
        P.checkpoint(idx, tmp, I.words_i32(mix))
        stored.append(t)
    P.final_rows(acc, I.words_i32(acc_v), COLS, ROWS)
    man = P.write(a.out, {"selftest": "qdma", "rounds": a.rounds, "seed": a.seed})
    print("QDMA_SELFTEST_READY " + " ".join(f"{k}={man.get(k)}" for k in (
        "descriptors", "segments", "queued_dma", "hoisted_dma", "event_bits_peak",
        "dependency_waits", "cmdq_ddr_base")))


if __name__ == "__main__":
    main()
