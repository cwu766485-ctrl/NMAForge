# GEMM / SFU scheduling optimization and TinyNPU timing audit

Status: **DESIGN_PARTIAL**. Product branch: **nmaforge**. Verified RTL/test commit:
`b2b3b0b5942f9218ed574a04e946104109dc2c99`.
Baseline: `9095832f049629dbfb3ee8a6f10839cdb50f4aa4`.
The evidence commit is a descendant with documentation/archive changes only.

The old remote spelling `nmaforege` was deleted after `origin/nmaforge` was
published and its SHA verified. Main and unrelated branches/worktrees are retained.

## Changes and actual end-to-end results

Two bounded product RTL changes retain the 16×16 / 256 INT8 MAC array, existing
SPAD ports, 128 KiB four-bank benchmark configuration, 512 KiB compatibility,
ABI-v7.4 and all numerical contracts. No engine, FIFO, buffer or register array
was added. Required INT32 intermediate writes remain materialized.

| Same trained H16 workload | 8-token decode cycles | cycles/token | SPAD read / write B |
|---|---:|---:|---:|
| Baseline | 66,931 | 8,366.375 | 72,448 / 42,112 |
| GEMM scheduling only, original SFU | 66,795 | 8,349.375 | 72,448 / 42,112 |
| GEMM + LN overlap | **65,771** | **8,221.375** | 72,448 / 42,112 |

Total reduction: **1,160 cycles / 1.733%**; throughput increase 1.764% at an
identical clock assumption. Matrix saves 136 actual decode cycles; LN saves a
further 1,024. These are NMAForge before/after results, not TinyNPU speedups.
Model SHA256:
`e7a521c762b66e5754d6d95c411c163452e0c9b01088cb11631202338cd28225`.
The GELU16 H16 QAT INT8 weights, four prefill tokens, eight teacher-forced decode
tokens, ring KV cache and fixed-point reference are unchanged. All eight logits
and physical KV hashes match the baseline; each decode stage checks 1,360 Golden
words. One persistent VCS process, one initial reset/load; stage queues re-arm
without resetting or clearing KV. Host token choice and initial loading are
outside decode timing. This is the existing small trained synthetic-task model,
not evidence of arbitrary large-language-model execution.

The trained 570,164-MAC both-fused row-major CNN improves **12,947 → 12,351 CMDQ
cycles (4.603% fewer)**, useful MAC/cycle **44.0383 → 46.1634**. All 20,800 Golden
words pass. DMA remains 3,019 setup/transfer-window cycles, 2,879 busy cycles,
10,944 AXI payload bytes. Compute SPAD remains 64,064 read / 16,640 write bytes.
CMDQ timing includes dispatch/compute/writeback/retirement but excludes the
separately measured initial DMA window. No Golden or model changes.

## 1. Matrix ownership and scheduling

The prefetch FSM formerly drained all A responses before issuing B. Accepted
read metadata already contains operand, destination ping-pong buffer, group, K
and address. A and B may therefore occupy the existing ordered-response FIFO
simultaneously. The final A acceptance now selects `PF_B_REQ` for ordinary GEMM;
`PF_B_DRAIN` still waits for **all** accepted responses before publishing the tile
valid bit. The original depth limit, fault-stop, response-context validation,
abort/watchdog drain and inactive-buffer ownership remain in force.

The change is deliberately gated off for `gemv_kfold_r` / Product 0x52. An early
experiment applying it to GEMV had mixed small-shape gains/losses. Retained
GEMV RTL scheduling is unchanged. An isolated dense 4×16×32 fixed-memory case
is 169 cycles before/after; tail and multirow fixed-memory cases are unchanged.
The full campaign's first GEMV case can differ because its preceding GEMM
cache-collision precondition changes the free-running testbench RNG phase
(166 → 170 cycles); that is not an isolated GEMV performance comparison.

| GEMM M×N×K | Seeded-random baseline → final | Always-ready, zero extra queue delay baseline → final | read / write B |
|---|---:|---:|---:|
| 16×16×16 | 175 → 166 | 125 → 119 | 512 / 1,024 |
| 16×16×32 | 263 → 253 | 181 → 167 | 1,024 / 1,024 |
| 32×32×64 | 1,407 → 1,310 | 979 → 919 | 6,144 / 4,096 |

