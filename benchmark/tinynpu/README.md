# NMAForge / TinyNPU benchmark harness

This harness pins `harishsg993010/tiny-NPU` to
`8216c22b762011aa20c05fc2768423fd12dda59d`, builds its SystemVerilog with
Verilator, runs a common INT8 GEMM vector on both compute arrays, runs the
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
[`gemm_results.csv`](gemm_results.csv). The run summary JSON remains alongside
those raw logs and is not committed as a tool database.

The same logical `16×16×16` signed INT8 matrices and an independent INT32
integer Golden are checked against 256 outputs on both designs. The current
TinyNPU 16×16 array is driven directly with its systolic wavefront input
schedule; its observed endpoint is “first operand accepted to all accumulators
stable”. NMAForge runs its Matrix controller with a one-cycle behavioral SPAD;
its endpoint includes bank reads and SPAD writeback. Therefore the two raw cycle
counts are not an apples-to-apples latency ratio. The CSV keeps both results
and records each boundary explicitly.

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

The committed GEMM CSV records Matrix size and common-vector results. The
paired CNN CSV has one row per design and records model/input hashes, both
cycle windows, SPAD traffic where instrumented, and Golden status. Its run ID,
NMAForge SHA, tool versions and exact values are repeated in the benchmark
report and the JSON generated beside the raw logs under `/tmp`.

For the paired graph, NMAForge checks all intermediate integer tensors and the
same four output bytes as TinyNPU. This workload counts 1,872 logical INT8 MACs
and submits eight CMDQ descriptors. The host-side flatten and matrix-layout
bridge is measured separately; preserve this distinction in any engine-only
comparison.

These CSVs are RTL simulation evidence, not SRAM timing, ASIC PPA, or measured
Fmax. See the [benchmark report](../../docs/benchmark/NMAFORGE_VS_TINY_NPU.md)
for run identity, cycle boundaries, memory traffic, ablation and outstanding
comparison work. The separate three-seed Matrix performance rerun is archived
in [`compute_performance.csv`](../compute_performance.csv) and its summary JSON.
