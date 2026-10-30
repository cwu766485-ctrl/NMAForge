# NMAForge Compute Cluster v1.0 Functional DV Sign-off Report

**Review date:** 2026-10-30  
**Decision:** **HOLD — not signed off**  
**Scope:** Compute Cluster functional DV only; no claim of whole-NPU sign-off or ASIC PPA closure.

## Version and evidence baseline

| Item | Frozen identity |
|---|---|
| Product RTL candidate | `f916874a9ce60741a4516eaf9e33ebcae4a676c2` |
| Latest top-level DV test SHA | `f24c5383fad511c8b2e1132c1157942807994759` (R54; DV-only, product RTL unchanged) |
| Latest clean replay harness SHA | `ded9d923a432e869592ec8710a22df5501d8d474` (R55–R58; Matrix test-build Makefile only) |
| Prior reviewed product baseline | `6848a414eaeaa05cf9e1411cf55d9d27333208a6` |
| Latest published closeout snapshot before this follow-up | `fc370aad6b8360af9affb52cb30909ec97d79be3` |
| Review branch | `work/compute-cluster-kv-overflow-20261030` |
| Evidence/test commit | R53 `f916874a9ce60741a4516eaf9e33ebcae4a676c2`; R54 `f24c5383fad511c8b2e1132c1157942807994759`; R55–R58 `ded9d923a432e869592ec8710a22df5501d8d474`; R52 `dde780660e40cb6accff5a53c2e6f8163b325839` |
| SPEC | Compute Cluster SPEC v1.7; R53 adds KV address overflow/alignment guards |
| VCS | Synopsys VCS `V-2023.12-SP1_Full64`; R49 passed the corrected Matrix checker on three seeds; R50 passed the published-snapshot six-seed UVM and Top Smoke; R52 passed the legal Scalar INT8 numeric campaign; R53 passed KV boundary and clean top regressions |

The review branch is isolated from the v2 research branch. R53 changes the KV product RTL to reject invalid 32-bit word addresses before SPAD access and adds its SPEC/test evidence. Earlier R40–R52 evidence retains its own exact source/test SHA relationships.

## Requirement disposition

The Execution RTM maps all 38 requirements (`REQ-CL-001..028`, `REQ-PC-001..010`) to test IDs, checkers, coverage, run IDs, seeds and evidence paths.

| Disposition | Count | Meaning |
|---|---:|---|
| PASS-SCOPED | 24 | Evidence passes only for the explicitly exercised scope |
| PARTIAL | 14 | Remaining cases or integration evidence are open |
| BLOCKED_SPEC | 0 | No unresolved specification blocker remains in the current frozen contract |
| NOT_RUN | 0 | Every requirement has a recorded disposition; this does not mean every test ran |

R46/R47 were historical `BLOCKED_ENV` attempts; R48 exposed a testbench coverage-counter reset issue; R49 resolves that issue for the scoped Matrix Line contract. R50 passes on its exact published closeout SHA. R52 passes 13 legal Scalar INT8 Golden cases on each of three clean-worktree seeds. R51's reserved-activation testpoint is superseded and excluded. R53 passes ten KV address/configuration rejection bins and the final legal SPAD word round trip on three clean-worktree seeds. R54 passes the real-top KV Protection-denial and completion slice, plus clean Top Smoke and a 20-case seeded run. R55–R58 pass on detached clean harness SHA `ded9d92`: seven-engine UVM on three seeds, 25/25 observation mutations, Matrix depth-4 fault/recovery on three seeds, and separate prefetch-off fallback on three seeds. The overall 38-requirement disposition remains 24 PASS-SCOPED / 14 PARTIAL.

## Review findings

| Area | Evidence | Remaining issue / disposition |
|---|---|---|
| Golden and memory image | R40: six clean seeds on the selected product SHA; seven-engine memory scoreboard; R45: Digits 360/360 with bit-exact integer Golden | Bounded to tested operations and shapes; see the RTM partial rows |
| Shared SPAD and response ownership | R40 top scoreboard, R31 CNM/DMA-SPAD lifecycle slice, R32 accepted-read reset sweep across seven engines | Production-top pair and fault-phase combinations remain incomplete; actual external-fabric reset qualification is open |
| Backpressure, parity, protection, abort and reset | R30–R32 and R40–R41 cover named Matrix, CNM, DMA/SPAD, parity, reset and mutation slices | No complete legal `Engine × Fault × Phase × Reset` matrix has been demonstrated |
| Mutation sensitivity | R41 catches 25/25 passive checker observation mutations for address, data, owner, WSTRB and completion lifecycle | This is checker sensitivity, not a DUT RTL mutation score; broader fault/error injection remains open |
| Matrix FSM | R28 records raw enabled-profile coverage 49/53, five non-vacuous formal proofs, state reachability covers, and the separate prefetch-disabled transition | Preserve raw 49/53; no illegal stimulus is used to force bins. Remaining transitions are dispositioned only within the documented proof assumptions/configuration |
| Matrix Line output | SPEC v1.5 freezes aligned full-`WSTRB` Line writes, scalar fallback for 4-byte-aligned non-Line-aligned output, protection-prefix behavior, and partial/zero WSTRB as unsupported. `MATRIX-LINE-001` checks these interface rules plus stall stability | R49 passes three seeds; each records 312 stable stalls, full WSTRB/alignment, fallback and protection checks, and reference-memory comparison. Scoped Line contract is closed; this does not close the broader Matrix requirement rows |
| SVA and compile diagnostics | R40/R15 provide non-vacuity and AXI assertion evidence for their named properties; R50 has no UVM severity or compile errors | R50 compute-only AR/AW stall-to-accept cover bins have zero matches (W has one); the separate R15 E2E profile supplies 3/3 AXI stall covers. Top Smoke keeps one `LOOP-REROLL-ENABLED` fixture warning. Evidence does not cover every requester/fault/backpressure combination |
| Descriptor and scalar numeric boundaries | R52 checks the common Scalar INT8 arithmetic semantics across 13 legal VDOT/GEMV/GEMM Golden cases per seed, with 60 output words checked on three seeds | `OPEN-NUM-01` closes within this common arithmetic scope; legacy Conv and broader `REQ-CL-020` opcode/shape/fault coverage remain PARTIAL, as do descriptor boundary rules |
| KV address and Protection | R53 checks ten invalid arithmetic/alignment classes per seed plus legal `0x7fffc` read/write; R54 checks a real-top Protection denial, KV owner/error completion, and sentinel preservation | SPEC v1.7 overflow/alignment slice is covered 11/11 per seed; R54 directed group passes 4/4 points. Raw KV FSM remains 11/15 transitions; broader ownership, stride/alias, and Engine descriptor contracts remain open |

