# CIMForge A5 performance observability and decoder-attention increment

## Scope implemented for the board-measurement build

- `ai_tensor_matrix_core` has a one-entry operand prefetch buffer.  It requests
  the next A/B K-group while the current group is in its four INT8 MAC lane
  cycles, then only switches buffers once both registered scratchpad responses
  have been captured.  This preserves the single arbiter-owned banked port.
- The sixteen INT8 product nets are tagged `(* use_dsp = "yes" *)` for the
  Xilinx FPGA profile.  The post-synthesis report, rather than the attribute,
  is the acceptance evidence for DSP48E2 inference.
- `OP_CAUSAL_SOFTMAX_Q15 (0x39)` is a decoder attention primitive.  It uses
  descriptor `aux0[15:0]` as the query-token index and writes exact zero for
  score columns above that index.  The remaining elements follow the existing
  stable Q8.8-log2 to Q0.15 softmax contract.
- `ai_perf_monitor` adds passive, software-clearable counters.  They do not
  alter scratchpad arbitration or AXI backpressure.

## A5 measurement registers

Write `PERF_CTRL[0]` before a benchmark.  Read counters only after the
completion/IRQ for that benchmark.

| Offset | Register | Meaning |
|---:|---|---|
| `0x178` | `PERF_MATRIX_CYCLES` | matrix core busy cycles |
| `0x17c` | `PERF_MATRIX_MAC_CYCLES` | 16-MAC lane cycles |
| `0x180` | `PERF_MATRIX_BANKED_STALL` | A/B/prefetch response wait cycles |
| `0x184` | `PERF_DMA_READ_BYTES` | accepted DMA read beats × 4 bytes |
| `0x188` | `PERF_DMA_WRITE_BYTES` | accepted DMA write beats × 4 bytes |
| `0x18c` | `PERF_DMA_AR_COUNT` | accepted DMA read addresses |
| `0x190` | `PERF_DMA_AW_COUNT` | accepted DMA write addresses |
| `0x194` | `PERF_DMA_RD_STATE` | `[5:3]` read outstanding high-water, `[2:0]` current |
| `0x198` | `PERF_DMA_R_STALL` | valid R cycles blocked by DMA/scratchpad admission |

For a matrix workload with `N_mac` completed INT8 MACs at `f_clk`:

`sustained_GMAC_per_s = N_mac * f_clk / PERF_MATRIX_CYCLES / 1e9`

`mac_util = PERF_MATRIX_MAC_CYCLES / PERF_MATRIX_CYCLES`

The current DMA datapath remains 32-bit.  At 100 MHz its one-direction AXI
ceiling is 400 MB/s; the counters above distinguish DDR/AXI stalls from matrix
or scratchpad stalls.

## Tonight's board acceptance workload

`sw/baremetal/cimforge_bringup.c` retains the original version, DDR DMA,
CMDQ, VDOT, completion and GIC-IRQ checks, then adds two deterministic A5
microbenchmarks:

1. `dma256`: a 256-word load plus a 256-word store between PS DDR and
   scratchpad. It checks the first/last returned words and requires exactly
   1024 DMA read bytes and 1024 DMA write bytes from the monitor.
2. `gemm4x4x8`: a 4x4 INT8 matrix times an identity matrix with two K-groups.
   The second K-group is zero and exists specifically to exercise the A/B
   prefetch path. It verifies four output corners and requires nonzero matrix
   busy and MAC-active counters.

The UART prints the raw counter lines as `A5 PERF dma256` and
`A5 PERF gemm4x4x8`. Archive those lines with the routed timing/utilization
reports. For GEMM, use `N_mac = 4 x 4 x 8 = 128` in the formula above; for
DMA, calculate payload bandwidth independently for each direction as
`bytes / elapsed_cycles / 1e6` MB/s at 100 MHz. Do not compare the two
microbenchmarks as end-to-end Transformer throughput.

## Implementation handoff (2026-07-26)

The XCZU15EG board design has been placed, routed and exported at 100 MHz:
WNS is `+0.094 ns`, WHS is `+0.010 ns`, and no setup or hold endpoint fails.
The routed accelerator hierarchy uses 17,287 LUTs, 10,489 FFs, 128 RAMB36 and
38 DSP48E2. The complete PS/PL image (including interconnect and debug IP)
uses 30,630 LUTs, 29,679 FFs, 189 RAMB36, 1 RAMB18 and 38 DSP48E2.

The generated local handoff artifacts are `fpga/xczu15eg/build/board/
cimforge_board.bit`, `.xsa` and `.ltx`, together with
`fpga/xczu15eg/build/baremetal/cimforge_fsbl.elf` and
`cimforge_bringup.elf`. They are build outputs and intentionally remain
outside Git. The remaining acceptance is physical: program the bitstream,
run FSBL then bring-up ELF, archive UART `A5 PERF` lines and save the ILA
capture.

## Deliberate next-stage boundaries

This board-measurement build does **not** claim a 128-bit payload DMA or full
CNN sliding-window frontend.  A real 128-bit upgrade requires four-word
load/store FIFOs plus four-bank scratchpad admission, not merely a SmartConnect
width converter; otherwise the scalar scratchpad port remains the 32-bit
bottleneck.  Likewise Conv3x3/DWConv currently consume software-generated
im2col/tile layout.  Padding, stride, sliding-window and line-buffer hardware
are a separate frontend engine and need their own golden-model regression.
