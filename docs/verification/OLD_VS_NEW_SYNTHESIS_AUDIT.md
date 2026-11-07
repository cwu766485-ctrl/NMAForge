# Historical vs. Round 7 Synthesis Audit

**Audit date:** 2026-11-07  
**Round 7 source:** `7b6cd8206dfffae3f5e371c83c501d0edb3664ea`  
**Published branch:** `feature/npu-architecture-v2`  
**Scope:** recover what the historical 512 KiB synthesis report actually proves, then compare it with a current standalone 16×16 Matrix Array mapping. This is pre-layout Design Compiler evidence, not sign-off PPA.

## Historical 512 KiB result

The public `docs/verification/TSMC28_SYNTHESIS_REPORT.md` records an `ai_accel_top` synthesis at TT / 0.9 V / 25 °C with a 4.0 ns clock target, 100 ps setup uncertainty, 20 ps hold guard, and 32 single-port scratchpad SRAM macros (512 KiB total). The report describes zero setup/hold WNS and TNS, a total reported cell area of 1,245,378.649905 library area units, 138,332 leaf cells, and 1,127,675.75 SRAM macro area units. It is explicitly pre-layout.

The report does **not** bind those metrics to an exact source SHA or an archived run ID. Git history contains a detailed predecessor report and the then-private macro adapter / DC scripts, but the released worktrees do not contain the historical mapped netlist, exact SDC, raw DC timing/area reports, or a run archive. A nearby documentation commit is not sufficient evidence of the RTL identity used by the synthesis run. Therefore:

- Historical source SHA: **NOT RECOVERABLE from retained evidence**.
- Independent exact replay: **NOT REPRODUCIBLE from the public checkout**.
- Historical synthesis top: the report identifies `ai_accel_top`; the metric summary is for the integrated top and not a standalone Matrix Array.
- Historical memory: 32 single-port macros, reported as 512 KiB. The retired private adapter is not a drop-in implementation for the present scratchpad contract: its old read pipeline and port arbitration predate current protection/parity behavior, and parity error reporting is tied inactive.

The historical result remains useful as a documented pre-layout snapshot, but it cannot be used as a source-bound v1/v2 comparison or as proof of current 400 MHz timing.

## Current Round 7 standalone Array mapping

Run IDs and retained external evidence:

| Run | Configuration | Result directory |
|---|---|---|
| `R7-ARRAY-8-medium-4.0` | 8×8 diagnostic Array, medium mapping | `/tmp/nmaforge_round7_synth_a2/array_8_medium_4p0ns` |
| `R7-ARRAY-16-medium-4.0` | 16×16 Array, medium mapping | `/tmp/nmaforge_round7_synth_a3/array_16_medium_4p0ns` |
| `R7-ai_tensor_matrix_core-16-medium-4.0` | 16×16 Matrix Core, invalid-condition attempt | `/tmp/nmaforge_round7_core_a2/ai_tensor_matrix_core_16_medium_4p0ns` |
| Correct-corner 8×8 configuration probe | license refused before DC analysis | `/tmp/nmaforge_round7_array_cornercheck/ai_tensor_matrix_array_8_medium_4p0ns` |

Tool: Synopsys Design Compiler V-2023.12-SP1. The mapped run used the licensed local 28 nm RVT TT / 0.9 V / 25 °C setup, ideal clock network, segmented wire-load mode, no routed parasitics, and no SRAM macros. The runner applies 100 ps setup and 20 ps hold clock uncertainty, 50 ps clock transition, 250/50 ps input/output delay budgets, 20 fF output load, and max-transition/fanout constraints. `compile -map_effort medium` maps once at a 4.0 ns target; the saved mapped netlist is then re-evaluated at 4.0, 3.333333, 2.500000, and 2.222222 ns. The latter are post-map constraint sweeps, not separately optimized clock-target compiles.

### 16×16 mapped metrics

