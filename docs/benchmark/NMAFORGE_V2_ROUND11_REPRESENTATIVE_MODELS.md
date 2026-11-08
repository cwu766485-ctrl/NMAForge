# NMAForge v2 Round 11 — Representative Model Enablement

**Disposition: `PARTIAL` — both requested Top-level model exit criteria remain open.**

- Target branch: `feature/npu-architecture-v2`
- Reviewed source HEAD: `cd7bdd3f01bea4cf35d4768b5335468784df14ec`
- Local isolated work branch: `codex/round11`
- TinyNPU reference (unchanged): `8216c22b762011aa20c05fc2768423fd12dda59d`
- Product RTL: unchanged by this round. The existing RTL snapshot is not represented as newly tested.

## Summary

| Goal | Round 11 result | Evidence boundary |
|---|---|---|
| H=16, two-head, sequence-8 trained Transformer on Top | `BLOCKED_MAPPER_SUPPORT`; Top `NOT_RUN` | Current trainer/mapper reject the requested model contract before descriptor generation. |
| Single-inference ≥100K-MAC CNN on Top | Workload and independent software Golden `PASS`; Top `BLOCKED_ENV` | Reproducible 262,144-MAC 1×1 CNN fits the 128 KiB address range. VCS could not check out a license, so no compile or RTL result exists. |
| Fused/Linear-Row/DMA-overlap runs for the new CNN | `NOT_RUN` | Baseline Top execution did not run; no performance or ablation result is claimed. |
| Existing H=4, Digits and Mini CNN evidence | Preserved, not rerun | Their product/test source paths did not change between the tested snapshot and this reviewed HEAD; prior results are cited below as historical evidence. |

## Baseline and contract audit

The working evaluation started from the clean reviewed commit above in a separate worktree. `main` R250 and the user’s other worktrees were not modified. No product RTL was changed. The checked-in Matrix/Top/SFU RTL, mapper, trainer, and existing top fixture remain the reviewed baseline.

The H=16 limitation is presently a software and fixture limitation, not a demonstrated hardware rejection:

- `sw/tools/train_transformer_micro.py` exposes only output, seed, and training-step options. Its task is a four-symbol cyclic sequence; all six trained matrices are created as 4×4 matrices.
- `sw/tools/cimforge_mapper.py` requires exactly four prefill token IDs in `[0,3]`, a decode token in `[0,3]`, and exactly six 4×4 INT8 matrices. It allocates 4×4 tensors and its decode helper expects a four-row destination. It does not parameterize hidden size, head count, sequence length, head split, masks, or KV layout for H=16.
- Existing Top Transformer checks consume the generated H=4 fixture (86 descriptors); no H=16 descriptor/image/Golden path is present.
- The current descriptor validator permits ordinary Matrix dimensions in multiples of four and bounds opcode `0x52` to M/N ≤16. That does not prove the complete two-head Attention/Softmax/LayerNorm/FFN/Residual/KV graph is implementable with the current Mapper or that its layouts and numeric contracts are correct.

Two diagnostic preflights were run using synthetic 16×16 identity matrices (not a trained model):

```sh
python3.12 sw/tools/cimforge_mapper.py --model-json /tmp/nmaforge_r11_h16_probe.json \
  --svh /tmp/nmaforge_r11_h16_probe.svh --manifest /tmp/nmaforge_r11_h16_probe_manifest.json
python3.12 sw/tools/cimforge_mapper.py --model-json /tmp/nmaforge_r11_h16_probe_4token.json \
  --svh /tmp/nmaforge_r11_h16_probe_4token.svh --manifest /tmp/nmaforge_r11_h16_probe_4token_manifest.json
```

The probe JSON consists of six 16×16 identity INT8 matrices; the first uses eight prefill token IDs, the second four. They are parser-contract probes only.

1. Eight-token prefill stops at `ValueError: trained model prefill_tokens must be four IDs in [0, 3]`.
2. Four-token input with 16×16 weights stops at `ValueError: trained model wq must be a 4x4 INT8 matrix`.

