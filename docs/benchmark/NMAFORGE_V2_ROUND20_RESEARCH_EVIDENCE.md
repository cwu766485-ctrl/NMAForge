# NMAForge v2 Round 20 — Research Evidence Closure

## Decision summary

Round 20 closes the highest-value evidence gaps for the existing 256-MAC INT8
prototype. The trained Digits CNN now uses the same feature ordering as its
training graph, its independent verifier checks the physical Matrix-A image,
and the fixed held-out set has been replayed through Top RTL. TinyNPU was rebuilt
at its pinned SHA and the existing GEMM, GEMV, and Mini CNN comparisons were
rerun. A bounded Top DMA/Matrix overlap probe now records actual AXI bursts,
bytes, and per-burst response latency.

The model-correctness fix and the measurement work do not change product RTL.
The CNN’s two fused commands reduce the CMDQ window substantially, but the full
CNN still pays host-side im2col/packing and AXI-Lite SPAD preload. The H16 GEMV
result remains shape-specific: M=1 decode improves by only 0.424%, and cache
reuse is disabled for that shape. TinyNPU comparisons remain useful evidence,
but the controller/memory endpoints are not the same RTL boundary, so the
reported normalized ratios are not system speedups.

**Recommendation:** freeze the current RTL as a research baseline. Do not claim
ASIC readiness, tapeout readiness, or universal Transformer acceleration from
these results.

## Frozen sources and tools

| Item | Value |
|---|---|
| Reviewed repository HEAD | `b476855c83f1e928bb8e386e7e96844de2544b1a` |
| Round 19 tested RTL and Top test source | `7e38a224bfa9558b8b9145c0a9dd81e2786f202a` |
| Product RTL at reviewed HEAD | Byte-identical to Round 19 tested RTL under `rtl/` |
| TinyNPU reference | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| VCS | `/usr/local/bin/vcs`, `V-2023.12-SP1_Full64` |
| Verilator | `/tmp/nmaforge_verilator_5.052/bin/verilator`, `5.052 2026-09-05 rev v5.052` |
| C++ compiler | GCC `8.5.0` |
| Python / NumPy / ONNX | `/tmp/nmaforge_arch_v2_py312/bin/python`, `3.12.13 / 2.4.6 / 1.17.0` |
| CNN training dependency | scikit-learn `1.9.1` |
| Round 20 CNN generator SHA-256 | `0b5f532d67dd8a4883d526fc7eac30aa85d7a227c141de00f46dec0cd016c3a2` |
| Round 20 CNN verifier SHA-256 | `30489a2da13993d4f43625864ec92d2bb9212f15964755b9b3f6d3b01e9c95d2` |
| Round 20 Top runner SHA-256 | `6bb05f19e7ee534d63d8cae12116ae70db05ea3132ecd25ebd90e3ea414e775d` |
| Round 20 Top testbench SHA-256 | `00f049d8241f1fbbfc2954cdb3bf439faa690782731ce939622bb287ea2737d6` |

The Top CNN binaries were reused from the Round 19 VCS build. The product RTL
and pre-instrumentation Top testbench are byte-identical between that tested
SHA and this review HEAD. Round 20 adds only a testbench AXI monitor and fixes
the host workload generator/verifier; there is no product RTL delta. The
Round 20 testbench was separately compiled and exercised by `ai_smoke` and the
DMA probe. The reused Top binary SHA-256 is
`19db88edf4f9438c96731fd7c59717fecd1c91277ee6f262eec3b2e67cd652d6`; its exact
VCS invocation and build log (archive member `reused_trained_cnn_simv_compile.log`)
are in [`R20-vcs-validation-logs.tar.gz`](round20_evidence/R20-vcs-validation-logs.tar.gz).

## Gate 1 — Trained CNN correctness and quality

### Model and layout audit

The model is a deterministically trained, two-stage INT8 network:

- 3×3 valid convolution lowered to a `196 × 36` Matrix input, with 63 learned
  channels and one constant feature implementing the offset.
