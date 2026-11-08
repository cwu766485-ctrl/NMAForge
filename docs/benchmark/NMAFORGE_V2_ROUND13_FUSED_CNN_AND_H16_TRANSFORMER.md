# NMAForge v2 Round 13 — Fused CNN and H16 Transformer

Date: 2026-11-08  
Disposition: **CNN first-layer fusion PASS; double-fusion output-layout probe PARTIAL; H16 QKV Top PASS; H16 attention Top FAIL_GOLDEN; full H16 Transformer NOT_RUN.**

## 1. Frozen source and measurement boundary

- Reviewed product RTL base: `854d2d6e8084227d4621570a85f3c587382b1e64`.
- Product RTL changed in this round: **none**.
- Round 13 code/test source at the final model run: `e469fac3ebf726b3feb3120eb54ac0e4a8243b3f`.
- Round 13 commits: `55486444d4a205c53066fb1141ab173f9230b242` (CNN modes and Top target), `49fd5742da4a876f7d8734cbe7e6c7f1989e09c8` (H16 QKV training/export/Top), `e469fac3ebf726b3feb3120eb54ac0e4a8243b3f` (H16 two-head attention mapper/probe).
- Simulator: Synopsys VCS `V-2023.12-SP1_Full64`; workload scripts: Python `3.12.13`.
- Top simulation: behavioral 4-bank SPAD, 128 KiB (`AI_SPAD_WORDS_PER_BANK=8192`), 10 ns ACLK. These are RTL simulation measurements, not ASIC/PPA results.
- CNN “Load + Command” is the measured AXI workload preload plus CMDQ execution. It excludes host-side model/workload generation and any external image/data acquisition. The Top path has no host compute fallback or Im2col for this 1×1 workload.
- TinyNPU remains pinned at `8216c22b762011aa20c05fc2768423fd12dda59d`; no matched TinyNPU model run was completed in this round.

Machine-readable results: [CSV](../../benchmark/representative/round13/round13_results.csv) and [JSON](../../benchmark/representative/round13/round13_results.json).

## 2. Phase A — 262,144-MAC pointwise CNN

The workload is a deterministic two-layer 1×1 INT8 inference network with input shape `[1,16,32,16]`, 512 spatial positions, and 16 input/output channels. Weights and inputs are fixed-seed generated inference data, **not trained weights**; no classification-accuracy claim is made. All three runs use seed `20261108`, identical input and weights, INT32 accumulation, signed INT8 saturation with shift 0, no ReLU, and the same scalar Python Golden.

| Mode | CMDQ sequence | Commands | Command cycles | Preload cycles | Load + Command | SFU busy | SPAD read / write | MAC / command cycle | Golden |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| Legacy | `0x30 → 0x36 → 0x30 → 0x36` | 4 | 61,310 | 136,415 | 197,725 | 53,252 | 98,304 / 81,920 B | 4.2757 | 20,480/20,480 PASS |
| First-layer fused | `0x53 → 0x30 → 0x36` | 3 | 35,184 | 136,295 | 171,479 | 26,625 | 65,536 / 49,152 B | 7.4507 | 20,480/20,480 PASS |
| Both layers fused | `0x53 → 0x53` | 2 | 9,050 | 136,175 | 145,225 | 0 | 32,768 / 16,384 B | 28.9662 | 20,480/20,480 for Matrix-A layout |

All modes report 262,144 useful MACs, 1,024 Matrix MAC-active cycles, 100% active-array utilization while Matrix MAC is active, and 128 KiB SPAD capacity. The final row of the table is an internal-layout probe: opcode `0x53` leaves the final INT8 result in Matrix-A tile layout, while the legacy externally checked output is row-major packed INT8. The additional conversion to the legacy-visible output format was not implemented or timed, so the two-command result is **not a complete output-compatible inference point** and must not be used as a system-level speedup claim.

### First-layer fusion result

The compatible three-command path reduces command latency by 26,126 cycles (42.61%, 1.742× by command cycles). Including the measured preload, it reduces 26,246 cycles (13.27%, 1.153×). SFU busy time falls by 26,627 cycles (50.00%); the remaining 26,625 SFU cycles are the second layer's separate requant command. SPAD read traffic falls 33.33%, write traffic 40.00%, and Matrix writeback cycles fall from 4,096 to 2,560. The Matrix MAC-active count remains unchanged, so the gain comes from removing one separate requant pass and its data movement, not from more MAC hardware.

