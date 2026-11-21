# NMAForge-V1.2 Round 24 — GPT-2 QAT Quality Recovery

## Disposition

**Product Top candidate qualification: PASS. Model-quality closure: PARTIAL.** The selected INT8 package completed four-layer Product Top forward/logit readback and four autoregressive feedback steps. It is bit-exact to the independent integer reference. The quality result is only 1.27 percentage points above the same-window bigram on 1,024 held-out targets; a second training seed performed materially worse on its 48-window validation sample. This is not sufficient to claim robust language-model quality recovery.

## Frozen implementation and numeric contract

- Branch: `research/nmaforge-v1.2-round24-gpt2`
- Tested source SHA: `f4f4316aec3188676b035e0475ab9b05dbc3fe12`
- Product RTL and numeric Golden were unchanged.
- Trainer: `benchmark/gpt2_quality/train_round24_integer_qat.py`
- Package: `benchmark/gpt2_quality/results/round24/round24_integer_qat_model.npz`
- Package SHA-256: `fa66d2ecd6709c0a49e5c23d6346de22adfbf2f0809f182e581fa63cbcb9a54b`
- QAT checkpoint SHA-256: `73801ce5682759ecb37f581ba6423c1a06abda9dba4e4538461d9b524817b796`
- Corpus: Tiny Shakespeare, SHA-256 `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed`.
- The Round24 fake-quant LayerNorm forward models Product Q3 input, truncating mean, floor variance, integer square root, Q30 reciprocal, Q5 gamma, unit-scale integer beta, and signed INT32 saturation. Gradient uses an STE through quantized floating LayerNorm. Other Product Q3/Q5/Q8.8/Q15/GELU/per-K16-down contracts are inherited from Round23.
- No per-channel activation scale is represented by the current descriptor contract; diagnostic range suggestions were not silently applied.

## Controlled training and quality evidence

Seed 20261125 used 500 steps, batch 16, AdamW, learning rate 2e-5, with training/development limited to the first 90% of the corpus. The final 10% was not used for fitting or calibration. Validation used 48 windows, seed 2026112401. An independent seed 20261126 used the same step/batch/rate settings but a different source FP32 checkpoint.

| Candidate / reference | Split | Targets | Accuracy | CE (nats) | PPL |
|---|---|---:|---:|---:|---:|
| Round24 INT8, seed25 | held-out | 1,024 | 30.4688% | 2.4876 | 12.0325 |
| QAT-updated float, seed25, same targets | held-out | 1,024 | 27.2461% | — | — |
| Bigram, same targets | held-out | 1,024 | 29.1992% | — | — |
| Round24 INT8, seed25 | validation | 48 | 29.5573% | 2.5405 | 12.6865 |
| QAT-updated float, seed25 | validation | 48 | 29.2969% | 2.5624 | 12.9665 |
| Round24 INT8, seed26 | validation | 48 | 24.8698% | 2.7383 | 15.4607 |
| QAT-updated float, seed26 | validation | 48 | 25.7813% | 2.7817 | 16.1464 |

The seed25 INT8 candidate exceeds its same-window bigram by 1.2695 percentage points, but the sample is small and seed26 shows substantial instability. Historical Round23 figures (original FP32 37.4023%, QAT INT8 29.0039%) came from a different evaluation record and are not pooled with the Round24 paired test. The candidate's same-target QAT-float top-1 agreement with INT8 is 32.7148%.

The held-out tensor diagnostics are in `benchmark/gpt2_quality/results/round24/heldout_diagnostics.json`. For the selected candidate, fake-quant versus independent integer logits have MAE 1.0200, RMSE 1.3161, cosine similarity 0.97786. Integer logits versus the QAT-updated FP32 logits have MAE 1.9753, RMSE 2.5281, cosine 0.93029. Maximum listed activation saturation is about 0.1051% (`l3.q`); weight endpoint saturation is zero. Thus widespread clipping is not supported as the cause of the remaining quality gap. The material risks are small-model/data generalization and seed sensitivity; scale and arithmetic limitations remain candidates for further controlled study, not proven hardware root causes.

## Product Top replay

The VCS environment was available. Version: `V-2023.12-SP1_Full64`. Compile and simulation exit codes were both 0. The compile log includes the existing `LOOP-REROLL-ENABLED` warning; no Product RTL change was made. Raw compile/run logs are retained losslessly as `.log.gz` files under `product_top_run/`; their original and archive hashes are in `round24_product_top_qualification.json`.

Command (from the worktree root, with the VCS environment already configured):

```bash
cd dv/subsystem/top_smoke/sim
make ai_h64_four_layer_top_argmax AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_MODEL_NPZ="$PWD/../../../../benchmark/gpt2_quality/results/round24/round24_integer_qat_model.npz" \
  AI_H64_NUMERIC_PROFILE=round21_residual_gelu_aligned \
  AI_H64_FOUR_LAYER_RUN=/tmp/round24_gpt2_product_top/run2 \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

The captured invocation compiled `tb_ai_accel_smoke` with `+define+VCS`, `AI_REPRESENTATIVE_LONG_TASK`, `AI_H64_WEIGHT_DMA`, and `AI_SPAD_WORDS_PER_BANK=8192`; it ran one Product Top instance with prompt `[1,7,42,3]`. Host read actual Product Top SPAD logits, used signed INT32 argmax with lowest-token-ID tie break, and supplied only token embedding/position inputs. Generated tokens were `[10,10,65,82]`. Four contexts × 256 logits (1,024 values total) matched the independent integer Golden exactly; reset count and host intermediate tensor writes were zero.

This run uses **four-layer prefix recomputation in the same Top instance**. It is not query-only incremental KV decode and the 4,339,422 extension cycles are not an isolated per-token latency result. The VCS `run.log`, `compile.log`, four logits CSVs, SPAD allocation CSV, plan and result JSON are retained under `benchmark/gpt2_quality/results/round24/product_top_run/`.

## Reproduction boundaries and remaining work

Seed26 training log is retained under `results/round24/seed_20261126/`. Seed25 training output, weights, diagnostics and Product Top logs are retained. However, the source FP32 checkpoint for seed25 is identified by SHA `fea7b0f819ad3cfe9d8ab3f5f12cab632ae005aabf444cd75611846acbf6bde3` but its source `.pt` is not present in this worktree; the original seed25 training log was also not archived. Exact retraining therefore requires restoring that checkpoint and the public corpus file whose SHA is recorded above. This reproducibility gap is disclosed rather than replacing the source with a different model.

Reproduction command for seed25, after restoring the source checkpoint and corpus:

```bash
python3 -u benchmark/gpt2_quality/train_round24_integer_qat.py \
  --fp32 /path/to/round23_qat_updated_fp32.pt \
  --corpus /path/to/tinyshakespeare.txt \
  --out-dir benchmark/gpt2_quality/results/round24/reproduction \
  --seed 20261125 --steps 500 --batch 16 --lr 2e-5 --validation-windows 48
```

Machine-readable summary: `benchmark/gpt2_quality/results/round24/round24_quality_summary.csv` and `round24_product_top_qualification.json`. No change to product RTL, ABI, or Golden is included.
