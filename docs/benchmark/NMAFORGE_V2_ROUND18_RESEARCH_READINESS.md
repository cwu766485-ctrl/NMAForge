# NMAForge v2 Round 18 — Research Readiness

**状态：PARTIAL — License-restored Top reruns PASS for the trained Digits CNN and the 262K-MAC pointwise fixture; the ≥100K-MAC trained-CNN requirement remains unmet.**

## Executive summary

Round 18 made no product RTL changes. The Round 17 tested RTL tree is byte-identical to the current base:

- Target branch: feature/npu-architecture-v2
- GitHub base/source SHA: 028656896a9fc296e1d72cab07c44f31fc747c12
- RTL tree SHA at base and Round 17 CNN run: fae8778d62c06c324bf5be0b5cbfea6843141e08
- Top smoke testbench tree SHA: fe249053f202fb0ae0e7865f201b24abeb6e80d8
- TinyNPU reference SHA: 8216c22b762011aa20c05fc2768423fd12dda59d

The frozen 262,144-MAC pointwise workload has valid Round 17 Golden and fusion results, but its weights are deterministic and untrained. The reproducible trained ten-class 3×3 CNN has 2,736 MAC/inference and 96.97% held-out accuracy. After license service recovery, a fresh Round 18 Top run passed its byte-exact output Golden at 3,193 CMDQ cycles. The separate 262,144-MAC two-layer pointwise fixture also passed a fresh Top run at 9,050 CMDQ cycles and 20,480/20,480 Golden words; it uses deterministic untrained inference weights and contains no 3×3 layer. Thus the fresh Top evidence is PASS, but the required ≥100K-MAC trained CNN is still OPEN.

The existing TinyNPU matrix has useful matched operands and independent Golden checks for seven GEMM/GEMV shapes. NMAForge measures controller plus behavioral SPAD; TinyNPU direct-array cycles are RTL-measured, while its common-memory values are serialized estimates. These are not equivalent full-system endpoints. The common mini CNN also passes both Goldens, but its graph/runtime and NMAForge phase boundaries differ. No system-level TinyNPU speedup is claimed.

## Frozen baseline and measurement contract

The base commit contains the Round 17 evidence package. Since the current RTL tree matches the tested Round 17 RTL tree, the following are reused as fixed-SHA evidence rather than claimed as new Round 18 simulations:

| Workload | Reused result | Measurement boundary |
|---|---|---|
| 262K-MAC pointwise CNN, legacy | 61,310 CMDQ cycles; 136,415 preload AXI-Lite cycles; 197,725 subtotal; 20,480 Golden words PASS | Preload + CMDQ subtotal excludes CSR queue setup, software generation, poison-read checks, and final Golden readback |
| Same CNN, first-layer fused | 35,184 CMDQ; 136,295 preload; 171,479 subtotal; Golden PASS | Same boundary |
| Same CNN, both-layer fused Linear-Row | 9,050 CMDQ; 136,175 preload; 145,225 subtotal; Golden PASS | Same boundary; two 0x53 descriptors produce final packed Row-Major output |
| H16 synthetic Transformer | Round 17 exact-LayerNorm fast-path: 35,391 decode cycles across four host-supplied tokens; all checked tensors/KV match | CMDQ decode stages only; not a trained language model, not autonomous token generation |
| Trained ten-class Digits CNN | Historical 396/396 Top intermediate/final Golden checks; 384/396 held-out classifications; see source-bound history below | Historical test SHA, not a Round 18 Top replay |

The common measurement fields requested in Round 18 are not all instrumented by the frozen tests. “N/A” means not independently measured, not zero:

| Field | Available evidence / boundary |
|---|---|
| Input and weight transfer | Pointwise Round 17 counts 90,784 bytes of testbench SPAD image writes and a combined AXI-Lite preload interval. It does not isolate input/weight transfer cycles. |
| Descriptor programming | Descriptor words are included in the same image-write loop; queue-register programming occurs after that timer and is not separately timed. |
| CMDQ execution | Measured from doorbell through final completion. |
| Output readback | Golden inspection occurs outside the CMDQ and preload timers; no separate readback-cycle field exists. |
| End-to-end latency | The available preload + CMDQ value is only a subtotal, not full application latency. Host workload generation, CSR setup, poison reads, and final readback are excluded. |
| Useful MAC/cycle | Derived as useful MACs divided by the stated CMDQ interval; not a direct PE utilization measure. |
| SRAM/DDR traffic | SPAD engine read/write counters are available. No DDR traffic was measured in these workloads. The preload loop is host AXI-Lite writes, not an external-memory DMA measurement. |
| Golden / accuracy | Independent integer tensor Goldens and model test accuracy are stated separately. |

### Preload audit: 262K pointwise workload

