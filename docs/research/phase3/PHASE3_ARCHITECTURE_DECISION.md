# Phase 3 — architecture research decision

**RESEARCH_PARTIAL; product DESIGN_PARTIAL. Stop after Gates 0–2.**
Phase 2 LN32 is retained and merged. No Phase 3 Matrix/SFU product RTL change,
new SRAM port, MAC, descriptor, relaxed fault mode or transparent bypass.
Research artifacts are on `feat/phase3-throughput`; its published commit is the
Git commit containing this report (recorded in the final delivery/remote check).

| Gate / candidate | Evidence and decision |
|---|---|
|0: Phase 2 review|PASS; [PR4](https://github.com/cwu766485-ctrl/NMAForge/pull/4) merged to nmaforge at `c93ea144713d5fafe2e8a5509029927cd6859e75`, remote SHA verified|
|1: SFU streaming|Conditional cycle target exceeded, but permission/fault order not proved; STOP candidate, no RTL admission|
|2: CNN writeback|Small two-buffer overlap is feasible in transaction model; present findings, no automatic implementation|
|3: Tiny contract|Pinned desk review/archived evidence only; a new native/full-system campaign not started|
|4: RTL implementation/freeze|No Phase 3 candidate implemented; no architecture freeze/signoff claim|

Measured RTL tree `fe0e999fa187c4ed52a512d27509d5922e6137eb` is identical to
Phase 2 `20bd47ca714551607268d62a74e2c507fbadc7c4`.
Approved pre-LN32 baseline remains `48790076b351cb9d49e1785247d32a1f51b8286d`.
Measured fixed-input H32 decode 350,155 / 8 = 43,769.375 cycles/token, H16
65,771 / 8 = 8,221.375, CNN both-fused 12,351 CMDQ cycles; all strict Golden PASS.
H32 SFU 273,699 cycles dominates; CNN writeback 5,200 and operand wait 3,219 dominate
its actual matrix window. Compute read/write bytes H32 546,816/227,840;
H16 72,448/42,112; CNN 64,064/16,640. All are accepted compute traffic, separate
from descriptor/completion, host fixture preload and DMA/system inference.
CNN useful throughput 46.1634 MAC/cycle (18.0326% of 256-MAC full-CMDQ capacity).
The exclusive window sums reconcile exactly; overlapping counters are separate.

## Candidate decision and incremental cost

SFU single-lane pipelining projects 350,155 → 200,139 cycles (42.8427% reduction),
while scalar 2/4 lanes give the same result. Hypothetical 16 B line, 4-lane scheduling projects
163,387 (53.3387%). These are conditional trace-calibrated transaction schedules,
not measured latency, safe lower bounds or closed-loop product results.
Model retains all read words/intermediate writes. Real SRAM/protection tests
expose legal scalar-prefix and adjacent-region counterexamples to naïve wide
fault aggregation. Additional ordered per-word authorization, error retirement,
coherence and epoch drain have not been designed/proved; ≥20% alone is not
admission. Stop without resuming A3/B2 or modifying the fault contract.

The SFU planning budget has 1,024 operand/result data bits + 224 tag bits + 136 metadata bits
and 168 pipeline bits/lane, before unresolved recovery/coherence state; up to 3/9
extra 32×32 product paths for 2/4 lanes. Not synthesized/implemented. More arithmetic
lanes have no evidenced scalar-port benefit and carry timing/area cost.

CNN four existing postprocess lanes + two ordered 128-bit buffers project
12,351 → 11,376 cycles: 975 saved / 7.8941% reduction (1.0857× predicted speedup).
The 4,160 pack edges are actual work; overlap only removes 15 commit-only edges/tile,
leaving the final drain. Extra line data 128 bits; illustrative additional metadata
≤108 bits, no new arithmetic lane or SRAM. 1,560 abstract FIFO invariant cases and
1,040 immutable Golden payload transactions PASS. No implemented RTL, watchdog/
abort priority proof or measured candidate gain yet. This is the preferred
**next proposal**, subject to the explicit next RTL decision and focused fault,
backpressure/full-model regressions. Other wider-packer projections are sensitivity
analysis, not selected implementations.

## Reproducibility and limitations

[VCS review](PHASE3_PHASE2_RTL_REVIEW.md),
[SFU model and fault contract](PHASE3_VECTOR_SFU_FEASIBILITY.md),
[CNN model](PHASE3_CNN_WRITEBACK_MODEL.md),
[Tiny contract](PHASE3_TINYNPU_BENCHMARK_CONTRACT.md),
[exact commands](../../../tools/benchmark/phase3/README.md),
[public manifest](../../../benchmark/research/phase3/manifest.json).
Archive hash inventory pins all product RTL, benchmark/model tools, fixture/
Golden references, real-memory counterexample TB, tool versions and measured
service geometry. Fresh merged-HEAD replay exactly matches all 12 Phase 2 summary
records and raw traces/Golden in the referenced ledger. VCS LN32 numerical/fault/
reset/abort/watchdog checks, Top smoke/seeded 20, independent CNN and H16/H32
Logits/KV/intermediate Golden PASS. New transaction models pass calibration and
invariants; that does not validate candidate RTL which does not exist.

Main and original development branches/worktrees are preserved. Phase 3 is
published on its own branch; no failing/experimental RTL is merged into product.
No PDK, license, private library, generated simulator or waveform is included.
No automatic next stage or second RTL modification follows this report.

## Research value and freeze blockers

Decoupled queues, SIMD/streaming and ping-pong buffers are established prior art.
Repository prior-art entries include Eyeriss (JSSC 2017,
10.1109/JSSC.2016.2616357), Timeloop (ISPASS 2019,
10.1109/ISPASS.2019.00042) and Gemmini (arXiv 1911.09925).
This phase supplies calibrated bottlenecks and concrete safety counterexamples;
it does not establish literature novelty or a paper-level new vector engine.
Tiny's exact raw adapter checks remain limited to 1.20–1.27×; native whole-CNN/H32
math/quantization/DMA/endpoint compatibility is not established. Tiny has native
SFU/LLM blocks; differences must be measured rather than called unsupported.

Remaining freeze obstacles: (1) safe streaming fault/authorization/lifetime
contract; (2) real CNN overlap implementation/regressions if approved;
(3) fair same-endpoint native/full-system benchmarks; (4) inherited top latch/
combinational-loop/width dispositions; (5) registered mux/arithmetic timing and
SRAM-macro integration/port semantics; (6) broader functional fault/reset and
concurrency coverage. H32's 100% blind accuracy is for a simple synthetic period-3
task also solved by a lag-3 rule; it supports arithmetic/mapper validation, not
language-model usefulness. No comprehensive SpyGlass/DC/DFT/P&R initiated;
no mapped area/Fmax evidence or 400 MHz claim. Product remains DESIGN_PARTIAL.
