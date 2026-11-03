# Compute Cluster Actual RTL Mutation Campaign — R246

**Result: PASS, 7/7 targeted RTL mutants detected.** The campaign ran against the exact published closeout `main` source and test tree, commit `269c2a0de8cf226dd01c3f86c05e180908252b04`, tree `61e365cc5a37998c0bf2688981cbb89f278eace2`, from a detached clean worktree. Tool: Synopsys VCS `V-2023.12-SP1_Full64`; seed `20261025`.

## Command

```sh
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r246_dut_mutation_269c2a0
```

The existing runner makes a temporary source copy for each mutation, applies an exact single-site replacement, compiles the mutated design, runs `ai_compute_cluster_e2e_test`, and requires the expected Checker ID in the log. It also rejects a normal Compute Cluster PASS marker. Product RTL in the clean worktree was not modified. All seven mutant compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

## Results

| Injected RTL fault | Expected Checker observed | Notes |
|---|---|---|
| SPAD address offset | `CLUSTER_MEMORY_UNKNOWN` | A later scalar Golden mismatch also occurs; the runner accepts the configured `MEMORY_UNKNOWN` or `GOLDEN` class. |
| SPAD write-data bit flip | `CLUSTER_GOLDEN` | Golden detects the corrupted stored value. |
| Response routed to next engine | `CLUSTER_ENGINE_RESPONSE_OWNER` | Owner ledger reports expected and actual engine masks. |
| Matrix line WSTRB bit cleared | `CLUSTER_MATRIX_WSTRB` | 128 line-mask violations precede the expected Golden failure. |
| Completion error code changed | `CLUSTER_COMPLETION_ERROR_CODE` | Recovery status mismatch is reported. |
| Scalar Done suppressed | `CLUSTER_MISSING_DONE` | The later completion timeout is a consequence of the injected missing Done. |
| Duplicate Scalar Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | Expected lifecycle checker fires; an additional run-level SVA failure appears later in this mutated run. |

## Evidence and disposition

Logs-only archive: `/tmp/nmaforge_r246_mutation_evidence_20261103.tar.gz`; SHA-256 `6a1f8f19078135b86b8a695ac1a951fe0b259cdd7acb8ce2d827ce9ed55b6a8b`. It contains per-mutant compile/run logs, the checker summary, manifest, and file checksums; generated VCS databases are excluded.

This proves sensitivity for these seven injected faults on the selected published tree. It does not claim a global mutation score, close the legal Engine × Fault × Phase × Reset × Backpressure space, or change any Requirement disposition. The 38-row RTM remains **24 PASS-SCOPED / 14 PARTIAL** and `CL-DV-v1.0` remains **HOLD**.
