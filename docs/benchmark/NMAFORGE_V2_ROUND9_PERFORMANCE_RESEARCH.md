# NMAForge v2 Round 9 — Performance Research Results

**Status: `PARTIAL_RESEARCH_BASELINE`**

**Reviewed baseline:** `7721302b21b575fa130d023010201216ea69727c`

**Product RTL/test candidate:** `74402ba991285cb4403cb50737013362f5a2af53`

**Published equivalent source commit:** `13f94abf59c3dbea833ad4bbe227ef5cab4df503` (GitHub API commit; its source tree is identical, tree `56813cb32844bb01683c6710c57d19bce136028a`). Run logs retain the local measured source SHA above.

**TinyNPU reference:** `8216c22b762011aa20c05fc2768423fd12dda59d`
**Run date:** 2026-11-07

This round completed two bounded SFU changes, a trained H=4 Top replay, a new
three-tile Matrix/DMA correctness and overlap probe, current-source Matrix
GEMM/GEMV runs, and a same-model `conv1x_mini` replay. It did not complete a
representative H=16/32 Transformer, a >=100K-useful-MAC CNN, or a common
Transformer benchmark on TinyNPU. No synthesis or PPA was run, as required by
the Round 9 scope.

## 1. Transformer SFU optimization

### Measurement boundary and model

The paired run uses deterministic trained INT8 weights with SHA-256
`001550dbadb816e66f737f5f6cba0819f51821c71a78d84861d62dc80dd8511f`, seed
`20261107`, and the same 86-descriptor H=4, one-layer, one-head fixture in both
runs. The training flow requested 20,000 steps and stopped at step 1,178; it
reports 16/16 training examples, 690/1008 held-out examples, 4/4 prefill task
predictions, and 1/1 decode task prediction. This is a tiny synthetic cyclic
next-token task, not a pretrained language model or a representative Transformer.

The measured endpoint is Top doorbell acceptance through final CPLQ tail
commit. Both runs completed all 86 descriptors and matched 60 intermediate and
final tensors, including K/V cache images. The optimized run emitted 306
`PASS: Transformer` checks and no Transformer mismatch.

| Phase | Baseline cycles | Optimized cycles | Saved | Reduction | Read bytes baseline → optimized |
|---|---:|---:|---:|---:|---:|
| Prefill | 5,682 | 5,259 | 423 | 7.44% | 1,936 → 1,664 |
| Single-token Decode | 5,715 | 5,110 | 605 | 10.59% | 1,880 → 1,640 |
| Prefill + Decode | 11,397 | 10,369 | 1,028 | 9.02% | 3,816 → 3,304 |

Write traffic was unchanged at 2,120 bytes for the full run. Same-endpoint
decode ratio is 1.1184x and full-run ratio is 1.0991x. These are H=4 Top
simulation ratios, not TinyNPU comparisons or ASIC latency claims.

### Per-command bottlenecks and changes

| Decode command class | Baseline interval | Optimized interval | Change | Supporting profile |
|---|---:|---:|---:|---|
| LayerNorm (`0x38`, eight rows) | 2,631 | 2,503 | −128 / −4.87% | accepted reads 160 → 96; response-wait event 160 → 96; divider and sqrt busy unchanged |
| Causal Softmax (`0x39`, four rows) | 1,303 | 826 | −477 / −36.61% | pass-2 1,136 → 659; divider busy 1,024 → 547; operand reads and output writes unchanged |
| LayerNorm + Softmax | 3,934 | 3,329 | −605 / −15.38% | matches the total Decode cycle reduction |

**LayerNorm fast path:** for vector length ≤16, the SFU caches the first pass's
16 signed 32-bit input values and reuses them for variance and normalization.
It adds 512 bits of local data storage plus a mode flag. It keeps the existing
mean, variance, divider, square-root, quantization, and writeback arithmetic;
lengths above 16 retain the old reread path. For the H=4 Decode, arithmetic
busy time did not change: 1,536 divider cycles and 256 sqrt cycles remain in
the overlapping event counters. The savings come from fewer SPAD rereads and
shorter FSM passes.

