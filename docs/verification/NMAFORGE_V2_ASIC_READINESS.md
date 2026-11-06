# NMAForge v2 ASIC Readiness

## Final research baseline capacity disposition — 2026-11-06

The source/test SHA `9576e539c21fe6312763c4745a90dc032c6457e0` exercised two
compact-mapped CNN workloads at both 128 KiB and 512 KiB with the same four
banks, 128-bit line interface, and 256 INT8 MAC array. Both model outputs
were Golden-exact, and measured cycles/traffic were unchanged between the
two capacities. This is behavioral-SPAD simulation evidence, not physical
SRAM timing, macro area, power, or PPA evidence.

Current-map address high-water analysis: trained 10-class CNN 69,888 bytes;
`conv1x_mini` 69,760 bytes; legacy Digits MLP 351,232 bytes; fixed 86-descriptor
Transformer fixture 79,200 bytes. The two CNN models pass at 128 KiB. MLP and
Transformer capacity rows are static-only; their 128 KiB results are not run
claims. A 64 KiB capacity cannot hold the current compact CNN map, while 256
KiB was not separately simulated. Logical storage requirements remain 4,194,304,
2,097,152, 1,048,576, and 524,288 bits for 512/256/128/64 KiB respectively.

Machine records: [`capacity CSV`](../../benchmark/v2_spad_capacity_study_20261106.csv),
[`capacity JSON`](../../benchmark/v2_spad_capacity_study_20261106.json). DC,
SRAM macro mapping, timing, physical design, and power are `NOT_RUN` /
`BLOCKED_ENV`; foundry libraries, SRAM timing views, and implementation
constraints were not available in the repository environment. The project is
not Tapeout Ready.

## Bounded benchmark / storage update — 2026-11-06

This round does not pursue ASIC sign-off. No DC, SRAM macro mapping, PPA,
reduced-capacity RTL, or physical implementation run was performed. The
current status remains **NOT ASIC READY** / PPA **BLOCKED_ENV** as documented
below.

The only storage update is a source/address-based capacity assessment. Four
banks with 32-bit words per bank require these logical storage quantities:

| Total SPAD | Words per bank | Storage bits | Relative same-shape macro capacity |
|---:|---:|---:|---:|
| 512 KiB | 32,768 | 4,194,304 | 1× |
| 256 KiB | 16,384 | 2,097,152 | 1/2× |
| 128 KiB | 8,192 | 1,048,576 | 1/4× |
| 64 KiB | 4,096 | 524,288 | 1/8× |

These are logical bit counts and relative capacity only, not foundry macro
counts or area. Digits' current fixed map reaches 351,232 bytes and its
simultaneously initialized data objects total at least 79,776 bytes: it fits
only the 512 KiB option without remapping. A compact 128 KiB map fits that
static lower bound, while 64 KiB needs streaming/reuse. The mini-CNN's fixed
descriptor/completion map reaches 135,296 bytes: it fits 256/512 KiB, not
128/64 KiB. No remapping, data-preservation, cycle, bank-conflict, or <=5%
performance-degradation experiment was run. Machine table:
[`static capacity CSV`](../../benchmark/v2_spad_capacity_static_20261106.csv)
and [JSON](../../benchmark/v2_spad_capacity_static_20261106.json).

**Review date:** 2026-11-06
**R250 baseline:** `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Latest RTL/static-analysis candidate replayed:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7`
**Disposition:** **NOT ASIC READY**; v1.0 remains **HOLD**.

## Later DV-only provenance — 2026-11-06

Testbench-only SHA `85e7db2d12f5edfaed17e8ca3910bb504983779f` adds three-seed
real-CMDQ opcode-0x52 GEMV + CNM response-owner and Golden checks. It leaves
product RTL unchanged and does not update synthesis, timing, power, SRAM,
formal/LEC, or physical implementation evidence.

