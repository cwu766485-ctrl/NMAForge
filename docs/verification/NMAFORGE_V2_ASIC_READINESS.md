# NMAForge v2 ASIC Readiness

**Review date:** 2026-11-05  
**R250 baseline:** `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Latest RTL/test candidate replayed:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7`
**Disposition:** **NOT ASIC READY**; v1.0 remains **HOLD**.

## Current evidence

| Area | Current result | Sign-off meaning |
|---|---|---|
| Shared compute resources | v2 retains the existing 16×16, 256-INT8-MAC Matrix array. Opcode `0x52` reuses the existing operand/cache resources; `0x53` adds a bounded 512 B two-bank forwarding store. | RTL architecture evidence only; no mapped area cost. |
| Scratchpad | 512 KiB logical capacity, four banks; current v2 functional evidence uses behavioral RAM models. | No v2 SRAM macro mapping, macro timing, or physical bank implementation evidence. |
| Digits model utilization | Matched R250/v2 RTL run reports 6.68%→21.17% estimated array utilization over the top-level CMDQ cycle interval. | Simulation-derived workload metric, not silicon utilization or timing. See [model report](../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md). |
| SpyGlass lint | V-2023.12-SP1, current candidate and complete listed RTL: 0 errors, 465 warnings, 5 infos. | Tool run completed; warning review/waivers and lint sign-off remain open. No waiver was added. |
| SpyGlass structural CDC | Setup: 0 errors, 1 warning, 9 infos. Structural check: 0 errors, 2 warnings, 37 infos; 0 unsynchronized clock crossings and 0 convergence reports. | Partial structural evidence only. `Reset_sync04` and `FLAT_504` remain open; advanced/full CDC closure is not claimed. |
| SpyGlass RDC | 180 s bounded run stopped during `Ar_resetcross01`; shell returned timeout status 124. | **NOT_RUN**; no RDC conclusion. |
| Matrix FSM formal guards | VC Formal V-2023.12-SP2: 5/5 assertions proven and non-vacuous, 2/2 reachability covers hit. | PASS for the named Matrix guard properties only; not LEC or full `0x52`/`0x53` proof. |
| LEC | No Base-vs-v2 equivalence run in this review. | **NOT_RUN**. |
| DC Base-vs-v2 synthesis | Design Compiler V-2023.12-SP1 executable responds, but the public worktree has no DC run script and no standard-cell/SRAM views are configured (`TSMC28_STDCELL_DB` and `TSMC28_SRAM_DB` unset). Private collateral is excluded by `syn/README.md`. | **BLOCKED_ENV**; area, Fmax and power delta are not available. |
| SRAM mapping | No current-v2 macro adapter, Liberty/LEF, or SRAM timing view available. | **NOT_RUN**. |
| DFT | No current-v2 scan, ATPG, MBIST, or test-mode report was run. | **NOT_RUN**. |
| Physical PPA / power | No placement, CTS, routed parasitics, IR/EM, or workload-annotated current-v2 power run. | **NOT_RUN**. No ASIC performance or power claim. |

## Tool runs and evidence

### SpyGlass lint

Exact command, from `dv/spyglass`:

```sh
PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH \
  bash ./run_spyglass_a8.sh lint
```

Run completed with SpyGlass exit code 0 and summary `0 errors, 465 warnings,
5 infos`. The warning count is not closure. The current project now reads the
Matrix array, parallel dispatcher, and compute SPAD mux sources; these were
present in `a8_rtl.f` but omitted from `a8_static.prj`, which caused the first
candidate attempt to report unsynthesized/black-box errors. The project-only
`mthresh` was adjusted to 16385 to admit the 16384-bit Matrix accumulator
while retaining the 256-word-per-bank lint override. Product RTL defaults and
SPAD capacity are unchanged. No lint rule or warning was waived.

The rerun log is under
`dv/spyglass/a8_static/ai_accel_top/lint/lint_rtl/spyglass.log`; summary report
is `dv/spyglass/a8_static/ai_accel_top/lint/lint_rtl/spyglass_reports/moresimple.rpt`.
Generated databases and reports remain ignored local output.

### Structural CDC and RDC

Exact CDC command, from `dv/spyglass`:

```sh
PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH \
  bash ./run_spyglass_a8.sh cdc
```

The remaining structural warnings are:

- `Reset_sync04` at `rtl/top/fabric/compute/ai_compute_spad_mux.v:103`: the
  asynchronous top reset is synchronized in multiple `aclk` state paths.
- `FLAT_504` at `rtl/compute/matrix/ai_tensor_matrix_core.v:490`: the CDC
  evaluator partially evaluates a 16384-bit logic input above its 1024-bit
  threshold. It is a model-analysis precision warning, not a resolved waiver.

