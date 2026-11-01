# Compute Cluster Matrix Benchmark — R164 — 2026-11-02

## Scope and source identity

R164 reruns the Matrix physical-array size sweep and eight-way microarchitecture ablation at exact test SHA `db7588be34200ac68ac66072799adca54ad287a5` (tree `e0816beba67133fbf6221005f16f97cba63eb2ca`). Product RTL/SPEC is unchanged. Each of seeds `20261025/26/27` runs five signed-INT8 GEMM shapes on `4×4`, `8×8`, and `16×16` arrays, then on `16×16` with Depth `2/4` × Prefetch `OFF/ON` × A-Tile Cache `OFF/ON`. All 165 points pass the independent complete-output Golden checker.

The memory model is behavioral SPAD with a one-cycle bank response. The testbench period is 10 ns. `effective_gops_250mhz_assumption` normalizes cycle counts at an assumed 250 MHz; it is not measured frequency, silicon throughput, or PPA.

## Physical array size

Cycles at Depth 4 / Prefetch ON / A-Tile Cache ON (identical across all three seeds):

| Workload | 4×4 cycles | 8×8 cycles | 16×16 cycles | 16×16 MAC/cycle | 16×16 utilization |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 76 | 76 | 76 | 6.737 | 2.63% |
| 8×8×32 | 259 | 116 | 116 | 17.655 | 6.90% |
| 16×16×32 | 957 | 397 | 233 | 35.159 | 13.73% |
| 16×32×32 | 1,788 | 709 | 417 | 39.290 | 15.35% |
| 32×32×64 | 6,543 | 2,447 | 1,187 | 55.211 | 21.57% |

The `4×4×32` workload is setup and memory dominated: all arrays take 76 cycles. For `32×32×64`, the `16×16` array takes 5.51× fewer cycles than `4×4` in this model.

## Eight-configuration ablation

The CSV contains all eight configurations. “Baseline” is Depth 2 / Prefetch OFF / A-Tile Cache OFF; “all on” is Depth 4 / Prefetch ON / A-Tile Cache ON. Entries are identical across the three seeds.

| Workload | Baseline → all-on cycles | Speedup | MAC/cycle baseline → all-on | Utilization baseline → all-on | SPAD read bytes baseline → all-on | Total SPAD bytes baseline → all-on | Bank stalls baseline → all-on | Line stalls baseline → all-on |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99 → 76 | 1.30× | 5.172 → 6.737 | 2.02% → 2.63% | 256 → 256 | 320 → 320 | 4 → 3 | 1 → 0 |
| 8×8×32 | 135 → 116 | 1.16× | 15.172 → 17.655 | 5.93% → 6.90% | 512 → 512 | 768 → 768 | 11 → 12 | 2 → 3 |
| 16×16×32 | 265 → 233 | 1.14× | 30.906 → 35.159 | 12.08% → 13.73% | 1,024 → 1,024 | 2,048 → 2,048 | 25 → 24 | 22 → 28 |
| 16×32×32 | 504 → 417 | 1.21× | 32.508 → 39.290 | 12.70% → 15.35% | 2,048 → 1,536 | 4,096 → 3,584 | 53 → 38 | 22 → 65 |
| 32×32×64 | 1,698 → 1,187 | 1.43× | 38.603 → 55.211 | 15.08% → 21.57% | 8,192 → 6,144 | 12,288 → 10,240 | 156 → 136 | 74 → 72 |

One-factor cycle comparisons isolate the effects:

| Workload | Baseline | Depth 4 only | Prefetch ON only | A-Tile Cache ON only | All on |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 99 | 99 | 76 | 99 | 76 |
| 8×8×32 | 135 | 135 | 116 | 135 | 116 |
| 16×16×32 | 265 | 242 | 248 | 265 | 233 |
| 16×32×32 | 504 | 486 | 483 | 445 | 417 |
| 32×32×64 | 1,698 | 1,636 | 1,555 | 1,471 | 1,187 |

Cache ON alone reduces operand reads by 25% for the two multi-macro-tile shapes (`16×32×32` and `32×32×64`). Depth and prefetch do not change those read-byte counts; they affect overlap and stalls. Cache does not help `16×16×32`, which fits one cached tile. For `16×32×32`, all-on raises Line stalls from 22 to 65 even while lowering bank stalls and reads.

## Integrated real-Cluster task timing

The exact-SHA three-seed UVM also runs a Matrix/CNM/SFU task benchmark through production dispatch and shared SPAD arbitration. All three seeds report identical values:

| Scenario | Cycles | Read / write bytes | Result |
|---|---:|---:|---|
| Serial Matrix + CNM + SFU | 1,239 (`565 + 217 + 457`) | 4,352 / 2,688 | Reference three-task workload |
| Staged Matrix+CNM, then SFU | 1,070 (`613 + 457`) | 4,032 / 2,416 | 1.158× vs the same three tasks serially; 32 pair-contention cycles |
| Parallel Matrix + CNM + two SFUs | 1,137 | 4,352 / 2,688 | 1.492× vs the same four tasks serially at 1,696 cycles; completion order preserved |

These are RTL simulation cycles and modeled SPAD transactions, not wall-clock chip measurements.

## Reproduction and evidence

Tool: Synopsys VCS `V-2023.12-SP1_Full64`. Run from a clean worktree at the exact SHA above:

```sh
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/matrix/sim matrix-size-benchmark \
    VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
    SEED=$seed BENCH_OUT_DIR=/tmp/nmaforge_r164_matrix_size_$seed
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
    VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
    SEED=$seed MATRIX_CONFIG_OUT=/tmp/nmaforge_r164_matrix_config_$seed
done
```

- [Detailed CSV](compute_cluster_matrix_r164.csv): 165 rows (45 array-size and 120 ablation results); SHA-256 `c02e8c1b110bd2bbde0a8778a59f0f7933f12192ca2c599b8857560c8c0b52e0`.
- Logs-only archive: `/tmp/nmaforge_r164_evidence_logs.tar.gz`; SHA-256 `c784ba44f8e1af5ad0c793fcf644b78ae855d457192825f806fb8552bec1fada`.
- Every row records `golden=PASS`, seed, physical array and configuration, 10 ns period, and the one-cycle behavioral SPAD model.

This is a reproducible Matrix RTL benchmark, not a TinyNPU comparison or ASIC PPA result. `REQ-CL-028` remains PARTIAL pending matched TinyNPU workloads and broader integrated-system comparison. The 38-row disposition remains `24 PASS-SCOPED / 14 PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
