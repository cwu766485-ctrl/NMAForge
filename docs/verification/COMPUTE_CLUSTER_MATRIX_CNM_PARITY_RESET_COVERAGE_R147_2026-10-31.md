# Compute Cluster Matrix/CNM parity reset functional coverage — R147

**Date:** 2026-10-31  
**Executed test SHA:** `ea7007328009614213550ebe18dae5f6021e445e`  
**Executed test tree:** `c8ea2923f5b93f1fa150c92f45921d4c687a349d`  
**Product RTL/SPEC identity:** unchanged from `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`  
**Tool:** Synopsys VCS/URG `V-2023.12-SP1_Full64`

## Scope

R147 adds an explicit functional covergroup to the R146 real-top Matrix/CNM parity-reset scenario. The scenario starts a legal Matrix GEMM and CNM GEMV through the command queue and shared scratchpad, faults Matrix operand-A parity, then asserts accelerator reset immediately after Matrix consumes `ERR_PARITY=0x52` while CNM has registered reads still pending. It checks reset and post-release quiet intervals, suppresses both interrupted-epoch tasks, and verifies full Matrix/CNM Golden recovery with ordered completions.

`TC-CL-R147-MATRIX-CNM-PARITY-RESET-COVERAGE` has four directed legal phase bins. The sequence samples a phase only after its associated checker condition passes; the Make regression requires the explicit 4/4 coverage marker.

| Functional bin | Checker condition | Hits across merged seeds |
|---|---|---:|
| `parity_with_cnm_reads_pending` | Matrix sampled parity response while CNM accepted reads were outstanding | 3 |
| `reset_quiet_window` | All engines idle and old-epoch responses suppressed while reset is held | 3 |
| `release_quiet_window` | No stale response/owner activity after reset release | 3 |
| `full_golden_recovery` | Full Matrix/CNM memory images match independent Golden; ordered completions retire | 3 |

URG reports the named covergroup as **4/4 bins, 100.00%**. This is the coverage result for this testpoint only; it does not represent total Compute Cluster coverage.

## Three-seed results

| Run ID | Seed | CNM reads accepted / returned at reset | Dropped by reset | Scoreboard words | UVM warning/error/fatal | Result |
|---|---:|---:|---:|---:|---:|---|
| `R147-UVM-MATRIX-CNM-PARITY-RESET-COVERAGE-3S-20261031` | 20261025 | 152 / 144 | 8 | 51,444 | 0 / 0 / 0 | PASS |
| same | 20261026 | 152 / 144 | 8 | 51,444 | 0 / 0 / 0 | PASS |
| same | 20261027 | 152 / 144 | 8 | 51,444 | 0 / 0 / 0 | PASS |

For every seed, the incomplete-epoch completion/output sentinels remain unchanged, no stale response or completion escapes, pending response ledgers drain, and the subsequent Matrix/CNM tasks match their full Golden images. The interrupted CNM had accepted no output write when reset asserted (`0/16` prefix).

The merged URG mixed-hierarchy raw summary is SCORE `57.72%`, line `69.34%`, condition `63.60%`, FSM `44.12%`, branch `59.76%`, assertion `72.00%`. The existing declared `cluster_cg` is 100% within its scope. URG also reports two UVM RAL assertion properties without attempts and three AXI AR/AW properties with attempts but no real success; the checked assertions have no failures or incomplete attempts. These residuals remain review items; the reset covergroup does not close them.

## Exact-source checker and top replay

| Run ID | Command | Result |
|---|---|---|
| `R147-MUTATION-28-20261031` | `make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r147_mutation COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r147_mutation_cases` | **28/28** passive-observation checker-sensitivity mutations caught by the expected checker, including Address, Data, Owner, WSTRB, completion error code, write-after-error, response epoch, and Done/Missing-Done/Duplicate-Done for all seven engines |
| `R147-TOP-SMOKE-20261031` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025 SEED=20261025` | `TEST PASS`; existing `LOOP-REROLL-ENABLED` fixture warning remains |
| `R147-TOP-20-20261031` | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026` | `TEST PASS` |

The mutations alter the passive observation copy and validate checker sensitivity; they are not DUT RTL fault injection. Product RTL and SPEC did not change in R147.

## Commands and evidence archive

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r147_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r147_mutation \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r147_mutation_cases

make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025 SEED=20261025
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026
```

The text-log and URG-summary archive is `/tmp/nmaforge_r147_evidence.tar.gz`, SHA-256 `64914863803282fafb21bd2598236db86fc4914e8bf81f0c8b87d7e49a5e76ca`. It includes the three-seed UVM transcript, merged URG dashboard/groups/assertion summaries, all 28 mutation logs, both top-level logs, and a command/result manifest. VDBs and generated simulator directories are excluded.

## Disposition

R147 closes the named Matrix-parity/CNM-pending-read shared-reset functional coverage point at 4/4 legal bins. It does not close the broader Engine × Fault × Phase × Reset or requester × response-backpressure spaces. `REQ-CL-018/019` and `REQ-PC-006/007` remain `PARTIAL`; the 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The overall mixed URG score is not a sign-off metric and remains below full coverage.
