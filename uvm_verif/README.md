# NMAForge reusable UVM infrastructure

`uvm_verif/` owns reusable UVM transaction types, AXI agents, interfaces and
the original top-level ABI smoke bring-up for the A8 AXI-Lite/128-bit-AXI4
NMAForge accelerator. `verif/` owns the active block/subsystem verification
tree and reuses these common protocol assets where appropriate.

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
| `sim/` | VCS file list and build entry points | Version smoke passed in the Linux/VCS environment |

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
cd <repo>/uvm_verif/sim
make uvm_compile
make uvm_smoke
```

The default `ai_version_smoke_test` passed in the Linux/VCS environment. The
active UVM work is now under `verif/block/`: DMA has 11 passing directed/random
tests and AXI-Lite control has six passing tests. See `verif/VERIFICATION_MATRIX.md`
for the current evidence boundary.

## Next additions, in order

1. Block-level `ai_axi128_dma` environment: AXI4 slave responder plus SPAD BFM;
2. DMA 1D/2D/gather, 4 KiB, abort and four-outstanding block sequences;
3. `ai_spad_arbiter` and command/queue/completion subsystem environments;
4. AXI-Lite RAL, reset/error/IRQ tests at top level;
5. active/error-injection AXI4 memory responder with RID/RLAST/BID scoreboarding;
6. CNM/matrix/SFU golden-model adapters, Transformer chain, coverage and formal closure.
