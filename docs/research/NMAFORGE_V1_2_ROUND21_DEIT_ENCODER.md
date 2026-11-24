# NMAForge V1.2 Round 21 — DeiT Encoder Progress

## Disposition

**PARTIAL — 256 KiB Product Top now executes the complete 197-token patch embedding and one genuine H192 LayerNorm row from its Matrix-A packed output. The first QKV projection and full Encoder Layer 0 have not run.** This report does not claim DeiT classification accuracy or Encoder PASS.

## Source and model provenance

| Item | Value |
|---|---|
| Research branch | `research/nmaforge-v1.2-round21-deit` |
| Branch base SHA | `733b573beb984ad455113a229b94593a7ac42f9b` |
| Simulator | Synopsys VCS V-2023.12-SP1 Full64 |
| Model | `facebook/deit-tiny-patch16-224`, official checkpoint, hidden 192, 3 heads, 12 layers |
| Checkpoint config SHA-256 | `e8786a68c993c04b8721c4d379e4f9de6a9564fba5987704dbf8696d53b7972d` |
| Image processor config SHA-256 | `90d1ae427c27d2b9dcb01f6a62ba96aa67aac2de1697c59cd212055b5035c4a2` |
| Checkpoint weight SHA-256 | `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` |
| Synthetic fixture seed | `20261117` |
| Processed-pixel SHA-256 | `028bcacc0b989481a9e7b1fb119974605721e2cc063a76d1dd1b248d088f9b88` |

The checkpoint is genuine and the image is a deterministic synthetic RGB fixture processed by the official image processor. No labeled image set was used; no classification score is claimed.

## Bug found and bounded fix

The first LayerNorm Top run retired all descriptors but mismatched its first output (`addr=0x2b900`, expected `6`, actual `0`). The diagnostic showed that Tile-A byte extraction was selected globally for all SFU SPAD responses. Consequently, the 32-bit gamma value `0x00041b51` was read as its low byte `81`; beta was also at risk of truncation. A first state restriction omitted the normalization output input-read state and produced a distinct large incorrect output. The final correction limits byte extraction to the three LayerNorm source-vector response states: `ST_LN_SUM_WAIT`, `ST_LN_VAR_WAIT`, and `ST_RMS_X_WAIT`. Gamma remains signed Q0.15 INT32 and beta remains signed INT32.

The descriptor validator bounds the research mode to opcode `0x38`, ABI 7, flag bit 6, `length=192`, `M=208`, `N=192`, logical row `0..196`, gamma/beta enabled, and its specified auxiliary fields. Flag bit 6 clear preserves the existing linear INT32 path. The added contract is documented as a research extension, not full ABI sign-off.

## Product Top evidence

Command (from `dv/subsystem/top_smoke/sim`):

```bash
make ai_deit_round21_layernorm_row_256k \
  AI_DEIT_R21_RUN=/tmp/nmaforge_v12_r21_deit_lnrow_fix2 \
  AI_DEIT_R21_ROW=1
```

VCS compile and simulation both completed. The test produced:

- `REPRESENTATIVE_MODEL_PASS desc=469 ... golden_words=10176 ...`
- 468 patch-embedding descriptors plus one LayerNorm descriptor.
- 302 late-DMA events, 308,736 payload bytes, 77,184 checked words, all fenced.
- 29,013,376 useful MACs and 30,670,848 physical MACs in the embedding portion.
- Full Top command cycles: 925,701; end-to-end testbench session cycles: 1,416,109. The latter includes testbench/model setup and is not a product software runtime measurement.
- Top performance counters: 4,326,912 SPAD read bytes, 360,192 SPAD write bytes; 81,406 DMA busy cycles overlapped with the 92,012-cycle late-DMA window.
- LayerNorm command: 3,852 cycles; 576 input reads across sum, variance, and output passes; 960 affine reads; 192 writes.
- Golden file SHA-256: `854bd68d462587c73f623ed64d9c440330a683824e67077a29127d9d1e20bfc8` (9,984 embedding + 192 LayerNorm words).
- Independent integer Golden versus checkpoint FP32 LayerNorm for row 1: MAE `0.15312`, RMSE `0.17096`, max abs `0.37057` after dequantization. This is a numerical comparison, not a classification-quality result.

Raw logs and hashes are outside the repository:

- Compile: `/tmp/nmaforge_v12_r21_deit_lnrow_fix2/compile.log`, SHA-256 `bfe466d53d43acc87563209a43df34441e68890a5e57889ca6a0082b11550008`.
- Run: `/tmp/nmaforge_v12_r21_deit_lnrow_fix2/run.log`, SHA-256 `838de759aa0d59097ddbc7950e6a4ccbef93a3b10b4912e1ea14efae5d53fe6f`.
- Workload manifest: `/tmp/nmaforge_v12_r21_deit_lnrow_fix2/workload/manifest.json`, SHA-256 `441382b86d8704ab857e2bfe8b159a401b57254a6e0ca232878daa1c764d117d`.

VCS reported the existing `LOOP-REROLL-ENABLED` warning; the targeted compile/run had no fatal compile or runtime errors. Default 128 KiB `make ai_smoke` also passed after the RTL change. The single-seed SFU randomized-latency regression passed: `cases=64`, `error_cases=9`, `late_faults=1`, abort/watchdog, reset/fault combination and reset recovery all hit; 39 reset and 39 abort FSM states observed; 979 reads/responses and 451 writes checked. Its logs are `/tmp/nmaforge_v12_r21_deit_sfu_regression_20261121/{compile.log,run.log}` with SHA-256 `5c7784d103849acbef76e0806f702342b2471d40d53e231a6f4f000b79ff6083` and `07b609a6db4a3c597322b2a42ee70893244dc4628e0b4dc3f0f4f7c964738eb8`. This tests the existing SFU randomized-latency/fault/reset environment; it does not replace the Product Top LayerNorm row golden.

