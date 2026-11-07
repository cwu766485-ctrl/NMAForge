# NMAForge v2 Round 7 — Synthesis and Research Decision

**Reviewed base:** `7b6cd8206dfffae3f5e371c83c501d0edb3664ea`
**Target branch:** `feature/npu-architecture-v2`
**Round 7 product RTL changes:** none
**Tool:** Synopsys Design Compiler V-2023.12-SP1
**Run date:** 2026-11-07

## Decision summary

Round 7 restored a valid licensed DC mapping flow and produced an actual 16×16
Matrix Array mapped netlist. The standalone Array maps at 124,704.412 library
area units / 137,928 leaf cells. It meets the current 250 MHz / 4.0 ns
pre-layout constraint by only +0.01 ns, fails 300 MHz by −0.66 ns, and fails
400 MHz by −1.49 ns. Its path is a combinational result select plus
post-processing path from `result_index` to `selected_result`. This is not a
full Matrix Core or Compute Cluster PPA result and does not include SRAM
macros, placement or parasitics.

The first bounded 16×16 Matrix Core attempt ended at the 3,600 s timeout; the
interactive tool reported exit 124 and 7.65 GB peak RSS, but a shell-wrapper
error caused the stored console to contain only a command-not-found message
and left no retained DC report. A later run reached mapping with an invalid
operating-condition name (`tt0p9v25c`), reported that the library had no
inverter, and emitted a gtech-only netlist with 0 area and unmapped logic; it
was stopped and is rejected as invalid synthesis. The exact TT condition was
identified as `tt0p9v0p9v25c`; however, the follow-up 8×8 configuration probe
was refused by the license manager (DC exit 255), so a correct-corner Core
retry was not completed. The corrected runner now validates the requested
operating condition and rejects zero-area/unmapped output. The historical
full-top 512 KiB report has no retained source SHA, netlist, exact SDC or raw
report archive and cannot be reproduced from the released tree. Details are
in the [historical/current synthesis audit](../verification/OLD_VS_NEW_SYNTHESIS_AUDIT.md).

Innovation 1 shows useful gains for batched M=8/16 Matrix-core GEMV when
B-fold Cache is enabled, but the H=4 single-token Transformer Decode showed
no cycle reduction. Innovation 2 now has a three-rung ablation: Legacy,
fused requant with native Matrix-A layout, and fused requant with Linear-Row
output. All three paths match independent Goldens on `conv1x_mini.onnx` and
396 held-out Digits samples. The separate phases show the fused compute-path
effect and the consumer-ready layout effect. For the trained ten-class CNN,
Legacy→fused-native reduces CMDQ cycles from 3,193 to 2,712 (1.177×) and the
phase interval from 4,273 to 3,792 (1.127×); fused-native→Linear-Row removes
the 1,080-cycle layout phase and reduces interval cycles to 2,712 (1.398×).
The combined Legacy→Linear-Row interval is 1.576×. These are behavioral-SPAD
Top results, not silicon or cross-system TinyNPU speedups. Machine data is in
[`v2_round7_cnn_fused_modes_20261107.csv`](../../benchmark/v2_round7_cnn_fused_modes_20261107.csv).

## Baseline audit and source identity

Round 7 began from source/test HEAD `7b6cd8206dfffae3f5e371c83c501d0edb3664ea`.
The current tested source contains the Round 6 corrected GEMV weight packing;
the relevant Mapper, RTL and Top test files are unchanged from the source
snapshot bound by the Round 6 exact Golden results. Round 7 changed no product
RTL. The 8×8 and 16×16 standalone synthesis runs are bound to source SHA
`7b6cd8206dfffae3f5e371c83c501d0edb3664ea` by their run manifests.

The old full-top report was generated under TT / 0.9 V / 25 °C at 4.0 ns,
with four logical SPAD banks backed by 32 single-port macros (512 KiB). It
does not identify its exact RTL SHA or retain the mapped database and raw
timing report. The current Array run is separately bound to Round 7 source,
but maps no SRAM and is not equivalent to that old top-level design.

## ASIC synthesis evidence

