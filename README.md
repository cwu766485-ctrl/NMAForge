# NMAForge — AXI4 Near-Memory Tensor Accelerator

[中文 README](README_ZH.md) · [Architecture](docs/architecture/ARCHITECTURE.md) ·
[Specification](docs/spec/SPEC.md) · [Verification plan](docs/verification/VPLAN.md) ·
[Documentation index](docs/README.md)

> **Short description:** A synthesizable AXI4 near-memory tensor accelerator
> with a banked scratchpad, queued DMA and INT8/Transformer primitives.

NMAForge is a synthesizable, all-digital near-memory tensor-accelerator IP.
It is **not** analog compute-in-memory: arithmetic remains digital, while a
four-bank scratchpad keeps tiles close to bank-local compute and reduces
external-memory traffic.

## Architecture at a glance

- 32-bit AXI4-Lite control plane and 128-bit AXI4 memory-master interface.
- 512 KiB four-bank scratchpad with a single arbitration point and control-plane
  priority.
- Command/completion queues, scratchpad or external descriptors, dependency
  events, atomic four-word completion publishing, status and IRQ.
- 1D/2D/gather DDR↔scratchpad DMA with 4 KiB boundary splitting, up to four
  tagged read requests, RID/BID-aware response handling, narrow-transfer
  alignment support and abort drain.
- INT8 VDOT/GEMV/GEMM, a 4×4 matrix tile engine, quantized SFU primitives,
  Conv3x3/depthwise-convolution primitives and KV-cache addressing.
- Transformer micro-workloads assembled from descriptor primitives, including
  QKV projection, QKᵀ, causal Softmax, AV, residual/norm and FFN.

## Evidence and current boundary

- VCS directed top-level smoke and Transformer micro-workload regressions have
  passed.
- DMA block UVM: 11 directed/random tests passed, covering 1D/2D/gather,
  RID/BID out-of-order responses, 4 KiB, abort and back-pressure.
- AXI-Lite control block UVM: six tests passed for reset/ABI, split AW/W,
  WSTRB/errors, IRQ/W1C, busy/abort, randomized accesses and RAL frontdoor.
- A commercial 28 nm pre-layout synthesis study met a 250 MHz constraint under
  its documented single-corner assumptions; details are sanitized in
  [`docs/verification/TSMC28_SYNTHESIS_REPORT.md`](docs/verification/TSMC28_SYNTHESIS_REPORT.md).
- XCZU15EG FPGA synthesis/implementation and bring-up scripts are included,
  but a clean-clone board deployment still needs the board owner’s private
  reference project and hardware access.

This is not ASIC sign-off or a production LLM-serving claim. Coverage closure,
full CDC/RDC/formal, post-layout ASIC sign-off, and real-board workload
measurements remain open.

## Repository layout

```text
rtl/       Synthesizable accelerator RTL
dv/     Smoke, block UVM, subsystem tests and static-analysis collateral
dv/uvm/ Reusable UVM agents and top-level UVM bring-up
sw/        ABI header, mapper and bare-metal bring-up source
fpga/      Public Vivado flows and board integration scripts
docs/      Architecture, specification, verification and public-release notes
```

## Public-release policy

No PDK files, SRAM macro models, timing libraries, vendor board schematics,
vendor reference projects, generated bitstreams, waveforms, credentials or
machine-specific EDA settings are included. See
[`docs/PUBLIC_RELEASE.md`](docs/PUBLIC_RELEASE.md) before publishing a fork.

Historical ABI/software identifiers may still use the `CIMFORGE_*` prefix for
compatibility. The public project name is **NMAForge**.
