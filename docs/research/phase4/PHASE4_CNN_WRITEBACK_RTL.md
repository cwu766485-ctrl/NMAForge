# Phase 4 — CNN output ping-pong RTL

Gate0 PASS: research `48345af9c5a4dcabc8fec04999c8edae55dc09c5` has no RTL diff
from product `c93ea144713d5fafe2e8a5509029927cd6859e75`.
Phase3 archive validator PASS before edits: 65×80-cycle writeback, 1040 accepted
16B writes / 16640B, 1560 abstract cases and independent Golden payloads. Those
were model results; this report adds actual VCS candidate results.

Candidate branch `feat/phase4-cnn-writeback`, based on Phase3 research. The
Gate2 checkpoint commit containing this report identifies measured RTL, pinned
by `benchmark/research/phase4/manifest.json` SHA256 inventory. Product and other
worktrees are preserved. No automatic product merge.

## Implemented mechanism

Only product file changed: `rtl/compute/matrix/ai_tensor_matrix_core.v`.
`ENABLE_FUSED_PINGPONG_WRITEBACK` defaults1, accepts0 for old-path ablation.
Existing four postprocess lanes/0x53 requant/row-major epilogue are unchanged.
The original 128-bit line register becomes bank0; one extra128-bit register is
bank1. Two addresses, full mask, separate pack/commit selectors and pack-done
flag keep FIFO order. Packing advances existing row/column/lane pointers;
committing uses the registered head address/data, so neither pointer movement
nor ready/protection changes the offered payload. A full bank is immutable.
There is no same-edge reuse of a full bank: stall conservatively until next edge.

Only ARRAY_SIZE16 full16×16 tiles, aligned output, ordinary tile-major or full
row-major N16, and no active legacy elastic capture/consume use this path.
Partial tiles, other arrays/layouts, unaligned addresses and elastic forwarding
use the unchanged path. Both buffers drain before ST_NEXT clears accumulator.
No overlap with next-tile accumulator lifetime, no INT32 intermediate removed.

Protected line admission is unchanged; a denied head sets ERR_PROTECTION and
suppresses younger commits. Result and element count update only on successful
commits, with the existing row-major count convention. Reset clears queue;
start/ST_NEXT initialize it. Abort/watchdog/banked-error outer priority remains
unchanged; leaving ST_WRITE suppresses line_valid, new start flushes dormant
metadata. No reads bypassed or parity/protection checks relaxed. At equal wall
clock times an optimized command can have a longer committed prefix; preserving
fault priority/accepted-prefix semantics does not imply identical time-cut output.

## Cost and static review

Added declared registers:128 data +64 address +2 full +3 control =197bits.
Original bank0 register/counters and four requant arithmetic lanes reused.
No SRAM bytes/ports, MACs, opcode, descriptor or ABI change. Head2:1 mux selects
registered128-bit data and32-bit address. Existing accumulator-select/add/shift/
saturation→pack register remains; occupancy→enable/control fanout needs mapped
STA. No direct SRAM-response→new arithmetic combinational path introduced.
Variable part-selects are explicitly sized. Synthesizable always/assign logic;
VCS elaboration and Verilator parse PASS, no new LATCH/UNOPTFLAT/width warnings.
No mapped synthesis, area, power or 400MHz evidence. 4ns is a simulation clock.
Inherited Top warnings remain2PINMISSING/64WIDTHTRUNC/113WIDTHEXPAND/
4CASEINCOMPLETE/10LATCH/3UNOPTFLAT. Focused Matrix18TRUNC/41EXPAND/1SYMRSVDWORD,
both baseline and candidate. Existing severe Top dispositions remain open.

## Verification

See [ablation](PHASE4_CNN_ABLATION.md), public archive, and
[commands](../../../tools/benchmark/phase4/README.md).
Three seeds20261021/22/23: each parameterON/OFF passes18 numerical+35 generic
fault cases and dedicated0x52/0x53 fault/recovery. New campaign per seed/mode:
16 protection prefixes,48 abort/watchdog/priority cases,16reset/recovery,
4 public programmed watchdog cases,20random latency/backpressure cases, both
layouts, N32 tile-major and partial M20 fallback. Checks full address/data/WSTRB/
order, committed prefix/untouched suffix, stable stalls, no premature accumulator
clear, exactly-once done, no stale writes after reset and clean new command.
Priority probes using force are separately identified in commands; public-input
watchdog and generic watchdog tests complement them.

Full Top independent trained CNN Golden all mappings PASS, all1040 both-fused
transactions match immutable Phase3 payloads; H16 and both H32 model fixtures
Logits/KV/intermediate Golden PASS. Canonical ai_smoke and seeded20 PASS.
512KiB elaboration capacity/fault boundary PASS (not full-model replay).
These are focused regression evidence, not comprehensive verification signoff.
