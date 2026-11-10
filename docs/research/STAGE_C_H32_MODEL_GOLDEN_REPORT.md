# Stage C — H32 model, mapping and independent Golden

Result: **functional PASS in the measured scope; model quality LIMITED**.
H32,L2,heads2/head16,context16,FFN128,vocab32 uses existing product RTL and ABI-v7.
It is a trained synthetic Post-LN decoder, not pretrained GPT-2/Qwen weights.
Final model SHA256:
`e4ded992c6f4ed686f5d4531b861041ffedeba0392a1998b1f7a1dfbe9cd15aa`.

## Training and quality

Deterministic PyTorch2.7.1+cpu, one CPU thread, seed20261110, AdamW lr.006,
60epochs,2,048 sampled training sequences,256 sampled test sequences,
16next-token positions per sequence. Exported integer weights/activations use
power-of-two scales. Training uses base2 causal attention and the declared
piecewise GELU. There is no natural-text corpus or pretrained checkpoint.

The finite-state generator has only112 complete trajectories. An initial
independent-seed split overlapped train/test trajectories; its90.56% integer
accuracy is **invalid as independent generalization evidence**. The superseded
model/quality are archived with `models/split_audit.json`, not selected as final.
Final split partitions each mode's initial states into21 train/7 test, giving
84/28 disjoint trajectories and **zero overlap**. Retraining reproduces the
entire final JSON byte-for-byte with the SHA above.

| Metric | Final result | Positions |
|---|---:|---|
| FP32 next-token accuracy |2.34375%|0..15|
| FP32 cross entropy |12.7799063|0..15|
| FP32 decode accuracy |3.125%|4..15|
| FP32 decode cross entropy |13.2947273|4..15|
| INT8 next-token accuracy |3.1901042%|4..15|
| INT8 cross entropy |13.3099897|4..15|
| INT8 perplexity |603,191.334|4..15|

Metrics with different position sets are not a quantization-loss comparison;
`training.float_decode_*` records matched4..15 float metrics. The model memorizes
training trajectories and fails unseen-state generalization. Functional RTL
correctness does not repair model quality. No third directed model tuning round
was started: scale-export correction and disjoint-split correction exhaust the
two-fix rule. Quality measurement uses3,072 teacher-forced independent-test
predictions, logit scale256, scalar integer execution, not float accuracy reuse.

## Numeric and dataflow contract

Embeddings/positions are rounded/clamped scale16 and their sum is sat8. QKV
weights scale16, GEMM shift5 produce scale8; QK exact dots are interpretedQ8.8.
Softmax is existing integer base2 PWL Q15, causal query index equals slot0..11;
probability requant shift8, AV shift7; per-head Wo weights scale16 and shift3
produce scale16. Heads merge with signed saturated residual arithmetic.
LayerNorm applies existing mean trunc0, variance floor, isqrt(var+1), Q30 inverse,
gamma Q15×16, beta scale16; it normalizes **32 features**, not two length16 halves.
Norm requant shift0 saturates to INT8. Up weights scale256, shift4 give Q8.8;
piecewise GELU then shift4 gives scale16; Down weights scale16, shift4 restores
scale16. Two layers execute the same contract with separate learned weights and
parameters. Tied LM head uses exported embeddings and produces INT32 scale256.
No new integer algorithm or modified old Golden is used.

`generate.py` lowers shape-derived tensors/descriptors using existing Mapper and
block `ai_a3_reference`; `reference.py` imports scalar numeric primitives only,
never Mapper or generated Golden. Before simulation, every live-row intermediate,
Logits and physically packed per-layer/head KV is crosschecked with that scalar
reference. Top then compares every generated output word, including padding,
INT32 intermediate writes and KV readbacks. Padding rows are deterministic zeros
where softmax operates only on row0; subsequent padding activations are genuinely
computed by RTL. No host-computed Q/attention/FFN activation is injected.
Layer1 residual receives an **RTL nonpacked requant result**, preserving saturated
input semantics, rather than reusing an unsaturated Layer0 INT32 norm output.

K storage is per-layer/head B[feature,token], V is B[token,feature],256B/head.
K append uses four ordinary word-strided0x43 commands/head; V uses existing
flags1 bounded16feature/16token byte-preserving RMW scatter. Full64word/head
0x44 readbacks are checked. Four separate Layer×Head pairs cannot alias.

## Memory and workload boundary

| Allocation | End / bytes |
|---|---:|
| Persistent weights, parameters, all12 host embeddings and KV |40,448 end|
| Reusable per-token workspace |28,928|
| Workspace end |69,376|
|128-entry CMDQ base/reservation |69,632 /8,192|
|128-entry CPLQ base/reservation |77,824 /2,048|
| Actual address high water |**79,872**|
| Configured four-bank capacity |131,072|

The earlier60,800B Stage A budget was an estimate, not this mapper allocation.
Queue reservations include all advertised entries. Initial vectors and persistent
regions do not overlap workspace; workspace reuse occurs only after complete
ordered retirement and exhaustive readback. Tensors retain distinct addresses
within a batch and every required INT32 result is committed before reuse.

Four-token prefill executes the **entire two-layer graph sequentially per token**,
then8teacher-forced decode tokens use the same persistent SPAD KV without reset.
113 descriptors/token;1,356 total. This is real full causal prefill, unlike old
H16's QKV-only prefill. It is not a batched-prefill throughput claim. Context16
slots0..11 are exercised; capacity boundary/ring wrap is not claimed validated.
Host supplies embeddings/token IDs and later reads results. No natural-text
end-to-end throughput or closed-loop sampled generation is claimed.

## Final Top measurements

| Scope | Cycles | Matrix | SFU | KV | Control | Reads B | Writes B |
|---|---:|---:|---:|---:|---:|---:|---:|
|4 prefill tokens|181,391|20,680|143,163|10,112|7,436|273,408|113,920|
|8 decode tokens|367,788|41,360|291,332|20,224|14,872|546,816|227,840|

Decode **45,973.5 cycles/token**, Matrix11.25%, SFU79.21%, KV5.50%, control4.04%.
All92,928 intermediate/KV/Logits words across12stages match exactly; decode61,952.
Exclusive partitions, accepted traffic and sum of descriptor intervals reconcile
with each CMDQ timing window. No-engine cycles remain explicit.

Timing sums doorbell→last completion commit windows; excludes initial host preload,
queue configuration, host interbatch delay, Golden readback and token processing.
Accepted bytes count compute-side SRAM service, not descriptors/CPL/host/DMA wire
traffic. Physical GEMM pads one logical token to four rows; profile includes all
padding work.4ns simulation is250MHz, **not400MHz/Fmax evidence**.

H16 replay remains65,771/8=8,221.375cycles/token and its original strict Golden
passes; models differ in layers/FFN/dimensions, so H32/H16 ratio is not a regression
or equivalent-workload speedup. See archived model, memh, observed snapshots,
per-token CSV, SFU state profile and compile/run logs.

Reproduction commands are in `STAGE_C_ARCHITECTURE_DECISION.md`.
