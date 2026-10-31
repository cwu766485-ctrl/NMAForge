> **2026-10-31 R140 Matrix parity + active CNM Abort:** At clean test SHA `c9e0214dfbf8847666baa0b3b10faa973b842224` (tree `b7da3b220d847fd360614e375c007839075291ae`), three real-top seeds pass Matrix `ERR_PARITY=0x52` while CNM is active, then software Abort retires CNM `ERR_ABORT=0x32` first in CMDQ order. Each seed records 7 overlap cycles, 3 shared-bank accepts, 1 Matrix/41 CNM tagged responses, zero route mismatch/post-Abort writes, and 44,811 memory words with zero mismatch/unknown/stale/orphan. UVM severity is 0/0/0; focused cluster coverage is 100% only for the declared group; mixed URG is 56.01%. Top Smoke passes and all 28 checker-sensitivity mutations reach their expected checker. This adds bounded evidence to `REQ-CL-017/019/027` and `REQ-PC-006/007`, which remain PARTIAL; total remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` HOLD. See [R140 report](../docs/verification/COMPUTE_CLUSTER_PARITY_CNM_ABORT_OWNER_CROSS_R140_2026-10-31.md).
> **2026-10-31 R133 Matrix size and configuration benchmarks:** At exact R131 source SHA `207cc3896cb635ff04e7095fc18c435080507724`, VCS passes 15/15 Golden points across 4×4/8×8/16×16 arrays and 40/40 across Depth 2/4 × Prefetch OFF/ON × A-Tile Cache OFF/ON, with fixed seed `20261026` and one-cycle behavioral bank responses. Logs record cycles, MAC/cycle, array utilization, banked read and Line write bytes, and bank/Line/arbiter/response/writeback stall counters. On 32×32×64, D4/P1/C1 is 1,187 cycles vs 1,698 baseline (1.43×) and reads 25% fewer banked bytes. The 250 MHz figure is a reference calculation only; this is not PPA or TinyNPU head-to-head evidence. `REQ-CL-028` remains PARTIAL; global disposition stays 24 PASS-SCOPED / 14 PARTIAL, `CL-DV-v1.0` HOLD. See [R133 report](../docs/benchmark/COMPUTE_CLUSTER_MATRIX_BENCHMARK_R133_2026-10-31.md).
> **2026-10-31 R132 exact-SHA Top Smoke and mutation replay:** At unchanged R131 source SHA `207cc3896cb635ff04e7095fc18c435080507724` (tree `caed517e162270fc2f64beb5382fecdccb651bd5`), mapper precheck passes 86 descriptors/60 tensors and seeded 20-case Top Smoke ends `TEST PASS`; the named checker-sensitivity campaign catches all 28/28 mutations with their expected Checker. This closes the R131 report's NOT_RUN evidence items only; monitor-side mutations are not DUT fault injection and legal system-level fault/phase/reset crossings remain open. Requirement disposition remains 24 PASS-SCOPED / 14 PARTIAL, `CL-DV-v1.0` HOLD. See [R132 report](../docs/verification/COMPUTE_CLUSTER_R131_TOP_MUTATION_REPLAY_R132_2026-10-31.md).
> **2026-10-31 R131 real-top Protection/Abort cross:** Clean test SHA `207cc3896cb635ff04e7095fc18c435080507724` (tree `caed517e162270fc2f64beb5382fecdccb651bd5`), published same-tree at `78aec6c3067c97613521f5744fdba123628ce647`. Three VCS seeds pass concurrent Matrix GEMM + CNM GEMV with denied CNM source-A, ordered completions Matrix `ERR_ABORT=0x32` then CNM `ERR_PROTECTION=0x62`, 128/128 Matrix read responses drained, six accepted Golden output Lines, complete destination Memory Image, no post-Abort write, and zero response-owner mismatch. Full scoreboard checks 42,651 words/seed without mismatch, unknown, stale epoch, or orphan; UVM severity is 0/0/0. Focused `cluster_cg` is 64/64, mixed URG 55.92%; R132 separately passes Top Smoke and mutation campaign at the same source SHA. Adds bounded evidence to `REQ-CL-017/019/027` and `REQ-PC-006`, which remain PARTIAL; global disposition remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 HOLD. See [R131 report](../docs/verification/COMPUTE_CLUSTER_CNM_PROTECTION_MATRIX_ABORT_R131_2026-10-31.md).
> **2026-10-31 R119 Matrix FSM formal replay:** At unchanged RTL/formal source identity `4797a7710a18670d820f8f3815959091f9636e75`, VC Formal `V-2023.12-SP2` proves all five selected FSM guard/invariant properties non-vacuously and reaches `cp_prefetch_wait_reachable` / `cp_error_drain_reachable` at depths 11/5. Clean setup, exit 0. Raw enabled-profile simulation remains 49/53; the legal prefetch-off edge remains a separate R58 simulation point. This formal disposition does not mean 100% FSM coverage and changes no requirement status; RTM remains 24 PASS-SCOPED / 14 PARTIAL, CL-DV-v1.0 HOLD. See [R119 report](../docs/verification/COMPUTE_CLUSTER_MATRIX_FSM_R119_FORMAL_2026-10-31.md).
> **2026-10-31 R117/R118 subsystem testpoint closure:** At exact clean published SHA `480eb443b835f8cbe771682e91ff6d97acae0a99`, the default DMA/SPAD/CNM three-seed suite, 16/64/300-cycle AXI RREADY stress, banked reset, Core/Banked contention, and interleaved Core/Banked reset were run and merged from 15 same-source VDBs. URG reports 17/17 declared subsystem functional covergroups at 100.00%; 29 real assertion successes, 0 failures/incomplete, 2 UVM RAL no-attempt properties. Mixed raw code metrics remain line/condition/toggle/FSM/branch=`73.24/59.49/40.51/54.82/62.47%`; these are distinct from functional testpoint coverage. This closes the named subsystem groups only; 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R117/R118 report](../docs/verification/COMPUTE_CLUSTER_FUNCTIONAL_TESTPOINTS_R117_R118_2026-10-31.md).
> **2026-10-31 R116 exact published HEAD subsystem replay:** At clean published SHA `e7eb378e64f9dad48edaba597fa6be9eb00b8416`, default `subsystem_regress` passes seeds `12345/987654/20261014`, with UVM severity `0/0/0` per seed. Merged URG group score is 79.74%; `dma_rready_stall_cg` is 55.56% because only the 16-cycle profile runs here, and the dedicated banked owner/reset groups are not invoked by this target. Assertions: 28 success, 0 failure/incomplete; two UVM RAL properties and the banked response-tag property have no attempts in this run. Separate R110–R114 reports provide their non-vacuous banked checks. This is a clean replay, not global coverage closure: RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R116 replay report](../docs/verification/COMPUTE_CLUSTER_FINAL_HEAD_SUBSYSTEM_REPLAY_R116_2026-10-31.md).
> **2026-10-31 R115 final published HEAD replay:** At exact clean published SHA `5bc52ed80a763de58c6a1d3487255ca9552cc12b`, Top Smoke passes the mapper precheck (`86` descriptors, `60` tensors) and VCS `TEST PASS`; `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` also ends `TEST PASS`. The existing Rocky/WSL support notices and `LOOP-REROLL-ENABLED` fixture debug notice are retained. This verifies only the restored Top Smoke and named 20-case top target, not seven-engine UVM or whole-Cluster coverage. Full RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R115 replay report](../docs/verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R115_2026-10-31.md).
> **2026-10-31 R114 banked/Core reset epoch:** At exact published code/test SHA `4797a7710a18670d820f8f3815959091f9636e75`, three clean-worktree VCS seeds exercise simultaneous scalar/Core and Matrix-like Banked requests through the in-repository `ai_accel_memory_fabric`. The Core response owner/data is checked while the accepted Banked response is pending; shared reset flushes that old-epoch response, all response owners remain quiet during reset and four release cycles, then both owners recover with Golden data. Focused `banked_core_reset_epoch_cg` is 100%; `ap_core_response_tag` and `ap_banked_response_tag` each record 471 attempts/3 real successes, and `ap_single_response_owner` records 471/441, all with zero failures/incomplete; UVM severity is 0/0/0. Clients are testbench-driven; production Matrix concurrency and broad fault/backpressure crossings remain open. `REQ-CL-018/PC-007` remain PARTIAL; overall RTM is 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R114 report](../docs/verification/COMPUTE_CLUSTER_BANKED_CORE_RESET_R114_2026-10-31.md).
> **2026-10-31 R113 banked/core owner contention:** At exact clean code/test SHA `10601142cf912369b871fa9e5affed8fde5f767b`, three VCS seeds issue simultaneous scalar/core and Matrix-like banked reads through the production `ai_accel_memory_fabric`. The arbiter grants Core then Banked; tag-2 scalar and tag-3 four-bank responses are exclusive and match independent Golden data. `banked_core_contention_cg` is 100%; `ap_banked_response_tag` and `ap_core_grant_owner` each have 429 attempts, 3 real successes, 0 failures/incomplete; UVM severity is 0/0/0. Requesters are testbench driven, so production Matrix contention, backpressure and fault/reset crossings remain open; `REQ-PC-007` remains PARTIAL, RTM remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. See [R113 report](../docs/verification/COMPUTE_CLUSTER_BANKED_CORE_CONTENTION_R113_2026-10-31.md).
> **2026-10-30 R112 banked response reset epoch:** At exact clean code/test SHA `b4d99efe95034ff953ca26c66f90a8402a0cde7c`, three VCS seeds accept a testbench-driven client-3 banked read through production `ai_accel_memory_fabric`, reset before the registered response, verify no response during reset or a four-cycle post-reset quiet window, then check fresh owner-3/four-bank Golden recovery. Focused reset functional coverage is 100%; `ap_banked_response_tag` has 450 attempts, 3 real successes, 0 failures/incomplete; UVM severity is 0/0/0. This is not production Matrix-engine contention and leaves broad fault/backpressure crosses open; `REQ-CL-018/PC-007` remain PARTIAL, RTM remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. See [R112 report](../docs/verification/COMPUTE_CLUSTER_BANKED_RESET_EPOCH_R112_2026-10-30.md).
> **2026-10-30 R110 banked response-owner SVA non-vacuity:** At exact clean code/test SHA `95864f7027ccbec22a09b0a61832c68d3ca08098`, three VCS seeds drive a testbench Matrix-like read requester through production `ai_accel_memory_fabric`, arbiter, and four-bank registered SPAD. Client-3 grant/response ownership, no competing response owner, and four Golden bank words pass with UVM severity 0/0/0. URG reports `ap_banked_response_tag` 426 attempts, 3 real successes, 0 failures/incomplete. This closes only the harness assertion non-vacuity point; production Matrix/fault/backpressure crosses remain open, RTM remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. See [R110 report](../docs/verification/COMPUTE_CLUSTER_BANKED_OWNER_SVA_R110_2026-10-30.md).
> **2026-10-30 R109 KV Cache accepted-write Abort prefix:** At exact clean code/test SHA `5c212a302b0df6ea0f3815ccdf085e139cb4104f`, three real-top seeds execute legal KV_WRITE for `head=1/token=2`, then Abort after two of eight cache writes. Each checks the nonzero 96-byte address offset, Golden prefix, six untouched suffix words, two adjacent guards, `ERR_ABORT=0x32`, and 3/3 accepted-read response drain. The scoreboard checks 33,510 words with zero mismatch/unknown/stale/orphan; pending queues are empty; UVM severity is 0/0/0 and focused applicable coverage is 100%. At the same clean SHA, 28/28 checker-sensitivity mutations, Top Smoke and the 20-case seeded Top pass. This is a named point only: the RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See the [R109 report](../docs/verification/COMPUTE_CLUSTER_KV_ABORT_WRITE_PREFIX_R109_2026-10-30.md).

> **2026-10-30 R108 CNM accepted-write Abort prefix:** At exact clean code/test SHA `26448b12e545498d31ce8665723db97e10e2c1e2`, three real-top seeds abort a legal 16-output CNM GEMV after the first accepted output. Each seed checks the independent signed Golden prefix, all 15 untouched suffix sentinels, 40/40 CNM read-response drain, and owner/status `ERR_ABORT=0x32`. The memory scoreboard checks 33,491 words with zero mismatch/unknown/stale/orphan and pending queues empty; UVM severity is 0/0/0, and applicable focused compute coverage is 100%. At this same clean SHA, checker sensitivity is 28/28, Top Smoke and the 20-case seeded Top run pass. This is a directed one-shape/one-cut-point result; legal fault/phase/reset closure remains open, the RTM stays 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See the [R108 report](../docs/verification/COMPUTE_CLUSTER_CNM_ABORT_WRITE_PREFIX_R108_2026-10-30.md).

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

> **2026-10-30 R102 current-candidate AXI SVA gate:** At exact code/test
> commit `d0b94ec74865f1f68af14de12113a8c19caf5204`, the mixed-precision
> behavioral-DDR stall/reset E2E passes with UVM severity 0/0/0. The
> regression target now fails unless AR/AW/W `stall_then_accept` SVA covers
> all match; VCS reports 3,287 attempts and 14/5/12 matches. This supplements
> current-candidate R101's compute-only AXI property no-success observations;
> it does not close broad compute requester × fault/backpressure crosses.
> RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 HOLD. See
> [R102 report](../docs/verification/COMPUTE_CLUSTER_AXI_STALL_SVA_R102_2026-10-30.md).

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
> `35c7670594c85d471bad1e5a975df7f16369c78f`; seven seeds × 24 profiles
> passed (168/168), each with 32/32 scenarios and UVM severity `0/0/0`.
> URG passed at 63/63 functional variables, 34/34 crosses, high-payload 1/1,
> mixed reset 4/4, kind×delay×reset 24/24, abort timing 7/7; assertions
> 13 success, 0 failure/incomplete, 2 UVM RAL no-attempts; covers 4/4.
> `ai_smoke` printed `TEST PASS`. Raw CP/writer toggle coverage remains
> 13.21%/41.81%; no waiver is claimed. Testbench models the compute/fetch/DMA
> endpoints, so this is CP-block evidence only, not V2/A10/V5 closure. See the
> [exact-SHA run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN35C7670_V2_CP_HIGH_PAYLOAD.md).

> **2026-10-19 CP seeded-random mixed-interaction follow-up:** Based on
> `35c7670` with the additive random target in the working tree, 200 seeds
> (`20262021..20262220`) passed the full CP UVM test: 200/200 logs, 32/32
> scenario bins each, UVM warning/error/fatal=`0/0/0`. URG passed 63/63
> variables, 34/34 crosses, mixed reset 4/4, kind×delay×reset 24/24, and
> abort timing 7/7; 13 assertions succeeded, 0 failed/incomplete, 2 UVM RAL
> no-attempts; covers 4/4. `ai_smoke` printed `TEST PASS`. Raw CP/writer
> toggle coverage remains 13.21%/41.81%. This closes only the selected
> randomized CP mixed error→abort→partial-reset→recovery slice, not V2/A10/V5.
> See [run record](../docs/verification/A10_DV_RUN_2026-10-19_CP_RANDOM_200.md).

> **2026-10-19 CP high-payload slice (`90757f5b` dirty-worktree evidence):**
> The seven-seed × 24-profile CP campaign completed 168/168 profiles. Each
> profile reached `scenario_bins=32/32`, the `CP_HIGH_PAYLOAD` marker, and UVM
> warning/error/fatal=`0/0/0`. URG measured `cp_cg` 63/63 variables and 34/34
> crosses, `cp_high_payload` 1/1, mixed reset 4/4, kind×delay×reset 24/24,
> abort timing 7/7; assertions were 13 success, 0 failure/incomplete, and two
> UVM RAL no-attempts, with 4/4 covers matched. The initial final gate had a
> stale 62/62 variable expectation; the corrected `check-coverage` passed.
> `ai_smoke` printed `TEST PASS`. The case checks v7 INT8 VDOT `length=ffff`,
> task ID `c3a5`, CPLQ base `0x78000` inside the 512 KiB SPAD, result
> `3e123456`, cycles `00010023`, elements `ffff`, four completion words, and
> exactly-once tail advancement. This is dirty-worktree evidence, not a
> fixed-SHA replay or V2/A10/V5 closure; endpoint compute/fetch/DMA behavior is
> still block-level modeled. See the [run record](../docs/verification/A10_DV_RUN_2026-10-19_CP_HIGH_PAYLOAD.md).

> **2026-10-19 exact-main V5 FP result-path mutation replay (`3cdb6cc`):**
> Detached baseline and restore passed FP dot UVM seeds `712345` and `987654`,
> each with 484/484 bit-exact scoreboard checks and UVM severity `0/0/0`.
> A one-bit product-path mutant produced real scoreboard mismatches (`0/424/0`)
> and failed the Makefile pass gate. This checks FP scoreboard sensitivity only;
> it does not close V1/A10/V5. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN3CDB6CC_FP_MUTATION.md).

> **2026-10-19 exact-SHA V5 completion-tail mutation replay (`0490a7f`):**
> CP UVM baseline and restore (`ai_cp_test`, seed `20261019`) passed with
> 31/31 scenario bins and UVM severity `0/0/0`. The final-word-index mutant
> omitted word 3 and advanced the tail early; the existing monitor/scoreboard
> reported 314 UVM errors. Compile logs were clean, and logs/VDBs are retained
> outside the repository. This is targeted checker-sensitivity evidence, not
> V2/V5 closure. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN0490A7F_COMPLETION_TAIL_MUTATION.md).

> **2026-10-19 exact-SHA V5 DMA accepted-write abort/drain mutation replay (`9a8fde0`):**
> Detached baseline and post-restore focused subsystem runs passed with UVM
> severity `0/0/0`. The premature-retirement mutant was caught by
> `accepted/completed=1/0 pending=1` and a drain-coverage miss (UVM `0/2/0`).
> Baseline/restored RTL SHA-256 matched and the worktree was clean. This is
> targeted checker-sensitivity evidence only; full V5 remains open. [Run
> record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN9A8FDE0_DMA_WRITE_ABORT_MUTATION.md).

> **2026-10-19 exact-SHA V5 CNM backpressure mutation replay (`200448c`):**
> On a detached clean worktree, `dma_spad_subsystem_test` seed `20261014`
> passed on baseline and post-restore with UVM severity `0/0/0`. The one-line
> denied-prefetch fallback mutant was detected by two
> `ap_cnm_request_stable_when_stalled` failures and CNM timeout/drain/result
> checker errors before the 150,000,000 ps testbench timeout. VCS returned RC 0,
> so classification uses the explicit checker evidence. This is one targeted
> checker-sensitivity replay—not full V5 mutation closure; the original
> historical failure artifact/fix SHA remain missing. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN200448C_CNM_MUTATION.md).

> **2026-10-19 exact-SHA V5 CNM protection-tag mutation replay (`6d97d65`):**
> At pushed source SHA `6d97d6511db78f3a177b72decb715505fdaadc7f`, the
> DMA/SPAD/CNM subsystem test passed baseline and post-restore with the
> protection marker, `TEST_DONE`, and UVM severity `0/0/0`. The one-line
> current-request-tag mutant was detected by 15 UVM errors, including
> response-tag/status mismatches and unauthorized protected writes. The mutant
> reached `TEST_DONE`, but UVM severity was `0/15/0`; it is not a pass. This is
> targeted sensitivity evidence, not full V5 mutation closure. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN6D97D65_CNM_PROTECTION_MUTATION.md).

> **2026-10-19 exact-main V2 CP seed expansion (`3855d51`):** Detached clean
> replay on pushed SHA `3855d513614782b14163e4a59c2be266b1c65998` passed
> 168/168 mixed profiles across seven seeds; every run had 31/31 scenario
> bins and UVM severity `0/0/0`. URG: CP 61/61 variables + 34/34 crosses,
> reset 4/4, kind×delay×reset 24/24, abort timing 7/7; 13 assertions
> succeeded, none failed/incomplete, two UVM RAL no-attempts; all four covers
> matched. Top `ai_smoke` passed. The 15 raw CP condition outcomes remain
> uncovered but retain the prior formal/assume-guarantee disposition; raw
> toggle and broader V2/A10/V5 closure remain open. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN3855D513_V2_CP_SEED_EXPANSION.md).

> **2026-10-19 exact-current-main V3 replay (`76cde0f`):** Clean exact-SHA
> replay passed 10 DMA–SPAD–CNM seeds, 16/64/300-cycle AXI RREADY stress,
> reset-delay cutpoints 0/1/2/3, standalone SPAD arbiter fairness/coverage,
> and top `ai_smoke`. The merged RREADY group reached 4/4 variables + 3/3
> crosses; parity×abort×reset reached 4/4 + 2/2. Assertions were 29 success,
> zero failure/incomplete, and two UVM RAL no-attempts. Standalone arbiter
> raw line/condition/branch/toggle=`100/86.89/100/10.73%`; subsystem raw DUT
> coverage and broader V3/A10/V5 requirements remain open. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN76CDE0F_V3.md).

> **2026-10-19 exact-SHA V2 CP replay (`aee74ef`):** Clean detached worktree;
> 72/72 configured mixed reset/error/abort profiles passed, each with 31/31
> scenario bins and UVM severity 0/0/0. URG CP functional coverage was 61/61
> variables + 34/34 crosses; reset words 4/4, mixed reset cross 24/24, abort
> timing 7/7. Assertions: 13 success, 0 failure/incomplete, two UVM RAL
> no-attempts; all four covers matched. CP raw condition=`237/252` (94.05%),
> line/FSM transitions/branch=100%; completion-writer line/condition/FSM
> transitions/branch=100%. Top `ai_smoke` passed. CP toggle remains open;
> the 15 raw-uncovered condition outcomes have existing formal/assume-guarantee
> disposition recorded in the RTM. This is not full V2/A10/V5 closure.
> [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAINAEE74EF_V2_CP.md).

> **2026-10-19 当前 `main` 的 V1 FP exact-SHA recheck（`1956f36`）：** clean detached worktree 中新跑 8 seeds × 200 vectors；8/8 PASS、每 seed 484/484 bit-exact、UVM severity 0/0/0、peak outstanding reads=2；六个 FP 功能 coverage groups 均 100%。这仅代表 FP block UVM 选定功能切片，不表示 full-domain parity/writeback formal 或 A10 coverage closure。详见[运行记录](../docs/verification/A10_DV_RUN_2026-10-19_MAIN1956F36_V1_FP.md)。

> **2026-10-19 最新 `main` 的 V1 FP directed 切片（`9e497a5`）：** FP dot core 与最大长度 parity 定向测试通过；四种 BF16/FP16 × A/B cutoff 均 drain 65,536 笔 reads 并完成无复位 recovery，Python FP model 19/19。仍不代表 full-domain formal 或 A10/V1–V5 sign-off。[运行记录](../docs/verification/A10_DV_RUN_2026-10-19_MAIN9E497A5_V1_FP_DIRECTED.md)。

> **2026-10-19 固定 SHA 的 V4 混合精度 DDR E2E（`2b18b5f`）：** 已推送 `main` 的 detached clean worktree 中，官方顶层 UVM 192-seed 回归全部通过；192 个日志均有 E2E PASS marker，非零 UVM severity 为 0。URG 的 E2E 组、四个逐事务 AXI 组和 Makefile 要求的 19 个功能点均为 100%。Assertions：20 项成功、0 失败/未完成、2 项 UVM RAL 内部属性未触发；3/3 AXI stall covers 命中。这是固定 SHA 的选定 V4 复跑，不代表 V4/A10/V5 全部闭环。[运行记录](../docs/verification/A10_DV_RUN_2026-10-19_MAIN2B18B5F_V4_E2E.md)。

> **2026-10-19 exact-SHA baseline replay (`2166334`):** A detached clean
> worktree at pushed SHA `21663348789175ad7dc74bc2934302255b25bb4b` passed
> selected FP directed/3-seed UVM and reference-model tests, DMA UVM 19/19,
> Control UVM 9/9, top `ai_smoke`, and 20/20 seeded top cases. DMA/Control
> severity summaries were zero and official URG reports were generated. This
> is a frozen-SHA reproducibility checkpoint, not complete A10 acceptance:
> FP parity-to-writeback formal remains open, as do CP lifecycle, broad V3/V4
> coverage disposition, and V5 review. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_MAIN2166334.md).

> **2026-10-19 latest SPAD arbiter coverage/formal follow-up (`d0ae9b5`):**
> Exact-source VCS/URG passed scheduler fairness, fallback, control priority,
> and response checks. Raw line/condition/branch/toggle=`100.00/86.89/100.00/10.73%`.
> VC Formal `V-2023.12-SP2` proved 8/8 decode/response invariants
> non-vacuously and reached 4/4 covers, dispositioning all eight raw condition
> tuples from the URG report without synthetic hits/waivers. Exact-source top
> smoke and 20-case seeded top regression passed. This is a selected scheduler
> slice, not V3/A10/V5 closure. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_SPAD_ARB_PRIORITY.md).

> **2026-10-19 earlier SPAD arbiter coverage follow-up (`cc89574`, superseded by `a1e87d9` below):**
> VCS/URG standalone run passed the 10k-cycle scheduler fairness test and 12
> directed legal RR fallback request cases. Six previously unhit data-plane
> fallback source lines are now covered. `ai_spad_arbiter` line/condition/
> branch/toggle=`96.79/81.97/96.97/6.22%`; CPL selection line/branch and raw
> condition tuples remain open with no waiver. Exact-main top `ai_smoke`
> printed `TEST PASS`. This is not full V3/A10/V5 closure. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_SPAD_ARB_COVERAGE.md).

> **2026-10-19 exact-SHA V3 subsystem replay (`7271c54`):** Detached clean worktree; full DMA-SPAD-CNM test 10/10 seeds, RREADY 16/64/300-cycle stress 3/3 profiles, reset cutpoints 0/1/2/3 all passed with UVM warning/error/fatal=`0/0/0`; top `ai_smoke` passed. Combined URG `dma_rready_stall_cg`=4/4 variables + 3/3 crosses and `cnm_parity_abort_reset_cg`=4/4 + 2/2; assertions 29 success, 0 failure/incomplete, 2 UVM RAL no-attempts. This closes only selected scenarios, not overall V3/A10/V5. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_V3_CLEAN_REPLAY.md).

> **2026-10-19 exact-SHA V3 parity/abort/reset replay (`c500b3d`):** On a detached clean worktree at `c500b3daba529d3123ffe250644f3297ae8c16f3`, 20 randomized seeds plus four forced reset delays (`0..3` cycles) passed with UVM warning/error/fatal=`0/0/0`; combined URG covered `cnm_parity_abort_reset_cg` at 4/4 variables and 2/2 crosses, and 29/31 assertions succeeded with 0 failures/incomplete (two UVM RAL no-attempts). Top `ai_smoke` passed. This closes only the exercised CNM parity-error + DMA abort-drain + shared-reset timing slice; broader V3/A10/V5 remain open. [Run record](../docs/verification/A10_DV_RUN_2026-10-19_V3_FAULT_ABORT_RESET.md).

> **2026-10-18 CP tile load-DMA error/recovery follow-up (pushed `c500b3d`):** `CP_TILE_PINGPONG` runs a successful three-tile job, a first-load DMA error (`dma_done` + `dma_error`, code `0xA`), then a successful restart. Focused/full CP UVM, 3-seed regression, 72/72 three-seed × 24-profile URG campaign, and top `ai_smoke` passed. Every profile log reported `tiles=7/6/6 events=3 dma_errors=1 recovery_events=1 error_completion_starts=0`; UVM severity=`0/0/0`, scenario bins=`31/31`, `cp_cg`=`61/61` variables + `34/34` crosses, abort timing=`7/7`. A detached clean-worktree replay at exact SHA `c500b3daba529d3123ffe250644f3297ae8c16f3` also passed 72/72 profiles and top `ai_smoke`, with worktree clean before/after. No product RTL/SPEC/ABI change. This closes one directed tile error/recovery slice only; broader V2/A10/V5 remain open. [Run record](../docs/verification/A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md#follow-up-tile-load-dma-error-propagation).

> **2026-10-18 CP decode busy-hold and formal follow-up (UVM based on `2317abb`; formal based on pushed `5439cb7`):** The macro-child decode-abort sequence synchronizes to the child request/response, and `CP_SUBMIT_GUARD` verifies two cycles of `ST_DECODE` hold while `compute_busy=1`, then exactly one launch/completion after release. Focused/full CP UVM, 72/72 coverage profiles, and top `ai_smoke` passed with UVM severity `0/0/0`; every full-suite run had scenario bins `31/31`. URG CP line/FSM/branch=`250/250`, `6/6` states + `13/13` transitions, and `67/67` branches; condition=`229/252` (90.87%, 23 outcomes remain raw-uncovered). VC Formal setup check reported no issues; 5/5 assertions proved non-vacuously and 3/3 covers reached, including busy-hold/release/launch and tile activity ownership. Of the 23 raw condition outcomes, 5 now have formal unreachable proofs, 2 are definitionally impossible, 1 is semantically masked, and 15 need cross-layer review. No product RTL/SPEC/ABI change. Evidence is from shared-worktree increments, not a clean-SHA replay; V2/A10 remain open. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_CP_DECODE_BUSY.md).

> **2026-10-18 CP descriptor-fetch done ownership smoke check:** With a testbench-only monitor in top `ai_smoke`, the integrated descriptor-source mux produced 56 `desc_done` pulses; every pulse coincided with CP `ST_FETCH`. `ai_smoke` printed `TEST PASS` on Rocky Linux 8.10 / VCS `V-2023.12-SP1_Full64`. This is exercised integration evidence only; it does not change the raw URG score or close the all-input/formal disposition of the fetch-done condition. No DUT RTL/SPEC/ABI change. See the [CP run record](../docs/verification/A10_DV_RUN_2026-10-18_CP_DECODE_BUSY.md#integrated-descriptor-fetch-done-ownership-smoke-check).

> **2026-10-18 current-worktree AXI-Lite SLVERR response follow-up (HEAD `bd3a7cd`):**
> Added top-E2E checks for unmapped register `0x1fc`: writes and reads return
> SLVERR and reads return zero. Focused run, the 16-seed FP-length matrix,
> the 192-seed E2E campaign, and `ai_smoke` passed; UVM warning/error/fatal
> counts were `0/0/0`, and URG AXI-Lite response plus E2E groups were 100%.
> DECERR is legal AXI but excluded from this direct-IP coverage boundary,
> which has no interconnect decoder. Shared dirty worktree; not a clean-SHA
> replay and not full A10/V5 closure. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_AXILITE_SLVERR.md).

> **2026-10-18 current-worktree V4 narrow-32 AXI E2E follow-up (HEAD `77b2ceb`):**
> Added a scoreboard-checked 32-bit DMA read/write round-trip at non-128-bit-
> aligned addresses. The 192-seed mixed-precision DDR E2E campaign passed
> 192/192 with UVM warning/error/fatal=`0/0/0`; merged URG AXI4 and E2E groups
> are both 64/64 (100%), and `ai_smoke` passed. This was run on a shared dirty
> worktree, not a clean commit replay; raw RTL code coverage and the broader
> V4/V5/A10 closure remain open. See the [narrow-32 run record](../docs/verification/A10_DV_RUN_2026-10-18_NARROW32_AXI.md).

> **2026-10-18 exact-main V4 mixed-precision DDR E2E replay (`968c8bc`):**
> The top-level 192-seed UVM campaign passed 192/192 with UVM
> warning/error/fatal=`0/0/0`; selected E2E functional points and all four
> transaction-level AXI gap/backpressure groups reached 100%. The aggregate
> URG score was 90.63%, with a malformed generic AXI4 `kind` coverpoint
> (32-bit `int` auto-binned into 64 ranges for a five-value enum) and unhit
> narrow-32 / >16-beat / non-OKAY AXI-Lite scenarios. These are recorded as
> coverage-model or scenario-scope follow-ups, not silently waived. V4
> selected end-to-end behavior is reproduced; V4/V5/A10 remain open. See the
> [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-v4-mixed-precision-ddr-e2e-replay-at-968c8bc).

> **2026-10-18 exact-main V3 DMA–SPAD–CNM/RREADY replay (`575f1ae`):**
> Three subsystem seeds and the dedicated 16/64/300-cycle AXI RREADY stress
> passed with UVM severity `0/0/0`. The merged URG covered all 14 selected
> functional groups at 100%; 29/31 assertions had successful attempts, with
> 0 failures/incomplete and two UVM RAL no-attempts. Exact-SHA top `ai_smoke`
> passed. This is selected subsystem evidence, not V3/A10 closure; fairness,
> broad fault×abort×reset, DUT-only residual coverage, and full queue/completion
> lifecycle remain open. See the [run evidence](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-pushed-main-v3-dma-spad-cnm-and-rready-replay-at-575f1ae).

> **2026-10-18 exact-main CP/Completion replay (`b4c9f8b`):** Three seeds ×
> 24 mixed profiles passed 72/72, each with 31/31 scenario bins and UVM
> severity `0/0/0`. URG `cp_cg` was 61/61 variables + 34/34 crosses; the
> mixed reset and abort-timing groups passed their gates. Thirteen assertions
> succeeded, zero failed/incomplete, two UVM RAL no-attempts; four covers
> matched. CP raw condition/branch coverage remains 90.48%/97.01%, so this is
> not full CP/V2 closure. See the [run evidence](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-cpcompletion-coverage-replay-at-b4c9f8b).

> **2026-10-18 exact-main FP directed increment (`bcc1fba`):** `dot-core-test`
> passed the directed core suite and four maximum-length final-word parity
> cases (BF16/FP16 × A/B); all 65,536 accepted reads drained, failed jobs made
> no result write, peak outstanding was 2, and each post-error recovery passed.
> This is a V1 simulation increment; full-domain formal parity disposition
> remains open. See the [run evidence](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-fp-directed-core-and-maximum-parity-replay-at-bcc1fba).

> **2026-10-18 exact pushed-main selected baseline (`1fe66f0`):** FP UVM
> passed 3 seeds × 200 random vectors per format with 484/484 bit-exact
> transactions per seed; Python FP model tests passed 19/19; Control UVM
> passed 9/9 tests; DMA UVM passed 16/16 tests; and top `ai_smoke` passed
> from an isolated worktree at the exact SHA. UVM severity was `0/0/0` for
> FP/Control/DMA. This is selected G0 reproducibility, not A10 closure. See
> the [run evidence](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-pushed-main-baseline-replay-at-1fe66f0).

> **2026-10-18 CP macro event-only frontend-error increment (tree based on pushed `651b7a7`):** Added two `CPLQ_SIZE=0` macro-child cases for invalid descriptor (`0x15a0`, `ERR_DESC`) and dependency timeout (`0x15b0`, `ERR_DEPENDENCY`). Each checks one parent event/head advance and no child launch/later fetch/completion write/CPLQ tail advance. Focused/full CP UVM, 72/72 three-seed × 24-profile coverage runs, URG gates, and top `ai_smoke` passed with UVM severity `0/0/0`. CP raw line/condition/FSM/branch=`100/90.48/100/97.01%`; remaining CP bins, V2, and A10 remain open. This tests the existing no-CPLQ compatibility path only; no RTL/SPEC/ABI changed. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-cp-macro-child-event-only-frontend-errors-with-cplq-disabled).

> **2026-10-18 CP macro-child error ownership increment (candidate based on pushed `1c1ab96`):** Added UVM checks for invalid child-descriptor and dependency-timeout failures under an active macro parent. Both paths return the parent task ID with the expected error and suppress child launches. Focused case, full CP UVM, 72/72 coverage profiles, and top `ai_smoke` passed; UVM severity=`0/0/0`; CP raw coverage improved to 228/252 conditions and 65/67 branches. Remaining raw bins and V2/A10 are still open. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-cp-macro-child-error-ownership-increment).

> **2026-10-18 CP tile-launch ownership follow-up (tree based on `522df73`):** Added a tile-state launch ownership SVA/cover. Focused tile case passed (3 cover matches); full CP coverage matrix passed 72/72 profiles and URG merge; all four covers matched, new tile cover=216, UVM severity=`0/0/0`, 0 assertion failures/incomplete. Top `ai_smoke` passed. Raw DUT coverage: CP lines 100%, condition 89.68%, FSM 100%, branch 94.03%; completion writer line/condition/FSM/branch all 100%. Four CP raw branch bins and remaining condition bins are not closed; see the [detailed disposition](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-cp-tile-launch-ownership-and-raw-code-coverage-disposition).

> **2026-10-18 CP submit-guard follow-up (tested tree based on `7aafb72`):** Added dependency-wait `ST_DECODE` re-submit coverage and synchronized the mixed abort/reset testbench sampling. Focused assertion/cover, full CP suite, 72/72 three-seed × 24-profile URG matrix, and top `ai_smoke` passed; UVM severity was `0/0/0`, all three CP covers matched, and URG reported 0 assertion failures/incomplete. This is not raw DUT code-coverage closure or full V2/A10 acceptance. Detailed results: [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-cp-submit-guard-and-mixed-reset-synchronization-follow-up).

> **Latest exact-main V2 CP/Completion run (`d0babfb`, 2026-10-18):** 72/72 profiles passed at the pushed SHA; every profile had 31/31 scenario bins and UVM warning/error/fatal=`0/0/0`. URG `cp_cg` 61/61 variables + 34/34 crosses; reset-word bins 4/4; kind×delay×reset crosses 24/24; abort timing 7/7. Assertions: 11 success, 0 failure/incomplete, two UVM RAL no-attempts; both covers matched. Exact-main `ai_smoke` passed. This closes only the tested CP mixed reset interaction; raw DUT code coverage, remaining CP lifecycle, external descriptor/DMA integration, and global A10/V5 are still open. See [the run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v2-cpcompletion-replay-at-d0babfb).

> **2026-10-18 exact-main V3-CUR-04 parity/abort/reset slice (`ae925bd`):** The exact-main 20-seed replay passed with UVM warning/error/fatal=`0/0/0`; a directed zero-cycle shared-reset run then closed the selected `cp_reset_timing` and `fault_abort_reset_x_timing` bins at 2/2 each (100%). URG assertions: 29 successful, 0 failures/incomplete, 2 unattempted UVM RAL internals; top `ai_smoke` passed. This evidence is limited to the modeled parity-error × DMA-abort-drain × shared-reset scenario, not broad V3 or A10 closure. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-v3-parityabortreset-timing-coverage-addendum-ae925bd).

> **2026-10-18 exact-main V3 DMA-SPAD-CNM replay (`4c4738a`):** Ten seeds (`20261030..20261039`) passed on pushed SHA `4c4738a6240f9ebb3b6b2d6705c2232ce4414ef9`, all UVM warning/error/fatal=`0/0/0`; URG had 14 groups and 29/31 assertions successful, with 0 failures/incomplete and 2 UVM RAL no-attempts. GEMV-shape, parity-contention, arbiter, reset-phase, and error-overlap groups were 100%; top `ai_smoke` printed `TEST PASS`. Broader V3 fairness/fault×abort×reset and A10/V5 closure remain open. See the [exact-main run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-main-v3-dma-spad-cnm-10-seed-replay-at-4c4738a).

> **2026-10-18 DMA write-ID slot coverage increment (candidate based on `3014be4`):** Added `dma_store_four_booo_test`, which accepts all four write IDs (`8..11`), returns B responses newest-first (`11..8`), checks 32 DDR words, and confirms no pending response. Focused and full 17-test DMA UVM regressions passed with per-test warning/error/fatal=`0/0/0`; random stress passed 20/20 and top `ai_smoke` printed `TEST PASS`. URG reports `ai_dma_write_response_tracker` line/condition/toggle/branch=`100.00/66.67/85.71/100.00%`; all 11 named DMA DUT SVA had nonzero successes, with no failure/incomplete. This closes only the write-slot slice; reachable burst-planner edge bins, full V3 and A10/V5 remain open. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-dma-four-write-id-slot-coverage-increment).

> **2026-10-18 exact-current-main DMA block replay at `3310d3d`:** VCS/URG
> passed all 16 DMA UVM tests with per-test UVM warning/error/fatal=`0/0/0`;
> random stress scored 20/20 transfers. `dma_cmd_cg` reached 14/14 variables
> and 5/5 crosses. All 11 named DMA DUT SVA had real successes, with 0
> failure/incomplete; two UVM RAL assertions were unattempted. DUT-only
> `ai_axi128_dma` line/condition/toggle/FSM/branch=`93.48/71.04/36.69/53.57/86.92%`.
> The same SHA passed top `ai_smoke`. Residual RTL bins and full V3/A10 closure
> remain open. See the [exact-main run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-dma-block-uvmurg-replay-at-3310d3d).

> **2026-10-18 V3 prolonged AXI RREADY stress increment (candidate based on `0da26d4`):** Focused 16/64/300-cycle backpressure profiles each held `RVALID` and its payload stable, drained four accepted read responses, and matched all 32 SPAD words; UVM warning/error/fatal=`0/0/0` for each. URG stall-length bins and stall×completion crosses were 3/3 (100%); 8 DUT-facing assertions plus one UVM check succeeded, 0 failed/incomplete, with two UVM RAL no-attempts. The default three-seed DMA-SPAD regression and `ai_smoke` passed. This is prolonged response-channel evidence, not complete arbiter fairness or V3/A10 closure. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-v3-prolonged-axi-rready-backpressure-profiles).

> **2026-10-18 exact-current-main V3 DMA-SPAD replay at `188e523`:** The
> three-seed subsystem regression passed with `[TEST_DONE]`, nine runtime
> pass markers per seed, and UVM warning/error/fatal=`0/0/0`. The focused
> 16-cycle AXI RREADY stall held the response payload stable and matched all
> 32 SPAD words. Selected URG groups were 100%; 29 assertions succeeded,
> 0 failed/incomplete, two UVM RAL no-attempts, and 2/2 covers matched. This
> is selected subsystem/backpressure evidence, not full V3/A10 closure. See
> the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v3-dma-spad-subsystem-replay-at-188e523).

> **2026-10-18 exact-current-main V2 CP/completion matrix at `1655db9`:**
> UVM `cov-regress` passed 72/72 mixed-error/abort/reset profiles, each with
> 31/31 scenario bins and severity `0/0/0`. URG `cp_cg` was 61/61 variables +
> 34/34 crosses; reset-word coverage 4/4, kind × delay × reset cross 24/24,
> and abort timing 7/7. Eleven assertions succeeded; 0 failed/incomplete, two
> UVM RAL no-attempts, and 2/2 covers matched. The real CP, completion writer,
> and tile scheduler were exercised, while descriptor-fetch/DMA endpoints are
> behavioral models. This closes the tested CP lifecycle matrix, not external
> descriptor-fetch integration, V3 DMA/SPAD concurrency, raw DUT coverage, or
> full A10. See the [run evidence](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v2-cpcompletion-full-suite-replay-at-1655db9).

> **2026-10-18 exact-current-main V1 FP replay at `08f398e`:** Directed core
> and all four maximum-length BF16/FP16 A/B parity drain/recovery scenarios
> passed. Three UVM seeds passed 484/484 bit-exact transactions each with
> UVM warning/error/fatal=`0/0/0`; URG selected FP groups were 100%, with
> 22,676 successes on the DUT stalled-request stability assertion and both
> selected covers matched. Python model passed 19/19. DUT line/condition/FSM/
> branch coverage was 97.96/97.00/85.71/92.86%; residual coverage disposition
> is explicit: the main FSM is 5/5 states and 10/10 transitions, while
> `pending_error_r` is 6/6 states and 14/18 transitions. Three prior-error to
> protection transitions have canonical formal dispositions; parity to
> protection and full-domain parity-to-writeback remain open. Three raw RTL
> lines/four branches remain unhit, with legal-interface invariant mappings
> documented separately. This is a scoped V1 slice, not V1/A10 closure. See
> the [run evidence](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v1-fp-replay-at-08f398e).

> **2026-10-18 exact-current-main V2 CP replay at `e24b770`:** The full CP
> scenario suite passed across 72/72 mixed error/abort/reset profiles (three
> seeds × 24 profiles), each with 31/31 scenario bins and UVM severity
> `0/0/0`. URG: `cp_cg` 61/61 variables + 34/34 crosses, reset cutpoints
> 4/4, kind×delay×reset cross 24/24, abort timing 7/7; 11 assertions
> succeeded, none failed/incomplete, two UVM RAL internals had no attempts,
> and 2/2 covers matched. This closes only the exercised mixed-reset slice,
> not full V2/A10. See the [exact-main run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v2-command-processor-mixed-reset-replay-at-e24b770).

> **2026-10-18 exact-current-main V4 randomized DDR E2E at `3345286`:** The
> 192-seed campaign passed 192/192 at the exact pushed SHA with zero nonzero
> UVM warning/error/fatal logs. URG `e2e_cg`, four per-transaction AXI gap/
> back-pressure groups, and every Makefile-gated functional point were 100%;
> assertions had 20 successes, 0 failures/incomplete, 2 UVM RAL no-attempts,
> and all 3 AXI stall covers matched. This closes only the selected randomized
> E2E slice, not broad V4, global DUT-only coverage review, or A10/V5. See the
> [exact-main run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v4-randomized-ddr-e2e-at-3345286).

> **2026-10-18 exact-current-main V3 DMA-SPAD replay at `b1257fb`:** The
> focused 16-cycle AXI RREADY-stall case and three-seed subsystem regression
> passed at the exact pushed SHA; each seed had `[TEST_DONE]`, nine runtime
> pass markers, and UVM warning/error/fatal=`0/0/0`. URG selected functional
> groups were 100%, with 29 assertions successful, 0 failed/incomplete, and
> two UVM RAL internals unattempted. This closes only the exercised response-
> backpressure/subsystem slice; broader V3 and A10/V5 remain open. See the
> [exact-main run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v3-dma-spad-replay-at-b1257fb).

> **2026-10-18 exact-current-main CP/completion replay at `9dce04d`:** The
> 3-seed × 24-profile mixed prefix-error/abort/reset campaign passed 72/72;
> every run hit 31/31 scenario bins and UVM warning/error/fatal=`0/0/0`.
> URG `cp_cg` was 61/61 variables + 34/34 crosses, reset cutpoints 4/4,
> kind×delay×reset cross 24/24, abort timing 7/7. Ten testbench/DUT-facing
> assertions plus one UVM framework check succeeded; two UVM RAL internals
> were unattempted, with 0 failures/incomplete and 2/2 covers matched. This
> closes only the exercised mixed-reset interaction, not all CP/V2/A10 work.
> See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-v2-command-processor-mixed-reset-replay-at-9dce04d).

> **2026-10-18 exact-main FP replay at `880c697`:** FP directed core and
> maximum-length parity tests passed; three UVM seeds passed 484/484 each with
> UVM severity `0/0/0`, peak outstanding=2, and six selected FP functional
> groups at 100%; Python model passed 19/19. URG reports one DUT request-
> stability SVA with 22,676 real successes, one UVM component-name check, two
> UVM RAL no-attempts, and both covers matched. DUT line/condition/FSM/branch
> was `97.96/97.00/85.71/92.86%`; code-coverage disposition and full-domain
> parity formal remain open. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-fp-baseline-at-880c697).

> **2026-10-18 current-main FP stall/latency stress:** At pushed `main` SHA
> `90ddbbd`, six seeded unit-SPAD profiles passed with BF16/FP16 lengths
> 1..1024 and request back-pressure / ordered response jitter settings
> `0/0`, `30/3`, and `60/11`; read-only audit checked all 108 format/length
> rows. This is not DMA contention, UVM/URG coverage, or full-domain formal
> closure. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-current-main-fp-spad-latencybackpressure-stress).

> **2026-10-18 V3 DMA RREADY-backpressure increment:** A new subsystem test
> holds the DUT-side AXI `RREADY` low for 16 cycles, checks response tuple
> stability, then checks all four bursts and 32 SPAD words. Focused run and
> three-seed `subsystem_regress` passed with UVM warning/error/fatal=`0/0/0`;
> URG merge and top `ai_smoke` passed. This is a bounded AXI response-stall
> scenario only; system fairness and V3/A10 closure remain open. See the
> [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-v3-axi-rready-downstream-backpressure-increment).

> **2026-10-18 baseline replay at `edf115cd`:** Control UVM passed 9/9 and DMA UVM passed 16/16 (current DMA Makefile count; older 15-test note is stale), with per-test severity 0/0/0 and `[TEST_DONE]` / scoreboard pass markers. Top `ai_smoke` exited 0 (`TEST PASS`). Non-fatal compile clock-skew warnings were present. URG and seeded top 20-case `ai_run` were not run; this does not represent clean-worktree or full A10 closure. See the [A10 run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-edf115cd-controldmatop-baseline-replay).

> **2026-10-18 `edf115cd` FP dot UVM/URG replay:** Three seeds (`712345`, `987654`, `20261015`) each passed 484/484 mixed BF16/FP16 bit-exact transactions, UVM warning/error/fatal=`0/0/0`, peak outstanding=2. URG merged at 100%; all six selected functional groups were 100%. One DUT-facing request-stability assertion succeeded (22,676 real successes), one UVM component-name check succeeded, two UVM RAL internal no-attempts are not counted as DUT passes, and both selected covers matched. Python reference-model tests passed 19/19 from the model directory. This is focused V1 evidence, not full parity/writeback formal or A10 closure. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-edf115cd-fp-dot-uvmurg-replay).

> **2026-10-18 V2 command-processor reset sweep:** On the dirty worktree based on `d1ed485`, CP UVM mixed prefix-error/abort/reset coverage passed 72/72 runs (3 seeds × 24 combinations), each with 31/31 scenario bins and UVM severity `0/0/0`. Reset was injected at completion word cut points 0, 1, 2, and 3; URG covered all 4 reset bins and all 24 kind × abort-delay-class × reset-word cross bins. `cp_cg` aggregate is 61/61 variables + 34/34 crosses, 100%. Eleven assertions succeeded, 0 failed/incomplete, two UVM RAL internals had no attempts; both cover properties matched. This is a focused V2 interaction closure, not full command-processor or A10 closure. Exact evidence and repro command: [2026-10-18 A10 run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md).

> **2026-10-18 `edf115c` CP mixed error/abort/reset rerun:** CP RTL/UVM inputs matched HEAD `edf115c` (only documentation changed during the run). `make -C dv/block/command_processor/uvm cov-regress SEEDS='20261017 20261018 20261019' COV_OUT=/tmp/nmaforge_cp_mix_reset_edf115c_20261018` exited 0 on Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`: 72/72 runs, each `scenario_bins=31/31`, UVM warning/error/fatal=`0/0/0`. URG merge and hard `check-coverage` passed: `cp_cg` 61/61 variables + 34/34 crosses, `cp_mixed_reset_words` 4/4, `cp_mixed_kind_delay_reset_cross` 24/24, `abort_timing_cg` 7/7. This is closure evidence only for the exercised CP mixed error/abort/reset slice; raw code-coverage disposition, cross-layer and other V2 residuals, and V5 remain open—not full CP V2/A10. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#cp-mixed-errorabortreset-rerun-at-head-edf115c-2026-10-18).

