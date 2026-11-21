# NMAForge V1.2 Round 21 — GPT-2 INT8 Quality Recovery

## Disposition

**PARTIAL — the quality collapse is localized to fixed-point scale/quantization alignment, but quality is not recovered and the candidate contract has not been executed on Product Top.** No frozen model package, Golden, RTL, or product configuration was changed.

## Fixed inputs and provenance

| Item | Value |
|---|---|
| Research branch | `research/nmaforge-v1.2-round21-gpt2` |
| Analysis base/source SHA | `ac088cf06c5188a814dc7753033bafc249ad265d` |
| Model | H64, 4 layers, 4 heads, FFN 256, byte vocabulary 256, context 16 |
| Training/checkpoint SHA-256 | `1d59cf803c328149add9ddb004766e63043b3babdb56ea178bf96d7a51fda8df` |
| Frozen INT8 package SHA-256 | `2132835994c2ecce03dc1d8e7345474eeddb271d86e34de9cc1f5ccdf2fecfc2` |
| Tiny Shakespeare corpus SHA-256 | `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed` |
| Round 21 analysis seed | `20261121` |

The previous, frozen Product Top regression remains evidence only for that package and source: four-layer RTL output was bit-exact with the independent integer reference. It does not qualify the scale-aligned candidate below.

## Root-cause evidence

Layerwise FP32-versus-integer tracing showed no broad input or Q8.8 up-projection saturation. The first severe divergence is in the output/residual scale chain, followed by large growth in residual2 across layers. On the 128-window diagnostic set, layer 0 projection integers ranged `[-973, 868]` while FP32 projection ranged approximately `[-0.635, 0.574]`; the direct same-domain MAE was `136.15`. Layer 0 residual1 had MAE `135.98`; residual2 MAE was `221.19`. Later residual2 MAE grew to `532.62` by layer 3. In contrast, the QKV tensors are clipped to INT8 without meaningful saturation and LayerNorm/FFN-up diagnostics do not show an earlier catastrophic clipping event.

This points to inconsistent scale contracts at Matrix projection → residual, LayerNorm beta, and FFN-up → GELU → down projection. It is a scale/alignment failure, not evidence that saturation is the sole cause. The trace is diagnostic; fitted scale values are not used to alter Golden or scores.

## Controlled software-only contract ablation

The frozen package and input windows were held fixed. `residual_gelu_aligned` applies a candidate output shift for attention projection, a separate Q8.8 FFN-up quantization for the existing GELU contract, a GELU-to-INT8 shift, a down-projection shift, and the package’s LayerNorm beta scale. It is **not** a Product Top run and is not an accepted new ABI contract.

| Contract / score | Frozen package contract | `residual_gelu_aligned` software candidate |
|---|---:|---:|
| Held-out targets | 256 | 256 |
| INT8 next-byte accuracy | 14.45% | 18.36% |
| FP32 accuracy on same targets | 37.11% | 37.11% |
| FP32/INT8 top-1 agreement | 21.48% | 30.08% |
| Cross entropy (nats) | 6.634 | 4.133 |
| Perplexity | 760.42 | 62.37 |
| Q8.8 up-weight saturation | 0% all layers | 0% all layers |

The candidate improves the software result, but remains below the independently measured bigram baseline (28.71%) and materially below FP32. Some deep residual traces still diverge. Therefore this is evidence for the scale diagnosis, not quality closure.

### Expanded fixed-window check and bounded shift ablation

To check whether the initial 256-window result was a small-sample artifact, the same corpus split, seed (`20261121`), model/package hashes, and contract were evaluated on 1,024 held-out windows (1,024 next-byte targets). This set uses 1,018 unique start offsets because sampling is with replacement. A bigram predictor was recomputed from the training split on the exact same target positions.

| Contract / reference | Targets | Accuracy | CE (nats) | PPL | FP32/INT8 top-1 agreement |
|---|---:|---:|---:|---:|---:|
| FP32 model | 1,024 | 37.40% | — | — | — |
| Frozen Product INT8 software reference | 1,024 | 11.52% | 6.774 | 874.97 | 18.85% |
| `residual_gelu_aligned` software candidate | 1,024 | 16.31% | 4.099 | 60.27 | 26.95% |
| Bigram, same target positions | 1,024 | 29.20% | not measured | not measured | — |

