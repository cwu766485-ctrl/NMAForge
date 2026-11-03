# Compute Cluster Final Published-Tree Replay — R248

**Result:** the published final tree reproduces the named regression, checker-sensitivity, and declared testpoint-coverage gates. **This is not full v1.0 sign-off.** The RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Frozen identity and tools

| Item | Value |
|---|---|
| Published `main` commit | `4c7a95242dd9d910969f2a9ab01bca1e7de2b0c6` |
| Published tree | `00431c3f0c05d11de2d8cf90f69ce0020c7944bf` |
| Local detached replay commit | `76d5121493407cddef6fdbe92c9f31058ff5ec1b` |
| Local replay tree | `00431c3f0c05d11de2d8cf90f69ce0020c7944bf` |
| Simulator / coverage | Synopsys VCS / URG `V-2023.12-SP1_Full64` |
| Clean worktree | `/tmp/nmaforge_r246_mutation_clean` |

The local detached commit and current published `main` have identical trees. All results below were generated from that tree.

## Runs and results

| Run ID | Command | Result |
|---|---|---|
| `R248-CLUSTER-UVM-3S` | `make -C dv/uvm/sim uvm_compute_cluster_regress` with seeds `20261025/26/27` and output `/tmp/nmaforge_r248_final_tree_cluster_3seed` | PASS on all three seeds; each checks 92,871 Memory Image words, 73,190 writes, zero mismatch/unknown/stale epoch, response-owner ledger drained; focused `cluster_cg=64/64`; UVM errors/fatals 0/0. |
| `R248-TOP-SMOKE` | `make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261103 AI_RANDOM_CASES=20 AI_SEED=12345` | PASS; mapper precheck covers 86 descriptors / 60 tensors and smoke ends `TEST PASS`. Existing `LOOP-REROLL-ENABLED` compile warning remains; no compile Error/TFIPC diagnostic. |
| `R248-DUT-MUTATION` | `make -C dv/uvm/sim uvm_compute_cluster_dut_mutation` | PASS, 7/7 temporary RTL mutants are detected: Address (`CLUSTER_MEMORY_UNKNOWN`), Data (`CLUSTER_GOLDEN`), Response Owner (`CLUSTER_ENGINE_RESPONSE_OWNER`), WSTRB (`CLUSTER_MATRIX_WSTRB`), Completion Error (`CLUSTER_COMPLETION_ERROR_CODE`), Missing Done (`CLUSTER_MISSING_DONE`), Duplicate Done (`CLUSTER_DONE_WITHOUT_ACTIVE`). |
| `R248-MIXED-E2E-COVERAGE-16S` | `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress` | PASS on 16 seeds: `20261014–20261027`, `712345`, `987654`; E2E functional coverage and URG merge targets pass. |
| `R248-URG-MERGE-19T` | URG merge of the three Cluster and 16 mixed-precision/AXI seed databases | PASS: 19 tests, all 28/28 declared functional groups score 100%; all three AXI stall-to-accept cover properties match. |

Merged hierarchy coverage is line/condition/FSM/branch/assert `73.99/69.39/47.24/64.95/92.00%`. Assertions report 20/22 with real successes, zero failures and zero incomplete; the only two without attempts are UVM RAL internal `do_read`/`do_write` properties. Code coverage is not 100% and is not represented as such.

VCS compile logs for the Cluster and mixed-precision suites have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The existing Top Smoke `LOOP-REROLL-ENABLED` warning is retained as disclosed above.

## Evidence

Text logs, URG summaries and SHA-256 manifest are archived at `/tmp/nmaforge_r248_final_tree_evidence_20261103.tar.gz`, SHA-256 `fd62fa63ad1978b53a091e50d6f809dfe4b05e49c93b6e44dbded8ef20ce184c`. The archive excludes simulator binaries, VDBs, generated compiler trees and waveforms.

The execution RTM has all 38 rows and continues to link each requirement to its accumulated evidence. R248 adds final-tree reproducibility and confirms that every declared group in the merged plan is hit; it does not promote any requirement disposition.

## Remaining Phase A exit gaps

- The 14 `PARTIAL` requirement rows still include broader legal Engine × Fault × Phase × Reset × backpressure/owner intersections, per-engine descriptor limits and address/stride/alias/overflow execution contracts, and selected coverage/FSM dispositions.
- The two UVM RAL internal assertion properties are disclosed no-attempt library properties, not DUT assertion failures. The 20 exercised assertions have zero failures/incomplete.
- Global RTL code coverage remains below 100%; the 100% statement here applies only to the 28 declared functional coverage groups in this merged plan.
- No PPA or whole-NPU sign-off is claimed.

**Decision:** declared testpoint-coverage target is met on this final tree; Phase A's full requirement-closure exit condition is not met. Keep `CL-DV-v1.0` at **HOLD** and continue closing the requirement-specific partials without manufacturing illegal stimulus.
