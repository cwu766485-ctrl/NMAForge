# NMAForge v2 Round 23 — Tiny GPT-2-like Inference

**Disposition: `RESEARCH_PARTIAL`**
**Tested code SHA:** `c01fe118b48593879c8f537a8091162632f67e26`
**Reviewed parent / product RTL SHA:** `c9d0f15e968a88d82aacb62b5e188291a3652d33`
**TinyNPU reference SHA:** `8216c22b762011aa20c05fc2768423fd12dda59d`

## Result

The trained H16 decoder ran through the NMAForge Top for eight host-feedback
generation steps. For every selected decode stage, all 1,360 checked output
words passed the Top Golden comparison, and all 32 INT32 logits matched an
independent scalar INT8 reference bit for bit. The resulting tokens were
`13, 29, 26, 11, 11, 11, 12, 6`.

This is a real trained-weight Top functional demonstration, but it is not a
useful language model yet. The training corpus is a synthetic finite-state
token task, and float-to-INT8 quantization caused a severe held-out quality
collapse. In addition, embedding lookup and token/position addition are Host
input preparation, and each generated token uses a fresh simulation that
replays its prefix. Therefore the result does not establish persistent-session
NPU throughput or natural-language generation quality.

## Model and numeric contract

| Property | Configuration |
|---|---|
| Hidden / heads / head dimension | 16 / 2 / 8 |
| Layers / context / vocabulary | 1 / 8 / 32 |
| Training objective | Causal next-token prediction, AdamW, cross entropy |
| Training / held-out data | 4,096 / 1,024 seeded sequences, 9 tokens each |
| Training seed / epochs | 20261123 / 120 |
| Model JSON SHA-256 | `e557225f55db9699ba2c5b5e60c904fc1adbda7043437ea2b17909127f5b1c36` |
| Independent INT8 reference SHA-256 | `2eee914c420a4d2a886bd82b97315f2e76b76a865426166f75736c57a7450bb6` |

The block uses learned token and position embeddings, two-head causal
attention, residuals, LayerNorm, GELU FFN, and a tied LM head. Its order is
attention → residual → LayerNorm → FFN → residual → LayerNorm (Post-LN), while
original GPT-2 uses Pre-LN. The FFN inner dimension is 16 rather than the usual
4× hidden dimension. It is thus a constrained GPT-2-like decoder test model,
not an architecture-faithful GPT-2 implementation. The corpus is synthetic;
there is no natural-language tokenizer or pretrained weight claim.

Quantized held-out quality was measured by the independent reference over
4,096 token predictions:

| Evaluation | Accuracy | Cross entropy (nats) | Perplexity |
|---|---:|---:|---:|
| Float trained model | 71.41% | 0.9705 | 2.639 |
| INT8 exported model | 8.72% | 30.3991 | 1.59×10¹³ |
| Bigram baseline | 6.70% | 3.1701 | 23.81 |

The INT8 accuracy is only slightly above the simple baseline while its
cross-entropy is much worse. The exported model therefore fails the practical
quality objective despite passing its bit-exact RTL/reference checks. The
training report must not be represented by the float metrics alone.

The integer contract uses signed INT8 operands, Q15 LayerNorm coefficients,
Q8.8 GELU inputs, the existing Q15 causal Softmax, and explicit power-of-two
projection scales/shifts. The independent scalar reference does not import the
Mapper or A3 reference implementation. It models the exported fixed-point
operations and checks intermediate tensors as well as final logits.

## Top execution boundary

The Top executes Q/K/V projections, KV append/read, causal attention, AV,
output projection, residual/normalization, GELU FFN, and LM Head. Host duties
are:

- synthetic token preparation and token/position embedding lookup;
- saturated INT8 addition of token and position embeddings before Top input;
- greedy Argmax and feedback of the selected token;
- workload generation and orchestration of separate simulator invocations.

No Transformer hidden-layer intermediate is calculated on the Host. However,
embedding itself is not executed by the NPU datapath in this run. The runner
starts a fresh VCS simulation for each output token, replays the four-token
prefill and required prefix, and advances through the relevant decode stage.
After four tokens it rolls the context window and resets position IDs. This
demonstrates eight logically connected outputs with Top-generated logits, but
not one persistent hardware session or full-history context beyond the
bounded rolling window.

## Decode profile

The table is the selected decode stage only. It excludes simulator restart,
prefix replay, Host feedback, workload generation, Top memory initialization,
and any real external weight-transfer interval. Per-stage SFU busy is an
activity counter, not an exclusive-cycle partition; it must not be added to
Matrix/KV counters to reconstruct latency.

