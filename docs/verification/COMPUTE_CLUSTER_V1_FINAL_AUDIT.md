# Compute Cluster v1.0 Final Audit

**Review date:** 2026-10-31

**Selected product/SPEC candidate:** c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413 (R99 CNM Protection response alignment; SPEC v1.8); R54 top-test SHA f24c5383fad511c8b2e1132c1157942807994759
- **Prior reviewed product baseline:** `6848a414eaeaa05cf9e1411cf55d9d27333208a6`
- **Follow-up evidence branch:** `work/compute-cluster-kv-overflow-20261030`
- **Follow-up product replay SHA:** `f916874a9ce60741a4516eaf9e33ebcae4a676c2`
- **Latest clean verification replay SHA:** `b86bd5df7256df6a8d641213a5601e1237254124` (R139 three-seed clean-worktree real-top UVM; tree `a1f77cc77b63795b5abfcf35410588add690f788`).
**Latest verification/test candidate:** R139 test SHA `b86bd5df7256df6a8d641213a5601e1237254124`; exact clean replay at that source tree. It is test-only; product RTL/SPEC remain tied to their separately reviewed baselines. Earlier formal evidence retains its own exact SHA.
**Decision:** bounded CL-RC1/CL-RC2 review candidate; **CL-DV-v1.0 is not signed**.

## Executive disposition

The reviewed product baseline has substantial reproducible evidence for Matrix/SPAD and seven-engine Compute Cluster behavior. R64 fixes Protection gating at Matrix banked/CNM lane SRAM boundaries and adds all-engine source-A checks; R65 extends Protection checks to selected source-B and writeback phases without changing product RTL. R66 reruns the 28-case checker-sensitivity campaign at the exact R65 SHA. R69/R70 add legal CNM response delay, backpressure, Abort/Reset phase checks, a scoped local-FSM disposition, and exact clean-SHA replay of their named scopes at `94c11ef`; R71 adds a three-seed real-top Matrix Line stall integration point at exact clean SHA `cfcd4db`. The Execution RTM still accounts for all 38 requirements (`REQ-CL-001..028`, `REQ-PC-001..010`): **24 PASS-SCOPED and 14 PARTIAL**, with no recorded FAIL, BLOCKED_SPEC, or NOT_RUN requirement. PASS-SCOPED means the named scenario passed; it is not full requirement closure.

R110 adds a non-vacuous response-owner assertion point through the production `ai_accel_memory_fabric`: 3/3 seed checks pass and URG records 426 attempts, 3 real successes, zero failures/incomplete. The requester is testbench-driven and does not close production Matrix integration or its fault/backpressure crosses; the disposition remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. See the [R110 evidence](COMPUTE_CLUSTER_BANKED_OWNER_SVA_R110_2026-10-30.md).

R111 replays the Matrix FSM formal gate at the exact R110 code/test SHA: five non-vacuous assertions proven and both reachability covers hit. This corrects the older Stage A note that those guard paths lacked formal evidence; the raw enabled-profile FSM count remains 49/53 and no full-FSM closure is claimed. See the [R111 report](COMPUTE_CLUSTER_MATRIX_FSM_R111_FORMAL_2026-10-30.md).

