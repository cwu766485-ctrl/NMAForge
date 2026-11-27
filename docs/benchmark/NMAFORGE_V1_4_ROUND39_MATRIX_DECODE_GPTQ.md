# NMAForge V1.4 Round 39 — Matrix read pipeline, VCS scratchpad fix, GPTQ INT4

Branch `integration/nmaforge-v1.4_gpt2_deit`. ABI unchanged (`CAP2=0x7ff`).

All numbers come from VCS V-2023.12-SP1 RTL simulation of Product Top with a
512 KiB SPAD and the behavioral AXI memory model. Every model run is bit-exact
against the independent integer Golden (`sw/compiler/nmaf`).

## Why `0x52` GEMV was not the fix

Round 38 left the Matrix at 66% of the GPT-2 window. We measured `0x30` GEMM
against `0x52` GEMV on the decode shapes, one op per fenced segment:

| Shape M×N×K | `0x30` | `0x52` |
|---|---:|---:|
| 4×64×768 (Q/K/fc1) | 6,521 | 6,885 (M=4), 6,261 (M=1) |
| 4×256×64 | 3,235 | 3,313 (M=4), 2,929 (M=1) |

GEMV is not faster. A per-state probe showed where the GEMM time goes:

- each K group runs 4 MAC cycles, then waits about 4 cycles for its prefetch;
- the prefetch issues 1 A line and 4 B lines, then drains for 2 cycles;
- the bias is fetched as 16 scalar word reads per N tile (2,304 of 9,411
  cycles for 4×768×64).

## RTL changes (`ai_tensor_matrix_core`)

- **Bias line reads.** A 16-byte-aligned bias tile whose column count is a
  multiple of 4 is read as whole lines through the banked port. Read-metadata
  bit 70 tags these reads. Other tiles keep the scalar path, so N-tail GEMV
  and unaligned bias still use it.
- **Operand staging (`ENABLE_GEMM_OPERAND_STAGE=1`).** Applies to plain GEMM
  only, not GEMV or tile forwarding.
  - When lane 0 of a K group loads into the array, the group's 32 A/B words are
    copied into a stage register.
  - Lanes 1–3 read the stage, so the read buffer is free as soon as the MAC
    starts.
  - Each buffer counts its own outstanding reads. The next K group's prefetch
    issues while the previous one is still draining. K group g always lives in
    buffer g % 2.
  - Added state: 32 stage words plus small counters, about 1 Kbit of flops.

Matrix command cycles (top-level probe, same operands):

| Shape | Before | + bias lines | + staging |
|---|---:|---:|---:|
| 4×64×768 | 6,425 | 6,257 | 3,977 (−38%) |
| 4×768×64 | 9,411 | 7,395 | 5,379 (−43%) |
| 4×256×64 | 3,139 | 2,467 | 1,795 (−43%) |

## VCS scratchpad model fix (`ai_scratchpad`, `+define+VCS` only)

With staging enabled, the GPT-2 decode checkpoint failed while every Matrix
and RESIDUAL result matched its inputs. Measurement-only monitors isolated
the cause:

- shadow checkers for each op type;
- a footprint dependency check of observed start/done times (0 violations);
- a per-DMA DDR/SPAD comparison.

One `0x60` store wrote eight words of an old ACC line to DDR in place of the
K cache. The cause was in the behavioral scratchpad model:

- Its line read had one register stage; every other port, and XPM
  (`READ_LATENCY=2`), has two.
- The arbiter returns the response two cycles after the request. A line
  access in the following cycle therefore overwrote the data still owed to
  the earlier reader.
- The model now has two stages. The FPGA XPM path was already correct.
- The defect predates this round. Earlier timing never put a line access in
  that cycle.

With the fix, the GPT-2 1-layer overlap+accumulate program (`gd1a`) passes. All
1,265 queued DMAs match the shadow DDR/SPAD comparison.

## Compiler: GPTQ INT4 (`sw/compiler/gpt2_compile.py`)

The INT4 block-exponent format and the hardware are unchanged.

- Block exponents still come from the original weight.
- The input rows are rounded in order. Each row's rounding error is
  propagated to the remaining rows through the Cholesky factor of the
  damped inverse Hessian (damping 1% of the mean diagonal).
- The Hessians come from the post-SmoothQuant calibration pass, 8×256 tokens:
  - full 768×768 for the LN1 and LN2 inputs;
  - diagonal 64×64 blocks for the attention output and the GELU output (per
    head / FF-chunk weight slice).
- `--no-gptq` restores round-to-nearest.

Integer PPL, WikiText-2 10×256 (FP32 47.02, INT8 51.25):

| Weights | Round-to-nearest | GPTQ | DDR weight bytes |
|---|---:|---:|---:|
| INT4 MLP | 58.14 | **54.60** | 0.69× |
| INT4 MLP + attention | 64.14 | **58.35** | 0.53× |

The round-to-nearest MLP value was re-measured with `OMP_NUM_THREADS=4`.
Round 38 reported 58.20; the difference is calibration run-to-run variation.

## End-to-end results

| Program | Round 38 | Round 39 | Change |
|---|---:|---:|---:|
| GPT-2 1 layer, prefill 32 + 4 decode, final config (`gd1L`) | 12,858,794 | 10,419,227 | −19.0% |
| GPT-2 1 layer, overlap + accumulate (`gd1a`) | 15,483,428 | 12,019,747 | −22.4% |
| DeiT layer 0, overlap + accumulate (`dl0a`) | 3,304,720 | 2,845,467 | −13.9% |
| GPT-2 12 layers, prompt + 8 decode, Round 38 program (`gt12L`) | 221,473,132 | 181,354,731 | −18.1% |
| Same, GPTQ INT4 MLP weights (`gt39f`) | — | 181,354,731 | −18.1% |
| Same, GPTQ INT4 MLP + attention weights (`gt39a`) | — | **164,124,531** | **−25.9%** |

