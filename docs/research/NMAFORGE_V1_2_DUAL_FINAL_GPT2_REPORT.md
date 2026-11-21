# NMAForge-V1.2 Dual-Model Final Integration — GPT-2 Track

**Disposition: Product Top functional PASS; model-quality closure PARTIAL.** This fresh run replays the frozen Round 25 H64 four-layer INT8 package on Product Top and completes four host-feedback Argmax steps in one unreset Top instance. It does not close the language-quality gap or establish a trained, well-generalizing language model.

## Frozen source and model

| Item | Value |
|---|---|
| Research branch / source SHA | `research/nmaforge-v1.2-dual-final-gpt2` / `901dd1d287413a4b8c51bd4f99c403842d6c30db` |
| Product RTL tree at source | `8798decc60fe257ef685a0b1c7e8814816e1d4de` |
| Product package | `benchmark/gpt2_quality/results/round25/seed_20261125/round24_integer_qat_model.npz` |
| Package SHA-256 | `fa66d2ecd6709c0a49e5c23d6346de22adfbf2f0809f182e581fa63cbcb9a54b` |
| Canonical integer model SHA-256 | `4f9bf1070ed14827ef99510d47eccde6f6dc218c2f7b9b677394f41437adf8fd` |
| Model scope | H64, four-layer byte-level Tiny-Shakespeare-derived model; not original pretrained GPT-2 |
| Seed / prompt | `20261116` / `[1, 7, 42, 3]` |
| VCS | `V-2023.12-SP1_Full64` |
| Clock used for testbench timing | 10 ns period (100 MHz assumption; not a silicon frequency claim) |
| SPAD / queues | 128 KiB, 4 banks × 8,192 words; 512-entry configured queues |

No product RTL or numeric contract changed in this replay.

## Fresh Product Top run — PASS

Exact command, from `dv/subsystem/top_smoke/sim`:

```bash
AI_H64_FOUR_LAYER_MODEL_NPZ=/tmp/nmaforge-v12-dual-final-gpt2/benchmark/gpt2_quality/results/round25/seed_20261125/round24_integer_qat_model.npz \
AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_dualfinal_gpt2_top_20261118 \
AI_H64_AUTOREGRESSIVE=1 VCS='vcs -licwait 1' \
make ai_h64_four_layer_top_argmax
```

The first invocation used a relative package path that the Make target resolves from its simulation directory and stopped before simulation setup. It was rerun with the absolute path above and passed; this was a command-path issue, not an RTL failure.

| Check | Result |
|---|---|
| Four-layer Product Top forward | PASS; 933 descriptors; 1,049,190 post-layer cycles |
| Logits | Four contexts × 256 signed INT32 values; every context bit-exact to independent integer Golden |
| Autoregressive feedback | PASS; generated tokens `[73, 73, 115, 111]` |
| Top instance / reset | Same Product Top instance; `reset_events=0` |
| Host intermediate tensor writes | 0; host reads RTL logits, runs signed INT32 Argmax (lowest token ID wins ties), and supplies token embedding/position inputs |
| Decode mode | Prefix recompute; not query-only incremental decode |
| Publications | 4,020 cumulative descriptor publications across the four feedback contexts |

Per-context Product cycles are reported as the run's post-layer/context counters; the extension counter is cumulative from contexts 1–3:

| Feedback result | Context command cycles | Cumulative extension cycles |
|---|---:|---:|
| Prompt logits → token 73 | 1,049,190 | 0 |
| Context including token 73 → token 73 | 1,414,188 | 1,414,188 |
| Context including two generated tokens → token 115 | 1,446,780 | 2,860,968 |
| Context including three generated tokens → token 111 | 1,479,804 | 4,340,772 |

Summing the four context executions gives 5,389,962 command/context cycles for this prefix-recompute feedback sequence. This is not a persistent query-only decode cost. The full VCS simulation time corresponds to 6,123,246 testbench clock cycles at the configured 10 ns period and includes setup, initialization and testbench work; it is not a Host-to-Host system latency measurement.

Logit SHA-256 values (little-endian signed INT32):

