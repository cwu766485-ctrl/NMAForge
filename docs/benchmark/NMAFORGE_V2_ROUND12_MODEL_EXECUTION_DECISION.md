# NMAForge v2 Round 12 — Model Execution Decision

**Disposition: PARTIAL.** The 262,144-useful-MAC CNN now passes through the production Top CMDQ path at the 128 KiB SPAD setting, including all four completions and 20,480 intermediate/final Golden words. H=16 Transformer remains blocked at the software mapper/model-export boundary; no H=16 RTL run or performance result exists. This is a functional baseline, not full model-quality evidence or v2 sign-off.

## Source and run identity

| Item | Value |
|---|---|
| Target branch | feature/npu-architecture-v2 |
| Tested source/test SHA | f17234cf9435272d05ff8e444a0da846da380963 |
| Reviewed starting SHA | 28cd86e0c18d62e4ce6cfb14a2f43967cdce0d4d |
| Product RTL changed in this round | No |
| Test/workload changes | Long-task SVA limit for this target; packed K-group descriptor correction; opcode-contract Golden correction; fractional MAC/cycle reporting fix |
| VCS | Synopsys V-2023.12-SP1_Full64 |
| Python | 3.12.13 |
| CNN seed | 20261108 |
| CNN Top run ID | R12-TOP-REP-CNN-128K-S20261108-FINAL |
| H=16 preflight | R12-H16-MAPPER-PREFLIGHT-20261108 |
| Final Top run log | /tmp/nmaforge_r12_cnn_128k_20261108_signedoff/run.log, SHA-256 0c5dabc18cd66140441e4798ee11677ee2cd787b9e06277dbc8dee17db5baf09 |
| Final VCS compile log | /tmp/nmaforge_r12_cnn_128k_20261108_signedoff/compile.log, SHA-256 35c32648bcfa77c76d96cfde09b2aef94adb778c66e04a55f4bf203e97044a13 |
| SPAD image | SHA-256 bd2dbed180dae0e996a6bd1a0a049eb642da81858c6ed7f033802d69647a61bd |
| Golden image | SHA-256 3751998e65e40ad1ffe03106baf732f9d9c83dfb051ed160dda365e21319b2fc |
| Machine-readable status / metrics | [round12_model_status.json](../../benchmark/representative/round12_model_status.json), [round12_performance.csv](../../benchmark/representative/round12_performance.csv) |

Work ran in an isolated worktree. main R250 and the user's other worktrees were not modified. No private PDK, license data, SRAM model, or generated simulation database is included in the repository.

## Phase 0 — 262,144-MAC CNN Top execution

### Workload contract

The fixed-seed workload has input shape [1,16,32,16] (512 spatial positions, 16 channels), two 1×1 Conv layers (16→16), and 262,144 useful INT8 MACs per inference. Weights are deterministic random inference weights, **not trained**; no classification accuracy is claimed. The Top path is 0x30 GEMM → 0x36 REQUANT_I8 → 0x30 GEMM → 0x36 REQUANT_I8. There is no Host intermediate compute or Im2col.

The first generated version incorrectly encoded ordinary GEMM word6 as scalar K=16, although this ABI field counts packed four-element K groups; the corrected descriptor encodes K-group count 4. The first Golden also assumed ReLU, but opcode 0x36 implements arithmetic shift and signed INT8 saturation only. The final workload therefore explicitly has **no activation**, preserving the specified hardware contract rather than changing RTL or relaxing the Golden. Both fixes are documented in the generator and independent verifier.

| Artifact | SHA-256 |
|---|---|
| Input tensor | f8514ef62fc2e83230d533ea2c82afb18a8d2b71e7324886679fd814e99561ea |
| Layer 1 weights | b780646f65d0247b5972c9125073988315d6ea4c2fe073ea4c1aa63a569b9d89 |
| Layer 2 weights | b37e120ac1afbc15ffc67c4ddc2f94368901ef0eca8f0120ae2cba6eb846efa0 |
| Final output tensor | 6f81ea743327c2b7daa5d4e11e8e2e88848398b99bfaca97d170c570ccc3170e |

### Top result

| Metric | Result | Boundary / note |
|---|---:|---|
| Top compile | PASS | 31 modules, 0 errors; one non-functional LOOP-REROLL-ENABLED warning; KDB elaboration reported 0 errors and 0 warnings |
| CMDQ descriptors / completions | 4 / 4 PASS | All four completion task IDs and success statuses checked |
| Independent intermediate/final Golden | PASS | 20,480 words checked after CMDQ completion |
| Command cycles | 61,310 | Doorbell through final completion; includes engine, dispatch, and retirement time |
| Host SPAD preload | 136,415 cycles; 90,944 bytes | Measured AXI writes before command issue; not DMA |
| Load + command subtotal | 197,725 cycles | Excludes CSR setup, poison verification/readback, and software generation; do not label full E2E |
| Useful MAC / command cycle | 4.2757 | Recomputed from 262,144 / 61,310; TB was corrected to retain fractional division |
| Matrix MAC-active cycles | 1,024 | Active-cycle counter from Top profile |
| Active-array utilization | 100.00% | Derived as 262,144 / (256 × 1,024); active-cycle utilization, not whole-command utilization |
| Matrix request wait / response wait | 16 / 202 cycles | Exclusive Matrix profile buckets |
| Matrix writeback / other | 4,096 / 2,620 cycles | Exclusive Matrix profile buckets |
| SFU busy | 53,252 cycles | Two packed requant commands; each command reads 8,192 INT32 values and writes 2,048 packed words |
| No-engine dispatch/control remainder | 100 cycles | Exclusive profile bucket |
| SPAD read / write traffic | 98,304 / 81,920 bytes | Top-observed engine accesses during command window; preload AXI bytes are separate |
| DMA/compute overlap | 0 cycles | This workload does not use DMA for its initial image preload |

