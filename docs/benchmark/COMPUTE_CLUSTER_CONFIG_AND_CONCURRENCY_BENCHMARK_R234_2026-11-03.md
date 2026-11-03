# Compute Cluster Fixed-Candidate Benchmark Replay — R234

**Date:** 2026-11-03
**Published replay HEAD:** `3259d4da158d56aebe41c227c426b6b4b74a0f72`
**RTL/DV source identity:** `c5755985b0e5b1e1a850122ece983a37be112272`; `rtl/`, `dv/`, and `docs/spec/` are unchanged between that source/test SHA and the published replay HEAD.
**Run IDs:** `R234-MATRIX-CONFIG-3S-20261103`; `R232-PUB3259-CLUSTER-UVM-3S-20261103`
**Seeds:** `20261025`, `20261026`, `20261027`
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

This replay binds the eight-way Matrix configuration ablation and the real-top Cluster serial/staged/parallel/recovery measurements to the same executable RTL/DV source identity. It changes no product or test source.

## Matrix shape and configuration ablation

The physical array remains 16×16. Five legal signed INT8 GEMM shapes (4×4×32, 8×8×32, 16×16×32, 16×32×32, and 32×32×64) run in each of eight configurations: Outstanding Read Depth 2/4 × next-K Prefetch OFF/ON × A-Tile Cache OFF/ON. Each shape's output is compared with the independent testbench Golden.

**120/120 shape/configuration/seed Golden points pass.** The cycle, MAC/cycle, utilization, bank traffic, bank-stall, and output-line-stall values are identical across all three seeds. Totals below are per seed across the five shapes; aggregate MAC/cycle and PE utilization are calculated from the total 92,672 INT8 MACs divided by summed measured cycles.

| Depth / Prefetch / A-cache | Cycles | Change vs D2/P0/C0 | Aggregate MAC/cycle | Aggregate PE utilization | SPAD read bytes | Bank stalls | Output-line stalls |
|---|---:|---:|---:|---:|---:|---:|---:|
| D2 / OFF / OFF | 2,701 | baseline | 34.31 | 13.40% | 12,032 | 249 | 121 |
| D2 / OFF / ON | 2,415 | −10.59% | 38.37 | 14.99% | 9,472 | 201 | 116 |
| D2 / ON / OFF | 2,478 | −8.26% | 37.40 | 14.61% | 12,032 | 251 | 174 |
| D2 / ON / ON | 2,158 | −20.10% | 42.94 | 16.77% | 9,472 | 189 | 194 |
| D4 / OFF / OFF | 2,598 | −3.81% | 35.67 | 13.93% | 12,032 | 294 | 134 |
| D4 / OFF / ON | 2,329 | −13.77% | 39.79 | 15.54% | 9,472 | 221 | 138 |
| D4 / ON / OFF | 2,337 | −13.51% | 39.65 | 15.49% | 12,032 | 290 | 162 |
| D4 / ON / ON | **2,029** | **−24.88%** | **45.67** | **17.84%** | **9,472** | 213 | 168 |

For this workload, D4/P1/C1 is the lowest-cycle configuration. A-Tile Cache reduces total bank-read bytes by 21.3%, and by 25% on the two multi-A-tile shapes. The best-cycle case incurs more output-line stalls than the baseline (168 versus 121), so the cycle change includes a writeback-stall trade-off. These are behavioral RTL measurements under a one-cycle SPAD response.

The point-level records, including per-shape cycles, MAC/cycle, utilization, read/write bytes, and both stall counts, are in [R234 Matrix CSV](compute_cluster_matrix_ablation_r234.csv).

## Real Compute Cluster throughput

The published-head three-seed UVM run reports identical real-top results on all seeds. Timings are doorbell-to-completion-tail; descriptor programming is excluded.

| Mode | Workload | Cycles | SPAD read / write bytes | Shared-SPAD contention | Speedup comparison |
|---|---|---:|---:|---:|---|
| Serial, three tasks | Matrix + CNM + SFU | 1,239 | 4,352 / 2,688 | — | baseline |
| Serial, four tasks | Matrix + CNM + SFU + SFU | 1,696 | 4,352 / 2,688 | — | baseline |
| Staged, three tasks | Matrix + CNM overlap, then SFU | 1,070 | 4,032 / 2,416 | 32 cycles | 1.158× vs three-task serial |
| Parallel, four tasks | Same four tasks as serial | 1,137 | 4,352 / 2,688 | 38 cycles | 1.492× vs four-task serial |
| Reset recovery | Active Matrix/SFU reset then fresh completion | 307 | — | — | recovery interval |

The per-seed records and completion order are in [R234 Cluster CSV](compute_cluster_concurrency_r234.csv). The UVM scoreboard and response-owner checks passed in all three runs with zero UVM warning/error/fatal, zero memory mismatch/unknown/stale response, and no pending response owner.

## Reproduction and build notes

Matrix command:

```sh
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
    SEED=$seed \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    MATRIX_CONFIG_OUT=/tmp/nmaforge_r234_matrix_configs_c575_20261103/seed_$seed
done
```

The real-top Cluster run is recorded in the [R232 published-head replay report](../verification/COMPUTE_CLUSTER_PUBLISHED_HEAD_CLEAN_REPLAY_R232_2026-11-03.md). The Matrix Make gate passed for all 24 configuration/seed runs. One initial VCS-generated `filelist.cu` caused a GNU Make clock-skew warning of approximately 0.24 seconds; compilation, linking, and the test gate completed. The exact D2/P0/C0 seed-20261025 configuration was rerun after the shared generated compile state settled; all five case metrics matched, with no clock-skew warning. No VCS `Warning-`, `Error-`, or `TFIPC` diagnostics were found in the Matrix compile/run logs.

Text logs, the per-seed config summaries, point-level CSVs, and a SHA-256 manifest are archived at `/tmp/nmaforge_r234_benchmark_evidence_v2_20261103.tar.gz`, SHA-256 `8acce508b0fb45cd3ad1a6a23b5519a42d14d5649a1ad5ec6f7808905b01dc5c`. No VCS binaries, generated `csrc`, waveforms, or coverage databases are included.

## Measurement limits and sign-off status

The Matrix test uses a one-cycle behavioral SPAD response and a 10 ns simulation period. The Cluster measurements use the behavioral scratchpad and the specific task bundles above. `effective_gops_at_250mhz` in the CSV is a normalization of simulated cycles only; this run did not measure Fmax, silicon throughput, area, power, or ASIC PPA. No common-memory TinyNPU or GEMV/decode comparison was run here.

This refreshes `REQ-CL-028` with the current executable RTL/DV identity but does not close it. Common-memory TinyNPU fairness, GEMV/decode workloads, broader model workloads, and physical PPA remain open. Overall RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
