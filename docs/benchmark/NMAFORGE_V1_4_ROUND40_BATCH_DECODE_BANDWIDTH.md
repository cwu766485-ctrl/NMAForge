# NMAForge V1.4 Round 40 — memory-latency model, four-sequence decode, CNM attention study

Branch `integration/nmaforge-v1.4_gpt2_deit`. RTL and ABI unchanged from Round 39.

All runs are VCS V-2023.12-SP1 simulations of Product Top (512 KiB SPAD) and
are bit-exact against the integer Golden (checkpoints after every layer of
every step, plus final words). Throughput assumes the 250 MHz target clock and
a 128-bit AXI port (4 GB/s, 16 B/cycle). It comes from simulated cycles, not
from silicon.

## 1. A DDR-like memory model for the testbench

The behavioral AXI model (`dv/block/dma/env/axi_memory_model.sv`) answered
every read immediately, but it inserted a gap and dropped RVALID between beats.
Each 128-bit beat took 2–3 cycles. Two opt-in plusargs now model a DDR
controller; both default off, so legacy timing is unchanged:

- `+AXI_MEM_READ_LATENCY=<n>`: first beat no earlier than n cycles after the
  AR handshake. The four queued ARs overlap their latencies.
- `+AXI_MEM_STREAM=1`: beats back to back.

The legacy GPT-2 1-layer cycle count (10,419,227) is unchanged, smoke passes,
and DMA UVM passes 19 tests with 0 errors.

GPT-2 1-layer final program (`gd1L`, Round 39 RTL), end-to-end cycles:

| Memory timing | 16-beat bursts | 32-beat bursts |
|---|---:|---:|
| Legacy model (gap, 2–3 cycles per beat) | 10,419,227 | 10,408,335 |
| Streaming, latency 0 | 9,699,760 | 9,701,167 |
| Streaming, latency 50 | 9,794,967 | 9,773,415 (−0.2%) |
| Streaming, latency 100 | 10,099,593 | 9,875,765 (−2.2%) |

- The legacy model was pessimistic. Part of the "exposed DMA" share reported
  in Round 39 came from the model's beat rate, not from the design.
- With 100-cycle latency, the DMA is capped by four outstanding reads of 16
  beats: 64 beats per round trip, about 8.8 B/cycle. The measured average is
  about 6.6 B/cycle.
- 32-beat bursts help when decode is DMA-bound (section 2): −10% to −12% on
  the 1-layer decode programs. They cost +8 Kbit of read slot buffer.
  Recommendation: make 32 the product default once the PPA run confirms the
  area. The build parameter `DMA_MAX_BURST_BEATS` already exists and passes
  the INT4 self-test at 32.

## 2. Four-sequence decode (`sw/compiler/gpt2_batch.py`)

A decode step always runs four GEMM rows, and the Matrix is bound by
weight-line reads. Four independent sequences therefore share one weight read
per step at almost no extra Matrix time:

- The four rows carry four sequences ("slots") in lockstep at position p.
- Attention stays per sequence. The prompts are prefilled by the Golden and
  their K/V caches are placed in DDR, so the program measures decode only.

Inserting one new position into each slot's INT8 cache is the hard part.
- The V^T cache keeps four positions per 32-bit word, and the DMA writes whole
  words.
- The compiler solves this without RTL changes:
  - LN(x_s) is placed in byte lane L = p mod 4 of group s of a 16-row operand
    (zero elsewhere), so the V^T GEMM has N = 16. The 16×16 array is 16 wide
    anyway.
  - The packed result for slot s has v_s in lane L and zeros in the other
    lanes.
  - The old cache words still have zeros in lanes ≥ L, so a 32-bit RESIDUAL
    add of the two is an exact byte insert. The words go DDR → SPAD → add →
    DDR.
- K rows are whole words and use a 2D store.
- Per-slot attention uses one GEMM per slot. The softmax row of slot s is
  written into an otherwise zero P8_s. The four AV GEMMs accumulate into one
  output with the GEMM accumulate epilogue: the rows of the other slots
  contribute (0 + half) >> sh = 0.
- `--batch 1` runs the same code with one slot. It is the single-stream
  reference.

GPT-2 small, 12 layers on the NPU, GPTQ INT4 weights (MLP + attention),
prompt 30, 4 decode steps, streaming memory with latency 100:

| Configuration | Cycles | Tokens | Cycles/token | Tokens/s @250 MHz | DDR bytes/token |
|---|---:|---:|---:|---:|---:|
| 1 sequence, 16-beat | 70,045,021 | 4 | 17.51 M | 14.3 | 49.4 MB |
| 1 sequence, 32-beat | 68,218,570 | 4 | 17.05 M | 14.7 | 49.4 MB |
| 4 sequences, 16-beat | 76,003,525 | 16 | 4.75 M | 52.6 | 13.1 MB |
| **4 sequences, 32-beat** | **73,213,234** | **16** | **4.58 M** | **54.6** | **13.1 MB** |

- Four sequences give 3.69× (16-beat) and 3.73× (32-beat) the tokens/s of
  one sequence, and read 3.8× fewer DDR bytes per token.
- The Matrix busy time is the same in both cases: 48.2 M and 46.9 M cycles.
- The continuation of slot 0 is identical to the single-sequence run
  (" in the war. The").

Where the time goes (4 sequences, 32-beat): Matrix busy 46.9 M (64%), SFU
9.9 M, DMA-only 16.7 M (23%).

