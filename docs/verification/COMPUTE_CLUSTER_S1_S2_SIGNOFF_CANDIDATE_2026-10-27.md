# Compute Cluster S1/S2 DV Sign-off Candidate

**Review date:** 2026-10-28 (current source-SHA addendum)

**Current reviewed source SHA (detached clean worktree):** `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`

**Earlier S1 evidence baseline:** `c83ad7463265062d4edb84d57fe4ada8195f9b10`; current supplemental source includes the SPEC v1.4 Error ABI implementation/checkers committed at `9d9e0f0`.

**Simulator:** Synopsys VCS/URG `V-2023.12-SP1_Full64`

**RTL change in this review:** Conv/KV/SFU error-code values were aligned to SPEC v1.4 (`ERR_OP=2`, watchdog `4`, merged SPAD `7`, SFU numeric `8`) and selected simultaneous-fault cases were added. No unrelated datapath/architecture optimization was made.

## Review decision

| Gate | Decision | Signed scope / hold reason |
|---|---|---|
| S1: 16×16 Matrix Block DV | **BOUNDED PASS** | Three-seed depth-4 functional/fault regression passed for the tested INT8 GEMM/batch/layout, prefetch/cache, parity/protection, abort/reset and recovery cases. Raw default-profile FSM remains 49/53; three guard/invariant edges now have scoped formal disposition, and the fourth profile edge is hit in a separate prefetch-disabled build. |
| S2: Compute Cluster functional slice | **BOUNDED PASS** | Current-SHA clean three-seed real-top seven-engine UVM, R32 accepted-read reset sweep across all seven engines, and R35 clean focused-testpoint replay pass; R35 reaches 100% of applicable bins. The replay test commit's product RTL/SPEC are byte-identical to the reviewed candidate. The 25/25 checker-sensitivity campaign, coordinated R/B reset/recovery, v1.4 error-contract cases and R31 CNM/DMA-SPAD fault/backpressure slice also pass. Historical raw coverage was 29/30 variables (98.96%); the sole completion-read response bin is explicitly excluded as structural N/A for the write-only writer and remains checked at zero. R31's separate 14 subsystem functional groups are all hit after 16/64/300-cycle RREADY and delayed-reset additions. |
| S2: all 38 frozen REQ-CL/REQ-PC requirements | **HOLD** | Current RTM has 24 `PASS-SCOPED`, 14 `PARTIAL`, 0 `BLOCKED_SPEC`, and 0 `NOT_RUN`. Error ABI/priority/prefix SPEC blockers are removed; Matrix core drain/recovery passes R30, selected CNM/DMA-SPAD Abort/Reset drain/recovery passes R31, and R32 resets each production engine after an accepted read. Actual external-fabric qualification, partial Line WSTRB and broader legal fault/phase crosses remain open. This is not full Compute Cluster sign-off. |
| S3: complete NPU IP | **OUT OF SCOPE** | DMA/CMDQ-to-compute-to-CPLQ system E2E, complete system regression, and ASIC PPA are not covered by S1/S2 evidence. |

`PASS-SCOPED` means the named requirement behavior was exercised and checked in
the current slice; it does not imply every cross listed in the SPEC is closed.
`PARTIAL` means some legal scenarios passed but requirement-level breadth is
incomplete. `BLOCKED_SPEC` and `NOT_RUN` are not DUT passes. The raw coverage
percentages below are retained; no unhit bin is silently removed from a score.

## S1: Matrix 16×16 block evidence

The clean depth-4 profile used `MAX_OUTSTANDING_READS=4`, A-tile cache enabled,
next-K prefetch enabled, and a physical 16×16 array. Seeds
`20261021/20261022/20261023` each passed 18 Golden/layout cases and 34
fault/recovery cases. The added cases include zero N/K, non-multiple-of-four
dimensions, misaligned A/B/destination/bias addresses, and B-side protection.
The forced M=16, N=20, K=32 case observes the `ST_MAC→ST_PREP_MAC` prefetch
handoff in the 16×16 profile.

