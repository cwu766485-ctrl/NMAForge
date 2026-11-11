# Phase 4 — architecture decision

**CNN RETAIN_AS_PR_CANDIDATE; scalar SFU REJECT; product DESIGN_PARTIAL.**
Stop Phase4; do not enter Phase5. No automatic merge or SFU RTL implementation.

Gate0 audited Phase3 with no product RTL changes and reproduced the1560abstract
cases/1040Golden transactions. Gate1/2 now implements one bounded product RTL
change: decouple existing four-lane0x53 packing from protected output commit with
two ordered128bit buffers. Gate2 checkpoint **73ebc74f5e155c614d3eeb4f5bee12315ed7f633**
was pushed and remote SHA matched before Gate3. Final report commit descends from
that checkpoint and retains its RTL exactly; Git head/PR records final SHA.
Base product remains **c93ea144713d5fafe2e8a5509029927cd6859e75** until PR review.

| Decision item | Actual evidence |
|---|---|
|CNN target≥5%|PASS:12351→11376CMDQcycles,975saved,7.8941%,1.0857×same-boundary|
|Golden/payload/traffic|PASS:all1040writes,address/data/WSTRB/order; reads64064B,writes16640B unchanged|
|Fault/lifecycle|Three seedsON/OFF,protection prefixes,backpressure,abort/reset/watchdog,recovery and exactly-once checks PASS|
|H16/H32|PASS:65771/350155per8tokens unchanged; strict Logits/KV/tensors|
|Static|No new warnings; focused Matrix no LATCH/UNOPTFLAT; inherited Top10LATCH/3UNOPTFLAT remain OPEN|
|Hardware cost|197additional declared state bits; no SRAM bytes/ports,MACs,ABI/opcode changes|
|Gate3 scalar SFU|Two rounds,196immutable/disjoint checks+279recovery schedules; concurrent Host/permission counterexamples survive ordered retirement; REJECT unrestricted candidate|
|Tiny/System|Historical raw adapter advantage only; native whole-model/full-system endpoints unmatched|

Only `rtl/compute/matrix/ai_tensor_matrix_core.v` changes in product RTL. New
passive monitor/directed scoreboard and public evidence support review. Existing
requant/row-major/four postprocess lanes and old elastic mechanisms are reused;
ping-pong output buffers are established prior art, not a newly proved paper
contribution. New value is measured bounded improvement under preserved access/
fault checking. No A3/B2 read bypass or hidden free SRAM service.

Proposed CNN PR is eligible after focused Golden/fault/regression/static-risk
review, despite inherited whole-top issues remaining explicitly open. PR targets
`nmaforge`; main, product and all existing worktrees remain protected. Phase3
research docs/tests are ancestors, not additional product RTL. No private PDK,
Liberty,license,simulation binary,waveform or coverage database is published.

Freeze obstacles: inherited combinational-loop/latch/width dispositions;
actual SRAM macro integration and port semantics; mapped timing for the new head
mux/enable fanout and existing postprocess path (400MHz NOT_PROVEN); broader
concurrency/lifecycle verification; exact same-endpoint Tiny native/full-system
benchmark; SFU safe lease/coherence/ordered fault contract and real closed-loop
arbitration/refinement.4ns functional simulation does not establish Fmax.
No complete SpyGlass/DC/DFT/P&R/coverage closure undertaken. Do not call this
front-end signoff or DESIGN_FROZEN.

Reports: [RTL](PHASE4_CNN_WRITEBACK_RTL.md),[ablation](PHASE4_CNN_ABLATION.md),
[SFU admission](PHASE4_SFU_FAULT_SAFE_PIPELINE.md),[Tiny boundaries](PHASE4_TINYNPU_COMPARISON.md).
[Exact commands](../../../tools/benchmark/phase4/README.md),
[Gate2 manifest](../../../benchmark/research/phase4/manifest.json).
