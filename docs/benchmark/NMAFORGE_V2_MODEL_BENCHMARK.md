# NMAForge v2 Model Benchmark

## Round 10 current-source replay — 2026-11-08

At reviewed source SHA `1cd1bde4d82c457d445f97a7817fc22d407b528b`, the RTL,
software, and test code is unchanged from tested code snapshot
`13f94abf59c3dbea833ad4bbe227ef5cab4df503`. Fresh 396-sample Digits CNN
replays match its fixed model/testset hashes and pass every intermediate and
logit Golden in Legacy, fused-native, and Linear-Row modes. They retain
384/396 (96.9697%) classification accuracy. Measured CMDQ cycles/image are
3,193 / 2,712 / 2,712; testbench-accounted layout intervals are 1,080 / 1,080
/ 0 cycles. The layout interval is not measured host CPU time. Round 10 also
reran the `conv1x_mini.onnx` three-mode ablation and TinyNPU graph smoke; all
model and endpoint details are in the
[Round 10 report](NMAFORGE_V2_ROUND10_ARCHITECTURE_PERFORMANCE.md) and
machine data is in [`Round 10 CNN CSV`](../../benchmark/v2_round10_cnn_ablation.csv).

Round 10 did not produce a representative model: current Transformer mapping
rejects H=16 weights because it requires 4×4 matrices, and neither checked-in
CNN workload reaches 100K useful MAC per inference. The H=4 toy Transformer
remains historical functional/performance evidence only. No H=16 SFU claim,
large CNN utilization claim, or model-level GEMV gain is established.

## Round 7 trained CNN dataflow recheck — 2026-11-07

The trained 10-class CNN was run in three modes on the exact same 396 held-out
samples and fixed trained INT8 weights. Testbench SHA
`7e64344fbb9bdaed0fd4ce14e8cddb19231827f7`, harness SHA
`30ef28b973343acd25ebd62d4df8576c84e8ffb1`, product RTL SHA
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, seed `20261107`, VCS
`V-2023.12-SP1_Full64`. Model SHA-256 is
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`;
held-out-set SHA-256 is
`cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`.

| Mode | CMDQ compute cycles / image | Layout cycles / image | SPAD bytes read / written per image | Top checks | Classification |
|---|---:|---:|---:|---:|---:|
| Legacy | 3,193 | 1,080 | 6,192 / 2,496 (including layout traffic) | 396/396 exact | 384/396 (96.97%) |
| `0x53` fused requant, native Matrix-A layout | 2,712 | 1,080 | 5,616 / 1,920 | 396/396 exact | 384/396 (96.97%) |
| `0x53` fused requant + Linear-Row | 2,712 | 0 | 5,472 / 1,776 | 396/396 exact | 384/396 (96.97%) |

The native-layout mode verifies the middle rung: its fused compute path saves
481 command cycles/image while leaving the same separately modeled layout
phase. Linear-Row then removes that 1,080-cycle phase with 288 additional
bytes read and 144 fewer bytes written than the fused-native path for this
model. The resulting same-harness phase interval is 2,712 vs 4,273 cycles
(1.576×); it is not a full application or TinyNPU system speedup. Useful work
is 2,736 MAC/image. The measured command-window rate rises from 0.857 to
1.009 useful MAC/cycle; this is not active-cycle array utilization. All three
paths preserve exact per-sample intermediate and output Goldens.

Machine-readable aggregates:
[`v2_round7_cnn_fused_modes_20261107.csv`](../../benchmark/v2_round7_cnn_fused_modes_20261107.csv).
Raw 396-row result CSVs and per-sample VCS logs remain outside Git under
`/tmp/nmaforge_round7_10class_{legacy,fused_native,linearized}_s20261107/`;
the CSV SHA-256 values are respectively
`2d649cecf7e92d9a8bd825d62309c24a3685a08fe9fb4d96c2abbcdec22d1963`,
`4124aa1c88e75ee30356b089915303082ff092ea502d6cb5b3ae7d1e3623b3bc`, and
`1b3e0dcaa701a99ba180765cc5dd8bc44386e634b91600238656326f7635bb3d`.

The dataset replay used the VCS `V-2023.12-SP1_Full64` top binary compiled
from the checked-in `ai_accel.f` and `tb_ai_accel_smoke.sv` at testbench
snapshot `7e64344fbb9bdaed0fd4ce14e8cddb19231827f7`. The recorded compile
command was:

```sh
cd dv/subsystem/top_smoke/sim
vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps \
  +define+VCS +define+AI_SPAD_WORDS_PER_BANK=32768 \
  +define+AI_TINYNPU_CNN_SPAD_BASE_SHIFT=0 \
  +incdir+../../../block/control/agent \
  +incdir+../../../block/dma/agent +incdir+../fixtures \
  -Mdir=/tmp/nmaforge_round7_cnn_fused_native_s20261107/fixed/csrc \
  -top tb_ai_accel_smoke -f ai_accel.f \
  ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
  -o /tmp/nmaforge_round7_cnn_fused_native_s20261107/fixed/simv \
  -l /tmp/nmaforge_round7_cnn_fused_native_s20261107/fixed/compile.log
```

With that compiled binary available as `$SIMV`, the exact dataset replay
invocations are:

```sh
python3 benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
  --simv "$SIMV" \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha 7e64344fbb9bdaed0fd4ce14e8cddb19231827f7 \
  --seed 20261107 --out-dir /tmp/nmaforge_round7_10class_legacy_s20261107

python3 benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
  --simv "$SIMV" \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha 30ef28b973343acd25ebd62d4df8576c84e8ffb1 \
  --seed 20261107 --fused-native \
  --out-dir /tmp/nmaforge_round7_10class_fused_native_s20261107

python3 benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
  --simv "$SIMV" \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha 7e64344fbb9bdaed0fd4ce14e8cddb19231827f7 \
  --seed 20261107 --linearized \
  --out-dir /tmp/nmaforge_round7_10class_linearized_s20261107
```

The output directories and compile logs are local run artifacts, not checked
into Git. The aggregate CSV retains the hashes and run IDs needed to verify
the archived sample tables.

The intermediate 0x53 native-layout mode is a testbench option that retains
the current output layout and performs the same explicit host layout phase.
The Linear-Row descriptor mode uses the existing bounded `0x53` row-write
logic; no product RTL changed in Round 7. This result applies to the tested
four-filter CNN and does not imply every consumer tensor can consume this
layout.

### Four-class mini CNN three-rung replay

The same `conv1x_mini.onnx` model, input SHA-256
`a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`,
Golden SHA-256
`94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c`,
seed `20261107`, and Top testbench pass in Legacy / fused-native / Linear-Row
modes. All three check the 4 output bytes and intermediates byte-exactly.
Compute cycles are 1,985 / 1,504 / 1,504; testbench host-layout cycles are
1,080 / 1,080 / 0. These correspond to phase intervals 3,065 / 2,584 /
1,504. The mini workload contains 1,872 useful MACs per four-output group.
Logs are in `/tmp/nmaforge_round7_cnn_fused_native_s20261107/`; the matching
aggregate rows are in the CSV above.

## Round 7 status boundary

This round does not add a larger trained Transformer: the existing H=4,
one-head, one-layer, 86-descriptor fixture remains the only reproducible
Transformer path. GEMM and `0x52` Decode are cycle-neutral at 5,715 cycles;
the B-fold Cache benefit remains demonstrated only on separate batched GEMV
commands. TinyNPU graph cycles and NMAForge Top CMDQ intervals remain
different measurement boundaries and are not ratioed.

---

## Round 6 model refresh — 2026-11-07

The fixed `conv1x_mini.onnx` workload was rerun at NMAForge source/test SHA
`54033ffd3a28378e867947e99598e79d2060fb9d` and TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`. Model/input hashes and exact
Golden status are unchanged. NMAForge Legacy measured 1,985 CMDQ cycles plus
1,080 testbench-emulated host-layout cycles; `0x53` Linear-Row measured 1,504
CMDQ cycles and no layout stage. TinyNPU measured 4,781 ONNX graph cycles.
The graph and CMDQ windows differ, so no TinyNPU speedup is computed.

