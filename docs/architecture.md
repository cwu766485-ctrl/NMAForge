# CIMForge A8 architecture

## Scope

CIMForge A8 is a single-clock, synthesizable accelerator IP with an AXI-Lite
control plane and a 128-bit AXI4 memory-master data plane.  Its canonical top
is `rtl/top/ai_accel_top.v`; synthesizable modules are organized under
`rtl/control`, `rtl/dma`, `rtl/memory` and `rtl/compute`.

The design is an all-digital, CIM-inspired near-memory accelerator: data is
tiled into a banked scratchpad close to the compute engines.  It does not
modify SRAM bitcells, bitlines or sense amplifiers.

## Ownership and command flow

```text
host AXI-Lite --> axi_lite_reg_if --> ai_accel_regs
                                      | configuration / doorbell / status
                                      v
                              ai_command_processor
                                | descriptor validate / issue / order
                 +--------------+------------------+
                 |                                 |
          desc fetch                         completion writer
                 |                                 |
AXI4 DDR <-> ai_axi128_dma <-> ai_spad_arbiter <-> ai_scratchpad
                                   |                        |
                         compute / DMA requesters     4 banks, 512 KiB
                                   |
                     INT8, matrix, SFU, Conv, KV-cache engines
```

- `ai_accel_regs` only implements software-visible configuration, pulses,
  sticky status and IRQ reporting.  It does not advance queue pointers.
- `ai_command_processor` owns command lifecycle scheduling: `CMDQ_HEAD`,
  `CPLQ_TAIL`, descriptor-source selection, validation, compute launch and
  completion ordering.  Software publishes `CMDQ_TAIL` and consumes by
  advancing `CPLQ_HEAD`.
- `ai_spad_arbiter` exclusively drives the scratchpad scheduler port.
  Descriptor/completion clients retain control-plane priority; scalar/line
  compute, banked compute and scalar/line DMA arbitrate round-robin.  No
  top-level bypass mux is permitted.
- `ai_completion_writer` commits all four 32-bit completion words before the
  command processor publishes a new `CPLQ_TAIL` value.
- `ai_desc_fetch` obtains scratchpad descriptors and `axi_desc_fetch` obtains
  external descriptors; the command processor holds the chosen source for the
  command lifetime.

## Storage and DMA

The default XCZU15EG profile uses four logical banks and 512 KiB total
scratchpad capacity.  The scratchpad provides a host/debug port, one
arbiter-owned scheduler port and scalar/banked/128-bit line operations.
Simulation selects behavioural RAM with `+define+VCS`; Vivado uses the XPM
branch; the 28 nm DC profile instantiates 32 real 4K x 32 SRAM macros.

`ai_axi128_dma` is the only active DMA implementation.  It provides 128-bit
AXI4 transfers with 64-bit addressing, 1D/2D/gather/tile planning, 4 KiB
boundary handling, up to four tagged read bursts and ID-aware response
handling.  It also preserves AXI drain semantics on abort.  The design should
be described as *tagged multi-outstanding with ID-aware read responses*;
system-level arbitrary transaction reordering still requires UVM and board
stress evidence.

## Compute and ABI

The descriptor ABI supports scalar/banked INT8 VDOT, GEMV and GEMM, 4x4 tensor
GEMM/batched GEMM, requantization, GELU, SiLU, residual, LayerNorm/RMSNorm,
Softmax/causal Softmax, Conv3x3 line-buffer and KV-cache primitives.  ABI v7.2
adds the PACK_I8 layout bridge used by `sw/tools/cimforge_mapper.py` to form a
real Transformer micro-workload command chain:

```text
Q/K/V -> QK^T -> causal/row Softmax -> AV -> projection
      -> residual + norm -> FFN -> residual + norm
```

This is a primitive-composed Transformer path, not a claim of a production
fused MHA/decoder engine or a full software framework.

## Implemented evidence and open gates

| Gate | Status | Boundary |
|---|---|---|
| A8 functional RTL | Passed directed and smoke VCS regressions | Not UVM coverage closure. |
| Transformer micro-workload | 30 descriptors and 16 final output words checked | Small mapped workload, not model-level benchmark. |
| XCZU15EG OOC P&R | 100 MHz closed, setup/hold WNS +0.187/+0.032 ns | OOC IP only; not a full board timing claim. |
| TSMC28 DC | 250 MHz pre-layout setup/hold closed with real SRAM macros | Ideal-clock, single-corner pre-layout; not sign-off. |
| UVM / CDC / formal / post-layout / board workload | Open | Next engineering phase. |

The current RTL is therefore a strong, integrated pre-verification baseline.
The immediate next development track is UVM, starting with AXI-Lite, AXI4
memory, RAL, descriptor/queue scoreboard, DMA ID/4 KiB/abort checks and
end-to-end mapped Transformer sequences.  CDC becomes a separate design task
when independent PS/DDR/accelerator clocks are introduced; it is not a reason
to invent a CDC problem in the present single-clock configuration.