**Softmax divider fast path:** `ai_unsigned_divider` now optionally counts
significant dividend bits and skips only the leading zero iterations. The
quotient/remainder recurrence and Q15 output are unchanged. The option is
asserted only for Softmax and causal Softmax; other users retain the full-width
division. The 64-bit leading-zero detection is combinational and was not
synthesized in this round, so its area and timing cost are unknown.

The profiler marks pass0/pass1/pass2/math/other as exclusive FSM buckets.
SPAD wait, divider busy, and sqrt busy are overlapping observations; they must
not be summed with those buckets. Top-level cycle buckets close exactly. The
per-phase accepted-read instrumentation differs from the top read-byte counter
by 16 bytes at the prefill/decode boundary, while the aggregate read-byte
reduction closes at 512 bytes. Therefore the report uses the command profile
for LayerNorm's accepted-read change and the Top aggregate for total traffic.

### Validation and scope

The current candidate passed the focused SFU random-latency test (64 vectors,
9 injected error cases, late fault, abort/watchdog, reset-fault combination,
reset recovery, and retained FSM reset/abort probes) with seed `20261107`.
The complete Top Smoke passed with `AI_RANDOM_CASES=0`, and the trained H=4 Top
run passed its independent outputs and KV-cache checks. These are focused
functional checks; this does not close full DV or prove broad numeric coverage.

In optimized Decode, 3,932 cycles are SFU-busy and 2,248 cycles are in the
combined no-engine/control/dispatch bucket. The profiler does not separate
descriptor dispatch from other control idle time. The given Round 8 baseline
reports 297 cycles for all Decode GEMM commands; even eliminating all 297
cycles would cap an idealized speedup at about 1.055x (5.2% cycle reduction)
for the 5,715-cycle baseline. This reinforces that SFU, not the MAC array, was
the dominant H=4 bottleneck.

## 2. Matrix/DMA overlap correctness and timing

A new real-Top task runs three distinct 4×4×4 INT8 tiles through the production
Matrix tile path and DMA ping-pong buffers. The independent Golden contains 192
useful MACs. The test checks all 48 INT32 external output words, both local
buffer rows, and 3/3 completion count.

| Mode | Total cycles | DMA-active | Matrix-active | Overlap counter | Stall counter | Golden |
|---|---:|---:|---:|---:|---:|---|
| Serialized, one tile per launch | 561 | 108 | 444 | 0 | 9 | PASS |
| Three-tile ping-pong | 488 | 108 | 447 | 72 | 5 | PASS |

Ping-pong saves 73 cycles (13.01%) for this small fixed workload. The total
cycle counter is the comparison value; the event counters are descriptive and
are not assumed to be mutually exclusive. This does not establish scaling to
large CNN tiles.

The reported Round 8 four-mismatch probe does not appear in the archived Round
8 Top Smoke log, and its exact dedicated failure log/fixture was not present in
the worktree. The new Round 9 reproducer passes, but it does not prove the root
cause of that earlier, unrecovered failure. Accordingly, the **new bounded
probe is PASS; closure of the exact Round 8 failure is PARTIAL**.

## 3. Fixed TinyNPU benchmark

### GEMM and GEMV endpoint

NMAForge was rerun on the Round 9 candidate with VCS and its 16×16 Matrix core,
controller, and four-bank behavioral SPAD. TinyNPU at the pinned SHA was replayed
from the cached direct-array Verilator binaries. The fixed operand formulas and
Independent INT32 Golden are shared by both array tests.

