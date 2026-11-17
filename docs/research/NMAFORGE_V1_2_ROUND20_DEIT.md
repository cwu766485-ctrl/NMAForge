# NMAForge v1.2 Round 20 — DeiT-Tiny Track Closure

## Disposition

**Track B: `PARTIAL`; Encoder Layer 0 `NOT_RUN`.** The full patch embedding
Product Top pass from Round 19 is retained as the starting point. Round 20 did
not run or claim a full Encoder Layer. The first integration gap is a data
representation/lifetime boundary between the tested packed INT8 Matrix-A
embedding output and the LayerNorm/QKV consumer path. It is not correct to
describe `ln_input_cache[0:15]` as a 16-element LayerNorm hardware maximum:
that array is only the fast path; the generic LayerNorm path accepts longer
vectors and uses repeated SPAD passes and iterative division. The generic H=192
path still needs a legal producer/consumer layout and numeric mapping before a
Product Top Encoder run can be assembled.

## Fixed source and checkpoint

| Item | Value |
|---|---|
| Research branch | `research/nmaforge-v1.2-round20-deit` |
| Round 20 branch base | `8f626c07644ff620b5756920b79c40245eabc4d3` |
| Tested patch-embedding implementation | `0a1d7545d84de6f8c3a771c3764c0a3616fc8d2f` |
| Round 19 Product RTL tree | `8798decc60fe257ef685a0b1c7e8814816e1d4de` |
| Checkpoint | `facebook/deit-tiny-patch16-224`, revision `b3428f18dcc7b543470d07f14b4a4157815d1880` |
| Checkpoint file SHA-256 | `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` |
| Test input | deterministic synthetic RGB fixture, processed by pinned official image processor |
| Image SHA-256 / processed pixels SHA-256 | `d2029eee4ae0be2479a662a7ed549836200929b41987d23caa68d924f0c89f0a` / `028bcacc0b989481a9e7b1fb119974605721e2cc063a76d1dd1b248d088f9b88` |
| VCS | Synopsys V-2023.12-SP1_Full64 |

The checkpoint is genuine official DeiT-Tiny weights. The image stimulus is a
deterministic fixture rather than a labeled ImageNet image; no classification
accuracy is claimed. The numerical contract and dequantized FP32 comparison
are in `benchmark/deit/round19/evidence.json`.

## Gate status

| Gate | Round 20 status | Evidence / remaining work |
|---|---|---|
| D0 — 256 KiB Top and queue geometry | `PASS_REUSED_R19` | Four banks × 16,384 words × 4 B = 262,144 B. Queue reserve is 40,960 B (CMDQ 32,768 B + CPLQ 8,192 B). |
| D1 — complete patch embedding | `PASS_REUSED_R19` | 196×192 patches plus CLS/position; 468 descriptors retired; 9,984/9,984 Product Top output words matched independent integer Golden. |
| D2 — full 197-token Encoder Layer 0 | `BLOCKED_NOT_RUN` | No integrated LN→QKV→QK→full-row Softmax→AV→projection→residual→LN→FFN Product Top command graph with Product-generated intermediates exists in this branch. |
| D3 — 12 layers + classifier | `NOT_RUN_GATED_ON_D2` | No twelve-layer Top graph, classification logits or image accuracy. |

No Round 20 VCS compile/run was performed for the encoder because there is no
valid integrated workload to execute. This is not a simulator/license failure
and is not a Product RTL functional failure. Round 19 raw VCS logs are retained
outside Git and identified below.

## Reused Round 19 Product Top evidence

The workload shape is 196 patches, input K=768, output H=192, 197 logical
tokens, and physical rows padded to 208. Mapping used 16×16 macro tiles:
156 GEMM tiles, each followed by correction and requant descriptors. Product
Top completed all 468 descriptors, 300 fenced DMA events and 9,984 Golden-word
checks.

| Metric | Round 19 result |
|---|---:|
| Useful / executed / padding MACs | 28,901,376 / 30,670,848 / 1,769,472 |
| Command window | 921,283 cycles |
| Command window excluding explicit late-DMA windows | 829,747 cycles |
| Late-DMA setup/transfer windows / DMA busy | 91,536 / 81,000 cycles |
| Top session through completion and output readback | 1,409,279 cycles |
| Useful MAC per command cycle | 31.3708 |
| Reported useful array utilization | 94.23% |
| SPAD reads / writes | 4,323,072 / 359,424 B |
| Late DMA payload | 307,200 B in 300 fenced events |
| Host AXI-Lite fixture / test-only poison | 241,664 / 51,200 B |

These are VCS Product Top counters under a 10 ns test clock, not wall-clock or
post-layout timing. Top-session accounting includes fixture setup, scheduled
DMA, command execution and output readback; Python preprocessing and checkpoint
loading are excluded. Patch embedding INT8 output compared with FP32 has MAE
0.0756258 and RMSE 0.0874820 for this single synthetic image only.

