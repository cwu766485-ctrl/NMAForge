# Compute Cluster Matrix Ablation and Top Concurrency Benchmark — R205

**Date:** 2026-11-02
**Candidate:** clean R204 checkout `bce4f81ef37158cf80e46f5804256c8e7531a9d9`
**Tree:** `a60e7523a11795cceddb83ccce71828f204e6ff3`
**RTL/UVM content:** `f87acc9bca3b3ecece385fadfd5623de6837ea8d`
**Run IDs:** `CL-MATRIX-ABLATION-R205-20261102`; `CL-CLEAN-HEAD-REPLAY-R204-20261102`
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`; behavioral production SPAD, registered one-cycle response.

## Matrix configuration ablation

The clean R204 worktree ran the existing `matrix-config-comparison` target with seeds `20261025/20261026/20261027`. It swept outstanding depth 2/4, next-K prefetch OFF/ON, and A-tile cache OFF/ON across five legal GEMM shapes. The Make target checked all five case IDs in each configuration; all 120 configuration/workload/seed points passed the testbench's independent Golden checks, and all cycle counts matched across seeds.

| Depth / Prefetch / A-cache | Cycle sum | Change vs D2/P0/C0 | Read bytes across five shapes |
|---|---:|---:|---:|
| D2 / OFF / OFF | 2,701 | baseline | 12,032 |
| D2 / OFF / ON | 2,415 | -10.59% | 9,472 |
| D2 / ON / OFF | 2,478 | -8.26% | 12,032 |
| D2 / ON / ON | 2,158 | -20.10% | 9,472 |
| D4 / OFF / OFF | 2,598 | -3.81% | 12,032 |
| D4 / OFF / ON | 2,329 | -13.77% | 9,472 |
| D4 / ON / OFF | 2,337 | -13.51% | 12,032 |
| D4 / ON / ON | **2,029** | **-24.88%** | **9,472** |

The best swept configuration is D4/P1/C1 for this workload set. The A-cache saves one quarter of bank-read bytes on the multi-A-tile cases (`16x32x32`: 128→96 reads; `32x32x64`: 512→384); it does not reduce reads for the other three shapes. Prefetch lowers cycles on these five workloads, while depth 4 has little effect on the smaller cases. These are shape- and memory-model-specific results, not a claim that every configuration wins on every shape.

The per-point CSV includes cycles, MAC cycles, bank reads/bytes/stalls, Line-write bytes/stalls, MAC/cycle, array utilization, and normalized effective GOPS for all 120 points: [R205 Matrix CSV](compute_cluster_matrix_ablation_r205.csv). The existing command's summary CSVs are retained in the evidence archive.

## Real Compute Cluster task throughput

The R204 real-top UVM log contains three runs of the same deterministic task bundle. Each seed produced identical results and all completion, Golden-memory, and UVM checks passed.

| Mode | Workload / measurement window | Cycles | Comparison | SPAD read / write bytes | Shared admission contention |
|---|---|---:|---:|---:|---:|
| Serial | Matrix + CNM + SFU + SFU | 1,696 | baseline | 4,352 / 2,688 | — |
| Parallel | Same four tasks dispatched together; completion remains CMDQ ordered | 1,137 | 1.492× speedup | 4,352 / 2,688 | 38 cycles |
| Staged | Matrix + CNM concurrent, then one SFU | 1,070 | 1.158× vs same three tasks serial (1,239 cycles) | 4,032 / 2,416 | 32 cycles in the Matrix/CNM pair |
| Reset recovery | Active reset followed by recovery task completion | 307 | recovery latency | — | — |

Each timing window is doorbell-to-completion-tail; descriptor programming is excluded. The parallel case compares the same four operations and moves the measured work from 1,696 to 1,137 cycles without changing the measured SPAD byte counts. The staged case is a three-task comparison, so it is not compared against the four-task serial total. The completion order and task outputs were checked by the real-top UVM sequence.

Machine-readable rows are in [R205 Cluster CSV](compute_cluster_concurrency_r205.csv). The source run logs are part of the evidence archive.

## Reproduction

Matrix ablation:

```sh
cd dv/block/compute/matrix/sim
for seed in 20261025 20261026 20261027; do
  VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
    make matrix-config-comparison SEED=$seed \
    MATRIX_CONFIG_OUT=/tmp/nmaforge_r205_matrix_ablation_$seed \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg
done
```

The Cluster benchmark markers are emitted by `uvm_compute_cluster_regress`, already run for R204 on seeds `20261025/20261026/20261027`. See [R204 replay](../verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R204_2026-11-02.md).

Evidence archive: `/tmp/nmaforge_r205_benchmark_evidence_20261102.tar.gz`
SHA-256: `69f245dd3bf11126157343e536166793ea4ba85eda1d4aef938bb8c6f57091bb`

## Measurement limits and sign-off impact

The Matrix benchmark uses a one-cycle behavioral bank response and a 10 ns simulation period. `effective_gops_250mhz` is normalized arithmetic using a 250 MHz reference; it is not measured Fmax, silicon throughput, or ASIC PPA. The Cluster timing uses the RTL behavioral scratchpad and the tested descriptor bundle; it is not a complete-system application benchmark or a TinyNPU comparison.

This adds reproducible benchmark evidence only. It does not close `REQ-CL-028`, the remaining fault/phase/reset/backpressure crosses, the 14 partial RTM rows, or `CL-DV-v1.0`. Sign-off remains **HOLD**.
