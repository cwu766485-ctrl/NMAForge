# NMAForge Compute Cluster — Current Progress and Remaining Distance

**Snapshot:** 2026-11-04. This is a planning estimate, not a sign-off or coverage metric.

## Current position

The v1.0 Functional DV package is in candidate review, not signed off. The 38-row Execution RTM has 27 `PASS-SCOPED` rows and 11 `PARTIAL` rows, with no `BLOCKED_SPEC` or `NOT_RUN`. `PASS-SCOPED` means the recorded test scope passed; it does not mean the entire requirement is closed. The latest three-seed clean replay adds the bounded R302 reset-with-held-request testpoint; it does not change dispositions. See the [R302 evidence](COMPUTE_CLUSTER_PARALLEL_RESET_REQUEST_STALL_R302_2026-11-04.md) and [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

The remaining partial requirements are `REQ-CL-006/010/014/015/017/018/019/027/028` and `REQ-PC-006/007`. They cover, in aggregate, shared-SPAD ownership under broader concurrency and faults, downstream-stall fairness, Matrix FSM/integration dispositions, per-engine legal fault/descriptor/result contracts, reset/abort/completion interactions, full memory-scoreboard scope, and comparable performance evidence. The full list and evidence are in the RTM. **Do not declare `CL-DV-v1.0` signed off yet.**

## Approximate program progress

| Workstream | Current evidence | Remaining work |
|---|---|---|
| Phase A — v1.0 DV sign-off | 27/38 requirements are `PASS-SCOPED`; three-seed real-top UVM, formal, mutation, and clean-replay evidence exist. | Close or formally disposition all 11 partials, review checker/SVA scope, and produce an independent final sign-off review. Exit condition not met. |
| Phase B — fused requant/native layout | The Digits baseline and the SFU tile-pack bottleneck are measured. | No fused requant/native tile writeback implementation or complete before/after Digits replay yet. |
| Phase C — shape-adaptive GEMM/GEMV | A research prototype exists. | Product Matrix integration, bank-aware fetch, outstanding response ownership, double buffering, K-fold reduction/tail masking, and real-SPAD ablations remain. |
| Phase D — TinyNPU comparison | Matrix ablation and a three-shape matched-controller comparison exist. | No same-memory-service RTL comparison across the required GEMM/CNN/GEMV set; TinyNPU memory behavior for the normalized endpoint is modeled. |
| Phase E — trained model/PPA | The existing Digits path is a useful functional baseline. | Trained decoder prefill/decode and credible ASIC area/Fmax/power evidence are not complete. |

Across these five sequential workstreams, a rough engineering-completion estimate is **about 30%**. This percentage is intentionally not derived from coverage-bin percentage or the 27/38 RTM count; it reflects that most of the architecture-optimization, fair comparison, trained-model, and PPA deliverables are still ahead.

## Distance to TinyNPU

The latest comparison pins TinyNPU at `8216c22b762011aa20c05fc2768423fd12dda59d` and uses NMAForge's 16×16 Matrix controller with behavioral four-bank SPAD:

| GEMM | NMAForge cycles | TinyNPU array cycles | TinyNPU normalized endpoint | Readout |
|---|---:|---:|---:|---|
| 16×16×16 | 152 | 52 | 151 | NMAForge is 1 cycle (0.7%) slower than the modeled endpoint. |
| 16×16×32 | 231 | 100 | 231 | Cycle parity with the modeled endpoint. |
| 32×32×64 | 1,198 | 790 | 1,305 | NMAForge is 8.2% faster than the serialized model, while reading 50% more input bytes. |

This is not a demonstrated same-memory-service advantage: TinyNPU's memory interval is normalized with an explicit serialized schedule, while NMAForge uses behavioral SRAM. GEMV/decode, larger CNN, trained-model inference, and ASIC PPA/Fmax/power have no comparable result yet. Source: [R273 matched-controller report](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R273_2026-11-04.md).

## Rough remaining schedule

For one full-time senior RTL/DV engineer, with VCS continuously available and required model/implementation inputs supplied, a rough remaining effort is:

| Workstream | Estimate |
|---|---:|
| Phase A final DV closure and review | 2–4 weeks |
| Phase B fused data-layout optimization | 3–5 weeks |
| Phase C shape-adaptive product integration | 4–7 weeks |
| Phase D fair TinyNPU benchmark suite | 3–4 weeks |
| Phase E trained-model and PPA evidence | 4–8+ weeks |

Because the phases are gated and the last phase depends on model weights, PDK/Liberty/SRAM timing views and licensed implementation tools, plan on **roughly 4–7 calendar months** for the full target. Missing implementation inputs can extend PPA separately; in that case PPA remains `BLOCKED_ENV`/`NOT_RUN`, not a claimed result.
