# Phase 3 Gate 1 — vector SFU transaction feasibility

**STOP_SFU_CANDIDATE_FAULT_CONTRACT_NOT_PROVEN. No vector SFU RTL admitted.**
The latency projections exceed the 20% research threshold, but authorization and
fault retirement are not proved. They are conditional predictions, not measured
product improvements. Baseline RTL is product merge
`c93ea144713d5fafe2e8a5509029927cd6859e75`; no modified SFU SHA exists this round.

## Actual service geometry and ownership

Source review: `ai_tensor_sfu_core.v`, `ai_tensor_sfu_math.v`,
`rtl/memory/ai_scratchpad.v`, `ai_spad_arbiter.v`, `ai_spad_protection.v`,
`rtl/top/fabric/compute/ai_compute_spad_mux.v` and memory fabric/subsystem.
Four physical 32-bit banks do **not** give SFU four independent request ports.
The scheduler arbiter admits one transaction/edge across its data/control
clients. A scalar 4 B transaction selects one bank. An aligned line/banked 16 B
transaction uses all four banks instead of an additional scalar transaction.
Host/debug Port A is not a free SFU port; host conflicts have explicit behavior.

The existing SFU only exposes scalar request/response. Matrix owns the current
compute line/banked route. Reusing a 16 B route for SFU would require top/mux
request ownership, response tags/demux, permission granularity and error handling
changes. Physical per-bank parity bits exist, but the present line response error
can be aggregated. Do not wire that aggregate into a vector engine and assume
scalar semantics survived.

Current scalar reads are in order, one outstanding in the SFU FSM, no response
backpressure or arbitrary external transaction IDs. Observed scheduler read
latency is two edges. A modeled pipeline needs an accepted-read metadata FIFO
(address, descriptor epoch, group, operand and per-word destination), response
capture even during local stalls, and ordered output retirement. Tags must not
be reused while an old accepted response can return. Reset flush, abort/fault
stop-issue plus drain, watchdog ordering and exactly-once completion remain
architecture requirements, not features verified in new RTL here.

## Trace calibration and dependency model

[model.py](../../../tools/benchmark/phase3/model.py) replays all 672 SFU segments
from the immutable full H32 prefill+decode trace. Successful accepted request
states, actual addresses, two-edge response waits and arithmetic/control edges
reconstruct each scalar segment exactly. The exported decode calibration has
448 descriptors with zero cycle error. Every response is paired to an accepted
read in the actual all-client ledger. This is trace calibration, not an
independent implementation of the proposed arithmetic.

Decode window is 350,155 cycles = 273,699 SFU + 76,456 non-SFU. Exclusive cycle
categories reconcile to the full window; overlapping busy/contended counters
are not summed into that total. Matrix/SFU simultaneous busy is zero in this
fixed dependency-serialized decode. SFU has 1,568 denied issue slots. These are
logical arbitration slots, not measured physical bank conflicts. Other clients'
accepted slots are frozen relative to each captured descriptor; a changed
schedule would move them. The model is not a closed-loop dispatcher/arbiter
resimulation and does not establish future concurrent throughput.

All read issue/response state pairs were classified below. Counts are decode
state occupancy, so issue counts include denied attempts; response states include
both registered wait edges. Other arithmetic and write states remain separately
accounted in `sfu_states.csv`. Zero-use states are inspected source paths, not
new measured vector coverage.

| Request / wait states | Function | Issue / response-state cycles |
|---|---|---:|
|1 / 2|Softmax max pass|544 / 1,024|
|3 / 4|Softmax sum pass|512 / 1,024|
|5 / 6|Softmax output pass|512 / 1,024|
|10 / 11|RMS sum pass|0 / 0|
|18 / 19|Normalization affine X|4,096 / 8,192|
|20 / 21|Gamma|4,096 / 8,192|
|23 / 24|Vector A|39,632 / 77,824|
|25 / 26|Vector B|6,144 / 12,288|
|32 / 33|LN mean input|4,224 / 8,192|
|36 / 37|LN variance input|4,096 / 8,192|
|39 / 40|Beta|4,096 / 8,192|

Accepted-read inter-issue gaps by opcode are in `sfu_issue_gaps.csv`. They include
necessary operand/ALU/output dependencies as well as FSM gaps; they cannot all be
charged as removable SRAM latency. In particular, overlap must not publish a
younger output before an older operand has passed its check.

| SFU operation | Decode descriptors | Measured busy cycles |
|---|---:|---:|
|Residual 0x34|48|43,248|
|GELU 0x35|16|49,200|
|Requant 0x36|224|82,144|
|LN32 0x38|128|87,168|
|Causal softmax 0x39|32|11,939|
|Total|448|273,699|

Requant requires a source value before shift/saturation; packed output commits
only after its complete word. Residual needs both matching inputs. GELU uses
its original piecewise integer product and clamp, not a replacement LUT.
LN32 retains all input reads for mean and variance, ordered 64-bit reduction,
mean-before-variance and variance-before-sqrt/inverse barriers, Gamma/Beta reads,
post-Gamma INT32 saturation, and affine output. No length-32 input-cache bypass.
Softmax and its iterative divider remain unchanged. This trace gives no measured
lane evidence for RMSNorm, SiLU or noncausal softmax.

