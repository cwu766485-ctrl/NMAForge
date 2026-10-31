# Compute Cluster Matrix/CNM parity reset-owner cross — R146

**Date:** 2026-10-31  
**Code/test SHA:** `1691b0368a57ac28ba247858452f6fa38fbc5b37`  
**Code/test tree:** `5cd73120a877d1b9c2babe55837508bece9e90c0`  
**Product RTL/SPEC identity:** unchanged from `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`  
**Scope:** a real-top Matrix parity response coincident with concurrent CNM work through the shared scratchpad, followed by shared reset and Golden recovery.

## Testpoint and result

Test ID `TC-CL-R146-MATRIX-PARITY-CNM-RESET` extends the real-engine Matrix/CNM owner cross. The sequence dispatches CNM GEMV and Matrix GEMM, injects parity on Matrix A, and asserts global reset immediately after Matrix samples the registered parity response while CNM still has accepted reads awaiting responses. It checks response-owner activity and shared-bank admission before reset, quiet response signals while reset is held and after release, no old-epoch completion or output side effect, and full Golden recovery with ordered new-epoch completions.

| Run ID | Seed | CNM reads accepted / returned at reset | Reset-dropped reads | Recovery | UVM severity |
|---|---:|---:|---:|---|---|
| `R146-UVM-20261025` | 20261025 | 152 / 144 | 8 | Matrix and CNM full Golden images; ordered completions | 0 / 0 / 0 |
| `R146-UVM-20261026` | 20261026 | 152 / 144 | 8 | Matrix and CNM full Golden images; ordered completions | 0 / 0 / 0 |
| `R146-UVM-20261027` | 20261027 | 152 / 144 | 8 | Matrix and CNM full Golden images; ordered completions | 0 / 0 / 0 |

Each run also checks that no completion is published from the interrupted epoch, completion sentinels and the Matrix output image remain unchanged, all engines drain, and response routing has no mismatch. The CNM had accepted no output write when reset asserted (`0/16` prefix); its destination remained untouched. On replay, all 16 CNM outputs and all 512 Matrix outputs match independently computed Golden data.

The memory scoreboard reports 51,444 checked words per seed, zero mismatch, zero unknown reads, zero stale-epoch accesses, zero orphan responses, and empty pending response ledgers. The declared focused compute covergroup reports `100.0%` on each run. This is the existing focused group score; the new reset cross itself is evidenced by its required PASS marker on all three seeds, not by claiming all design coverage is 100%.

## Commands and evidence

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r146_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r146_mutation \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r146_mutation_cases

make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025 SEED=20261025
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026
```

All commands exit successfully. The UVM/URG run uses Synopsys VCS and URG `V-2023.12-SP1_Full64`; its merged raw metrics are line/condition/FSM/branch/assert/group `69.34/63.60/44.12/59.76/72.00/29.72%`. There are 17 real assertion successes, zero failures/incomplete, two UVM RAL properties without attempts, and three AXI AR/AW properties with attempts but no matches in this compute workload. These raw metrics are separate from the 100% declared focused functional group.

The checker-sensitivity campaign catches `28/28` injected monitor-observation mutations: address, data, response owner, WSTRB, completion error code, write-after-error, response epoch, and done/missing-done/duplicate-done on all seven engines. These mutations alter only the passive observation copy; they are not DUT RTL fault injections.

Top Smoke prints `TEST PASS` after the 86-descriptor mapper precheck. The seeded 20-case Top run also prints `TEST PASS`. Top Smoke retains the existing `LOOP-REROLL-ENABLED` fixture debug warning.

Text logs and the merged URG summary are archived at `/tmp/nmaforge_r146_evidence.tar.gz`, SHA-256 `b2a79a4976ffc33fdcdb574d6a9beee53a64af05a9dee722571618a93d56f362`. The per-seed VDBs and complete URG report remain under `/tmp/nmaforge_r146_regress/`; the 28 mutation logs remain under `/tmp/nmaforge_r146_mutation_cases/`.

## Disposition

This closes the named Matrix-parity/CNM-pending-read shared-reset testpoint for the tested descriptors and three seeds. It adds scoped evidence to `REQ-CL-018/019` and `REQ-PC-006/007`; those requirements remain `PARTIAL` because the full legal engine × fault × phase × reset and requester × backpressure spaces are not closed. The independently selected in-repository `ai_accel_memory_fabric` reset target remains the bounded target documented by R142/R125; this R146 test adds production Matrix/CNM concurrency above that fabric.

No product RTL or SPEC changed. The 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
