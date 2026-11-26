# NMAForge v2 Round 25 — Performance Leadership Decision

**Disposition: `PARTIAL`**
**Evidence source SHA:** `1354626f9a41229b698fd2ada031a2c3916cb42c`
**Product RTL tree SHA-256:** `fae8778d62c06c324bf5be0b5cbfea6843141e08`
**TinyNPU reference SHA:** `8216c22b762011aa20c05fc2768423fd12dda59d`

## Decision

Round 25 produced a substantially better software INT8 Transformer candidate, refreshed the TinyNPU GEMM/Mini-CNN runs, and measured a production-payload DMA path for one trained-CNN sample. It did **not** establish a qualified Transformer model for new RTL inference: the best INT8 candidate remains 7.67 percentage points below its FP32 reference and was not run on Top RTL. No SFU RTL optimization was made. The TinyNPU GEMM comparison remains mixed measured/modeled, and the Mini-CNN endpoints differ. Therefore the evidence does not support a system-level TinyNPU win or “performance leadership.”

No product RTL changed in this round. The frozen RTL tree is identical to the preceding research baseline.

## Scope and evidence status

| Work item | Status | Result |
|---|---|---|
| INT8 Transformer quality recovery | `PARTIAL` | Best independent INT8 accuracy 74.4629%; still 7.6660 pp below FP32; candidate not Top-tested |
| Transformer SFU optimization | `NOT_RUN` | Quality gate not met; only inherited profile and screening estimates retained |
| Trained CNN dataflow replay | `PASS` for one selected sample | Both-fused Row-Major, DMA payload, 20,800 Golden words; not a full end-to-end run |
| TinyNPU rebuild and paired GEMM | `PASS` for bounded matrix set | Tiny engine regression 6/6; all three paired GEMM outputs pass; comparison is mixed measured/modeled |
| TinyNPU common Mini-CNN | `PASS` functionally | Same model/input Golden; timing endpoints differ, so no speedup is computed |
| TinyNPU GEMV / Transformer comparison | `NOT_RUN` | The Round 25 comparison script did not execute those workloads |

The archived run manifest, exact commands, tools, run IDs, hashes, and artifacts are in [`round25_run_manifest.json`](../../benchmark/representative/round25/round25_run_manifest.json) and [`round25_artifact_hashes.json`](../../benchmark/representative/round25/round25_artifact_hashes.json). Machine-readable summaries and raw logs are under [`benchmark/representative/round25`](../../benchmark/representative/round25/).

## Transformer quantization recovery

The workload is a synthetic finite-state next-token task, not natural-language training. The model is H=16, two heads, one layer, context 8, vocabulary 32, with Post-LayerNorm ordering. Do not describe it as a standard GPT-2 block or evidence of language-model quality. Training used seed `20261123`, 4,096 training sequences and 1,024 held-out sequences (seed `20261125`); positions 4–7 contribute 4,096 held-out predictions.

| Candidate | Held-out accuracy | Cross entropy (nats) | Perplexity | Notes |
|---|---:|---:|---:|---|
| Original FP32 reference | 82.1289% | 0.585270 | 1.79548 | Pre-QAT checkpoint |
| Initial scalar INT8 | 8.7158% | 30.3991 | 1.59e13 | Severe quantization collapse |
| Best Round 24 calibrated PTQ | 38.9160% | 6.03357 | 417.20 | Historical software reference |
| Round 24 QAT, GELU scale 64 | 38.0615% | 2.38760 | 10.887 | Older artifact had a Top bit-exact run; not a Round 25 result |
| Round 25 QAT, GELU scale 32 | 65.0146% | 1.24142 | 3.4605 | Independent INT8 evaluation; no Top run |
| **Round 25 QAT, GELU scale 16** | **74.4629%** | **0.787709** | **2.19836** | Best candidate; no Top run; gap to FP32 is 7.6660 pp |

The GELU-scale-16 candidate improves the initial INT8 accuracy by 65.7471 pp and reduces cross entropy from 30.3991 to 0.787709. It still misses the requested ≤5 pp FP32/INT8 gap by 2.6660 pp. Its post-QAT FP32 checkpoint scores 62.8174% on the same held-out positions, so the training outcome itself is not uniformly strong; the apparent higher INT8 score should not be treated as language capability. The GELU-scale-32 candidate scores 65.0146% INT8.

The layerwise comparison places substantial error after the GELU16 adjustment: FFN-down MAE/RMSE is 0.8071/1.3816, LayerNorm2 saturation is 1.707%, and final-logit MAE/RMSE is 3.9473/6.0854 with 60.47% top-1 agreement against the compared floating path. GELU saturation falls to 1.181%. Earlier Round 24 evidence identified coarse LayerNorm1 scaling, GELU clipping, fixed-point exponential differences, and LM-head scaling as candidate contributors; Round 25 does not prove one exclusive root cause. Full per-layer results are in the two `layerwise_error` and `layerwise_threeway` CSV/JSON sets.

