# NMAForge v2 DV Closure Status

**Status:** IN PROGRESS — scoped regressions pass; v2 sign-off is not ready.  
**Reviewed RTL/test candidate SHA:** `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164`

**Candidate tree:** `dbf5060ac465ef4bb913543024182b298f675413`

**Report commit before this RTM update:** `f4ed9c4f5b711bd6554d588477957e9bf3ce3806`

**Baseline:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`

This report records the initial replay at `33e8528` and now defines the
normalized v2 `REQ-V2-*` identifiers below. The RTM binds both that fixed
replay and the subsequent validator, GEMV, forwarding, formal, and clean Top
replay evidence to the exact source/test SHA. It does not replace the v1.0
38-row RTM.

## Initial three-seed replay commands

These runs used the reviewed test SHA `33e85287fbf37187fccb76e97be6effe888670e9` from a detached clean worktree.
Artifacts were isolated under `/tmp`; no VCS database or generated simulator
binary is committed.

```sh
make -C dv/block/control/sim descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_v2_descriptor_validator_33e8528

make -C dv/block/compute/matrix/sim product-gemv-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_product_gemv_33e8528

make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_core_regress_33e8528

make -C dv/block/compute/matrix/sim core-tile-forward-regress \
  SEEDS='20261105 20261106 20261107' \
  TILE_FORWARD_REGRESS_OUT=/tmp/nmaforge_v2_p2_tile_forward_33e8528

