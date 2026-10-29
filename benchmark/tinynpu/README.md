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
TinyNPU six-engine reference regression, and TinyNPU's pinned
`conv1x_mini.onnx` graph (`8×8×1 → 3×3 Conv → ReLU → Flatten → GEMM`). The
current NMAForge CNN record is a separate single-convolution microbenchmark;
the full ONNX graph has not yet been mapped to NMAForge, so no cross-design CNN
speedup is claimed.

## Current run

The committed CSV records Run ID `TINY-COMPARE-20261029-S20261029`, NMAForge
research-branch source SHA `df7335871068c6e2fbbc6a0eaad315d6c5815fef`, and TinyNPU
SHA `8216c22b762011aa20c05fc2768423fd12dda59d`. It contains 15 current-source
Matrix size-sweep rows and three common-shape GEMM rows (NMAForge 8×8, NMAForge
16×16, TinyNPU 16×16). The 16×16×16 common Golden passed 256/256 outputs on
each side. TinyNPU's official engine suite passed 6/6; its ONNX CNN Graph
completed in 4,781 testbench cycles and matched all four output bytes.

This CSV is RTL simulation evidence, not SRAM timing, ASIC PPA, or measured
Fmax. See the [benchmark report](../../docs/benchmark/NMAFORGE_VS_TINY_NPU.md)
for run identity, cycle boundaries, memory traffic, ablation and outstanding
comparison work. The separate three-seed Matrix performance rerun is archived
in [`compute_performance.csv`](../compute_performance.csv) and its summary JSON.
