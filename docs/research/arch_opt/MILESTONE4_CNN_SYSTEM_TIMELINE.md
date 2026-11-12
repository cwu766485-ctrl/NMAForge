# Milestone 4 — CNN DMA and System Dataflow

## Measured continuous accelerator timeline

The existing representative Top flow now measures one common endpoint sequence:
DMA preload into SPAD, CMDQ execution, completion, and AXI-Lite output readback.
For both-fused row-major CNN on VCS `V-2023.12-SP1_Full64`, 4 ns behavioral
clock, 128 KiB SPAD:

| Segment | Cycles | Bytes |
|---|---:|---:|
| DMA input setup + transfer | 3,019 | 10,944 AXI read payload |
| DMA busy subset | 2,879 | 10,944 |
| CNN CMDQ | 11,376 | 64,064 read / 16,640 write |
| AXI-Lite output readback | 4,992 | 3,328 readback bytes |
| Sum of measured endpoint segments | 19,387 | endpoint-specific |

The first-fused and legacy modes use the same endpoint and measured 3,035 and
3,051-cycle DMA windows respectively. Strict CNN Golden and independent payload
verification pass. The sum is a serialized accounting boundary, not a claim
that all segments are physically overlapped.

## DMA output comparison

The testbench has a validated DMA preload path and a separate DMA store smoke,
but this branch does not yet run output DMA to the same host-visible endpoint as
the AXI-Lite readback in one matched experiment. Therefore no DMA-output
speedup is reported. The required next experiment must use the same output bytes,
completion boundary, external-memory model latency and protection behavior for
both paths. DMA and Compute coexistence must retain the sole SPAD arbiter and
fault ordering.

Decision: **PARTIAL**. The continuous measured baseline is complete; the ≥10%
full endpoint reduction is not demonstrated and no CNN DMA RTL change is made.