make -C dv/subsystem/top_smoke/sim ai_comp
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261107 SEED=20261107
```

The runs used the following VCS setup:

```sh
VCS_ARCH_OVERRIDE=linux
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10'
```

## Normalized v2 Execution RTM

This RTM assigns stable `REQ-V2-*` identifiers to the implemented v2 contract.
The evidence is scoped to each named shape/testpoint; a `PASS` below does not
mean the whole opcode or v2 subsystem is signed off. “Assertion” identifies a
real SVA/formal property when one exists; otherwise it says `none` rather than
claiming a testbench fatal check is an assertion. Directed marker names are
functional coverage evidence, not merged URG coverage bins.

| Requirement | RTL feature | Test / checker | Assertion | Coverage / disposition point | Run ID, seed, source SHA | Status and evidence path |
|---|---|---|---|---|---|---|
| REQ-V2-COM-001: ABI-v7 routes 0x52/0x53 to the shared Matrix engine | Opcode decode, descriptor validator, dispatcher | `tb_ai_descriptor_validator`; Top CMDQ output/completion checks | No v2-specific SVA | legal opcode classification; actual CMDQ dispatch | `V2-DESC-VALIDATOR-AC6B83F`, seed N/A, `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164`; `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`, 20261105/06/07, `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PASS (scoped)**; validator log `/tmp/nmaforge_v2_descriptor_validator_ac6b83f/run.log`; Top archive `/tmp/nmaforge_v2_top_cmdq_clean_3seed_3a283c0_logs.tar.gz` |
| REQ-V2-COM-002: v2 additions preserve legacy 0x30/0x31 behavior and aux compatibility | Additive opcode ABI | Validator accepts legacy 0x30 aux behavior; Top fused path retains SPAD writeback | No v2-specific compatibility SVA | legacy aux acceptance; baseline and 0x53 producer writeback | `V2-DESC-VALIDATOR-AC6B83F`, seed N/A, SHA `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164`; `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`, seeds 20261105/06/07, SHA `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PARTIAL**; tested points pass, broad legacy opcode regression is not part of the v2-specific replay; validator and Top archives linked above |
| REQ-V2-052-001: accept only the documented dense GEMV descriptor subset and legal boundaries | Opcode 0x52 validator | `tb_ai_descriptor_validator` fatal/count checks | None | 43/43 boundary accepts, 26/26 rejects; 33 invalid-rule cases | `V2-DESC-VALIDATOR-AC6B83F`, seed N/A, `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` | **PASS (validator scope)**; `/tmp/nmaforge_v2_descriptor_validator_ac6b83f/run.log`; does not prove execution at maximum encoded dimensions |
| REQ-V2-052-002: reject output overlap with padded A, dense B, enabled bias, and 32-bit address wrap | Opcode 0x52 span validation | Directed overlap/overflow vectors and `check_invalid` | None | adjacent A/output acceptance; A, B, bias overlap rejects; B end-address wrap reject | `V2-DESC-VALIDATOR-AC6B83F`, seed N/A, `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` | **PASS (directed validator scope)**; same validator log; runtime aliasing of externally changing inputs remains a software ownership contract |
| REQ-V2-052-003: signed INT8 GEMV, optional bias/postprocess and INT32 outputs match independent Golden | Shared 256-MAC Matrix array, opcode 0x52 mapping | `check_dense_gemv_case`, Top independent reference and output image checks | No opcode-specific SVA | M4×16×32, 64 outputs; bit-exact Golden | `V2-GEMV-CORE-3SEED-18DAD2B`, 20261105/06/07, `18dad2ba4c502680893094bb726d88377d33eb9b`; Top run above, `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PASS (tested shape)**; `/tmp/nmaforge_v2_gemv_random_replay_307eac8_logs.tar.gz` (SHA-256 `4fd0ba313b484a2da588562ff62411b2951ca089bb703a74e49fed7f2bc506c1`), Top archive above |
| REQ-V2-052-004: mask M/N/K tails and never write beyond logical output span | Opcode 0x52 K-fold and scalar-tail output | `check_dense_gemv_tail_case`, `check_dense_gemv_mrows_tail_case`; Top Memory Image/Gateway checks | None | M1×13×17; M8×16×19; M16×16×19/65; scalar and line write counts | `V2-GEMV-CORE-3SEED-18DAD2B`, 20261105/06/07, `18dad2ba4c502680893094bb726d88377d33eb9b`; `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`, same seeds, `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PASS (these shapes only)**; GEMV and Top logs/archives above; full legal M/N/K space remains open |
| REQ-V2-052-005: B-fold cache returns correct values, saves repeated B reads, and bypasses K beyond 64 | Existing bounded local reuse array | Core independent INT32 Golden, cache-hit/read-saved counters, response drain | None | M8/M16 K19 cache hits; K65 first-64 bounded cache and uncached remainder; 48/48 cache-config-shape-seed points in four-way suite | `V2-GEMV-FOUR-WAY-S20261105-K19-B0-P0` family, seeds 20261105–07, RTL/test SHA `b9d593e5f55869ff4a47748013a4b15dcd60f83f` | **PASS (tested shapes/configs)**; [CSV](../../benchmark/v2_p2_gemv_cache_prefetch_4way.csv), [summary](../../benchmark/v2_p2_gemv_cache_prefetch_4way_summary.json), report [ablation](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md) |
| REQ-V2-052-006: bounded next-K prefetch uses an inactive buffer and overlaps legal MAC work | Existing double operand buffers / prefetch controller | Core checks active/inactive buffer, handoff, completed/overlap counters and Golden | Generic Matrix FSM guard only; see COM-003 | prefetch handoff, both buffers observed, nonzero overlap; four-way ON/OFF results | `V2-GEMV-CORE-3SEED-18DAD2B`, 20261105/06/07, `18dad2ba4c502680893094bb726d88377d33eb9b`; four-way run SHA above | **PASS (tested profiles)**; GEMV archive and ablation CSV; starvation/fairness under other engines remains open |
| REQ-V2-052-007: count accepted reads, return responses to the correct command, and drain before completion | Matrix response FIFO / outstanding tracker | Single-core responder ledger checks accepted vs returned and no pending response | No v2 ownership SVA | high-water 4; response wait, backpressure and drain observed in directed Matrix tests | `V2-GEMV-CORE-3SEED-18DAD2B`, 20261105/06/07, `18dad2ba4c502680893094bb726d88377d33eb9b` | **PARTIAL**; single Matrix client is checked, but multi-engine response-owner attribution and hostile held-response cases are not closed; GEMV archive and core TB |
| REQ-V2-052-008: GEMV abort/reset/parity/protection recover without stale writes or lost response ownership | Opcode 0x52 lifecycle plus Matrix faults | Existing generic Matrix `finish_fault`, `run_phase_abort/reset`, outstanding abort/parity and recovery checks | Generic Matrix FSM formal only; no GEMV-specific property | Generic 18 functional/35 fault cases per seed; not run with opcode 0x52 descriptors | `NOT_RUN@f4ed9c4`, seed N/A, candidate `f4ed9c4f5b711bd6554d588477957e9bf3ce3806` | **PARTIAL**; current generic-core coverage cannot substitute for opcode-specific interleavings; no v2 GEMV fault-by-phase cross |
| REQ-V2-052-009: supported GEMV path rejects transpose, stride, batch, head, reserved flags and invalid alignment | Opcode 0x52 descriptor legality | Validator directed `check_invalid` and boundary checker | None | unsupported descriptor field rejection | `V2-DESC-VALIDATOR-AC6B83F`, seed N/A, `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` | **PASS (directed validator scope)**; descriptor run log |
| REQ-V2-053-001: fused Matrix postprocess/requant order and packed Matrix-A layout match bit-exact Golden | Opcode 0x53 fused path | Core fused boundary checker; Top producer/consumer independent output-image checker | No opcode-specific SVA | signed requant boundaries and 16×16×16 output image | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, 20261105/06/07, `33e85287fbf37187fccb76e97be6effe888670e9`; Top run SHA `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PASS (tested path)**; [tile metrics CSV](../../benchmark/v2_p2_tile_forward_3seed.csv), core/Top logs and archives |
| REQ-V2-053-002: capture becomes valid only after accepted producer lines and consume uses exact tag or SPAD fallback | 512 B bounded tile-forward buffer | Core capture mask/final-line checker; tag hit and miss Golden/read-count checker | None | full capture mask; exact tag hit; mismatch miss and 32-read fallback | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, 20261105/06/07, `33e85287fbf37187fccb76e97be6effe888670e9`; Top run above | **PASS (tested core path)**; tile CSV and report; Top CMDQ producer/consumer also passes |
| REQ-V2-053-003: consume old bank while capture writes the opposite bank; preserve outputs and flip banks | Ping-pong buffer control | Core chain Golden + bank/tag comparison; Top CMDQ output/completion differential | None | simultaneous consume/capture, old-bank data, opposite-bank flip, 16 source-A reads saved | core run SHA `33e85287fbf37187fccb76e97be6effe888670e9`; Top `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`, seeds 20261105/06/07, `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PASS (16×16 chain)**; tile CSV and Top archive |
| REQ-V2-053-004: producer writeback backpressure cannot outrun capture or alter committed image | Fused line writer and capture handshake | Core `tile_forward_backpressure_seen`, final line and complete memory image checks | None | line stall, all 16 accepted lines, capture mask `ffff` | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, 20261105/06/07, `33e85287fbf37187fccb76e97be6effe888670e9` | **PASS (directed line-ready stall)**; tile report/CSV; arbitrary held-response timing remains untested |
| REQ-V2-053-005: Abort/reset invalidate tile tag and prevent prior-epoch reuse | Local tile validity epoch | Core abort/reset probe and stale-tag prevention check | No epoch-specific SVA | reset flush, abort invalidation, response drain, fallback after invalidation | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, 20261105/06/07, `33e85287fbf37187fccb76e97be6effe888670e9` | **PARTIAL**; tag invalidation is checked, but a delayed response crossing reset epoch is not injected as a feature-specific test; tile report/logs |
| REQ-V2-053-006: parity/protection/held response/Completion faults preserve 0x53 error and memory contract | Fused path fault lifecycle | No complete feature-specific checker/testpoint | None | NOT_RUN | `NOT_RUN@f4ed9c4`, seed N/A, candidate `f4ed9c4f5b711bd6554d588477957e9bf3ce3806` | **NOT_RUN**; open item in this report |
| REQ-V2-053-007: software-held source immutability and cross-engine SPAD access obey the forwarding contract | Explicitly ordered local handoff, no coherence | Contract reviewed; no cross-engine checker | None | source mutation/DMA or other-engine write during handoff NOT_RUN | `NOT_RUN@f4ed9c4`, seed N/A, candidate `f4ed9c4f5b711bd6554d588477957e9bf3ce3806` | **NOT_RUN**; spec requires source immutability, but there is no coherent cache or test evidence |
| REQ-V2-COM-003: new-feature assertions are connected and non-vacuous | Matrix FSM and top SVA | VC Formal proves existing Matrix guard set; Top SVA is AXI/quiescence scoped | Formal: 5/5 named Matrix assertions non-vacuous and 2/2 covers reached at `145363ddff5141177421ee7429fc65f78834830d`; no opcode-specific 0x52/0x53 assertion | `prefetch_wait`, `error_drain` covers; no v2 opcode transition cross | `V2-MATRIX-FSM-GUARDS-145363D`, formal run, SHA `145363ddff5141177421ee7429fc65f78834830d` | **PARTIAL**; this does not prove new opcode properties or full SVA connection coverage; `/tmp/nmaforge_v2_matrix_fsm_formal_33e8528/vc_formal.log` |
| REQ-V2-COM-004: all legal v2 functional bins are merged and every exclusion/waiver has disposition | URG functional/code coverage | No current-candidate URG merge or reviewed exclusion set | No coverage assertion | VCS line/condition/FSM/branch enabled on core suite, but DB not merged and no per-bin disposition | `NOT_RUN@f4ed9c4`, candidate `f4ed9c4f5b711bd6554d588477957e9bf3ce3806` | **NOT_RUN**; no coverage percentage/closure claim; raw run logs are external only |
| REQ-V2-COM-005: each new checker detects its assigned RTL fault through mutation | 0x52/0x53 checkers | No v2-specific RTL mutation campaign | None | data/address/owner/WSTRB/completion mutations for v2 NOT_RUN | `NOT_RUN@f4ed9c4`, candidate `f4ed9c4f5b711bd6554d588477957e9bf3ce3806` | **NOT_RUN**; historical v1 mutation results are not inherited |

### Fixed run identities and reproducibility

- `V2-DESC-VALIDATOR-AC6B83F`: VCS `V-2023.12-SP1_Full64`; seed is not applicable because the test is directed. The run used `VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH VCS="/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10" make -C dv/block/control/sim descriptor-validator-regress DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_v2_descriptor_validator_ac6b83f`; compile/run logs are under `/tmp/nmaforge_v2_descriptor_validator_ac6b83f/`.
- `V2-GEMV-CORE-3SEED-18DAD2B`: VCS `V-2023.12-SP1_Full64`; Seeds 20261105/06/07; logs-only archive SHA-256 `4fd0ba313b484a2da588562ff62411b2951ca089bb703a74e49fed7f2bc506c1`.
- `V2-GEMV-FOUR-WAY-S20261105-K19-B0-P0` family: VCS `V-2023.12-SP1_Full64`, four-bank registered behavioral SPAD with seed-controlled Ready/latency; Seeds 20261105/06/07, 48/48 bit-exact Cache × Prefetch × shape × seed points.
- `V2-TILE-FORWARD-CORE-3SEED-33E8528`: VCS `V-2023.12-SP1_Full64`; 6/6 OFF/ON runs across Seeds 20261105/06/07; output images bit-exact. Raw CSV is checked in; raw simulator logs are in the referenced `/tmp` archive described in the tile replay report.
- `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`: VCS `V-2023.12-SP1_Full64`; clean detached worktree, `make ai_comp` then `make ai_run AI_RANDOM_CASES=4 AI_SEED=<seed> SEED=<seed>` for Seeds 20261105/06/07; logs-only archive SHA-256 `8e1bc2c3329de0ac11eedafed3972918baecf321c01b09990195662d691e35f6`.
- `V2-MATRIX-FSM-GUARDS-145363D`: VC Formal `V-2023.12-SP2`; 5/5 named Matrix FSM assertions proven/non-vacuous and 2/2 state covers reached. It is not an opcode 0x52/0x53 assertion campaign.

The RTM currently has 21 requirement IDs: 12 scoped PASS, 5 PARTIAL, and 4
NOT_RUN. No `BLOCKED_ENV` row was converted to PASS; all successful rows have
a named, limited test scope. This remains an execution RTM, not an approval
record. The
product GEMV machine-readable profiles are in
[`v2_p2_product_gemv_3seed.csv`](../../benchmark/v2_p2_product_gemv_3seed.csv).
Tile Forwarding raw metrics are in
[`v2_p2_tile_forward_3seed.csv`](../../benchmark/v2_p2_tile_forward_3seed.csv).
Raw logs remain under the `/tmp` directories named above. Stage occupancy
counters are state cycles; arbitration, response, writeback, bank, and line
stall counters are event counts that may overlap. They must not be added as
though they partition total latency.

## Additional fixed-candidate formal evidence — 2026-11-05

At RTL/test SHA `145363ddff5141177421ee7429fc65f78834830d`, the existing
Matrix FSM guard formal target passes:

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_v2_matrix_fsm_formal_33e8528
```