**Conclusion:** quantization recovery is meaningful but incomplete. The GELU16 model SHA is `e7a521c762b66e5754d6d95c411c163452e0c9b01088cb11631202338cd28225`; the GELU32 model SHA is `58a503cb151bf903059c105b2ef08bd970a2867a686903c7e978646fd7f92369`. Neither candidate was loaded into Top RTL. There is no new Round 25 RTL-logit or model-cycle evidence, and no basis to optimize SFU against this unqualified candidate.

## Transformer profile and bounded optimization screen

The available opcode profile is inherited from the Round 24 persistent H16 session, not measured on either Round 25 QAT candidate. It covers eight decode tokens / 72,312 total cycles / 424 descriptors:

| Operation interval | Cycles | Share of session cycles |
|---|---:|---:|
| LayerNorm | 23,872 | 33.01% |
| Requant | 14,816 | 20.49% |
| Residual | 12,720 | 17.59% |
| GEMM | 8,688 | 12.01% |
| GELU | 3,184 | 4.40% |
| Softmax | 3,880 | 5.37% |
| KV write/read | 5,152 | 7.13% |

SFU busy is 56,000 cycles and overlaps operation intervals; it must not be added to the mutually exclusive interval totals. The inherited mean was 9,039 cycles/token. This is not a Round 25 candidate result.

The screening file [`round25_sfu_candidate_estimates.csv`](../../benchmark/representative/round25/round25_sfu_candidate_estimates.csv) contains optimistic ceilings, not measured savings:

- Residual/LN fusion: at most 12,720 cycles (17.59%, 1.214×) only under the unrealistic assumption that the complete residual interval disappears at zero replacement cost. The addition still has to execute.
- LN output plus INT8 requant: at most 3,552 cycles (4.91%, 1.052×) using the existing 222-cycle descriptor estimate; the 2,048-byte traffic reduction is inferred, not measured.
- LN row batching: 23,872 cycles is a gross ceiling, not a realistic saving, because normalization arithmetic remains and descriptor/control cost was not isolated.

No RTL optimization was attempted. The next optimization decision requires a profile from an accuracy-qualified, Top-executed model.

## Trained CNN: current DMA-path replay

Run `R25-CNN-DMA-20261125-R0`, simulation seed `20261125`, test rank 0 / sample index 42. The deployed model is the trained 3×3 + pointwise INT8 Digits CNN (570,164 useful MAC/inference); its historical held-out accuracy is 346/360 = 96.111%. Round 25 replayed one sample only: label 1 predicted as label 1, with all 20,800 checked Golden words passing.

The current two-descriptor Both-Fused Row-Major path measured:

| Metric | Result |
|---|---:|
| CMDQ execution | 12,947 cycles |
| DMA setup + transfer window | 3,019 cycles |
| DMA window + CMDQ subtotal | 15,966 cycles |
| Useful MAC / CMDQ cycle | 44.0383 |
| Array-utilization counter | 82.37% |
| SPAD read / write | 64,064 B / 16,640 B |
| Production input/weight/descriptor DMA payload | 10,944 B |
| AXI read bursts / beats | 45 / 684 |
| Mean / max response wait | 47.6 / 50 cycles |
| Output readback and host postprocessing | Not included |

The payload comprises 7,488 B input pack (7,056 B valid im2col plus 432 B padding), 3,328 B weights, and 128 B descriptors, transferred in four segments. The 83,232-byte Poison/Sentinel setup is test-only and excluded from production payload. The measured subtotal is not full application end-to-end latency: full host resize/coordinate generation/packing, descriptor programming, output readback, global-average pooling, and argmax are not all timed. The reported 0.361 ms is only the Im2col subroutine, not full preprocessing. Memory is a behavioral AXI model, not external DDR.

Historical Round 20 dataflow runs are retained because their product RTL tree hash equals the Round 25 RTL tree, but their test source and measurement setup are historical and not exhaustive for each ablation. They show CMDQ cycles of 66,023 (Legacy), 23,577 (First-layer Fused), and 12,947 (Both-layer Fused Row-Major). The 360/360 exhaustive Top Golden is specifically for the both-fused mode; it is not a fresh Round 25 360-sample rerun. For the current CNN, the Round 25 one-sample replay confirms the DMA payload plan and output Golden only. Do not present historical AXI-Lite poison-initialization preload cycles as production DMA transfer cost.

## TinyNPU benchmark

TinyNPU was rebuilt from the pinned reference. The bounded Tiny engine regression passed 6/6. Current script coverage includes three paired GEMM cases and `conv1x_mini.onnx`; it does not run GEMV or Transformer workloads.