The NMAForge linear-row path was separately rerun by adding
`+AI_TINYNPU_CNN_LINEARIZED` to the existing `nma_cnn/simv` command. It passed
all intermediate and final Golden checks. Machine data is in
[`Round 6 CNN path CSV`](../../benchmark/v2_round6_cnn_legacy_linearized_20261107.csv)
and [`TinyNPU CNN CSV`](../../benchmark/tinynpu/cnn_results.csv). The Round 6
fixed-weight H=4 Transformer GEMV run also passes all 86 descriptors, but has
the same 5,715 Decode cycles as default GEMM; see the
[`Round 6 decision`](NMAFORGE_V2_ROUND6_DECISION.md).

## Round 5 current-source model evidence — 2026-11-07

All new measurements use source/test SHA
`73caef0f32140d1635816f1eb4ea28372523e80c` and VCS
`V-2023.12-SP1_Full64`. Machine-readable per-run records are in
[`v2_round5_model_summary_20261107.csv`](../../benchmark/v2_round5_model_summary_20261107.csv)
and [`v2_round5_run_manifest_20261107.json`](../../benchmark/v2_round5_run_manifest_20261107.json).

### `conv1x_mini.onnx` paired NMAForge/TinyNPU replay

The model, deterministic input, and output Golden hashes are respectively
`1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`,
`a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`, and
`94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c`.
Both NMAForge layouts and the TinyNPU graph produce byte-exact output.

| Run | Useful MACs | Measured cycles | SPAD traffic available | Golden |
|---|---:|---:|---:|---|
| NMAForge Legacy | 1,872 | 1,985 Compute + 1,080 testbench Host Layout | Compute 3,360/1,600 B R/W; Host 144/576 B R/W | PASS |
| NMAForge `0x53` Linear-Row | 1,872 | 1,504 Compute; no Host Layout | Compute 2,784/1,456 B R/W | PASS |
| TinyNPU ONNX Graph (`8216c22b…`) | 1,872 | 4,781 Graph-runtime cycles | Not instrumented in this runtime | PASS 4/4 bytes |

The same NMAForge endpoint gives 1.320× speedup for Legacy→Linear-Row
Compute cycles and 2.038× for the simulator interval that includes Legacy
Host Layout. TinyNPU's 4,781 cycles include its graph dispatcher and
testbench DMA/SRAM shim, which do not match the NMAForge interval. Therefore
no NMAForge/TinyNPU CNN speedup is calculated.

### Trained ten-class CNN at current source

The training-weight SHA is
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`; the
held-out set SHA is
`cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`.
Both modes run 396/396 samples with exact intermediate/final Golden checks
and classify 384/396 (96.9697%). Per sample, Legacy→Linear-Row is 3,193→2,712
CMDQ cycles (1.177×), or 4,273→2,712 cycles (1.576×) including the
testbench-emulated 1,080-cycle Host Layout. Compute SPAD R/W falls from
6,048/1,920 B to 5,472/1,776 B; total traffic including the simulated Host
layout falls 8,688→7,248 B (−16.6%). This paired comparison combines fused
epilogue and consumer-ready layout; it does not isolate either contribution.

### Transformer GEMV attempt

The current baseline H4 trained cyclic fixture still passes 301/301 checks
at 11,397 doorbell-to-CPL-tail cycles (5,682 Prefill + 5,715 Decode). The
opt-in Mapper's Q/K/V `0x52` policy was tested against the same fixture and
produced 175 Decode Golden mismatches, although prefill stayed correct and
the command queue completed. The reported 11,397-cycle counter is not
performance evidence for the failing mapping. The mode remains experimental
and must not replace the default `0x30` Decode map.

The model JSON SHA is
`55cef19181c84dda9f99e940a0a749c1499fc1ccb176b966b1e13462f8ae3c03`.
Mapper unit tests pass, but real Decode GEMV is **FAIL**; no Cache/Prefetch
ablation or Transformer-level speedup is claimed. The H4 cyclic task is a
small functional workload, not a representative language-model benchmark.

## Focused Research Round 3 — fixed candidate `4dab736`

Source/test candidate: `4dab73646989615c5479de0bac76d1488a102758`, based on
reviewed remote `240ed4106a1b31078cce15e2406d437ca0cde987`. VCS was
`V-2023.12-SP1_Full64`; Python was `3.12.13` (NumPy `2.4.6` for the CNN
dataset flow). The results below are behavioral Top/CMDQ/SPAD simulations.
They do not measure an ASIC clock, physical SRAM, or energy.

### Trained Tiny Transformer — PASS for the bounded toy task

`sw/tools/train_transformer_micro.py` deterministically trains six INT8 4×4
matrices with integer simulated annealing. Seed `20261106` converged after
987/20,000 requested updates. The synthetic task predicts the next symbol in
a four-symbol cyclic stream: 4 training sequences, 252 exhaustive held-out
sequences, 16/16 train predictions and 694/1,008 held-out token predictions
(68.85%). Model SHA-256:
`55cef19181c84dda9f99e940a0a749c1499fc1ccb176b966b1e13462f8ae3c03`.
This is a trained tiny Transformer functional demo, **not** pretrained
language-model inference or evidence of useful natural-language quality.

The Mapper loads the exported JSON weights and emits the existing 86 ABI-v7
descriptors over 60 tensors. The real Top executes QKV, causal attention,
Softmax/requant, AV, output projection, residuals, LayerNorm, FFN/GELU, and
KV-cache reads/writes; Host work is limited to training, mapping/address
allocation, initial tensor/weight preload, and independent Golden generation
and comparison. No Host fallback supplies intermediate activations. The Top
checks 301 intermediate/final/KV values and the completion chain. The selected
prefill predicts 4/4 next symbols and the single decode predicts 1/1.

| Top interval | Cycles | SPAD reads | SPAD writes | Useful MACs |
|---|---:|---:|---:|---:|
| Four-token Prefill | 5,682 | 1,936 B | 1,072 B | included below |
| One-token Decode | 5,715 | 1,880 B | 1,048 B | included below |
| Combined doorbell → final CPLQ tail | 11,397 | 3,816 B | 2,120 B | 640 |

Run ID: `V2-TRAINED-TRANSFORMER-TOP-4DAB736-S20261106`. The reportable
reproduction command is:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_transformer_trained \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  AI_SPAD_WORDS_PER_BANK=8192 \
  AI_TRANSFORMER_TRAINED_MODEL=/tmp/nmaforge_round3_4dab_transformer/trained_cyclic_h4.json \
  AI_TRANSFORMER_MANIFEST=/tmp/nmaforge_round3_4dab_transformer/manifest.json \
  AI_TRANSFORMER_SEED=20261106 AI_TRANSFORMER_STEPS=20000
```

