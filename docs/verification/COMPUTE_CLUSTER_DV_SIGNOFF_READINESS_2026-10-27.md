# Compute Cluster DV Sign-off Readiness — 2026-10-30

## Review decision (updated 2026-10-30)

**Selected product RTL/SPEC SHA:** `f916874a9ce60741a4516eaf9e33ebcae4a676c2`; latest verification/test SHA `2768843da1b3f3a0e988645746000d5befadf12b` (all-engine parity test and checker update; product RTL unchanged). R54 top test source is `f24c5383fad511c8b2e1132c1157942807994759`.\
**Current SPEC:** v1.7 freezes KV address alignment/overflow behavior; v1.6 freezes Scalar INT8 arithmetic order; v1.5 freezes the Matrix Line transfer contract.\
**Candidate classification:** bounded Functional DV review candidate; not CL-DV-v1.0 signed.\
**Product RTL:** the candidate preserves the earlier scoped Conv/KV/SFU error-code alignment and adds the KV 32-bit overflow/alignment guard.\
**Prior clean replay:** source SHA `6848a414eaeaa05cf9e1411cf55d9d27333208a6` was checked out detached at `/tmp/nmaforge_final_clean_6848a41`. VCS `V-2023.12-SP1_Full64` passed six seeds with 100% applicable focused compute testpoint coverage (29/29 URG variables); the write-only completion-read bin is explicitly excluded as N/A and checked for zero hits. That baseline passed 25/25 checker-sensitivity mutations, top smoke, trained Digits inference, 165/165 Matrix benchmark points and the pinned TinyNPU comparison. Evidence remains scoped to those tests and assumptions.

**2026-10-30 replay:** After license recovery, exact published closeout SHA `be78ee27b5a08783ec2560334ca1361baf382157` passed R50 clean six-seed Compute Cluster UVM and Top Smoke. Each UVM seed has 100% applicable focused testpoint coverage, 5,368 checked words, zero scoreboard mismatch/unknown/stale/orphan, and UVM warning/error/fatal `0/0/0`; Top Smoke reports `TEST PASS` after the 86-descriptor mapper precheck. R49 separately passes the corrected Matrix Line checker on three seeds, with 312 stable-stall observations per seed and reference-memory checks. R50's compute-only AR/AW stall-to-accept SVA cover bins remain at zero (W is one); prior R15 is the evidence for the full three-cover AXI E2E profile. One benign Top Smoke `LOOP-REROLL-ENABLED` fixture warning remains. See RTM R46–R50. These runs do not close the remaining partial requirements.

**2026-10-30 Scalar INT8 numeric closure:** R52 passes 13 legal independent Golden cases on each of three clean-worktree seeds at test commit `dde7806`, with 60 output words checked, read/write backpressure observed, and no compile warning/error/`[TFIPC]`. Only assigned activation values 0/1/2 are used. R51's reserved activation=3 bin is superseded and excluded. SPEC v1.6 and R52 close `OPEN-NUM-01` for common VDOT/GEMV/GEMM arithmetic semantics within this test scope. Legacy Conv and broader `REQ-CL-020` opcode/shape coverage remain PARTIAL. See the [R52 report](COMPUTE_CLUSTER_SCALAR_INT8_NUMERIC_R52.md).

**2026-10-30 KV address closure slice:** R53 at exact clean SHA `f916874` passes ten invalid-address/alignment cases and a legal final-SPAD-word round trip on three seeds. Every invalid case returns `ERR_CONFIG=1` before any SPAD request or side effect. KV DUT-only URG line/condition/FSM/branch is `100/98.77/73.33/96.97%`; four unhit transitions remain open without formal disposition. Top-level KV Protection-region denial and other Engine descriptor ranges remain open. Clean `ai_smoke` and 20-case seeded `ai_run` pass. See the [R53 report](COMPUTE_CLUSTER_KV_ADDRESS_R53.md).

