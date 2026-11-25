# NMAForge V1.3 Round 34 — Transformer Operators, GPT-2 Runtime and SFU Fast Path

**Disposition: `TRANSFORMER_SFU_PASS_SCOPED`.** All three planned steps ran on
`research/nmaforge-v1.3-round34-transformer-sfu`, which is based on Round 33
`49221642`. The source is the uncommitted working tree; its delta hash is in
the [run manifest](../../benchmark/performance_dominance/round34/evidence/run_manifest.json).
DC/PPA was deferred by request and is `NOT_RUN`. The descriptor ABI, numeric
contract, `ai_spad_arbiter`, SPAD geometry and SFU port are unchanged.

| Step | Result |
|---|---|
| 1. Matched Transformer-operator comparison with pinned TinyNPU | Baseline: TinyNPU needed 0.21–0.67× of NMAForge's SFU cycles. With the Round 34 SFU, NMAForge is 1.98× faster on GELU, 2.11× on Softmax(197) and 1.08× on LayerNorm(197), and ties on Residual |
| 2. GPT-2 H64 software/runtime (active rows, batch publish, Golden out of window) | 4.21× and 1.25× individually, 7.65× combined. All logits bit-exact |
| 3. Gate-5 SFU hardware upgrade (streaming fast path) | GPT-2 decode reaches 10.9× vs the same-source baseline. The DeiT attention+Wo slice is 1.94× faster. Bit-exact; all regressions pass |

## Step 1 — operator comparison

The harness is [`benchmark/transformer_ops/`](../../benchmark/transformer_ops/).
Both sides are timed from start to done on the same element counts.

- **NMAForge side.** The production `ai_tensor_sfu_core` is driven through a
  SPAD model with the arbiter's scalar timing: ready high, read response two
  cycles after accept. Each output word is compared to the independent Python
  reference.
- **Calibration.** The legacy build reproduces the archived Round 31 Product
  Top SFU log: LayerNorm 64 gives 1,421 cycles (identical), Residual 1024 gives
  7,170 vs 7,173, and GELU 256 gives 1,538 vs 1,539.
- **TinyNPU side.** The pinned `8216c22b` `engine_tb_top` is run under VCS
  with two simulation-only adaptations: the Round 33 `sram_dp` adapter, and a
  generated `softmax_engine` copy with one hoisted declaration.

Cycles per element:

| Op | Length | NMAForge legacy | **NMAForge Round 34** | TinyNPU | Tiny / R34 |
|---|---:|---:|---:|---:|---:|
| GELU | 197 | 6.01 | **2.03** | 4.01 | 1.98× |
| Softmax | 197 | 25.0 | **3.34** | 7.03 | 2.11× |
| LayerNorm | 197 | 20.04 | **4.03** | 4.36 | 1.08× |
| LayerNorm | 64 | 22.2 | **5.00** | 5.11 | 1.02× |
| Residual / Vec-add | 197 | 7.01 | **3.02** | 3.01 | 1.00× |
| Requant | 197 | 4.01 | **2.03** | — | — |
| LayerNorm / Softmax | 768 | 19.3 / 24.4 | 19.3 / 24.4 (legacy fallback) | 4.09 / 7.01 | 0.21× / 0.29× |

All rows are in the
[results CSV](../../benchmark/performance_dominance/round34/evidence/transformer_ops_results.csv).

Comparison boundaries:

- **Ports.** TinyNPU engines have two read ports plus one write port (LN, Vec)
  and a private Softmax scratch SRAM. NMAForge uses one shared 32-bit request
  port.
- **TinyNPU numerics.** TinyNPU's own engine tests check little arithmetic. On
  these inputs its INT8 LayerNorm output equals beta shifted by one element
  (Pearson 0.9996 against `beta[i-1]`), and the normalization term is absent.
  Its Softmax correlates 0.38–0.64 with float, and returns all zeros at length
  768. The first post-reset LayerNorm word is X in 4-state simulation.
- **NMAForge numerics.** Every NMAForge row is bit-exact to its documented
  Q-format contract.
- **Rows longer than 256.** Rows over 256 elements exceed the fast-path row
  cache and fall back to the legacy FSM. TinyNPU is faster there. This is an
  open item.

