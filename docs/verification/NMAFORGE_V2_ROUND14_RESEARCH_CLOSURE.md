# NMAForge v2 — Round 14 Research Closure

Date: 2026-11-08
Disposition: **PARTIAL** — P0 AV correctness and P1 CNN output compatibility pass; H16 runs a synthetic one-layer block but does not implement incremental KV-cache progression; no new matched TinyNPU comparison was run.

## 1. Frozen source and measurement boundary

- Reviewed base: `dac3e99aa5a40703ef4cb77ab9f7c9b1690aafa3`.
- Final test/source SHA for the runs below: `ede0ed937b49fea66483d3afc5eff1fca9bd7795`.
- Product RTL tree SHA: `27dba680a250779ee3d95d11381987c9b1dddc11`; no product RTL file changed in this round. Last RTL-changing commit is `13f94abf59c3dbea833ad4bbe227ef5cab4df503`.
- TinyNPU reference remains pinned to `8216c22b762011aa20c05fc2768423fd12dda59d`.
- Simulator: Synopsys VCS `V-2023.12-SP1_Full64`; Python `3.12.13`; WSL2 Linux x86_64. Simulation clock is 10 ns. SPAD is the behavioral four-bank model configured as 128 KiB. No ASIC timing, area, or power claim is made.
- Machine-readable results: [CSV](../../benchmark/representative/round14/round14_results.csv) and [JSON](../../benchmark/representative/round14/round14_results.json).
- Logs and generated model images are in the `/tmp/nmaforge_r14_*_final_ede0_*` directories named below; they are deliberately not committed.

## 2. P0 — H16 AV correctness

### Failure and root cause

The original 47-descriptor attention workload completed every command but failed its first AV output comparison at INT32 address `0x5080`: expected `0xffffff82`, observed `0x00000004`. The failure was reproduced from the reviewed base with seed `20261114` in `/tmp/nmaforge_r14_h16_repro_dac3_s20261114/run.log`.

Before the failing AV command, the testbench captured the INT8 probability tile at `0x5000` and V readback tile at `0x4d80`. Both matched the independent software Golden; the captured dump is `av_inputs_before_desc30.txt` (SHA-256 `86a04b12269f362a733df2730d16ed8b9d76c2f7b9b821039166efd5424daa56`). Replaying those physical inputs through a standalone asymmetric 8×8 Top GEMM passed 64/64 output words. This ruled out the suspected weight transpose / signed-byte / tile-order error for this case.

The failure was caused by an incomplete producer-consumer ordering contract in the generated descriptor sequence. The dispatcher may overlap work from independent engines; AV could observe state without an explicit ordered-retirement dependency from the probability/KV producers. The mapper now adds an ABI event-bit dependency chain: each descriptor after the first waits for and clears the preceding command's event, and each non-final descriptor signals it on ordered retirement. This is a conservative serialization fix in the mapper; **Matrix RTL was not modified**.

### Fixed evidence

| Gate | Result | Evidence |
|---|---|---|
| Non-symmetric 8×8 AV GEMM differential | PASS | `64/64` output words; captured inputs; run in `/tmp/nmaforge_r14_h16_repro_dac3_s20261114/av_actual_diff_run.log` |
| H16 QKV projection | PASS | 3 descriptors, 384/384 Golden words, 6,144 useful MAC, 360 command cycles |
| H16 Attention / KV readback / AV / merge | PASS | 47 descriptors, 1,440/1,440 Golden words, 10,240 useful MAC, 9,010 command cycles |
| Prior QKV behavior | PASS | Re-run at the final test SHA; Q/K/V projection Golden checks pass |

The final attention run used model SHA `431c422a7fa603387d6a557a6be77f33213082323499d3010e734b123b5fced3`, SPAD image SHA `955d2d91a63a265169bfdb6de8002ecb346f90bd789a3a619857ac84343a0cc5`, and Golden image SHA `d6c8ca1a45682a494f42955e3d47dd244733461ce44700f771a36a56ba56daf5`. Log: `/tmp/nmaforge_r14_h16_attention_final_ede0_s20261114/run.log`.

## 3. P1 — CNN double-fused output compatibility

The fixed-seed CNN is a deterministic two-layer 1×1 INT8 inference workload (`[1,16,32,16]`, 512 spatial positions, 16 input/output channels), 262,144 useful neural MAC per inference. Weights are reproducible random INT8 inference weights, **not trained weights**; no classification accuracy claim is made. All candidates use the same seed `20261108`, input, weights, independent scalar INT32/INT8 Golden, and 128 KiB behavioral SPAD.