The full log is `dv/subsystem/top_smoke/sim/ai_transformer_trained.log` at
run time; a fresh run regenerates the fixture from the committed model JSON.
The default fixed-weight fixture remains the standard `ai_transformer`
regression. This 128 KiB run demonstrates fit and functional execution only;
no 512 KiB timing comparison was repeated.

### CNN fused linear-row handoff — PASS, 396 samples

The 0x53 native tile-major output cannot be consumed directly by the next
FC's `M=4,K=36` descriptor, which expects one four-INT8 feature word at the
start of each 16-byte K line. Descriptor strides/address mapping alone cannot
express the required 4× expansion from compact tile-major storage. Added the
opt-in ABI-v7 `aux0[7]` mode: for bounded `M=4..64` divisible by four and
`N=4`, it writes one line per output row, low 32 bits containing four
requantized INT8 values and upper 96 bits zero. The consumer gets its exact
layout directly from Matrix; no testbench flattening or Host tensor transform
is used. The old `aux0[7]=0` contract is unchanged.

Both configurations use the same trained ten-class model and all 396 held-out
images at 128 KiB, with seed `20261106`. Both produce 384/396 classifications
(96.97%) and pass all per-sample intermediate/output Golden checks (396/396).
Model SHA-256 is
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`; test-set
SHA-256 is
`cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`.

| Measure per sample | Legacy Matrix + Host layout | Fused `0x53` linear-row | Change |
|---|---:|---:|---:|
| Top CMDQ cycles | 3,193 | 2,712 | −15.1% |
| Host layout cycles | 1,080 | 0 | −1,080 |
| Total measured task interval | 4,273 | 2,712 | −36.5% |
| Compute SPAD read/write | 6,048 / 1,920 B | 5,472 / 1,776 B | −576 / −144 B |
| Host layout read/write | 144 / 576 B | 0 / 0 B | eliminated |
| Total measured SPAD traffic | 8,688 B | 7,248 B | −16.6% |
| Useful MACs | 2,736 | 2,736 | unchanged |
| Useful MAC / total interval cycle | 0.640 | 1.009 | derived |
| Golden / accuracy | 396/396 exact; 384/396 | 396/396 exact; 384/396 | unchanged |

The 1,080 layout cycles are measured from the testbench AXI host sequence
(36 reads and 144 word writes at the configured simulation timing); they are
not operating-system wall time. The total interval excludes input preload and
post-run Golden reads on both sides. The new line writes use the existing
Matrix line port and reuse the existing 128-bit fused line buffer; the mode
adds three state bits plus address/data selection and control logic. No DC
area/timing/power run was available, so the physical cost is **BLOCKED_ENV**.

Run IDs: `V2-TRAINED-CNN-TOP-DATASET-4DAB736-LEGACY_LAYOUT` and
`V2-TRAINED-CNN-TOP-DATASET-4DAB736-LINEARIZED`. They were run using
`benchmark/tinynpu/run_nma_cnn_demo_dataset.py` with the tracked model and
testset paths above, `--candidate-sha 4dab73646989615c5479de0bac76d1488a102758`,
`--seed 20261106`, `--spad-base-shift 65536`; the optimized command adds
`--linearized`. Per-sample CSVs and 792 VCS logs are retained outside the
repository under `/tmp/nmaforge_round3_4dab_cnn_{legacy,linear}/`.

### Comparison boundaries

TinyNPU remains pinned to
`8216c22b762011aa20c05fc2768423fd12dda59d`. The current 3-GEMM/4-GEMV direct
array and modeled common-memory results remain in the performance report;
they are not rerun at this candidate. TinyNPU has not run this trained CNN or
Transformer through a matching Top/memory boundary. Therefore no new
system-level TinyNPU speedup is claimed.

The sections below are earlier dated model records. Their statements that a
trained Transformer was not run are historical and superseded by the bounded
synthetic task above; their fixed-weight fixture, prior CNN, and capacity
results retain their original source SHAs.

## Earlier research-baseline model status — 2026-11-06 (superseded below)

This earlier closeout snapshot is retained as historical evidence. Its
statement that the Transformer is only a fixed-weight fixture was superseded
by the Round 3 trained synthetic-task run at the top of this report. The
ten-class CNN result and the source-bound capacity measurements below remain
valid for their stated SHAs.

### Trained 10-class Digits CNN — complete for this bounded model

The checked-in flow trains a small INT8 CNN/readout using sklearn Digits:
1,401 stratified training images and all 396 held-out images, with test split
seed 29. Convolution weights use NumPy backpropagation with Adam for 250
epochs, batch 128, learning rate 0.006, training seed 44. The readout is
scikit-learn LogisticRegression (`C=1`, no intercept) trained on the deployed
integer convolution features. Model SHA-256 is
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`, test-set
SHA-256 is `cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`,
and independent integer Golden SHA-256 is
`249587647d45f3e3ef9a54d009a1896cc7d1daf9152de1e11bfba2f4a1b115bc`.

All 396 held-out samples completed the real Top CMDQ path and passed exact
intermediate/logit Golden checks. Both software and RTL classified 384/396
(96.97%). Per sample: 16 descriptors, 3,193 RTL compute cycles, 1,080 host
layout cycles, 2,736 useful MACs, 6,048/1,920 compute SPAD read/write bytes,
and 144/576 host-layout read/write bytes. These boundaries are kept separate;
host layout is not counted as RTL compute. The 396-row logs are summarized in
[`128 KiB`](../../benchmark/v2_trained_cnn_tenclass_top_128k_9576e53.csv) and
[`512 KiB`](../../benchmark/v2_trained_cnn_tenclass_top_512k_9576e53.csv)
machine-readable files. The exact trained weights, full test set, selected
input, Golden bytes, and manifests are checked in under
[`benchmark/models/nma_tiny_cnn_10class`](../../benchmark/models/nma_tiny_cnn_10class/).
Run ID: `V2-SPAD-CAPACITY-STUDY-20261106-9576E53`;
source/test SHA: `9576e539c21fe6312763c4745a90dc032c6457e0`; product RTL SHA:
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

### `conv1x_mini.onnx` and TinyNPU boundary

The pinned TinyNPU ONNX compiler and NMAForge Top produce identical Golden
bytes (`94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c`).
The NMAForge Top run passes at 128 KiB and 512 KiB: 8 descriptors, 1,985
compute cycles, 1,080 host-layout cycles, 3,360/1,600 compute SPAD read/write
bytes, 3,456 initialization bytes, and 1,872 useful MACs. The TinyNPU
Verilator graph runtime was not rerun here, so this is a Golden comparison,
not a cycle or system-level speedup comparison. TinyNPU SHA is
`8216c22b762011aa20c05fc2768423fd12dda59d`.

