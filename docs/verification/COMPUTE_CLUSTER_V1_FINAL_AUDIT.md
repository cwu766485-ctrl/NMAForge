# Compute Cluster v1.0 Final Audit

**Review date:** 2026-10-30

**Selected product/SPEC candidate:** `cc357830923e3dd7beda114b4d761fde839b01a7` (corrective Protection RTL, SPEC v1.7); latest verification/test SHA `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec` (R88 aligned Matrix Line Abort-prefix test; no product RTL changes); R54 top-test SHA `f24c5383fad511c8b2e1132c1157942807994759`
- **Prior reviewed product baseline:** `6848a414eaeaa05cf9e1411cf55d9d27333208a6`
- **Follow-up evidence branch:** `work/compute-cluster-kv-overflow-20261030`
- **Follow-up product replay SHA:** `f916874a9ce60741a4516eaf9e33ebcae4a676c2`
- **Latest clean verification replay SHA:** `2768843da1b3f3a0e988645746000d5befadf12b`
**Latest verification/test candidate:** `3d6fe5c58631bdeb6333b6e3572f24eeba7da1ef` (R86 Matrix scalar-fallback accepted-write Abort prefix, testbench-only).
**Decision:** bounded CL-RC1/CL-RC2 review candidate; **CL-DV-v1.0 is not signed**.

## Executive disposition

The reviewed product baseline has substantial reproducible evidence for Matrix/SPAD and seven-engine Compute Cluster behavior. R64 fixes Protection gating at Matrix banked/CNM lane SRAM boundaries and adds all-engine source-A checks; R65 extends Protection checks to selected source-B and writeback phases without changing product RTL. R66 reruns the 28-case checker-sensitivity campaign at the exact R65 SHA. R69/R70 add legal CNM response delay, backpressure, Abort/Reset phase checks, a scoped local-FSM disposition, and exact clean-SHA replay of their named scopes at `94c11ef`; R71 adds a three-seed real-top Matrix Line stall integration point at exact clean SHA `cfcd4db`. The Execution RTM still accounts for all 38 requirements (`REQ-CL-001..028`, `REQ-PC-001..010`): **24 PASS-SCOPED and 14 PARTIAL**, with no recorded FAIL, BLOCKED_SPEC, or NOT_RUN requirement. PASS-SCOPED means the named scenario passed; it is not full requirement closure.

The complete requirement-by-requirement execution table lives in the [Compute Cluster Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). It records each requirement's disposition, testcase/checker or oracle, covered behavior, Run ID, seed, and evidence path. The RTM run/evidence index records source-SHA relationship, tool version, and result; R40–R45 replay the selected candidate SHA from a clean worktree. The [9d9e0f replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md) is retained as historical evidence for that earlier candidate. Runs without an exact source identity remain historical/source-equivalent and are not silently upgraded to exact-candidate replay.

The **100%** result is limited to the focused top-compute functional testpoint group reproduced by R40 on six clean seeds and reconfirmed by R55 on three seeds: 29/29 applicable URG variables, with completion-read structurally N/A and checked to remain zero. R53 separately passes 11/11 KV address-contract directed testpoints per seed on three clean seeds; R54 checks four top-level KV Protection testpoints. R57 adds Matrix fault/recovery and Line stability evidence; R58 independently checks the prefetch-off fallback profile; R60 adds 18/18 all-engine parity read points per seed; R64 adds source-A Protection denial across seven engines; R65 adds source-A/source-B/writeback Protection phases (19 cases per seed) with clean top replay. R66 adds 28/28 expected checker-sensitivity catches, which are not functional coverage. These directed marker counts are not whole-design URG coverage. Neither result means 100% requirement, DUT code, or complete Compute Cluster coverage. R52 adds a separate 13-legal-case-per-seed Scalar INT8 numeric campaign, without an URG percentage claim; R51's reserved activation=3 bin is superseded/excluded. The Matrix enabled-profile FSM remains 49/53 raw transitions; selected guard paths have formal disposition and one edge is exercised in the separate prefetch-disabled profile.

