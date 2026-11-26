# NMAForge V1.3 Round 35 — Official DeiT-Tiny Encoder on Product Top

**Disposition: `DEIT_12_LAYER_PRODUCT_TOP_PASS`, bit-exact.**

All 12 encoder layers of `facebook/deit-tiny-patch16-224` ran as one
compiler-generated program on Product Top:

- Pinned checkpoint `e1a51b0c…`; input is an ILSVRC2012 validation image from
  Imagenette class 0.
- 512 KiB SPAD; weights stream from DDR through the production AXI DMA.
- The program is 16,128 ABI-v7 descriptors in 324 segments with 553 DMA loads.
- Every layer output (491,712 checkpoint words) and the final 197×192
  residual stream (37,824 words) match the independent integer Golden.
- No host data was written into SPAD.

The patch embedding and the classifier head (final LN + linear) still run on
the host. With the bit-exact final residual stream, the predicted label (0)
matches the ground truth.

## Commands

From the repository root:

```bash
PYTHONPATH=<pylib with torch, pillow> python sw/compiler/deit_compile.py \
  --checkpoint <deit-tiny pytorch_model.bin> --val-dir <imagenette2-320/val> \
  --layers 12 --check layer --out /tmp/nmaf34/d12
make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/nmaf34/d12
```

The TB stores file paths in 128-character registers, so the program
directory must use a short path. The accuracy model is the same script with
`--accuracy <images per class>`.

## Results

| Run | Descriptors | Checked words | Compute window | Fenced DMA | Descriptor staging | VCS CPU |
|---|---:|---:|---:|---:|---:|---:|
| Layer 0 (debug checkpoints) | 1,344 | 78,800 + 37,824 | 3,126,609 cycles | 576,354 | 129,024 | 96 s |
| **12 layers** | 16,128 | 491,712 + 37,824 | **37,519,308 cycles** | 6,592,722 | 1,548,288 | 1,904 s |

- At the 250 MHz synthesis target, the 12-layer compute window is 150 ms.
- The DMA figure is pessimistic. It uses the TB protocol-stress AXI model
  (at most one R beat per two cycles) and per-block host fences.
- Each FFN row block re-streams W1/W2, about 34 MB of DMA in total. That is
  the target of the next step (DMA in CMDQ with overlap and coalescing).
- SPAD high-water: 493,952 B of the 503,808 B below the queue rings.

Integer accuracy model, which is the same arithmetic as the Product Top
program, on 500 Imagenette images: **75.6% top-1 vs FP32 78.0%**.

## Compiler and runtime

**`sw/compiler/nmaf/intops.py`** holds bit-exact numpy models of GEMM,
REQUANT (floor or rounded), LUT activation, RESIDUAL, LAYERNORM_Q15, exp2
Softmax and the Matrix-A/B layouts. The layouts are checked against
`cimforge_mapper`.

**`sw/compiler/nmaf/program.py`** builds the program:

- SPAD allocation, with attention and FFN scratch sharing one union region;
- the DDR image;
- DMA + descriptor segments of at most 255 descriptors;
- the completion-event chain;
- checkpoints and the output files.

**`sw/compiler/deit_compile.py`** handles calibration, power-of-two INT8
quantization and the per-layer schedule:

- **LN.** One LN per valid row into a 4-row temp, then REQUANT-pack.
- **Q/K.** Q and K per head with log2e/√64 folded into Wq, so scores are
  Q8.8 log2-domain.
- **V.** Vᵀ comes from a transposed GEMM whose B operand is the packed X.
- **Attention.** 40-row query blocks:
  - S = Q·Kᵀ;
  - Softmax over 197 keys;
  - REQUANT to Q7 with flags[7] rounding;
  - AV;
  - head-concat packing.
- **Output projection.** The V bias is folded into the Wo bias. Wo blocks
  feed an in-place RESIDUAL.
- **FFN.** 24-row blocks: FC1, then LUT GELU fused with Matrix-A packing
  (SFU flags[7]), then FC2, then RESIDUAL.

The Matrix-B layout of Mᵀ equals the Matrix-A layout of M, so no repack
opcode is needed.

**TB `+AI_COMPILED_PROGRAM` runtime.** For each segment it runs the fenced
DMA loads, stages descriptors into the ring, publishes them with one
TAIL/doorbell, compares completion records and checkpoints through the
passive SPAD backdoor at retirement, and checks the final words at the end.
It uses an 8 MiB AXI model and the long-task SVA limit.

## Limits / open

- **Host-side stages.** The patch embedding (2.3% of MACs) and the classifier
  head run on the host.
- **Weight scales.** Per-tensor power-of-two weight scales explain most of
  the gap to the per-16-channel study (77.2%). Per-16-column scales need
  column-tiled GEMMs with row-pitched outputs, or per-channel compensation.
- **DMA scheduling.** DMA is host-fenced between segments. W1/W2 are
  re-streamed per FFN block.
- **Evidence scope.** One full-image Product Top run, not a dataset-scale RTL
  run. Accuracy comes from the bit-exact integer model.