- 1×1 projection from 64 to 10 output logits.
- 570,164 useful MACs per image.
- sklearn Digits 8×8 grayscale images, nearest-neighbor 2× upsampled to 16×16,
  plus constant, x-coordinate, and y-coordinate planes.
- Training seed `20261119`, 250 epochs, stratified 1,437/360 train/test split.
- Symmetric signed INT8 weights, INT8 activations, INT32 accumulation, explicit
  shifts, ReLU on the first layer, and signed saturation.
- Software INT8 held-out accuracy: **346/360 (96.111%)**. Float model accuracy:
  95.556%.

The original Top workload generator flattened Conv1 patches in
`[input-channel, kernel-position]` order, while the trainer’s actual array
operations produce `[kernel-position, input-channel]`. The old physical Golden
was internally self-consistent, so word-level Golden PASS did not catch the
semantic input permutation. Round 20 adds the missing transpose in the
generator. The independent verifier now reconstructs the held-out image from
the pinned sklearn dataset and checks every physical Matrix-A input element
before recalculating the integer Golden. No Golden values or RTL outputs were
changed to make the test pass.

Retraining the same seed/epoch recipe reproduced the exact deployed INT8 weight
hash `0d772a4d569814b67aefe7dabe596f43cf275b3aa26df4a529f3a3e83bbd3e6c` and the
same 96.111% held-out result. The prior model JSON hash is
`763a86d8a4ad508bd3ec34106163891f26870a98868889b0bc6c8bfe285370f8`; the new
retraining record differs only in metadata reflecting the corrected trainer
comment/source hash (`b4967d220d5eb4919d89e5cf23fce5b493029ceb0ffc9f93c848adb6a4adc250`).
Both are recorded in [`cnn_training_reproduction.json`](../../benchmark/representative/round20/cnn_training_reproduction.json).

### Stratified multi-sample Top replay

The deterministic sample plan includes all 14 software INT8 errors and the
first two correct held-out samples in each class (34 samples total). Every class
is represented, and the plan deliberately oversamples errors; its 20/34
correct-prediction fraction is **not** the model’s accuracy estimate.

| Dataflow | Descriptors | CMDQ cycles | SPAD read / write bytes | SFU busy cycles | Top Golden |
|---|---:|---:|---:|---:|---|
| Legacy GEMM + Requant | 4 | 66,023 | 130,624 / 83,200 | 54,084 | 34/34 samples, 20,800 words/sample |
| First-layer Fused | 3 | 23,577 | 77,376 / 29,952 | 10,817 | 34/34 samples, 20,800 words/sample |
| Both-layer Fused, Row-Major output | 2 | 12,947 | 64,064 / 16,640 | 0 | 34/34 samples, 20,800 words/sample |

All **102 Top runs** passed all intermediate and final memory-image comparisons:
2,121,600 word checks. The independent software classifier uses global average
pooling and argmax on the output logits. Top output words match that independent
tensor bit-exactly, so the hardware-produced logits imply the same predicted
label; pooling/argmax itself remains host postprocessing.

The exhaustive run replayed all 360 held-out samples in the best two-layer
fused mode: **360/360 Top completions passed**, with **7,488,000/7,488,000
intermediate/final word checks**. The cycle count was 12,947 for every sample.
The hardware-produced logits matched the independent integer Golden for every
sample. Applying the documented host global-average/argmax postprocess to those
Top-observed logits gave **346/360 correct (96.111%)**, matching the software
held-out score; this is model accuracy, separate from the 100% bit-exact RTL
functional result. This run took 1,556.064 host wall-clock seconds for 360
simulations. The PASS/accuracy summary is in
[`cnn_top_all360_results.json`](../../benchmark/representative/round20/cnn_top_all360_results.json)
and the per-sample table is in
[`cnn_top_all360_results.csv`](../../benchmark/representative/round20/cnn_top_all360_results.csv).
Per-sample logs are archived under
[`round20_evidence/cnn_top_logs/`](round20_evidence/cnn_top_logs/).
All three dataflows were run on the 34-sample stratified set; only the best
two-layer fused mode was expanded to all 360 samples.

### Dataflow effect and transfer accounting

