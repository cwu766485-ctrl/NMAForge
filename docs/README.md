# NMAForge documentation

[中文索引](README_ZH.md) · [Repository README](../README.md)

## Current design and verification sources

| Topic | Source |
|---|---|
| Product behavior, register ABI and numerical contracts | [English spec](spec/SPEC.md) · [中文规格](spec/SPEC_ZH.md) · [FP extension spec](spec/FP_EXTENSION_SPEC_ZH.md) · [Naming compatibility](spec/NAMING_COMPATIBILITY.md) |
| RTL ownership and dataflow | [Architecture](architecture/ARCHITECTURE.md) |
| Compute-engine verification status | [Five-engine status](verification/COMPUTE_ENGINE_STATUS.md) · [2026-10-21 run evidence](verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md) |
| A10 requirement traceability and remaining closure | [A10 RTM](verification/A10_DV_RTM.md) · [Bug register](verification/A10_BUG_REGISTER.md) · [Verification plan](verification/VPLAN.md) |
| Lint, CDC/RDC and synthesis evidence | [Static analysis](verification/STATIC_ANALYSIS_REPORT.md) · [CDC disposition](verification/CDC_DUAL_CLOCK_DISPOSITION_ZH.md) · [RDC status](verification/RDC_STATUS_ZH.md) · [SpyGlass triage](../dv/spyglass/LINT_TRIAGE.md) · [TSMC28 synthesis](verification/TSMC28_SYNTHESIS_REPORT.md) |
| Board bring-up | [XCZU15EG procedure](verification/XCZU15EG_BRINGUP.md) |
| CNM evaluation and research | [CNM evaluation](architecture/CNM_EVALUATION.md) · [中文评估](architecture/CNM_EVALUATION_ZH.md) · [Literature review](architecture/Literature_Review.md) |
| Performance, project experience and release | [Performance/PPA report](architecture/PERFORMANCE_PPA_REPORT_ZH.md) · [Project experience](architecture/PROJECT_EXPERIENCE_ZH.md) · [Public release guide](PUBLIC_RELEASE.md) |
| RTL learning and safe refactoring | [RTL guide](RTL_GUIDE.md) |

Detailed dated A10 run records remain under `verification/` as historical
evidence. Use the RTM for current workstream status instead of treating an old
run snapshot as the latest result.

## Common verification entry points

Run from the repository root unless the command specifies another directory.

| Scope | Command |
|---|---|
| Five compute verification groups | `make -C dv/subsystem/tensor_datapath/sim cluster_regress` |
| Top smoke | `make -C dv/subsystem/top_smoke/sim ai_smoke` |
| Seeded top regression | `make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345` |
| Control UVM | `make -C dv/block/control/sim uvm_regress` |
| DMA UVM | `make -C dv/block/dma/sim uvm_regress` |
| SpyGlass | `cd dv/spyglass && ./run_spyglass_a8.sh all` |

Check tool availability and use the command's recorded output directory before
starting a long run. Keep generated simulator, coverage, and EDA output outside
the source tree.
