# NMAForge Compute Cluster v1.0 Functional DV Sign-off Report

**Review date:** 2026-10-30  
**Decision:** **HOLD — not signed off**  
**Scope:** Compute Cluster functional DV only; no claim of whole-NPU sign-off or ASIC PPA closure.

## Version and evidence baseline

| Item | Frozen identity |
|---|---|
| Product RTL/SPEC candidate | `9d4e9abdba1f745644a485960620fa6bbc4979db` (R73; SPEC v1.8 busy-time CPLQ_HEAD contract) |
| Latest real-top descriptor-latch SHA | `3fdb22640dc8b3c73e9ff05d3b07c6f0e3e67a28` (R77 SFU descriptor-latch test; Matrix R74 remains separately evidenced) |
| Latest exact clean code/test SHA | `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907` (R80 production MUX-to-arbiter fairness/response follow-up) |
| Prior reviewed product baseline | `6848a414eaeaa05cf9e1411cf55d9d27333208a6` |
| Latest published closeout snapshot before this follow-up | `fc370aad6b8360af9affb52cb30909ec97d79be3` |
| Review branch | `work/compute-cluster-kv-overflow-20261030` |
| Evidence/test commit | R53 `f916874a9ce60741a4516eaf9e33ebcae4a676c2`; R54 `f24c5383fad511c8b2e1132c1157942807994759`; R55–R58/R59 `ded9d923a432e869592ec8710a22df5501d8d474`; R60 `2768843da1b3f3a0e988645746000d5befadf12b`; R73 `9d4e9abdba1f745644a485960620fa6bbc4979db`; R74 `519ca161f3c2ce8beab78161a88bbdcb6cbcdc61`; R75 `969992291732cf694d7de4bdfef2808d4f017d57`; R77 `3fdb22640dc8b3c73e9ff05d3b07c6f0e3e67a28`; R80 `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907` |
| SPEC | Compute Cluster SPEC v1.8; R73 records busy-time CPLQ_HEAD progress; earlier KV address overflow/alignment is frozen in v1.7 |
| VCS | Synopsys VCS `V-2023.12-SP1_Full64`; R49 passed the corrected Matrix checker on three seeds; R50 passed the published-snapshot six-seed UVM and Top Smoke; R52 passed the legal Scalar INT8 numeric campaign; R53 passed KV boundary checks; R75 passed the SFU block random regression on three seeds, with merged URG |

The review branch is isolated from the v2 research branch. R53 changes the KV product RTL to reject invalid 32-bit word addresses before SPAD access and adds its SPEC/test evidence. Earlier R40–R52 evidence retains its own exact source/test SHA relationships.

## Requirement disposition

The Execution RTM maps all 38 requirements (`REQ-CL-001..028`, `REQ-PC-001..010`) to test IDs, checkers, coverage, run IDs, seeds and evidence paths.

| Disposition | Count | Meaning |
|---|---:|---|
| PASS-SCOPED | 24 | Evidence passes only for the explicitly exercised scope |
| PARTIAL | 14 | Remaining cases or integration evidence are open |
| BLOCKED_SPEC | 0 | No unresolved specification blocker remains in the current frozen contract |
| NOT_RUN | 0 | Every requirement has a recorded disposition; this does not mean every test ran |

