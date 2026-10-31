# Compute Cluster Scalar GEMV reset after accepted output prefix — R151

**Result: PASS for this bounded testpoint; Compute Cluster v1.0 remains HOLD.** R151 adds a legal real-top Scalar GEMV reset point and clean-SHA evidence. It does not resolve all reset/fault crosses or promote requirement dispositions.

## Frozen identity and scope

| Item | Identity |
|---|---|
| Clean replay source/test SHA | `cc15b4841d2266f34ef8cacae7abd895890eb07a` |
| Source/test tree | `41ed9c384dd2ac70d65b06406ff399aca6c85bc1` |
| Published GitHub commit | `a49d3ffe7abd025cc54d384dc51eff1e6f583659` (same tree) |
| Parent / reviewed product baseline | R150 `ca4bd5e515ef73abf36cc2d5e7f8664200c14aef`; product RTL and SPEC v1.8 unchanged |
| Test ID | `TC-CL-R151-SCALAR-GEMV-RESET-ACCEPTED-PREFIX` |
| Run ID | `R151-UVM-SCALAR-RESET-PREFIX-3S-20261031` |
| Changed files | `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh`; `dv/uvm/sim/Makefile` |

No product RTL, SPEC, SVA, checker strictness, or external ABI changed. The sequence runs the test before other CMDQ doorbells so the shared top SVA's 2,000-cycle task watchdog observes only the command under test. The tested legal descriptor is Scalar GEMV M=16, K=2; K=2 completes within that fixed watchdog.

## Test and observed result

The real CMDQ path launches a signed INT8 GEMV and checks each accepted output against an independent INT32 Golden. After the first accepted output (1/16), the test asserts top reset while the engine is active. It checks that the committed prefix is Golden, the remaining 15 output words retain sentinels, the old completion image and CPLQ tail are unchanged, and no response appears during reset or the eight-cycle release quiet window. It then replays the descriptor in the new epoch and checks the full 16/16 Golden output and completion. A six-bin functional group checks task busy, accepted prefix, reset quiet, release quiet, prefix/suffix/completion disposition, and full recovery; the sequence requires all six bins.

| Seed | Reset point | Epoch/completion checks | Golden recovery | Focused bins | UVM severity |
|---|---|---|---|---:|---:|
| 20261025 | 1/16 accepted output | old completion suppressed; reset-dropped reads 0 | 16/16 | 6/6 | 0/0/0 |
| 20261026 | 1/16 accepted output | old completion suppressed; reset-dropped reads 0 | 16/16 | 6/6 | 0/0/0 |
| 20261027 | 1/16 accepted output | old completion suppressed; reset-dropped reads 0 | 16/16 | 6/6 | 0/0/0 |

The full three-seed sequence checks 63,597 scratchpad words per seed with zero data mismatch, unknown read, stale epoch, or orphan response. Its aggregate response ledger records 20,207 accepted reads, 20,175 responses, 32 reset-dropped reads from the other reset cases in the full sequence, and all pending ledgers empty. Those 32 drops do not belong to the new Scalar cut: its marker explicitly reports `reset_dropped_reads=0`.

The applicable focused compute functional group is 100.0%. Merged mixed-code URG is SCORE 61.06% (line/condition/FSM/branch/assert/group: 69.51/63.63/44.67/59.80/72.00/56.75%). These mixed DUT/testbench/UVM code metrics are not functional requirement closure.

## Fixed-SHA validation

All commands ran in detached clean worktree `/tmp/nmaforge_r151_clean_cc15b48` at source/test SHA `cc15b4841d2266f34ef8cacae7abd895890eb07a`, VCS V-2023.12-SP1_Full64, UVM 1.2, behavioral SPAD (`+define+VCS`).

| Run ID | Command | Result |
|---|---|---|
| `R151-UVM-SCALAR-RESET-PREFIX-3S-20261031` | `make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r151_clean_cc15b48/uvm COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` from `dv/uvm/sim` | 3/3 PASS; VCS compile and URG merge exit 0 |
| `R151-MUTATION-28-20261031` | `make uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r151_clean_cc15b48/uvm COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r151_clean_cc15b48/mutation` from `dv/uvm/sim` | 28/28 PASS; each injected monitor-observation error hit its named checker |
| `R151-TOP-SMOKE-20261031` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261025` from `dv/subsystem/top_smoke/sim` | PASS; VCS reported the existing `[LOOP-REROLL-ENABLED]` fixture warning |
| `R151-TOP-20CASE-20261031` | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261026` from `dv/subsystem/top_smoke/sim` | PASS (`TEST PASS`) |

The Mutation Campaign is monitor-side checker-sensitivity testing, not DUT RTL fault injection. The complete clean-replay logs and URG text reports are archived at `/tmp/nmaforge_r151_evidence_cc15b48.tar.gz` (SHA-256 `a890ca1efcad6373bf12ae10bd683d9aea62b0d6f60121ac738f12cc8514bbc0`). The archive excludes compiled binaries and coverage databases.

## Requirement traceability delta

| Requirement | Disposition | Testpoint / checker / coverage | Run ID, seed, and evidence |
|---|---|---|---|
| REQ-CL-017 | PARTIAL | `TC-CL-R151-SCALAR-GEMV-RESET-ACCEPTED-PREFIX`; accepted-output prefix Golden checker and active-reset cut checker; one Scalar M16/K2 legal reset point. Other engines, shapes, faults, and phases remain open. | `R151-UVM-SCALAR-RESET-PREFIX-3S-20261031`; 20261025/26/27; `/tmp/nmaforge_r151_clean_cc15b48/uvm/seed_*/run.log` |
| REQ-CL-018 | PARTIAL | Six reset/epoch bins 6/6 per seed; reset/release quiet-window and stale-response checker. The new Scalar cut has zero pending reads at reset, so it adds no pending-response flush point. | Same run and seeds; archive at `/tmp/nmaforge_r151_evidence_cc15b48.tar.gz` |
| REQ-CL-019 | PARTIAL | Old CPLQ tail/completion sentinels remain unchanged; the 15-word suffix remains sentinel; new-epoch completion and full output pass. Other completion/error/backpressure combinations remain open. | Same run and seeds; per-seed UVM logs above |
| REQ-CL-027 | PARTIAL | Old task does not complete across reset; recovery task ID, ordered completion, and all 16 output words pass. Full seven-engine completion/error ABI matrix remains open. | Same run and seeds; per-seed UVM logs above |
| REQ-PC-006 | PARTIAL | Production SPAD scoreboard: 63,597 checked words/seed, zero mismatch/unknown/stale/orphan; reset ledger empty after full sequence. Other fault/requester/backpressure combinations remain open. | Same run and seeds; per-seed UVM logs above |
| REQ-PC-007 | PARTIAL | Scalar request/response and memory ownership are checked through the real top. This new reset point is one engine and does not close the shared-engine contention/reset cross. | Same run and seeds; per-seed UVM logs above |

The 38-row disposition remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN**. `CL-DV-v1.0` remains **HOLD**. No new requirement is promoted by this bounded result.