Candidate schedules hold two groups of four elements, at most four metadata tags
(actual maximum two), one memory admission/edge and registered response capture.
Arithmetic consumes the captured operands over subsequent cycles. A result must
be stable from a previous edge before a write can be accepted; the same-edge
result-capture/write shortcut is forbidden in the model as well as proposed RTL.
Arithmetic initiation interval is one per lane; modeled depths are requant/
residual 1, GELU 2, LN affine 3, mean 1 and variance 2. Mean/variance use a single
ordered one-element/edge reducer, not an uncharged multi-input reduction tree.
Each original read word is retained exactly once per original phase, with no
cache and no cancellation of intermediate writes. Scalar pipeline retains
input element/operand order within a phase but prefetches ahead of output
retirement. The hypothetical line model gathers four adjacent words from an
operand stream, only if fully aligned and contiguous, without fetching extra
words. That changes transaction ordering/granularity and is **not admitted**.

## Conditional cycle projections

| Arithmetic lanes | Proposed memory schedule | Modeled SFU | Projected full decode | Reduction vs 350,155 | Fault admission |
|---:|---|---:|---:|---:|---|
|1/2/4|Unchanged scalar FSM|273,699|350,155|0%|Unchanged by identity; no candidate gain|
|1|Scalar 4 B pipeline|123,683|200,139|42.8427%|NOT_PROVEN|
|2|Scalar 4 B pipeline|123,683|200,139|42.8427%|NOT_PROVEN|
|4|Scalar 4 B pipeline|123,683|200,139|42.8427%|NOT_PROVEN|
|1|Hypothetical 16 B line pipeline|92,563|169,019|51.7302%|NOT_PROVEN|
|2|Hypothetical 16 B line pipeline|88,595|165,051|52.8634%|NOT_PROVEN|
|4|Hypothetical 16 B line pipeline|86,931|163,387|53.3387%|NOT_PROVEN|

In the scalar pipeline, additional arithmetic lanes provide no incremental gain:
serialized operand service dominates. New lane arithmetic and II are assumptions;
no proposed implementation has been verified against numerical Golden.
The full-window estimate holds non-SFU cycles fixed and substitutes scheduled
SFU phases plus the observed remaining iterative/barrier work. Changed descriptor
concurrency, protection faults, watchdogs and dynamic host writes are not solved.

Resource lower bounds are exported per phase in `sfu_resource_bounds.csv`:
maximum of required memory admissions and arithmetic issue edges (one ordered
reduction/edge for LN), before response, dependency and barrier overhead.
Non-softmax scalar schedules retain 65,536 read words and 26,112 output words,
requiring 91,648 memory admissions. The line hypothesis serves the same words in
42,496 admissions. Unchanged softmax adds its existing work to both. These are
service bounds, not a whole-system latency bound. The all-client response
histogram includes prefill/checker traffic and must not be relabeled SFU decode.

## Real-memory counterexamples

New VCS test `tb_phase3_fault_contract.sv` instantiates the **unchanged** SFU,
real behavioral scratchpad and real protection checker, not a proposed vector
engine. Four GELU input words, second word with deliberately corrupted parity:
scalar engine commits one legal output, reports local ERR_PARITY=5, and leaves
three sentinels intact. Reading the same line yields parity mask `0010`.
Naively reporting the aggregate fault before word zero retirement would erase
the legal accepted prefix.

A separate check uses adjacent permitted regions `[0x100,0x108)` and
`[0x108,0x110)`. All four scalar reads are authorized; a 16 B transaction is
denied because no single region contains it. Even identical returned words do
not preserve the access contract. Both counterexamples PASS with real modules.
They disprove naïve aggregation, not every possible streaming architecture.
A future design might retain scalar authorization and ordered per-word error
retirement, but must separately prove read-time behavior, DMA/host coherence,
epoch drain and accepted-prefix equivalence before admission. No relaxed mode,
A3/B2 transparent bypass or product interface change is introduced.

## Hardware budget and timing risks

| Modeled resource | Design budget; not mapped area |
|---|---|
|Operand storage|2 groups × 4 elements × 3 operands × 32 = 768 data bits (96 B)|
|Results|2 × 4 × 32 = 256 data bits (32 B)|
|Read metadata|At most four entries; example 32-bit address + 16-bit epoch + group1 + operand2 + destination mask4 + valid1 = 56 bits/entry, 224 bits; epoch reuse/drain still requires proof|
|Group/control metadata|Operand ready24 + result valid8 + fault mask8 + two 16-bit indices32 + counters/state estimated64 = 136 bits; not an exhaustive RTL register count|
|Arithmetic pipeline budget|Example per-lane two 64-bit intermediate stages + one 32-bit output + 8 control bits = 168 bits/lane; allocation/latency not synthesized|
|Shared sum/variance|Existing 64-bit reduction resources retained; new overlap/hold implementation not specified|
|Arithmetic replication|Up to three 32×32 product paths per lane for variance/GELU, Gamma and inverse scaling; 2/4 lanes could add 3/9 paths; sharing changes II and requires remodeling|
|SRAM|0 additional SRAM bytes/ports in the hypothesis; operand/result/tag storage would be flops|

Illustrative subtotal 1,384 + 168×lanes = 1,552/1,720/2,056 bits, excluding
unresolved fault-retirement/coherence metadata and any extra pipeline cut needed
for timing. This is a planning budget, not an implemented bounded netlist proof.
A line-capable ownership mux and per-lane dispatch/broadcast/retirement add control.
Target a registered memory response → operand register → arithmetic stage → result
register structure. Do not create response → lookup/mux → SFU arithmetic in one
uncut cycle. Multiplier/clamp, wide operand select and retirement fanout require
mapped STA for 2.5 ns. No PPA/Fmax assertion.

Vectorization, tagged pipelines and ping-pong buffering are established methods;
see the repository prior-art comparison (Eyeriss, Gemmini, Timeloop). Exact
protection-preserving scheduling may be an engineering contribution, but this
phase has neither a complete safe design nor evidence of literature novelty.
Stop this SFU candidate here under the fault-contract admission rule.