R46/R47 were historical `BLOCKED_ENV` attempts; R48 exposed a testbench coverage-counter reset issue; R49 resolves that issue for the scoped Matrix Line contract. R50 passes on its exact published closeout SHA. R52 passes 13 legal Scalar INT8 Golden cases on each of three clean-worktree seeds. R51's reserved-activation testpoint is superseded and excluded. R53 passes ten KV address/configuration rejection bins and the final legal SPAD word round trip on three clean-worktree seeds. R54 passes the real-top KV Protection-denial and completion slice; R59 repeats Top Smoke and the 20-case seeded top regression at clean harness SHA `ded9d92`. R55–R58 pass on the same detached clean harness: seven-engine UVM on three seeds, 25/25 observation mutations, Matrix depth-4 fault/recovery on three seeds, and separate prefetch-off fallback on three seeds. The overall 38-requirement disposition remains 24 PASS-SCOPED / 14 PARTIAL.

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
| SFU launch-parameter retention | R75 block-core GELU input mutation plus R77 real-top RMSNorm descriptor mutation during divider wait; independent Golden, completion and destination sentinel checks | R77 adds one legal top-level SFU descriptor-latch point, but other engines/fields and descriptor-boundary crosses remain open; `REQ-CL-005` stays PARTIAL |
| KV address and Protection | R53 checks ten invalid arithmetic/alignment classes per seed plus legal `0x7fffc` read/write; R54 checks a real-top Protection denial, KV owner/error completion, and sentinel preservation | SPEC v1.7 overflow/alignment slice is covered 11/11 per seed; R54 directed group passes 4/4 points. Raw KV FSM remains 11/15 transitions; broader ownership, stride/alias, and Engine descriptor contracts remain open |

## Clean replay status

The candidate SHA passed the previously recorded clean R40–R45 campaigns: six-seed seven-engine UVM, 25/25 checker-sensitivity mutations, 165/165 Matrix size/ablation checks, pinned TinyNPU paired cases, Top Smoke and Digits inference. Those passes remain valid for their named sources and scope.

The latest published closeout snapshot was checked out into a clean worktree. The initial R46 attempt was license-blocked; after license recovery R50 passed six UVM seeds and Top Smoke at that exact published SHA. R48 exposed a testbench aggregate-counter reset issue, fixed and verified by R49 on three seeds. R52 passed on a detached clean worktree fixed at test commit `dde7806`; it exercises only legal Scalar INT8 activation values and the common arithmetic path without changing product RTL. R51's reserved activation=3 bin is explicitly excluded. R53 passed at exact product/test/SPEC SHA `f916874`; R54 passed at top-test SHA `f24c538`; R55–R59 pass at detached clean harness SHA `ded9d92`. R59 repeats Top Smoke plus 20-case seeded top run and checks the KV Protection completion/sentinels. R60 passes at clean verification/test SHA `2768843`: 18/18 selected parity cases per seed for all seven engines, 25/25 checker-sensitivity mutations, Top Smoke and the 20-case top regression. R73 updates the busy-time CPLQ_HEAD contract in SPEC v1.8 and fixes the register lock. R74 adds the real-top Matrix descriptor parameter-latch case. R75 at exact clean code/test SHA `9699922` passes the SFU block random-latency regression on three seeds, including the new in-flight core-input mutation test and the aggregate block URG report; this is not a real-top descriptor test. R76 reruns the current exact SHA's top UVM, 28/28 checker-sensitivity, Top Smoke, 20-case top regression, behavioral AXI stall/reset E2E, and both Matrix benchmark suites. It improves replay evidence but does not change any RTM disposition or the HOLD decision. R55–R58 details, paths, seeds, scoreboard and URG/SVA dispositions are in the [R55–R58 report](COMPUTE_CLUSTER_CLEAN_REPLAY_R55_R58_2026-10-30.md); R59 logs are in the [Top Smoke report](COMPUTE_CLUSTER_TOP_SMOKE_REPLAY_R59_2026-10-30.md), R75 logs/URG are in the [R75 SFU report](COMPUTE_CLUSTER_SFU_PARAMETER_LATCH_R75_2026-10-30.md), and R76 logs/hashes/limits are in the [R76 report](COMPUTE_CLUSTER_CLEAN_REPLAY_R76_2026-10-30.md). R55 has three AXI AR/AW properties without real success in the compute-only profile and two RAL assertions without attempts; no failures/incomplete. Logs and commands are indexed in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md), [R52 numeric report](COMPUTE_CLUSTER_SCALAR_INT8_NUMERIC_R52.md), [R53 KV report](COMPUTE_CLUSTER_KV_ADDRESS_R53.md), and [R54 KV Protection report](COMPUTE_CLUSTER_KV_PROTECTION_R54.md).

