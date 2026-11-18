# NMAForge v1.2 Round 27 — GPT-2 Track Results

## Disposition

**Product Top functional replay: PASS. Model quality closure: PARTIAL / NOT MET.**

The selected H64, four-layer byte decoder ran on Product Top and produced four autoregressive feedback tokens with all 256 logits at each of four contexts bit-exact against the independent Product integer reference. The experiment does **not** establish a useful language model: mean Product INT8 next-byte accuracy across three fixed seeds was 25.98%, below the train-only bigram baseline of 26.89%. This is a trained Tiny Shakespeare byte model using the H64-compatible decoder, not imported pretrained GPT-2 weights.

## Frozen experiment

| Item | Value |
|---|---|
| Product source commit during run | `901dd1d287413a4b8c51bd4f99c403842d6c30db` |
| Experiment script SHA-256 | `712868fcdbcc097a841555ed4054b251439ade2545a5c93bb24ccd2ca588dc92` |
| Corpus SHA-256 | `86c4e6aa9db7c042ec79f339dcb96d42b0075e16b8fc2e86bf0ca57e2dc565ed` |
| Test-window-start SHA-256 | `36c21c93a1c98515c4f8a6209fe016688babe19d991a3d0ad7af4573419376a2` |
| Split | Contiguous corpus ranges 70/15/15; context-plus-target guard at each boundary |
| Evaluation | 512 fixed windows × 8 scored positions = 4,096 predictions per seed |
| Seeds | `20261211`, `20261212`, `20261213` |
| Configuration | H64 / 4 layers / 4 heads / FFN256; FP32 2,000 steps, Product-aligned QAT 800 steps, batch 8 |
| VCS | `V-2023.12-SP1_Full64` |
| Python | 3.12.13; NumPy 2.5.4; PyTorch 2.6.0+cpu |

The train, validation, and test windows are sampled only from their own disjoint raw-corpus intervals. The test set was evaluated once after all three candidate packages had been frozen. Test windows may overlap each other within the held-out interval; no window crosses a split boundary.

## Held-out quality

Values below are mean ± sample standard deviation across the three training seeds. Accuracy is percentage; CE is nats and PPL is `exp(CE)`. Bigram is fitted on the training interval only and is identical for all seeds.

| Evaluation path | Next-byte accuracy | CE | PPL | FP32 top-1 agreement |
|---|---:|---:|---:|---:|
| Original FP32 | 32.54% ± 0.59 pp | 2.3466 ± 0.0207 | 10.45 ± 0.22 | — |
| QAT-updated float | 24.40% ± 1.59 pp | 2.7785 ± 0.2080 | 16.34 ± 3.57 | 42.28% ± 8.68 pp |
| Fake-quant evaluation | 25.97% ± 0.42 pp | 2.6997 ± 0.0088 | 14.88 ± 0.13 | 31.71% ± 2.43 pp* |
| Product INT8 reference | 25.98% ± 0.35 pp | 2.7047 ± 0.0102 | 14.95 ± 0.15 | 50.57% ± 2.17 pp |
| Train-only bigram | 26.89% | 2.5378 | 12.65 | — |

`*` Fake-quant agreement is measured against the QAT-float logits, whereas Product INT8 agreement is against the original FP32 logits, matching the experiment’s recorded fields; do not compare these two agreement values as if they shared a reference.

The Product INT8 mean is 0.91 percentage points below bigram and 6.56 points below original FP32. The FP32 model itself is above bigram on this split, but QAT-updated float quality is substantially worse and varies more across seeds. That points to a training/QAT objective or implementation problem still requiring investigation; it is not evidence that RTL arithmetic is wrong because Product INT8 is bit-exact against the independent integer contract.

## Product Top qualification

Selected by validation Product INT8 accuracy (seed `20261212`; validation accuracy 26.9531%), not by test performance. The frozen package SHA-256 is `792c3b196ce76dc86d5ed73a7922966f4668857df92c8f582a9970568768781a`. Its source FP32 checkpoint SHA-256 is `ccab9ece65c7acdd5e9727acef20cf849056fa32a254c65b61482b4d2fb22955`; QAT checkpoint SHA-256 is `e937c52eb9ed8dedcdc6049a01b464ded88345481e9810191e12bc28d1e9497e`.

