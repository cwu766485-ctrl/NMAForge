# NMAForge-V1.2 Round 17 — GPT-2 Closure and DeiT Deployment Preparation

**Disposition: `PARTIAL`**

Round 17 completes a real four-layer H64 autoregressive feedback loop on the Product Top, using deterministic synthetic weights and prefix recomputation. It also starts DeiT-Tiny integration with an official checkpoint, an independent FP32 software reference, and one bit-exact Product Top patch-projection tile. It does not demonstrate trained GPT-2 language quality, full-session end-to-end latency, full DeiT patch embedding, or an encoder layer in RTL.

## Source and environment

| Item | Value |
|---|---|
| Research branch | `research/nmaforge-v1.2-round17` |
| Round 17 test/evidence source commit | `03a15c18f3bd7c3a83fb2d1a63f7eeaa13b321c0` |
| Round 17 branch base | Round 16 commit `c85baa17f457610b7d7de4d6363ad064ae04a8d5` |
| Round 15 ancestor | `995ba340e914d2264b24e1928bcfef09bd675ea3` |
| Product RTL changes | None |
| Simulation | Synopsys VCS `V-2023.12-SP1_Full64` (CLI `V-2023.12`) |
| H64 Python / NumPy | Python `3.12.13`, NumPy `2.4.6` |
| DeiT Python stack | Python `3.12.13`, PyTorch `2.6.0+cpu`, Transformers `4.48.3`, NumPy `2.5.4` |

The active branch is based on Round 16, whose parent is Round 15. The generated planner JSON still labels its inherited planner provenance as Round 15 (`995ba...`); this is not the Round 17 tested-source identifier. The Product Top design sources were unchanged. The changes are confined to the testbench/runtime, workload preparation and verification scripts, benchmark artifacts, and this report.

## Milestone A — H64 four-layer autoregressive inference

| Gate | Status | Evidence and boundary |
|---|---|---|
| A0 — Product Top logits and host Argmax | **PASS** | Four independent 256-element signed INT32 logits vectors were dumped from Product Top SPAD and compared bit-exactly with the independent INT8 Golden. Argmax uses the lowest token ID on ties. |
| A1 — autoregressive feedback | **PASS, prefix-recompute mode** | Prompt `[1,7,42,3]`; generated tokens `[114,162,193,193]`. The same unreset Product Top instance runs all four contexts. Each next token comes from the prior RTL logits. No host hidden/intermediate tensor or KV words are written. |
| A2 — complete session timing | **PARTIAL** | Per-context command/runtime windows are recorded. A single end-to-end interval including all input/embedding publication, all weight DMA/fences, output readback and host feedback was not measured. |
| A3 — trained model and quality | **PARTIAL** | Functional model weights are deterministic synthetic values, SHA-256 `67a89c411254039bab22a7dffc49c64b69233575368503f544ee9f3ec4ab00fc`. There is no training corpus, held-out language metric, tokenizer evaluation, or pretrained-weight claim. |

### Runtime behavior and cycle evidence

The testbench reads real Top logits from SPAD, applies signed INT32 Argmax, then uses the selected token ID only for host embedding/position lookup and prefix input publication. The next run recomputes the complete prefix at the next position (`prefix_recompute`); it is not query-only incremental decoding. The Product Top is not reset between contexts, and prior physical KV state is checked before each replay. Per-stage Product Top checks cover four layer handoffs, layer KV/readback checkpoints, output tensors, and final logits.

| Context checked | Valid input tokens | Emitted token | Descriptor publications | Command/runtime window cycles |
|---:|---:|---:|---:|---:|
| 0 | 4 | 114 | 933 | 1,312,333 |
| 1 | 5 | 162 | 981 | 1,414,584 |
| 2 | 6 | 193 | 1,029 | 1,447,518 |
| 3 | 7 | 193 | 1,077 | 1,480,902 |
| **Total** | — | **4 tokens** | **4,020** | **5,655,337** |

These are command/runtime windows for full-prefix executions, not single-token incremental latency and not complete session end-to-end latency. The average of the four windows is 1,413,834.25 cycles per emitted token in this prefix-recompute experiment; it must not be presented as query-only decode performance. VCS run CPU time was 87.150 s. The testbench reported `reset_events=0`, `host_intermediate_words=0`, and `host_kv_words=0` at the successful sequence marker.

