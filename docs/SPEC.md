# CIMForge A8 AI Accelerator Specification

**RTL release:** A8　**Software ABI:** v7.2　**Version register:** `0x1000_0008`
**Canonical top:** `rtl/top/ai_accel_top.v`　**Scope date:** 2026-08-04

This file is the English compatibility entry point for the current A8
specification. The complete, detailed specification is maintained in
[SPEC_ZH.md](SPEC_ZH.md). It covers the same RTL contract: AXI4-Lite control,
128-bit AXI4 DMA, 512 KiB four-bank scratchpad, CMDQ/CPLQ, ABI v7.2 descriptors,
INT8/matrix/SFU/CNN/KV operators, protection, performance counters, verification
evidence, and TSMC28 pre-layout limitations.

Source-of-truth files are `rtl/top/ai_accel_top.v`,
`rtl/control/ai_accel_regs.v`, `rtl/control/ai_command_processor.v`,
`rtl/dma/ai_axi128_dma.v`, `rtl/memory/ai_spad_arbiter.v`,
`rtl/memory/ai_scratchpad.v`, and `sw/include/cimforge_regs.h`.

The current evidence is TSMC28 TT/0.9 V/25 C, 4.0 ns (250 MHz) pre-layout
setup/hold closure using 32 real SRAM macros. This is not post-route ASIC
sign-off or proof of 400 MHz. See [A8_TSMC28_SYNTHESIS_REPORT.md](A8_TSMC28_SYNTHESIS_REPORT.md)
for conditions and limitations.
