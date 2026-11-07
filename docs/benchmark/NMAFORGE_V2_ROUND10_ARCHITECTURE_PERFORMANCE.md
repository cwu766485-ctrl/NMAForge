# NMAForge v2 Round 10 — Architecture & Performance Decision

**Disposition: `PARTIAL`**
**Reviewed source HEAD:** `1cd1bde4d82c457d445f97a7817fc22d407b528b`
**Product RTL/software/test code snapshot:** `13f94abf59c3dbea833ad4bbe227ef5cab4df503`
**TinyNPU reference:** `8216c22b762011aa20c05fc2768423fd12dda59d`
**Seed:** `20261107`; trained CNN replay date: `2026-11-08`
**Tools:** VCS `V-2023.12-SP1_Full64`; Verilator `5.052 2026-09-05`; Python `3.12.13`; NumPy `2.4.6`; ONNX `1.17.0`; scikit-learn `1.9.1`; GCC `8.5`.

No product RTL, mapper, software, or testbench source changed in this round. The checked-in product/test tree matches the Round 9 tested tree at `13f94ab`; Round 10 adds fresh benchmark data and a scope decision. ASIC/PPA and full DV closure were not run, as requested.

## Decision summary

| Round 10 question | Result |
|---|---|
| Can the current mapper execute H=16, 2-head, 8-token Transformer? | **BLOCKED:** its trained-model contract requires 4×4 INT8 matrices and a 4-symbol, one-head manifest. The H=16 mapper preflight failed before Top simulation; no H=16 quality or timing result exists. |
| Did LayerNorm/Softmax changes help a representative Transformer? | **Not established.** Reused H=4 toy evidence shows cycles improved, but H=16 is unsupported. No further SFU RTL change was made. |
| Is a ≥100K useful-MAC multi-layer CNN measured? | **No (`NOT_RUN`).** Existing model paths are 1,872-MAC mini CNN and 2,736-MAC/image Digits CNN. Dataset totals are not one inference. |
| Did the CNN dataflow ablation preserve outputs? | **PASS for both small models.** Exact intermediates and outputs; Digits classification stayed 384/396 (96.97%) in all three modes. |
| Is large-model Matrix/DMA overlap proven? | **No.** A small three-tile probe from Round 9 passed; the Round 8 four-mismatch probe has no recovered exact failure archive. No large CNN overlap result was run. |
| Does NMAForge beat TinyNPU at a matched system endpoint? | **Not proven.** GEMM/GEMV use NMA controller+behavioral-SPAD versus Tiny direct-array RTL plus a separately modeled memory schedule. CNN graph and Top/CMDQ windows also differ. |

The evidence supports keeping the current RTL frozen until a real representative model path exists. The next useful work, if authorized later, is a bounded H=16 mapper/model extension and a ≥100K-MAC CNN lowering flow; current data does not justify speculative SFU RTL changes or a system-level TinyNPU speedup claim.

## Phase status

| Phase | Status | Evidence boundary |
|---|---|---|
| 0A H=16 Transformer | `BLOCKED_MAPPER_SUPPORT` | Preflight error, no Top execution or quality result |
| 0B ≥100K-MAC CNN | `NOT_RUN` | No current mapper/Top workload meets this per-inference size |
| 1 H=16 SFU optimization | `NOT_RUN` | No H=16 profile; H=4 reuse only, no new RTL |
| 2 CNN dataflow | `PASS_SMALL_MODELS / PARTIAL_SCOPE` | 396 Digits inputs plus one mini-CNN input; all exact Goldens, no large CNN profile |
| 3 Matrix/DMA overlap | `PARTIAL` | Small prior probe passed; no large-model result; old four-word mismatch archive unavailable |
| 4 TinyNPU comparison | `PASS_MATRIX_AND_MINI_FUNCTION / NO_MATCHED_SYSTEM_SPEEDUP` | Clean pinned rebuild, 3 GEMM + 4 GEMV Goldens and mini-CNN Golden; endpoints remain different |
| PPA/full DV | `NOT_RUN_BY_SCOPE` | Explicitly outside Round 10 |