| Mode | Sequence | Output contract | Commands | CMDQ cycles | Preload cycles | Preload + CMDQ | SFU busy | SPAD read / write | Useful MAC / CMDQ cycle | Golden |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| Legacy | `0x30 → 0x36 → 0x30 → 0x36` | Row-major packed INT8 | 4 | 61,310 | 136,415 | 197,725 | 53,252 | 98,304 / 81,920 B | 4.2757 | 20,480/20,480 PASS |
| First-layer fused | `0x53 → 0x30 → 0x36` | Row-major packed INT8 | 3 | 35,184 | 136,295 | 171,479 | 26,625 | 65,536 / 49,152 B | 7.4507 | 20,480/20,480 PASS |
| Both fused, native layout | `0x53 → 0x53` | Matrix-A tile layout; **not public Row-Major compatible** | 2 | 9,050 | 136,175 | 145,225* | 0 | 32,768 / 16,384 B | 28.9662* | 20,480/20,480 tile-layout Golden |
| Both fused + explicit conversion | `0x53 → 0x53 → 0x30 → 0x36` | Row-major packed INT8 | 4 | 39,686 | 136,799 | 176,485 | 26,625 | 81,920 / 57,344 B | 6.6055 | 20,480/20,480 PASS |

`*` The native Matrix-A case is an internal-layout probe only. Its `145,225` preload-plus-command number and `28.9662` MAC/cycle do **not** represent a compatible completed inference and are excluded from speedup conclusions.

For the compatible first-layer fused candidate, command cycles fall by 26,126 (42.61%, 1.7426×); including the measured preload window they fall by 26,246 (13.27%, 1.1531×). The separate requant pass is removed from the first layer: SFU busy cycles drop by 26,627 (50.00%), while 26,625 cycles remain for the second layer. SPAD read and write traffic drop by 33.33% and 40.00% respectively.

