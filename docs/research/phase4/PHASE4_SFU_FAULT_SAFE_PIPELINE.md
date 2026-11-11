# Phase 4 — fault-safe scalar SFU pipeline admission

**REJECT_UNRESTRICTED_PIPELINE_NO_RTL_ADMISSION.** Two targeted rounds completed;
stop this candidate. No SFU RTL, new port, 4-lane SFU, transparent bypass or
relaxed fault mode. H32 stays350155cycles; no safe incremental speedup claimed.
Gate2 CNN checkpoint73ebc74f5e155c614d3eeb4f5bee12315ed7f633 was committed and
published/remote-verified before this protocol study.

## Actual contract and round 1 failure

Source reviewed unchanged scalar `ai_tensor_sfu_core`, scratchpad, protection,
compute mux and sole scheduler arbiter. SFU issues4B scalar accesses, one in
flight; real scheduler response is two edges. Protection is checked on each
actual admitted access; parity comes from that read. Host/debug has a separate
port, DMA and other engines arbitrate scheduler service. Neither port is free
bandwidth. The speculative reader must retain original read granularity,
authorization, response ownership and intermediate output writes.

Re-ran real VCS `tb_phase3_fault_contract.sv` via
`PHASE3_OUT=/tmp/nmaforge-phase4-runs/sfu-contract PHASE3_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator bash tools/benchmark/phase3/run_review.sh`.
Unchanged product: second-word GELU parity error5 commits exactly word0 and
leaves three sentinels. Same line has mask0010, naive aggregate error before
retirement loses that prefix. Adjacent permitted `[0x100,0x108)` and
`[0x108,0x110)` allow four scalar reads but deny one16B read. PASS both original
counterexamples; no candidate RTL is instantiated by these tests.

Round1 executable scalar speculation model retains4B reads but eagerly raises
a younger read fault: baseline output prefix[10], candidate[]. This fails even
without line aggregation. Repair requires per-word fault state and in-order
retirement, not a wider arithmetic datapath.

## Round 2 protocol and bounded results

`tools/benchmark/phase4/sfu_protocol_model.py` specifies four live word entries,
one arithmetic lane, two-edge accepted-read response, registered operand/result,
one scheduler admission per edge and in-order output. Each accepted read carries
index/epoch; permission/parity/value are sampled at its actual admission, never
from cached data. A younger fault stops new issue, but is held until all older
legal outputs retire; all younger writes are suppressed. Accepted responses drain
before completion, and a new epoch cannot consume an older response. Abort/
watchdog stop new reads/writes; reset flushes local state, drops old epoch data.
This is a **candidate protocol**, not proof it refines current RTL priority at
same-edge abort/write acceptance or top tagless response behavior.

Executable assertions cover: monotonically indexed reads/no duplicates; at most
four live entries; no output before all its checks; ordered writes; fault-prefix
and suffix suppression; no post-stop issue/write; completion exactly once after
drain; no stale epoch retirement. Exhaustive parameter enumeration over
N1/2/4/8, four contention periods and each single read-parity/read-protection/
write-protection location gives196immutable/disjoint cases matching serial
output/error.279bounded reset/abort/watchdog schedules check recovery invariants.
These are finite Python transition checks, **not RTL formal proof or unbounded
verification**. Packed Requant partial-word failure, LN reductions/barriers,
aliasing and real arithmetic are not modeled by this toy protocol.

A closed-loop two-client RR example issues competing requests based on that
client's prior grant. No pre-recorded blocked slots are replayed as fixed free
bandwidth. For eight immutable toy words serial/pipeline cycles are40/16 without
competition,43/30 at period1,44/30 at period2,43/23 at period4. These illustrate
sensitivity only. The real arbiter has control priority, multiple client classes,
Host bank conflicts and changing dispatcher releases: a refinement/calibrated
closed-loop product model remains missing. These numbers are not H32 projection.

## Surviving coherence counterexamples

Ordered retirement does not restore the time of an earlier speculative read.
With a Host write of source word1 to999 at edge2, serial returns
[10,999,12,13], candidate[10,11,12,13]. Both check permission/parity at their own
actual reads; both are internally consistent, but software-visible observations
differ. With word1 permission revoked at edge2, serial writes[10] then protection
fault; candidate read word1 earlier and completes all four. Raw event traces
in `sfu_protocol/summary.json` retain accept/response/write/host/error/epoch.
Dynamic parity corruption/repair has the same read-time issue. No data replay
or skipped check can repair a missing observation at the old access time.

A potentially safe restricted workload needs **immutable input/Gamma/Beta and
permissions/parity state throughout the command**, disjoint output/live operand
regions, no concurrent Host/DMA/debug/other-engine mutation, plus preserved
ordered pack/reduction barriers and write checks. Current SPEC does not establish
an enforced lease covering those actors; current descriptors have no such
opt-in/fence. An offline trace showing stable operands is not an enforceable
architecture contract. Restricting deployment would need explicit review and
proof rather than silently treating it as guaranteed. No interface or fault
contract is changed here. No third repair or product implementation follows.

## Cost, risks and decision

Illustrative four-entry lower planning budget: each address32+epoch16+index16+
operand32+result32+flags8 =136bits,544bits total, plus counters/recovery/barrier
state and arithmetic stage registers. This is not a complete RTL bit count;
LN/residual operand requirements, packed output hold and tagless route refinement
would add state. No new SRAM port/bytes/MAC. A single existing arithmetic lane
could be retimed, but multiplier sharing/II and exact rounding need numerical
proof. Use response→operand register→arithmetic→result register; do not create
response→mux→arithmetic combinational shortcuts. No synthesis/Fmax claim.

Known ordered queues/pipelines are prior art; this phase provides concrete
fault/coherence counterexamples and scoped invariants, not literature novelty.
Safe H32 gain NOT_PROVEN; old Phase3 conditional42.8427% is not upgraded to a
measurement or admitted prediction. Full safety proof, real closed-loop arbiter,
reset-drain and concurrent observation contract are open. Reject current
unrestricted candidate and stop, preserving product SFU.