## Transformer

### H=16 preflight

Requested target was hidden=16, two heads, one layer, sequence length 8, INT8. The existing `sw/tools/cimforge_mapper.py` and `sw/tools/train_transformer_micro.py` support hidden=4, one head, four-symbol task data, and six 4×4 matrices. A synthetic H=16 model JSON was passed to the current mapper. It stopped with:

```text
ValueError: trained model wq must be a 4x4 INT8 matrix
```

The exact preflight command was:

```sh
/tmp/nmaforge_round10_venv/bin/python sw/tools/cimforge_mapper.py \
  --svh /tmp/nmaforge_round10_h16_preflight.svh \
  --manifest /tmp/nmaforge_round10_h16_manifest.json \
  --model-json /tmp/nmaforge_round10_h16_model_preflight.json
```

Run status is `BLOCKED_MAPPER_SUPPORT`; no descriptors were emitted and no Top run was attempted. Therefore H=16 Prefill/Decode cycles, SFU breakdown, KV correctness, model quality, and Host fallback are `NOT_RUN`. No H=4 values are relabeled as H=16.

### Reused H=4 evidence (context only)

The product and test sources are unchanged from the Round 9 tested tree, so its H=4 result is reusable but is not a new Round 10 run. Model SHA-256 `001550dbadb816e66f737f5f6cba0819f51821c71a78d84861d62dc80dd8511f`, seed `20261107`, 86 descriptors, 640 useful MACs, and 60 intermediate/final tensors plus KV images bit-exact. The model is a four-symbol cyclic task: train 16/16, held-out 690/1008, prefill task 4/4 and decode task 1/1; it is not a pretrained or representative language model.

| Measurement | Prior H=4 exact-mode baseline | Prior H=4 optimized path | Difference |
|---|---:|---:|---:|
| Decode | 5,715 cyc | 5,110 cyc | −605 cyc (−10.59%, same Top endpoint) |
| Prefill | 5,682 cyc | 5,259 cyc | −423 cyc |
| Decode LayerNorm | 2,631 cyc | 2,503 cyc | −128 cyc |
| Decode Softmax | 1,303 cyc | 826 cyc | −477 cyc |

Those changes were measured on H=4 only. There is no evidence that the same optimization improves H=16. Round 10 made no SFU RTL changes.

## CNN model-level dataflow ablation

Fresh VCS Top runs used the same checked-in trained INT8 weights, all 396 held-out samples, seed `20261107`, and independent per-sample intermediate/logit Goldens. Model SHA-256 is `ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`; test-set SHA-256 is `cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`. Each run passed 396/396 exact Golden checks and classified 384/396 samples (96.9697%). The model performs 2,736 useful MACs per image.

| Mode | CMDQ cycles/image | Testbench layout cycles | Accounted interval | SPAD read/write bytes | Host layout read/write bytes | Useful MAC/CMDQ cycle |
|---|---:|---:|---:|---:|---:|---:|
| Legacy | 3,193 | 1,080 | 4,273 | 6,048 / 1,920 | 144 / 576 | 0.857 |
| Fused Requant, native layout | 2,712 | 1,080 | 3,792 | 5,472 / 1,344 | 144 / 576 | 1.009 |
| Fused Requant + Linear-Row | 2,712 | 0 | 2,712 | 5,472 / 1,776 | 0 / 0 | 1.009 |

Fused Requant reduces measured CMDQ cycles by 481/image (15.06%) versus Legacy. Linear-Row keeps compute cycles unchanged and removes 1,080 **testbench-accounted** layout cycles; these are simulated transaction accounting, not measured CPU wall time. Compared with fused-native, Linear-Row adds 432 SPAD write bytes but removes 720 host-layout bytes, for 288 fewer accounted data bytes overall. The total phase interval is 4,273→2,712 cycles (1.576× within this harness), not full application latency. Matrix Active/Idle, DMA wait, Bank Stall and descriptor breakdown were not instrumented in this dataset, so useful MAC/CMDQ cycle must not be presented as PE utilization.

