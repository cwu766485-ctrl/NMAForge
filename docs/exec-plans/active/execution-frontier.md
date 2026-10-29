# NMAForge execution frontier

Updated: 2026-10-29. This is a short handoff for the next engineering task; it
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

The VCS license is available in the current environment. On research branch
`feat/tinynpu-model-inference`, run `DIGITS-RTL-20261029-FINAL` passed: a trained
INT8 digits MLP ran through the real top-level Matrix/SFU/CMDQ/CPLQ path and
matched an independent integer Golden for all checked values. The run reports
the host layout bridge separately; it does not claim host-free inference. See
the [digits inference report](../../benchmark/REAL_MODEL_INFERENCE.md).

At source SHA `0c525bcf8fbdd957396cc98fb314ec56c7888a18`, the pinned TinyNPU
benchmark passed: 18 GEMM rows, 256/256 same-vector outputs on both designs,
TinyNPU's engine regression 6/6, and the same `conv1x_mini.onnx` graph on both
tops. NMAForge passed all intermediate tensors and final outputs byte-exactly
using eight CMDQ descriptors. Its recorded windows are 1,985 compute cycles
plus 1,080 host-layout cycles; TinyNPU's graph smoke is 4,781 testbench cycles.
Run ID `TINY-COMPARE-20261029-S20261029`; VCS
`V-2023.12-SP1_Full64`, Verilator 5.052, NumPy 2.1.3, ONNX 1.17.0. Memory
setup and timing boundaries differ, so there is no CNN speedup claim.
Paired evidence is in [`cnn_results.csv`](../../../benchmark/tinynpu/cnn_results.csv)
and the [comparison report](../../benchmark/NMAFORGE_VS_TINY_NPU.md).

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
