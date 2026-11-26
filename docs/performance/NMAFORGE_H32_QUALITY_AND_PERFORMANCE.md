# Phase 1 — H32 quality diagnosis and performance

Status: **qualified synthetic recall model and scoped RTL Golden PASS;
research/application quality remains limited**. Product RTL untouched at
`48790076b351cb9d49e1785247d32a1f51b8286d` / tree
`c86d2cfda7cde900482f38a3b48b620bc69f67cb`.

H32,L2,H2/head16,C16,FFN128,V32,INT8 Post-LN uses existing opcodes, descriptor
ABI, scalar arithmetic contract and Matrix array. It is not GPT-2 or Qwen
pretrained-weight support. New fixed model SHA256:
`fc9c8a9fbcccf556e7a8281b06ee0e75827ca9264424f57ff66f5d82b7c6de78`.
All model/Golden/input/tool hashes, raw snapshots and commands are in the
[public manifest](../../benchmark/research/phase1/manifest.json).

## Diagnosis and FP32 admission

Old StageC final disjoint84train/28test trajectories gave FP32 decode3.125% and
INT8 3.1901%, near random1/32. FP32 CE13.2947 also fails: this cannot be blamed
primarily on INT8. Repeated sampling from a small finite state set and strong
training memorization did not generalize to the held-out initial-state set.
The older overlapping-split90.56% result remains invalid; it was not revived.

Phase1 changes the **software diagnostic task**, not Golden arithmetic: causal
period3 recall from three distinct symbols drawn from32.1,024training and128
monitored validation sequences contain disjoint triples, including cyclic
rotations. Vocabulary IDs are shared; combinations are unseen. Seed20261112
training/20261113validation,60epochs, deterministic CPU PyTorch2.7.1, AdamWlr.003,
one thread. Bias-free projections, two Post-LN blocks, base2attention and existing
piecewise GELU/export scales are preserved. Full recipe and exact public
checkpoint accompany `tools/benchmark/phase1/train_h32.py`.

The script requires FP32≥90% and at least50percentage points above unigram,
copy-current and trained-bigram baselines **before INT8 export**. The fixed model
passes, then the independent scalar reference evaluates quantized execution.
Two complete training runs reproduce the INT8 JSON byte-for-byte. No RTL
arithmetic, expected comparison or quantization threshold was weakened.

| Metric, positions4..15 | Monitored disjoint validation | Fresh blind test |
|---|---:|---:|
|Sequences / next-token predictions|128 /1,536|128 /1,536|
|FP32 accuracy|100%|100%|
|FP32 cross entropy nats|0.0003102143|0.0002953285|
|INT8 independent accuracy|100%|100%|
|INT8 cross entropy nats|0.0007723436|0.0006841429|
|INT8 perplexity|1.000772642|1.000684377|
|Unigram accuracy|2.34375%|2.60417%|
|Copy current|0%|0%|
|Trained bigram|4.16667%|2.08333%|
|Lag3 rule oracle|100%|100%|
|Split overlap including rotations|0|0|

Fresh blind seed20261114 excludes both training and monitored-validation triples;
weights are fixed before this test, with no further tuning. Because training
prints validation metrics every10epochs, that split is properly described as
validation, not an untouched final test. `evaluate_h32.py` evaluates the blind
split with the frozen checkpoint and independent integer model; no mapper import.

This is a narrow memory/generalization diagnostic. A three-symbol delay rule
solves it perfectly: the Transformer does **not** beat the best task-specific
simple algorithm. It proves learning unseen symbol compositions and clean
quantization for this task, not language quality, broad reasoning or performance
on the old finite-state task. New/old accuracy is not an apples-to-apples gain.
A richer qualified task remains a prerequisite for stronger application claims.

## Exact model/mapping contract

Existing scale16embeddings, scale8QKV, Q8.8scores, Q15base2softmax,
probability shift8, AV shift7, Wo shift3, gamma Q15×16, beta scale16,
mean truncation toward0, variance floor, integer sqrt(var+1), Q30inverse,
FFN/GELU scales and saturation remain as in StageC's independent reference.
Length32LN is not two length16operations. Every necessary INT32 output is still
written. Original historical model and its Golden are retained and replayed
separately; new weights necessarily generate a distinct fixed Golden.

The generalized existing mapper runs113descriptors/token, all12stages in one
Top process with persistent Layer×Head×Token KV. Four prefill tokens execute the
entire graph, sequentially; eight teacher-forced decode tokens follow without
reset. Host supplies embeddings/token IDs outside the timer.4physical matrix
rows are padded per logical token. Only live-row useful MAC is counted.
The Top session uses the first monitored-validation trajectory; the separate
blind quality test is software-only. Each stage checks7,744words, including padding, Logits, all intermediate results
and separate physical K/V readback:92,928total; decode61,952. Independent scalar
checks precede simulation; observed memh also matches Golden byte-for-byte.

Actual mapper high water79,872B, not StageA's hypothetical60,800B:
persistent end40,448; workspace28,928B/end69,376; CMDQ69,632+8,192B;
CPLQ77,824+2,048B.128KiB margin51,200B. Queue reservations and12host embedding
vectors are included. Workspace is reused only after complete retirement and
verification; in-stage outputs remain distinct and fully committed.

## Top performance and memory

VCS V-2023.12-SP1_Full64,4nsclock,128KiB/four-bank behavioral SRAM, two-edge
registered reads,256MAC. Clock period is a simulation condition, not Fmax.

| Fixed artifact / scope | Cycles | Cycles/token | Reads B | Writes B |
|---|---:|---:|---:|---:|
|Historical H32 /4prefill|181,391|45,347.75|273,408|113,920|
|Historical H32 /8decode|367,788|45,973.5|546,816|227,840|
|Qualified H32 /4prefill|181,329|45,332.25|273,408|113,920|
|Qualified H32 /8decode|367,051|45,881.375|546,816|227,840|
|Unchanged H16 /8decode|65,771|8,221.375|72,448|42,112|

New H32 exclusive decode: Matrix41,360 (11.27%), SFU290,595 (79.17%),
KV20,224 (5.51%), control14,872 (4.05%); sum367,051. SFU opcode cycles:
LN104,064, requant82,144, GELU49,200, residual43,248, causal-softmax11,939.
Per-window closed partitions, admission bytes and response ledgers are archived.
Different old/new weights alter data-dependent arithmetic wait by737decode
cycles. **That is not an RTL optimization gain**. H16 has different layers/FFN/
context and QKV-only prefill; its ratio to H32 is not a comparable-work speedup.

Doorbell→last committed completion windows exclude model preload, configuration,
intertoken host service, Golden reads, embeddings and token selection.113×8=904
Decode descriptors;1,356fullsession. No closed-loop host-feedback generation,
full context16wrap, multi-prompt RTL sweep or physical macro timing is claimed.

Reproduction: [complete command sequence](../../tools/benchmark/phase1/README.md).
PASS is scoped to this deterministic task/session and strict numerical Golden.
Full-system throughput and natural-language benchmark admission remain OPEN.
