# Compute Cluster S1/S2 DV Sign-off Candidate

**Review date:** 2026-10-28 (candidate evidence addendum)

**Baseline reviewed SHA (detached clean worktree):** `c83ad7463265062d4edb84d57fe4ada8195f9b10`

**Supplemental source base:** `fa2b4dd943dba996c82fbad5828ed1a28529a854` (the supplemental RTL/DV changes are listed below)

**Simulator:** Synopsys VCS/URG `V-2023.12-SP1_Full64`

**RTL change in this review:** none. `rtl/` is byte-identical to the prior
tested RTL baseline `03bf257afdca9b0041ff80b6d30cbaf8107cf7e0`.

## Review decision

| Gate | Decision | Signed scope / hold reason |
|---|---|---|
| S1: 16×16 Matrix Block DV | **BOUNDED PASS** | Three-seed depth-4 functional/fault regression passed for the tested INT8 GEMM/batch/layout, prefetch/cache, parity/protection, abort/reset and recovery cases. The default-profile FSM has four unhit transitions; each is dispositioned below. No formal unreachable proof is claimed. |
| S2: Compute Cluster functional slice | **BOUNDED PASS** | Exact-candidate three-seed real-top, seven-engine UVM and 25/25 checker-sensitivity campaign passed. Supplemental 16-seed DMA/FP E2E also passes with non-vacuous AXI SVA. The only unhit focused functional cover variable is completion response-client, explicitly WAIVED/N/A because the completion writer is write-only. |
| S2: all 38 frozen REQ-CL/REQ-PC requirements | **HOLD** | The updated table has 23 `PASS-SCOPED`, 13 `PARTIAL`, 2 `BLOCKED_SPEC`, and 0 `NOT_RUN`. Three-seed Conv/KV and two-seed FP block evidence now closes the named functional slices; reset epoch evidence closes the scoped reset requirement. Full parameter/opcode cross, partial line WSTRB disposition, broad error-prefix/reset combinations, and SFU numeric subcontracts remain open. This is not full Compute Cluster sign-off. |
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
| `ST_PREFETCH_WAIT→ST_A_REQ` | The transition is guarded by `!ENABLE_NEXT_K_PREFETCH`, while `ST_PREFETCH_WAIT` is only entered by the enabled-prefetch path. In the disabled build, execution takes the direct `ST_MAC→ST_A_REQ` transition instead. Reviewed as a mutually exclusive compile-profile branch; no formal proof is claimed. |
| `ST_IDLE→ST_ERROR_DRAIN` | Abort/watchdog require `busy`; banked protection requires an accepted banked request. The legal Matrix request path is inactive in IDLE. No legal trigger was found in the reviewed control path; no illegal unowned event was injected just to hit this bin. Formal reachability proof is not available. |
| `ST_ERROR→ST_ERROR_DRAIN` | The state is entered after the error drain reaches zero outstanding reads; the normal request path is inactive in ST_ERROR. A new accepted request/fault is not part of the legal state contract. Reviewed against the outstanding-read invariant, without a formal unreachable proof. |

These dispositions are sufficient for the **bounded functional scope** above;
they are not a blanket waiver of all Matrix code coverage. URG reports nine
unhit branch outcomes in the same profile. They include 32-bit result-clamp
branches and control/error paths. No 100% code-coverage claim is made.

## S2: Compute Cluster evidence

Three clean-worktree seeds `20261025/20261026/20261027` passed the real-top
seven-engine UVM. Each seed reported:

- focused Compute Cluster covergroup `98.96%` (rounded runtime marker `99.0%`);
  URG found 29/30 cover variables hit. The sole miss is
  `cp_response_client.completion`; it is explicitly WAIVED/N/A because the
  completion writer issues writes and has no read-response client bin.
- memory scoreboard: 4,444 accepted writes, 4,852 checked words, zero
  mismatches, unknown reads, stale epochs, or orphan responses; all seven
  engine read/write activity bins were nonzero.
- line WSTRB observed counts `{full:512, partial:0, zero:0}`; partial WSTRB
  remains open and is not waived by this run.
- seeded parity cross `14/14`, covering INT8/Matrix/CNM/BF16, A/B operand
  phases and all four CNM lanes; this is not the full fault × phase × engine
  cross.
- UVM warning/error/fatal `0/0/0`; all seven production engines produced
  Golden-checked results and completions. The sequence also checked selected
  Matrix/CNM ownership, ordered retirement, active Matrix/SFU abort, active
  reset/recovery, and request backpressure.

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