### Transformer status

The reusable 86-descriptor ABI-v7 Prefill/Decode fixture remains the only
current Transformer evidence: it uses deterministic hand-authored weights,
has 301 intermediate Golden checks, and reports 5,682 Prefill plus 5,715
single-token Decode cycles at its own fixed test SHA. It is not trained
weights, does not prove model quality or useful token generation, and does
not meet the trained-model requirement. Its static map high-water is 79,200
bytes; reduced-SPAD replay is `NOT_RUN_STATIC_ONLY`.

### Reproduction and evidence archive

The exact VCS/Python/NumPy/scikit-learn versions, training command, dataset
replay command, hashes, and capacity dispositions are recorded in
[`capacity study JSON`](../../benchmark/v2_spad_capacity_study_20261106.json).
The normalized four-workload benchmark table is rebuilt by
`python3 benchmark/tinynpu/build_v2_research_benchmark_matrix.py`.
The archived raw run logs are outside the Git repository at
`/tmp/nmaforge_v2_research_capacity_logs_9576e53.tar.gz` (SHA-256
`fd2c5c9816de8a9fefc1a4c07bb218d216a105b360b2ea0b5f61ae9ecb87a447`); the
CSV artifacts are checked in. No model result uses Host Fallback to produce
the final CNN logits.

## Bounded status update — 2026-11-06

The current TinyNPU GEMM/GEMV fixed matrix is recorded separately in the
[performance comparison](NMAFORGE_V2_PERFORMANCE_COMPARISON.md) and its CSV /
JSON artifacts. It reuses the pinned TinyNPU array model and does not contain a
TinyNPU memory controller result. The trained Digits MLP and `conv1x_mini`
ONNX evidence below remains the functional minimum for this round: Digits
matches all 360 independent Golden logits; the CNN matches all checked
intermediate tensors and final outputs. CNN cycle windows differ between the
two implementations, so this report makes no relative-speed claim.

Scratchpad capacity work is static only. The Digits fixed map reaches
351,232 bytes from SPAD base with a 79,776-byte full-data lower bound; a 128
KiB compact remap is plausible by byte count, but has not been generated or
run. The CNN fixed map reaches 135,296 bytes. No reduced-SPAD model replay or
remapped model timing was run.

**Status date:** 2026-11-06
**Latest fixed-weight Transformer Top replay:** `f9f32f71e7168350d74a75ede0a4a4b222844cc9`
**R250 baseline:** `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Latest trained-model Top replay candidate:** `9b835aeac33d43fd97a81496b1048d359cdff3d0`
**Latest Compute Cluster DV replay candidate:** `8758794c1f3bd6abb41c33276422b84ac5ee7a80`
**Product RTL SHA:** `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`
**Latest paired benchmark source SHA:** `c3a59f08d8c07a8da973010d0f23d5d6d7eed61b`
**TinyNPU reference:** `8216c22b762011aa20c05fc2768423fd12dda59d`

Later testbench-only source SHA `85e7db2d12f5edfaed17e8ca3910bb504983779f`
adds a real CMDQ GEMV/CNM ownership cross. It did not rerun any model workload
or change the model benchmark results below; this report's model run identities
and boundaries remain unchanged.

## Trained Digits MLP: matched RTL replay

The 360-image sklearn Digits test set was run against the same trained INT8
weights on R250 and v2. Both runs used seed `20261029`, the same model SHA and
the same independent integer Golden. The v2 path uses the real top and Matrix
datapath, ABI-v7 descriptors, CMDQ/CPLQ, and the opt-in fused `0x53`
Matrix output path. No host computation supplies hidden activations or logits.

| Measure | R250 | v2 candidate | Change |
|---|---:|---:|---:|
| Test images correct | 352/360 | 352/360 | unchanged |
| INT8 accuracy | 97.78% | 97.78% | unchanged |
| Exact RTL logits CSV | `7980fb67…10360e9c` | `7980fb67…10360e9c` | byte-identical |
| CMDQ descriptors | 69 | 46 | −23 |
| Doorbell-to-completion-tail cycles | 110,155 | 34,761 | −68.44% |
| Executed padded MACs | 1,884,160 | 1,884,160 | unchanged |
| MAC/cycle over full interval | 17.1046 | 54.2033 | 3.17× rate |
| Estimated 256-lane utilization | 6.68% | 21.17% | derived from RTL cycles |
| Layout-related busy cycles | 76,613 SFU tile-pack | 26,444 fused Matrix cycles | counter classes differ |
| Layout-related bytes | 117,760 accepted SPAD conversion bytes | 23,552 fused tile-write bytes | meanings differ; do not ratio |
| SPAD initialization traffic | 58,064 B | 56,224 B | setup only |

The model archive SHA-256 is
`e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`; the
integer Golden-logit SHA-256 is
`8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc`.
The R250 and v2 RTL logits files are byte-identical and have SHA-256
`7980fb678505ae0590d13c2f590b9523a98bedee7c3037936ccacb9b10360e9c`.

The timing counter starts immediately before the CMDQ doorbell write and stops
when the hardware completion tail reaches 46. It includes command execution,
completion commits and the hardware-visible completion interval. It excludes
testbench SPAD preload and post-run output reads/comparison. The fused-path
counter and legacy SFU tile-pack counter measure different internal events, so
their cycles are listed separately. The traffic fields likewise have different
definitions; no byte-reduction ratio is claimed here. Array utilization is a
derived simulation metric using 256 INT8 MAC lanes, not silicon utilization.

Exact replay command on the tested candidate SHA:

```sh
VCS_ARCH_OVERRIDE=linux \
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_digits_inference \
  AI_DIGITS_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  AI_DIGITS_RUN=/tmp/nmaforge_v2_digits_33e8528_replay
