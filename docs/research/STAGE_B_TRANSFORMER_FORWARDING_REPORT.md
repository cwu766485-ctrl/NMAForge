# Stage B — Transformer Matrix→Requant forwarding

**Decision: REJECT.** Reject the proposed transparent 128 B read-bypass cache
under the current ABI/error-observation contract. Gate 0 fails; no product cache
RTL or interface changes were made. This is a completed failure analysis and
transaction-model study, not a completed B2 RTL optimization. Innovation A3 was
not implemented. A different fault-observation mode requires architecture review
before hardware work resumes.

Baseline: branch `nmaforge`, Stage A commit
`1b455b355c8604272cbc49a81f5564db9a4e4f05`, product RTL tree
`479f24f33af0ccfa87fd7458ac9c43f94aae7398`.
Work performed in independent `/tmp/nmaforge-stage-b-candidate`, branch
`experiment/stage-b-matrix-requant`. Product RTL, ABI, models and Golden remain
identical. Publishing commit contains only checked evidence/model/test/report
changes and is reported after remote SHA verification. Main and unrelated
worktrees are preserved.

Public evidence and hashes:
[Stage B manifest](../../benchmark/research/stage_b/manifest.json).
Reproduction commands are below. Normative references:
[SPEC](../spec/SPEC_ZH.md), [Cluster SPEC](../spec/COMPUTE_CLUSTER_SPEC_ZH.md),
[SFU integers](../spec/SFU_NUMERIC_CONTRACT_ZH.md).

## Gate 0 — Ten contract questions, audited against code

### 1. What establishes a successful Matrix SPAD commit?

`ai_spad_arbiter` ready means admission, **not permission success**. For aligned
full-line output, capture requires Matrix valid+ready, correct owner, write=true,
full WSTRB, legal alignment/range, and no line protection/raw error. Scalar
fallback requires equivalent scalar checks. Writes commit on the admitted SRAM
edge and do not produce a later write response. `ai_accel_spad_subsystem` gates
actual SRAM access with permissions; `ai_scratchpad` enforces range/alignment.
The cache must capture the committed bus representation and set masks only on
successful write edges, then wait for successful producer termination/retirement.
A prior accepted prefix is not a successful whole producer.

Relevant RTL: `rtl/compute/matrix/ai_tensor_matrix_core.v` lines493/531/1512/1682;
`rtl/memory/ai_spad_arbiter.v` response-generation comment near160;
`rtl/top/fabric/memory/ai_accel_memory_fabric.v` protection calculation;
`rtl/top/fabric/memory/ai_accel_spad_subsystem.v` SRAM gating.
The new VCS test demonstrates ready=1 with protection_error=1 and **no commit**.
No write acknowledgement from a physical SRAM macro is invented: this is the
current synchronous behavioral/RTL interface contract, not physical fault proof.

### 2. Which INT32 representation is cached?

The ordinary0x30 output words **after existing bias, arithmetic shift, activation
and sat32**, as committed at Matrix scalar/Line output; not raw64-bit accumulator
values and not the0x53 packed INT8 stream. Eligible H16 shape4×8 has32 contiguous
row-major INT32 words=128 B. Requant retains its independent shift/sat8 and
Matrix-A packing. Cache range is physical byte address; output layout/length/
stride/format must match exactly. Larger/wrong-format outputs fall back.

### 3. Which descriptor could consume it?

Only an eligible0x36 Requant, identical base,32-word length, committed INT32 format
and supported packing/shape/shift fields; no alias with a writer, no partial mask,
no busy bank, and a proven completed dependency on that exact producer. Existing
0x52 capability is retained but the measured H16 producers here are0x30, not0x52.
A bare base-address match never authorizes a hit. Under the **current strict
contract no descriptor may suppress the original SRAM parity read**; eligibility
in the model is a potential data match, not permission to enable a product hit.

### 4. How is dependency proved?

`ai_parallel_compute_dispatcher` waits on `desc_wait_mask & ~dependency_events`;
successful retirement signals events, dispatch clears the specified bits.
H16 serializes each chain with event bit0: consumer waits1/clears1/signals1,
following descriptors do likewise. A future cache must track which command/epoch
last signaled the waited event and require successful producer retirement,
not simply a sticky event bit. The transaction model reconstructs event writer
identity from the recorded successful serialized descriptors. Generic parallel
queues would require live dispatcher provenance or an explicitly more restrictive
mode; the current engine interface does not expose this cache lease contract.

### 5. How are identical addresses in different epochs distinguished?

