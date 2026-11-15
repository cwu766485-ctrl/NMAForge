# Round 12 Research ABI: QK-Compatible KV Append

## Status

Research-only extension on `research/nmaforge-v1.2-round12`. This is not part
of the product ABI and must not be merged into the product branch without a
separate ABI review. Existing opcode `0x43` modes and opcode `0x44` retain their
existing behavior.

## Descriptor Contract

`KV_WRITE (0x43)` with `flags=0x02` and descriptor version 6 appends one packed
INT8 K token directly into the physical Matrix-B layout consumed by QK. The
descriptor fields are:

| Field | Requirement |
|---|---|
| `length` | 4, 8, 12, or 16 INT8 features |
| `src0_stride` | 16 bytes between packed feature-group source words |
| `src1_stride` | Per-head cache byte span, divisible by `length` |
| `src1_stride / length` | Token capacity 4, 8, 12, or 16 |
| `aux0[15:0]` | Token index, less than token capacity |
| `aux0[31:16]` | Head index |
| `dst_stride` | Zero |

The source points at a Matrix-A packed K row. For `g=0..length/4-1`, the KV
engine reads one 32-bit source word at `src0 + 16*g`. It writes that word at

```text
word_index = (((token_index >> 2) * (length >> 2) + g) << 2)
             + (token_index & 3)
destination = dst + head_index * src1_stride + 4 * word_index
```

The four source bytes remain in feature-lane order. This is the Matrix-B
physical packing of `K^T[feature, token]` produced by
`_pack_matrix_b_physical()`. Each accepted destination word commits all four
feature bytes. Completion `element_count` advances by four per accepted word.
Abort/error therefore exposes a whole-word prefix; it does not roll back words
already accepted by the SPAD.

## Validation and Compatibility

The descriptor validator accepts this mode only for `0x43`, version 6, and
the geometry above. Legacy `flags=0` writes, `flags=0x01` append, and `0x44`
reads retain the previous version/flag acceptance rules. The cache engine also
rejects invalid geometry and 32-bit source/destination address overflow before
issuing a SPAD request.

This mode does not add SRAM ports, compute engines, or matrix operations. It
changes only the K-cache placement on an isolated research branch.
