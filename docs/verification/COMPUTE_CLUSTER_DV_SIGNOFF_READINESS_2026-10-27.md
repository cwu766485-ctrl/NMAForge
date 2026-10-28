# Compute Cluster DV Sign-off Readiness — 2026-10-28

## Review decision (updated 2026-10-28)

**Selected review candidate source SHA:** `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`.\
**Candidate classification:** bounded Functional DV review candidate; not CL-DV-v1.0 signed.\
**Product RTL:** this candidate includes scoped Conv/KV/SFU error-code alignment to SPEC v1.4 and targeted checker/test updates; it is not an RTL-unchanged documentation-only commit.\
**Clean replay:** the exact source SHA was checked out detached at `/tmp/nmaforge_closure_9d9e0f_clean`. VCS `V-2023.12-SP1_Full64` passed the real-top seven-engine regression (3 seeds), coordinated behavioral AXI R/B reset, 25/25 checker-sensitivity mutation campaign, and Matrix benchmark replays. VC Formal `V-2023.12-SP2` proved 5/5 non-vacuous legal Matrix properties and reached both target states. Evidence remains bounded to those tests and assumptions.

| Gate | Readiness | Evidence and remaining gate |
|---|---|---|
| **CL-RC1 — Matrix + SPAD dataflow** | **Ready for bounded review** | Current-SHA size sweep passes 45/45 and eight-way ablation passes 120/120 over three seeds. The Matrix FSM raw enabled-profile result remains 49/53; three guard/invariant edges have scoped formal disposition and the fallback edge is tested in the separate prefetch-disabled build. Line WSTRB partial-write semantics/coverage remain open. |
| **CL-RC2 — seven-engine Cluster** | **Ready for bounded evidence review; not fully closed** | Current-SHA clean seven-engine UVM passes three seeds with memory scoreboard, 25/25 checker-sensitivity mutations pass, R/B reset and recovery pass against a behavioral responder, and SPEC v1.4 freezes Error ABI/priority/prefix. RTM status is 24 PASS-SCOPED, 14 PARTIAL, 0 BLOCKED_SPEC, 0 NOT_RUN. The dispatcher all-pair overlap test still uses behavioral Engine agents. |
| **CL-DV-v1.0 — defined Functional DV scope** | **HOLD** | No unresolved Error ABI/priority spec blocker remains. P0 integration/evidence gap `OPEN-CL-003`, legal Engine × Fault × Phase × Reset crosses, Matrix Line WSTRB, and remaining partial requirements prevent full closure. Formal results disposition selected Matrix guards; they do not claim all 53 transitions or every parameter profile. |
| **Whole NPU sign-off / ASIC PPA / pretrained model deployment** | **Out of this review** | Full DMA/CMDQ/compute/CPLQ system closure, current PPA, and pretrained GPT-2/Qwen deployment are not necessary to review the defined Cluster functional slice, and are not claimed here. |

## Version and history review

- Selected candidate source is `9d9e0f0`; the preceding evidence baseline was `c0832e5`. Commit `9d9e0f0` changes RTL error constants in Conv/KV/SFU to match the v1.4 cause table and adds directed checker tests. Current evidence replay used the exact commit in a detached clean worktree; the follow-on evidence report commit changes only documentation.
- Earlier runs R14–R23 remain useful historical evidence; R24–R29 now add current-source priority/error tests, clean top UVM, mutation, coordinated reset, formal guards and Matrix benchmarks. R19 uses the prior candidate's product RTL with local benchmark-only TB additions and a pinned TinyNPU reference.
- SPEC v1.1 freezes the 38 `REQ-CL`/`REQ-PC` contracts; v1.2 defines coordinated reset/epoch expectations; v1.3 freezes SFU integer arithmetic; v1.4 freezes seven-engine Error ABI, simultaneous-fault priority and accepted-write prefix. `OPEN-CL-006/007` are closed as specification issues. `OPEN-CL-003` remains for target external-fabric qualification and non-FP accepted-SPAD drain/restart evidence; `OPEN-CL-002/004`, scalar `OPEN-NUM-01`, and legal cross coverage remain open. A frozen SPEC is not requirement verification closure.
- The original `READY` rows in the UVM Testplan remain planning/status-history and are not execution evidence; use the RTM run IDs and artifacts below.

## Verification evidence review

The controlling detailed record is the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). Its evidence includes:

