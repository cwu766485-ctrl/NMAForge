# Compute Cluster Matrix Ablation and Real-Top Concurrency Benchmark — R226

**Date:** 2026-11-03
**Candidate tested:** `65a4b216c713ce2ac2b10c6d442247df29301d96`
**Candidate tree:** `d82639b22dff8b3c13295b5fe77cffcaae870412`
**Run IDs:** `CL-MATRIX-ABLATION-R226-20261103`; `CL-UVM-CLUSTER-CONCURRENCY-R226-20261103`
**Seeds:** `20261025`, `20261026`, `20261027`
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

This report records same-candidate reruns of the two requested benchmark families: the eight-way Matrix configuration ablation and real Compute Cluster serial/parallel/staged/recovery workloads. Both used the same fixed candidate and seed set. No RTL was changed in this run.

## Matrix configuration ablation

The 16×16 physical Matrix array was run against five legal GEMM shapes: 4×4×32, 8×8×32, 16×16×32, 16×32×32, and 32×32×64. The sweep varies Outstanding Read Depth (2/4), next-K Prefetch (OFF/ON), and A-Tile Cache (OFF/ON). Every shape/configuration/seed point passed the testbench's independent Golden check: **120/120 PASS**. Cycle counts match across all three seeds.

The following values are per seed, summed across the five shapes. SPAD read-byte counts, bank stalls, and output line stalls are measured by the Matrix RTL testbench.

| Depth / Prefetch / A-cache | Cycles | Change vs D2/OFF/OFF | SPAD read bytes | Bank stalls | Output line stalls |
|---|---:|---:|---:|---:|---:|
| D2 / OFF / OFF | 2,701 | baseline | 12,032 | 249 | 121 |
| D2 / OFF / ON | 2,415 | −10.59% | 9,472 | 201 | 116 |
| D2 / ON / OFF | 2,478 | −8.26% | 12,032 | 251 | 174 |
| D2 / ON / ON | 2,158 | −20.10% | 9,472 | 189 | 194 |
| D4 / OFF / OFF | 2,598 | −3.81% | 12,032 | 294 | 134 |
| D4 / OFF / ON | 2,329 | −13.77% | 9,472 | 221 | 138 |
| D4 / ON / OFF | 2,337 | −13.51% | 12,032 | 290 | 162 |
| D4 / ON / ON | **2,029** | **−24.88%** | **9,472** | 213 | 168 |

On this workload set, D4/P1/C1 has the lowest cycle sum. A-Tile Cache reduces total bank-read bytes by 21.3%; the reduction is 25% on the two multi-A-tile shapes (16×32×32 and 32×32×64), with no read-byte reduction on the other three. The best-cycle configuration also increases output line stalls versus baseline (168 vs 121 per seed), so the cycle improvement comes with a writeback-stall tradeoff. These results are specific to the tested shapes and memory model.

The per-point CSV includes cycles, MAC cycles, MAC/cycle, array utilization, SPAD bytes, bank/line stalls, and effective GOPS normalized at a 250 MHz reference: [R226 Matrix CSV](compute_cluster_matrix_ablation_r226.csv). The 250 MHz column is a normalization only; this run did not measure Fmax, silicon throughput, or ASIC PPA.

## Real Compute Cluster task throughput

The existing real-top UVM sequence runs the same workload bundle on each seed and checks task results, completion order, and memory/response ownership.

| Mode | Workload and comparison | Cycles | SPAD read / write bytes | Shared SPAD contention | Completion order |
|---|---|---:|---:|---:|---|
| Serial, three tasks | Matrix + CNM + SFU | 1,239 | 4,352 / 2,688 | — | `0600,0601,0602` |
| Serial, four tasks | Matrix + CNM + SFU + SFU | 1,696 | 4,352 / 2,688 | — | `0600,0601,0602,0603` |
| Parallel, four tasks | Same four tasks; compared with four-task serial | **1,137**; **1.492×** | 4,352 / 2,688 | 38 cycles | `0600,0601,0602,0603` |
| Staged, three tasks | Matrix + CNM overlap, then SFU; compared with three-task serial | **1,070**; **1.158×** | 4,032 / 2,416 | 32 cycles in Matrix/CNM phase | `0700,0701,0702` |
| Reset recovery | Active Matrix/SFU reset followed by fresh recovery completion | 307 | — | — | recovery task checked |

Each timing interval is doorbell-to-completion-tail; descriptor programming is excluded. The parallel case compares identical four-task work and preserves measured SPAD byte totals. The staged case is a three-task workload and is compared only with its 1,239-cycle three-task serial reference. The three seeds produced identical benchmark values.

### UVM checks and scope

- The seven-engine workload observed all **21/21** engine-pair overlaps and a maximum of seven active engines; independent output Golden and ordered-completion checks passed.
- Per seed, the memory scoreboard recorded 73,190 writes and checked 92,871 words, with zero mismatches, unknown reads, or stale-epoch responses. The response-owner ledger reported 5,015 accepted, 4,995 checked, 20 reset-dropped, zero routing/data/error mismatches, and zero pending responses.
- Focused applicable Compute Cluster coverage reported 100%. This is a scoped testpoint result, not global code, assertion, or requirement coverage. In this workload the memory scoreboard observed full-line WSTRB only (partial and zero WSTRB counts were zero).
- All three UVM runs ended with zero UVM warnings, errors, and fatals. The VCS compile log had no `Warning-`, `Error-`, or `TFIPC` diagnostics.

Machine-readable per-seed records are in [R226 Cluster CSV](compute_cluster_concurrency_r226.csv).

## Reproduction and evidence

Matrix ablation command:

```sh
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=$seed \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    MATRIX_CONFIG_OUT=/tmp/nmaforge_r226_matrix_configs_65a4b21/seed_$seed
done
```

Real-top Cluster UVM command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r226_cluster_uvm_65a4b21 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The archived logs, 24 Matrix run/compile logs, per-seed summaries, UVM compile and run logs, and merged URG group report are in `/tmp/nmaforge_r226_benchmark_evidence_20261103_complete.tar.gz` (SHA-256 `47e6df10aa8cef38bfd16191bbb60c72343226a74fc8411b25bf0e995fa10c7b`). The archive contains generated simulator evidence and is kept outside the repository; the report and CSVs are the checked-in summary artifacts.

## Limits and sign-off impact

Matrix uses a one-cycle behavioral SPAD response and 10 ns simulation period. Cluster measurements use the RTL behavioral scratchpad and the listed task bundle. Neither is a common-memory TinyNPU comparison, a production SRAM timing result, or ASIC PPA. No 250 MHz timing closure, area, power, or energy claim is made.

R226 adds reproducible benchmark evidence to `REQ-CL-028` but does not close it. Common-memory TinyNPU comparison, GEMV/decode, broader workloads, candidate ASIC PPA, and the 14 partial Execution RTM requirements remain open. The 38-row RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