For the same model/input/weights and compatible final Row-Major output:

| Comparison | CMDQ cycles saved | CMDQ reduction | Cycle ratio |
|---|---:|---:|---:|
| Legacy → first-layer fused | 42,446 | 64.29% | 2.800× |
| Legacy → both-layer fused Row-Major | 53,076 | 80.39% | 5.099× |
| First-layer fused → both-layer fused Row-Major | 10,630 | 45.09% | 1.821× |

These are command-window comparisons, not full-inference speedups. The full
Top setup loads a 94,336-byte memory image using AXI-Lite writes; this is **not
the hardware DMA path**. The image contains 7,056 valid input bytes, 432 bytes
of padded input rows, 3,328 weight bytes, 320 descriptor/completion bytes, and
83,200 poison/sentinel/output initialization bytes. The useful input+weight
payload is 10,384 bytes (10,816 bytes including input padding). Preload plus
CMDQ cycles are:

| Dataflow | AXI-Lite preload cycles | CMDQ cycles | Preload + CMDQ |
|---|---:|---:|---:|
| Legacy | 141,503 | 66,023 | 207,526 |
| First-layer Fused | 141,383 | 23,577 | 164,960 |
| Both-layer Fused Row-Major | 141,263 | 12,947 | 154,210 |

Thus the fused paths reduce the measured preload+command interval by 20.5% and
25.7% versus Legacy, respectively. This interval still excludes software
training/preprocessing wall time and final host output collection. Host Im2col
and packing are separately timed by the workload generator; no host activation
computation is used between the two hardware GEMM layers. The last global
average/argmax is host work. The 82.37% array-utilization counter is utilization
while the array is active, not over the full command window: the 2,704 MAC-active
cycles are 4.10%, 11.47%, and 20.89% of the three respective CMDQ windows.

## Gate 2 — TinyNPU benchmark

TinyNPU was checked out and rebuilt from pinned SHA
`8216c22b762011aa20c05fc2768423fd12dda59d` with Verilator 5.052. The fixed
GEMM/GEMV shapes and the common `conv1x_mini.onnx` passed their independent
Golden checks. Detailed records, tool versions, and source SHAs are in
[`benchmark/representative/round20/tinynpu/`](../../benchmark/representative/round20/tinynpu/).
The raw build/run outputs are archived in
[`tinynpu_benchmark_logs.tar.gz`](round20_evidence/tinynpu_benchmark_logs.tar.gz).

### GEMM and GEMV

The normalized ratio column is `NMAForge measured cycles / TinyNPU measured
array cycles plus modeled serialized memory service`; below one means fewer
cycles in this mixed endpoint, above one means more. It is **not** an RTL-to-RTL
system speedup.

| Workload | NMAForge controller + behavioral SPAD | TinyNPU direct array | TinyNPU normalized | Mixed ratio | Golden |
|---|---:|---:|---:|---:|---|
| GEMM 16×16×16 | 172 | 52 | 151 | 1.139× | PASS |
| GEMM 16×16×32 | 268 | 100 | 231 | 1.160× | PASS |
| GEMM 32×32×64 | 1,411 | 790 | 1,305 | 1.081× | PASS |
| GEMV 1×13×17 | 68 | 100 | 126 | 0.540× | PASS |
| GEMV 8×16×19 | 163 | 100 | 170 | 0.959× | PASS |
| GEMV 16×16×19 | 266 | 100 | 218 | 1.220× | PASS |
| GEMV 16×16×65 | 637 | 244 | 459 | 1.388× | PASS |

NMAForge is lower in the modeled GEMV endpoint for M=1 and M=8, and higher for
the larger M=16 cases. It is higher in all three normalized GEMM cases. TinyNPU
does not expose the tested SPAD/controller endpoint: its GEMV cases pad into a
16×16 direct systolic array, and the “normalized” values serialize a common
16-byte/cycle, one-cycle-response memory model around measured array cycles.
The NMAForge side measures its Matrix controller with behavioral SPAD. We do
not calculate cross-project system speedups from these mixed endpoints.

