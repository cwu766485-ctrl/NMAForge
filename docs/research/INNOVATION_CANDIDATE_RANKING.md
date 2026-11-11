# Phase 1 — innovation candidate ranking

Decision: **one RTL experiment recommended; second slot left unallocated**.
Phase1 implements none of these product changes. Candidate selection is based on
unchanged approved RTL `48790076b351cb9d49e1785247d32a1f51b8286d`,128KiB/four-bank,
256MAC, VCS V-2023.12-SP1_Full64/4ns behavioral SRAM. Hash-pinned source,
workloads, Golden, exact commands and PASS evidence:
[manifest](../../benchmark/research/phase1/manifest.json),
[reproduction](../../tools/benchmark/phase1/README.md),
[cycle attribution](../performance/NMAFORGE_PHASE1_CYCLE_ATTRIBUTION.md).
Analytical savings below are bounds, not modified-RTL measurements.

## B — exact Length32 SFU, rank1 / ADMIT_FOR_DECISION

**Narrow implementation proposed:** extend the existing length16 exact mean and
variance power-of-two division specialization to length32. Do not enlarge or
extend the X cache, do not skip X/Gamma/Beta SRAM reads, and do not change any
required read's authorization/parity observation point.

| Item | Evidence / proposed contract |
|---|---|
|Baseline|H32 decode367,051cycles;128length32LNdescriptors; LN104,064cycles|
|Removable cycles|ST_LN_MEAN_WAIT35 =8,448; ST_RMS_MEAN_DIV_WAIT13 =8,448;132wait clocks/LN|
|Ideal improvement|16,896cycles =4.6032% full Decode reduction;350,155/8=43,769.375cycles/token under unchanged dispatch/start cost|
|Expected implementation range|About4.53–4.60% if0–2extra clocks/LN; estimate only, data-dependent changed control must be measured|
|New state/logic|No new data buffer, SRAM port or MAC. Constant shift5, magnitude/sign restore, existing64-bit overflow comparison, length decode and result select; reuse existing sum/mean registers|
|Critical path|Magnitude/negation→range compare→sign restore/mux to mean register. Preserve pipeline cut;400MHz/2.5ns unproven without synthesis/STA|
|Correctness risk|Negative sum division truncates toward0, so arithmetic signed shift alone is wrong. Use magnitude>>5 then sign restore, matching original divider's quotient/range check including0x80000000. Preserve variance64-bit overflow/truncation, isqrt, reciprocal, epsilon, affine saturation and allerrorconditions|
|Fault/lifecycle risk|No read deleted or moved. Abort/watchdog can expire on a different cycle after acceleration; maintain precedence, terminal fault delivery and exactly-once completion; baseline watchdog programming must remain sufficient|
|Prior-art distinction|Constant-division specialization is standard strength reduction and length16already exists. This is a useful exact microarchitecture extension with measured end-to-end benefit potential, not an independent novel paper contribution|

The two START states already cost128clocks each; the bound removes WAIT clocks
only, never charges START as saved. Sqrt4,352 and reciprocal4,224wait clocks
remain. LN's fresh sum/variance/affine/Gamma/Beta reads and INT32 writes remain.
No cache-hit substitution is admitted. Optional residual/requant/GELU fusion is
not included: required intermediates and fault observations would require a
separate contract, beyond this experiment.

Entry criteria for the next authorized RTL phase: independent integer exhaustive/
directed arithmetic edges, unchanged descriptor ABI, structural synthesis review,
LN32focused/fault tests plus same-model full H32/H16/CNN Golden and timing.
RETAIN only on measured full-window improvement with all checks passing. Do not
claim the ideal number as achieved performance.

## C — bank-aware prefetch/scheduling, rank2 / DEFER

**Baseline:**32×32×64 productTop986cycles;312operand wait, of which300state14
PREFETCH_WAIT;256compute,256writeback.240prefetch/compute overlap, zero request
arbitration wait, outstanding highwater2. CNN12,351cycles has3,219operand wait
but only12arbitration-wait clocks. H32 has4,288sum request-form waits, overlapping
existing engine/control clocks and including control priority.