Against the Round 36 fenced baseline (366,901,212 cycles), `gt12L` is −50.6%
and `gt39a` is −55.3%.

- `gt39f` has the same shapes and DMA bytes as `gt12L` (560.6 M), so its cycle
  count is identical; only the weight values differ.
- `gt39a` streams 442.5 M DMA bytes.
- The INT4 weights in all three programs come from the compiler; the RTL is
  identical.

Engine occupancy (`COMPILED_V3_PROFILE`, busy cycles):

| Program | Total | Matrix | SFU | Matrix ∥ DMA | DMA only |
|---|---:|---:|---:|---:|---:|
| Round 38 `gt12L` | 221.5 M | 145.6 M (66%) | 16.0 M | — | 59.7 M (27%) |
| Round 39 `gt12L` | 181.4 M | 101.4 M (56%) | 16.1 M | 43.8 M | 63.8 M (35%) |
| Round 39 `gt39a` | 164.1 M | 103.2 M (63%) | 16.6 M | 42.9 M | 44.3 M (27%) |

Matrix busy time drops by 30%. Exposed DMA becomes the second limiter at 35%
of `gt12L`. All-INT4 weights cut it to 44.3 M. The AXI model has almost no
read latency, so on silicon the DMA share would be larger. The next steps
therefore target bytes per token:

- decode four sequences in the four GEMM rows (one weight read serves four
  tokens);
- realistic memory latency in the TB;
- the burst-length decision.

Greedy continuations of "Alan Turing was a British mathematician who" (FP32:
" was the first to discover that the universe is"):

| Program | Continuation | Tokens matching FP32 |
|---|---|---:|
| `gt12L` | " was the first to discover the existence of a" | 5 |
| `gt39a` | " was the first to discover the existence of the" | 5 |
| `gt39f` | " was born in 1844. He was a" | 1 |

With 8 tokens these comparisons are anecdotal. PPL is the accuracy metric.

## 32-beat DMA bursts

`DMA_MAX_BURST_BEATS` already exists as a top-level parameter. A build with 32
beats passes the queued-DMA/INT4 self-test bit-exactly (79,668 cycles). The
16-beat build takes 79,607 cycles. The behavioral AXI model has almost no read
latency, so this simulation cannot show the gain. Round 35 measured the gain
at 50–100 cycles of latency. 32 beats doubles the read slot buffer (+8 Kbit),
so the default and the SPEC stay at 16 until a latency and PPA decision.

## Verification (this environment)

| Check | Command | Result |
|---|---|---|
| Matrix core | `make -C dv/block/compute/matrix/sim core-random-regress product-gemv-regress product-opcode-fault-regress product-opcode-handshake-regress core-no-prefetch-fallback-regress core-tile-forward-regress` | PASS |
| Matrix handoff (4×4 build) | `make ... core-prefetch-handoff-regress OUTSTANDING_DEPTH=4 PHYSICAL_ARRAY_SIZE=4 SEEDS='20261021 20261022 20261023'` | PASS |
| DMA/SPAD subsystem | `make -C dv/subsystem/dma_spad/sim subsystem_regress` | PASS |
| Top smoke | `make -C dv/subsystem/top_smoke/sim ai_smoke` | TEST PASS |
| Seeded top regression | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | TEST PASS |
| Control UVM | `make -C dv/block/control/sim uvm_regress` | 9 tests, 0 errors / 0 fatals |
| DMA UVM | `make -C dv/block/dma/sim uvm_regress` | 19 tests, 0 errors / 0 fatals |
| DMA block TB | `make -C dv/subsystem/top_smoke/sim ai_dma_run` | PASS |
| Queued DMA + INT4 self-test | `make ai_qdma_selftest` | bit-exact |
| Shared top UVM | `make -C dv/uvm/sim uvm_compile` | compiles |

Testbench changes in the Matrix TB. All of them keep the original check:

- **Bias.** The banked responder now models bias reads. The scalar-bias
  parity and protection faults moved to a 4-byte-aligned bias so they still
  hit the scalar path. Two new faults cover the line path (protection and
  parity), so the fault count goes from 38 to 40.
- **Prefetch assertion.** The "prefetch never targets the compute buffer"
  assertion now applies without staging. With staging it is replaced by
  "never targets an un-snapshotted buffer".
- **Watchdog/abort tests.** These count a staged buffer that is still
  draining as a prefetch in flight.
- **Read count.** The dense GEMV read count includes its 4 bias lines.

A 4×4-array `core-random-test` fails `run_outstanding_abort`. The same failure
reproduces on the Round 38 HEAD, so it is pre-existing.

NOT RUN: SpyGlass lint/CDC, formal (the matrix formal tops do not model
staging), DC synthesis. The staging flops and the bias-line path are open PPA
disposition items. All evidence is pre-layout RTL simulation.

## Reproduction

```bash
python sw/compiler/gpt2_compile.py --model-dir <gpt2 snapshot> --wikitext <test parquet> \
  --layers 12 --prompt "Alan Turing was a British mathematician who" --decode-steps 8 \
  --overlap --int4-weights ffn --out /tmp/nmaf34/gt39f
make -C dv/subsystem/top_smoke/sim ai_compiled_program AI_COMPILED_DIR=/tmp/nmaf34/gt39f \
  AI_COMPILED_AXI_WORDS=25165824
python sw/compiler/gpt2_compile.py ... --layers 12 --ppl-windows 10 --no-program --int4-weights all
```

Evidence (run summaries, manifests, gzipped run logs, PPL reports) is in
`benchmark/performance_dominance/round39/evidence/model_opt/`.
