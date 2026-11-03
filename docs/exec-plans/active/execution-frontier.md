# NMAForge execution frontier

Updated: 2026-11-03. This is a short handoff for the next engineering task; it
does not duplicate per-run evidence. The current Compute Cluster sign-off and
benchmark work is tracked in the execution RTM and open-issue report.

## Latest Compute Cluster evidence

**R250 final published-tree replay (2026-11-03):** Exact published source/test tree `da34f7e314fccf3793372c59768ebac541fa22a7` passes three-seed seven-engine UVM, Top Smoke, 16-seed mixed E2E, and 7/7 actual RTL mutation checks. URG combines 19 tests: 28/28 declared functional groups, all 3 AXI stall covers, 20/22 assertions with real successes, zero failures/incomplete; two no-attempt properties are UVM RAL internals. Hierarchy line/condition/FSM/branch/assert is 73.99/69.39/47.24/64.95/92.00%, not 100% code coverage. The audited RTM remains 24 scoped pass dispositions / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. See [R250 report](../../verification/COMPUTE_CLUSTER_FINAL_TREE_REPLAY_R250_2026-11-03.md), logs-only archive SHA-256 `9f4865a09e93152548da30c85e25ac3afcd94d6ab05abdd56930c71c6d34b57a`.

**R249 Matrix FSM disposition replay (2026-11-03):** At the exact published tree 074c0411a84e4e971898f4b864d5d7a77852b1a7, enabled-profile Matrix core passes 18 functional + 35 fault/recovery cases on each of three seeds; prefetch-disabled fallback and all five benchmark shapes pass on three seeds. VC Formal proves 5/5 non-vacuous assertions and reaches both state covers. The four residual enabled-profile transitions are accounted for by three proven guard dispositions and one legal prefetch-disabled fallback. Raw enabled-profile FSM remains 49/53; REQ-CL-010 remains PARTIAL and CL-DV-v1.0 remains **HOLD**. See [R249 report](../../verification/COMPUTE_CLUSTER_MATRIX_FSM_R249_REPLAY_2026-11-03.md); logs-only archive SHA-256 107924a06561c4af8e53de229254dbc4daca18dabb3b7d1aef9ac40b317329fc.

**R248 final published-tree replay (2026-11-03):** Exact published `main` tree `00431c3f0c05d11de2d8cf90f69ce0020c7944bf` passes three-seed seven-engine UVM, Top Smoke, 16-seed mixed-precision/AXI regression, and 7/7 actual RTL mutation checks. The merged URG plan reports 28/28 declared functional groups at 100%, 3/3 AXI stall-to-accept covers, 20/22 assertions with real successes, and zero failure/incomplete; the two no-attempt properties are UVM RAL internals. Raw line/condition/FSM/branch coverage is 73.99/69.39/47.24/64.95%. This meets the declared testpoint target only: the 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL` and `CL-DV-v1.0` remains **HOLD**. See [R248 report](../../verification/COMPUTE_CLUSTER_FINAL_TREE_REPLAY_R248_2026-11-03.md), logs-only archive SHA-256 `fd62fa63ad1978b53a091e50d6f809dfe4b05e49c93b6e44dbded8ef20ce184c`.

R247 reruns the production Descriptor Validator and Scalar INT8 numeric/core gates on the tree identical to published `main` (`be7ec4aeaff3d4a75e504809ba70327dc9ec5bbf`). The validator passes 27 opcode classifications, 21 invalid rules, 38 accepted and 26 rejected boundary vectors; its `engine_limit_claim=0` remains explicit. Scalar INT8 passes 14 cases on each of three seeds, including Abort/Watchdog/Reset priority and recovery Golden. These are bounded `REQ-CL-002/020` evidence, not requirement closure. See the [R247 report](../../verification/COMPUTE_CLUSTER_BOUNDARY_REPLAY_R247_2026-11-03.md), archive SHA-256 `c879d12dce3d435cb90db63eb14e742730b5c22c4ee21c4915b3923356905210`.

R246 reruns the actual RTL mutation campaign against exact published closeout SHA `269c2a0de8cf226dd01c3f86c05e180908252b04` / tree `61e365cc5a37998c0bf2688981cbb89f278eace2`. Seven temporary mutants are compiled and injected; the configured Address, Data, Response Owner, WSTRB, Completion Error, Missing Done, and Duplicate Done checkers all detect their mutation. This is checker-sensitivity evidence only; the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` HOLD. See the [R246 report](../../verification/COMPUTE_CLUSTER_DUT_MUTATION_R246_2026-11-03.md); logs-only archive SHA-256 `6a1f8f19078135b86b8a695ac1a951fe0b259cdd7acb8ce2d827ce9ed55b6a8b`.

