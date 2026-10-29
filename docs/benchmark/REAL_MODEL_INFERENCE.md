# Trained Digits Model Inference on NMAForge RTL

## Result

The `sklearn.datasets.load_digits` experiment trained a two-layer `64-64-ReLU-10`
MLP with NumPy Adam, quantized its weights to signed INT8, and executed both
GEMMs plus the hidden ReLU/requantization through the production NMAForge top.
The run used ABI-v7 descriptors, CMDQ/CPLQ, the real Matrix and SFU engines,
AXI-loaded SPAD contents, and completion checking. It was not a fixed-random-
weight smoke test.

| Measure | Result |
|---|---:|
| Test set | 360 real 8×8 images; split seed `20261029` |
| FP32 accuracy | 352/360 = 97.78% |
| INT8 accuracy | 352/360 = 97.78% |
| INT8 vs independent integer Golden | Exact match for all checked hidden and output values |
| Hardware commands | 69 descriptors in one CMDQ submission; GEMM → SFU tile pack → GEMM per batch |
| CMDQ execution interval | 110,155 cycles from doorbell submission to hardware completion-tail update; 305.99 cycles per test image |
| Host layout bridge | 0 host layout cycles and 0 host layout bytes |
| SFU Matrix-A tile pack | 76,613 SFU busy cycles; 117,760 accepted SPAD bytes for INT32 reads and packed INT8 writes |
| Executed MAC operations | 1,884,160 including the padded final batch |
| Measured MAC/cycle | 17.1046 over the full CMDQ interval |
| Estimated array utilization | 6.68% of the 256 INT8 MAC lanes |
| SPAD image initialization | 58,064 bytes; this is setup traffic, not total SPAD traffic |

The 23 batches contain 368 slots; the final batch has eight padded samples. The
classifier stores ten useful logits in a sixteen-column tile; padded columns
are checked to be zero. Accuracy is computed on the 360 real test samples.

## Reproduction

Run from the repository root in a Linux environment with VCS, NumPy, and
scikit-learn available:

```sh
make inference-digits \
  AI_DIGITS_RUN=/tmp/nmaforge_digits_hw_layout_20261029_replay \
  AI_DIGITS_PYTHON=python3.11 PYTHON=python3.11
```

The current tiled-layout run used VCS `V-2023.12-SP1_Full64`, Python 3.11.13,
NumPy 2.4.6, and scikit-learn 1.9.1 on source SHA
`63071c14dc3025d06d1ece620e0d52d200265e23`. The independent checker reported
`rtl_output_compared: true` and `independent_integer_golden: PASS`. Quantized
model SHA-256:
`e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`.

## Hardware Matrix-A layout bridge

The previous host reorder has been removed. On source SHA
`63071c14dc3025d06d1ece620e0d52d200265e23`, SFU `REQUANT_I8` flag
`PACK_I8_TILE_A` writes the hidden activation directly in Matrix A tile order.
A single submission runs all 69 descriptors. The testbench compares all 5,888
packed hidden words at their final SPAD addresses and all 360×12 output logits
against the independent integer Golden; it performs no intermediate SPAD
read/reorder/write. Run ID: `DIGITS-HW-TILE-LAYOUT-20261029`.

```text
DIGITS_RTL_METRICS samples=360 correct=352 descriptors=69 cycles=110155 host_layout_cycles=0 host_layout_bytes=0 rtl_layout_cycles=76613 rtl_layout_bytes=117760 mac=1884160 mac_per_cycle=17.1046 array_utilization=6.68% spad_initialization_bytes=58064
DIGITS_INFERENCE_PASS model=sklearn_digits_int8 rtl=top_spad_cmdq_cplq accuracy=97.78%
```

VCS `V-2023.12-SP1_Full64`, Python 3.11.13, NumPy 2.4.6, and scikit-learn
1.9.1 were used. The checker reported exact RTL/Golden output agreement,
97.78% INT8 accuracy, and Golden-logit SHA-256
`8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc`.
`cycles` measures from doorbell submission until the completion tail updates;
`rtl_layout_cycles` counts cycles with the SFU busy in tile-pack mode. The
117,760-byte figure counts only accepted SPAD traffic for this conversion, not
all Compute Cluster traffic.

The full Digits inference was replayed from clean source SHA
`6848a414eaeaa05cf9e1411cf55d9d27333208a6` after scoping descriptor bit-5
validation to `REQUANT_I8`. Run ID `DIGITS-HW-TILE-LAYOUT-CLEAN-6848A41` used
VCS `V-2023.12-SP1_Full64`, Python 3.11.13, NumPy 2.1.3 and scikit-learn
1.6.1, seed `20261029`. It again passed 360 samples with 352 correct, 69
descriptors and exact independent integer Golden results. The current-source
log reports `host_layout_cycles=0` and `host_layout_bytes=0`; artifacts are
under `/tmp/nmaforge_digits_final_6848a41/`.

The same source SHA passed the focused checks:

```sh
make -C dv/block/compute/sfu/sim random-latency-regress \
  SEEDS='20261029 20261030 20261031' \
  OUT_DIR=/tmp/nmaforge_sfu_tile_a_final_20261029
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=4 AI_SEED=20261029
```