```

Result: VCS `V-2023.12-SP1_Full64`, Python 3.12.13, NumPy 2.4.6,
scikit-learn 1.9.1; `DIGITS_INFERENCE_PASS`, 360/360 outputs checked against
the independent integer Golden. Raw logs and generated model/input artifacts
are under `/tmp/nmaforge_v2_digits_33e8528_replay`; they are intentionally not
committed.

Machine-readable records: [CSV](../../benchmark/v2_digits_model_comparison.csv)
and [JSON](../../benchmark/v2_digits_model_comparison.json). The CSV includes
the field definitions and timing endpoints; empty stage fields mean that the
run did not instrument that stage.

## CNN and Transformer status

| Workload | Status | Evidence and boundary |
|---|---|---|
| ONNX `conv1x_mini` paired graph | **PASS; NMAForge side replayed at `d1867da`** | Current run `V2-TINYNPU-REPLAY-CURRENT-D1867DA-S20261029` rechecked all intermediate tensors and 4/4 outputs against the pinned model Golden. NMAForge: 1,985 compute + 1,080 host-layout cycles; TinyNPU: 4,781 graph cycles from prior run `TINY-COMPARE-V2C3A59-S20261029`. Different timing boundaries; no speedup ratio. |
| Trained-weight CNN | **PASS; full held-out Top run at `9b835ae`** | Four shared 3×3 convolution filters and the four-class INT8 readout are trained. All 159 held-out samples passed separate real Top CMDQ runs; every checked intermediate tensor/logit matched the independent integer Golden and all 159 classifications were correct on Digits labels 0–3. This is a scoped four-class model, not a full ten-class deployment. |
| Tiny Transformer | **PARTIAL** | The fixed-weight 86-descriptor Top prefill/decode fixture passes 301 intermediate/KV/final checks at `f9f32f7`; Top CMDQ interval is 11,397 cycles (5,682 prefill / 5,715 for one decode token). Weights are not trained or pretrained, and the one-token sample is not a steady-state decode result. |
| Host / DMA / compute / writeback / graph cycle split | **PARTIAL** | Digits has a top-level CMDQ interval and a fused Matrix activity counter; the current run does not separately time host, DMA, writeback and orchestration. Its input preload is testbench setup outside the timed interval. |

The current paired CNN uses the exact ONNX asset supplied by the pinned
TinyNPU checkout and archives model/input hashes with its machine-readable
results. Reproduction logs are archived at
`/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59_logs.tar.gz`
(SHA-256 `6825223159a0d75c6f876fc971d7b02f30be4fef5ae0c7d91911374add385cdf`);
the archive is outside Git to keep generated simulation logs out of the
repository. Exact commands and all measured/modelled boundaries are in the
[replay record](NMAFORGE_V2_TINYNPU_REPLAY_2026-11-05.md). No ASIC PPA,
measured Fmax, power, or energy result is inferred from these RTL runs.

## Next model-benchmark closure

1. Add common Memory Adapter behavior to TinyNPU or keep its memory service
   explicitly modeled; do not merge the two endpoints into a single score.
2. Extend the trained CNN beyond the current four-class Digits subset and
   measure each supported stage; add a small trained Transformer only with
   independent software Goldens and hardware-executed operators. Keep host
   fallback separately measured. Trained Transformer inference remains
   **NOT_RUN**.
3. Instrument distinct host, DMA, compute, writeback, and graph-orchestration
   windows for the larger model runs.
4. Preserve this Digits replay as the fixed regression and report each
   workload independently. Do not aggregate unlike cycle windows.

## Current fixed-weight Transformer replay — `3f87b03`

The existing ABI-v7 Top CMDQ workload was regenerated and rerun at test/tooling
SHA `3f87b033cb49c95f9ecb139b532714873a6c9476`; product RTL remains fixed at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. Command:

```sh
VCS_ARCH_OVERRIDE=linux \
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make ai_transformer AI_SEED=20261106 SEED=20261106
```

VCS `V-2023.12-SP1_Full64` and Python `3.12.13` generated 86 ABI-v7
descriptors over 60 tensors for four-token prefill plus one-token decode. The
real Top CMDQ path passed 301/301 intermediate, final, and KV checks and ended
with `TEST PASS`. This reconfirms the fixed deterministic fixture on the
current tooling candidate; the weights are hand-authored and are not trained
or pretrained. The logged 64 Matrix MAC activity cycles are not an end-to-end
latency measurement. This earlier replay did not measure end-to-end cycles;
the later fixed-weight replay below adds that measurement. TinyNPU comparison
and separate host/DMA/compute/writeback timing remain **NOT_RUN**. Compile
reported the known non-fatal `LOOP-REROLL-ENABLED` debug-capacity notice; there
were no compile errors or simulation error lines.

Run ID `V2-TRANSFORMER-FIXED-WEIGHTS-TOP-3F87B03-S20261106`. Machine-readable
record: [JSON](../../benchmark/v2_transformer_fixed_weights_3f87b03.json).
Compile and simulation logs are archived outside Git at
`/tmp/nmaforge_v2_transformer_fixed_weights_3f87b03_logs.tar.gz`, SHA-256
`30d0d0f744d5aa8a3ed04ca0d37aa30dac8de2aa5f5f31db87d39e78632d3e3e`.

## Fixed-weight Transformer Prefill/Decode timing — `f9f32f7`

The testbench timestamps the actual Top `processor_cplq_tail` update at the
generated Prefill/Decode boundary. The mapper records the 46-descriptor
Prefill prefix in the fixture/manifest; the remaining 40 descriptors execute
the one-token Decode path. This is testbench-only instrumentation. Product RTL
remains at SHA `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

At fixed test/tooling SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`, Mapper
unit tests pass 4/4. Three VCS Top runs on Seeds 20261106/07/08 each pass
301 independent intermediate, final, and KV checks for 86 descriptors and 60
tensors (903 checks total). Each run reproduces the same 10 ns simulation-clock
cycle counts:

| Interval | Top CMDQ cycles | Scope |
|---|---:|---|
| Four-token Prefill | 5,682 | Doorbell-start through completion of descriptor 46; 1,420.50 average cycles per prefilled token |
| One-token Decode | 5,715 | Completion of descriptor 46 through completion of descriptor 86; one observed token, not a steady-state average |
| Combined | 11,397 | Doorbell write begins through final completion-tail update |

The endpoint includes descriptor fetch/dispatch, compute, behavioral SPAD
service, and completion commits. It excludes testbench preload and the later
Golden read/compare. The 10 ns clock is a simulation setting, not a measured
silicon frequency. The Seed changes vary the simulator seed only; model
weights and workload remain fixed. This does not establish trained Transformer
inference, a TinyNPU speed comparison, ASIC timing, or separate
Host/DMA/Compute/Writeback/Graph-Orchestration costs. Compile emitted the known non-fatal
`LOOP-REROLL-ENABLED` debug-capacity notice; compilation and simulation had no
errors.

Run ID `V2-TRANSFORMER-FIXED-WEIGHTS-TIMED-TOP-F9F32F7-3SEED`. Machine record:
[JSON](../../benchmark/v2_transformer_timing_f9f32f7_3seed.json). Logs-only
archive outside Git:
`/tmp/nmaforge_v2_transformer_timing_f9f32f7_3seed_logs.tar.gz`, SHA-256
`664ddf0f3e59e9ee5919bb5bfdaf06aae90fc9bd8d0e14d2dcf86bf2d690a944`.

## Current fixed-candidate Digits replay — `410b81d`

The trained INT8 sklearn Digits MLP was rerun from the current fixed v2
candidate using the real top SPAD/CMDQ/CPLQ path and opcode `0x53`. Run ID is
`V2-DIGITS-410B81D-S20261029`. VCS
`V-2023.12-SP1_Full64`; Python 3.12.13, NumPy 2.4.6, scikit-learn 1.9.1.
Command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
AI_DIGITS_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
AI_DIGITS_RUN=/tmp/nmaforge_v2_digits_current_410b81 \
make ai_digits_inference \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10'
```

The replay passed 360/360 independent integer Golden logit checks and
classified 352/360 images (97.78%). It issued 46 descriptors and took 34,761
doorbell-to-completion-tail RTL cycles for 1,884,160 padded MACs, or 54.2033
MAC/cycle and 21.17% derived 256-lane utilization. The run logged 26,444
fused Matrix activity cycles and 23,552 bytes of fused tile writes. These
counters retain their own semantics and are not ASIC measurements.

