# NMAForge v1.2 Round 14 — Runtime Integration Status

## Baseline and scope

- Research base: `research/nmaforge-v1.2-round13` at `009632ff88ac9e662c305ece91a77125154d5087`.
- Isolated branch: `research/nmaforge-v1.2-round14`.
- Product RTL/ABI and PR branches: unchanged.
- VCS: `V-2023.12-SP1_Full64`; simulation clock: 10 ns; behavioral 128 KiB SPAD.

Round 13 was independently replayed before editing. Its `512` VDOT test passed
with 8-entry CMDQ / 4-entry CPLQ and no reset, but the testbench advanced
normal execution using DUT hierarchy signals and read completion/data through
a behavioral SRAM backdoor. Its H64 run was one static six-token graph. Those
results did not constitute a reusable host runtime or token-persistent decode.

## Round 14 changes and evidence

The Top Smoke runtime now uses reusable tasks for 64-byte descriptor publication,
DMA-status fences, queue-idle polling, completion reads, and ring retirement.
Normal progress is polled through AXI-Lite `STATUS`, `CMDQ_HEAD`, `CPLQ_TAIL`,
and `DMA_STATUS`; completion payloads and VDOT outputs are read through the
AXI-Lite SPAD aperture. No hierarchy signal drives runtime progress and no SRAM
backdoor is used by this test.

The configured queues remain CMDQ=8, CPLQ=4 (3 usable completion entries).
Transactions are published in batches of at most 3, and each batch drains before
the next doorbell. This is required by the present host/compute SPAD conflict
contract: an AXI-Lite host read cannot reliably access SPAD while the compute
engine is issuing SPAD traffic. A same-top live CPLQ-full consumer protocol is
therefore not demonstrated. The earlier 20-cycle CPLQ-full backpressure probe
was intentionally removed from the AXI-only runtime test because it depended
on backdoor reads to retire while the accelerator remained busy.

An 8-byte input vector is loaded through the real AXI4 DMA. The host polls
`DMA_STATUS` and validates the loaded words before publishing compute work,
which demonstrates a real DMA-to-compute fence. The 512 VDOT descriptors then
run on the same Product Top instance, with no reset, and all four completion
words plus all result words are checked using AXI-Lite.

| Runtime measure | Result |
|---|---:|
| VDOT descriptors / output checks | 512 / 512 |
| CMDQ/CPLQ entries | 8 / 4 (3 usable) |
| CMDQ / CPLQ wraps | 64 / 128 |
| End-to-end driver window | 103,446 cycles |
| Compute SPAD reads / writes | 4,096 B / 2,048 B |
| AXI4 DMA input | 8 B |
| Completion payload check | 512/512, AXI-Lite SPAD reads |
| No-reset session | PASS |
| DMA status fence | PASS |
| Ring retirement and reuse | PASS, batch-idle mode |
| Live queue refill / live CPLQ full retirement | NOT DEMONSTRATED |

The existing H64 two-token workload was also regenerated and run on Product
Top with real AXI4 weight preload. It is explicitly a batch replay: both rows'
Q/K/V projection and KV append are in a static descriptor graph before KV reads
and attention. This run proves that Product KV_READ buffers feed Product QK and
AV operands for a multi-row batch, but does not prove Token 0 completion and
KV retirement precede Token 1's query execution.

| H64 batch replay measure | Result |
|---|---:|
| Tokens | `[1, 7]` |
| Descriptors / checkpoint set | 197 / 31 |
| DMA preload payload | 49,152 B |
| End-to-end cycles, preload included | 327,605 |
| Command cycles | 260,253 |
| SPAD read / write bytes | 342,144 B / 220,160 B |
| Useful / executed / padding MACs | 98,688 / 819,200 / 720,512 |
| Product Top Golden checkpoints | 31 PASS, nonintrusive behavioral SRAM snapshots |
| Cache-vs-recompute independent reference | 16 tensor boundaries PASS, Python only |
| Token 0→1 persistent decode | NOT PASS / NOT IMPLEMENTED |

The independent comparison command passed QK scores, causal probabilities,
AV, residual, LN2, FFN accumulator, and Residual2 for the two-token batch. It
does not compare two sequential Product Top token invocations. Cache results
must not be described as persistent-decode closure.

## Gate status