This confirms the earliest mapper contract blockers. No dimension check was removed. No H=16 model was trained, mapped, or run; Prefill, Decode, KV-cache, task quality, and cycle values are all `NOT_RUN`.

## Representative CNN workload

A bounded two-layer pointwise CNN workload was added for the existing production Top CMDQ path:

- Input: `[1,16,32,16]` INT8 tensor (512 spatial positions).
- Layer 1: 1×1 Conv2D, 16→16 channels, ReLU.
- Layer 2: 1×1 Conv2D, 16→16 channels, ReLU.
- Useful work: `2 × 512 × 16 × 16 = 262,144 MAC/inference`.
- Weights: fixed-seed reproducible INT8 inference weights, seed `20261108`; **not trained**, and no classification accuracy is claimed.
- Numeric contract: signed INT8 inputs/weights, scalar INT32 accumulation, shift 0, clamp/ReLU to `[0,127]`.
- Mapping: two ABI-v7 `0x30` Matrix GEMM descriptors and two `0x36` Requant descriptors. No im2col, Host compute fallback, or host-produced intermediate activation is used. The activation is initialized to poison and is expected to be written by the Top descriptor chain.
- Memory: The generated image contains 90,944 bytes of intended AXI preload data (operands, poison destinations, descriptors and completion records); because the Top run did not start, those writes were not actually issued. Address high-water is `0x19240` (102,976 bytes), below 128 KiB by 28,096 bytes. This is an address-fit calculation, not a measured SRAM utilization or timing result.

The generator and separate verifier use only Python’s standard library. The verifier decodes the emitted physical Matrix-A/B layouts, checks descriptor fields/dependencies and 128 KiB bounds, recalculates both INT32 matrix outputs, and compares 20,480 intermediate/final tensor words against the independent Golden image. Result: `REPRESENTATIVE_CNN_OFFLINE_GOLDEN_PASS`. Repeating generation with the same seed produced identical memory-image and Golden SHA-256 values.

| Artifact | SHA-256 |
|---|---|
| Input tensor | `f8514ef62fc2e83230d533ea2c82afb18a8d2b71e7324886679fd814e99561ea` |
| Layer 1 weights | `b780646f65d0247b5972c9125073988315d6ea4c2fe073ea4c1aa63a569b9d89` |
| Layer 2 weights | `b37e120ac1afbc15ffc67c4ddc2f94368901ef0eca8f0120ae2cba6eb846efa0` |
| Expected output tensor | `22cb785cff0275f5cc4bba995800d65350231373effc4723734370b3f4860d5f` |
| SPAD image | `ed38edf71c161d44ddbadf2178aa203f51a09d9122a4e4bff7a6bef1f486d4c1` |
| Intermediate/final Golden image | `9e094fda9315fb86e39d20c084015772aaa21eb1bd1fbeb49d8ee72a59833b9d` |

## Top execution status

The standard Makefile target `ai_representative_cnn` was run with the 128 KiB configuration and seed `20261108`. Workload generation and offline Golden verification passed. VCS `V-2023.12-SP1_Full64` then failed before RTL compilation:

```text
Cannot connect to the license server.
The connect() system call failed.
Failed to obtain license ...
make: *** [Makefile:592: ai_representative_cnn] Error 255
```

Run ID: `R11-TOP-REP-CNN-128K-S20261108`
Run directory: `/tmp/nmaforge_r11_top_cnn_128k_20261108`
Command:

```sh
make -C dv/subsystem/top_smoke/sim ai_representative_cnn \
  AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r11_top_cnn_128k_20261108 \
  AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108
```

Tool: Python `3.12.13`; VCS `V-2023.12-SP1_Full64`. The compile log SHA-256 is `8ddf414eaac7d912684e0a059a38e84d6fa6de129c85ccb447a0b42112aefc8c`. There is no `simv` or `run.log`; no RTL compile, Top Golden, completion, cycle, SPAD engine traffic, matrix utilization, fused ablation, or overlap result was obtained. These fields are intentionally blank in the machine-readable CSV/JSON.

