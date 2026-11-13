# Project update log

## 2026-11-14 — Matrix phase-abort test contract and M3 replay

On isolated branch `feature/m3-phase-abort-test-contract`, replaced the
internal `ST_DONE` abort wait with an abort at the final output-write boundary.
Baseline plus Candidate 001/002 each passed the corrected three-seed regression
and all configured simulation Stage Runtime gates. A final-row abort-ignored
mutation failed at the new check. Benchmark backpressure is re-seeded per
workload for comparable A/B stimulus; both candidates measured five fewer
aggregate cycles (0.25%), below the 5% objective. ASIC PPA remains STOP pending
approved library/corner, Matrix SDC, equivalence policy, and DC/STA adapter
inputs. See `docs/verification/MATRIX_PHASE_ABORT_OPTIMIZATION_2026-11-14.md`.

## Round 27 — incomplete session

Prepared historical baseline extracts and an incomplete review at `docs/benchmark/NMAFORGE_V2_ROUND27_ARCHITECTURE_FREEZE_REVIEW.md`. Withdrew unsupported LayerNorm phase allocations; phases remain unmeasured. Corrected large GEMM historical read traffic to 6,144 B. No RTL experiment, simulation, synthesis, freeze decision, commit or push completed. Historical extraction uses `git show 800c5b0:<artifact-path>`. Git metadata writes failed with read-only `.git/index.lock`; escalation was aborted.
