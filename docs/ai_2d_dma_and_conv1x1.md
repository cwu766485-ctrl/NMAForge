# 2D DMA and INT8 CONV1x1

## 2D DMA

The original `DMA_LENGTH` path remains the compatibility mode: when
`DMA_ROW_COUNT=0`, one contiguous `DMA_LENGTH`-word transfer is issued.

When `DMA_ROW_COUNT` is non-zero, DMA transfers a rectangle of
`DMA_ROW_COUNT × DMA_ROW_WORDS` 32-bit words.  `DMA_EXT_STRIDE` and
`DMA_SPAD_STRIDE` are byte distances between row starts.  A zero stride means
the contiguous row width (`DMA_ROW_WORDS * 4`).  Every row reuses the existing
AXI INCR burst machinery, including the maximum-burst limit, 4KB split, AXI
response handling and back-pressure support.

| Offset | Register |
|---:|---|
| `0x104` | `DMA_ROW_WORDS` |
| `0x108` | `DMA_ROW_COUNT` |
| `0x10C` | `DMA_EXT_STRIDE` |
| `0x110` | `DMA_SPAD_STRIDE` |

All addresses and strides must be 32-bit aligned.  Region-protection checks
remain active on every scratchpad beat.

## `OP_CONV1X1_INT8` (`0x13`)

The first convolution operator uses a deliberately compact NHWC-flattened
contract and reuses the GEMM tile dataflow:

```text
M       = H * W              (number of spatial positions)
N       = Cout               (output channels)
K_WORDS = ceil(Cin / 4)      (packed INT8 input channels)

src0[M][K_WORDS] = NHWC input pixels
src1[N][K_WORDS] = output-channel weights
dst [M][N]       = INT32 output pixels/channels
```

For each `(pixel, output_channel)`, hardware computes the packed INT8 dot
product over `K_WORDS`, then uses the existing scale-shift, ReLU and INT32
saturation path.  `GEMV` and `GEMM_INT8_TILE` retain their original op codes
and layout; this is an additive interface extension.
