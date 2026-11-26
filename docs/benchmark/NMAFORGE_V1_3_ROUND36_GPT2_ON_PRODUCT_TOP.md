# NMAForge V1.3 Round 36 — Official GPT-2 Small on Product Top

**Disposition: `GPT2_SMALL_12_LAYER_PREFILL_AND_DECODE_PRODUCT_TOP_PASS`, bit-exact.**

The official `gpt2` checkpoint (124M, 12 layers, D=768, 12 heads) runs as
compiler-generated programs on Product Top with 512 KiB SPAD:

- **Prefill.** All 12 decoder blocks for a 32-token WikiText-2 prompt.
- **Decode.** Prefill of a text prompt followed by greedy KV-cache decode
  steps, all 12 blocks, with the K/V caches in DDR.

Every block output and the final residual rows match the independent integer
Golden. Weights stream from DDR through the production AXI DMA, and no host
data is written into SPAD.

The token embedding (wte + wpe) and the final LN + LM head run on the host.

## Commands

From the repository root, with a Python environment that has torch,
transformers, safetensors and pyarrow. The evidence programs used
`OMP_NUM_THREADS=8` (g0, g12) and `OMP_NUM_THREADS=4` (gd1, gt12).

```bash
# 12-layer prefill, 32 WikiText-2 tokens (+ integer PPL on 40 x 256 windows)
python sw/compiler/gpt2_compile.py --model-dir <gpt2 snapshot> \
  --wikitext <wikitext-2-raw-v1/test-00000-of-00001.parquet> \
  --layers 12 --tokens 32 --ppl-windows 40 --out /tmp/nmaf34/g12
make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/nmaf34/g12 \
  AI_COMPILED_AXI_WORDS=25165824

# 12-layer prompt prefill + 8 greedy decode steps
python sw/compiler/gpt2_compile.py --model-dir <gpt2 snapshot> --wikitext <parquet> \
  --layers 12 --prompt "Alan Turing was a British mathematician who" --decode-steps 8 \
  --out /tmp/nmaf34/gt12
make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/nmaf34/gt12 \
  AI_COMPILED_AXI_WORDS=25165824
```

Notes:

- `AI_COMPILED_AXI_WORDS` sizes the TB AXI model. The default is 8 MiB, and a
  12-layer image is about 89 MB.
- `AI_COMPILED_SIM_ARGS=+AI_COMPILED_SEG_TIMING` prints per-segment compute
  cycles.
- Program directories must use short paths, because the TB stores file paths in
  128-character registers.

## Results

| Run | Descriptors | Segments | DMA loads / stores | Checked words | Compute window | Fenced DMA | VCS wall |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 layer, prefill 32 (debug checkpoints) | 984 | 74 | 207 / 0 | 65,536 + 24,576 | 8,799,646 | 1,429,362 | 2.5 min |
| 1 layer, prefill 32 + 4 decode (debug) | 2,564 | 435 | 1,144 / 120 | 91,136 + 3,072 | 16,289,467 | 7,215,078 | — |
| **12 layers, prefill 32** | 11,860 | 888 | 2,473 / 0 | 319,488 + 24,576 | **106,555,776** | 16,944,774 | 39.5 min |
| **12 layers, prompt 7 (8 rows) + 8 decode** | 43,473 | 9,396 | 24,706 / 2,592 | 399,360 + 3,072 | **212,172,570** | 154,728,642 | 100.9 min |

In the 12-layer decode run, the per-segment timing (`+AI_COMPILED_SEG_TIMING`)
splits the compute window into the 8-row prompt prefill (32,699,946 cycles)
and eight decode steps of 22.42M–22.44M cycles each (about 1.87M per block).
Fenced DMA averages about 17.2M cycles per pass, so one decode token costs
about 40M cycles (160 ms at 250 MHz) end to end.

The debug checkpoints cover LN1 packing, the K cache, Vᵀ, Q·Kᵀ scores, the
causal Softmax (zero-padded to KMAX), AV, the attention residual, LN2,
LUT-GELU and the block output.

**Generation (12-layer decode run).** The prompt "Alan Turing was a British
mathematician who" continues with the integer model's greedy tokens:

- **Integer model:** " was born in 1859 in the town of".
- **FP32:** " was the first to discover that the universe is".

The integer continuation (24 steps in the Golden) is: " was born in 1859 in
the town of Walthamstow. He was a member of the Royal Society of London". The
NPU program reproduces the integer Golden bit-exactly. Divergence from FP32
greedy decoding is expected under INT8 PTQ, so quality is measured by
perplexity.

## Accuracy (integer model = Product Top arithmetic)

WikiText-2 test set, 40 non-overlapping 256-token windows, calibrated on 8
disjoint windows from the tail of the test split:

| Model | FP32 PPL | Integer PPL | Gap | Round 35 study best (g16 scales) |
|---|---:|---:|---:|---:|
| gpt2 (124M) | 50.56 | **55.94** (55.89 with the OMP=4 calibration) | +10.6% | 56.37 |
| distilgpt2 | 75.22 | **83.43** | +10.9% | 78.56 |

On every evaluated layer, LN post-gamma saturation is 0 and the accumulator
peak stays below 2^30.

## Compiler: `sw/compiler/gpt2_compile.py`

**Numeric contract.** The Round 35 deployment contract, with these additions
for GPT-2:

- **SmoothQuant (alpha 0.5).** Folded into the LN gamma/beta encoding for
  c_attn and c_fc, and into the V columns for the attention c_proj. The V bias
  is folded into the c_proj bias.
- **LN rounding offset.** LN uses a rounding offset with `LN_RB = 4`. The
  residual stream is INT32 at 2^-8.