For the two-descriptor fused Linear-Row image, the generator places 22,696 32-bit words (90,784 bytes) into the preload image:

- Input and two weight matrices: 8,704 bytes.
- Descriptor and completion initialization: 160 bytes.
- Poison initialization of output/reserved buffers: 81,920 bytes. This includes 65,536 bytes for unused RAW1/RAW2 reservations and 16,384 bytes for ACT1/final-output sentinels.

Thus 90.24% of the written image is poison/sentinel buffer initialization; only 9.59% is input and weights. The Top testbench loops over addresses and calls a 32-bit AXI-Lite write once per image word. Its measured 136,175 cycles correspond to about 6.00 cycles per word or 0.667 image-bytes per cycle. This describes the testbench bus procedure, not DMA throughput, DDR bandwidth, or a hardware loader bottleneck. AXI4 burst length is not applicable to this per-word AXI-Lite preload loop. The current evidence cannot establish how an actual DMA boot/load path would perform.

No Round 18 change was made to the loader. A future system benchmark should separately time actual input/weight DMA, queue programming, CMDQ, and result readback, while keeping poison writes outside the deployment path or reporting them as verification-only overhead.

## P0 — Trained CNN

### Reproducible software model

The existing training workflow was rerun using Python 3.12.13, NumPy 2.4.6, and scikit-learn 1.9.1. Its generated weight, input, and test-set files exactly match the checked-in artifacts:

- Model: four shared 3×3 INT8 filters plus trained ten-class readout.
- Data: sklearn Digits labels 0–9; stratified split 1,401 train / 396 test; split seed 29.
- Training: NumPy/Adam convolution training, 250 epochs, batch 128, learning rate 0.006, seed 44; LogisticRegression readout with C=1 and no intercept, trained on deployed integer features.
- Quantization: input floor(pixel/4); INT8 weights/activations, INT32 accumulation; fixed documented round/shift/saturation rules.
- Useful work: 2,736 MAC per inference (1,296 convolution + 1,440 classifier).
- Independent integer software Golden: PASS; test accuracy 384/396 = 96.9697%.
- Weight SHA-256: ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726.
- Test-set SHA-256: cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107.
- Selected sample Golden SHA-256: 249587647d45f3e3ef9a54d009a1896cc7d1daf9152de1e11bfba2f4a1b115bc.

The checked-in manifest and model are the reproducible artifact. Round 18's software preflight reproduced their hashes and selected-sample logits. This workload is a legitimate trained 3×3 CNN demo, but is much smaller than the required 100K MAC/inference workload.

### Top result and status

The initial Round 18 attempts stopped at VCS license checkout. After license recovery, the same checked-in workload path compiled and ran successfully. Fresh run ID `R18-TRAINED-DIGITS-CNN-TOP-20261109-LIC-RETRY` passed with 16 descriptors, 3,193 CMDQ cycles, 1,080 testbench layout-accounting cycles, 6,048/1,920 SPAD read/write bytes, and byte-exact Golden. The VCS compile/run log hashes are recorded in the JSON manifest. This validates the existing small trained model on the current Round 18 source, but it does not meet 100K MAC/inference.

Historical evidence for the same ten-class model exists at older source/test SHA 9576e539c21fe6312763c4745a90dc032c6457e0, with the product RTL baseline recorded as cd0a05d8ecd8cfb6c3f39b559788a2531e324b23. It reports 396/396 exact Top intermediate/output checks, 384/396 classification, and identical behavior for 128 KiB and 512 KiB behavioral SPAD configurations. Round 10 also records a three-mode Top ablation at source/test SHA 1cd1bde4d82c457d445f97a7817fc22d407b528b. These historical results are retained as history only; they are not a current Round 18 replay and do not demonstrate a ≥100K-MAC trained CNN.

| Historical trained-CNN mode | CMDQ cycles/sample | Testbench layout cycles/sample | Accounted sum | SPAD read/write bytes | Exact Golden / accuracy |
|---|---:|---:|---:|---:|---|
| Legacy | 3,193 | 1,080 | 4,273 | 6,048 / 1,920 | 396/396; 384/396 |
| Fused requant, native layout | 2,712 | 1,080 | 3,792 | 5,472 / 1,344 | 396/396; 384/396 |
| Fused requant + Linear-Row | 2,712 | 0 | 2,712 | 5,472 / 1,776 | 396/396; 384/396 |

The testbench layout interval is simulated transaction accounting, not measured CPU wall time. The 10-class model is not a substitute for the requested high-MAC CNN.

### Existing ≥100K-MAC CNN

The separate 262,144-MAC workload is two 1×1 INT8 pointwise layers with deterministic fixed-seed inference weights. It is not trained, has no classification accuracy, and does not contain 3×3 convolution or Host Im2col. Its three Round 17 Golden-passing dataflows remain useful architecture ablations:

| Mode | CMDQ cycles | Preload + CMDQ subtotal | SPAD read/write bytes | Useful MAC/CMDQ cycle | Golden |
|---|---:|---:|---:|---:|---|
| Legacy, four descriptors | 61,310 | 197,725 | 98,304 / 81,920 | 4.276 | 20,480 words PASS |
| First-layer fused, three descriptors | 35,184 | 171,479 | 65,536 / 49,152 | 7.451 | 20,480 words PASS |
| Both-layer fused Linear-Row, two descriptors | 9,050 | 145,225 | 32,768 / 16,384 | 28.966 | 20,480 words PASS |

These are reused Round 17 tests at source SHA 84148b9abf35aa82d12e058814e260784d76d554; the current base has the identical RTL tree. The last row has compatible packed Row-Major output. Even here, preload + CMDQ falls 26.55% from legacy, much less than the 85.24% CMDQ-only reduction, because the serial testbench image load dominates the subtotal.

**P0 conclusion: PARTIAL.** The fresh trained Digits CNN Top replay and fresh 262K-MAC pointwise Top fixture both PASS their stated Golden checks. The trained model is only 2,736 MAC/inference; the 262K fixture is deterministic untrained inference data and has no accuracy claim. A trained model with at least 100K useful MAC/inference and the requested 3×3 lowering/transfer accounting remains the main unmet Round 18 MUST.

## P1 — Transformer

The H16, two-head, one-layer INT8 incremental KV path is a synthetic supervised projection task, not a trained next-token model. Round 17 verified four host-supplied incremental decode steps and exact output/KV hashes. The exact LayerNorm fast path measured 35,391 CMDQ cycles for tokens 4–7 versus 39,615 baseline (10.66% reduction); prefill was 2,734 cycles. Round 18 did not retrain or rerun Transformer Top. A training/held-out language-model metric, model quality claim, and input/weight transfer/end-to-end timing are NOT_RUN.

GEMV had only a 0.424% mean decode-latency reduction in the earlier H16 comparison; it is not evidence of a meaningful model-level acceleration. Round 17 did not rerun Cache/Prefetch under the exact-LayerNorm configuration. No new Transformer innovation ablation is claimed.

## P2 — TinyNPU fairness assessment

Pinned TinyNPU SHA: 8216c22b762011aa20c05fc2768423fd12dda59d. Round 17's fixed matrix used the same deterministic operand formulas, signed INT8 inputs, INT32 accumulation, independent Golden, and 16-byte/cycle, one-cycle-response common memory assumption. NMAForge cycles are measured Matrix controller + behavioral SPAD. TinyNPU direct array cycles are RTL-measured; the normalized memory endpoint is a serialized model around that array, not TinyNPU memory RTL.

| Shape | NMAForge measured cycles | TinyNPU direct-array RTL cycles | TinyNPU serialized memory estimate | NMAForge / modeled Tiny | Both Goldens |
|---|---:|---:|---:|---:|---|
| GEMM 16×16×16 | 174 | 52 | 151 | 1.1523 | PASS |
| GEMM 16×16×32 | 248 | 100 | 231 | 1.0736 | PASS |
| GEMM 32×32×64 | 1,390 | 790 | 1,305 | 1.0651 | PASS |
| GEMV 1×13×17 | 70 | 100 | 126 | 0.5556 | PASS |
| GEMV 8×16×19 | 149 | 100 | 170 | 0.8765 | PASS |
| GEMV 16×16×19 | 256 | 100 | 218 | 1.1743 | PASS |
| GEMV 16×16×65 | 627 | 244 | 459 | 1.3660 | PASS |

The ratios are mixed-endpoint diagnostics, not cross-system RTL speedups. They indicate NMAForge uses more cycles for the three listed GEMMs and two larger GEMVs under this model, and fewer for the two smaller GEMVs. The different controller/memory boundaries prevent a system-level winner claim.

For conv1x_mini.onnx, both sides pass the same four-byte Golden. NMAForge reports 1,985 CMDQ compute + 1,080 host-layout accounted cycles; TinyNPU reports 4,781 graph-smoke cycles using its graph dispatcher and testbench DMA/SRAM shim. Those intervals differ, so no ratio is calculated. The 262K pointwise workload, trained Digits CNN, and H16 Transformer were not run on TinyNPU under matching native endpoints.

The Round 18 host has no Verilator on PATH. VCS is now available and the trained-CNN, 262K fixture, and bounded smoke Top runs pass; no Round 18 TinyNPU rebuild or fresh matched run was performed. The fixed-SHA Round 17 benchmark is reused for fairness analysis.

