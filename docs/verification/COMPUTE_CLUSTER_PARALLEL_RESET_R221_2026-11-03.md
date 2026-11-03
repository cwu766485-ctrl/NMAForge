# Compute Cluster Seven-Engine Parallel Reset/Epoch Evidence — R221

**Result:** PASS for the named testpoint. This adds a real-top reset cut while all seven production compute engines are active and accepted SPAD reads remain outstanding. It does not close the broad fault × phase × reset/backpressure matrix or promote a requirement.

## Fixed source and test identity

- Published code/test commit: `b9cff3d3f0f6205ac2a6b35cddf197d6652c22dc`
- Tested source tree: `9cc1ebe6a953297e7c0bb7ade791f29d3d78e848`
- GitHub branch: `feat/compute-cluster-closeout-audit`
- Product RTL and SPEC were not modified. This change adds a real-top UVM sequence/checker and makes its PASS marker a required gate in the existing three-seed Compute Cluster regression.
- Test ID: `TC-CL-R221-ALL-ENGINE-PARALLEL-RESET`
- UVM scenario: `run_all_engine_parallel_reset_epoch_test`; marker: `CLUSTER_ALL_ENGINE_PARALLEL_RESET_PASS`
- VCS: Synopsys `V-2023.12-SP1_Full64`; URG: Synopsys `V-2023.12-SP1`

## Scenario and checker results

The sequence dispatches legal CMDQ work to Scalar INT8, FP, CNM, Matrix, SFU, Conv, and KV. It waits for the real busy vector to be `1111111`, a production accepted-read handshake from each engine, and at least one accepted response still pending. Shared reset is asserted at that sampled cut. At the cut, the owner mask is `1111111` and two accepted reads remain outstanding. Reset-time output writes are counted by engine as contiguous prefixes; Matrix writes must be full 16-byte aligned Lines. The checker compares each accepted prefix and untouched suffix with the independent C1 Golden/image and sentinels.

The reset/release checker confirms that no old completion retires and no stale request, response, or write appears after release. It then reissues all seven tasks and checks task ID, status, element count, completion ownership, and every output against the full independent Golden image.

For each seed (`20261025`, `20261026`, `20261027`):

- Seven engines were simultaneously busy; all seven read owners were accepted; two reads were pending at reset.
- Accepted output-prefix words at the reset cut, ordered Scalar/FP/CNM/Matrix/SFU/Conv/KV: `0/0/0/0/17/0/1`; the checked prefix and remaining sentinels match the expected image.
- Old completion count was zero; stale post-release activity was zero; all seven fresh tasks recovered with full Golden outputs.
- `engine_parallel_reset_cg` bins `seven_engine_overlap_with_pending_reads`, `old_epoch_quiet_and_unretired`, and `seven_engine_golden_recovery` each hit once per seed. The group is **3/3 bins (100%) per seed**, 9/9 aggregate observations.
- `CLUSTER_ENGINE_RESPONSE_OWNER`: 5,015 accepted, 4,995 checked, 20 reset-dropped, zero route/data/error mismatch, pending zero.
- `CLUSTER_MEMORY_SCOREBOARD`: 73,190 writes and 92,871 checked words; zero mismatch, unknown read, stale epoch, or orphan; full/partial/zero Line WSTRB counts `1589/0/0`.
- UVM severity: warning/error/fatal `0/0/0`.

## Same-tree replay and coverage merge

The following gates pass on the fixed code/test source tree above:

```sh
make uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r221_parallel_reset_final_20261103 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make uvm_mixed_precision_ddr_e2e_cov_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r221_mixed_final_20261103

cd dv/subsystem/top_smoke/sim
make ai_smoke VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

The coverage merge command was:

```sh
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r221_parallel_reset_final_20261103/compile.vdb \
  /tmp/nmaforge_r221_parallel_reset_final_20261103/seed_*/coverage.vdb \
  /tmp/nmaforge_r221_mixed_final_20261103/seed_*/coverage.vdb \
  -format text -report /tmp/nmaforge_r221_combined_final_20261103 \
  -log /tmp/nmaforge_r221_combined_final_20261103.log