> **2026-10-18 reachable CP fetch/macro abort increment:** From baseline HEAD `189cd2a5f4a0d2542387e9b3b5a6169cc175d804`, the existing `CP_FETCH_ABORT` and `CP_MACRO_CHILDREN` scenarios now exercise direct `ST_FETCH` abort on the `fetch_done` cycle with `abort_pending=0`, plus macro child-fetch and child-decode aborts. All 72 runs (3 seeds × 24 profiles) passed with scenario bins 31/31 and UVM warning/error/fatal `0/0/0`; all logs hit the three new abort-route bins. URG `/tmp/nmaforge_a10_cp_reachable_cov_r1_20261018/coverage/urg_merged/`: `cp_cg` 61/61 variables + 34/34 crosses, `abort_timing_cg` 7/7 variables. Assertions: 11 successes, 0 failure/incomplete, 2 UVM RAL no-attempts; 2/2 cover properties matched. The Makefile `check-coverage` gate requires the 7/7 abort group and passed against this report. Only these three reachable paths are closed; this is not all CP code coverage or V2 closure. See [the run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-cp-reachable-fetchmacro-abort-coverage).

> **2026-10-18 `edf115c` exact-commit FP dot-core aggregate:** Tracked worktree clean; `make -j -C dv/block/compute/fp/sim dot-core-test DOT_CORE_OUT_DIR=/tmp/nmaforge_a10_fp_dotcore_edf115c_20261018 DOT_CORE_PARITY_MAX_OUT_DIR=/tmp/nmaforge_a10_fp_parity_edf115c_20261018` passed on Rocky 8.10 / VCS `V-2023.12-SP1_Full64`. The legacy BF16 dot marker passed, then all four BF16/FP16 final-A/final-B maximum-length parity cases passed: each drained 65,536 reads at prefix 65,534, peak outstanding=2, 98,306 cycles, and recovered without reset to `0x3f800000`. `make -j` serialized the VCS compiles successfully; a non-fatal clock-skew warning was present. Focused aggregate only, not UVM/URG, formal, or full A10; `ai_smoke` was not rerun because `edf115c` has no RTL change. See the [exact-commit run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-edf115c-clean-tracked-worktree-fp-aggregate-verification).

