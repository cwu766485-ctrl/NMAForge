# NMAForge AXI4 Near-Memory Tensor Accelerator Specification

**RTL release:** A10　**Software ABI:** v7.4　**Version register:** `0x1000_000a`
**Canonical top:** `rtl/top/ai_accel_top.v`　**Scope date:** 2026-10-17

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
The core presents at most one new scratchpad request per cycle, while its two
operand-pair buffer slots allow up to two accepted reads to remain outstanding.
The core relies on in-order scratchpad responses because this port has no
per-read ID; it does not support response reordering.
They are advertised by `CAP2[6]` and `CAP2[7]`, respectively. ABI major remains
7; descriptors remain 64 bytes and completions 16 bytes. A8 remains identifiable
as version `0x1000_0008` / ABI v7.2 with `CAP2=0x3f`; A9 is `0x1000_0009` /
ABI v7.3 with `CAP2=0x7f`; A10 reports `0x1000_000a` / ABI v7.4 with
`CAP2=0xff`.

The four SPAD protection regions use inclusive `BASE` and exclusive `LIMIT`
byte addresses. `PERM[0..3]` means read, write, execute, and enable. An enabled
region must individually contain the full byte range of a valid request;
adjacent regions cannot be stitched together, while any one matching region is
sufficient. With all regions disabled, protection is in compatibility/open
mode; with any region enabled, a zero-byte request is denied. Invalid requests
are not accesses and pass this checker. End-address arithmetic is 33-bit, so a
range that wraps beyond the 32-bit SPAD address space cannot match. The checker
returns allow/deny; the integrating fabric reports and retires rejected
transactions.

Macro opcodes `0x40`–`0x42` support v4 compatibility addressing and ABI v7
addressing. Version 4 takes a 32-bit child-list base from `src0`; v7 takes the
64-bit base from `{src1,src0}`. The list base must be 64-byte aligned,
`length` is the child count, and `flags[3]` selects external-memory fetch (1)
versus scratchpad fetch (0). In v7, `src1` is the upper address word, not an
independent data pointer, so byte alignment is checked on the full address via
the low bits in `src0`, not on `src1` separately. A macro parent emits one
completion; children execute in order and stop on the first failure.

The current top-level UVM slice runs queued FP16 `0x51`, BF16 `0x50`, and INT8
VDOT `0x10` through DDR-model DMA loads, SPAD compute, shared completion, and
DMA stores. Six reproducible runs exhaust all six legal operation-order
permutations and check results against independent references. Each run then
submits one invalid FP16 descriptor selected by the run: unsupported opcode,
version, dimensions, alignment, stride, or flags. Each case checks `ERR_DESC`,
completion status, queue-pointer wrap, and error IRQ W1C. These are directed
validator cases; normal descriptor addresses and remaining fields stay fixed,
so broad random descriptor, AXI-error, and reset-recovery closure is still open. See the
[A10 DV RTM](../verification/A10_DV_RTM.md).

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

## Evidence boundary as of 2026-10-17

- Dynamic regression and directed CNM benchmarks are a functional baseline; they
  are not UVM coverage closure.
- The shared top-level UVM environment passes seeded queued FP16 (`0x51`),
  BF16 (`0x50`), and INT8 VDOT (`0x10`) DDR-to-DDR checks, plus six directed
  invalid-descriptor validator cases (opcode/version/dimensions/alignment/FP
  stride/FP flags) with `ERR_DESC` completion and queue wrap. It remains an MVP,
  not broad randomized descriptor, AXI-error, or reset/IRQ closure.
- Latest mixed BF16/FP16 dot UVM worktree rerun passed seeds `712345`, `987654`,
  and `20261015` with 484/484 scoreboard transactions per seed (430 numeric +
  54 fault/reset/error-transition), zero UVM warnings/errors/fatals, and peak
  read outstanding=2. Selected numeric/fault/reset and odd-tail parity coverage
  is 100%.
  The latest three-seed run extends randomized numerical coverage to lengths
  1..16 in both formats: 420 rows × 35 fields per seed, 215 BF16 and 215 FP16
  numeric transactions per seed; merged URG `cp_length` is 16/16 and
  `format_length_cross` is 32/32 (both 100%). This is dirty-worktree evidence,
  not a frozen-SHA replay, and does not establish full-length parity
  lifecycle/writeback. Short formal remains constrained to lengths 1..4; V1
  and A10 remain open. Artifacts: `/tmp/nmaforge_a10_fp_length16_20261017/`.
  DUT line/condition/FSM/branch coverage is 97.96%/97.00%/85.71%/92.86%. The FP
  core canonical formal harness proved 12/12 selected assertions and reached
  both covers with clean setup. A fresh length-1..4 bounded parity proof passed
  5/5 non-vacuous assertions and 2/2 covers at depth 5 with a 360-second
  solver budget. Across all nonzero 16-bit lengths,
  read accounting, request-word-index bounds, parity-cutoff compute blocking,
  and drain-to-error proved;
  three remaining cutoff/progress/writeback properties did not converge within
  240 seconds and produced no counterexample. Full-domain parity closure remains
  open, as do reset-release/RDC signoff, the parity prior-error transition
  disposition, and residual URG bins. The ready-pair/error-cutoff case is also
  hit by the targeted late-B protection test (two hits per seed). The latest
  `ai_smoke` and seeded 20-case `ai_run` passed on the 2026-10-17 worktree. The
  testbench-only vector/stimulus/formal-harness updates did not change production
  RTL. Exact commands, coverage limits, and dirty-worktree caveat are in the
  [A10 DV RTM](../verification/A10_DV_RTM.md) and
  [A10 run record](../verification/A10_DV_RUN_2026-10-17.md).
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