| Gate | Status | Reason |
|---|---|---|
| Round 13 baseline replay | PASS | Existing runtime and six-token batch reproduced from Round 13 evidence; Product scope limitations retained. |
| A. Reusable Model Runtime | PARTIAL | AXI-only publication, DMA fence, completion payload read, retirement, wrap and tensor-free ring-slot reuse exercised. H64 generic planner integration, live refill, and safe runtime SPAD output reads while busy remain open. |
| B. H64 Token 0–1 Persistent Decode | FAIL / NOT IMPLEMENTED | Current H64 generator constructs a whole multi-row graph and performs all K/V appends before cache reads. It has no token-scoped publish/retire schedule or per-token SPAD lifetime handoff. |
| C. H64 Tokens 0–5 Persistent Decode | BLOCKED BY B | No six-token sequential execution or cache-vs-full-recompute Product Top comparison. |
| D. Four-layer preparation | PARTIAL / GATED | Existing reference is deterministic synthetic H64 weights. Per-layer DMA and tensor plan work was not started because A–C did not pass. No pretrained GPT-2 claim. |
| Product RTL / ABI | UNCHANGED | No RTL or ABI change required for the demonstrated tests. |
| `ai_smoke` | PASS | Standard Product Top smoke and Make marker checks pass. Existing VCS `LOOP-REROLL-ENABLED` fixture warning remains. |

### First unimplemented H64 node

The current `generate_h64_preln_qkv.py` creates a single 16-row physical graph.
For each head, the descriptor order is all K/V writes for the requested token
rows, followed by KV reads, QK, Softmax, AV, projection, residual, LN2, and FFN.
There is no executable boundary where Token 0 is retired, its KV ownership is
committed, and a new Token 1 input/descriptor batch is published while retaining
the same top instance. The existing 16-row GEMM and attention buffers, absolute
causal Softmax row selection, KV address layout, descriptor lifetime, and ring
storage must be lowered together; simply slicing the current descriptor list
would cause reads of not-yet-produced rows and/or alias live buffers.

The present Product doorbell contract also only starts a queue when the
processor and DMA are idle. Runtime uses legal idle-boundary DMA and command
fences; it does not claim asynchronous DMA/compute overlap. This contract does
not itself prevent sequential persistent decode, but it means the token planner
must explicitly publish a completed token stage, retire all completions, then
issue the next token without resetting SPAD/KV state.

## Reproduction

From `/tmp/nmaforge-v1.2-round14/dv/subsystem/top_smoke/sim`:

```sh
make ai_cmdq_stream_runtime \
  AI_CMDQ_STREAM_RUN=/tmp/nmaforge_round14_runtime_final2 \
  AI_CMDQ_STREAM_COUNT=512 AI_CMDQ_STREAM_SEED=20261116

make ai_h64_kv_roundtrip_top \
  AI_H64_KV_RUN=/tmp/nmaforge_round14_h64_2token_batch \
  AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_H64_KV_SEED=20261116 \
  'AI_H64_KV_GENERATOR_FLAGS=--kv-attention --tokens 1,7 --kv-k-write-mode matrix-a-tile'

cd /tmp/nmaforge-v1.2-round14
/tmp/nmaforge_round10_venv/bin/python \
  benchmark/gpt2_compat/compare_h64_kv_recompute.py \
  --seed 20261116 --tokens 1,7 --kv-k-write-mode matrix-a-tile

make -C dv/subsystem/top_smoke/sim ai_smoke
```

Raw logs and SHA-256:

| Artifact | Path | SHA-256 |
|---|---|---|
| Runtime VCS compile | `/tmp/nmaforge_round14_runtime_final2/compile.log` | `2b9ce075419d3b334e704a967858103fb99f8e332ca2ecefd5d7183ab10734c8` |
| Runtime VCS simulation | `/tmp/nmaforge_round14_runtime_final2/run.log` | `fd9f85513ad6978428009000dda3d4d892b26e57ce1a65a0522b6c0077a947ff` |
| H64 VCS compile | `/tmp/nmaforge_round14_h64_2token_batch/compile.log` | `5ef696e7c5c0e317bd6d0e50e44bd7ff25f085c0ceb5c1b77e258cf72a1bac56` |
| H64 Product Top simulation | `/tmp/nmaforge_round14_h64_2token_batch/run.log` | `1cec870a432383c3996355dd071f9c9d17d96de0058715f9d570e7ed4fd8af5c` |
| Standard smoke | `dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | `8f1237b2b180de159eeff1adf4deec3f37b4a2001d59b980dba13bef88697741` |

Independent Python cache/recompute output ends with:
`H64_CACHE_RECOMPUTE_GOLDEN_PASS tokens=1,7 seed=20261116 tensors=16 full_desc=181 cache_desc=197`.

## Next decision

Keep Runtime changes as research verification infrastructure. Do not claim a
released host runtime until a non-testbench host driver and a legal host-visible
SPAD/completion access strategy exist. Continue H64 only with a token-scoped
planner and explicit Tensor ownership/lifetime allocation. The next gate should
be a two-token minimal plan where Token 0's Product K/V projection and append
complete before Token 1 starts, then Product KV_READ words are independently
shown to be the actual QK/AV source. Six-token work remains gated on that
Product Top proof. No product RTL or ABI proposal is justified by the current
evidence.