The same three-mode ablation was rerun on `conv1x_mini.onnx` (1,872 useful MACs, one deterministic input). All modes passed exact Golden checks for intermediates and four output bytes:

| Mode | CMDQ cycles | Accounted layout cycles | Accounted interval | Read/write bytes (SPAD; host-layout separate) |
|---|---:|---:|---:|---:|
| Legacy | 1,985 | 1,080 | 3,065 | 3,360/1,600; 144/576 |
| Fused Requant, native layout | 1,504 | 1,080 | 2,584 | 2,784/1,024; 144/576 |
| Fused Requant + Linear-Row | 1,504 | 0 | 1,504 | 2,784/1,456; 0/0 |

This model is also far below 100K MAC/inference. Round 10 did not run Legacy/Fused/Fused-Linear on a larger CNN, and did not claim a high-throughput CNN result.

## TinyNPU comparison

TinyNPU source was cleanly rebuilt from pinned SHA `8216c22b762011aa20c05fc2768423fd12dda59d` using Verilator 5.052. Seven direct-array shape cases passed independent INT32 Golden checks; its six-engine regression passed 6/6. For the shared `conv1x_mini.onnx`, its rebuilt graph runner passed all four output bytes and reported 4,781 graph cycles, 1,088 DMA load bytes and 4 store bytes.

### Fixed 3 GEMM + 4 GEMV matrix

All rows below passed Golden on both implementations. NMAForge endpoint is Matrix controller + behavioral four-bank SPAD through output completion. Tiny direct cycles measure its 16×16 RTL array only. The “Tiny common-memory” column is a model, not TinyNPU memory RTL: array cycles + `ceil((input_bytes + output_bytes)/16)` serialized transfer cycles + three fixed cycles, assuming 16 B/cycle, one-cycle read response, no overlap. The ratio is NMA measured cycles / Tiny estimated cycles; it is **not a measured system speedup**. Stall counters may overlap and must not be summed.

| Operation/shape | MACs | NMA measured cyc | Tiny direct-array cyc | Tiny common-memory estimate | NMA / estimate | NMA MAC/cyc; PE util | Tiny array MAC/cyc; PE util |
|---|---:|---:|---:|---:|---:|---:|---:|
| GEMM 16×16×16 | 4,096 | 185 | 52 | 151 | 1.2252 | 22.14; 8.65% | 78.77; 30.77% |
| GEMM 16×16×32 | 8,192 | 270 | 100 | 231 | 1.1688 | 30.34; 11.85% | 81.92; 32.00% |
| GEMM 32×32×64 | 65,536 | 1,381 | 790 | 1,305 | 1.0582 | 47.46; 18.54% | 82.96; 32.41% |
| GEMV 1×13×17 | 221 | 75 | 100 | 122 | 0.6148 | 2.95; 1.15% | 2.21; 0.86% |
| GEMV 8×16×19 | 2,432 | 154 | 100 | 164 | 0.9390 | 15.79; 6.17% | 24.32; 9.50% |
| GEMV 16×16×19 | 4,864 | 250 | 100 | 205 | 1.2195 | 19.46; 7.60% | 48.64; 19.00% |
| GEMV 16×16×65 | 16,640 | 631 | 244 | 441 | 1.4308 | 26.37; 10.30% | 68.20; 26.64% |

NMAForge takes more cycles than the modeled endpoint for three GEMMs, M=16 GEMV with K=19, and M=16 K=65 GEMV. It is below the estimate for M=1 and narrowly below for M=8 K=19. Since the endpoint is estimated and the direct-array and controller cycles differ, these are diagnostic comparisons only. The present data shows lower array utilization on larger NMA controller workloads and identifies controller/SPAD/packing stalls as a target for profiling; it does not show a general NMAForge win.

### Innovation 1 — GEMV and bounded reuse