Run `R27-GPT2-H64-CLEAN-SPLIT-SEED20261212-TOP` used prompt `[1,7,42,3]`; RTL logits selected tokens `[101,104,10,97]`. For all four feedback contexts, the 256 RTL INT32 logits matched the independent integer Golden. VCS reported four-layer Top PASS, Final LN/LM Head PASS, and `reset_events=0`, `host_intermediate_words=0`. The runtime mode is **prefix recompute**: each token recomputes the current prefix in the same Top session. This proves autoregressive host feedback and same-session execution, but is not query-only incremental KV Decode and must not be quoted as its latency.

The captured run reported 4,020 total descriptor publications and 4,340,826 extension cycles for the four generated tokens. That interval is the testbench’s prefix-recompute extension counter; it is not a complete host-to-host throughput claim. Per-context logit hashes and the exact PASS markers are in [`round27_final_summary.json`](../../benchmark/gpt2_quality/results/round27_long_train/round27_final_summary.json), [`autoregressive_result.json`](../../benchmark/gpt2_quality/results/round27_long_train/top_run/autoregressive_result.json), and the archived VCS logs.

## Reproduction

From the repository root, with the same Python/VCS environment and the tracked Tiny Shakespeare corpus:

```bash
python -u benchmark/gpt2_quality/round27_clean_split_experiment.py \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --out-dir benchmark/gpt2_quality/results/round27_long_train \
  --seeds 20261211 20261212 20261213 --fp-steps 2000 --qat-steps 800 --batch 8 \
  --validation-windows 128 --test-windows 512

cd dv/subsystem/top_smoke/sim
VCS_HOME=/tmp/nmaforge_vcs_overlay_round27 make ai_h64_four_layer_top_argmax \
  VCS=/usr/local/bin/vcs \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_H64_FOUR_LAYER_MODEL_NPZ=../../../../benchmark/gpt2_quality/results/round27_long_train/seed_20261212/product_int8.npz \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_round27_gpt2_long_candidate_top \
  AI_H64_FOUR_LAYER_SEED=20261212 AI_H64_AUTOREGRESSIVE=1
```

The retained files under `results/round27_long_train/top_run/` are the exact VCS compile/run logs and model result/plan used here. The run directory contains no compiled simulator database.

## Open issues

- Model quality does not exceed the bigram baseline; the selected package is a functional deployment candidate, not a quality-qualified language model.
- The training script’s `qat_float` path has substantial cross-seed variance and a low mean; inspect fake-quant training semantics before further hardware changes.
- No TinyNPU result is claimed for this trained byte model.
- Persistent KV-only Decode and full host-to-host latency remain unmeasured in this run.

No Product RTL was changed for this track.

## Round 27 extended, validation-selected candidate

To test whether the modest below-bigram result was seed/under-training noise,
the same script was run with three new fixed seeds, 4,000 FP32 steps, and 1,200
Product-aligned QAT steps. The corpus, guarded contiguous 70/15/15 split,
validation protocol, and held-out test windows were fixed before training. The
three candidates were selected/evaluated on the same validation/test
definitions; seed `20261223` was chosen by **validation Product INT8 accuracy**
before examining its test metrics for deployment qualification.

| Path | Accuracy, mean ± sample SD | CE | PPL | FP32 top-1 agreement |
|---|---:|---:|---:|---:|
| FP32 | 35.693% ± 0.228 pp | 2.2174 | 9.183 | — |
| QAT-updated float | 29.846% ± 1.597 pp | 2.5045 | 12.240 | 54.42% ± 6.89 pp |
| Fake Quant | 27.824% ± 0.214 pp | 2.6223 | 13.768 | 39.52% ± 2.38 pp* |
| Product INT8 software reference | 27.897% ± 0.208 pp | 2.6194 | 13.729 | 46.85% ± 2.63 pp |
| Train-only bigram | 26.892% | 2.5378 | 12.652 | — |

The candidate improves Product INT8 accuracy over bigram by 1.005 pp, but its
cross-entropy is 0.0816 nats higher and its perplexity is 1.077 higher. This is
a measurable accuracy improvement, not model-quality closure. FP32 remains
7.80 pp more accurate than Product INT8, and QAT Float trails FP32 by 5.85 pp.
The sizable QAT Float drop is present before integer export, so the primary
remaining issue is training/QAT quality, not a demonstrated Product RTL
Logits mismatch. `*` Fake-Quant agreement uses the QAT-float reference; other
agreement numbers use the FP32 reference.