Model tag includes epoch+producer identity+base+length+format. Reset, queue
restart and epoch wrap invalidate before reuse; old pending responses cannot
survive. The trace replay uses each stage index as a distinct epoch, preserving
explicit task identity. This is a logical test identity, not a claim that a new
hardware epoch field exists. Finite-width product counters would require a
flush-before-wrap rule and consumer-bound identity. Task ID/address alone can be
reused and therefore is insufficient.

### 6. How do all writers invalidate?

Accepted overlapping writes from DMA scalar/Line, Host/Debug byte strobes, SFU,
other Matrix work, CNM/CNN/KV and completion traffic invalidate; zero-strobe or
nonoverlapping accesses need not. Same-clock invalidation must dominate hit and
cancel a pending response before consumption; a leased single bank cannot be
recaptured. The model exercises byte overlap and each named writer class.

Invalidation must reflect actual commits. Current `ai_scratchpad` rejects Host
access during scheduler activity (`host_conflict`, lines69–71), in addition to
permissions/alignment/range; host_valid alone is not a committed write. A design
may conservatively invalidate on attempted writes without claiming they committed.
Permission-register updates must also flush/cancel or reauthorize each access.
**A silent SRAM upset is not a write transaction** and is invisible to all these
snoops. Ordinary coherence cannot solve that fault-observation problem.

### 7. Reset, Abort, Fault and Watchdog?

Any reset, abort, producer/consumer fault, watchdog, partial/duplicate capture,
failed retirement or epoch rollover clears mask/valid/lease/pending responses.
Accepted SPAD writes remain visible; no rollback. Reset need only clear control
validity, not necessarily all data flops. Model tests cover invalidation during
pending registered response, exactly-once acceptance/backpressure, duplicate
capture, missing words and denied/uncommitted writes. These are transaction tests,
not a substitute for future hardware recovery verification. Existing SFU/Matrix
fault/reset regression was replayed unchanged and passes.

### 8. Does a hit preserve Parity/Protection?

**No, if it removes the original read.** Request-time protection is computed from
current region read+execute permissions and range; producer write permission
does not imply consumer read permission. This could be preserved only by keeping
real authorization or adding a reviewed equivalent authorization path.

Parity is more fundamental. `ai_scratchpad` compares current SRAM word parity at
actual read and registers the result. SFU `ST_VEC_A_REQ` rejects Protection;
`ST_VEC_A_WAIT` checks returned parity before any Requant output. The new VCS
contract test uses unchanged production memory fabric+SFU, Matrix's real Line
admission port for source writes, and a passive32-word shadow copy:

| Case | Observed baseline | Required implication for cache |
|---|---|---|
| Normal32-word producer image |32 successful source reads,8 packed writes; exact independent Golden | Bit-exact data alone can be modeled |
| Source SRAM word23→22 after commit, stored SRAM parity unchanged, no bus write | `ERR_PARITY=5`, zero output writes, destination sentinel unchanged | An intact cached23 and cached parity cannot observe this upset |
| Region permits execute+write but denies read | `ERR_PROTECTION=6`, zero output writes | Producer permission cannot be reused as consumer authorization |
| Attempted denied Line write | ready1, Protection1, SRAM unchanged | Ready alone must not set committed mask |
| Clean source reload / permission restore | Successful Requant recovery | Original path remains usable |

This test drives the Matrix output interface, not a full Matrix descriptor; it
proves memory admission/fault and real SFU observation. Matrix command lifecycle
is separately audited and covered by the existing focused Matrix regression.
Backdoor upset is a behavioral fault test, not a physical soft-error-rate model.

Two executions can have identical cache/tag/mask/epoch and all snooped transactions
but different SRAM bit upsets. Original reads distinguish them; cache-only lookup
cannot. Cache parity/ECC checks the cache, not the separate SRAM. Even a preflight
whole-tensor SRAM scan cannot guarantee equivalence to later per-word checks if
an upset occurs between scan and consumption. Therefore the transparent read
elimination fails the required observation contract.

### 9. Exactly one response?

Model allows one registered pending cache response; a second request is rejected,
backpressure holds it, wrong epoch/invalidation cancels it, retirement consumes
once. A hypothetical hit suppresses SPAD read; miss issues normal SPAD only.
However suppressing reads is disallowed by question8. Retaining both reads and
cache data requires waiting for original check success **before irreversible
output/completion**, including original accepted-prefix behavior. A speculative
output cannot be undone when a late error arrives. This study does not implement
a new pipelined verifier or response FIFO; those are different mechanisms.

### 10. Software opt-in / legacy ABI?

