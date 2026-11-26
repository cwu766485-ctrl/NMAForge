# ASIC feasibility and open design risks

Stage A only; **DESIGN_PARTIAL**. No DC/SpyGlass/DFT/P&R signoff was run or inferred.
Target400 MHz is **2.5 ns**, not historical4 ns. Simulated cycle counts do not
measure physical frequency, area, power or energy efficiency.

| Risk | Evidence and implication | Required later closure |
|---|---|---|
| SRAM macro mapping | Behavioral SPAD four-bank host A/scheduler B, registered two-cycle response; current clients assume in-order responses, width/lane/parity contracts | Specify macro ports, write masks, read-during-write, parity and adapter latency; prove response-owner/drain equivalence |
| Macro capacity / residency | 128 KiB workloads pass; 512 KiB compatibility retained. Generic smoke uses512 KiB addresses, not a universal128 KiB test | Dedicated128 KiB integration regressions plus capacity/alias checks; do not relabel512 KiB smoke |
| Matrix frequency | Broadcast operands/64-bit accumulators, result indexing and operand-buffer selections can create fanout/mux paths | Current-source mapped synthesis and STA at2.5 ns; no array-cycle ratio converted to area-normalized throughput |
| SFU frequency | Gamma multiply/clamp, reciprocal normalization multiply/add/clamp, residual add/shift, divider control | Respect existing register/saturation boundaries; no extra read-response→multiplier bypass cascade |
| A3 partial sums | Four K tiles cannot be split into independent consumer descriptors with accumulator clear | Define continuation/ownership or reject; bit-exact full CNN memory-image verification |
| A3 live set | Existing512 B only two256 B tiles; real producer64-channel row tile requires four | Mapper schedule proves occupancy, collisions and fallback benefit before any storage increase |
| B2 coherence | DMA/host/other engines can overwrite a cached address; host port independent | Observe all accepted writes or gate ineligible; explicit dependency, epoch, byte-overlap invalidation |
| B2 protection/parity | Cached data must not bypass authorization or silently hide architecturally required SRAM parity detection | Resolve fault-observability contract and optional cache parity before implementation approval |
| B2 control/timing |128 B +≤160 bits metadata estimate; mux and snoop fanout unmeasured | Registered hit response, no valid/ready combinational loop, exactly-once handshakes, synth/STA area check |
| Numerical quality | H16 INT8 accuracy74.46%, historical original FP32~82.13%; fixed-point PWL approximations are contractual | Retain quality gap, representative trained task and tolerance; no lower precision or modified Golden for performance |
| Larger workload | H32 budget fits but mapper/reference hardcodedH16; H64 resident budget fails128 KiB | New training/reference/Logits/KV evidence and explicit lifetime; streaming separate review |
| Comparison boundary | Tiny64 KiB native data SRAM, modeled byte DMA; no matched controller memory path | Common clocked memory/commit model, same arithmetic and larger common subgraphs |
| Historical signoff source | `docs/signoff/synthesis_readiness.json` is older R21 source; includes Matrix DC internal failures/array timeout | Recover synthesis on exact frozen source; historical reports are not current RTL qualification |
| Verification scope | New smoke, seeded20 and workload checks pass; existing warnings and coverage dispositions remain | Requirement-driven DV/formal, lint/CDC/RDC, LEC, mapped synthesis and reset/abort/fault closure later |
| Testchip / test | No current macro/MBIST/DFT or physical integration evidence | Separate Stage F workstream; no tapeout-ready claim |

New hardware actually added in Stage A: **zero**. Only passive DV observations,
benchmark harnesses, analysis and public evidence are added. A3/B2 cost envelopes
are proposals, not synthesized flop/cell counts. No foundry library, Liberty,
macro timing model, credentials or license file belongs in this delivery.

The existing scheduling optimization already used two bounded RTL changes.
Stage A does not silently extend that experiment. Any later A3/B2 implementation
requires the architecture review requested in the roadmap, with its own bounded
scope and acceptance criteria.
