# NMAForge v2 / TinyNPU Paired Replay

**Run ID:** `TINY-COMPARE-V2C3A59-S20261029`  
**NMAForge source SHA:** `c3a59f08d8c07a8da973010d0f23d5d6d7eed61b`  
**TinyNPU SHA:** `8216c22b762011aa20c05fc2768423fd12dda59d`  
**Seed:** `20261029`  
**Status:** listed simulation targets PASS; not a TinyNPU product-level sign-off.

## Exact replay command

Run from the NMAForge repository root:

```sh
env \
  VCS_ARCH_OVERRIDE=linux \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  VCS_VERSION=V-2023.12-SP1_Full64 \
  TINYNPU_BENCH_OUT=/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59 \
  BENCH_RUN_ID=TINY-COMPARE-V2C3A59-S20261029 \
  SEED=20261029 JOBS=8 \
  bash benchmark/tinynpu/run_comparison.sh
```

The TinyNPU checkout was fetched and verified at the pinned SHA above. Verilator
was built in `/tmp` from tag `v5.052`, revision
`ea338be98e1e838d3518809ce8899f85a009963c`. The Python environment used
Python 3.12.13, NumPy 2.4.6, and ONNX 1.17.0. VCS is
`V-2023.12-SP1_Full64`.

## Results

| Test | Result | Measurement boundary |
|---|---|---|
| NMAForge Matrix size sweep | 15/15 Golden PASS | Five shapes × 4×4/8×8/16×16 physical arrays; one-cycle behavioral SPAD; one Seed. |
| Paired INT8 GEMM | 3/3 shapes PASS on both | Independent signed INT32 Golden checks every output. |
| TinyNPU engine regression | 6/6 PASS | Pinned upstream testbench regression; integrity check, not matched performance. |
| Paired ONNX `conv1x_mini` | PASS on both | Same ONNX model and input hashes; TinyNPU graph dispatcher/testbench DMA-SRAM shim versus NMAForge two top-level CMDQ windows. No speed ratio because timed graph boundaries differ. |

### GEMM data

| Shape | NMAForge RTL cycles | NMAForge SPAD read/write | TinyNPU direct array cycles | TinyNPU common-memory estimate | NMA / Tiny normalized |
|---|---:|---:|---:|---:|---:|
| 16×16×16 | 172 | 512 / 1,024 B | 52 | 151 | 1.1391 |
| 16×16×32 | 263 | 1,024 / 1,024 B | 100 | 231 | 1.1385 |
| 32×32×64 | 1,391 | 6,144 / 4,096 B | 790 | 1,305 | 1.0659 |

The common-memory estimate gives TinyNPU a 16-byte line, 16 bytes/cycle
bandwidth, one-cycle read response, serialized read/compute/write phases, and
two accumulator-clear cycles. TinyNPU's tested wrapper does not expose a SPAD
interface. NMAForge's cycle count and traffic come from RTL simulation with a
behavioral SPAD. Thus the ratio is explicitly mixed measured/modeled evidence;
greater than one means NMAForge took more cycles under this model. It is not an
ASIC result, nor does it prove a fair fixed-resource win or loss.

### CNN data

| Design | Cycles | Bytes/traffic evidence | Golden |
|---|---:|---|---|
| NMAForge | 1,985 compute + 1,080 host-layout | compute reads 3,360 B; writes 1,600 B; host-layout reads 144 B and writes 576 B | all intermediate tensors and 4/4 outputs exact |
| TinyNPU | 4,781 graph cycles | graph dispatch plus testbench DMA/SRAM shim; setup excluded | 4/4 outputs exact |

Model SHA-256: `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`.  
Input SHA-256: `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`.  
The graph has 1,872 logical INT8 MACs and uses eight NMAForge CMDQ descriptors.
NMAForge excludes SPAD preload, descriptor programming, and final host read;
TinyNPU excludes testbench input setup. The graph engines and timed windows
differ, so no speedup ratio is computed.

## Evidence and remaining scope

Machine-readable results are checked in at
[`gemm_results.csv`](../../benchmark/tinynpu/gemm_results.csv),
[`cnn_results.csv`](../../benchmark/tinynpu/cnn_results.csv),
[`benchmark_summary.json`](../../benchmark/tinynpu/benchmark_summary.json), and
[`cnn_summary.json`](../../benchmark/tinynpu/cnn_summary.json). Compile and
simulation logs are archived outside Git at
`/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59_logs.tar.gz`, SHA-256
`6825223159a0d75c6f876fc971d7b02f30be4fef5ae0c7d91911374add385cdf`.

This replay closes only the listed benchmark points. Still open: a true
TinyNPU common memory adapter; paired small/thin GEMV; a separately trained
CNN; a constrained trained-weight Tiny Transformer; per-phase DMA/writeback
and graph orchestration counters; v2 DC PPA; LEC/DFT and physical readiness.
The v1.0 Compute Cluster disposition remains HOLD, and no tapeout readiness or
overall NPU sign-off is claimed.