| URG metric for `ai_tensor_matrix_core` | Result |
|---|---:|
| Line | 97.08% (465/479) |
| Condition | 91.05% |
| FSM | 15/15 states; 49/53 transitions (92.45%) |
| Branch | 95.52% (192/201) |
| Prefetch FSM | 5/5 states; 9/9 transitions |
| Child `ai_tensor_matrix_array` | line 82.35%, condition 20.00%, branch 58.82% |

The four transitions not hit in the prefetch-enabled 16×16 build are:

| Transition | Disposition |
|---|---|
| `ST_MAC→ST_A_REQ` | This is the compile-time no-prefetch fallback. A separate 16×16, depth-4, three-seed Golden regression with prefetch disabled hit the fallback marker in all seeds. Its VDB is kept separate because compile-time profiles must not be merged into one percentage. |
| `ST_PREFETCH_WAIT→ST_A_REQ` | The guard depends on prefetch being disabled while `ST_PREFETCH_WAIT` is entered only in the enabled profile. Exact-SHA VC Formal property `ap_prefetch_wait_does_not_fall_back_to_a_req` is proven non-vacuously; no illegal state force was used. |
| `ST_IDLE→ST_ERROR_DRAIN` | Abort/watchdog require `busy`; banked protection requires an accepted banked request. Exact-SHA VC Formal property `ap_idle_does_not_enter_error_drain` proves the guard under the legal descriptor/response assumptions. |
| `ST_ERROR→ST_ERROR_DRAIN` | A new request is not legal in `ST_ERROR` after the accepted-response drain. Exact-SHA VC Formal property `ap_error_does_not_reenter_error_drain` proves the guard under the same model assumptions. |

VC Formal run R28 additionally proves the IDLE/ERROR outstanding-read invariants and reaches both `ST_PREFETCH_WAIT` and `ST_ERROR_DRAIN`. These dispositions are sufficient for the **bounded functional scope** above;
they are not a blanket waiver of all Matrix code coverage. URG reports nine
unhit branch outcomes in the same profile. They include 32-bit result-clamp
branches and control/error paths. No 100% code-coverage claim is made.

## S2: Compute Cluster evidence

Three clean-worktree seeds `20261025/20261026/20261027` passed the real-top
seven-engine UVM at source candidate `9d9e0f0`; the later R32 replay at clean
test commit `bb6e3a2` repeats the same seeds with the new all-engine reset
sweep. Product `rtl/` is unchanged between those commits. R32 reported:

- focused Compute Cluster covergroup `99.0%` (rounded runtime marker; prior URG
  export resolves this to `98.96%`);
  URG found 29/30 cover variables hit. The sole miss is
  `cp_response_client.completion`; it is explicitly WAIVED/N/A because the
  completion writer issues writes and has no read-response client bin.
- memory scoreboard: 5,094 accepted writes, 5,368 checked words, zero
  mismatches, unknown reads, stale epochs, or orphan responses; all seven
  engine read/write activity bins were nonzero.
- line WSTRB observed counts `{full:512, partial:0, zero:0}`; partial WSTRB
  remains open and is not waived by this run.
- seeded parity cross `14/14`, covering INT8/Matrix/CNM/BF16, A/B operand
  phases and all four CNM lanes; this is not the full fault × phase × engine
  cross.
- UVM warning/error/fatal `0/0/0`; all seven production engines produced
  Golden-checked results and completions. R32 also reset each engine after an
  accepted SPAD read, checked busy deassertion and preserved destination plus
  completion sentinels, and reported `reset_dropped=9`, zero stale responses,
  and zero stale completion/writeback.

