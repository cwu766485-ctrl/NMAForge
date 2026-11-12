# Architecture freeze proposal — bounded Phase A/B evidence

2026-11-12. Parent candidate56adb124 on feat/arch-opt-round2-dispatch. This is
PARTIAL and requires review; not FRONTEND_FREEZE_CANDIDATE, not tapeout-ready.
Product RTL remains byte-identical to the parent. Configuration128KiB/four
banks/256MAC/128-bit DMA; no new ports, buffers, engines or ABI.

## Phase A

32 actual Top/DMA cases pass common INT32 Golden. Full M1/M4/M8/M16 ×
N16 × K16/32/64/128 results are in benchmark/research/final_endpoints/matrix_results.csv.
The continuous fixture interval includes DMA, layout padding, queue configuration,
completion checks and output DMA. CPU packing is recorded separately.

M8 selected GEMM is slower by3.13/4.84/6.58/3.52% at K16/32/64/128: additional
A padding outweighs isolated CMDQ improvement. REJECT recommending M8 for this
load-once endpoint. M16 improves4.30/7.33/10.79/21.51%; RETAIN as measured endpoint
candidate, not automatic runtime policy. M1/M4 keep0x52, identical paired results.
The existing offline mapper is unchanged pending review of deployment objective.
Exclusive operands and permissions from load/fence to completion remain caller
preconditions, not a hardware lease. Concurrent DMA/Host/permission mutation
retains legacy mode; no dynamic equivalence is claimed.

## Phase B

Trained CNN sample42, Phase4 ping-pong candidate, both-fused row-major layout.
Strict independent Golden checks20,800 words (including intermediates and untouched
poison); both endpoint modes check832 final words/3328bytes at identical external
array indices. Existing AXI DMA Store is used without product changes.

Common timestamps (simulation clocks):

| Event | AXI-Lite | DMA Store |
|---|---:|---:|
| production begin (checker setup excluded) |129851|129851|
| load end |132906|132906|
| completion checked |144366|144366|
| output delivered |149358|145288|
| output cycles |4992|922|

Output transfer improvement81.53%, saving4070cycles. The continuous production
interval19507→15437 improves20.86%; both paths start before DMA configuration
and end after delivery/status check. All83,232bytes of checker-only poison
initialization and its validation occur before production_begin; no independent
segment sum replaces this measured interval. DMA preload payload10944bytes,
setup+transfer3019cycles; the continuous load phase3055 also includes DMA mode
configuration. RETAIN existing DMA output as a measured candidate. PhaseB
acceptance remains PARTIAL pending endpoint-specific AXI/SPAD backpressure,
protocol/fault/reset checks. No tile overlap or new RTL is added.
Baseline host array materialization is zero-latency after AXI-Lite reads; DMA
uses actual AXI memory model writes/response, so host-store cost is not hidden
in favor of DMA. This is a simulation endpoint, not CPU wall-time/silicon timing.

## Phase C boundary only

Requant/direct producer fusion already exists as Matrix0x53. Do not implement
another SFU engine. Standalone SFU chains preserve INT32 intermediates, numerical
round/saturate order and per-access authorization/parity. Current immutable
protocol model rejects dynamic Host-write and permission-revoke equivalence;
no general ownership lease exists. REJECT unrestricted fusion and defer new RTL
until explicit ownership/fault-prefix specification and H32>=5% RTL evidence.
Existing proof/model is not H32 RTL performance evidence.

## Validation and limitations

VCS endpoint compile succeeds;32 Matrix paths, CNN strict and two output modes
pass. Mapper independent decoder72cases passes. Existing top smoke and one-seed
Matrix numerical/opcode-fault regression were executed; text logs are archived.
Initial endpoint compile scope errors and CNN all-Golden capacity failure are
retained under runs/ and corrected: only final tensor belongs in output delivery,
while separate strict replay keeps intermediate/sentinel checks. No test removed.

No new DMA endpoint-specific abort/parity/protection campaign or independent
protocol checker was run; inherited tests are not re-labelled as covering new
endpoint combinations. No production timing acceptance, SRAM macro mapping,
current128KiB DC/PPA, full RTM, CDC/RDC, DFT or physical signoff is claimed.
ASIC_MAPPING_BLOCKED pending compatible authorized macro integration. PhaseD/E
not started. Stop for review before architecture extensions or merge to nmaforge.

Reproduction: tools/benchmark/final_endpoints/README.md. Public evidence is
benchmark/research/final_endpoints; raw tools/binaries remain under ignored runs/.