R139 adds a three-seed real-top dual-Protection test with a full CPLQ hold and ordered software release across two tail-wrap points. Each run checks 44,611 memory words with zero mismatch/unknown/stale/orphan, UVM severity `0/0/0`, 128 Matrix and 64 CNM tagged responses, and zero response-route mismatch. `REQ-PC-004` keeps its existing PASS-SCOPED status; `REQ-CL-017/019/027` and `REQ-PC-006/007` remain PARTIAL. The RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. Top Smoke and checker-sensitivity mutations were NOT_RUN at this UVM-only SHA. See [R139 evidence](COMPUTE_CLUSTER_DUAL_PROTECTION_CPLQ_R139_2026-10-31.md).

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
| SVA connectivity/non-vacuity | R92 merges R91 Cluster and current-content mixed E2E VDBs: 20/22 assertion properties with real successes, zero failures/incomplete; all five AXI master properties succeed and all 3 stall covers match | Two UVM RAL internals have no attempts. Behavioral responder evidence is not external-fabric qualification; broad legal requester/fault/phase/reset interactions remain open |
| Functional testpoint coverage | R35/R36/R40: 29/29 applicable variables, 5/5 applicable response-client bins on each of six R40 seeds | 100% only for this focused group; the structural completion-read bin remains excluded/N/A |
| Matrix FSM | R28 source replayed as R111 at exact R110 code/test SHA: 5/5 non-vacuous properties proven; both reachability covers hit; raw default-profile FSM 49/53 | Three guard edges dispositioned under the documented bounded assumptions; fallback is covered in the separate no-prefetch profile; no forced states or 100% FSM claim |
| CNM local FSM | R69/R70 at exact clean `94c11ef`: 8/8 states, 22/23 transitions; all six legal Abort and Reset phases hit on three seeds, with delayed reads and prefetch backpressure | The sole unhit raw transition `ST_IDLE→ST_ERROR` requires a zero-length local start; the public CNM core rejects it before local launch and the test checks the bank controllers remain idle. Raw 22/23 is retained; scoped unreachable disposition only |
| KV address and Protection | R53: 10 invalid address/alignment cases and final legal SPAD word read/write pass on three clean seeds; R54: real-top Protection denial, KV owner/error completion and sentinel | Address group is 11/11 per seed and R54 hits its four directed points. KV line/condition/FSM/branch is `100/98.77/73.33/96.97%`; four raw KV FSM transitions remain unhit without a formal-unreachable disposition; broader ownership, stride/alias and descriptor contracts remain open |
| All-engine parity fault slice | R60 at `2768843`: 18/18 selected parity reads per seed across all seven engines and all CNM lanes; checker confirms error owner/completion and no writeback | Three clean seeds pass; this adds selected read-phase parity evidence only. Legal fault × phase × Abort/Reset combinations remain incomplete |
| Current clean replay | R55–R58 at `ded9d92`: 3-seed seven-engine UVM, 25/25 checker mutations, Matrix depth-4 18 Golden + 35 fault/recovery cases/seed, and prefetch-off fallback 3 seeds. R60 at `2768843`: all-engine parity, mutation, Top Smoke and 20-case top regression | Named PASS evidence is reproducible; URG R57 preserves enabled-profile 49/53 FSM. R60 has 17/22 assertions with real success, three AXI AR/AW properties without real success and two RAL properties without attempts; R15 remains prior E2E evidence. No full closure implied |
| Current clean replay | R70 at `94c11ef`: three-seed seven-engine UVM, Matrix depth-4, CNN/KV and CNM block regression; 28/28 checker sensitivity; Top Smoke and 20-case top regression | Named scopes pass on one clean SHA. UVM has 0/0/0 severity, 5,812 checked words/seed and 100% focused applicable testpoints; top compute-only AR/AW stall-to-accept properties remain unhit. No full closure implied |
| Whole-top code coverage | Existing URG databases include DUT, checker, UVM and testbench code | Not presented as DUT-only or functional closure |

R36's compute-only AXI SVA observations show 0 matches for AR/AW stall-to-accept and one W match. This sequence does not exercise those AXI request stalls; R15 remains the evidence for real AR/AW/W assertion successes. R52 closes `OPEN-NUM-01` for the legal common VDOT/GEMV/GEMM arithmetic subset, but does not change the 24 PASS-SCOPED / 14 PARTIAL requirement dispositions.