- Three-seed real-top tests for the seven production engines, with independent result/completion checks and a byte-addressed accepted-transaction SPAD model. Per seed: 4,946 accepted writes, 5,256 compared words, and zero memory mismatches, unknown reads, stale epochs, or orphan responses.
- Selected Matrix/CNM concurrent tag and lane ownership (`Matrix tag=3`, `CNM tag=5`, CNM lane mask `1111`), shared read-only Scalar/SFU test, and descriptor latching test.
- Request stability observations across seven engines and four CNM lanes. The selected top UVM has no Matrix line-write stall samples; that bin remains open.
- A selected 14-case parity cross per seed (42/42 aggregate), active Matrix/SFU abort/reset recovery, and exact-candidate 25/25 passive observation-mutation campaign for address, data, owner, WSTRB, and per-engine Done/missing/duplicate completion.
- Conv/depthwise and KV three-seed block regressions, FP two-seed 596/596 bit-exact regression, Matrix depth-4 and no-prefetch profile regressions, three-seed 45/45 Matrix size sweep, and three-seed 120/120 eight-configuration ablation.
- A 16-seed exact-candidate DMA/FP E2E run with real AXI stalls and response gaps, which closes the prior AR/AW/W SVA non-vacuity gap for that traffic profile.
- The current-source clean SHA replay adds 4,946 accepted writes and 5,256 checked words per top-UVM seed, with zero mismatch/unknown/stale/orphan responses; coordinated reset drops old AR/R and AW/W/B responses in the behavioral model and a post-reset recovery read passes.
- Current-source Matrix benchmarks pass 45/45 size points and 120/120 ablation points across seeds `20261025/26/27`; the production top measures serial, staged and four-task parallel cycle counts on the same real-engine workloads.

The current-source clean UVM compile uses VCS/URG `V-2023.12-SP1_Full64`; its log has zero `Warning-`, `Error-`, or `[TFIPC]` diagnostics and `engine_busy`/`engine_done` SVA ports are connected. Each of the three seed logs has UVM warning/error/fatal `0/0/0`, 4,946 accepted writes, 5,256 compared words, zero memory mismatch/unknown/stale/orphan responses, and focused compute covergroup `98.96%` (29/30). A separate top-smoke compile has one retained `[LOOP-REROLL-ENABLED]` workload-fixture warning; it is not an SVA disconnect.

## Assertion non-vacuity review

URG for the three-seed top UVM reports 22 assertion properties: 17 successes, 5 uncovered, no failures, and no incomplete attempts. All 14 compute-activity properties (two each for Scalar, CNM, Matrix, SFU, Conv, KV, and FP) have substantial real attempts and successes. The exact-candidate 16-seed mixed-precision DDR E2E run (R15) reports 20 successes, 2 without attempts, and zero failures/incomplete:

| Checker group | Observed result | Disposition |
|---|---|---|
| Engine activity/quiescence assertions | Real attempts and successes for all seven engines; zero failures | Non-vacuous for exercised operations. |
| AXI master AR/AW/W payload stability and 4KB burst bounds | Real successes in R15; these were uncovered in R14 | Closed for the seeded DMA/FP E2E transaction profile; not a proof across every AXI integration case. |
| UVM RAL assertions | Two checks have no attempts | Not relevant to this task’s compute datapath; leave uncovered. |
| Protocol cover properties | R15 AR/AW/W stall-to-accept hit 166/70/107 times | Non-vacuous for seeded DDR E2E traffic; broader requester/fault cross remains open. |

This shows that SVA ports are connected and there are no current omitted-port warnings. R15 closes the prior AXI assertion-antecedent gap for its actual DDR E2E traffic. Whole-top URG code percentages mix DUT, checker, testbench, and UVM; they are not reported as DUT-only closure.

## Required review outcomes

1. Review the dispositions and evidence paths for all 38 requirements in the RTM (24 PASS-SCOPED / 14 PARTIAL; no BLOCKED_SPEC or NOT_RUN).
2. SPEC v1.4 removes the Error ABI and priority specification blockers. Review the remaining P0 integration evidence gap for actual external-fabric reset compliance and non-FP drain/restart before CL-DV-v1.0 acceptance.
3. Keep the Matrix residual transition record bounded: retain raw default-profile 49/53, identify the separate prefetch-disabled edge, and retain the five-proposition formal assumptions and two reachability covers. Do not force illegal events to hit bins.
4. Current-source replay and selected supplemental campaigns are indexed as `R24`–`R29` in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md); exact commands, tool versions and selected raw-artifact hashes are in the [current-candidate replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md). R19 remains the bounded TinyNPU matched-workload run with its separate benchmark manifest.
5. Do not extend this Functional DV review into an overall NPU sign-off claim.

See the [remaining Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md) and [TinyNPU benchmark report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md).