Both fused layers can meet the original output contract only by adding a layout conversion. The implemented conversion reuses dead scratch space, performs an identity Matrix GEMM followed by shift-zero requant, and adds 131,072 physical conversion MACs (50% of the model's useful neural MAC count). Against Legacy, this compatible mode saves 21,624 CMDQ cycles (35.27%, 1.5449×) and 21,240 preload-plus-command cycles (10.74%, 1.1203×). It is **slower than first-layer fusion** by 4,502 command cycles (12.80%) and 5,006 preload-plus-command cycles (2.92%). The experiment does not isolate a conversion-only counter, so the measured `30,636` cycle delta between native two-fused and converted candidates is a whole-sequence difference, not a standalone conversion latency.

All compatible candidates produce the same decoded output digest `6f81ea743327c2b7daa5d4e11e8e2e88848398b99bfaca97d170c570ccc3170e`. Tile Forwarding was not enabled. The measured neural useful-array utilization is 66.67% in the conversion candidate because its extra conversion GEMM occupies Matrix cycles without adding useful CNN MACs; all candidates' Matrix active-cycle counts and detailed counters are in the CSV.

CNN evidence was regenerated at test SHA `ede0ed937b49fea66483d3afc5eff1fca9bd7795` using the `ai_representative_cnn` target. Run IDs and logs:

- `nmaforge_r14_cnn_legacy_final_ede0_s20261108`: `/tmp/nmaforge_r14_cnn_legacy_final_ede0_s20261108/run.log`; Golden file SHA `3751998e65e40ad1ffe03106baf732f9d9c83dfb051ed160dda365e21319b2fc`.
- `nmaforge_r14_cnn_first_final_ede0_s20261108`: `/tmp/nmaforge_r14_cnn_first_final_ede0_s20261108/run.log`; Golden file SHA `65874af21578e6d52699c68577618caf56d75765bebbc9586d6c71ee341ac5bb`.
- `nmaforge_r14_cnn_both_final_ede0_s20261108`: `/tmp/nmaforge_r14_cnn_both_final_ede0_s20261108/run.log`; Golden file SHA `31e1f2f469219b42e513cedbbc19bbc3332d0d560b107999747daffd2d68f86d`.
- `nmaforge_r14_cnn_both_convert_final_ede0_s20261108`: `/tmp/nmaforge_r14_cnn_both_convert_final_ede0_s20261108/run.log`; Golden file SHA `09159d726a7966f17d4ff32c07da5cb15cf3ea2c5e5ea96e72644e4b995a22b1`.

Shared input SHA is `f8514ef62fc2e83230d533ea2c82afb18a8d2b71e7324886679fd814e99561ea`; weight SHAs are `b780646f65d0247b5972c9125073988315d6ea4c2fe073ea4c1aa63a569b9d89` and `b37e120ac1afbc15ffc67c4ddc2f94368901ef0eca8f0120ae2cba6eb846efa0`.

## 4. P2 — H16 Transformer block and decode status

The new reproducible workload uses Hidden=16, 2 heads, head dimension 8, one layer, sequence length 8, signed INT8. Six projection matrices are trained by deterministic integer perceptrons on synthetic token-projection labels. LayerNorm gamma/beta are fixed identity parameters. This exercises a real Top descriptor path with independent software Golden, but it is **not a language model, pretrained model, or model-quality benchmark**.

| Stage | Status | Evidence |
|---|---|---|
| G1 — model/weight export and independent Golden | PASS for synthetic projection task | Model SHA `ea5d2a5bc104d5d6255183133198d0e9193b82decc2d3e35abbe772a1c486810`; all six weight matrices generated from seed `20261114` |
| G2 — Q/K/V projection | PASS | 3 descriptors, 384 Golden words, 6,144 useful MAC, 360 command cycles |
| G3 — two-head QK, causal Softmax, KV V readback, AV, head merge | PASS | 47-descriptor path, 1,440 Golden words, 10,240 useful MAC, 9,010 command cycles |
| G4 — residual, LayerNorm, FFN and output | PASS in full chain | Independently checked in 102-descriptor run |
| G5 — Prefill and single-token Decode | PARTIAL | 70-descriptor Prefill plus 32-descriptor token-7 replay over the populated 8-token KV snapshot; no incremental K/V append, eviction, or multi-step autoregressive progression |

Final H16 run `nmaforge_r14_h16_transformer_final_ede0_s20261114` used model SHA `ea5d2a5bc104d5d6255183133198d0e9193b82decc2d3e35abbe772a1c486810`, SPAD image SHA `fb4ee0cec8070700ddf5cbe3aecf3a63a73dc1c5e4101971e1e8819c934b63f3`, and independent Golden file SHA `bf38ec91a2f005027ef0f66cd85255572a80f465aded936684b302dd8f9f527a`. It passed **3,264/3,264 Golden words** across 102 descriptors. No runtime Host compute fallback is used; training, mapping and Golden generation happen before Top execution.

| Phase | Descriptors | Useful MACs | Command cycles |
|---|---:|---:|---:|
| Prefill | 70 | 14,336 | 21,030 |
| Single-token replay | 32 | 1,280 | 8,578 |
| Combined | 102 | 15,616 | 29,608 |

The Top profiler closes exclusive phase cycles exactly to command cycles. Across the combined run it reports 26,424 SFU busy cycles, 568 KV busy cycles, 264 Matrix MAC-active cycles, 82 Matrix request-wait, 92 response-wait, 456 writeback, 528 other Matrix cycles, and 1,194 no-engine/dispatch-remainder cycles. The active Matrix useful throughput is 0.5274 useful MAC/command-cycle; useful-array utilization over aggregate Matrix MAC-active cycles is 23.11%. SPAD traffic is 22,176 read bytes and 13,120 write bytes; workload preload is 38,087 cycles / 25,392 bytes. Preload plus command is 67,695 cycles, excluding host-side training and workload generation.

The “Decode” phase is a functional replay of token 7 with M=1 Q GEMV and attention over the KV snapshot populated by Prefill. It is not a new-token generation step and does not test cache append/eviction. The model therefore closes the H16 Attention/Residual/LN/FFN computation path but remains **PARTIAL** for production Transformer Decode semantics. The model's synthetic projection training metrics are not a language task accuracy result.

## 5. P3 — TinyNPU comparison

No new Round 14 matched TinyNPU run was completed. In particular, there is no same-endpoint TinyNPU execution of this 262,144-MAC two-layer CNN or the H16 full-block workload. The pinned TinyNPU SHA remains `8216c22b762011aa20c05fc2768423fd12dda59d`. Existing historical GEMM/GEMV and `conv1x_mini.onnx` measurements use different controller, memory, and graph timing boundaries and are not reused here. Therefore this report makes **no cross-project speedup claim**. A matched benchmark still needs identical tensors/quantization, output layout, memory service and timed endpoints on both sides.

## 6. Innovation status, open items, and reproducibility

- **Innovation 1 — Shape-Adaptive GEMV:** the H16 token replay exercises opcode `0x52` for two M=1 Q projections. This round did not compare the same Transformer workload against a GEMM-mapped baseline or Cache/Prefetch toggles; model-level GEMV speedup is **not measured**.
- **Innovation 2 — fused output dataflow:** first-layer fusion gives the best compatible CNN result. Fusing both layers alone is not output-compatible; adding explicit conversion restores Row-Major correctness but loses 12.80% command-window performance relative to first-layer fusion. No Tile Forwarding benefit is claimed.
- Product RTL and main R250 were not changed. No ASIC synthesis, PPA, full DV closure, or 100% coverage claim is made. Prior H4 and Digits results remain untouched; they were not re-run at this SHA.
- The preserved Digits evidence remains the previous fixed run documented in `docs/benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md`: 360/360 exact integer-Golden logits, 352/360 classification (97.78%), 34,761 Top cycles at candidate `33e85287fbf37187fccb76e97be6effe888670e9`. A Round 14 re-run attempt with `AI_DIGITS_PYTHON=python3.12` stopped before VCS because this interpreter has no NumPy (`ModuleNotFoundError: numpy`); it produced no new Digits result. The earlier evidence is retained, not re-certified at this test SHA.
- Remaining Open: incremental H16 K/V projection and cache mutation for new tokens; genuine trained Transformer task/quality; a same-endpoint TinyNPU CNN/Transformer comparison; a model-level GEMV/cache/prefetch ablation; Tile Forwarding; ASIC area/timing/power.

### Reproduction commands

Run from `dv/subsystem/top_smoke/sim` with VCS `V-2023.12-SP1_Full64` and Python `3.12.13`:

```bash
make ai_h16_qkv_top AI_H16_QKV_RUN=/tmp/nmaforge_r14_h16_qkv_final_ede0_s20261114 AI_H16_QKV_PYTHON=python3.12 AI_H16_QKV_SEED=20261114
make ai_h16_attention_top AI_H16_ATTENTION_RUN=/tmp/nmaforge_r14_h16_attention_final_ede0_s20261114 AI_H16_ATTENTION_PYTHON=python3.12 AI_H16_ATTENTION_SEED=20261114
make ai_h16_transformer_top AI_H16_TRANSFORMER_RUN=/tmp/nmaforge_r14_h16_transformer_final_ede0_s20261114 AI_H16_TRANSFORMER_PYTHON=python3.12 AI_H16_TRANSFORMER_SEED=20261114
make ai_representative_cnn AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r14_cnn_legacy_final_ede0_s20261108 AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108 AI_REPRESENTATIVE_FUSION_MODE=legacy AI_REPRESENTATIVE_DESC_COUNT=4
make ai_representative_cnn AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r14_cnn_first_final_ede0_s20261108 AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108 AI_REPRESENTATIVE_FUSION_MODE=first AI_REPRESENTATIVE_DESC_COUNT=3
make ai_representative_cnn AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r14_cnn_both_final_ede0_s20261108 AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108 AI_REPRESENTATIVE_FUSION_MODE=both AI_REPRESENTATIVE_DESC_COUNT=2
make ai_representative_cnn AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r14_cnn_both_convert_final_ede0_s20261108 AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108 AI_REPRESENTATIVE_FUSION_MODE=both_convert AI_REPRESENTATIVE_DESC_COUNT=4
```

The Round 14 changes were committed in order as `66e5877860ba6095298d4f1e0435eb0cfb76794b`, `4092a1aa26081aaf8f8bb0c2a3743d388f19cbd6`, `db18e3082e88a1625efc8c2b84382cf2db4e0bba`, `d5d65760de3031b2181a8da2f22968d97344fe9b`, `b538dfaee4600ab372f421f8b22f4d56f326c353`, `d0f534630dbd225fec36d6c70a9128f9c02d142e`, and `ede0ed937b49fea66483d3afc5eff1fca9bd7795`. The report/CSV/JSON are the final Round 14 delivery; no next round is started.
