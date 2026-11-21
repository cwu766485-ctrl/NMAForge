# NMAForge-V1.2 Round 23 — GPT-2 Quantization Recovery

## Disposition

**Product Top functional gate: PASS. Model quality gate: PARTIAL.**

A contract-aligned 1,200-step QAT candidate was exported twice from the same fixed inputs; both exports had the same package SHA-256. The package passed four-layer Product Top prefix-recompute autoregressive feedback. All four 256-element logits vectors matched the independent integer Golden bit-for-bit.

The quality target is not closed: INT8 held-out accuracy is 29.0039%, two targets below the same-window Bigram baseline at 29.1992%, and below the original FP32 model's 37.4023%. This is a byte-level Shakespeare task result, not a general language-model quality claim.

## Frozen inputs and reproducibility

- Initial H64 FP32 checkpoint SHA-256: 1d59cf803c328149add9ddb004766e63043b3babdb56ea178bf96d7a51fda8df
- QAT-updated float checkpoint SHA-256: fea7b0f819ad3cfe9d8ab3f5f12cab632ae005aabf444cd75611846acbf6bde3
- Corpus SHA-256: 86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed
- Held-out protocol: first 90% of corpus for training/calibration; last 10% held out; first 5% of held-out region skipped as in Round 22.
- Training: seed 20261123, 1,200 steps, batch 16, AdamW learning rate 1e-4.
- Calibration: 256 windows drawn only from the first 90%, seed 20261121 XOR 0xCA11B. Calibration ranges were diagnostic; the Product descriptor format cannot express independent per-channel activation/output scales, so no unsupported scales were applied.
- Evaluation: 1,024 fixed targets, seed 20261121.
- INT8 package: benchmark/gpt2_quality/results/round23/round23_product_qat_model.npz
- Package SHA-256: 4d931a7fe8fab88b035fd9a29b2d9c6206a35e988f3f5fd044d65b231073961d
- Re-running the exact QAT command reproduced the same package hash.

Training command:
    /tmp/nmaforge_deit_round17_venv/bin/python -u benchmark/gpt2_quality/train_round23_product_qat.py --fp32 /tmp/nmaforge_v12_r20_gpt2_quality_corrected/h64_byte_lm_fp32.pt --corpus /tmp/nmaforge_tinyshakespeare.txt --out-dir /tmp/round23_gpt2/reproduction --seed 20261123 --steps 1200 --batch 16 --lr 1e-4

The calibration and tensor diagnostics command is recorded in benchmark/gpt2_quality/results/round23/round23_gpt2_run_manifest.json. It emits per-tensor min/max, saturation, MAE, RMSE, normalized RMSE, cosine similarity and held-out top-1 agreement.

## Integer contract

The package follows tensor_q_format_contract.json and the round21_residual_gelu_aligned Product profile:

| Tensor / operation | Contract |
|---|---|
| Embedding + position | signed INT8 Q3, scale 8 |
| Projection weights and Q/K/V output | signed INT8 Q5, scale 32; QKV GEMM shift 0 |
| Attention scores | signed INT32 Q8.8, GEMM shift 2; no additional 1/sqrt(d) factor |
| Softmax / AV | unsigned Q15 probability; AV consumes probability shifted right by 8 (Q7) |
| LayerNorm gamma / beta | signed INT32 Q5 gamma; Q3 package beta divided by 8 |
| Output projection / residual | Q3 residual; output projection shift 7 |
| FFN up | signed INT8 Q8.8 weights, Q8.8 accumulator |
| GELU | Product piecewise integer Q8.8 GELU; shift 5 to INT8 |
| FFN down | 16 K=16 partials, each floor-requantized with shift 5 before summing |
| Final logits | signed INT32 Q5; software evaluation divides by 32 |

The QAT fake-quant graph models the observable shifts and saturation. Its PyTorch LayerNorm is not bit-exact to the Product integer LayerNorm. Independent integer reference and Product Top comparisons remain the correctness authority.

## Quality result

All metrics below use the same 1,024 held-out targets.

| Model | Accuracy | Cross entropy (nats) | Perplexity |
|---|---:|---:|---:|
| Round 22 INT8 candidate | 16.3086% | 4.0989 | 60.2735 |
| Round 23 QAT INT8 candidate | 29.0039% | 2.5272 | 12.5182 |
| Same-window Bigram | 29.1992% | — | — |
| Original FP32 model | 37.4023% | — | — |
| Round 23 QAT-updated float checkpoint | 27.6367% | — | — |

The QAT INT8 score improved by 12.6953 percentage points over the prior INT8 candidate; cross entropy fell by 1.5717 nats and perplexity by 47.7552. The candidate remains 0.1953 percentage points below Bigram (2 of 1,024 targets), so the acceptance criterion “exceed Bigram” is not met. Its top-1 agreement with the QAT-updated float checkpoint is 33.9844%; the trained float checkpoint itself also trails the original FP32 baseline.

The independent tensor report is round23_qat_diagnostics.json. In physical units, errors grow through the residual/FFN chain: Layer 0 down MAE 0.9572 and Residual2 MAE 1.0222; Layer 1 Residual2 MAE 2.0383; Layer 2 3.0730; Layer 3 4.0905. Final LayerNorm MAE is 0.6178 and logits MAE is 1.8955 (cosine 0.9283). INT8 endpoint saturation is sparse (largest listed Q endpoint ratio is below 0.1%); widespread clipping is not the observed explanation. The diagnostic also shows fake-quant versus integer LayerNorm differences, so further quality work should first improve the training surrogate/scale contract rather than change Golden.

## Product Top evidence

Command:
    cd dv/subsystem/top_smoke/sim
    make ai_h64_four_layer_top_argmax AI_H64_AUTOREGRESSIVE=1 AI_H64_FOUR_LAYER_MODEL_NPZ=/tmp/round23_gpt2/qat_contract_aligned/round23_product_qat_model.npz AI_H64_NUMERIC_PROFILE=round21_residual_gelu_aligned AI_H64_FOUR_LAYER_RUN=/tmp/round23_gpt2/qat_contract_aligned/product_top_autoreg AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python AI_H64_FOUR_LAYER_SEED=20261123 AI_H64_FOUR_LAYER_TOKENS=1,7,42,3 VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs

- VCS: V-2023.12-SP1_Full64; compile exit 0, 0 compile errors; KDB summary reports 0 errors / 0 warnings.
- Run: four generated tokens [10, 10, 73, 73].
- Prompt: [1, 7, 42, 3]; logits were read from Product Top SPAD and host Argmax used lowest-token-id tie breaking.
- Four contexts each checked 256 logits bit-exact against the independent integer Golden. SHA-256 of each little-endian INT32 vector is in round23_autoregressive_result.json.
- 4,020 descriptor publications; 4,339,728 reported session extension cycles; zero reset events and zero Host intermediate words.
- Mode is four_layer_prefix_recompute_same_top_instance. These results do not represent query-only incremental decode or a persistent-KV latency optimization. The reported cycle count is the run's prefix-recompute extension total, not an isolated per-token latency.

Raw compressed compile/run logs, logits dumps, QAT training/diagnostic logs, plan, result, and independent Golden bundle are under benchmark/gpt2_quality/results/round23/.

## Changes and remaining work

- Added the Product-contract-aligned QAT trainer, quantization diagnostic, and explicit fixed-point contract.
- Product RTL/ABI and Golden were not changed.
- Product Top correctness is closed for this candidate package; model quality is still PARTIAL. The next quality experiment should target the observed cumulative Residual2/LayerNorm mismatch and use a held-out set that remains fixed and disjoint from calibration.
