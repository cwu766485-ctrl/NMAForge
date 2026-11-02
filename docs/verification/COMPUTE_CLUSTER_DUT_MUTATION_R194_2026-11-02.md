# Compute Cluster real-DUT completion mutation and clean replay — R194

**Run IDs:** `R194-COMPUTE-CLUSTER-UVM-CLEAN-3S-20261102` and `R194-REAL-DUT-MUTATION-7-20261102`  
**Fixed candidate:** commit `f87acc9bca3b3ecece385fadfd5623de6837ea8d`, tree `cfc7ba4955488ae58d58f36deec368173c6ec98c`  
**Checkout:** detached clean worktree `/tmp/nmaforge_r194_clean_f87acc9`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, UVM 1.2

## Changes under test

R194 changes only the UVM monitor and real-DUT mutation driver; product RTL and SPEC are unchanged. The monitor now treats any sampled `engine_busy` transition as an observation trigger. Without that trigger, the first Missing Done injection was only caught later as a generic completion timeout. With transition sampling, the passive lifecycle checker reports the intended `CLUSTER_MISSING_DONE` at the point the active engine stops without Done or Error. The mutation driver adds Missing Done and wrong-engine Duplicate Done RTL mutations to the five R193 injections.

## Fixed-SHA clean regression

Exact command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C /tmp/nmaforge_r194_clean_f87acc9/dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r194_clean_regression_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

All three seeds pass. Each reports UVM warning/error/fatal `0/0/0`; the scoreboard checks 69,656 Memory Image words with zero mismatch, unknown read, or stale epoch. The production Core response-owner ledger reports, per seed:

```text
accepted=2847 checked=2828 reset_dropped=19
route_mismatch=0 data_mismatch=0 error_mismatch=0 pending=0
```

The compile log contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The declared applicable Compute Cluster coverage group reports 100.0% for this workload. This is named workload/testpoint coverage and is not global RTL or requirement closure.

The assertion/cover report has two UVM RAL internal properties without attempts. In this compute-only workload, the top AXI AR/AW stall-to-accept cover properties receive no matches; the W cover matches three times. R194 does not claim AR/AW assertion stimulus coverage. These scope findings do not change the separate R172 AXI evidence, and are retained here to avoid treating inactive properties as exercised.

## Real RTL mutation campaign

Exact command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C /tmp/nmaforge_r194_clean_f87acc9/dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r194_clean_mutants
```

The target creates temporary RTL copies and requires each assigned checker to fire. All seven mutants were caught:

| Mutated behavior | Expected checker | Observed result |
|---|---|---|
| Shift SPAD request address by 4 bytes | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| Flip SPAD write data bit | `CLUSTER_GOLDEN` | Caught |
| Route response to the wrong engine owner | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Clear a Matrix Line WSTRB bit | `CLUSTER_MATRIX_WSTRB` | Caught |
| Corrupt successful completion error code | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Suppress Scalar engine Done | `CLUSTER_MISSING_DONE` | Caught directly before timeout |
| Duplicate Scalar Done onto KV engine Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

Result: **7/7 targeted real RTL mutations caught**. These are checker-detection tests, not legal functional coverage bins and not a comprehensive mutation score. No product RTL was modified to inject the faults.

## Requirement traceability impact

| Requirement | Status | Test ID / checker | Result and scope | Run ID / seeds | Evidence |
|---|---|---|---|---|---|
| `REQ-PC-006` | PARTIAL | `TC-CL-R194-REAL-ENGINE-RESPONSE-OWNER`; accepted-read owner ledger, actual response mux valid/data/error checker, Memory Scoreboard | 2,847 accepted reads; 2,828 checked responses; 19 reset drops accounted; zero mismatch and no pending response per seed. Full client × fault × phase × backpressure × reset space remains open. | `R194-COMPUTE-CLUSTER-UVM-CLEAN-3S-20261102`; `20261025/26/27` | `/tmp/nmaforge_r194_clean_regression_3seed/seed_*/run.log`; archive below |
| `REQ-PC-007` | PARTIAL | Same test; production compute response mux and per-request owner ledger | Checks response destination/data/error for accepted Core reads; all production-engine concurrency/fault/backpressure/reset combinations remain open. | Same run and seeds | Same report and archive |

The injected defects exercise the named checker paths only. Existing `REQ-CL-011/012/013/027` dispositions are unchanged; this evidence does not add functional bins or promote any requirement.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_r194_evidence_20261102.tar.gz`  
SHA-256: `ddb254e5d36f20fca0de1f44f3a9c5bcbf2f3803781f20ea909296fc381477b8`  
The archive contains clean compile and three seed logs, selected URG summaries, seven mutant compile/run logs, temporary mutated RTL copies, generated mutant filelists, a summary, and a per-file SHA-256 manifest. It excludes simulator executables, generated compile trees, waveforms, and coverage databases.

## Sign-off effect

R194 closes the dedicated-checker gap for the two named Done lifecycle mutations and replays the R193 response-owner checker from a fixed clean SHA. It does not close any requirement or resolve the remaining legal requester × fault × phase × reset/backpressure matrix, partial WSTRB/alignment/protection contracts, descriptor upper-bound contract, SVA workload gaps, and other PARTIAL clauses. The 38-row disposition remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