> **2026-10-18 current-main replay:** At SHA `452813f`, Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64` passed F…169 tokens truncated…1103' OUT=/tmp/nmaforge_cp_final3_retry_20261016 COV_OUT=/tmp/nmaforge_cp_final3_retry_20261016/coverage VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg`; also `make check-coverage COV_OUT=/tmp/nmaforge_cp_final3_retry_20261016/coverage` | Focused cases 25/22/26 and default suite pass; 27/27 scenario bins. Coverage campaign: 18/18 seed/profile logs and VDBs, severity 0/0/0; URG 47/47 functional variables + 10/10 crosses. CP DUT line/condition/toggle/FSM/branch=`100.00/76.10/9.68/100.00/88.06%`; writer=`97.44/100.00/28.74/100.00/91.67%`. No RTL/SPEC/ABI change or exclusions. Illegal FSM injection is robustness stimulus, not legal traffic. Residual CP bins and V2/V5/clean-SHA closure remain open. See the linked A10 run record. |
| Command Processor completion-writer illegal-state recovery coverage addendum (2026-10-16) | Real `ai_command_processor` + `ai_completion_writer`; testbench-only force/release of writer state `2'b11` while idle | Rocky 8.10 / VCS V-2023.12-SP1; focused `CP_ONLY_CASE=28`; then from `dv/block/command_processor/uvm`, `make cov-regress SEEDS='20261081 20261082 20261083' OUT=/tmp/nmaforge_a10_cp_writer_fsm_cov_20261016 COV_OUT=/tmp/nmaforge_a10_cp_writer_fsm_cov_20261016/coverage VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg`; independently re-ran `make check-coverage` and verified all 18 logs | Writer default branch returns to IDLE with no SPAD write, done/busy pulse, or pointer movement; a subsequent legal task completes. Focused case passed. All 18 seed×profile logs report 29/29 scenarios, recovery marker, UVM warning/error/fatal=0/0/0; URG `cp_cg` 49/49 variables + 10/10 crosses. DUT-only CP line/condition/toggle/FSM/branch=`100.00/83.67/10.10/100.00/88.06%`; writer=`100.00/100.00/28.74/100.00/100.00%`, branches 12/12. `make check-coverage` passes. Illegal state is robustness fault injection, not legal protocol stimulus; no RTL/SPEC/ABI change. CP residual condition/toggle, fault×abort×reset cross-layer closure, and clean fixed-SHA replay remain open; see the A10 run record. |
| Command Processor macro child descriptor-fetch error (2026-10-16) | Real `ai_command_processor` + `ai_completion_writer`; UVM fetch endpoint returns `ERR_FETCH` on the second child descriptor of a 3-child macro | `make run SEED=20261016 OUT=/tmp/nmaforge_a10_macro_child_fetch_error_focus_20261016`; `make cov-regress SEEDS='20261016 20261017 20261018' MIXED_COV_CASES='1-0 1-1 1-3 2-0 2-1 2-3' OUT=/tmp/nmaforge_a10_cp_macro_fetch_error_cov_20261016`; followed by top `make ai_smoke` | First child completes; second child fetch fails; parent ID `0x1550` receives one `ERR_FETCH` completion; third child does not launch. Focused full suite passes; all 18 seed/profile logs/VDBs pass with UVM warning/error/fatal=0/0/0 and marker present. URG `cp_cg` 49/49 variables + 10/10 crosses; CP DUT line/condition/toggle/FSM/branch=`100.00/85.66/10.28/100.00/92.54%`; completion writer=`100.00/100.00/28.74/100.00/100.00%`. Five CP interface SVA have non-vacuous successes `960/6244/1390/54/54`, 0 failure/incomplete; two no-attempts are UVM RAL internals. `ai_smoke` PASS. Testbench-only; no RTL/SPEC/ABI/source-list change. Residual condition/toggle and cross-layer fault×abort×reset closure remain open; dirty-tree evidence, not clean frozen-SHA replay. |
| SPAD arbiter sustained and seeded request-mode round-robin fairness (2026-10-18 refresh) | `ai_spad_arbiter` directed testbench; continuously pending core, banked/CNM and DMA clients | `cd dv/subsystem/top_smoke/sim && make ai_spad_arb_run`; followed by `make ai_smoke` | Retains the 30-cycle directed and 300-cycle seeded checks. Adds a configurable seeded request-mode run (`+SPAD_RR_MODE_CYCLES=10000`) with xorshift seed `0xA10D2026`, changing each accepted client's request form among core scalar/line, banked/CNM, and DMA scalar/line while preserving valid until grant. Checks client tag, one grant maximum per cycle, no wait beyond two ungranted cycles, every mode hit, then drains pending requests. | Rocky 8.10 / VCS `V-2023.12-SP1_Full64`: default 300-cycle and 10,000-cycle runs PASS; 10,000-cycle phase plus 2 tail-drain grants; total grants core/banked/DMA=`3334/3334/3334`, max wait=`2/2/2`; request-mode counts core scalar/line=`1654/1680`, banked/CNM=`1667/1667`, DMA scalar/line=`1659/1675` (all six nonzero). Existing CNM/DMA contention remains 6/6 and response-parity check passes; `ai_smoke` prints `TEST PASS`. This is prolonged scheduler-admission fairness under held requests; the arbiter has no downstream ready signal, so it does not model memory response back-pressure or establish long system-level fairness. Testbench/target/docs only; no product RTL/SPEC/ABI change. See [A10 SPAD fairness run record](../docs/verification/A10_DV_RUN_2026-10-18_SPAD_RR.md). |
| Compute-engine block-validation expansion (2026-10-21) | Direct CNN line-buffer/KV, Matrix datapath, and SFU cores; existing CNM, mixed-FP, and top/shared-fabric environments | `make -C dv/block/compute/cnn_kv/sim random-latency-test SEED=20261021`; `make -C dv/block/compute/matrix/sim datapath-random-test SEED=20261021`; `make -C dv/block/compute/sfu/sim random-latency-test SEED=20261021`; aggregate `make -C dv/subsystem/tensor_datapath/sim cluster_regress CLUSTER_TAG=multi_engine_20261021_final CLUSTER_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261021_final` | All direct RTL gates PASS: CNN/KV 24 convolutions + 24 KV round trips, 596/596 read responses, 7-cycle max latency and 280 ready stalls; Matrix 10,072 cases; SFU 64 cases across all 8 opcodes and lengths 1/2/3/4/7/8/15/16, 1,038/1,038 reads/responses, 426 total writes, 7-cycle max latency and 532 ready stalls. Aggregate exit 0 / `MULTI_ENGINE_COMPUTE_CLUSTER_PASS`; CNM A2.2/GEMV and Matrix A3 gates, 10 DMA–SPAD–CNM seeds, 3 FP UVM seeds (212/212 bit-exact each, warning/error/fatal=0/0/0), FP model 19/19, A4 reference 10,000 cases, and top smoke (20 seeded INT8 cases, `TEST PASS`) completed. SFU testing found missing GELU/SiLU threshold branches; RTL and SPEC were updated and 64/64 passed after correction. Full-cluster formal, DUT-only code-coverage disposition, simultaneous engine dispatch, and broad per-engine fault/reset combinations remain open. See [validation run record](../docs/verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md). |
| Compute-cluster verification closure follow-up (2026-10-21) | Full Matrix core; causal Softmax zero-token boundary; all seven production compute engines under serial dispatch; top DUT-only code coverage | `make -C dv/subsystem/tensor_datapath/sim cluster_regress CLUSTER_TAG=multi_engine_20261021_complete CLUSTER_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261021_complete AI_SEED=20261021`; plus `make -C dv/block/command_processor/formal completion-ownership OUT=/tmp/nmaforge_compute_cluster_cp_serial_formal_20261021 VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf` | Aggregate exit 0 / `MULTI_ENGINE_COMPUTE_CLUSTER_PASS`. Matrix: five numerical/layout cases, ten config/parity/protection/abort/watchdog faults, post-fault recovery, bank 64/64 and SPAD 49/49 responses. SFU: causal query token 0 at lengths 1 and 7, all 64 vectors pass. Fixed Matrix prefetch-valid and watchdog-error-state defects. VC Formal on actual `ai_accel_compute_cluster`: 3/3 assertions proven, 7/7 engine covers reached, setup clean. Complementary command-processor formal: 7/7 assertions proven non-vacuously, including busy-blocks-launch; 3/3 covers reached. Together with production top wiring, these verify serial dispatch; parallel starts are unsupported by the architecture. VCS/URG code coverage is scoped under `tb_ai_accel_smoke.dut`; raw DUT subtree line/condition/FSM/branch=`81.07/68.61/35.59/71.65%`, with uncovered bins retained. This is selected control formal and one-seed raw code coverage, not numerical full-top formal or coverage closure. See [run record](../docs/verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md). |
| FP16 DDR-to-compute | `ai_axi128_dma` ↔ scratchpad ↔ queued `0x51` FP16 dot ↔ completion writer ↔ DMA | Directed top smoke loads two packed FP16 words from the AXI memory model, computes the dot, then stores FP32 result back to the model. | Checks both SPAD operands, FP32 result, shared completion and external-memory result (`0x41300000`). Passed in current `ai_smoke`; does not model DDR PHY or randomized DDR errors. |
| Top smoke | `ai_accel_top` ↔ AXI-Lite tasks ↔ AXI4 memory model | Directed register/DMA/queue/compute, BF16/FP16 command tests, FP16 DDR path and Transformer micro-workload. | `TEST PASS`, SVA clean, expected completion/result checks and fixed-point reference gate pass.  This is regression evidence, not UVM coverage closure. |
| Top smoke seeded regression (2026-10-16) | Same top smoke testbench and full integration RTL | `cd dv/subsystem/top_smoke/sim && make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | Rocky 8.10 / VCS `V-2023.12-SP1_Full64`; exit 0, `TEST PASS` at 411,470,000 ps. Includes directed baseline, 20 seeded random GEMV/GEMM/Conv3x3/DWConv post-op cases, protection and reset recovery. Current dirty worktree evidence, not a fixed-SHA replay. |
| Top smoke seeded regression (2026-10-26 owner follow-up) | Same top smoke testbench and full integration RTL | `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | VCS `V-2023.12-SP1_Full64`; exit 0, `TEST PASS`. Includes real concurrent CNM GEMV + Matrix GEMM ownership/data checks followed by 20 seeded random compute cases, protection and reset recovery. Current-worktree evidence, not a fixed-SHA replay. |
| Shared top UVM ABI smoke | `dv/uvm` AXI-Lite UVM agent ↔ `ai_accel_top` | `make -C dv/uvm/sim uvm_smoke` reads VERSION only. | A10 expected value `0x1000000a`; 2026-10-14 run has one AXI-Lite transaction and UVM warning/error/fatal=0. This is infrastructure/ABI bring-up only. |
| Top UVM queued INT8/BF16/FP16 DDR vertical slice + mixed-FP length/AXI-gap sweep | `dv/uvm` AXI-Lite sequencer + passive AXI4 monitor/scoreboard ↔ `ai_accel_top` + AXI memory model | `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_regress` runs six order/layout/validator/error/reset cases; `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress` adds 16 FP16 K=1..4 × BF16 K=1..4 runs and read/WREADY gap bins 0..3, including K=3 odd tail and K=4 two packed words. | 16/16 sweep PASS. Its URG `e2e_cg` result at that run was 41/41 variable bins and 16/16 cross bins (100%), report `/tmp/nmaforge_mixed_precision_e2e_cov_20261015_140052_244573981/urg_merged`. Whole-design raw summary for that run: line 48.18%, condition 42.99%, FSM 9.09%, branch 36.23%, assertion 33.33%, score 40.44; not overall closure. Later 42/42, 52/52 and 53/53 results are historical; the latest 54/54 result including the independent accelerator-reset/DDR-live check is in the seeded-random row below. Ordinary six-run regression also PASS (`/tmp/nmaforge_a10_mixed_e2e_order_regress_20261015.log`). **Selected slices passed; V4/V5 remain open.** |
| Top UVM seeded-random mixed-precision DDR E2E + bounded AXI latency/back-pressure + reset + FP watchdog/software abort (2026-10-16 rerun) | Same top-level active AXI-Lite/passive AXI4 environment and AXI memory model | `cd dv/uvm/sim && make uvm_mixed_precision_ddr_e2e_random_cov_regress MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_20261016_e2e_independent_reset_final`; Rocky 8.10 / VCS `V-2023.12-SP1_Full64`; seeds `20261101..20261292` (192 runs), no order/layout/FP16 K/BF16 K override; seeded UVM randomizes descriptor order, SPAD layout, K=1..4 and operands. Each run covers queued INT8/BF16/FP16, invalid descriptor, two-beat DMA RRESP SLVERR at first and last position, idle-AXI-boundary accelerator-only reset with live DDR and a post-reset DMA readback, separate outstanding-DMA coordinated reset/recovery, FP watchdog completion, software abort, and bounded AXI gap/back-pressure configs. | All 192 seed logs have E2E and independent-DDR-reset PASS markers, UVM_WARNING/ERROR/FATAL=0; compile log has no VCS `Warning-`/`Error-`; target and URG merge exited 0. Fresh URG `e2e_cg`: 54/54 variables + 16/16 crosses; new `cp_independent_ddr_reset` hit 192 times; `dma_error_position_cg`: before-last/on-last 192 hits each, 2/2 bins (100%). Whole-design dashboard line/condition/FSM/branch/assertion/score=`49.44/45.81/10.64/37.80/33.33/43.05%` aggregates DUT, TB and UVM; URG assertion report has one UVM component-name property with successes and two UVM RAL no-attempt properties, but no top DUT SVA evidence. **Historical V4-RAND-01 path run before SVA enablement; retain these numbers only as historical functional-coverage evidence. The intermediate 12-property SVA run at `/tmp/nmaforge_a10_20261016_e2e_dut_sva_random` is superseded by the final FP checker campaign at `/tmp/nmaforge_a10_20261016_e2e_fp_sva_random`; preserve the old URG metrics and apply no new numbers to that old URG.** Gap configuration remains fixed per run, not per transaction; independent reset is only tested with the AXI/DDR boundary idle, not with an external transaction in flight. Broader descriptor fields and global coverage closure remain open; artifacts stay under `/tmp`, V4/V5 remain open. |
| Top UVM seeded-random mixed-precision DDR E2E, refreshed after ABI-v7 macro test (2026-10-16) | Same top-level active AXI-Lite/passive AXI4 environment and AXI memory model | `cd dv/uvm/sim && make uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_OUT=/tmp/nmaforge_a10_e2e_post_macro_final_20261016 && make uvm_mixed_precision_ddr_e2e_random_cov_regress MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_top_e2e_random_post_macro_20261016`; Rocky 8.10 / VCS `V-2023.12-SP1_Full64`; random seeds `20261101..20261292` | 16-case mixed FP length/gap sweep plus 192 seeded E2E runs covering descriptor order, SPAD layout/bank, K=1..4 and operands, invalid descriptors, first/last DMA SLVERR, reset/recovery, watchdog/abort and bounded AXI gaps/backpressure; URG functional bins and top-level protocol assertions | Both targets and URG merges exit 0; 192/192 run directories, UVM warning/error/fatal=0 and no VCS compile `Warning-`/`Error-`; selected `e2e_cg` and modeled functional bins=100%. Latest URG `/tmp/nmaforge_a10_top_e2e_random_post_macro_20261016/urg_merged`: 22 properties, 20 success, 0 failure/incomplete, 2 no-attempt UVM RAL properties; five DUT-owned AXI master assertions have non-vacuous real successes `1920/1012/576/383/1494`, three AR/AW/W stall covers match `1012/383/1494`; 14 engine activity checks are testbench monitors. Whole-design line/condition/FSM/branch/assertion/score=`51.58/47.40/12.28/39.48/84.62/47.07%` includes DUT+TB+UVM and is not DUT-only; remaining per-DUT code/assertion disposition, transaction-level independent gap randomization, fault×abort×reset combinations and clean frozen-SHA replay remain open. Strong selected V4 evidence, not V4/V5 closure. |
| Top UVM ABI-v7 external macro descriptor DDR E2E | `ai_accel_top` + command processor + external AXI descriptor fetch + shared SPAD/INT8 compute/completion | `cd dv/uvm/sim && make uvm_external_macro_ddr_e2e` | Parent descriptor points to `0x0000_0001_0000_1000`; fetch 3 child descriptors, check full 64-bit AR addresses, AXI ID/order/4-beat RLAST framing, 3 child result words and exactly one aggregate completion. | VCS `V-2023.12-SP1_Full64`; focused UVM severity `0/0/0`, `MACRO_EXTERNAL_DDR_E2E_PASS` and `MACRO_AXI_DESC_FETCH_PASS`; 3 fetches/12 beats/3 results/1 completion. Top-UVM-only memory-model option aliases upper tag `1` into a small 4096-word backing array while rejecting other nonzero high tags; this is address-routing verification, not >4 GiB physical DDR/PHY validation. Follow-up six-seed mixed E2E and `make ai_smoke` also pass. Targeted V4 slice only; V4/V5 remain open. |
| Top UVM accelerator-only reset with live DDR | Same top-level mixed-precision UVM and AXI memory model, with separate DUT `aresetn` and memory-model `ddr_resetn` | Included in all 192 runs of `uvm_mixed_precision_ddr_e2e_random_cov_regress MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_20261016_e2e_independent_reset_final` | During active FP compute, assert accelerator reset only after proving DMA/AXI/DDR request and response queues are idle; leave DDR responder out of reset, then perform a real DMA read of retained DDR word `0xdada5511` and compare SPAD readback. | `cp_independent_ddr_reset` 192/192; each run logs `[MIXED_E2E_DDR_INDEPENDENT_RESET_PASS]`; UVM severity 0/0/0. This proves the idle-boundary reset/recovery behavior only; it does not define or verify accelerator-only reset while AXI traffic is in flight. |
> Matrix history note: the older `e2e_dut_sva_random` entry is superseded by the final FP activity-checker campaign at `/tmp/nmaforge_a10_20261016_e2e_fp_sva_random`; preserve its old metrics and do not apply new metrics to its URG.
| Top UVM DMA two-beat SLVERR position / burst-atomicity addendum (2026-10-15) | Same top-level mixed-precision UVM and AXI memory model | Focused `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e`; six-seed order/layout regression; 16-run `uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_OUT=/tmp/nmaforge_a10_v4_errorpos_cov_check_20261015` | Inject one SLVERR in beat 0 and one on RLAST of two-beat/8-word reads; monitor RID through RLAST, error count/beat count and read-error position coverage; check `ERR_AXI_RD` and all 8 SPAD sentinels unchanged because no burst data commits before successful OKAY RLAST. | Focused, six-seed and 16-run regressions PASS with UVM warning/error/fatal=0. URG `dma_error_position_cg` has before-last/on-last bins each hit 16 times (2/2, 100%) at `/tmp/nmaforge_a10_v4_errorpos_cov_check_20261015/urg_merged`. A first test version incorrectly expected partial commit on final-beat error; it was corrected to match the RTL burst-buffer contract. This directed error-position evidence does not close random error/reset/abort combinations or V4/V5. |
| DMA–SPAD concurrent FP AXI error drain | Real BF16/FP16 dot core + DMA + shared memory fabric | `make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10errfpfix SEEDS='12345 987654 20261014' URG_REPORT=/tmp/nmaforge_a10errfpfix_urg`; each seed runs BF16 and FP16 with one injected DMA RRESP SLVERR while 4 reads are outstanding. | Checks 4/4 accepted/drained reads, one accepted injected SLVERR, FP/DMA error overlap, no DMA SPAD write, FP result/readback `0x43000000`, fully idle fabric/DMA and a subsequent clean DMA transfer without reset. All three seeds PASS with UVM warning/error/fatal=0. Fixed address and directed delay only; does not close random AXI-error × compute concurrency, abort/parity/protection, CNM, CMDQ/completion-writer lifecycle, or V3 overall. |
| DMA–SPAD CNM protection-error alignment/recovery addendum (2026-10-15) | Real `ai_banked_cnm_core` through shared memory fabric and registered SPAD response path | `make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10cnmprot_matrix VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg URG_REPORT=/tmp/nmaforge_a10cnmprot_matrix_urg` (Makefile defaults to seeds `12345/987654/20261014`); then `ai_smoke` and `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | In 4 KiB profile, separately set source A and B to OOB `0x1180`; third case enables a region with read/execute permission but no write permission for in-range destination `0x2b0`; check aligned read response tags, `ERR_PROTECTION=6`, destination sentinel, then legal recovery without reset | All three seeds PASS; UVM warning/error/fatal=0 and A/B/destination-permission bins=100%. Fresh URG: 31 assertions, 29 success, 0 failure/incomplete, 2 unattempted internal UVM RAL assertions; source protection-response assertion has 6 successes. GEMV shape cross remains 12/12. `ai_smoke` and the 20-case seeded top regression PASS. These are directed protection scenarios only; broad protection/parity/error combinations and V3 closure remain open. |
| Top UVM per-transaction AXI latency/back-pressure jitter (2026-10-16) | `ai_accel_top` mixed-precision DDR E2E and testbench AXI memory responder | `cd dv/uvm/sim && make uvm_mixed_precision_ddr_e2e_axi_stalls`; `make uvm_mixed_precision_ddr_e2e_cov_regress`; `make uvm_mixed_precision_ddr_e2e_random_cov_regress` (192 seeds `20261101..20261292`) | Seeded, independently bounded ARREADY/AWREADY address stalls, per-beat R response gaps and WREADY gaps; scoreboard checks transaction integrity. Deterministic outstanding-DMA reset probe temporarily disables jitter and restores it afterward. | Focused, 16-run sweep and 192-run campaign PASS on Rocky 8.10 / VCS+URG `V-2023.12-SP1_Full64`; four dedicated URG groups (`axi_arready_stall_cg`, `axi_awready_stall_cg`, `axi_read_response_gap_cg`, `axi_write_data_gap_cg`) each 100%. `ai_smoke`, 20-case `ai_run`, six default-mode order runs and DMA UVM 15/15 also PASS. Current dirty-worktree evidence only; no product RTL/SPEC/ABI change. This supersedes earlier rows that describe AXI gap selection as fixed per run. In-flight external-AXI reset semantics, all fault×abort×reset combinations and overall V4/V5 closure remain open; see [A10 run record](../docs/verification/A10_DV_RUN_2026-10-16.md). |

> **2026-10-15 V4 FP abort-drain rerun:** strengthened `run_fp_abort_completion_check` so every run observes the top-level `core_abort` pulse while `outstanding_reads_r=1`, then checks that the count returns to zero before the `ERR_ABORT` completion. The focused test, 16-run coverage sweep, 192/192 seeded-random campaign, `ai_smoke`, and `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` pass; latest URG report is `/tmp/nmaforge_a10_abort_drain_random_20261015/urg_merged` (selected `e2e_cg`: 53/53 variables and 16/16 crosses). This supersedes the prior row's report path for the latest rerun; it does not close global V4/V5 coverage.

## Evidence status

### 2026-10-18 exact pushed SHA `622ecc7` replay

At exact `main` SHA `622ecc7`, Rocky 8.10 / VCS `V-2023.12-SP1_Full64` and
URG `V-2023.12-SP1`, selected frozen-baseline replay passed: FP directed test,
three FP UVM seeds (484/484 bit-exact each, UVM severity 0/0/0, selected
functional groups 100%), FP model 19/19, DMA UVM 16/16, Control UVM 9/9, top
`ai_smoke`, and seeded `ai_run` 20/20. DMA `dma_cmd_cg` and Control coverage
groups were 100%; DMA/Control URG had 0 assertion failures/incomplete, with
two unattempted UVM RAL internals in each. Canonical FP formal passed 12/12
assertions and both selected covers. Three short-vector parity lifecycle
properties under the fixed two-cycle core-facing SPAD model re-proved
non-vacuously at depths 224/27/206. This is selected exact-SHA evidence only;
full 16-bit parity proof, remaining subsystem/top coverage disposition, and
V1–V5 overall closure remain open. Full commands and limits are in the
[exact-SHA run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-pushed-sha-622ecc7-replay).

### 2026-10-18 exact current-main `e06f49c` maximum-length FP parity replay

Fresh Rocky 8.10 / VCS `V-2023.12-SP1_Full64` `dot-core-parity-max-test`
passed all BF16/FP16 × final-A/final-B parity cases at length `16'hffff`;
each drained 65,536 reads, stopped at a 65,534-element prefix with one
`ERR_PARITY`, emitted zero destination writes, and recovered without reset
with one exact FP32 `1.0` write. This updates the maximum-length parity
simulation evidence from dirty-worktree to an exact current-main run, but does
not close full-domain formal, V1-FP-04, or A10. See the [run record](../docs/verification/A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-maximum-length-fp-parity-replay).