Both harness modes retain registered ordered responses. `MATRIX_FIXED_MEMORY`
forces ready and removes the responder's *extra queue countdown*; it does not
model a real SRAM macro or bypass the registered testbench response path.

For 32×32×64 in the fixed model, exclusive input/compute/writeback/lifecycle
counts remain 38 / 320 / 256 / 5. Prefetch wait falls **360 → 300**, accounting
for the entire 60-cycle gain. Random-model prefetch wait is **674 → 588**;
A-drain observation falls 118 → 0 and FIFO-full observation becomes 24 cycles.
These overlapping counters cannot be added to exclusive state totals.

New optional edge traces verify **480 accepted requests / 480 ordered matching
responses**, no loss or residual ownership, across the three shapes. Mixed
A/B outstanding cycles change 0 → 86. Address/operand metadata are checked by
the archive script independently of the result scoreboard.

**Correction of historical timing claims:** `TINY_NPU_MATCH_MULTI` previously
printed `bank_response_latency=1 cycle`, but its responder uses seeded random
ready and per-entry countdown `rng[6:5]`. That label was inaccurate. Its
`bank_stalls` are injected ready stalls, **not measured bank conflicts**. The
new fixed-mode result separates controller bubbles from artificial readiness.
No physical bank-conflict reduction is claimed. Bank-aware placement requires
actual shared-fabric requester/bank traces before another hardware change.

## 2. SFU: overlap Gamma arithmetic with Beta fetch

Existing length-16 LN input cache already removes variance-pass and affine-pass
X rereads. It retains 16 input + 16 Gamma + 16 Beta accepted reads and 16 INT32
writes per descriptor. It does not cache Gamma/Beta across descriptors: software
can alter weights between commands, and no lifetime/invalidation ABI exists.

Measured mutually exclusive LN busy-state profile (64 decode descriptors):

| Phase | baseline | final |
|---|---:|---:|
| Input fetch | 49 | 49 |
| Mean / variance | 50 | 50 |
| Reciprocal / sqrt | 69 | 69 |
| Gamma / Beta fetch | 96 | 96 |
| Affine-only states | 33 | 17 |
| Output writeback | 16 | 16 |
| FSM finish | 1 | 1 |
| **Total busy** | **314** | **298** |

At `ST_LN_B_REQ`, Gamma arithmetic is evaluated from stable registered X/Gamma
while the original Beta request waits for admission. The already existing
`output_word_r` stores the **saturated INT32 post-Gamma intermediate**. The Beta
response loads Beta and moves that intermediate into `x_r`, then enters the
existing second arithmetic stage. This removes one standalone arithmetic state
per element. Gamma multiplication now overlaps the fetch bucket; it has not
vanished from the hardware or mathematical operation count.

No new outstanding SFU read, extra port or response routing is needed. Repeated
captures under request backpressure are idempotent. Parity/protection failures,
abort, reset and watchdog still prevent a successful commit. Gamma-disabled,
Beta-disabled, short/long LN, packed requant and other SFU modes retain the
reference semantics in the numerical regression. The length-16 input cache
remains command-local.

Residual was already optimized in the baseline. Requant still reads required
INT32 outputs before shift/clamp/pack. Neither changes in this experiment:
removing these writes would violate the requested contract, while adding a
shared forwarding lifetime or read pipeline needs separate dependency/fault
proof. Their request/response stalls remain visible in the existing SFU profile.

## 3. TinyNPU boundary audit

Reference source remains pinned to **8216c22b762011aa20c05fc2768423fd12dda59d**.
The public C++ harness adds mutually exclusive clear, feed-wavefront and drain
counters. It also fixes interpretation of the legacy array timer: that timer
excluded the first two clear cycles but included clears on later output tiles.
The legacy field is retained for compatibility; the inclusive phase total is
the consistent array boundary. `feed_wavefront` includes skew/fill/empty slots,
not just cycles with 256 useful MACs.

| Shape | Tiny clear | feed wavefront | drain | inclusive array total | NMA fixed controller total |
|---|---:|---:|---:|---:|---:|
| 16×16×16 | 2 | 48 | 4 | 54 | 119 |
| 16×16×32 | 2 | 96 | 4 | 102 | 167 |
| 32×32×64 | 8 | 768 | 16 | 792 | 919 |

