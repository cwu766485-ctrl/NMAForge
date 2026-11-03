# Compute Cluster R176 clean replay and real-DUT mutation evidence

**Run date:** 2026-11-03  
**Published branch:** `feat/compute-cluster-closeout-6848a41`  
**Exact clean tested SHA:** `643a2aee5708e7a815e86e0144f9b0e4a5c881ce`  
**Tree:** `c549564fb3492f14afdf74a596fd712810aee80f`  
**Product/SPEC baseline:** `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413` (SPEC v1.8)  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, UVM 1.2

## Result

The detached clean worktree at the exact published SHA passed the three-seed real-top Compute Cluster UVM regression, the seven-case real-DUT mutation campaign, Top Smoke, and the 16-seed mixed-precision DDR/AXI E2E coverage regression. This adds checker and reproducibility evidence; it does not change any of the 38 requirement dispositions. The current result remains 24 `PASS-SCOPED`, 14 `PARTIAL`, and `CL-DV-v1.0` **HOLD**.

## Commands and evidence

All commands ran from `/tmp/nmaforge_phasea_r176_exact_clean`.

```sh
make uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r176_clean_cluster_643a2ae \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make uvm_compute_cluster_dut_mutation \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r176_clean_mutations_643a2ae

make ai_smoke \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  SEED=20261103 AI_RANDOM_CASES=20 AI_SEED=12345

make uvm_mixed_precision_ddr_e2e_cov_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r176_clean_mixed_643a2ae

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  /tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r176_clean_cluster_643a2ae/compile.vdb \
  /tmp/nmaforge_r176_clean_cluster_643a2ae/seed_*/coverage.vdb \
  -dir /tmp/nmaforge_r176_clean_mixed_643a2ae/simv_uvm.vdb \
  /tmp/nmaforge_r176_clean_mixed_643a2ae/seed_*/coverage.vdb \
  -format text -report /tmp/nmaforge_r176_clean_urg_merged \
  -log /tmp/nmaforge_r176_clean_urg_merged.log
```

### Real-top UVM and ownership scoreboard

The three seeds passed with UVM warning/error/fatal counts `0/0/0`. Each full memory scoreboard checked 69,022 words with zero mismatch, unknown read, stale response, or orphan response. The independent engine-response ledger observed 2,821 accepted reads per seed; 2,802 owner/data/error tuples were checked and the remaining 19 reads were explicitly accounted for as pending reads dropped by reset. No pending ledger entry remained after recovery.

### Real-DUT mutation campaign

Seven temporary RTL source copies were mutated; product RTL in the repository was not changed by the campaign. All seven mutations were caught by the assigned checker:

| Mutation | Expected checker | Result |
|---|---|---|
| Address | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| Data | `CLUSTER_GOLDEN` | Caught |
| Response Owner | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| WSTRB | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion Error Code | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Missing Done | `CLUSTER_MISSING_DONE` | Caught |
| Duplicate Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

Result: **7/7 expected checker catches**. This is sensitivity evidence for these seven injected defects, not proof of complete fault-space coverage or a general mutation score.

### Top Smoke and merged functional coverage

Top Smoke passed the mapper precheck (`86` descriptors, `60` tensors) and 20 random cases. The existing fixture diagnostic `[LOOP-REROLL-ENABLED]` remains visible.

The mixed precision DDR/AXI E2E regression passed 16 seeds. URG merged 19 tests and reports all 20/20 **declared testbench functional groups** at 100%. Raw merged metrics are line/condition/FSM/branch/assert/group `73.62/68.15/46.69/64.58/92.00/100.00%`. Assertions have 20/22 properties with real successes, zero failures and zero incomplete; two UVM RAL internal properties had no attempts. All 3/3 cover properties matched.

These percentages are not 100% DUT code coverage and do not represent closure of all 38 requirements. The cluster-only profile and mixed DDR/AXI profile have different applicable properties; the 20/20 figure is specifically the merged set of declared testbench functional groups.

## RTM impact

R176 strengthens evidence for the existing rows without changing dispositions:

| Requirement | Status remains | Added R176 evidence |
|---|---|---|
| `REQ-PC-006` | `PARTIAL` | Independent accepted-read owner/data/error ledger and complete 69,022-word memory scoreboard on three seeds; reset-dropped responses are counted explicitly. |
| `REQ-PC-007` | `PARTIAL` | Seven-engine response ownership observations and recovery checks; the tested task does not close all production-engine pair × bank × fault × reset combinations. |
| `REQ-CL-019`, `REQ-CL-027` | `PARTIAL` | Completion error-code and Done lifecycle checker sensitivity caught the named mutations; other error classes and legal phase/reset crossings remain open. |

No requirement is promoted to `PASS`. Broader legal Engine × Fault × Phase × Reset/backpressure coverage, partial Matrix WSTRB/alignment/protection contracts, and remaining legal opcode/shape space remain open as recorded in the RTM and open-issue list.

## Artifact archive

VCS/URG logs, coverage summaries, mutation logs, Top Smoke logs, manifest, and per-file checksums are retained outside Git at `/tmp/nmaforge_r176_evidence_643a2ae.tar.gz`.

Archive SHA-256: `f902594267f375688f88eebd96be27d744e48b3407e4063b04f76aba2e9c48b0`.

Generated VCS/URG databases and logs are deliberately not committed. The manifest and 49-entry `SHA256SUMS.R176` are staged locally under `/tmp/nmaforge_r176_evidence_643a2ae/`.
