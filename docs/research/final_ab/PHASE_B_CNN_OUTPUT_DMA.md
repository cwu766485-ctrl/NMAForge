# Phase B — RETAIN existing output DMA store scheduling

Fixed trained570164-MAC CNN, both-fused row-major Phase4 ping-pong candidate,
128KiB/four banks,256MAC. Existing128-bit AXI DMA store, no RTL engine changes.
The exact timing runner is shared with Phase A; strict independent CNN payload
and all20800 Golden words are checked after delivery outside the measured interval.

## Continuous timestamps (same simulation clock)

| Event | AXI-Lite output | DMA output |
|---|---:|---:|
| Start input DMA config |124859|124859|
| Input load finished |127914|127914|
| CMDQ configuration finished/doorbell boundary |127974|127974|
| Completion published |139350|139350|
| Completion records read/output begins |139374|139374|
| Consumer byte delivery complete |144366|140296|
| Full interval cycles |19507|15437|
| Output delivery cycles |4992|922|

Full interval reduction20.86%; modeled speedup1.2636x. Output stage reduction
81.53%. Input payload10944B; output3328B in both modes. Compute traffic remains
64064B reads/16640B writes; CMDQ11376cycles. The new timestamp interval exposes
120cycles absent from the old sum19387: initial DMA setup36, between load and
CMDQ60, completion record consumption24. Thus the old independent-window sum
is not used as the baseline.

## Endpoint definition and limits

Both paths deliver the same3328B to a consumer-owned array at external-model
address0x3000. DMA uses the real AXI store and waits for DMA done/status after
write response before availability. The AXI-Lite consumer explicitly reads each
SPAD word and copies the returned value into its reference array; those CPU-side
reference copies are zero modeled cycles. This favors the Lite baseline and is
not a model of CPU external-memory writes/cache effects. The array has identical
expected bytes; real CPU retrieval of a DMA buffer is not timed for either path.
Same external-memory model and deterministic seed are used for both cases; the
DMA case pays its additional AW/W/B service. All input DMA config/status, output
DMA config/status, queue config and completion record reads are timed. Test-only
poison setup, offline packing, full intermediate Golden scanning and queue teardown
are explicitly excluded. No software seconds are combined with clock cycles.

The backpressure suite increases existing AXI address/read/write gaps equally
for both modes, retaining real arbiter constraints and active protocol assertions.
There is no compute/store overlap, no RAW/WAW hazard or SRAM-port increase.
A tile-overlap extension is not needed to establish the measured improvement and
is not implemented. Basic smoke and seeded20 protocol/fault/reset recovery pass;
existing Matrix fault/backpressure regressions are archived with their limits.
New DMA-output-specific fault injection coverage remains an open DV item; these
results establish functional/Golden and success-path protocol behavior, not
exhaustive fault closure.

Hardware cost: zero new hardware state, muxes,ports or combinational timing paths.
Testbench instrumentation and host DMA scheduling only. RETAIN as a validated
software/data-movement candidate; no automatic merge or ASIC frequency claim.
