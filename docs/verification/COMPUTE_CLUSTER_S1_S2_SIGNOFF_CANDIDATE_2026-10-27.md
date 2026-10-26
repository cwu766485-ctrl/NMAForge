# Compute Cluster S1/S2 DV Sign-off Candidate

**Review date:** 2026-10-27  
**Tested source SHA:** `c83ad7463265062d4edb84d57fe4ada8195f9b10`  
**Simulator:** Synopsys VCS/URG `V-2023.12-SP1_Full64`  
**RTL change in this review:** none. `rtl/` is byte-identical to the prior
tested RTL baseline `03bf257afdca9b0041ff80b6d30cbaf8107cf7e0`.

## Review decision

| Gate | Decision | Signed scope / hold reason |
|---|---|---|
| S1: 16×16 Matrix Block DV | **BOUNDED PASS** | Three-seed depth-4 functional/fault regression passed for the tested INT8 GEMM/batch/layout, prefetch/cache, parity/protection, abort/reset and recovery cases. The default-profile FSM has four unhit transitions; each is dispositioned below. No formal unreachable proof is claimed. |
| S2: Compute Cluster functional slice | **BOUNDED PASS** | Three-seed real-top, seven-engine UVM passed its selected workload set; the accepted-transaction memory scoreboard, 14-case parity cross, reset/abort checks and 25/25 observation-mutation sensitivity campaign passed. The only unhit functional cover variable is completion response-client, explicitly WAIVED/N/A because the completion writer is write-only. |
| S2: all 38 frozen REQ-CL/REQ-PC requirements | **HOLD** | The table below has 16 `PASS-SCOPED`, 17 `PARTIAL`, 2 `BLOCKED_SPEC`, and 3 `NOT_RUN`. In particular, the full parameter/opcode cross, partial line WSTRB, error-prefix/reset combinations, SFU numeric subcontracts, and shared-read-only isolation are not all closed. This is not full Compute Cluster sign-off. |
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

## Requirement disposition table

| Requirement | Disposition | Evidence / remaining gap |
|---|---|---|
| REQ-CL-001 | PASS-SCOPED | `CLUSTER-S2-UVM-3S`: legal launches for all seven production engines. |
| REQ-CL-002 | PARTIAL | Representative opcode-to-engine launches pass; not every legal opcode/configuration tuple is swept. |
| REQ-CL-003 | NOT_RUN | Launch sampling around all configuration-edge cases lacks a dedicated sequence. |
| REQ-CL-004 | NOT_RUN | Unused-field perturbation is not systematically swept across engines. |
| REQ-CL-005 | PARTIAL | Selected in-flight tasks preserve sampled configuration; not the full engine/field matrix. |
| REQ-CL-006 | PARTIAL | Real top observes 236 compute-request backpressure cycles; not every engine, direction and stall class. |
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
| REQ-CL-024 | PARTIAL | Selected Conv3x3 Golden case passes; complete height/width/sign/window classes are not closed. |
| REQ-CL-025 | PARTIAL | KV write/readback and selected stride/address cases pass; overflow/alias/head/token matrix is incomplete. |
| REQ-CL-026 | PARTIAL | Selected mixed-FP engine activity is checked; full BF16/FP16 class × odd-tail × response-latency matrix is not closed here. |
| REQ-CL-027 | PARTIAL | Selected engine error codes are observed; a complete Engine × Fault table is blocked by OPEN-CL-006. |
| REQ-CL-028 | PARTIAL | Matrix and cluster cycle counters are reported; all counter boundaries/events are not independently covered. |
| REQ-PC-001 | PASS-SCOPED | Three-seed C0-P run covers all 21 unordered engine pairs. |
| REQ-PC-002 | PASS-SCOPED | Same-engine queueing with other engines active passes selected scenarios. |
| REQ-PC-003 | PASS-SCOPED | Selected CMDQ dispatch and CPLQ retirement order checks pass. |
| REQ-PC-004 | PASS-SCOPED | Selected variable-latency/full-queue hold and ordered retirement checks pass. |
| REQ-PC-005 | PASS-SCOPED | Simultaneous engine Done and distinct completion records are checked. |
| REQ-PC-006 | PARTIAL | Shared mux ownership, selected ready stalls and response/error routing pass; complete requester/error/backpressure matrix remains open. |
| REQ-PC-007 | PARTIAL | Matrix/CNM separate tags, four CNM lanes and response ledger pass in selected real-top cases; full line/banked fault/backpressure sweep remains open. |
| REQ-PC-008 | NOT_RUN | Concurrent shared-read-only isolation has no dedicated scoreboard sequence; conflicting aliases are excluded by software contract. |
| REQ-PC-009 | PASS-SCOPED | Multi-engine abort stops selected dispatch and drains ordered completions; broader active-engine combinations remain open. |
| REQ-PC-010 | PARTIAL | Active reset clears selected owner/task state and permits recovery; external SRAM retention/late response contract is still open. |

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

## Not covered by this sign-off candidate

- The other 17 partial, 2 blocked, and 3 not-run requirements in the table.
- Full all-opcode × shape × numeric-class closure and full legal fault × phase
  × engine × abort/reset cross.
- Partial Matrix line WSTRB and all `OPEN-CL-*` / `OPEN-NUM-*` dispositions.
- Formal Matrix reachability proof, ASIC synthesis/PPA, and post-layout timing.
- Full DMA/CMDQ/compute/CPLQ system sign-off or pretrained model deployment.

The next S2 closure action is to resolve `OPEN-CL-002/003/004/006/007` and
`OPEN-NUM-01/02`, then add targeted testpoints for each now-legal P0 bin. Keep
the existing `PASS-SCOPED` evidence and add explicit `WAIVED` or `BLOCKED_SPEC`
dispositions only when approved by the relevant design owner.
