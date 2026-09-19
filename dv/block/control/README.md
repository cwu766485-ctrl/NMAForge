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
  abort and constrained-random read/write tests.

## Acceptance tests

| Test | Primary intent | Pass condition |
|---|---|---|
| `control_reset_version_test` | reset map and immutable ABI identity | VERSION/CAP/ABI/CAP2/reset fields match the specification |
| `control_protocol_test` | AW/W ordering, B/R back-pressure, WSTRB and illegal addresses | valid accesses return OKAY; partial/unaligned/out-of-page/RO writes return SLVERR; writable state is preserved |
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

VCS collected line/condition/FSM/branch/toggle/assertion coverage during the
run.  HTML code-coverage reporting via `urg` is currently blocked by the
Linux environment lacking the `VT_CoverageURG`/`VCSTools_Net` license feature.
Functional coverage and multi-seed closure therefore remain follow-up work;
this result is P0 directed-regression acceptance, not final coverage closure.