| Metric | Result |
|---|---:|
| Mapped standard-cell area | 124,704.412 library area units |
| Leaf cells | 137,928 |
| Combinational / sequential cells | 116,936 / 20,992 |
| Array state | 16,384 accumulator flops (256 × 64-bit), plus operand/result state |
| Macro cells | 0 |
| Critical path length | 3.39 ns (zero-wireload estimate) |
| Setup slack @ 250 MHz / 4.0 ns | +0.01 ns; 0 violating paths |
| Setup slack @ 300 MHz / 3.333333 ns | −0.66 ns; 3,361 violating paths; TNS −993.47 ns |
| Setup slack @ 400 MHz / 2.5 ns | −1.49 ns; 7,969 violating paths; TNS −5,764.27 ns |
| Setup slack @ 450 MHz / 2.222222 ns | −1.77 ns; 9,729 violating paths; TNS −8,229.02 ns |
| Vectorless power estimate | 7.714 mW total under static 0.5 / toggle 0.1 input assumptions; leakage 73.1 µW |

The worst path is `result_index[2]` to `selected_result[21]`, through the array result-selection and activation/saturation logic. It is a combinational input-to-output path; at 2.5 ns the constrained arrival is 3.64 ns against a 2.15 ns required time. This is an unplaced, zero-wireload library timing result. It demonstrates that this mapped Array netlist does not meet the requested 400 MHz timing under the stated IO budget. No false path or multicycle exception was used.

The 8×8 diagnostic mapped at 31,809.330 library area units with 35,098 leaf cells and a 3.37 ns critical path. That first diagnostic used 100 ps hold uncertainty and showed 1,280 violating hold paths (−0.04 ns worst); it is not a sign-off result and should not be directly compared to the 16×16 run, which uses 20 ps hold uncertainty.

### Evidence limits and next stage

- These are mapped logic metrics for the standalone Matrix Array only; they exclude Matrix Controller, Scratchpad, SPAD arbitration, clock-tree synthesis, placement, routing, extracted RC, and SRAM macros.
- Library area units are reported as emitted by DC; no mm² conversion is asserted.
- The vectorless power report is an estimate without workload SAIF and without routed parasitics.
- The Matrix Core has no accepted mapped result. The first attempt reached the 3,600 s wall limit (interactive status 124, reported peak RSS 7.65 GB), but the then-current timeout wrapper retained only a shell command-not-found message and no usable DC report. A later run used the wrong operating condition `tt0p9v25c`; the actual TT name in the `.db` is `tt0p9v0p9v25c`. DC reported `OPT-101` (target library does not contain an inverter); `area_hier.rpt` shows 0 area, gtech-only references, and unmapped logic. This emitted netlist is invalid and is not area/timing evidence.
- The runner was corrected to validate the operating-condition object, record runner/Tcl hashes, and reject zero-area/unmapped outputs. A short 8×8 correct-corner probe was refused before DC analysis with `Fatal: Design Compiler is not enabled` (exit 255), while another DC job was active and left untouched. A correct-corner Core rerun is therefore NOT_RUN / license-blocked; the Matrix Core remains PARTIAL.
- Current 400 MHz result: **FAIL for the standalone Array under the stated pre-layout timing model**. A pipeline change would alter observable result timing/handshake and needs a scoped architecture change plus Golden/handshake regression; no RTL change is included in this audit.

## Reproduction

The synthesis runner is parameterized and intentionally does not contain the private PDK path or library database. Supply the local setup script and NLDM database through environment variables; keep generated data outside Git:

```sh
TSMC28_ENV_SETUP=<private-setup-script> \
NMAFORGE_R7_STD_LIB=<private-standard-cell-nldm-db> \
NMAFORGE_R7_RUN_ROOT=/tmp/nmaforge_round7_synth \
syn/run_round7_matrix_synth.sh 16 4.0 medium ai_tensor_matrix_array
```

The run manifest records source SHA, tool version, PVT class, constraints, host, run time, and exit status. Do not check in the private library, setup environment, or generated DC directory.