The earlier real-Top legal opcode `0x52` UVM regression at source/test SHA
`92874788fb2cb2a2b15657a3621e5a275a9d5990` adds M=N=K=16 maximum-tile
execution after the minimum and tail cases. The newer `85e7db2` testbench
replay adds a concurrent CNM response-owner cross. Both change testbench
stimulus/coverage only and leave product RTL unchanged. These VCS/URG PASSes do not update the
SpyGlass, formal/LEC, SRAM mapping, DC, physical PPA, or power evidence below.
Their existing `NOT_RUN` and `BLOCKED_ENV` dispositions remain in force; no
ASIC readiness or tapeout claim is made.

The latest targeted DV and matched Cluster serial/parallel replay is
`f19e92934cd6273d327621c43cb17291cf1a9aa5` (three-seed real-CMDQ `0x52`
read-only A/B alias checks and existing Cluster UVM benchmark workload); the
latest Matrix benchmark replay is `a4dcc6b609878811fcd48a0310401609d4952c62`.
These are testbench/report changes only. Product RTL remains at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, so neither changes the static RTL
or PPA result.

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
| DC Base-vs-v2 synthesis | Design Compiler `V-2023.12-SP1` is installed at `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`; the executable reports its version. The public worktree has no DC run script or `external/private` overlay, and `TSMC28_STDCELL_DB`, `TSMC28_SRAM_DB`, SRAM timing and SDC variables are unset. | **BLOCKED_ENV**; executable availability alone is insufficient; area, Fmax and power delta are not available. |
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
An environment probe on 2026-11-06 found DC `V-2023.12-SP1` at its installed
path, but the flow script listed in the project instructions is absent, the
private overlay is absent, and the required standard-cell, SRAM timing and SDC
environment entries are unset. Therefore the Base-vs-v2 synthesis run was not
attempted: it cannot produce an auditable result in this public workspace.

The probe checked `dc_shell -version`, executable and flow-script paths, the
`external/private` directory, and only the presence/path-existence state of
`TSMC28_STDCELL_DB`, `TSMC28_SRAM_DB`, `TSMC28_SRAM_TIMING`, `TSMC28_SDC`, and
`TSMC28_PRIVATE_OVERLAY`; no private path values or credentials were printed.
Result: DC installed; run inputs absent; PPA `BLOCKED_ENV`.

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

## Environment recheck — 2026-11-06

The project `eda.yaml` names `external/private` as the PDK root and the
private TSMC28 standard-cell database and SDC as synthesis inputs. The
read-only EDA check found Design Compiler installed at
`/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`; `dc_shell -version` reports
`V-2023.12-SP1`. `eda.py doctor` found the configured Synopsys executables.
`eda.py plan --flow synth --dry-run` generated a generic plan under ignored
`runs/`; it did not execute synthesis and is not PPA evidence.

The required `external/private` directory, `syn/run_ai_accel_28nm_dc.sh`,
TSMC28 standard-cell/SRAM/timing inputs, and configured SDC are absent in this
worktree. The environment probe reported only set/unset state for the private
input variables; their values were not recorded. No DC library read, synthesis,
or license checkout was attempted. Base-vs-v2 area/Fmax/power remains
**BLOCKED_ENV** because the design-specific implementation inputs are missing;
this is not a claim that the DC executable or license is unavailable.

The K=256 verification update at SHA `8758794` does not change the RTL or
existing PPA boundary. Its functional regression evidence is documented in
the [DV closure report](NMAFORGE_V2_DV_CLOSURE.md), not as synthesis evidence.

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

The functional regressions listed in the [v2 DV report](NMAFORGE_V2_DV_CLOSURE.md)
completed at this fixed source/test SHA. SpyGlass V-2023.12-SP1 was also run
against the checked-in A8 project with the analysis-only
`SPAD_WORDS_PER_BANK=256` override. The exact lint evidence snapshot is
`/tmp/nmaforge_v2_410b81_static_eda.tar.gz`, SHA-256
`178d3267e55304a0c173a9fc89facd547fb7926b516c3c672e1e9ed710dfab60`.