R245 replays the exact published `main` SHA `8078ed55af3b72652e74308483c20bd0d18a6cc9` from a detached clean worktree. Three real-top Cluster seeds and Top Smoke pass; each seed checks 92,871 Memory Image words with zero mismatch/unknown/stale and drains its response-owner ledger. URG focused `cluster_cg` is 64/64, mixed group score is 79.18%, and assertions have 17/22 real successes with zero failure/incomplete. This confirms published-tree reproducibility only; the 38-row RTM stays 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` HOLD. See the [R245 replay report](../../verification/COMPUTE_CLUSTER_PUBLISHED_HEAD_CLEAN_REPLAY_R245_2026-11-03.md).

R244 reruns the eight depth/prefetch/A-Tile Cache Matrix configurations on the current test tree (`3db422d6456edfaf9b5dc74460f9d5507a42c08c`): all 120 shape/configuration/seed Golden points pass. D4/P1/C1 reduces the five-workload cycle sum 2,701→2,029 (24.88%) and SPAD read bytes 12,032→9,472 (21.28%); writes are unchanged, while measured line-write stalls increase. This remains one-cycle behavioral-SPAD evidence, not ASIC PPA or a TinyNPU win. See the [R244 report](../../benchmark/COMPUTE_CLUSTER_MATRIX_CONFIG_COMPARISON_R244_2026-11-03.md) and [CSV](../../benchmark/compute_cluster_matrix_config_comparison_r244.csv).

R243 adds passive per-engine request-wait observation and reruns real seven-engine UVM plus Top Smoke on the exact published code tree. Three seeds pass with clean memory and owner ledgers; maximum request waits are `{12,14,53,0,64,126,14}` cycles. URG reports `cluster_cg=64/64`, group score 79.18%, and 17/22 assertion successes with zero failure/incomplete; three AXI AR/AW assertions have no real success and two UVM RAL assertions have no attempts. No downstream SRAM stall is injected, so `REQ-CL-014` remains PARTIAL. See the [R243 report](../../verification/COMPUTE_CLUSTER_ENGINE_REQUEST_WAIT_R243_2026-11-03.md).

R240 is the latest detached clean-worktree replay of the published closeout tree: three real-top Cluster seeds and Top Smoke pass; 92,871 Memory Image words/seed have zero mismatch/unknown/stale and `cluster_cg` is 64/64. R241 separately records non-vacuous AXI AR/AW/W payload-stability assertions and stall-to-accept covers. See the [R240 replay](../../verification/COMPUTE_CLUSTER_FINAL_CANDIDATE_REPLAY_R240_2026-11-03.md) and [R241 SVA report](../../verification/COMPUTE_CLUSTER_SVA_NONVACUITY_R241_2026-11-03.md).

R235 re-audits the exact R232 published-head UVM logs for the seven-engine writeback Protection × full-CPLQ × ordered-wrap point: 7/7 engines on all three seeds, correct error mapping and sentinels, and clean memory/owner scoreboards. This testpoint is now traced to the `c5755985` RTL/DV identity; the wider fault/phase/reset/backpressure matrix remains open. See the [R235 audit](../../verification/COMPUTE_CLUSTER_P0_PROTECTION_CPLQ_REPLAY_R235_2026-11-03.md).

R234 is the earlier same-RTL benchmark snapshot; R244 refreshes its 8-way ablation at the later test tree. Common-memory TinyNPU and PPA comparisons remain open.

R233 additionally passes all nine Control UVM tests, including frontdoor RAL read/write, with zero UVM severity. All seven Control AXI-Lite assertions have real successes; two UVM library `uvm_reg_map` properties remain no-attempts and are explicitly disclosed. This does not alter the Phase A HOLD.

R232 replayed the exact published closeout HEAD 3259d4da158d56aebe41c227c426b6b4b74a0f72 from a clean worktree. Top Smoke, three-seed real seven-engine Compute Cluster UVM, 16-seed mixed E2E coverage, and the 28/28 actual RTL mutation campaign pass. Combined URG reports 28/28 declared functional covergroups at 100%; all AR/AW/W stall-to-accept cover properties match. Each Cluster seed checks 92,871 Memory Image words with zero mismatch/unknown/stale and drains the owner ledger. The combined simulation hierarchy still reports line/condition/FSM/branch coverage 73.95/69.39/47.24/64.95%, with two UVM RAL internal assertions without attempts.

The declared testpoint target is met for this merged plan. The full Phase A exit criteria are not met: the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL, so CL-DV-v1.0 stays HOLD. Next, strengthen legal downstream-stall/fairness evidence without claiming a bound absent from SPEC, close requirement-level fault × phase × reset × backpressure interactions and descriptor max/stride/alias/overflow boundaries, then review Matrix integration and remaining benchmark scope. Keep v2.0 product changes behind the v1.0 review.

See the [R232 report](../../verification/COMPUTE_CLUSTER_PUBLISHED_HEAD_CLEAN_REPLAY_R232_2026-11-03.md), [Execution RTM](../../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md), [Open-Issue List](../../verification/COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md), and [Sign-off Readiness](../../verification/COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md). The logs-only archive is /tmp/nmaforge_r232_final_evidence_20261103.tar.gz, SHA-256 ac1f65990fd2aef1b044a680170878ac8f327eb848f53be722b9a13801b2e0ba.

## Project baseline

NMAForge is a synthesizable AXI-Lite/AXI4 digital compute-near-memory
accelerator. The only chip integration top is `rtl/top/ai_accel_top.v`. Product
behavior comes from `docs/spec/SPEC_ZH.md` / `SPEC.md`; ownership and dataflow
come from `docs/architecture/ARCHITECTURE.md`.

Key architecture rules:

- `ai_spad_arbiter` is the only scheduler-side scratchpad admission point.
- `ai_command_processor` owns command lifecycle and queue-pointer advancement.
- Completion commits all four words before advancing the completion tail.
- AXI valid/ready, ID, LAST, back-pressure, reset, and abort-drain behavior
  must remain protocol-correct.
- Ordinary compute descriptors can overlap across engines through
  `ai_parallel_compute_dispatcher`; each engine has one active slot and
  completions retire in CMDQ order. See the Compute Cluster SPEC v1.1.

## Historical branch evidence snapshots

On the isolated closeout branch, exact clean candidate SHA
`43a84cac688a56e789162dfa5a8106551779abdb` passes the three-seed real-top
Compute Cluster UVM, all 28 named checker-sensitivity mutations, Top Smoke,
and the 20-case seeded Top regression. Each UVM seed checks 17,388 memory
words with zero mismatch/unknown/stale/orphan response and 100% of the
applicable focused cluster bins. URG remains 17/22 assertion successes with
zero failures/incomplete; AR/AW stall properties are not activated by this
compute-only sequence. This adds reproducibility only: the RTM remains 24
PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. See the
[R91 replay report](../../verification/COMPUTE_CLUSTER_CLEAN_REPLAY_R91_2026-10-30.md).

The VCS license is available in the current environment. On research branch
`feat/tinynpu-model-inference`, run `DIGITS-RTL-20261029-FINAL` passed: a trained
INT8 digits MLP ran through the real top-level Matrix/SFU/CMDQ/CPLQ path and
matched an independent integer Golden for all checked values. The run reports
the host layout bridge separately; it does not claim host-free inference. See
the [digits inference report](../../benchmark/REAL_MODEL_INFERENCE.md).

At source SHA `08c34322879c688afd505ddf41fa4b2a5dc93ac0`, the pinned TinyNPU
benchmark passed: 22 GEMM rows, including three common 16×16-array shapes
(16×16×16, 16×16×32, 32×32×64) with every output matched against the independent
INT32 Golden on both designs. TinyNPU's engine regression passed 6/6. The same
`conv1x_mini.onnx` graph passed on both tops; NMAForge checked all intermediate
tensors and outputs byte-exactly using eight CMDQ descriptors. Its recorded
windows are 1,985 compute cycles plus 1,080 host-layout cycles; TinyNPU's graph
smoke is 4,781 testbench cycles. Run ID `TINY-COMPARE-20261029-S20261029`; VCS
`V-2023.12-SP1_Full64`, Verilator 5.052, NumPy 2.1.3, ONNX 1.17.0. Memory
setup and timing boundaries differ, so there is no CNN or GEMM speedup claim.
Paired evidence is in [`cnn_results.csv`](../../../benchmark/tinynpu/cnn_results.csv)
and [`gemm_results.csv`](../../../benchmark/tinynpu/gemm_results.csv), with
machine summaries in the same directory. TinyNPU's direct-array measurements
exclude SRAM and graph DMA, so equal-bandwidth comparison remains open.

On current follow-up SHA `27638d191f3aabbe9e8fecc350b76849b5ab51d3`, the
license-enabled real Compute Cluster UVM regression passed three seeds with
14/14 selected parity cases, 100% applicable focused coverage, 5,368 checked
words per seed, and zero UVM warning/error/fatal. The 25/25 checker-sensitivity
mutation campaign also passed. These results reconfirm their named evidence;
the full RTM remains 24 PASS-SCOPED / 14 PARTIAL. Current top `ai_smoke` passed
with its existing `[LOOP-REROLL-ENABLED]` fixture warning.

The paired TinyNPU benchmark is archived as run
`TINY-COMPARE-20261029-S20261029`: three tiled INT8 GEMM shapes and the
`conv1x_mini.onnx` CNN pass independent Golden checks on both designs. The GEMM
cycle windows differ (NMAForge includes controller/SPAD; TinyNPU directly
drives its array), so no normalized speedup is reported. See the benchmark
README, CSV/JSON summaries, and R38 in the [Execution RTM](../../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

The trained digits MLP and the 86-descriptor Transformer fixture also passed
again on current local SHA `6115212e8587f2ca3374787df358761eada7d7ee` with VCS
`V-2023.12-SP1_Full64`. Digits matched the independent integer Golden for all
360 samples (352 correct, 97.78%) over 69 descriptors; its 70,656-cycle host
layout bridge remains separately counted. The fixed-weight Transformer
fixture checked all intermediate/completion words and ended in `TEST PASS`.
Both compiles retain `[LOOP-REROLL-ENABLED]`; neither result claims pretrained
language-model inference. See the [inference report](../../benchmark/REAL_MODEL_INFERENCE.md).

The three-seed Matrix size/ablation replay at SHA
`110e0c9db49eb1a7a558c955347accfde87f963e` passed 45/45 size cases and 120/120
configuration cases. Run ID `MATRIX-PERF-20261025-20261026-20261027-110e0c9d`; CSV/JSON evidence is
in [`benchmark/compute_performance.csv`](../../../benchmark/compute_performance.csv)
and [`benchmark/compute_performance_summary.json`](../../../benchmark/compute_performance_summary.json).

The checked-in 86-descriptor prefill/decode fixture also reran with VCS on this
SHA and passed all tensor/completion checks. It uses deterministic functional
weights; it is not a trained or pretrained GPT-style model deployment.

The current branch is research work based on the v1.0 audit candidate, not a
replacement sign-off baseline. The audited candidate remains
`9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`; its final audit records 24
PASS-SCOPED and 14 PARTIAL requirements and concludes CL-DV-v1.0 is not signed.
The digits experiment does not change that disposition.

The isolated shape-adaptive kernel also passed a fresh VCS replay on its current
source SHA `8c19eaf43c4b70a61272d698f1cb7aa9a191f27d`: three seeds, 12 shapes
per seed, baseline/GEMV Golden checks, Abort/Reset, and invalid-dimension
rejection all passed. Run ID `SHAPE-ADAPTIVE-20261029-8c19eaf4`; the compile
log has no Warning, Error, or `[TFIPC]` diagnostics. Its four-way memory
prefetch schedule remains an analytical fixed-bandwidth model, not an integrated
SPAD measurement. See the [shape-adaptive report](../../research/SHAPE_ADAPTIVE_TENSOR_ENGINE.md).

| Area | Current evidence | Open work |
|---|---|---|
| CNM, CNN/KV, FP, Matrix, SFU | Selected block/subsystem/top regression passed. Raw DUT-only code coverage is partial. | See [compute-engine status](../../verification/COMPUTE_ENGINE_STATUS.md) and [detailed run record](../../verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md). |
| A10 G0/V1–V5 | Current workstream status and strongest evidence are in the [A10 RTM](../../verification/A10_DV_RTM.md). | Full-domain FP parity proof, residual code/assertion coverage, broad interaction closure and fixed-SHA manifest remain open. |
| Static analysis | Evidence and license/tool boundaries are in [static analysis](../../verification/STATIC_ANALYSIS_REPORT.md), [SpyGlass triage](../../../dv/spyglass/LINT_TRIAGE.md), and [CDC/RDC status](../../verification/CDC_DUAL_CLOCK_DISPOSITION_ZH.md). | Resolve or disposition remaining warnings and advanced-tool gaps. |
| Physical and board | [TSMC28 report](../../verification/TSMC28_SYNTHESIS_REPORT.md) is pre-layout evidence; [XCZU15EG guide](../../verification/XCZU15EG_BRINGUP.md) defines board bring-up. | Post-layout multi-corner sign-off and board evidence are not claimed. |

## Next work

1. Close the remaining Compute Cluster P0/P1 items in the
   [execution RTM](../../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)
   and [open-issue report](../../verification/COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).
2. Freeze the reviewed source and test manifest, then replay the remaining
   required gates on one clean SHA. R35 already replays the focused group from
   clean test commit `cb9717e` with RTL/SPEC byte-identical to the review candidate.
3. Continue the FP parity-to-writeback proof from the [FP formal frontier](../../../dv/block/compute/fp/formal/README.md); an inconclusive timeout is not a pass.
4. Keep LEC, DFT, post-layout PPA, and board results as separate closure gates.
5. Continue the isolated `feat/shape-adaptive-gemv-v2` branch. Its 256-MAC
   kernel passes three-seed RTL Golden checks at SHA `8c19eaf`; the
   bandwidth/prefetch schedule is analytical and still needs an actual
   double-buffered SPAD path, bank-arbitration tests, and synthesis evidence.

## Canonical commands

Run from the repository root unless noted:

```sh
make -C dv/subsystem/tensor_datapath/sim cluster_regress
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/command_processor/formal completion-ownership
```

For RTL edits, run the focused target and `ai_smoke`. For queue, DMA,
scratchpad, top, or source-list changes, also run the seeded top regression
when the EDA environment is available. Record exact commands and PASS evidence
in the owning report; run `git diff --check` before handoff.

## 2026-10-30 update — R61 checker sensitivity replay

- Code/test commit: `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`.
- Exact clean-SHA replay: 3-seed Compute Cluster UVM PASS, 28/28 checker-sensitivity probes caught, Top Smoke PASS, 20-case seeded top regression PASS.
- Focused applicable compute testpoint group: 100% for these seeds; not full RTL/RTM closure.
- Open: external-fabric late-response/reset qualification, legal Engine × Fault × Phase × Reset crosses, Matrix descriptor/partial-WSTRB contract limits, AXI AR/AW SVA real-success gaps, and remaining partial RTM dispositions. CL-DV-v1.0 remains HOLD.
- Evidence: [R61 report](../../verification/COMPUTE_CLUSTER_R61_CHECKER_SENSITIVITY_2026-10-30.md).

## 2026-10-30 update — R62 separate AXI address-stall E2E

- Exact clean code/test SHA: `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`.
- `make uvm_mixed_precision_ddr_e2e_axi_stalls`: PASS; legal AR/AW backpressure configured, UVM severity `0/0/0`, AR/AW/W SVA cover matches `14/5/12`.
- Separate workload with no `-cm` database; do not merge its match counts into R61 URG (`22 properties; 17 success; 5 uncovered`). Consolidated SVA coverage remains open.
- Evidence: [R62 replay report](../../verification/COMPUTE_CLUSTER_R62_AXI_STALL_REPLAY_2026-10-30.md).

## 2026-10-30 update — R63 combined SVA closure evidence

- Exact clean code/test SHA `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`.
- URG merged R61 three-seed Compute Cluster VDBs with a separately identified coverage-enabled mixed-precision AR/AW stall E2E at the same SHA.
- 20/22 assertions have real successes; zero failures/incomplete; the two no-attempts are UVM RAL internals. Five top AXI AR/AW/W assertions succeeded; AR/AW/W stall covers matched 14/5/15.
- Functional coverage remains separately attributed to its workload. Broader fault/reset/fabric gaps remain; CL-DV-v1.0 stays HOLD.
- Evidence: [R63 combined SVA report](../../verification/COMPUTE_CLUSTER_R63_COMBINED_SVA_2026-10-30.md).


## 2026-10-30 update — R92 current-source SVA coverage

- R92: 16-seed coverage-enabled mixed-precision DDR/AXI E2E PASS; zero UVM warnings/errors/fatals and no UVM compile `Warning-`, `Error-`, or `[TFIPC]` diagnostics.
- Combined with exact R91 Cluster workload VDBs from byte-identical RTL/DV/SPEC source content, URG reports 20/22 assertion successes, zero failures/incomplete, and AR/AW/W stall covers `166/70/126` (3/3 hit). The two no-attempts are UVM RAL internals.
- E2E and AXI responder coverage bins meet their specified goals; functional coverage remains separately attributed by workload.
- Behavioral responder only: `OPEN-CL-003`, broad legal fault/phase/reset crosses, and the 14 PARTIAL RTM rows remain. `CL-DV-v1.0` is **HOLD**.
- Report: [R92 SVA replay](../../verification/COMPUTE_CLUSTER_SVA_REPLAY_R92_2026-10-30.md); raw log and report hashes are in the external `/tmp/nmaforge_candidate_4c5b_combined_sva_20261030/RUN_MANIFEST.md`.

## 2026-10-31 update — R123 CNM descriptor latch

- Executed clean test SHA `750fd0f9d27c8c2b0f0b9ed6f4a82f6cacb7ca45`, tree `c8b47296ee6492e8d258f4aa7dc46ebd97844711`; same tree published at test-only SHA `1abf84864a5b6f0f1d3ef5da72fe67b41df3b367`.
- Three-seed real-top UVM PASS: legal scalar SPAD write overlaps active CNM GEMV and mutates its fetched descriptor word; 16/16 outputs match signed four-bank K=64 Golden 47,104, both completions pass, scoreboard checks 41,776 words/seed with zero mismatch/unknown/stale/orphan, UVM severity `0/0/0`.
- Top Smoke PASS; checker sensitivity PASS `28/28`; declared `cluster_cg` is 100%. Mixed URG remains 55.34% with 17/22 assertion properties having real successes; five properties have no real success in this compute-only workload. No product RTL/SPEC changed.
- `REQ-CL-005` gains one bounded point and remains PARTIAL. RTM stays 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` stays **HOLD**. See [R123 report](../../verification/COMPUTE_CLUSTER_CNM_PARAMETER_LATCH_R123_2026-10-31.md).