These runs close the exact-SHA repeatability, AXI assertion antecedent, and Matrix benchmark reproducibility items. They do not change the 38 requirement dispositions (23 PASS-SCOPED, 13 PARTIAL, 2 BLOCKED_SPEC) or close the specification-dependent and unproved FSM items. Full logs and paths are in the [Execution RTM R14–R18](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

**R19 common-workload benchmark addendum (2026-10-28):** From the current workspace at the same candidate product RTL SHA, a benchmark-only Matrix TB mode ran the pinned TinyNPU A/B values at 16×16×16 on both 8×8 arrays; all 256 outputs passed independent Golden checks. A second case compared native NMAForge 3×3 Conv with TinyNPU's padded-GEMM lowering of the same single-channel image/filter; both returned -30. NMAForge reports 298 cycles for GEMM and 66 for native Conv. TinyNPU reports 1,800 cycles to done / 2,056 through its 256-word result stream. The TinyNPU VCS run required a temporary DSP48E1 functional model and an `always_ff` compatibility copy because local UNISIM is unavailable and the original source has multiple procedural writers. R19 is bounded RTL simulation evidence; it is not a hardware speedup or PPA comparison. It does not change RTM dispositions. See [Execution RTM R19](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) and [Benchmark Report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md).

## Requirement disposition table

| Requirement | Disposition | Evidence / remaining gap |
|---|---|---|
| REQ-CL-001 | PASS-SCOPED | `CLUSTER-S2-UVM-3S`: legal launches for all seven production engines. |
| REQ-CL-002 | PARTIAL | Representative opcode-to-engine launches pass; not every legal opcode/configuration tuple is swept. |
| REQ-CL-003 | PASS-SCOPED | `CLUSTER-LAUNCH-3S`: real-top launch monitor captured scalar VDOT source/destination/length/flags/aux/strides against the descriptor. Other engines and boundary-value fields remain outside this test. |
| REQ-CL-004 | PASS-SCOPED | `CLUSTER-LAUNCH-3S`: scalar VDOT flags, aux0, and all three strides were perturbed; output/completion stayed Golden. Unused-field sweeps for other engines remain open. |
| REQ-CL-005 | PARTIAL | `CLUSTER-LATCH-3S`: a 64-word scalar VDOT completed with result 4,480 at the original destination after its source/destination descriptor words were changed in flight. This does not cover the full engine/field matrix. |
| REQ-CL-006 | PARTIAL | `CLUSTER-STABILITY-3S`: no payload violations; stalled mask `1110111`, per-engine stall cycles `{7,4,23,0,261,8,6}`, Matrix banked checks=338, and 30 stall checks on each CNM lane. Matrix line stalls were not observed in this top test; all directions/classes are not closed. |
| REQ-CL-007 | PASS-SCOPED | Accepted-read ownership ledger; 1,945 responses, zero orphan/stale response; selected ready/response timing. |
| REQ-CL-008 | PASS-SCOPED | Byte-aware accepted-write memory image: 4,852 words/seed, zero mismatch/unknown. |
| REQ-CL-009 | PASS-SCOPED | Four CNM lanes, address/response ownership and selected parity cross checked; broader latency/fault matrix remains open. |
| REQ-CL-010 | PARTIAL | Matrix 2/4 outstanding block regressions and top smoke pass; partial line WSTRB is untested and OPEN-CL-004 remains. |
| REQ-CL-011 | PASS-SCOPED | Seven-engine completion ledger; all-engine Done/missing/duplicate checker mutations caught. |
| REQ-CL-012 | PASS-SCOPED | Selected per-engine result/error/completion Golden checks pass; not every error/result code. |
| REQ-CL-013 | PASS-SCOPED | Selected task lifecycle is exactly-once; lifecycle mutations cover every engine bit. |
| REQ-CL-014 | PARTIAL | Backpressure and bounded progress observed; no full fairness/bound matrix for every engine. |
| REQ-CL-015 | PARTIAL | Representative Golden tasks pass for all engines; not every opcode × shape × numeric class. |
| REQ-CL-016 | PASS-SCOPED | Selected cross-engine task switching and stale-response checks pass. |
| REQ-CL-017 | PARTIAL | Parity/protection/abort prefixes are checked in selected cases; full engine × fault × phase prefix matrix is open. |
| REQ-CL-018 | PARTIAL | Active Matrix/SFU reset drops tracked responses and recovers; external SRAM reset/late-response contract remains open. |
| REQ-CL-019 | BLOCKED_SPEC | Same-cycle multi-fault priority and all fault-pair phases remain OPEN-CL-007. |
| REQ-CL-020 | PARTIAL | Selected signed INT8 VDOT/GEMM numerics pass; complete opcode, saturation and boundary matrix is not closed. |
| REQ-CL-021 | PASS-SCOPED | Four-bank CNM address/response ledger and selected GEMV Golden/parity cases pass. |
| REQ-CL-022 | PASS-SCOPED | `MATRIX-S1-DEPTH4-3S`: 18 Golden/layout and 34 fault/recovery cases per seed; 16×16 profile covered. Broader option space and line WSTRB remain open. |
| REQ-CL-023 | BLOCKED_SPEC | Selected SFU vectors run, but approximate/numeric tolerance subcontracts are not fully frozen. |
| REQ-CL-024 | PASS-SCOPED | `CNN-KV-RAND-3S`: both Conv3x3 and depthwise opcodes; 25 convolution cases/seed across 3–6 row/column shapes; every valid-window output checked against an independent signed oracle under ready stalls and 0–7-cycle responses. Widths above 6 remain outside this run. |
| REQ-CL-025 | PASS-SCOPED | `CNN-KV-RAND-3S`: 27 read/write round trips/seed; lengths 1–128, token/head stride fields, zero/minimum/high boundary offsets and complete memory images checked across the 512 KiB model. Exhaustive stride cross-products and out-of-aperture overflow behavior remain open. |
| REQ-CL-026 | PASS-SCOPED | `FP-UVM-2S`: 596/596 bit-exact mixed BF16/FP16 transactions per seed; odd tails, response latency, two outstanding reads and selected parity/reset cases covered. The real-top cluster UVM also launches and checks the FP engine. |
| REQ-CL-027 | PARTIAL | Selected engine error codes are observed; a complete Engine × Fault table is blocked by OPEN-CL-006. |
| REQ-CL-028 | PARTIAL | Matrix and cluster cycle counters are reported; all counter boundaries/events are not independently covered. |
| REQ-PC-001 | PASS-SCOPED | Three-seed C0-P run covers all 21 unordered engine pairs. |
| REQ-PC-002 | PASS-SCOPED | Same-engine queueing with other engines active passes selected scenarios. |
| REQ-PC-003 | PASS-SCOPED | Selected CMDQ dispatch and CPLQ retirement order checks pass. |
| REQ-PC-004 | PASS-SCOPED | Selected variable-latency/full-queue hold and ordered retirement checks pass. |
| REQ-PC-005 | PASS-SCOPED | Simultaneous engine Done and distinct completion records are checked. |
| REQ-PC-006 | PARTIAL | Shared mux ownership, selected ready stalls and response/error routing pass; complete requester/error/backpressure matrix remains open. |
| REQ-PC-007 | PARTIAL | Matrix/CNM separate tags, four CNM lanes and response ledger pass in selected real-top cases; full line/banked fault/backpressure sweep remains open. |
| REQ-PC-008 | PASS-SCOPED | `CLUSTER-SHARED-RO-3S`: scalar VDOT and SFU GELU concurrently read the same immutable 64-word SPAD region, with distinct Golden-checked destinations/completions. Conflicting write aliases remain excluded by software contract. |
| REQ-PC-009 | PASS-SCOPED | Multi-engine abort stops selected dispatch and drains ordered completions; broader active-engine combinations remain open. |
| REQ-PC-010 | PASS-SCOPED | `CLUSTER-S2-UVM-3S-FA2B`: active Matrix/SFU reset dropped two already-accepted reads per seed; no stale/orphan response or old completion/writeback appeared, SRAM sentinels were retained, and a fresh post-reset task completed. Other reset phases/engines remain outside this scope. |

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
stall class had zero samples in this workload. The response-client group
remains raw 98.96% (29/30 variables); its sole uncovered completion-read bin
is waived/N/A because the completion writer is write-only, while DMA read
response was observed. UVM compile had no `Warning`, `Error`, or `TFIPC` text.

The four Matrix `state_r` transition misses remain as reviewed dispositions in
the S1 table: two are mutually exclusive prefetch compile profiles, and two
have no legal trigger found in the current control path. No formal unreachable
proof is claimed; the Matrix directory has no dedicated formal harness. The
Matrix FSM remains 49/53 (92.45%) in the default prefetch-enabled profile and
is not being presented as 100% closed.

## Not covered by this sign-off candidate

- The other 13 partial and 2 blocked requirements in the table.
- Full all-opcode × shape × numeric-class closure and full legal fault × phase
  × engine × abort/reset cross.
- Partial Matrix line WSTRB and all `OPEN-CL-*` / `OPEN-NUM-*` dispositions.
- Formal Matrix reachability proof, ASIC synthesis/PPA, and post-layout timing.
- Full DMA/CMDQ/compute/CPLQ system sign-off or pretrained model deployment.

The next S2 closure action is to resolve `OPEN-CL-002/003/004/006/007` and
`OPEN-NUM-01/02`, then add targeted testpoints for each now-legal P0 bin. Keep
the existing `PASS-SCOPED` evidence and add explicit `WAIVED` or `BLOCKED_SPEC`
dispositions only when approved by the relevant design owner.

The requested current-checkout CNM retry on 2026-10-27 did not start compiling:
VCS could not connect to the configured license server, including with a
bounded `-licwait 1` retry. This is a new `BLOCKED_ENV` attempt, not a CNM test
failure and not additional PASS evidence. Earlier archived CNM runs remain
historical evidence; this retry is not counted in the 23 `PASS-SCOPED` tally.

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
mismatch, unknown read, stale epoch or orphan response. Focused compute coverage
is 29/30 variables (`98.96%`). Compile has no warning/error or `[TFIPC]`
diagnostic. URG has 22 assertions: 17 successes, 5 uncovered, zero
failure/incomplete; AR/AW stall cover properties remain unhit. Exact logs,
checksums and the assertion/group reports are in
`/tmp/nmaforge_signoff_clean_c0832e5_20261027/` and summarized as R14 in the
[Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

This closes the candidate clean-replay process item for the top-UVM slice. It
does not close all 38 REQ-CL/REQ-PC rows, the Matrix FSM residuals, all legal
fault-phase crosses, or CL-DV-v1.0. The initial license-blocked attempt above
remains only as historical evidence and is superseded by this successful run.