SFU reported `tile_a_pack=1` and 9 error cases on all three seeds; top smoke
ended `TEST PASS` and included a descriptor-validator negative case for an
invalid `M×N` extent. VCS emitted the existing
`[LOOP-REROLL-ENABLED]` warning for the fixed Transformer fixture.

## Fixed-SHA replay

The root `make inference-digits` entry was rerun after the paired-CNN harness
commit on source SHA `110e0c9db49eb1a7a558c955347accfde87f963e` (Run ID
`DIGITS-RTL-20261029-110e0c9`). With VCS `V-2023.12-SP1_Full64` and the same
Python 3.11.13/NumPy 2.1.3 environment, it passed 360 samples with 352 correct,
69 descriptors, 93,653 Matrix/SFU cycles, and exact independent integer Golden
matches. Model and Golden hashes match the earlier replay. The paired ONNX CNN
testbench adds no product RTL changes.

The public root target was rerun after the harness commit on source SHA
`df7335871068c6e2fbbc6a0eaad315d6c5815fef`:

```sh
make inference-digits \
  AI_DIGITS_RUN=/tmp/nmaforge_digits_root_target_20261029 \
  AI_DIGITS_PYTHON=/tmp/nmaforge_ai_venv_20261029/bin/python
```

Run ID: `DIGITS-RTL-20261029-ROOT-REPLAY`. VCS again reported 360 samples,
352 correct, 69 descriptors, 93,653 Matrix/SFU cycles, and 97.78% accuracy;
the independent integer Golden matched all outputs. Quantized model and Golden
SHA-256 values matched the run recorded above. These earlier runs used the
host layout bridge and are retained as historical evidence; the hardware tile
packing run above supersedes their layout-conversion result.

The root `make inference-digits` target passed again on earlier research SHA
`6115212e8587f2ca3374787df358761eada7d7ee` (Run ID
`DIGITS-RTL-20261029-6115212`) using VCS `V-2023.12-SP1_Full64`, Python
3.11.13, NumPy 2.1.3, and scikit-learn 1.6.1. It reproduced 352/360 correct
predictions (97.78%), all 69 descriptors, 93,653 Matrix/SFU RTL cycles, and
exact independent integer Golden outputs. That SHA predates hardware tile
packing and reported the 70,656-cycle host layout bridge separately. Its
compile retained the existing `[LOOP-REROLL-ENABLED]` fixture warning.

## Data layout and limits

Matrix writes INT32 accumulations in row-major order while its A operand reader
expects 4×4 microtile order. `PACK_I8_TILE_A` now performs that conversion in
the SFU: row-major INT32 input is requantized, packed, and written directly in
Matrix A tile order. Dependency events chain each batch's GEMM, SFU, and
following GEMM. The testbench only reads the final hidden memory image for
comparison; it does not reorder or write intermediate data. SPAD is behavioral
RTL memory, and these cycles are neither physical SRAM timing nor ASIC PPA.

The earlier host-reorder measurements at SHAs `e9d661c`, `110e0c9`,
`df73358`, and `6115212` are historical baselines, superseded by the hardware
tile-pack result above.

The checked-in trained weights and training metadata are in
[`benchmark/digits/artifacts`](../../benchmark/digits/artifacts/). Raw VCS
executables, coverage databases, waveforms, and logs stay outside the source
tree under `/tmp`. This result closes the trained digits-classifier experiment
only. It does not establish pretrained GPT-2/Qwen inference, whole-NPU
sign-off, or deployment quality on other image distributions.

## Existing Transformer functional workload

The root `make inference-transformer TRANSFORMER_SEED=20261029` target passed
on source SHA `df7335871068c6e2fbbc6a0eaad315d6c5815fef` with VCS
`V-2023.12-SP1_Full64` (Run ID `TRANSFORMER-FIXED-20261029`). The test checked
86 ABI-v7 descriptors, command/completion ordering, prefill/decode Q/K/V and
KV-cache words, and final completion words. The checked-in mapper uses
deterministic functional weights and a four-token fixture. This verifies the
available operator/dataflow path; it is not TinyGPT training, pretrained
checkpoint loading, or a language-model quality result.

The same public entry point was replayed after the sign-off evidence commit on
source SHA `530d0816c5f5cc3c442f79b5a9517fc299a6c4b2`; VCS
`V-2023.12-SP1_Full64`, seed `20261029`. Run ID
`TRANSFORMER-FIXED-20261029-530d081`. It passed the 86-descriptor/60-tensor
mapper precheck, intermediate and completion checks, and final `TEST PASS`.
The existing `[LOOP-REROLL-ENABLED]` fixture warning remains. The workload
still uses deterministic functional weights and is not a trained or
pretrained language-model deployment.

The fixture passed once more on source SHA
`6115212e8587f2ca3374787df358761eada7d7ee` (Run ID
`TRANSFORMER-FIXED-20261029-6115212`), seed `20261029`. VCS checked the same
86 descriptors, 60 tensors, intermediate values, and completion words, ending
with `TEST PASS`. The `[LOOP-REROLL-ENABLED]` fixture warning remains. This is
still a fixed-weight functional datapath test, not trained TinyGPT inference.
