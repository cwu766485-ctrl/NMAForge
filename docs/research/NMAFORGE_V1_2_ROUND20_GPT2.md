# NMAForge v1.2 Round 20 — GPT-2 Track Closure

## Disposition

**Track A: `PARTIAL`.** A newly trained H64 byte-level next-token model was
executed by the four-layer Product Top. Four feedback decisions were based on
the Top's 256 signed INT32 logits and matched an independent integer reference
bit-for-bit. The held-out INT8 model quality is poor (12.70% next-byte
accuracy, below the measured 28.71% bigram baseline), so this is not a
quality-qualified language model. The run is prefix recomputation, not
query-only incremental decode. A like-for-like TinyNPU performance result was
not produced.

## Frozen source, model and tool environment

| Item | Value |
|---|---|
| Research branch | `research/nmaforge-v1.2-round20-gpt2` |
| Product/test source used by VCS | `f7e65ed02b64dfd1faf49e7a9a25222f5b6bd560` |
| Product RTL tree | `8798decc60fe257ef685a0b1c7e8814816e1d4de` |
| Top smoke/testbench tree | `4baaa3ace96bd0dcbd5d715ba6f1c43bf14854f5` |
| Runtime run ID | `R20-A-H64-TRAINED-BYTE-LM-AR-HOST-20261120` |
| Seed / prompt | `20261120` / `[1,7,42,3]` |
| VCS | Synopsys V-2023.12-SP1_Full64 |
| Python stack | Python 3.12.13, NumPy 2.5.4, PyTorch 2.6.0+cpu |
| Model package SHA-256 | `2132835994c2ecce03dc1d8e7345474eeddb271d86e34de9cc1f5ccdf2fecfc2` |
| Training manifest SHA-256 | `2cb006dc7ae1d3b7db7a8cd5dc286b34c8e14ed96f41b89385c321127f2ed02e` |
| INT8 quality result SHA-256 | `b481668d7c8b23c54275a5c93ebeb8244a63dea689e74ff75ed050ed3bdf85de` |
| Independent Top integer check SHA-256 | `6e41e9e15f8eb72eea63f02683f4fb58f55db18b736c61e6cce7ead80c143f16` |

The model is trained from scratch on a byte-level Tiny Shakespeare corpus pinned
to source commit `6f9487a6fe5b420b7ca9afb0d7c078e37c1d1b4e` (1,115,394 bytes,
SHA-256 `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed`).
The split is first 90% train / final 10% held-out. Architecture: H64, four
heads of 16, four pre-LN decoder layers, FFN 256, vocabulary 256, context 16,
GELU FFN, tied embedding/LM head. Training used deterministic CPU AdamW,
seed 20261120, 1,200 steps, batch 32, learning rate 3e-4 and weight decay
0.01. FP32 checkpoint SHA-256:
`1d59cf803c328149add9ddb004766e63043b3babdb56ea178bf96d7a51fda8df`.

This is an NMAForge-compatible GPT-2-like research model, not original GPT-2
and not a fine-tuned GPT-2 checkpoint. INT8 scales are recorded in
`benchmark/gpt2_quality/results/round20_training_manifest.json`: embedding and
position ×8, matrix weights ×32, LayerNorm gamma ×32, beta ×8, signed INT8
saturation. Product Q5 logits are divided by 32 for cross entropy/perplexity;
argmax is unchanged by this positive scale. The initial evaluation code used
raw Q5 logits for CE and produced an invalid metric; the evaluation was fixed
and rerun with the declared scale. The corrected values below supersede that
invalid calculation.

## Model quality

Evaluation used 64 deterministic held-out windows, 16 targets each (1,024
next-byte targets), seed 20261121. The simple bigram baseline uses the same
evaluation windows.

| Model | Held-out CE (nats) | Perplexity | Next-byte accuracy |
|---|---:|---:|---:|
| FP32 | 2.1440 | 8.53 | 39.16% |
| Product-contract INT8 | 6.1536 | 470.40 | 12.70% |
| Bigram baseline | — | — | 28.71% |

