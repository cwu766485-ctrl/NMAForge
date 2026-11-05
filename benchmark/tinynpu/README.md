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

The focused product GEMV comparison is run separately:

```sh
benchmark/tinynpu/run_gemv_match.sh
```

It exercises NMAForge opcode `0x52` at `M=1,N=13,K=17` and `M=8,N=16,K=19`
against the pinned TinyNPU 16×16 array with identical operand formulas. The
TinyNPU cases use zero-padded direct-array inputs; they do not exercise a
TinyNPU GEMV descriptor, controller, or SPAD. Its memory endpoint is therefore
reported as a serialized model alongside measured TinyNPU array cycles.

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

## Latest run

Run ID `TINY-COMPARE-V2C3A59-S20261029` ran on NMAForge SHA
`c3a59f08d8c07a8da973010d0f23d5d6d7eed61b` and pinned TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`. The GEMM CSV has 22 rows: 15
size-sweep points, four NMAForge matched shapes, and three TinyNPU matched
shapes. Both designs pass every output of the three paired shapes against an
independent INT32 Golden. NMAForge cycles are 172 / 263 / 1,391 with 512 /
1,024 / 6,144 SPAD read bytes and 1,024 / 1,024 / 4,096 write bytes. TinyNPU
direct-array cycles are 52 / 100 / 790; its serialized common-memory estimates
are 151 / 231 / 1,305 cycles. The stored ratio is NMAForge measured cycles /
TinyNPU normalized modeled cycles: 1.1391 / 1.1385 / 1.0659. Values above one
mean NMAForge used more cycles under this mixed measured/modeled endpoint.

The five-workload 4×4/8×8/16×16 size sweep passes 15/15 points. TinyNPU's
reference compute-engine regression passes 6/6. The paired ONNX graph uses
model SHA `1ac385ac…1811640`, input SHA `a74587bf…705898`, and 1,872 logical
INT8 MACs. Both sides pass Golden: NMAForge checks all intermediate tensors
and 4/4 outputs (1,985 compute + 1,080 host-layout cycles); TinyNPU checks 4/4
outputs at 4,781 graph-dispatch/testbench-shim cycles. These CNN timing
boundaries differ, so no speedup ratio is claimed.

Tools: VCS `V-2023.12-SP1_Full64`, Verilator 5.052 revision
`ea338be98e1e838d3518809ce8899f85a009963c`, Python 3.12.13, NumPy 2.4.6, and
ONNX 1.17.0. Raw logs are archived outside Git at
`/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59_logs.tar.gz`, SHA-256
`6825223159a0d75c6f876fc971d7b02f30be4fef5ae0c7d91911374add385cdf`.
The [replay report](../../docs/benchmark/NMAFORGE_V2_TINYNPU_REPLAY_2026-11-05.md)
has the exact command, timing boundaries, and evidence paths.

Charts are regenerated from the checked-in CSVs by:

```sh
python3 benchmark/tinynpu/plot_results.py
```

See [`gemm_cycle_comparison.svg`](gemm_cycle_comparison.svg) and
[`cnn_cycle_breakdown.svg`](cnn_cycle_breakdown.svg). The GEMM chart separates
TinyNPU measured array cycles from its modeled serialized-memory endpoint; the
CNN chart labels the differing timing windows and makes no speedup claim.

These CSVs are RTL simulation evidence and an explicitly identified memory
schedule estimate, not SRAM timing, ASIC PPA, or measured Fmax. See the
[benchmark report](../../docs/benchmark/NMAFORGE_VS_TINY_NPU.md) for run
identity, cycle boundaries, memory traffic, ablation and the remaining need
for an actual TinyNPU memory adapter. The separate three-seed Matrix performance rerun is archived
in [`compute_performance.csv`](../compute_performance.csv) and its summary JSON.
