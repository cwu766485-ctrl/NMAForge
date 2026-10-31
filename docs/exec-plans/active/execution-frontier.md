# NMAForge execution frontier

Updated: 2026-10-30. This is a short handoff for the next engineering task; it
does not duplicate per-run evidence. The current Compute Cluster sign-off and
benchmark work is tracked in the execution RTM and open-issue report.

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

## Current verification frontier

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
