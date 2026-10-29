# NMAForge / TinyNPU benchmark harness

This harness pins `harishsg993010/tiny-NPU` to
`8216c22b762011aa20c05fc2768423fd12dda59d`, builds its SystemVerilog with
Verilator, runs three common INT8 GEMM shapes on both compute arrays, runs the
TinyNPU engine regression and ONNX CNN Graph smoke, and writes CSV/JSON
evidence. It does not modify the TinyNPU checkout.

## Requirements and run

Use VCS `V-2023.12-SP1_Full64`, Verilator 5.052 or compatible, Git, a C++17
compiler, and Python 3.9+ with NumPy and ONNX installed. `PYTHON`, `VERILATOR`,
`TINY_NPU_ROOT`, `TINYNPU_BENCH_OUT`, `SEED`, and `JOBS` can be overridden.

```sh
make benchmark-tinynpu
```

The script clones the pinned reference under `/tmp` if `TINY_NPU_ROOT` is not
set. It writes raw compile/run logs and binaries under `/tmp`, then updates
[`gemm_results.csv`](gemm_results.csv), [`cnn_results.csv`](cnn_results.csv),
[`benchmark_summary.json`](benchmark_summary.json), and
[`cnn_summary.json`](cnn_summary.json). Raw logs and binaries stay under `/tmp`.

The same signed INT8 input formulas and independent INT32 Golden are used for
`16×16×16`, `16×16×32`, and `32×32×64`. TinyNPU tiles each problem across its
16×16 systolic array and checks every output (256, 256, and 1,024 values).
NMAForge runs its actual Matrix controller and banked SPAD model and checks all
output words against the independent Golden. The TinyNPU array interval is
measured directly, then extended with a clearly marked common-memory estimate
using a 16-byte line, 16 bytes/cycle bandwidth, and one-cycle read response.
The model serializes load, array execution, and output commit and includes the
two accumulator-clear cycles. It does not claim TinyNPU memory RTL results.

The same command also runs the NMAForge 4×4/8×8/16×16 Matrix size sweep, the
TinyNPU six-engine reference regression, and both sides of the pinned
`conv1x_mini.onnx` graph (`8×8×1 → 3×3 Conv → ReLU → Flatten → GEMM`).
NMAForge executes the convolution and FC GEMMs and their fixed-point post-ops
through the real top-level Matrix/SFU engines and command/completion queues.
The testbench performs only the explicit intermediate layout conversion; it
does not calculate model operators. `cnn_results.csv` records both designs'
cycles and memory boundaries. The timing windows differ, so the harness does
not report a CNN speedup ratio.

## Current run

Run ID `TINY-FAIR-6848A41-S20261029` ran on NMAForge SHA
`6848a414eaeaa05cf9e1411cf55d9d27333208a6` and pinned TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`. The GEMM CSV has 22 data rows:
15 NMAForge size cases, one 8×8 NMAForge common case, three 16×16 NMAForge
common cases, and three TinyNPU common cases. The paired CNN CSV has one row per design and records
model/input hashes, both cycle windows, SPAD traffic where instrumented, and
Golden status. Run identity, tools, and exact values are in the committed
summary JSON files and the benchmark report.

For the three paired shapes, NMAForge records 171 / 263 / 1,393 measured
cycles, 512 / 1,024 / 6,144 SPAD read bytes, and 1,024 / 1,024 / 4,096 write
bytes. TinyNPU records 52 / 100 / 790 direct-array cycles and 151 / 231 / 1,305
normalized cycles under the common model. Both pass every output against
independent INT32 Golden. The normalized cycle ratios are estimates, since
TinyNPU's tested wrapper has no SPAD port. Both use the same assumed line
bandwidth and response delay, but only NMAForge's controller/SPAD interval is
measured RTL timing.

Tools: VCS `V-2023.12-SP1_Full64`, Verilator 5.052 (source tag `v5.052`,
revision `ea338be98e1e838d3518809ce8899f85a009963c`), Python 3.11.13, NumPy
2.4.6, and ONNX 1.17.0. TinyNPU builds use `-Wno-SYNCASYNCNET -Wno-fatal` for the
pinned reference RTL. The TinyNPU and NMAForge CNN compiles emit the existing
`LOOP-REROLL-ENABLED` test-fixture warning; no compile errors occurred.

For the paired graph, NMAForge checks all intermediate integer tensors and the
same four output bytes as TinyNPU. This workload counts 1,872 logical INT8 MACs
and submits eight CMDQ descriptors. The host-side flatten and matrix-layout
bridge is measured separately; preserve this distinction in any engine-only
comparison.

These CSVs are RTL simulation evidence and an explicitly identified memory
schedule estimate, not SRAM timing, ASIC PPA, or measured Fmax. See the
[benchmark report](../../docs/benchmark/NMAFORGE_VS_TINY_NPU.md) for run
identity, cycle boundaries, memory traffic, ablation and the remaining need
for an actual TinyNPU memory adapter. The separate three-seed Matrix performance rerun is archived
in [`compute_performance.csv`](../compute_performance.csv) and its summary JSON.