After license recovery, R35 replayed the focused applicable-compute testpoint
group from clean test commit `cb9717eb853dc507f4a7e4d188c7bd840160c955` on
seeds `20261025/20261026/20261027`. `rtl/` and `docs/spec/` were byte-identical
to the reviewed product candidate `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`.
All three runs passed with 29/29 applicable variables, 5/5 applicable
response-client bins, 5,094 writes and 5,368 checked words per seed, zero
mismatch/unknown/stale/orphan responses, and UVM severity 0/0/0. The structural
completion-read response remains excluded and checked zero. Merged URG reports
`cluster_cg` at 100%; the mixed testbench/UVM total is 29.72% and is not DUT
functional or code coverage. Exact run paths and command are in R35 of the
[Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

The checker-sensitivity campaign ran 25 tests: address, data, owner and WSTRB
once each, plus unsolicited Done, missing Done and duplicate Done for each of
the seven engine bits. Every run emitted the expected checker marker (25/25).
These are passive monitor-observation mutations; they validate checker
sensitivity and are not an RTL mutation score.

### 2026-10-28 exact-candidate evidence addendum

The selected candidate SHA was re-used from its detached worktree after VCS licensing was restored; tracked source remained at the selected SHA with no source edits. The following targets passed with VCS/URG `V-2023.12-SP1_Full64`:

- `CLUSTER-AXI-E2E-COV-16S-C0832`: 16 seeded DDR/FP end-to-end simulations and URG merge passed. All five AXI AR/AW/W stability and 4KB boundary assertions recorded real successes; AR/AW/W stall-to-accept covers matched 166/70/107 times. URG has 20/22 assertions with successes, 2 unattempted UVM RAL assertions, and 0 failures/incomplete.
- `CLUSTER-MUT-CAND-25-C0832`: 25/25 passive-monitor observation mutations were caught by the expected Checker. This is checker-sensitivity evidence, not an RTL mutation score.
- `MATRIX-SIZE-CAND-3S-C0832`: 45/45 cases passed across physical 4×4/8×8/16×16 arrays, five GEMM workloads, and three seeds.
- `MATRIX-ABLATION-CAND-3S-C0832`: 120/120 cases passed across eight Depth/Prefetch/A-Cache configurations, five workloads, and three seeds.

These runs close the exact-SHA repeatability, AXI assertion antecedent, and Matrix benchmark reproducibility items for the historical `c0832e5` candidate. The current-source disposition is updated below; the evidence remains linked in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

**R19 common-workload benchmark addendum (2026-10-28, historical candidate):** At product RTL SHA `c0832e5`, a benchmark-only Matrix TB mode ran the pinned TinyNPU A/B values at 16×16×16 on both 8×8 arrays; all 256 outputs passed independent Golden checks. A second case compared native NMAForge 3×3 Conv with TinyNPU's padded-GEMM lowering of the same single-channel image/filter; both returned -30. NMAForge reports 298 cycles for GEMM and 66 for native Conv. TinyNPU reports 1,800 cycles to done / 2,056 through its 256-word result stream. The temporary DSP48E1 functional model and `always_ff` compatibility copy under `/tmp` make this functional evidence, not hardware speedup or PPA. See R19 in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) and [Benchmark Report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md).

### Current candidate evidence (2026-10-28)

The selected source SHA is `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9` (SPEC v1.4 Error ABI/priority/prefix implementation). Exact clean-worktree VCS replay passed the seven-engine top UVM on seeds `20261025/26/27`, the reset R/B slice, 25/25 checker-sensitivity mutations, Matrix formal guard checks, Matrix benchmarks, and R31's CNM/DMA-SPAD abort/reset and RREADY stress. R32 replays from clean test commit `bb6e3a2`; it resets each production engine after an accepted read, with product RTL unchanged from the selected source SHA. The RTM records 24 PASS-SCOPED, 14 PARTIAL, 0 BLOCKED_SPEC and 0 NOT_RUN; no partial requirement is silently upgraded.

- Error ABI, same-cycle priority and accepted-output prefix are now specified and implemented for the listed Engine causes. Three-seed directed CNM/Matrix/SFU/Conv/KV cases check selected simultaneous Abort/watchdog, code ownership and memory prefix. Full Engine × Fault × Phase × Reset coverage remains partial.
- Matrix formal run R28 proves five non-vacuous assertions and reaches both `ST_PREFETCH_WAIT` and `ST_ERROR_DRAIN`. The default-profile FSM raw score remains 49/53; the separate no-prefetch profile hits `ST_MAC→ST_A_REQ`.
- Matrix size benchmark passes 45/45; eight-way Depth/Prefetch/A-Cache ablation passes 120/120 over three seeds. The `32×32×64` workload improves from 1,698 to 1,187 cycles and cuts banked reads by 25% between baseline and the fully enabled configuration.
- Real-top serial/staged/four-task parallel cycles are 1,239 / 1,070 / 1,137 (versus 1,696 serialized for four tasks), with ordered completions. They use the current production engines and behavioral scratchpad model.
- Coordinated reset testing excludes stale R and B for a behavioral AXI responder. Matrix depth-4 accepted-read drain/recovery passes in R30; selected CNM/DMA-SPAD accepted-read and prewrite reset recovery passes in R31; R32 resets each real top engine after an accepted read. R32 passed seeds `20261025/26/27`; each seed checked busy clear, destination/completion sentinels, stale completion/writeback and owner epoch, with 5,094 accepted writes, 5,368 checked words, zero mismatch/unknown/stale/orphan, `reset_dropped=9`, UVM severity `0/0/0`, and focused coverage `99.0%` rounded. R35 independently replayed the focused testpoint group at 100% applicable coverage on three seeds with product RTL/SPEC identical to this candidate. Actual external-fabric compliance remains open integration evidence; legal abort/fault cross coverage also remains partial.

Detailed Run IDs, tools, seeds and artifact paths are in [Execution RTM R24–R32](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). These results support bounded S1/S2 review, not CL-DV-v1.0 or whole-NPU sign-off.

## Requirement disposition table

| Requirement | Disposition | Evidence / remaining gap |
|---|---|---|
| REQ-CL-001 | PASS-SCOPED | `CLUSTER-S2-UVM-3S`: legal launches for all seven production engines. |
| REQ-CL-002 | PARTIAL | Representative opcode-to-engine launches pass; not every legal opcode/configuration tuple is swept. |
| REQ-CL-003 | PASS-SCOPED | `CLUSTER-LAUNCH-3S`: real-top launch monitor captured scalar VDOT source/destination/length/flags/aux/strides against the descriptor. Other engines and boundary-value fields remain outside this test. |
| REQ-CL-004 | PASS-SCOPED | `CLUSTER-LAUNCH-3S`: scalar VDOT flags, aux0, and all three strides were perturbed; output/completion stayed Golden. Unused-field sweeps for other engines remain open. |
| REQ-CL-005 | PARTIAL | `CLUSTER-LATCH-3S`: a 64-word scalar VDOT completed with result 4,480 at the original destination after its source/destination descriptor words were changed in flight. This does not cover the full engine/field matrix. |
| REQ-CL-006 | PARTIAL | `CLUSTER-STABILITY-3S`: no payload violations; stalled mask `1110111`, per-engine stall cycles `{7,4,23,0,261,8,6}`, Matrix banked checks=338, and 30 stall checks on each CNM lane. Matrix line stalls were not observed in this top test; all directions/classes are not closed. |
| REQ-CL-007 | PASS-SCOPED | Accepted-read ownership ledger; R32 all-engine accepted-read reset sweep adds zero stale/orphan responses across 3 seeds. |
| REQ-CL-008 | PASS-SCOPED | R32 byte-aware accepted-write memory image: 5,368 words/seed, 5,094 writes, zero mismatch/unknown. |
| REQ-CL-009 | PASS-SCOPED | Four CNM lanes, address/response ownership and selected parity cross checked; broader latency/fault matrix remains open. |
| REQ-CL-010 | PARTIAL | Matrix 2/4 outstanding block regressions pass; R30 adds outstanding-read drain/recovery and line-write backpressure. Observed Matrix line mask is full; partial/zero WSTRB semantics remain open under OPEN-CL-004. |
| REQ-CL-011 | PASS-SCOPED | Seven-engine completion ledger; all-engine Done/missing/duplicate checker mutations caught. |
| REQ-CL-012 | PASS-SCOPED | Selected per-engine result/error/completion Golden checks pass; not every error/result code. |
| REQ-CL-013 | PASS-SCOPED | Selected task lifecycle is exactly-once; lifecycle mutations cover every engine bit. |
| REQ-CL-014 | PARTIAL | Backpressure and bounded progress observed; no full fairness/bound matrix for every engine. |
| REQ-CL-015 | PARTIAL | Representative Golden tasks pass for all engines; not every opcode × shape × numeric class. |
| REQ-CL-016 | PASS-SCOPED | Selected cross-engine task switching and stale-response checks pass. |
| REQ-CL-017 | PARTIAL | Parity/protection/abort prefixes are checked in selected cases; R30 adds Matrix phase Abort/drain and R31 adds CNM parity during DMA abort, no result write and recovery. Full engine × fault × phase prefix matrix is open. |
| REQ-CL-018 | PARTIAL | R32 resets all seven real top engines after accepted reads and checks stale completion/writeback plus destination/completion sentinels; R27 covers coordinated AXI R/B reset with behavioral responder. External-fabric compliance and broader legal fault/reset phases remain open. |
| REQ-CL-019 | PARTIAL | v1.4 freezes same-cycle priority and accepted-write prefix; R30 adds Matrix fault+Abort/Reset and R31 adds CNM parity/abort with same-cycle and delayed reset, but the full legal fault-pair/phase/reset matrix remains open. |
| REQ-CL-020 | PARTIAL | Selected signed INT8 VDOT/GEMM numerics pass; complete opcode, saturation and boundary matrix is not closed. |
| REQ-CL-021 | PASS-SCOPED | Four-bank CNM address/response ledger and selected GEMV Golden/parity cases pass; R31 also sweeps K={1,2,8,9} × M={2,3,4} and four lane parity under DMA contention. |
| REQ-CL-022 | PASS-SCOPED | `MATRIX-S1-DEPTH4-3S`: 18 Golden/layout and 34 fault/recovery cases per seed; 16×16 profile covered. Broader option space and line WSTRB remain open. |
| REQ-CL-023 | PASS-SCOPED | v1.3 freezes SFU integer arithmetic; 192/192 selected edge vectors are bit-exact over three seeds. Other legal length/address combinations remain outside that campaign. |
| REQ-CL-024 | PASS-SCOPED | `CNN-KV-RAND-3S`: both Conv3x3 and depthwise opcodes; 25 convolution cases/seed across 3–6 row/column shapes; every valid-window output checked against an independent signed oracle under ready stalls and 0–7-cycle responses. Widths above 6 remain outside this run. |
| REQ-CL-025 | PASS-SCOPED | `CNN-KV-RAND-3S`: 27 read/write round trips/seed; lengths 1–128, token/head stride fields, zero/minimum/high boundary offsets and complete memory images checked across the 512 KiB model. Exhaustive stride cross-products and out-of-aperture overflow behavior remain open. |
| REQ-CL-026 | PASS-SCOPED | `FP-UVM-2S`: 596/596 bit-exact mixed BF16/FP16 transactions per seed; odd tails, response latency, two outstanding reads and selected parity/reset cases covered. The real-top cluster UVM also launches and checks the FP engine. |
| REQ-CL-027 | PARTIAL | v1.4 freezes supported per-engine Error ABI and priority. Selected codes/owner/prefix scenarios pass; full Engine × Fault × Phase mapping coverage remains open. |
| REQ-CL-028 | PARTIAL | Matrix and cluster cycle counters are reported; all counter boundaries/events are not independently covered. |
| REQ-PC-001 | PASS-SCOPED | Three-seed C0-P run covers all 21 unordered engine pairs. |
| REQ-PC-002 | PASS-SCOPED | Same-engine queueing with other engines active passes selected scenarios. |
| REQ-PC-003 | PASS-SCOPED | Selected CMDQ dispatch and CPLQ retirement order checks pass. |
| REQ-PC-004 | PASS-SCOPED | Selected variable-latency/full-queue hold and ordered retirement checks pass. |
| REQ-PC-005 | PASS-SCOPED | Simultaneous engine Done and distinct completion records are checked. |
| REQ-PC-006 | PARTIAL | Shared mux ownership, selected ready stalls and response/error routing pass; R31 adds CNM/FP-versus-DMA contention and 16/64/300-cycle DMA RREADY stalls. Complete requester/error/backpressure matrix remains open. |
| REQ-PC-007 | PARTIAL | Matrix/CNM separate tags, four CNM lanes and response ledger pass; R31 covers four-lane CNM parity under DMA contention. Full integrated line/banked fault/backpressure sweep remains open. |
| REQ-PC-008 | PASS-SCOPED | `CLUSTER-SHARED-RO-3S`: scalar VDOT and SFU GELU concurrently read the same immutable 64-word SPAD region, with distinct Golden-checked destinations/completions. Conflicting write aliases remain excluded by software contract. |
| REQ-PC-009 | PASS-SCOPED | Multi-engine abort stops selected dispatch and drains ordered completions; broader active-engine combinations remain open. |
| REQ-PC-010 | PASS-SCOPED | R32: each of seven real engines reset after an accepted read; busy cleared, destination/completion sentinels held, no stale response/completion/writeback. R31/R27 cover selected CNM/DMA and behavioral AXI R/B reset. Other reset phases and external-fabric qualification remain open. |

## Reproducible clean-SHA runs

All commands below ran from detached clean worktree
`/tmp/nmaforge_s1s2_clean_c83ad74` at the tested SHA above. Generated VCS/URG
artifacts are under `/tmp` and are not checked into the repository.

| Run ID | Command | Result / artifact |
|---|---|---|
| `MATRIX-S1-DEPTH4-3S` | `make -C dv/block/compute/matrix/sim core-random-regress OUTSTANDING_DEPTH=4 SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_s1s2_clean_c83ad74_matrix` | PASS; URG `/tmp/nmaforge_s1s2_clean_c83ad74_matrix/urg/` |
| `MATRIX-S1-NOPREF-3S` | `make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress OUTSTANDING_DEPTH=4 NEXT_K_PREFETCH_ENABLE=0 PHYSICAL_ARRAY_SIZE=16 SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_s1s2_clean_c83ad74_noprefetch` | PASS; fallback observed in all three seeds |
| `CLUSTER-S2-UVM-3S` | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_s1s2_clean_c83ad74_uvm` | PASS; per-seed logs and merged URG under output directory |
| `CLUSTER-S2-MUT-25` | `make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_s1s2_clean_c83ad74_uvm COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_s1s2_clean_c83ad74_mutations` | PASS 25/25, expected checker by mutation; logs under output directory |
| `CLUSTER-S2-TOP-SMOKE` | `make ai_smoke` from `dv/subsystem/top_smoke/sim` | PASS (`TEST PASS`, 86-descriptor mapper precheck). One VCS `[LOOP-REROLL-ENABLED]` warning in the workload fixture affects line-debug capacity only. |

VCS/URG compile diagnostics for the clean UVM and Matrix runs had no compile
warnings/errors and no `TFIPC`. The top-smoke warning is retained as a
disposition item rather than counted as zero warnings. Mutation runs are
expected to report UVM checker errors; the normal three-seed regression remains
at UVM warning/error/fatal `0/0/0`.

## Supplemental validation and license retry on 2026-10-27

The initial CNN/KV and SFU attempts below occurred while VCS could not connect
to the configured license server; they stopped before compilation. After the
license was restored, both blocks and the additional runs listed below passed.
The supplemental runs used the source tree based on `fa2b4dd` with the DV
interface/sequence/Makefile changes listed below; those same RTL/DV file
contents are now committed, and `rtl/` was not changed. The final report edits
followed the run. The first independent clean-worktree replay was blocked by
license-server connectivity; the successful retry after license recovery is
recorded in the addendum at the end of this report.

| Intended run | Command | Result |
|---|---|---|
| CNN/KV initial attempt | `make random-latency-regress SEEDS='20261021 20261022 20261023' OUT_DIR=/tmp/nmaforge_unverified_cnn_kv_20261027` from `dv/block/compute/cnn_kv/sim` | BLOCKED_ENV before compile; license server unavailable. A successful retry is below. |
| SFU initial attempt | `make random-latency-regress SEEDS='20261021 20261022 20261023' OUT_DIR=/tmp/nmaforge_unverified_sfu_20261027` from `dv/block/compute/sfu/sim` | BLOCKED_ENV before compile; license server unavailable. A successful retry is below. |
| FP independent reference-model unit checks | `python3.12 -m unittest discover -s dv/block/compute/fp/model -p 'test_*.py' -v` | PASS 19/19 software-model tests; this does not exercise RTL. |

Successful retries and new testpoints:

| Run ID | Command | Result / artifact |
|---|---|---|
| `CNN-KV-RAND-3S` | `make random-latency-regress SEEDS='20261021 20261022 20261023' OUT_DIR=/tmp/nmaforge_unverified_cnn_kv_retry_20261027` from `dv/block/compute/cnn_kv/sim` | PASS all seeds; each ran 25 Conv + 12 depthwise cases, 27 KV roundtrips, Conv/KV fault counts 6/7, two late faults, reset+fault and recovery; reads matched responses, max delay 7. |
| `SFU-RAND-3S` | `make random-latency-regress SEEDS='20261021 20261022 20261023' OUT_DIR=/tmp/nmaforge_unverified_sfu_retry_20261027` from `dv/block/compute/sfu/sim` | PASS all seeds; each ran 64 cases/8 error cases, late fault, fault+abort, reset+fault/recovery, 39 reset and 39 abort state observations, 1,040 reads/responses and 427 writes. |
| `FP-UVM-2S` | `make dot-uvm-regress DOT_UVM_OUT_DIR=/tmp/nmaforge_unverified_fp_uvm_20261027 DOT_UVM_SEEDS='20261028 20261029' DOT_RANDOM_COUNT=256` from `dv/block/compute/fp/sim` | PASS; 596/596 bit-exact scoreboard transactions per seed; BF16/FP16, odd-tail parity, two outstanding, response latency, and selected fault/reset groups all 100%; severity 0/0/0. Merged URG under output directory. |
| `MATRIX-CORE-3S-FA2B` | `make core-random-regress OUTSTANDING_DEPTH=4 SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_unverified_matrix_core_20261027` from `dv/block/compute/matrix/sim` | PASS all seeds; 18 Golden + 34 fault/recovery cases per seed, including late tile fault, fault+abort, reset+fault/recovery, outstanding abort/parity, prefetch parity/abort/watchdog/reset and state-phase abort/reset. |
| `MATRIX-ABLATION-40-FA2B` | `make matrix-config-comparison SEED=20261026 MATRIX_CONFIG_OUT=/tmp/nmaforge_unverified_matrix_compare_20261027` from `dv/block/compute/matrix/sim` | PASS 8 configurations × 5 workloads. At 32×32×64, depth4/prefetch/cache took 1,187 cycles and 384 bank reads versus 1,698 cycles/512 reads at depth2/no-prefetch/no-cache (30.1% fewer cycles). One seed and one-cycle behavioral SPAD only. |
| `CLUSTER-S2-UVM-3S-FA2B` | `make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_unverified_cluster_uvm_final3_20261027` from `dv/uvm/sim` | PASS all seeds; all seven engines and selected serial/staged/parallel, fault, abort, reset, DMA response and new launch/latch/shared-read-only checks. UVM severity 0/0/0; memory scoreboard each seed: 4,946 writes, 5,256 checked words, 0 mismatch/unknown/orphan/stale response; selected covergroup 98.96%. Staged workload was 1,239→1,070 cycles (1.158×); four-task queue was 1,696→1,137 cycles (1.492×) with ordered completions. Merged URG is deliberately a DUT+testbench/UVM report, not DUT-only coverage. |
| `CLUSTER-S2-MUT-25-FA2B` | `make uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_unverified_cluster_uvm_final3_20261027 COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_unverified_cluster_mutations_final_20261027` from `dv/uvm/sim` | PASS 25/25 expected checker catches: address/data/owner/WSTRB plus done/missing/duplicate done on each of seven engine bits. These mutate monitor observations, not RTL. |
| `CLUSTER-S2-TOP-SMOKE-FA2B` | `make ai_smoke` from `dv/subsystem/top_smoke/sim` | PASS (`TEST PASS`, mapper precheck and 86-descriptor fixed-weight Transformer flow). Compile retains one `[LOOP-REROLL-ENABLED]` warning from the workload fixture; it affects line-debug capacity. |

The current top UVM adds four checked testpoints: launch-field snapshot and
unused VDOT-field perturbation; descriptor mutation after launch while the
scalar engine is busy; concurrent scalar/SFU access to one shared read-only
SPAD region; and stalled request-payload stability. All passed in all three
seeds. Per seed, stall observations were engine mask `1110111`, Matrix banked
338 checks, and 30 checks on each of four CNM lanes; the Matrix line-write
stall class had zero samples in this workload. Before the focused testpoint
disposition, the response-client group was raw 98.96% (29/30 variables). R33
and R35 clean replays report 29/29
applicable variables (100.00%); URG lists the completion-read bin as excluded
N/A with zero hits, and the test keeps the zero-read guard while observing DMA
read response. R35 reproduces the result on three seeds after license recovery.
This is focused-group coverage, not full requirement closure.
UVM compile had no `Warning`, `Error`, or `TFIPC` text.

The four Matrix `state_r` transition misses remain as reviewed dispositions in
the S1 table: one is exercised in the separate no-prefetch profile; one is
guarded by mutually exclusive prefetch profiles and proven by a non-vacuous
formal property; two error-drain entries are guard-dispositioned by
non-vacuous formal properties under the documented legal descriptor and
response assumptions. The raw default prefetch-enabled score remains 49/53
(92.45%); this is not a merged 100% FSM score or proof across every profile.

## Not covered by this sign-off candidate

- The 14 partial requirements in the table; there are 0 `BLOCKED_SPEC` and 0 `NOT_RUN` rows.
- Full all-opcode × shape × numeric-class closure and full legal fault × phase
  × engine × abort/reset cross.
- Partial Matrix line WSTRB and all `OPEN-CL-*` / `OPEN-NUM-*` dispositions.
- Broader Matrix formal properties beyond the stated guard assumptions, ASIC
  synthesis/PPA, and post-layout timing.
- Full DMA/CMDQ/compute/CPLQ system sign-off or pretrained model deployment.

The next S2 closure action is to resolve `OPEN-CL-002/003/004`, `CL-COV-006`,
and `OPEN-NUM-01/02`, then add targeted testpoints for each remaining legal P0 bin. Keep
the existing `PASS-SCOPED` evidence and add explicit `WAIVED` or `BLOCKED_SPEC`
dispositions only when approved by the relevant design owner.

The requested current-checkout CNM retry on 2026-10-27 did not start compiling:
VCS could not connect to the configured license server, including with a
bounded `-licwait 1` retry. That historical attempt is `BLOCKED_ENV`, not a DUT
failure. After license recovery, exact-candidate R31 ran the CNM/DMA-SPAD
subsystem from the clean `9d9e0f0` worktree and passed the scoped cases listed
in the Execution RTM. It is included in the current 24/14 disposition and is
not inferred from the earlier archived CNM runs.

## Exact-candidate clean replay after license recovery

After VCS licensing became available, the selected candidate
`c0832e5c822de1a03f82751d5ff8f831d0addb98` was replayed from a detached clean
worktree using VCS/URG `V-2023.12-SP1_Full64`:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_signoff_clean_c0832e5_20261027 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The command and URG merge exited `0`. All three seeds emitted
`COMPUTE_CLUSTER_REAL_UVM_PASS`, with UVM warning/error/fatal `0/0/0`. The
accepted-transaction memory scoreboard checked 5,256 words per seed with no
mismatch, unknown read, stale epoch or orphan response. In that historical
R14 run, focused compute coverage was 29/30 variables (`98.96%`). R33 adds the
current focused testpoint closure at 29/29 applicable variables (`100.00%`),
with the write-only completion-read response explicitly excluded and guarded
at zero. Compile has no warning/error or `[TFIPC]` diagnostic. URG has 22
assertions: 17 successes, 5 uncovered, zero
failure/incomplete; AR/AW stall cover properties remain unhit. Exact logs,
checksums and the assertion/group reports are in
`/tmp/nmaforge_signoff_clean_c0832e5_20261027/` and summarized as R14 in the
[Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

This closes the candidate clean-replay process item for the top-UVM slice. It
does not close all 38 REQ-CL/REQ-PC rows, the Matrix FSM residuals, all legal
fault-phase crosses, or CL-DV-v1.0. The initial license-blocked attempt above
remains only as historical evidence and is superseded by this successful run.
