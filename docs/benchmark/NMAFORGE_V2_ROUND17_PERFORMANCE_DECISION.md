# NMAForge v2 — Round 17 Performance Decision

**Repository:** `cwu766485-ctrl/NMAForge`<br>
**Target:** `feature/npu-architecture-v2`<br>
**Reviewed base:** `79bdfbf550e6b2dccf9e0cb830b8dbab1f878459`<br>
**TinyNPU reference:** `8216c22b762011aa20c05fc2768423fd12dda59d`<br>
**Round 17 tested product source:** CNN and TinyNPU `84148b9abf35aa82d12e058814e260784d76d554`; H16 optimized replay `d2148e3107e0f602c10abb07eb58c3e21f170d53`; KV recovery test source `d2148e3107e0f602c10abb07eb58c3e21f170d53`.<br>
**Report/evidence packaging source:** `4b659e6f8a5b9128c7b068d12015784379433028` plus this report commit.

## Decision summary

| Work item | Result | Decision |
|---|---|---|
| H16 four-step incremental Decode baseline | PASS | Golden and KV hashes match on all four host-supplied tokens. |
| Exact LayerNorm length-16 fast path | PASS; target not met | Saves 4,224 cycles (10.66%) across four Decode steps. The 20% exploration target is not reached. |
| Two-layer CNN fused Row-Major output | PASS | New bounded `0x53` mode returns the legacy packed output exactly in 9,050 CMDQ cycles. |
| KV append Abort/Reset/retry checks | PASS for selected cases | Partial writes are not consumable until successful completion; no validity bitmap is present. |
| TinyNPU fixed GEMM/GEMV/Mini-CNN matrix | PASS for listed Golden checks | Some array and modeled-memory data is available; no full-system speedup claim is justified. |
| Round 17 overall | COMPLETE WITH OPEN LIMITATIONS | Keep the measured RTL candidate frozen. Do not infer full architecture closure, language-model quality, or ASIC PPA. |

## Baselines and measurement contract

The H16 workload is a deterministic synthetic projection task, not a trained language model. It uses Hidden=16, two heads, one layer, INT8, a four-token prefill and four incremental Decode steps. Tokens 4–7 are supplied by the host; RTL computes the projections, KV appends/reads, attention, normalization, residual and FFN path. It does not autonomously sample the next token and has no language-model accuracy claim.

The CNN workload is a deterministic fixed-seed two-layer pointwise INT8 inference workload, not a trained classifier. It contains 262,144 useful MACs/inference. All candidates use the same input, weights, seed, Independent Golden and final packed Row-Major INT8 output contract.

`Command Cycles` count the Top CMDQ execution interval. CNN `Preload + Command` adds measured AXI preload cycles. It still excludes host workload generation, descriptor programming and final host readback. H16 per-token cycles count the CMDQ stage; external input-token production is not included. SPAD byte counters cover accepted compute-engine accesses, not AXI preload traffic. Exclusive state-cycle buckets close to their command interval; overlapping request/response/divider observations are not added to those buckets.

## P0 — H16 Decode profile and LayerNorm optimization

### Four-token profile

Model SHA-256: `43ea1d5012e825d068a9dde137c18f2b7e0b95d725a753278331791d86c8ae61`. Seed: `20261117`. Baseline run: `nmaforge_r17_profile_gemm`; optimized run: `nmaforge_r17_h16_postlayout`. Both use GEMM mapping so the LayerNorm change is isolated from the prior GEMV mapping experiment.

| Decode token | Baseline cycles | Round 17 cycles | Saved | LayerNorm interval baseline → new | Softmax busy, unchanged | Requant busy, unchanged |
|---:|---:|---:|---:|---:|---:|---:|
| 4 | 9,791 | 8,735 | 1,056 (10.79%) | 4,039 → 2,983 | 534 | 1,492 |
| 5 | 9,865 | 8,809 | 1,056 (10.70%) | 4,039 → 2,983 | 608 | 1,492 |
| 6 | 9,939 | 8,883 | 1,056 (10.62%) | 4,039 → 2,983 | 682 | 1,492 |
| 7 | 10,020 | 8,964 | 1,056 (10.54%) | 4,039 → 2,983 | 763 | 1,492 |
| **Total / average** | **39,615 / 9,903.75** | **35,391 / 8,847.75** | **4,224 / 10.66%** | **16,156 → 11,932** | **2,587 total** | **5,968 total** |

