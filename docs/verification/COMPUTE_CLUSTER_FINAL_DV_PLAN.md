# Compute Cluster Final DV Plan

**DUT baseline:** `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`
**Intent:** close existing seven-engine and memory integration requirements without duplicating mature block agents or changing architecture.

## Boundary and topology

```text
Virtual sequencer / scenario controller
  ├── existing control/CMDQ/CPLQ agent: descriptor publish, queue pointers, events, IRQ
  ├── existing DMA AXI4 agent: DDR memory, IDs, burst/backpressure, R/B and reset coordination
  ├── passive engine launch/done monitor: real seven engines remain in DUT
  └── passive SPAD interface monitor(s)
       DUT: ai_accel_compute_cluster
            + real ai_compute_spad_mux
            + real ai_spad_arbiter
            + real ai_spad_protection
            + four-bank behavioral ai_scratchpad with parity backdoor
       independent per-opcode Goldens + accepted-write byte memory image
       response-owner ledger + completion queue scoreboard
       functional coverage, assertions and optional formal harnesses
```

Use the real top-owned mux/arbiter/response router, not a testbench replacement. At a cluster boundary, retain exactly the selected launch fields, seven engine status vectors, scalar/banked/line SPAD interfaces, and completion event. Reuse `dv/block/compute/fp/` UVM/reference models and `dv/subsystem/dma_spad/` arbiter/CNM/SPAD checks; port the task-based Matrix/CNN/KV Goldens into the shared memory-image scoreboard only where no reusable checker exists. Do not create duplicate AXI or register agents.

Recommended phases: (1) compact memory allocator and static geometry gate; (2) seven isolated engine tests with same shared arbitration path; (3) owner and banked/line contention; (4) parallel dispatch/ordered completion; (5) legal fault × phase × abort/reset tests; (6) top smoke and fixed-SHA replay.

## Agent / monitor / scoreboard ownership

| Component | Responsibility |
|---|---|
| Control agent | Writes descriptors/data, publishes CMDQ_TAIL, consumes CPLQ, changes CPLQ_HEAD while busy, checks registers/IRQ. |
| AXI4 agent | Models external memory, independent AR/R/AW/W/B handshakes, IDs, latency, response status, and coordinated reset when a transfer is accepted. |
| SPAD request monitor | Records every `valid && ready`, width/type, address, strobes, requester class and accepted cycle. Never counts valid-only stalls as accepted work. |
| SPAD response-owner monitor | Enqueues owner metadata on accepted reads; checks response order/data/parity/protection/lane mask and reset flush. No out-of-order return unless interface is explicitly changed. |
| Engine monitor | Samples launch fields at launch, enforces exactly one engine per descriptor, observes independent done/error/result/cycle/element and no duplicate completion. |
| Golden/memory scoreboard | Independent arithmetic and layout per opcode; byte-addressed old/new memory image updated only on accepted writes; checks untouched guards and accepted prefix. |
| Queue scoreboard | Tracks descriptor order, per-engine active slot, result slot, 4-word completion commit, tail/head wrap and dependency signals. |
| Coverage collector | Separates functional requirements, legal cross coverage, raw DUT code bins and assertion attempts/results. No combined DUT+UVM score presented as DUT-only. |

## Seven-engine RTM focus

| Engine / IDs | Required directed and constrained-random checks | Error/priority and recovery checks | Main completion criteria |
|---|---|---|---|
| Scalar INT8 `0x10..0x17` | Every opcode; legal minimum/maximum/odd lengths; signed lane extrema; shift/activation/saturation; address stride and output layout. | Abort/watchdog/protection/parity at read, calculate and write phases; compare accepted output prefix and restart. | Independent dot4/INT32 Golden and memory image exact; accepted read owner has no leak. |
| CNM `0x20/0x21` | Four-lane independent addresses/masks, M rows, packed dot4 boundaries, local/global reduction, stalls and lane skew. | Each parity lane, shared protection, abort during lane response, watchdog and reset; Matrix banked simultaneous request. | Per-lane request/response ledger; no cross-owner/lane response; exact 64-bit-local then specified quantized result. |
| Matrix `0x30/0x31/0x52/0x53` | Tile and macro-tile boundaries, all legal transpose/stride/bias/activation modes, K tails/opcode restrictions, line aligned/fallback writes, configured depths. | Fault at every banked response/writeback boundary; full-strobe line protection; abort/watchdog/reset while reads outstanding; accepted prefix. | Independent element-address Golden, maximum outstanding=4 by default, no response metadata loss, line data/WSTRB stable under stall. |
| SFU `0x32..0x39` | Every opcode with exact fixed-point boundaries, zero/one/extreme vectors, epsilon, beta/gamma, packed requant and tile-A order. | Numeric error, parity/protection, abort/watchdog while divider/sqrt busy, reset/recovery. | Bit-exact independent integer model; output packing and masked tail lanes exact. |
| Conv `0x16/0x17` | Width=3, max width, height=3, row transition, output edge, channel/depthwise mapping, signed extremes. | Combined SPAD error mapping, watchdog/abort in each row phase, reset and recovery. | Independent convolution Golden, line-buffer window and output address/prefix exact. |
| KV `0x43/0x44` | Legacy copy/read boundaries and persistence; `0x43 flags=1` append at lengths 4/8/12/16, capacities 4/8/12/16, each byte lane, head/token boundaries and invalid flag/stride/shape. | RTL priority is watchdog > abort > merged SPAD error; reset clears control state but does not define SRAM clearing. Inject faults at source read, destination read and accepted write; check no request for precheck-invalid descriptors and exact accepted prefix. | Independent byte-memory image checks legacy offset and append physical `[token,feature]` layout, preserved neighbor bytes and precheck no-side-effect. |
| Mixed FP `0x50/0x51` | BF16/FP16 finite, signed zero, subnormal/NaN/Inf contract, lengths 1/2/odd/max, two reads outstanding, ordered returns. | Parity/protection read/write priority, abort/watchdog with paired responses accepted, reset and clean next task. | Bit-exact FP32 result; unused odd tail excluded; all accepted responses drained before done/error. |