FP32/INT8 top-1 agreement is 20.21%; INT8 loses 26.46 percentage points from
FP32 and trails the bigram baseline. **Model quality gate: FAIL for useful
language-model deployment; no language-quality claim is made.** The model is
still useful for testing the declared Product fixed-point path.

The training manifest's preliminary bigram score (27.34%) used a separate
random window sample. The final quality JSON recomputed the bigram predictor
on the exact same 1,024 held-out targets used for FP32 and INT8 (28.71%); the
table uses this paired evaluation result.

## Product Top execution

The successful VCS command executed four layers, Final LayerNorm and a 256-way
LM head in one unreset Product Top simulation. The host read Product Top logits,
used signed INT32 argmax with lowest-token-ID tie breaking, and supplied only
the selected token's embedding and position input. No host hidden/intermediate
tensor writes were reported. All four 256-element logit vectors matched a
separate integer reference bit-exactly; all four argmax values agreed:

| Context | Valid tokens | Product Top argmax | Logit SHA-256 (little-endian INT32) | Golden |
|---:|---:|---:|---|---|
| 0 | 4 | 107 | `26fe1cb61e7857ce449139dcc1a913f05d45fa0be2001a9427d9e77a9ecf9b0b` | PASS, 256/256 |
| 1 | 5 | 103 | `db29d4acb78b7b0d7fdb88903f5f124678425e38fefcb08e029215fd12035e63` | PASS, 256/256 |
| 2 | 6 | 32 | `a07a4fc78d7713859921ed8023f84f2e4c890cf84206198d77778768ec24aa7f` | PASS, 256/256 |
| 3 | 7 | 111 | `a688a09cb771992b518c280a00bd773640bfe2581c7275cd05a1e909518dad14` | PASS, 256/256 |

Generated tokens were `[107,103,32,111]`. Four layer handoffs, KV cache
readbacks, completions and Final logits were checked in the run log. The
testbench reconstructs expected cache words from the previous stage's
independent checkpoint, then reads the existing Product Top SPAD through
AXI-Lite and compares them; it does not write those expected KV values into
SPAD. Each later context recomputes the complete valid prefix, so the execution
is **same-Top autoregressive feedback with RTL KV state checks, in
`prefix_recompute` mode**, not query-only decode. We therefore do not report
these cycles as incremental per-token decode performance.

| Measurement boundary | Cycles | Meaning |
|---|---:|---|
| Initial 4-token prompt command window | 1,048,740 | Four-layer Product commands through Final LN/LM head; excludes training and Python package preparation |
| Context 5 command window | 1,413,702 | Prefix recompute for first feedback result |
| Context 6 command window | 1,446,042 | Prefix recompute for second feedback result |
| Context 7 command window | 1,479,012 | Prefix recompute for third feedback result |
| Three extension contexts | 4,338,756 | Sum of the above three prefix-recompute command windows |
| Prompt + extension command windows | 5,387,496 | RTL command-cycle total only; not full host-to-host wall latency |

The first emitted token costs 1,048,740 command cycles. The three later
feedback contexts average 1,446,252 command cycles each. The 1,346,874 figure
in the machine manifest is the four command windows divided by four emitted
tokens; it includes the prompt context and is not the steady-state feedback
latency.

The timed `make ai_h64_four_layer_top_argmax` wrapper measured 74.75 seconds
wall time (71.21 user / 2.15 system seconds, peak RSS 221,956 KiB) from
workload generation through VCS compilation, simulation and Golden checking.
VCS reported 53.890 seconds simulation CPU time. This is a build-to-result
measurement, not an inference-only host latency: compile time is included,
while training, corpus download and held-out evaluation are excluded. A
separate application runtime measurement with a precompiled simulator was not
made. Exact run paths and hashes are listed below.

## TinyNPU contract audit

Pinned TinyNPU SHA is
`8216c22b762011aa20c05fc2768423fd12dda59d`. Its GPT-2 exporter truncates the
public GPT-2 checkpoint to H64, four heads, four layers and 256 token IDs, omits
projection biases and ties the LM head to embeddings. Its quantization/packing
uses different tensor scales and GEMM shifts from the NMAForge product
contract. This Round 20 model instead trains NMAForge's explicit byte-level
architecture on Tiny Shakespeare. The model weights, vocabulary semantics,
packing, LayerNorm/Softmax/GELU contracts and memory/runtime boundaries are not
matched. **TinyNPU GPT-2 comparison: NOT_RUN / NOT_COMPARABLE.** No speedup is
computed.