| Design/run | Area | Leaf cells | Critical path | @250 MHz | @300 MHz | @400 MHz | Scope |
|---|---:|---:|---:|---:|---:|---:|---|
| 8×8 Array, `R7-ARRAY-8-medium-4.0` | 31,809.330 area units | 35,098 | 3.37 ns | +0.03 ns | NOT_RUN | NOT_RUN | Diagnostic only; first run used 100 ps hold uncertainty and reported 1,280 hold violations |
| 16×16 Array, `R7-ARRAY-16-medium-4.0` | 124,704.412 area units | 137,928 | 3.39 ns | +0.01 ns | −0.66 ns | −1.49 ns | Real medium-effort mapped Array; 0 macros; zero-wireload/pre-layout |
| 16×16 Matrix Core, `R7-ai_tensor_matrix_core-16-medium-4.0` | INVALID / 0 mapped area | — | — | — | — | — | Wrong opcond; gtech-only, unmapped output rejected |
| Full Compute Cluster | NOT_RUN | — | — | — | — | — | Current banked SPAD/macro adapter equivalence is not established |

The Array mapping compiled against the licensed TT / 0.9 V / 25 °C RVT
library, with 100 ps setup and 20 ps hold uncertainty, 50 ps clock
transition, 250/50 ps IO delays, 20 fF output load, and 0.20 ns max
transition. The mapped netlist was evaluated at 4.0, 3.333333, 2.5 and
2.222222 ns; only the 4.0 ns mapping was optimized at synthesis. There were
no false-path or multicycle exceptions. The estimated 7.714 mW vectorless
power used static input probability 0.5 / toggle 0.1; it is not workload
power. Design Compiler area units are left in native library units.

The worst 400 MHz setup path starts at `result_index[2]` and ends at
`selected_result[21]`, through result selection and output post-processing.
At a 2.5 ns clock, constrained arrival is 3.64 ns versus 2.15 ns required
(−1.49 ns slack). The reciprocal of the 3.39 ns critical path is about
295 MHz; treat this only as an indicative standalone pre-layout estimate.
The machine-readable top 20 paths are in
[`v2_round7_matrix_array_worst20_400mhz.csv`](../../benchmark/v2_round7_matrix_array_worst20_400mhz.csv).
No false-path or multicycle exception was used.

### 128 KiB SRAM

The nominal capacity organization remains eight 4K×32 (16 KiB) single-port
macros, with a previously recorded LEF geometry sum of approximately
0.281919 mm². This is geometry arithmetic only. The current behavioral SPAD
exposes independent host and scheduler accesses, registered responses,
byte enables and parity/protection behavior. The retired adapter predates
some of these semantics and ties parity errors inactive. No compatible
adapter was restored, integrated or differentially verified in this round;
there is no 128 KiB macro-mapped area/timing/power result.

## Innovation 1 — Shape-Adaptive GEMV

### Transformer single-token result

The fixed trained INT8 Transformer fixture is H=4, one layer, one head,
640 useful MACs, 86 descriptors and one Decode row (M=1). Round 6 ran both
default GEMM (`0x30`) and Q/K/V GEMV (`0x52`) at the same Mapper/RTL/test
snapshot, seed `20261106`, with independent final output and KV-cache Golden.

| Mapping | Prefill | Decode | Total | Decode reads/writes | Golden |
|---|---:|---:|---:|---:|---|
| GEMM default | 5,682 | 5,715 | 11,397 | 1,880 / 1,048 B | PASS |
| Q/K/V `0x52` | 5,682 | 5,715 | 11,397 | 2,024 / 904 B | PASS |

M=1 Decode has zero cycle gain: GEMV trades 144 more read bytes for 144
fewer write bytes. B-fold reuse primarily helps batched M>1 and does not
accelerate this H=4 single-token path. A reproducible H=16 trained model was
not available in the current fixed H=4 trainer/Mapper; **NOT_RUN** rather
than extrapolated from the toy fixture.

### Batched GEMV Cache × Prefetch ablation

The fixed 16×16 Array/Matrix-core workload uses four legal shapes and the
registered four-bank behavioral SPAD. Data below is from the exact Round 6
single-seed result set with run-ID prefix
`V2-GEMV-FOUR-WAY-S20261106-*` (seed `20261106`); all four
configurations check bit-exact Golden. It measures a Matrix-core GEMV
command, not Transformer end-to-end latency.

| Shape | Cache/PF OFF cycles | Cache ON/PF OFF | Cache ON/PF ON | Cache read bytes OFF → ON | OFF→Cache cycles |
|---|---:|---:|---:|---:|---:|
| 8×16×19 | 197 | 147 | 148 | 864 → 560 | −25.4% |
| 8×16×65 | 544 | 398 | 381 | 2,720 → 1,696 | −26.8% |
| 16×16×19 | 391 | 270 | 265 | 1,728 → 816 | −30.9% |
| 16×16×65 | 1,071 | 627 | 629 | 5,440 → 2,368 | −41.5% |

