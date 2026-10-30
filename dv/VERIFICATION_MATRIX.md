Warning: truncated output (original token count: 30845)
Total output lines: 1085

> **2026-10-30 R99 CNM Protection and selected memory-fabric reset:** At exact
> clean SHA `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, the full three-seed
> DMA/SPAD/CNM regression passes after aligning CNM Protection errors with the
> registered response. Selected source-A/source-B/destination-deny bins are
> 100%, storage is preserved, and UVM severity is 0/0/0. The user-selected
> in-repository `ai_accel_memory_fabric` reset target passes all three reset
> functional groups at 100% on seeds `20261025/26/27`, including pending owner
> flush and post-reset DMA/CNM recovery. Same-SHA Top Smoke and 20-case seeded
> Top pass. This closes only the selected reset evidence item; RTM remains
> 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See the
> [R99 report](../docs/verification/COMPUTE_CLUSTER_MEMORY_FABRIC_RESET_R99_2026-10-30.md).

> **2026-10-30 R90 descriptor validator boundaries:** At exact clean SHA
> `7837701cefe606a01abd517d46788b982da0f2e4`, VCS passes 27 supported opcode
> classifications, tile-pack and 21 invalid cases. This is validator/decode
> scope, not top-level CMDQ dispatch. [R90 report](../docs/verification/COMPUTE_CLUSTER_DESCRIPTOR_VALIDATOR_R90_2026-10-30.md).

> **2026-10-30 R89 Matrix configuration benchmark:** At R88 code/test SHA
> `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec`, VCS passes 40/40 Golden cases
> across eight Depth/Prefetch/A-Cache configurations and five workloads with a
> one-cycle behavioral bank model. Full report and checked-in CSV:
> [R89 benchmark](../docs/benchmark/COMPUTE_CLUSTER_MATRIX_BENCHMARK_R89_2026-10-30.md).

> **2026-10-30 R88 Matrix aligned Line Abort prefix:** At exact clean SHA
> `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec`, three real-top UVM seeds accept
> six of 16 aligned 128-bit Line writes (24/64 Golden output words) before
> Abort; full WSTRB, line address/data, untouched suffix, 5/5 read drain and
> `ERR_ABORT` pass. Each scoreboard checks 17,388 words with zero mismatch,
> unknown or stale response and UVM severity 0/0/0. Same-SHA Top Smoke,
> 20-case seeded Top, and passive checker sensitivity 28/28 pass. This scoped
> point does not close global prefix/fault crosses; RTM stays 24 PASS-SCOPED /
> 14 PARTIAL and CL-DV-v1.0 HOLD. See the
> [R88 report](../docs/verification/COMPUTE_CLUSTER_MATRIX_LINE_ABORT_WRITE_PREFIX_R88_2026-10-30.md).

Warning: truncated output (original token count: 30169)
Total output lines: 1035

> **2026-10-30 R87 Regression output-path reproducibility:** At exact clean
> test SHA `402c8ce4689ae48cfee624f1f5fdca66d534bbbf`, the default three-seed
> Compute Cluster UVM regression and 28/28 passive checker-sensitivity campaign
> share a stable Make run stamp and pass; same-SHA Top Smoke prints `TEST PASS`.
> This is harness-only evidence, does not add a functional testpoint, and leaves
> the RTM at 24 PASS-SCOPED / 14 PARTIAL with CL-DV-v1.0 HOLD. See the
> [R87 report](../docs/verification/COMPUTE_CLUSTER_REGRESSION_PATH_STABILITY_R87_2026-10-30.md).

Warning: truncated output (original token count: 40096)
Total output lines: 1139

> **2026-10-30 R86 Matrix scalar-fallback accepted-write Abort prefix:** At exact clean
> verification/test SHA `3d6fe5c58631bdeb6333b6e3572f24eeba7da1ef`, three real-top UVM seeds abort a 4×4 GEMM
> after six of 16 accepted scalar output writes to a legal word-aligned,
> non-16-byte-aligned destination. The Golden prefix and ten sentinels pass,
> eight accepted banked reads drain, no Line request is used, and completion is
> `ERR_ABORT`; the scoreboard checks 17,352 words/seed with zero
> mismatch/unknown/stale response and UVM severity 0/0/0. Same-SHA Top Smoke,
> 20-case seeded top regression, and 28/28 passive checker-sensitivity mutations
> pass. This is one scalar-fallback point, not aligned Line or global prefix
> closure; RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 HOLD. See the
> [R86 report](../docs/verification/COMPUTE_CLUSTER_MATRIX_ABORT_WRITE_PREFIX_R86_2026-10-30.md).

> **2026-10-30 R85 Conv accepted-write Abort prefix:** At exact clean
> verification/test SHA `5a35d60d20ee6fc6622e46f92d05fc1ef00dd14d`, three real-top UVM seeds abort a Conv 3×3
> task after its first accepted output write. Each checks a one-word Golden
> prefix, three unchanged suffix sentinels, 21/21 accepted reads drained, and
> `ERR_ABORT`; the scoreboard checks 17,304 words/seed with zero
> mismatch/unknown/stale response and UVM severity 0/0/0. Same-SHA Top
> Smoke prints `TEST PASS` with the existing fixture warning. This is one
> Conv timing point, not all-engine/all-prefix closure; RTM remains 24 PASS-SCOPED
> / 14 PARTIAL and CL-DV-v1.0 HOLD. See the [R85 report]
> (../docs/verification/COMPUTE_CLUSTER_CONV_ABORT_WRITE_PREFIX_R85_2026-10-30.md).

# NMAForge block and subsystem verification matrix

> **2026-10-30 R101 full Compute Cluster replay:** At exact tested tree
> `94a3797dfea4d9011ab16ab4d3877244f0a6aafe` (R100 documentation-only
> descendant of code/test SHA `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`),
> the real-top Cluster UVM passes three seeds with 100% applicable focused
> testpoints, 26,451 memory words/seed and zero mismatch/unknown/stale/orphan
> responses. UVM warning/error/fatal is 0/0/0. The 28-case passive checker
> sensitivity campaign passes at the same source tree. Compute-only URG has
> 17/22 assertion properties with real successes and zero failure/incomplete;
> two UVM RAL assertions have no attempts, three top AXI AR/AW assertions have
> attempts but no real success, and only the W stall cover matches in this
> workload. RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 HOLD. See
> [R101 evidence](../docs/verification/COMPUTE_CLUSTER_CLEAN_REPLAY_R101_2026-10-30.md).

> **2026-10-30 R84 SFU accepted-write Abort prefix:** At exact clean
> verification/test SHA `8bc2ee28725d09ac75ecfcb0417e1ba47fd688f2`, three real-top UVM seeds abort the SFU
> GELU task after its first accepted output write. Each checks a one-word
> Golden prefix, 63 untouched output sentinels, 2/2 accepted reads drained,
> and `ERR_ABORT`; the scoreboard checks 17,267 words with zero
> mismatch/unknown/stale response and UVM severity 0/0/0. Same-SHA Top
> Smoke prints `TEST PASS` with the existing fixture warning. This is one
> SFU timing point, not all-engine prefix closure; RTM remains 24 PASS-SCOPED
> / 14 PARTIAL and CL-DV-v1.0 HOLD. See the [R84 report]
> (../docs/verification/COMPUTE_CLUSTER_SFU_ABORT_WRITE_PREFIX_R84_2026-10-30.md).

> **2026-10-30 R83 all-engine accepted-read Abort/drain:** At exact clean
> verification/test SHA `071578d997d69ebf011fe5e7d4742fae3e0f73ac`, three
> VCS seeds each abort Scalar INT8, FP, CNM, Matrix, SFU, Conv and KV after a
> real SPAD read is accepted. All 21/21 cases complete with `ERR_ABORT=0x32`,
> accepted reads equal returned responses, and every engine drains idle. The
> independent scoreboard checks 17,249 words/seed with zero mismatch,
> unknown, stale-epoch or orphan responses; UVM severity is 0/0/0. This closes
> only the directed accepted-read Abort/drain point. Full legal fault/phase/
> reset crosses and external-fabric reset qualification remain open; status is
> still 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 HOLD. See the [R83 replay
> report](../docs/verification/COMPUTE_CLUSTER_ALL_ENGINE_ABORT_R83_2026-10-30.md)
> and [Execution RTM](../docs/verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

> **2026-10-30 current review addendum:** Product RTL baseline is
> `6848a414eaeaa05cf9e1411cf55d9d27333208a6`; SPEC v1.5 freezes the current
> Matrix Line behavior (aligned full WSTRB, scalar fallback, and no partial or
> zero WSTRB). The new `MATRIX-LINE-001` checker enforces Line alignment,
> strobe, stall stability, fallback, and protection error behavior. Its
> first final-source VCS run exposed a testbench counter reset issue (RTM R48);
> the corrected three-seed replay passes R49 with 312 stall-stability checks per
> seed and reference-memory checks. Published closeout SHA
> `be78ee27b5a08783ec2560334ca1361baf382157` now passes a six-seed clean UVM
> replay and Top Smoke (R50): 100% applicable focused coverage per seed,
> 5,368 checked memory words with zero mismatch, and `TEST PASS`. R49
> is the latest Matrix Line PASS evidence; R50 validates the published snapshot
> but does not change the overall Compute Cluster status of
> 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 remains
> HOLD; see the [current Execution RTM](../docs/verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

> **2026-10-30 KV address contract addendum:** Candidate SHA `f916874` adds
> SPEC v1.7 validation for 32-bit KV byte-address overflow and word alignment.
> Clean VCS R53 passes ten invalid-address/alignment cases and the legal final
> SPAD word read/write boundary on three seeds; every invalid descriptor is
> rejected before SPAD access. KV DUT-only URG line/condition/FSM/branch is
> `100.00/98.77/73.33/96.97%`; four raw FSM transitions remain without a
> reachability disposition. The KV top-level Protection-region denial and
> other Engine descriptor contracts remain open. See the [R53 evidence](../docs/verification/COMPUTE_CLUSTER_KV_ADDRESS_R53.md).

> **2026-10-30 KV Protection addendum:** DV-only top-test SHA `f24c538` passes
> the real CMDQ KV source-read / Protection-denied destination-write path,
> KV response ownership and error completion (`status/error=2/7`), and
> destination-memory sentinel checks. `make ai_smoke` and the 20-case seeded
> top regression pass from a detached clean worktree. This closes only the
> named KV Protection slice; it does not close multi-requester ownership,
> broader fault crosses or the 38-requirement review. See the
> [R54 report](../docs/verification/COMPUTE_CLUSTER_KV_PROTECTION_R54.md).

> **2026-10-30 fixed-harness clean replay:** Review harness SHA `ded9d92`
> passes three-seed real seven-engine UVM (R55), 25/25 passive checker
> sensitivity mutations (R56), Matrix depth-4 Golden/fault regression (R57),
> and a separately compiled prefetch-disabled fallback profile (R58). R55 has
> 100% applicable focused compute testpoints, 5,368 checked words/seed and
> zero mismatch/unknown/stale/orphan responses. Matrix enabled-profile DUT-only
> URG is line/condition/FSM/branch `97.08/91.05/93.55/95.52%` (49/53 FSM);
> no profile percentages are merged. R55's compute-only SVA still has three
> AXI AR/AW properties without real success and two RAL properties without
> attempts. The 38-requirement status remains 24 PASS-SCOPED / 14 PARTIAL and
> CL-DV-v1.0 HOLD. See [R55–R58 evidence](../docs/verification/COMPUTE_CLUSTER_CLEAN_REPLAY_R55_R58_2026-10-30.md).

> **2026-10-30 exact-clean top replay R59:** At harness SHA `ded9d923a432e869592ec8710a22df5501d8d474`, `make ai_smoke` and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` both passed. The real-top KV Protection denial completed with status/error `2/7` and preserved source/destination sentinels; Top Smoke also completed mapper precheck, reset recovery and the 86-descriptor workload. The known fixture `LOOP-REROLL-ENABLED` warning remains. See the [R59 evidence](../docs/verification/COMPUTE_CLUSTER_TOP_SMOKE_REPLAY_R59_2026-10-30.md). This does not close any broader requirement or change the 24/14 RTM disposition.

