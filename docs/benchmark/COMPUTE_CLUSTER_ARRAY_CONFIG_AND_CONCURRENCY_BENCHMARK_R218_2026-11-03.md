# Compute Cluster Array, Configuration, and Concurrency Benchmark — R218

**Date:** 2026-11-03  
**RTL/UVM candidate SHA:** `09f9d31209fdcc803ec322cf3822bd51e763665a`  
**RTL/UVM tree:** `9778101254417c7272c37d8177e319e70849c8b4`  
**Run IDs:** `R218-MATRIX-SIZE-3S-20261103`; `R218-MATRIX-CONFIG-3S-20261103`; `R218-UVM-COMPUTE-CLUSTER-3S-20261103`; `R218-MIXED-AXI-SVA-E2E-20261103`; `R218-TOP-SMOKE-20261103`; `R218-TOP-RANDOM-20-20261103`  
**Tool:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`  
**Seeds:** `20261025`, `20261026`, `20261027` for Matrix and Compute Cluster; top random regression uses `AI_SEED=12345`.

This is measurement evidence on the fixed RTL/UVM candidate. It does not change the v1.0 requirement disposition: 24 `PASS-SCOPED`, 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Matrix physical array size

The Matrix core testbench ran five shapes on parameterized 4×4, 8×8, and 16×16 arrays. All 45 shape/array/seed points passed the independent Golden check. Cycle counts were identical across the three seeds.

| Workload M×N×K | 4×4 cycles | 8×8 cycles | 16×16 cycles | 16×16 MAC/cycle | 16×16 utilization | 16×16 SPAD read/write bytes |
|---|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99 | 99 | 99 | 5.172 | 2.02% | 256 / 64 |
| 8×8×32 | 407 | 135 | 135 | 15.170 | 5.93% | 512 / 256 |
| 16×16×32 | 1,600 | 562 | 265 | 30.913 | 12.08% | 1,024 / 1,024 |
| 16×32×32 | 3,169 | 1,086 | 504 | 32.508 | 12.70% | 2,048 / 2,048 |
| 32×32×64 | 12,273 | 4,063 | 1,698 | 38.596 | 15.08% | 8,192 / 4,096 |

The 4×4×32 case is setup and transfer dominated and shows no cycle benefit from increasing the physical array. The 16×16 array reaches 7.23× fewer cycles than 4×4 for 32×32×64, but this is a block-level result under the testbench memory schedule, not sustained application throughput.

Full per-seed measurements, including bank and line stalls, MAC/cycle, and normalized 250 MHz GOPS, are in [the array-size CSV](compute_cluster_matrix_array_size_r218.csv).

## Eight-configuration Matrix ablation

The fixed 16×16 array ran Depth 2/4 × Next-K Prefetch OFF/ON × A-Tile Cache OFF/ON over the same five workloads. All 120 configuration/shape/seed points passed their independent Golden checks; metrics were deterministic across the three seeds.

| Workload | D2/P0/C0 → D4/P1/C1 cycles | Speedup | Bank reads, baseline → best | Bank stalls, baseline → best | Line stalls, baseline → best |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 99 → 76 | 1.30× | 16 → 16 | 4 → 3 | 1 → 0 |
| 8×8×32 | 135 → 116 | 1.16× | 32 → 32 | 11 → 12 | 2 → 3 |
| 16×16×32 | 265 → 233 | 1.14× | 64 → 64 | 25 → 24 | 22 → 28 |
| 16×32×32 | 504 → 417 | 1.21× | 128 → 96 | 53 → 38 | 22 → 65 |
| 32×32×64 | 1,698 → 1,187 | 1.43× | 512 → 384 | 156 → 136 | 74 → 72 |

Across the five workloads, the cycle sum decreases from 2,701 to 2,029 per seed (24.88%). A-Tile Cache reduces bank reads by 25% on the two workloads that reuse A across multiple macro tiles; smaller shapes do not benefit from that reuse. The `16×32×32` case also raises Line stalls from 22 to 65 even as total cycles fall, so traffic and stall improvements do not move uniformly. This is shape-specific evidence, not a universal performance claim. The full eight-way comparison is in [the configuration CSV](compute_cluster_matrix_config_ablation_r218.csv); detailed per-configuration FSM and stall counters are in [the profile CSV](compute_cluster_matrix_config_profile_r218.csv).

## Real Compute Cluster task throughput

The production top UVM ran the same deterministic Matrix/CNM/SFU/SFU task bundle on three seeds. Cycles and SPAD traffic were identical across seeds. Timing is doorbell-to-completion-tail; descriptor programming is excluded.

| Mode | Workload | Cycles | Comparison | SPAD read/write bytes | Shared-SPAD contention |
|---|---|---:|---:|---:|---:|
| Serial | Matrix + CNM + SFU + queued SFU | 1,696 | Baseline | 4,352 / 2,688 | — |
| Parallel | Same four tasks, dispatched concurrently; ordered completion | 1,137 | 1.492× speedup | 4,352 / 2,688 | 38 cycles |
| Staged | Matrix + CNM, then one SFU | 1,070 | 1.158× vs three-task serial 1,239 | 4,032 / 2,416 | 32 cycles |
| Reset recovery | Active Matrix/SFU reset then recovery completion | 307 | Recovery latency | — | — |

All three seeds pass the real-seven-engine UVM sequence. Per-seed Memory Scoreboard checks 72,512 words with zero mismatch, unknown read, stale epoch, or orphan response; pending owner queues drain. Seven-engine pair overlap is 21/21, with maximum seven active engines. The scenario rows and scoreboard evidence are in [the concurrency CSV](compute_cluster_concurrency_r218.csv) and the archive below.

## Additional sign-off replay gates

- `uvm_compute_cluster_regress`: three seeds pass; UVM severity `0/0/0` per seed. The merged UVM-only URG reports 77.51% total group coverage; all 18 Compute Cluster groups are 100%. Five AXI memory-model groups are unhit, while the AXI4 and AXI-Lite groups are 50.28% and 87.50%. This is not 100% overall UVM/code coverage and does not close the 14 partial RTM rows.
- `uvm_mixed_precision_ddr_e2e_axi_stalls`: PASS, UVM `0/0/0`; memory image checks 152 words with zero mismatch/unknown/stale; AR/AW/W stall-to-accept SVA matches 14/5/12. This is a separate directed E2E run, not merged into the compute-only URG score above.
- `ai_smoke`: PASS, mapper precheck reports 86 descriptors and 60 tensors. The existing VCS `[LOOP-REROLL-ENABLED]` fixture warning remains.
- `ai_run AI_RANDOM_CASES=20 AI_SEED=12345`: PASS, 20 random cases.

## Reproduction commands

```sh
for seed in 20261025 20261026 20261027; do
  VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
    make -C dv/block/compute/matrix/sim matrix-size-benchmark \
    SEED=$seed OUTSTANDING_DEPTH=2 NEXT_K_PREFETCH_ENABLE=0 \
    A_TILE_CACHE_ENABLE=0 BENCH_OUT_DIR=/tmp/nmaforge_r218_matrix_size_$seed
