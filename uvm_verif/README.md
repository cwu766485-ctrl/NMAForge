# CIMForge UVM verification environment

`uvm_verif/` is the independent, scalable verification project for the A8
AXI-Lite/128-bit-AXI4 CIMForge accelerator.  Existing `verif/` remains the
fast directed/smoke regression and reference-model area; it does not contain
UVM sources or UVM build targets.

## Directory ownership

| Directory | What belongs here | Current status |
|---|---|---|
| `agent/` | Reusable UVM transaction types plus AXI4-Lite active and AXI4 passive agents | One class per `.svh`; package files only assemble namespaces |
| `agent/items/` | `descriptor`、`completion`、AXI-Lite、AXI4 transaction objects | Implemented baseline |
| `agent/interfaces/` | Synthesizable SystemVerilog bus interfaces used by agent virtual interfaces | Implemented |
| `env/` | Environment composition, protocol scoreboard, coverage and reference-model adapter | One class per `.svh`; implemented baseline |
| `tests/` | `base/`、`sequences/`、`smoke/` and later `block/` tests | Version ABI smoke implemented |
| `tb/` | DUT + behavioural DDR integration only; no checking policy | Implemented |
| `formal/` | VC Formal harnesses, assumptions, properties and proof logs | Property template only; not proven |
| `sim/` | VCS file list and build entry points | Implemented; not executed in this workspace |

## Current testbench wiring

```text
ai_version_smoke_test
  -> ai_version_smoke_seq
  -> active ai_axil_agent
  -> rtl/top/ai_accel_top.v
  -> passive ai_axi4_agent -> scoreboard / functional coverage
  -> axi_memory_model (same 128-bit DDR behavioural slave used by smoke)
```

The AXI-Lite agent is active because software drives the accelerator register
file.  The AXI4 agent is passive because the accelerator itself is the AXI4
master; the behavioural DDR model supplies responses.  This preserves the
actual A8 ownership model: `ai_command_processor` schedules, `ai_axi128_dma`
owns data movement, and `ai_spad_arbiter` owns scratchpad arbitration.

Package files are intentionally small compilation/namespace containers.  For
example, `ai_accel_uvm_types_pkg.sv` includes one source file for each item;
the same pattern is used by AXI-Lite/AXI4 agents, environment and tests.  Do
not compile the `.svh` files individually: VCS compiles the package file, which
then includes its owned classes in a defined dependency order.

## Run on the Linux/VCS EDA environment

```bash
cd /home/ray/ic/CIMForge/uvm_verif/sim
make uvm_compile
make uvm_smoke
```

The default test is `ai_version_smoke_test`.  This command has not been run by
this source-only reorganisation, so compilation/pass evidence must be recorded
in `docs/project_update_log.md` after it is run on the licensed VCS host.

## Next additions, in order

1. Block-level `ai_axi128_dma` environment: AXI4 slave responder plus SPAD BFM;
2. DMA 1D/2D/gather, 4 KiB, abort and four-outstanding block sequences;
3. `ai_spad_arbiter` and command/queue/completion subsystem environments;
4. AXI-Lite RAL, reset/error/IRQ tests at top level;
5. active/error-injection AXI4 memory responder with RID/RLAST/BID scoreboarding;
6. CNM/matrix/SFU golden-model adapters, Transformer chain, coverage and formal closure.