- **Power-of-two weight scales.** There is one scale per head for the
  Wq/Wk/Wv/Wo slices and one per 64-column FF chunk for W1/W2. Q is pre-scaled
  by log2e/8, so scores are Q8.8 log2-domain.
- **Common accumulator grid.** Wo and W2 partials accumulate on a common grid
  2^E. The final `ACC >> s` is one `RESIDUAL(ACC, ACC, s+1)`. When the
  products are coarser than the residual grid (layer 11 after SmoothQuant), a
  negative `s` becomes `-s` exact doublings `RESIDUAL(ACC, ACC, 0)`; no weight
  clipping is needed.
- **Rounding and activations.** Probabilities are rounded to Q7 (REQUANT
  flags[7]). gelu_new uses a per-chunk 256-entry LUT (SFU flags[7]). Causal
  attention uses `CAUSAL_SOFTMAX_Q15` (0x39) with `aux0` set to the absolute
  position.

**Schedule.** One decoder block runs over rows `pos0..pos0+T-1`:

- **Prefill** covers all prompt rows, padded to a multiple of 4 with zero
  rows.
- **Decode** covers the 4-token group holding the new token. The Matrix row
  granule is 4. Earlier rows of the group are recomputed bit-identically from
  their embeddings, so no hidden state is stored between steps.

**KV cache.** It lives in DDR. Each layer and head has:

- a packed-A K cache [KMAX, 64];
- a packed-A Vᵀ cache [64, KMAX], which is the Matrix-B layout of V.

At KMAX = 64, the two caches total 8 KiB per head. Per head:

1. Load cached K rows `< pos0`.
2. Pack new K rows straight into the SPAD K cache.
3. Write the new Vᵀ columns to DDR with one 2D DMA store (16 rows at stride
   KMAX·4), then load the whole Vᵀ cache back.
4. Run AV at K = KMAX, with probabilities zero-padded beyond the current
   length.
5. Store the new K rows back.

Because AV always runs at K = KMAX, the cache layout never depends on the
current length.

**Long RESIDUALs.** They are split into 8-row (6,144-element) chunks. One
24,576-element RESIDUAL exceeds the dispatcher's 65,535-cycle dependency-wait
limit for its successor, which reports `ERR_DEPENDENCY` (status 0xc2).

**SPAD.** High-water is 493,312 B (prefill 32) of the 503,808 B below the
queue rings. The attention and FFN scratch share one union region.

## Runtime / TB changes

- **Program format v2.** Each DMA entry is `(ext, spad, store<<31 | row_words,
  row_count, ext_stride, spad_stride)`. Entries can be 1D or 2D, and loads or
  stores. The TB still accepts v1, and the Round 35 DeiT layer-0 program
  replays with identical cycles (3,126,609).
- **TB options.** `AI_COMPILED_AXI_WORDS` (macro and Makefile variable)
  sizes the AXI model. The `+AI_COMPILED_SEG_TIMING` plusarg prints
  per-segment timing. `COMPILED_PROGRAM_PASS` now reports `dma_stores`.
- **intops.** New `causal_softmax_rows` (0x39 model).

## Performance analysis (cycles at 1 cycle = 4 ns @ 250 MHz)

| Block part | Prefill 32 rows | Decode (4-row group) |
|---|---:|---:|
| LN1 + LN2 (D=768 rows use the legacy SFU path, >256-entry cache) | 1.01M | 0.13M |
| Attention (12 heads incl. 11 partial accumulations) | 2.00M | 0.49M |
| FFN (48 chunks incl. 47 partial accumulations) | 5.66M | 1.23M |
| **Block compute** | **8.82M** | **1.87M** |
| Fenced weight DMA per block (stress AXI model) | 1.43M | ~1.45M |

Where the time goes:

- **Prefill.** About 4.3M of the 8.8M cycles is partial-sum RESIDUAL
  accumulation. Each element costs 3 SPAD accesses (2 reads + 1 write)
  through one port. GEMM cannot accumulate into its destination, and its
  `dst_stride` is a batch stride, not a row pitch, so output-column tiling
  with full-K reduction is not expressible.
- **Decode.** M=4 GEMMs use a quarter of the 16×16 array. The weight DMA
  (7.4 MB per block per token) is host-fenced and not overlapped with
  compute. Decode is about 40M cycles per token for 12 blocks.

Co-design targets this points to, matching the planned order:

1. DMA descriptors in CMDQ with compute overlap and coalescing. Decode
   streams 85 MB of weights per token.
2. A GEMM accumulate/residual epilogue (C += A·B, X += A·B). It removes all
   partial-sum RESIDUALs and the final X += Y.
3. INT4 weight-stream GEMV (0x52 path) for M ≤ 16.
4. An LN fast path for D > 256: larger row cache or two-pass streaming.

## Limits / open

- **Host-side stages.** The embedding and the LM head (38.6M MACs per token,
  about 0.3× of one block) run on the host.
- **Context length.** KMAX = 64 tokens in the demonstrated programs. The
  compiler accepts larger KMAX. SPAD use grows with T·KMAX through the PR, SC
  and P8 buffers.
- **Weight scales.** Coarser than the per-16-column study, which explains
  the remaining distilgpt2 gap (83.4 vs 78.6).
- **Evidence scope.** RTL evidence is single prompts. PPL comes from the
  bit-exact integer model, not from dataset-scale RTL runs.
- **Calibration determinism.** It uses FP32 PyTorch percentiles. A different
  thread count changes float summation order. With 8 and 4 threads the shift
  tables are identical, but some SmoothQuant-scaled integer weights differ by
  rounding (PPL 55.94 vs 55.89). Each program is self-consistent with its own
  Golden, and the manifest records `torch_threads` for new runs.
