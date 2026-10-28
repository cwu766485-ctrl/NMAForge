# Compute Cluster DV Sign-off Readiness — 2026-10-28

## Review decision (updated 2026-10-28)

**Selected review candidate:** `c0832e5c822de1a03f82751d5ff8f831d0addb98` (`main`).\
**Candidate classification:** bounded Functional DV candidate; not CL-DV-v1.0 signed.\
**Product RTL:** no change in the candidate commit; `rtl/` is unchanged from its parent `fa2b4dd`. The candidate adds DV observation/checking code and updates evidence/status documents.\
**Clean replay:** completed for this exact SHA on 2026-10-27 after VCS licensing became available. The detached clean worktree compiled with VCS `V-2023.12-SP1_Full64`, passed the real-top Compute Cluster UVM regression on seeds `20261025/20261026/20261027`, and merged URG coverage. This confirms reproducibility for the selected top-UVM slice. R15 later closed the AXI SVA antecedent gap for its traffic profile; requirement, FSM, and broader fault-cross gaps remain.

| Gate | Readiness | Evidence and remaining gate |
|---|---|---|
| **CL-RC1 — Matrix + SPAD dataflow** | **Ready for bounded review** | Exact-candidate three-seed Matrix size sweep (45/45) and eight-way configuration ablation (120/120) complement the Golden/fault/recovery runs. Matrix FSM remains 49/53 transitions; R23 formally dispositions three legal guard paths under stated assumptions, while the compile-profile edge is covered in R4. Line WSTRB rules/partial writes remain open. |
| **CL-RC2 — seven-engine Cluster** | **Ready for bounded evidence review; not closed** | Exact-candidate real-top seven-engine UVM, memory image, checker-sensitivity mutations, supplemental 16-seed AXI E2E and SFU numeric edge campaign pass. R22 adds behavioral-responder R/B reset exclusion. AXI AR/AW/W assertion antecedents and cover properties are non-vacuous in R15. The 38-row RTM is now 24 PASS-SCOPED, 13 PARTIAL, 1 BLOCKED_SPEC. Dispatcher all-pair overlap still uses behavioral Engine agents. |
| **CL-DV-v1.0 — defined Functional DV scope** | **HOLD** | P0 spec blockers (`OPEN-CL-003`, `OPEN-CL-006`), partial/blocked requirements, Matrix Line WSTRB gaps, broad legal fault crosses and external-fabric qualification remain open. R23 is scoped formal evidence, not full FSM transition closure. These open items fail the “no unresolved P0 bug/spec blocker; all requirement evidence reviewed” exit gate. |
| **Whole NPU sign-off / ASIC PPA / pretrained model deployment** | **Out of this review** | Full DMA/CMDQ/compute/CPLQ system closure, current PPA, and pretrained GPT-2/Qwen deployment are not necessary to review the defined Cluster functional slice, and are not claimed here. |

## Version and history review

- HEAD at review: `c0832e5` → `fa2b4dd` → `c83ad74` → `f2457ef` → `f46e5a0` → `03bf257` → `a05e030` → `827c005`.
- Selected candidate is `c0832e5`; runtime-affecting changes are limited to DV monitor/sequence/Makefile/testbench files; product RTL is byte-identical to its parent. R14 is the SHA-stamped clean-worktree replay; R15–R18 ran from the same detached candidate source with no tracked source changes. R19 runs the candidate product RTL with local benchmark-only TB additions; TinyNPU was pinned separately and simulated with a documented functional primitive surrogate.
- `c83ad7463265062d4edb84d57fe4ada8195f9b10` is the detached clean worktree SHA for the focused 2026-10-27 Matrix/S2 campaign. Older fixed-SHA replay at `827c0052cf589fde676e93e34bf459188956182f` covers an earlier selected slice. R14 in the RTM now supplies the exact clean replay for selected candidate `c0832e5`.
- SPEC v1.1 freezes the 38 `REQ-CL`/`REQ-PC` contracts; v1.2 adds the coordinated reset/epoch boundary for accepted external AXI traffic; v1.3 freezes the documented SFU arithmetic contract, checked in R21. `OPEN-CL-003` remains for non-FP outstanding depth, Abort drain/restart and outstanding B-response exclusion; `OPEN-CL-002/004/006/007` and scalar-only `OPEN-NUM-01` also remain. A frozen SPEC is not the same as requirement verification closure.
- The original `READY` rows in the UVM Testplan remain planning/status-history and are not execution evidence; use the RTM run IDs and artifacts below.

## Verification evidence review

The controlling detailed record is the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). Its evidence includes:

- Three-seed real-top tests for the seven production engines, with independent result/completion checks and a byte-addressed accepted-transaction SPAD model. Per seed: 4,946 accepted writes, 5,256 compared words, and zero memory mismatches, unknown reads, stale epochs, or orphan responses.
- Selected Matrix/CNM concurrent tag and lane ownership (`Matrix tag=3`, `CNM tag=5`, CNM lane mask `1111`), shared read-only Scalar/SFU test, and descriptor latching test.
- Request stability observations across seven engines and four CNM lanes. The selected top UVM has no Matrix line-write stall samples; that bin remains open.
- A selected 14-case parity cross per seed (42/42 aggregate), active Matrix/SFU abort/reset recovery, and exact-candidate 25/25 passive observation-mutation campaign for address, data, owner, WSTRB, and per-engine Done/missing/duplicate completion.
- Conv/depthwise and KV three-seed block regressions, FP two-seed 596/596 bit-exact regression, Matrix depth-4 and no-prefetch profile regressions, three-seed 45/45 Matrix size sweep, and three-seed 120/120 eight-configuration ablation.
- A 16-seed exact-candidate DMA/FP E2E run with real AXI stalls and response gaps, which closes the prior AR/AW/W SVA non-vacuity gap for that traffic profile.

The exact-candidate clean UVM compile uses VCS/URG `V-2023.12-SP1_Full64`. Its compile log reports zero compile warnings/errors and no `[TFIPC]`; `engine_busy`/`engine_done` SVA ports are explicitly connected. Each of the three seed logs has UVM warning/error/fatal `0/0/0`, 4,946 accepted writes, 5,256 compared words, zero memory mismatch/unknown/stale/orphan responses, and focused compute covergroup `98.96%` (29/30). The separate top-smoke compile has one retained `[LOOP-REROLL-ENABLED]` warning in a workload fixture; it is documented and is not an SVA disconnect.

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

1. Review the dispositions and listed evidence paths for all 38 requirements in the RTM.
2. Resolve or formally disposition the P0 specification issues before CL-DV-v1.0 acceptance.
3. Keep the Matrix residual transition review bounded: the two compile-profile transitions are exercised in separate builds; two guard/invariant paths lack formal unreachable proof. Do not force illegal events to hit them.
4. The selected candidate SHA clean replay and named supplemental AXI, mutation, and Matrix benchmark campaigns are complete. R19 adds matched GEMM and lowered-convolution functional workloads with TinyNPU. Commands, seeds, artifacts, and assertion results are recorded as `R14`–`R19` in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md); R19 source/log checksums are in the [benchmark manifest](COMPUTE_CLUSTER_BENCHMARK_R19_MANIFEST_2026-10-28.md).
5. Do not extend this Functional DV review into an overall NPU sign-off claim.

See the [remaining Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md) and [TinyNPU benchmark report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md).
