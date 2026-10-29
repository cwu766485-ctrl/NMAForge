# Compute Cluster DV Sign-off Readiness — 2026-10-28

## Review decision (updated 2026-10-28)

**Selected review candidate source SHA:** `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`.\
**Candidate classification:** bounded Functional DV review candidate; not CL-DV-v1.0 signed.\
**Product RTL:** this candidate includes scoped Conv/KV/SFU error-code alignment to SPEC v1.4 and targeted checker/test updates; it is not an RTL-unchanged documentation-only commit.\
**Clean replay:** the exact source SHA was checked out detached at `/tmp/nmaforge_closure_9d9e0f_clean`. Testbench commit `cb9717eb853dc507f4a7e4d188c7bd840160c955` was replayed from a clean worktree; it changes only coverage classification and the regression gate, while product RTL/SPEC remain at the selected source candidate. VCS `V-2023.12-SP1_Full64` passed three seeds with 100% applicable focused compute testpoint coverage (29/29 URG variables); the write-only completion-read bin is explicitly excluded as N/A and checked for zero hits. The prior clean evidence includes the seven-engine accepted-read reset sweep, coordinated behavioral AXI R/B reset, 25/25 checker-sensitivity mutations, Matrix benchmark replays, and VC Formal `V-2023.12-SP2` proofs of 5/5 non-vacuous legal Matrix properties. Evidence remains bounded to those tests and assumptions.

| Gate | Readiness | Evidence and remaining gate |
|---|---|---|
| **CL-RC1 — Matrix + SPAD dataflow** | **Ready for bounded review** | Current-SHA size sweep passes 45/45 and eight-way ablation passes 120/120 over three seeds. The Matrix FSM raw enabled-profile result remains 49/53; three guard/invariant edges have scoped formal disposition and the fallback edge is tested in the separate prefetch-disabled build. Line WSTRB partial-write semantics/coverage remain open. |
| **CL-RC2 — seven-engine Cluster** | **Ready for bounded evidence review; not fully closed** | Current-SHA clean seven-engine UVM passes three seeds with memory scoreboard; R32 resets every real engine after an accepted SPAD read; R33 closes the focused group at 100% applicable bins; 25/25 checker-sensitivity mutations pass; R/B reset and recovery pass against a behavioral responder; and SPEC v1.4 freezes Error ABI/priority/prefix. RTM status is 24 PASS-SCOPED, 14 PARTIAL, 0 BLOCKED_SPEC, 0 NOT_RUN. The dispatcher all-pair overlap test still uses behavioral Engine agents. |
| **CL-DV-v1.0 — defined Functional DV scope** | **HOLD** | No unresolved Error ABI/priority spec blocker remains. P0 integration/evidence gap `OPEN-CL-003` for actual external-fabric qualification, legal Engine × Fault × Phase × Reset crosses, Matrix Line WSTRB, and remaining partial requirements prevent full closure. Formal results disposition selected Matrix guards; they do not claim all 53 transitions or every parameter profile. |
| **Whole NPU sign-off / ASIC PPA / pretrained model deployment** | **Out of this review** | Full DMA/CMDQ/compute/CPLQ system closure, current PPA, and pretrained GPT-2/Qwen deployment are not necessary to review the defined Cluster functional slice, and are not claimed here. |

## Version and history review

- Selected candidate source is `9d9e0f0`; the preceding evidence baseline was `c0832e5`. Commit `9d9e0f0` changes RTL error constants in Conv/KV/SFU to match the v1.4 cause table and adds directed checker tests. Current evidence replay used the exact commit in a detached clean worktree; the follow-on evidence report commit changes only documentation.
- Earlier runs R14–R23 remain useful historical evidence; R24–R31 add current-source priority/error tests, clean top UVM, mutation, coordinated reset, Matrix and CNM/DMA-SPAD accepted-read drain/recovery, formal guards, Matrix benchmarks and RREADY stall stress. R32 adds a clean three-seed all-engine accepted-read reset sweep with testbench-only changes. R19 uses the prior candidate's product RTL with local benchmark-only TB additions and a pinned TinyNPU reference.
- SPEC v1.1 freezes the 38 `REQ-CL`/`REQ-PC` contracts; v1.2 defines coordinated reset/epoch expectations; v1.3 freezes SFU integer arithmetic; v1.4 freezes seven-engine Error ABI, simultaneous-fault priority and accepted-write prefix. `OPEN-CL-006/007` are closed as specification issues. R32 now supplies accepted-read reset evidence for every real top engine; `OPEN-CL-003` remains for target external-fabric qualification. `OPEN-CL-002/004`, scalar `OPEN-NUM-01`, and legal fault cross coverage remain open. A frozen SPEC is not requirement verification closure.
- The original `READY` rows in the UVM Testplan remain planning/status-history and are not execution evidence; use the RTM run IDs and artifacts below.

