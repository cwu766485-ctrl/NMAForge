# Compute Cluster Open-Issue List — 2026-10-28

This list governs the current bounded CL-RC1/CL-RC2 review candidate. No issue is closed by a coverage percentage alone. Severity reflects whether a requirement can be judged under the current approved contract.

## Specification blockers

| ID | Priority | Affected requirements | Open question / consequence | Closure evidence |
|---|---|---|---|---|
| `OPEN-CL-003` | **P0** | REQ-CL-018, REQ-PC-009/010 | Non-FP accepted request depth and Abort/Reset drain/restart contract is only partly frozen; reset behavior for accepted external transactions belongs to the owning fabric. | Design-owner-approved contract plus directed/formal check for each affected engine/phase and stale response/write/completion exclusion. |
| `OPEN-CL-006` | **P0** | REQ-CL-027 | Engine-specific error encoding is implemented, but cross-engine error ABI/mapping is not approved. | Approved error table mapping every supported Engine × Fault to status/completion code, followed by checker-backed tests. |
| `OPEN-CL-002` | P1 | REQ-CL-002/015/020/024/025 | Per-opcode legal ranges for dimensions, address aliasing/overflow, strides and zero values are incomplete. | Frozen validator/descriptor contract and boundary-value tests against independent address/parameter oracle. |
| `OPEN-CL-004` | P1 | REQ-CL-010/022, REQ-PC-007 | Matrix 128-bit line alignment, partial WSTRB, protection and partial-commit behavior are not defined sufficiently for an independent checker. | Approved byte-mask/alignment/protection semantics plus full/partial/zero WSTRB tests and complete output Memory Image comparison. |
| `OPEN-CL-007` | P1 | REQ-CL-017/019/027 | Same-cycle multi-fault priority and committed-prefix rules are not frozen. | Approved fault priority and prefix semantics; legal pairwise fault-phase tests. Do not infer priority from current RTL. |
| `OPEN-NUM-01/02` | P1 | REQ-CL-020/023 | Scalar rounding/saturation boundaries and SFU fixed-point/approximation tolerances are not complete. | Frozen per-opcode numeric appendix and independent bit-accurate/tolerance oracle; rerun edge vectors. |

## Verification closure gaps

## Disposition of the five review recommendations (2026-10-28)

| # | Recommendation | Disposition and evidence | Remaining item |
|---|---|---|---|
| 1 | P0 reset/abort response ownership | The legal owner/epoch checker is active in the real-top UVM. R14 reset recovery exercised active Matrix/SFU, dropped two accepted reads per seed, then checked no old write/completion and a successful fresh task. Selected abort runs drain accepted work. | `OPEN-CL-003` remains: behavior of a response arriving from the external fabric after reset is owned by the fabric reset contract and was not injected in the behavioral SPAD model. Do not consume a prior-epoch response; add a late-response test after the fabric contract is approved. |
| 2 | P0 error ABI, priority and committed prefix | The current RTL constants are enumerated below, and selected error cases check owner, code and memory prefix. This is an as-implemented inventory, not an approved cross-engine ABI. | `OPEN-CL-006` remains P0 for ABI approval. Same-cycle fault priority and legal prefix rules remain `OPEN-CL-007`; no oracle is inferred from RTL ordering. |
| 3 | Mutation checker sensitivity | Exact-candidate R16 caught 25/25 address, data, owner, WSTRB, Done, missing-Done and duplicate-Done observation mutations. | Checker sensitivity is closed for these fields. This is not DUT fault injection or a mutation score; error-code and full prefix sensitivity remain open. |
| 4 | Matrix FSM 49/53 | 15/15 states and the prefetch sub-FSM 9/9 are hit. `ST_MAC→ST_A_REQ` is exercised in the prefetch-disabled build; default prefetch-enabled build exercises `ST_MAC→ST_PREFETCH_WAIT` / valid-buffer handoff. | The other three misses are `ST_PREFETCH_WAIT→ST_A_REQ` (its guard is compile-time disabled, while disabled builds bypass PREFETCH_WAIT), `ST_IDLE→ST_ERROR_DRAIN` (requires busy/error event while idle), and `ST_ERROR→ST_ERROR_DRAIN` (Abort/watchdog guards exclude ST_ERROR). These are source-level guard analyses, not formal unreachable proofs. No VC Formal executable is installed; keep them open and do not force illegal states. |
| 5 | `[TFIPC]`, numeric checker and coverage scope | R14 candidate compile has zero `[TFIPC]`, warning and error diagnostics; SVA engine busy/done ports are connected. R15 makes the five AXI AR/AW/W assertions non-vacuous for its 16-seed traffic. Coverage reports distinguish the focused compute covergroup (29/30) from whole-top URG, which includes DUT, assertions, TB and UVM. | SFU numeric tolerance remains `OPEN-NUM-02`; two UVM RAL properties have no attempts and are out of compute-protocol scope. Broad compute requester × fault/backpressure SVA closure is not claimed. |

