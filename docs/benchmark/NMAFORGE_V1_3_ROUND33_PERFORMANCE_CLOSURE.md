# NMAForge V1.3 Round 33 — Overlapped Execution and Performance Closure

**Disposition: `PERFORMANCE_CLOSURE_PARTIAL`.** The isolated candidate reduces
the large fixed-memory GEMM cycle counts and passes the Round33 challenge goals
for 32×32×64 GEMM, fixed 64×64×64 GEMM, and all three seeded 64×64×64 GEMM
runs. It does not meet every small-GEMM or GEMV challenge goal. A fair TinyNPU
L1 comparison shows NMAForge faster on four matched INT8 GEMM workloads, but
the full GEMV and shared-CNN comparisons are still open. No overall
TinyNPU-dominance claim is made.

This work is isolated on
`research/nmaforge-v1.3-round33-overlapped-execution`, based on
`651c32db216c34e653575dbeaddaefd4787a5c91`. The main worktree and unrelated
changes remain untouched. Product Top remains `rtl/top/ai_accel_top.v`, with
one 16×16/256-MAC array and default 128 KiB SPAD. The ABI, SPAD arbitration,
DMA, queue ownership, and completion contracts are unchanged.

## Round33 cycle goals

| Workload | Round32 baseline | Round33 result | Minimum | Challenge | Result |
|---|---:|---:|---:|---:|---|
| GEMM 16×16×16, fixed | 119 | 115 | ≤119 | ≤105 | Minimum pass; challenge misses by 10 |
| GEMM 16×16×32, fixed | 167 | 159 | ≤160 | ≤145 | Minimum pass; challenge misses by 14 |
| GEMM 32×32×64, fixed | 804 | 564 | ≤750 | ≤650 | Minimum and challenge pass |
| GEMM 64×64×64, fixed | 2,768 | 1,606 | ≤2,600 | ≤2,200 | Minimum and challenge pass |
| GEMM 64×64×64, seeded | 3,550/3,529/3,546 | 2,205/2,209/2,204 | ≤3,200 | ≤2,800 | All three challenge runs pass |
| GEMV 1×64×64, fixed | 358 | 313 | ≤358 | ≤300 | Minimum pass; challenge misses by 13 |
| GEMV 1×64×64, seeded | 442/483/475 | 406/429/423 | ≤450 | ≤400 | Minimum passes; challenge misses on all seeds |
| GEMV 1×256×64, fixed | 1,414 | 1,249 | ≤1,350 | ≤1,150 | Minimum pass; challenge misses by 99 |
| GEMV 1×64×256, fixed | 2,261 | 2,005 | ≤2,000 | ≤1,700 | Minimum misses by 5; challenge remains open |

The fixed 64×64×64 GEMM issues 8,192 SPAD read bytes, preserving Round32's
traffic result while reducing the fixed-memory cycles by 42.0% from Round32.
The useful MAC rate rises to 163.2 MAC/cycle (63.8% of the 256-MAC array) at
the fixed one-cycle SPAD boundary. These are behavioral RTL cycle results,
not frequency, area, or sign-off measurements. Full rows and target status
are in [`comparison.csv`](../../benchmark/performance_dominance/round33/evidence/comparison.csv).

## TinyNPU comparison boundary

TinyNPU is pinned at
`8216c22b762011aa20c05fc2768423fd12dda59d`. The fresh L1 harness runs its
native `gemm_ctrl` and `systolic_array` against the actual four-bank `banked_sram`
module. The SRAM has four 4 KiB banks in each of two ping-pong planes. A
testbench address adapter maps address bit 14 to the existing ping-pong select
so the full physical 32 KiB is reachable; the controller and SRAM RTL are
unchanged. SRAM reads are registered with one-cycle latency, and reads and
writes each sustain one byte per cycle. Initial operands are populated before
the timed controller command on both sides.

For four GEMM shapes, both systems use the same deterministic signed INT8
operands, INT32 accumulation, saturating INT8 output, independent Golden, and
one byte/cycle effective read and write bandwidth. The NMAForge side models a
16-byte transfer every 16 cycles (one-cycle response); TinyNPU issues native
byte transfers. Thus the effective bandwidth is normalized, while the
transaction granularity differs. Actual bytes are included in the CSV:

| GEMM shape | NMAForge L1 cycles | TinyNPU native L1 cycles | Tiny/NMA | NMA/Tiny read bytes |
|---|---:|---:|---:|---:|
| 16×16×16 | 740 | 1,332 | 1.80× | 512 / 512 |
| 16×16×32 | 1,252 | 2,919 | 2.33× | 1,024 / 1,024 |
| 32×32×64 | 5,156 | 24,369 | 4.73× | 4,096 / 8,192 |
| 64×64×64 | 12,836 | 97,473 | 7.59× | 8,192 / 32,768 |

The geometric-mean Tiny/NMA cycle ratio is **3.50×** across these four
matched L1 GEMMs, so the Round33 GEMM cross-project threshold of 1.05× passes
for this specified set. TinyNPU rereads B for each M tile in the two larger
cases; this actual controller traffic is retained in the comparison rather
than normalized away. NMAForge's added caches and the storage totals appear in
[`resource_and_ppa.csv`](../../benchmark/performance_dominance/round33/evidence/resource_and_ppa.csv).

L0 TinyNPU direct-array values (52/100/790/3,166 cycles for the four GEMMs)
remain `NOT_COMPARABLE`: they exclude Tiny's controller and SRAM, whereas
NMAForge's earlier rows include Matrix Core and SPAD service.