VC Formal V-2023.12-SP2 reports 5/5 assertions proven and non-vacuous, plus
2/2 reachability covers (prefetch wait and error drain). The target's setup
and proof gates pass. This is additional evidence for those named safety and
reachability properties only; it does not close full FSM transition coverage,
new-opcode fault proofs, RTL/gate LEC, or the v2 RTM. Log:
`/tmp/nmaforge_v2_matrix_fsm_formal_33e8528/vc_formal.log`.

Current v2 lint/CDC/RDC and PPA readiness are summarized in the
[ASIC readiness report](NMAFORGE_V2_ASIC_READINESS.md). RDC remains NOT_RUN and
DC Base-vs-v2 PPA remains BLOCKED_ENV.

## Current-branch clean Top CMDQ replay — 2026-11-05

The product Top Smoke was recompiled and rerun from a detached clean worktree at
`3a283c04724378c46747d907505eb82ea1ccbd4a` (tree
`45ec75947744026e1510f881aa474136f211129d`). VCS
`V-2023.12-SP1_Full64` passed Seeds `20261105`, `20261106`, and `20261107`.
Each run reported `TEST PASS` and matched the exact markers for the real CMDQ
`0x52` M4 GEMV descriptor, M1/N13/K17 scalar tail, M8/N16/K19 K tail, and the
`0x53` 16×16 producer/consumer output and completion differential. The
forwarded path observed 16 baseline source-A reads versus zero forwarded
source-A reads; both producer and consumer output images were bit-exact and
legacy SPAD writeback remained enabled.