> **2026-10-30 Scalar INT8 numeric addendum:** R52 passes 13 independent
> Golden cases per seed on three seeds at clean test SHA `dde7806`, covering
> VDOT/GEMV/GEMM arithmetic boundaries, output Memory Image, response drain,
> and read/write backpressure using only assigned activation values 0/1/2.
> R51's reserved activation=3 testpoint is superseded and excluded. SPEC v1.6
> closes the common arithmetic contract ambiguity; legacy Conv and wider
> REQ-CL-020 opcode/shape coverage remain partial. See the [R52 report](../docs/verification/COMPUTE_CLUSTER_SCALAR_INT8_NUMERIC_R52.md).

> **2026-10-28 historical review addendum:** Product RTL/SPEC candidate is
> `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`. Clean test commit
> `bb6e3a270ab819c15df0eb993c184c99d13a6d71` has byte-identical `rtl/` and
> adds a seven-engine accepted-read reset sweep. VCS/URG
> `V-2023.12-SP1_Full64` passed 3/3 seeds; each seed checked 5,368 memory
> words with zero mismatch/unknown/stale/orphan response, `reset_dropped=9`,
> and UVM severity `0/0/0`. All seven real production engines were reset
> after an accepted SPAD read, and destination/completion sentinels were
> preserved. R33 clean test commit `cb9717eb853dc507f4a7e4d188c7bd840160c955`
> reports 100% applicable focused testpoint coverage (URG 29/29 expected
> variables); the completion-read response bin is explicitly excluded as N/A
> and remains checked at zero. The historical raw score is 29/30 (98.96%).
> RTM remains 24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN.
> This does not close partial Line WSTRB, legal fault/reset crosses, or target
> external-fabric qualification. The older dated rows below are retained as history;
> current disposition and artifacts are in the
> [Execution RTM](../docs/verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

> **2026-10-27 S1/S2 sign-off candidate:** At detached clean-worktree SHA
> `c83ad7463265062d4edb84d57fe4ada8195f9b10`, Matrix depth-4 three-seed and
> prefetch-disabled fallback three-seed regressions passed; the seven-engine
> real-top UVM passed three seeds with 4,852 compared words/seed and zero
> mismatch/unknown/stale response; and 25/25 passive observation mutations
> were caught by their expected checker, including Done/missing/duplicate Done
> on every engine bit. Matrix core line/condition/FSM/branch is
> `97.08/91.05/93.55/95.52%`, with 49/53 default-profile transitions and
> four reviewed dispositions. The focused cluster group is 98.96% raw with
> only the write-only completion read-response bin WAIVED/N/A. S1 is bounded
> PASS; the tested S2 slice is bounded PASS, while full S2 remains HOLD because
> 23 requirements are `PASS-SCOPED`, 13 remain partial, two are BLOCKED_SPEC,
> and none are NOT_RUN after the 2026-10-27 license-restored rerun. That rerun
> adds launch/latch, shared-read-only, request-stability, CNN/KV, SFU, and FP
> checks on the `fa2b4dd` source base with the DV changes listed in the report;
> those same RTL/DV file contents are committed. A fresh clean-worktree replay
> is pending because the current VCS license server is unavailable; see the
> supplemental section below.
> A later CNM retry encountered an unavailable VCS license server before
> compilation; it adds no result and does not invalidate the archived PASS runs.
> See the [S1/S2 sign-off candidate report](../docs/verification/COMPUTE_CLUSTER_S1_S2_SIGNOFF_CANDIDATE_2026-10-27.md).

### 2026-10-27 license-restored supplemental verification at `fa2b4dd`

After the Synopsys license server was restored, the previously blocked CNN/KV
and SFU random-latency runs passed three seeds. FP mixed-dot UVM passed two
seeds (596/596 bit-exact transactions each; BF16/FP16, odd-tail parity,
two-outstanding, latency and selected fault/reset bins all 100%). Matrix depth-4
core passed three seeds with 18 Golden and 34 fault/recovery cases per seed;
the eight-configuration/five-workload ablation passed 40/40 runs at one fixed
seed and behavioral one-cycle SPAD latency.

The real-top Compute Cluster UVM passed seeds `20261025/20261026/20261027` on
the current checkout with DV-only working-tree changes. It now directly checks
descriptor launch sampling and scalar VDOT unused fields, in-flight descriptor
mutation/latching, concurrent Scalar VDOT + SFU reads from one immutable SPAD
region, and request payload stability across ready stalls. Each seed had UVM
severity 0/0/0, 4,946 memory writes and 5,256 compared words with zero
mismatch/unknown/stale/orphan responses, and 2 accepted reads intentionally
dropped by reset. The focused functional group is 98.96% raw (29/30 variables);
the only uncovered response-client bin is completion-read, dispositioned
WAIVED/N/A because the completion writer is write-only. The DUT+TB+UVM merged
URG dashboard is not a DUT-only percentage.

The 25-run observation mutation campaign caught address, data, response owner,
WSTRB, and done/missing/duplicate Done faults on all seven engine bits.
`make ai_smoke` passed with the existing `[LOOP-REROLL-ENABLED]` workload-fixture
warning. UVM compilation had no `Warning`, `Error`, or `TFIPC` diagnostic. The
Matrix default-profile FSM remains 49/53 transitions (92.45%); the four misses
are individually reviewed, but the two invalid-state paths have no formal
unreachable proof, so no full FSM closure claim is made. Exact commands,
artifacts, requirement dispositions and residual gaps are in the [S1/S2
sign-off candidate report](../docs/verification/COMPUTE_CLUSTER_S1_S2_SIGNOFF_CANDIDATE_2026-10-27.md).

> **2026-10-26 Stage A + benchmark status:** At tested RTL/DV SHA
> `03bf257afdca9b0041ff80b6d30cbaf8107cf7e0`, real-top seven-engine UVM passed
> three clean-worktree VCS seeds. The byte-addressed scoreboard checked 4,852
> words/seed with zero mismatch, unknown read or stale-epoch response; the DMA
> response-client bin is hit, and the write-only completion response bin is
> explicitly waived/N/A. Focused functional coverage is 99.0%; five
> observation-only checker mutations were caught (5/5). Matrix FSM audit:
> 49/53 `state_r` transitions, 15/15 states, prefetch FSM 9/9; four misses are
> reviewed but not formally waived unreachable. Matrix ablation passed 40/40
> workload/configuration runs. Cluster staged parallel mode measured 1,239→1,070
> cycles (1.158×); four-task queued mode measured 1,696→1,137 cycles (1.492×).
> Matrix+CNM+DMA top contention remains blocked by the legal `DMA_CTRL` busy
> gate. This is not full C1 signoff; merged top code coverage is not DUT-only.
> Full evidence and run artifacts are in the
> [Stage A and benchmark report](../docs/verification/COMPUTE_CLUSTER_STAGE_A_AND_BENCHMARKS_2026-10-26.md).

> **2026-10-23 Multi-Engine NPU Compute Cluster interaction follow-up:** The
> three-seed direct regressions now include CNM late parity after 128 accepted
> request slots and parity/protection+abort/reset combinations; full-range CNN/KV
> address modeling, stride boundaries, and late faults; Matrix late parity after
> 20 committed output lines and fault+abort/reset combinations; SFU late parity
> after 8/16 responses and fault+abort/reset combinations; and FP parity+abort
> response competition/reset. Updated aggregate, top smoke, DMA–SPAD–CNM 10-seed
> UVM, serial-cluster formal (3 assertions proven, 7 engine covers), and URG
> merge passed. Follow-up top-smoke coverage observes overlap for all 21 engine
> pairs, checks ordered abort drain, and passes all five coverage seeds. The
> dispatcher formal run proves 5/5 assertions and reaches 23/23 covers (four
> antecedent properties non-vacuous). Weighted `rtl/compute` line/condition/FSM/
> branch coverage across focused and top tests is
> `92.69/90.00/54.67/87.31%`; the five-seed top-only compute slice is
> `83.79/66.39/41.60/69.19%`. These remain partial raw code coverage. The
> combined full-domain FP lifecycle run proves 3/6 properties; a separate
> actual-core full-length writeback-exclusion proof passes. The dependent
> control-only parity-response cutoff lemma timed out at 600 seconds without
> a counterexample and remains unproven, so dependent progress composition is
> not claimed. Other fault permutations, completion backpressure, and project
> signoff remain open. See
> the [interaction run record](../docs/verification/COMPUTE_ENGINE_INTERACTION_FOLLOWUP_2026-10-23.md),
> [validation history](../docs/verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-23.md),
> and [per-module status](../docs/verification/COMPUTE_ENGINE_STATUS.md).

> **2026-10-24 FSM and parallel-dispatch follow-up:** SFU random-latency
> regression passed seeds `20261024/20261025/20261026`; every seed visited all
> 39 encoded states through asynchronous reset and all 39 through Abort, plus
> the RMSNorm gamma-bypass transition. VCS V-2023.12-SP1 / URG reports
> `ai_tensor_sfu_core.state_r` transitions 139/139 (100%). Re-merging the
> existing compute block/top VDBs with the refreshed SFU database gives
> 258/339 (76.11%) weighted transitions across the nine FSM-bearing
> `rtl/compute` modules, up from 185/339 (54.57%) on the same parsed baseline.
> Remaining transition bins are in Tile Pipeline 6/30, INT8 19/36, Matrix
> 26/39, bank-local controller 15/23, CNM 13/18, Conv line buffer 18/29,
> Mixed-FP 12/14, and KV 12/15; this is targeted FSM closure, not full code or
> functional closure. New Dispatcher/SPAD-MUX UVM regression passed seeds
> `20261024/20261025/20261026`: 21/21 engine-pair overlaps and 5/5 scenario
> bins each seed, UVM warning/error/fatal `0/0/0`. It instantiates the real
> dispatcher and real 32-bit compute SPAD mux with behavioral Engine/SPAD
> models; it does not cover `ai_spad_arbiter`, four-bank SRAM, CNM/Matrix side
> channels, or concurrent memory-image conflicts. The following top `ai_smoke`
> also passed. Exact commands and artifacts are recorded in the Compute
> Cluster UVM Testplan and `/tmp/nmaforge_{sfu_fsm_converge_multi_20261024,
> parallel_compute_uvm_20261024}`.

> **2026-10-19 exact-SHA CP randomized full-width payload replay (`cd50605`):**
> Clean detached worktree passed focused reproducibility plus 200/200 CP UVM/
> URG seeds, each with 32/32 scenario markers and UVM severity `0/0/0`.
> Result/cycles/elements each had 200 unique 32-bit values. `cp_cg` 63/63
> variables + 34/34 crosses; payload 1/1; reset 4/4; kind×delay×reset 24/24;
> abort timing 7/7; assertions 13 success, 0 failure/incomplete, two RAL
> no-attempts; covers 4/4. CP/writer toggle coverage is 16.10%/50.43% versus
> 13.21%/41.81% under the matched fixed-payload stimulus; this is activity
> coverage, not PPA. `ai_smoke` and 20-case `ai_run` passed. Raw condition/
> toggle residuals and V2/V5/A10 closure remain open. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAINCD50605_CP_PAYLOAD.md).