| Context | SHA-256 |
|---|---|
| 0 | `7143fe6a08599e02cd8c70349b24c5cec8b48354c5410a659efb5aa8e638eaec` |
| 1 | `098de298678dcf47751aa0b66355ae8eae5cf4de52624815c84428b056eea4ce` |
| 2 | `3d62a03bc31e3a605d4f7eff959e1bf4e43332c60c6a45d3a1e78ca09072d3cb` |
| 3 | `86eec45220f6afbc0b49a90e82356ccd05271434ed154c776b27d6054e348d73` |

The initial preflight with a relative path did not compile/run the RTL; the absolute-path rerun returned PASS. No RTL code was changed, so no separate legacy smoke rerun was necessary for this evidence-only change.

## Model quality — PARTIAL

Round 26 used a fixed 512-target software evaluation sample, seed `20261128`, with the Product-aligned independent integer reference. The data are useful for comparing quantization candidates, but they are not sufficient to qualify general language quality.

| Candidate | Accuracy | Cross-entropy | Perplexity |
|---|---:|---:|---:|
| Source FP32 | 23.242% | 2.6683 | 14.41 |
| QAT-updated Float, mean of 3 seeds | 22.721% | 2.7168 | 15.13 |
| Product-contract INT8, mean of 3 seeds | 29.362% ± 0.332 pp | 2.4862 | 12.02 ± 0.23 |
| Same-window Bigram | 27.539% | — | — |

INT8 exceeds this same-window Bigram result by 1.82 percentage points on average. FP32 and QAT Float are below Bigram. The earlier Validation sample was drawn inside the training/development corpus partition, weakening model selection. The fresh RTL replay proves the selected package's numerical/feedback behavior only; it does not repair those data and model-quality limitations. No new clean split or retraining was performed in this round.

## Evidence archive and reproduction

Fresh evidence is under `benchmark/gpt2_quality/results/round27/product_top/`:

- `compile.log.gz`, `run.log.gz` (lossless compressed raw VCS logs)
- `autoregressive_result.json`, `autoregressive_plan.json`
- `rtl_logits_context0.csv` … `rtl_logits_context3.csv`
- `context0/model_golden.memh` … `context3/model_golden.memh`

Uncompressed raw log hashes:

| Artifact | SHA-256 |
|---|---|
| Compile log | `1409c63b580f0f3c3fc394f82ffad53dcfc79c8e296e0f5150a0dc109298c204` |
| Run log | `c2b7373d0faeb9e6de5c8201571945992f46e5b192e23d86e3b81f496dfbcb71` |
| Autoregressive result JSON | `cf260aafcc92ae85868517defc8922c897724e4a4ccdcdb6e8e82b037a8cd347` |
| Context 0 Golden | `fbde54d3e936f18da324839d827f750bedfc8ceb30208358de16970e277dea43` |

The compile log contains the pre-existing `Warning-[LOOP-REROLL-ENABLED]` diagnostic. The run log contains `H64_FOUR_LAYER_TOP_PASS` and `H64_AUTOREGRESSIVE_SEQUENCE_PASS`, with zero reset events and zero host intermediate tensor writes. Use the command above to replay; the archived logs preserve the original compile/run evidence and its Make result.

## Gate disposition

| Gate | Status | Reason |
|---|---|---|
| Frozen INT8 package Product Top forward/logits | PASS | Fresh four-layer Top; four 256-logit contexts bit-exact |
| Four-token host-feedback loop | PASS | Actual RTL logits → host Argmax → next input; same unreset Top |
| GPT-2 language-model quality | PARTIAL | Tiny byte-level model; small fixed sample; FP32/QAT Float below Bigram; validation overlap issue remains |
| Full GPT-2 deployment claim | PARTIAL | Functional loop is a GPT-2-like derivative, not original pretrained GPT-2 or quality-qualified language deployment |
| TinyNPU performance comparison | NOT RUN | No same model/numeric and timing endpoint benchmark in this round |

The actionable quality work is to establish corpus-disjoint train/validation/test splits, strengthen the H64 FP32 model, and retrain/QAT with the Product integer contract. Do this before changing RTL requantization. Preserve this exact Product Top package replay as the functional regression.
