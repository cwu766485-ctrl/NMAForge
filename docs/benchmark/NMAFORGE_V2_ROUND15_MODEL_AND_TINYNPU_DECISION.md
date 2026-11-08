# NMAForge v2 — Round 15 Model and TinyNPU Decision

Date: 2026-11-08
Disposition: **PARTIAL**. The fixed H16 KV-snapshot replay was re-run and passed on the reviewed source SHA. True incremental multi-token decode, a Round 15 CNN conversion improvement, and matched TinyNPU model runs were not completed. No unverified RTL change is included.

## 1. Frozen source and run evidence

| Item | Value |
|---|---|
| Repository / target | `cwu766485-ctrl/NMAForge`, `feature/npu-architecture-v2` |
| Reviewed and tested source SHA | `feee5de020411ebbb15f5cc2af02cbd1eb8d2466` |
| Product RTL tree SHA | `27dba680a250779ee3d95d11381987c9b1dddc11` |
| H16 mapper blob | `9228a9ac5b47cff3067c01f390ae668b8312f5a3` |
| Top smoke testbench blob | `60ecb56d94201de7c8a30534af0a51b766786f2d` |
| TinyNPU pinned source SHA | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64` |
| Python | `3.12.13` (NumPy is unavailable in this interpreter) |
| H16 Run ID / seed | `nmaforge_r15_h16_baseline_s20261115` / `20261114` |
| H16 run log / SHA-256 | `/tmp/nmaforge_r15_h16_baseline_s20261115/run.log` / `f8d0b67212326e25d3e91c548086564081d9d1d9f5a31ffb5dd2ee7c9cc56caa` |
| H16 compile log / SHA-256 | `/tmp/nmaforge_r15_h16_baseline_s20261115/compile.log` / `6c2b4d0976468d933c7b33ee1d58cfab5c1c1f658c4581b12d634b0edc7b1908` |

The Round 14 CNN runs are retained as historical measurements from test SHA `ede0ed937b49fea66483d3afc5eff1fca9bd7795`. That commit is the parent of the reviewed SHA; the intervening commit only adds the Round 14 report. The product RTL tree is identical, so the CNN RTL evidence remains applicable, but it was not re-run in Round 15. Raw rows and hashes are in [`round15_results.csv`](../../benchmark/representative/round15/round15_results.csv); the structured summary is in [`round15_results.json`](../../benchmark/representative/round15/round15_results.json).

## 2. Phase 1 — H16 incremental decode

### Fixed baseline replay: PASS

The H16 model has Hidden=16, two heads, head dimension 8, one layer, sequence length 8, and signed INT8. On the reviewed SHA, Top completed 102 descriptors and checked 3,264/3,264 Golden words. The workload contains a 70-descriptor prefill followed by a 32-descriptor replay for token 7 against the already-populated eight-token KV snapshot.

| Phase | Descriptors | Useful MACs | Command cycles |
|---|---:|---:|---:|
| Prefill | 70 | 14,336 | 21,030 |
| Token-7 KV-snapshot replay | 32 | 1,280 | 8,578 |
| Combined | 102 | 15,616 | 29,608 |

Additional counters: preload 38,087 cycles / 25,392 bytes; SPAD 22,176 read bytes and 13,120 write bytes; SFU busy 26,424 cycles; KV busy 568; Matrix MAC-active 264; `0.5274` useful MAC per command cycle; array utilization 23.11%. Exclusive phase counters close to the 29,608 command cycles. The model weights are reproducible synthetic projection weights (model SHA `ea5d2a5bc104d5d6255183133198d0e9193b82decc2d3e35abbe772a1c486810`), not language-model weights. No next-token quality or language accuracy is established.

### Incremental token progression: NOT RUN / BLOCKED_ENV

This workload does not execute a newly produced token embedding through fresh Q/K/V projections, append that step's K/V to the cache, and consume the updated cache on a later step. Its 8,578-cycle replay is therefore **not** a per-token autoregressive latency result. Round 15 has no valid measurements for four dependent Decode Steps, cache append/position progression, rolling-window replacement, or model-level GEMV/cache/prefetch ablation.

We explored a bounded strided KV write primitive as a possible K-cache append mechanism. VCS did not reach compile or simulation: the focused attempt reported license connection failures; the bounded retry ended with timeout exit 124 and no `simv`. The exploratory RTL/interface edits were reverted. No change to the KV ABI or product RTL is part of this delivery. Exact attempted commands:

```bash
make random-latency-test OUT_DIR=/tmp/nmaforge_r15_kv_scatter_seed20261115 SEED=20261115
timeout 90s make random-latency-test OUT_DIR=/tmp/nmaforge_r15_kv_scatter_retry_s20261116 SEED=20261116
```

Logs: `/tmp/nmaforge_r15_kv_scatter_seed20261115/compile.log` and `/tmp/nmaforge_r15_kv_scatter_retry_s20261116/compile.log`. No simulator binary or functional result was produced. A further attempt is outside this bounded round.

The remaining implementation is not just a testbench-provided KV image: each Decode step needs its own embedding lookup from the prior hardware output, Q/K/V execution, K/V cache mutation with correct position/head layout, reads from that updated state, and per-step Golden checkpoints. The existing 102-descriptor fixture does not demonstrate these semantics. Continuous progression remains open.

## 3. Phase 2 — Transformer ablation

**NOT RUN.** The replay contains M=1 GEMV projections, but there is no same-input GEMM baseline or controlled Cache/Prefetch variant for a true incremental Decode. Therefore no model-level speedup is attributed to Shape-Adaptive GEMV. Batch M=8/16 reuse gains are not available from this H16 run and would not be evidence for single-token Decode. Legacy/optimized SFU ablation was also not performed.

## 4. Phase 3 — CNN output-compatible dataflow

Round 14 fixed-seed results use the same 262,144-useful-MAC, two-layer pointwise INT8 workload, independent Golden and 128 KiB behavioral SPAD. The workload uses deterministic random inference weights, not trained CNN weights.

| Candidate | Output contract | Commands | CMDQ cycles | Preload + CMDQ | SPAD read / write | Golden |
|---|---|---:|---:|---:|---:|---|
| Legacy, 4 commands | Row-major packed INT8 | 4 | 61,310 | 197,725 | 98,304 / 81,920 B | 20,480/20,480 PASS |
| First-layer fused | Row-major packed INT8 | 3 | **35,184** | **171,479** | 65,536 / 49,152 B | 20,480/20,480 PASS |
| Both fused, native layout | Matrix-A tile layout; incompatible with public output | 2 | 9,050 | 145,225* | 32,768 / 16,384 B | Internal tile Golden only |
| Both fused + explicit conversion | Row-major packed INT8 | 4 | 39,686 | 176,485 | 81,920 / 57,344 B | 20,480/20,480 PASS |

`*` Internal-layout probe only; excluded from completed-inference comparisons.

First-layer fusion remains the best verified output-compatible path. Versus Legacy it reduces CMDQ cycles by 42.61% (1.7426× command-window ratio), and preload-plus-command cycles by 13.27% (1.1531×). It removes 26,627 SFU busy cycles and reduces SPAD reads by 33.33% and writes by 40.00%. The two-layer fused native result cannot be compared as a completed inference because its final layout is incompatible. Explicit conversion restores Row-Major Golden but takes 4,502 more CMDQ cycles than first-layer fusion (12.80% slower) and 5,006 more preload-plus-command cycles (2.92% slower). The 30,636-cycle difference between native and converted sequences is not an isolated conversion-latency measurement.

No DMA-address remap or small output-layout mode was implemented in Round 15. No evidence shows a complete output-compatible path below 35,184 CMDQ cycles. Training-weight CNN, 3×3 Conv, Im2col/Lowering, and DMA/Compute overlap measurements are **NOT RUN**. The 262K workload is not a trained classifier and has no accuracy claim.

Round 14 Run IDs, data hashes, exact commands, and detailed profile counters remain in [`NMAFORGE_V2_ROUND14_RESEARCH_CLOSURE.md`](../verification/NMAFORGE_V2_ROUND14_RESEARCH_CLOSURE.md) and [`round14_results.csv`](../../benchmark/representative/round14/round14_results.csv). The test SHA was `ede0ed937b49fea66483d3afc5eff1fca9bd7795`, RTL tree `27dba680a250779ee3d95d11381987c9b1dddc11`, seed `20261108`; Run IDs are `nmaforge_r14_cnn_legacy_final_ede0_s20261108`, `nmaforge_r14_cnn_first_final_ede0_s20261108`, `nmaforge_r14_cnn_both_final_ede0_s20261108`, and `nmaforge_r14_cnn_both_convert_final_ede0_s20261108`.

## 5. Phase 4 — TinyNPU matched benchmark

Pinned TinyNPU source remains `8216c22b762011aa20c05fc2768423fd12dda59d`; no Round 15 same-endpoint GEMM/GEMV, CNN, or Transformer comparison was executed. The prior NMAForge Top+behavioral-SPAD measurements and TinyNPU direct-array/graph measurements have different control, memory, and timing boundaries. They are not divided to produce a system speedup. The `conv1x_mini.onnx` historical comparison is not reused as evidence for the 262K CNN or H16 model.

The fixed Python 3.12.13 interpreter lacks NumPy, and no TinyNPU dependency rebuild or Round 15 model run is recorded. This phase is **NOT RUN**; NMAForge-versus-TinyNPU relative performance is unknown for the requested workloads.

## 6. Innovation outcomes and decision

| Innovation / question | Round 15 conclusion |
|---|---|
| Shape-Adaptive GEMV | M=1 appears in fixed replay, but no incremental Decode and no GEMM/cache/prefetch control pair; model-level benefit is unproven. |
| Fused epilogue / dataflow | First-layer fusion is the best complete-output CNN path: 42.61% fewer command cycles and 13.27% fewer preload+command cycles than Legacy. Double fusion needs conversion and loses to first-layer fusion. |
| Continuous autoregressive model | Not demonstrated; synthetic projection task only, no next-token quality measurement. |
| Trained multi-layer CNN / 3×3 Conv | Not demonstrated. |
| TinyNPU leadership | No matched Round 15 endpoint; no winner or speedup claim. |

Round 15 is **PARTIAL**, not a research-complete baseline. The main remaining work is: implement and VCS-validate incremental H16 Decode with per-step KV mutation/checks; find a complete-output CNN layout path faster than the current 35,184-cycle candidate; run trained CNN/3×3 workload on Top; restore a reproducible TinyNPU environment and align endpoints. ASIC/PPA, broad DV closure, and full language-model claims remain outside scope.

## 7. Reproduction

H16 fixed replay, run at source SHA `feee5de020411ebbb15f5cc2af02cbd1eb8d2466`:

```bash
cd dv/subsystem/top_smoke/sim
make ai_h16_transformer_top \
  AI_H16_TRANSFORMER_RUN=/tmp/nmaforge_r15_h16_baseline_s20261115 \
  AI_H16_TRANSFORMER_PYTHON=python3.12 \
  AI_H16_TRANSFORMER_SEED=20261114
```

Expected result: `REPRESENTATIVE_MODEL_PASS desc=102 ... golden_words=3264 ... command_cycles=29608 ... decode_command_cycles=8578 ...`. Run and compile log hashes are in Section 1. The round-specific outcome table is machine-readable in `round15_results.csv` and `round15_results.json`.

This round changed no product RTL, did not complete true multi-token Decode, and makes no TinyNPU speedup claim. The next action is not started here.