R76 at the latest exact clean code/test SHA `969992291732cf694d7de4bdfef2808d4f017d57` passes the three-seed real-top UVM, 28/28 checker-sensitivity campaign, Top Smoke, 20-case seeded top run, behavioral AXI stall/reset E2E, 45/45 Matrix size checks, and 120/120 Matrix ablation points. It adds reproducibility evidence only: RTM remains 24 PASS-SCOPED / 14 PARTIAL and the decision remains HOLD. The behavioral responder run does not identify or qualify an external production fabric. See [R76 replay report](COMPUTE_CLUSTER_CLEAN_REPLAY_R76_2026-10-30.md).

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
- [R59 Top Smoke replay evidence](COMPUTE_CLUSTER_TOP_SMOKE_REPLAY_R59_2026-10-30.md)
- [R76 exact-candidate clean replay evidence](COMPUTE_CLUSTER_CLEAN_REPLAY_R76_2026-10-30.md)
- [R60 all-engine parity clean replay evidence](COMPUTE_CLUSTER_ALL_ENGINE_PARITY_R60_2026-10-30.md)
- [R75 SFU block-core parameter-latch evidence](COMPUTE_CLUSTER_SFU_PARAMETER_LATCH_R75_2026-10-30.md)
- [Compute Cluster SPEC v1.6](../spec/COMPUTE_CLUSTER_SPEC_ZH.md)
- [Verification matrix](../../dv/VERIFICATION_MATRIX.md)


## R77 exact-clean review update — 2026-10-30

R77's exact clean code/test SHA is `3fdb22640dc8b3c73e9ff05d3b07c6f0e3e67a28`; product RTL/SPEC remain byte-identical to product candidate `9d4e9abdba1f745644a485960620fa6bbc4979db`. R77 adds a real-top SFU RMSNorm descriptor-latch point and passes three-seed UVM, 28/28 checker-sensitivity, Top Smoke, 20-case seeded top, behavioral AXI stall/reset, 45/45 Matrix size and 120/120 Matrix ablation. The new evidence is scoped; RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. The behavioral responder does not qualify an external target fabric. See [R77 report](COMPUTE_CLUSTER_CLEAN_REPLAY_R77_2026-10-30.md) and the updated [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

R78 runs the standalone SPAD arbiter fairness target at the same exact code/test SHA: 10,000 cycles with 3,334 grants per client, maximum observed wait 2 cycles, directed CNM/DMA ownership checks and clean URG assertions. It does not demonstrate the full seven-engine fairness contract or downstream memory backpressure. `REQ-CL-014` remains PARTIAL; the 38-requirement table is still 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. See [R78 report](COMPUTE_CLUSTER_SPAD_FAIRNESS_R78_2026-10-30.md).

R79 at exact clean test SHA `a45864565ace4702783f5c5632c1f13a001c7653` exercises the production seven-client compute SPAD MUX for 4,096 cycles under deterministic bounded ready stalls. It observes 3,233 accepts with maximum wait 10 cycles/client and checks all 2,582 read responses for correct owner, payload and error routing; three SVA properties pass. Top Smoke with 20 random cases passes at the same SHA. R80 at exact clean code/test SHA `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907` composes the production MUX and scheduler arbiter for 4,096 cycles, checks 4,096 accepted requests and 3,465 read responses, and reaches all seven engine request owners. Maximum per-engine wait is 22 cycles; all three assertions and four cover properties pass. Exact-SHA Top Smoke with 20 random cases passes. The R80 setup uses behavioral engine clients and memory; it does not include production engine instances, SRAM subsystem/backpressure, protection, or completion-owner integration. `REQ-CL-014` remains PARTIAL and the overall v1.0 decision remains HOLD. See [R79 report](COMPUTE_CLUSTER_MUX_FAIRNESS_R79_2026-10-30.md) and [R80 report](COMPUTE_CLUSTER_SPAD_PATH_FAIRNESS_R80_2026-10-30.md).
