# Static and verification disposition

Tested production RTL checkpoint: `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`.

Verilator 5.052, `--lint-only --timing -Wno-fatal -DVCS --top-module ai_accel_top -f ai_accel.f`, with **`-GSPAD_WORDS_PER_BANK=8192`** and **`=32768`**, elaborates both capacities. `-D` alone would not override this top parameter; the archived final logs use `-G`. LATCH=0, UNOPTFLAT=0 after the Mux correction (previously10/3). No MULTIDRIVEN diagnostic. Width truncation64, expansion113, CASEINCOMPLETE4, PINMISSING2 remain. Every diagnostic is preserved in STATIC_DISPOSITION.csv as OPEN_REVIEW, not silently waived.

Width/sign review must prove the intended range and rounding, especially Matrix index casts and fixed-point arithmetic. CASEINCOMPLETE requires illegal-state/reset-X disposition. Missing dependency-event pins belong to an optional dual-clock command shell; no waiver is granted. Default product has a single aclk and asynchronous active-low aresetn, but asynchronous reset release still requires RDC review.

SpyGlass V-2023.12-SP1 lint completed on the public **depth256 structural profile**: 0 fatal/0 errors/467 warnings/5 infos, zero waived. This is not full-capacity mapped lint closure. Per-message moresimple report retained. Multiple assignments within one sequential process (W415a) are not automatically multiple drivers; priority and intent still require individual review. No blanket waiver is added. The first lint was launched during the short structural-fix interval, so it is supplemental, not exact-checkpoint signoff; final-capacity Verilator is exact-checkpoint evidence.

SVA: DMA AW4K11, AW-payload37, AWID48, B-known9, BID9, W-payload16 real successes; zero failures/incomplete. Five read-channel assertions are vacuous in the store-only directed suite. URG store-only code coverage: line69.57%, condition60.81%, FSM41.18%, branch56.31%. Assertion54.55% (6/11); handshake functional group100%. These measure different scopes and are not combined into a closure score. This run is dynamic assertion checking; no new formal proof claim.

Control9 tests pass. DMA19 tests pass with zero reported UVM errors/fatals. DMA/SPAD seeds12345/987654/20261014 pass; initial URG PATH failure repaired by invoking installed absolute URG path. Matrix3 directed/random/opcode-fault seeds pass; original20261116 deterministic stall checks are nonzero. Top smoke/default128KiB and20-case seed12345/20261116 pass. Optional512KiB top20-case smoke also passes. Seven-engine real-top regression fails at old fixture address0x7d000 on128KiB; historical512KiB coverage cannot close default128KiB requirements.

Outstanding correctness evidence: compact all-seven-engine fixture allocation, protection-region equivalence, adversarial error×contention/Abort×fault crosses, independent external-fabric reset contract, reset-X and optional dual-clock CDC/RDC, per-message width/static waivers, and formal progress proofs. Global Gate3 exit remains HOLD.

Descriptor-validator target additionally FAILS: the old fixture calls0x53 aux0=0x80 reserved, while current validator and Matrix core already implement bit7 Row-Major mode. Failure retained rather than weakening checks; test needs reviewed valid/invalid Row-Major shapes and truly reserved bit8 vectors. The correction and limited closure are documented below.

SpyGlass CDC setup/structural verification on depth256 completes with0fatal/0error/2warnings/38infos and0unsynchronized crossings/0convergences for the single-clock top. This does not close reset release or optional dual-clock integration. RDC and final-checkpoint lint results are recorded with the evidence when complete.

Follow-up: reserved-bit rejection vector corrected from bit7 to actual reserved bit8; `descriptor-validator-regress` now PASS (29opcodes/33invalid/43accepted/26rejected). Original failing log retained. Dedicated Row-Major validator boundary matrix remains future scope. Final-checkpoint SpyGlass lint repeats0errors/467warnings/5infos. CDC warnings are FLAT_504 (16384bit mux logic evaluation threshold) and Reset_sync04 (distributed reset synchronization); both remain open review.

No new formal proofs were executed. The present dynamic SVA successes do not substitute for progress, reset-release or ownership formal signoff. Open static messages receive no automatic waiver; acceptance requires named reviewer and rationale.

The raw three-seed subsystem URG text dashboard/groups/asserts are archived separately; do not confuse its combined group79.74% with store-only handshake100% or whole-project functional closure.
