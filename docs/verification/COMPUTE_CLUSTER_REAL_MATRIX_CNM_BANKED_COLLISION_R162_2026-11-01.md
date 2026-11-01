# Compute Cluster production Matrix/CNM banked collision — R162

**Date:** 2026-11-01
**Decision:** scoped testpoint PASS; `REQ-PC-007` remains PARTIAL; `CL-DV-v1.0` remains HOLD.
**Run ID:** `R162-UVM-MATRIX-CNM-BANKED-COLLISION-3S-20261101`; seeded Top replay `R162-TOP-AI-RUN-20-20261101`
**Executed test SHA/tree:** `3c4b558c4b9d7fa479c259be175abbff9c48b9f9` / `d3cc2b76129213ce943f8e9301ec6f539365a9b0`
**RTL/SPEC:** unchanged; testbench, coverage, gate, and evidence documentation only.

## Testpoint and evidence mapping

| Requirement | Disposition | Test ID | Checker / coverage | Run / seeds | Result and evidence |
|---|---|---|---|---|---|
| `REQ-PC-007` | PARTIAL | `TC-PC-R162-PRODUCTION-MATRIX-CNM-BANKED-COLLISION` | Production Matrix banked requester and CNM lane request monitor; held-request address stability; response-owner route checker; `cp_matrix_cnm_bank_collision`, `cp_matrix_cnm_cnm_granted` | `R162-UVM-MATRIX-CNM-BANKED-COLLISION-3S-20261101`; `20261025/26/27` | All three seeds pass the named point and independent Golden / Memory Image checks. Logs-only archive: `/tmp/nmaforge_r162_matrix_cnm_collision_evidence.tar.gz`, SHA-256 `86ea3c68f0e57d920d904223ecee1a85d7d8ef4640a2d8777edbf283b000dde0`. |
| `REQ-CL-006` | PARTIAL | Same testpoint, limited to the collision stall interval | Matrix held-payload stability monitor; 320 observations per seed; zero hold violations | Same run and seeds | Adds a real collision-caused wait interval only; does not cover the full direction × phase × progress cross. |
| `REQ-PC-006` | PARTIAL | Same real-top workload | `CLUSTER_MEMORY_SCOREBOARD`, production response ledger and route mismatch counter | Same run and seeds | 68,692 words checked per seed; zero data mismatch, unknown read, stale epoch, or Matrix/CNM route mismatch. Broader requester/owner/error/reset behavior remains open. |

The test exercises concurrent traffic from the **production Matrix engine's banked SPAD requester** and a production CNM lane. Per seed the monitor records 333 collision cycles, 320 admitted simultaneous collisions, 320 Matrix wait cycles, 320 held-payload checks, Matrix/CNM response totals of 768/1,120, and zero owner, hold, or response-route violations. All seven production engines also complete their existing legal workload and match the independent SPAD Golden; the whole memory scoreboard reports 62,386 writes and 68,692 checked words, with zero mismatch, unknown read, or stale epoch.

## Commands and tools

Synopsys VCS/URG `V-2023.12-SP1_Full64`, UVM 1.2, behavioral SPAD (`+define+VCS`), license wait enabled. Commands ran from the exact clean R162 test worktree:

```sh
make uvm_compute_cluster_regress \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r162_matrix_cnm_collision_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make uvm_compute_cluster_mutation \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r162_matrix_cnm_collision_uvm \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r162_matrix_cnm_collision_mutations

cd dv/subsystem/top_smoke/sim && make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All commands exited 0. The UVM target printed `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`; each seed reported UVM warning/error/fatal `0/0/0`. Top Smoke ended with `TEST PASS` after the mapper precheck (86 descriptors, 60 tensors). At the same source SHA, `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` also reports both requested settings and ends `TEST PASS`. Its log-only archive is `/tmp/nmaforge_r162_top_replay_evidence.tar.gz`, SHA-256 `f2b856aa07b3191d1c2bf6c26027b8116bca3ab95933d5963a486f8b1eb34c0f`. The existing `[LOOP-REROLL-ENABLED]` fixture notice and VCS ASLR save/restore notice are retained. The UVM compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

## Coverage, checker sensitivity, and limits

Merged URG reports `cp_matrix_cnm_bank_collision` and `cp_matrix_cnm_cnm_granted` at 100% and the declared `cluster_cg` at 64/64. The 16-group all-group URG score remains 64.86%; this is **not** global functional or code coverage closure.

The same exact test content passes the 28/28 named passive monitor-observation mutation campaign: Address, Data, Response Owner, WSTRB, Completion Error Code, post-error write, response epoch, and Done/Missing-Done/Duplicate-Done for each of seven engine bits. Every run contains the injected marker, expected assigned-checker marker, a nonzero expected UVM_ERROR, and zero UVM_FATAL. This is checker sensitivity, not RTL/DUT mutation coverage.

This closes only the named real Matrix/CNM banked collision and collision-stall testpoints. It does not close all production requester pairs, full response-owner × bank combinations, completion/backpressure combinations, or legal Engine × Fault × Phase × Reset crosses. Therefore no requirement disposition is promoted: the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and the Compute Cluster v1.0 decision remains **HOLD**.