Current artifact identities:

- Trained INT8 model SHA-256: `e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`.
- Independent integer Golden logits SHA-256:
  `8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc`.
- RTL logits CSV SHA-256:
  `7980fb678505ae0590d13c2f590b9523a98bedee7c3037936ccacb9b10360e9c`.
- Machine-readable current run record:
  [JSON](../../benchmark/v2_digits_410b81d.json) records the SPAD
  initialization-image, model, Golden and output hashes, endpoint, tool
  versions, and run limits.
- Combined run archive:
  `/tmp/nmaforge_v2_current_410b81_gemv_digits.tar.gz`, SHA-256
  `26b751910afa296181c1e85aab39910b71f0cdd49e196f493a5cdf1a22f9d5fa`.

The 360-image output and cycle result reproduce the previously reported v2
Digits result at this newer source/test SHA. This is not a trained CNN or
Transformer run. Separate Host, DMA, Compute, Writeback, and graph-orchestration
timers remain uninstrumented; ASIC PPA remains outside this simulation result.

## Current-candidate paired CNN functional replay — `d1867da`

The fixed-weight `conv1x_mini.onnx` workload was replayed through the current
NMAForge top, Matrix/SFU datapaths, CMDQ/CPLQ and behavioral SPAD. Executed Git
HEAD was `d1867da79a84b17451d63e919f9ce1e8ef4df098`; the intervening changes
from v2 source/test SHA `410b81dfd37992a760b28258bb7e8c6b6f5017d7` are
documentation and benchmark records only. VCS was
`V-2023.12-SP1_Full64`; Python 3.12.13, NumPy 2.4.6 and ONNX 1.17.0.

NMAForge passed all intermediate tensors and all four final output bytes.
The timed RTL window was 1,985 compute cycles plus 1,080 host-layout cycles;
SPAD traffic was 3,360 read / 1,600 write bytes for compute, with 144 read /
576 write bytes for host layout. The fixed TinyNPU model SHA is
`1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640` and the
input is generated with seed 99. TinyNPU's 4,781-cycle graph result is from
the pinned-reference replay at TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`; its timing boundary differs, so
no speedup ratio is reported. This is a fixed reference graph, not a trained
CNN model.

Reproduction command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_tinynpu_cnn_match \
  AI_TINYNPU_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  AI_TINYNPU_CNN_RUN=/tmp/nmaforge_v2_tinynpu_cnn_current_d1867da \
  AI_TINYNPU_CNN_MODEL=/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59/reference/source/models/conv1x_mini.onnx \
  AI_TINYNPU_CNN_GOLDEN=/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59/tiny_cnn/graph_cnn/golden.bin
```

The [current CNN CSV](../../benchmark/v2_tinynpu_current_d1867da_cnn.csv)
records both sides and their timing boundaries. Logs, generated manifest and
input/expected SPAD images are archived at
`/tmp/nmaforge_v2_tinynpu_current_d1867da_logs.tar.gz` (SHA-256
`018d11dc90159192f0fb13c5e5901269b66be7ff8013bf4891cfd26b1e9e7885`).
The model has fixed reference weights; trained CNN and trained Transformer
remain **NOT_RUN**.

## Verification-only update — 2026-11-06