## Memory and scope

The 256 KiB configuration retains four banks at 16,384 words each. The workload reserves a 40 KiB command/completion ring, places the embedding output at `[179,968, 219,904)`, and reuses the now-dead input/scratch ranges for the row's gamma, beta, and output at `[176,896, 179,200)`. Queue start is 221,184 bytes, leaving a measured 1,280-byte gap after the embedding tensor. Only one LayerNorm row is emitted and checked; this bounded reuse does not imply a full 197-row layer allocation plan.

The new row is consumed from the real Matrix-A packed tensor at `0x2bf04`, then LayerNorm writes to `0x2b900`. No Host-produced embedding or LayerNorm result is written into Product output memory. Host/testbench initializes the starting image and stages DMA payloads, as in the existing workload.

## Gate status

| Gate | Status | Evidence / remaining work |
|---|---|---|
| Full 197×192 Patch Embedding | PASS | 9,984 independent output words matched in the Top workload. |
| Packed Matrix-A → signed H192 LayerNorm input row | PASS | Row 1, 192 output words bit-exact to the independent integer reference. |
| Full 197-row LayerNorm | NOT RUN | Requires a bounded per-row consumer/checkpoint schedule and additional descriptors. |
| QKV projection / real QKV handoff | NOT RUN | No Q/K/V projection descriptor has executed from the RTL LayerNorm output. |
| Attention, FFN, Encoder Layer 0 | NOT RUN | Not reached; Softmax(197), QK/AV, residual, LN2, FFN and GELU remain open. |
| Twelve-layer execution / classification | NOT RUN | No 12-layer schedule or labeled classification test executed. |
| 256 KiB Top regression | PARTIAL | Targeted model passed; default 128 KiB `ai_smoke` passed. No 256 KiB multi-model regression claim. |

## Updated files

- `rtl/compute/sfu/ai_tensor_sfu_core.v`: constrain Matrix-A byte unpacking to LayerNorm input reads so gamma/beta remain INT32.
- `rtl/top/fabric/compute/ai_accel_compute_cluster.v`: route the bounded flag/row inputs.
- `rtl/control/descriptor/ai_descriptor_validator.v`: reject unsupported descriptor combinations.
- `benchmark/deit/round19/generate_deit_full_patch_embedding.py`: append one row's affine parameters, descriptor, and independent Golden.
- `dv/subsystem/top_smoke/sim/Makefile`, `dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv`: reproducible focused Top entry and gated debug trace.
- Three direct SFU testbench instances tie off the added optional inputs.
- `docs/spec/SFU_NUMERIC_CONTRACT_ZH.md`: document the bounded research extension and INT32 affine reads.

No 197-token attention, Encoder Layer 0, 12-layer model, or model accuracy claim is made in this round.

## Final compatibility checks

After the targeted DeiT run, the branch was checked against the frozen legacy H64 autoregressive Top workload. This confirms the new LayerNorm input mode is opt-in and the ordinary H64 path remains operational with the added SFU ports tied off for other direct instances.

H64 command (from `dv/subsystem/top_smoke/sim`):

```bash
make ai_h64_four_layer_top_argmax AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_v12_r21_deit_h64_autoreg \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_H64_FOUR_LAYER_SEED=20261116 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

Result: `H64_AUTOREGRESSIVE_SEQUENCE_PASS generated_tokens=4 total_publications=4020 extension_cycles=4343004 reset_events=0 host_intermediate_words=0 mode=prefix_recompute`. Each of four 256-logit dumps came from Product Top SPAD and passed host argmax comparison. This is a legacy synthetic H64 compatibility regression, not a trained GPT-2 quality result. Compile log SHA-256: `e6c1d7cb1a9fbc59067eefc1c9467b6d56e8a2e60db5884caf1491d4f1f03ad9`; run log SHA-256: `a9fa436d89ca61da53bd84daf2410412c96103eed3e3f7fd0aa2288037cda227`.

The final 128 KiB smoke was also rerun with VCS V-2023.12-SP1, `AI_SEED=20261121`, and four random cases:

```bash
make ai_smoke PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  AI_SEED=20261121 AI_RANDOM_CASES=4
```

It returned `TEST PASS` and all Makefile GEMV, tail, fused forwarding, and CNM profile checks passed. Archived logs: `/tmp/nmaforge_v12_r21_deit_final_smoke/ai_comp.log` SHA-256 `2f26984311ebda2ea1b9ce7245a2cf80138d0078823b3b6f16dbd30caa848338`; `ai_accel_smoke.log` SHA-256 `21aee90292dd9cef91ae7f21a95ae09a521748b779882281089a6ff803ab63e3`.

Verilator 5.052 `--lint-only --timing -Wno-fatal --top-module ai_tensor_sfu_core` completed successfully on the SFU and its divider/sqrt/math dependencies. It reports width expansion/truncation, array-index width, and reserved-word warnings; no claim of warning-free lint is made. Log: `/tmp/nmaforge_v12_r21_deit_vlt_lint.log`, SHA-256 `bd562afa21f5e4d60b6facd9aeaf125ea34d415127df781b9bcea6f27c7971c9`.

The one-row feature still lacks a focused invalid-descriptor matrix and abort/reset/fault injection while the new mode is active. Those tests, full 197-row LayerNorm, and all Encoder operations remain open.
