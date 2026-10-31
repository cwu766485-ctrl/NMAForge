# Compute Cluster parity fault and reset cross — R143

**Date:** 2026-10-31  
**Run ID:** `R143-PARITY-RESET-CROSS-3S-20261031`  
**Executed code/test SHA:** `4008d73f800fd470ed2ff8b9c4f7068053d5b041`  
**Tree:** `42e81651746a6f42c53b1020583f990228d87f94`  
**Product RTL/SPEC:** unchanged from R99 product baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8.

## Testpoint added

R143 crosses a real accepted parity-faulted SPAD operand read with top reset for all seven production compute engines. It covers operand A for all seven engines and operand B for the five engines that define a second source (Scalar INT8, BF16, CNM, Matrix and Conv), for 12 legal cases per seed. Each case asserts reset one nanosecond after the accepted-read edge, before the registered fault response is consumed. The sequence checks response suppression through reset and release, no completion-tail advance, preserved destination and completion sentinels, then reissues the repaired descriptor and checks the recovery task ID and success status.

This adds accepted-read-to-reset parity cases. Matrix's separate R141/R142 tests cover reset on either side of the response-consume edge. The R143 recovery reissue checks retirement/status; the existing all-engine functional sweep in the same test still supplies the independent numeric Golden checks. R143 does not claim numerical Golden checks for each individual recovery reissue.

## Verification results

VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r143_parity_reset_3s \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The regression passed all three seeds. Each reports 12/12 R143 cases, focused applicable `cluster_cg` coverage 100.0%, UVM severity `0/0/0`, 45,617 checked memory words, zero mismatch/unknown/stale/orphan, and empty pending response ledgers. Each existing full-sequence seven-engine numeric Golden sweep also passes 21/21 engine pairs.

The merged URG dashboard for the three-seed run reports mixed-hierarchy SCORE 56.33% (LINE 69.34%, COND 63.60%, FSM 43.57%, BRANCH 59.76%, ASSERT 72.00%, GROUP 29.72%). These are raw aggregate code and covergroup metrics, including infrastructure and unrelated scopes; they are not functional requirement closure. The 100.0% figure applies only to the focused applicable compute group printed by the test.

Top-level checks at the same local source SHA:

```sh
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both pass; the mapper reports 86 descriptors and 60 tensors. The Top Smoke test ends `TEST PASS`.

The exact-source passive checker-sensitivity campaign passed 28/28 at the same test SHA:

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r143_parity_reset_3s \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r143_mutations
```

It injects Address, Data, Owner, WSTRB, Completion Error Code, Write After Error, and Response Epoch mutations, plus `done`, `missing_done`, and `duplicate_done` for each of the seven engine bits. Every run emits exactly one injection record, one expected checker catch, and at least one UVM error. Expected checkers are `matrix_request_address`, `memory_data`, `response_owner_route`, `matrix_write_mask`, `completion_error_code`, `write_after_error_prefix`, `response_epoch`, and `engine_done_lifecycle`. This is passive checker-sensitivity evidence, not a DUT RTL mutation score.

## Requirement disposition

The new points add evidence to `REQ-CL-017`, `REQ-CL-018`, `REQ-CL-019`, `REQ-CL-027`, `REQ-PC-006`, and `REQ-PC-007`. All remain `PARTIAL`: the test covers parity reset before response consumption, not all fault classes, accepted-write phases, response-consumed phases for every engine, or the full production requester/backpressure matrix. Overall status remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Reproducibility evidence

Per-seed logs and coverage databases are under `/tmp/nmaforge_r143_parity_reset_3s/seed_<seed>/`; mutation logs and databases are under `/tmp/nmaforge_r143_mutations/`. The checker outcome CSV is `/tmp/nmaforge_r143_mutation_summary.csv`. A portable evidence bundle containing the compile log, three run logs, coverage databases, merged URG dashboard, Top Smoke and 20-case seeded Top logs, and all 28 mutation logs is `/tmp/nmaforge_r143_evidence.tar.gz` (SHA-256 `ea0a2b62ded979f2e7fab30dfc77cd9f41dbb8216a602a0b6c324c36f1a41a49`). Its internal `SHA256SUMS` digest is `e15408b1b8644cd0230b0e51b00f923ce4428be749ef031386b6ac215d97aabd`.
