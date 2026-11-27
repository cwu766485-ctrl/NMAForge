# NMAForge digital-CNM evaluation summary

Status summary: 2026-10-21. For per-engine functional and code-coverage
convergence, see the [compute-engine status page](../verification/COMPUTE_ENGINE_STATUS.md).

## Scope

This public summary covers the bank-local digital compute-near-memory (CNM)
path. It does not claim analog in-SRAM compute, system-level TOPS or complete
LLM-serving performance.

## What was evaluated

- Four bank-local controllers and PEs for INT8 VDOT/GEMV.
- Local address generation, operand buffering, partial accumulation and final
  reduction across the four banks.
- Directed VCS regressions and a controlled GEMV benchmark against the prior
  scalar baseline.
- Interaction with the active DMA/scratchpad/command-completion architecture is
  exercised by top-level smoke and the selected DMA–SPAD–CNM campaign.

## Results boundary

The controlled bank-local GEMV benchmark demonstrated approximately 1.98×
cycle improvement relative to the retained scalar baseline for its documented
fixed workload. The 4×4 matrix-tile benchmark demonstrated approximately
3.97× relative cycle improvement for its own fixed GEMM workload.

These are microbenchmark cycle comparisons, not end-to-end FPGA throughput,
ASIC TOPS, energy efficiency or application latency claims. Memory latency,
DDR bandwidth, tile size, clock frequency and workload shape can dominate an
actual system result.

## Comparison with the Matrix engine (Round 40, 2026-11-27)

The speedups above are against the retained scalar baseline. On GPT-2 decode
shapes the Matrix engine of the same Product Top is faster:

| Shape | CNM `0x21` GEMV (1 row) | Matrix `0x30` GEMM (4 rows, Round 39) |
|---|---:|---:|
| 64×768 | 9,697 cycles | 3,977 cycles |
| 256×64 | 4,705 cycles | 1,795 cycles |

The bank-local controllers fetch the A and B words in separate admissions, so
the CNM streams about 5 B/cycle of weights against about 13 B/cycle for the
staged Matrix.

The CNM can overlap the Matrix on independent work. 8 GEMMs plus 8 GEMVs take
96,928 cycles concurrently, against 141,684 cycles serially.

Moving per-sequence decode attention onto the CNM was nevertheless 3.7–10.8%
slower than Matrix attention at contexts of 64 and 256, for three reasons:

- in-order issue;
- the single scheduler-side SPAD port;
- the SPAD capacity left for double-buffered caches.

See the [Round 40 report](../benchmark/NMAFORGE_V1_4_ROUND40_BATCH_DECODE_BANDWIDTH.md).

## Implementation evidence

A licensed commercial-28-nm pre-layout synthesis study met a 4.0 ns clock
constraint under its documented nominal-PVT assumptions. The result is
summarized in [TSMC28_SYNTHESIS_REPORT.md](../verification/TSMC28_SYNTHESIS_REPORT.md); raw
libraries, macro adapters and reports are private.

## Next measurements

1. Board-level effective GB/s, MAC/s, DMA-stall and overlap counters.
2. Fixed-shape CNN/Transformer end-to-end cycle and byte counts; existing
   overlap data covers selected FP ping-pong workloads only.
3. Residual DUT coverage and cross-layer fault/reset closure; selected groups
   are not global coverage closure.
4. Post-layout multi-corner PPA with licensed physical-design collateral.