> **2026-10-19 exact-pushed-main V2 Command Processor (`2f991dd`):** Clean
> detached worktree: 72/72 mixed error/abort/reset profiles plus 200/200
> random seeds, each with scenario bins 32/32 and UVM severity 0/0/0. URG
> functional `cp_cg` 63/63 variables + 34/34 crosses; assertions 13 success,
> 0 failure/incomplete, 2 UVM RAL no-attempts; covers 4/4. CP/writer line/FSM/
> branch were 100%; raw CP condition 94.05% and CP/writer toggle 13.21%/41.81%
> remain open. Top `ai_smoke` and 20-case `ai_run` passed. This is selected V2
> evidence, not V2/V5/A10 closure. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN2F991DD_V2_CP.md).

> **2026-10-19 exact-pushed-main V4 192-seed DDR E2E (`5dd6ed4`):** A clean
> detached worktree passed 192/192 seeds with UVM severity 0/0/0 and no compile
> `Warning-`/`Error-` lines. The E2E covergroup, four per-transaction AXI
> groups and all 19 checked functional points reached 100%; URG assertions
> were 20 success, 0 failure/incomplete and 2 UVM RAL no-attempts; covers 3/3.
> Raw DUT code coverage remains partial and workload-specific; this is not V4,
> V5, or A10 closure. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN5DD6ED4_V4_E2E.md).

