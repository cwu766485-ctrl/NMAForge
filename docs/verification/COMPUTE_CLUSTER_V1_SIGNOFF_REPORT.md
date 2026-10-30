# NMAForge Compute Cluster v1.0 Functional DV Sign-off Report

**Review date:** 2026-10-30  
**Decision:** **HOLD — not signed off**  
**Scope:** Compute Cluster functional DV only; no claim of whole-NPU sign-off or ASIC PPA closure.

## Version and evidence baseline

| Item | Frozen identity |
|---|---|
| Product RTL candidate | `6848a414eaeaa05cf9e1411cf55d9d27333208a6` |
| Latest published closeout snapshot | `be78ee27b5a08783ec2560334ca1361baf382157` |
| Review branch | `work/compute-cluster-v1-closeout-20261030` |
| Evidence state when this report was drafted | `8feca2d46a9f8003118147d62b75180e65c0da65` |
| SPEC | Compute Cluster SPEC v1.5; product RTL unchanged by this review commit |
| VCS | Synopsys VCS `V-2023.12-SP1_Full64`; license could not be acquired for R46–R48 |

The review branch is isolated from the v2 research branch. The review commit adds DV checks and evidence documentation only; it does not change product RTL.

## Requirement disposition

The Execution RTM maps all 38 requirements (`REQ-CL-001..028`, `REQ-PC-001..010`) to test IDs, checkers, coverage, run IDs, seeds and evidence paths.

| Disposition | Count | Meaning |
|---|---:|---|
| PASS-SCOPED | 24 | Evidence passes only for the explicitly exercised scope |
| PARTIAL | 14 | Remaining cases or integration evidence are open |
| BLOCKED_SPEC | 0 | No unresolved specification blocker remains in the current frozen contract |
| NOT_RUN | 0 | Every requirement has a recorded disposition; this does not mean every test ran |

The 2026-10-30 clean replay attempts R46–R48 are separately classified `BLOCKED_ENV`; they produced no new simulation or coverage result and do not change the requirement counts.

## Review findings

| Area | Evidence | Remaining issue / disposition |
|---|---|---|
| Golden and memory image | R40: six clean seeds on the selected product SHA; seven-engine memory scoreboard; R45: Digits 360/360 with bit-exact integer Golden | Bounded to tested operations and shapes; see the RTM partial rows |
| Shared SPAD and response ownership | R40 top scoreboard, R31 CNM/DMA-SPAD lifecycle slice, R32 accepted-read reset sweep across seven engines | Production-top pair and fault-phase combinations remain incomplete; actual external-fabric reset qualification is open |
| Backpressure, parity, protection, abort and reset | R30–R32 and R40–R41 cover named Matrix, CNM, DMA/SPAD, parity, reset and mutation slices | No complete legal `Engine × Fault × Phase × Reset` matrix has been demonstrated |
| Mutation sensitivity | R41 catches 25/25 passive checker observation mutations for address, data, owner, WSTRB and completion lifecycle | This is checker sensitivity, not a DUT RTL mutation score; broader fault/error injection remains open |
| Matrix FSM | R28 records raw enabled-profile coverage 49/53, five non-vacuous formal proofs, state reachability covers, and the separate prefetch-disabled transition | Preserve raw 49/53; no illegal stimulus is used to force bins. Remaining transitions are dispositioned only within the documented proof assumptions/configuration |
| Matrix Line output | SPEC v1.5 freezes aligned full-`WSTRB` Line writes, scalar fallback for 4-byte-aligned non-Line-aligned output, protection-prefix behavior, and partial/zero WSTRB as unsupported. `MATRIX-LINE-001` checks these interface rules plus stall stability | The final checker source has not compiled or run; R48 is `BLOCKED_ENV`. No new PASS, memory-image comparison or coverage is claimed |
| SVA and compile diagnostics | R40/R15 provide non-vacuity and AXI assertion evidence for their named properties; prior focused compile had no `[TFIPC]` diagnostics | Evidence does not cover every requester/fault/backpressure combination; see the individual RTM notes |
| Descriptor and scalar numeric boundaries | Existing representative descriptor, scalar, Matrix and engine Golden checks | Per-opcode legal descriptor boundaries and full scalar INT8 arithmetic edge campaign remain open |

## Clean replay status

The candidate SHA passed the previously recorded clean R40–R45 campaigns: six-seed seven-engine UVM, 25/25 checker-sensitivity mutations, 165/165 Matrix size/ablation checks, pinned TinyNPU paired cases, Top Smoke and Digits inference. Those passes remain valid for their named sources and scope.

The latest published closeout snapshot was checked out into a clean worktree for R46. UVM compilation and restored Top Smoke compilation stopped before simulation because VCS could not contact/acquire a license. The 86-descriptor mapper precheck did pass. R47 was the initial Matrix Line checker attempt; R48 retried the final checker source with the same license wait outcome. Logs and exact commands are indexed in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

## Sign-off decision and exit conditions

**CL-DV-v1.0 remains HOLD.** The current evidence does not satisfy the required closure for 14 partial requirements. No coverage percentage is used to waive missing legal scenarios.

Before an independent review can consider sign-off, the open items must be closed or receive an approved scope disposition, including:

1. Run the final Matrix Line checker and compare the complete output Memory Image on the fixed candidate.
2. Complete legal fault/reset phase crosses and production-top shared-SPAD ownership cases, or document approved bounded exclusions.
3. Qualify the coordinated reset/epoch contract against the selected external fabric, or attach its approved compliance review.
4. Freeze and test descriptor boundary rules and scalar INT8 numeric boundary vectors.
5. Re-run the required fixed-SHA clean-worktree regression with VCS available; review all 38 RTM rows and their evidence paths.

PPA and full pretrained-model deployment are outside this Functional DV decision and remain unclaimed.

## Evidence documents

- [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)
- [Open issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md)
- [Sign-off readiness](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md)
- [UVM testplan](COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)
- [Compute Cluster SPEC v1.5](../spec/COMPUTE_CLUSTER_SPEC_ZH.md)
- [Verification matrix](../../dv/VERIFICATION_MATRIX.md)
