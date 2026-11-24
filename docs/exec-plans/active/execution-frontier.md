# NMAForge execution frontier

Updated: 2026-11-24. This is a short handoff for the next engineering task; it
does not duplicate per-run evidence. The current Compute Cluster sign-off and
benchmark work is tracked in the execution RTM and open-issue report. The
evidence below is historical and tied to its named source SHA; it is not a fresh
pass claim for the current checkout.

## Next-step decision (2026-11-24)

### Classification and goal

The next step is **software/runtime and verification first, followed by
evidence-driven hardware/software co-design**. It is not an immediate hardware
upgrade. The goal is to make the GEMM/GEMV and model measurements reproducible,
explain the observed cycle differences, and prove a real continuous model path
on one Product Top. Only then decide whether a measured bottleneck requires an
RTL/ABI change.

The planning baseline for this checkout is branch
`feat/shape-adaptive-gemv-v2`, source SHA
`409c3a9fd647d4f8c4c881c9bfdaf5d93b7076ee`. No new simulation result at that SHA
is recorded in this handoff. The prior UVM replay cited below used a separate
candidate worktree and must not be presented as a pass for this branch.

| Gate | Work type | Next work | Goal / exit evidence |
|---|---|---|---|
| 1. Reproducible compute baseline | Software and testbench | Freeze source SHA, seed, operands, memory timing, and start/stop points. Re-run the 64×64×64 GEMM and 1×64×64 GEMV cases. Split direct compute, controller/SPAD, transfer, and host intervals; check each result against the same independent Golden. | Explain prior cycle differences with paired logs and CSV. Report cycles, useful MAC/cycle, bytes, and stalls at each measured endpoint. Do not derive system speedup from unlike endpoints. |
| 2. Regression fixture recovery | Verification/software | Reproduce the `CLUSTER_MEMORY_EMPTY` setup failure on its exact recorded SHA. The prior candidate replay failed before an engine transaction because fixture address `0x7d000` is outside the default 128 KiB SPAD. Correct the fixture allocation or map only if the configured design supports it; keep range/protection checks strict, then rerun the focused UVM smoke. | Reach the intended DUT transaction and record the exact command, compile/run logs, exit status, and checker result. If it remains blocked, preserve the failure as BLOCKED/FAIL with its source SHA. |
| 3. Continuous model path | Runtime/mapper software, with co-design if needed | Freeze the H64 model/runtime source and verify genuine Persistent-KV Decode separately from prefix replay. Continue the DeiT real-token path from the last proven stage; keep staged operator runs distinct from a single-session Product Top run. No host readback/repacking/writeback of intermediate activations. | Demonstrate producer-to-consumer dependencies, retained KV/SPAD state, completion retirement, and per-step Golden on one unreset Product Top. Report host, DMA, command, and compute costs separately. |
| 4. Dataflow A/B | Software-first co-design | Compare GEMV prefetch/arbitration settings and CNN host layout against existing DMA/repack/fused paths with identical inputs and Golden. Attribute bank, line, prefetch, and layout costs before proposing RTL. | Keep an optimization only when a reproducible A/B lowers measured latency or traffic without changing results or breaking compatibility. Include area/timing impact if RTL changes. |
| 5. Hardware decision gate | Hardware only when evidence requires it | Consider a minimal RTL/ABI change only if the measured bottleneck cannot be expressed by the current Mapper/Runtime and existing datapaths. First write the contract, minimal reproducer, expected benefit, and verification plan. | Directed Golden and protocol tests pass; legacy Matrix/SFU/CNN/model regressions remain correct; synthesis/timing cost is measured or explicitly NOT_RUN. No MAC-array or SPAD expansion is assumed. |

TinyNPU comparison remains a separate evidence task: pin both source SHAs and
match the model, arithmetic contract, memory service, and timing boundary before
calculating speedup. Otherwise publish the raw endpoints as non-comparable. A
successful benchmark does not by itself close Compute Cluster DV or authorize
an architecture freeze.

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

1. Complete Gates 1–2 above on a frozen source/test manifest and update the
   owning benchmark and verification reports with exact run identities.
2. Use those results to proceed with Gate 3's continuous H64/DeiT execution
   evidence; do not treat historical staged results as a current Product Top
   pass.
3. Run Gate 4 A/B experiments. Route an RTL change through Gate 5 only when
   measurements show that software scheduling or existing hardware cannot
   address the bottleneck.
4. Keep the [execution RTM](../../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md),
   [open-issue report](../../verification/COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md),
   FP formal frontier, LEC, DFT, PPA, and board evidence as distinct closure
   records. Do not infer full sign-off from a model Golden or benchmark pass.

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