## Step 2 — GPT-2 H64 four-layer decode (software/runtime only)

Setup: QAT package `d9ff47c5…`, prompt `[1,7,42,3]`, persistent incremental
KV, 128 KiB SPAD, and three decode contexts in one unreset Product Top. In
every configuration the generated tokens are `65,82,68,89` and all logits are
bit-exact to the independent Golden. The logits SHA-256 values of all
configurations are identical.

| Configuration | Descriptors | 3-token cycles | Per token | vs baseline |
|---|---:|---:|---:|---:|
| Round 33 flow (fixed 16 rows, one descriptor per AXI-Lite round trip) | 3,540 | 4,190,904 | 1,396,968 | 1.00× |
| Batch resident publish | 3,540 | 3,351,938 | 1,117,313 | 1.25× |
| Active-row SFU mapping | 2,595 | 995,580 | 331,860 | 4.21× |
| Active rows + batch publish | 2,595 | 547,819 | 182,606 | 7.65× |
| **+ Round 34 SFU fast path** | 2,595 | **384,617** | **128,206** | **10.90×** |

Per-layer engine occupancy (context 1, layer 0):

| | Window | SFU busy | Matrix busy | All idle |
|---|---:|---:|---:|---:|
| Baseline | 330,144 | 240,831 (73%) | 14,291 (4%) | 72,590 (22%) |
| Active rows + batch | 42,338 | 23,113 (55%) | 14,927 (35%) | 1,790 |
| + SFU fast path | 29,206 | 9,981 (34%) | 14,927 (51%) | 1,790 |

### What changed

- **Active rows** (`AI_H64_ACTIVE_ROWS=1`, `--active-rows`). The old
  "persistent incremental" mode appended only K/V incrementally; every
  row-wise SFU command still processed all 16 padded rows. The generator now
  maps residual, LayerNorm, Softmax, GELU and Requant/pack to the new token
  row only. Matrix commands still use 16-row tiles.
  - Packed Requant keeps the ABI rule that `m_size` is a multiple of 4: the
    whole aligned four-row group is packed.
  - The inter-layer handoff keeps the row offset inside its source tensors.
  - The software Golden is unchanged. Product checks cover the active rows.
  - Each context's active-row checkpoint words are proven equal to an
    independent fixed-row prefix recompute: 4,592 words per context.
- **Batch publish** (`AI_H64_BATCH_PUBLISH=1`). Each layer program is staged
  into retired ring slots before the timed window. Inside the window it is
  published in segments, with one TAIL write and one doorbell per segment.
  Ordering comes from the existing ABI completion-event chain, not from host
  round trips.
- **Checkpoints out of the window.** In batch mode, checkpoints and completion
  records are compared through a zero-time behavioral-SPAD backdoor at the
  exact cycle each completion becomes visible.

### Costs outside the window, reported separately

- Per-layer weight DMA: 14,982 cycles, which was already outside the Round 31
  window.
- Descriptor staging: 14,112–15,840 cycles per layer over AXI-Lite.

With both included, the cost per token is about 1.457M cycles for the
baseline and about 247k for Round 34, i.e. 5.9×.

Run-directory note: the testbench stores file paths in 128-character
registers, so GPT-2 run directories must use short paths such as `/tmp/nmaf34`.

## Step 3 — Gate 5 SFU streaming fast path

### Contract and minimal reproducer

The legacy SFU issues one 32-bit SPAD request and waits for its two-cycle
response before issuing the next. `ai_compute_spad_mux` and `ai_spad_arbiter`
already accept one core request per cycle and return read data in order. The
reproducer is the Step 1 legacy row, for example GELU at 6.0 cycles/element.

New module: [`ai_tensor_sfu_stream.v`](../../rtl/compute/sfu/ai_tensor_sfu_stream.v),
instantiated inside `ai_tensor_sfu_core`. It shares the core's divider, square
root and SPAD port.

Coverage of the fast path:

- **Residual 0x34, GELU 0x35, Requant 0x36** (plain, linear packed, Matrix-A
  tile packed). These use pipelined in-order reads with an 8-entry response
  FIFO and staged writes.
- **LayerNorm 0x38**, up to 256 elements. x is read once into a 256-entry row
  cache. gamma and beta are prefetched while mean, variance, sqrt and
  reciprocal run. The divider uses its exact leading-zero skip.