## 2026-10-31 update — R124 CNM latch regression gate

- Executed clean code/test SHA `752c9e0327c18b8775f3bfac62f4cf5483dc38d7`, tree `9232a92b09f4fed7573ecdc50c786f5680b8281e`; published same-tree test content `863771c1062ff8390dc82c705594c5cef3289e3c`.
- Default three-seed UVM requires and passes `[CLUSTER_CNM_PARAMETER_LATCH_PASS]`; each seed checks 41,776 words with zero mismatch/unknown/stale/orphan and UVM severity `0/0/0`. Top Smoke and 28/28 checker-sensitivity mutations pass.
- This is a regression gate for one bounded CNM descriptor-latch testpoint. `REQ-CL-005` remains PARTIAL; 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.
- Evidence: [R124 report](../../verification/COMPUTE_CLUSTER_CNM_LATCH_REGRESSION_GATE_R124_2026-10-31.md).


## 2026-10-31 update — R125 selected fabric replay

- Clean replay checkout `5ea67bd125bb1ed20af8b86369e2cf8112f25131`; product RTL/DV/SPEC match the published R124 functional source content.
- Selected `ai_accel_memory_fabric` reset/epoch, banked reset, Core/Banked contention, and Core/Banked reset regressions pass on three seeds each. Applicable focused coverage groups reported by all four targets are 100%; owner SVAs have real successes and zero failure/incomplete.
- `OPEN-CL-003` remains closed for this selected fabric. `REQ-CL-018/PC-007` remain PARTIAL because broad production-engine fault/backpressure/reset combinations are still open; overall 24 PASS-SCOPED / 14 PARTIAL, **HOLD**.
- Evidence: [R125 clean replay report](../../verification/COMPUTE_CLUSTER_MEMORY_FABRIC_CLEAN_REPLAY_R125_2026-10-31.md).