| Workload | Shape | Useful MACs | NMAForge controller + behavioral SPAD | TinyNPU Direct Array |
|---|---|---:|---:|---:|
| GEMM | 16×16×16 | 4,096 | 185 cycles; 22.14 MAC/cycle; 8.65% array utilization; 512 B read / 1,024 B write | 52 cycles; 78.77 MAC/cycle; 30.77% |
| GEMM | 16×16×32 | 8,192 | 270 cycles; 30.34 MAC/cycle; 11.85%; 1,024 B read / 1,024 B write | 100 cycles; 81.92 MAC/cycle; 32.00% |
| GEMM | 32×32×64 | 65,536 | 1,381 cycles; 47.46 MAC/cycle; 18.54%; 6,144 B read / 4,096 B write | 790 cycles; 82.96 MAC/cycle; 32.41% |
| GEMV | 1×13×17 | 221 | 75 cycles; 2.95 MAC/cycle; 304 B read | 100 cycles; 2.21 MAC/cycle; 0.86% |
| GEMV | 8×16×19 | 2,432 | 154 cycles; 15.79 MAC/cycle; 560 B read | 100 cycles; 24.32 MAC/cycle; 9.50% |
| GEMV | 16×16×19 | 4,864 | 250 cycles; 19.46 MAC/cycle; 816 B read | 100 cycles; 48.64 MAC/cycle; 19.00% |
| GEMV | 16×16×65 | 16,640 | 631 cycles; 26.37 MAC/cycle; 2,368 B read | 244 cycles; 68.20 MAC/cycle; 26.64% |

Both sides passed all listed output Golden checks. TinyNPU exposes no product
SPAD/controller endpoint in this benchmark: its numbers are array-only and
its memory traffic is not measured. NMAForge numbers include controller and
behavioral SPAD cycles. **No cross-system speedup is claimed** from this table.
The current result does show the cost of the NMAForge memory/control path and
the benefit TinyNPU gets from measuring only the array; it does not establish
which complete product is faster.

TinyNPU's source checkout is clean at the pinned SHA. This host currently lacks
`verilator`, `numpy`, and `onnx`, so the Round 9 TinyNPU results replayed cached
binaries and did not rebuild the reference. The TinyNPU direct-array binary
results are exact replays; a clean independent toolchain rebuild remains open.

### Shared `conv1x_mini.onnx` graph

The same model (`1,872` useful MACs), input seed 99, input hash
`a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`, and
TinyNPU Golden hash
`94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c` were used.
Both implementations passed; NMAForge matched the byte-level output and
TinyNPU matched all four output bytes.

| System | Measured cycles | Memory traffic | Boundary |
|---|---:|---:|---|
| NMAForge | 1,985 CMDQ cycles + 1,080 separately accounted Host Layout cycles | Compute SPAD 3,360 B read / 1,600 B write; Host Layout 144 B read / 576 B write | Top CMDQ execution windows; excludes preload, descriptor programming, and final host read |
| TinyNPU | 4,781 graph cycles | graph log reports 1,088 B DMA load / 4 B DMA store | ONNX graph dispatcher and behavioral DMA/SRAM shim |

No speedup is calculated because the graph, memory setup, Host Layout, and
measurement endpoints differ. The 1,985 cycles alone are not an end-to-end
NMAForge total; the separately reported 1,080 layout cycles and excluded setup
must remain visible.

## 4. Model representativeness and innovation claims

| Round 9 item | Status | Evidence / limitation |
|---|---|---|
| SFU LayerNorm and Softmax optimization | **PASS for H=4 fixture** | Exact intermediate/Top Golden; LayerNorm −128 Decode cycles, Softmax −477, Decode −605 |
| H=16/32 two-head trained Transformer | **PARTIAL / NOT RUN** | `train_transformer_micro.py` and `cimforge_mapper.py` are explicitly H=4, one-head, four-token flows; expanding them would be a broader mapper/model effort |
| Shape-Adaptive GEMV in Transformer Decode | **NOT RUN** | H=4 Decode run used GEMM mapping; no GEMM/GEMV/cache/prefetch model-level ablation was run |
| >=100K-useful-MAC multi-layer CNN | **PARTIAL / NOT RUN** | Current matched `conv1x_mini` has 1,872 useful MACs; no larger trained model or multi-layer mapper execution was added |
| CNN Legacy/Fused/Fused Linear-Row ablation on larger model | **NOT RUN** | No >=100K CNN model was available for this round |
| Matrix/DMA overlap | **PASS for 3×4×4 case; original failure PARTIAL** | New independent DDR and SPAD Golden passes; exact prior 4-mismatch probe not recovered |
| TinyNPU shared Transformer subgraph | **NOT RUN** | No same trained model/quantized QKV/Attention/FFN Decode graph was executed on both designs |