No ABI/register/opcode/flag changed. Legacy0x36 and all existing flags retain
strict read-time checking. A future relaxed observation mode would require an
explicit reviewed opt-in/capability, default-off behavior and unsupported-command
rejection. Merely adding an internal enable is not enough to preserve old semantics.
A proposed mode specification appears below; it is **not approved or allocated**.

## Gate 1 — Independent transaction model and traced coverage

[model.py](../../tools/benchmark/stage_b/model.py) is an independent one-entry
32-word cache model: committed mask, address/length/format/epoch, successful
producer completion and event-provenance retirement, lease, byte-overlap
invalidation, registered response and exactly-once acceptance. Seven contract
tests cover commits, failure, stale identity, format, all writers, pending-hit
cancellation and parity/protection counterexamples. Forty-seven sensitivity cases
cover hit fractions0/.25/.5/.75/1, response service1/2/3 clocks and lease invalidation
before reads or halfway through; two strict policies are included.

[replay.py](../../tools/benchmark/stage_b/replay.py) consumes Stage A's exact
accepted-address/cycle traces, descriptor intervals and unchanged observed/Golden
snapshots. All eight stage snapshots are equal to the independent Golden; source
values for each successful write are **reconstructed from the end-of-stage
snapshot**, not falsely called a live captured-data trace. Tested destinations
are disjoint within a stage; live fault/failed-producer behavior is tested in the
transaction suite and directed VCS case separately.

Coverage: **64 leases,2,048 reads,8,192 B**, exactly Stage A's Matrix→Requant bound.
Each mask closes32 words before successful producer completion. The model checks
all512 hypothetical packed output words against the existing Golden with integer
arithmetic shift, sat8 and4×4 tile packing. This is not a second full Transformer
RTL execution: unchanged B1 independently replays every intermediate/Logits/KV.

Model estimates replace serialized measured3-clock read service with assumed
cache service and subtract illustrative2 clocks per selected lease. They do
not model retimed arbitration/FSM or physical frequency. Full-read elimination
numbers below are **unapproved counterfactuals, not RTL ablation**:

| Model policy | Potential hits / misses out of2,048 | Net saved clocks | Estimated full decode | Reduction | Read B / retained write B |
|---|---|---:|---:|---:|---|
| Strict cache disabled |0 /2,048 |0 |65,771 |0% |72,448 /42,112 |
| Strict checked shadow,2 clocks/lease extra |0 /2,048 bypasses |−128 |65,899 |−0.195% |72,448 /42,112 |
| Ideal1-clock response,100% hit |2,048 /0 |3,968 |61,803 |6.033% |64,256 /42,112 |
| Ideal1-clock response,25% leases invalidated before read |1,536 /512 |2,944 |62,827 |4.476% |66,304 /42,112 |
| Ideal1-clock response,25% leases invalidated after16 reads |1,792 /256 |3,456 |62,315 |5.255% |65,280 /42,112 |
| Ideal2-clock response,100% hit |2,048 /0 |1,920 |63,851 |2.919% |64,256 /42,112 |

At one-clock response, no invalidation and two overhead clocks/selected lease,
50% hits predicts3.017% reduction; at two-clock response even100% misses the3%
research target with that overhead. One or two additional lookup clocks for all
104 Requant descriptors cost104/208 extra clocks respectively. These sensitivities
show why the original zero-cost6,144-clock bound cannot be claimed as a result.

Strict mode here means original per-word authorization/parity service, with no
speculative commit or pipelining change. It eliminates **zero SRAM reads** and
proves no latency/energy benefit for adding this cache; disabled baseline has
zero extra hardware. A new concurrent check/data pipeline might have a different
latency, but is not implemented, measured or assumed free. Gate1 passes model
consistency/data checks, **fails product admission together with Gate0**.

## Gate 2/3 — Stop and actual regression evidence

Gate2 was **NOT ENTERED**. The user explicitly requires stopping hardware work if
Gate0's observation contract cannot hold. No failed experiment RTL was merged.
Consequently there is no B2-enable switch, measured B2 hit/miss count, or B2 RTL
latency. These entries are NA, not zero or a fabricated failed RTL run.

A fresh unchanged B1 build independently replays the fixed trained model,
eight teacher-forced tokens and resident KV. All8 per-token metric dictionaries
and all9 complete stage observed-memory snapshots (prefill+decode) are identical
to Stage A. Model SHA
`e7a521c762b66e5754d6d95c411c163452e0c9b01088cb11631202338cd28225`.