The latest testbench/build candidate is `380f96114dba022300db09fb217264c3a606a2fd`
(tree `79aaf0782aba0da18d7109b74ae2bd343a473181`), with no product RTL
change. No model workload was rerun on this test-only commit. The Digits,
fixed `conv1x_mini`, and TinyNPU comparison results above remain bound to
their named source SHAs; trained-weight CNN/Transformer and separated stage
timing remain **NOT_RUN**. The v2 feature coverage evidence is recorded in the
[DV report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

### Later Top CMDQ verification provenance — 2026-11-06

The latest legal opcode `0x52` GEMV Top CMDQ replay at test/source SHA
`92874788fb2cb2a2b15657a3621e5a275a9d5990` adds maximum 16×16×16 execution
after the previously recorded M=N=K=1 and 3×5×5 points. It is testbench-only;
product RTL is unchanged and no model benchmark was rerun. Digits, fixed
`conv1x_mini`, and TinyNPU results remain tied to their separate SHAs and
timing boundaries listed above. This maximum-tile run is functional evidence,
not a performance measurement. Trained-weight CNN, trained Transformer, and
separated Host/DMA/Compute/Writeback/Orchestration timing remain **NOT_RUN**.

### Fixed-candidate model regression replay — `4b99d10`

On candidate `4b99d107270a572aec798de007f8c7167749d4af` (product RTL remains
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`), both existing model paths were
recompiled and replayed with VCS `V-2023.12-SP1_Full64` and Python 3.12.13.
These are regression replays of existing workloads, not newly trained CNN or
Transformer evidence.

| Run ID | Workload | Result | Timed RTL interval | Traffic / endpoint |
|---|---|---|---:|---|
| `V2-DIGITS-4B99D10-S20261029` | Trained INT8 sklearn Digits MLP, 360 images, 46 CMDQ descriptors | PASS: 360/360 exact integer-Golden logits; 352/360 classified correctly (97.78%) | 34,761 doorbell-to-completion-tail cycles | 1,884,160 padded MACs; 54.2033 MAC/cycle; 21.17% derived 256-lane utilization; 56,224 B initialization excluded from timed interval |
| `V2-CNN-4B99D10-S20261029` | Fixed TinyNPU `conv1x_mini` reference graph, 8 CMDQ descriptors | PASS: every checked intermediate tensor and all 4 output bytes match independent Golden | 1,985 compute cycles; separate 1,080 host-layout cycles | Compute: 3,360 B read / 1,600 B written; host layout: 144 B read / 576 B written; 3,456 B initialization excluded |

The fixed TinyNPU reference comparison remains **not timing-equivalent**: its
4,781 graph cycles use another endpoint and exclude different setup/read work.
No speedup conclusion is derived. The Digits accuracy is a trained MLP result,
not a CNN result. A trained-weight CNN, trained Tiny Transformer, and separate
Host/DMA/Compute/Writeback/Graph-Orchestration stage timers remain **NOT_RUN**.

Reproduction commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
AI_DIGITS_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
AI_DIGITS_RUN=/tmp/nmaforge_v2_digits_current_4b99d10 \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/subsystem/top_smoke/sim ai_digits_inference

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
AI_TINYNPU_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
AI_TINYNPU_CNN_RUN=/tmp/nmaforge_v2_tinynpu_cnn_current_4b99d10 \
AI_TINYNPU_CNN_MODEL=/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59/reference/source/models/conv1x_mini.onnx \
AI_TINYNPU_CNN_GOLDEN=/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59/tiny_cnn/graph_cnn/golden.bin \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/subsystem/top_smoke/sim ai_tinynpu_cnn_match
```

Machine-readable result rows are in
[`v2_model_replay_4b99d10.csv`](../../benchmark/v2_model_replay_4b99d10.csv)
and [`v2_model_replay_4b99d10.json`](../../benchmark/v2_model_replay_4b99d10.json).
Combined raw log/evidence archive:
`/tmp/nmaforge_v2_model_replay_4b99d10_logs.tar.gz`, SHA-256
`acd7e8e44778ce5c3465798708f8e32ddbeb979f64030fd92c2756d42acfb801`.
The archive stays outside Git because it contains generated simulator output.

## Trained four-class CNN Top demo — `835f958`

The existing real Top graph path now also accepts a generated NPZ weight
package and explicit INT8 input fixture. The small model uses four fixed 3×3
edge filters and a trained four-class INT8 LogisticRegression readout. The
readout is trained on the actual quantized convolution feature values, so the
reported 158/159 (99.37%) held-out accuracy measures the deployed rounding,
clamping and activation contract. The convolution filters were not trained;
this scoped benchmark must not be read as a generally trained CNN deployment.

Candidate SHA `835f958b5f486b3f3e4808e735a788721f4f1441`; product RTL remains
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. VCS
`V-2023.12-SP1_Full64`, Python 3.12.13, NumPy 2.4.6, scikit-learn 1.9.1.
Run ID `V2-TRAINED-CNN-835F958-S20261029` passed the full Top CMDQ path on one
held-out image: label/prediction class 0, logits `[87,-73,-19,5]`, all
intermediate stage memory and final output matched the independent software
Golden byte-for-byte. Golden SHA-256:
`0760b44581d5d257f4009b7ba06cd39b02644009ad0f4b6b2796d1a6a543f9d2`.

The Top interval was 1,985 compute cycles plus 1,080 separately counted host
layout cycles. It performed 1,872 useful MACs; compute SPAD traffic was 3,360
read and 1,600 write bytes; testbench preload was 3,456 bytes and is excluded.
This first selected-sample run was subsequently expanded to all held-out inputs
in the full replay below. The model still uses fixed convolution filters, and
no TinyNPU speedup or common-memory comparison is inferred.

Reproduce with:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
AI_TRAINED_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
AI_TRAINED_CNN_RUN=/tmp/nmaforge_v2_trained_cnn_835f958 \
make -C dv/subsystem/top_smoke/sim ai_trained_cnn_demo
```

Machine-readable evidence:
[`v2_trained_cnn_demo_835f958.csv`](../../benchmark/v2_trained_cnn_demo_835f958.csv)
and [`v2_trained_cnn_demo_835f958.json`](../../benchmark/v2_trained_cnn_demo_835f958.json).
Model, input, Golden, compile/run logs and smoke logs archive:
`/tmp/nmaforge_v2_trained_cnn_835f958_evidence.tar.gz`, SHA-256
`f0919d1f3b74ff6442ec33c300c7fdf9f88e4f6e842004288f5b4582c691287e`.
Generated model weights and simulation databases remain outside Git.

## Historical full held-out-set Top replay — `de22e46`

The same model and test split were then run end-to-end for all 159 held-out
images. Run ID `V2-TRAINED-CNN-TOP-DATASET-DE22E46`, candidate
`de22e4652a54dfe7537e14585bdf3ae6f08fe9fb` (tree
`29d35cadabd84872081dc7f6d51a7398cfb431b5`), product RTL unchanged at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. All 159 independent Top instances
passed; every checked Conv, requant, ReLU/layout, FC and output memory image
matched the independent Golden. The hardware-checked classification result is
158/159 (99.37%). VCS was `V-2023.12-SP1_Full64`; Python 3.12.13, NumPy 2.4.6,
scikit-learn 1.9.1.

Per image: 1,985 compute cycles + 1,080 host-layout cycles, 1,872 useful MACs,
3,360 B compute reads / 1,600 B compute writes, and 144 B host-layout reads /
576 B host-layout writes. The 3,456 B testbench preload is outside the timed
interval. These are behavioral-SPAD RTL results, not ASIC measurements.
The `0.9433` useful MAC/compute-cycle ratio and derived 0.3685% of 256 lanes
are scoped to this small fixed workload, not a large-array throughput claim.

The software model has four fixed 3×3 edge kernels and a trained four-class
INT8 LogisticRegression readout trained on the deployed quantized Conv
features. This proves the trained head's model path, not end-to-end trained
convolution filters. TinyNPU was not run on this model; no relative performance
claim is available. The fixed `conv1x_mini` TinyNPU compatibility workload
remains a separate run with its previously documented timing-boundary caveat.

Reproduce the training and every Top inference with:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
AI_TRAINED_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
AI_TRAINED_CNN_RUN=/tmp/nmaforge_v2_trained_cnn_dataset_de22e46 \
make -C dv/subsystem/top_smoke/sim ai_trained_cnn_dataset_regress
```

Full per-sample results are in
[`v2_trained_cnn_dataset_de22e46.csv`](../../benchmark/v2_trained_cnn_dataset_de22e46.csv)
and summary metadata in
[`v2_trained_cnn_dataset_de22e46.json`](../../benchmark/v2_trained_cnn_dataset_de22e46.json).
The archive includes model/input/testset hashes, all 159 run logs, compile log,
and Golden records:
`/tmp/nmaforge_v2_trained_cnn_dataset_de22e46_evidence.tar.gz`, SHA-256
`dfacc9a6a7e17150def4814cfe9baad11b8c21675d75db1505c0b907c80de1be`.

## 2026-11-06 update — trained convolution weights on full held-out Top set

The previous `de22e46` run used fixed convolution filters. The training flow
now learns four shared 3×3 convolution filters with deterministic NumPy/Adam
(250 epochs, batch 128, learning rate 0.006, seed 44), then trains the INT8
readout on deployed quantized convolution features. The evaluated dataset is
still deliberately scoped to sklearn Digits labels 0–3: 561 training and 159
stratified held-out samples (`random_state=29`).

At candidate SHA `9b835aeac33d43fd97a81496b1048d359cdff3d0` (tree
`04215a9fb125e57aa6a9ce6ead2410f59bafa2b7`), product RTL remains
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. Run ID
`V2-TRAINED-CNN-TOP-DATASET-9B835AE` passed 159/159 separate Top CMDQ runs.
Every checked convolution, requantization, activation/layout, FC, and output
memory image matched the independent integer Golden. All 159 classifications
were correct (100% on this four-class test split). VCS was
`V-2023.12-SP1_Full64`; Python 3.12.13, NumPy 2.4.6, scikit-learn 1.9.1;
simulation seed `20261029`.

Each sample used 1,985 RTL compute cycles and 1,080 separately counted
host-layout cycles, with 1,872 useful MACs. Compute SPAD traffic was 3,360 B
read and 1,600 B write; host-layout traffic was 144 B read and 576 B write.
Testbench preload was 3,456 B and is excluded from these cycle intervals. The
derived useful rate is 0.9433 MAC/RTL-compute-cycle, or 0.3685% of the nominal
256 INT8 lanes for this small workload; it is not a large-matrix utilization
claim. Aggregate over 159 runs: 315,615 RTL compute cycles, 171,720
host-layout cycles, 534,240/254,400 B compute read/write, and 297,648 useful
MACs. These are behavioral-SPAD Top simulation results, not ASIC measurements.

Reproduce the clean-source model training and all 159 Top inferences with:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
AI_TRAINED_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
AI_TRAINED_CNN_RUN=/tmp/nmaforge_v2_trained_learned_cnn_9b835ae \
make -C dv/subsystem/top_smoke/sim ai_trained_cnn_dataset_regress
```

Machine-readable per-sample results and run summary:
[CSV](../../benchmark/v2_trained_cnn_top_dataset_9b835ae.csv) and
[JSON](../../benchmark/v2_trained_cnn_top_dataset_9b835ae.json). Model SHA-256
is `bf19003c13bdc641c560bc380b22534c04bea4c23e5904261160c2c9f841edb1`;
test-set SHA-256 is
`4e000728b8e2a6496d7d3fa1439a16b44361d93f433f0a528076410592f31282`; the
selected-sample independent Golden SHA-256 is
`a391badd117ff5ac77e7b51266fd04f6164d09fa5e6bc81775f7f4075f7605c3`.
The archive contains the 159 per-sample Top logs and replay inputs/Goldens,
plus model and compile/run records, but excludes simulator binaries, databases,
waveforms, and `ucli.key`:
`/tmp/nmaforge_v2_trained_cnn_dataset_9b835ae_seed20261029_evidence.tar.gz`
(SHA-256
`c2eb02228567c4f33d5a53a5020c67b7a927cdd2095b3e193c32ff46669ff71d`).

No TinyNPU comparison was run on these trained weights, so this result makes no
relative speedup claim. The ten-class CNN and trained Tiny Transformer remain
open; v2 functional sign-off and ASIC PPA are also not implied by this model
run.

## 2026-11-06 update — fixed-weight Transformer fixture replay

At the clean detached source SHA
`9b835aeac33d43fd97a81496b1048d359cdff3d0` (product RTL
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`), the existing
`transformer_micro_4x4_prefill_decode` fixture was regenerated and run through
the production Top CMDQ path. Run ID
`V2-TRANSFORMER-FIXED-WEIGHTS-TOP-9B835AE-S20261106`, VCS
`V-2023.12-SP1_Full64`, Python 3.12.13, Seed `20261106`: the mapper emitted 86
ABI-v7 descriptors and 60 tensors with closed data dependencies and poison
initialization. Top simulation finished with `TEST PASS`; all checked
intermediate tensors, final prefill/decode states, KV cache and readback values
matched the mapper's integer Golden. There were 301 Transformer-labeled PASS
checks in the run log.

This fixture has one attention head, hidden size 4, four-token prefill and
one-token decode. It uses hand-authored deterministic non-identity INT8 test
weights, not a trained checkpoint. The result verifies operator composition
and KV address/data flow only. The Top run reports a 64-cycle Matrix MAC
activity counter, but no end-to-end latency or cycles/token interval was
measured, so performance is **NOT_RUN** and the trained Transformer demo stays
**NOT_RUN**.

Reproduce from repository root:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/subsystem/top_smoke/sim ai_transformer \
  AI_RANDOM_CASES=0 AI_SEED=20261106 SEED=20261106
```

Machine-readable run record:
[JSON](../../benchmark/v2_transformer_fixture_9b835ae.json). Compile/run logs,
the generated manifest and SystemVerilog workload are archived outside Git at
`/tmp/nmaforge_v2_transformer_fixture_9b835ae_s20261106_evidence.tar.gz`
(SHA-256
`9b994707c392f0b2ba98cbb26f0235c5fea97c2ece7b5fe6bd0a306caf668387`). The
archive excludes simulator binaries, databases, and waveforms.

## Current-candidate status check — `839b9af`

The clean-candidate VCS replay at `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`
covered Top smoke, Compute Cluster UVM, focused opcode tests, and Matrix
performance only; trained-model workloads were not rerun at that SHA. Model
evidence therefore remains tied to the separate source identities above: the
10-class Digits MLP and four-class trained CNN have Golden-checked Top results,
while the 86-descriptor Transformer fixture uses deterministic test weights
and is not evidence of trained-model inference. A TinyNPU same-task comparison
and the full host/DMA/compute/writeback timing split remain open. No model
result is recast as current-candidate performance or as v2 DV/ASIC sign-off.

## Research closure round 2 — compact MLP and bounded Transformer replay

The only code change in this round is test/workload plumbing at commit
`acfaec281f5414c0e357c1dc7985b79a829c8c30`; product RTL remains at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

| Model/run | SPAD | RTL cycles | Host layout | Golden / accuracy | Run ID |
|---|---:|---:|---:|---|---|
| Trained Digits INT8 MLP, 360 held-out samples | 128 KiB | 34,761 | N/A between layers; preload excluded | Independent integer Golden, exact logits; 352/360 (97.78%) | `V2-R2-DIGITS-MLP-128K-S20261029` |
| Same Digits MLP and compact map | 512 KiB | 34,761 | N/A between layers; preload excluded | Same byte-identical logits; 352/360 (97.78%) | `V2-R2-DIGITS-MLP-512K-S20261029` |
| Existing 86-descriptor Transformer fixture | 128 KiB | 11,397 (5,682 prefill + 5,715 one-token decode) | Fixture-defined | 301 Transformer Golden/KV checks pass; weights deterministic hand-authored, not trained | `V2-R2-TRANSFORMER-FIXTURE-128K-S20261106` |

The MLP model SHA is `e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`;
the integer-Golden logits SHA and both RTL output CSV SHAs are
`8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc` and
`7980fb678505ae0590d13c2f590b9523a98bedee7c3037936ccacb9b10360e9c`,
respectively. Both capacity runs use the same 93,184-byte compact static map,
46 descriptors, 1,884,160 useful MACs, 54.2033 MAC/cycle, and 21.17% derived
array utilization. This is a placement-only fit result, not streaming or a
physical-SRAM timing result.

Transformer fixture timing is scoped evidence only. The enclosing full Top
smoke ended `TEST FAIL errors=23` because existing non-Transformer checks
probe the 512 KiB boundary and depend on larger-SPAD/all-engine behavior;
the fixture's 301 own Golden/KV checks and timing completed. No trained
Transformer checkpoint or training pipeline is present in the repository,
and the current mapper hardcodes deterministic fixture weights. Therefore a
trained-weight Transformer is **NOT_RUN / BLOCKED_MODEL_PIPELINE**; the fixed
fixture must not be described as trained inference.

The fixture compatibility audit finds a bounded one-layer path at hidden size
4, one head, four-token prefill and one-token decode. Its descriptor chain
exercises Q/K/V projection and packing, KV writes/reads, QK transpose, causal
softmax, attention-value projection, output projection, residuals, layer norm,
FFN up/GELU/down, and decode KV-cache update. These operator classes already
exist in the mapped fixture; the gap for this task is trained checkpoint,
training/export and external weight-loading support, not proof that a new
hardware engine is required. This shape-limited compatibility result does not
establish a useful language model or general Transformer compiler.

Machine-readable per-run details, exact commands, tool versions and log hashes
are in the [round-2 record](../../benchmark/v2_round2_research_closure_20261106.json)
and [capacity CSV](../../benchmark/v2_round2_capacity_mlp_20261106.csv).
