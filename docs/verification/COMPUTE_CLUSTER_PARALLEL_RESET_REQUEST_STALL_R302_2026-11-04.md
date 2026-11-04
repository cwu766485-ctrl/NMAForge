# Compute Cluster Parallel Reset with Held Request — R302

## Result

The fixed R302 UVM candidate passes the full three-seed real-top Compute Cluster regression from a detached clean worktree. It adds one bounded point to R221: during seven-engine overlap, a production SPAD request that was ready is held unaccepted for one sampled cycle, its payload is checked for stability, and shared reset is asserted while an accepted read remains pending. All seven engines then recover with their existing Golden checks.

This is **not** full reset/backpressure closure. The held request was the `engine_req` client at bit 6 (`engine_mask=1000000`); Matrix banked, Matrix Line, and CNM were not selected by this point. It promotes no RTM requirement.

## Fixed identity and run

| Item | Value |
|---|---|
| Test commit / tree | `1ca8755e015033ad68031a26ed54fbd918f449a0` / `3b1edc19571c3f4f4a1ffcd8df022b8993ad5c55` |
| Parent | `79c10e6c15716f3ed4b567723cdcd9bd790f7050` (published R301 documentation snapshot) |
| Test ID | `TC-CL-R302-ALL-ENGINE-RESET-WITH-HELD-REQUEST` |
| Sequence / marker | `run_all_engine_parallel_reset_epoch_test` / `CLUSTER_PARALLEL_RESET_STALL_PASS` |
| Run ID | `R302-UVM-PARALLEL-RESET-REQUEST-STALL-3S-20261104` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |
| Worktree | Detached clean worktree at test commit above |
| Product RTL / SPEC | Unmodified |

Command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r302_clean_replay \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

## Evidence

For each seed, the required marker records the same deterministic cut:

- All seven production engines are busy and each has accepted work (`busy=1111111`, `accepted_mask=1111111`).
- The `engine_req` bit-6 request is sampled valid and ready, then scheduler admission is stalled at the falling edge. At the next sampled edge it remains valid, is not ready, and its write/address/data payload is unchanged.
- One accepted read is still pending at reset (`pending_reads=1`). The reset-cut accepted output prefix is `0/0/0/0/17/0/1` in the existing Scalar/FP/CNM/Matrix/SFU/Conv/KV ordering.
- The sequence releases the testbench stall under reset, verifies old-epoch quiet behavior, and completes all seven post-reset Golden recoveries.

Each seed finishes with UVM warning/error/fatal `0/0/0`. The whole-run Memory Scoreboard checks 277,883 words and records zero mismatch, unknown read, or stale epoch. The whole-run response-owner ledger records 141,773 accepted, 141,754 checked, 19 reset-dropped, zero route/data/error mismatch, and zero pending responses. Focused applicable Compute Cluster functional coverage reports 100%; that is coverage of the declared focused groups, not full RTL or requirement closure. VCS compile/elaboration reports 0 errors and 0 warnings.

The reproducible logs-only archive is `/tmp/nmaforge_r302_clean_replay_logs.tar.gz`, SHA-256 `42d473cd491cd3ed2fc4444426e89a74832f30077c1e066463df5b4e2a9f2a0e`. It contains the compile log and three seed logs, not VCS databases or generated binaries.

## Requirement disposition

| Requirement | Disposition | Evidence delta | Remaining gap |
|---|---|---|---|
| `REQ-CL-006` | `PARTIAL` | Real reset cut now combines all-seven accepted owners and a held, unaccepted production request. | Only engine client bit 6 was held. Other requester types, fault phases, and their reset/backpressure combinations remain open. |
| `REQ-CL-018` | `PARTIAL` | Adds one clean three-seed seven-engine reset-with-pending-read and held-request point. | Does not span each engine × fault × phase × reset × backpressure combination or external fabric contracts. |
| `REQ-PC-006/007` | `PARTIAL` | Whole-run memory and owner ledgers remain clean for all three seeds. | This does not provide a complete concurrent owner/fault/memory cross or all-client held-request test. |

The overall RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, with no `BLOCKED_SPEC` or `NOT_RUN`; `CL-DV-v1.0` remains **HOLD**.