The bounded RDC command was:

```sh
timeout -k 5s 180s env \
  PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH \
  bash ./run_spyglass_a8.sh rdc
```

It reached `Ar_resetcross01` and exceeded 180 seconds. Raw redirected output is
`/tmp/nmaforge_v2_rdc_33e8528.log`. No RDC report was completed.

### Formal guard properties

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_v2_matrix_fsm_formal_33e8528
```

VC Formal V-2023.12-SP2 completed with 5/5 Matrix FSM assertions proven,
5/5 non-vacuous, and both named reachability covers hit. The covered states
include prefetch wait and error drain. This is not proof of every FSM
transition, descriptor contract, equivalence to R250, or full Compute Cluster
correctness. Raw log: `/tmp/nmaforge_v2_matrix_fsm_formal_33e8528/vc_formal.log`.

## PPA and storage boundary

The sanitized [TSMC28 synthesis report](TSMC28_SYNTHESIS_REPORT.md) is
historical pre-layout evidence for its documented RTL/configuration. It is not
a v2 result. `syn/README.md` confirms that the public repository excludes the
foundry libraries, SRAM views, macro wrappers, DC setup and generated reports.
The current workspace has no DC flow script at the path listed in the supplied
project instructions, so the Base-vs-v2 synthesis run could not be reproduced.

Known architectural storage facts are limited to RTL declarations:

- Matrix: the existing shared 16×16/256-MAC array; no second array was added.
- GEMV: existing 1 KiB reuse array is reused for bounded B-fold caching, with
  cache-valid/control state; no separate 256-MAC GEMV datapath was added.
- Tile forwarding: 2 × 16 × 16 B = 512 B local storage plus control/tag state.
- Scratchpad: existing 512 KiB logical organization across four banks.

No synthesis area is available for those additions. No capacity sweep, SRAM
macro mapping, measured Fmax, activity-based power, or energy/inference result
was run. The 10 ns simulation clock and any 250 MHz normalization are not
ASIC timing evidence.

## Remaining gates

1. Review the 465 lint warnings, including v2 Matrix width/boolean/FSM-style
   messages and the unused capture marker; add only narrow, reviewed waivers.
2. Close or formally disposition `Reset_sync04`; rerun CDC after any reset
   change. Resolve the structural evaluator's `FLAT_504` precision limitation.
3. Run RDC to completion with a supported reset-check configuration; then
   execute full RTL-vs-gate LEC and current-v2 formal requirements.
4. Restore approved private standard-cell/SRAM views, macro adapter, SDC and
   DC script. Run Base-vs-v2 synthesis on identical constraints, then compare
   area, Fmax and activity-annotated power.
5. Complete SRAM mapping, scan/ATPG/MBIST planning, physical implementation,
   routed STA, IR/EM and workload power before any testchip/tapeout decision.

Until these results exist, NMAForge v2 is an RTL architecture candidate, not
an ASIC-ready or tapeout-ready design.

## Candidate replay status at `410b81d` — 2026-11-05

VCS and URG became available for the fixed candidate and completed the
functional regressions listed in the [v2 DV report](NMAFORGE_V2_DV_CLOSURE.md).
That environment change does not provide the private standard-cell library,
SRAM timing/macro views, DC constraints, or implementation flow needed for
ASIC evidence. No new SpyGlass lint/CDC/RDC, DC, LEC, macro mapping, or
physical-design run was executed at this candidate in this increment; the
465-warning lint inventory and other static-analysis results above remain
bound to their recorded historical tool/configuration runs.

| Readiness item | Current disposition |
|---|---|
| Functional simulation | Scoped candidate replay PASS; v2 sign-off remains IN PROGRESS. |
| SpyGlass warnings / CDC / RDC | NOT_RERUN at `410b81d`; historical warning and structural findings remain OPEN. |
| Formal / LEC | NOT_RERUN; older Matrix FSM proof does not establish whole-design equivalence or v2 closure. |
| DC area / Fmax / power | NOT_RUN at `410b81d`; no measured ASIC PPA. |
| SRAM mapping and capacity study | NOT_RUN; behavioral four-bank SRAM remains the performance-model boundary. |
| DFT, MBIST, CTS, route, routed STA, IR/EM | NOT_RUN; required before any tapeout-readiness claim. |

The current candidate still uses one 16×16/256-MAC array, existing
four-bank/512-KiB logical SPAD, 1-KiB bounded reuse array and 512-B forwarding
store. These are RTL-declared sizes, not mapped silicon costs. VCS timing and
the 250-MHz normalization are not physical timing evidence. Disposition stays
**NOT ASIC READY**.