The reciprocal cycle ratio is `39,615 / 35,391 = 1.1194×`; this is the measured Decode latency ratio for the same four-token workload, not an ASIC frequency-normalized speedup. Prefill remains 2,734 cycles in both runs, so prefill plus Decode falls from 42,349 to 38,125 cycles (9.97%).

The only optimization is an exact fast path for LayerNorm vectors of length 16. Since the divisor is 16, mean and variance division use sign/magnitude shifts while preserving truncation toward zero and the existing overflow check. Other lengths and RMSNorm retain the divider path; square-root, inverse-square-root, requantization, rounding and saturation behavior are unchanged. No sequential state or local buffer was added; the implementation adds a combinational bypass. Area and timing impact were not synthesized.

Per Decode step, LayerNorm busy cycles fall from 3,951 to 2,895; overlapping divider busy observations fall from 1,536 to 512. Softmax, Requant, Matrix, KV, memory traffic and dispatcher/completion behavior do not change. Thus the full 1,056-cycle per-token reduction comes from the LayerNorm path. Softmax and Requant optimizations were not made. Baseline SFU busy is 32,135/39,615 Decode cycles (81.1%); after the change it is 27,911/35,391 (78.9%). This is why the 20% target was missed: LayerNorm is improved, but Softmax, Requant and non-SFU stages remain.

The other exclusive command buckets are unchanged per step: Matrix 714 cycles (176 MAC-active, 26 request wait, 52 response wait, 184 writeback, 276 other), KV 394 cycles and dispatcher/completion gap 762 cycles. Therefore the baseline partition is `714 + 7,921 SFU + 394 + 762 = 9,791`; optimized is `714 + 6,865 + 394 + 762 = 8,735`. Useful MAC/cycle changes from 0.1732/0.1752/0.1771/0.1788 to 0.1942/0.1962/0.1981/0.1999 for tokens 4–7. Each step's SPAD traffic remains 8,160 read / 4,688 write bytes, and the reported Matrix active utilization remains 3.76–3.98%.

All 1,216 checked words and KV-after hashes match independently for each token. H16 was rerun after the later CNN RTL change at tested source `d2148e3`; all cycle numbers match the focused fast-path run. The focused SFU test passes 64 random-latency cases, including 9 error cases, late-fault, abort/watchdog, reset/recovery and parameter-latch checks. Top Smoke also passes after the CNN RTL change.

Prior Round 16 evidence showed GEMV mapping lowered mean H16 Decode latency by only 0.424% versus GEMM (42 cycles over the four steps). Round 17 did not rerun Cache/Prefetch or GEMV after the LayerNorm change, so that earlier small result is not presented as a Round 17 optimized-model ablation. Cache/Prefetch model-level contribution remains OPEN.

## P1 — CNN Fused Row-Major output

The old linear-row mode was limited to `N=4, M≤64`; it could not produce the full `M=512, N=16` output. The new opt-in mode uses `0x53 aux0[7]` for a bounded dense linear-row writeback with `N=16`, `M=4..512` in multiples of four, aligned destination, one instance, zero destination stride, and no transpose or tile-forwarding flags. The legacy Matrix-A output mode and the old `N=4` linear-row behavior are retained.

The implementation reuses the existing 128-bit fused line buffer to gather four 32-bit requantized output words into one 16-byte row segment. It changes row/column address and writeback control for this mode; it adds no register bank or buffer. No generic tensor reshape engine or separate layout-conversion command is used. Area/timing cost is NOT_RUN because this round did not run synthesis.

