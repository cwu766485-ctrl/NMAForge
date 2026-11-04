# R307 — Exact Published-HEAD Clean Replay

**Result:** PASS for the listed regressions and bounded formal targets. This is a reproducibility and testpoint-coverage update; it does not sign off Compute Cluster v1.0 or promote any Requirement disposition.

## Frozen candidate and environment

| Item | Value |
|---|---|
| Exact published closeout HEAD | `718df8e2cb7b2e592873e0d9c2415a988698cd1d` |
| Candidate tree | `7fdc8900717f95649b3bf4133c406c31064b24dd` |
| RTL/DV code/test identity | R306 code commit `b345e9788c171247bdf5ab9575e5ac1c9ce7b9fa`, tree `48b0f4935ca4ae809c96d9f529be61a5bfb1312a` |
| Difference from code/test identity | No RTL or DV files changed; the tested HEAD is a docs-only descendant |
| VCS / URG | Synopsys V-2023.12-SP1_Full64 / URG V-2023.12-SP1 |
| VC Formal | Synopsys VC Formal V-2023.12-SP2 |
| Evidence archive | `/tmp/nmaforge_r307_718df8e_20261104/R307_clean_718df8e_evidence.tar.gz` |
| Archive SHA-256 | `abfee6f5aebc7856dd51fe52903668ad6792c709ee4781f70d28ed8236816ed3` |

The exact commands, tool paths, seeds, Run IDs, selected logs, URG reports, and formal summaries are in the archive manifest. Simulator executables and VDB databases are intentionally excluded. The archive is local evidence outside Git; it must be retained with the review package if raw logs are required later.

## Executed runs

| Test ID | Run ID | Seed / scope | Result and checker evidence |
|---|---|---|---|
| `TC-CL-R307-PUBLISHED-HEAD-UVM` | `R307-CLUSTER-3S-20261104` | Cluster seeds `20261025/26/27` | PASS all 3. Each run: UVM severity 0/0/0; 278,649 Memory Scoreboard words, zero mismatch/unknown/stale; owner ledger 141,827 accepted / 141,808 checked / 19 reset-dropped, zero route/data/error mismatch and zero pending. Applicable focused Cluster testpoint coverage 100%. |
| `TC-CL-R307-MIXED-E2E-COVERAGE` | `R307-MIXED-E2E-16S-20261104` | 16 mixed DDR/AXI seeds: `20261014`, `712345`, `987654`, and `20261015..20261027` | PASS all 16 mixed-precision K/length/order/layout and AXI stall/jitter runs. |
| `TC-CL-R307-COMBINED-URG` | `R307-COMBINED-URG-19RUN-20261104` | The 3 Cluster + 16 mixed E2E runs, same candidate | PASS merge: all 38/38 declared functional covergroups are 100%. Whole-top line/condition/FSM/branch/assert/group summary is 76.21/71.52/53.49/67.49/92.00/100.00%; hierarchy includes DUT and UVM/testbench and is not DUT-only coverage closure. Assertions: 20/22 have real successes, 0 failures/incomplete; the two without attempts are UVM RAL `do_read/do_write`. Cover properties: 3/3 matched. |
| `TC-CL-R307-TOP-SMOKE` | `R307-TOP-SMOKE-20261104` | `AI_SEED=20261025`, 4 random cases plus mapper fixture | PASS, 86 descriptors / 60 tensors, `TEST PASS`. Existing `[LOOP-REROLL-ENABLED]` fixture warning remains. |
| `TC-CL-R307-TOP-20CASE` | `R307-TOP-20CASE-20261104` | `AI_SEED=12345`, 20 random cases | PASS, `TEST PASS`. |
| `TC-CL-R307-SPAD-ARBITER-FAIRNESS-FORMAL` | `R307-SPAD-FAIRNESS-20261104` | Deterministic VC Formal | PASS: 5/5 assertions, 4/4 progress implications non-vacuous, 6/6 covers; no setup issues. Control-plane traffic is constrained idle and the harness has no downstream SRAM-ready/backpressure or production seven-engine requester integration. |
| `TC-CL-R307-MATRIX-FSM-GUARDS-FORMAL` | `R307-MATRIX-FSM-20261104` | Deterministic VC Formal | PASS: 5/5 assertions non-vacuously proven and 2/2 covers reached at depth 5/11. The enabled-prefetch raw FSM count remains 49/53; this bounded proof does not force illegal transitions or close the broader integration requirement. |

The UVM compile reports no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The Top Smoke fixture warning above is pre-existing and retained.

## Requirement trace and disposition

| Requirement scope | Test / checker | Evidence | Disposition after R307 |
|---|---|---|---|
| `REQ-CL-001..028`, `REQ-PC-001..010` (all 38 rows) | Fixed-candidate clean replay; UVM Golden, Memory Scoreboard, response-owner ledger, declared functional coverage, top smoke | Run IDs and seeds above; full source mapping remains in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) | Existing 27 `PASS-SCOPED` / 11 `PARTIAL`; R307 adds no blanket requirement closure |
| `REQ-CL-014` | SPAD arbiter fairness assertions, progress implications and covers | `R307-SPAD-FAIRNESS-20261104` | `PARTIAL`: only the bounded arbiter profile is proven; no downstream service backpressure or full engine × fault × phase × reset fairness |
| `REQ-CL-010` | Matrix FSM guard assertions and legal reachability covers | `R307-MATRIX-FSM-20261104` | `PARTIAL`: 49/53 enabled-profile transitions remain observed; broader Matrix integration/fault/reset/backpressure scope is open |

The combined 100% figure is declared **functional group** coverage for these 19 tests, not 100% line/FSM coverage, not every requirement closure, and not DUT-only coverage. The two UVM RAL properties without attempts are disclosed rather than treated as passes. No illegal-state or otherwise illegal stimulus was added to chase FSM bins.

## Sign-off decision and remaining distance

The 38-row disposition remains 27 `PASS-SCOPED` and 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The eleven partial rows are `REQ-CL-006/010/014/015/017/018/019/027/028` and `REQ-PC-006/007`. Remaining closure work is requirement-specific: wider legal shared-SPAD concurrency/fault/reset phases and service stalls, Matrix FSM/integration disposition, per-engine descriptor/fault/result contracts, completion/reset interactions, complete scoreboard scope, and comparable performance evidence. R307 did not rerun or close any new benchmark/PPA item.

At the program level the estimate remains about **30% complete** across Phases A–E. With one full-time senior RTL/DV engineer, continuous VCS access, and external implementation/model inputs available, the rough remaining schedule is **2–4 weeks for Phase A** and **4–7 calendar months for the complete program**. This is a planning estimate, not a delivery promise; model/PDK/Liberty/SRAM timing and implementation-license gaps can extend or block Phase E independently.

TinyNPU comparison remains near parity on the smallest normalized GEMM points. The existing R273 report shows 152 vs 151 cycles at 16×16×16, parity at 16×16×32, and an 8.2% NMAForge lead at 32×32×64 against a serialized TinyNPU memory model while NMAForge reads 50% more input bytes. That is not a demonstrated same-memory-service advantage. See the [current status and comparison](NMAFORGE_COMPUTE_CLUSTER_STATUS_2026-11-04.md) and [R273 report](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R273_2026-11-04.md).
