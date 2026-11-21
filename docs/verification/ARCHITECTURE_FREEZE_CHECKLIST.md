# Architecture Freeze Checklist

**Review baseline:** `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`
**Disposition:** bounded design baseline identified; freeze approval and Compute Cluster DV closure remain pending. Do not treat this checklist as PR approval.

## Frozen design statements

- [x] Active product top is `rtl/top/ai_accel_top.v`; structural engine wrapper is `ai_accel_compute_cluster`.
- [x] Seven engines and opcode routes are enumerated in the [architecture review](FINAL_COMPUTE_CLUSTER_ARCHITECTURE_REVIEW.md).
- [x] Default SPAD geometry is four banks × 8192 × 32-bit = 128 KiB; optional 32768-word banks are a separate 512 KiB profile.
- [x] Compute mux, sole scheduler arbiter, owner tags and Matrix/CNM shared banked class are documented from RTL.
- [x] One active task per engine; cross-engine overlap; per-engine result capture; CMDQ-order retirement; four-word completion publication are frozen by current RTL/SPEC.
- [x] Ordered registered read response, no local response ID/ready and engine-specific outstanding limits are documented.
- [x] Error code meanings, engine-specific priority and accepted output prefix are documented without normalizing them across engines.
- [x] Single top clock `aclk`, asynchronous active-low reset assertion `aresetn`, Abort distribution and external fabric reset contract are explicit.
- [x] No PR merge, new engine, ABI edit or parameter change was performed.

## Required before Compute Cluster DV closure

- [ ] Replace old 512 KiB fixture addresses with checked half-open 128 KiB allocations; prove all descriptor, CPLQ, input, weight, temporary, output, KV and guard intervals fit and legal concurrency does not alias.
- [ ] Run all 21 real-engine pairs on the actual cluster/arbiter/SPAD boundary with a compact fixture and independent Goldens.
- [ ] Close Matrix banked-read versus CNM lane same-turn competition with response tag/lane scoreboarding.
- [ ] Close each engine's opcode/shape/numeric/address RTM and P0 fault × phase × Abort/Reset crosses.
- [ ] Check accepted write prefixes at every output cut; distinguish accepted same-edge writes from rejected/stalled requests.
- [ ] Exercise simultaneous `engine_done` vectors, reverse completion order, per-engine slot ownership, CPLQ full, and software CPLQ_HEAD progress while busy.
- [ ] Prove accepted-read order/owner, request stability and reset flush; test real target fabric coordinated reset for R and B channels.
- [ ] Disposition every width/signedness/static warning by exact source row; no blanket lint waiver.
- [ ] Complete RDC with final reports and review async reset release; keep optional dual-clock shell separately scoped.
- [ ] Fixed-SHA clean worktree replay with tool versions, seeds, manifest and retained coverage databases; leave unhit bins dispositioned.

## Required before ASIC mapping or physical claims

- [ ] Approve the [SPAD Macro Contract](SPAD_MACRO_CONTRACT.md) for geometry, ports, latency, collision/read-first policy, byte masks, parity and reset behavior.
- [ ] Supply legal standard-cell and SRAM libraries plus exact 128 KiB macro wrapper/views and mapping instructions.
- [ ] Supply clock/reset, I/O, operating corner and uncertainty constraints; run DC and inspect unmapped memories/latches/width/sign issues.
- [ ] Verify mapped macro port structure and memory collision semantics against behavioral model with an adapter equivalence suite.
- [ ] Run MMMC setup/hold STA, power with representative activity, DFT/MBIST, APR, extraction, IR/EM and physical verification.
- [ ] Keep all results labeled pre-layout, post-layout or signoff with tool, libraries, constraints and source SHA.

## SPEC ownership and revision gates

- [ ] Reconcile the 512 KiB statements in `docs/spec/NPU_ARCHITECTURE_V2_SPEC.md` with the 128 KiB product default and 512 KiB compatibility profile.
- [ ] Review descriptor validator legality for legacy opcodes plus v2 `0x52/0x53`; do not weaken accepted/rejected behavior to accommodate an invalid fixture.
- [ ] Confirm busy-time CPLQ_HEAD consumer semantics and performance counter visibility/enable definitions against driver ABI.
- [ ] Any change to observable ABI, accepted request timing, fault priority, output prefix, reset contract or macro-visible behavior receives a SPEC revision and focused regression.

## Final gate

- [ ] Compute Cluster requirements have named PASS evidence or explicit owner-approved disposition; no selected-slice result is presented as whole-project closure.
- [ ] PR #7 is separately reviewed and approved by its maintainers; this architecture report does not merge or approve it.
- [ ] Architecture review SHA, report commit SHA and exact reproduction commands are recorded in the project update log.