## P3 — Readiness decision

| Deliverable | Status | Evidence / remaining gap |
|---|---|---|
| Frozen Round 17 functional baseline and measurement contract | PASS_REUSED | Current RTL tree equals Round 17 tested RTL tree. New input/transfer/readback fields are explicitly marked N/A when not separately instrumented. |
| Trained CNN software model and independent Golden | PASS | Ten-class Digits, 384/396 test accuracy; hashes reproduced. |
| Trained Digits CNN Top replay | PASS | Fresh Round 18 VCS Top run; byte-exact output Golden, 2,736 MAC/sample, below representative threshold. |
| Representative trained CNN ≥100K MAC Top run | OPEN / NOT SATISFIED | 262K-MAC Top fixture passes but is untrained and pointwise-only; no ≥100K-MAC trained 3×3 CNN Top run. |
| High-MAC trained CNN with 3×3 Conv and fully accounted Im2col | NOT_RUN | No existing Top mapping for such a trained workload in this round; do not treat Host transforms as free. |
| Trained H16 next-token Transformer | NOT_RUN_OPTIONAL | Existing H16 is synthetic task with host-supplied tokens. |
| TinyNPU fairness decision and fixed evidence | PASS_SCOPED | Matched operands/Golden exist for 3 GEMM + 4 GEMV; memory and native-model endpoints are not equivalent. |
| ASIC PPA / freeze for implementation | OUT_OF_SCOPE / NOT_READY | No synthesis, PPA, or physical memory timing was run. |

The 16×16 Matrix, 128 KiB behavioral SPAD candidate, GEMV 0x52, fused Row-Major 0x53, H16 KV append, and exact LayerNorm fast path can be frozen as a research RTL baseline. The project is not research-complete against Round 18's representative-model requirements and is not ready to claim ASIC implementation readiness.

## Reproduction and artifact references

Round 18 software training and Golden:

    /tmp/nmaforge_arch_v2_py312/bin/python benchmark/tinynpu/train_nma_cnn_demo.py --num-classes 10 --out-dir /tmp/nmaforge_round18_trained_cnn_attempt/model
    /tmp/nmaforge_arch_v2_py312/bin/python benchmark/tinynpu/generate_nma_cnn_demo_golden.py --model /tmp/nmaforge_round18_trained_cnn_attempt/model/nma_tiny_cnn_demo_weights.npz --input-npz /tmp/nmaforge_round18_trained_cnn_attempt/model/nma_tiny_cnn_demo_input.npz --golden /tmp/nmaforge_round18_trained_cnn_attempt/model/nma_cnn_golden.bin

Initial Round 18 attempt (before license recovery):

    make -C dv/subsystem/top_smoke/sim ai_trained_cnn_demo AI_TRAINED_CNN_CLASSES=10 AI_TRAINED_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python AI_TRAINED_CNN_RUN=/tmp/nmaforge_round18_trained_cnn_attempt

Run ID: R18-TRAINED-DIGITS-CNN-SOFTWARE-20261109; software Golden PASS. Initial Top attempt was BLOCKED_ENV before simulation, then license-restored retry R18-TRAINED-DIGITS-CNN-TOP-20261109-LIC-RETRY PASS. Run ID R18-POINTWISE-262K-TOP-20261109-BOTH-LINEARIZED PASS; Run ID R18-TOP-SMOKE-SEED20261118 PASS. Toolchain: VCS V-2023.12-SP1_Full64, Python 3.12.13, NumPy 2.4.6, scikit-learn 1.9.1, ONNX 1.17.0. Fresh Verilator executable was not found on PATH.

Machine-readable Round 18 summary:

- [Performance summary CSV](ROUND18_MODEL_PERFORMANCE.csv)
- [TinyNPU comparison CSV](ROUND18_TINYNPU_COMPARISON.csv)
- [Run, hashes, and statuses JSON](ROUND18_RESEARCH_READINESS.json)

Reused detailed sources:

- [Round 17 CNN fusion evidence](round17_evidence/ROUND17_CNN_FUSION_COMPARISON.json)
- [Round 17 Transformer profile](round17_evidence/round17_decode_comparison.json)
- [Round 17 TinyNPU matrix](round17_evidence/tinynpu/benchmark_summary.json)
- [Ten-class trained model artifacts](../../benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_manifest.json)
- [Historical ten-class Top results](../../benchmark/v2_trained_cnn_tenclass_top_128k_9576e53.csv)

No RTL changes, full DV closure, ASIC synthesis, or Round 19 work was started. The local license-restored reruns were made against source commit 6683f6d659d161fd18b9f882000ddbe7ed96a573 (RTL tree fae8778d62c06c324bf5be0b5cbfea6843141e08), whose files match the published Round 18 baseline tree.