The common CNN is `conv1x_mini.onnx` (1,872 logical MACs, model SHA
`1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`, input seed
99). Both produce the same four final output bytes and NMAForge checks all
intermediate tensors. NMAForge records 1,985 CMDQ cycles plus 1,080 host layout
cycles (3,065 reported total for those windows); TinyNPU records 4,781 graph
cycles including its graph dispatcher and testbench DMA/SRAM shim. SPAD preload,
descriptor setup and final host read are outside the NMAForge intervals, so no
CNN speedup is claimed.

The run completed TinyNPU’s 6/6 engine regression. NMAForge uses a 128 KiB
four-bank behavioral SPAD in Top work; these runs do not establish equal SRAM
capacity or equal native memory systems. The bounded common-memory model is
useful diagnostic data only. Building an equivalent TinyNPU RTL memory endpoint
would require adding a new exposed memory interface and is outside this round.

## Gate 3 — DMA transfer and legal overlap

The Top probe runs three legal 4×4×4 Matrix tiles in serialized and existing
ping-pong modes. Input data is read from the external behavioral AXI memory by
the Top DMA; results are written back by the Top DMA and checked bit-exactly.
It observes 3 accepted AR bursts / 48 read bytes / 3 R beats and 3 AW bursts /
192 write bytes / 12 W beats / 192 asserted WSTRB bytes / 3 B responses in both
modes. Each read burst is 16 bytes and averages 5 cycles from AR acceptance to
its final R beat; each write burst is 64 bytes and averages 7 cycles from AW
acceptance to B response. The maximum per-burst latencies equal those averages
in this fixed run. These latencies are from the behavioral model and the probe
clock is 10 ns; they are not a physical memory bandwidth or timing claim.

| Mode | Total cycles | DMA busy | Matrix active | Overlap counter | Stall | Golden |
|---|---:|---:|---:|---:|---:|---|
| Serialized | 561 | 108 | 444 | 0 | 9 | bit-exact |
| Ping-pong | 488 | 108 | 447 | 72 | 5 | bit-exact |

Ping-pong saves 73 cycles (13.01%) on this small probe with the same bytes and
Golden. Exclusive-cycle accounting closes as `108 + 444 + 9 = 561` for
serialized, and `108 + 447 + 5 - 72 = 488` for ping-pong. The overlap counter is
subtracted because those cycles are counted in both DMA and Matrix busy time.
At the probe's 10 ns simulated clock, burst payload efficiency is 3.20 read
bytes/cycle (16 B over 5 cycles) and 9.14 write bytes/cycle (64 B over 7
cycles). Over the full observed request-to-response spans, aggregate rates are
0.088/0.250 read bytes/cycle and 0.351/0.623 write bytes/cycle for serialized /
ping-pong respectively. These are measurements of this behavioral-memory
probe, not a silicon or whole-model bandwidth claim.
The full trained CNN still uses AXI-Lite host writes to preload its SPAD image;
the probe is not whole-model DMA timing. A model-scale ping-pong transfer and
preload using hardware DMA remain OPEN.

Machine-readable records are
[`dma_overlap.csv`](../../benchmark/representative/round20/dma/dma_overlap.csv)
and [`dma_overlap.json`](../../benchmark/representative/round20/dma/dma_overlap.json);
raw VCS output and smoke/compile logs are in
[`R20-vcs-validation-logs.tar.gz`](round20_evidence/R20-vcs-validation-logs.tar.gz).

## Gate 4 — H16 incremental Transformer and GEMV

Round 16 verified a fixed H16, two-head, one-layer, INT8 incremental decode
using tested source SHA `0f6e9f33ae1f129f57b0947849cffb5de43d6281`, seed
`20261116` and model SHA
`756a39fc74134cbc451d8aafa94743f2793abd2651032b36b180b99117d68bfc`:
prefill tokens 0–3, then four host-supplied tokens 4–7 with RTL Q/K/V, KV
append/read, QK, causal Softmax, AV, output projection, residual, LayerNorm and
FFN. Every tested intermediate tensor and KV image matched. The inputs are
host-supplied; weights were generated from deterministic integer projection
tasks, not trained language-model weights. This is functional Decode evidence,
not autonomous language generation or an LM quality benchmark.