Round 10 has **no Transformer model-level GEMV result**: H=4 Decode still uses
GEMM in the reused trained run, and H=16 is blocked before descriptor
generation. Prior fixed Matrix-command evidence remains useful but is not a
model result: B-fold Cache-only versus all-off reduced cycles from 197→147
(8×16×19), 544→398 (8×16×65), 391→270 (16×16×19), and 1,071→627
(16×16×65). Prefetch combined with Cache was shape-dependent and regressed
by two cycles at 16×16×65 versus Cache-only. See the
[Round 6 cache/prefetch data](NMAFORGE_V2_PERFORMANCE_COMPARISON.md).
Consequently, Innovation 1 is supported at batched command level only; no
Transformer Decode gain is claimed.

On `conv1x_mini.onnx`, both sides match model SHA `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`, input SHA `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`, and output Golden SHA `94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c`. Tiny graph cycles and DMA traffic are not on the same boundary as NMA Top CMDQ plus separately accounted layout work. No cross-system CNN ratio is calculated. Transformer and ≥100K MAC CNN matched model comparisons are `NOT_RUN`.

## Overlap and remaining evidence gaps

The inherited Round 9 three-tile small Matrix/DMA probe passed 3/3 Goldens and reported serialized 561 versus ping-pong 488 cycles (73 fewer; 72 overlap cycles). It is a small probe, not a large CNN result. The Round 8 original probe had four Golden mismatches; its exact archived failure was not recovered, so that issue remains `PARTIAL`. Round 10 did not use failed-run cycles for any result.

Open items are H=16 trained Transformer mapping/inference and quality, ≥100K-MAC multi-layer CNN lowering and full timing, H=16 SFU profile, model-level GEMV Cache/Prefetch ablation, large-model DMA/Matrix overlap, matched TinyNPU Transformer/CNN end-to-end boundary, CNN per-state stall profile, and ASIC cost/PPA. The last two were excluded or not reached; no Round 10 RTL optimization or new hardware claim is made.

## Reproduction and evidence

Run data:

- Matrix run ID: `R10-MATRIX-MATCH-1CD1BDE-S20261107`, seed `20261107`; raw logs under `/tmp/nmaforge_round10_nma_match_20261107/`.
- TinyNPU shape run: source SHA above; raw data under `/tmp/nmaforge_round10_tiny_gemm_20261107/`.
- TinyNPU CNN run: raw data under `/tmp/nmaforge_round10_tinynpu_20261107/cnn/`.
- NMA mini CNN modes: `R10-CNN-MINI-{LEGACY,FUSED-NATIVE,LINEAR-ROW}-1CD1BDE`.
- NMA Digits runs: `V2-TRAINED-CNN-TOP-DATASET-1CD1BDE-{LEGACY_LAYOUT,FUSED_NATIVE,LINEARIZED}`; result CSVs are in the matching `/tmp/nmaforge_round10_digits_*_20261108/` directories.
- H=16 preflight failure log: `/tmp/nmaforge_round10_h16_mapper.log`, SHA-256 `178100945aac52c5aeb1270edfaeada180574b330e7c7e5a3c8d41138076ce61`.
- Committed aggregate data: [`matrix/TinyNPU CSV`](../../benchmark/v2_round10_matrix_tinynpu.csv), [`CNN ablation CSV`](../../benchmark/v2_round10_cnn_ablation.csv), [`evidence JSON`](../../benchmark/v2_round10_evidence.json).

Aggregate artifact SHA-256:

| File | SHA-256 |
|---|---|
| `benchmark/v2_round10_matrix_tinynpu.csv` | `3816109c0b99bc48e1e72971c677ce0fb30575a88ead394f199eb2e3a53602a5` |
| `benchmark/v2_round10_cnn_ablation.csv` | `0a46f39ded756928a734d3f867619fd6553a970559c8bc40b1fc5db1341b9df3` |
| `benchmark/v2_round10_evidence.json` | `53a3f94536cd5cd311b4e499fed44666c7cc7018709b6e4352be0a69e83845e9` |

Key command lines (build/run output remains outside Git):