**2026-10-30 KV Protection closure slice:** R54 at exact clean test SHA `f24c538` passes `make ai_smoke` and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`. The real top accepts one KV source read, denies the cache destination write through Protection, attributes the error to KV, commits completion status/error `2/7`, and preserves the destination sentinel. This closes only that KV Protection denial path; it does not close multi-requester ownership/fault crosses or the wider `REQ-PC-006`. See the [R54 report](COMPUTE_CLUSTER_KV_PROTECTION_R54.md).

**2026-10-30 final clean replay at `ded9d92`:** R55 replays real seven-engine top UVM on three seeds; every seed reports 100% applicable focused compute testpoints, 5,368 checked memory words, zero mismatch/unknown/stale/orphan response, reset-dropped=9, and UVM severity `0/0/0`. R56 catches 25/25 passive observation mutations. R57 passes Matrix depth-4 (18 Golden/layout + 35 fault/recovery cases/seed) and the Line stability checker records 312 samples/seed. R58 separately compiles prefetch off and hits the fallback in all three seeds across five workloads. Enabled-profile Matrix DUT-only URG is line/condition/FSM/branch `97.08/91.05/93.55/95.52%` (49/53 FSM); raw profile databases are not combined. R55 leaves three AXI AR/AW properties without real success in this compute-only run and two RAL properties without attempts. See the [R55–R58 report](COMPUTE_CLUSTER_CLEAN_REPLAY_R55_R58_2026-10-30.md).

**2026-10-30 exact-clean top smoke at `ded9d92`:** R59 passes `make ai_smoke` and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`; both replay the real-top KV Protection denial, completion `2/7`, source/destination sentinels, and recovery. The existing fixture `LOOP-REROLL-ENABLED` warning remains. See the [R59 report](COMPUTE_CLUSTER_TOP_SMOKE_REPLAY_R59_2026-10-30.md).

**2026-10-30 all-engine parity clean replay at `2768843`:** R60 extends seeded parity read fault coverage to 18 cases/seed across INT8, Matrix, CNM, BF16, SFU, Conv and KV, with all CNM lanes represented. Three clean seeds pass with UVM severity `0/0/0`, 5,445 checked words, and zero mismatch/unknown/orphan responses; 25/25 passive observation mutations, Top Smoke and the 20-case top regression also pass. The focused applicable compute testpoint group is 100%, but legal fault × phase × Abort/Reset coverage remains incomplete. Merged URG retains five uncovered assertions (three compute-profile AR/AW properties without real success and two UVM RAL checks without attempts). See the [R60 report](COMPUTE_CLUSTER_ALL_ENGINE_PARITY_R60_2026-10-30.md).

| Gate | Readiness | Evidence and remaining gate |
|---|---|---|
| **CL-RC1 — Matrix + SPAD dataflow** | **Ready for bounded review** | Current candidate R42 passes 45/45 size-sweep and 120/120 eight-way ablation points over three seeds. The Matrix FSM raw enabled-profile result remains 49/53; three guard/invariant edges have scoped formal disposition and the fallback edge is tested in the separate prefetch-disabled build. SPEC v1.5 freezes full-strobe Line writes and scalar fallback; R49 passes the scoped Line handshake/output checks on three seeds. |
| **CL-RC2 — seven-engine Cluster** | **Ready for bounded evidence review; not fully closed** | Exact clean R55 at `ded9d92` replays seven-engine top UVM on three seeds with memory scoreboard and 100% applicable focused testpoints; R56 catches 25/25 checker-sensitivity mutations; R57/R58 replay Matrix depth-4 and prefetch-off fallback. R60 at `2768843` adds 18 all-engine parity read cases per seed; R64 at `cc35783` adds all-engine source-A Protection denial; R65 at `2ab887a` adds 19/seed source-A, selected source-B and writeback denial checks. R65 passes clean three-seed UVM, Top Smoke and seeded top regression. R32/R55 reset each real engine after an accepted SPAD read; R/B reset/recovery remain bounded to a behavioral responder; SPEC v1.4 freezes Error ABI/priority/prefix. RTM remains 24 PASS-SCOPED, 14 PARTIAL, 0 BLOCKED_SPEC, 0 NOT_RUN. The dispatcher all-pair overlap test still uses behavioral Engine agents. |
| **CL-DV-v1.0 — defined Functional DV scope** | **HOLD** | No unresolved Error ABI/priority or Matrix Line contract question remains; R49 closes the scoped Line checker and R53 closes the KV overflow/alignment slice. R64/R65 add clean-SHA all-engine Protection evidence for source-A and selected source-B/writeback phases. P0 integration/evidence gap `OPEN-CL-003` for actual external-fabric qualification, legal Engine × Fault × Phase × Reset crosses, remaining descriptor contracts, and other partial requirements prevent full closure. Formal results disposition selected Matrix guards; they do not claim all 53 transitions or every parameter profile. |
| **Whole NPU sign-off / ASIC PPA / pretrained model deployment** | **Out of this review** | Full DMA/CMDQ/compute/CPLQ system closure, current PPA, and pretrained GPT-2/Qwen deployment are not necessary to review the defined Cluster functional slice, and are not claimed here. |