## 2026-10-31 update — R126 requester stability gate

- Published same-tree test-gate content: `45497791e86468703303542a5961423a0311242c`; exact local replay: `175673b0930a81a00732ddff2cf825f358465cf9`.
- Three-seed Compute Cluster UVM passes. Each seed records nonzero stall samples for six scalar clients, Matrix banked/Line, and all four CNM lanes; existing checker reports zero stability violations and UVM severity `0/0/0`.
- Focused compute functional bins remain 100% for their declared scope. `REQ-CL-006` stays PARTIAL for broader stall × direction × phase combinations; overall 24 PASS-SCOPED / 14 PARTIAL, **HOLD**.
- Evidence: [R126 request-stability report](../../verification/COMPUTE_CLUSTER_REQUEST_STABILITY_GATE_R126_2026-10-31.md).


## 2026-10-31 update — R127 Scalar CMDQ GEMV/GEMM dispatch

- Executed test SHA 0b68ad884fa35f4f9b858953ffa5f3513fc124b4; published same-tree test content d9aae22f8a885a4075258a9ca8c27dbaa79bb80d, tree e1334264bb8962ed2d508affb0d273d89b6650ed.
- Three-seed VCS top UVM requires and passes sequential Scalar GEMV opcode 0x11 then GEMM 0x12 dispatch; checks launch fields/order, no busy relaunch, both completions, and 6/6 independent signed K=2 Golden outputs. Each scoreboard checks 41,832 words with zero mismatch/unknown/stale/orphan; severity 0/0/0.
- Top Smoke PASS; mapper reports 86 descriptors/60 tensors. Existing LOOP-REROLL-ENABLED warning retained.
- This narrows REQ-CL-002/015/020 only; all remain PARTIAL. Overall RTM is 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD.
- Evidence: [R127 report](../../verification/COMPUTE_CLUSTER_SCALAR_CMDQ_GEMV_GEMM_R127_2026-10-31.md).


