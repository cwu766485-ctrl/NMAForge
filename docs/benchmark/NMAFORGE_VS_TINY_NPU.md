# NMAForge vs TinyNPU RTL Benchmark

## Review boundary

This is a functional RTL and cycle-count comparison, not an ASIC PPA or an
implementation-level speedup claim. NMAForge uses a behavioral SPAD with a
one-cycle read response. TinyNPU's direct-array measurement bypasses its graph
DMA and SRAM ports; its CNN Graph smoke uses a testbench DMA shim. The CSV
records the measured endpoints so results are not conflated.

The NMAForge run is on research branch `feat/shape-adaptive-gemv-v2`, source
SHA `08c34322879c688afd505ddf41fa4b2a5dc93ac0`; Matrix product RTL is identical
to the audited candidate `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`. TinyNPU is
pinned to `harishsg993010/tiny-NPU`
[`8216c22b762011aa20c05fc2768423fd12dda59d`](https://github.com/harishsg993010/tiny-NPU/tree/8216c22b762011aa20c05fc2768423fd12dda59d).
Tools: VCS `V-2023.12-SP1_Full64`, Verilator `5.052` (2026-09-05, source tag
`v5.052`, revision `ea338be98e1e838d3518809ce8899f85a009963c`), Python
3.12.13, NumPy 2.1.3, ONNX 1.17.0. TinyNPU is built from its unmodified pinned
RTL; the local Verilator invocation disables an upstream `SYNCASYNCNET`
warning that otherwise stops the build under `-Wall` and uses
`-Wno-fatal`. This is simulation compatibility only.

Run ID: `TINY-COMPARE-20261029-S20261029`, seed `20261029`. The reproducible
entry point is `make benchmark-tinynpu`; instructions are in the
[harness README](../../benchmark/tinynpu/README.md). The committed
[GEMM CSV](../../benchmark/tinynpu/gemm_results.csv) includes the current
source SHA, shape, array size, cycles, MAC/cycle, PE occupancy, SPAD bytes,
stalls, Golden result, and timing boundary for 22 measurements. Machine
summaries are committed in [`benchmark_summary.json`](../../benchmark/tinynpu/benchmark_summary.json)
and [`cnn_summary.json`](../../benchmark/tinynpu/cnn_summary.json).

The root `make compute-performance-report` entry passed on this same source
SHA with seeds `20261025/26/27`. Run ID:
`MATRIX-PERF-20261025-20261026-20261027-110e0c9d`. All 45 size cases and 120
depth/prefetch/cache ablation cases passed their Golden checks (165/165).
Machine-readable evidence is in
[`compute_performance.csv`](../../benchmark/compute_performance.csv) and
[`compute_performance_summary.json`](../../benchmark/compute_performance_summary.json).

## Same-vector INT8 GEMM

Both designs use the same deterministic signed INT8 matrices:

```text
A[r,k] = ((3*r + 2*k + 1) % 9) - 4
B[k,c] = ((2*k - 3*c + 5) % 9) - 4
C       = A × B, signed INT32 accumulation
```

Both independently check every output against the integer Golden for the
three paired shapes (256, 256, and 1,024 outputs).

| Design / shape | Physical array | Cycles to measured endpoint | MAC/cycle | PE utilization | SPAD read / write | Stalls |
|---|---:|---:|---:|---:|---:|---:|
| NMAForge 16×16×16 | 8×8 | 298 | 13.745 | 21.48% | 768 B / 1,024 B | 18 bank, 21 line-write |
| NMAForge 16×16×16 | 16×16 | 171 | 23.953 | 9.36% | 512 B / 1,024 B | 7 bank, 18 line-write |
| TinyNPU 16×16×16 | 16×16 | 52 | 78.769 | 30.77% | Not modeled | Not modeled |
| NMAForge 16×16×32 | 16×16 | 263 | 31.148 | 12.17% | 1,024 B / 1,024 B | 17 bank, 28 line-write |
| TinyNPU 16×16×32 | 16×16 | 100 | 81.920 | 32.00% | Not modeled | Not modeled |
| NMAForge 32×32×64 | 16×16 | 1,393 | 47.047 | 18.38% | 6,144 B / 4,096 B | 131 bank, 91 line-write |
| TinyNPU 32×32×64 | 16×16 | 790 | 82.957 | 32.41% | Not modeled | Not modeled |

The NMAForge endpoint starts at Matrix command acceptance and ends after the
last output SPAD write and `done`. TinyNPU has no command wrapper in this test:
its endpoint starts when the first skewed systolic operands are accepted and
ends when every output-tile accumulator is stable. For 32×32×64, TinyNPU
clears and runs four output tiles, each accumulating four K tiles. This
excludes graph DMA, SRAM loading, input stalls, and output streaming. The
measurements establish matching arithmetic and expose each architecture's
measured work; they do **not** define a latency speedup because the boundaries
and memory paths differ.

The standalone NMAForge 3×3 convolution check also passed on VCS, seed
`20261029`: 9 useful MACs, 66 cycles, 72 B read, 4 B written, result `-30`.
Its input/filter pattern is not the same as TinyNPU's complete ONNX model, so
it is reported as an operator check rather than a paired CNN result.

## Matrix size sweep

The current-source size sweep ran 15 cases (five shapes × three physical array
sizes) at seed `20261029`, with outstanding depth 4, Next-K prefetch enabled,
A-tile cache enabled, and a one-cycle behavioral SPAD. All 15 Golden checks
passed.

| Physical array | Shape | Cycles | MAC/cycle | Array utilization | SPAD read / write | Bank / line stalls |
|---:|---:|---:|---:|---:|---:|---:|
| 4×4 | 4×4×32 | 76 | 6.737 | 42.11% | 256 B / 64 B | 3 / 0 |
| 4×4 | 8×8×32 | 259 | 7.907 | 49.42% | 768 B / 256 B | 14 / 2 |
| 4×4 | 16×16×32 | 957 | 8.560 | 53.50% | 2,560 B / 1,024 B | 63 / 17 |
| 4×4 | 16×32×32 | 1,788 | 9.163 | 57.27% | 4,608 B / 2,048 B | 93 / 34 |
| 4×4 | 32×32×64 | 6,543 | 10.016 | 62.60% | 18,432 B / 4,096 B | 384 / 86 |
| 8×8 | 4×4×32 | 76 | 6.737 | 10.53% | 256 B / 64 B | 3 / 0 |
| 8×8 | 8×8×32 | 116 | 17.655 | 27.59% | 512 B / 256 B | 12 / 3 |
| 8×8 | 16×16×32 | 397 | 20.635 | 32.24% | 1,536 B / 1,024 B | 27 / 31 |
| 8×8 | 16×32×32 | 709 | 23.109 | 36.11% | 2,560 B / 2,048 B | 59 / 35 |
| 8×8 | 32×32×64 | 2,447 | 26.782 | 41.85% | 10,240 B / 4,096 B | 235 / 87 |
| 16×16 | 4×4×32 | 76 | 6.737 | 2.63% | 256 B / 64 B | 3 / 0 |
| 16×16 | 8×8×32 | 116 | 17.655 | 6.90% | 512 B / 256 B | 12 / 3 |
| 16×16 | 16×16×32 | 233 | 35.159 | 13.73% | 1,024 B / 1,024 B | 24 / 28 |
| 16×16 | 16×32×32 | 417 | 39.290 | 15.35% | 1,536 B / 2,048 B | 38 / 65 |
| 16×16 | 32×32×64 | 1,187 | 55.211 | 21.57% | 6,144 B / 4,096 B | 136 / 72 |

This run shows the latency and utilization tradeoff as physical array size
changes. The 4×4 design runs the largest case in 6,543 cycles at 62.60%
utilization, while the 16×16 design runs it in 1,187 cycles at 21.57%.
Utilization is computed against the configured physical INT8 MAC count over
the reported controller cycle interval; it is not an ASIC frequency or power
measurement.

The three-seed replay is deterministic for these directed vectors: each
array/shape combination produced the same cycle count, traffic and stalls in
all three seeds. For 32×32×64 on the 16×16 array, all seeds reported 1,187
cycles, 6,144 B read, 4,096 B written, 136 bank stalls, 72 line-write stalls,
55.211 MAC/cycle and 21.57% utilization. The lowest-workload utilization is
only 2.63% for 4×4×32 on a 16×16 array, which exposes the shape mismatch for
small batches.

The existing same-seed eight-way Matrix ablation evidence is in the
[Compute Cluster benchmark report](../verification/COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md):
depth 2/4 × Prefetch OFF/ON × A-cache OFF/ON, five shapes, three seeds
`20261025/26/27`, 120/120 checks passed on the clean candidate. For 32×32×64,
the depth-2/no-prefetch/no-cache baseline is 1,698 cycles and 512 bank reads;
depth-4/prefetch/cache is 1,187 cycles and 384 reads (30.1% fewer cycles and
25% fewer bank reads). This result uses the same one-cycle behavioral SPAD
model, not physical SRAM.

The new three-seed run reproduced those 32×32×64 endpoint values in all seeds:
depth-2/prefetch-off/cache-off was 1,698 cycles and 8,192 B of bank reads;
depth-4/prefetch-on/cache-on was 1,187 cycles and 6,144 B. This is 30.1% fewer
cycles and 25% fewer bank-read bytes in the fixed behavioral memory model.

## TinyNPU reference integrity and CNN Graph

On the pinned TinyNPU SHA, the official Verilator engine regression passed
6/6: GELU, 16×16 systolic GEMM, Softmax, LayerNorm, Vec ADD, and a chained
GELU/ADD check. The custom same-vector systolic test passed 256/256 INT32
accumulators. The pinned ONNX `conv1x_mini.onnx` graph contains 8×8×1 input,
3×3 convolution, ReLU, Flatten, and GEMM. TinyNPU compiled 13 instructions and
11 tensor descriptors, used 1,312 bytes of SRAM allocation, and completed the
graph in 4,781 testbench cycles. All four output bytes matched the compiler's
Golden.

That CNN's graph uses fixed random weights from the checked-in model and a
seeded test input. It is a functional smoke, not a trained model. Its cycle
count includes the graph testbench and DMA/SRAM shim.

## Paired full CNN graph

The pinned `conv1x_mini.onnx` graph was mapped through the production NMAForge
top. The workload generator reads the ONNX tensors, applies the fixed INT8
scales/shifts, independently computes Golden intermediate tensors, and
confirms the four final bytes against TinyNPU's generated `golden.bin`.
NMAForge executes two GEMM layers and their requant/bias/ReLU post-ops through
eight CMDQ descriptors. The testbench performs only the explicit
flatten/matrix-layout conversion of RTL-produced values; it does no operator
math on the host. Every intermediate tensor, all eight completion IDs/statuses,
and all four output bytes are checked.

| Design | Logical INT8 MACs | Measured engine/graph cycles | Host layout cycles | Memory traffic | Golden |
|---|---:|---:|---:|---|---|
| NMAForge top | 1,872 | 1,985 | 1,080 | Compute SPAD 3,360 B read / 1,600 B write; layout 144 B read / 576 B write; 3,456 B preload | Intermediate tensors and 4/4 output bytes exact |
| TinyNPU ONNX graph | 1,872 | 4,781 | N/A | 1,312 B SRAM allocation; per-engine traffic unavailable | 4/4 output bytes exact |

Run ID `TINY-COMPARE-20261029-110e0c9-S20261029`; NMAForge SHA
`110e0c9db49eb1a7a558c955347accfde87f963e`, TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`, model SHA-256
`1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`, input
seed 99, and input INT8 SHA-256
`a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`.
Tools were VCS `V-2023.12-SP1_Full64`, Verilator 5.052, Python 3.11.13,
NumPy 2.1.3 and ONNX 1.17.0. The committed [`cnn_results.csv`](../../benchmark/tinynpu/cnn_results.csv) and
the paired `cnn_summary.json` emitted with run logs record the run identity,
hashes, tools, and measurements. NMAForge's measured engine interval spans two
CMDQ execution windows and excludes SPAD preload, descriptor programming, and
final host reads. Host layout is reported separately. TinyNPU's graph interval
uses the graph dispatcher and a testbench memory shim. These boundaries and
memory paths differ, so the cycle counts are **not** an apples-to-apples
latency or speedup comparison. They demonstrate exact results for the same
fixed-weight model and input through both RTLs.

The older `R19` TinyNPU pair in the [historical report](../verification/COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md)
used a different TinyNPU repository/commit and an earlier NMAForge source SHA.
Its 8×8 GEMM and padded-GEMM convolution data are retained for provenance only;
they are not merged into the current pinned-reference CSV.

## Open work and interpretation

- The current pinned TinyNPU reference does not expose an 8×8 configuration
  in the tested engine wrapper; current matched-array results use 16×16.
- The same bandwidth-constrained 16×16 GEMM is not yet run through both
  designs' memory interfaces. Until it is, no normalized speedup is available.
- The paired CNN uses fixed weights from TinyNPU's checked-in ONNX graph; it is
  not a trained model. A hardware-native flatten/reformat operator is not part
  of this workload; the host layout bridge is measured separately.
- TinyNPU and NMAForge now share Golden-checked 16×16×16, 16×16×32, and
  32×32×64 arithmetic vectors. The broader 8×8 TinyNPU pairing and a
  bandwidth-constrained run through both memory interfaces remain open.
- 64×64 workloads are not included in this paired benchmark.
- No candidate-specific ASIC synthesis, SRAM timing view, measured Fmax, or
  power report was run. Any 250 MHz effective-GOPS column in existing Matrix
  logs is a normalization assumption only.
- Compute Cluster v1.0 remains a sign-off candidate, not signed: the final
  audit is 24 PASS-SCOPED / 14 PARTIAL, with unresolved functional closure
  items documented in the [audit report](../verification/COMPUTE_CLUSTER_V1_FINAL_AUDIT.md).
