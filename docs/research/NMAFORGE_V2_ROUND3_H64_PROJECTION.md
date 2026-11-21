# NMAForge v2 Round 3 — H64 Projection Bring-up

## Result

The first nonzero H64 operation now executes through the production Top,
CMDQ/CPLQ, descriptor validation, Matrix engine, shared SPAD arbiter, and
behavioral SPAD. It computes layer-0 Q projection for four token rows with four
legal Matrix N tiles. All 1,024 output INT32 words match an independent scalar
INT8 GEMM Golden.

```text
H64_PROJECTION_GENERATOR_PASS descriptors=4 shape=16x16x64 golden_words=1024 high_water=38912
REPRESENTATIVE_MODEL_PASS desc=4 golden_words=1024 useful_macs=65536 command_cycles=1188
  matrix_mac_cycles=256 matrix_req_wait=27 matrix_rsp_wait=21 matrix_writeback=256
  spad_read_bytes=8192 spad_write_bytes=4096
```

This is one H64 projection, not an attention block, decoder block, or four
layer inference result. Weights are deterministic pseudo weights. No language
model quality or pretrained checkpoint claim is made. Measurement uses the
behavioral SPAD and the testbench's default 10 ns clock period; it is not an
Fmax or ASIC result.

## Legal Mapping

Product descriptor validation permits Matrix `M,N` to be nonzero multiples of
four and the 16x16 Matrix implementation tiles larger dimensions. For this
operation the mapping uses four descriptors with `M=16`, `N=16`, `K=64`
(`k_words=16`), opcode `0x30`, ABI v7.4. Splitting the 64 output channels into
four 16-column tiles avoids any unsupported H64-wide Matrix tile.

The 16-row A operand contains four nonzero token-plus-position INT8 vectors
and twelve zero rows for the physical Matrix tile. The B operand is the
corresponding 64x16 slice of the H64 Q matrix in the established Matrix-B
four-column/four-K-lane packing. Outputs are row-major signed INT32. No
intermediate tensor is computed on the host; Python only initializes inputs,
packs weights, and calculates the independent expected result.

## SPAD Map

All addresses are byte offsets within the 128 KiB SPAD. Ranges are
`[start,end)` and are aligned to 64 bytes by the existing Mapper.

| Region | Range | Size | Lifetime |
|---|---:|---:|---|
| H64 input A, padded 16x64 | `[0x1000,0x1400)` | 1,024 B | All four commands |
| Q weight N0 | `[0x1400,0x1800)` | 1,024 B | Command 0 |
| Output N0 | `[0x1800,0x1c00)` | 1,024 B | Command 0 through readback |
| Q weight N1 | `[0x1c00,0x2000)` | 1,024 B | Command 1 |
| Output N1 | `[0x2000,0x2400)` | 1,024 B | Command 1 through readback |
| Q weight N2 | `[0x2400,0x2800)` | 1,024 B | Command 2 |
| Output N2 | `[0x2800,0x2c00)` | 1,024 B | Command 2 through readback |
| Q weight N3 | `[0x2c00,0x3000)` | 1,024 B | Command 3 |
| Output N3 | `[0x3000,0x3400)` | 1,024 B | Command 3 through readback |
| CMDQ descriptors (4 x 64 B) | `[0x8000,0x8100)` | 256 B | Entire run |
| CPLQ records (4 x 16 B) | `[0x9000,0x9040)` | 64 B | Entire run |

The reported `high_water_bytes=38912` reserves the full 128-entry completion
ring starting at 0x9000; it remains below 0x20000. There is no simultaneous
writer overlap: the four descriptors are chained through the existing ordered
event bit. Input A remains read-only. Each output range is disjoint from all
input and weight ranges and from other output tiles.

## Reproduction

Requires VCS `V-2023.12-SP1_Full64`, NumPy, and the Python environment with
NumPy at `/tmp/nmaforge_round10_venv` by default. Override
`AI_H64_PROJECTION_PYTHON` for another compatible Python 3 environment.

```sh
cd /tmp/nmaforge-v2-round3-h64
make -C dv/subsystem/top_smoke/sim ai_h64_projection_top \
  AI_H64_PROJECTION_RUN=/tmp/nmaforge_h64_projection_replay \
  AI_H64_PROJECTION_SEED=20261114
```

The standalone descriptor/memory generator is:

```sh
/tmp/nmaforge_round10_venv/bin/python \
  benchmark/gpt2_compat/generate_h64_projection.py \
  --seed 20261114 --out /tmp/nmaforge_h64_projection_replay/workload
```

## Remaining Gate 1/2 Work

- QKV and output projection tiling need a common graph allocator with explicit
  tensor live ranges.
- The current Matrix tile shape can represent H64 projections as multiple
  legal descriptors; it does not imply that all Transformer stages are legal.
- H64 QK/AV attention and its 16-token Q15 softmax need separately lowered
  matrices and exact comparison against the frozen numeric contract.
- LayerNorm, residual, FFN, persistent KV ownership, four-layer chaining,
  external weight DMA streaming, and autoregressive Top feedback remain
  `NOT_RUN` for H64.
- Current product LayerNorm/softmax/Matrix descriptors have shape and numeric
  contracts that must be met by every expanded stage; a plan CSV alone is not
  executable evidence.