VCS compile, top smoke, historical 20-case top random, FP block (three seeds × 256 random,
584 checks/seed, severity zero, peak outstanding=2), Control UVM, DMA UVM
(current 14 tests), Command Processor UVM (latest 25/25 scenario bins per seed across
50 seeds; latest 2026-10-17 CP replay is 31/31 scenario bins per seed and
`cp_cg` 57/57 variables + 10/10 crosses with the direct-start compute-error
event-only and stale-ERR_ABORT-code robustness bins/SVAs exercised; CPLQ full/hold/resume, BF16/FP16 direct-start validation,
macro paths, fetch-error without completion, and abort/partial-completion/reset recovery), and DMA/SPAD
subsystem UVM (latest 10-seed campaign) have passing evidence. The ordinary six-run top order/layout
regression, 16-run FP16 K=1..4 × BF16 K=1..4 plus AXI-gap sweep, and refreshed
192-seed mixed E2E campaign with compute-active reset and FP watchdog completion
also pass; latest targeted `e2e_cg` is 54/54 variable bins and 16/16 cross bins,
including the real watchdog, software-abort completion, and idle-boundary
independent accelerator-reset/DDR-live recovery bins. Overall A10 V1–V5 remain
incomplete: V1 has strong bounded block evidence; V2/V3 have block/subsystem
coverage but no unified closure; V4 covers selected E2E features (the new
20-case rerun passed after license recovery; V5 still needs
overall code/assertion review, mutation, a final reproducible manifest, and
classification/disposition of outstanding coverage. Previous full-design raw
dashboard values are historical and this watchdog increment does not recalculate
them; they are not a closure claim.

2026-10-17 initial V3 refresh (historical; its AW-stability assertion disposition
was superseded by the follow-up below): the dirty worktree passed a fresh
10-seed `dma_spad_subsystem_test` regression (`20261110..20261119`) on Rocky
8.10 / VCS `V-2023.12-SP1_Full64`. All seeds had UVM warning/error/fatal
`0/0/0` and emitted `[SPAD_CNM_DMA_PASS]` and `[DMA_SPAD_ERR_DRAIN_PASS]`;
GEMV and parity coverage checks passed. URG
`/tmp/nmaforge_a10_v3_refresh_20261017_b/urg_merged` reports 13 functional
groups at 100%; assertion totals are `31/28/0/0/3` (total/success/failure/
incomplete/uncovered). Two uncovered assertions are UVM RAL `do_read` and
`do_write` no-attempts; one was then-unresolved DUT DMA instance `unnamed$$_1`
(119,882 attempts, 0 successes, 0 failures). This is bounded dirty-worktree
evidence, not frozen-SHA replay.

The follow-up V3 AW-stability replay labels that property as
`ap_dma_aw_payload_stable`, applies four real responder-controlled AW stall
cycles, and records 50 real assertion successes across ten seeds with zero
failures/incomplete. The same result was reproduced in the detached clean-SHA
replay at `43dbbbc`. This dispositions the AW-stability assertion slice only;
it does not close V3 fairness, broader fault/abort/reset, residual DUT code
coverage, or full command/completion lifecycle. See the
[AW-stability addendum](../docs/verification/A10_DV_RUN_2026-10-17_REFRESH.md)
and [clean-SHA replay](../docs/verification/A10_DV_CLEAN_SHA_REPLAY_43DBBBC.md).
Additional prolonged/downstream-backpressure fairness (the separate 300-cycle
admission test reaches max wait=2 but has no downstream response backpressure),
broad fault×abort×reset, residual DUT code coverage, and V3/A10 closure remain
open. See
[`A10_DV_RUN_2026-10-17_REFRESH.md`](../docs/verification/A10_DV_RUN_2026-10-17_REFRESH.md)
and [`A10_DV_RTM.md`](../docs/verification/A10_DV_RTM.md).

## 下一步
| 阶段 | 验证层级 | 验证对象 | 主要内容 | 通过标准 |
|---|---|---|---|---|
| 0 | 基线 | 全项目 | 固化 RTL/filelist/ABI、整理 test plan、lint triage | 顶层 smoke 可复现、路径唯一 |
| 1 | Block | AXI-Lite control | RAL、寄存器读写、WSTRB、IRQ、reset、sticky error | 2026-08-13 六项 VCS 回归通过；寄存器镜像、协议与本地 SVA 均通过。coverage closure 与多 seed 仍待完成。 |
| 2 | Block | DMA | 1D、2D、gather、32/128-bit、store/BID、4 KiB、abort、随机 back-pressure | DDR↔SPAD scoreboard 正确；ID/RLAST/BID/abort SVA 通过；DMA coverage 达标 |
| 3 | Block | SPAD arbiter | descriptor/completion/DMA/compute 多客户端争用、优先级、round-robin | 无丢包/重复；控制面优先；无饥饿 |
| 4 | Block | Command processor | descriptor 合法性、CMDQ/CPLQ 指针、event dependency、error/abort | 不合法任务不启动；head/tail 所有权正确；completion 原子提交 |
| 5 | Block | CNM / Matrix / SFU / CNN-KV | INT8 算法正确性、边界值、transpose、量化、Softmax/Norm、卷积窗口、KV 地址 | 与 Python bit-aware golden 匹配；无死锁、无越界 |
| 6 | Subsystem | DMA–SPAD | DMA 通过 arbiter 访问真实 scratchpad，同时叠加 compute-like client | 数据正确、仲裁正确、protection/error 可恢复 |
| 7 | Subsystem | Queue–completion | AXI-Lite 配置 → CMDQ → processor → completion writer | completion 四个 word 完成后才推进 tail；reset/abort 正确 |
| 8 | Subsystem | Multi-Engine NPU Compute Cluster Verification | Five compute groups through real top dispatch; shared-SPAD concurrency; per-engine slot and ordered-completion checks; all `rtl/compute` module coverage | The 2026-10-23 full `cluster_regress` VDB merge remains the source for the listed line/condition/branch numbers. It reports 23 `rtl/compute` module definitions, 20 executable and 3 wiring wrappers N/A; weighted line/condition/FSM/branch=`92.69/90.00/54.67/87.31%`; five-seed top-only compute slice=`83.79/66.39/41.60/69.19%`. The targeted 2026-10-24 SFU-refresh re-merge updates the compute FSM weighted value to 76.11% (258/339; nine FSM-bearing modules), and the new three-seed Dispatcher/SPAD-MUX UVM reaches 21/21 overlap pairs + 5/5 scenario bins per seed. The 2026-10-25 Matrix controller integration follow-up is tracked separately: default `ARRAY_SIZE=16` now executes real descriptor-facing SPAD GEMM; three seeds each pass 8 numeric/layout cases including 16×16 and 32×16 multi-macro-tile GEMM, plus 12 fault/recovery cases. Matrix core DUT-scoped URG is line/condition/FSM-transition/branch=`96.17/90.83/65.85/93.52%`; array child=`82.35/20.00/N/A/58.82%`. A fixed-response VCS 4×4/8×8/16×16 physical-array × workload-size benchmark is recorded separately; it is not DC/PPA. These additions do not recalculate older full-merge compute line/condition/branch values and do not close full C0/C1. Each engine pair also overlaps and passes ordered abort drain in top smoke. Dispatcher formal proves 5/5 assertions and reaches 23/23 covers (4 antecedent properties non-vacuous). Full-domain FP writeback exclusion is proven; the FP six-property unassisted lifecycle remains 3/6 and project-wide closure remains partial. [Status](../docs/verification/COMPUTE_ENGINE_STATUS.md) / [Interaction run record](../docs/verification/COMPUTE_ENGINE_INTERACTION_FOLLOWUP_2026-10-23.md) / [Compute Cluster Testplan](../docs/verification/COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md) / [Upgrade roadmap](../docs/verification/COMPUTE_CLUSTER_UPGRADE_ROADMAP_ZH.md) |
| 9 | Top UVM | `ai_accel_top` | 软件可见 ABI、随机 CMDQ、乱序 DDR、IRQ、reset、Transformer command-chain | 端到端结果、completion、错误恢复、性能计数器一致 |
| 10 | 静态/形式/覆盖率 | 全 RTL | SpyGlass lint/CDC/RDC、关键 SVA formal、functional/code coverage closure | P0 lint 清零或有 waiver；CDC/RDC 收口；coverage 达标 |
| 11 | FPGA/板级 | XCZU15EG | bitstream、DDR DMA、IRQ、ILA、性能计数器、长时间稳定性 | 实测数据与仿真一致，日志与性能报告归档 |

### A10 当前增量：DMA–SPAD CNM parity × DMA contention（2026-10-15）

`dv/subsystem/dma_spad` 三 seed 回归 `12345/987654/20261014` 全部通过：每个 seed 均覆盖四个 CNM lane 的 parity fault 与 DDR→SPAD DMA 并发，逐场景检查 `ERR_PARITY=5`、响应 drain、结果写抑制、目的 sentinel 保持及 parity restore 后的 oracle/readback recovery。每 seed UVM warning/error/fatal 为 `0/0/0`；lane×DMA functional cross 每 seed 与 merged URG 均为 4/4。紧随其后的 top `ai_smoke` 也 PASS。注入仅通过 VCS behavioral scratchpad RAM testbench backdoor 实现，并非 SRAM macro 物理故障模型；没有修改产品 RTL。此项是 V3 targeted fault/contention evidence，不代表 subsystem-wide error/reset/fairness 或 A10/V5 closure；详细命令见 [A10 RTM](../docs/verification/A10_DV_RTM.md) 和 [A10 baseline](../docs/verification/A10_DV_BASELINE_2026-10-14.md)。

### A10 最新增量：CNM active × DMA SLVERR drain overlap（2026-10-15）

`make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10cnmerrphase3 VCS=vcs URG=urg URG_REPORT=/tmp/nmaforge_a10cnmerrphase3_urg` 三 seed PASS，UVM warning/error/fatal=`0/0/0`；CNM-busy/error overlap 和 DMA 4/4 accepted/completed drain 均检查通过，错误读没有产生 DMA SPAD grant/write，CNM oracle/readback 正确，随后 clean DMA load 无 reset 恢复。merged URG 新增 `cnm_dma_error_overlap_cg` 两个 coverpoint 和 cross 均为 100%。其后 top `ai_smoke` 与 `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS。此处故障地址是 newest-first 的首个响应，因此该增量只证明计算活动与 DMA 错误排空重叠，不是 SPAD arbiter contention；定向 error address/delay、不覆盖随机 fault/reset 组合，也不关闭 V3/A10。详细证据见 [A10 RTM](../docs/verification/A10_DV_RTM.md) 和 [A10 baseline](../docs/verification/A10_DV_BASELINE_2026-10-14.md)。

### A10 V3 late SLVERR after valid DMA commits（2026-10-15）

将 SLVERR 故障位置扩展为 newest-first 响应流中 0、1、2、3 个成功 burst 后注入。三 seed subsystem regression、`ai_smoke` 和 20-case seeded `ai_run` 均 PASS，UVM warning/error/fatal=`0/0/0`。每 seed 分别逐 word 核对合法已提交数据数 `0/8/16/24`，其余 sentinel 不变；所有用例 DMA 4/4 response drain 到 idle，CNM oracle/readback 正确，随后无 reset 的 DMA recovery 通过。晚于首响应的三种位置与真实 CNM 请求竞争，DMA grants 每 seed 为 `1/3/3`。URG `/tmp/nmaforge_a10cnmerrpos4_urg` 的四个位置 bins 各命中 3 次，scenario×drain 4/4、overlap×drain 1/1（100%）。这是固定响应地址/延迟的 directed sweep，不是随机 fault/reset/abort closure，也不代表 V3/A10 完成；详见 A10 RTM 和 baseline。

### A10 V3 CNM active × DMA abort/drain overlap（2026-10-15）

DMA–SPAD subsystem 新增 DMA abort 与真实四-lane CNM 并发场景。DMA 在 CNM busy 期间、首个 AXI R response 前 abort；三 seed `12345/987654/20261014` 均检查 4/4 accepted/completed reads、outstanding 回零、4-deep highwater、无 DMA SPAD commit、目标 32-word sentinel 不变、CNM oracle/readback 正确，以及无需 reset 的 DMA clean-load recovery。UVM warning/error/fatal=`0/0/0`；URG `/tmp/nmaforge_a10cnmabort1_urg` 的 overlap/drain/no-commit/four-outstanding bins 各 3/3。之后 `ai_smoke` 和 20-case `ai_run` PASS。此为固定时刻 directed overlap，不覆盖随机 abort/error/reset 全组合；没有改产品 RTL，V3/A10 仍开放。详见 A10 RTM 与 baseline。
| Top UVM seeded-random mixed-precision DDR E2E + compute-activity SVA evidence (2026-10-16 final FP SVA) | `ai_accel_top` mixed INT8/BF16/FP16 DDR E2E, reset/recovery, DMA error positions, and compute activity properties | `cd dv/uvm/sim && make uvm_mixed_precision_ddr_e2e_random_cov_regress MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_20261016_e2e_fp_sva_random` | VCS `V-2023.12-SP1`, exit 0; 192 seed dirs; 192/192 E2E and independent-DDR-reset markers; zero non-zero UVM WARNING/ERROR/FATAL summaries; compile.log zero `Warning-`/`Error-`; URG `/tmp/nmaforge_a10_20261016_e2e_fp_sva_random/urg_merged`, 192 tests. asserts Total/Uncovered/Success/Failure/Incomplete/Without Attempts=`17/2/15/0/0/2`; 14 compute-activity properties (Scalar/CNM/Matrix/SFU/CNN/KV/FP, two each) have 593422 attempts each and zero failure/incomplete, plus one UVM component visitor; FP real successes are 521737 and 520393; two no-attempts are UVM RAL. | Whole-design dashboard score/line/condition/FSM/branch/assertion/group=`52.45/50.04/46.14/10.64/38.39/88.24/81.26%`, including TB/UVM and not DUT-only. New `ai_smoke` passed with the FP checker connected. Accelerator reset is during active compute at an AXI idle boundary; DDR remains active and DMA recovery reads the retained operand. Not an in-flight AXI reset test; global DUT-only/V4/V5 closure remains open. |
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

### Compute Cluster R104 concurrent Protection/owner cross — 2026-10-30

At exact committed test SHA `ee18cfc0363b9130cefcd4f73c58111717fa8b7a`, a three-seed real-top UVM regression passes a legal Matrix output Protection denial while an independent CNM GEMV runs concurrently through shared SPAD. Each seed reports 341 cycles with both engines busy, 154 shared-bank accepts, Matrix/CNM tagged response counts `128/1024`, zero route mismatches, ordered Matrix error `0x62` then CNM success, 16 CNM Golden output words, and 512 unchanged Matrix destination sentinels. The byte-addressed memory scoreboard checks 31,091 words with zero mismatch/unknown/stale/orphan; UVM severity is `0/0/0`. The named 28-case passive checker-sensitivity campaign passes all 28 expected checker catches. Focused applicable compute coverage is 100% for its named testpoint group only. URG for this compute workload has 17/22 assertion successes, zero failures/incomplete, with three AXI assertions lacking successful antecedents, two UVM RAL properties without attempts, and AR/AW stall covers unhit in this profile; R102 contains the separate AXI stall workload. This adds scoped evidence only: the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R104 evidence](../docs/verification/COMPUTE_CLUSTER_PROTECTION_OWNER_CROSS_R104_2026-10-30.md).

### Compute Cluster R105 Protection/Abort owner cross — 2026-10-30

At exact committed test SHA `973b4a1291bc3d63deb96ba0720337d84cb3ae34`, the three-seed production-top regression runs a legal Matrix Protection output fault concurrently with CNM, then software-Aborts CNM while it is still active. It checks the ordered Matrix `0x62` and CNM `0x32` completions, response drain and ownership, zero route mismatch, unchanged Matrix sentinels, and Golden-or-untouched CNM output. Each seed observes 341 overlap cycles, 154 shared-bank accepts, 32,503 scoreboard-checked words with zero mismatch/unknown/stale/orphan, and UVM severity `0/0/0`. The exact-source passive checker campaign passes 28/28. The restored top smoke and 20-case seeded top replay also pass at the published clean tree. This adds bounded evidence to `REQ-CL-017/019/027` and `REQ-PC-006/007`; those requirements remain PARTIAL. The RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R105 evidence](../docs/verification/COMPUTE_CLUSTER_PROTECTION_ABORT_OWNER_CROSS_R105_2026-10-30.md).


### Compute Cluster R106 reverse-direction Protection/owner cross — 2026-10-30

At exact committed test SHA `ef0924767c3ccf0bec9b2f54d4b96da2491c9901`, three real-top UVM seeds concurrently run legal Matrix 16×32×64 GEMM and CNM GEMV through shared SPAD. CNM source-A Protection denial occurs while Matrix is active; Matrix still completes all 512 independent Golden words, then CNM retires Protection `0x62` with its output destination unchanged. Each seed records 7 overlap cycles, 192 Matrix and 2 CNM tagged responses, ordered completions, zero owner mismatch, and 33,303 memory-scoreboard words with zero mismatch/unknown/stale/orphan; UVM severity is `0/0/0`. The named focused point has 100% applicable coverage; this is not global requirement coverage. The exact-source passive checker-sensitivity campaign passes 28/28. Top Smoke and 20-case seeded Top pass; the existing `[LOOP-REROLL-ENABLED]` fixture warning remains. R106 adds bounded evidence to `REQ-CL-017/027` and `REQ-PC-006/007`, all still PARTIAL. `CL-COV-002/006` remain open, RTM remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. See [R106 evidence](../docs/verification/COMPUTE_CLUSTER_CNM_PROTECTION_MATRIX_OWNER_R106_2026-10-30.md).


### Compute Cluster R107 Protection/reset epoch cross — 2026-10-30

At exact committed test SHA `53b40e67ac0f82d01dfc3c40ad36ce34745ea929`, three real-top UVM seeds observe a CNM source-A Protection denial while Matrix is active and has issued accepted SPAD reads, then assert reset. Each run records 26 Matrix read accepts and two cycles with both engines busy at the fault. Reset clears both engines with no completion, writeback, post-reset response or owner mismatch; 512 Matrix destination, 16 CNM destination, and eight completion words remain sentinel, completion tail is zero, and the final pending ledger is empty. The scoreboard checks 33,435 words with zero mismatch/unknown/stale/orphan; `reset_dropped` is 11 versus the paired R106 baseline of 9. UVM severity is `0/0/0`, focused applicable coverage is 100%, and the named passive checker-sensitivity set is 28/28. Top Smoke and 20-case seeded Top pass; the existing `[LOOP-REROLL-ENABLED]` fixture warning remains. This checks reset superseding the in-flight fault, not the CNM error completion. The affected requirements remain PARTIAL, the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. See [R107 evidence](../docs/verification/COMPUTE_CLUSTER_CNM_PROTECTION_RESET_OWNER_R107_2026-10-30.md).

### Compute Cluster R111 Matrix FSM clean-SHA formal replay — 2026-10-30

At exact clean code/test SHA `95864f7027ccbec22a09b0a61832c68d3ca08098`, Synopsys VC Formal `V-2023.12-SP2` passes the existing Matrix FSM guard target. Setup reports no issues; all five assertions are non-vacuous and proven, and both state reachability covers hit (`ST_PREFETCH_WAIT` at depth 11, `ST_ERROR_DRAIN` at depth 5). The legal 4×4×3 descriptor and accepted banked-response owner assumptions are retained; no FSM state is forced. The 49/53 enabled-profile raw FSM result remains, and `ST_MAC→ST_A_REQ` remains separately exercised in the prefetch-disabled build. R111 updates the original Stage A review, where the guard edges had not yet received formal disposition. It adds no requirement closure: the RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. See [R111 formal evidence](../docs/verification/COMPUTE_CLUSTER_MATRIX_FSM_R111_FORMAL_2026-10-30.md) and [Execution RTM](../docs/verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

### Compute Cluster R113 banked/core owner contention — 2026-10-31

Three VCS seeds pass simultaneous scalar/core and Matrix-like banked reads through the selected production fabric. The real arbiter grants the Core request first and the banked request on the next turn; both tagged response owners and independent Golden data pass. Focused coverage is 100%; the banked tag assertion records three real successes and no failures/incomplete. This is not a production Matrix-engine contention test and closes no full requirement. See [R113 evidence](../docs/verification/COMPUTE_CLUSTER_BANKED_CORE_CONTENTION_R113_2026-10-31.md).


## R128 Scalar CMDQ minimum-shape and numeric boundary evidence — 2026-10-31

The exact clean-worktree UVM test SHA dfbebbd8c8ee68458c4261f74f041e816b6b0284 passes the three-seed Compute Cluster regression. Seven legal Scalar GEMV M=1/K=1 descriptors cover bias sign-extension/saturation, arithmetic shift 31, and identity/ReLU/ReLU6. Each seed checks 7/7 Golden outputs and completions, case_mask=7f, and a 41,961-word memory image with zero mismatch/unknown/stale/orphan; UVM severity is 0/0/0. The published content SHA is 0e38b482e13eefa759441ac8ed1ab3d4d6246b37. This is scoped evidence for REQ-CL-002/015/020, which remain PARTIAL; global disposition remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R128 report](../docs/verification/COMPUTE_CLUSTER_SCALAR_CMDQ_NUMERIC_BOUNDARY_R128_2026-10-31.md).

## Compute Cluster R129 Scalar GEMV accepted-write Abort prefix — 2026-10-31

The clean-worktree three-seed top UVM at test SHA 8b511e474727fe13439f99674d1a30b46005f274 passes a real CMDQ Scalar GEMV M=16/K=64 Abort point. Each run commits one Golden output, preserves the other 15 sentinels, drains 130/130 reads, writes no output after Abort sampling, and reports ERR_ABORT 0x32. The 42,107-word scoreboard has zero mismatch/unknown/stale/orphan and UVM severity is 0/0/0. Focused cluster_cg is 100%; the merged mixed URG score is 55.92%. This is scoped evidence for REQ-CL-017/019/027 and REQ-PC-006, all remain PARTIAL. See the R129 report (../docs/verification/COMPUTE_CLUSTER_SCALAR_GEMV_ABORT_PREFIX_R129_2026-10-31.md).

## Compute Cluster R136 Matrix FSM Formal clean replay — 2026-10-31

At the exact published closeout tree `a2e3aafe29262b9237c97d7f4d90e4a9f22e118b`, VC Formal `V-2023.12-SP2` checks out Base/FPV and passes five non-vacuous Matrix FSM assertions plus both selected reachability covers (`ST_PREFETCH_WAIT` depth 11; `ST_ERROR_DRAIN` depth 3). No FSM state is forced. The enabled-prefetch raw FSM remains 49/53; legal `ST_MAC→ST_A_REQ` remains covered in the separate prefetch-off simulation. This is a clean replay of the scoped guard disposition, not global FSM closure. See [R136 report](../docs/verification/COMPUTE_CLUSTER_MATRIX_FSM_R136_FORMAL_REPLAY_2026-10-31.md); the v1.0 disposition stays 24 PASS-SCOPED / 14 PARTIAL, HOLD.

## Compute Cluster R137 Scalar legacy Conv CMDQ — 2026-10-31

At published test commit `4b587cf1ded4f3d4786698c17d6fa875e3a7bd53` (tree `eec76b8e2aec19e531c40939635b820c4a2829d5`), a clean local worktree with the identical tree passes the three-seed real-top UVM regression and Top Smoke. Real CMDQ Scalar opcodes `0x13/0x14/0x15` each launch in order and complete; every seed checks 12/12 independent signed packed-INT8 output words and 42,803 full-memory words with zero mismatch/unknown/stale/orphan, UVM severity `0/0/0`. The declared R137 opcode testpoint group is 3/3 per seed; existing focused `cluster_cg` is 100%. Mixed URG is 56.00% and is not a functional-closure metric. Top Smoke reports mapper 86 descriptors/60 tensors and `TEST PASS`, retaining the fixture's `[LOOP-REROLL-ENABLED]` compile warning. This strengthens REQ-CL-002/015/020 only; all remain PARTIAL and the overall disposition remains 24 PASS-SCOPED / 14 PARTIAL, HOLD. See [R137 report](../docs/verification/COMPUTE_CLUSTER_SCALAR_LEGACY_CONV_CMDQ_R137_2026-10-31.md).


> **2026-10-31 R138 parallel Matrix/CNM Protection cross:** Three real-top VCS seeds require both Matrix and CNM to be active when the CNM output Protection denial is observed, then check Matrix/CNM `0x62` completions in CMDQ order, 128/64 tagged responses, zero route mismatch, and unchanged destination sentinels. The independent scoreboard checks 43,603 words with zero mismatch/unknown/stale/orphan; UVM severity is 0/0/0 and focused cluster coverage is 64/64. The test adds a directed marker required by the default regression gate. It does not exercise same-cycle fault priority or close full fault × phase × reset coverage; all affected RTM rows remain PARTIAL and overall sign-off remains HOLD. See [R138 report](../docs/verification/COMPUTE_CLUSTER_DUAL_PROTECTION_OWNER_CROSS_R138_2026-10-31.md).

> **2026-10-31 R139 dual Protection under full CPLQ backpressure:** Exact clean test SHA `b86bd5df7256df6a8d641213a5601e1237254124` (tree `a1f77cc77b63795b5abfcf35410588add690f788`) passes three seeds. Three legal prefix results fill the completion ring; parallel Matrix/CNM Protection `0x62` completions remain pending until software advances the head twice. Ordered Matrix then CNM retirement wraps the tail `3→0→1`, with the queue full after each release. Each seed checks 44,611 memory words with zero mismatch/unknown/stale/orphan, 128/64 tagged responses, zero route mismatch, and UVM severity 0/0/0. Same-SHA Top Smoke passes and checker-sensitivity passes 28/28. Focused `cluster_cg` is 100% only for its declared group; mixed URG is 56.00%. `REQ-PC-004` retains PASS-SCOPED; `REQ-CL-017/019/027` and `REQ-PC-006/007` remain PARTIAL. RTM total remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. See [R139 report](../docs/verification/COMPUTE_CLUSTER_DUAL_PROTECTION_CPLQ_R139_2026-10-31.md).
> **2026-10-31 R141 Matrix parity/reset epoch:** At clean test SHA `f686f1260156472d6ea9e564fadd172b1dcbf565` (tree `e86f41efbc29cd8e6a27531c5714d44ad83d62a2`), three real-top seeds accept a Matrix A parity-fault read, reset before response consumption, verify no stale response/completion or memory side effect, and recover the reissued 4×4×4 GEMM with 16/16 Golden outputs. Each run checks 44,851 words with zero mismatch/unknown/stale/orphan and UVM severity `0/0/0`; focused applicable compute coverage is 100%. Same-SHA Top Smoke passes and 28/28 named checker-sensitivity mutations are caught. This is a bounded testpoint; the 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R141 report](../docs/verification/COMPUTE_CLUSTER_MATRIX_PARITY_RESET_EPOCH_R141_2026-10-31.md).


> **2026-10-31 R142 Matrix parity response-consumed reset:** At test SHA `c87e137aaab2c708beffc1d7bdfb378829dcab1e` (tree `301ceb34e0eeba231a296ac35f52ea131240c8d3`), three real-top seeds sample a Matrix parity response before reset, suppress the not-yet-published error completion and data side effect, then reissue the task and check 16/16 Golden outputs. Each seed checks 44,895 words with zero mismatch/unknown/stale/orphan and UVM severity `0/0/0`; focused applicable coverage is 100%. Same-tree Top Smoke and 28/28 checker-sensitivity checks pass. R141 tests the adjacent reset-before-consume phase. Both are bounded testpoints; affected RTM rows remain PARTIAL, total remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R142 report](../docs/verification/COMPUTE_CLUSTER_MATRIX_PARITY_RESET_RESPONSE_R142_2026-10-31.md).


> **2026-10-31 R142 selected memory-fabric replay:** Four in-repository `ai_accel_memory_fabric`/`ai_spad_arbiter` targets pass three VCS seeds: shared reset with pending DMA/CNM work, banked reset, Core/Banked contention, and Core/Banked reset. Every run has UVM severity 0/0/0; declared focused groups are 100%; owner SVAs have real successes and zero failure/incomplete. The Core/Banked requesters are testbench-driven; production Matrix banked contention and full integrated engine/fault/reset closure remain open. `REQ-CL-018` and `REQ-PC-007` remain PARTIAL; overall status remains 24 PASS-SCOPED / 14 PARTIAL, HOLD. See [R142 fabric report](../docs/verification/COMPUTE_CLUSTER_MEMORY_FABRIC_CLEAN_REPLAY_R142_2026-10-31.md).


> **2026-10-31 R142 Matrix Line contract replay:** Three seeds pass the Matrix core test with 18 numerical/layout and 35 fault/recovery cases each. The `MATRIX-LINE-001` checker requires full WSTRB, 16-byte aligned Line address, stable payload under 312 stalled cycles, legal scalar fallback for 4-byte-aligned unaligned-Line destinations, and Protection-error handling. Partial/zero WSTRB are unsupported by SPEC v1.5. This is block-level scoped evidence; `REQ-CL-010` remains PARTIAL. See [R142 report](../docs/verification/COMPUTE_CLUSTER_MATRIX_LINE_CONTRACT_R142_2026-10-31.md).
> **2026-10-31 R143 seven-engine parity/reset cross:** At exact code/test SHA `4008d73f800fd470ed2ff8b9c4f7068053d5b041` (tree `42e81651746a6f42c53b1020583f990228d87f94`), three VCS seeds pass 12 legal parity-faulted accepted-read/reset cases per seed across all seven production engines and all defined source phases. Each run checks 45,617 memory words with zero mismatch/unknown/stale/orphan, UVM severity `0/0/0`, empty pending ledgers, and 100% focused applicable compute testpoint coverage. Top Smoke and the 20-case seeded Top run pass at the same source SHA. Reset occurs before response consumption; Matrix's after-consume phase remains covered by R142, while other faults/phases remain open. The 38-row RTM stays 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. See [R143 report](../docs/verification/COMPUTE_CLUSTER_PARITY_RESET_CROSS_R143_2026-10-31.md).
> R143 exact-source passive checker-sensitivity campaign passes 28/28: Address, Data, Owner, WSTRB, Completion Error Code, Write After Error, Response Epoch, and Done/Missing Done/Duplicate Done on each of seven engines all triggered the assigned checker. The merged URG dashboard is SCORE 56.33%, FSM 43.57%; focused compute coverage is 100.0% for its applicable group only. This is not an RTL mutation score or global functional coverage closure. See the R143 report for the Run ID and artifact locations.