```

The UVM merge includes three Compute Cluster seeds and 16 mixed-precision/DDR/AXI E2E seeds (19 runs total). UVM Warning/Error/Fatal is `0/0/0` on all 19 runs. URG reports **28/28 declared functional covergroups at 100%**. This is the coverage of the declared groups in these named workloads, not 100% RTL or requirement coverage. Combined line/condition/FSM/branch is `73.95/69.39/47.24/64.95%`. Assertions have 20/22 properties with real success, zero failures/incomplete, and two UVM RAL internal properties without attempts; all 3/3 cover properties match. Top Smoke runs its mapper check (`86` descriptors, `60` tensors) and default four random cases, and passes. The separate 20-case run with `AI_SEED=12345` also passes. The pre-existing `[LOOP-REROLL-ENABLED]` Top fixture compile warning remains disclosed.

## Requirement traceability delta

The following existing RTM rows receive this scoped evidence and **remain PARTIAL**:

| Requirement | Test ID / checker | Coverage and result | Run ID / seeds | Evidence |
|---|---|---|---|---|
| REQ-CL-018 | `TC-CL-R221-ALL-ENGINE-PARALLEL-RESET`; `engine_parallel_reset_cg`; reset-epoch, quiet-window, accepted-prefix, and recovery Golden checkers | All-seven busy/owner reset cut with two pending reads; prefix and suffix checked; old epoch quiet; three declared bins hit on all three seeds. Other fault/phase/reset cuts remain open. | `R221-UVM-ALL-ENGINE-PARALLEL-RESET-3S-20261103`; `20261025/26/27` | This report; logs-only archive below |
| REQ-CL-019 | Same test; completion-tail/memory sentinel, task owner, and exactly-once recovery checks | No old completion retires; all seven new tasks complete once after reset. Other queue-pressure and simultaneous-error combinations remain open. | Same run and seeds | This report; per-seed logs in archive |
| REQ-CL-027 | Same test; task-ID/status/element-count and completion-owner Golden checker | All seven post-reset task identities and results match; this does not exercise the full external error-code ABI matrix. | Same run and seeds | This report; per-seed logs in archive |
| REQ-PC-006 | `CLUSTER_MEMORY_SCOREBOARD`; accepted-prefix/suffix and stale-epoch image checker | 92,871 words checked per seed with zero mismatch/unknown/stale/orphan; this scenario observes full Line WSTRB only. Partial/zero WSTRB and wider requester/fault crosses remain open. | Same run and seeds | This report; scoreboard summaries in archive |
| REQ-PC-007 | `CLUSTER_ENGINE_RESPONSE_OWNER`; production accepted-read/returned/reset-dropped ledger | 5,015/4,995/20 accepted/checked/reset-dropped; zero route/data/error mismatch, pending zero; each of the seven production owners had an accepted read before the shared reset cut; two accepted reads remained pending systemwide. Other fault/backpressure ownership intersections remain open. | Same run and seeds | This report; owner summaries in archive |

## Evidence archive and disposition

Logs-only archive (32 files, including per-file SHA-256 manifest): `/tmp/nmaforge_r221_evidence_logs_final_20261103.tar.gz`; SHA-256 `f63314a7e5b1bb3ff973ffdd79c09aac4f5c1ccb37f3e0cf9bbbb76fe693180a`.

The archive contains VCS compiler/run logs, Top Smoke logs, URG text reports, and a per-file SHA-256 manifest. It excludes VCS/URG databases, simulation binaries, waveforms, and generated work directories.

R221 adds a reproducible reset-with-pending-accepted-reads testpoint and keeps the make gate from silently omitting it. It does not establish complete legal Engine × Fault × Phase × Reset × Backpressure closure. The Execution RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