## Version and evidence integrity

- Product/SPEC review baseline is `6848a414eaeaa05cf9e1411cf55d9d27333208a6`; its clean detached checkout and tool runs are indexed in R40–R45. Follow-up candidate `f916874a9ce60741a4516eaf9e33ebcae4a676c2` preserves the baseline descriptor-validator fix and adds the SPEC v1.7 KV overflow/alignment guard; R53 is the exact clean replay for that KV change, not a rerun of every earlier campaign.
- R33/R35 are historical replays of the earlier `9d9e0f0` candidate, before the current descriptor-validator correction. They passed their recorded three seeds, but are not byte-identical to the selected `6848a41` source. R40 is the exact six-seed clean replay for the selected source and supersedes them for current-candidate reproducibility.
- R34 (`CLUSTER-COV100-REPLAY-20261029`) was an environment-blocked attempt before VCS license recovery; it produced no simulation or coverage result. R35 (`CLUSTER-COV100-LICENSE-REPLAY-20261029`) supersedes R34 only for the earlier candidate's replay status, not for current-candidate evidence or requirement dispositions.
- VCS/URG version for R33 is `V-2023.12-SP1_Full64`; Matrix formal uses VC Formal `V-2023.12-SP2`. R33's compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostic. The separate top-smoke fixture retains one `[LOOP-REROLL-ENABLED]` warning, documented in the RTM.
- A first clean replay at `9688429` exposed that the newly assigned `PACK_I8_TILE_A` bit was being rejected on unrelated VDOT descriptors. The validator was corrected according to SPEC and committed as candidate `6848a41`; six-seed R40 then passed, including the failing seed, and R44/R45 passed the top smoke and full Digits inference. R41 caught 25/25 checker mutations; R42/R43 provide Matrix and normalized TinyNPU benchmarks on the same source SHA.

## Checker and coverage review

| Area | Evidence | Audit disposition |
|---|---|---|
| Independent memory/result checks | R25/R32/R35/R36/R40 real-top scoreboard and selected per-engine Golden checks; R40 has zero mismatch/unknown/stale/orphan responses on six seeds | Pass for the named workloads and memory transactions; opcode/shape/fault space remains partial |
| Mutation sensitivity | R26/R37/R41: 25/25; R66 at R65 SHA and R70 at `94c11ef`: 28/28 expected catches for address, data, owner, WSTRB, completion error, post-error write, response epoch, and Done/missing/duplicate-Done observations | Pass for the named checker sensitivity only; this is not DUT fault injection or an RTL mutation score |
| SVA connectivity/non-vacuity | R32 has 17/22 top assertion properties with real successes and no failures/incomplete; R15 supplies real AXI AR/AW/W successes and stall-to-accept hits; compute activity properties are active | No disconnected compute activity ports found in the reviewed clean compile. Unattempted RAL and sequence-specific AXI properties remain scoped dispositions, not passes |
| Functional testpoint coverage | R35/R36/R40: 29/29 applicable variables, 5/5 applicable response-client bins on each of six R40 seeds | 100% only for this focused group; the structural completion-read bin remains excluded/N/A |
| Matrix FSM | R28: 5/5 non-vacuous legal properties proven; `ST_PREFETCH_WAIT` and `ST_ERROR_DRAIN` reachability covers hit; raw default-profile FSM 49/53 | Selected guards dispositioned; no forced states and no 100% FSM claim |
| CNM local FSM | R69/R70 at exact clean `94c11ef`: 8/8 states, 22/23 transitions; all six legal Abort and Reset phases hit on three seeds, with delayed reads and prefetch backpressure | The sole unhit raw transition `ST_IDLE→ST_ERROR` requires a zero-length local start; the public CNM core rejects it before local launch and the test checks the bank controllers remain idle. Raw 22/23 is retained; scoped unreachable disposition only |
| KV address and Protection | R53: 10 invalid address/alignment cases and final legal SPAD word read/write pass on three clean seeds; R54: real-top Protection denial, KV owner/error completion and sentinel | Address group is 11/11 per seed and R54 hits its four directed points. KV line/condition/FSM/branch is `100/98.77/73.33/96.97%`; four raw KV FSM transitions remain unhit without a formal-unreachable disposition; broader ownership, stride/alias and descriptor contracts remain open |
| All-engine parity fault slice | R60 at `2768843`: 18/18 selected parity reads per seed across all seven engines and all CNM lanes; checker confirms error owner/completion and no writeback | Three clean seeds pass; this adds selected read-phase parity evidence only. Legal fault × phase × Abort/Reset combinations remain incomplete |
| Current clean replay | R55–R58 at `ded9d92`: 3-seed seven-engine UVM, 25/25 checker mutations, Matrix depth-4 18 Golden + 35 fault/recovery cases/seed, and prefetch-off fallback 3 seeds. R60 at `2768843`: all-engine parity, mutation, Top Smoke and 20-case top regression | Named PASS evidence is reproducible; URG R57 preserves enabled-profile 49/53 FSM. R60 has 17/22 assertions with real success, three AXI AR/AW properties without real success and two RAL properties without attempts; R15 remains prior E2E evidence. No full closure implied |
| Current clean replay | R70 at `94c11ef`: three-seed seven-engine UVM, Matrix depth-4, CNN/KV and CNM block regression; 28/28 checker sensitivity; Top Smoke and 20-case top regression | Named scopes pass on one clean SHA. UVM has 0/0/0 severity, 5,812 checked words/seed and 100% focused applicable testpoints; top compute-only AR/AW stall-to-accept properties remain unhit. No full closure implied |
| Whole-top code coverage | Existing URG databases include DUT, checker, UVM and testbench code | Not presented as DUT-only or functional closure |

