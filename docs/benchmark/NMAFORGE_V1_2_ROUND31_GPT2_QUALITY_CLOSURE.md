# NMAForge-V1.2 Round 31 — GPT-2 Quantization Quality Closure

## Disposition

**PARTIAL.** The fixed Round 30 checkpoint and Product INT8 package were evaluated on a fixed validation window set. The aligned software integer path improves on the old frozen contract, but remains below the same-window Bigram baseline. A per-channel Q31 multiplier/shift candidate also fails to beat the scalar contract. No evidence justifies a Product RTL Requant change or another QAT round in this branch. The exact package hash has prior four-layer Product Top autoregressive Golden evidence; Round 31 did not rerun VCS because no package or RTL changed. The independent test range was not read.

## Frozen inputs and run

| Item | Value |
|---|---|
| Branch / starting commit | `research/nmaforge-v1.2-round31-gpt2` / `f055d91af0adccd64959450282db291ec96ac549` |
| Run ID / seed | `round31-gpt2-validation-20263101` / `20263101` |
| Corpus SHA-256 | `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed` |
| Split manifest SHA-256 | `78c4a0b3c3f67e693725bcc7c30caedca8d6b24cec7a6c685365c1ff04a6cd00` |
| Source FP32 checkpoint SHA-256 | `00f73c2eaf14e2c2ea170ae6bdbdbc570d6850bb2f3a77b61f68596e5019cca0` |
| QAT checkpoint SHA-256 | `ef43f58a66af89669c661d3a4c881451e8fdad7d43cfac636f9e98c1df7a1b56` |
| Existing Product INT8 package SHA-256 | `22ffc2103efd765817599b5ceb4ae3d839956b6523e91f0fa4fec759ab159af2` |
| Validation | 128 windows, 2,048 next-byte targets; context 16; validation range `[780792, 948067]` |
| Final test | Range `[948101, 1115394]`; **not read** |
| Software | Python 3.12.13, NumPy 2.5.4, PyTorch 2.6.0+cpu |

The main ablation uses the same fixed checkpoint, corpus, split manifest, and package across all contracts. It is a validation-only software diagnosis, not a retraining result. The per-channel experiment evaluates only the final position of each of the same 128 validation windows (128 targets), so its absolute metrics must not be compared directly to the 2,048-target main run.

## Validation results

Main run, common 2,048 targets:

| Contract | Accuracy | CE (nats) | PPL | Top-1 agreement vs FP32 | vs QAT Float |
|---|---:|---:|---:|---:|---:|
| FP32 | 37.06% | 2.2053 | 9.07 | — | — |
| QAT Float | 35.40% | 2.2375 | 9.37 | — | — |
| Product-aligned Fake Quant / Independent INT (`residual_gelu_aligned`) | 22.12% | 3.2707 | 26.33 | 39.06% | 35.74% |
| Old frozen integer contract | 11.28% | 5.2206 | 185.05 | 14.16% | 14.55% |
| Bigram | 26.66% | 2.5372 | 12.64 | — | — |

The aligned contract gains **10.84 percentage points** over the old frozen integer contract on this validation set, but is still **4.54 points below Bigram** and **13.28 points below QAT Float**. This does not close model quality.

Same-window per-channel experiment, 128 final-position targets:

| Contract | Accuracy | CE (nats) | PPL | Top-1 agreement vs FP32 | vs QAT Float |
|---|---:|---:|---:|---:|---:|
| FP32 | 38.28% | 2.2702 | 9.68 | — | — |
| QAT Float | 39.06% | 2.2819 | 9.80 | — | — |
| Scalar Power-of-Two product contract | 22.66% | 3.6126 | 37.06 | 32.03% | 32.81% |
| Per-channel Q31 multiplier + arithmetic shift | 21.88% | 3.4569 | 31.72 | 32.03% | 32.81% |
| Bigram | 25.78% | 2.3995 | 11.02 | — | — |

The Q31 candidate changes CE/PPL slightly but reduces accuracy by 0.78 points against the scalar contract and remains 3.91 points below Bigram. This software-only post-accumulator candidate has no RTL/ABI implementation or synthesis evidence. It does **not** support changing Product RTL.

## Error localization

The exported `round31_layer_tensor_error.csv` reports each activation's physical contract, scale interpretation, range, zero ratio, rail-code occupancy, MAE/RMSE and cosine similarity. `clip_event_ratio` is unavailable in the source artifacts; `rail_code_ratio` is only the fraction at the quantized rails and is not a measured clipping-event counter.

For the aligned contract, the first attention chain already shows loss relative to the QAT Float path: score MAE/RMSE `4.104/6.247` with cosine `0.9606`, probability cosine `0.8288`, and attention output MAE/cosine `0.1983/0.7532`. The first FFN block then shows a larger degradation at Down projection (`MAE 0.9633`, cosine `0.3751`) and Residual2 (`MAE 1.0207`, cosine `0.3625`). By Layer 3, Residual2 MAE reaches `4.0374` and cosine falls to `0.3042`; final logits MAE/RMSE are `1.707/2.154`, cosine `0.9216`.

