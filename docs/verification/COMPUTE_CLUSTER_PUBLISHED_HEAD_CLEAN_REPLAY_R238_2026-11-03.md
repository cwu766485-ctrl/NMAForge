# Compute Cluster Published-Head Clean Replay — R238

**Date:** 2026-11-03
**Published branch:** `feat/compute-cluster-closeout-audit`
**Published HEAD:** `a48a9f4db9b8f0dd04850e8026d8d5f862869487`
**Local equivalent HEAD:** `7a9a750036f6d98f7959f896c39521590ba28ed4`
**Tree:** `b7f0c807d98c429be9989fd71bff0f5e2bf495b8`
**Run IDs:** `R238-PUBLISHED-HEAD-TOP-SMOKE-20261103`, `R238-PUBLISHED-HEAD-CLUSTER-UVM-3S-20261103`
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Exact-candidate regression

The published branch HEAD and the isolated local replay worktree had the same tree before execution. The worktree was clean before the tests. All generated simulator, coverage, and log files stayed outside tracked source files.

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias

make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r237_head_cluster_20261103 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Both targets exit zero. Top Smoke ends with `TEST PASS` using the fixed test seed and 20 randomized cases. Its compile emits the existing `[LOOP-REROLL-ENABLED]` fixture warning; no simulation error was observed.

The production-top Compute Cluster UVM Make gate passes all three seeds with UVM warning/error/fatal counts `0/0/0`. Each run checks 92,871 Memory Image words with zero mismatch, unknown read, or stale-epoch read. The response-owner ledger reports 5,015 accepted, 4,995 checked, and 20 reset-dropped requests, with zero route/data/error mismatches and zero pending entries. The focused applicable compute covergroup reports `100.0%`; completion-read coverage is explicitly `N/A` for this workload. All seven-engine accepted-read reset and full recovery, 72/72 legal Protection/reset phase points, and 12/12 parity/reset points pass per seed.

The UVM-only three-seed URG report shows line/condition/FSM/branch/assert/group scores of `70.42/65.51/45.96/60.64/72.00/79.18%`. Seventeen of 22 assertion properties have real successes; there are zero failures/incomplete attempts, two UVM RAL properties have no attempts, and one of three AXI cover properties matches. The unhit AXI AR/AW properties are outside the compute-only stimulus. These hierarchy metrics are not DUT-only coverage and do not imply complete RTL or requirement coverage.

The VCS UVM compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The Top Smoke fixture warning is recorded above rather than hidden.

## Actual RTL mutation campaign

The production RTL was not edited. The mutation runner generated isolated temporary RTL copies in `/tmp`, compiled each copy, and required the real production-top UVM checker to report the assigned failure. The run used a clean detached worktree at the same tree and seed `20261025`:

```sh
git worktree add --detach /tmp/nmaforge_r238_mutation_clean HEAD
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r238_dut_mutation_clean_20261103
```

All seven real RTL mutants were caught by their intended checker; none reached the normal Compute Cluster PASS marker.

| RTL mutation | Expected checker | Result |
|---|---|---|
| Address offset | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| Write data bit flip | `CLUSTER_GOLDEN` | Caught |
| Response owner rotation | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix WSTRB corruption | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion error-code corruption | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Missing engine Done | `CLUSTER_MISSING_DONE` | Caught |
| Duplicate engine Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

Result: `COMPUTE_CLUSTER_DUT_MUTATION_PASS: 7/7 real RTL mutants caught`. The compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Expected UVM errors/fatals in the mutation run are the checker-catch evidence, not regression failures.

## Evidence archive

Logs and text reports, excluding simulator binaries, `csrc`, waveforms, and coverage databases:

- `/tmp/nmaforge_r238_published_clean_evidence_20261103.tar.gz`
- Archive SHA-256: `c3789738ce9b8e635e291134454204c142694e0bd2087b0b600b22318859e402`
- Manifest SHA-256: `cb376c190dd89e5aed7e749a008255ef3c54a95a16821f647f1a2dadb76fbcb9`

The archive contains the exact Top Smoke log, UVM compile log, all three UVM seed logs, and merged UVM-only URG dashboard/group/assertion text. The separate R237 report retains the standalone Scalar INT8 priority regression logs and archive.

Mutation-only logs and text summary:

- `/tmp/nmaforge_r238_dut_mutation_evidence_20261103.tar.gz`
- Archive SHA-256: `f7bbcf015b7cfa69d6767c117ec28f2cf00b36246c6edc53b3a08f37e16c434e`
- Manifest SHA-256: `cce98db8ce815b0663b684ccb210b72685cffc2ca6cb6539882d8182ed4bf883`

## Requirement and sign-off impact

This clean replay refreshes reproducibility evidence on the current published tree. It does not promote any RTM disposition: the table remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. Remaining closure work includes the open per-engine descriptor bounds/stride/alias/overflow contract, broad legal fault × phase × reset × backpressure × owner combinations, disposition of all requirement-level partial clauses, and the separately scoped TinyNPU/PPA objectives. No requirement is marked PASS based only on aggregate coverage.
