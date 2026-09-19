# NMAForge RTL learning and refactoring guide

Status: 2026-09-01. This guide describes the synthesizable RTL currently used
by `rtl/top/ai_accel_top.v`. It is a reading guide, not a replacement for the
ABI contract in [SPEC.md](spec/SPEC.md) / [SPEC_ZH.md](spec/SPEC_ZH.md).

## 1. Start from transactions, not from files

There are three distinct transaction paths. Keeping them separate makes the
RTL much easier to read and prevents accidental ownership violations.

```text
CPU AXI-Lite -> AXI-Lite adapter -> register semantics -> command processor
DDR AXI4     <-> 128-bit DMA       <-> scratchpad arbiter <-> scratchpad
Command      -> selected compute engine -> scratchpad -> completion writer
```

The command processor owns lifecycle scheduling. The register file publishes
software configuration and pulses only; it must not advance queue pointers.
The scratchpad arbiter owns the scheduler port; no new top-level mux may bypass
it. The completion writer commits four words before the command processor may
advance `CPLQ_TAIL`.

## 2. Recommended reading order

| Step | Files | Question answered |
|---|---|---|
| 1 | `rtl/top/ai_accel_top.v` | Which block owns each external interface and how are engine results selected? |
| 2 | `rtl/control/axi_lite/axi_lite_reg_if.v`, `rtl/control/axi_lite/ai_accel_regs.v` | How does software issue a register access and observe status? |
| 3 | `rtl/control/queue/ai_command_processor.v`, `rtl/control/descriptor/ai_desc_fetch.v`, `rtl/control/descriptor/axi_desc_fetch.v`, `rtl/control/queue/ai_completion_writer.v` | How is a command fetched, validated, launched and completed? |
| 4 | `rtl/memory/ai_spad_arbiter.v`, `ai_scratchpad.v`, `ai_spad_protection.v` | Who can access scratchpad memory and with which priority? |
| 5 | `rtl/dma/ai_axi128_dma.v` | How do external-memory transfers cross 4 KiB and outstanding-read boundaries? |
| 6 | `rtl/compute/int8/ai_int8_compute_core.v`, `rtl/compute/cnm/ai_banked_cnm_core.v`, `rtl/compute/matrix/ai_tensor_matrix_core.v`, `rtl/compute/sfu/ai_tensor_sfu_core.v` | Which engine implements an opcode and what data path does it use? |

## 3. Integration wrappers and acceptance state

The top-level wrapper files make protocol boundaries visible without moving
the state-machine owners that define the ABI.

| Wrapper | Scope | Acceptance state |
|---|---|---|
| `ai_accel_control_fabric.v` | AXI-Lite protocol adaptation and register-versus-SPAD-window response selection | Default integration path; requires the current top smoke before acceptance. |
| `ai_accel_axi_fabric.v` | Descriptor ID0/DMA ID1--4 AXI read routing, DMA write passthrough, fixed AXI sideband values | Default integration path; requires the current top smoke before acceptance. |
| `ai_accel_memory_fabric.v` | SPAD arbiter, response demux, storage and protection wiring | Experimental only. The proven top wiring remains default; enable only with `+define+NMAFORGE_ENABLE_MEMORY_FABRIC` for focused equivalence work. |
| `ai_int8_datapath.v` | Stateless packed INT8 dot4, accumulation, activation and saturation cone | Used by `ai_int8_compute_core`; its FSM and registered SPAD timing remain in the core. |

The legacy wiring branches are deliberate short-term safety fallbacks. Remove a
branch only after its selected configuration passes the matching VCS regression.

## 4. Control plane: two modules, one responsibility boundary

`axi_lite_reg_if` and `ai_accel_regs` are intentionally separate.

- `axi_lite_reg_if` implements AXI4-Lite channel timing. AW and W may arrive
  independently. It captures them into sticky registers and dispatches the
  internal write only on the following cycle after both are present. This is a
  protocol-safety boundary, not a data-path performance limit.
- `ai_accel_regs` implements register meaning: configuration storage, W1C
  sticky status, doorbells, abort pulses, IRQ, capability reporting and queue
  pointer-load compatibility writes. It does not schedule descriptors.

When changing either file, preserve the internal transaction contract:

```text
reg_req_valid, reg_req_write, reg_req_addr, reg_req_wdata, reg_req_wstrb
reg_rsp_rdata, reg_rsp_error
```

Do not change register offsets, field meanings, W1C behavior, response timing,
or the AW/W delayed-dispatch rule without a SPEC, software-header and UVM
update in the same change.

## 5. Datapath ownership map

| Area | Primary modules | Invariant to preserve |
|---|---|---|
| Command queue | `ai_command_processor` | Software produces `CMDQ_TAIL`; hardware reports `CMDQ_HEAD`. |
| Completion queue | `ai_completion_writer`, `ai_command_processor` | Four 32-bit words commit before hardware advances `CPLQ_TAIL`; software consumes with `CPLQ_HEAD`. |
| DMA | `ai_axi128_dma` | 128-bit AXI4, 64-bit address, 1D/2D/gather, 4 KiB split and up to four tagged read requests. |
| Scratchpad | `ai_spad_arbiter`, `ai_scratchpad`, `ai_spad_protection` | Control traffic has priority; the arbiter is the sole scheduler-side access point. |
| Tile overlap | `ai_tile_pipeline` | Store has priority over load; Context 0 wins ties; DMA and compute may operate on different buffers in one cycle. |
| Bank-local CNM | `ai_banked_cnm_core`, `ai_bank_local_controller`, `ai_bank_pe` | Four bank lanes retain local state; reduction happens at the output boundary. |
| Matrix/SFU/Conv/KV | tensor, SFU, line-buffer and KV modules | Registered scratchpad response timing and valid/ready behavior remain unchanged. |

## 6. Safe refactoring rules

An RTL readability change is safe only when all of these remain invariant:

1. Module ports, parameter defaults, register ABI, opcode values and source
   lists are unchanged.
2. A state transition occurs in the same cycle and keeps the same priority.
3. AXI and scratchpad `valid`/`ready` behavior, including data stability while
   stalled, is unchanged.
4. Register arithmetic widths, signedness, reset values and memory latency
   assumptions are unchanged.
5. The resulting source is compiled and the matching focused regression is
   executed.

Good refactorings include named state constants, named handshake predicates,
grouped address-decode functions, one-purpose helper functions, comments that
state an ownership invariant, and removal of duplicated context branches only
when their priority is made explicit.

Avoid merging protocol and register-semantic layers, converting registered
paths to combinational paths, moving scratchpad arbitration into the top level,
or using a stylistic cleanup to alter reset or response timing.

## 7. Current regression evidence

The following runs are recorded for the current public baseline:

```bash
cd dv/block/control/sim
make uvm_regress

cd ../../subsystem/top_smoke/sim
make ai_smoke
```

The current 2026-09-01 regression evidence includes the control and DMA UVM
regressions, the Transformer workload, top smoke, and a seeded 20-case random
run (`AI_SEED=12345`); the maintainer reported every requested target passing.
These are strong regression checks, not coverage, formal, post-layout, power
or board sign-off.

For the full verification closure strategy, see [VPLAN.md](verification/VPLAN.md).