## Clean replay status

The candidate SHA passed the previously recorded clean R40–R45 campaigns: six-seed seven-engine UVM, 25/25 checker-sensitivity mutations, 165/165 Matrix size/ablation checks, pinned TinyNPU paired cases, Top Smoke and Digits inference. Those passes remain valid for their named sources and scope.

The latest published closeout snapshot was checked out into a clean worktree. The initial R46 attempt was license-blocked; after license recovery R50 passed six UVM seeds and Top Smoke at that exact published SHA. R48 exposed a testbench aggregate-counter reset issue, fixed and verified by R49 on three seeds. R52 passed on a detached clean worktree fixed at test commit `dde7806`; it exercises only legal Scalar INT8 activation values and the common arithmetic path without changing product RTL. R51's reserved activation=3 bin is explicitly excluded. R53 passed at exact product/test/SPEC SHA `f916874`; R54 passed at top-test SHA `f24c538`. R55–R58 pass at detached clean harness SHA `ded9d92`, with full paths, seeds, memory scoreboard and URG/SVA dispositions in the [R55–R58 report](COMPUTE_CLUSTER_CLEAN_REPLAY_R55_R58_2026-10-30.md). The R53 DUT-only KV URG is line/condition/FSM/branch `100/98.77/73.33/96.97%`; four transitions remain unhit without an unreachable proof. R55 has three AXI AR/AW properties without real success in the compute-only profile and two RAL assertions without attempts; no failures/incomplete. Logs and commands are indexed in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md), [R52 numeric report](COMPUTE_CLUSTER_SCALAR_INT8_NUMERIC_R52.md), [R53 KV report](COMPUTE_CLUSTER_KV_ADDRESS_R53.md), [R54 KV Protection report](COMPUTE_CLUSTER_KV_PROTECTION_R54.md), and R55–R58 report.

## Sign-off decision and exit conditions

**CL-DV-v1.0 remains HOLD.** The current evidence does not satisfy the required closure for 14 partial requirements. No coverage percentage is used to waive missing legal scenarios.

Before an independent review can consider sign-off, the open items must be closed or receive an approved scope disposition, including:

1. Complete legal fault/reset phase crosses and production-top shared-SPAD ownership cases, or document approved bounded exclusions.
2. Qualify the coordinated reset/epoch contract against the selected external fabric, or attach its approved compliance review.
3. Freeze and test remaining descriptor boundaries; R52 closes the common Scalar INT8 arithmetic contract within its legal VDOT/GEMV/GEMM subset, R53 closes the KV 32-bit overflow/alignment slice, and R54 closes one top-level KV Protection-denial path. Legacy Conv, other Engine descriptor limits and broader shared-owner/fault coverage remain open.
4. Review all 38 RTM rows and their evidence paths with an independent reviewer.

PPA and full pretrained-model deployment are outside this Functional DV decision and remain unclaimed.

## Evidence documents

- [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)
- [Open issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md)
- [Sign-off readiness](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md)
- [UVM testplan](COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)
- [Scalar INT8 R52 evidence](COMPUTE_CLUSTER_SCALAR_INT8_NUMERIC_R52.md)
- [KV address R53 evidence](COMPUTE_CLUSTER_KV_ADDRESS_R53.md)
- [KV Protection R54 evidence](COMPUTE_CLUSTER_KV_PROTECTION_R54.md)
- [R55–R58 clean replay evidence](COMPUTE_CLUSTER_CLEAN_REPLAY_R55_R58_2026-10-30.md)
- [Compute Cluster SPEC v1.6](../spec/COMPUTE_CLUSTER_SPEC_ZH.md)
- [Verification matrix](../../dv/VERIFICATION_MATRIX.md)