NMA exclusive input-fetch/compute/writeback/lifecycle/prefetch counts are archived
separately and close exactly to its total. Tiny's direct array wrapper injects
operands from C++ and inspects accumulators without clocked memory commits;
**transfer, dispatch and writeback are `NA` (unmeasured)**. They must not be
silently assigned zero. This table compares different scopes and produces no
system speedup. Tiny's direct wrapper has no shared SPAD request timing; its
SRAM_DEPTH=4096 also does not make its array measurement comparable with NMA's
128 KiB controller/SPAD path.

Trained common H16 Q/K/V raw projections (three 4×16×16 shapes) pass the same
independent integer Golden: 192 words/design, common host requant excluded from
both RTL timings. Final NMA seeded-random controller is 88 cycles/projection;
Tiny inclusive direct array is 54. These endpoints remain distinct.

Common `conv1x_mini` CNN passes the pinned Golden, with NMA CMDQ **1,985 → 1,874**
and separate host-layout model 1,080 cycles unchanged. Tiny's previous full
graph measurement is 4,781 cycles with graph SRAM0_DEPTH=65536 (256 KiB versus
NMA 128 KiB). Input/layout/preload and controller boundaries still differ; no
matched system speedup is reported or full Transformer speedup inferred.
A future system comparison needs a common clocked transfer/commit adapter or
instrumented full graph controllers and common quantization/layout semantics.
This experiment establishes trustworthy phase boundaries and arithmetic pairing;
complete equal-boundary TinyNPU system benchmarking remains open.

## 4. Cost, timing and verification

Hardware state: **zero new data flops, buffers, FIFO entries or MACs** at RTL.
Matrix adds a mode-dependent FSM transition and group-reset selection. LN adds
32-bit Gamma-result selection into `output_word_r`, an existing-register-to-X
selection, and state/enable decode. Actual synthesized cell/mux sharing, power
and area are unmeasured. No source files/modules moved or added to RTL lists.

The two LN multipliers remain on separate registered stages with INT32
saturation between them. Beta response data enters a register; no response-to-
multiplier cascade is added. Matrix ready/output paths and outstanding FIFO
widths do not change. Remaining possible critical paths include indexed operand
register muxes, Gamma multiply/clamp, normalization multiply/add/clamp, and the
baseline Residual response/add/shift/clamp path. These are structural review
findings; **400 MHz / 4 ns is not established by a simulation clock**. SRAM macro
latency/ports, timing, reset implementation and response-order assumptions still
need integration review, synthesis and STA.

VCS V-2023.12-SP1_Full64 results:

- SFU three seeds 20261109/10/11: 64 numerical + 9 error cases each; 39 selected
  reset and 39 abort states each; parameter latching and Golden PASS.
- Matrix same three seeds: 18 numerical / 35 fault cases each plus Product GEMV
  tails/multirow/cache and six shape bins; accepted read drain, response parity,
  prefetch abort/watchdog/reset, held request stability and line contracts PASS.
- Depth-2 Matrix focused regression and no-prefetch fallback regression PASS.
- The watchdog probe cut point changed 20 → 17 to expire during active prefetch
  after the speedup. Its error-code, outstanding drain, no stale validity and
  recovery checks remain. No assertions or numerical checks were removed.
- Top `ai_smoke`, 20-case seed-12345 `ai_run`, persistent H16 Golden/hash checks,
  trained CNN, common CNN, paired trained QKV and Tiny's 6 engine tests PASS.
- Verilator 5.052 lint/elaboration exits zero: SFU 17 inherited warnings, Matrix
  60 inherited warnings; warning category/count multisets match baseline
  (width and reserved-symbol warnings). This is not warning closure or DC proof.

No full UVM closure, SpyGlass signoff, DC/LEC, DFT or backend work was performed.
**DESIGN_PARTIAL** remains appropriate: numerical/interface evidence is positive,
but equal-boundary system comparison, physical timing and SRAM macro integration
remain unresolved. Stop after publishing this experiment; no next round started.

Raw logs, trace CSVs, state partitions, hashes and ablation data:
`benchmark/representative/schedule_optimization/manifest.json`.
See [REPRODUCTION.md](REPRODUCTION.md) for exact commands and artifact boundaries.
