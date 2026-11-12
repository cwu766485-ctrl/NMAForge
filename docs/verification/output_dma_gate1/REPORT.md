# Output DMA Gate 1 — scoped verification, review required

Base source `14c3f8a9adbb98070b08d617bb0c953a9abb8d47`; candidate branch
`feat/output-dma-gate1`, exact evidence source hashes in manifest. No product RTL,
ABI, SRAM port or architecture change. VCS V-2023.12-SP1_Full64; directed DMA
clock10ns, MAX_BURST_BEATS4; Top default128KiB/four banks and256MAC. Simulation
clock does not establish Fmax. Scope is Gate1 only, no product merge or PPA.

## Root cause and repair

Exact seed20261116 failed before repair: tile-forward chain's randomized
line_ready never stalled a capture, but a mandatory nonvacuity check required it.
The test now arms force_line_stall before producer launch, waits for line_valid,
then releases after four negative edges. The existing sampled payload-stability
monitor is retained and its counter must increase. Original seed20261116 and
20261112/13 pass with explicit MATRIX_CAPTURE_DETERMINISTIC_STALL_PASS. No check
was removed or expected value relaxed. Determinism is in the responder, not DUT.

## New independent Output DMA scoreboard

`tb_output_dma_gate1.sv` drives the real DMA and models SPAD service. Independent
source function and accepted AW/W monitor calculate expected output addresses,
per-byte WSTRB validity, data and WLAST. External memory is poisoned; after terminal
completion the full image must equal the accepted legal prefix plus untouched
suffix/guards. A B error does not roll back accepted W writes. Abort after AW must
finish the promised burst; no new writes after terminal done are permitted. Shared
reset cancels both AXI endpoints; reset with delayed B and mid-W are separately
exercised, then recovery. Reset preserves already-accepted external bytes, and
checks no later stale byte acceptance. An unreset external interconnect sending
old responses across reset is outside this shared-reset contract.

Ten deterministic cases pass:52-byte partial final strobe,80-byte4KiB split,
BRESP SLVERR,abort after accepted W,SPAD request denial,response parity,mid-W
reset,recovery,reset with outstanding delayed B,second recovery. Every successful
case requires actual AWVALID&&!AWREADY,WVALID&&!WREADY,SPAD request stalls and
nonzero AW/W stable-payload checks. Delayed B is held until its scheduled response.
No forced DUT output is used. Existing11 AXI assertions are instantiated.

Real Top also injects source protection via public region registers and flips
behavioral SRAM parity metadata: both preserve external Sentinel, return DMA
ERR_SPAD and raise error IRQ. Rewriting source repairs parity; next store succeeds
with independent external-word Golden. Region configuration is saved/restored.
Success-only DMA does not raise processor IRQ in current RTL; errors do. DMA direct
store is not a CMDQ descriptor and has no separate CPLQ completion. Top smoke
already checks store Abort drain/status; the new run includes20random cases.

Nine existing DMA UVM tests pass with zero UVM_ERROR/FATAL:store_booo,
store_four_booo,2d_store,aw_stall_stability,short_tail_store,write_slverr,
abort_write,backpressure,random_stress. Existing independent UVM scoreboard and
AXI assertions retained. Matrix/DMA real Top overlap observes72overlap cycles,
5stall cycles,three accepted AW/B bursts and192strobe bytes; DDR/SPAD Golden PASS.
This is successful concurrency evidence, not all fault×contention crosses.

## Coverage separation and limitations

Directed functional handshake group100% for its six declared coverpoints. Actual
partial beats3,split_AW1; each successful case reports actual sampled AW/W/SPAD
stalls and stability checks. URG directed database:line69.47%,condition58.12%,
FSM46.43%,branch56.11%; assertion success6/11(54.55%),failure0. Five read-channel
assertions are unexercised in store-only suite, not waived globally. No combined
whole-product coverage claim; UVM logs provide separate command functional data.

BVALID&&!BREADY count0: valid legal BID is asserted only after WLAST, at which
point the pending tag directly enables BREADY. Response delay is covered; forced
BREADY-low would override DUT and is not a legal external control. Unexpected BID
and BVALID before completed W are not substituted as legal backpressure. This
structural exclusion is proposed for review, not an approved waiver.

Remaining:SPAD faults after earlier bursts with simultaneous outstanding B;
abort during denied/protection response;reset with non-reset external fabric;
IRQ/status exactly-once exhaustive fault crosses;output fault while real compute
contends;more seeds/payloads and scoreboard mutation sensitivity. SPAD-model stalls
are not relabeled real physical bank conflict. New block request/parity injection
uses interface error pins;real Top source denial/parity supplies integration points.
No complete P0 closure is claimed for those remaining crosses. Gate1 is
**PASS_SCOPED / CLOSURE_PARTIAL**, not full DV closure; submit for review and stop.

## Late-fault defect, minimal RTL repair and final scope

The expanded12case suite reproduced a real P0:late parity in second store gather
caused done before the prior B response (6045000ps). Failure evidence at commit
154b479 is retained. The minimal RTL fix routes SPAD store faults with nonzero
pending B count to existing ST_WRITE_DRAIN, and uses sticky error to choose
ST_ERROR after drain. No new state,buffer,port or feature is added. ERR_SPAD is
preserved for the tested OKAY prior B. Same-edge multiple-fault priority beyond
this scope remains an explicit risk, not a claimed closure.

All12cases now pass, including late request denial and late parity with64B visible
prefix,one drained B,exactly-once done and no subsequent W. Existing11selected
UVM tests (including load and SPAD error read drain) pass zero error/fatal after
recompile. Fixed real Top fault+20random,canonical smoke and Matrix/DMA overlap
also pass. Focused Verilator5.052 completes with inherited width warnings; no
latch/loop/multiple-driver warning in this run, no signoff claim.

Final directed URG:line69.57%,condition60.81%,FSM41.18%,branch56.31%;assertion
success6/11,failure0,functional group100%. Metrics differ with the repaired FSM
transition denominator; no whole-product closure claim. Case counters are in the
fixed_observed_cases.csv. Earlier10case counts above are historical only.

Final status: **PASS_SCOPED / REVIEW_REQUIRED**. Tested P0 output paths pass;
error×real-compute-contention, simultaneous B error plus source parity,abort×fault,
nonshared-reset interconnect and exhaustive IRQ/status crosses remain open.
Gate1 is submitted with these explicit remaining items; no automatic Gate2/PPA.