### As-implemented error-code inventory

Values are read from the selected candidate RTL localparams and fault assignments. `—` means no separate code symbol was found in that Engine; it does not authorize a new behavior. These values do not define simultaneous-fault priority or a unified software ABI.

| Engine | Config | Opcode | Abort | Watchdog | Parity / SPAD | Protection | Numeric |
|---|---:|---:|---:|---:|---:|---:|---:|
| Scalar INT8 | 1 | 2 | 3 | 4 | Parity 5 | 6 | — |
| CNM | 1 | 2 | 3 | 4 | Parity 5 | 6 | — |
| Matrix | 1 | 2 | 3 | 4 | Parity 5 | 6 | — |
| SFU | 1 | 2 | 3 | 4 | Parity 5 | 6 | 11 |
| Mixed FP | 1 | — | 3 | 4 | Parity 5 | 6 | — |
| Conv | 1 | — | 3 | 7 | Combined SPAD error 4 | — | — |
| KV | 1 | — | 3 | 4 | Combined SPAD error 4 | — | — |

Conv and KV report SPAD errors through one code. KV also uses code 4 for watchdog, so completion status alone cannot distinguish those causes. RTL source references are the seven Engine cores under `rtl/compute/{int8,cnm,matrix,sfu,fp,cnn,kv}/`.