Innovation 1 has its clearest existing use in batched small-M GEMV where B-fold
reuse saves operand reads. This round's Direct Array comparison shows why such
cases need an endpoint-matched memory model; it does not show that the feature
accelerates a real Transformer Decode. Innovation 2 remains demonstrated only
by prior smaller CNN experiments. This round adds no larger-model evidence for
either innovation.

## 5. Reproduction commands and evidence

All current candidate runs use product/test SHA
`74402ba991285cb4403cb50737013362f5a2af53`, seed `20261107` unless noted, and
VCS `V-2023.12-SP1_Full64`.

```bash
# Complete Top Smoke
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=0 AI_SEED=20261107 SEED=20261107

# Trained H=4 INT8 Transformer, GEMM mapping
make -C dv/subsystem/top_smoke/sim ai_transformer_trained \
  PYTHON=python3.12 AI_TRANSFORMER_SEED=20261107 \
  AI_TRANSFORMER_STEPS=20000 \
  AI_TRANSFORMER_TRAINED_MODEL=/tmp/nmaforge_r9_transformer_seed20261107.json \
  AI_TRANSFORMER_MANIFEST=/tmp/nmaforge_r9_transformer_manifest_seed20261107.json \
  AI_TRANSFORMER_MAPPING_POLICY=gemm

# SFU focused functional regression
make -C dv/block/compute/sfu/sim random-latency-test \
  PYTHON=python3.12 SEED=20261107 OUT_DIR=/tmp/nmaforge_r9_sfu_final

# Three-tile Matrix/DMA baseline and ping-pong probe
make -C dv/subsystem/top_smoke/sim ai_matrix_dma_overlap_probe \
  AI_SEED=20261107 SEED=20261107

# Current-candidate 16x16 Matrix GEMM and product GEMV shapes
make -C dv/block/compute/matrix/sim core-random-compile \
  SEED=20261107 PHYSICAL_ARRAY_SIZE=16 \
  CORE_OUT_DIR=/tmp/nmaforge_r9_tinynpu_matrix
/tmp/nmaforge_r9_tinynpu_matrix/simv +SEED=20261107 +TINY_NPU_MATCH_MULTI \
  -l /tmp/nmaforge_r9_tinynpu_matrix/gemm_match.log
/tmp/nmaforge_r9_tinynpu_matrix/simv +SEED=20261107 +MATRIX_PRODUCT_GEMV_ONLY \
  -l /tmp/nmaforge_r9_tinynpu_matrix/gemv_product.log
```

The Round 9 NMAForge `conv1x_mini` Top replay used the fixed workload files in
[`benchmark/round9_runs_20261107`](../../benchmark/round9_runs_20261107/)
because this host lacks Python `numpy`/`onnx` needed to regenerate the workload.
The exact input, output Golden, and manifest hashes are in
[`v2_round9_performance_summary_20261107.json`](../../benchmark/v2_round9_performance_summary_20261107.json).
TinyNPU cached binary logs, executable/data hashes, and current product raw logs
are archived in the same evidence directory. Per-command SFU CSV/JSON profiles
are [`baseline`](../../benchmark/v2_round9_transformer_sfu_profile_20261107.csv)
and [`optimized`](../../benchmark/v2_round9_transformer_sfu_optimized_profile_20261107.csv).
The paired machine-readable summary is available as
[`CSV`](../../benchmark/v2_round9_performance_summary_20261107.csv) and
[`JSON`](../../benchmark/v2_round9_performance_summary_20261107.json).

## 6. Final decision

The scoped H=4 SFU optimization and the new small Matrix/DMA overlap case pass
with bit-exact Golden. Current-source NMAForge Matrix and same-model CNN checks
pass. The main new measured improvement is 605 fewer H=4 Decode cycles (10.59%)
from LayerNorm input reuse and exact Softmax divider leading-zero skipping.

Round 9 remains **PARTIAL**, not a performance breakthrough sign-off: the
Transformer is a synthetic H=4 toy, the >100K-MAC CNN and true model-level
GEMV/Fused ablations are absent, the original four-mismatch pipeline probe is
not conclusively traced, and TinyNPU timing endpoints are not system-matched.
No ASIC PPA, frequency, power, or area claim is made. Work stops at this
bounded research result; no automatic follow-on phase is started.
