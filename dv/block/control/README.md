# AXI-Lite control block UVM

## DUT boundary

The block DUT is the real protocol and register-file chain:

```text
active AXI4-Lite UVM agent
        -> axi_lite_reg_if -> ai_accel_regs
                                      <- control-status BFM
```

`ai_control_status_if` is a test-only boundary that supplies processor/DMA
completion and busy feedback, and observes IRQ plus register-file pulses.  It
does not replace or mock either DUT module.

## Assets

- `agent/`: active AXI4-Lite agent with independently delayed AW and W,
  programmable B/R back-pressure, and a passive transaction monitor.
- `env/control_reg_model.svh`: P0 RAL map for reset/identity, configuration,
  queue control, DMA control and IRQ ABI registers.
- `env/`: monitor-fed scoreboard and functional coverage.
- `assertions/`: AXI valid stability, abort pulse and IRQ-known SVA.
- `tests/`: reset/version, protocol/WSTRB/error, IRQ/sticky error, busy-lock/
  abort, constrained-random read/write, busy-channel back-pressure, and in-flight
  reset-phase tests.

## Acceptance tests

| Test | Primary intent | Pass condition |
|---|---|---|
| `control_reset_version_test` | reset map and immutable ABI identity | VERSION/CAP/ABI/CAP2/reset fields match the specification |
| `control_register_file_test` | mapped register read/write, queue boundaries, status feedback and control pulses | all mapped regions read correctly; configuration masks, W1C/IRQ behavior and observed pulses match the ABI |
| `control_protocol_test` | AW/W ordering, B/R back-pressure, WSTRB and illegal addresses | valid accesses return OKAY; partial/unaligned/out-of-page/RO writes return SLVERR; writable state is preserved |
| `control_channel_backpressure_test` | hold a second AW/W/AR request while the single-entry adapter is busy | all three request VALID/payload signals remain stable until READY returns; responses retire in order |
| `control_inflight_reset_test` | assert reset in each write/read FSM in-flight phase | reset clears pending B/R responses and IRQ; post-reset VERSION access succeeds |
| `control_irq_error_test` | processor error event, sticky status and W1C | result/error/status/IRQ latch and clear exactly through the documented writes |
| `control_busy_abort_test` | configuration lock while busy and allowed abort | protected configuration returns SLVERR; ABORT is accepted and SVA observes its pulse |
| `control_random_rw_test` | randomized legal configuration transactions | every readback equals the last accepted full-word write, with randomized channel delays |
| `control_ral_access_test` | P0 UVM RAL frontdoor access | RAL map, adapter, sequencer binding and predictor perform VERSION read plus OP write/read correctly |

## Commands

Run in the Linux/VCS EDA environment:

```bash
cd <repo>/dv/block/control/sim
make uvm_smoke
make uvm_regress 2>&1 | tee control_block_regress.log
make coverage
```

## Current acceptance evidence

On 2026-08-13, `make uvm_regress` completed all six tests in the Linux VCS
V-2023.12-SP1 environment.  Each log reports `UVM_ERROR=0` and
`UVM_FATAL=0`; the monitor-fed scoreboard reports only legal AXI-Lite
responses, and the local SVA remain clean.  The regression found and fixed a
real independent-AW/W dispatch bug in `axi_lite_reg_if`: a write is now issued
only after both channels were captured in prior cycles.

The 2026-08-13 entry above is historical. The VCS license is available in the
current Rocky 8.10 / WSL environment, and URG reports have been generated for
the refreshed regression below.

### 2026-10-16 refreshed coverage evidence

After URG review found that read items' default `strb=0` was being counted as
WSTRB coverage, `cp_strb` was qualified to write transactions only. The
protocol sequence probes every partial WSTRB encoding (`0x0` through `0xe`)
and verifies each write is rejected without changing OP; it also read-probes
the previously unhit address windows. The follow-up
`control_channel_backpressure_test` overlaps a second AW/W/AR request with a
busy adapter. `control_inflight_reset_test` asserts reset in WR_REQ,
WR_RESP_ARM, WR_RESP, RD_REQ, RD_WAIT, and RD_WAIT2, then checks reset
quiescence and successful post-reset access. Canonical `make uvm_regress`
passes all eight tests with UVM warning/error/fatal=0. Fresh URG report:
`/tmp/nmaforge_a10_control_reset_irq_20261015/urg_final/`; selected
functional group is 34/34 variables + 4/4 crosses (100%). All seven DUT SVA
have real successes, 0 failures/incomplete; the two unattempted properties
are UVM RAL internals. The AXI interface FSMs now cover all 6/6 write and 8/8
read transitions, including reset-to-idle from in-flight states.

The 2026-10-16 regression includes the ninth test, `control_register_file_test`,
and passes 9/9 with UVM warning/error/fatal=0. The merged URG report is
`/tmp/nmaforge_a10_control_20261016_release_urg/`; the selected functional
group remains 34/34 variables + 4/4 crosses (100%), and all seven DUT SVA
properties have non-vacuous successes with 0 failure/incomplete. The two
assertions without attempts are UVM RAL internals. `ai_accel_regs` line/
condition/toggle/branch is now 100.00%/85.09%/30.14%/98.51%; its earlier
50.73%/60.53%/12.23%/25.25% numbers are superseded. Condition/branch outcomes
and low toggle coverage still need review; this does not close all Control
coverage or overall A10 sign-off. See [the exact run record](../../../docs/verification/A10_DV_RUN_2026-10-16.md).