> **2026-10-19 exact pushed-main selected replay (`649c6c0`):** On a clean
> detached worktree at SHA `649c6c00dd22dc10910f1cc795df25fdff636b32`, FP
> directed/max-parity tests, three-seed FP UVM (1,452/1,452 bit-exact checks),
> Python model (19/19), DMA UVM (19/19), Control UVM (9/9), top smoke, and a
> 20-case seeded top run passed. All tested UVM severity counts were zero.
> URG merges included compile VDBs and had no design-load errors. This is a
> selected replay, not A10/V5 closure. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN649C6C0_SELECTED_REPLAY.md).

> **2026-10-19 exact-main CP high-payload replay (`35c7670`):** Clean
> detached worktree at pushed SHA
> `35c767…18845 tokens truncated…/branch/assertion/group=`52.45/50.04/46.14/10.64/38.39/88.24/81.26%`, including TB/UVM and not DUT-only. New `ai_smoke` passed with the FP checker connected. Accelerator reset is during active compute at an AXI idle boundary; DDR remains active and DMA recovery reads the retained operand. Not an in-flight AXI reset test; global DUT-only/V4/V5 closure remains open. |
### A10 V3 CNM parity fault during DMA abort/drain (2026-10-16)

Added one directed cross-layer fault/abort scenario to `dv/subsystem/dma_spad`: four DMA read bursts are accepted, DMA abort begins before the first R response, and a real four-lane CNM operation then retires `ERR_PARITY=5` while the DMA remains active draining accepted traffic. The checker requires 4/4 DMA read responses, zero DMA SPAD commits, zero CNM result writes, all accepted CNM lane responses drained, and both destination sentinels unchanged. After restoring the behavioral parity bit, clean DMA load and CNM compute/readback both recover without subsystem reset. Three seeds `12345/987654/20261014` pass with UVM warning/error/fatal=`0/0/0`; merged URG `cnm_parity_dma_abort_cg.parity_abort_x_drain` is 1/1 (100%). Top `ai_smoke` passes. This is testbench backdoor parity injection against behavioral SRAM, one directed lane/address/timing—not a physical SRAM fault model or randomized fault×abort×reset closure. Product RTL/ABI unchanged; V3/A10 remain open.

### A10 V3 CNM contention during DMA accepted-write abort/drain (2026-10-16)

Added a directed `dv/subsystem/dma_spad` scenario that starts the real four-lane CNM before a 32-word DMA store, aborts after the first AW handshake, and holds the matching B response for 64 cycles. Three seeds `12345/987654/20261016` pass: each has 20 CNM/DMA overlap cycles, a CNM grant under shared-SPAD contention, exactly one accepted/completed B response, sequence-checked `ERR_ABORT=5`, clean DMA idle, correct CNM oracle/readback, and a subsequent DMA load without reset. UVM warning/error/fatal is `0/0/0` for all seeds. Merged URG `/tmp/nmaforge_a10_dma_write_abort_20261016/urg_merged` reports both `cnm_dma_write_abort_cg` crosses at 1/1 (100%); top `ai_smoke` reports `TEST PASS`. No product RTL, SPEC, or ABI changed. The abort point and response delay are directed; randomized write-abort, broader fault×abort×reset combinations, command/completion lifecycle, and V3/A10 closure remain open. See the [A10 RTM](../docs/verification/A10_DV_RTM.md) and [run record](../docs/verification/A10_DV_RUN_2026-10-16.md).

### A10 verification replay after EDA license recovery (2026-10-17)

The user restored the Linux EDA license, then the following current-worktree runs completed:

- `make -C dv/block/compute/fp/sim dot-core-test VCS='vcs -licwait 1' DOT_CORE_OUT_DIR=/tmp/nmaforge_a10_resume_dotcore_20261017` — PASS; VCS `V-2023.12-SP1_Full64`.
- `make -C dv/block/compute/fp/sim dot-uvm-regress DOT_RANDOM_COUNT=200 DOT_UVM_SEEDS='712345 987654 20261015' DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_resume_fp_20261017 VCS='vcs -licwait 1' URG=urg` — all three seeds PASS, each 482/482 scoreboard transactions (430 numeric + 52 fault/reset/error-transition), 1,446 total; peak outstanding=2 and UVM warning/error/fatal=0/0/0. URG output is in `/tmp/nmaforge_a10_resume_fp_20261017/urg_report_merged/`.
- `make -C dv/block/command_processor/uvm cov-regress 'SEEDS=712345 987654 20261015' COV_OUT=/tmp/nmaforge_a10_cp_resume_20261017/coverage VCS='vcs -licwait 1' URG=urg` — 18/18 simulations passed (three seeds × six `kind × abort-delay` profiles); each passed the 29/29 scenario and zero-severity gates. The Makefile coverage gate passed with `cp_cg` 49/49 variables + 10/10 crosses. This block filelist includes both `ai_command_processor` and `ai_completion_writer`.
- `make -C dv/subsystem/top_smoke/sim ai_precheck` — exit 0; A4 reference precheck 1,000/1,000 and Transformer mapper passed, then the top simulation ended `TEST PASS`.
- `make -C dv/subsystem/top_smoke/sim ai_smoke` — PASS, `TEST PASS`.
- `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345` — PASS, all 20 seeded cases completed.
- `make -C dv/block/compute/fp/formal run VCF=vcf OUT=/tmp/nmaforge_a10_formal_error_disposition_12_20261017` — VC Formal `V-2023.12-SP2`: 12/12 selected assertions proved, both covers reached, and setup reported `No setup issues found` after deterministic reset simulation. Three non-vacuous assertions exclude `ERR_ABORT`, `ERR_CONFIG`, and `ERR_WATCHDOG` from `ST_WRITE`. The parity-only exclusion did not converge within the bounded run; the broad `ST_WRITE -> pending_error_r == ERR_NONE` assertion also did not converge. Neither is a counterexample. Reset-release behavior and RDC signoff are not established. Log: `/tmp/nmaforge_a10_formal_error_disposition_12_20261017/vc_formal.log`.

The successful new runs supersede the prior same-day license-connectivity failures as current environment status; those failures remain documented as history. RTL/DV/SPEC files in the repository were already modified before these runs, so this is dirty-worktree evidence, not a frozen-SHA clean replay. V1 parity/coverage residuals, overall V2/V3/V4 interaction closure, V5 global coverage/mutation review, and final clean replay remain open.

Additional license-restored runs: `make -C dv/block/control/sim uvm_regress VCS='vcs -licwait 1'` passed 9/9 tests with per-test UVM warning/error/fatal=0/0/0; `make -C dv/block/dma/sim uvm_regress VCS='vcs -licwait 1'` exited 0 for the current 15-test suite (the pre-existing aggregate log was stale, so no aggregate severity count is claimed); and the three-seed `dv/subsystem/dma_spad/sim subsystem_regress` plus URG merge exited 0. The DMA–SPAD run reused one `RUN_LOG` path across seeds, so only the final-seed transcript remains; see the A10 run record for the exact command and VDB paths.
> **2026-10-17 V4 top smoke and seeded replay:** Re-ran Rocky 8.10 / VCS top-level ai_smoke and ai_run AI_RANDOM_CASES=20 AI_SEED=12345; both exited 0 and printed TEST PASS. Exact commands and isolated log paths are in [2026-10-17 run evidence](../docs/verification/A10_DV_RUN_2026-10-17.md). This is dirty-worktree replay evidence for the top smoke/random slice only; it does not close V4/V5 or replace the broader E2E UVM coverage review.

### A10 V4 clean-SHA top DDR E2E UVM completion (2026-10-17)

Completed the 192-seed mixed-precision DDR E2E UVM campaign against detached
RTL baseline `43dbbbc498377d852667c4e3eb5880ecf4aaf8f7`. The first invocation
had been interrupted after 91 seeds by an unreachable license server; after
`lmutil lmstat -a` returned exit 0 and VCS feature status, seeds
`20261192..20261292` were resumed with the already compiled simulator. All
192/192 logs passed the exact per-seed functional marker and zero-severity gates
from `dv/uvm/sim/Makefile`.

The shard auditor/URG merger `tools/verify_a10_mixed_e2e_shards.sh` exited 0.
Merged URG `/tmp/nmaforge_clean43_v4_random_20261017/urg_merged/` reports the
E2E covergroup, four per-transaction AXI AR/AW/R-gap/W-gap groups, and all 19
required functional points at 100%. Assertion summary: 22 total, 20 success, 0
failure, 0 incomplete, and two UVM RAL internal `do_read`/`do_write`
no-attempts; all three AXI stall-to-accept cover properties matched. Commands,
seed partition, and limits are in
[the A10 clean-SHA replay record](../docs/verification/A10_DV_CLEAN_SHA_REPLAY_43DBBBC.md)
and [run refresh](../docs/verification/A10_DV_RUN_2026-10-17_REFRESH.md).

This closes the clean-SHA randomized E2E slice only. It does not close all V4
interactions (including accelerator reset during an in-flight AXI transaction),
global DUT code/assertion coverage, or A10/V5. No product RTL, SPEC, or ABI was
changed by this verification increment.

### A10 V4 current-main mixed-precision DDR E2E replay (2026-10-18)

Fresh `uvm_mixed_precision_ddr_e2e_random_cov_regress` at GitHub `main`
`0578dde3a72ad8f9f89ef5c6a870f83d76de24d7` passed all 192 default seeds
(`20261101..20261292`): 192/192 E2E pass markers, all per-seed Makefile gates,
and zero nonzero UVM WARNING/ERROR/FATAL summaries. Merged URG reports `e2e_cg`
and all four per-transaction AXI AR/AW/R-gap/W-gap groups at 100%, plus all 20
Makefile-gated functional points at 100%. Assertions: 20 success, 0
failure/incomplete, 2 no-attempt UVM RAL internals; all three AXI
stall-to-accept cover properties matched. The five AXI-master protocol
assertions are DUT-owned; compute-activity properties are testbench monitors.
Artifacts are under `/tmp/nmaforge_a10_main0578dde_top_e2e_random_20261018/`.
This is a current-main selected-slice replay, not full V4/V5 closure; broader
top interactions and DUT-only residual coverage disposition remain open. See
the [A10 run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md)
and [RTM](../docs/verification/A10_DV_RTM.md).

### A10 V3 DMA burst-planner edge checks (2026-10-18)

Added two DMA UVM tests without changing product RTL: an exact 4-KiB boundary
read split (`0x1ff0/LEN0`, followed by `0x2000/LEN1`) and 1/2/3-word stores
checking WSTRB=`000f/00ff/0fff` plus B-response drain. Focused tests and the
full 19-test DMA regression passed with per-test UVM warning/error/fatal
`0/0/0`; the random test scored 20/20 transfers, URG merged, all 11 named DMA
DUT SVA had real successes, and top `ai_smoke` printed `TEST PASS`. A first
tail-test attempt caught a testbench expected-mask formula error; it was fixed
before the passing rerun. The full 19-test suite, URG merge, and top smoke were
then replayed at pushed SHA `264230a75bd5d4cba97b88dc592290e0f8892ef5` with
per-test warning/error/fatal=`0/0/0`, 20/20 random transfers scored, and
`TEST PASS`. DMA raw residual coverage and V3/A10/V5 closure remain open; see
the [exact-main run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-dma-planner-edge-replay-at-264230a).

### A10 最新增量：CP completion availability 与 CPLQ busy-lock disposition（2026-10-18）

CP UVM/URG 三 seed × 24-profile campaign 为 72/72 PASS，scenario bins 每次 31/31、UVM warning/error/fatal=`0/0/0`，`cp_cg` 61/61 variables + 34/34 crosses；CP condition 为 237/252（94.05%）。七个 `completion_required_r && completion_available` 点的 `(1,0)` 现已命中，`(0,1)` 仍保留为 URG raw Not Covered，并由 busy-time `CPL_SIZE` SLVERR/readback Control UVM 检查及 CP+completion-writer VC Formal 6/6 non-vacuous proof 作组合式不可达 disposition。Control UVM 全 9 项通过，top `ai_smoke` PASS。没有产品 RTL/SPEC/ABI 变更。该证据只关闭目标条件组合的 disposition；其它 CP raw coverage、完整 V2/V5 与 frozen-SHA clean replay 仍开放。详见 [A10 CP completion availability run record](../docs/verification/A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md)。

### CP raw condition audit follow-up (2026-10-18)

VC Formal is now 7/7 proven, 7/7 non-vacuous, and 3/3 covers. Under the explicit one-outstanding descriptor-fetch response contract, the new `fetch_done -> ST_FETCH` proof classifies the final raw condition miss; the existing ownership/reservation properties and `cmdq_empty` definition classify the other 14. CP raw condition remains 237/252 (94.05%) in URG by design—no exclusions or synthetic coverage claims. CP toggle residuals, broader lifecycle interactions, V2/V5 closure, and clean-SHA replay remain open. Details: [A10 CP completion availability run record](../docs/verification/A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md).

### Real-top Compute Cluster Matrix/SFU UVM replay (2026-10-25)

After VCS license recovery, the new real-top Cluster UVM test passed three
seeds:
`make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_real_compute_cluster_uvm_final_20261025`
with VCS `V-2023.12-SP1_Full64`, seeds `20261025/20261026/20261027`. Each seed
checked real 16×16×64 Matrix GEMM against the golden model, queued SFU work,
Matrix/SFU overlap, banked/core arbiter traffic, completion order, two-engine
abort, reset-dropped in-flight reads, no stale writeback/completion, and
post-reset recovery. All three printed the test and reset-recovery PASS markers;
UVM warning/error/fatal was `0/0/0`, orphan responses were zero, and pending
reads drained to zero. The expected abort completion contributes one observed
engine error per seed. Focused functional coverage was 55.5%. The three-test
whole-top URG dashboard reports line/condition/FSM/branch/assertion/group
`45.93/39.46/8.99/35.46/60.00/17.88%`; this includes DUT, checker, testbench,
and UVM and is not a DUT-only or full-cluster coverage claim. VCS elaborated with
zero errors; one `Warning-[TFIPC]` reports omitted inputs on the top protocol
SVA instance.

Also reran `make -C dv/subsystem/top_smoke/sim ai_smoke` (`TEST PASS`) and
`make -C dv/block/compute/matrix/sim core-random-regress
SEEDS='20261021 20261022 20261023'
CORE_OUT_DIR=/tmp/nmaforge_matrix16_core_regress_vcs_20261025` (all three seeds
passed 8 numerical/layout and 12 fault cases, late tile fault, and recovery).
Merged Matrix core/array URG is respectively
`96.17/90.83/65.85/93.52%` and `82.35/20.00/N/A/58.82%`
(line/condition/FSM/branch). Detailed logs and reports are in the two `/tmp`
directories named above. These are dirty-worktree replay results, not a
clean-SHA run; broader engine, feature-coverage, mutation, and signoff closure
remain open.

### Matrix P0-B ordered banked-read pipeline (2026-10-26)

`ai_tensor_matrix_core` now has a bounded ordered response-metadata FIFO with
configurable depth 2/4 (top default 4). It records A/B, 4×4 group, K group and
full request address, preserves request order, and stops issue/drains accepted
responses on abort, watchdog, protection or parity errors. No descriptor/opcode
or ABI change. VCS `V-2023.12-SP1_Full64` command:

```sh
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' OUTSTANDING_DEPTH=2 \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_p0b_depth2_regress_20261026
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' OUTSTANDING_DEPTH=4 \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_p0b_depth4_regress_20261026
```

Both depth campaigns PASS (three seeds each; 10 numeric/layout cases and 14
fault/recovery cases per seed). Coverage points include actual occupancy 2/4,
depth-2 FIFO-full stalls, full-depth abort drain, parity with other responses
pending, no post-fault requests, and clean recovery. Fixed one-cycle behavioral
SPAD size benchmark: 16×16 array / 16×16×K32 is 242 cycles, 33.851 MAC/cycle,
13.22% array utilization, 16.926 normalized GOPS at assumed 250 MHz versus the
357-cycle pre-pipeline baseline. `ai_smoke` and 20-case seeded top regression
also PASS. These are block/top-smoke results; they are not merged into the
real-top UVM functional covergroup. P0-C evidence follows.

### Matrix P0-C prefetch and A-tile reuse (2026-10-26; initial UVM slice)

Depth-2 and depth-4 Matrix core regressions each passed three seeds, with 17
numeric/layout and 17 fault/recovery cases per seed. The tests check that the
inactive operand buffer becomes consumable only after its accepted A/B reads
return; next-K prefetch overlaps MAC; A-tile reuse hits across N tiles; K>64
falls back to SPAD; and prefetch parity/abort/watchdog drain, reset invalidation
and recovery. Depth-4 block VDB was freshly summarized with VCS V-2023.12-SP1 URG.
`ai_tensor_matrix_core` DUT-only line/condition/FSM/branch is
`96.59/88.48/66.67/95.48%`; FSM transitions are 40/60, so controller FSM
coverage is improved but not closed.

The real-top UVM ran three seeds with a 16×32×64 Matrix GEMM and checked 512
Golden outputs, 16 A-cache hits and 120 prefetch/MAC overlap cycles per seed.
It also ran queued SFU work and active prefetch abort/reset/recovery. UVM
warning/error/fatal is `0/0/0`; focused functional coverage is 65.4%. Merged
whole-top URG line/condition/FSM/branch/assert/group is
`47.54/41.38/10.52/37.70/60.00/19.11%`, including DUT, SVA, testbench and UVM.

Cache ON/OFF results for the 16×16 physical array with one-cycle behavioral
bank response:

| Workload | Cache off | Cache on | Change |
|---|---:|---:|---:|
| 16×32×K32 | 469 cycles / 128 reads | 417 / 96 | cycles −11.1%, reads −25% |
| 32×32×K64 | 1443 cycles / 512 reads | 1187 / 384 | cycles −17.7%, reads −25% |

GOPS is normalized to an assumed 250 MHz; neither these results nor the 10 ns
testbench period model SRAM macro timing or establish PPA. Exact commands and
artifact paths are in the [upgrade roadmap](../docs/verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md#34-p0-c-ping-pong-prefetch--p1-bounded-a-tile-reuse).

### 2026-10-26 initial Matrix FSM convergence and seven-engine top UVM follow-up (superseded)

The depth-4 Matrix core regression and a focused 4×4 physical-array
prefetch-handoff regression were merged in URG after the initial P0-C result
above. `ai_tensor_matrix_core` reached 15/15 states and 49/53 transitions
(92.45%); prefetch FSM reached 9/9 transitions. Core line/condition/branch
coverage is 96.45/88.52/95.02%. The four unhit core transitions were reviewed
against RTL guards and configuration reachability; no formal unreachable
waiver is claimed. A separate prefetch-disabled Golden benchmark hits the
`ST_MAC→ST_A_REQ` fallback, but its differently compiled VDB is not merged into
the prefetch-enabled percentage. The child array remains partial at 82.35% line
/ 20.00% condition / 58.82% branch.

The real-top UVM now sweeps INT8 VDOT, BF16 dot, CNM, Matrix, SFU, Conv3x3, and
KV write, with separate KV readback/stride checking. Three seeds pass; each
engine's result and completion are checked, as are CNM per-lane request/response
ownership, Matrix/CNM response tags, request backpressure (236 cycles),
Matrix/SFU concurrent Abort, and reset recovery. Each seed reports focused
functional covergroup 97.9%, UVM warning/error/fatal `0/0/0`, no orphan response,
and empty pending ledgers. The merged whole-top URG also includes DUT, SVA,
testbench, and UVM definitions and must not be interpreted as DUT-only code
coverage. The older 65.4% UVM and 40/60 Matrix FSM values above are preserved as
dated intermediate evidence, not current status.

The VCS same-seed Matrix configuration sweep also completed eight combinations
of outstanding depth, prefetch, and A-tile cache. With one-cycle behavioral
bank response, 16×16×K32 improved 265→233 cycles, 16×32×K32 improved 504→417
cycles with reads 128→96, and 32×32×K64 improved 1698→1187 cycles with reads
512→384, comparing depth-2/no-prefetch/no-cache to depth-4/prefetch/cache.
These are behavioral cycle/read comparisons, not SRAM timing or PPA.

The closeout reran the same three real-top UVM seeds in
`/tmp/nmaforge_cluster_closeout_multiseed_20261026/`. Each seed ran 14/14 parity
cases and reported 3,584 modeled writes, 3,536 compared words, zero
mismatches/unknown reads, zero orphan responses, and UVM warning/error/fatal
`0/0/0`. The 97.92% functional group has two explicit misses: DMA and completion
response-client bins. The byte-addressed reference-memory scoreboard is now
implemented for observed host/scalar/banked/CNM accesses; line/partial-WSTRB
and broader randomized feature/fault coverage remain open. One targeted
mutation and selected fixed-SHA replay were completed afterward; a broader
mutation campaign remains open. The latest top smoke, 20-case seeded regression, and 86-descriptor
fixed-weight Transformer functional test are documented in the
[upgrade roadmap](../docs/verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md).
This block records the original closeout worktree run. A later detached
clean-SHA replay at `827c0052cf589fde676e93e34bf459188956182f` reran the
selected UVM, Matrix, Transformer, smoke, and seeded top targets; one targeted
scratchpad data mutation was detected and restored-source replay passed. The
full logs, commands, testpoint mapping, and open coverage items are in the
[clean replay record](../docs/verification/COMPUTE_CLUSTER_CLEAN_REPLAY_2026-10-26.md).
Current ASIC area/Fmax/power and pretrained-model accuracy remain unmeasured.

### 2026-10-26 Stage A closeout and benchmark replay at `03bf257`

The fixed-SHA clean replay closes the selected Stage A checker tasks: the top
UVM observes the real DMA response-client path; the completion read-response
bin is explicitly N/A because the completion writer is write-only; the
byte-addressed memory scoreboard sees 4,852 compared words/seed with no
mismatch/unknown/stale response; and address/data/owner/WSTRB/done observation
mutations are all detected. The functional covergroup is 99.0%, which is not
REQ closure. The parity cross is 42/42 across three seeds, but broader fault ×
phase × engine × Abort/Reset cases remain open. VCS compile warning `[TFIPC]`
is resolved by connecting the real per-engine busy/done SVA inputs.

For Matrix, three depth-4 seeds each pass 18 cases and 25 fault profiles. URG
over the depth-4 and focused 4×4 handoff databases reports 15/15 states,
49/53 `state_r` transitions, and 9/9 prefetch transitions. The four remaining
transitions are reviewed in the report; no formal unreachable waiver is
claimed. A separate prefetch-disabled run dynamically hits `ST_MAC→ST_A_REQ`.
The same-SHA 8-configuration/five-workload sweep passes 40/40 combinations.

The Compute Cluster benchmark reports 1,239 serial cycles versus 1,070 staged
Matrix+CNM-then-SFU cycles (1.158×), and 1,696 sequential versus 1,137 queued
four-task cycles (1.492×), with ordered completions. Three-seed CNM+DMA
subsystem contention passes. Exact Matrix+CNM+DMA top contention is blocked by
the register contract that only launches DMA when `processor_busy` is low.
This work changes verification/testbench evidence only; it does not claim
ASIC PPA or full Cluster signoff. See the
[Stage A and benchmark report](../docs/verification/COMPUTE_CLUSTER_STAGE_A_AND_BENCHMARKS_2026-10-26.md)
for the requirement table, commands, artifacts, and coverage dispositions.


### Compute Cluster R60 all-engine parity replay — 2026-10-30

At exact clean verification/test SHA `2768843da1b3f3a0e988645746000d5befadf12b` (product RTL/SPEC remains `f916874a9ce60741a4516eaf9e33ebcae4a676c2`), Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1` passes the real top Compute Cluster UVM on seeds `20261030/20261025/20261026`. Each seed hits all 18 selected parity read cases across INT8, Matrix, CNM, BF16, SFU, Conv and KV, including A/B operands where defined and all four CNM lanes. The checker requires owner-specific error completion, drained accepted reads and unchanged output sentinels; Conv/KV use their specified parity completion code 7, other tested engines code 5. Each run reports UVM warning/error/fatal `0/0/0`, 5,445 checked words, zero mismatch/unknown/orphan response, drained pending queues and `reset_dropped=9`.

The scoreboard allows only the matching engine's terminal `Done` in the one sampled cycle after an observed active error, matching production Conv/KV error-state timing. This is a testbench checker correction; no product RTL/SPEC was changed. The same clean SHA passes the 25/25 passive observation checker-sensitivity mutation suite, `make ai_smoke`, and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`. Compile log has no VCS warning/error/`TFIPC`; Top Smoke retains the existing `LOOP-REROLL-ENABLED` fixture warning. See [R60 detailed evidence](../docs/verification/COMPUTE_CLUSTER_ALL_ENGINE_PARITY_R60_2026-10-30.md) for commands, log hashes and URG/SVA dispositions.

This closes only the selected parity read slice. The 38 requirement statuses remain 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. Legal Engine × Fault × Phase × Abort/Reset crosses, external-fabric reset qualification, remaining coverage gaps and the three uncovered compute-profile AR/AW assertion properties are not closed by R60.