## Verification evidence review

The controlling detailed record is the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). Its evidence includes:

- Three-seed real-top tests for the seven production engines, with independent result/completion checks and a byte-addressed accepted-transaction SPAD model. Per seed: 4,946 accepted writes, 5,256 compared words, and zero memory mismatches, unknown reads, stale epochs, or orphan responses.
- Selected Matrix/CNM concurrent tag and lane ownership (`Matrix tag=3`, `CNM tag=5`, CNM lane mask `1111`), shared read-only Scalar/SFU test, and descriptor latching test.
- Request stability observations across seven engines and four CNM lanes. The selected top UVM has no Matrix line-write stall samples; that bin remains open.
- A selected 14-case parity cross per seed (42/42 aggregate), active Matrix/SFU abort/reset recovery, and exact-candidate 25/25 passive observation-mutation campaign for address, data, owner, WSTRB, and per-engine Done/missing/duplicate completion.
- Conv/depthwise and KV three-seed block regressions, FP two-seed 596/596 bit-exact regression, Matrix depth-4 and no-prefetch profile regressions, three-seed 45/45 Matrix size sweep, and three-seed 120/120 eight-configuration ablation.
- R31 real CNM + DMA/SPAD subsystem: three seeds plus a directed delayed-reset run; CNM abort/read-drain/recovery, reset during accepted-read and prewrite phases, four-lane parity under DMA contention, parity during DMA abort plus shared reset, and 16/64/300-cycle AXI RREADY stress. Merged URG hits 100% of the 14 functional groups in this subsystem-only campaign; this is not full-Cluster functional coverage or DUT code coverage.
- R32 clean test-commit replay: seeds `20261025/26/27`; all seven real engines were reset after an accepted SPAD read. Each seed has 5,094 accepted writes, 5,368 checked words, zero mismatch/unknown/stale/orphan, `reset_dropped=9`, and UVM severity `0/0/0`. Focused compute coverage marker is `99.0%` (rounded), with completion read-response still architecturally N/A.
- R33 clean coverage replay at testbench commit `cb9717e`: seeds `20261025/26/27` each report 100.0% applicable focused compute coverage; merged URG is 29/29 variables, including 5/5 applicable response-client bins. The completion-read bin is listed as excluded/N/A and checked to remain zero; DMA response-client is hit. Each seed retains 5,094 accepted writes, 5,368 checked words, zero mismatch/unknown/stale/orphan, and UVM severity `0/0/0`.
- A 16-seed exact-candidate DMA/FP E2E run with real AXI stalls and response gaps, which closes the prior AR/AW/W SVA non-vacuity gap for that traffic profile.
- The current-source clean SHA replay adds 4,946 accepted writes and 5,256 checked words per top-UVM seed, with zero mismatch/unknown/stale/orphan responses; coordinated reset drops old AR/R and AW/W/B responses in the behavioral model and a post-reset recovery read passes.
- Current-source Matrix benchmarks pass 45/45 size points and 120/120 ablation points across seeds `20261025/26/27`; the production top measures serial, staged and four-task parallel cycle counts on the same real-engine workloads.

