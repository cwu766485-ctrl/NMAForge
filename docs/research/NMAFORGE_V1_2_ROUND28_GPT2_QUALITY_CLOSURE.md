# NMAForge-V1.2 Round 28 — GPT-2 Track Evidence

**Disposition: PARTIAL.** A clean-split H64 research candidate passes the existing four-layer Product Top autoregressive replay bit-exactly. Its test accuracy is only modestly above the byte bigram baseline, while cross-entropy/perplexity are worse; model-quality closure is not achieved.

## Frozen source and evaluation contract

| Item | Value |
|---|---|
| Branch | `research/nmaforge-v1.2-dual-final-round28-gpt2` |
| Source commit used for the Product Top run | `ae06661c8c2416ad5af011088cbe0eedc5077c5c` |
| Product INT8 package SHA-256 | `9e330e56226d76aaf5c639975b30ae2612a1a965ec4c942cb9f93db86dc5a803` |
| Corpus SHA-256 | `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed` |
| Independent test-starts SHA-256 | `36c21c93a1c98515c4f8a6209fe016688babe19d991a3d0ad7af4573419376a2` |
| Model/task | byte-level Tiny-Shakespeare H64 research model; **not pretrained GPT-2** |
| Split | 70/15/15 contiguous corpus regions; 17-byte guards around boundaries; context 16; windows cannot cross split boundaries |
| Test size | 512 context windows × 16 targets = 8,192 targets |
| Product contract | 4 layers, 4 heads, FFN 256, vocabulary 256; package fixes per-op shifts and LN/logit scales |
| Seed | selected replay seed `20261223`; clean-split experiment seeds `20261221`, `20261222`, `20261223` |

The corpus source ranges are recorded in `benchmark/gpt2_quality/results/round27_extended_train/corpus_split.json`. Train/validation/test byte intervals are disjoint. This removes overlapping-window leakage across split boundaries; it does not make Tiny-Shakespeare a broad language benchmark.

## Held-out quality

All values below use the same 8,192 target positions for the selected seed. Accuracy alone is insufficient: Product INT8 slightly exceeds Bigram accuracy but has worse CE/PPL.

| Model | Accuracy | Cross-entropy (nats) | Perplexity |
|---|---:|---:|---:|
| FP32 | 35.7300% | 2.22248 | 9.2302 |
| QAT-updated Float | 28.0273% | 2.49580 | 12.1315 |
| Product INT8 / independent integer | 27.9053% | 2.60427 | 13.5213 |
| Byte Bigram | 26.8921% | 2.53785 | 12.6524 |
| Fake Quant (diagnostic) | 7.6904% | 6.51377 | 674.3617 |

Product INT8 vs Bigram paired bootstrap uses the whole context window as the sampling unit (20,000 resamples): accuracy delta **+1.0132 percentage points**, 95% CI **[+0.0366,+1.9897] pp**; CE delta **+0.06642 nats** (worse), 95% CI **[+0.04232,+0.09094]**. Product-vs-FP32 top-1 agreement is 46.81%.

Three clean-split seeds, each evaluated against the same fixed test targets, produced Product INT8 accuracy mean **27.8971%**, sample SD **0.2076 pp**; QAT Float **29.8462% ± 1.5969 pp**; FP32 **35.6934% ± 0.2280 pp**. The frozen per-seed data are in `round28_paired_quality.json`. The bootstrap interval is for the selected seed only, not a pooled multi-seed confidence interval.

**Interpretation:** the candidate has a small accuracy advantage over the byte bigram baseline, but loses on log loss and perplexity and remains well below FP32. Do not describe this as useful language-model quality closure or pretrained GPT-2 deployment.

## Product Top qualification

The new clean-split seed `20261223` INT8 package was run on the actual four-layer Product Top path. Four contexts each produced 256 logits; every logit matched the independent integer Golden. Host readback Argmax supplied the next token. The run had zero reset events and zero host-written intermediate tensor words. Execution mode is `prefix_recompute` on the same Top instance, so the cycles include repeated prefix work and are not query-only incremental decode timing.

| Metric | Result |
|---|---:|
| Top status | `FOUR_LAYER_TOP_AUTOREGRESSIVE_GOLDEN_PASS` |
| Contexts / logits | 4 / 256 each, all bit-exact |
| Prompt | `[1, 7, 42, 3]` |
| Generated tokens | `[83, 109, 104, 110]` |
| Cumulative descriptor publications | 4,020 |
| Final context cycles | 4,340,790 |
| Reset events / host intermediate words | 0 / 0 |
| VCS CPU time | 96.180 s |
| VCS | `V-2023.12-SP1_Full64` |