Commands, run from
`/tmp/nmaforge-v2-top-clean-3a283c0/dv/subsystem/top_smoke/sim`:

```sh
make ai_comp
make ai_run AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105
make ai_run AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106
make ai_run AI_RANDOM_CASES=4 AI_SEED=20261107 SEED=20261107
```

The compile emitted the existing `LOOP-REROLL-ENABLED` notice for
`ai_transformer_workload.svh`; there were no compile errors. Per-seed feature
markers, `TEST PASS`, and the compile log are archived outside Git at
`/tmp/nmaforge_v2_top_cmdq_clean_3seed_3a283c0_logs.tar.gz` (SHA-256
`8e1bc2c3329de0ac11eedafed3972918baecf321c01b09990195662d691e35f6`). Run ID:
`V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`.

This current-branch replay adds reproducibility for the named top-level test
points only. It does not close the v2 fault/coverage matrix or change the v1.0
Compute Cluster disposition from **HOLD**.

## Open closure items

1. Extend the RTM evidence until every required v2 testpoint has a current-SHA
   run, named checker, assertion disposition, and coverage-bin disposition; the
   current 21-row RTM is normalized but still contains PARTIAL/NOT_RUN rows.
2. Add current-SHA feature-specific `0x52`/`0x53` Parity, Protection,
   held-response, request backpressure, Abort, Reset, and stale-epoch tests.
3. Define and test tile-source immutability under cross-engine SPAD traffic;
   test repeated consume and producer/consumer interleavings.
4. Review/merge current-SHA functional coverage; audit assertions for
   connectivity and non-vacuity; run actual RTL checker mutations for every
   v2 error class.
5. Complete old-opcode compatibility regression beyond the selected Top
   Smoke and Matrix-core test points.
6. Run formal/LEC, CDC/RDC, DC, SRAM mapping, DFT preparation, and PPA only
   with the appropriate tool, constraints, libraries, and licenses. These
   results remain `NOT_RUN` or `BLOCKED_ENV` as applicable.

The v1.0 Compute Cluster remains **HOLD**; no system-wide or ASIC sign-off is
implied by the scoped v2 evidence above.