The existing8configuration×5shape block ablation proves existing mechanisms help:
32×32×64 d2/P0/C0→d4/P1/C1 is1,711→1,161cycles; read requests512→384.
Its randomized ready/response model differs from Top; this cannot be used as an
additional550cycle Top improvement or as evidence of actual bank collision.
Native line reads touch all4banks; relocating an aligned base cannot create
additional service bandwidth.

**Precise next research question:** can a legal earlier kick/registered readiness
handoff use the already available ping-pong buffer sooner while retaining all
original reads, ordered response metadata, authorization, fault-drain and
writeback order? Existing normal GEMM already issues B before A drain, so that
optimization must not be proposed again. GEMV retains an A-drain boundary;
removing it requires proving the A-line reuse/ownership invariants first.

| Item | Disposition |
|---|---|
|Removable cycles|Unproven;300PREFETCH_WAIT clocks are a ceiling containing mandatory bandwidth/latency and readiness work, not300removable cycles|
|Expected incremental improvement|NOT_ESTABLISHED. Full H32/CNN benefit cannot be projected from this ceiling|
|State/logic target|Reuse current two operand buffers,4-entry outstanding metadata and existing ports; at most a small registered readiness/kick select. No resource addition approved|
|Critical path risk|Response-complete/metadata select→buffer-valid→MAC launch; avoid unregistered SRAM response→operand mux→MAC path|
|Correctness/fault risk|Early issued access can change permission/fault timing; must not issue before descriptor ownership/dependency or publish data before allresponses validated. Abort/reset/watchdog drains remain mandatory|
|Prior-art distinction|Latency hiding/operand scheduling are standard; research value requires a demonstrated new safe schedule beyond existing prefetch, not a renamed cache|

No positive incremental transaction-level result exists in Phase1, so this
candidate is **not admitted for RTL**. Suggested next action is a model of the
observed schedule with explicit buffer lifetimes/service edges. Add no FIFO,
SRAM port or parallel array merely because the wait counter is large.

## A — existing0x53 fused epilogue extension, rank3 / NO_INCREMENTAL_CASE

**Baseline:**same trainedCNN legacy65,429 / first-fused22,983 / both-fused
row-major12,351cycles. Reads130,624→77,376→64,064B; writes83,200→29,952→16,640B;
20,800wordGolden and832worddeployment output allmatch. The two Matrix
Descriptors already perform both epilogues and row-major output. No remaining
separate Pack/Layout Descriptor exists for this graph.

Incremental removable Pack/Layout cycles are **0 identified**, expected benefit
unproven, added state/logic unspecified and therefore not justified. Host Im2col/
packing is a software/system mapping gap, not a missing Matrix epilogue. Existing
5,200writeback-state clocks include4,160packing/control edges; optimizing their
implementation could be a future proposal, but must preserve accepted-store
ordering and allintermediate semantics. It is not a new fusion feature under
this candidate definition. Wider output mux/pipeline could add timing and
fault-order risk with no proven benefit. Fusion/quantized epilogues are prior art;
current0x53must be the ablation baseline, not the unfused mode alone.

Transformer Matrix→requant sometimes exposes raw INT32 as required intermediate
results. Deleting them or substituting cached reads would repeat rejected B2.
No broader0x53conversion is admitted on the strength of these measurements.

## Freeze/innovation decision

Only B has a bounded, numerically defensible removable-cycle mechanism. The user
requested at most two evidence-backed candidates; there is no justification to
fill the second slot. C is the second investigation priority, not an approved
hardware change. A is already largely implemented. No independent paper novelty
is established by this phase. Existing opt-in elastic forwarding's fault/ownership
contract remains an open product qualification issue; transparent A3/B2remain
rejected. Front-end freeze remains DESIGN_PARTIAL pending the risk register and
stronger matched application evidence.