| Goal | Current-candidate result | Disposition |
|---|---|---|
| `lint/lint_rtl` | Exit 0; 0 errors, 465 warnings, 5 infos; 0 waived. | Execution PASS only; warning closure OPEN. |
| `cdc/cdc_setup` / `cdc/cdc_verify_struct` | The scripted `cdc` run produced no current report/output for 6m10s and was terminated (exit 143). | **NOT_RUN**; no current CDC PASS inferred. |
| `rdc/rdc_verify_struct` | 180s bounded run reached rule 385/478, `Ar_resetcross01`, at about 6.1 GB RSS; timeout exit 124; no final report. | **NOT_RUN**; timeout is not a pass. |
| Formal / LEC | Not rerun at `410b81d`. | **NOT_RUN**. The prior scoped Matrix FSM proof does not cover the whole v2 design. |
| DC area / Fmax / power | Not run. DC executable is present, but `external/private`, the configured SDC, and `syn/run_ai_accel_28nm_dc.sh` are absent. | **BLOCKED_ENV**; no PPA result. |
| SRAM macro mapping, DFT, MBIST, CTS, route, routed STA, IR/EM | Not run; private SRAM and physical views are absent. | **NOT_RUN/BLOCKED_ENV**. |

Exact current static commands from the repository root:

```sh
PATH="${SPYGLASS_HOME}/bin:${PATH}" bash dv/spyglass/run_spyglass_a8.sh lint
PATH="${SPYGLASS_HOME}/bin:${PATH}" bash dv/spyglass/run_spyglass_a8.sh cdc
timeout --signal=TERM --kill-after=10s 180s \
  env PATH="${SPYGLASS_HOME}/bin:${PATH}" \
  bash dv/spyglass/run_spyglass_a8.sh rdc
```

### Lint and reset finding disposition

The 465 warning rule counts are: `W415a` 160, `STARC05-2.2.3.3`
(`InitValUsingNBA`) 141, `W426` 56, `W287b` 27,
`STARC05-2.11.3.1` 22, `W528` 20, `STARC05-2.1.3.1` 11,
`STARC05-2.1.4.5` 11, `W240` 7, `W362` 6, and one each of
`STARC05-1.3.1.3`, `W216`, `W486`, and `FLAT_504`. `W415a` and
`InitValUsingNBA` can describe the same sequential assignments, so their
counts are not unique RTL defects. The warning report is included in the
snapshot; zero waivers were added.

The current lint `FLAT_504` at `ai_tensor_matrix_core.v:490` says a 16,384-bit
Matrix accumulator mux is only partially evaluated against the tool's 1,024-bit
threshold. This is an analysis-precision limitation around a wide variable
slice, not proof of a functional bug or proof that the logic is safe. Keep it
open until the analysis limit is resolved with an acceptable runtime and the
result is reviewed; do not suppress the rule.

The latest completed structural CDC report in the ignored local SpyGlass tree
is historical (2026-11-05 16:25), not a new 410b81d run. It reports one
`Reset_sync04`: `aresetn` reaches both
`compute_spad_mux_u.response_owner_valid_d_r` and
`spad_subsystem_u.cnm_protection_error_req_r`, both in the `aclk` domain; it
also reports `Ar_syncdeassert01` through the abstract reset-port constraint,
zero unsynchronized crossings, and zero convergence. RTL inspection confirms
both named registers are asynchronously reset. The spec says `aresetn` is an
active-low asynchronous reset but does not define its release timing. The
integration contract and reset-release verification therefore remain OPEN;
the warning is neither waived nor classified as a proven functional failure.

One `AsyncResetOtherUse` lint warning also remains for reset use in the DMA/CNM
hierarchy and needs source-level disposition. No RTL reset architecture was
changed in response to these tool findings.

