# NMAForge-V1.2 Round 31 — GPT-2 Quantization Quality Closure

## Disposition

**PARTIAL.** The fixed Round 30 checkpoint and Product INT8 package were evaluated on a fixed validation window set. The aligned software integer path improves on the old frozen contract, but remains below the same-window Bigram baseline. A per-channel Q31 multiplier/shift candidate also fails to beat the scalar contract. A bounded three-seed QAT retraining follow-up was then run from the fixed FP32 checkpoint. Its validation-selected package remained below Bigram, and its Product Top attempt was blocked before compilation by VCS license-server connectivity. No evidence justifies a Product RTL Requant change. The exact prior package hash retains historical four-layer Product Top evidence; that is distinct from the new package attempt. The final test was evaluated post-validation-selection for all three QAT candidates, so it is not a pristine future confirmation set.

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
| Final test for fixed-checkpoint ablation | Range `[948101, 1115394]`; not read in that ablation |
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

## Bounded multi-seed QAT retraining follow-up

To address the Round 31 request for contract-aligned QAT, the same source checkpoint, corpus, split manifest, context, training settings, and Product Integer Forward were used for three QAT seeds. The validation set selected seed `20263113` by Product-INT validation accuracy (CE tie-break). The held-out test was evaluated only after that validation selection, but all three candidate test results were inspected and therefore the test must not be described as untouched in later selection work.

| Split / model | Accuracy mean ± population SD | CE mean ± population SD | PPL mean ± population SD |
|---|---:|---:|---:|
| Validation QAT Float | 35.303% ± 0.000 pp | 2.2388 ± 0.0011 | 9.382 ± 0.010 |
| Validation Product INT8 | 21.452% ± 0.180 pp | 3.2839 ± 0.0201 | 26.684 ± 0.539 |
| Validation Bigram | 26.660% | 2.5372 | 12.644 |
| Post-selection test QAT Float | 35.347% ± 0.064 pp | 2.2262 ± 0.0009 | 9.264 ± 0.009 |
| Post-selection test Product INT8 | 20.626% ± 0.089 pp | 3.2741 ± 0.0143 | 26.422 ± 0.377 |
| Post-selection test Bigram | 26.514% | 2.5198 | 12.426 |

The selected seed's validation Product INT8 accuracy is `21.6797%`, below the earlier fixed-checkpoint aligned candidate's `22.1191%` on the same 2,048-target validation set. Its post-selection test score is `20.75195%`, while Bigram is `26.51367%`; this is a post-hoc diagnostic, not a clean final model-quality confirmation. Fake Quant and Independent INT traces match at all 56 recorded nodes across 8 sampled windows, but this only confirms the tested software contract trace.

The selected package SHA-256 is `d9ff47c56a4ddc335a34d601d2083cfa2967d179b6aa617fdb25e484a9af3bb4`; its QAT checkpoint SHA-256 is `a5e42d806859bd702194054b053cd5a3a1e48004c053f67012ed6f4470d8f5c7`. Workload preparation generated four-layer per-token descriptor counts `[225, 225, 225, 258]` for the initial prompt and later plans for feedback tokens. Planner status explicitly remains `PLANNER_READY_REQUIRES_PRODUCT_TOP_AUTOREGRESSIVE_PASS`; it is not RTL evidence.

The selected package was submitted to the existing Top flow using VCS `V-2023.12-SP1_Full64` and `-licwait 1`. VCS reported `Cannot connect to the license server`, queued for the VCS-BASE-COMPILE/VCSCompiler_Net feature, and was manually interrupted after the bounded wait. `make` exited `130`; no compile or simulation began and there are no RTL logits. Gate status for this new package is **BLOCKED_ENV**, not PASS. The original make/compiler logs are archived losslessly as gzip files (`top_attempt/make.stdout.log.gz`, `top_attempt/compile.log.gz`), alongside the generated four-layer workload manifest, planner output, and SPAD allocation.

Retraining command and settings:

```bash
python benchmark/gpt2_quality/round30_fixed_checkpoint_qat.py
# fixed source seed 20261221; QAT seeds 20263111, 20263112, 20263113
# 200 steps/seed, batch 8, learning rate 1e-5, validation 128 windows,
# post-selection test 512 windows, trace 8 windows
python benchmark/gpt2_quality/summarize_round31_qat_retrain.py \
  --results benchmark/gpt2_quality/results/round31_qat_retrain
```

## Gate status

| Gate | Status | Evidence |
|---|---|---|
| Fixed checkpoint / data / contract | PASS | Hashes and split recorded; fixed-checkpoint ablation did not read test |
| Layer-wise software error and contract A/B | PARTIAL | Tensor table, software A/B and three-seed QAT; test later inspected post-selection |
| Candidate multiplier/shift quality | FAIL for selection | Does not beat scalar accuracy or Bigram; software only |
| Existing selected package four-layer Top function | PASS (historical evidence reused) | Exact same package hash; two prompt runs archived under Round 30 |
| New package Product Top qualification | BLOCKED_ENV | Selected package prepared; VCS license server unreachable before compilation |
| Model quality closure | FAIL / OPEN | Selected candidate below Bigram on validation and post-selection test |
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
- `benchmark/gpt2_quality/summarize_round31_qat_retrain.py`
- `benchmark/gpt2_quality/results/round31_qat_retrain/round31_qat_seed_summary.csv`
- `benchmark/gpt2_quality/results/round31_qat_retrain/round31_qat_seed_summary.json`
- `benchmark/gpt2_quality/results/round31_qat_retrain/SHA256SUMS` (25 archived files; verified with `sha256sum -c`)
- `benchmark/gpt2_quality/results/round31_qat_retrain/round31_qat_retrain.stdout.log.gz`
- `benchmark/gpt2_quality/results/round31_qat_retrain/fixed_validation_ablation.stdout.log.gz`
- `benchmark/gpt2_quality/results/round31_qat_retrain/top_attempt/compile.log.gz` and `make.stdout.log.gz`
- `benchmark/gpt2_quality/results/round31_qat_retrain/top_attempt/`