The H64 workload uses the existing 128 KiB, four-bank SPAD profile and a 512-entry descriptor/completion ring. The static allocator reports 78,848 B peak live data and an 82,944 B data high-water mark. Four independent K/V allocations occupy 8,192 B total and retain session lifetimes. This is the static planner proof plus successful Product Top execution of the generated map; it is not a general-purpose software runtime proof.

The first context’s logged preload reports 49 DMA transactions, 50,176 payload bytes, 14,945 setup/transfer cycles, and 16,384 test-only poison-initialization bytes. Per-layer transaction counts in each context are 49, 49, 49, and 67. Those values are retained as phase evidence; there is no single full-session accounting interval that combines every transfer and host phase.

### H64 reproduction

Run from the repository root in the Rocky/WSL VCS environment. Use a fresh output directory because the Make target rejects an existing run directory.

```bash
make -C dv/subsystem/top_smoke/sim ai_h64_four_layer_top_argmax \
  AI_H64_AUTOREGRESSIVE=1 \
  AI_H64_FOUR_LAYER_RUN=/tmp/nmaforge_r17_ar_repro \
  AI_H64_FOUR_LAYER_PYTHON=/tmp/nmaforge_round10_venv/bin/python

/tmp/nmaforge_round10_venv/bin/python \
  benchmark/gpt2_compat/verify_h64_autoregressive.py \
  --run /tmp/nmaforge_r17_ar_repro
```

The recorded run ID is `nmaforge_r17_ar_final12`, seed `20261116`. The compile, run and Python verification logs are retained under [`round17/logs`](../../benchmark/gpt2_compat/results/round17/logs/).

## Milestone B — DeiT-Tiny deployment start

The selected checkpoint is the non-distilled `facebook/deit-tiny-patch16-224` at Hub revision `b3428f18dcc7b543470d07f14b4a4157815d1880`. The imported configuration is ViT image classification: 224×224 RGB, 197 tokens including CLS, hidden size 192, 3 heads, 12 layers, FFN 768, and 1,000 classes. The checkpoint is kept outside the repository; only reference outputs, manifests, a bounded Top workload, and the derived Golden/memory files are committed.

| Gate | Status | Evidence and boundary |
|---|---|---|
| B0 — model import and FP32 reference | **PASS, software only** | Full checkpoint loaded; 5,717,416 parameters. Deterministic synthetic image seed `20261117` produced software patch projection, embedding/position, encoder layer 0, and logits references. No labeled ImageNet input or accuracy claim. |
| B1 — Product Top patch projection | **PARTIAL PASS** | One of 196 image patches and the first 16 of 192 output channels; 12,288 useful MACs. Product Top produced 256 physical INT32 words matching an independent scalar INT64 GEMM Golden bit-exactly. |
| B2 — full patch embedding and encoder layer | **NOT_RUN** | Position/CLS addition, all patch/output tiles, requantization, attention, FFN and encoder output are not integrated in Product Top. |
| B3 — 128/256 KiB execution comparison | **PARTIAL, static estimate only** | No 256 KiB Product Top configuration was run and no RTL liveness/DMA schedule was proven. |

The Product Top tile result is 2,442 command cycles, 768 Matrix MAC cycles, 24,576 SPAD read bytes and 1,024 SPAD write bytes. The testbench preloaded 25,680 SPAD bytes through AXI-Lite in 38,519 cycles; `end_to_end_cycles=40,961` is only this testbench preload plus the one tile command, with `dma_preload_included=0`. It is not a model-level DMA or inference latency. Useful throughput was 5.0319 MAC/cycle and useful array utilization was 6.25% because most physical tile work was padding. Dequantized projection comparison against the FP32 subset reports MAE 0.004956, RMSE 0.006787 and maximum absolute error 0.016858; this is a one-tile diagnostic, not a full INT8 model accuracy result.

Checkpoint SHA-256: `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c`. The input is a deterministic synthetic RGB pattern, SHA-256 `d2029eee4ae0be2479a662a7ed549836200929b41987d23caa68d924f0c89f0a`; it has no classification label or accuracy claim. Weight-only symmetric INT8 quantization is explicitly an estimate and is not asserted to match the NMAForge integer contract.

### DeiT software reference and Top reproduction

The reference environment is described in `benchmark/deit/round17/requirements.txt`. The checkpoint should be fetched at the pinned revision into a local directory; it is intentionally not checked in.