For the Round 16 fixed model (`model_sha256`
`756a39fc74134cbc451d8aafa94743f2793abd2651032b36b180b99117d68bfc`, seed
`20261116`), the same four incremental steps compare as follows:

| Mapping | Prefill | Four Decode steps | Prefill + Decode | Decode SPAD read / write |
|---|---:|---:|---:|---:|
| GEMM QKV | 2,734 | 39,615 | 42,349 | 32,640 / 18,752 bytes |
| Shape-Adaptive GEMV QKV | 2,734 | 39,447 | 42,181 | 34,560 / 16,448 bytes |

GEMV saves 42 cycles/token on average (0.424% over Decode; 0.397% over prefill
plus four steps). It reduces Matrix active cycles per token from 176 to 104,
but increases read traffic by 480 bytes/token. SFU work is unchanged and is the
dominant portion of Decode. Since B-fold reuse is disabled for `M<=4`, this
single-token test provides no cache-reuse benefit; there is no independent
prefetch toggle in this mapper configuration. Cache/prefetch model-level
ablation is **not run**, not inferred from other shapes.

| Token | Useful MAC | GEMM / GEMV cycles | GEMM / GEMV MAC/cycle | SFU cycles | KV cycles | GEMM / GEMV read bytes | GEMM / GEMV write bytes |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 4 | 1,696 | 9,791 / 9,749 | 0.1732 / 0.1740 | 7,921 | 394 | 8,160 / 8,640 | 4,688 / 4,112 |
| 5 | 1,728 | 9,865 / 9,823 | 0.1752 / 0.1759 | 7,995 | 394 | 8,160 / 8,640 | 4,688 / 4,112 |
| 6 | 1,760 | 9,939 / 9,897 | 0.1771 / 0.1778 | 8,069 | 394 | 8,160 / 8,640 | 4,688 / 4,112 |
| 7 | 1,792 | 10,020 / 9,978 | 0.1788 / 0.1796 | 8,150 | 394 | 8,160 / 8,640 | 4,688 / 4,112 |

Separate Round 17 H16 evidence used tested RTL SHA
`7f6fd2a40ef939a7df3a488e04df8ff89ae039e3`, seed `20261117`, and model SHA
`43ea1d5012e825d068a9dde137c18f2b7e0b95d725a753278331791d86c8ae61`. On that
separate fixed model, the Exact Length-16 LayerNorm fast path reduced four-step
Decode from 39,615 to 35,391
cycles, saving 4,224 cycles (10.66%) with all stage outputs and KV matching.
Softmax and Requant cycle counts were unchanged. The Round 16 GEMV and Round 17
LayerNorm results use different model artifact hashes; they are independent
one-factor ablations and must not be added together or presented as one combined
model result. The detailed copies are
[`h16_round16_gemm_vs_gemv.json`](../../benchmark/representative/round20/h16_round16_gemm_vs_gemv.json)
and [`h16_round17_sfu_comparison.json`](../../benchmark/representative/round20/h16_round17_sfu_comparison.json).

## Research novelty and prior work