R36's compute-only AXI SVA observations show 0 matches for AR/AW stall-to-accept and one W match. This sequence does not exercise those AXI request stalls; R15 remains the evidence for real AR/AW/W assertion successes. R52 closes `OPEN-NUM-01` for the legal common VDOT/GEMV/GEMM arithmetic subset, but does not change the 24 PASS-SCOPED / 14 PARTIAL requirement dispositions.

## Remaining closure items

| ID | Affected scope | Remaining evidence or contract |
|---|---|---|
| `OPEN-CL-003` | REQ-CL-018, REQ-PC-009/010 | Qualify coordinated reset/epoch behavior against the selected external AXI fabric, or attach its approved compliance evidence. Current reset evidence uses a behavioral responder. |
| `OPEN-CL-002` | REQ-CL-002/015/020/024/025 | R53 freezes and verifies KV 32-bit overflow/alignment; R54 verifies one real-top KV Protection denial path. Other Engine descriptor ranges/aliases/strides/zero rules and wider KV boundary/ownership cases remain open. |
| `CL-COV-006` | REQ-CL-017/019/027, REQ-PC-006/007/009/010 | Expand legal Engine × Fault × Phase × Reset coverage with completion-code and accepted-write-prefix checkers. The current selected cases do not close the full cross. |
| `CL-COV-004` | REQ-PC-001/006/007 | The 21/21 pair test uses the real dispatcher but behavioral engine agents. Production top pair coverage remains selected, not all real-engine pairs. |
| `CL-COV-002/003` | Dataflow, opcode/shape and protocol coverage | Matrix line-write stall remains unobserved at top; broader legal request/backpressure and opcode × shape × numeric boundaries remain partial. |

The full owner-by-owner issue log is in [Compute Cluster Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md). No FSM state forcing or unsupported fault combinations are accepted as closure evidence.

