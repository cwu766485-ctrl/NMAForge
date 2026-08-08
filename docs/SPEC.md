# CIMForge A8 AI Accelerator Specification

**RTL release:** A8　**Software ABI:** v7.2　**Version register:** `0x1000_0008`
**Canonical top:** `rtl/top/ai_accel_top.v`　**Scope date:** 2026-08-08

This file is the English compatibility entry point for the current A8
specification. The complete, detailed specification is maintained in
[SPEC_ZH.md](SPEC_ZH.md). It covers the same RTL contract: AXI4-Lite control,
128-bit AXI4 DMA, 512 KiB four-bank scratchpad, CMDQ/CPLQ, ABI v7.2 descriptors,
INT8/matrix/SFU/CNN/KV operators, protection, performance counters, verification
evidence, and TSMC28 pre-layout limitations.

## Digital CNM datapath

For banked VDOT/GEMV opcodes `0x20/0x21`, CIMForge implements a digital
compute-near-memory (CNM) datapath. `ai_banked_cnm_core` instantiates four
`ai_bank_local_controller` blocks. Each controller owns its bank-local address
generation, A/B request, ready/response-valid lane, ping-pong operand buffer,
64-bit local accumulator and event counters. Only the four completed local
sums cross to the output-level Global Reducer.

`ai_spad_arbiter` remains the only scheduler-side scratchpad admission point.
A CNM admission carries four independent bank-lane addresses/masks; it does
not bypass the arbiter. Fine-grained simultaneous accesses by distinct clients
to different banks are not implemented and must not be inferred from this
interface. This is a digital near-memory architecture, not analog in-SRAM CIM.

Source-of-truth files are `rtl/top/ai_accel_top.v`,
`rtl/control/ai_accel_regs.v`, `rtl/control/ai_command_processor.v`,
`rtl/dma/ai_axi128_dma.v`, `rtl/memory/ai_spad_arbiter.v`,
`rtl/memory/ai_scratchpad.v`, and `sw/include/cimforge_regs.h`.

The current evidence is TSMC28 TT/0.9 V/25 C, 4.0 ns (250 MHz) pre-layout
setup/hold closure using 32 real SRAM macros. This is not post-route ASIC
sign-off or proof of 400 MHz. See [TSMC28_SYNTHESIS_REPORT.md](TSMC28_SYNTHESIS_REPORT.md)
for conditions and limitations.