Shape-dependent mappings, local operand reuse, operator fusion, output-layout
selection, and memory/compute overlap are established accelerator/compiler
techniques. Eyeriss describes dataflow choices that exploit local reuse to
reduce data movement ([ISCA 2016 paper](https://research.nvidia.com/publication/2016-06_eyeriss-spatial-architecture-energy-efficient-dataflow-convolutional-neural));
MAESTRO analyzes shape/dataflow reuse and hardware cost
([MICRO 2019 paper](https://research.nvidia.com/publication/2019-10_understanding-reuse-performance-and-hardware-cost-dnn-dataflows-data-centric));
TVM includes graph/operator fusion and memory latency hiding
([OSDI 2018 paper](https://www.usenix.org/conference/osdi18/presentation/chen)).

The Round 20 evidence therefore does **not** establish novelty of these
individual mechanisms. Potential project value is their constrained integration
into one 256-INT8-MAC array and four-bank SPAD with existing ABI-v7 descriptors,
plus measured behavior for this prototype’s workload shapes. A publishable
novelty claim still needs a carefully scoped related-work review, matched
resource comparisons, representative trained workloads, and hardware cost/
energy evidence.

## Open items and readiness

| Topic | Status | Evidence boundary / next required evidence |
|---|---|---|
| Trained CNN Top correctness | PASS | 34-sample three-mode stratified sweep and 360-sample Both-Fused sweep; see result status above |
| Trained CNN accuracy | PASS, host postprocess | 346/360 INT8 held-out predictions; Top logits bit-exact, global average/argmax on host |
| Full model transfer via DMA | PARTIAL | Top CNN SPAD image still uses AXI-Lite preload; only bounded DMA probe measured |
| TinyNPU common compute shapes | PASS with mixed endpoints | Golden passes; no shared controller/memory RTL endpoint, normalized ratios are not system speedups |
| H16 four-token incremental decode | PASS on historical fixed source/model | H16 results retain their SHA/model manifests; no trained language model claim |
| GEMV model-level benefit | PASS, small and shape-specific | 0.424% single-token reduction; cache/prefetch not applicable to M=1 mapping |
| Exact LayerNorm fast path | PASS, independent ablation | 10.66% decode reduction on separate fixed model; do not combine with GEMV delta |
| Full UVM/Formal/coverage closure | NOT DONE | Out of Round 20 scope |
| ASIC synthesis/PPA | NOT RUN | No current Round 20 PPA claim |

The architecture is suitable for a frozen **research baseline** with these
limits recorded. It is not ASIC-ready or tapeout-ready on this evidence alone.

## Reproduction commands and artifacts

Top CNN uses the existing compiled VCS binary and deterministic test ranks:

```bash
PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python
SIMV=/tmp/r19_cnn_top/simv
MODEL=benchmark/representative/models/r19_trained_digits_3x3_cnn.json
RANKS="$(seq -s, 0 359)"
"$PYTHON" benchmark/representative/round20/run_trained_cnn_top_matrix.py \
  --model "$MODEL" --simv "$SIMV" --python "$PYTHON" \
  --out-dir /tmp/r20_cnn_all360_both_fused --ranks "$RANKS" \
  --modes both_fused_row_major --seed 20261120 \
  --source-sha 7e38a224bfa9558b8b9145c0a9dd81e2786f202a \
  --run-id R20-CNN-ALL360-BOTH-FUSED
```

The stratified run used ranks from
[`cnn_sample_plan.csv`](../../benchmark/representative/round20/cnn_sample_plan.csv),
all three fusion modes, seed `20261119`, and run ID `R20-CNN-STRAT34`. Top Smoke
and the focused DMA probe were run with:

```bash
cd dv/subsystem/top_smoke/sim
make ai_smoke AI_RANDOM_CASES=0 AI_SEED=20261120 SEED=20261120
make ai_matrix_dma_overlap_probe AI_RANDOM_CASES=0 AI_SEED=20261120 SEED=20261120
```

The stratified replay command can be reconstructed directly from its committed
sample plan:

```bash
PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python
RANKS="$(tail -n +2 benchmark/representative/round20/cnn_sample_plan.csv | cut -d, -f1 | paste -sd, -)"
"$PYTHON" benchmark/representative/round20/run_trained_cnn_top_matrix.py \
  --model benchmark/representative/models/r19_trained_digits_3x3_cnn.json \
  --simv /tmp/r19_cnn_top/simv --python "$PYTHON" \
  --out-dir /tmp/r20_cnn_stratified --ranks "$RANKS" \
  --modes legacy,first_fused,both_fused_row_major --seed 20261119 \
  --source-sha 7e38a224bfa9558b8b9145c0a9dd81e2786f202a \
  --run-id R20-CNN-STRAT34
```

Training reproducibility check:

```bash
/tmp/nmaforge_arch_v2_py312/bin/python \
  benchmark/representative/train_digits_3x3_cnn.py \
  --seed 20261119 --epochs 250 --out /tmp/r20_retrained_digits.json
```

Training reproduction record: seed `20261119`, 250 epochs, model SHA-256
`b4967d220d5eb4919d89e5cf23fce5b493029ceb0ffc9f93c848adb6a4adc250`, deployed
INT8 weight SHA-256 `0d772a4d569814b67aefe7dabe596f43cf275b3aa26df4a529f3a3e83bbd3e6c`.

The DMA summary parser can be rerun with:

```bash
mkdir -p /tmp/r20_vcs_logs
tar -xzf docs/benchmark/round20_evidence/R20-vcs-validation-logs.tar.gz \
  -C /tmp/r20_vcs_logs
/tmp/nmaforge_arch_v2_py312/bin/python \
  benchmark/representative/round20/collect_dma_overlap.py \
  --log /tmp/r20_vcs_logs/dma_overlap_probe.log \
  --testbench dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv \
  --run-id R20-DMA-OVERLAP-20261109 \
  --source-sha b476855c83f1e928bb8e386e7e96844de2544b1a \
  --seed 20261120 --period-ns 10.0 \
  --out-dir benchmark/representative/round20/dma
```

TinyNPU was rebuilt and run using the existing scripts with pinned sources:

```bash
env SEED=20261120 BENCH_RUN_ID=R20-TINY-COMPARE-20261109 \
  TINYNPU_BENCH_OUT=/tmp/r20_tinynpu_compare \
  TINYNPU_WORK_ROOT=/tmp/nmaforge_round19_tiny_reference \
  VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python JOBS=4 \
  VCS_VERSION=V-2023.12-SP1_Full64 bash benchmark/tinynpu/run_comparison.sh

env SEED=20261120 BENCH_RUN_ID=R20-GEMV-MATCH-20261109 \
  GEMV_BENCH_OUT=/tmp/r20_tinynpu_gemv \
  TINYNPU_WORK_ROOT=/tmp/nmaforge_round19_tiny_reference \
  TINY_NPU_ROOT=/tmp/nmaforge_round19_tiny_reference/source \
  VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python JOBS=4 \
  VCS_VERSION=V-2023.12-SP1_Full64 bash benchmark/tinynpu/run_gemv_match.sh
```

Key machine-readable evidence:

- [`cnn_sample_plan.json`](../../benchmark/representative/round20/cnn_sample_plan.json)
- [`cnn_top_stratified_results.csv`](../../benchmark/representative/round20/cnn_top_stratified_results.csv)
- [`cnn_top_stratified_results.json`](../../benchmark/representative/round20/cnn_top_stratified_results.json)
- [`cnn_top_all360_results.csv`](../../benchmark/representative/round20/cnn_top_all360_results.csv)
- [`cnn_top_all360_results.json`](../../benchmark/representative/round20/cnn_top_all360_results.json)
- [`R20-CNN-ALL360-BOTH-FUSED-top-logs.tar.gz`](round20_evidence/cnn_top_logs/R20-CNN-ALL360-BOTH-FUSED-top-logs.tar.gz)
- [`R20-CNN-STRAT34-all-mode-top-logs.tar.gz`](round20_evidence/cnn_top_logs/R20-CNN-STRAT34-all-mode-top-logs.tar.gz)
- [`R20-vcs-validation-logs.tar.gz`](round20_evidence/R20-vcs-validation-logs.tar.gz)
- [`tinynpu/`](../../benchmark/representative/round20/tinynpu/)
- [`dma_overlap.csv`](../../benchmark/representative/round20/dma/dma_overlap.csv)
- [`dma_overlap.json`](../../benchmark/representative/round20/dma/dma_overlap.json)
- [`SHA256SUMS.txt`](round20_evidence/SHA256SUMS.txt) lists hashes for the
  model, scripts, source testbench, raw logs and machine-readable result files.

VCS emitted its existing `LOOP-REROLL-ENABLED` debug-capacity warning for the
Transformer fixture. Compilation and the targeted smoke/probe commands passed.
This warning is recorded, not waived.