Risk-oriented triage remains OPEN: review reset and width/shift/variable-slice
findings and disconnected ports first; inspect the repeated-assignment rules
with their overlapping signals before deciding whether any are functional or
style-only. All 465 are tool-severity `Warning`, but the rule count is not a
functional severity ranking and no rule has been waived.

| Readiness item | Current disposition |
|---|---|
| Functional simulation | Scoped candidate replay PASS; v2 sign-off remains IN PROGRESS. |
| SpyGlass warnings / CDC / RDC | Current lint completed with 465 warnings; current CDC stalled and current RDC timed out as detailed above. |
| Formal / LEC | NOT_RUN; older Matrix FSM proof does not establish whole-design equivalence or v2 closure. |
| DC area / Fmax / power | BLOCKED_ENV at `410b81d`; no private libraries/SDC or checked-in synthesis script. |
| SRAM mapping and capacity study | NOT_RUN; behavioral four-bank SRAM remains the performance-model boundary. |
| DFT, MBIST, CTS, route, routed STA, IR/EM | NOT_RUN; required before any tapeout-readiness claim. |

The current candidate still uses one 16×16/256-MAC array, existing
four-bank/512-KiB logical SPAD, 1-KiB bounded reuse array and 512-B forwarding
store. These are RTL-declared sizes, not mapped silicon costs. VCS timing and
the 250-MHz normalization are not physical timing evidence. Disposition stays
**NOT ASIC READY**.

## Verification-only update — 2026-11-06

Testbench/build candidate `380f96114dba022300db09fb217264c3a606a2fd` adds
coverage and directed checks without changing product RTL. SpyGlass, formal,
DC, LEC or physical-design flows were not rerun for that test-only commit; the
static-analysis and PPA dispositions above remain bound to the listed
candidate and tool runs. No area, Fmax, power, SRAM-macro, or tapeout-readiness
claim follows from the functional coverage results. The current functional
replay is summarized in the [v2 DV report](NMAFORGE_V2_DV_CLOSURE.md).

## Current environment recheck — 2026-11-06

Product RTL is still `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; the later
v2 commits in this worktree modify verification, measurement, and reports.
VCS `V-2023.12-SP1_Full64` ran the fixed-weight Transformer Top test and
`ai_smoke` on the current testbench candidate. The DC executable exists at
`/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`, but the isolated worktree has
no `syn/run_ai_accel_28nm_dc.sh`, synthesis Tcl, or `external/private` / TSMC28
overlay. `TSMC28_STDCELL_DB`, `TSMC28_SRAM_DB`, `TSMC28_SDC`, and
`TSMC28_TECH_LEF` are unset. No DC run was attempted because the design inputs
are missing. Base-vs-v2 area/Fmax/power remains **BLOCKED_ENV**; this is not a
DC license failure or a PPA result.

SpyGlass lint/CDC/RDC were not rerun in this environment refresh. Existing
evidence remains 465 lint warnings with no waiver, structural CDC with the
`Reset_sync04` / `FLAT_504` dispositions still open, and RDC **NOT_RUN** after
the recorded timeout. No formal/LEC, SRAM-macro, DFT, MBIST, CTS, route, routed
STA, or IR/EM status is advanced. The IP remains **NOT ASIC READY**.

## Current clean-candidate check — `839b9af`

The VCS clean-candidate replays at
`839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` are testbench/measurement work.
The product RTL remains at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`;
SpyGlass, CDC/RDC, Formal/LEC, DC, SRAM macro mapping, and physical-design
flows were not rerun for this candidate. Their last recorded outcomes remain
as in the environment audit above: lint has 465 unwaived warnings, CDC/RDC and
Formal/LEC are incomplete, and Base-vs-v2 PPA is `BLOCKED_ENV` because the
private libraries, SRAM timing views, SDC, and checked-in DC flow inputs are
unavailable. DFT, MBIST, CTS, route, routed STA, and IR/EM remain `NOT_RUN` or
`BLOCKED_ENV`. No silicon area, Fmax, power, or tapeout-readiness conclusion
follows from the current functional or behavioral-SPAD results.
