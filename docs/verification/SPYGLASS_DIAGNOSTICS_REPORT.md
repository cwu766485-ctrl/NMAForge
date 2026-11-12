# SpyGlass Errors and Warnings

**Review date:** 2026-11-12

**Available SpyGlass run:** 2026-10-20, SpyGlass `V-2023.12-SP1`, top `ai_accel_top`; lint analysis overrides `SPAD_WORDS_PER_BANK=256` to avoid elaborating the full behavioral SRAM. The current worktree is newer than this analysis snapshot, so these diagnostics are the latest archived run, not a run against checkout `3ec0be5`.

## Summary

| Goal | Fatal | Error | Warning | Info | Result |
|---|---:|---:|---:|---:|---|
| `lint/lint_rtl` | 0 | 0 | 305 | 4 | Tool exit 0; warning closure remains open |
| `cdc/cdc_setup` | 0 | 0 | 0 | 9 | Setup completed |
| `cdc/cdc_verify_struct` | 0 | 0 | 1 | 37 | One `Reset_sync04`; structural crossings and convergence reported as 0 |
| `rdc/rdc_verify_struct` | - | - | - | - | Run stalled at `Ar_resetcross01` and was terminated; no RDC report/result |

The lint report contains 309 generated messages: 305 warnings and four infos, with no waived or over-limit messages. The full individual lint diagnostics are in the generated SpyGlass report [`moresimple.rpt`](../../dv/spyglass/a8_static/consolidated_reports/ai_accel_top_lint_lint_rtl/moresimple.rpt). The full CDC structural report and the reset warning are in [`CDC-report.rpt`](../../dv/spyglass/a8_static/consolidated_reports/ai_accel_top_cdc_cdc_verify_struct/CDC-report.rpt) and [`moresimple.rpt`](../../dv/spyglass/a8_static/consolidated_reports/ai_accel_top_cdc_cdc_verify_struct/moresimple.rpt). The following table lists every lint warning by rule and count; the linked raw report gives each occurrence's RTL path, line, hierarchy and message.

## All lint warnings by rule

| Rule | Count | RTL area / diagnostic meaning |
|---|---:|---|
| `STARC05-2.2.3.3 InitValUsingNBA` | 124 | Sequential blocks combine default/nonblocking assignment and conditional updates; review assignment priority and exclusivity per occurrence. |
| `W415a` | 124 | A signal is assigned multiple times in one `always` block. Occurrences span sequential control paths; inspect each signal and branch priority. |
| `W287b` | 27 | Instance output is unconnected. Confirm intentional unused/reserved output versus missed integration. |
| `STARC05-2.11.3.1 SepStateNextLogic` | 20 | Single-process FSM coding style. |
| `W528` | 8 | Assigned but unread variable; check dead logic or intentionally retained interface/state. |
| `STARC05-1.3.1.3 AsyncResetOtherUse` | 1 | DMA reset-use classification; review with reset contract and CDC/RDC evidence. |
| `W240` | 1 | Behavioral scratchpad `resetn` is unused; memory array does not reset. |
| **Total** | **305** |  |

There are no `MatchFuncArgWidth` warnings in this run; the earlier two occurrences were removed by the recorded zero-extension fix. `W415a` and `InitValUsingNBA` counts are reported independently by SpyGlass and can refer to overlapping coding patterns; do not sum them as unique RTL statements.

## CDC/RDC diagnostics

The CDC structural report has one warning:

| Rule | RTL location | Diagnostic |
|---|---|---|
| `Reset_sync04` | `rtl/memory/ai_spad_arbiter.v:170` | `ai_accel_top.aresetn` is synchronized at least twice relative to `ai_accel_top.aclk`, at `spad_arbiter_u.accept_is_line_d` and `spad_arbiter_u.accept_error_d`. |

Basic structural results report one clock (`aclk`), one asynchronous active-low reset (`aresetn`), zero unsynchronized crossings and zero convergence. Advanced CDC rules were not run due to license availability. RDC stopped without a result, so it has neither pass nor fail status. These results do not establish CDC/RDC sign-off.

## Reproduction and evidence boundary

Archived commands, run environment and analysis limitations are recorded in [Static Analysis Report](STATIC_ANALYSIS_REPORT.md) and [Lint Triage](../../dv/spyglass/LINT_TRIAGE.md). The raw `moresimple.rpt` is the exhaustive occurrence list: it includes diagnostic ID, rule, severity, source file, source line, message, and hierarchy for every warning. No SpyGlass run was started for this report, and no generated SpyGlass database or report was modified.
