# Shape-Adaptive Tensor Engine Research Baseline

## Scope and branch boundary

This is the measurement baseline for a separate v2 architecture study. The
current `feat/tinynpu-model-inference` work does not change product Matrix RTL.
No GEMV-mode RTL, bandwidth scheduler, area result, or timing result is claimed
by this document. Implementation experiments must be isolated from the v1.0
Compute Cluster audit candidate.

## Existing Matrix measurements

Run ID `MATRIX-PERF-20261025-20261026-20261027-df733587` used VCS
`V-2023.12-SP1_Full64`, three seeds, and the one-cycle behavioral SPAD model.
All 45 size cases and 120 ablation cases passed their independent Golden
checks. The current Tensor GEMM descriptor requires M and N to be non-zero
multiples of four, so the existing interface cannot submit true M=1 decode
work directly.

For K=32 on the 16×16 physical array, measured cases include:

| Logical M×N×K | Cycles | MAC/cycle | Physical-array utilization |
|---|---:|---:|---:|
| 4×4×32 | 76 | 6.737 | 2.63% |
| 8×8×32 | 116 | 17.655 | 6.90% |
| 16×16×32 | 233 | 35.159 | 13.73% |

The largest tested 32×32×64 workload reaches 55.211 MAC/cycle and 21.57%
utilization on the 16×16 array at 1,187 cycles. These values include Matrix
controller, behavioral scratchpad traffic and output writes; the 250 MHz
effective-GOPS normalization in lower-level logs is not a measured frequency.
The three-seed raw data is archived in
[`benchmark/compute_performance.csv`](../../benchmark/compute_performance.csv).

## Required v2 experiment

The next experiment must add legal M=1/4/8/16 decode-like shapes through an
isolated block or an approved descriptor extension, with an independent
integer Golden and fixed valid-byte bandwidth. Compare the baseline mapping
against GEMV lane folding, bandwidth-aware prefetch, and their combination.
Record useful versus padded MACs, cycles, SPAD traffic, stalls, utilization,
and (once a synthesis flow and valid library are available) area and timing.

No speedup target is marked achieved yet. Functional GEMM regressions and
fault/reset checks must continue to pass for any candidate implementation.
