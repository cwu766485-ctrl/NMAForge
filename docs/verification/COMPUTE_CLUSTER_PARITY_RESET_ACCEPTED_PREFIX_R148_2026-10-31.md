# Compute Cluster parity reset after CNM accepted-write prefix — R148

**Date:** 2026-10-31  
**Executed test SHA:** `ef16a2e9d7fa0dd4a3962a43f06ee1672893f7ee`  
**Executed test tree:** `50b5ac8dc613adcee7dee31623b65141f274aa44`  
**Product RTL/SPEC identity:** unchanged from `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`  
**Tool:** Synopsys VCS/URG `V-2023.12-SP1_Full64`

## Testpoint

`TC-CL-R148-MATRIX-PARITY-CNM-RESET-WRITE-PREFIX` extends the R147 real-top Matrix/CNM shared-reset test to cover a legally committed output prefix. It dispatches a 16×32×16 Matrix GEMM and a 16-output CNM GEMV on the real CMDQ and shared scratchpad. Matrix A parity is faulted at the final A-row address. The sequence asserts shared reset only after Matrix has consumed `ERR_PARITY=0x52`, CNM has committed between 1 and 15 accepted output writes, and registered CNM responses remain pending.

The checker compares every accepted CNM write against an independent signed Golden result, checks the complete destination image so the unwritten suffix remains sentinel data, verifies old-epoch completion/response suppression, and replays both tasks to full Golden outputs and ordered completions. The UVM Make target now requires the accepted prefix, pending response, reset/release checks, recovery result, and explicit functional coverage marker; a run with zero prefix or a completed CNM task fails.

## Three-seed results

| Run ID | Seed | CNM outputs accepted before reset | CNM reads accepted / returned | Reset-dropped reads | Scoreboard words | UVM warning/error/fatal |
|---|---:|---:|---:|---:|---:|---:|
| `R148-UVM-MATRIX-PARITY-CNM-RESET-PREFIX-3S-20261031` | 20261025 | 4/16 | 1112 / 1104 | 8 | 57,960 | 0 / 0 / 0 |
| same | 20261026 | 4/16 | 1112 / 1104 | 8 | 57,960 | 0 / 0 / 0 |
| same | 20261027 | 4/16 | 1112 / 1104 | 8 | 57,960 | 0 / 0 / 0 |

For each seed, all four committed words match the independent Golden, the remaining twelve destination words match their untouched sentinels, and the post-reset replay checks the complete 16-word CNM image and 512-word Matrix image. The old epoch publishes neither task completion nor any later response/write side effect; the new epoch retires Matrix and CNM completions in order. The full scoreboard has zero mismatch, unknown, stale-epoch, and orphan-response events and ends with empty pending ledgers.

`matrix_cnm_prefix_reset_cg` measures five ordered legal phases: nonempty Golden prefix with a pending response, reset quiet window, release quiet window, prefix/suffix image preservation, and full Golden recovery. Each bin hits once per seed; merged URG shows **5/5 bins (100.00%)**, with three hits per bin. This is coverage of the named testpoint, not global closure.

Merged mixed URG raw coverage is SCORE `58.77%`, line `69.34%`, condition `63.60%`, FSM `44.12%`, branch `59.76%`, assertion `72.00%`. The declared `cluster_cg` remains 100% within its scope. The two UVM RAL assertion properties have no attempts; three AXI AR/AW properties in this compute profile have attempts but no real success. These limitations remain open review items.

## Fixed-source replay

| Run ID | Command | Result |
|---|---|---|
| `R148-MUTATION-28-20261031` | `make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r148_mutation COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r148_mutation_cases` | **28/28** passive-observation mutations caught by the expected checkers: Address, Data, Owner, WSTRB, completion error code, write-after-error, response epoch, and Done/Missing-Done/Duplicate-Done on all seven engines |
| `R148-TOP-SMOKE-20261031` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025 SEED=20261025` | `TEST PASS`; existing `LOOP-REROLL-ENABLED` fixture warning remains |
| `R148-TOP-20-20261031` | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026` | `TEST PASS` |

The mutations alter the passive observation copy and test checker sensitivity; they are not DUT RTL fault injection. Product RTL and SPEC did not change.

## Commands and archive

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r148_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r148_mutation \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r148_mutation_cases

make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025 SEED=20261025
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026
```

Logs and merged URG summaries are archived at `/tmp/nmaforge_r148_evidence.tar.gz`, SHA-256 `0c303cd2f5becea42bbff1c8a49af92f810ba3674bbd99badfd24d4463d154bb`. The archive contains the complete three-seed UVM transcript, URG dashboard/group/assertion summaries, all 28 mutation logs, Top Smoke and seeded-top logs, and a command/result manifest; VDBs and generated simulator directories are excluded.

## Disposition

R148 closes the named parity-reset-after-CNM-accepted-write-prefix functional testpoint. `REQ-CL-018/019` and `REQ-PC-006/007` remain `PARTIAL` because this is one fault/phase/engine pairing and does not close the broader legal requester, fault, reset, accepted-prefix, or backpressure matrix. The 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