The final context cycle count is reported as observed for that context, not as a steady-state per-token latency. The execution is a hardware correctness qualification, not a throughput claim.

Raw compile/run/make logs, logits CSVs, result JSON, SHA256SUMS and run manifest are archived under `benchmark/gpt2_quality/results/round28_product_top/`.

### Deterministic package export audit

The selected checkpoint was re-exported through the repository's integer package exporter. All 45 named tensors matched in shape, dtype, and value, and the regenerated archive was byte-identical to the Product Top package. This establishes deterministic **checkpoint-to-package export**, not deterministic retraining from the corpus.

| Item | SHA-256 / result |
|---|---|
| FP32/QAT checkpoint | `8674782e974cdbb1f43743b00762d854d37e3808b3a2426d3180b36bd99d3130` |
| Original Product INT8 package | `9e330e56226d76aaf5c639975b30ae2612a1a965ec4c942cb9f93db86dc5a803` |
| Re-exported package | same SHA; archive bytes equal |
| Tensor comparison | 45/45 equal; zero tensor mismatches |
| Machine-readable evidence | `benchmark/gpt2_quality/results/round28_package_audit/reproducibility.json` |

Reproduction command (from this worktree root):

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/round28_package_repro_audit.py \
  --checkpoint benchmark/gpt2_quality/results/round27_extended_train/seed_20261223/qat_float.pt \
  --package benchmark/gpt2_quality/results/round27_extended_train/seed_20261223/product_int8.npz \
  --reexport /tmp/nmaforge_round28_reexport.npz \
  --report benchmark/gpt2_quality/results/round28_package_audit/reproducibility.json
```

## Reproduction

Environment: Python 3.12.13, NumPy 2.5.4, PyTorch 2.6.0+cpu, Transformers 4.48.3; VCS V-2023.12-SP1 Full64.

Paired quality audit:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/round28_paired_quality_audit.py \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --evidence benchmark/gpt2_quality/results/round27_extended_train \
  --out benchmark/gpt2_quality/results/round28_paired_audit
```

Product Top replay (from `dv/subsystem/top_smoke/sim`):

```bash
AI_H64_FOUR_LAYER_MODEL_NPZ=/tmp/nmaforge-v12-dualfinal-r28-gpt2/benchmark/gpt2_quality/results/round27_extended_train/seed_20261223/product_int8.npz \
AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_r28_gpt2_seed20261223_top \
AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
AI_H64_FOUR_LAYER_SEED=20261223 AI_H64_AUTOREGRESSIVE=1 VCS='vcs -licwait 1' \
make ai_h64_four_layer_top_argmax
```

The successful command exited 0. The archived `run_manifest.json` binds the command, run ID, source commit and model hash. The first invocation used an incorrect model path and did not qualify; only the corrected, successful invocation is included in the pass claim.

## Gate status

| Gate | Status | Evidence / open item |
|---|---|---|
| Corpus/data split audit | PASS | Disjoint source ranges, guards, fixed test-start hash, paired window bootstrap |
| Multi-seed quality comparison | PARTIAL | Three fixed seeds measured; Product INT8 CE/PPL remains worse than Bigram; small byte corpus/task limits generalization claims |
| Product integer package export reproducibility | PASS | Frozen `qat_float.pt` re-exported byte-for-byte; all 45 tensors match and NPZ SHA is unchanged |
| Full training-to-package reproducibility | PARTIAL | Frozen source checkpoint is identified; clean retraining was not repeated in this round |
| Four-layer Product Top logits | PASS | 4×256 logits bit-exact with independent integer Golden |
| Four-token autoregressive feedback | PASS | Real RTL logits → Host Argmax → next input, same Top instance; prefix-recompute mode |
| GPT-2 quality closure | PARTIAL | Not pretrained GPT-2; no credible quality margin over simple baseline |
| Product RTL changes | NONE | This track changed software evidence/audit artifacts only |

## Remaining work

Do not adjust Product RTL or its Golden based on these results. The next useful GPT work is to resolve the poor FP32/QAT generalization with a corpus-level, leakage-audited training/evaluation protocol and explain the Fake Quant divergence at operator level. Any new model must be selected on validation only, frozen before final test, and then rerun through the same Product Top contract. TinyNPU speedup is not claimed here.