The fusion preserves the final legacy row-major output. The first layer's raw INT32 destination is intentionally left poisoned/unused; its independently computed raw INT32 Golden is retained in the workload manifest, while the packed intermediate and final output are checked at Top. The observable model result hash is identical across modes: `6f81ea743327c2b7daa5d4e11e8e2e88848398b99bfaca97d170c570ccc3170e`.

The two-fused probe removes both separate SFU passes and has a much lower raw command count, but its final-layout conversion cost is missing. Do not interpret `9,050` cycles as a complete model result latency. No tile-forwarding capture/consume flags were exercised, so no Tile Forwarding benefit is claimed.

### CNN artifacts and reproduction

All runs were generated and checked with the checked-in `generate_pointwise_cnn_workload.py` and `verify_pointwise_cnn_workload.py`; input hash is `f8514ef62fc2e83230d533ea2c82afb18a8d2b71e7324886679fd814e99561ea`, weights are `b780646f65d0247b5972c9125073988315d6ea4c2fe073ea4c1aa63a569b9d89` and `b37e120ac1afbc15ffc67c4ddc2f94368901ef0eca8f0120ae2cba6eb846efa0`.

```bash
cd dv/subsystem/top_smoke/sim
make ai_representative_cnn AI_REPRESENTATIVE_RUN=/tmp/r13-legacy \
  AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108 \
  AI_REPRESENTATIVE_FUSION_MODE=legacy AI_REPRESENTATIVE_DESC_COUNT=4
make ai_representative_cnn AI_REPRESENTATIVE_RUN=/tmp/r13-first \
  AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108 \
  AI_REPRESENTATIVE_FUSION_MODE=first AI_REPRESENTATIVE_DESC_COUNT=3
make ai_representative_cnn AI_REPRESENTATIVE_RUN=/tmp/r13-both \
  AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108 \
  AI_REPRESENTATIVE_FUSION_MODE=both AI_REPRESENTATIVE_DESC_COUNT=2
```

The successful run logs and compile logs are under `/tmp/nmaforge_r13_cnn_e469_{legacy,first_desc3,both}_s20261108/`. Image/Goden hashes and raw profile counters are in the JSON/CSV. (The workload manifest uses `golden_file_sha256`; the corresponding memory hashes are `bd2dbed180dae0e996a6bd1a0a049eb642da81858c6ed7f033802d69647a61bd`, `4d73c41b17170153f070dacaeb8d632645c3446328a389a3b29ffd808d301c93`, and `6000796835438b998b477d574ab8a5497cbf09508b6464fb07886642a0adfaac`.)

## 3. Phase B — H16 / two-head Transformer enablement

### Scope implemented

The new deterministic trainer exports Hidden=16, two heads, head dimension 8, one layer, sequence length 8, signed INT8 Q/K/V matrices. It trains three projection matrices with a seeded integer multiclass perceptron on synthetic token-to-projection labels and exports a model SHA. This is a **trained synthetic QKV projection task**, not a pretrained or language-model-trained Transformer. Its 48/48 training labels and 8/8 sequence marker are not held-out model quality metrics.

The mapper retains H4 legacy behavior and adds H16 Top generation. It lays out Q/K/V by head, emits real ABI-v7 Matrix descriptors, handles physical 4×4 subtiles, and creates an independent scalar software Golden. The code changes are confined to Python trainer/mapper/verifier and the Top Smoke Makefile; no product RTL or opcode behavior changed.

| Gate | Status | Evidence / limit |
|---|---|---|
| G1 — H16 model export and software Golden | PARTIAL | Reproducible synthetic QKV training and independent QKV/attention software Golden exist; not a complete trained Transformer. |
| G2 — QKV GEMM Top | PASS | 3 descriptors, 384 INT32 words, 6,144 useful MACs; 360 command cycles, 4,199 preload cycles, 1,152 B SPAD read and 1,536 B write; all output words match. |
| G3 — QK, causal Softmax, AV, head merge | FAIL_TOP_GOLDEN | The 47-descriptor workload and its independent 1,440-word Golden validate offline. Top retires all 47 commands, then fails at the first AV INT32 output word: index 768, address `0x00005080`, expected `0xffffff82`, actual `0x00000004`. No full attention performance number is admitted. |
| G4 — residual, LayerNorm, FFN | NOT_RUN | The preceding attention Top mismatch blocks valid model continuation. |
| G5 — KV cache, Prefill, Decode | PARTIAL / NOT_RUN | KV key/value tile write/readback descriptors execute before the AV mismatch, but no complete KV sequence, incremental Decode, or end-to-end Transformer passes. |