The exclusive command profile closes exactly: 1,024 + 16 + 202 + 4,096 + 2,620 + 53,252 + 100 = 61,310. mac_per_cycle in the final VCS log is 4.2757; an earlier passing run printed a truncated integer and was superseded by the final run above.

This model is intentionally a functional/throughput stress fixture. It is not trained and has no task accuracy. The measured command window is not full system inference latency; Host preload and software/CSR setup must be accounted separately for an end-to-end comparison.

### Iteration record

1. License checkout initially failed before compilation. After the user restored the VCS license, the same target compiled and ran.
2. The first licensed run reached the TB's generic 2,000-cycle SVA watchdog. A compile define now raises only this representative target's watchdog to 200,000 cycles; the test itself retains its 2,000,000-cycle completion bound.
3. The first functional mismatch exposed the packed-K-group descriptor bug. Correcting K to four groups made both raw INT32 GEMM tensors match.
4. The next mismatch exposed a model/operator contract error: the workload assumed ReLU while 0x36 is signed saturation. The final workload contract was corrected to no activation; no expected values were waived.
5. The final fixed-seed Top run passed compile, all completions, and every Golden word. No product RTL was modified.

## Phase 1 — CNN optimization gate

Status: NOT_RUN_BY_SCOPE. This round establishes the required valid Top baseline only. Fused requant, alternative output layout, and DMA/compute overlap ablations were not run. No speedup claim is made. A 3×3 convolution/Im2col cost study also remains open.

## Phase 2 — H=16 two-head Transformer

Current trainer and mapper remain H=4-oriented: one head, four token IDs in [0,3], and six 4×4 matrices. Two preflight probes were rejected by those existing software checks: eight-token input fails the token/model contract, and 16×16 weights fail the fixed weight-shape contract. These are mapper-support findings, not RTL failures.

| Gate | Status | Evidence / reason |
|---|---|---|
| G1 — train/export H=16, shape validation, independent Golden | BLOCKED_MAPPER_SUPPORT | No H=16 model/weight export or software Golden exists |
| G2 — Q/K/V GEMM descriptors + Top Golden | NOT_RUN | No H=16 mapping/descriptors generated |
| G3 — two-head split, QK, Softmax, AV, merge | NOT_RUN | No head layout/address mapping or tensor Golden |
| G4 — Residual, LayerNorm, FFN | NOT_RUN | No H=16 descriptor/tensor chain |
| G5 — KV-cache, Prefill, single-token Decode | NOT_RUN | No H=16 cache strides/layout or Top execution |

Probe logs were run at the reviewed starting SHA 28cd86e0c18d62e4ce6cfb14a2f43967cdce0d4d: /tmp/nmaforge_r12_h16_probe8.log (SHA-256 b3938bff16541c9ddb713185da2b755cb8ddb5f9da12914c679a2ccaecc8e3b5) and /tmp/nmaforge_r12_h16_probe4.log (SHA-256 1136c20820b437c82e2120c29ed55f799f58c63a7973f2b8d58fa74cee569a38). H=16 Prefill/Decode cycles, accuracy, MAC/cycle, GEMV benefit, cache/prefetch effect, and SPAD traffic are unavailable. Historical H=4 evidence is not H=16 evidence.

## Reproduction

From repository root, with an authorized VCS license active:

    make -C dv/subsystem/top_smoke/sim ai_representative_cnn \
      AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r12_cnn_128k_20261108_signedoff \
      AI_REPRESENTATIVE_PYTHON=python3.12 \
      AI_REPRESENTATIVE_SEED=20261108

The command used AI_SPAD_WORDS_PER_BANK=8192 (128 KiB total, four banks), VCS -full64 -sverilog -debug_access+all -kdb, and the repository Top smoke file list. Offline generation and checking are also run by the Make target:

    python3.12 benchmark/representative/generate_pointwise_cnn_workload.py \
      --seed 20261108 --out-dir /tmp/nmaforge_r12_cnn_128k_20261108_signedoff/workload
    python3.12 benchmark/representative/verify_pointwise_cnn_workload.py \
      --workload-dir /tmp/nmaforge_r12_cnn_128k_20261108_signedoff/workload

## Decision

Round 12 remains PARTIAL: the representative CNN functional/measurement baseline is reproducible and passes Top RTL, while the H=16 model path is blocked before descriptor generation. No CNN optimization ablation, H=16 Transformer inference, ASIC PPA, or v2 sign-off is claimed. Preserve the passing H=4/other historical evidence separately; do not extrapolate it to H=16.