| Actual metric | Stage A B1 | Fresh Stage B B1 replay | B2 enabled RTL |
|---|---:|---:|---|
| Persistent8-token decode cycles |65,771 |65,771 |NOT_RUN_GATE0_FAILED |
| Cycles/token |8,221.375 |8,221.375 |NA |
| Accepted compute SPAD read B |72,448 |72,448 |NA |
| Accepted compute SPAD write B |42,112 |42,112 |NA |
| Decode descriptors |424 |424 |NA |
| Matrix exclusive cycles |6,600 |6,600 |NA |
| SFU exclusive cycles |49,595 |49,595 |NA |
| KV exclusive cycles |3,152 |3,152 |NA |
| No-engine control/request/remainder |6,424 |6,424 |NA |
| Actual cache hits/misses |NA:no cache |NA:no cache |NA:no candidate |
| Actual cache-related extra cycles |0 |0 |NA |
| All tensor/logits/physical KV Golden |PASS |PASS |NA |

Matrix6,600 includes initial1,152, prepare/execute2,080, prefetch1,416,
writeback1,696,lifecycle256. SFU49,595 includes fetch34,888,
arithmetic/cache/control10,259,writeback4,232,lifecycle216. Control6,424 includes
completion request1,824,descriptor request592,other response/dispatch4,008.
These exclusive values close65,771; admission-stall counters overlap and are not
added. No-engine remainder is not exclusively causal dispatcher stall.

