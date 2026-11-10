# Open design risks

- SRAM macro read latency, single-port read/write turnaround, parity and response routing need explicit implementation adapters. Behavioral RAM passes do not close this interface risk.
- New cache-read/subtract path on accepted output write requires timing review; existing gamma/reciprocal multiply cuts remain. No 400 MHz claim or area estimate without tools.
- One seed/fixed model establishes bounded numerical evidence, not all legal length/alias/fault combinations or formal equivalence. Existing warning debt remains 17 in focused Verilator run.
- Shared-SPAD concurrency relies on software immutable inputs and dependency events. Existing caches/forward tags do not provide coherence.
- Gamma/beta and Requant/Residual traffic remains; no removed INT32 intermediate. Matrix stall counters overlap and require more granular causal traces for any next scheduling change.
- No matched complete Transformer subgraph on TinyNPU; CNN graph/controller endpoints differ. No cross-design system speedup supported.
- CNN full host preprocessing/output readback/GAP/argmax timing remains excluded. Historical accuracy is not revalidated on a complete held-out set.
- SSH public key rejected; candidate is local only until secure authentication is repaired. Do not claim GitHub publication.
