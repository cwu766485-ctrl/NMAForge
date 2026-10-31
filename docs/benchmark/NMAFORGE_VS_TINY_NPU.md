# NMAForge vs TinyNPU RTL Benchmark

## Review boundary

This is a functional RTL and cycle-count comparison, not ASIC PPA evidence.
NMAForge uses a behavioral SPAD with a one-cycle read response. The pinned
TinyNPU RTL array wrapper exposes no SPAD request/response port, so its
array-cycle measurement is extended with an explicit common-memory schedule:
16 bytes/cycle, one-cycle read response, and serialized load/compute/store.
That normalized TinyNPU endpoint is a model around measured array RTL cycles,
not a measured TinyNPU memory-controller result. The CSV retains both raw and
normalized endpoints.

The NMAForge run is on research branch `feat/shape-adaptive-gemv-v2`, source
SHA `6848a414eaeaa05cf9e1411cf55d9d27333208a6`; Matrix product RTL is identical
to the audited candidate `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`. TinyNPU is
pinned to `harishsg993010/tiny-NPU`
[`8216c22b762011aa20c05fc2768423fd12dda59d`](https://github.com/harishsg993010/tiny-NPU/tree/8216c22b762011aa20c05fc2768423fd12dda59d).
Tools: VCS `V-2023.12-SP1_Full64`, Verilator `5.052` (2026-09-05, source tag
`v5.052`, revision `ea338be98e1e838d3518809ce8899f85a009963c`), Python
3.11.13, NumPy 2.4.6, ONNX 1.17.0. TinyNPU is built from its unmodified pinned
RTL; the local Verilator invocation disables an upstream `SYNCASYNCNET`
warning that otherwise stops the build under `-Wall` and uses
`-Wno-fatal`. This is simulation compatibility only.

Run ID: `TINY-FAIR-6848A41-S20261029`, seed `20261029`. The reproducible
entry point is `make benchmark-tinynpu`; instructions are in the
[harness README](../../benchmark/tinynpu/README.md). The committed
[GEMM CSV](../../benchmark/tinynpu/gemm_results.csv) includes the current
source SHA, shape, array size, raw and normalized cycles, memory bandwidth,
MAC/cycle, PE occupancy, SPAD bytes, stalls, Golden result, and timing
boundary for 22 measurements. Machine
summaries are committed in [`benchmark_summary.json`](../../benchmark/tinynpu/benchmark_summary.json)
and [`cnn_summary.json`](../../benchmark/tinynpu/cnn_summary.json).

The root `make compute-performance-report` benchmark was rerun on this exact
source SHA with seeds `20261029/30/31`. Run ID:
`MATRIX-PERF-20261029-20261030-20261031-6848a414`. All 45 size cases and 120
depth/prefetch/cache ablation cases passed their Golden checks (165/165).
The run used VCS `V-2023.12-SP1_Full64`, 10 ns simulation clock settings,
and a one-cycle behavioral SPAD. Its 250 MHz GOPS reference is an assumption,
not a measured clock frequency. Machine-readable evidence is in
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

| Design / shape | Physical array | Raw RTL cycles | Common-boundary cycles | MAC/cycle at common boundary | PE utilization at common boundary | Read / write bytes | Stalls |
|---|---:|---:|---:|---:|---:|---:|
| NMAForge 16×16×16 | 16×16 | 171 | 171 measured | 23.953 | 9.36% | 512 / 1,024 | 7 bank, 18 line-write |
| TinyNPU 16×16×16 | 16×16 | 52 array | 151 modeled | 27.126 | 10.60% | 512 / 1,024 modeled | N/A |
| NMAForge 16×16×32 | 16×16 | 263 | 263 measured | 31.148 | 12.17% | 1,024 / 1,024 | 17 bank, 28 line-write |
| TinyNPU 16×16×32 | 16×16 | 100 array | 231 modeled | 35.463 | 13.85% | 1,024 / 1,024 modeled | N/A |
| NMAForge 32×32×64 | 16×16 | 1,393 | 1,393 measured | 47.047 | 18.38% | 6,144 / 4,096 | 131 bank, 91 line-write |
| TinyNPU 32×32×64 | 16×16 | 790 array | 1,305 modeled | 50.219 | 19.62% | 4,096 / 4,096 modeled | N/A |

The common model uses one 128-bit line (16 bytes) per cycle and one cycle of
read response latency. NMAForge numbers are measured from Matrix start through
final output write and `done`, using its behavioral SPAD/controller path.
TinyNPU's estimated service is `ceil((A+B bytes)/16) + 1` read cycles and
`ceil(C bytes/16)` write cycles, added around the measured array interval and
two accumulator-clear cycles. Its load, compute, and store are serialized.

The cycle ratio `TinyNPU normalized / NMAForge measured` is 0.883, 0.878, and
0.937 for the three shapes. This is a model-normalized cycle comparison, not a
measured TinyNPU end-to-end RTL result or silicon speedup. The upstream
TinyNPU graph DMA/SRAM path remains a separate smoke measurement. Both sides
use identical INT8 values, output shapes, independent INT32 Golden checks, and
the stated 16-byte/cycle timing assumption. The earlier direct-array cycles
remain in the CSV for audit and are not compared directly to NMAForge's
controller interval.

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

The eight-way Matrix ablation is depth 2/4 × Prefetch OFF/ON × A-cache OFF/ON,
five shapes, three seeds. For 32×32×64, the depth-2/no-prefetch/no-cache
baseline is 1,698 cycles and 8,192 B of bank reads; depth-4/prefetch/cache is
1,187 cycles and 6,144 B (30.1% fewer cycles and 25% fewer bank-read bytes).
All 120 ablation points pass Golden on the current candidate. These results
use the fixed one-cycle behavioral SPAD model, not physical SRAM.

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
- TinyNPU does not expose a matching SPAD interface in its tested array
  wrapper. The common-memory TinyNPU values are a transparent adapter model;
  an actual same-interface RTL comparison requires an upstream memory adapter
  or a dedicated TinyNPU wrapper.
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

## R134 current-candidate replay — 2026-10-31

The current-candidate paired harness was rerun at NMAForge test SHA
`207cc3896cb635ff04e7095fc18c435080507724` with Run ID
`R134-TINY-NPU-PAIRED-20261031`, seed `20261026`, and pinned TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`. VCS `V-2023.12-SP1_Full64`,
Verilator 5.052, Python 3.12.13, NumPy 2.4.6 and ONNX 1.17.0 were recorded.
All three same-vector GEMM shapes passed independent output Golden checks on
both designs; the CNN graph passed as well. NMAForge required 171/263/1,393
measured Matrix-controller cycles for 16×16×16, 16×16×32 and 32×32×64.
TinyNPU's array RTL used 52/100/790 cycles; after the explicit serialized
16-byte/cycle, one-cycle memory schedule, its modeled endpoints were 151/231/
1,305 cycles. These results show the remaining Matrix path latency and do not
establish a product-level winner because TinyNPU memory is modeled and the
two RTL timing boundaries differ. The paired fixed-weight CNN likewise has
different endpoints and no speedup claim.

The R134 run refreshes the machine-readable CSV/JSON and leaves `REQ-CL-028`
PARTIAL. The run evidence, exact command, data hashes, and boundary analysis
are in the [R134 replay report](../verification/COMPUTE_CLUSTER_TINYNPU_REPLAY_R134_2026-10-31.md).
