# NMAForge v1.2 Round 13 — Runtime and Persistent Decode Status

## Baseline and Isolation

Research branch: `research/nmaforge-v1.2-round13`  
Base SHA (Round 12): `1353d0e5ca82518235f1f1553057832b55287f61`  
Product RTL and ABI: unchanged. No product branch or PR was merged.

Round 12's Make failure was a stale output-marker check, not a simulation or
Golden failure. VCS printed `DESCRIPTOR_VALIDATOR_PASS` and `simv` exited zero;
the Make recipe still searched for the older `invalid_rules=33` and
`boundary_accept=43/43` values. The current validator emits `37` and `44/44`.
The Round 13 research worktree updates only the expected marker and the full
`descriptor-validator-regress` Make target now exits zero.

This distinction is retained throughout this report:

- **Simulation PASS** means the VCS process completed and the testbench emitted
  its PASS marker.
- **Golden PASS** means the independent numerical/reference comparison passed.
- **Make target PASS** means all recipe commands and marker/count checks exited
  zero.

## Gate Results

| Gate | Status | Evidence |
|---|---|---|
| Round 12 validator/build diagnosis | PASS | `descriptor-validator-regress` complete Make target passes with the updated expected marker. |
| Reusable ring publication/retirement harness | PARTIAL PASS | Product Top accepts and executes 512 real VDOT descriptors with 8-entry CMDQ and 4-entry CPLQ, wraps both rings without reset, checks 512 result words and all four completion words through a nonintrusive behavioral-SPAD snapshot, and retires by AXI-Lite CPLQ_HEAD. Descriptor batches are published after the prior batch drains; publish-while-busy is not exercised. |
| Host-visible completion payload reads | OPEN | Reads during active compute can return `SLVERR` under the current host/compute SPAD conflict contract. The runtime test therefore does not claim CPU-visible CPLQ data reads; it uses the existing nonintrusive verification snapshot for payload checking. |
| H64 DMA batch replay | PASS, batch scope | Product Top reproduces the Round 12 six-token Matrix-A Tile batch: 229 descriptors, 31/31 intermediate checkpoints, DMA preload, and final SPAD Golden. This is not token-persistent decode. |
| H64 cache-vs-recompute independent Golden | PASS, Python only | 16 tensor-boundary comparisons pass for the six-token batch. No per-token Product Top comparison is implied. |
| H64 Token 0–5 persistent decode | NOT COMPLETE | There is no token-scoped descriptor publisher/retirement plan; current H64 mapping emits one global six-token graph. No persistent-decode PASS is claimed. |
| Four-layer H64 RTL / LM Head | NOT RUN | Gated on single-layer persistent decode; no four-layer RTL execution was attempted. |
| `ai_smoke` | PASS | Full Product Top smoke Make target and all its marker checks pass. Existing VCS loop-reroll fixture warning remains. |

## Streaming Runtime Result

The runtime stress task is in the Top Smoke testbench and is launched by
`ai_cmdq_stream_runtime`. It writes descriptors at run time through AXI-Lite,
publishes the CMDQ tail, polls hardware CMDQ_HEAD/CPLQ_TAIL, checks completion
records, and advances CPLQ_HEAD. Queue sizes remain 8 and 4 throughout the
512-command session. The DUT is reset only once at test start; there is no
reset, queue resize, head seed, or tail seed between command batches.

| Measure | Result |
|---|---:|
| Compute descriptors / independent output checks | 512 / 512 |
| CMDQ / CPLQ size | 8 / 4 entries (7 / 3 usable) |
| CMDQ / CPLQ pointer wraps | 64 / 128 |
| End-to-end driver window | 79,471 cycles |
| Accepted compute SPAD reads / writes | 4,096 B / 2,048 B |
| DMA bytes | 0 B (not applicable to this compute-only runtime stress) |
| CPLQ full condition | tail=3, head=0 held for 20 cycles, then released |
| Completion ordering | 512/512 task IDs in order; status=done, result=70, element count=1 |
| Numerical result | 512/512 VDOT results equal independent INT8 result 70 |
| Reset during session | 0 |

Completion record payloads and output values are checked with the
nonintrusive behavioral SRAM snapshot function already used by the
representative-model test. Pointer polling and CPLQ_HEAD writes are real
AXI-Lite transactions. Host SPAD reads are deliberately not counted as passed:
the memory model rejects a host access that overlaps an active compute SPAD
request, and the runtime must schedule/retry those reads around that conflict.
This is a verification-grade ring runtime exercise, not a released software
driver. This VDOT case has no DMA transfer, so DMA fence handling and reusable
tensor-lifetime transitions are not measured. Descriptor batches are published
dynamically between completed runs, but the harness does not extend CMDQ_TAIL
while a batch is active.

## H64 Replay and Decode Boundary

The Round 12 Product Top replay was regenerated and rerun with the same seed,
tokens, Matrix-A Tile layout, 128 KiB four-bank behavioral SPAD, and DMA
weight-loading path.

