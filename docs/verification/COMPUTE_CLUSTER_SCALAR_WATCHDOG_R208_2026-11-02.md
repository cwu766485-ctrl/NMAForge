# Compute Cluster seven-engine watchdog retirement — R208

**Candidate:** `30378888dadc21a6fd2dace0a125ee78fd20d45b`  
**Tree:** `412ec3700cd79b6c3f5b64e4f0f37691e2f679d8`  
**Published same-tree commit:** [`f482fcb508b2dabd4337c9d7d911acc61b88526b`](https://github.com/cwu766485-ctrl/NMAForge/commit/f482fcb508b2dabd4337c9d7d911acc61b88526b)
**Run:** `CL-ENGINE-WATCHDOG-R208-CLEAN-3S-20261102`  
**Seeds:** `20261025`, `20261026`, `20261027`  
**Environment:** detached clean worktree `/tmp/nmaforge_r208_clean`; VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`; UVM 1.2.

## Finding and repair

The Scalar INT8 core could not retire a watchdog error while `busy` remained asserted. The watchdog predicate kept assigning `ST_ERROR` every cycle, so the `ST_ERROR` case that clears `busy` and pulses `done/error` never ran. A continuously asserted Abort had the same state-machine starvation pattern. The RTL now allows `ST_ERROR` to execute its retirement cycle even while Abort remains asserted or the watchdog predicate remains expired. Error priority and descriptor/completion ABI are unchanged.

The real-top sequence programs watchdog limit 1 and dispatches one long-running descriptor to each production engine. It observes each selected engine become busy and report error, checks `ERR_WATCHDOG` (`0x42`) in the real completion queue, verifies each destination image remains at its sentinels, and checks exactly one completion. Focused `engine_watchdog_cg` has one bin per engine and reaches 7/7 (100%) in every seed.

| Engine | Descriptor class | Guarded result words | Result |
|---|---|---:|---|
| Scalar INT8 | VDOT, length 128 | 1 | PASS |
| FP | BF16, length 128 | 1 | PASS |
| CNM | GEMV, M=16, K=64 | 1 | PASS |
| Matrix | GEMM, 16×32×16 | 512 | PASS |
| SFU | GELU, length 128 | 128 | PASS |
| Conv | 16×16, K=9 | 196 | PASS |
| KV | KV write, length 128 | 128 | PASS |

The test checks the declared watchdog cut only. It does not claim complete legal fault × phase × reset coverage for these engines.

## Clean-SHA evidence

The exact commit above was checked from a detached clean worktree.

| Gate | Command/result |
|---|---|
| Three-seed real-top Cluster UVM | `make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'`; PASS 3/3, each seed has 7/7 watchdog completions and no-writeback checks, UVM warning/error/fatal `0/0/0` |
| Memory Image scoreboard | Each seed: 65,160 writes, 70,577 checked words, 0 mismatch, 0 unknown, epoch 57, 0 stale epoch; WSTRB full/partial/zero `1461/0/0` |
| Response ownership ledger | Each seed: 3,108 accepted, 3,089 checked, 19 reset-dropped, 0 route/data/error mismatch, 0 pending |
| Top Smoke | `make ai_smoke SEED=20261025 AI_RANDOM_CASES=4 AI_SEED=12345`; PASS; mapper precheck reports 86 descriptors / 60 tensors |
| Seeded Top | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025`; PASS |
| Real RTL mutation | `make uvm_compute_cluster_dut_mutation`; PASS 7/7 expected Checker catches |

Mutations were made only in temporary source copies; repository RTL was not modified by the campaign.

| Mutant | Expected checker | Observed |
|---|---|---|
| SPAD address corruption | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| SPAD data bit flip | `CLUSTER_GOLDEN` | Caught |
| Response-owner rotation | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix WSTRB corruption | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion error-code corruption | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Suppressed Done | `CLUSTER_MISSING_DONE` | Caught |
| Duplicate/wrong-owner Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

The VCS UVM compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Top Smoke retains the known `LOOP-REROLL-ENABLED` fixture warning. In the three-seed UVM-only URG report, the new watchdog group is 100%; aggregate group score is 74.44% and total coverage score is 64.70% because the report also includes unrelated, unexercised AXI groups. These run-local totals are not sign-off coverage closure.

**Text-log archive:** `/tmp/nmaforge_r208_3037888_evidence.tar.gz`  
**SHA-256:** `bafb452bfbadde0c4d80df68b8da0feb3dc4192a15b4f1ba493261fc75cd29ce`

## Disposition

This closes the watchdog completion hang observed in Scalar RTL and adds a seven-engine watchdog testpoint. It does not promote any RTM row: the 38 requirements remain 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. Broad engine × fault × phase × reset/backpressure crosses, the Matrix FSM’s four remaining raw transitions, and other open contract/coverage items still need evidence and review.