The new TB mode checks pre-run poison, ordered completion IDs/status, every intermediate/final Golden word, exclusive cycle-profile closure, AXI preload cycles/bytes, engine traffic, and Matrix/SFU/DMA busy buckets once VCS is available. The 90,944-byte preload number above is derived from the generated image, not a measured simulation transfer. It has **not** been compiled in this run because the license failure happened before source compilation.

## Historical model baselines (context only; not Round 11 reruns)

The relevant test/product source files were unchanged from the tested tree recorded in the Round 10 report, so these remain prior evidence, not fresh Round 11 runs:

| Model | Historical evidence | Round 11 interpretation |
|---|---|---|
| Trained H=4 one-layer toy Transformer | 640 useful MAC; 86 descriptors; 5,259 Prefill + 5,110 Decode cycles on the optimized path; all emitted tensor/KV checks passed. Four-symbol synthetic task, held-out 690/1008. | Functional small-model baseline only; not representative language-model performance. No H=16 inference or Round 11 rerun. |
| Trained 10-class Digits CNN | 2,736 useful MAC/image; Fused + Linear-Row 2,712 CMDQ cycles/image; 396/396 exact checks; 384/396 classifications. | Correct small-model regression baseline; far below 100K MAC per inference. Not rerun in this license-blocked round. |
| `conv1x_mini.onnx` | Existing paired functional evidence and three-mode ablation are in the Round 10 report. | Remains preserved historical evidence; no new model result. |

Round 10 source/test snapshot: `13f94abf59c3dbea833ad4bbe227ef5cab4df503`; reviewed Round 11 HEAD `cd7bdd3f...` has no differences in the RTL, mapper/trainer, existing top smoke TB, or its Makefile from that snapshot. See `NMAFORGE_V2_ROUND10_ARCHITECTURE_PERFORMANCE.md` for exact hashes and earlier run evidence.

## Reproduction commands

```sh
python3.12 benchmark/representative/generate_pointwise_cnn_workload.py \
  --seed 20261108 --out-dir /tmp/nmaforge_r11_pointwise_cnn
python3.12 benchmark/representative/verify_pointwise_cnn_workload.py \
  --workload-dir /tmp/nmaforge_r11_pointwise_cnn
make -C dv/subsystem/top_smoke/sim ai_representative_cnn \
  AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r11_top_cnn_128k_20261108 \
  AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108
```

The last command currently stops at VCS license checkout in this environment. After a working license is available, rerun that exact command first; only after a Top Golden pass should cycle profiling, Fused/Linear-Row ablation, or overlap be interpreted.

## Open issues and disposition

1. **H=16 Mapper/model support — `OPEN / BLOCKED_MAPPER_SUPPORT`.** A bounded implementation needs dimension-parameterized training/export, hidden/head/sequence tensor allocation, two-head projection/split/merge, causal mask and Softmax lengths, LayerNorm/FFN/residual shapes, KV address/stride handling, independent layer Golden, and a generic Top workload loader. H=4 checks must remain unchanged.
2. **VCS Top functional execution — `BLOCKED_ENV`.** The 128 KiB CNN workload has not reached elaboration. Restore license connectivity and run the Makefile target; a license failure is not a functional failure or PASS.
3. **Large-CNN performance and dataflow — `NOT_RUN`.** No Top cycles or traffic exist, so useful MAC/cycle, Matrix active/idle, stalls, Fused Requant/Linear-Row and overlap benefits are unknown.
4. **Model quality — `NOT_APPLICABLE / NOT_RUN`.** The CNN is a deterministic inference workload, not a trained classifier; H=16 training is not implemented.
5. **TinyNPU comparison — `NOT_RUN_THIS_ROUND`.** No same workload/Top endpoint was produced; no speedup is claimed.

Round 11 therefore does not meet its requested Top-level completion criteria. Existing small-model evidence is preserved; no product RTL change or performance claim was made.