Two bounded layout fixes were attempted: (1) pack the 8×8 K tiles in the physical order required by the existing Matrix B reader, then (2) produce V-transpose with the shared Matrix array and retain a B-compatible physical tile without host activation rearrangement. The subsequent fixed-SHA run still mismatches at AV writeback. The evidence localizes the first observed failure to the AV output range; it does **not** prove whether the remaining cause is the Matrix 8×8 output/writeback path or descriptor/layout semantics. Further RTL changes are outside this round's bounded repair limit.

The independent H16 attention Golden reports 47 descriptors, 1,440 output words, 10,240 useful MACs, Golden digest `eb34c60c0ad8f4d7b371c249977affa152bcf9bb9ba78f3caf1d0eeaf7e0c0f1`; Top execution is still FAIL. Its observed cycles are excluded from benchmark tables because the Top output Golden fails.

### H16 reproduction

```bash
cd dv/subsystem/top_smoke/sim
make ai_h16_qkv_top AI_H16_QKV_RUN=/tmp/r13-h16-qkv \
  AI_H16_QKV_PYTHON=python3.12 AI_H16_QKV_SEED=20261113
make ai_h16_attention_top AI_H16_ATTENTION_RUN=/tmp/r13-h16-attn \
  AI_H16_ATTENTION_PYTHON=python3.12 AI_H16_ATTENTION_SEED=20261113
make ai_smoke AI_RANDOM_CASES=0 AI_SEED=20261113
```

QKV model SHA: `ce932455f883bcb374663d4b9d9737f8a846421857b5c87ad2b63f5fa8fea9de`; QKV Golden image SHA: `5bbac5cde03d37ca1e137554b46bcd2b3b2f5d0bd6d0e3fbb7a01d75db03dfcf`; Q/K/V output hashes are in the results JSON. QKV and H4 compatibility pass logs are under `/tmp/nmaforge_r13_h16_qkv_e469fac_s20261113/` and the repository's ignored Top smoke log. The failing attention log is `/tmp/nmaforge_r13_h16_attention_top_e469fac_s20261113/run.log`; its independent Golden log is captured by the same run's make output.

## 4. TinyNPU, remaining evidence, and decision

No TinyNPU executable/model comparison was run in this round. The pinned revision remains `8216c22b762011aa20c05fc2768423fd12dda59d`; the Round 13 CNN is a local deterministic inference workload and H16 has not passed the full Top path. Therefore there is no new matched TinyNPU speedup claim. A future comparison needs both sides to execute identical tensors and quantization and include the same output-layout conversion and memory service boundary.

This round demonstrates an output-compatible first-layer `0x53` optimization on the 262K-MAC CNN, with measured command and preload-inclusive gains. It does not demonstrate trained CNN quality, full H16 Transformer inference, H16 Decode acceleration, `0x52` GEMV benefit, Tile Forwarding gain, TinyNPU superiority, or ASIC PPA.

## 5. Final status

- CNN baseline and first-layer fused path: **PASS**.
- Both-layer fused path: **Top data Golden PASS in Matrix-A layout; public output layout compatibility PARTIAL**.
- H16 QKV software/Top path: **PASS**.
- H16 attention Top: **FAIL_TOP_GOLDEN** at AV output address `0x5080`; fixed-SHA failure retained.
- H16 full Transformer, LayerNorm/FFN, incremental Decode and model-level quality: **NOT_RUN**.
- TinyNPU matched CNN/Transformer model comparison: **NOT_RUN**.
- Product RTL modified: **no**; required next debugging target, if authorized later, is the bounded 8×8 AV output/layout path with an independent row-by-row physical-memory audit.

This report closes Round 13 at source/test SHA `e469fac3ebf726b3feb3120eb54ac0e4a8243b3f`. It does not declare the H16 Transformer task complete and does not start another round.
