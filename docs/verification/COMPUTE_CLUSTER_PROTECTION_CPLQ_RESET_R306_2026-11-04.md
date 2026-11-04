# Compute Cluster Protection × Full-CPLQ × Reset Recovery — R306

**Result:** PASS for this directed testpoint; no product RTL was changed. This does not close the Compute Cluster v1.0 sign-off.

## Fixed candidate and run identity

| Item | Value |
|---|---|
| Test ID | `TC-CL-R306-PROTECTION-FULL-CPLQ-RESET-RECOVERY` |
| Run ID | `R306-PROTECTION-CPLQ-RESET-3S-20261104` |
| Code/test SHA | `b345e9788c171247bdf5ab9575e5ac1c9ce7b9fa` |
| Git tree | `48b0f4935ca4ae809c96d9f529be61a5bfb1312a` |
| Published closeout parent | `f87e2ec8af06238c37b60540333d0f1785ddb829` |
| Replay | Detached clean worktree at the exact code/test SHA |
| Simulator / coverage | Synopsys VCS and URG `V-2023.12-SP1_Full64` |
| Seeds | `20261025`, `20261026`, `20261027` |

## Test and checker

For each of the seven real engines (Scalar INT8, FP, CNM, Matrix, SFU, Conv, KV), the sequence fills the usable three-entry Completion Queue capacity with real descriptor-error completions, then issues a legal engine descriptor whose destination write is denied by the configured Protection region. It checks that the real engine drains, its Protection completion is retained behind the full queue, and the original output and held completion slot remain unchanged.

While that completion is still unpublished, the test asserts the real top reset. It checks response quiet during reset and release, zero completion tail in the new epoch, unchanged output/completion sentinels, and then reissues a legal task on the same engine. The recovery checker verifies the new task ID, success status, descriptor-defined element count, and Scalar/Matrix numerical output. The new functional coverage cross samples five checked phases for each engine: completion blocked, reset asserted, release quiet window, stale completion suppressed, and post-reset recovery.

The test retains the pre-existing seven-engine Protection/full-CPLQ release-and-wrap case as a separate call. Thus the reset case does not replace or weaken the existing completion-retirement check.

## Results

All three seeds pass the new cross with `engines=7/7`, `blocked=7/7`, `reset=7/7`, `stale_completion_suppressed=7/7`, `same_engine_recovery=7/7`, and `35/35` bins at `100.0%`.

Each seed also reports:

- UVM severity `WARNING/ERROR/FATAL = 0/0/0`.
- Independent Memory Scoreboard: `278,649` words checked, `0` mismatch, `0` unknown read, `0` stale epoch.
- Response Owner Ledger: `141,827` accepted, `141,808` checked, `19` reset-dropped, `0` route/data/error mismatch, `0` pending.
- Existing applicable focused Compute Cluster coverage marker: `100.0%`.

The exact-SHA Top Smoke passes, including the 86-descriptor/60-tensor mapper check and `TEST PASS`. Its existing VCS fixture warning `[LOOP-REROLL-ENABLED]` remains present.

## Exact commands

From the repository root, with VCS installed at `/opt/Synopsys/vcs/V-2023.12-SP1`:

```bash
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r306_clean_b345e97 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

make -C dv/subsystem/top_smoke/sim ai_smoke \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

## Requirement mapping and remaining scope

| Requirement | Disposition | R306 evidence | Still open |
|---|---|---|---|
| `REQ-CL-017` | `PARTIAL` | Seven real Protection-denied writebacks are held behind full CPLQ; reset suppresses stale retirement and preserves output sentinels; all seven engines recover. | Other legal fault classes and accepted-write prefixes across fault/phase/reset combinations. |
| `REQ-CL-018` | `PARTIAL` | Top reset while a real Protection completion is pending; reset/release stays quiet, suppresses stale completion, and accepts fresh work. | Other active requester/fabric reset cut points and their full concurrency combinations remain tracked by separate tests. |
| `REQ-CL-019` | `PARTIAL` | No old-epoch completion is published; each fresh recovery task is attributed and retired once. | Full response/error priority and completion-interaction matrix. |
| `REQ-CL-027` | `PARTIAL` | Recovery completion task ID, status, and element count are checked for every engine. | Complete error ABI and priority matrix. |
| `REQ-PC-006` | `PARTIAL` | Full-run Memory Scoreboard checks 278,649 words per seed with no mismatch/unknown/stale entry. | Broader legal fault/client memory-image combinations. |
| `REQ-PC-007` | `PARTIAL` | Full-run response-owner ledger drains with no owner/data/error mismatch or pending response. | Broader requester × fault × phase × reset and downstream-service contention combinations. |

The test does not promote any RTM row. The controlling 38-row RTM remains `27 PASS-SCOPED / 11 PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The R305 19-run merged functional-coverage result is separate and was not rerun as part of R306.

## Evidence archive

Clean-worktree compile log, all three UVM logs, the three-seed URG report, Top Smoke log, and a run manifest are archived at:

`/tmp/nmaforge_r306_clean_b345e97/R306_clean_evidence.tar.gz`

SHA-256: `5c62df3f5e0854d6e27c234be2b575886d1e93ea6fbb6ce90eb0fff28dfbb739`
