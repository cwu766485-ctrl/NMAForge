# Compute Cluster Abort × Full CPLQ Cross — R216

## Candidate and disposition

- Test ID: `TC-CL-R216-ENGINE-ABORT-FULL-CPLQ-7`
- Run ID: `CL-ABORT-CPLQ-R216-CLEAN-3S-20261103`
- Fixed code/test SHA: `09f9d31209fdcc803ec322cf3822bd51e763665a`
- Published GitHub code commit: `09f9d31209fdcc803ec322cf3822bd51e763665a` (tree `9778101254417c7272c37d8177e319e70849c8b4`, identical to the tested SHA tree)
- Parent published closeout source: `eb27e716fc40c6e526e479e2472837b165675a97`
- Tools: VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`
- RTL and SPEC were not changed. The change is confined to the UVM sequence and regression gate.
- Scope outcome: **PASS for the named testpoint; no requirement is promoted.** `REQ-CL-017` and `REQ-CL-027` remain `PARTIAL`; `REQ-PC-004` remains `PASS-SCOPED`; the overall 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Scenario and checker evidence

For each of seven real engines (Scalar INT8, FP, CNM, Matrix, SFU, Conv, KV), the sequence first fills the four-slot Completion Queue's three-entry usable capacity with legal descriptor-error completions. It then dispatches a legal, long-running operation, waits until that engine is observed busy, and issues software Abort while the completion ring is full.

The checker requires the engine to stop, keeps the three filler records intact, verifies that the held completion does not advance `CPLQ_TAIL` while full, and checks that software head advancement releases the task's `ERR_ABORT=0x32` record at slot 3 with tail wrap from 3 to 0. It also checks exactly-once retirement, the task ID, held-slot sentinels, and zero accepted output writes after the DUT samples Abort. Matrix Line output handshakes are monitored through the Line interface; the other engines use their real engine request handshakes.

| Seed | Seven-engine cases | Focused URG bin | Memory Image / owner result | UVM severity |
|---|---:|---:|---|---:|
| `20261025` | 7/7 PASS | 7/7, 100% | 72,512 words; 0 mismatch/unknown; 0 stale/orphan; pending owners 0 | 0/0/0 |
| `20261026` | 7/7 PASS | 7/7, 100% | 72,512 words; 0 mismatch/unknown; 0 stale/orphan; pending owners 0 | 0/0/0 |
| `20261027` | 7/7 PASS | 7/7, 100% | 72,512 words; 0 mismatch/unknown; 0 stale/orphan; pending owners 0 | 0/0/0 |

The UVM owner ledger reports 24,904 reads, 24,863 responses, and 41 reset-dropped reads in the whole sequence, with zero orphan responses and all owner pending queues empty. This full-sequence counter includes existing reset tests; R216's seven abort cases pass the independent per-engine completion, memory, and post-Abort-write checks.

Top Smoke also passes at the same committed source: mapper precheck covers 86 descriptors and 60 tensors, and the RTL smoke ends with `TEST PASS`. The existing `[LOOP-REROLL-ENABLED]` fixture warning remains visible; it is unrelated to this UVM change.

## Reproduction

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_abort_cplq_published_sha_09f9d312 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=20 AI_SEED=12345
```

The clean-SHA compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Logs and selected URG reports are archived outside the repository at `/tmp/nmaforge_abort_cplq_r216_published_09f9d312_20261103.tar.gz` (SHA-256 `a93725d2c8787f69b1c8baea4ad5761e89e7afef4d3b0917a15096b4e18b7026`). The archive contains the compile log, all three seed logs, merged URG dashboard/groups/assertions, and the Top Smoke compile/run logs; it excludes VDBs and generated executables.

## Remaining sign-off issues

R216 closes only the seven-engine Abort × full-CPLQ backpressure testpoint. It does not establish the full Engine × Fault × Phase × Reset × Backpressure × Response-Owner matrix, nor does it close all legal fault-priority and completion ABI combinations. Other open requirements, Matrix's raw 49/53 default-profile transitions, unsupported partial/zero Matrix Line WSTRB, descriptor upper-bound contracts, and whole-cluster coverage disposition remain as tracked in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) and [Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).
