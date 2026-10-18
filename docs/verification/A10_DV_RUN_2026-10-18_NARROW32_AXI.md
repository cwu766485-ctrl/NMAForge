# A10 V4 Follow-up — Narrow 32-bit AXI Read/Write Path

## Scope and tested tree

This run adds a directed top-level UVM round-trip for the legal 32-bit AXI4
transfer path used by the DMA when the byte address is word-aligned but not
128-bit aligned. It changes verification only; no RTL, specification, ABI, or
software behavior changed.

The run used Rocky Linux 8.10 and Synopsys VCS/URG `V-2023.12-SP1_Full64`.
The Git HEAD was `77b2cebfb1840f189d1859aa876aac089f2b0c3d` (`test(dv): correct
AXI4 coverage sampling`). The shared WSL worktree also contained unrelated
uncommitted user edits, so these results are **current-worktree evidence, not
an exact clean-commit replay**. The narrow-32 changes listed below were the
only files included in the follow-up commit.

## Verification added

- AXI read from DDR address `0x1ae4` (`ARSIZE=2`, `ARLEN=0`, INCR), where the
  returned word occupies lane 1 of the 128-bit bus. The sequence checks that
  the DMA places `0x13579bdf` in the requested scratchpad word.
- AXI write to DDR address `0x1afc` (`AWSIZE=2`, `AWLEN=0`, INCR), where the
  write occupies lane 3. Distinct canaries in all four words of the target
  128-bit line prove that only lane 3 changes.
- The scoreboard checks narrow AR/AW shape and uniqueness, expected read ID,
  data and lane mask, write ID, selected WDATA lane, matching WSTRB lane,
  WLAST, transaction counts, and retirement of all expected transactions.
- Each random run must emit both `[MIXED_E2E_NARROW_AXI_PASS]` and
  `[MIXED_E2E_PASS]` or the Make target fails.

During initial test development, SPAD address `0x7f70` overlapped the INT8 B
operand under one randomized SPAD layout, causing false UVM data mismatches.
The directed scratchpad word was moved to `0x7c00`, outside the generated
operand/result, queue, and sentinel ranges. This was testbench address aliasing,
not an RTL failure; the corrected test passes before the compute workload.

## Commands and results

Commands were run through the audited Rocky bridge (`bash -lic`) from the
repository root:

```sh
make -C dv/uvm/sim uvm_run \
  UVM_TEST=ai_mixed_precision_ddr_e2e_test \
  RUN_LOG=/tmp/nmaforge_a10_narrow32_focus_20261018/run.log

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress \
  MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_narrow32_random192_20261018

make -C dv/subsystem/top_smoke/sim ai_smoke
```

| Check | Result |
|---|---|
| Focused top-level E2E | PASS; narrow read/write round-trip and mixed-precision DDR oracle passed; UVM warning/error/fatal=`0/0/0`. |
| Seeded mixed-precision DDR E2E | 192/192 seeds passed; all 192 logs contain both required pass markers; no log has nonzero UVM warning/error/fatal counts. |
| URG functional groups | AXI4 coverage `64/64` (100%); mixed-precision E2E coverage `64/64` (100%); total group coverage 97.66%. |
| URG assertions | 20 successes, 0 failures, 0 incomplete; two unattempted assertions are UVM RAL internals. Cover properties: 3/3 matched. |
| RTL code coverage | Overall score 56.14% (line 50.65%, condition 46.77%, FSM 10.64%, branch 39.14%); raw code coverage remains open. |
| Top smoke | PASS (`TEST PASS`, make exit 0). |

The URG database and logs remain in `/tmp/nmaforge_a10_narrow32_random192_20261018`
and the focused log in `/tmp/nmaforge_a10_narrow32_focus_20261018`. They are
local run artifacts, not checked into Git.

## Files changed and limits

- `dv/uvm/agent/ai_accel_uvm_types_pkg.sv`
- `dv/uvm/env/scoreboard/ai_accel_scoreboard.svh`
- `dv/uvm/tests/sequences/ai_fp16_ddr_e2e_seq.svh`
- `dv/uvm/sim/Makefile`

This closes the previously unexercised legal narrow-32 transfer slice for the
selected mixed-precision E2E workload and repairs its AXI4 coverage bins. It
does **not** close all V4 interactions, DUT raw code coverage, V5 coverage
review, or the full A10 plan. In particular, oversized-burst and non-OKAY
AXI-Lite response cases remain separate follow-up items.