Candidate package SHA-256:
`9e330e56226d76aaf5c639975b30ae2612a1a965ec4c942cb9f93db86dc5a803`.
Its source FP32 checkpoint SHA-256 is
`6d71d0a4649f276a74d42834f94f01812c4cf1e6d64bc6562f1ab017361c0021`; QAT
checkpoint SHA-256 is
`8674782e974cdbb1f43743b00762d854d37e3808b3a2426d3180b36bd99d3130`.
The training completed in 265.95 seconds on the recorded local CPU/Python
environment.

The selected package was then run through four-layer Product Top autoregressive
feedback, on source SHA `901dd1d287413a4b8c51bd4f99c403842d6c30db`, with VCS
`V-2023.12-SP1_Full64`. Run ID:
`R27-GPT2-H64-EXTENDED-CLEAN-SPLIT-SEED20261223-TOP`.
All four contexts emitted 256 Product Top INT32 logits and matched the
independent integer Golden bit-for-bit. Host Argmax produced
`[83, 109, 104, 110]` from prompt `[1, 7, 42, 3]`; the Top instance had no reset
between feedback contexts and did not receive host-written intermediate
tensors. This remains prefix-recompute mode, not query-only KV decode.
The recorded simulation reported 4,020 descriptor publications and
4,340,790 prefix-recompute extension cycles. This is not full host-to-host
latency.

| Evidence | SHA-256 |
|---|---|
| Training console log | recorded in `round27_extended_evidence_manifest.json` |
| VCS compile log | `c1b86aa2756645fc8b33d20b5130e64df88318e1739a45845f0338eeb123cef2` |
| VCS run log | `998078f3cb5b341b70d758319b0439e6c417f4bda161d3a5c08ce950770be5fa` |
| Top result JSON | `78793046fe4b9eef1d27d504eb8f16b8a786529d2395341301183fe4f08d0ffb` |

The complete run evidence is retained losslessly; VCS and training console logs are stored as `.log.gz` to preserve raw trailing whitespace. The recorded log SHA-256 values are computed over the decompressed original bytes. Per-context logit CSVs, three seed checkpoints and
packages, metric CSV, and a recomputable artifact manifest are stored under
`benchmark/gpt2_quality/results/round27_extended_train/`. Run
`/tmp/nmaforge_deit_round17_venv/bin/python benchmark/gpt2_quality/verify_round27_extended_evidence.py`
from the repository root to verify the hashes, validation-selected seed,
four 256-logit Golden vectors, and run markers. The raw training command was:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python -u benchmark/gpt2_quality/round27_clean_split_experiment.py \
  --corpus benchmark/gpt2_quality/results/round25/corpus/tinyshakespeare.txt \
  --out-dir benchmark/gpt2_quality/results/round27_extended_train \
  --seeds 20261221 20261222 20261223 --fp-steps 4000 --qat-steps 1200 --batch 8 \
  --validation-windows 128 --test-windows 512
```

The selected package Product Top command was:

```bash
cd dv/subsystem/top_smoke/sim
VCS_HOME=/tmp/nmaforge_vcs_overlay_round27 make ai_h64_four_layer_top_argmax \
  VCS=/usr/local/bin/vcs \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_H64_FOUR_LAYER_MODEL_NPZ=../../../../benchmark/gpt2_quality/results/round27_extended_train/seed_20261223/product_int8.npz \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_round27_gpt2_extended_seed20261223_top \
  AI_H64_FOUR_LAYER_SEED=20261223 AI_H64_AUTOREGRESSIVE=1
```

`make` exited 0, and the independent check printed
`H64_AUTOREGRESSIVE_GOLDEN_PASS` with all four contexts bit-exact.

The new result changes the quality disposition from `below bigram` to `accuracy
slightly above bigram`, but CE/PPL and seed variance show that it is not a
stable language-model deployment-quality closure. The model is still a
Tiny-Shakespeare-trained byte decoder, not pretrained GPT-2.