This is evidence of cumulative scale/rounding sensitivity, not proof of one isolated RTL defect. An 8-window trace compared Fake Quant with the Independent Integer Reference at 56 nodes: **0 mismatches**. That establishes software contract alignment for the sampled trace only; it does not establish a new model's Product Top pass.

The progressive integerized-prefix diagnostic falls from 28.03% (one integerized layer) to 24.37% (four) on the same 2,048-target validation run. This indicates error accumulation across layers. It is a software diagnostic, not an RTL execution or causal isolation of a specific operator.

## Product Top evidence and limits

The existing package hash above matches the package in Round 30 Product Top evidence. That historical VCS run used `V-2023.12-SP1_Full64`, source commit `c45e307f12d05542f16068aeeb87bd8877176ed6`, and reported:

- two fixed prompts, each with four 256-logit contexts, bit-exact against the independent integer Golden;
- one unreset Product Top instance per prompt and zero Host intermediate-tensor writes;
- prefix-recompute feedback, not incremental query-only KV decode;
- `make_exit=0`, compile and run exit 0.

Round 31 reuses that evidence because the package hash is unchanged. It is **not** a Round 31 rerun, and it is not a language-quality PASS. Newly proposed quantization candidates have no Product Top evidence.

## Reproduction

```bash
source /tmp/nmaforge_round31_py/bin/activate
python benchmark/gpt2_quality/round31_fixed_checkpoint_ablation.py \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --split-manifest benchmark/gpt2_quality/results/round27_extended_train/corpus_split.json \
  --source-checkpoint benchmark/gpt2_quality/results/round27_extended_train/seed_20261221/fp32_before_qat.pt \
  --qat-checkpoint benchmark/gpt2_quality/results/round30_qat_fixed_source/source_20261221_qat_20263032/qat_float.pt \
  --package benchmark/gpt2_quality/results/round30_qat_fixed_source/source_20261221_qat_20263032/product_int8.npz \
  --out-dir benchmark/gpt2_quality/results/round31_validation_ablation \
  --windows 128 --seed 20263101

python benchmark/gpt2_quality/round31_per_channel_mshift_ablation.py \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --split-manifest benchmark/gpt2_quality/results/round27_extended_train/corpus_split.json \
  --source-checkpoint benchmark/gpt2_quality/results/round27_extended_train/seed_20261221/fp32_before_qat.pt \
  --qat-checkpoint benchmark/gpt2_quality/results/round30_qat_fixed_source/source_20261221_qat_20263032/qat_float.pt \
  --package benchmark/gpt2_quality/results/round30_qat_fixed_source/source_20261221_qat_20263032/product_int8.npz \
  --out benchmark/gpt2_quality/results/round31_validation_ablation/round31_per_channel_mshift.json \
  --windows 128 --seed 20263101
```

Both Round 31 commands exited 0. Exact stdout logs, machine-readable JSON/CSV, checkpoint/package references, and hashes are in `benchmark/gpt2_quality/results/round31_validation_ablation/`; see `round31_run_manifest.json` and `SHA256SUMS`.

## Gate status

| Gate | Status | Evidence |
|---|---|---|
| Fixed checkpoint / data / contract | PASS | Hashes and split recorded; test range not read |
| Layer-wise software error and contract A/B | PARTIAL | Tensor table and two software A/B runs; no multi-seed retraining |
| Candidate multiplier/shift quality | FAIL for selection | Does not beat scalar accuracy or Bigram; software only |
| Existing selected package four-layer Top function | PASS (historical evidence reused) | Exact same package hash; two prompt runs archived under Round 30 |
| New package Product Top qualification | NOT RUN | No new package selected/generated |
| Model quality closure | FAIL / OPEN | Current aligned integer result is below Bigram on validation; final test untouched |
| RTL Requant extension | NOT PROPOSED for implementation | Software evidence does not show a quality benefit |

## Evidence files

- `benchmark/gpt2_quality/round31_fixed_checkpoint_ablation.py`
- `benchmark/gpt2_quality/round31_per_channel_mshift_ablation.py`
- `benchmark/gpt2_quality/results/round31_validation_ablation/round31_validation_ablation.json`
- `benchmark/gpt2_quality/results/round31_validation_ablation/round31_layer_tensor_error.csv`
- `benchmark/gpt2_quality/results/round31_validation_ablation/round31_per_channel_mshift.json`
- `benchmark/gpt2_quality/results/round31_validation_ablation/round31_contract_summary.csv`
- `benchmark/gpt2_quality/results/round31_validation_ablation/round31_per_channel_summary.csv`
- `benchmark/gpt2_quality/results/round30_product_top_fixed_source/`