### Paired GEMM results

| Shape | Useful MACs | NMAForge measured controller + behavioral SPAD | Tiny direct array RTL | Tiny common-memory modeled endpoint | NMAForge / modeled Tiny |
|---|---:|---:|---:|---:|---:|
| 16×16×16 | 4,096 | 177 cycles | 52 cycles | 151 cycles | 1.1722× |
| 16×16×32 | 8,192 | 265 cycles | 100 cycles | 231 cycles | 1.1472× |
| 32×32×64 | 65,536 | 1,384 cycles | 790 cycles | 1,305 cycles | 1.0605× |

All output Golden checks pass. NMAForge's measured endpoint is slower than the Tiny modeled endpoint in all three cases. The ratio is `NMAForge cycles / modeled Tiny cycles`, so values above 1 mean NMAForge takes longer. Tiny's direct-array cycles are RTL measured, but its common-memory endpoint is a serialized 16 B/cycle, one-cycle response model around that array. NMAForge includes its Matrix controller and behavioral SPAD. This is a mixed measured/modeled comparison, not a matched full-system RTL result and not a claim of a TinyNPU system speedup. See [`round25_tinynpu_matched_gemm.csv`](../../benchmark/representative/round25/round25_tinynpu_matched_gemm.csv).

### Common Mini-CNN

Both implementations pass Golden on the same `conv1x_mini.onnx` (model SHA `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`) and input (seed 99, SHA `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`). The workload has 1,872 MACs. NMAForge reports 1,985 CMDQ + 1,080 Host Layout = 3,065 phase cycles, excluding preload, descriptor setup, and final host read/processing. TinyNPU reports 4,781 Graph cycles, including its graph dispatch and testbench DMA/SRAM shim. Because the timing boundary and included work differ, no cross-system speedup is computed. No Round 25 trained-CNN or Transformer comparison was run on TinyNPU.

## Reproduction and tool record

Run IDs, commands, paths, versions, model hashes, payload hashes, and log hashes are recorded in the run manifest. Key versions: VCS `V-2023.12-SP1_Full64`; Verilator `5.052` (`2026-09-05`, `v5.052`); Python `3.12.13`; NumPy `2.4.6`; ONNX `1.17.0`; PyTorch `2.7.1+cpu`.

Key commands (temporary output paths refer to the measured environment):

```sh
# QAT candidates and independent held-out analysis
/tmp/nmaforge_round23_torch/bin/python sw/tools/train_tiny_gpt2.py \
  --out /tmp/nmaforge_round25_qat_gelu16.json --seed 20261123 \
  --epochs 120 --train-sequences 4096 --test-sequences 1024 \
  --norm-output-scale 16 --gelu-output-scale 16 --wdown-weight-scale 16 \
  --qat-epochs 120 --qat-lr 0.0002 \
  --float-checkpoint-dir /tmp/nmaforge_round25_qat_gelu16_ckpt

# Trained CNN production-payload Top replay
make -C dv/subsystem/top_smoke/sim ai_representative_trained_cnn_dma \
  AI_REPRESENTATIVE_DMA_RUN=/tmp/nmaforge_round25_trained_cnn_dma \
  AI_REPRESENTATIVE_DMA_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  AI_REPRESENTATIVE_DMA_SEED=20261125 AI_REPRESENTATIVE_DMA_TEST_RANK=0

# Pinned TinyNPU rebuild / bounded comparison
TINYNPU_BENCH_OUT=/tmp/nmaforge_round25_tiny SEED=20261125 \
  BENCH_RUN_ID=R25-TINY-20261109 \
  TINY_NPU_ROOT=/tmp/nmaforge_round25_tiny/reference/source \
  TINYNPU_WORK_ROOT=/tmp/nmaforge_round25_tiny/reference \
  VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python JOBS=2 \
  bash benchmark/tinynpu/run_comparison.sh
```

The exact GELU32 and analyzer commands are in `round25_run_manifest.json`. Logs are preserved below `cnn/logs/` and `tinynpu/logs/`; no proprietary PDK, license, SRAM library, or EDA database is included.

## Final disposition

`PARTIAL` is the evidence-based disposition. This round improves the quantized synthetic Transformer in software, validates a fresh trained-CNN DMA Top sample, and refreshes a bounded TinyNPU comparison. It does not provide a quality-qualified Transformer Top run, a Round 25 GEMV/Transformer TinyNPU comparison, a matched TinyNPU system endpoint, or complete CNN application end-to-end timing. No new RTL optimization or hardware-cost result is claimed. The two existing innovations remain plausible research mechanisms, but this round's measured evidence does not establish that NMAForge leads TinyNPU.

The architecture should not be frozen on a claim of model-level performance leadership from these results. The next decision should be made from the remaining concrete gaps above; this report does not start another work round.