## First Encoder integration gap

### Producer/consumer representation

The tested patch-embedding command sequence writes a packed INT8, 16×16
macro-tile-major output in Matrix-A physical order. In contrast, SFU scalar
LayerNorm reads signed 32-bit values at `src0 + 4*index`, and its gamma/beta
operands are 32-bit words. The current Product workload does not define an
integer mapping that converts the embedding's packed/tile-major values into
the required LayerNorm representation while preserving the official checkpoint
scales. QKV GEMM also needs its declared operand packing and position/CLS
semantics. Thus, the tested embedding output is not yet a ready-to-consume
Encoder activation.

The SFU numeric contract declares nonzero vector lengths through 65,535, and
the LayerNorm FSM has a generic multi-pass path outside its ≤16-element
small-vector optimization. A 192-element Length is therefore representable in
the SFU control/data path by inspection, but the full H=192 Product Top
LayerNorm contract has not been run in this pipeline. Existing `REQ-CL-023`
selected-domain tests and the isolated 197-value Softmax probe are not proof
of this complete layer.

### Memory budget

The Round 19 full embedding allocation is:

| Region | Byte range | Bytes |
|---|---:|---:|
| Input/patch matrix | `[4096,163840)` | 159,744 |
| Streamed weights | `[163840,176128)` | 12,288 |
| Bias | `[176128,176896)` | 768 |
| GEMM scratch | `[176896,177920)` | 1,024 |
| Residual scratch | `[177920,178944)` | 1,024 |
| Position/CLS correction | `[178944,179968)` | 1,024 |
| Packed output | `[179968,219904)` | 39,936 |
| Data high-water | `[0,219904)` | 219,904 |
| CMDQ/CPLQ reserve | `[221184,262144)` | 40,960 |

Only 1,280 B separate gap remains before the queues in this tested allocation.
An Encoder workload must release patch inputs and streamed tiles when their
last consumer retires, reuse scratch between query blocks and stream layer
weights. A bidirectional encoder does not need all twelve layers' K/V caches
resident simultaneously; KV is per-layer attention scratch and can be reclaimed
after that layer. A 197×197 INT32 score matrix is 155,236 B per head; three
heads cannot be held together in the remaining capacity. A 16-query ×197-key
INT32 block is 12,608 B per head, but key tiles must contribute to one global
Softmax normalization, not be independently normalized. No Round 20 liveness
allocator or full-layer address map has been qualified.

## Minimal next integration work (not implemented as RTL in this round)

1. Define one exact activation scale and a legal packed-INT8 → SFU INT32
   LayerNorm input path, including tile order, signed unpacking, rounding and
   saturation. Prefer a bounded descriptor/SFU input mode or a small mapper
   conversion using an already-supported data path; do not silently host-write
   the converted tensor.
2. Extend a lifetime-aware 256 KiB allocation: reuse patch/input regions,
   retain only one query block of scores/probabilities, stream QKV/FFN weights,
   keep the entire 197-key row in the same Softmax max/sum/output passes.
3. Build and run the actual Product Top graph in order: LN1, QKV, head split,
   QK scores, Softmax, AV, output projection, residual, LN2, FFN1, GELU,
   FFN2, residual. Compare each Product-generated tensor with independent
   integer Golden and report integer-vs-FP32 error separately.
4. Only after D2 passes, generate the twelve-layer streaming schedule and run
   final LayerNorm, 1000-way classifier and real labeled-image accuracy.

## Reproduction and raw evidence

The inherited R19 command from `dv/subsystem/top_smoke/sim` was:

```bash
make ai_deit_round19_full_patch_embedding_256k \
  AI_DEIT_R19_RUN=/tmp/nmaforge_deit_r19_top_002 \
  AI_DEIT_R19_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_DEIT_R19_MODEL_DIR=/tmp/nmaforge_deit_round17
```

| Artifact | Path | SHA-256 |
|---|---|---|
| Compile log | `/tmp/nmaforge_deit_r19_top_002/compile.log` | `b62dba21268cfeacc060d720d68eb1a1bca18930886adfd676d8534b4cb39b6a` |
| Run log | `/tmp/nmaforge_deit_r19_top_002/run.log` | `b540bd83306df4943025a5e6487cc24e1adf313850f4c15e5f60408fa9f613fb` |
| Machine evidence | `benchmark/deit/round19/evidence.json` | `a031389c5492eca0f164813697ed279e072a68fdfd9e9c476d63380d543aae07` |
| Summary CSV | `benchmark/deit/round19/summary.csv` | `300c5873cda3cf5780f02e8aabd882791a6a76c152317f2e47478fefa9f1413d` |

Round 20 did not create a new encoder run log or a new result CSV. This is
intentional: the missing integration contract means there is no valid full
Encoder workload yet, so no software-only plan is presented as RTL evidence.
