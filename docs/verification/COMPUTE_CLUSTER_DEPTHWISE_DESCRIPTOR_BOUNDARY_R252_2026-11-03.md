# Compute Cluster Depthwise Descriptor Boundary — R252

**Disposition: focused PASS; v1.0 sign-off remains HOLD.** This run extends the real-CMDQ shape-boundary test from Conv opcode `0x16` to per-channel Depthwise opcode `0x17`. It adds boundary evidence only and does not change the 38-row RTM disposition.

## Fixed candidate and run

- Candidate commit: `f5aba99b8812d946188cf098fff034284885fd99`
- Candidate tree: `82a238f7dcd76562dd25a4fa38da9c5546367067`
- Worktree: detached clean checkout at the candidate commit
- Run ID: `R252-COMPUTE-CLUSTER-3SEED-20261103`
- Simulator: VCS `V-2023.12-SP1_Full64`; coverage merger: URG `V-2023.12-SP1`
- Seeds: `20261025`, `20261026`, `20261027`
- Command, from `dv/uvm/sim`:

  ```sh
  make uvm_compute_cluster_regress \
    COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
    COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r252_clean_replay_f5aba99_3seed \
    VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
  ```

The command exits successfully and reports `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS` for all three seeds.

## Test and checker evidence

For each opcode, the real CMDQ fetch/validation/launch path exercises a legal `3×3` minimum descriptor and a `3×128` maximum-width descriptor. The 0x17 cases are single-channel Depthwise descriptors; this does not test a multi-channel descriptor chain.

- Observed launch snapshots: four ordered launches (`0x16`, `0x16`, `0x17`, `0x17`) with the expected M/N/K fields.
- Independent signed INT8-to-INT32 Golden: all 254 output words match (127 outputs per opcode across the two shapes).
- Completion checker: all four task IDs, result words, element counts, status, and order match the Golden.
- Boundary checker: before/after sentinels remain unchanged around all four output spans.
- Focused functional coverage: Conv minimum/maximum `2/2`; Depthwise minimum/maximum `2/2`. URG reports each dedicated covergroup at `100.00%` over the merged three-seed DB.
- Per seed, the full UVM Memory Scoreboard checks 93,757 words with zero mismatch, unknown read, stale epoch, orphan response, or pending owner. UVM severity is `0/0/0`.

The full single-test URG report contains 29 groups and an aggregate score of 80.61%. That aggregate is not a sign-off threshold or evidence of complete RTL/code coverage; this result claims only the named Conv/Depthwise testpoints.

## Evidence archive

Logs and the focused URG group reports are archived outside the repository at `/tmp/nmaforge_r252_depthwise_evidence_f5aba99.tar.gz` (SHA-256 `fa6a39b60ae74e6093ec0ce2afde3a7eb62b7ae5c662cc26841896d10ccc3b9a`). VCS databases and generated simulation directories remain outside the repository.

## Remaining scope

This result does not cover H>3 boundary cases, multi-channel Depthwise scheduling, stride/alias/address-overflow contracts, or broad fault × phase × reset × response-backpressure crosses. `OPEN-CL-002` remains open for those descriptor contracts. `REQ-CL-024` remains `PASS-SCOPED` under its bounded functional scope; no requirement status is promoted by this run. The overall disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