```bash
/tmp/nmaforge_deit_round17_venv/bin/python \
  benchmark/deit/round17/run_deit_tiny_reference.py \
  --model-dir /tmp/nmaforge_deit_round17 \
  --out-dir /tmp/nmaforge_deit_round17/reference

make -C dv/subsystem/top_smoke/sim ai_deit_patch_projection_top \
  AI_DEIT_PATCH_RUN=/tmp/nmaforge_deit_patch_repro \
  AI_DEIT_MODEL_DIR=/tmp/nmaforge_deit_round17 \
  AI_DEIT_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python
```

The recorded Product Top run ID is `nmaforge_deit_patch_round17_v1`, seed `20261117`. VCS emitted the existing testbench `Warning-[LOOP-REROLL-ENABLED]`; compilation completed and the run produced the Golden PASS marker. It is retained verbatim in [`DeiT logs`](../../benchmark/deit/round17/results/logs/).

The static capacity estimate counts 255,872 B for its selected schedule: this does not fit in 128 KiB (124,800 B over). It nominally fits in 256 KiB with only 6,272 B headroom. Because this is a planning estimate without Product Top address propagation, DMA execution, liveness checks or PPA, it is not evidence that a 256 KiB design is ready or that the 128 KiB model can be tiled successfully. No capacity parameter was changed in Product Top.

## Regressions and evidence integrity

| Check | Result |
|---|---|
| H64 four-layer autoregressive Top compile/run | **PASS** |
| Independent H64 logits/Argmax verifier | **PASS, four contexts bit-exact** |
| Default `ai_smoke` | **PASS** |
| `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | **PASS** |
| Python source AST and retained JSON parsing | **PASS** |
| `git diff --check` on source changes | **PASS** |

Original VCS logs and CSV bytes are preserved. A repository-wide whitespace scan also flags tool-generated trailing spaces and CRLF line endings in raw VCS logs/CSV; those files were not normalized so their recorded hashes continue to identify the original run artifacts. The DeiT compile log contains the existing loop-reroll diagnostic, not an RTL change warning.

Key SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| H64 synthetic model | `67a89c411254039bab22a7dffc49c64b69233575368503f544ee9f3ec4ab00fc` |
| H64 autoregressive result JSON | `30b1f6a80313fd4a45b4cb024d1bfa9b1b52fddef94db7977d5d9e609c2a2d62` |
| H64 VCS compile log | `7f4c183f33dffbeb4c230fef73aa9d56465193da95ac7dd73934480c672b21ec` |
| H64 VCS run log | `c77c585fe1f92dcf1adc31facc318f33a6237f6b855648c4e7e58857cc7bcbf2` |
| H64 verifier log | `96342f6e46b7234fdb454d376650ee79d1df2a2e61188f9a8d3344cd02b58d9d` |
| DeiT checkpoint | `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` |
| DeiT FP32 reference NPZ | `cc0d0f74639a7c101476ad7a4742ff9a80b715f8b00a9dda35fbd889cc5b3b35` |
| DeiT Top compile log | `b9d6510cb9648f292fca47cf623f3371d0226ae3234d22be270a92140eea75be` |
| DeiT Top run log | `de2b42aa744059c49aa3fac6bd934c369676947ddd954900fff14f9814256d14` |

The full artifact hash catalog and machine-readable gate summary are [`round17_evidence_summary.json`](../../benchmark/gpt2_compat/results/round17/round17_evidence_summary.json). The four per-context Product Top logit dumps, SPAD allocation map, planner manifest, DeiT reference NPZ, workload memory/Golden files, and complete compile/run logs are checked in alongside it.

## Remaining work

- **GPT-2:** Replace synthetic functional weights with traceable trained/imported weights and a quality metric; separately measure a complete host-to-host session; optimize query-only decode only after this baseline.
- **DeiT:** Build complete 196-patch embedding, position/CLS path, then one actual Top encoder layer with an agreed INT8 numeric contract and full tensor Golden. Rework/query blocking before treating the current 256 KiB static fit as viable.
- **System:** The existing Product Top was not changed, and this round ran no new ASIC synthesis/PPA, broad DV closure, or TinyNPU comparison.

No Product Top RTL, main branch, private PDK, SRAM library or license material was modified or committed.
