# NMAForge V1.2 Round 22 — Dual-Model Closure

## Overall disposition

**PARTIAL.** The GPT-2 candidate completed the requested four-layer Product Top logit/argmax feedback run and matched the independent INT8 reference. Its held-out quality remains below the same-window bigram baseline. The DeiT research workload completed the valid LayerNorm rows, then failed because the generator issued an illegal LayerNorm descriptor for padding row 197; final LayerNorm packing, QKV, and Attention did not complete. Both isolated branches passed the default Product Top smoke regression. Neither result is a full dual-model closure or a full DV sign-off.

No Product RTL or `main` was changed. The tracks remain separate; there was no merge.

## Branches and source identity

| Track | Branch | Round 22 commit | RTL/test base used for focused run | Status |
|---|---|---|---|---|
| GPT-2 | `research/nmaforge-v1.2-round21-gpt2` | `04b9098de87e6815f977e31479a4b0d23d37d4c5` | `540a3fb465f6997c29b24ab72489d4095aa7c5ea` | Product Top candidate PASS; quality PARTIAL |
| DeiT-Tiny | `research/nmaforge-v1.2-round21-deit` | `e64ead0b37c8774e3d73a55a650e770d70839e99` | `3fd0d480a042b03c919b2e89f7e241c1c9c5f032` | focused Encoder workload PARTIAL; compatibility smoke PASS |

The RTL baselines were unchanged during these runs. Round-specific scripts, manifests, reports, and evidence are committed on their respective branches. VCS version: `V-2023.12-SP1_Full64`.

## Track A — GPT-2 INT8 candidate

The candidate package is H64, four layers, four heads, FFN 256, byte vocabulary 256, context 16. Candidate weight/package SHA-256 values, the numeric profile, test-set definition, and frozen-vs-candidate comparison are recorded in [`NMAFORGE_V1_2_ROUND22_GPT2_QUALITY.md`](NMAFORGE_V1_2_ROUND22_GPT2_QUALITY.md) and `benchmark/gpt2_quality/results/round22/run_manifest.json`.

| Measurement | Frozen INT8 | Round 22 candidate | FP32 / baseline |
|---|---:|---:|---:|
| Held-out next-byte accuracy | 11.52% | 16.31% | FP32 37.40%; bigram 29.20% |
| Cross entropy | 6.774 nats | 4.099 nats | — |
| Perplexity | 874.97 | 60.27 | FP32/INT8 top-1 agreement: 26.95% |

The candidate improves over frozen INT8 by 4.79 percentage points and lowers CE by 2.675 nats, but remains 12.89 points below bigram and 21.09 points below FP32. Therefore quality recovery is not closed.

Product Top executed the candidate under `round21_residual_gelu_aligned`. Prompt `[1,7,42,3]` generated `[32,66,117,107]`. All four 256-element signed INT32 logit vectors and argmax decisions matched the independent INT8 reference exactly. The same simulation instance reported zero resets and no host-written hidden/intermediate tensors. Feedback used **prefix recomputation**, so this is not query-only incremental KV Decode. The run reported 4,020 descriptor publications and 4,338,360 extension cycles for three feedback replays; this excludes the initial prompt and does not include all Host/AXI work as a single Host-to-Host latency. No full-session latency is claimed.

Run ID: `round22-gpt2-h64-four-layer-ar-seed20261121`; seed: `20261121`. Product Top and smoke compile/run logs are compressed under `benchmark/gpt2_quality/results/round22/logs/`. The independent logits record is `product_top_independent_logits.json`.

Compatibility smoke passed with 4 random cases, `AI_SEED=12345`; VCS KDB elaboration reported 0 errors and 0 warnings. Reproduction command:

```bash
cd dv/subsystem/top_smoke/sim
make ai_smoke VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

## Track B — DeiT-Tiny LayerNorm/QKV preparation

The pinned official checkpoint identity and hashes are in `benchmark/deit/round22/evidence/round22_run_status.json`. The workload started from a verified Product Top patch-embedding readback: all 9,984 Matrix-A words matched the existing embedding Golden.

The generated 256 KiB four-bank plan used 16,384 words/bank, 197 valid token rows, and 208 physical rows. Its static allocation high-water mark was 219,904 data bytes plus a 40,960-byte queue reservation. The planned stream had 249 descriptors, 146 late-DMA events, and 36 QKV tiles. These are plan counts, not evidence that later work executed.

The directed VCS run completed the 197 valid LayerNorm row descriptors. Its first failure was descriptor 209, `deit_ln_token_197`, task ID `0x000071d1`, completion `0x00000072` (`CPL_ERROR` / `ERR_DESC`). The generator requested LayerNorm for padding row 197; the descriptor validator correctly permits only source rows 0–196. The final pack and full memory Golden comparison were not reached. QKV, the 16-query block, three-head QK/Softmax/AV, and Encoder Layer 0 were not run. Do not report full 197-row LayerNorm Golden PASS based only on successful row completions.

Run ID: `round22-deit-197-ln-qkv-first-query-block-seed20261117`; seed: `20261117`. Compile, focused run, console logs, generated plan, memory image, DMA payload, and Golden are archived under `benchmark/deit/round22/evidence/`. The focused log includes the streamed completion mismatch; its process exit code alone is not a PASS indicator.

The separate default compatibility smoke passed in this branch with 4 random cases, `AI_SEED=12345`, `ntb_random_seed=1794901328`; KDB elaboration reported 0 errors and 0 warnings. Full logs are archived as `deit_default_smoke_compile.log.gz` and `deit_default_smoke_run.log.gz`.

## Gate summary

| Gate | Result | Evidence-based disposition |
|---|---|---|
| GPT candidate package frozen | PASS | Weight/package hashes, config, and held-out set recorded |
| GPT candidate Product Top logits / argmax | PASS | Four contexts bit-exact against independent INT8 reference |
| GPT quality above bigram | FAIL | 16.31% candidate vs 29.20% same-window bigram |
| GPT query-only persistent KV Decode | NOT RUN | Candidate used prefix recomputation |
| DeiT verified embedding input | PASS | 9,984 Product Top readback words matched prior Golden |
| DeiT valid LayerNorm row completions | PASS (scoped) | Rows 0–196 completed |
| DeiT full LayerNorm packed output Golden | PARTIAL | Padding descriptor error prevented final pack/compare |
| DeiT QKV and attention | NOT RUN | Focused stream stopped before QKV |
| Default top smoke on both branches | PASS | VCS smoke logs preserved separately |
| Full DeiT Encoder Layer 0 | NOT RUN | First blocked at invalid padding-row descriptor |

## Decision

Do not start twelve-layer DeiT integration. First correct the workload generation so padding rows do not receive LayerNorm descriptors, initialize the final padded pack lanes through a legal path, and compare the complete packed tensor against Golden. Then reach and validate the QKV/attention consumer path. GPT-2 has a new candidate Product Top pass, but language-quality recovery remains open; continue only after addressing the quantization/quality gap. The two branches are pushed independently and remain unmerged.