Roofline at 16 B/cycle:

| | Bandwidth floor | Achieved | Limiter |
|---|---:|---:|---|
| 1 sequence | 3.1 M cycles/token (81 tok/s) | 17.05 M (14.7 tok/s) | Matrix weight-line rate |
| 4 sequences | 0.82 M cycles/token (305 tok/s) | 4.58 M (54.6 tok/s) | Matrix plus exposed DMA |

The next limit is the Matrix's consumption of expanded INT8 weight lines.
Larger batches and wider SPAD read paths are the levers, not more DDR
bandwidth.

## 3. Attention on the bank-local CNM: a negative result

`--attn-engine cnm` moves each slot's S = K q and AV = V^T p8 onto opcode
`0x21`:
- K and V^T caches are row-major. CNM results are floored, because the CNM
  has no bias input.
- The Matrix work of head h+1 is interleaved with the attention of head h,
  with double-buffered head scratch, so the CNM and the Matrix can run
  concurrently.
- `0x21` gained a footprint model in `nmaf/program.py`.

1-layer decode, 4 sequences, streaming memory with latency 100 (bit-exact):

| Context | Matrix attention | CNM attention | Single sequence |
|---|---:|---:|---:|
| kmax 64, p = 30..32, 16-beat | 5,384,690 | 5,581,308 (+3.7%) | 4,835,799 |
| kmax 64, 32-beat | 4,725,087 | 4,919,126 (+4.1%) | 4,358,294 |
| kmax 256, p = 200..202, 32-beat | 5,370,090 | 5,951,364 (+10.8%) | 4,406,405 |

CNM attention is slower in every case:

1. Running decode shapes alone, the CNM streams about 5 B/cycle. Its
   controllers fetch A and B words separately. The Matrix streams about
   13 B/cycle and serves four rows.
2. Matrix and CNM can overlap in an independent pair. 8 GEMMs plus 8 GEMVs
   take 96,928 cycles concurrently against 141,684 serially (1.46×). In
   decode, however:
   - the attention chain (S → softmax → pack → AV) blocks in-order issue;
   - all engines share one SPAD port.
3. At kmax 256, two heads' caches do not fit in the SPAD, so the pipeline
   falls back to sequential issue.

A fair comparison now replaces the earlier "1.98× vs scalar baseline" claim:
- CNM GEMV of 64×768 takes 9,697 cycles for 1 row.
- The Matrix takes 3,977 cycles for 4 rows.

Making near-memory attention pay off would need several changes:
- bank-level multi-port SPAD arbitration (not implemented, SPEC §2.1);
- an INT4/INT8 CNM that reads both operands in one admission;
- out-of-order issue across engines.

## 4. Progress summary (GPT-2 small, 12 layers)

| Round | Change | Measured on | Result |
|---|---|---|---|
| 36 | Baseline: fenced DMA, INT8 | legacy model, prompt + 8 decode | 366.9 M cycles |
| 37 | Queued DMA overlap | same | 292.9 M (−20%) |
| 38 | GEMM accumulate, INT4 MLP, LN fast path | same | 221.5 M (−40%) |
| 39 | Matrix read pipeline; GPTQ INT4 everywhere | same | 164.1 M (−55%) |
| 40 | Four-sequence decode, 32-beat | decode only, latency 100 | 54.6 tok/s vs 14.7 tok/s single-stream (3.7×) |

The Round 36–39 rows use the legacy memory model and a prefill + 8-decode
program. The Round 40 row is decode-only with the DDR-like model, so the two
groups are not directly comparable.

## Verification

| Check | Command | Result |
|---|---|---|
| Batch decode, 1 layer | `gpt2_batch.py --layers 1 --batch 4 [--attn-engine cnm]` + `make ai_compiled_program` | bit-exact (matrix, CNM; kmax 64 and 256) |
| Batch decode, 12 layers | `gpt2_batch.py --layers 12 --batch {1,4} --int4-weights all` | bit-exact, 16- and 32-beat |
| Memory model default | `make ai_smoke`; `make -C dv/block/dma/sim uvm_regress` | PASS; 19 tests, 0 errors |
| 32-beat INT4 | qdma self-test at `DMA_MAX_BURST_BEATS=32`, 4 timing modes | bit-exact |

NOT RUN: SpyGlass, formal, DC. Area and power are pending the synthesis of
the current RTL, so tokens/s per mm² is not reported yet. The CNM numerics
(floored S/AV) were not evaluated for PPL, because the mode is not adopted.

## Reproduction

```bash
# quantize once (GPTQ INT4 ~35 min), cached in --quant-cache
python sw/compiler/gpt2_batch.py --model-dir <gpt2> --wikitext <parquet> --layers 12 \
  --batch 4 --prompt-len 30 --decode-steps 4 --int4-weights all \
  --quant-cache /tmp/qcache --out /tmp/gx4
make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/gx4 \
  AI_COMPILED_AXI_WORDS=25165824 \
  AI_COMPILED_SIM_ARGS="+AXI_MEM_READ_LATENCY=100 +AXI_MEM_STREAM=1"
```

The 32-beat build adds
`-pvalue+tb_ai_accel_smoke.dut.DMA_MAX_BURST_BEATS=32` to the VCS compile.
Evidence (run summaries, manifests, gzipped 12-layer logs) is in
`benchmark/performance_dominance/round40/evidence/`.
