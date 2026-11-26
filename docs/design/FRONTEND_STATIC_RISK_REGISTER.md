# Phase 1 — front-end static risk register

Status: **DESIGN_PARTIAL; review only, no product RTL repair or signoff**.
RTL `48790076b351cb9d49e1785247d32a1f51b8286d` / tree
`c86d2cfda7cde900482f38a3b48b620bc69f67cb`.128KiB/four-bank default,
optional512KiB elaboration,256MAC, ABI unchanged. Baseline Verilator5.052
`--lint-only --timing -Wno-fatal +define+VCS --top-module ai_accel_top` on the
canonical Top filelist. The flag allows warning collection, not warning approval.
No SpyGlass/DC/PPA/DFT/P&R was run.4ns functional simulation does not prove
400MHz;2.5ns physical timing remains unmeasured.

[Manifest, logs and warning hashes](../../benchmark/research/phase1/manifest.json),
[all196 warning identities/dispositions](../../benchmark/research/phase1/analysis/static_warning_inventory.csv),
[exact commands](../../tools/benchmark/phase1/README.md).
Public baseline/throwaway-copy logs retain full paths/dependency traces. All
warning records remain OPEN_SCOPED_REVIEW; diagnostic findings are not waivers.

| Warning | Reproduced baseline | Diagnostic local-default copy | Disposition |
|---|---:|---:|---|
|PINMISSING|2|2|Optional CDC wrapper interface gap; inactive product instance, fix recommendation|
|WIDTHTRUNC|64|64|Parameter/index/arithmetic/transfer bounds need explicit proof|
|WIDTHEXPAND|113|113|Signedness/address widening review; not automatic harmlessness|
|CASEINCOMPLETE|4|4|Two deliberate default/hold decode patterns, two illegal-state recovery gaps|
|LATCH|10|0|Local temporary missing default; downstream block-analysis propagation likely|
|UNOPTFLAT|3|3|Coarse procedural dependency feedback remains; bit-level acyclicity closure required|

## P1 — compute scalar mux latch diagnostics

`rtl/top/fabric/compute/ai_compute_spad_mux.v:42` puts arbitration selection,
ready/protection routing and registered-response demultiplexing in one
combinational process. Integer `candidate` is assigned only in the round-robin
`else` loop; the held-owner branch retains its prior temporary value. Therefore
the incomplete assignment of this temporary is real coding debt, not an
intentional architectural latch. It is read only after assignment in the loop,
so source inspection does not identify a functional dependence on its retained
value in the held-owner branch.

The nine other flagged outputs (`core_spad_valid/write/addr/wdata`, engine ready,
protection error and response valid/data/error) all have explicit unconditional
defaults before conditional routing. In a **throwaway source copy** adding only
`candidate=0` removes all10LATCH warnings; all other warning counts remain equal.
This supports a local analysis-propagation explanation for those nine outputs.
It does not constitute synthesized netlist/LEC proof or authorize silently
waiving them. Product RTL is unchanged. Future narrow repair: default temporary,
separate pure selection from handshake/response fanout, then equivalence plus
backpressure/held-owner/reset/abort/parity/protection tests. No evidence currently
requires an emergency Phase1 behavioral RTL change.

## P1 — three SPAD/protection combinational dependency paths

Warnings identify `arb_core_ready`, arbiter `accept_client` and
`compute_prot_error`. The example path is ready/protection→mux procedural block→
core request valid/address→arbiter select→SPAD protection→mux block again.

Source-level dependency review:

- Mux selected owner/valid depend on registered owner state and request valids,
  not `spad_ready`, protection error or response data. Ready/error inputs only
  route to per-engine outputs. The same process makes this distinction coarse
  for a scheduling-based lint tool.
- `ai_spad_arbiter` admission selection depends on request valids and registered
  round-robin state. Ready outputs decode the resulting accepted client; they
  do not feed admission selection directly. Request-time protection error is
  pipelined into the tagged response, not used to suppress the selected request.
- Top protection depends on selected request address/valid/client. It returns an
  error to the owner. Changing admission to hide that error would change the
  fault contract and is prohibited.

This explains a plausible structural false-cycle mechanism, but all3warnings
**persist after the temporary default diagnostic**. The complete path includes
engine output-generation blocks, and no bit-level graph/equivalence/physical
netlist proof was completed. Disposition: unresolved structural/timing risk,
no blanket waiver and no claim of a confirmed oscillating logic loop. Future
split-process diagnostic plus topological cone check must prove request signals
independent of ready/error and preserve error precedence/registered response
ownership. Avoid inserting a pipeline that loses accepted transactions or shifts
protection sampling without a reviewed contract.

