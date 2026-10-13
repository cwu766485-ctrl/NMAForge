# NMAForge AXI4 Near-Memory Tensor Accelerator Specification

**RTL release:** A10　**Software ABI:** v7.4　**Version register:** `0x1000_000a`
**Canonical top:** `rtl/top/ai_accel_top.v`　**Scope date:** 2026-10-13

This file is the English compatibility entry point for the current A10
specification. The complete, detailed specification is maintained in
[SPEC_ZH.md](SPEC_ZH.md). It covers the same RTL contract: AXI4-Lite control,
128-bit AXI4 DMA, 512 KiB four-bank scratchpad, CMDQ/CPLQ, ABI v7.4 descriptors,
INT8/BF16/FP16/matrix/SFU/CNN/KV operators, protection, performance counters, verification
evidence, and commercial-28-nm pre-layout limitations. It is the English companion of the
Chinese source-of-truth document, not a second ABI definition.

Opcode `0x50` (`BF16_DOT_ACC_FP32`) remains unchanged. A10 adds opcode `0x51`
(`FP16_DOT_ACC_FP32`); both use the existing command lifecycle, scratchpad
arbiter and completion writer, with sequential non-fused FP32 accumulation.
They are advertised by `CAP2[6]` and `CAP2[7]`, respectively. ABI major remains
7; descriptors remain 64 bytes and completions 16 bytes. A8 remains identifiable
as version `0x1000_0008` / ABI v7.2 with `CAP2=0x3f`; A9 is `0x1000_0009` /
ABI v7.3 with `CAP2=0x7f`; A10 reports `0x1000_000a` / ABI v7.4 with
`CAP2=0xff`.

## What the IP is—and is not

NMAForge is a synthesizable, **digital compute-near-memory (CNM)** accelerator.
It moves tiles between external memory and a four-bank scratchpad, then keeps
bank-local address generation, operand buffering and partial accumulation close
to each SRAM bank. It is not analog in-SRAM compute: the SRAM bit-cell, bit-line
and sense amplifier are not redesigned, and there is no ADC/DAC in the IP.

The supported architectural primitives are INT8 VDOT/GEMV/GEMM, 4×4 matrix-tile
GEMM/batched GEMM, Conv1x1/Conv3x3/depthwise Conv, Q15 Softmax/causal Softmax,
RMSNorm/LayerNorm, residual, GELU, SiLU, requantization and KV-cache read/write.
QKV/MHA/FFN are descriptor-composed micro-workloads. They are valuable end-to-end
RTL integration tests, but are not a claim of a production fused Transformer or
LLM-serving stack.

## Digital CNM datapath

For banked VDOT/GEMV opcodes `0x20/0x21`, NMAForge implements a digital
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
`rtl/control/axi_lite/ai_accel_regs.v`, `rtl/control/queue/ai_command_processor.v`,
`rtl/dma/ai_axi128_dma.v`, `rtl/memory/ai_spad_arbiter.v`,
`rtl/memory/ai_scratchpad.v`, and `sw/include/cimforge_regs.h`.

## Evidence boundary as of 2026-08-09

- Dynamic regression and directed CNM benchmarks are a functional baseline; they
  are not UVM coverage closure.
- A commercial 28 nm TT/0.9 V/25 C, 4.0 ns (250 MHz) pre-layout DC study met
  setup and hold with 32 SRAM macros. This is not post-route ASIC sign-off or proof of
  400 MHz.
- SpyGlass lint has 0 errors; CDC/RDC are structural-only checks blocked from
  advanced sign-off by missing licenses.
- XCZU15EG has an OOC implementation result and a bring-up runbook, but no
  board-level end-to-end acceptance claim.

See [TSMC28_SYNTHESIS_REPORT.md](../verification/TSMC28_SYNTHESIS_REPORT.md),
[ARCHITECTURE.md](../architecture/ARCHITECTURE.md) and [VPLAN.md](../verification/VPLAN.md) for conditions,
measured values and open gates.
