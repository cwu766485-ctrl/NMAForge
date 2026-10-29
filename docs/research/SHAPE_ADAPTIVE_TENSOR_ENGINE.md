# Shape-Adaptive Tensor Engine Research Baseline

## Scope and branch boundary

This is the measurement baseline for a separate v2 architecture study. The
current `feat/shape-adaptive-gemv-v2` branch is based on the completed
`feat/tinynpu-model-inference` research branch and does not change product
Matrix RTL, descriptor ABI, or v1.0 sign-off sources. It contains an isolated
GEMV compute kernel. The prefetch/bandwidth results below are an analytical
schedule model, not an implemented SPAD controller or measured memory path.

## Existing Matrix measurements

Run ID `MATRIX-PERF-20261025-20261026-20261027-110e0c9d` used VCS
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

## Isolated 256-MAC GEMV kernel

RTL `rtl/research/ai_shape_adaptive_gemv.sv` uses the same 256 signed INT8
multipliers in both mappings. Baseline maps M×N outputs and advances K one
step per cycle. GEMV folds up to `16/M` K values across the 16 physical rows,
registers the products, then reduces each output in a separate cycle. Invalid
K lanes and output rows/columns are masked. A static selector compares the
shape cost estimates at 32 bytes/cycle and retains baseline when folding is
not predicted to help. The kernel takes packed operand buses directly; it is
not connected to the Matrix controller or SPAD.

Run ID `SHAPE-ADAPTIVE-20261029-b44894b7` is at NMAForge SHA
`b44894b7b1a900d5ab7df6a786b783c840808157`, with VCS
`V-2023.12-SP1_Full64`, seeds `20261025/20261026/20261027`, and command
`make shape-adaptive-regress`. Each seed checked 12 shapes (`M=1/4/8/16`,
`N=8/13/16`, `K=17/64`) for baseline, forced GEMV, and static selection.
All baseline and GEMV outputs matched the independent signed-INT8 testbench
Golden, including odd K tails and masked output columns. Abort, asynchronous
reset recovery, and zero-M descriptor rejection passed. The clean VCS compile
had no warning, error, or `[TFIPC]` diagnostics. The run produced 144 rows:
three seeds × 12 shapes × four ablations.

The four ablations hold the 256-MAC budget and 32 valid operand bytes/cycle
constant. The schedule model assumes one 32-byte read beat, ideal conflict-
free bank striping, and two-cycle GEMV compute plus reduction. It pads each
tile transfer to a whole beat. It does not simulate SRAM, a bank arbiter,
ready stalls, or an RTL prefetch buffer; its schedule cycles and SPAD traffic
are model outputs, not RTL memory measurements.

| Workload | Baseline | Baseline + modeled prefetch | GEMV fold | GEMV + modeled prefetch | Matched-prefetch speedup |
|---|---:|---:|---:|---:|---:|
| 1×13×64 | 128 | 65 | 36 | 30 | 2.17× |
| 1×16×64 | 128 | 65 | 44 | 38 | 1.71× |
| 4×16×64 | 128 | 65 | 80 | 50 | 1.30× |
| 8×16×64 | 128 | 65 | 128 | 66 | 0.98× |
| 16×16×64 | 128 | 65 | 192 | 129 | 0.50× |

For 1×13×64 the measured VCS compute-kernel cycles are 64 baseline versus 8
folded; the modeled end-to-end schedule is 65 versus 30 cycles with prefetch.
The same model predicts no benefit for M=8 and a regression for forced GEMV at
M=16. The static selector chooses baseline for those shapes, and also for the
short-K 1×8×17 case. Across all 12 workloads the mean speedup is 1.59× with
prefetch off and 1.16× with prefetch on; these are analytical schedule-model
averages, not measured SPAD or product-top speedups.

Machine-readable data is in
[`benchmark/shape_adaptive_ablation.csv`](../../benchmark/shape_adaptive_ablation.csv)
and [`benchmark/shape_adaptive_summary.json`](../../benchmark/shape_adaptive_summary.json).
Raw VCS runs are under `/tmp/nmaforge_shape_adaptive_20261029_214646`.

## Remaining v2 work

The next step is a real double-buffered fetch controller with a 4-bank memory
model, response ownership, variable ready/response latency, and an RTL
prefetch schedule. Then rerun the same four ablations with identical address
maps and bank conflicts, add parity/protection/abort/reset fault crosses, and
measure GEMM regression against the current production core. Area, timing,
and power remain NOT_RUN; no synthesis library was used.

This research kernel is not top-integrated, does not replace the production
GEMM path, and provides no sign-off claim. No speedup target is marked as a
measured hardware result.
