# Phase 2 — architecture decision

**RETAIN_LN32; streaming remains a feasibility model pending fault-timing
review. Stop after Gates1/2.** No second RTL experiment is admitted this round.

## Decision evidence

| Category | Disposition |
|---|---|
| Existing mechanisms | LN16 input cache/constant division,0x52/0x53,Matrix caches/prefetch/elastic forwarding retained |
| Newly implemented RTL | LN32 exact mean and variance power-of-two division in existing SFU FSM only |
| Measured gain | Fixed qualified H32 decode367,051 ->350,155cycles/8tokens;16,896removed,4.603175% |
| Predicted gain | Streaming requant conditional additional43,504cycles/12.4242% after LN32; not implemented |
| Hardware cost LN32 | Zero added flops/buffer/port/MAC/ABI fields; length decode and combinational arithmetic/select changes |
| Hardware cost streaming | Estimated518state bits plus registered selects/packing/control; no synthesis or area evidence |
| Golden/fault validation | LN32 independent arithmetic/fullGolden/fault/recovery; H32/H16/CNN/Matrix/Top smoke+seeded20 PASS |
| Protection | All original reads/writes and authorization/parity checks retained; no transparent bypass |
| Static/timing | No new focused lint identity; inherited Top latch/loop/width issues remain; no Fmax/PPA claim |
| TinyNPU | Common raw adapter only; no matched native graph/full-system speedup |
| Freeze | DESIGN_PARTIAL; this acceptance is a bounded optimization decision, not frontend signoff |

Phase1 review found no RTL delta against the approved baseline. It was merged
without overwriting any worktree, and GitHub `nmaforge` was verified at merge
`cb08797e612355b404f9eb697a34f99628deebfd`. Candidate changes are on dedicated
`feat/phase2-exact-sfu`; no Phase2 product-branch merge is claimed here.
The final publication commit and remote verification are reported at handoff.
All source/workload SHA256, tools, boundaries and commands are archived.

## Why retain the RTL

The measured4.603175% full-decode reduction exceeds4%; all128LN32 descriptors
save132cycles. H16/CNN/fixedMatrix/GEMV retain identical cycles and traffic.
Both old and new arithmetic pass the independent integer oracle including
signed-truncation and generic divider overflow/cast edges. Access order/addresses
and required intermediate outputs remain intact. The bounded combinational
change is a useful implementation improvement with no new storage/ports.

Power-of-two constant division is established prior art, not a proven original
research contribution. Exact integration with the fixed-point fault-preserving
SFU and quantified graph effect is engineering evidence. Literature originality
for vectorized scheduling, existing0x52/0x53 and other mechanisms still needs a
separate systematic review; this phase makes no novel-paper claim.

## Why stop before streaming RTL

The model explains real two-edge SRAM latency and scalar issue gaps and shows
conditional throughput potential. It retains every read/check, numerical output
and required INT32 producer tensor. However, moving a read earlier may change
which Host write, parity fault or permission state it observes. Ordered error
retirement, alias fallback, epochs/ownership and late response disposal need
an explicit architecture contract and RTL proof; the358-case abstract model
is not that proof. The fixed competing-service trace also cannot predict a
changed arbiter schedule completely. No relaxed fault mode is introduced.

The next decision, if authorized separately, must settle those contracts and
validate closed-loop scheduling before implementation. A3/B2 bypass remains
rejected. No InnovationA3, new engine, MAC expansion or extra SRAM port starts.

## Remaining frontend freeze obstacles

1. Inherited `ai_compute_spad_mux` latch diagnostics and SPAD/protection
   combinational-loop warning dispositions need focused closure.
2. The new mean register path and existing arithmetic require mapped synthesis
   and timing evidence for400MHz; no valid Fmax evidence exists in this phase.
3. H32 synthetic memory-task quality is well above weak baselines but equals
   the lag3oracle; broader task quality and production host integration remain.
4. Native end-to-end CNN/Transformer TinyNPU comparison lacks equal endpoints.
5. Streaming fault-observation/ownership contract remains unresolved and is
   not part of the retained product candidate.

Reports: [implementation](PHASE2_LN32_IMPLEMENTATION.md),
[paired ablation](PHASE2_LN32_ABLATION.csv),
[streaming feasibility](PHASE2_SFU_STREAMING_MODEL.md),
[performance and boundaries](PHASE2_H32_PERFORMANCE.md).
Reproduction: [commands](../../../tools/benchmark/phase2/README.md).