done

for seed in 20261025 20261026 20261027; do
  VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
    make -C dv/block/compute/matrix/sim matrix-config-comparison \
    SEED=$seed MATRIX_CONFIG_OUT=/tmp/nmaforge_r218_matrix_config_$seed
done

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_RUN_STAMP=r218_20261103 \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r218_compute_cluster_20261103

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_axi_stalls

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/subsystem/top_smoke/sim ai_smoke

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The 4×4/8×8/16×16 array sweep and eight-configuration ablation were each run for all three listed seeds. The logs-only archive includes all 45 array runs and 120 ablation points, the three real-top Compute Cluster logs, the mixed AXI/SVA run, and both top-smoke runs. Archive: `/tmp/nmaforge_r218_evidence_20261103.tar.gz`, SHA-256 `4b022e8d7172fd143effff3cd175dc77b4d83ff54a6dc0dd4a341d48dbc18ac7`; 87 evidence files, manifest SHA-256 `0252f502bb539f315c2ed15ff1b948d6aa97dc583b3c0a5cedc24d0c91a71dd8`.

## Limits and sign-off impact

Matrix runs use a one-cycle behavioral bank response and 10 ns simulation period. `effective_gops_250mhz_normalized` is a normalization at an assumed 250 MHz, not a measured clock, Fmax, silicon throughput, or ASIC PPA. The real-top concurrency figures use the checked-in behavioral scratchpad and this task bundle. No TinyNPU same-resource run, system-level application benchmark, PPA, or complete sign-off closure is claimed.

The new benchmark points add reproducible evidence but do not change requirement status. Remaining legal fault/phase/reset/backpressure and response-contract gaps stay open; `CL-DV-v1.0` remains **HOLD**.
