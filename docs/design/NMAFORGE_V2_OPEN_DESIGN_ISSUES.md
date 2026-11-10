# Open front-end design issues

Status: DESIGN_PARTIAL. This is not a signoff checklist or a request to perform deferred backend work.

1. No matched full Transformer subgraph on TinyNPU. Common arithmetic kernels have different timing endpoints; same-shape results cannot demonstrate application leadership.
2. LN saves 2.66% complete decode cycles, but residual/Requant and gamma/beta fetch remain substantial. No second optimization is assumed to be beneficial; row batching/forwarding need independent observable-tensor contracts.
3. Matrix eight-configuration ablation establishes benefits of existing controls, not a complete causal partition of overlapping stall counters. Bank placement or request scheduling remains an unproven next experiment.
4. 0x52 is bounded M,N<=16, dense/padded-layout only. Generic graph GEMV and automatic Mapper shape policy are not closed by this round.
5. Host CNN preprocessing/readback/pooling/argmax timing remains outside device subtotal. Accuracy evidence is historical; only one trained sample was rerun here.
6. SRAM macro port timing, read/write collision, parity and multi-cycle response adaptation remain integration risks. 128 KiB and 512 KiB behavioral evidence is not macro evidence.
7. No 400 MHz Fmax claim; candidate decode select is unsynthesized. Inspect divider shift/priority and arithmetic paths in later implementation work.
8. No complete opcode/shape/fault numerical sweep or formal equivalence for divider mode select; focused random SFU and complete H16 Golden are the bounded evidence.
9. New LN optimization shortens busy/watchdog exposure. Software must not rely on exact legacy completion latency; arithmetic and materialized tensors remain identical.
