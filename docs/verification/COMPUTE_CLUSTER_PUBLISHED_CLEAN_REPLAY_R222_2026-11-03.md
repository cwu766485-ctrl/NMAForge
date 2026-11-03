# Compute Cluster Published Clean-Worktree Replay — R222

**Result:** PASS for the named replay set. This verifies the published branch head in a detached clean worktree; it does not close the remaining partial requirements or change the sign-off decision.

## Fixed candidate

- Branch: `feat/compute-cluster-closeout-audit`
- Tested published HEAD: `6fa734ec5cd2d781729cd6ba5659037cba929cba`
- Tree: `7b47b902cbc4e687c354b2b9366f0b70413f300b`
- RTL/UVM/test parent: `b9cff3d3f0f6205ac2a6b35cddf197d6652c22dc`
- The tested HEAD adds only four verification documents over its parent; RTL, UVM, test sources, and Make targets are unchanged.
- Worktree was clean before and after the replay.
- VCS: Synopsys `V-2023.12-SP1_Full64`; URG: Synopsys `V-2023.12-SP1`.

## Reproduction commands and results

Run the UVM commands from `dv/uvm/sim`:

```sh
make uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r221_published_clean_6fa734e_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make uvm_mixed_precision_ddr_e2e_cov_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r221_published_clean_6fa734e_mixed
```

Run the combined coverage merge from the repository root:

```sh
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r221_published_clean_6fa734e_uvm/compile.vdb \
  /tmp/nmaforge_r221_published_clean_6fa734e_uvm/seed_*/coverage.vdb \
  /tmp/nmaforge_r221_published_clean_6fa734e_mixed/seed_*/coverage.vdb \
  -format text -report /tmp/nmaforge_r221_published_clean_6fa734e_urg_combined \
  -log /tmp/nmaforge_r221_published_clean_6fa734e_urg_combined.log
```

Run the Top Smoke commands from `dv/subsystem/top_smoke/sim`:

```sh
make ai_smoke VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

Results:

- Compute Cluster UVM: 3/3 seeds pass. Each seed observes `accepted_mask=1111111`, seven accepted-read owners, two responses pending at the reset cut, max active engines 7, three focused reset bins hit, no old completion or stale activity, and all seven engines recover against Golden. UVM Warning/Error/Fatal is `0/0/0` for every seed. Each run checks 92,871 memory words with zero mismatch, unknown read, stale epoch, or orphan; the response ledger ends with zero pending entries and zero route/data/error mismatch.
- Mixed-precision/DDR/AXI E2E: 16/16 seeds pass with UVM Warning/Error/Fatal `0/0/0` per run.
- Combined URG: 19 tests, 28/28 declared functional covergroups at 100%. Raw line/condition/FSM/branch coverage is `73.95/69.39/47.24/64.95%`. Assertion properties: 20/22 with real successes, zero failures/incomplete, two UVM RAL internal properties without attempts; cover properties 3/3.
- Top Smoke: mapper reports 86 descriptors and 60 tensors; both the default four-case smoke and the 20-case `AI_SEED=12345` run end in `TEST PASS`.
- UVM compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Top fixture compilation retains the existing `[LOOP-REROLL-ENABLED]` warning.

The logs-only evidence archive is `/tmp/nmaforge_r222_published_clean_evidence_20261103.tar.gz`, SHA-256 `41f494be18dfaf2e477960418f18204fb94495e1f16d23720ed04a0ba9e49320`. It contains 32 text logs/reports plus a per-file SHA-256 manifest and excludes VCS/URG databases, binaries, waveforms, and generated work directories.

## Disposition

This is reproducibility evidence for the published SHA, not additional requirement closure. The 38-row Execution RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. Remaining legal fault × phase × reset/backpressure combinations, Matrix FSM dispositions, descriptor-contract gaps, and scoped P0 review remain open.