Cache reduced B-read traffic by 35.2–56.5%. Cache plus prefetch adds shape
dependence: it helps the two M=8 cases and 16×16×19 slightly, but is two
cycles slower than Cache alone for 16×16×65. Single-seed workload-window
useful MAC/cycle ranges from about 16.5 to 26.5 with Cache+Prefetch; this is
low Array utilization and not a claim of model-level Transformer speedup.
Machine data: [`v2_round6_gemv_four_way_20261106.csv`](../../benchmark/v2_round6_gemv_four_way_20261106.csv).

## Innovation 2 — Fused Epilogue and Dataflow

The same `conv1x_mini.onnx`, inputs and independent Golden pass on both
NMAForge paths. Legacy measured 1,985 CMDQ compute cycles plus 1,080
testbench-emulated Host Layout cycles (3,065 reported phase cycles); fused
`0x53` Linear-Row measured 1,504 CMDQ cycles and no Host Layout. The RTL
outputs are bit-exact; the fused path measured 2,784 B SPAD reads / 1,456 B
writes. This comparison includes a different descriptor graph and output
layout, and its phase totals are not a common full-system endpoint. It is
model-level evidence for the fused + consumer-ready layout combination, not
an isolated requant-only result.

The trained ten-class CNN has 396/396 exact Top Golden runs in all three
tested modes. Legacy → fused requant with native Matrix-A layout reduces
CMDQ cycles from 3,193 to 2,712 per image (15.1% fewer), while retaining the
same 1,080-cycle testbench-emulated layout phase. The Linear-Row descriptor
then removes that phase; classification remains 384/396 in all modes.
Directed Tile Forwarding core evidence saves 23 cycles (288→265
producer+consumer) on its fixed microcase; this is not a full CNN model-level
forwarding measurement.

## TinyNPU comparison boundary

TinyNPU remains fixed at `8216c22b762011aa20c05fc2768423fd12dda59d`.
Round 6 same-operand INT8 GEMM Golden results compare NMAForge Top Controller
+ behavioral SPAD against TinyNPU Direct Array RTL and a separate serialized
16 B/cycle TinyNPU memory-service estimate. The estimated endpoint is not a
TinyNPU system RTL measurement, so no system-level speedup is claimed. On the
common mini CNN, both outputs match Golden, but NMAForge's CMDQ interval
excludes preload/descriptor programming/final host read while TinyNPU's 4,781
cycles include its graph dispatch and DMA/SRAM shim. These are separately
reported raw endpoints, not a fair cross-system speedup. Existing paired
data and precise boundaries are in the [Round 6 performance report](NMAFORGE_V2_PERFORMANCE_COMPARISON.md)
and machine-readable [CNN CSV](../../benchmark/v2_round6_cnn_legacy_linearized_20261107.csv).

## Open items and disposition

| Item | Status | Evidence / reason |
|---|---|---|
| Historical 512 KiB source-bound replay | PARTIAL | Old report has no exact SHA, netlist, exact SDC or raw reports |
| Current 16×16 Array mapping | PASS at 250 MHz only; FAIL at 300/400 MHz | Valid mapped netlist and timing reports exist; 300/400 fail under stated constraints |
| Current Matrix Core mapping | PARTIAL / NOT VALID | First run timed out with wrapper log failure; second used invalid opcond and produced gtech/zero-area output; corrected-corner probe hit license refusal |
| Full Compute Cluster mapping | NOT_RUN | No proven current SRAM macro adapter / semantic equivalence |
| 128 KiB macro adapter | NOT_RUN | Port, latency, byte enable and parity contract not implemented/verified |
| H=16 trained Transformer Decode | NOT_RUN | Existing reproducible trainer is H=4; no claim inferred from H=4 |
| GEMV model-level latency gain | No gain observed | H=4/M=1 Decode is cycle-neutral; batched GEMV gains are command-level |
| CNN three-rung dataflow ablation | PASS | Legacy, fused requant with native layout, and fused requant + Linear-Row all passed 396/396 exact intermediate/output checks |
| Complete physical PPA | NOT_RUN | No placement, extracted RC, CTS, routed STA or workload SAIF |

No Round 7 product RTL was changed. The bounded experiment does not establish
400 MHz closure, mapped Matrix Core/Compute Cluster area, Compute Cluster
tapeout readiness, or system-level TinyNPU superiority.

## CNN three-mode replay and exact measurement limits