## Reproduction

From the GPT-2 worktree root, using the pinned corpus at
`/tmp/nmaforge_tinyshakespeare.txt`:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/train_h64_byte_lm.py \
  --out /tmp/nmaforge_v12_r20_gpt2_quality_corrected \
  --corpus /tmp/nmaforge_tinyshakespeare.txt --seed 20261120 \
  --steps 1200 --batch 32 --eval-windows 64

/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/evaluate_h64_byte_lm.py \
  --package benchmark/gpt2_quality/models/canonical_h64_byte_lm_int8.npz \
  --fp32 /tmp/nmaforge_v12_r20_gpt2_quality/h64_byte_lm_fp32.pt \
  --corpus /tmp/nmaforge_tinyshakespeare.txt \
  --out benchmark/gpt2_quality/results/round20_product_contract_quality.json \
  --seed 20261121 --windows 64

cd dv/subsystem/top_smoke/sim
make ai_h64_four_layer_top_argmax AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_v12_r20_gpt2_host_complete \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_H64_FOUR_LAYER_MODEL_NPZ=/tmp/nmaforge_v12_r20_gpt2_quality_corrected/canonical_h64_byte_lm_int8.npz \
  AI_H64_FOUR_LAYER_SEED=20261120 AI_H64_FOUR_LAYER_TOKENS=1,7,42,3

/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/verify_top_independent_int.py \
  --run /tmp/nmaforge_v12_r20_gpt2_host_complete \
  --package benchmark/gpt2_quality/models/canonical_h64_byte_lm_int8.npz \
  --out benchmark/gpt2_quality/results/round20_top_independent_integer_check.json
```

| Run artifact | Path | SHA-256 |
|---|---|---|
| VCS compile log | `/tmp/nmaforge_v12_r20_gpt2_host_complete/compile.log` | `5fd8dc7dfc4bd771603239db829c48c84aa4adf96acfd94f24788f8bb24ab8fa` |
| VCS run log | `/tmp/nmaforge_v12_r20_gpt2_host_complete/run.log` | `16533607b67396f0706b11cc328be65667916cab1fd4b53c084bd0a57f8027af` |
| Top result JSON | `/tmp/nmaforge_v12_r20_gpt2_host_complete/autoregressive_result.json` | `2ec78dc5cfb58111df6d65b7c2fc5c33f20f5f329256095713b64d6afa573d05` |
| Build-to-result wall timer | `/tmp/nmaforge_v12_r20_gpt2_host_time.txt` | `elapsed_seconds=74.75` |
| Corrected training manifest | `benchmark/gpt2_quality/results/round20_training_manifest.json` | model artifact hashes embedded |

## Round 20 gate disposition

| Gate | Status | Reason |
|---|---|---|
| Trained compatible H64 package | PASS | Reproducible training/export and pinned held-out corpus; package hash fixed |
| Product Top 4-layer logits | PASS | Four contexts, 1,024 total logits bit-exact against independent integer reference |
| Host feedback loop | PASS, prefix-recompute scope | Four selected tokens fed back without Top reset; embeddings/positions are host-supplied |
| Product KV residency | PASS, checked scope | Physical cache words read/compared between contexts; host does not seed KV words |
| Quantized model quality | FAIL | INT8 12.70%, below bigram 28.71%; not suitable as quality-qualified LM |
| Query-only persistent decode | NOT_RUN | Each later step recomputes the prefix |
| Full Host-to-Host latency | PARTIAL | Build-to-result measured at 74.75 s; inference-only runtime not isolated; training/download/evaluation excluded |
| Matched TinyNPU model comparison | NOT_COMPARABLE | Different model weights/quantization/graph/runtime contracts |

This model result is not sufficient to freeze GPT-2 deployment quality. The
next useful model work is quantization recovery and matched contract definition,
not claiming language capability from a functional Token sequence.