The current-source clean UVM compile uses VCS/URG `V-2023.12-SP1_Full64`; R32 elaboration reports zero errors/warnings, no `[TFIPC]` or `Warning-`/`Error-` diagnostics, and `engine_busy`/`engine_done` SVA ports are connected. R33's clean compile likewise has no `Warning-`, `Error-` or `[TFIPC]` diagnostics. Each R33 seed has UVM warning/error/fatal `0/0/0`, 5,094 accepted writes, 5,368 compared words, zero memory mismatch/unknown/stale/orphan responses, and 100% applicable focused testpoint coverage (URG 29/29 variables). The completion read-response bin is explicitly excluded as N/A and checked to remain zero. A separate top-smoke compile has one retained `[LOOP-REROLL-ENABLED]` workload-fixture warning; it is not an SVA disconnect.

## Assertion non-vacuity review

URG for the three-seed top UVM reports 22 assertion properties: 17 successes, 5 uncovered, no failures, and no incomplete attempts. All 14 compute-activity properties (two each for Scalar, CNM, Matrix, SFU, Conv, KV, and FP) have substantial real attempts and successes. The exact-candidate 16-seed mixed-precision DDR E2E run (R15) reports 20 successes, 2 without attempts, and zero failures/incomplete:

R32's merged URG keeps the same bounded disposition: 17/22 properties have
real successes and zero fail/incomplete; the five uncovered include three AXI
AR/AW properties that are not successfully exercised by this compute-only
sequence and two UVM RAL properties with no attempts. R15 supplies real
successes for the AXI AR/AW/W payload/burst properties and its AR/AW/W
stall-to-accept covers. The R32 clean compile reports zero elaboration
warnings/errors and no `[TFIPC]` diagnostic; the compute activity SVA ports
remain connected and active. The RAL properties remain out of this compute
datapath scope.

| Checker group | Observed result | Disposition |
|---|---|---|
| Engine activity/quiescence assertions | Real attempts and successes for all seven engines; zero failures | Non-vacuous for exercised operations. |
| AXI master AR/AW/W payload stability and 4KB burst bounds | Real successes in R15; these were uncovered in R14 | Closed for the seeded DMA/FP E2E transaction profile; not a proof across every AXI integration case. |
| UVM RAL assertions | Two checks have no attempts | Not relevant to this task’s compute datapath; leave uncovered. |
| Protocol cover properties | R15 AR/AW/W stall-to-accept hit 166/70/107 times | Non-vacuous for seeded DDR E2E traffic; broader requester/fault cross remains open. |

This shows that SVA ports are connected and there are no current omitted-port warnings. R15 closes the prior AXI assertion-antecedent gap for its actual DDR E2E traffic. Whole-top URG code percentages mix DUT, checker, testbench, and UVM; they are not reported as DUT-only closure.

R31's separate DMA/SPAD subsystem URG reports 28/31 assertion properties with
real successes, zero failures and zero incomplete attempts. One property,
`ap_banked_response_tag`, has no real success because this subsystem harness
does not instantiate a Matrix/banked requester; this is a harness scope gap,
not evidence that the property is proven. Two UVM RAL properties have no
attempts and are outside this subsystem's compute protocol. The connected
Matrix/CNM top owner checks and Matrix block read metadata tests are tracked
separately in the RTM.

## Required review outcomes

1. Review the dispositions and evidence paths for all 38 requirements in the RTM (24 PASS-SCOPED / 14 PARTIAL; no BLOCKED_SPEC or NOT_RUN).
2. SPEC v1.4 removes the Error ABI and priority specification blockers. Review the remaining P0 integration evidence gap for actual external-fabric reset compliance; R32 now covers accepted-read reset on every real top engine, while abort/fault phase crosses remain partial.
3. Keep the Matrix residual transition record bounded: retain raw default-profile 49/53, identify the separate prefetch-disabled edge, and retain the five-proposition formal assumptions and two reachability covers. Do not force illegal events to hit bins.
4. Current-source replay and selected supplemental campaigns are indexed as `R24`–`R32` in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md); exact commands, tool versions and selected raw-artifact hashes are in the [current-candidate replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md). R19 remains the bounded TinyNPU matched-workload run with its separate benchmark manifest.
5. Do not extend this Functional DV review into an overall NPU sign-off claim.

See the [remaining Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md) and [TinyNPU benchmark report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md).
