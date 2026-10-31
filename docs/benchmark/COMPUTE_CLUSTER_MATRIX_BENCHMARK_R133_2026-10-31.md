# Matrix Size and Configuration Benchmark — R133

**Run ID:** `R133-MATRIX-SIZE-ABLATION-20261031`  
**Date:** 2026-10-31  
**Executed source SHA:** `207cc3896cb635ff04e7095fc18c435080507724`  
**Source tree:** `caed517e162270fc2f64beb5382fecdccb651bd5`  
**Tool:** Synopsys VCS `V-2023.12-SP1`  
**Seed:** `20261026`  
**Product RTL/SPEC:** unchanged; benchmark-only execution.

## Scope and commands

The two runs use the same standalone production Matrix core, deterministic workload set, 16-byte banked-read and Line-write accounting, and one-cycle behavioral bank response. Every case compares the full output Memory Image to the testbench's independent signed Golden and checks read-response drain and cycle-accounting consistency.

```sh
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 \
  BENCH_OUT_DIR=/tmp/nmaforge_r132_size_20261031

make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_r132_config_20261031
```

- Array-size comparison: physical arrays 4×4, 8×8, and 16×16; five workloads each; 15/15 Golden cases pass.
- Configuration ablation: physical array fixed at 16×16; Outstanding Depth 2/4 × Next-K Prefetch OFF/ON × A-Tile Cache OFF/ON; five workloads each; 40/40 Golden cases pass.
- Workloads: `4×4×32`, `8×8×32`, `16×16×32`, `16×32×32`, `32×32×64`.

## Array-size comparison

Selected representative cases; the complete 15-row data set is in the CSV artifact.

| Workload | Physical array | Cycles | MAC/cycle | Array utilization | Bank read bytes | Line write bytes | Bank stalls | Line stalls |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 4×4 | 76 | 6.737 | 42.11% | 256 | 64 | 3 | 0 |
| 4×4×32 | 8×8 | 76 | 6.737 | 10.53% | 256 | 64 | 3 | 0 |
| 4×4×32 | 16×16 | 76 | 6.737 | 2.63% | 256 | 64 | 3 | 0 |
| 16×16×32 | 4×4 | 957 | 8.560 | 53.50% | 2,560 | 1,024 | 63 | 17 |
| 16×16×32 | 8×8 | 397 | 20.635 | 32.24% | 1,536 | 1,024 | 27 | 31 |
| 16×16×32 | 16×16 | 233 | 35.159 | 13.73% | 1,024 | 1,024 | 24 | 28 |
| 32×32×64 | 4×4 | 6,543 | 10.016 | 62.60% | 18,432 | 4,096 | 384 | 86 |
| 32×32×64 | 8×8 | 2,447 | 26.782 | 41.85% | 10,240 | 4,096 | 235 | 87 |
| 32×32×64 | 16×16 | 1,187 | 55.211 | 21.57% | 6,144 | 4,096 | 136 | 72 |

The small 4×4×32 workload is setup/memory dominated in this model: all array sizes take 76 cycles, so utilization falls as the configured array grows. On 32×32×64, 8×8 is 2.67× faster than 4×4 and 16×16 is 5.51× faster than 4×4 under the same bank-response model.

## Eight-configuration ablation

The baseline is Depth 2 / Prefetch OFF / A-Tile Cache OFF. The last column is its cycle ratio to Depth 4 / Prefetch ON / A-Tile Cache ON.

| Workload | Baseline cycles | D4/P1/C1 cycles | Speedup | Baseline bank-read bytes | D4/P1/C1 bank-read bytes | Baseline→D4/P1/C1 bank stalls | Baseline→D4/P1/C1 line stalls |
|---|---:|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99 | 76 | 1.30× | 256 | 256 | 4→3 | 0→0 |
| 8×8×32 | 135 | 116 | 1.16× | 512 | 512 | 11→12 | 0→0 |
| 16×16×32 | 265 | 233 | 1.14× | 1,024 | 1,024 | 25→24 | 22→28 |
| 16×32×32 | 504 | 417 | 1.21× | 2,048 | 1,536 | 53→38 | 22→65 |
| 32×32×64 | 1,698 | 1,187 | 1.43× | 8,192 | 6,144 | 156→136 | 74→72 |

For 16×32×32 and 32×32×64, A-Tile reuse reduces banked input reads by 25%. End-to-end cycles improve 17.3% and 30.1% respectively in the D4/P1/C1 configuration. The small workloads show less benefit and can carry higher output-stall counts despite lower total cycles.

The detailed rows also retain `arbiter_stall`, `response_wait`, `writeback_wait`, FIFO-full, outstanding high-water, prefetch-wait, and cache-hit counters. “Tracked input/output bytes” is specifically accepted banked operand-read bytes plus accepted Line output-write bytes; it excludes descriptor, DMA, and unrelated control traffic.

## Results and interpretation limits

VCS simulation period is 10 ns. The log's `effective_gops_250mhz` is a cycle-counter arithmetic reference at an assumed 250 MHz, not measured frequency or silicon throughput. This benchmark uses behavioral Matrix memory with a fixed one-cycle response and no foundry SRAM timing model. It provides RTL cycle, traffic, stall, and Golden evidence only. It is not ASIC PPA, SRAM timing sign-off, energy, or a TinyNPU head-to-head result.

## Reproducibility artifacts

All generated files remain outside Git:

- Array-size logs and detail CSV: `/tmp/nmaforge_r132_size_20261031/`; `matrix_size_detail.csv` SHA-256 `d8a3c3f2568c1d7c9c195fe1667941beeb851fb5b2ce1d1c13e3ebc8ea897aeb`.
- Eight-config logs, original comparison CSV, summary, and detailed counters: `/tmp/nmaforge_r132_config_20261031/`.
- Detailed configuration CSV SHA-256: `78191f1d336a0496e1514ad8ae24d72923af2113acc67efef28408dfa40b9e84`.
- Original comparison CSV SHA-256: `0314a8df69aa9245e1335942c2ccb00a45b417d0caca23a1e6a4044355e40045`.
- Summary SHA-256: `0c953146a3e1de34ac93d40e2d761dc54a95b5d3bc6cb07080079fb6e24b1d8b`.
- Compile/run logs and CSV hashes: `/tmp/nmaforge_r132_matrix_bench_SHA256SUMS`, SHA-256 `20e4929888cb35522d10bc636eee774ce288ec4c68719dfd4f81470d1fcf52c5`.

R133 adds current-source evidence to `REQ-CL-028`; that requirement remains PARTIAL because the full workload matrix, equal-resource TinyNPU comparison, and integrated performance/power scope are not closed. No requirement disposition changes; the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains **HOLD**.