R49 closes the defined Matrix Line transfer-contract checker slice. R52 closes the Scalar INT8 common arithmetic contract and directed legal VDOT/GEMV/GEMM edge campaign on three clean-worktree seeds. R51 is superseded/excluded due to reserved activation=3 stimulus. Legacy Conv and broader legal opcode/shape coverage remain PARTIAL under `REQ-CL-020`/`CL-COV-003`; neither closure implies complete subsystem coverage.

## Final review outcome

- **CL-RC1 (bounded Matrix + SPAD review):** ready for review with explicit WSTRB and broader legal fault-cross limitations.
- **CL-RC2 (bounded seven-engine review):** ready for evidence review; the RTM remains 24 PASS-SCOPED / 14 PARTIAL.
- **CL-DV-v1.0:** **HOLD / not signed** until the defined P0/P1 gaps above are resolved or formally dispositioned by the project reviewers.
- **Whole NPU sign-off, pretrained-model deployment and ASIC PPA:** not established by this audit.

## Related records

- [Complete Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)
- [Clean candidate replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md)
- [Sign-off readiness report](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md)
- [Open issue list](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md)
- [KV address R53 evidence](COMPUTE_CLUSTER_KV_ADDRESS_R53.md)
- [KV Protection R54 evidence](COMPUTE_CLUSTER_KV_PROTECTION_R54.md)
- [R55–R58 clean replay evidence](COMPUTE_CLUSTER_CLEAN_REPLAY_R55_R58_2026-10-30.md)
- [R59 Top Smoke replay evidence](COMPUTE_CLUSTER_TOP_SMOKE_REPLAY_R59_2026-10-30.md)
- [R60 all-engine parity replay evidence](COMPUTE_CLUSTER_ALL_ENGINE_PARITY_R60_2026-10-30.md)
- [R64 all-engine Protection replay evidence](COMPUTE_CLUSTER_PROTECTION_CROSS_R64_2026-10-30.md)
- [R65 Protection phase-cross replay evidence](COMPUTE_CLUSTER_PROTECTION_PHASE_CROSS_R65_2026-10-30.md)
- [R66 current-SHA checker mutation replay evidence](COMPUTE_CLUSTER_MUTATION_CLEAN_REPLAY_R66_2026-10-30.md)
- [R70 final clean replay and CNM FSM disposition](COMPUTE_CLUSTER_FINAL_CLEAN_REPLAY_R70_2026-10-30.md)
- [Matrix/TinyNPU historical benchmark report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md)

## R61 closeout update — 2026-10-30

At exact clean test SHA `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`, the three-seed real-cluster UVM regression, 28/28 named checker-sensitivity campaign, Top Smoke, and 20-case top regression pass. The focused applicable compute testpoint group is 100% on those seeds; this does not imply 100% RTL or requirement coverage. URG retains 5 uncovered properties out of 22, including three AXI AR/AW assertions without real successes and two UVM RAL properties without attempts. The three new mutation-style probes alter testbench observations/memory image, not the DUT. External-fabric qualification, broad legal fault/phase/reset crosses, unsupported Matrix partial/zero WSTRB, descriptor breadth, and other partial RTM requirements remain unresolved. **CL-DV-v1.0 remains HOLD; this is not a sign-off declaration.** See [R61 evidence](COMPUTE_CLUSTER_R61_CHECKER_SENSITIVITY_2026-10-30.md).

## R63 SVA disposition update — 2026-10-30

The initial R61 Compute Cluster-only URG remains 17/22 assertion properties with successes because that compute-focused workload does not issue stalled external AXI address traffic. R63 separately combines the R61 three-seed Compute Cluster VDBs with a same-SHA coverage-enabled mixed-precision DDR/AXI-stall VDB. The merged report has 20/22 properties with real successes, 0 failures/incomplete, and two UVM RAL no-attempt internals; all five top AXI AR/AW/W assertions and all three stall-to-accept covers are hit. This improves SVA non-vacuity evidence, but does not merge functional coverage groups or close broader fabric/fault/reset coverage. See [R63 combined SVA report](COMPUTE_CLUSTER_R63_COMBINED_SVA_2026-10-30.md). CL-DV-v1.0 remains HOLD.