## 2026-10-31 update — R128 Scalar CMDQ numeric boundaries

- Exact clean-worktree test SHA dfbebbd8c8ee68458c4261f74f041e816b6b0284; published same-tree content 0e38b482e13eefa759441ac8ed1ab3d4d6246b37, tree a5adb3db01aee36f8363eb63a67194d5078d2398.
- Three-seed VCS top UVM passes seven legal Scalar GEMV M=1/K=1 CMDQ descriptors covering signed bias extrema, saturation, arithmetic shift 31, and identity/ReLU/ReLU6. Every seed hits case_mask=7f, checks 7/7 Golden outputs/completions, and checks 41,961 memory words with zero mismatch/unknown/stale/orphan; UVM severity 0/0/0.
- Focused declared cluster_cg is 100%. URG assertion and AXI profile residuals remain disclosed.
- REQ-CL-002/015/020 gain bounded evidence and remain PARTIAL; RTM stays 24 PASS-SCOPED / 14 PARTIAL, CL-DV-v1.0 HOLD.
- Evidence: [R128 report](../../verification/COMPUTE_CLUSTER_SCALAR_CMDQ_NUMERIC_BOUNDARY_R128_2026-10-31.md).

## 2026-10-31 update — R129 Scalar GEMV accepted-write Abort prefix