| Candidate | Descriptors | CMDQ cycles | Preload + CMDQ cycles | SPAD read / write bytes | SFU busy cycles | Full Row-Major output Golden |
|---|---:|---:|---:|---:|---:|---|
| Legacy `0x30→0x36→0x30→0x36` | 4 | 61,310 | 197,725 | 98,304 / 81,920 | 53,252 | PASS, 20,480 words |
| First layer fused `0x53→0x30→0x36` | 3 | 35,184 | 171,479 | 65,536 / 49,152 | 26,625 | PASS, 20,480 words |
| Both layers fused + linear-row `0x53→0x53` | 2 | **9,050** | **145,225** | **32,768 / 16,384** | **0** | **PASS, 20,480 words** |

All three candidates produce the same final output SHA-256 `6f81ea743327c2b7daa5d4e11e8e2e88848398b99bfaca97d170c570ccc3170e`. The optimized candidate's Golden file SHA-256 is `29653c0200a936355f8bcf3a35dd973007272696ec8c288283dfa6bd1d2f68ed`.

Legacy → both-layer fused reduces command cycles by 85.24% (6.78× command-window cycle ratio), but preload + command falls by 26.55% only: `197,725 → 145,225`. First-layer fused → both-layer fused reduces command cycles by 74.28% (3.89×) and preload + command by 15.31%. The ratio is smaller at the load-plus-command boundary because AXI preload remains about 136k cycles. These figures exclude workload generation, descriptor programming and final host readback.

Useful MAC/cmd-cycle rises from 4.2757 to 7.4507 to 28.9662. The array completes 1,024 full-array MAC-active cycles in each mode; `100% array utilization` is only utilization during those active cycles. The active fraction of the CMDQ window is 1.67%, 2.91% and 11.31%, respectively. Preloaded scratchpad bytes are 90,944 / 90,864 / 90,784. The workload uses deterministic inference weights, so no classifier accuracy is claimed.

## P2 — KV append interruption/recovery

Run `nmaforge_r17_kv_append_safety_s20261117`, seed `20261117`, VCS `V-2023.12-SP1_Full64`. No product KV RTL changed. The selected flags=1 scatter-append test passes:

- Abort after one accepted append element: partial prefix observed and test passes.
- Reset after two accepted elements: partial prefix observed and test passes.
- Retry at the same position: all eight features are restored; neighboring byte lanes are preserved.
- Repeated successful append at the same position: same-position replacement passes.
- Out-of-capacity token index: rejected before a SPAD request or side effect.

The KV engine has no per-token validity bitmap. The tested contract is completion-gated: consumers may use a token position only after the append descriptor completes successfully. After Abort/Reset with a partial physical prefix, software retains that position, retries the append, and schedules no consumer before successful completion. This is a focused recovery test, not broad append/reset coverage closure.

## P3 — TinyNPU pinned benchmark

Run ID `NMAFORGE-R17-FULL-TINY-S20261117`, seed `20261117`; NMAForge source `84148b9abf35aa82d12e058814e260784d76d554`, TinyNPU source `8216c22b762011aa20c05fc2768423fd12dda59d`. Both sides pass the listed independent integer Golden checks.

### GEMM

| Shape | NMAForge measured Matrix+behavioral-SPAD cycles | TinyNPU array RTL cycles | TinyNPU normalized cycles* | NMAForge / normalized Tiny cycles |
|---|---:|---:|---:|---:|
| 16×16×16 | 174 | 52 | 151 | 1.1523× |
| 16×16×32 | 248 | 100 | 231 | 1.0736× |
| 32×32×64 | 1,390 | 790 | 1,305 | 1.0651× |

### GEMV

| Shape | NMAForge measured cycles | TinyNPU direct array cycles | TinyNPU normalized cycles* | NMAForge / normalized Tiny cycles |
|---|---:|---:|---:|---:|
| 1×13×17 | 70 | 100 | 126 | 0.5556× |
| 8×16×19 | 149 | 100 | 170 | 0.8765× |
| 16×16×19 | 256 | 100 | 218 | 1.1743× |
| 16×16×65 | 627 | 244 | 459 | 1.3660× |