- **Softmax / causal Softmax 0x32/0x39**, up to 256 elements. A row cache plus
  one exact reciprocal per row: r = ⌊2⁵⁶/s⌋, then ⌊a·r/2⁵⁶⌋ ∈ {q−1, q} and one
  (q̂+1)·s ≤ a test restores the legacy quotient. Bound: a ≤ 2³⁰, s ≤ 2²³.

Commands fall back to the legacy FSM for any of the following:

- `input_tile_a`
- rows longer than 256
- SiLU, RMSNorm, 0x3a, 0x3b
- configuration errors
- dst overlapping its sources other than an exact in-place match
  (packed Requant must be disjoint)

`+define+AI_SFU_LEGACY_ONLY`, or the `FAST_PATH_ENABLE_P` parameter, forces
the legacy FSM.

### Protocol

A request presented without ready is re-presented unchanged until accepted.
The first build violated this: a newly staged write replaced a stalled read.
The real-top Compute Cluster UVM caught it as `CLUSTER_REQUEST_STABILITY`.

On error or abort, the unit withdraws its request, as the legacy FSM does.
Before reporting `done`, it drains outstanding read responses so they cannot
be consumed by the next command.

Fault reporting: protection errors are reported at accept and parity errors
at response. Error codes match legacy. Partial memory side effects on fault
paths are not claimed to be identical.

### Verification

| Check | Result |
|---|---|
| `make -C dv/block/compute/sfu/sim stream-equiv-regress` (seeds 20261125/26/27). Legacy and fast cores run side by side; random ready stalls; 1–4 cycle multi-outstanding latency; full final-memory compare; valid/ready stability checker | PASS, 491 cases × 3 seeds (431–439 fast, 52–60 fallback, 60 fault cases each). About 40k stability checks per seed |
| Same with `EQUIV_STALL=0` (fixed two-cycle latency) | PASS × 3 seeds |
| Negative controls on the same bench: GELU boundary shifted by 1; Softmax correction removed; tile-pack row/k-group swap; request hold removed | All detected (2 / 19 / 51 failing cases; 3,898 stability errors) |
| Directed Golden (Step 1 harness, 20 shapes) | PASS, exact |
| Legacy SFU random-latency regress (3 seeds) and LN32 bench | PASS. Both benches are pinned to `FAST_PATH_ENABLE_P(0)` because they probe legacy FSM states and exact legacy access counts |
| `ai_smoke` (4 cases, seed 20261122); `ai_run` (20 cases, seed 12345) | PASS / PASS |
| Compute Cluster real-top UVM, 128/256/512 KiB × seeds 20261025/26/27 | PASS, UVM_ERROR=0, UVM_FATAL=0 |
| GPT-2 H64 four-layer autoregressive (active rows + batch + fast SFU) | PASS, bit-exact logits, 384,617 cycles |
| DeiT Round 31 attention + Wo, 16 queries, official checkpoint | PASS for both builds, 72,384 Golden words. Legacy 811,476 cycles vs fast 418,662 (1.94×). The window includes per-batch AXI-Lite publication and Golden observation |

Source lists updated: `ai_accel.f`, `ai_accel_uvm.f`, `a8_rtl.f`, both FPGA
`ai_accel_rtl.tcl` files, the SFU block Makefile, the DAMS research Makefile,
the compute-cluster formal tcl and `tools/benchmark/phase2/run_directed.sh`.

### Not run / open

- **DC/PPA.** Not run. The fast path adds three 256×32-bit row caches (about
  24.6 kbit of flops), a 31×57-bit and a 64×64-bit multiply, and control logic.
  Area and timing at 250 MHz are unmeasured.
- **Static analysis and formal.** SpyGlass lint/CDC and formal were not run on
  the new module.
- **Long rows.** Rows over 256 elements, such as the 768-wide FFN-hidden
  LayerNorm/Softmax, still use the legacy path.
- **Line-wide SFU.** A 128-bit banked read / line write SFU (4–16× more)
  would need a new `ai_spad_arbiter` client. It is not part of this round.
- **Model scope.** DeiT Layer-0 closure, GPT-2 model quality (still below
  Bigram) and silicon/FPGA performance are unchanged by this round.