| Step | Window / position | Input → output token | Cycles | Useful MAC | MAC/cycle | SFU busy | Matrix active | SPAD read/write bytes |
|---:|---|---|---:|---:|---:|---:|---:|---:|
| 0 | 0 / 4 | 13 → 13 | 8,897 | 2,208 | 0.2482 | 6,858 | 208 | 9,056 / 5,264 |
| 1 | 0 / 5 | 13 → 29 | 9,101 | 2,240 | 0.2461 | 7,062 | 208 | 9,056 / 5,264 |
| 2 | 0 / 6 | 29 → 26 | 9,106 | 2,272 | 0.2495 | 7,067 | 208 | 9,056 / 5,264 |
| 3 | 0 / 7 | 26 → 11 | 8,922 | 2,304 | 0.2582 | 6,883 | 208 | 9,056 / 5,264 |
| 4 | 1 / 4 | 11 → 11 | 8,852 | 2,208 | 0.2494 | 6,813 | 208 | 9,056 / 5,264 |
| 5 | 1 / 5 | 11 → 11 | 9,065 | 2,240 | 0.2471 | 7,026 | 208 | 9,056 / 5,264 |
| 6 | 1 / 6 | 11 → 12 | 8,912 | 2,272 | 0.2549 | 6,873 | 208 | 9,056 / 5,264 |
| 7 | 1 / 7 | 12 → 6 | 9,041 | 2,304 | 0.2548 | 7,002 | 208 | 9,056 / 5,264 |
| **Total / mean** | — | — | **71,896 / 8,987** | **18,048 / 2,256** | **0.2510** | **55,584 / 6,948** | **1,664 / 208** | **72,448 / 42,112 total** |

Each selected stage has 53 descriptors and 394 KV busy cycles. The logged
active-window array utilization is 4.15–4.33%, calculated over Matrix-active
cycles. Useful-MAC utilization across the complete selected stage is only
about **0.098%** of the 256-MAC peak (`0.2510 / 256`). SFU busy is 77.31% of
selected-stage cycles as a counter ratio; it is not an exclusive attribution
and does not prove that optimizing SFU will reduce latency by that percentage.
The currently archived stage profile does not reliably associate all
per-opcode SFU detail lines with the selected token, so separate LayerNorm,
Softmax, GELU, and pack cycle totals are `NOT_MEASURED` here.

These cycle counts are RTL simulation cycle counts at the configured 4 ns
clock period, not wall-clock execution time or silicon frequency evidence.
No tokens/s claim is made because reset, replay, Host work, and transfer time
are outside the selected-stage boundary.

## Gate status

| Gate | Status | Evidence / limitation |
|---|---|---|
| 1. Trained Tiny-GPT-2-like model | **PARTIAL** | Deterministic training and learned weights are present; synthetic corpus only. INT8 held-out quality is poor. |
| 2. Model-to-Top integration | **PARTIAL** | Eight steps, 8/8 logits bit-exact to independent INT8 reference; 8/8 Top stage Golden PASS. Embeddings remain Host input preparation; runs are reset/replay, not persistent. |
| 3. Profiling | **PARTIAL** | Per-stage cycles, useful MACs, Matrix/SFU/KV counters and SPAD bytes are archived. Host, DMA/weight-load, and restart costs plus reliable per-op SFU decomposition are not measured. |
| 4. Scale-up feasibility | **NOT_RUN** | H32 / two-layer / context-16 / vocab-128 was not implemented or measured. |
| 5. TinyNPU comparison | **NOT_RUN** | TinyNPU SHA is pinned, but no identical trained workload, output contract, memory service, or matched Top endpoint was run. No cross-design speedup is valid. |

GEMM-vs-GEMV and Exact-SFU ON/OFF ablations were also **NOT_RUN**. The
synthetic H16 compatibility regression remains PASS at the same RTL baseline:
102 descriptors, 3,264/3,264 Golden words, 15,616 useful MACs, 26,440
command cycles. That is a compatibility result, not language-model evidence.

## Reproduction and evidence

Environment used: Synopsys VCS `V-2023.12-SP1_Full64`, Python 3.12.13,
PyTorch `2.7.1+cpu`, NumPy `2.4.6`; VCS license was available. No ONNX or
Verilator dependency is used by this flow.

```bash
cd dv/subsystem/top_smoke/sim
make ai_tiny_gpt2_top \
  AI_TINY_GPT2_RUN=/tmp/nmaforge_round23_final_run2 \
  AI_TINY_GPT2_PYTHON=/tmp/nmaforge_round23_torch/bin/python \
  AI_TINY_GPT2_SEED=20261123
```

The target trains and exports the model, runs the independent INT8 reference,
compiles the Top smoke testbench, then runs the eight-step feedback replay.
The exact invocation, tool versions, source hashes, model/reference hashes,
result hashes, per-step records, Golden files, and archived logs are indexed
in `benchmark/representative/round23/reproduction.json`. The per-step log
files are under `benchmark/representative/round23/logs/`; final-window
descriptor, Golden, observed, poison, and manifest files are under
`benchmark/representative/round23/golden/last_window/`.

Python syntax compilation and byte-for-byte comparison of all archived
Golden/observed files passed. The existing synthetic H16 Top regression also
passed after adding the optional useful-MAC accounting for the LM Head.
VCS compile emitted an existing `LOOP-REROLL-ENABLED` warning in
`ai_transformer_workload.svh`; no product RTL file was changed.

## Decision

Keep this as a reproducible **functional research prototype**, not a language
model or performance-ready inference claim. The next necessary work is to
recover INT8 task quality, move learned embedding/position lookup into a
supported hardware path if native end-to-end inference is required, and
measure a persistent-session endpoint with Host and transfer intervals.
Only then is it useful to test GEMV ablations, compare TinyNPU, or justify
H32/context scale-up. This round does not establish ASIC/PPA readiness.
