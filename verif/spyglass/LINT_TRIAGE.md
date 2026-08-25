# NMAForge SpyGlass lint triage

## Run record

- Date: 2026-08-10
- Command: `./run_spyglass_a8.sh lint`
- Top: `ai_accel_top`
- Result: process exit code 0; 0 error, 414 warnings, 4 infos.
- Report: `a8_static/consolidated_reports/ai_accel_top_lint_lint_rtl/moresimple.rpt`

The policy summary counts some underlying coding-style findings in more than
one rule group.  The consolidated `moresimple.rpt` contains 214 finding rows.
No waiver has been applied.

## Disposition

| Finding | Count | Disposition | Required action |
|---|---:|---|---|
| `MatchFuncArgWidth` in `ai_tensor_sfu_core.v:408` | 1 | P0 fix | Make the gamma-scaled intermediate explicitly signed 64-bit before passing it to `clamp_i32`; add a directed negative/positive saturation test. |
| `AsyncResetOtherUse` involving `resetn` and DMA | 1 | P1 classify | Do not add a reset synchronizer blindly.  First document the IP reset contract and run CDC/RDC; either constrain synchronous deassertion at integration or implement an explicit synchronizer at the reset boundary. |
| `InitValUsingNBA` | 180 | P2 review/targeted cleanup | Mostly emitted because state/register defaults and updates share sequential processes.  Audit DMA, command processor and register file first; only refactor a signal if two assignments can occur in one functional path. |
| `SepStateNextLogic` | 20 | Coding-style waiver candidate | Existing one-process FSMs are synthesizable.  Do not mass-convert them during verification bring-up; document the project coding rule or refactor one block at a time with regression. |
| `WRN_1024` on `$signed` of already signed values | 11 | P2 cleanup | Remove redundant casts only when accompanied by fixed-point reference and directed regression; no intended arithmetic change. |
| `WarnAnalyzeBBox` on private SRAM macro adapter | 1 | Expected in private flow | The public profile does not include the adapter. In a licensed private flow, keep the waiver narrow and tied to the adapter instance. |

## Lint acceptance gate

The current run proves that active A8 RTL elaborates and all enabled lint rules
complete.  It is **not** lint closure.  Closure requires: zero errors, P0/P1
items fixed or formally dispositioned, every remaining warning placed in a
narrow reviewed waiver or an accepted project coding-policy bucket, and a
repeat run with the same source list.
