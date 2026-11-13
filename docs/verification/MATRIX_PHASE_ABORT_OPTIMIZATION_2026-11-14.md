# Matrix Phase-Abort Test Contract and Simulation Optimization

Status: the Candidate 001 failure was caused by a testbench dependency on an
internal terminal state, not by an abort sampled and ignored by the DUT. The
test now aborts at an externally observable final-write boundary and preserves
its error, no-extra-write, and drain checks. The corrected three-seed regression
passes for the baseline and isolated Candidate 001/002 patches. With
per-workload backpressure aligned, both candidates save five aggregate
simulation cycles (0.25%), below the 5% goal. No ASIC PPA result or signoff is
claimed.

Review branch: [NMAForge PR #10](https://github.com/cwu766485-ctrl/NMAForge/pull/10),
targeting `feat/shape-adaptive-gemv-v2`. GitHub currently reports no Actions
checks for this branch; the local VCS regression and archived artifacts are
linked below.

## Root Cause and Test Correction

The former phase-abort case waited for `dut.state_r == 11` (`ST_DONE`) and only
then asserted `abort`. Candidate 001 skips that internal state at its final
`ST_NEXT` branch, deasserts `busy`, asserts `done`, and enters `IDLE`. In the
seed `20261021` trace the implementations first diverged at operation cycle 22:

| Snapshot | Cycle 21 | Cycle 22 |
| --- | --- | --- |
| Baseline | state 10, busy 1, done 0, abort 0 | state 11, busy 1, done 0, abort 0 |
| Candidate 001 | state 10, busy 1, done 0, abort 0 | state 0, busy 0, done 1, abort 0 |

The test asserted abort only after the state wait. Candidate 001 therefore
never sampled abort; the failure did not demonstrate an abort protocol
violation. The original logs are preserved for the
[baseline](artifacts/MATRIX_PHASE_ABORT_2026-11-14/first-divergence/baseline_seed_20261021.log)
and [Candidate 001](artifacts/MATRIX_PHASE_ABORT_2026-11-14/first-divergence/candidate001_seed_20261021.log)
trace. The test was changed to wait until three of four output lines have
committed and the final line is valid while `busy` is high. At the falling edge,
the testbench holds `line_ready` low and asserts abort, then requires
`ERR_ABORT`, no additional line/scalar writes, and accepted-read drain. All
other phase-abort cases and all assertions, scoreboards, and fault checks remain
present. The random regression still reports 18 cases and 35 fault checks per
seed, with six phase-abort checks.

## Contract Assessment

The reviewed contract is `docs/spec/COMPUTE_CLUSTER_SPEC_ZH.md`, REQ-PC-009,
plus the Matrix P0-B/P0-C abort-drain requirements: stop new reads after abort,
drain already accepted responses, and report the abort/error completion. These
requirements specify no fixed completion latency and do not require internal
state 11 to be reachable. The old test therefore imposed an implementation
phase-reachability condition beyond the written protocol. The corrected test
checks abort at a busy, externally observable final-write boundary.

A negative mutation that ignores abort only during the final output row was
killed by the new case after earlier phase/fault cases passed. The test failed
with `done/error/code/busy=0/0/0/1` at the final-write abort check, as expected.
Mutation sources remain isolated under `/tmp/nmaforge_phase_abort_negative_control`
and `/tmp/nmaforge_phase_abort_negative_finalwrite_mutant`; neither mutant is
part of this feature branch. The negative-control log is archived at
[`negative_control_final_write_abort.log`](artifacts/MATRIX_PHASE_ABORT_2026-11-14/negative_control_final_write_abort.log).

The test-only branch starts at base revision
`409c3a9fd647d4f8c4c881c9bfdaf5d93b7076ee`. Commit
`987c957e32a3be71e7d8b593e8d7a515eecf9b42` changes the abort stimulus to the
final-write-pending boundary; commit
`52353d5454284e05119764705fb8a6e406a5c8f4` re-seeds backpressure before each
benchmark workload. The revised testbench SHA-256 is
`7b886201d9f95d22aee03f2c8826aa217a819e3ef73d5393ad05cd5e1d1dc85c`.
Baseline and both isolated candidates passed regression and reference-model
stages on seeds `20261021/20261022/20261023`. Each seed reports 18 cases and
35 fault checks, including `MATRIX_CORE_PHASE_ABORT_PASS
phase=final_write_pending id=29 prior_writes=3/0`. Regression, reference,
latency-gate, and performance stages passed for all three snapshots.

The final-write abort-ignored mutation failed with
`done/error/code/busy=0/0/0/1`; its log SHA-256 is
`d3712a94a23e3f82a42a017455e1bb87b39ccab5ba943ab1cf81fc7ddab086b5`. Mutation
sources remain isolated and were not added to the branch.

## Reproducible Regression and Runtime

The test-only feature branch starts at base NMAForge revision
`409c3a9fd647d4f8c4c881c9bfdaf5d93b7076ee` and contains:

- `987c957e`: replace the internal `ST_DONE` abort target with the final-write
  pending boundary.
- `52353d54`: reset the benchmark readiness/response LFSR from `SEED + case_id`
  before each workload, so a cycle-count change in one workload cannot shift
  later workloads' stimulus sequence.

VCS `V-2023.12-SP1_Full64` passed the corrected baseline regression on seeds
`20261021/20261022/20261023`. It also passed each isolated candidate's regression
and reference-model stages on the same three seeds. The shared Stage Runtime
baseline and both candidate campaigns passed regression, reference model,
latency gate, and performance stages. The raw command logs are archived under
[`artifacts/MATRIX_PHASE_ABORT_2026-11-14`](artifacts/MATRIX_PHASE_ABORT_2026-11-14),
with SHA-256 values in the
[`run evidence manifest`](MATRIX_PHASE_ABORT_OPTIMIZATION_EVIDENCE.json). The
Stage Runtime's full JSON/source snapshots remain at
`/tmp/nmaforge_m3_phaseabort_aligned_stagecampaign` on the execution host.

| Workload MxNxK | Baseline cycles | Candidate 001 | Candidate 002 |
| --- | ---: | ---: | ---: |
| 4x4x32 | 78 | 77 | 77 |
| 8x8x32 | 110 | 109 | 109 |
| 16x16x32 | 230 | 229 | 229 |
| 16x32x32 | 403 | 402 | 402 |
| 32x32x64 | 1189 | 1188 | 1188 |
| Aggregate | 2010 | 2005 (-0.25%) | 2005 (-0.25%) |

Weighted useful MAC/cycle changed from 46.105 to 46.220 (+0.25%). Candidate
patch SHA-256 values are `537fe77b9214e4b8700110b186bc6c23243e551e9839f2cc8a358868be0389c9`
for Candidate 001 and
`63b95da01b6de1e89ae85913bbb5ac07ccc2dc151765bd47899c87ea00843d3a` for
Candidate 002. Both are simulation candidates only. The comparator's
`ACCEPT` means required simulation gates passed and the measured metrics moved
in the configured direction; the separate 5% campaign objective was not met.
Neither patch is included in this test-contract branch. Stage artifacts are
retained at `/tmp/nmaforge_m3_phaseabort_aligned_stagecampaign`. The aligned
candidate patches and decisions are available as
[`Candidate 001 diff`](candidates/MATRIX-CYCLE-001.diff),
[`Candidate 002 diff`](candidates/MATRIX-CYCLE-002.diff),
[`Candidate 001R2 decision`](MATRIX-CYCLE-001R2.decision.json),
[`Candidate 002R2 decision`](MATRIX-CYCLE-002R2.decision.json), and the
[`run evidence manifest`](MATRIX_PHASE_ABORT_OPTIMIZATION_EVIDENCE.json).

## Cycle Profile and Next Target

For the baseline `32x32x64` workload (1,189 cycles), the mutually exclusive FSM
state counters sum to the total:

| State group | Cycles | Share |
| --- | ---: | ---: |
| Prefetch wait | 500 | 42.05% |
| Write state | 320 | 26.91% |
| MAC | 256 | 21.53% |
| Prepare MAC | 64 | 5.38% |
| A/B requests and waits | 44 | 3.70% |
| Next and done | 5 | 0.42% |

The additional counters report 210 arbiter-stall cycles, 64 writeback-wait
cycles, and 11 response-wait cycles. These event counters overlap FSM states
and one another; do not add them to the state totals. The next simulation
investigation should separate prefetch readiness/response delay from arbiter
denial and distinguish productive write cycles from blocked writeback. The
256 MAC cycles are the ideal arithmetic work for this workload at 256 useful
MACs/cycle, so the largest measured opportunity lies outside the arithmetic
phase. No third candidate was attempted after two equivalent 0.25% cycle
results.

## ASIC PPA Status

ASIC optimization remains `STOP`: this run has no approved standard-cell
library/corner, standalone Matrix SDC, candidate equivalence policy, or target
DC/PrimeTime adapter inputs. Synthesis, STA, area, frequency, and power were not
measured. The simulation benchmark's 250 MHz normalized display is not ASIC
timing evidence.