## Version and history review

- Prior reviewed candidate source is `6848a41`; follow-up product/SPEC is `f916874`, R54 top-test source is `f24c538`, and latest review harness SHA is `ded9d92`. The prior candidate scopes `PACK_I8_TILE_A` descriptor validation to opcode `0x36`; the correction was caught by a clean-seed launch-field regression and then passed six seeds. R53/R54 and R55–R58 are exact-clean evidence for their named slices; they do not replay every historical numeric, benchmark, external-fabric or model campaign at the latest SHA.
- R14–R39 remain useful historical/supplemental evidence for their identified source versions. R40–R45 add exact-clean-current-SHA UVM, mutation, Matrix/TinyNPU benchmark, top smoke and trained Digits inference evidence. R32 adds a separate all-engine accepted-read reset sweep, and R19 uses earlier product RTL with local benchmark-only additions and a pinned TinyNPU reference.
- SPEC v1.1 freezes the 38 `REQ-CL`/`REQ-PC` contracts; v1.2 defines coordinated reset/epoch expectations; v1.3 freezes SFU integer arithmetic; v1.4 freezes seven-engine Error ABI, simultaneous-fault priority and accepted-write prefix; v1.5 freezes the Matrix Line contract; v1.6 freezes Scalar INT8 arithmetic order and saturation; v1.7 freezes KV word alignment/address overflow. `OPEN-CL-006/007` and the Line contract question are closed; R49 closes its scoped checker execution. R32 supplies accepted-read reset evidence for every real top engine; R50 closes the published-snapshot replay. R52 closes `OPEN-NUM-01` within the tested legal common arithmetic scope; R53/R54 narrow `OPEN-CL-002` for KV overflow/alignment and one top-level Protection denial path, while other descriptor and ownership/fault tests remain open. `OPEN-CL-003`, broader opcode/shape and legal fault-cross coverage remain open. A frozen SPEC is not requirement verification closure.
- The original `READY` rows in the UVM Testplan remain planning/status-history and are not execution evidence; use the RTM run IDs and artifacts below.

## Verification evidence review

The controlling detailed record is the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). Its evidence includes:

- Historical three-seed real-top tests on the earlier source, with independent result/completion checks and a byte-addressed accepted-transaction SPAD model. The selected current candidate is separately replayed in R40 on six seeds.
- Selected Matrix/CNM concurrent tag and lane ownership (`Matrix tag=3`, `CNM tag=5`, CNM lane mask `1111`), shared read-only Scalar/SFU test, and descriptor latching test.
- Request stability observations across seven engines and four CNM lanes. The selected top UVM has no Matrix line-write stall samples; that bin remains open.
- The earlier R40 selected 14-case parity cross per seed (42/42 aggregate), active Matrix/SFU abort/reset recovery, and exact-candidate 25/25 passive observation-mutation campaign; R60 extends the parity slice to 18 cases per seed for address, data, owner, WSTRB, and per-engine Done/missing/duplicate completion.
- Conv/depthwise and KV three-seed block regressions, FP two-seed 596/596 bit-exact regression, Matrix depth-4 and no-prefetch profile regressions, three-seed 45/45 Matrix size sweep, and three-seed 120/120 eight-configuration ablation.
- R31 real CNM + DMA/SPAD subsystem: three seeds plus a directed delayed-reset run; CNM abort/read-drain/recovery, reset during accepted-read and prewrite phases, four-lane parity under DMA contention, parity during DMA abort plus shared reset, and 16/64/300-cycle AXI RREADY stress. Merged URG hits 100% of the 14 functional groups in this subsystem-only campaign; this is not full-Cluster functional coverage or DUT code coverage.
- R32 clean test-commit replay: seeds `20261025/26/27`; all seven real engines were reset after an accepted SPAD read. Each seed has 5,094 accepted writes, 5,368 checked words, zero mismatch/unknown/stale/orphan, `reset_dropped=9`, and UVM severity `0/0/0`. Focused compute coverage marker is `99.0%` (rounded), with completion read-response still architecturally N/A.
- R40 clean coverage replay: seeds `20261025/26/27/29/30/31` each report 100.0% applicable focused compute coverage; merged URG covers the six runs. The completion-read bin is excluded/N/A and checked to remain zero; DMA response-client is hit. Each seed retains 5,094 accepted writes, 5,368 checked words, zero mismatch/unknown/stale/orphan, and UVM severity `0/0/0`.
- A 16-seed exact-candidate DMA/FP E2E run with real AXI stalls and response gaps, which closes the prior AR/AW/W SVA non-vacuity gap for that traffic profile.
- R40 current-candidate clean SHA replay checks 5,368 words per top-UVM seed, with zero mismatch/unknown/stale/orphan responses. Coordinated behavioral AXI reset/recovery remains covered by the separately identified R27 evidence.
- Current-candidate Matrix benchmarks pass 45/45 size points and 120/120 ablation points across seeds `20261029/30/31`; R40 records production top serial, staged and four-task parallel cycle counts on the same real-engine workloads.

R40's current-candidate clean UVM compile uses VCS/URG `V-2023.12-SP1_Full64`, with no `Warning-`, `Error-` or `[TFIPC]` diagnostics; `engine_busy`/`engine_done` SVA ports are connected. Each of six seeds has UVM warning/error/fatal `0/0/0`, 5,094 accepted writes, 5,368 compared words, zero memory mismatch/unknown/stale/orphan responses, and 100% applicable focused testpoint coverage (URG 29/29 variables). The completion read-response bin is explicitly excluded as N/A and checked to remain zero. A separate top-smoke compile has one retained `[LOOP-REROLL-ENABLED]` workload-fixture warning; it is not an SVA disconnect.

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

1. Review the dispositions and evidence paths for all 38 requirements in the RTM (24 PASS-SCOPED / 14 PARTIAL; no BLOCKED_SPEC or NOT_RUN); R55–R58 add exact-clean test evidence but do not promote partial requirements.
2. SPEC v1.4 removes the Error ABI and priority specification blockers. Review the remaining P0 integration evidence gap for actual external-fabric reset compliance; R32 now covers accepted-read reset on every real top engine, while abort/fault phase crosses remain partial.
3. Keep the Matrix residual transition record bounded: retain raw default-profile 49/53, identify the separate prefetch-disabled edge, and retain the five-proposition formal assumptions and two reachability covers. Do not force illegal events to hit bins.
4. Current-source replay and selected supplemental campaigns are indexed as `R24`–`R45` in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md); exact commands, tool versions and run paths are recorded there. Current Matrix/TinyNPU results are in the [benchmark report](../benchmark/NMAFORGE_VS_TINY_NPU.md).
5. Do not extend this Functional DV review into an overall NPU sign-off claim.

See the [remaining Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md) and [current TinyNPU benchmark report](../benchmark/NMAFORGE_VS_TINY_NPU.md).