`*` TinyNPU exposes a direct array test but no scratchpad port for this harness. The normalized number adds a modeled 16-byte/cycle memory service with one-cycle read response and serializes input read, array execution, output write and accumulator clear. NMAForge numbers are measured Matrix controller plus a one-cycle behavioral SPAD. These are useful cycle/traffic evidence under a stated model, but not matched full-system RTL endpoints. Ratios above one mean NMAForge used more cycles in this mixed measured/modeled endpoint; none is reported as an ASIC or product speedup. TinyNPU's native direct-array-only result is shown separately.

GEMV read traffic on NMAForge is 304/560/816/2,368 bytes for the four shapes; write traffic is 52/512/1,024/1,024 bytes. Its wait counters overlap and must not be summed as exclusive phase cycles. The M=1 normalized modeled case is lower for NMAForge, while the M=16 cases are higher; memory/controller differences prevent a system-level conclusion.

### Common Mini CNN

Both sides run `conv1x_mini.onnx`, model SHA-256 `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`, input seed 99 and input SHA-256 `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`. The graph has 1,872 logical MACs; both Golden checks pass, including all four final output bytes.

NMAForge measures 1,985 compute cycles plus 1,080 host-layout cycles (3,065 reported phase cycles), 3,360 compute SPAD read bytes and 1,600 write bytes. Its interval is two CMDQ windows and excludes preload, descriptor programming and final host read. TinyNPU reports 4,781 ONNX graph-smoke cycles using its graph dispatcher and testbench DMA/SRAM shim; input setup is excluded. Since the graph/runtime and memory windows are not identical, no CNN speedup is calculated. The larger 262,144-MAC pointwise workload is not claimed as a TinyNPU matched CNN.

### Reproducibility environment

VCS `V-2023.12-SP1_Full64`; Verilator `5.052 2026-09-05 rev v5.052`; Python `3.12.13`; NumPy `2.4.6`; ONNX `1.17.0`. No ASIC PPA is included in this round.

## Exact commands and evidence

Run commands from the repository root unless the command includes `cd`:

```bash
# H16 baseline and exact length-16 LayerNorm replay
cd dv/subsystem/top_smoke/sim && make ai_h16_incremental_decode \
  AI_H16_INCREMENTAL_RUN=/tmp/nmaforge_r17_profile_gemm \
  AI_H16_INCREMENTAL_POLICY=gemm AI_H16_INCREMENTAL_SEED=20261117
cd dv/subsystem/top_smoke/sim && make ai_h16_incremental_decode \
  AI_H16_INCREMENTAL_RUN=/tmp/nmaforge_r17_h16_postlayout \
  AI_H16_INCREMENTAL_POLICY=gemm AI_H16_INCREMENTAL_SEED=20261117

# Focused exact LayerNorm/SFU tests and Top Smoke
cd dv/block/compute/sfu/sim && make random-latency-test \
  PYTHON=python3.12 SEED=20261117 OUT_DIR=/tmp/nmaforge_r17_sfu_fastpath
cd dv/subsystem/top_smoke/sim && make ai_smoke \
  AI_RANDOM_CASES=20 AI_SEED=1717 SEED=1717

# KV append Abort/Reset/retry tests
cd dv/block/compute/cnn_kv/sim && make random-latency-test \
  PYTHON=python3.12 SEED=20261117 OUT_DIR=/tmp/nmaforge_r17_kv_append_safety

# Generate and verify the Row-Major fused CNN workload
python3.12 benchmark/representative/generate_pointwise_cnn_workload.py \
  --fusion-mode legacy --seed 20261108 \
  --out-dir /tmp/nmaforge_r17_cnn_legacy
python3.12 benchmark/representative/verify_pointwise_cnn_workload.py \
  --workload-dir /tmp/nmaforge_r17_cnn_legacy
python3.12 benchmark/representative/generate_pointwise_cnn_workload.py \
  --fusion-mode first --seed 20261108 \
  --out-dir /tmp/nmaforge_r17_cnn_first
python3.12 benchmark/representative/verify_pointwise_cnn_workload.py \
  --workload-dir /tmp/nmaforge_r17_cnn_first
python3.12 benchmark/representative/generate_pointwise_cnn_workload.py \
  --fusion-mode both_linearized --seed 20261108 \
  --out-dir /tmp/nmaforge_r17_cnn_both_linearized
python3.12 benchmark/representative/verify_pointwise_cnn_workload.py \
  --workload-dir /tmp/nmaforge_r17_cnn_both_linearized

# Top CNN: same workload seed/weights, full-output checks in each mode
cd dv/subsystem/top_smoke/sim && make ai_representative_cnn \
  AI_REPRESENTATIVE_FUSION_MODE=legacy \
  AI_REPRESENTATIVE_DESC_COUNT=4 AI_REPRESENTATIVE_SEED=20261108 \
  AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r17_cnn_legacy_toprun \
  AI_REPRESENTATIVE_PYTHON=python3.12
cd dv/subsystem/top_smoke/sim && make ai_representative_cnn \
  AI_REPRESENTATIVE_FUSION_MODE=first \
  AI_REPRESENTATIVE_DESC_COUNT=3 AI_REPRESENTATIVE_SEED=20261108 \
  AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r17_cnn_first_toprun \
  AI_REPRESENTATIVE_PYTHON=python3.12
cd dv/subsystem/top_smoke/sim && make ai_representative_cnn \
  AI_REPRESENTATIVE_FUSION_MODE=both_linearized \
  AI_REPRESENTATIVE_DESC_COUNT=2 AI_REPRESENTATIVE_SEED=20261108 \
  AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r17_cnn_both_linearized_toprun \
  AI_REPRESENTATIVE_PYTHON=python3.12

# Complete fixed TinyNPU comparison matrix
env BENCH_RUN_ID=NMAFORGE-R17-FULL-TINY-S20261117 SEED=20261117 \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
  TINY_NPU_ROOT=/tmp/nmaforge_research_tinynpu_8216c22 \
  TINYNPU_WORK_ROOT=/tmp/nmaforge_r17_full_tiny \
  TINYNPU_BENCH_OUT=/tmp/nmaforge_r17_full_tiny JOBS=4 \
  bash benchmark/tinynpu/run_comparison.sh
```

