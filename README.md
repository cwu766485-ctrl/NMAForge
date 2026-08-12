# CIMForge — AXI4 INT8 Tensor Accelerator

CIMForge is a synthesizable, scratchpad-based AI accelerator RTL project.  The
active product is an AXI-Lite control plane plus a 128-bit AXI4 memory-master
data plane; the historical AHB SRAM/vector teaching track has been removed.

## Current A8 baseline

- Canonical top: `rtl/top/ai_accel_top.v`.
- 32-bit AXI-Lite register/control interface and 128-bit, 64-bit-address AXI4
  DMA interface.
- 512 KiB four-bank scratchpad, with scalar, banked and 128-bit line accesses.
- Command/completion queues, scratchpad/external descriptors, in-order
  completion publishing and IRQ/status reporting.
- One unified `ai_axi128_dma`: 1D/2D/gather/tile transfer planning, 4 KiB
  boundary splitting, up to four tagged read bursts and ID-aware read-response
  handling.
- INT8 VDOT/GEMV/GEMM, 4x4 tensor GEMM/batched GEMM, requantization, GELU,
  SiLU, residual, LayerNorm/RMSNorm, Softmax/causal Softmax, Conv3x3
  line-buffer and KV-cache primitives.
- ABI v7.2 mapper support, including PACK_I8 layout conversion, for a real
  descriptor chain rather than isolated operator demos.

## Verified evidence and its boundary

The A8 baseline has passed VCS directed/smoke regressions, including the
30-command Transformer micro-workload (Q/K/V, QK^T, row Softmax, AV,
projection, residual/norm and FFN).  It has also closed a standalone XCZU15EG
OOC implementation at 100 MHz (setup WNS +0.187 ns; hold WNS +0.032 ns), and
TSMC28 HPC+ pre-layout DC at 250 MHz (4.0 ns, TT/0.9 V/25 C, zero setup/hold
violations using 32 real SRAM macros).

These are substantial RTL and pre-layout implementation milestones, not ASIC
sign-off or board-level throughput proof.  UVM coverage closure, CDC/RDC,
formal, post-layout sign-off and real-board workload measurements remain open.

## Source-of-truth files

- RTL: `rtl/top`, `rtl/control`, `rtl/dma`, `rtl/memory`, `rtl/compute`.
- VCS smoke file list: `verif/subsystem/top_smoke/sim/ai_accel.f`.
- FPGA RTL lists: `fpga/xilinx_a7_100t/ai_accel_rtl.tcl` and
  `fpga/xczu15eg/ai_accel_rtl.tcl`.
- Architecture: `docs/architecture.md`.
- Current PPA evidence: `docs/A8_TSMC28_SYNTHESIS_REPORT.md`.
- Project status/change record: `docs/project_update_log.md`.

See `AGENTS.md` for contribution, verification and tool-flow requirements.
