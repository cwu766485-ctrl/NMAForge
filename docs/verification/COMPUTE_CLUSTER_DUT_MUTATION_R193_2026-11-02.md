# Compute Cluster real-DUT mutation and clean regression — R193

**Run IDs:** `R193-COMPUTE-CLUSTER-UVM-CLEAN-3S-20261102` and `R193-REAL-DUT-MUTATION-5-20261102`  
**Fixed candidate:** commit `0225e1a73e2265cc72907b905947fdcea8b3f76e`, tree `e0937ebd0b89018722fe12c1b15ddd332d9d7051`  
**Checkout:** detached clean worktree `/tmp/nmaforge_r193_clean_0225e1a`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, UVM 1.2

## Clean fixed-SHA UVM regression

Command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r193_clean_regression_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

All three seeds pass with UVM warning/error/fatal counts `0/0/0`. Each run checks 69,656 Memory Image words with zero mismatch, unknown read, stale epoch, or orphan. The new real response-owner ledger reports:

```text
accepted=2847 checked=2828 reset_dropped=19
route_mismatch=0 data_mismatch=0 error_mismatch=0 pending=0
```

The scoreboard records the accepted engine owner for each 32-bit Core read and checks the actual DUT response mux's valid, owner, data, and error against the accepted arbiter response. Reset-dropped accepted requests are accounted separately. This is a Core response-route checker; it does not claim complete concurrent seven-engine/fault/reset/backpressure closure.

The UVM compile log has no `Warning-`, `Error-`, or `TFIPC` diagnostics.

## Real RTL mutation campaign

Command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r193_clean_mutants
```

The target makes temporary copies of the named RTL modules under `/tmp`, compiles each mutant with the real Compute Cluster UVM environment, and requires the assigned checker to fire before the normal PASS marker. All five targeted mutants were detected:

| Mutated behavior | Temporary RTL source | Expected checker | Observed result |
|---|---|---|---|
| SPAD request address shifted by 4 bytes | `ai_compute_spad_mux.v` | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| SPAD write data bit flipped | `ai_compute_spad_mux.v` | `CLUSTER_GOLDEN` | Caught |
| Response valid/data/error routed to next engine | `ai_compute_spad_mux.v` | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix Line WSTRB bit cleared | `ai_tensor_matrix_core.v` | `CLUSTER_MATRIX_WSTRB` | Caught |
| Successful completion error code changed to 1 | `ai_parallel_compute_dispatcher.v` | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |

Result: `5/5` real RTL mutants caught. These are targeted checker-sensitivity results; they do not establish fault-mode functional coverage and do not complete the broader mutation campaign. Product RTL was not changed to inject any mutant.

## Requirement traceability impact

| Requirement | Status | Test / checker | Result and scope | Run ID / seeds | Evidence |
|---|---|---|---|---|---|
| `REQ-PC-006` | PARTIAL | `TC-CL-R193-REAL-ENGINE-RESPONSE-OWNER`; accepted-read owner ledger, actual response mux valid/data/error checker, memory scoreboard | 2,847 accepted reads, 2,828 responses checked, 19 reset drops accounted, zero route/data/error mismatches, no pending responses; does not cover every client/fault/backpressure/reset combination. | `R193-COMPUTE-CLUSTER-UVM-CLEAN-3S-20261102`; seeds `20261025/26/27` | `/tmp/nmaforge_r193_clean_regression_3seed/seed_*/run.log`; archive below |
| `REQ-PC-007` | PARTIAL | Same test; production compute response mux and per-request engine owner ledger | Actual response destination ownership is checked across the clean seven-engine workload. Simultaneous production-engine owner conflicts under the full fault/backpressure/reset matrix remain open. | Same run and seeds | Same report and archive |

The five injected defects additionally exercise address, data, response-owner, WSTRB, and completion-error checkers. That mutation result does not promote the 38-row RTM or imply the corresponding functional requirement is closed.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_r193_evidence_20261102.tar.gz`  
SHA-256: `9d979ab3e52d7c97c201e012eb174f9a115c27847bdeccf286ba2c5c6c5944ea`  
Archive includes the clean regression compile and seed logs, all five mutant compile/run logs, temporary mutated RTL copies, mutated filelists, a manifest, and per-file checksums. VCS binaries, generated work directories, and coverage databases are excluded.

## Sign-off effect

This closes the R193 response-route checker implementation and demonstrates that five named real RTL defects reach their assigned checkers. No requirement is promoted: the 38-row status remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. Remaining Phase A items include the broader legal requester × fault × phase × reset/backpressure matrix, remaining mutation classes and contract dispositions, and independent review of the complete RTM. This is not Compute Cluster sign-off.