R99 closes `OPEN-CL-003` for the designated in-repository `ai_accel_memory_fabric`: three seeds cover pending response-owner flush and recovery, with the three reset groups at 100%. The external DDR model remains behavioral; the unresolved broader legal reset/fault crosses stay under `CL-COV-006`. Evidence: [R99 report](COMPUTE_CLUSTER_MEMORY_FABRIC_RESET_R99_2026-10-30.md).

## Remaining closure items

| ID | Affected scope | Remaining evidence or contract |
|---|---|---|
| `OPEN-CL-002` | REQ-CL-002/015/020/024/025 | R53 freezes and verifies KV 32-bit overflow/alignment; R54 verifies one real-top KV Protection denial path. Other Engine descriptor ranges/aliases/strides/zero rules and wider KV boundary/ownership cases remain open. |
| `CL-COV-006` | REQ-CL-017/019/027, REQ-PC-006/007/009/010 | Expand legal Engine × Fault × Phase × Reset coverage with completion-code and accepted-write-prefix checkers. The current selected cases do not close the full cross. |
| `CL-COV-002/003` | Dataflow, opcode/shape and protocol coverage | R71 observes Matrix Line stall stability during real-top Matrix/CNM overlap and R93 observes all real-top engine pairs. Broader legal requester/backpressure/fault crosses and opcode × shape × numeric boundaries remain partial. |

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
- [R93 real-top pairwise evidence](COMPUTE_CLUSTER_REAL_TOP_PAIRWISE_R93_2026-10-30.md)

## R93 real-top all-engine pairwise overlap — 2026-10-30

At exact clean code/test SHA `d66431b8905ef7c1cccecef16a3cd34f4d62f9b0`, the production top runs all seven engines from legal disjoint-memory descriptors. Three VCS seeds observe 21/21 unordered busy pairs (`mask=1fffff`, maximum seven active engines), check all Golden SPAD images and ordered completions, and pass with UVM severity `0/0/0`. Each seed's memory scoreboard checks 26,451 words with zero mismatch, unknown, stale, or orphan responses; applicable focused compute testpoint coverage is 100%. This closes `CL-COV-004` only for real-top pair overlap. Full `REQ-PC-006/007` owner/fault/backpressure/reset crosses and the other PARTIAL requirements remain open; RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. Full command and artifact hashes are in [R93 evidence](COMPUTE_CLUSTER_REAL_TOP_PAIRWISE_R93_2026-10-30.md).
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


## R90 descriptor validator/decode check — 2026-10-30

R90 checks all 27 supported opcode classifications, the `0x36` tile-pack predicate and 21 invalid validator inputs using isolated VCS output at SHA `7837701cefe606a01abd517d46788b982da0f2e4`. This closes only the combinational validator test slice. CMDQ-to-engine dispatch and complete per-engine descriptor boundaries remain open; `REQ-CL-002` stays PARTIAL and CL-DV-v1.0 stays HOLD. See [R90 evidence](COMPUTE_CLUSTER_DESCRIPTOR_VALIDATOR_R90_2026-10-30.md).

## R91 exact-candidate replay — 2026-10-30

At exact clean code/test SHA `43a84cac688a56e789162dfa5a8106551779abdb`, the three-seed real-top UVM, 28/28 named checker-sensitivity mutations, Top Smoke, and the 20-case seeded Top regression pass. Each UVM seed checks 17,388 memory words with zero mismatch/unknown/stale/orphan responses and UVM severity `0/0/0`; the applicable focused cluster group is 64/64. URG assertion status is 17/22 successes with zero failures/incomplete, and the compute-only AXI stall covers match 1/3. The Top Smoke fixture warning is retained. This exact-candidate replay does not alter requirement status: 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 remains HOLD. See [R91 evidence](COMPUTE_CLUSTER_CLEAN_REPLAY_R91_2026-10-30.md).


## R92 current-source SVA closeout — 2026-10-30