The CNN mode matrix and all commands are also captured in each archived manifest/log. Machine-readable records are in [`ROUND17_LN_FASTPATH_PROFILE.csv`](round17_evidence/ROUND17_LN_FASTPATH_PROFILE.csv), [`ROUND17_CNN_FUSION_COMPARISON.csv`](round17_evidence/ROUND17_CNN_FUSION_COMPARISON.csv), [`gemm_results.csv`](../../benchmark/tinynpu/gemm_results.csv), [`gemv_results.csv`](../../benchmark/tinynpu/gemv_results.csv), and [`cnn_results.csv`](../../benchmark/tinynpu/cnn_results.csv). Selected compile/run logs, descriptor manifests, memory images and Golden images are under [`round17_evidence/`](round17_evidence/). `SHA256SUMS.txt` in that directory is the integrity manifest.

## Open limitations and freeze recommendation

1. The H16 task has host-supplied tokens and synthetic projection labels; it is not language-model inference. Model-quality metrics are therefore NOT APPLICABLE.
2. The LayerNorm fast path improves Decode by 10.66%, below the 20% target. Softmax and Requant remain unchanged; Cache/Prefetch was not re-ablationed against the optimized LayerNorm source.
3. The 262K-MAC CNN uses deterministic inference weights, not trained classifier weights. AXI preload dominates the combined measured interval, so command-window gains overstate end-to-end improvement.
4. The row-major mode has functional evidence and a 2-command full-output result, but no mapped area, timing, power or formal proof. The accepted mode is deliberately restricted to dense aligned N=16 output.
5. KV interruption checks cover selected append phases only. Token validity is a software completion contract, not a hardware validity bitmap.
6. TinyNPU matched shapes pass Golden but use direct array RTL plus modeled Tiny memory service. No matched Top-to-Top CNN/Transformer endpoint, common full graph, or system speedup has been established.
7. Full coverage closure, ASIC PPA and language-model quality remain outside this round.

The measured results are sufficient to freeze this Round 17 research candidate and stop this bounded task. Further product RTL changes are not justified until a real trained model or a matched full-system endpoint shows a specific remaining bottleneck. This is not a v2 sign-off or tapeout-readiness claim.
