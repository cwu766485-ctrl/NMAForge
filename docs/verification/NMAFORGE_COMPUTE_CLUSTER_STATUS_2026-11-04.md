# NMAForge Compute Cluster — Current Progress and Remaining Distance

**Snapshot:** 2026-11-04. This is a planning estimate, not a sign-off or coverage metric.

**Published branch:** `cwu766485-ctrl/NMAForge`, branch `feat/compute-cluster-closeout-audit`. Latest code/test candidate is published HEAD `a061c2ea96a874d0755674c75139154a2e6e391f` / tree `7a4051b78d2f874c014f67e2db4045d88d7b7815`. R310 clean replay passes three seeds; all seven real-engine held-request reset cuts retain an old-epoch read after the injected stall. See [R310 evidence](COMPUTE_CLUSTER_PENDING_READ_RESET_OWNER_SWEEP_R310_2026-11-04.md). Earlier R307 broad replay and R308 actual-RTL mutation campaign remain applicable to their recorded source trees.

## Current position

The v1.0 Functional DV package is in candidate review, not signed off. The 38-row Execution RTM has 27 `PASS-SCOPED` rows and 11 `PARTIAL` rows, with no `BLOCKED_SPEC` or `NOT_RUN`. `PASS-SCOPED` means the recorded test scope passed; it does not mean the entire requirement is closed. R302 adds a bounded reset-with-held-request point; R303 adds stalled-request mutation sensitivity; R304 replays a published candidate; R305 merges declared functional coverage; R306 adds a seven-engine Protection/full-CPLQ/reset/recovery cross; R307 reruns the exact published HEAD with 3 Cluster + 16 mixed E2E seeds, merges 19 VDBs, and passes Top Smoke, fixed Top regression, plus bounded formal replay; R308 reruns 8 actual RTL mutations; R309 covers each request owner; R310 requires a pending old-epoch read after the stalled-request edge for all seven owner cuts. R307 reports 38/38 declared groups at 100%, while whole-top line/condition/FSM/branch/assert remains 76.21/71.52/53.49/67.49/92.00%; R308 verifies assigned checker sensitivity. R310 is a bounded reset point, not the full requester × response-owner × fault × phase × reset space, so all 11 partial Requirement clauses remain open. See [R302 evidence](COMPUTE_CLUSTER_PARALLEL_RESET_REQUEST_STALL_R302_2026-11-04.md), [R303 evidence](COMPUTE_CLUSTER_REQUEST_STABILITY_MUTATION_R303_2026-11-04.md), [R304 replay](COMPUTE_CLUSTER_FINAL_CLEAN_REPLAY_R304_2026-11-04.md), [R305 coverage audit](COMPUTE_CLUSTER_COMBINED_COVERAGE_R305_2026-11-04.md), [R306 cross](COMPUTE_CLUSTER_PROTECTION_CPLQ_RESET_R306_2026-11-04.md), [R307 replay](COMPUTE_CLUSTER_PUBLISHED_HEAD_REPLAY_R307_2026-11-04.md), [R308 mutation](COMPUTE_CLUSTER_RTL_MUTATION_R308_2026-11-04.md), [R309 reset-owner sweep](COMPUTE_CLUSTER_RESET_REQUEST_OWNER_SWEEP_R309_2026-11-04.md), [R310 pending-read sweep](COMPUTE_CLUSTER_PENDING_READ_RESET_OWNER_SWEEP_R310_2026-11-04.md), and [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

The remaining partial requirements are `REQ-CL-006/010/014/015/017/018/019/027/028` and `REQ-PC-006/007`. R310 now retains a systemwide pending old-epoch read after each of the seven request-owner stalls, but does not cross the pending response owner against the held requester. Remaining work includes broader shared-SPAD ownership under faults/contention, downstream-stall fairness, Matrix FSM/integration dispositions, per-engine legal fault/descriptor/result contracts, reset/abort/completion interactions, full memory-scoreboard scope, and comparable performance evidence. The full list and evidence are in the RTM. **Do not declare `CL-DV-v1.0` signed off yet.**

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