- Exact clean-worktree test SHA 8b511e474727fe13439f99674d1a30b46005f274; published same-tree content 1ba30c7f85d5b07c13eddb7aef3e6929f7d9624d, tree 4a52f377cf93d008e8effd1310b94478713e82fc.
- Three VCS seeds pass legal real-CMDQ Scalar GEMV M=16/K=64 Abort after one accepted output write; Golden prefix 1/16, 15 intact sentinels, 130/130 reads drained, ERR_ABORT 0x32, zero post-Abort writes, UVM severity 0/0/0.
- Memory scoreboard checks 42,107 words with zero mismatch/unknown/stale/orphan. Focused cluster_cg is 100%; overall mixed URG score 55.92%. No RTL/SPEC change.
- REQ-CL-017/019/027 and REQ-PC-006 gain bounded evidence and remain PARTIAL. RTM remains 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 HOLD.
- Top Smoke and mutation campaign were not rerun for this UVM-only change.
- Evidence: R129 report (../../verification/COMPUTE_CLUSTER_SCALAR_GEMV_ABORT_PREFIX_R129_2026-10-31.md).

## 2026-11-02 update — R197 selected memory-fabric owner/contention/reset replay

- Fixed code/test SHA `f87acc9bca3b3ecece385fadfd5623de6837ea8d`; detached clean worktree at the matching tree `cfc7ba4955488ae58d58f36deec368173c6ec98c`.
- Four existing banked owner/contention/reset targets pass three seeds each with UVM severity `0/0/0`; contention and reset functional groups are 100%, and owner/tag assertions have real success with no failure/incomplete.
- The same SHA's R194 real-top UVM reports 320 Matrix/CNM shared-bank admissions per seed, 768 Matrix and 1,120 CNM responses, and zero owner/hold/route mismatch.
- This strengthens only selected fabric and named production Matrix/CNM points. `REQ-PC-006/007` and `REQ-CL-018` remain PARTIAL; aggregate status remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD.
- No RTL or test source changed. Evidence: [R197 report](../../verification/COMPUTE_CLUSTER_MEMORY_FABRIC_OWNER_CONTENTION_RESET_R197_2026-11-02.md); logs-only archive SHA-256 `83f03ec53a1e0344e017ccd9b8af20bfab7d0c0c8e2757ad4fe418f10e54d153`.