At R91/R92 source content (all `rtl/`, `dv/`, and `docs/spec/` files byte-identical across source tree SHAs `43a84cac` and `4c5b9d4`), the combined URG database reports 20/22 assertions with real successes, zero failures/incomplete, and three of three AR/AW/W stall covers hit. Five top AXI protocol assertions all have nonzero real successes. Two UVM RAL internal properties remain without attempts. The mixed E2E checks a checked-in behavioral AXI responder; external target-fabric qualification is still open. This updates the SVA evidence only: 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` **HOLD** remain. See [R92](COMPUTE_CLUSTER_SVA_REPLAY_R92_2026-10-30.md).


## R99 selected memory-fabric reset addendum — 2026-10-30

R99 is the current exact clean candidate `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`. The selected in-repository `ai_accel_memory_fabric` reset/epoch evidence is closed for pending DMA/CNM response ownership and post-reset recovery. The same SHA fixes CNM Protection response alignment and passes the full three-seed subsystem regression, Top Smoke, and 20-case seeded Top. See [R99 evidence](COMPUTE_CLUSTER_MEMORY_FABRIC_RESET_R99_2026-10-30.md). The overall decision remains **HOLD** (24 PASS-SCOPED / 14 PARTIAL); broader legal fault/phase/reset crossings remain open.

## R123 legal concurrent CNM descriptor latch — 2026-10-31

At executed clean test SHA `750fd0f9d27c8c2b0f0b9ed6f4a82f6cacb7ca45` (tree `c8b47296ee6492e8d258f4aa7dc46ebd97844711`), three seeds pass a real-top CNM GEMV parameter-latch point while scalar changes the already-fetched destination word through the legal SPAD path. All 16 outputs match independent signed four-bank K=64 Golden `47,104`; the mutated destination sentinel is preserved; both completions pass; and each scoreboard checks 41,776 words with zero mismatch/unknown/stale/orphan. Top Smoke and the 28/28 checker-sensitivity campaign pass. This adds one `REQ-CL-005` point only; that row remains PARTIAL. The same tree is published test-only at `1abf84864a5b6f0f1d3ef5da72fe67b41df3b367`; the overall disposition stays 24 PASS-SCOPED / 14 PARTIAL and **HOLD**. See [R123 evidence](COMPUTE_CLUSTER_CNM_PARAMETER_LATCH_R123_2026-10-31.md).


## R124 mandatory CNM latch regression gate — 2026-10-31

The default three-seed Compute Cluster regression now requires the R123 CNM descriptor-latch marker in every seed. Exact executed SHA `752c9e0327c18b8775f3bfac62f4cf5483dc38d7` and published test-content SHA `863771c1062ff8390dc82c705594c5cef3289e3c` share tree `9232a92b09f4fed7573ecdc50c786f5680b8281e`. Three-seed UVM, Top Smoke, and 28/28 checker-sensitivity mutations pass. This preserves regression enforcement for one `REQ-CL-005` point; the row remains PARTIAL, the RTM remains 24 PASS-SCOPED / 14 PARTIAL, and `CL-DV-v1.0` remains **HOLD**. See [R124 report](COMPUTE_CLUSTER_CNM_LATCH_REGRESSION_GATE_R124_2026-10-31.md).


## R125 selected memory-fabric clean replay — 2026-10-31

On clean replay checkout `5ea67bd125bb1ed20af8b86369e2cf8112f25131`, the selected `ai_accel_memory_fabric` reset, banked reset, Core/Banked contention, and Core/Banked reset tests pass for three seeds each. All applicable focused coverage groups reported by the four targets are 100%; response-owner assertions have real successes and zero failure/incomplete. This confirms `OPEN-CL-003` for the selected repository fabric on current R124 functional source content, but does not close the broader integrated fault/backpressure/reset crosses. `REQ-CL-018` and `REQ-PC-007` remain PARTIAL; 24 PASS-SCOPED / 14 PARTIAL; overall **HOLD**. See [R125 report](COMPUTE_CLUSTER_MEMORY_FABRIC_CLEAN_REPLAY_R125_2026-10-31.md).


## R126 per-requester request-stability gate — 2026-10-31

The three-seed Compute Cluster UVM target now requires stalled-payload stability evidence for six scalar request clients, Matrix banked/Line, and four CNM lanes in every seed. R126 passes at local SHA `175673b0930a81a00732ddff2cf825f358465cf9`, published same-tree content `45497791e86468703303542a5961423a0311242c`; UVM severity is `0/0/0`, payload-stability violations are zero, and declared focused compute coverage is 100%. `REQ-CL-006` remains PARTIAL for the full stall-class/direction/phase cross. The 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL; **HOLD**. See [R126 report](COMPUTE_CLUSTER_REQUEST_STABILITY_GATE_R126_2026-10-31.md).


## R127 real CMDQ Scalar GEMV/GEMM dispatch — 2026-10-31

At executed local SHA 0b68ad884fa35f4f9b858953ffa5f3513fc124b4 and published same-tree test content d9aae22f8a885a4075258a9ca8c27dbaa79bb80d, three VCS seeds pass sequential real-top CMDQ Scalar GEMV 0x11 then GEMM 0x12. The monitor checks launch order and descriptor snapshot on engine 0; two completions and all six signed K=2 Golden outputs pass, with no same-engine busy relaunch. Per seed, the scoreboard checks 41,832 words with zero mismatch/unknown/stale/orphan and UVM severity 0/0/0. Top Smoke also passes. This adds bounded evidence to REQ-CL-002/015/020 and does not change their PARTIAL dispositions. The focused cluster_cg is 100% for declared bins only; global RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains **HOLD**. URG non-success properties and Top Smoke's existing compile notice are retained in the [R127 report](COMPUTE_CLUSTER_SCALAR_CMDQ_GEMV_GEMM_R127_2026-10-31.md).


## R128 Scalar CMDQ minimum-shape/numeric boundaries — 2026-10-31

At exact clean-worktree SHA dfbebbd8c8ee68458c4261f74f041e816b6b0284 and published same-tree test content 0e38b482e13eefa759441ac8ed1ab3d4d6246b37, three VCS seeds pass seven Scalar GEMV M=1/K=1 CMDQ cases. The cases cover signed bias extrema and saturation, shift 31, and identity/ReLU/ReLU6. Each seed hits case_mask=7f, checks all outputs and completions, and has zero scoreboard mismatch/unknown/stale/orphan with UVM severity 0/0/0. R128 adds bounded evidence to REQ-CL-002/015/020; all remain PARTIAL. Focused cluster_cg is 100% within declared bins, not whole-design closure. The overall RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. See the [R128 report](COMPUTE_CLUSTER_SCALAR_CMDQ_NUMERIC_BOUNDARY_R128_2026-10-31.md).

## R129 Scalar GEMV accepted-write Abort prefix — 2026-10-31

At clean test SHA 8b511e474727fe13439f99674d1a30b46005f274 and published same-tree test content 1ba30c7f85d5b07c13eddb7aef3e6929f7d9624d, three seeds pass a real CMDQ Scalar GEMV Abort after the first output write. Each checks a 1/16 Golden prefix, 15 intact suffix sentinels, 130/130 read drain, ERR_ABORT 0x32, and no output write after Abort sampling. UVM severity is 0/0/0 and the full memory scoreboard has 42,107 checked words with zero mismatch/unknown/stale/orphan. Focused cluster_cg is 100%; overall mixed URG score is 55.92%, not a sign-off percentage. This adds bounded evidence to REQ-CL-017/019/027 and REQ-PC-006; statuses remain PARTIAL and overall HOLD remains. Top Smoke: NOT_RUN at this UVM-only SHA. Mutation campaign: NOT_RUN at this UVM-only SHA. See the R129 report COMPUTE_CLUSTER_SCALAR_GEMV_ABORT_PREFIX_R129_2026-10-31.md.