The native TinyNPU controller also passed INT8 Golden checks for M=1 cases
1×16×64, 1×64×64, and 1×256×64. These are not counted as cross-project GEMV
speedups because NMAForge's native opcode `0x52` path writes INT32 while
TinyNPU's native `gemm_ctrl` writes saturating INT8. The TinyNPU 1×64×256 case
completed its command but failed 64/64 independent output checks; its cycles
are withheld from the comparison. The pinned Tiny controller stores
`k_tiles_r` in four bits, so the required 16 K tiles for K=256 encode as zero;
its `multi_k` check then treats that command as a single K tile. The source
and failure trace are preserved without changing TinyNPU. Therefore the Round33 GEMV cross-project
threshold is not closed. TinyNPU's pinned `rtl/top.sv` ties graph status to
zero and does not instantiate `graph_top`, so no native Product Top + DMA +
runtime L2 execution endpoint is available. The shared CNN L2 speedup remains
`NOT_COMPARABLE`.

## RTL changes and isolated effects

- Added one 1 KiB result-ownership buffer for a full 16×16 INT32 tile. While
  its owner writes lines through the existing SPAD line port, the MAC array
  may start the next tile. Partial tiles keep the previous path. The buffer
  holds ownership through backpressure and drains before command completion;
  abort, protection, and reset are handled in the existing command lifecycle.
- Added a direct operand-prefetch kick that removes controller bubbles, and
  a GEMV K-group path that starts MAC when its first valid A/B group is ready.
  Subsequent GEMV groups stream while MAC is active. Existing A/B cache arrays
  are reused; the outstanding-read limit remains 8.
- At fixed memory, disabling only output overlap increases 32×32×64 GEMM
  from 564 to 756 cycles and 64×64×64 from 1,606 to 2,566. Disabling only
  direct operand prefetch raises the same shapes to 594 and 1,666 cycles.
  Disabling GEMV fill/MAC overlap raises 1×64×64 and 1×256×64 from 313/1,249
  to 373/1,489 cycles. Every isolated ablation passes Golden.
- The direct-prefetch-off experiment's first compile used an obsolete control
  parameter and is not included; the retained `compile_iter2`/`fixed_iter2`
  logs compile the actual direct-prefetch ablation. A prior GEMV streaming
  experiment that disabled the required loader path is discarded because its
  Golden failed.

The 32×32×64 overlap stress observed 158 cycles of MAC/writeback overlap,
388 writeback cycles, and 132 line-stall stability checks with the output
owner held until drain. Abort while held, protection denial, reset, and clean
Golden recovery also passed. Exclusive state totals and overlapping events
are separated in [`cycle_breakdown.csv`](../../benchmark/performance_dominance/round33/evidence/cycle_breakdown.csv).

## Verification and guardrails

- Focused full matrix regression: 18 numerical cases and 35 fault scenarios
  pass at seed 20261122, covering odd K/tails, signed extremes, prefetch,
  parity, protection, abort, watchdog, and reset recovery. Wide GEMV suite
  passes independent signed INT32 Goldens at seeds 20261122/24/25.
- Product Top `make ai_smoke` and the 20-case `make ai_run` seed 12345 pass.
- Compute Cluster real UVM passes at 128/256/512 KiB with seed 20261122;
  each run includes the cache, concurrency, GEMV-tail, parity, protection,
  reset, and command-retirement checks in the existing target.
- Existing synthetic `conv1x_mini` Product Top regression passes 20,480
  Golden words (4 descriptors, 59,620 command cycles). This is a functional
  datapoint, not a TinyNPU timing comparison.
- Existing Round31 DeiT attention/output-projection regression passes
  72,384 Golden words over 64 batches and 16 valid query rows (1,332
  descriptors; 811,476 runtime cycles). It still covers only 16 of 197 rows.
  GPT-2 was not run because its existing target retrains the model; the plan
  prohibits starting retraining. No 12-layer DeiT development was started.
- Current-source GEMV request-stability formal passes one non-vacuous
  assertion and reaches its backpressure-release cover. The new overlap
  harness proves the legal-writer-owner and accumulator-preservation
  assertions, but its two other assertions do not converge within 360 s.
  The existing matrix FSM guard run proves 1/5 assertions before its 360 s
  timeout. Formal closure is partial; no property or assumption was weakened.
- `dc_shell` is unavailable and `TSMC28_STDCELL_DB` is unset. Area and timing
  guardrails are `BLOCKED_ENV`; no PPA or frequency result is claimed. The
  new 1 KiB buffer is accounted for, but its mapped area and critical-path
  effect remain unmeasured.

Exact commands, return states, and raw evidence are in
[`verification_formal.csv`](../../benchmark/performance_dominance/round33/evidence/verification_formal.csv)
and [`run_manifest.json`](../../benchmark/performance_dominance/round33/evidence/run_manifest.json).
Compressed text logs are archived in
[`raw_logs.tar.gz`](../../benchmark/performance_dominance/round33/evidence/raw_logs.tar.gz).

## Final decision

Retain the measured overlap and prefetch candidate. It improves the large
GEMM path without changing traffic or MAC count and closes four L1 TinyNPU
GEMM comparisons. Overall closure remains **`PERFORMANCE_CLOSURE_PARTIAL`**
because small GEMM/GEMV challenge targets are missed, one TinyNPU GEMV Golden
fails, TinyNPU GEMV output precision is not matched, TinyNPU graph/Product Top
L2 is unavailable, formal proofs remain incomplete, and DC/PPA is blocked.
No TinyNPU-wide superiority claim follows from the GEMM-only comparison.