Fresh trained CNN mappings reproduce65,429/22,983/**12,351** CMDQ cycles;
all20,800 Golden words each pass; both-fused traffic64,064 read/16,640 write B,
DMA payload10,944 B,window3,019,busy2,879. Fresh output hash remains
`04b138d012cc69ccdbd28dfb2c36f187bf0c6b7e91596dd088d4e93641c3a5f6`.
VCS focused Matrix seed20261110:18 numeric+35 fault cases PASS, Line contract and
prefetch/abort/reset/watchdog checks PASS. SFU same seed:64 numeric+9 error cases,
39 selected reset/39 abort states, parameter latching and recovery PASS.
Default512 KiB Top Smoke PASS; dedicated128 KiB H16/CNN/contract tests PASS.
No new model quality evaluation is needed to claim unchanged outputs: weights,
reference and all executed outputs are identical. Stage A held-out quality
74.4629% INT8 remains the stated metric, including its FP32 quality gap.

## Gate 4 — Bounded cost and ASIC risks

Actual added product data flops=**0**, metadata bits=**0**, MACs=0, ports=0,
FIFO entries=0; no source list or synthesizable module changes. Python model and
SV fault harness are not product hardware. Gate4 candidate lint/synthesis is
**NOT_RUN_GATE0_FAILED**; there is no enabled candidate to synthesize or compare.
New test harness elaborates under VCS with no `Warning-*` or `Error-*` diagnostics
in the final directed build. Existing workload support/debug warnings remain;
VCS elaboration is not latch/width/loop signoff.

If reopened, a concrete provisional bit allocation is1,024 data bits plus197
control/metadata/response bits: base32,length6,epoch16,producer16,consumer16,
signal16,mask32,index5,format2,flags8,pending data32,pending epoch16.
This is an **illustrative allocation**, not a minimum proven by synthesis;
last-event-writer provenance and all-writer/protection control can add state.
Per-word cache parity adds32 bits and still does not check SRAM. Thus Stage A's
≤160-bit metadata envelope was not a validated complete implementation cost.

128-bit committed-write capture feeds word enables; lookup may select32×32 bits
through a mux plus tag/lease comparison and authorization. Put lookup result in
an explicit response register before the existing SFU arithmetic stage; do not
create unregistered SPAD response→cache selection→shift/saturation. Snoop fanout,
same-clock invalidation, region comparisons and reset/epoch control require
lint/structural checks, then local mapped synthesis and STA. **400 MHz=2.5 ns**;
no area/Fmax/power/energy target is asserted. Retaining SRAM reads plus the cache
provides no demonstrated memory-energy saving; toggling extra flops may cost more.

## Strictly scoped mode proposal — pending architecture review

A relaxed mode could define the forwarding cache as the authoritative source
for a completed producer→consumer lease, while all mandatory INT32 SRAM writes
remain observable. It must explicitly state that a hit **does not re-observe
SRAM parity after producer commit**. This is a fault-observation change, not a
transparent implementation of the old contract. It is not safe to describe it
as “same checks, just faster”.

A reviewable minimum contract would require:

- Explicit per-command software opt-in and capability discovery, default off;
  existing descriptors/0x36 strict mode unchanged; no bit/opcode assigned here.
- Only single128 B contiguous committed0x30→0x36, exact fields/layout/format,
  no in-place alias, successful producer retirement, fresh event provenance,
  one consumer lease, no unexplained queue restart or epoch wrap.
- Per-consumer current read+execute authorization and range validation. Any
  protection configuration update invalidates/cancels leases, including pending
  responses; write permission is never substituted for read permission.
- All accepted overlapping writes invalidate with same-clock priority, including
  host/debug strobes and DMA; cache error checks cover cache storage. Unsupported
  capture/ownership conditions use original strict SPAD fallback.
- No suppressed required INT32 writes, no changed fixed-point/packing/Golden;
  original error/abort prefix and exactly-once completion rules specified for
  both hit and miss. The changed SRAM fault-observation scope is explicit.

**This mode is not approved, implemented or enabled.** Await architecture review;
if changing fault observability is unacceptable, retain B1 and close this B2 path.
A memory-check-preserving request pipeline would be a separate proposal, not an
implicit continuation of this failed bypass experiment. No A3 work is started.

## Research/product/publication decision and TinyNPU limits

The mechanism actually delivered is an independent transaction model and a
reproducible counterexample, not cache RTL. Existing Requant always fetches
INT32 and applies fixed integer postprocess; existing Matrix elastic forwarding
retains bounded packed Matrix→Matrix tiles under a separate opt-in shape
contract. Neither establishes transparent cross-engine SRAM fault equivalence.

Independent research value: **useful negative result and quantified design
boundary**, including event provenance, committed masks and check observability.
Product retention: **do not retain/install this transparent cache**. Retain the
model, tests and report. Paper contribution: **not established**; ordinary
write-through caching/forwarding is conventional, and no implemented B2 benefit,
area/timing or representative matched-system result supports a standalone claim.
A later explicitly reviewed mechanism would need its own Golden/ablation/PPA and
closest-related-work differentiation.

TinyNPU remains pinned to`8216c22b762011aa20c05fc2768423fd12dda59d`. Stage A common
QKV array inputs/raw outputs have matched compute boundaries, but do not include
product Requant/SPAD fault checks or full persistent Transformer. Native Tiny
64 KiB byte-wide SRAM and modeled DMA differ from NMA128 KiB/AXI4. No B2 result
or Tiny system speedup exists; the earlier array3× schedule ratio is not evidence
for this cache. The≥3% admission target is **not achieved by qualified RTL**.

## Reproduce

From the Stage B report checkout, use fresh absolute output directories. VCS
`V-2023.12-SP1_Full64`, Python3.12; canonical Makefiles follow the EDA skill/project
contract. No private library/license/configuration is committed.

```bash
python3.12 tools/benchmark/stage_b/test_model.py
python3.12 tools/benchmark/stage_b/replay.py --out /tmp/stage-b-model-replay
STAGE_B_CONTRACT_OUT=/tmp/stage-b-contract-replay \
 bash tools/benchmark/stage_b/run_contract.sh
STAGE_A_OUT=/tmp/stage-b-baseline-replay STAGE_A_PYTHON=python3.12 \
 bash tools/benchmark/stage_a/run_nma.sh
python3.12 tools/benchmark/stage_a/run_cnn.py \
 --simv /tmp/stage-b-baseline-replay/simv --out /tmp/stage-b-cnn-replay
python3.12 tools/benchmark/stage_a/analyze.py \
 --run /tmp/stage-b-baseline-replay --cnn /tmp/stage-b-cnn-replay \
 --out /tmp/stage-b-analysis-replay
make -C dv/block/compute/sfu/sim random-latency-test PYTHON=python3.12 \
 OUT_DIR=/tmp/stage-b-sfu-replay SEED=20261110
make -C dv/block/compute/matrix/sim core-random-test \
 CORE_OUT_DIR=/tmp/stage-b-matrix-replay SEED=20261110
make -C dv/subsystem/top_smoke/sim ai_smoke
python3.12 tools/benchmark/stage_b/validate.py
```

Archive regeneration: copy
`benchmark/research/stage_b/collection_inputs.json`, replace paths with the fresh
run/model/test log paths, then
`python3.12 tools/benchmark/stage_b/archive.py --inputs <new.json> --out <fresh-dir>`
and validate with`--archive <fresh-dir>`. Deterministic gzip, LF CSV, SHA256,
no executable/coverage/waveform/library assets. The archive preserves the same
baseline, all8 token dictionaries and9 full Golden snapshots plus model/sweep/
contract/regression logs. Final decision **REJECT**; stop after publication.
