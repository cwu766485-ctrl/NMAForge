# NMAForge digital-CNM evaluation summary

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
  covered separately by top-level smoke and block verification.

## Results boundary

The controlled bank-local GEMV benchmark demonstrated approximately 1.98×
cycle improvement relative to the retained scalar baseline for its documented
fixed workload. The 4×4 matrix-tile benchmark demonstrated approximately
3.97× relative cycle improvement for its own fixed GEMM workload.

These are microbenchmark cycle comparisons, not end-to-end FPGA throughput,
ASIC TOPS, energy efficiency or application latency claims. Memory latency,
DDR bandwidth, tile size, clock frequency and workload shape can dominate an
actual system result.

## Implementation evidence

A licensed commercial-28-nm pre-layout synthesis study met a 4.0 ns clock
constraint under its documented nominal-PVT assumptions. The result is
summarized in [TSMC28_SYNTHESIS_REPORT.md](TSMC28_SYNTHESIS_REPORT.md); raw
libraries, macro adapters and reports are private.

## Next measurements

1. Board-level effective GB/s, MAC/s, DMA-stall and overlap counters.
2. Load/compute/store overlap on ping-pong tiles.
3. Multi-seed UVM coverage closure for DMA, control, arbitration and queue
   subsystems.
4. Post-layout PPA with licensed physical-design collateral.
