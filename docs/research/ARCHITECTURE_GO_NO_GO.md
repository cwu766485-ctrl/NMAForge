# Phase 1 Architecture Decision

| Candidate | Decision | Evidence |
|---|---|---|
| P1 Compact Static Layout | **RETAIN as engineering improvement / REWORK for product integration** | Real 128 KiB RTL replay passed Golden with unchanged 11,376 command cycles and traffic; high-water fell 12.02%, DMA preload window fell 40 cycles. Descriptor/DMA/readback addresses were regenerated. |
| P2 Joint Memory-Aware Cost Model | **REWORK** | Offline prototype uses a train/held-out split and selects existing B2, but lacks bank conflict attribution, DMA/compute contention, padding and complete live-range terms. No product mapper change. |
| P3 Conditional Hardware Support | **REJECT for this phase** | P1 has no compute-cycle or SPAD-traffic gain, and P2 has no demonstrated new mechanism. No RTL support is justified. |

P1 is a useful capacity/fixture engineering result. It must not be described as lower SRAM macro area, higher Fmax, or a new NPU architecture without physical implementation and a complete live-storage proof. P2 should proceed only with a richer offline allocator/cost model and a passive monitor that records response ownership, outstanding depth, stall cause and epoch transitions. P3 remains closed until an end-to-end workload shows a causal benefit that cannot be obtained by legal static mapping.

The A1 replay did not run new fault/abort/reset injections, so Compute Cluster DV closure is not implied. The next verification phase is the fault-causal methodology specification and a targeted monitor extension, followed by a matched V0/V1 mutation experiment under the same DUT and simulation budget.
