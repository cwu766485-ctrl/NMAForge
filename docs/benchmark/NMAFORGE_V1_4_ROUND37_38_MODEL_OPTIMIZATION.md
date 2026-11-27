# NMAForge V1.4 Rounds 37–38 — GPT-2 / DeiT deployment optimization on Product Top

Branch `integration/nmaforge-v1.4_gpt2_deit`.

All numbers come from VCS RTL simulation of Product Top, 512 KiB SPAD. Every
run is bit-exact against the independent integer Golden (`sw/compiler/nmaf`):
checkpoints are compared at descriptor retirement and the final words at
program end. Cycle counts are end to end: they include descriptor publication,
queued DMA and compute. The Round 35/36 baselines are sums of compute cycles,
fenced DMA cycles and descriptor-staging cycles.

## What changed

| Round | Feature | ABI | RTL owner |
|---|---|---|---|
| 37 | Queued DMA `0x60 DMA_COPY` as dispatcher engine 7: DMA runs inside the CMDQ and overlaps compute. Event-on-complete (`CMD_CTRL[1]`), 32-entry in-flight FIFO, `CMD_TAIL` append while busy, DDR-resident CMDQ ring | `CAP2[8]` | `ai_dma_queue_engine`, `ai_parallel_compute_dispatcher` |
| 37 | Compiler overlap mode: SPAD/DDR footprints give RAW/WAR/WAW events, which are interval-colored onto 16 event bits; DMA loads are hoisted; program format v3 | — | `sw/compiler/nmaf/program.py` |
| 38 | GEMM accumulate epilogue: `0x30/0x31 flags[7]` computes `C = sat32(C_old + R)`. The old C line is read through the banked port before each row write | `CAP2[9]` | `ai_tensor_matrix_core` |
| 38 | INT4 block-exponent load: `0x60 flags[1]` expands 256-byte super-blocks (one shift beat plus 15 INT4 beats) into 30 INT8 SPAD lines while draining DMA slots | `CAP2[10]` | `ai_axi128_dma` |
| 38 | SFU stream row cache 256 → 1024 entries, so LayerNorm rows up to 1024 elements (GPT-2 D=768) use the fast path. The Softmax limit stays at 256 | — | `ai_tensor_sfu_core` |

`CAP2` is now `0x7ff`. With every new bit clear, behavior is unchanged.

## GPT-2 small (124M), 12 layers, prompt (8 rows) + 8 greedy decode steps

| Configuration | Descriptors | DMA bytes | End-to-end cycles | vs Round 36 |
|---|---:|---:|---:|---:|
| Round 36 (fenced DMA): compute 212,172,570 + DMA 154,728,642 | 43,473 | 796.8 M | 366,901,212 | — |
| R37 queued DMA overlap (`gt12o`) | 70,772 | 796.8 M | 292,897,208 | −20.2% |
| + GEMM accumulate (`gt12a`) | 64,508 | 796.8 M | 255,481,367 | −30.4% |
| + INT4 FFN weights (`gt12f`) | 64,517 | 560.6 M | 232,723,188 | −36.6% |
| + LN fast path, final (`gt12L`) | 64,517 | 560.6 M | **221,473,132** | **−39.6%** |

Engine occupancy of the final run (`COMPILED_V3_PROFILE`), as cycles busy out
of 221.5 M:

| Unit | Busy cycles | Share |
|---|---:|---:|
| Matrix | 145.6 M | 66% |
| SFU | 16.0 M | 7% |
| Queued DMA | 110.5 M | — |
| DMA only (no compute engine busy) | 59.7 M | 27% |

The Matrix is now the bottleneck, mainly because decode runs M=4 GEMMs on a
16×16 array.

### One layer with debug checkpoints, prefill 32 + 4 decode steps

| Configuration | Cycles |
|---|---:|
| Round 36: compute 16,289,467 + fenced DMA 7,215,078 | 23,504,545 |
| Overlap (`gd1o`) | 19,728,983 |
| + accumulate (`gd1a`) | 15,483,428 |
| + INT4 all weights (`gd1i`) | 13,983,274 |
| + LN fast path (`gd1L`) | 12,858,794 (−45.3%) |

The LN fast path cuts one prefill LayerNorm (32 × 768) from 524,683 to
150,157 cycles.

### Accuracy of INT4 weights

Integer pipeline, WikiText-2 10 × 256, FP32 = 47.02:

| Weights | PPL | DDR weight bytes |
|---|---:|---:|
| INT8 (Round 36 contract) | 51.25 | 1.00× |
| INT4 for MLP only (`--int4-weights ffn`) | 58.20 | 0.69× |
| INT4 for MLP + attention (`--int4-weights all`) | 64.14 | 0.53× |

The 12-layer greedy continuation of the final (`ffn`) run is " was the first
to discover the existence of a". It matches FP32 for 5 tokens, against 1 token
for INT8; with only 8 greedy tokens this comparison is anecdotal. The
fake-quantization study (`sw/compiler/int4_study.py`) chose the 4×4-block
format: one shift per packed SPAD line, 5 levels per head slice, FP-PPL 62.4.
The alternatives were worse:

- per-channel INT4: 255
- 8×4 blocks: 71.2
- an MSE-chosen base exponent: worse than Emax−4