## R85 Conv accepted-write Abort prefix — 2026-10-30

Three exact-clean seeds at `5a35d60d20ee6fc6622e46f92d05fc1ef00dd14d` pass a real-top Conv Abort immediately after the first accepted output write. The checker verifies one Golden output prefix word, three unchanged suffix sentinels, 21/21 accepted-read drain, and `ERR_ABORT`; each Memory Scoreboard checks 17,304 words with zero mismatch/unknown/stale and UVM severity `0/0/0`. The same exact SHA passes Top Smoke. This adds one testpoint only: accepted-write prefix lengths for the other engines and the broader legal fault/phase/reset crosses remain open. The 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R85 report](COMPUTE_CLUSTER_CONV_ABORT_WRITE_PREFIX_R85_2026-10-30.md).


## R86 Matrix scalar-fallback accepted-write Abort prefix — 2026-10-30

Three exact-clean seeds at `3d6fe5c58631bdeb6333b6e3572f24eeba7da1ef` pass a real-top Matrix 4×4 INT8 GEMM Abort after six accepted scalar output words. The test uses a word-aligned/non-Line-aligned destination, verifies no Matrix Line use, checks the Golden prefix and ten untouched sentinels, drains 8/8 accepted banked reads, and checks `ERR_ABORT`. Each Memory Scoreboard checks 17,352 words with zero mismatch/unknown/stale and UVM severity `0/0/0`. The same exact SHA passes Top Smoke, the 20-case seeded top run and 28/28 passive checker-sensitivity tests. This adds one testpoint only; aligned Line aborts, more shapes/prefixes and broad legal fault/phase/reset crosses remain open. The RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See [R86 report](COMPUTE_CLUSTER_MATRIX_ABORT_WRITE_PREFIX_R86_2026-10-30.md).


## R87 default-path regression reproducibility — 2026-10-30

At exact clean SHA `402c8ce4689ae48cfee624f1f5fdca66d534bbbf`, default-path three-seed Compute Cluster UVM, 28/28 passive checker-sensitivity mutations, and Top Smoke pass. The stable Make stamp keeps the compiled `simv_uvm` and mutation invocations under the same output root. This is harness evidence only; requirement dispositions and the HOLD decision do not change. See [R87 report](COMPUTE_CLUSTER_REGRESSION_PATH_STABILITY_R87_2026-10-30.md).


## R88 aligned Matrix Line Abort-prefix test — 2026-10-30

Exact clean SHA `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec` passes three seeds with six accepted 128-bit Line writes and 24 accepted output words per seed, full WSTRB, exact Golden Line payload/address, preserved suffix, 5/5 read drain and `ERR_ABORT`. Same-SHA Top Smoke, 20-case seeded top regression and 28/28 checker-sensitivity pass. This is one Matrix shape and Abort timing point; no requirement disposition changes and CL-DV-v1.0 remains HOLD. A truncated intermediate upload failed compile and is explicitly superseded by this exact source SHA. See [R88 report](COMPUTE_CLUSTER_MATRIX_LINE_ABORT_WRITE_PREFIX_R88_2026-10-30.md).


## R89 Matrix configuration benchmark — 2026-10-30

R89 passes 40/40 Golden points across eight Matrix configurations and five workloads at code/test SHA `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec` using one-cycle behavioral SPAD. For d2/p0/c0→d4/p1/c1 the simulated cycle sum is 2,701→2,029; SPAD reads are 12,032→9,472 bytes, while Line stalls rise on two cases. The evidence is Matrix-core only and uses seed `20261026`; 250 MHz is not measured Fmax. See [R89 report and CSV](../benchmark/COMPUTE_CLUSTER_MATRIX_BENCHMARK_R89_2026-10-30.md). Requirement dispositions do not change and `CL-DV-v1.0` remains HOLD.