## Compact 128 KiB fixture allocation

Default absolute SPAD window is `[0x10000,0x30000)`. Use half-open ranges, 16-byte alignment for line buffers/Matrix line outputs and 4-byte alignment for scalar words. Every allocation records owner, direction/lifetime, size in bytes, start, exclusive limit, permitted concurrent tasks, protection region and SHA256 of initializer. Address arithmetic uses at least 33 bits; allocate failure is fatal. Do not mask high address bits.

For the existing H16 persistent workload, the reviewed allocation evidence records tensor high water 69,568 bytes, CMDQ base 69,632, CPLQ base 86,016, and reserved end 88,064 bytes relative to the SPAD base (`docs/research/FINAL_ARCHITECTURE_SPEC.md:139..145`). That leaves the remainder unused and proves this one fixture fits: absolute end is `0x10000 + 88064 = 0x25800 < 0x30000`. Re-run the allocator manifest at the target SHA; this arithmetic is not proof that the old all-engine fixture fits.

Recommended allocation policy for the old 512 KiB fixtures:

1. Inputs/weights and persistent KV occupy disjoint, read-only extents while overlapping engines run.
2. Each concurrently active engine receives a non-overlapping output extent; a task may read another task's immutable source, but no active task may overwrite another task's live input, weight, descriptor, or KV extent.
3. Reuse temporaries only after the producer's output is committed and all consumers retire; record that dependency edge in the allocation manifest.
4. Place descriptors and CPLQ in dedicated compact extents, reserve guard words before/after each arena, and verify no region crosses `0x30000`.
5. Protection has only four regions; coalesce extents only when their permissions and lifetime policy are identical. Since permission is not engine-owner-specific, protection is not a replacement for allocator non-alias checks.

The closeout RTM's old seven-engine fixture uses `0x7d000` and fails at default depth. It must be compacted and all pairwise overlap scenarios rerun; no conclusion about engine capability should be drawn from this environment/fixture failure.

## Functional coverage plan

Cover accepted (not merely asserted) request by engine × request kind (scalar/line/banked/CNM) × read/write × ready-stall bucket × response delay × bank/lane; descriptor opcode × shape class × alignment × layout flags; completion order × queue fullness × consumer-head progress; and engine × fault kind × phase × abort/reset timing. Add explicit bins for both sides of every same-cycle priority row in SPEC v1.8. Illegal software address conflicts are separate negative robustness tests, not legal parallel-performance coverage.

Raw code coverage must be reported per DUT module and parameter profile. Matrix `MAX_OUTSTANDING_READS=2/4` and SPAD 8192/32768 profiles must not be merged if elaborated bins differ. Explain every unhit condition/FSM transition as reachable test, proven unreachable, not applicable, or unresolved; do not delete assertions or waive bins by percentage target.

## SVA and formal plan

P0 properties: selected request is stable until accepted; only accepted owner receives ready/protection/response; response order equals accepted read order; CNM lane mask is exact; no write after terminal error except a same-edge accepted write allowed by prefix contract; all accepted writes form a contiguous prefix; each descriptor maps to one engine/slot; each engine done captured once; CPLQ tail advances only after four word accepts; ordered retirement; reset clears local valid/owner/FIFO state; no stale response can write after coordinated reset assumption.

Formal harnesses should prove local mux one-hot selection/owner retention, arbiter class exclusivity/round-robin progress under explicit ready assumptions, dispatcher one-slot-per-engine and ordered retirement, writer four-word commit, Matrix buffer-valid/response metadata safety, and engine-specific writeback exclusion after prior error. Progress proofs need explicit bounded environment fairness and response assumptions. External AXI epoch behavior must be proven at the fabric boundary or remain a system-level assumption with integration evidence; do not claim it from accelerator-only formal.

## P0 / P1 / P2 priorities

| Priority | Closure item | Exit evidence |
|---|---|---|
| P0 | Compact 128 KiB allocation; real-top seven-engine pair concurrency; exact owner/tag/lane routing; accepted-prefix at all fault cuts; CPLQ full + busy-time head progress; reset/fabric response isolation; Matrix/CNM shared class competition. | Fixed-SHA clean replay; independent memory/result scoreboard; zero stale/orphan responses; all required legal crosses hit or formally dispositioned. |
| P1 | Full per-engine opcode/shape/address boundary and numeric edges; outstanding-depth high-water; protection × phase; same-cycle priority × reset/abort; Matrix line stable/full-WSTRB and fallback; static warning disposition and full RDC. | Per-engine RTM rows PASS or named blocked spec; exact tool version and clean logs; no blanket waivers. |
| P2 | Expanded random distribution, broader mutation campaign, optional dual-clock shell tests, exhaustive non-product 512 KiB profile, performance counter correlation and additional model/workload breadth. | Deterministic seeds, targeted mutation expected catches, scoped signoff statement. |

## Reproduction and stop boundary

The later PR #7 candidate bundle lists exact run commands and hashes in `benchmark/verification/frontend_closeout/manifest.json` and compressed evidence under `benchmark/verification/frontend_closeout/evidence/`; these paths are not present in the exact-SHA review tree. The current review ran the EDA configuration doctor, validation, and lint/synthesis dry-runs; it did not execute VCS, SpyGlass, RDC, formal, DC or P&R. Complete the compact-allocation and cluster replay before treating the Architecture Freeze Checklist as closed.