At product RTL SHA `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, Top testbench
SHA `7e64344fbb9bdaed0fd4ce14e8cddb19231827f7`, dataset runner SHA
`30ef28b973343acd25ebd62d4df8576c84e8ffb1`, and VCS
`V-2023.12-SP1_Full64`, all three modes passed independent Golden checks on
seed `20261107`:

| Workload | Mode | Useful MACs | CMDQ cycles | Host-layout cycles | Total recorded interval | Effective MAC/CMDQ cycle | Read / write bytes |
|---|---|---:|---:|---:|---:|---:|---:|
| `conv1x_mini.onnx` (4 outputs) | Legacy | 1,872 | 1,985 | 1,080 | 3,065 | 0.943 | 3,504 / 2,176 |
| same | Fused requant, native layout | 1,872 | 1,504 | 1,080 | 2,584 | 1.245 | 2,928 / 1,600 |
| same | Fused requant + Linear-Row | 1,872 | 1,504 | 0 | 1,504 | 1.245 | 2,784 / 1,456 |
| Trained 10-class CNN (per image) | Legacy | 2,736 | 3,193 | 1,080 | 4,273 | 0.857 | 6,192 / 2,496 |
| same | Fused requant, native layout | 2,736 | 2,712 | 1,080 | 3,792 | 1.009 | 5,616 / 1,920 |
| same | Fused requant + Linear-Row | 2,736 | 2,712 | 0 | 2,712 | 1.009 | 5,472 / 1,776 |

All 396 ten-class samples match every checked intermediate and output Golden;
each mode classifies 384/396 (96.97%). The 1,080 host-layout cycles represent
the Top testbench's explicit AXI layout phase, not measured host CPU time.
Preload, descriptor setup, final output read and external DDR service are not
in this interval. The effective MAC rate is useful MACs divided by CMDQ
compute cycles, not a PE-active utilization figure. The mini-CNN result uses
the same fixed `conv1x_mini` operands and TinyNPU compiler Golden; TinyNPU's
4,781 graph cycles still have a different endpoint, so no ratio is valid.

Machine-readable rows and hashes are in
[`v2_round7_cnn_fused_modes_20261107.csv`](../../benchmark/v2_round7_cnn_fused_modes_20261107.csv).
The run logs and 396-sample output tables remain outside Git in the listed
`/tmp/nmaforge_round7_*_s20261107` directories.

## Synthesis runner validation disposition

The valid standalone Array run was `R7-ai_tensor_matrix_array-16-medium-4.0`
at source/test SHA `7b6cd8206dfffae3f5e371c83c501d0edb3664ea`, on a 18-logical-
CPU Intel Core Ultra 5 125H host with two DC cores. It ran from 08:18:28 to
08:34:43 UTC (16m15s); the captured `/usr/bin/time -v` record reports 1,044 s
CPU time and 2.205 GB peak RSS. Exact corrected-flow invocation (private DB
supplied through local environment):

```sh
NMAFORGE_R7_RUN_ROOT=/tmp/nmaforge_round7_synth_a3 \
NMAFORGE_R7_TIMEOUT_S=3600 \
syn/run_round7_matrix_synth.sh 16 4.0 medium ai_tensor_matrix_array
```

The setup wrapper now defaults to the actual TT condition `tt0p9v0p9v25c`,
records the runner/Tcl SHA-256 and selected condition, and rejects a zero-area
or unmapped result even when DC exits zero. `bash -n` and `git diff --check`
pass. A 600 s 8×8 check with the corrected condition failed before elaboration
because the license manager returned `Fatal: Design Compiler is not enabled`
(wrapper status 255); another user's already-running DC process was left
untouched. No current Matrix Core/Cluster area is claimed.

The successful Array run's manifest binds the RTL snapshot and environment but
predates runner/Tcl hash fields; the exact runner revision used for that run
cannot be recovered from the manifest. Current checked-in replay-script hashes
are `e5b0b3697649c8fcf7d6f2a272ee36388fe4114e731117f216594391ef56fcf3`
(runner) and `271f800b1a6294dde96e6c98153f5e08a69c7d5fdb74567de8088e678481c35a`
(Tcl). They provide a reproducible rerun path, not retroactive proof of the
script bytes used for the earlier mapping.

The current-runner retry command for the Core is:

```sh
NMAFORGE_R7_RUN_ROOT=/tmp/nmaforge_round7_core \
NMAFORGE_R7_TIMEOUT_S=3600 \
syn/run_round7_matrix_synth.sh 16 4.0 medium ai_tensor_matrix_core
```

It requires the private TT `.db` and setup variables locally. Do not infer a
successful Core map from the prior 0-area gtech file.
