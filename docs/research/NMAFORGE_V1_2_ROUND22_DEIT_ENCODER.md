# NMAForge V1.2 Round 22 — DeiT Encoder Integration

## Disposition

**PARTIAL — the workload reached the final five valid LayerNorm rows, then failed because it issued LayerNorm on a padded row. The 197-row output Golden was not completed, QKV was not reached, and no Attention path ran.** No RTL was changed. This report preserves the failing transaction and generated workload rather than treating a successful completion status as a Golden pass.

The isolated worktree is `research/nmaforge-v1.2-round21-deit`, based on `3fd0d480a042b03c919b2e89f7e241c1c9c5f032`. The pinned checkpoint is `facebook/deit-tiny-patch16-224`; this test used the same deterministic synthetic fixture image from the prior Product Top embedding workload, not a classification-quality test image.

## Gate results

| Gate | Result | Evidence |
|---|---|---|
| Existing 197×192 Product Top Patch Embedding | PASS (preserved Round 21 evidence) | 9,984 Matrix-A words read from Product Top and checked against the pinned embedding Golden before this workload was built. |
| Round 22 all-row LayerNorm workload | PARTIAL | Valid rows 0–196 received successful completions. The run stopped at padded row 197; the final packed output / complete memory Golden comparison was not reached. |
| LN output packing and Q/K/V projections | NOT RUN to completion | Descriptor stream was aborted before the final LN tile pack and before all 36 QKV GEMM tiles. |
| Three-head QK → non-causal Softmax(197) → AV | NOT RUN | No Attention descriptor was in this bounded workload. |
| Full Encoder Layer 0 | NOT RUN | Residual, LN2, FFN, GELU and output projection were not built/executed. |

## First failure and cause

The first failing completion was descriptor index 209, task ID `0x000071d1`, named `deit_ln_token_197`, with completion status `0x00000072` (`CPL_ERROR` / `ERR_DESC`). The generator issued LayerNorm for padded token row 197 even though the descriptor validator accepts only valid source rows 0–196. This is a workload-generation error, and the validator correctly rejected it.

The generated plan includes three zero-padding rows to make the 197-token final tile regular. The next bounded correction should avoid LayerNorm descriptors for those padding rows, initialize their final pack lanes to zero using a legal initialization/packing path, and then compare the final pack and QKV tensors against Golden. That correction was not attempted again in this round; the recorded run is the third targeted run and is the final attempt for this task.

The VCS testbench did emit `$fatal` on the completion mismatch. The saved simulation process exit status was 0, so disposition is based on the semantic failure in the log, not the shell status.

## Memory and workload evidence

The staged input was a verified Product Top embedding readback. The generated plan used four banks, 16,384 words per bank (256 KiB), 197 valid and 208 physical token rows, and a first 16-query projection block. Static interval checking reports a data high-water mark of 219,904 bytes plus 40,960 bytes of CMDQ/CPLQ reservation, within 262,144 bytes. Planned work comprised 249 descriptors, 146 late-DMA events, 36 QKV GEMM tiles, and 18,816 expected Golden words. These planning values do not imply execution of the later descriptors.

The first 16-query QKV projections represent 1,769,472 useful MACs in the generated workload; none may be reported as executed work because the run failed before reaching QKV. There is no Round 22 QKV performance or FP32 error result to report. The manifest's LayerNorm FP32 error (`MAE=0.14819`, `RMSE=0.17011`, max absolute error `0.60711`) is a software/reference estimate for the fixture image, not a Product Top output-accuracy result.

## Reproduction

Checkpoint SHA-256 values are recorded in `benchmark/deit/round22/evidence/round22_run_status.json`. The complete base embedding manifest, expected Golden and Product Top readback are archived under `benchmark/deit/round22/evidence/inputs/`. The failed run's DMA payload, plan, model memory image and Golden are archived under `benchmark/deit/round22/evidence/workload/`.

Workload generation:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/deit/round22/generate_deit_ln197_qkv_block.py \
  --model-dir /tmp/nmaforge_deit_round17 \
  --base-manifest benchmark/deit/round22/evidence/inputs/embedding_base_manifest.json \
  --base-golden benchmark/deit/round22/evidence/inputs/embedding_base_golden.memh \
  --embedding-dump benchmark/deit/round22/evidence/inputs/product_embedding_readback.log \
  --out-dir /tmp/round22_deit_ln197_fix3/workload
```

Product Top run (using the existing Round 21 compiled Top testbench executable):

```bash
/tmp/nmaforge_v12_r21_deit_lnrow_fix2/simv +ntb_random_seed=20261117 \
  +AI_RANDOM_CASES=0 +AI_SEED=20261117 +ACLK_PERIOD_NS=4 \
  +AI_REPRESENTATIVE_MODEL +AI_REPRESENTATIVE_LATE_DMA +AI_DEIT_R21_LN_DEBUG \
  +AI_REPRESENTATIVE_DMA_PAYLOAD=/tmp/round22_deit_ln197_fix3/workload/dma_payload.memh \
  +AI_REPRESENTATIVE_DMA_PLAN=/tmp/round22_deit_ln197_fix3/workload/late_dma_plan.memh \
  +AI_REPRESENTATIVE_MEMORY=/tmp/round22_deit_ln197_fix3/workload/model_memory.memh \
  +AI_REPRESENTATIVE_GOLDEN=/tmp/round22_deit_ln197_fix3/workload/model_golden.memh \
  +AI_REPRESENTATIVE_DESC_BASE=221184 +AI_REPRESENTATIVE_CPL_BASE=253952 \
  +AI_REPRESENTATIVE_DESC_COUNT=249 +AI_REPRESENTATIVE_QUEUE_SIZE=512 \
  +AI_REPRESENTATIVE_USEFUL_MACS=1769472 \
  -l /tmp/round22_deit_ln197_fix3/run.log
```

VCS was `V-2023.12-SP1_Full64`; the compiled testbench's full compile log and this run's full log/console are preserved in compressed form. Compile/elaboration completed; the test itself failed at the descriptor above. No new Product RTL or ABI behavior was introduced.

## Independent compatibility regression

After archiving the focused failure, the unchanged Product RTL also passed the default top smoke in this worktree:
`cd dv/subsystem/top_smoke/sim && make ai_smoke VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`.
VCS KDB elaboration reported 0 errors / 0 warnings; the run reported `TEST PASS` for 4 random cases (`AI_SEED=12345`, `ntb_random_seed=1794901328`). Full compile and run logs are archived as `evidence/logs/deit_default_smoke_compile.log.gz` and `evidence/logs/deit_default_smoke_run.log.gz`. This compatibility smoke does not change the focused DeiT result above: LayerNorm row 197 remains the first failure, with QKV and Attention not run.
