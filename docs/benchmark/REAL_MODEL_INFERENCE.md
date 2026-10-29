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
| Hardware commands | 69 descriptors over two CMDQ execution phases |
| Matrix/SFU RTL cycles | 93,653 total; 260.14 cycles per test image |
| Host layout bridge | 47,104 bytes and 70,656 cycles, reported separately |
| Compute plus host layout | 164,309 cycles, or 456.41 cycles per test image |
| Executed MAC operations | 1,884,160 including the padded final batch |
| Measured MAC/cycle | 20.1185, using RTL compute cycles only |
| Estimated array utilization | 7.86% of the 256 INT8 MAC lanes |
| SPAD image initialization | 58,064 bytes; this is setup traffic, not total SPAD traffic |

The 23 batches contain 368 slots; the final batch has eight padded samples. The
classifier stores ten useful logits in a sixteen-column tile; padded columns
are checked to be zero. Accuracy is computed on the 360 real test samples.

## Reproduction

Run from the repository root in a Linux environment with VCS and the listed
Python packages available:

```sh
make -C dv/subsystem/top_smoke/sim ai_digits_inference \
  AI_DIGITS_RUN=/tmp/nmaforge_digits_rtl_20261029_replay \
  AI_DIGITS_PYTHON=python3
```

The run used VCS `V-2023.12-SP1_Full64`, Python 3.11.13, NumPy 2.1.3, and
scikit-learn 1.6.1. It completed on research branch
`feat/tinynpu-model-inference`, source SHA
`e9d661c0f36d4b9878bd90d80fa4d1ad05e042b1`.

Run ID: `DIGITS-RTL-20261029-FINAL`.

The VCS log reported:

```text
DIGITS_RTL_METRICS samples=360 correct=352 descriptors=69 cycles=93653 host_layout_cycles=70656 host_layout_bytes=47104 mac=1884160 mac_per_cycle=20.1185 array_utilization=7.86% spad_initialization_bytes=58064
DIGITS_INFERENCE_PASS model=sklearn_digits_int8 rtl=top_spad_cmdq_cplq accuracy=97.78%
```

The independent checker reported `rtl_output_compared: true`,
`independent_integer_golden: PASS`, and the same 97.7778% accuracy. The quantized
model SHA-256 is
`e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`; the
integer-logit SHA-256 is
`8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc`.

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
SHA-256 values matched the run recorded above. The host layout bridge remains
47,104 bytes and 70,656 cycles, so this replay does not close the autonomous
host-free inference gap.

The root `make inference-digits` target passed again on current research SHA
`6115212e8587f2ca3374787df358761eada7d7ee` (Run ID
`DIGITS-RTL-20261029-6115212`) using VCS `V-2023.12-SP1_Full64`, Python
3.11.13, NumPy 2.1.3, and scikit-learn 1.6.1. It reproduced 352/360 correct
predictions (97.78%), all 69 descriptors, 93,653 Matrix/SFU RTL cycles, and
exact independent integer Golden outputs. The 70,656-cycle host layout bridge
is reported separately. The compile retains the existing
`[LOOP-REROLL-ENABLED]` fixture warning.

## Data layout and limits

Matrix writes INT32 accumulations in row-major order while its A operand reader
expects 4×4 microtile order. The existing ABI does not provide an in-engine
conversion for this layout. The experiment therefore runs the first Matrix
and SFU phase for all batches, reads/reorders/writes the quantized hidden
activations in the host testbench, then submits the second Matrix phase. That
bridge is counted separately above; it is not represented as autonomous,
host-free end-to-end inference. SPAD is behavioral RTL memory, and these
cycles are neither physical SRAM timing nor ASIC PPA.

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
