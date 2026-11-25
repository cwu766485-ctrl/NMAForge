# RTL Code Coverage and Uncovered Areas

**Review date:** 2026-11-12

**Checkout:** `3ec0be579c6847d4ae707a30e5e30ccd64ab0813`
**Conclusion:** the repository does not contain one current, whole-chip DUT-only coverage merge for this checkout. The latest available broad DUT code-bin statistics are an October 2026 VCS/URG merge of `rtl/compute`; newer November 12 runs cover selected DMA/SPAD work but their dashboard totals include UVM and testbench code. The numbers below are therefore scoped evidence, not a current full-chip percentage.

## Counted coverage bins

The 2026-10-23 multi-test merge covered all 23 `rtl/compute` source definitions. Twenty modules had executable code bins; three wiring-only wrappers had no applicable line/condition/FSM/branch bins. URG merged 29 test instances using `-flex_merge modules`: five top DUT seeds plus three seeds each for focused CNM, CNN/KV, Matrix datapath/core, SFU, FP wrapper/add-sub and mixed-FP tests. The report states `V-2023.12-SP1` VCS/URG.

| Metric | Hit / total | Hit | Unhit |
|---|---:|---:|---:|
| Line | 2,002 / 2,160 | 92.69% | 158 |
| Condition | 1,449 / 1,610 | 90.00% | 161 |
| FSM transition | 205 / 375 | 54.67% | 170 |
| Branch | 681 / 780 | 87.31% | 99 |

These are weighted bin totals across the `rtl/compute` merge. They are not counts of source lines, functional requirements, or all project RTL. The five-seed top-only `rtl/compute` subset is lower: line 1,639/1,956 (83.79%), condition 956/1,440 (66.39%), FSM 156/375 (41.60%), branch 494/714 (69.19%).

## Modules with raw misses

Percentages below are the recorded merged DUT module-definition results. Any metric below 100% has unhit bins. `N/A` means URG found no applicable bins for that metric, not zero percent.

| RTL module | Line | Condition | FSM | Branch |
|---|---:|---:|---:|---:|
| `ai_banked_cnm_core` | 97.22% | 87.76% | 72.22% | 83.87% |
| `ai_bank_local_controller` | 96.88% | 94.12% | 65.22% | 81.08% |
| `ai_conv3x3_linebuffer_core` | 100.00% | 84.42% | 62.07% | 97.62% |
| `ai_kv_cache_engine` | 100.00% | 98.28% | 80.00% | 96.30% |
| `ai_mixed_precision_dot_fp32_core` | 97.97% | 95.61% | 85.71% | 91.23% |
| `ai_bf16_mul_fp32` | 98.61% | 97.22% | N/A | 94.12% |
| `ai_fp16_mul_fp32` | 100.00% | 96.77% | N/A | 100.00% |
| `ai_fp32_add` | 88.68% | 88.51% | N/A | 82.35% |
| `ai_fp32_accumulator` | 100.00% | N/A | N/A | 100.00% |
| `ai_fp16_bf16_addsub_core` (FP16 parameters) | 99.02% | 95.29% | N/A | 96.97% |
| `ai_fp16_bf16_addsub_core` (BF16 parameters) | 99.02% | 97.65% | N/A | 96.97% |
| `ai_tensor_matrix_core` | 87.19% | 88.03% | 66.67% | 84.31% |
| `ai_tensor_matrix_datapath` | 100.00% | 100.00% | N/A | 100.00% |
| `ai_tensor_sfu_core` | 84.47% | 88.62% | 100.00% | 81.21% |
| `ai_tensor_sfu_math` | 100.00% | 100.00% | N/A | 100.00% |
| `ai_unsigned_divider` | 91.43% | 88.89% | N/A | 87.50% |
| `ai_integer_sqrt` | 96.55% | 83.33% | N/A | 90.00% |
| `ai_int8_compute_core` | 92.94% | 79.47% | 52.78% | 74.58% |
| `ai_int8_datapath` | N/A | 88.89% | N/A | 77.78% |
| `ai_tile_pipeline` | 92.35% | 80.00% | 25.00% | 87.80% |

Three wrappers with no executable bins: `ai_bf16_dot_fp32_core`, `ai_bf16_addsub`, and `ai_fp16_addsub`.

Outside `rtl/compute`, the same historical top-focused merge recorded `ai_parallel_compute_dispatcher` at 91.70% line / 66.91% condition / 75.00% FSM / 71.43% branch, and `ai_compute_spad_mux` at 100.00% / 75.00% / N/A / 100.00%. The separate Matrix default-profile FSM result is 49/53 transitions (92.45%), with four raw misses reviewed as guarded error/fallback paths; the alternate prefetch-disabled profile exercises one fallback edge, but profiles were not merged due to different compile-time coverage shapes.

## Newer focused evidence and limits

On 2026-11-12, URG processed three `dma_spad_subsystem` test VDBs and reported 72.11% line, 58.27% condition, 52.91% FSM and 61.79% branch for the overall test hierarchy. The top testbench instance was 87.65% / 61.64% / 52.91% / 79.18%. A separate DMA gate VDB reported 69.57% / 60.81% / 41.18% / 56.31% at module-definition level. These dashboards include verification hierarchy and are not comparable to the focused DUT-only module merge above; use them only as evidence that those particular test suites still leave raw bins unhit. Their files are under `/tmp/nmaforge-closeout-runs/` and are not checked-in reproducibility artifacts.

The current focused Compute Cluster testpoint result of 29/29 applicable functional variables is not code coverage. Completion-read is structurally N/A for the write-only completion client. Whole-top URG totals that mix DUT, assertions, testbench and UVM must not be presented as DUT-only coverage.

## Uncovered source locations

The checked-in records provide aggregate raw-bin counts, per-module percentages, and selected FSM/functional-bin dispositions. They do not preserve the merged URG source-line/condition/branch detail database for the 2026-10-23 aggregate. Consequently, an exhaustive list of individual uncovered RTL line numbers cannot be reconstructed from tracked artifacts without the original VDBs; the exact current-checkout gap list also requires a fresh coverage-enabled run and merge. No source lines are inferred as uncovered from percentages alone.

**Primary evidence:** [Compute Engine Status](COMPUTE_ENGINE_STATUS.md), [Verification Matrix](../../dv/VERIFICATION_MATRIX.md), and [Compute Cluster Final Audit](COMPUTE_CLUSTER_V1_FINAL_AUDIT.md). The broadest detailed statistics are in the `Complete rtl/compute module coverage` section of Compute Engine Status.
