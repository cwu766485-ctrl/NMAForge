# Active execution frontier

**Snapshot:** 2026-11-23
**Disposition:** Phases 1–2 are complete only within their documented benchmark scopes; Phase 3 is partial. No RTL task is active on this documentation branch.

The current status, source-bound evidence, verification boundaries, and open issues are maintained in [docs/STATUS.md](../../STATUS.md).

Completed benchmark work for this branch:

- [Round 3 Phase 1: fair Tiny-NPU benchmark](../../benchmark/NMAFORGE_V2_ROUND3_PHASE1_FAIR_BENCHMARK.md)
- [Round 3 Phase 2: GEMV and Product Top CNN dataflow A/B](../../benchmark/NMAFORGE_V2_ROUND3_PHASE2_DATAFLOW_ABLATION.md)
- [Round 3 Phase 3: consolidated status and evidence boundaries](../../benchmark/NMAFORGE_V2_ROUND3_PHASE3_STATUS_20261123.md)

Next bounded items:

1. Re-run the three GEMM shapes with a fixed seed and identical harness settings to explain the 2026-11-22 vs 2026-11-23 cycle differences.
2. Keep H64 status scoped to synthetic, same-Top prefix-recompute; a persistent-KV decode measurement and immutable source-bound run manifest are still open.
3. Keep DeiT status scoped to the targeted patch-projection smoke; full 197-token embedding/encoder execution is not established by that run.
4. Do not compute Tiny-NPU system speedup until compute, memory, setup, and output endpoints are matched.
5. Investigate the UVM smoke `CLUSTER_MEMORY_EMPTY` failure; formal targets remain `BLOCKED_ENV / NOT_RUN` because `vcf` was unavailable.

The previous frontier was retained verbatim at [execution-frontier-through-2026-11-09.md](../archive/execution-frontier-through-2026-11-09.md). Historical plans and RTM counts remain scoped to their owning workstreams; they are not current global sign-off totals.
