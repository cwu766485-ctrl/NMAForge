# Matrix source-B Protection fault/reset epoch — R155

**Result: PASS for this bounded testpoint; Compute Cluster v1.0 remains HOLD.** The test drives a legal real-top Matrix GEMM, observes the production SPAD Protection denial, verifies `ERR_PROTECTION`, resets before the error task retires, then checks reset side effects and new-epoch recovery. It does not close the complete Engine × Fault × Phase × Reset matrix.

## Frozen identity and scope

| Item | Identity |
|---|---|
| Clean replay test SHA | `a8458c41b0fc1fc397ee3d5dfd3a9514cf2b6858` |
| Test tree | `26d03f09d6e6ee33d356aa91e8b863a276797652` |
| Parent published closeout SHA | `fc3ecd6c529068bc137c4529fc7e510a16c0fdd9` |
| Test ID | `TC-CL-R155-MATRIX-SOURCE-B-PROTECTION-RESET-EPOCH` |
| Run ID | `R155-UVM-MATRIX-PROTECTION-RESET-3S-20261101` |
| Changed files in test commit | `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh`; `dv/uvm/sim/Makefile` |
| Tools | Synopsys VCS `V-2023.12-SP1_Full64`; UVM 1.2; behavioral SPAD (`+define+VCS`) |

R155 adds only a UVM sequence and its regression gate. Product RTL, SPEC, SVA, and checker strictness are unchanged. The run uses a detached clean worktree at the exact test SHA.

## Test and observed result

The sequence submits a legal 4×4 Matrix descriptor through the actual CMDQ/Matrix/SPAD path. The encoded dimensions are M=4, N=4, and descriptor length field=1; the test checks all 16 output words against 4. Protection permits the descriptor, completion region, and source A, while source B is outside every enabled region. The monitor requires an accepted source-A banked read followed by an accepted, denied source-B request. After the fault is captured, a hierarchical read checks the production Matrix error code is `ERR_PROTECTION=6`.

**Descriptor clarification:** an earlier version of this report called this a 4×4×4 GEMM. That was inaccurate; the checked descriptor length field is 1.

Reset is asserted before the faulted task can retire. The sequence checks that no response is visible during reset or the eight-cycle release quiet window, all engines are idle, CPLQ tail remains zero, and destination/completion sentinels are unchanged. It then reissues the legal GEMM with a new task ID and checks the completion and all 16 result words against the value 4. Six declared phase bins are required by the test and report 6/6.

| Seed | Accepted A reads before denied B | Error code | Old completion/writeback suppressed | Recovery Golden | Focused bins | UVM warning/error/fatal |
|---|---:|---|---|---:|---:|---|
| 20261025 | 1 | `ERR_PROTECTION=6` | Yes | 16/16 | 6/6 (100%) | 0/0/0 |
| 20261026 | 1 | `ERR_PROTECTION=6` | Yes | 16/16 | 6/6 (100%) | 0/0/0 |
| 20261027 | 1 | `ERR_PROTECTION=6` | Yes | 16/16 | 6/6 (100%) | 0/0/0 |

The full real-top sequence checks 63,641 memory words per seed; each scoreboard reports 58,940 writes, zero mismatches, zero unknown reads, zero stale epochs, and drained pending ledgers. The merged URG report shows `matrix_protection_reset_cg` and the enclosing `cluster_cg` at 100% for this campaign. The compile log contains no VCS `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

These are named functional bins and a real-top scenario result, not whole-design code coverage or requirement closure. R155 does not test partial WSTRB, a pending response at the reset cut, another engine/fault phase, or checker mutation; those claims are not made.

## Fixed-SHA command and evidence

From the repository root, this command completed successfully in the detached R155 worktree:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r155_clean_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'
```

The Make target exits 0 with `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS` for all three seeds. The local logs and merged functional-group report are archived outside the repository at `/tmp/nmaforge_r155_matrix_protection_clean_logs.tar.gz` (SHA-256 `4f68aef817eaa780c56c8e0d6d3ad1bd42c86b4ca7ab751b62afc5e556a10675`). Per-seed logs are also under `/tmp/nmaforge_r155_clean_uvm/seed_*/run.log`; compile and URG group report are in the same run root.

## Requirement traceability delta

| Requirement | Disposition | Testpoint / checker / observed coverage | Run ID, seeds, and evidence |
|---|---|---|---|
| REQ-CL-017 | PARTIAL | `TC-CL-R155-MATRIX-SOURCE-B-PROTECTION-RESET-EPOCH`; real source-B Protection denial and error-code checker, followed by active-task reset. Other engines, causes, phases, and accepted-prefix cases remain open. | `R155-UVM-MATRIX-PROTECTION-RESET-3S-20261101`; `20261025/26/27`; per-seed `run.log` |
| REQ-CL-018 | PARTIAL | Reset/release quiet-window, idle, no-old-completion and sentinel checkers; six focused bins hit per seed. The cut does not claim a pending-response flush. | Same run and seeds; `urg_merged/groups.txt` |
| REQ-CL-019 | PARTIAL | CPLQ tail and completion image remain unchanged for the faulted epoch; the new-epoch completion and 16 Golden outputs pass. Broader fault priority and completion backpressure remain open. | Same run and seeds; per-seed `run.log` |
| REQ-CL-027 | PARTIAL | Production Matrix error code is checked as 6 and reset suppresses retirement. Other engines, faults, and accepted-write prefixes remain open. | Same run and seeds; per-seed `run.log` |
| REQ-PC-006 | PARTIAL | Real-top scoreboard checks 63,641 words per seed with no mismatch, unknown read, or stale epoch. Broader requester × fault × backpressure combinations remain open. | Same run and seeds; per-seed `run.log` |
| REQ-PC-007 | PARTIAL | Production Matrix requester issues accepted source-A traffic and a denied source-B request through the shared SPAD boundary. This is one Matrix fault/reset point, not the full requester-owner matrix. | Same run and seeds; per-seed `run.log` |

The 38-row RTM remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN**. `CL-DV-v1.0` remains **HOLD**; R155 adds evidence without promoting a requirement disposition.