| ID | Priority | Affected requirements | Current evidence / gap | Closure action |
|---|---|---|---|---|
| `CL-RUN-001` | **Closed 2026-10-27** | All 38 | Exact candidate `c0832e5c822de1a03f82751d5ff8f831d0addb98` was replayed in a clean detached worktree after VCS licensing became available. Three real-top UVM seeds and URG merge passed; logs, tool version, checksums, and coverage reports are in RTM run `R14`. | Closed for the selected seven-engine top-UVM regression slice. This does not close individual requirements or other regressions. |
| `CL-COV-001` | P0 | REQ-CL-010/022, REQ-PC-007 | Matrix default FSM 49/53 transitions. Two are mutually exclusive prefetch profiles; two guard/invariant paths have no legal trigger found but no formal unreachable proof. This environment has VCS/URG, but no `vcf`/`vcformal` executable was found. | Preserve separate compile-profile evidence. For the two guard paths, add formal reachability proof in an environment with VC Formal or approved design/invariant disposition. No illegal stimulus. |
| `CL-COV-002` | P0 | REQ-CL-006/010/014/017/018, REQ-PC-006/007/009/010 | Partial Matrix line WSTRB untested; Matrix line-write request stall count is zero in the top UVM; full legal protection/fault × engine × phase × abort/reset cross is absent. | After resolving the associated SPEC items, cover each legal cross and compare accepted memory image/error prefix. Maintain explicit unsupported/blocked statuses for illegal or undefined combinations. |
| `CL-COV-003` | P1 | REQ-CL-002/015/020–028 | All-engine top regression checks representative operations, not every supported opcode × shape × numeric class. Conv widths are 3–6 in the current randomized run; KV stride products are selected, not exhaustive. | Add tests from frozen contract boundaries and prioritize untested legal bins. Keep one independent oracle per operation class. |
| `CL-COV-004` | P1 | REQ-PC-001/006/007 | 21/21 engine pairs pass with real dispatcher and behavioral Engine agents. Production top exercises selected Matrix/CNM/SFU/Scalar concurrency, not all real datapath pairs. | Add top-level legal pair cases where shared SPAD/data dependencies can be made disjoint; record unsupported pairs with rationale. |
| `CL-COV-005` | **Closed 2026-10-28 (scoped)** | SVA non-vacuity / REQ-PC-006/007 | Exact-candidate 16-seed DMA/FP E2E URG: all five AXI AR/AW/W assertions have real successes; AR/AW/W stall-to-accept covers all matched. Two UVM RAL properties remain without attempts and are outside the compute protocol scope. | Closed for the AXI master protocol properties. Keep the two RAL no-attempt dispositions separate; do not call them DUT protocol coverage. |
| `CL-MUT-001` | P1 | REQ-CL-007/008/011–013/017/027 | Exact candidate `c0832e5`: 25/25 passive-monitor observation mutations catch address, data, owner, WSTRB and completion lifecycle faults. This is checker-sensitivity evidence, not RTL/DUT fault injection or a mutation score. | Checker-sensitivity criterion is met. DUT fault injection and complete error-prefix/error-code sensitivity remain open; do not alter product RTL to manufacture a pass. |
| `CL-BENCH-001` | **Closed 2026-10-28** | REQ-CL-028 | Exact candidate `c0832e5c822de1a03f82751d5ff8f831d0addb98`: size sweep 45/45 and eight-way ablation 120/120 over seeds `20261025/26/27`; outputs retained under `/tmp/nmaforge_matrix_{size,config}_c0832e5_*`. | Closed for reproducible Matrix benchmark runs. These are core-cycle measurements with one-cycle behavioral SPAD, not PPA or real SRAM timing. |
| `CL-BENCH-002` | P1 | TinyNPU performance comparison | Matched 16×16×16 signed INT8 GEMM and a 3×3 one-channel convolution lowered to padded GEMM now pass on both RTLs with identical inputs and INT32 Golden. NMAForge uses 8×8 array/one-cycle behavioral SPAD. TinyNPU uses its fixed 8×8 systolic design plus a temporary DSP48E1 functional surrogate because UNISIM is unavailable. See benchmark R19. | **Partial closure:** common-workload arithmetic and simulation-cycle data exist. Different storage/output bandwidth and the TinyNPU primitive shim prevent an implementation-level speedup claim; TinyNPU has no native Conv opcode, so the CNN is an im2col/padded-GEMM mapping. |
| `CL-PPA-001` | Out of current functional scope | System PPA | No current candidate-specific placed-and-routed ASIC area/Fmax/power result is present. | Separate implementation project with approved libraries, SRAM model, constraints, and signoff flow. Do not use the 250 MHz arithmetic normalization as Fmax. |

## Current disposition

- `CL-RC1`: bounded Matrix + SPAD evidence is ready for review; candidate-SHA multi-seed size/ablation and matched-workload benchmarks are recorded. `OPEN-CL-004` and `CL-COV-001/002` still prevent broad closure.
- `CL-RC2`: bounded seven-engine evidence is ready for review; the RTM remains 23 PASS-SCOPED, 13 PARTIAL, and 2 BLOCKED_SPEC. Exact-candidate checker sensitivity and AXI SVA antecedents now have passing evidence. P0 spec blockers `OPEN-CL-003` and `OPEN-CL-006` remain.
- `CL-DV-v1.0`: **not signed** until P0 blockers are resolved and all requirement statuses receive formal review. The fixed candidate SHA clean replay is complete for the selected top-UVM slice.
- Full NPU/system integration, pretrained-model accuracy, and ASIC PPA remain separate scope items and do not block review of the defined Compute Cluster functional slice.