## 2026-11-02 update — R198 Matrix Line contract clean replay

- Fixed code/test SHA `f87acc9bca3b3ecece385fadfd5623de6837ea8d`; detached clean worktree at tree `cfc7ba4955488ae58d58f36deec368173c6ec98c`.
- The enabled 16×16 Matrix core regression passes 18 numerical/layout and 35 fault/recovery cases on each of three seeds. It checks full WSTRB, 16-byte Line alignment, 312 stall-stability samples, unaligned scalar fallback and Protection error. Partial/zero WSTRB are unsupported by SPEC v1.5.
- The separately compiled prefetch-disabled fallback and five-workload marker pass all three seeds. This uses the block-level one-cycle behavioral SPAD model, not ASIC timing or PPA.
- `OPEN-CL-004` is replayed at the current candidate; `REQ-CL-010` remains PARTIAL because the enabled raw FSM is 49/53 and wider request/fault crosses remain open. Overall status remains 24 PASS-SCOPED / 14 PARTIAL, HOLD.
- Evidence: [R198 report](../../verification/COMPUTE_CLUSTER_MATRIX_LINE_CONTRACT_R198_2026-11-02.md); archive SHA-256 `1a0099840d43316a6bb320a6fd4d5da2b51b5702c003fd0d00df202cd1fd8690`.

