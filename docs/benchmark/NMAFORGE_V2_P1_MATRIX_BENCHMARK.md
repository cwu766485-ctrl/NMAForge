# NMAForge v2 P1 Matrix Performance Benchmark

## Run identity and scope

- Candidate SHA: `550ef39f22c22c39eb3bfd7f38dbc574b630e163` (branch `feature/npu-architecture-v2`).
- Run ID: `MATRIX-PERF-20261105-20261106-20261107-550ef39f`.
- Seeds: `20261105`, `20261106`, `20261107`; VCS `V-2023.12-SP1_Full64`.
- Result: 45 size-sweep + 120 ablation points; 165/165 independent Golden checks PASS.
- Model: one-cycle behavioral SPAD. 250 MHz is only a reference conversion and is not measured Fmax, SRAM timing, ASIC PPA, or power.
- The suite measures the Matrix RTL core/controller path; it is not a fair TinyNPU comparison. TinyNPU paired replay is pending because Verilator is unavailable in this workspace.

Invocation from the candidate worktree:

```bash
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' PYTHON=python3.12 SEEDS='20261105 20261106 20261107' COMPUTE_PERF_OUT=/tmp/nmaforge_v2_p1_perf_550ef_20261105 make compute-performance-report
```

Raw machine-readable results: [`CSV`](../../benchmark/v2_p1_matrix_performance_550ef39.csv) and [`run summary`](../../benchmark/v2_p1_matrix_performance_550ef39_summary.json). Full console logs remain under `/tmp/nmaforge_v2_p1_perf_550ef_20261105` on the run host.

## Size sweep

Configuration: outstanding depth 4, Next-K prefetch ON, A-tile cache ON. Table entries are arithmetic means across the three seeds; the source CSV preserves per-seed values.

| Physical array | Shape | Cycles | MAC/cycle | Array utilization | SPAD read/write | Bank/line stalls |
|---:|---:|---:|---:|---:|---:|---:|
| 4x4 | 4x4x32 | 77.3 | 6.622 | 41.4% | 256.0 B / 64.0 B | 3.3 / 1.0 |
| 4x4 | 8x8x32 | 261.7 | 7.827 | 48.9% | 768.0 B / 256.0 B | 14.3 / 4.3 |
| 4x4 | 16x16x32 | 941.7 | 8.7 | 54.4% | 2560.0 B / 1024.0 B | 40.0 / 24.7 |
| 4x4 | 16x32x32 | 1795.7 | 9.124 | 57.0% | 4608.0 B / 2048.0 B | 98.7 / 36.0 |
| 4x4 | 32x32x64 | 6521.3 | 10.049 | 62.8% | 18432.0 B / 4096.0 B | 359.7 / 88.7 |
| 8x8 | 4x4x32 | 77.3 | 6.622 | 10.3% | 256.0 B / 64.0 B | 3.3 / 1.0 |
| 8x8 | 8x8x32 | 124.0 | 16.523 | 25.8% | 512.0 B / 256.0 B | 15.0 / 8.0 |
| 8x8 | 16x16x32 | 391.0 | 20.959 | 32.8% | 1536.0 B / 1024.0 B | 30.3 / 21.7 |
| 8x8 | 16x32x32 | 718.7 | 22.8 | 35.6% | 2560.0 B / 2048.0 B | 55.0 / 48.7 |
| 8x8 | 32x32x64 | 2419.7 | 27.085 | 42.3% | 10240.0 B / 4096.0 B | 215.3 / 79.3 |
| 16x16 | 4x4x32 | 77.3 | 6.622 | 2.6% | 256.0 B / 64.0 B | 3.3 / 1.0 |
| 16x16 | 8x8x32 | 124.0 | 16.523 | 6.5% | 512.0 B / 256.0 B | 15.0 / 8.0 |
| 16x16 | 16x16x32 | 229.7 | 35.728 | 14.0% | 1024.0 B / 1024.0 B | 20.0 / 28.7 |
| 16x16 | 16x32x32 | 385.7 | 42.512 | 16.6% | 1536.0 B / 2048.0 B | 32.7 / 39.0 |
| 16x16 | 32x32x64 | 1177.7 | 55.652 | 21.7% | 6144.0 B / 4096.0 B | 116.0 / 82.7 |

## Eight-configuration ablation

Physical array 16×16; depth 2/4 × prefetch OFF/ON × A-tile cache OFF/ON, five shapes and three seeds per point. Below, baseline is depth 2/prefetch OFF/cache OFF and full configuration is depth 4/prefetch ON/cache ON.

| Shape | Baseline cycles | Full cycles | Cycle change | Baseline read | Full read | Read change | Full MAC/cycle | Full utilization |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4x4x32 | 98.3 | 77.3 | -21.4% | 256.0 B | 256.0 B | +0.0% | 6.622 | 2.6% |
| 8x8x32 | 136.0 | 124.0 | -8.8% | 512.0 B | 512.0 B | +0.0% | 16.523 | 6.5% |
| 16x16x32 | 252.7 | 229.7 | -9.1% | 1024.0 B | 1024.0 B | +0.0% | 35.728 | 14.0% |
| 16x32x32 | 510.3 | 385.7 | -24.4% | 2048.0 B | 1536.0 B | -25.0% | 42.512 | 16.6% |
| 32x32x64 | 1694.3 | 1177.7 | -30.5% | 8192.0 B | 6144.0 B | -25.0% | 55.652 | 21.7% |

For the larger 16×32×32 and 32×32×64 workloads, A-tile reuse cuts bank-read bytes by 25%; combining it with prefetch and depth 4 reduces cycles by about 24% and 30%, respectively, versus the stated baseline. On 4×4×32 and 8×8×32, A-cache does not reduce traffic because those shapes do not reuse an A row across multiple column tiles. This is a measured result of the one-cycle behavioral model, not evidence of physical SRAM performance.

`line_stalls` is reported by the size-sweep harness; the ablation harness reports bank stalls but leaves `line_stalls` blank. Blank means not reported, not zero. This run provides no fault, abort, reset, or concurrent-engine conclusions.

## TinyNPU comparison status

The environment check `verilator --version` returns `/bin/bash: verilator: command not found`. The pinned TinyNPU source is `8216c22b762011aa20c05fc2768423fd12dda59d`; historic paired measurements exist in [`gemm_results.csv`](../../benchmark/tinynpu/gemm_results.csv), but they were run against an earlier NMAForge candidate. They are retained as historical context and are not relabeled as this candidate’s paired benchmark. A current-SHA TinyNPU replay remains `BLOCKED_ENV`.

## Limits and next work

- This completes the NMAForge Matrix size/configuration benchmark slice of P1, not the fair TinyNPU comparison requirement.
- No RTL was changed for this benchmark commit.
- The later fixed-SHA v2 replay closes the named three-seed Tile Forwarding core and Top CMDQ checks; broader Bank-Aware Issue, fault/phase combinations, cross-engine coherence, and legacy interaction coverage remain open. See [current performance comparison](NMAFORGE_V2_PERFORMANCE_COMPARISON.md).
- PPA remains `NOT_RUN`; the 250 MHz reference must not be presented as measured frequency.