## DeiT-Tiny, 12 layers, one ImageNet validation image

| Configuration | Cycles | vs Round 35 |
|---|---:|---:|
| Round 35: compute 37,519,308 + fenced DMA 6,592,722 + staging 1,548,288 | 45,660,318 | — |
| Layer 0 overlap (`dl0o`) / + accumulate (`dl0a`) | 3,367,126 / 3,304,720 | — |
| 12 layers, overlap + accumulate (`d12a`) | **39,211,913** | **−14.1%** |

DeiT gains less than GPT-2 because its weights are small (5 M), it has only
two residual adds per layer, and D=192 was already on the fast path.

## Verification (VCS V-2023.12-SP1, this environment)

| Check | Command | Result |
|---|---|---|
| Top smoke | `make -C dv/subsystem/top_smoke/sim ai_smoke` | TEST PASS (after every RTL step) |
| Seeded top regression | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | TEST PASS |
| Queued DMA + INT4 self-test | `make ai_qdma_selftest` | 8 segments, 45 descriptors, 38 INT4 super-blocks, bit-exact |
| Matrix core regression | `make -C dv/block/compute/matrix/sim core-random-test core-random-regress product-gemv-regress product-opcode-fault-regress product-opcode-handshake-regress` | PASS. New: 6 accumulate shapes (bias/shift/ReLU/batch/next-K prefetch), 532 saturated words, 3 config faults |
| Descriptor validator | `make -C dv/block/control/sim descriptor-validator-regress` | PASS, 60 invalid rules (5 new INT4 rules, 4 accumulate rules) |
| Control UVM | `make -C dv/block/control/sim uvm_regress` | 9 tests, 0 errors / 0 fatals |
| DMA UVM | `make -C dv/block/dma/sim uvm_regress` | 19 tests, 0 errors / 0 fatals |
| DMA block TB | `make -C dv/subsystem/top_smoke/sim ai_dma_run` | PASS, including the INT4 config-error check. The target's source list now includes the DMA submodules it was missing |
| SFU stream equivalence | `make -C dv/block/compute/sfu/sim stream-equiv-regress` (EQUIV_STALL=1 and 0) | 3 seeds × 2 latency modes PASS. LN rows up to 1024 on the fast path; 1025/1100 fall back |
| SFU flag[7] modes | `make -C dv/block/compute/sfu/sim act-modes-regress` | PASS |
| Shared top UVM | `make -C dv/uvm/sim uvm_compile` | compiles |

NOT RUN in this round:

- SpyGlass lint/CDC
- Formal (the matrix formal tops tie `accumulate=0`)
- DC synthesis

The SFU row cache grows from 3×256 to 3×1024 32-bit entries, about +72 Kbit
of flops before any SRAM mapping. Its area and timing impact is an explicit
open disposition item. All evidence is pre-layout RTL simulation with a
behavioral AXI memory model, for a single input per model.

## Reproduction

The Python environment needs torch, transformers, safetensors, pyarrow and
pillow. Program directories need short paths.

```bash
# GPT-2 final configuration (12 layers, prompt + 8 decode)
python sw/compiler/gpt2_compile.py --model-dir <gpt2 snapshot> --wikitext <test parquet> \
  --layers 12 --prompt "Alan Turing was a British mathematician who" --decode-steps 8 \
  --overlap --int4-weights ffn --out /tmp/nmaf34/gt12L
make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/nmaf34/gt12L \
  AI_COMPILED_AXI_WORDS=25165824 AI_COMPILED_SIM_ARGS=+AI_COMPILED_SEG_TIMING
# DeiT 12 layers
python sw/compiler/deit_compile.py --checkpoint <deit-tiny bin> --val-dir <imagenette2-320/val> \
  --layers 12 --check layer --overlap --out /tmp/nmaf34/d12a
make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/nmaf34/d12a
# integer PPL with INT4 weights
python sw/compiler/gpt2_compile.py ... --layers 12 --ppl-windows 10 --no-program --int4-weights ffn
```

The flags select the configurations as follows:

- `--no-gemm-acc` restores the PART + RESIDUAL form.
- Omitting `--overlap` gives the Round 36 fenced program format v2.
- `--int4-weights none|ffn|all` selects the weight format.

Evidence (summaries, manifests, gzipped run logs) is in
`benchmark/performance_dominance/round38/evidence/model_opt/`.

## Innovation items status

- **GEMM epilogue fusion.** Done (accumulate form). Requant, residual and LN
  statistics fusion at write-back are not done.
- **INT4 weight streaming.** Done: INT4 block-exponent expansion in the DMA,
  with GEMM consuming the expanded INT8.
- **Bank-level programmable lanes.** Dropped from the innovation list. The
  measured SFU share (7–16%) caps the gain.

## Next

1. Decode Matrix efficiency at M ≤ 4 (`0x52` K-fold GEMV mapping). Matrix is
   66% of the final window.
2. The remaining exposed DMA (27%): finer INT4 coverage, more weight slots, or
   32-beat bursts.
3. DC/PPA for the three RTL changes, and SpyGlass.
4. Embedding/head on the NPU and longer context (`kmax` > 64).
