# NMAForge current status

**Snapshot date:** 2026-11-22
**Status:** `PARTIAL — benchmark evidence is bounded; product-wide sign-off is open.`

This page is the concise index for the public evidence currently recorded in this
repository. A result applies only to its named source/test SHA, run, workload,
and measurement boundary. Historical reports and workstream RTMs are not merged
into one global pass count.

## Design facts

| Item | Current documented configuration | Source |
|---|---|---|
| Physical Matrix Array | 16×16 INT8, 256 MAC lanes by default | [Architecture](architecture/ARCHITECTURE.md), [verification status](verification/COMPUTE_ENGINE_STATUS.md) |
| Matrix operand storage | 4×4 tile-major ABI/SPAD packing; this is not the physical array size | [English spec](spec/SPEC.md), [中文规格](spec/SPEC_ZH.md) |
| Scratchpad | Four banks, 128 KiB default; 512 KiB is an elaboration option | [English spec](spec/SPEC.md), [中文规格](spec/SPEC_ZH.md) |
| Compute-engine scope | Seven real top-level engine paths: INT8 VDOT, BF16 dot, CNM, Matrix, SFU, Conv3x3, and KV | [Compute-engine status](verification/COMPUTE_ENGINE_STATUS.md) |

## Current bounded evidence

| Workstream | Disposition | Evidence and boundary |
|---|---|---|
| Matched GEMM and Mini-CNN benchmark | `PARTIAL` | [Round 3 Phase 1](benchmark/NMAFORGE_V2_ROUND3_PHASE1_FAIR_BENCHMARK.md). NMAForge source/test SHA `c4c2970ad8e66c93e00e854ef3befff4ccc9188b`; Tiny-NPU is `harishsg993010/tiny-NPU` at `8216c22b762011aa20c05fc2768423fd12dda59d`. Tiny-NPU memory cycles are modeled for GEMM and endpoints differ for CNN; no system-level speedup is claimed. |
| GEMV cache/prefetch ablation | `PASS for tested standalone cases; not Product Top closure` | [Round 3 Phase 2](benchmark/NMAFORGE_V2_ROUND3_PHASE2_DATAFLOW_ABLATION.md), 48/48 Golden-exact cases, three seeds, physical array 16×16 and behavioral four-bank memory. Cache consistently reduced read traffic; prefetch benefit depended on shape. No area/timing result. |
| 262,144-MAC pointwise CNN dataflow A/B | `PASS for tested Product Top command paths; research workload only` | Same Phase 2 report and committed raw data. Legacy / first-layer fused / both-layer fused Linear-Row used 4 / 3 / 2 descriptors and 60,930 / 34,324 / 7,708 command cycles; all three passed 20,480 Golden words. Weights are deterministic inference weights, not a trained model. Fixture preload/poison cycles are not production end-to-end latency. |
| Product-wide functional/DV closure | `OPEN` | Seven-engine and A10 evidence are in separate reports and have distinct scopes. The Compute Cluster 38-row RTM records 24 `PASS-SCOPED` and 14 `PARTIAL`; its disposition remains `HOLD`. Do not combine these with A10 RTM counts. See [Compute Cluster RTM](verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) and [A10 RTM](verification/A10_DV_RTM.md). |
| Static analysis | `PARTIAL / NOT_RUN by goal` | Latest report snapshot is for source/test SHA prefix `410b81d` on 2026-11-05: SpyGlass lint completed with 0 errors, 465 warnings, 5 infos, 0 waivers; warning closure is open. CDC replay was terminated (exit 143, `NOT_RUN`); RDC timed out (exit 124, no conclusion). See [static analysis report](verification/STATIC_ANALYSIS_REPORT.md). |
| ASIC synthesis | `HISTORICAL PRE-LAYOUT POINT ONLY` | The published 250 MHz result describes a 512 KiB four-bank profile, TT/0.9 V/25 °C, 4.0 ns constraint, and single-port SRAM macros. It is not current 128 KiB candidate PPA, routed timing, or sign-off. See [synthesis report](verification/TSMC28_SYNTHESIS_REPORT.md). |

## Reproduction references

- Fair benchmark: command, tool versions, run ID, SHA values, and log hashes are in the [Phase 1 report](benchmark/NMAFORGE_V2_ROUND3_PHASE1_FAIR_BENCHMARK.md). Raw simulator logs are stored under `/tmp/nmaforge_round3_fair_20261122/` on the run host, not in Git.
- GEMV and CNN A/B: commands, seed/configuration data, manifests, CSV/JSON, and log hashes are in the [Phase 2 report](benchmark/NMAFORGE_V2_ROUND3_PHASE2_DATAFLOW_ABLATION.md). Local raw run logs are outside Git as identified there.
- These results do not establish trained-model accuracy, ASIC PPA, sustained array utilization, or a fair whole-system Tiny-NPU speedup.

## Open items

1. Establish a matched Tiny-NPU controller/memory endpoint before making system-level performance claims.
2. Measure production data loading and full application latency separately from fixture preload, poison initialization, and command-window cycles.
3. Continue the distinct A10 and Compute Cluster verification workstreams without merging their requirement counts.
4. Close lint warnings and obtain conclusive CDC/RDC results on a fixed candidate before sign-off.
5. Re-run synthesis for the selected current RTL/SPAD configuration with source-bound constraints before making current PPA claims.

## Historical snapshots

The prior [execution frontier through 2026-11-09](exec-plans/archive/execution-frontier-through-2026-11-09.md)
is retained verbatim for traceability. The active frontier is intentionally short
and points here instead of duplicating stale status tables.
