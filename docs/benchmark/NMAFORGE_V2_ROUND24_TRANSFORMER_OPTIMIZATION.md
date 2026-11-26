# NMAForge v2 Round 24 — Transformer Quality and Performance

**Disposition: `PARTIAL`.** The quantized model now matches the independent INT8 reference in one uninterrupted Top simulation covering Prefill and eight Decode steps. INT8 quality improved substantially from the initial export but remains far below the FP32 checkpoint. This round made no product RTL or cycle optimization, and the Decode inputs were teacher-forced by the test flow rather than selected live from the Top logits.

## Frozen source and run identity

| Item | Value |
|---|---|
| Requested baseline / remote feature HEAD | `1c54ac593808126439a5b46109a674065e5525e4` |
| Tested software/test source commit | `c48c641ad320a2c56c6e1c3d57a0ccb7c22ec7f5` |
| RTL tree at tested source | `fae8778d62c06c324bf5be0b5cbfea6843141e08` |
| RTL changes in Round 24 | None |
| Persistent session run | `R24-TOP-PERSISTENT-S20261123` |
| Training / held-out seeds | `20261123` / `20261125` |
| TinyNPU pinned SHA | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64` |
| Python / ML stack | Python `3.12.13`, PyTorch `2.7.1+cpu`, NumPy `2.4.6` |
| Clock used for behavioral simulation | 4 ns period (250 MHz assumption only; not an ASIC frequency result) |

Source and run manifests, machine-readable tables, quantized models, FP32 checkpoints, held-out sequences, and logs are archived in [`benchmark/representative/round24/`](../../benchmark/representative/round24/). The authoritative hashes and commands are in its [`run_manifest.json`](../../benchmark/representative/round24/run_manifest.json).

## 1. Model and numerical quality

The model is a reproducibly trained **synthetic finite-state next-token task**, not natural-language pretraining. It is one layer, Hidden 16, two 8-wide heads, Context 8, Vocab 32, signed INT8 export, learned position embeddings, and a tied LM head. Its block is Post-LayerNorm; it is GPT-2-like, not operation-order-identical to GPT-2's Pre-LayerNorm block. The task has 4,096 training sequences and 1,024 independent held-out sequences, each nine tokens long. Quality comparisons below use the same four teacher-forced prediction positions (4–7), 4,096 predictions total.

The earlier baseline headline of **71.41% FP32 / 8.72% INT8** mixes scopes: 71.41% is FP32 accuracy over positions 0–7, while the independent INT8 reference measured positions 4–7. On the matched decode slice, the same baseline FP32 checkpoint is 82.13% and INT8 is 8.72%. The archive labels these scopes separately; only matched-scope rows should be compared directly.

| Model / path | Decode accuracy | Cross-entropy (nats) | Perplexity | Interpretation |
|---|---:|---:|---:|---|
| Original trained FP32 checkpoint | 82.13% | 0.5853 | 1.795 | Pre-QAT weights |
| Original weights, initial scalar INT8 | 8.72% | 30.3991 | 1.59e13 | Initial quantization failure |
| Calibrated PTQ, best tested accuracy (LN scale 16) | 38.92% | 6.0336 | 417.20 | Same original FP32 weights; accuracy improved, probability calibration remains poor |
| QAT 120 epochs, independent scalar INT8 | 38.06% | 2.3876 | 10.89 | New QAT weights; best tested cross-entropy/perplexity |
| QAT 120 epochs, fake-quant software path | 36.25% | 2.3456 | 10.44 | Training-side fake-quant metric |
| QAT 120 FP32 weights, ordinary float path | 21.44% | 6.4062 | 605.56 | QAT changes the FP32 behavior; do not compare as quantization-only degradation |
| Smoothed bigram baseline | 6.70% | 3.1701 | 23.81 | Synthetic task baseline |

QAT raises independent INT8 accuracy from 8.72% to 38.06% and improves cross-entropy/perplexity, but it does **not** recover FP32 quality: the best PTQ accuracy is 43.21 percentage points below the original FP32 decode accuracy. The best QAT cross-entropy is better than the bigram baseline, but its accuracy is still far from the FP32 checkpoint. The requested ≤5-point FP32/INT8 gap is not met. The final QAT model is therefore not quality-closed and is not evidence of a useful language model.

### Error localization

The initial same-weight FP32-versus-independent-INT8 trace first loses substantial information at LayerNorm1, then degrades sharply through the FFN:

| Stage | MAE | Top-1 agreement | Quantization observation |
|---|---:|---:|---|
| Q/K/V projections | 0.159–0.164 | 93.5–98.3% | Relatively small initial error |
| Softmax probabilities | 0.0144 | 95.6% | Low probability MAE; RTL uses fixed-point exp2 semantics rather than PyTorch's natural-exponential path |
| LayerNorm1 | 0.6419 | 72.0% | Original output scale 1 leaves only integer-level resolution |
| FFN-up | 0.8081 | 58.2% | Error grows after LayerNorm quantization |
| GELU-to-INT8 | 0.7884 | 18.9% | 29.97% saturation at ±127/−128 in the initial export; Q8.8 values were narrowed with shift 0, clipping near +0.496 real value |
| FFN-down / residual2 | 3.0146 / 3.2070 | 37.8% / 30.0% | Error compounds through integer accumulation and residual |
| Final logits | 17.1277 | 9.3% | Severe downstream disagreement |

The likely causes are numerical-contract mismatches, not evidence of an RTL functional bug: the original trainer used PyTorch Softmax/GELU, while the hardware reference uses fixed-point Q8.8 exp2 Softmax and bounded piecewise Q8.8 GELU; LayerNorm originally exported at unit scale; GELU narrowing used a shift that saturated many values; and LM-head logit scale affects cross-entropy strongly. The Round 24 scale sweep changes LayerNorm output scale to 16 and GELU output scale to 64, and uses corresponding power-of-two GEMM shifts. The three-way FP32/fake-quant/independent-INT8 per-stage comparison for the final QAT checkpoint is in [`layerwise_threeway.csv`](../../benchmark/representative/round24/layerwise_threeway.csv); baseline localization is in [`layerwise_error_baseline.csv`](../../benchmark/representative/round24/layerwise_error_baseline.csv).

Quantization contract for the selected QAT artifact: LayerNorm output scale 16; GELU output scale 64 (Q8.8-to-INT8 right shift 2); Wdown weight scale 16; GEMM shifts QKV=4, Wo=4, QK=0, Wup=4, Wdown=6, LM Head=4. Top Logits match the independent scalar INT8 reference exactly. That proves implementation agreement for this fixed-point contract, not FP32 model quality.

For the final post-QAT checkpoint, fake-quant and independent INT8 traces agree exactly through embedding/QKV/score stages, then show small numerical differences from AV onward; fake-quant-to-INT8 Logit MAE is 0.463 in the recorded scale. The post-QAT ordinary FP32 path is a poor reference for quantization loss because QAT changed the weights to fit its fake-quant path (its held-out decode accuracy is only 21.44%). Read [`layerwise_threeway.csv`](../../benchmark/representative/round24/layerwise_threeway.csv) with that distinction in mind: it reports stagewise FP32, fake-quant, and independent INT8 values, but does not make the post-QAT FP32 path an accuracy target equivalent to the original pre-QAT model.

## 2. Persistent Top Decode

**Result: `PERSISTENT_TOP_DECODE_PASS` for the bounded teacher-forced session.** VCS ran one `simv` process, one initial reset and SPAD/model initialization, then Prefill followed by eight Decode batches. The DUT was not reset and the KV cache was not cleared between batches. The queue was re-armed between commands. Four Prefill tokens occupy cache slots 0–3; Decode positions 4–11 append to an eight-slot ring, overwriting the oldest slot after capacity. Position embedding wraps modulo 8, and all eight live slots are visible. This is bounded rolling-window behavior, not unbounded-context GPT inference.

| Stage | Cycles | Descriptors | Golden words | Useful MACs | SPAD read / write bytes |
|---|---:|---:|---:|---:|---:|
| Prefill (4 tokens) | 2,734 | 40 | 368 | 3,072 | 2,560 / 1,536 |
| Decode position 4 | 8,887 | 53 | 1,360 | 2,208 | 9,056 / 5,264 |
| Decode position 5 | 8,991 | 53 | 1,360 | 2,240 | 9,056 / 5,264 |
| Decode position 6 | 9,130 | 53 | 1,360 | 2,272 | 9,056 / 5,264 |
| Decode position 7 | 8,876 | 53 | 1,360 | 2,304 | 9,056 / 5,264 |
| Decode position 8 | 9,260 | 53 | 1,360 | 2,304 | 9,056 / 5,264 |
| Decode position 9 | 9,208 | 53 | 1,360 | 2,304 | 9,056 / 5,264 |
| Decode position 10 | 9,006 | 53 | 1,360 | 2,304 | 9,056 / 5,264 |
| Decode position 11 | 8,954 | 53 | 1,360 | 2,304 | 9,056 / 5,264 |
| **Eight Decode steps** | **72,312** | **424** | **10,880** | **18,240** | **72,448 / 42,112** |

Mean Decode latency is **9,039 cycles/token**. At the simulation's assumed 250 MHz clock this corresponds to 27.66k tokens/s arithmetically, not measured silicon throughput. Useful MAC/cycle is 0.252 across Decode. The reported active-array utilization is 4.33% at steady full-window steps. Matrix is active for 208 cycles/token; SFU busy is 6,837–7,221 cycles/token. These busy counters overlap other activity and must not be added to command cycles.

Every Decode batch matches the independent INT8 Logits and the physical KV-cache hash; all 1,360 expected words per Decode stage and all 368 Prefill words pass. The persistent runner also verifies that the 53 descriptor intervals per token sum exactly to that token's command interval. Token inputs are fixed, host-supplied teacher-forced values. Although logits are checked, they are **not** returned to a live host process to choose the next input token. Thus this is persistent incremental KV execution, not closed-loop autoregressive generation.

Timing excludes training, model/weight loading, initial SPAD population, host embedding/position preparation, descriptor programming, final host readback, token selection and tokenizer work. The SPAD byte counts are observed command-path traffic, not external DDR transaction measurements. Full application End-to-End latency is `NOT_MEASURED`.

## 3. Opcode profile and optimization result

Exclusive descriptor intervals over the eight Decode steps close exactly to 72,312 cycles:

| Opcode | Function | Descriptors | Cycles | Share of Decode cycles |
|---|---|---:|---:|---:|
| `0x30` | GEMM | 128 | 8,688 | 12.01% |
| `0x34` | Residual | 24 | 12,720 | 17.59% |
| `0x35` | GELU | 8 | 3,184 | 4.40% |
| `0x36` | Requant | 104 | 14,816 | 20.49% |
| `0x38` | LayerNorm | 64 | 23,872 | 33.01% |
| `0x39` | Softmax | 16 | 3,880 | 5.37% |
| `0x43` | KV Write | 48 | 2,528 | 3.50% |
| `0x44` | KV Read | 32 | 2,624 | 3.63% |
| **Total** |  | **424** | **72,312** | **100%** |

SFU busy totals 56,000 cycles (77.47% of the Decode command window) as an overlapping activity counter. It is not an additional exclusive phase. LayerNorm alone is the largest exclusive opcode interval. The theoretical Amdahl bound if all LayerNorm cycles disappeared with every other interval unchanged is 72,312 / (72,312 − 23,872) = **1.493×**, or 6,055 cycles/token over this run. That is a bound, not an expected result.

No Round 24 RTL optimization was implemented. The existing exact LayerNorm fast path was measured as-is; no new batching, residual/requant fusion or descriptor scheduling was introduced. Therefore the cycle reduction attributable to a Round 24 optimization is **0 cycles demonstrated**. The exploratory target below 7,000 cycles/token was not met. The 8,987-cycle figure from the prior model is not a valid before/after baseline because the weights/quantization and persistent growing-window workload differ. The most useful bounded architecture candidate remains reducing LN's four row-wise descriptor passes per application LN operation, but it requires a separate correctness and hardware-cost study.

## 4. TinyNPU comparison

TinyNPU remains pinned at `8216c22b762011aa20c05fc2768423fd12dda59d`. Round 24 did not run the trained synthetic Transformer on TinyNPU, and did not rebuild a common Transformer endpoint. The historical paired GEMM/GEMV work uses matching mathematical operands and Golden checks, but the NMAForge measurement includes Matrix controller plus behavioral SPAD while TinyNPU exposes Direct Array RTL; its common-memory figure is modeled. These are useful shape diagnostics but are not matched system endpoints. The Round 20 raw cycle ratios below (`NMAForge measured / TinyNPU modeled`) indicate which direction those mixed diagnostic numbers moved; they are **not** system speedups and are not Round 24 measurements.

| Historical workload | NMAForge controller + behavioral SPAD | Tiny direct array | Tiny modeled common-memory | Mixed cycle ratio NMA/Tiny-model | Direction of these diagnostic numbers |
|---|---:|---:|---:|---:|---|
| GEMM 16×16×16 | 172 | 52 | 151 | 1.139 | NMAForge higher |
| GEMM 16×16×32 | 268 | 100 | 231 | 1.160 | NMAForge higher |
| GEMM 32×32×64 | 1,411 | 790 | 1,305 | 1.081 | NMAForge higher |
| GEMV 1×13×17 | 68 | 100 | 126 | 0.540 | NMAForge lower |
| GEMV 8×16×19 | 163 | 100 | 170 | 0.959 | NMAForge lower |
| GEMV 16×16×19 | 266 | 100 | 218 | 1.220 | NMAForge higher |
| GEMV 16×16×65 | 637 | 244 | 459 | 1.388 | NMAForge higher |

The prior `conv1x_mini.onnx` evidence reports NMAForge 1,985 CMDQ + 1,080 Host-layout cycles versus TinyNPU 4,781 graph cycles. Those boundaries also differ; do not compute a cross-system speedup from them. Historical endpoint definitions, hashes, and run manifests remain in [Round 20](NMAFORGE_V2_ROUND20_RESEARCH_EVIDENCE.md) and [Round 22](NMAFORGE_V2_ROUND22_PERFORMANCE_CLOSURE.md).

| Workload | Round 24 status | Comparison boundary |
|---|---|---|
| INT8 GEMM/GEMV fixed shape matrix | Historical data only | Same operand/Golden shapes; controller/memory endpoints differ, no system speedup |
| Same QKV/FFN subgraph | `NOT_RUN` | No frozen common model/input run in this round |
| Trained H16 synthetic model | `NOT_RUN` on TinyNPU | Mapper/operator and model-level endpoint not established on TinyNPU |
| Native End-to-End Transformer | `NOT_COMPARABLE` | NMA host-prepared Top command run versus no matching TinyNPU graph run |

No workload in Round 24 supports a defensible NMAForge-versus-TinyNPU End-to-End speedup. The fixed shape comparisons should remain described as prior diagnostic evidence only. For a paper, no cross-project performance-leading claim is justified yet; the Round 20/22 shape-level data can be included only with the mixed measurement boundaries stated above.

## 5. Final decisions

| Question | Result |
|---|---|
| INT8 quality recovered to FP32? | **No.** Best tested INT8 accuracy 38.92% (PTQ) / 38.06% (QAT) versus original FP32 82.13% on the same Decode positions. |
| Persistent KV Decode? | **PASS**, one Top process, eight append/read/decode steps, Golden and physical KV hashes match. Inputs remain host teacher-forced; no live argmax feedback. |
| Per-op cycles known? | **PASS.** 424 descriptor intervals close exactly to 72,312 cycles; SFU busy is reported separately. |
| Decode optimization demonstrated? | **No.** Zero new RTL, no valid before/after cycle reduction; 9,039 cycles/token remains above the 7,000-cycle target. |
| TinyNPU same-model comparison? | **NOT_RUN.** No common trained model/subgraph endpoint. |
| Freeze for front-end sign-off? | **No.** Quality is not recovered; dynamic feedback and full application timing are absent. This round also does not provide full DV or sign-off evidence. |

The evidence is sufficient to retain the INT8 Top/Golden path as a functional research fixture and to document quantization failure modes. It is not sufficient to claim a high-quality Tiny-GPT model, autonomous generation, a Round 24 performance improvement, a TinyNPU win, or front-end sign-off readiness.

## Reproduction

Commands, tool versions, artifact hashes, and log hashes are in [`run_manifest.json`](../../benchmark/representative/round24/run_manifest.json). The canonical training command is:

```bash
PYTHON=/tmp/nmaforge_round23_torch/bin/python  # Python 3.12.13 + PyTorch 2.7.1+cpu + NumPy 2.4.6 used for this run
"$PYTHON" sw/tools/train_tiny_gpt2.py \
  --out benchmark/representative/round24/models/tiny_gpt2_h16_qat_int8.json \
  --seed 20261123 --epochs 120 --train-sequences 4096 --test-sequences 1024 \
  --norm-output-scale 16 --gelu-output-scale 64 --wdown-weight-scale 16 \
  --qat-epochs 120 --qat-lr 0.0002 \
  --float-checkpoint-dir benchmark/representative/round24/models
```

The deterministic rerun reproduced model SHA-256 `530471bee248a3271325c00f6b635f9cab3b445f5c370eb1785905beed338b44` and both FP32 checkpoint hashes. The exact Python interpreter path and tool-source SHA-256 values are recorded in `run_manifest.json`. The exact Top-session simulator command is preserved in `persistent_decode.json`; the compile invocation, simulator log, generator log, and their SHA-256 values are preserved with the evidence package. The system `/usr/bin/python3` on the run host was 3.6.8 and is too old for these scripts; use the recorded Python 3.12 environment or an equivalent environment with the listed packages.