| Measure | Result |
|---|---:|
| Tokens in batch | `1,7,42,3,5,8` |
| Descriptors / intermediate checkpoints | 229 / 31 PASS |
| DMA preload | 45 transactions, 49,152 payload bytes |
| Command / end-to-end cycles | 266,858 / 338,050 (DMA preload included) |
| SPAD reads / writes | 346,496 B / 222,208 B |
| Useful / executed / padding MAC | 297,600 / 819,200 / 521,600 |
| Full-recompute comparison | 16 tensor boundaries PASS in independent Python reference |
| Per-token Product Top cycles | NOT MEASURED |

The first unimplemented persistent-decode node is the token-scoped execution
planner. `generate_h64_preln_qkv.py` builds embeddings, pre-LN, Q/K/V, K/V
cache operations, QK, causal Softmax, AV, output projection, residual, LN2,
and FFN as one graph over all requested token rows. It then emits one static
descriptor image and Golden image. It does not partition the graph into a
current-token producer batch and a following-token consumer batch. The
Product Top run consequently cannot prove that Token N's `KV_READ` result feeds
Token N+1's query computation after completion retirement.

The existing causal Softmax uses descriptor `aux0` as the query's causal
position, so the arithmetic primitive has an absolute-position control. The
missing work is the token-scoped planner/layout/dependency proof, not an
assumption that the existing six-token batch is already persistent decode.
No testbench or Host-generated intermediate was injected into the Product Top
for the batch replay; the generated initial image and DMA weights remain
testbench workload setup, while all descriptor computations execute in RTL.

## Four-Layer Preparation

The repository's H64 reference is deterministic synthetic pseudo-weight data,
not an exported pretrained GPT-2 checkpoint. Existing Product contracts
include Q15 causal Softmax, Q15 LayerNorm parameters with INT32 output,
INT8-packed Matrix operands, and the currently specified per-op shifts and
saturation. No four-layer H64 execution manifest or cross-layer lifetime plan
was generated in this round. A full reconciliation of a four-layer Golden
against each Product RTL quantization boundary remains OPEN and must precede
four-layer RTL work.

## Reproduction

Run from the isolated worktree:

```sh
cd dv/subsystem/top_smoke/sim
make ai_cmdq_stream_runtime \
  AI_CMDQ_STREAM_RUN=/tmp/nmaforge_round13_cmdq_stream_release \
  AI_CMDQ_STREAM_COUNT=512 AI_CMDQ_STREAM_SEED=20261115

make ai_h64_kv_roundtrip_top \
  AI_H64_KV_RUN=/tmp/nmaforge_round13_h64_baseline \
  AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_H64_KV_SEED=20261115 \
  'AI_H64_KV_GENERATOR_FLAGS=--kv-attention --tokens 1,7,42,3,5,8 --kv-k-write-mode matrix-a-tile'

cd ../../../../
/tmp/nmaforge_round10_venv/bin/python \
  benchmark/gpt2_compat/compare_h64_kv_recompute.py \
  --seed 20261115 --tokens 1,7,42,3,5,8 \
  --kv-k-write-mode matrix-a-tile

make -C dv/block/control/sim descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_round13_validator_final2
make -C dv/subsystem/top_smoke/sim ai_smoke
```

Tool versions: Synopsys VCS `V-2023.12-SP1_Full64`; Python `3.12.13` in
`/tmp/nmaforge_round10_venv`; 10 ns Top Smoke clock. `ai_smoke` reports the
existing `LOOP-REROLL-ENABLED` fixture warning.

Raw evidence:

- Runtime compile/run: `/tmp/nmaforge_round13_cmdq_stream_release/compile.log`,
  `/tmp/nmaforge_round13_cmdq_stream_release/run.log`.
- H64 batch compile/run and generated workload:
  `/tmp/nmaforge_round13_h64_baseline/`.
- Validator compile/run: `/tmp/nmaforge_round13_validator_final2/`.
- Smoke log: `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`.
- Independent recompute comparison: command output above; the script emits
  per-tensor PASS rows and `H64_CACHE_RECOMPUTE_GOLDEN_PASS`.

Selected SHA-256:

| Artifact | SHA-256 |
|---|---|
| Runtime compile log | `0376ae8a2bf145af31f9ee4c6d0b88437755148176a10a65e17ef69f896f9d54` |
| Runtime run log | `f70cb6e36c413b9918b266b1b276d3829adc50875d2525db420d847f2c5e94a9` |
| H64 compile log | `de300674f02c517131101ec6f954230fa73a84481a3ee288dbcae47fdf5f0c18` |
| H64 run log | `8f04246bc5cbf898b0634e9e55d544b5030b6bb2910d4c44eca3c3f721b94cf4` |
| Validator run log | `ee5e8162e76ea7242852872fab871d5663e7af60c1630c50dbe8609adb65264f` |
| `ai_smoke` log | `abe643a78ffc589294465ea5896acfd764a467d1e8476e0b5eaec22536d2160c6` |

## Decision

Streaming ring mechanics: **RETAIN as a research verification harness**, with
the explicit host-payload-read limitation above. Product host-runtime signoff:
**REWORK**. H64 persistent decode: **REWORK**, first implementation target is
a token-scoped descriptor planner that uses Matrix-A word K append, Product
KV_READ history, absolute causal position, and per-token completion fences.
Four-layer execution remains gated. Product RTL/ABI remain unchanged.
