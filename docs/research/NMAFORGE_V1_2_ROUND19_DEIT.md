# NMAForge-V1.2 Round 19 — Track B: DeiT-Tiny Patch Embedding

## Result

**Track disposition: `PARTIAL`.** The complete 196-patch × 192-channel patch projection, CLS/position addition and INT8 requantization ran on the 256 KiB Product Top. All 468 descriptors retired successfully and all 9,984 golden words matched. This is the first full Patch Embedding path; it is **not** an Encoder Layer, ImageNet classification, or full DeiT inference.

## Fixed model/input and numerical contract

- Research branch base: `research/nmaforge-v1.2-round19-deit`, based on Round 18 `0e54224510a24e316674df7fa50262ccf2b46429`.
- Tested implementation source commit: `0a1d7545d84de6f8c3a771c3764c0a3616fc8d2f`.
- Checkpoint: `facebook/deit-tiny-patch16-224`, revision `b3428f18dcc7b543470d07f14b4a4157815d1880`.
- Checkpoint SHA-256: `pytorch_model.bin=e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c`; config and processor hashes are in the machine-readable manifest.
- Input is a deterministic synthetic RGB fixture processed by the official image processor. Input image SHA-256 `d2029eee4ae0be2479a662a7ed549836200929b41987d23caa68d924f0c89f0a`; processed pixel SHA-256 `028bcacc0b989481a9e7b1fb119974605721e2cc063a76d1dd1b248d088f9b88`. No classification accuracy is claimed.
- Shape: 196 patches, 768 input features, 192 output channels; 197 logical tokens after CLS; physical tiles pad to 208 rows.
- INT8 input and weights use symmetric round-to-nearest-even saturation. Product requantization uses opcode `0x36`, arithmetic right shift 13 and signed INT8 saturation without rounding. Bias/CLS/position correction is rounded into INT32 accumulator units. Full parameters and FP32 comparison are in `benchmark/deit/round19/evidence.json` and the external workload manifest.

## Gate results

| Gate | Status | Evidence |
|---|---|---|
| B0 — 256 KiB Product Top + queues | **PASS** | VCS elaborated with `AI_SPAD_WORDS_PER_BANK=16384`; 4 × 16,384 × 4 B = 262,144 B. 512-entry CMDQ/CPLQ reserve 40,960 B. Data high-water 219,904 B, descriptor queue starts at 221,184 B, leaving a checked 1,280 B gap. |
| B1 — full Patch Embedding | **PASS** | 156 16×16 macro tiles × (GEMM, residual correction, requant) = 468 Product descriptors. All 468 completions retired; 9,984 golden words matched. CLS and all 196 patch rows are present. |
| B2 — full 197-token Encoder Layer 0 | **NOT_RUN** | No Product-generated QK → full-row Softmax → AV chain, three-head attention, LayerNorm, output projection, FFN/GELU or residual layer was exercised. The earlier synthetic one-row Softmax probe is not used as evidence for this gate. |
| B3 — 12 layers/classifier | **NOT_RUN** | Correctly gated on B2. |

## Product Top execution and accounting

The 12 official-checkpoint weight tiles were fetched as 144 DMA chunks (256 words each, 147,456 B). The 156 position/CLS correction tiles were fetched as 156 DMA events (1,024 B each, 159,744 B). Total late DMA payload was 307,200 B across 300 fenced events, 1,200 AXI read bursts and 19,200 read beats. Every DMA event completed and its SPAD destination was checked against external memory before the dependent descriptor was published.

| Metric | Result |
|---|---:|
| Useful / executed / padding MACs | 28,901,376 / 30,670,848 / 1,769,472 |
| Product command window | 921,283 cycles |
| Command cycles excluding explicit late-DMA windows | 829,747 cycles |
| Late-DMA setup/transfer windows / DMA busy | 91,536 / 81,000 cycles |
| Full measured Top session through completion and output readback | 1,409,279 cycles |
| Late-DMA output/completion readback portion | 65,520 cycles |
| Useful MAC per command cycle | 31.3708 |
| Reported useful array utilization | 94.23% |
| SPAD reads / writes | 4,323,072 / 359,424 B |
| Host AXI-Lite fixture bytes / test-only poison bytes | 241,664 / 51,200 B |

These are VCS Product Top cycle-counter results at a 10 ns test clock, not wall-clock runtime, ASIC frequency, or post-layout performance. The full Top session includes fixture setup, scheduled DMA, command execution and output readback; it excludes Python image preprocessing/checkpoint loading. The test-only poison/sentinel traffic is separately identified and is not called production payload. The output is 16×16 macro-tile-major with local Matrix-A packing, not a contiguous row-major tensor contract for a later encoder consumer.

The integer output is compared with an independent Integer projection Golden for every physical output word. The same 197×192 output compared with the official FP32 embedding has MAE `0.0756258`, RMSE `0.0874820`, and maximum absolute error per token max `0.183940` after dequantization. This is a one-image numerical comparison, not task quality.

## Reproduction

Environment: VCS `V-2023.12-SP1_Full64`; Python 3.12.13; NumPy 2.5.4; PyTorch 2.6.0+cpu; Transformers 4.48.3. The official checkpoint and processor are under `/tmp/nmaforge_deit_round17` and are not committed.

```bash
make ai_deit_round19_full_patch_embedding_256k \
  AI_DEIT_R19_RUN=/tmp/nmaforge_deit_r19_top_002 \
  AI_DEIT_R19_PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
  AI_DEIT_R19_MODEL_DIR=/tmp/nmaforge_deit_round17
```

Also run the existing smoke after the focused test:

```bash
make ai_smoke
```

Run IDs and external raw logs:

| Run ID | Result | Compile log SHA-256 | Run log SHA-256 |
|---|---|---|---|
| `R19-B-FULL-PATCH-EMBEDDING-256K-20261117` | 468/468 descriptors, 9,984/9,984 golden words, 300/300 DMA events PASS | `b62dba21268cfeacc060d720d68eb1a1bca18930886adfd676d8534b4cb39b6a` | `b540bd83306df4943025a5e6487cc24e1adf313850f4c15e5f60408fa9f613fb` |
| `R19-B-TOP-SMOKE-20261117` | `TEST PASS`, 4 random cases plus existing directed checks | `810a85ab00d30019199817f8c11fc020173e3f3b18e4b6f6ad68b6df140af48e` | `1dc02286a606c6f57d74bba9566206439cdd27b40367a4b4e58d441dd949ca77` |

Full compile/run files are `/tmp/nmaforge_deit_r19_top_002/compile.log`, `/tmp/nmaforge_deit_r19_top_002/run.log`, and the smoke logs under the branch's ignored `dv/subsystem/top_smoke/sim/`. VCS emitted the existing `LOOP-REROLL-ENABLED` informational warning for `ai_transformer_workload.svh`; no compile error occurred. The focused run's Make checks verified all 468 retirements, all 300 DMA events and the exact final PASS counters.

## Changes and remaining work

- Added a reproducible full-patch workload generator using the pinned official checkpoint and independent integer Golden.
- Extended the Top testbench only for this bounded streaming workload: larger test AXI memory, a bounded late-DMA event plan, a DMA completion fence and SPAD readback check before publishing each consuming descriptor. No Product RTL or ABI changed.
- Expanded `dv/subsystem/top_smoke/sim/Makefile` with the focused 256 KiB target.
- The next DeiT gate requires true QK-generated scores, valid 197-key normalization, AV and the rest of Encoder Layer 0. The tile-major output format and global numeric scaling must be agreed with that consumer before claiming layer integration.