Thus the candidate reduces cross entropy and perplexity relative to the frozen package but is still 12.89 accuracy points below the same-window bigram baseline and 21.09 points below FP32. This is a material software diagnostic improvement, not recovery to useful model quality. The 1,024-window output from the original two-contract run is `benchmark/gpt2_quality/results/round21/round21_contract_ablation_1024.json`.

A further bounded grid tests whether the explicit output-projection/up-projection shifts are the dominant remaining sensitivity. It keeps weights, corpus, targets, seed, and all other contract fields fixed, and varies only those shifts (`o=7/10`, `up=0/5`). The output is `benchmark/gpt2_quality/results/round21/round21_contract_grid_1024.json`; its per-contract results are reported only as software experiments. None of these candidate shifts is an accepted descriptor package or Product Top result.

| Software contract | `o` shift | `up` shift | Accuracy | CE (nats) | PPL | Same-window bigram accuracy |
|---|---:|---:|---:|---:|---:|---:|
| `residual_gelu_aligned` | 7 | 0 | 16.31% | 4.099 | 60.27 | 29.20% |
| `residual_gelu_o10` | 10 | 0 | 14.94% | 3.901 | 49.44 | 29.20% |
| `residual_gelu_up5` | 7 | 5 | 0.68% | 12.779 | 354,719 | 29.20% |
| `residual_gelu_o10_up5` | 10 | 5 | 0.68% | 12.079 | 176,135 | 29.20% |

The sweep shows a sensitive multi-stage integer scale contract: increasing only the attention output shift improves CE/PPL but lowers top-1 accuracy; shifting the Q8.8 FFN-up accumulation by five bits collapses model quality. The current evidence is insufficient to select or ship a repaired contract. It reinforces that changing a shift in isolation is not quantization recovery; a compatible PTQ calibration/QAT and a new Product package/top replay would be needed.

## Artifacts and reproducibility

- `benchmark/gpt2_quality/analyze_round21_quantization.py`
- `benchmark/gpt2_quality/round21_contract_ablation.py`
- `benchmark/gpt2_quality/results/round21/round21_layerwise_quantization.json`
- `benchmark/gpt2_quality/results/round21/round21_contract_ablation.json`
- `benchmark/gpt2_quality/results/round21/round21_contract_ablation_1024.json`
- `benchmark/gpt2_quality/results/round21/round21_contract_grid_1024.json` (SHA-256 `e0d9279ffe5fdd1e01092261e1f4126952ee1327f9cfa36bdf2efa95f8e31632`)
- Independent reference: `benchmark/gpt2_quality/product_integer_reference.py`

Commands (run from repository root):

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/analyze_round21_quantization.py \
  --package benchmark/gpt2_quality/models/canonical_h64_byte_lm_int8.npz \
  --fp32 /tmp/nmaforge_v12_r20_gpt2_quality_corrected/h64_byte_lm_fp32.pt \
  --corpus /tmp/nmaforge_tinyshakespeare.txt --seed 20261121 --windows 128 \
  --out benchmark/gpt2_quality/results/round21/round21_layerwise_quantization.json

/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/round21_contract_ablation.py \
  --package benchmark/gpt2_quality/models/canonical_h64_byte_lm_int8.npz \
  --fp32 /tmp/nmaforge_v12_r20_gpt2_quality_corrected/h64_byte_lm_fp32.pt \
  --corpus /tmp/nmaforge_tinyshakespeare.txt --seed 20261121 --windows 256 \
  --out benchmark/gpt2_quality/results/round21/round21_contract_ablation.json

/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/round21_contract_ablation.py \
  --package benchmark/gpt2_quality/models/canonical_h64_byte_lm_int8.npz \
  --fp32 /tmp/nmaforge_v12_r20_gpt2_quality_corrected/h64_byte_lm_fp32.pt \
  --corpus /tmp/nmaforge_tinyshakespeare.txt --seed 20261121 --windows 1024 \
  --out benchmark/gpt2_quality/results/round21/round21_contract_grid_1024.json
```

The report and JSON are software analysis. No new VCS command was run for this candidate. QAT, per-layer/per-channel PTQ calibration, revised package export, candidate Top descriptor generation, and full autoregressive accuracy evaluation remain open. Do not claim recovered GPT-2 quality or a TinyNPU model-level comparison.