```sh
# TinyNPU fixed matrix and six-engine regression
TINY_NPU_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference/source \
TINYNPU_GEMM_OUT=/tmp/nmaforge_round10_tiny_gemm_20261107 \
VERILATOR=/tmp/nmaforge_verilator_src_5.052/bin/verilator \
VERILATOR_ROOT=/tmp/nmaforge_verilator_5.052 JOBS=4 \
bash benchmark/tinynpu/run_tinynpu_gemm.sh

# NMAForge Matrix build and fixed GEMM/GEMV measurements
make -C dv/block/compute/matrix/sim core-random-compile SEED=20261107 \
  PHYSICAL_ARRAY_SIZE=16 CORE_OUT_DIR=/tmp/nmaforge_round10_nma_match_20261107
/tmp/nmaforge_round10_nma_match_20261107/simv +SEED=20261107 \
  +TINY_NPU_MATCH_MULTI -l /tmp/nmaforge_round10_nma_match_20261107/gemm_match.log
/tmp/nmaforge_round10_nma_match_20261107/simv +SEED=20261107 \
  +MATRIX_PRODUCT_GEMV_ONLY -l /tmp/nmaforge_round10_nma_match_20261107/gemv_product.log

# TinyNPU clean-build ONNX mini CNN
TINY_NPU_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference/source \
TINYNPU_WORK_ROOT=/tmp/nmaforge_round10_tinynpu_20261107 \
TINYNPU_CNN_OUT=/tmp/nmaforge_round10_tinynpu_20261107/cnn \
PYTHON=/tmp/nmaforge_round10_venv/bin/python \
VERILATOR=/tmp/nmaforge_verilator_src_5.052/bin/verilator JOBS=4 \
bash benchmark/tinynpu/run_tinynpu_cnn.sh

# NMAForge paired mini CNN (compile + Legacy baseline)
make -C dv/subsystem/top_smoke/sim ai_tinynpu_cnn_match \
  AI_TINYNPU_CNN_RUN=/tmp/nmaforge_round10_nma_cnn_20261107 \
  AI_TINYNPU_CNN_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_TINYNPU_CNN_MODEL=/tmp/nmaforge_tinynpu_8216c22b/reference/source/models/conv1x_mini.onnx \
  AI_TINYNPU_CNN_GOLDEN=/tmp/nmaforge_round10_tinynpu_20261107/cnn/graph_cnn/golden.bin

# Reuse the compiled Top to collect the other two mini-CNN modes.
/tmp/nmaforge_round10_nma_cnn_20261107/simv +AI_TINYNPU_CNN_MATCH \
  +AI_TINYNPU_CNN_MEMORY=/tmp/nmaforge_round10_nma_cnn_20261107/workload/nma_cnn_spad.memh \
  +AI_TINYNPU_CNN_EXPECTED=/tmp/nmaforge_round10_nma_cnn_20261107/workload/nma_cnn_expected.memh \
  +AI_TINYNPU_CNN_FUSED_NATIVE -l /tmp/nmaforge_round10_nma_cnn_20261107/fused_native.log
/tmp/nmaforge_round10_nma_cnn_20261107/simv +AI_TINYNPU_CNN_MATCH \
  +AI_TINYNPU_CNN_MEMORY=/tmp/nmaforge_round10_nma_cnn_20261107/workload/nma_cnn_spad.memh \
  +AI_TINYNPU_CNN_EXPECTED=/tmp/nmaforge_round10_nma_cnn_20261107/workload/nma_cnn_expected.memh \
  +AI_TINYNPU_CNN_LINEARIZED -l /tmp/nmaforge_round10_nma_cnn_20261107/linearized.log

# NMAForge Digits dataset replay (reuse compiled top binary)
/tmp/nmaforge_round10_venv/bin/python benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
  --simv /tmp/nmaforge_round10_nma_cnn_20261107/simv \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha 1cd1bde4d82c457d445f97a7817fc22d407b528b --seed 20261107 \
  --out-dir /tmp/nmaforge_round10_digits_cnn_20261108
```

Do not commit VCS binaries, per-sample logs, simulator databases, `ucli.key`, or private EDA data. CSV/JSON aggregates provide committed results; original run logs remain local at the paths above.
