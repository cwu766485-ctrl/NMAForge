# Compute Cluster parity reset phase cross — R145

**Run ID:** `R145-PARITY-RESET-PHASE-CROSS-3S-20261031`  
**Executed code/test SHA:** `b835350624bd5f8ca5ebd1c985a1483a63be39a8`  
**Tree:** `34c5328f992c1112c19b84fbc7f40a560026fc63`  
**Product RTL/SPEC:** unchanged from R99 product baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8.

## Added legal testpoints

R145 extends the seven-engine parity/read-reset test from reset before response consumption to both sides of the response-consume edge. For each of seven production compute engines, it tests source A; it also tests source B for the five engines with a defined second operand (Scalar INT8, BF16, CNM, Matrix and Conv). For each legal engine/operand combination, one case asserts reset after the accepted read and before response consumption, and one asserts reset immediately after the engine samples the parity response. This yields 12 cases per phase and 24 per seed.

The passive UVM interface observes the real per-engine parity response: shared-core response mux for Scalar/BF16/SFU/Conv/KV, Matrix's banked response fault, and CNM's per-lane parity response. The sequence requires the target engine to be busy on the sampling edge, asserts reset one nanosecond after it, verifies response/error suppression and preserved destination/completion sentinels, then reissues the descriptor and checks its task ID and success status. The pre-consume path is retained as a separate required 12/12 marker.

The recovery reissue checks completion identity and status, not a per-case numeric Golden. The same three-seed full regression also runs the independent seven-engine numeric Golden sweep (21/21 engine pairs); R145 does not claim new numeric coverage for each parity-recovery reissue. Product RTL and SPEC were not changed.

## Verification results

VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r145_parity_reset_3s \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The exact-source three-seed regression passes. Each seed reports 12/12 pre-consume and 12/12 consumed-response cases, 24 case-pass markers total, focused applicable compute coverage 100.0%, UVM severity `0/0/0`, and 46,368 checked memory words with zero mismatch/unknown/stale/orphan. Empty pending response ledgers and the independent full seven-engine Golden sweep also pass.

The merged mixed-hierarchy URG dashboard reports SCORE 56.42% (LINE 69.34%, COND 63.60%, FSM 44.12%, BRANCH 59.76%, ASSERT 72.00%, GROUP 29.72%). The focused 100.0% number applies only to the declared applicable compute group; the raw aggregate is not a sign-off closure percentage.

The same test SHA passes the passive checker-sensitivity campaign:

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r145_parity_reset_3s \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r145_mutations
```

All 28 mutations are caught by their assigned checker: Address, Data, Owner, WSTRB, Completion Error Code, Write After Error, Response Epoch, and Done/Missing Done/Duplicate Done for all seven engines. Each run has one injection record, one expected checker-catch record, and a nonzero UVM error count. This is passive checker-sensitivity evidence, not an RTL mutation score.

Top Smoke (`make ai_smoke`) and the 20-case Top regression (`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`) pass at the same source content; the mapper reports 86 descriptors and 60 tensors.

## Requirement disposition

R145 adds evidence to `REQ-CL-017`, `REQ-CL-018`, `REQ-CL-019`, `REQ-CL-027`, `REQ-PC-006` and `REQ-PC-007`. These remain `PARTIAL`: non-parity faults, accepted-write phases, simultaneous production-engine contention, and broader backpressure/error-completion combinations remain open. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Reproducibility artifacts

Per-seed logs and coverage databases are under `/tmp/nmaforge_r145_parity_reset_3s/seed_<seed>/`; mutation logs and databases are under `/tmp/nmaforge_r145_mutations/`. The 28-row checker result table is `/tmp/nmaforge_r145_mutation_summary.csv`. The portable evidence archive `/tmp/nmaforge_r145_evidence.tar.gz` contains the compile and run logs, coverage databases, merged URG dashboard, Top Smoke/seeded Top logs and mutation evidence. Archive SHA-256: `bd217fd8b689c026b19b6810a3112289f8df0c8f19277669fc4554ced930e67d`; internal `SHA256SUMS` SHA-256: `19351ad3e58dcf709728e77992fc47406078cad0c04e46d277368e7f116f60ae`.