## 2026-11-02 update — R199 exact published-HEAD replay attempt

- Clean detached checkout: published closeout HEAD `353695f4badca20a8a12a515393af0d59a4b66b5`, tree `c79b4f100adc83400a486adc5de007d311bfe1ee`; underlying RTL/test SHA remains `f87acc9bca3b3ecece385fadfd5623de6837ea8d`.
- The three-seed UVM compile queued for `VCS-BASE-COMPILE/VCSCompiler_Net`; VCS and a local reachability check could not reach the configured license service. No sim image or test seed ran. Result is `BLOCKED_ENV`; Top Smoke, seeded Top, and combined coverage merge remain NOT_RUN at this exact HEAD.
- Prior PASS evidence stays tied to its exact tested code/test SHA. RTM remains 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 remains **HOLD**.
- Evidence: [R199 report](../../verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R199_2026-11-02.md); archive SHA-256 `d9459a09a06ad173323a04f65c494ef7b79f9e334e240cd83ac5a67cafe99376`.

## 2026-11-02 update — R200 Execution RTM integrity checker

- Added `tools/verify_compute_cluster_rtm.py` to check expected IDs, duplicate/missing rows, disposition labels, six-column formatting, and required Test/Checker, Coverage, Run/Seed, and Evidence fields.
- `python3 tools/verify_compute_cluster_rtm.py` passes 28/28 `REQ-CL` plus 10/10 `REQ-PC` rows; disposition counts are 24 PASS-SCOPED / 14 PARTIAL. The check does not verify historical artifact contents or promote sign-off.
- Evidence: [R200 report](../../verification/COMPUTE_CLUSTER_RTM_INTEGRITY_R200_2026-11-02.md). Exact published-HEAD VCS replay remains `BLOCKED_ENV` under R199.

## 2026-11-02 update — R202 RTM evidence-link audit

- Extended the RTM checker to verify repository-relative Markdown evidence targets. All 92/92 linked targets resolve; it deliberately excludes absolute `/tmp` artifacts and does not inspect evidence sufficiency.
- The 38-row matrix and its 24 PASS-SCOPED / 14 PARTIAL dispositions are unchanged; CL-DV-v1.0 remains **HOLD**.
- Evidence: [R202 report](../../verification/COMPUTE_CLUSTER_RTM_LINK_AUDIT_R202_2026-11-02.md). VCS rerun remains pending license-server reachability.

## 2026-11-02 update — R203 exact latest-HEAD replay retry

- A detached clean worktree at local commit `518b75541e32878998c9dd478a692f0ba27c0982` (tree `03c034bf30e5bbb2af2200411fa0b1e674ebf3d6`; published same-tree commit `18059052b73ad1507f7b754108b9c84ed75a929a`) was used for the three-seed Compute Cluster UVM target.
- VCS could not reach the configured license service, queued for `VCS-BASE-COMPILE/VCSCompiler_Net`, and was stopped by the 120-second timeout before producing a simulator image. No seed, Top Smoke, or seeded Top test ran. Result: `BLOCKED_ENV`.
- RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**. No product RTL or test source changed.
- Evidence: [R203 report](../../verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R203_2026-11-02.md); raw log remains outside repository at `/tmp/nmaforge_r203_compile.log`, SHA-256 `3103ee7046612a59855f0094d61574a4ce4c2c4cf71d0454eafc0fce10e6b95c`.

## 2026-11-02 update — R204 latest clean-candidate verification

- The user restored VCS license access. A detached clean worktree at `bce4f81ef37158cf80e46f5804256c8e7531a9d9` passes three-seed Compute Cluster UVM, Top Smoke, a 20-case seeded Top run, 16-seed mixed E2E coverage, and 7/7 real RTL mutations.
- Combined URG reports all 21 declared functional groups at 100%; RTL/test line/condition/FSM/branch coverage is 73.70/68.72/46.69/64.70%. Assertions are 20/22 with zero failures/incomplete and two UVM RAL no-attempts; all 3 cover properties match.
- The clean replay closes the immediate environment/reproducibility gap only. RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD** pending legal cross and contract dispositions.
- Evidence: [R204 report](../../verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R204_2026-11-02.md); archive `/tmp/nmaforge_r204_evidence_20261102.tar.gz`, SHA-256 `9f32c098463213e338cd6ef4a9da9b44631771b17f48c0350bc7fbca4d3a490f`.