## P2 — missing pins and incomplete cases

Missing `dependency_events_load` and16bit`dependency_events_seed` are at
`rtl/control/cdc/ai_accel_dual_clock_command_path.v:297` on its command processor.
That wrapper is in the source list but not instantiated by the single-clock
product `ai_accel_top`; it is not evidence that the active product queue has
missing pins. Floating inputs can create X/unsupported seed behavior if the
optional wrapper is used. Review that CDC packet/seed contract; explicitly tie
load0/seed0 if unsupported, or carry valid seed transactions correctly. Do not
claim optional dual-clock integration ready for reuse before closure.

`ai_accel_regs.v:232` initializes `reg_rsp_rdata=0`, then enumerates known read
addresses without a default branch. Unknown/misaligned accesses separately
produce `reg_rsp_error`; there is no need to retain old read data. Its sequential
write case at296 is guarded by valid/write/no-error; fields intentionally hold
unless written. These two warnings have an explicit plausible hold/default
justification, conditional on address/readonly/lock coverage. No blanket
CASEINCOMPLETE suppression is proposed.

`ai_kv_cache_engine.v:137` and `ai_conv3x3_linebuffer_core.v:87` enumerate legal FSM
states without illegal-state recovery. Reset and ordinary transitions use legal
states; unexpected encodings can hold state/busy until watchdog/abort intervenes
(or indefinitely with watchdog0). This is a robustness gap, not proven reachable
in normal execution. Add a reviewed illegal-state terminal-error/drain policy in
a future scoped patch; never reset away an accepted read/write without ownership
accounting or suppress a fault completion.

## P2 — width inventory and limits

All177width findings are listed individually with file/line, exact message,
classification and next action. No evidence here establishes that all are safe.

| Category | Review focus / proposed future validation |
|---|---|
|Matrix parameters/index/boolean|READ_FIFO_LAST, response K/group and array indices; prove legal depths and group bounds at each2/4/etc elaboration; explicitly size constants/boolean enables|
|DMA transfer/ID/burst|Slot/pointer wrap subtraction, burst planner shifts/beat count and4KiB boundaries; legal outstanding range and ID mapping; directed wrap/overflow tests|
|Memory/KV/CNN/pipeline address/index|32/64bit intermediate extension, word/line indexing, CNN width≤128, stride×token overflow before narrowing;128/512KiB boundary rejection|
|SFU/INT8 arithmetic|Sign extension of32bit operands into64bit sum and saturation/rounding; extreme negative/positive vectors and exact independent integer reference|
|Optional FP exponent/rounding|Mixed signed widths/exponent fields and narrowed results; separate numeric corner tests, not covered by INT8 benchmark Golden|
|Control counters/address shifts|Queue head+base shift widths, registered pointer/counter narrowing, dispatch indices; range and wrap invariants|

Some extensions are likely intentional zero/sign extension and some constant
truncations likely match constrained parameter ranges. That is a hypothesis per
finding, not an accepted waiver. Future patches should add explicit types/casts
only after proving the preexisting intended semantics. Broad cosmetic resizing
in this phase could change signed arithmetic and is deliberately not performed.

## Freeze blockers beyond warning count

| Risk | Status / closure needed |
|---|---|
|SPAD mux latch/feedback classification|Open as above; diagnostic evidence narrows scope but is not signoff|
|Strict parity/protection versus existing optional elastic forwarding|StageB/C transparent bypass rejected. Existing opt-in path's ownership/immutability/fault contract needs explicit product disposition; no new cache authorized|
|SRAM macro interface|Behavioral TDP, two-edge reads and parity storage cannot assume available macro port/latency/read-during-write semantics. Preserve fault observation and accepted-response tags under legal macro mapping|
|400MHz timing|Potential mux/address→permission-compare→owner-ready path; Matrix operand fanout/MACaccumulator, SFU magnitude/multiply/saturation path. No2.5ns constraint or mapped STA evidence in Phase1|
|H32 functional scope|Only one12token teacher-forced RTL session; context boundary/wrap, multi-prompt and broader edge/fault validation remain open|
|Model/application validity|Period3task improves clean diagnostic quality; task oracle equally perfect, no natural-language/pretrained claim|
|Benchmark endpoint fairness|Raw array/common-adapter claims supported; trainedCNN/fullTransformer native system comparison absent|

Front-end freeze therefore remains **DESIGN_PARTIAL**. This phase completes
attribution, quality diagnosis and candidate review; it does not claim static/DV
signoff or physical implementation closure. Stop after publication and await the
RTL optimization decision.
