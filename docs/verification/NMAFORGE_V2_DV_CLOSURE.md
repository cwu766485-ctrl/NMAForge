# NMAForge v2 DV Closure Status

**Status:** IN PROGRESS — scoped regressions pass; v2 sign-off is not ready.  
**Reviewed RTL/test candidate SHA:** `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164`

**Candidate tree:** `dbf5060ac465ef4bb913543024182b298f675413`

**Latest fault replay at GitHub branch HEAD:** `de705ee6317557954af9cb396cda94b01eb1c432` (tree `d948c9f72a24fd6ccdfdef9acfd5d940ceb37cfa`), including the added 0x53 Reset/Epoch scenario.
**Latest RTL-mutation replay:** `a015de58379ca1303ebfc1c4c3899d1fd77affa2` (tree `402f5172240dfe60197bbb41937ab99814333d6a`); this adds only the mutation harness and Make target.

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

## Latest fixed-SHA fault and compatibility replay — 2026-11-05

The fault campaign was rerun at the GitHub branch HEAD
`59d1e5ed6570fefe957a6ed2abc10d6d18c21ed2`; VCS was
`V-2023.12-SP1_Full64`. Matrix-core and Top compatibility runs were run at
`465855acf0ba686421d61d77f36b22f1e23bd4f0`, whose RTL/test files are
unchanged in the branch HEAD.

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim product-opcode-fault-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_opcode_fault_59d1e5e

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_core_compat_465855a

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105
```

All three fault seeds emitted `MATRIX_V2_OPCODE_FAULT_PASS`: opcode 0x52
Parity, B-read Protection, Abort with prefetch outstanding, Reset followed
by an unowned late response, sentinel preservation, and Golden recovery;
opcode 0x53 read Parity, output-write Protection, held-line Abort, sentinel
preservation, and a successful producer/consumer tile chain. The 0x52 checks
compare accepted and returned responses and require the outstanding counter
to drain. The directed run does not cover every Fault × Phase × Reset cross or
external-fabric ownership.

The legacy Matrix-core regression emitted `MATRIX_CORE_RANDOM_PASS` and
`MATRIX_PRODUCT_GEMV_ONLY_PASS` for Seeds 20261105/06/07. Top Smoke emitted
`TEST PASS` and exact 0x52 M4/M1-tail/M8-tail and 0x53 CMDQ forwarding markers.
Top compile reported the existing `LOOP-REROLL-ENABLED` fixture notice; no
compile error was observed. VCS line/condition/FSM/branch instrumentation was
enabled in those Matrix runs; the fault-only `59d1e5e` database was not merged
at the time and had no exclusion review. The later fixed-candidate multi-test
merge and its limits are recorded below.

Fault logs and compile record are archived outside Git at
`/tmp/nmaforge_v2_opcode_fault_59d1e5e_logs.tar.gz` (SHA-256
`5d2f7d0d352287cc00c00ebc04d76f6e637f1a25f60facd7605f1d9d1df257b7`). The
compatibility logs are archived at
`/tmp/nmaforge_v2_replay_465855a_logs.tar.gz` (SHA-256
`cd41f65abb8cb1b38de65fc7d68162ff7310df13bfcfcce0c245e18283447277`). Run
IDs: `V2-OPCODE-FAULT-3SEED-59D1E5E` and
`V2-OPCODE-FAULT-COMPAT-3SEED-465855A`.

### 0x53 Reset/Epoch follow-up at hosted HEAD

The fault campaign was extended with a 0x53 consumer reset while an accepted
B-operand response is outstanding. The test first captures a producer tile,
starts a consumer with delayed bank responses, asserts reset while the consume
is active, then injects the stale response after reset. It checks that reset
clears the outstanding count and forwarding tag, the stale response is
discarded without completion/error/writeback, the destination sentinel is
unchanged, and a fresh producer/consumer Golden chain recovers.

At exact GitHub SHA `de705ee6317557954af9cb396cda94b01eb1c432` (tree
`d948c9f72a24fd6ccdfdef9acfd5d940ceb37cfa`), the following command exited 0
on VCS `V-2023.12-SP1_Full64`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim product-opcode-fault-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_opcode_fault_de705ee_verified
```

All three seeds emitted `MATRIX_0X53_RESET_EPOCH_PASS` and
`MATRIX_V2_OPCODE_FAULT_PASS`, plus bit-exact 0x52 Golden and 0x53 tile-chain
recovery markers. The archived compile and three seed logs are at
`/tmp/nmaforge_v2_opcode_fault_de705ee_verified_logs.tar.gz` (SHA-256
`05edd8a0e9918b6dbd77f7736cbf42ef9ead661822ea430428b9dd4bf50c4675`). VCS
line/condition/FSM/branch collection was enabled. This initial reset-only
three-seed result was subsequently merged with the core suite in the coverage
review below; the functional bins and exclusions still need review. This closes
only this directed reset interleave; it does not establish the full Reset ×
Phase × Engine cross or external-fabric ownership.

## Fixed-candidate DUT coverage and FSM-bin review — 2026-11-05

On branch HEAD `871b752764f1a9b4742732e26e5082a0c728d27b` (tree
`1eb09dd23a5baadd0dc91c7fb7af68bd4ad6ff78`), the RTL, testbench, and source
lists are unchanged from the tested opcode source/test SHA `de705ee`; the
intervening commit only updates reports. The Matrix coverage hierarchy selects
the production `dut` and its MAC-array child, not the testbench.

The default Prefetch-ON database combines three core-random tests (each covers
18 functional and 35 fault cases), three product GEMV Golden tests, and the
three opcode fault/Reset-Epoch tests. The separate Prefetch-OFF database
combines three supported fallback benchmark tests and three product GEMV
Golden tests. Both use Seeds 20261105/06/07. Exact commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_opcode_fault_de705ee_verified

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress \
  SEEDS='20261105 20261106 20261107' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_v2_noprefetch_871b752

# Add product GEMV shapes to the same Prefetch-OFF coverage database.
set -e
for seed in 20261105 20261106 20261107; do
  /tmp/nmaforge_v2_noprefetch_871b752/simv +SEED=$seed \
    +MATRIX_PRODUCT_GEMV_ONLY -cm line+cond+fsm+branch \
    -cm_dir /tmp/nmaforge_v2_noprefetch_871b752/coverage.vdb \
    -cm_name no_prefetch_gemv_$seed \
    -l /tmp/nmaforge_v2_noprefetch_871b752/gemv_seed_$seed.log
done

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_v2_opcode_fault_de705ee_verified/coverage.vdb \
  -format text -report /tmp/nmaforge_v2_opcode_fault_de705ee_verified/urg_full

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_v2_noprefetch_871b752/coverage.vdb \
  -format text -report /tmp/nmaforge_v2_noprefetch_871b752/urg_full

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=4 AI_SEED=20261105
```

The Prefetch-ON URG result reports 9 tests and, for the selected DUT hierarchy,
Line 93.76%, Condition 90.67%, FSM 92.42%, and Branch 96.50%; Matrix core FSM
state coverage is 15/15 and transition coverage is 50/55. The supported
Prefetch-OFF report is a separate build profile: its DUT-only summary is Line
72.86%, Condition 73.98%, FSM 28.79%, and Branch 86.23%; its state_r FSM is
19/55 after the six named tests. Do not combine these percentages because the
compile-time profiles have different active logic.

Across the two profiles, `ST_A_REQ->ST_PREP_MAC` and `ST_MAC->ST_A_REQ` are
observed in the Prefetch-OFF product GEMV tests. The following three transition
pairs remain unhit and have no waiver or formal unreachable proof:

| Unhit transition | Source-level reason under review | Disposition |
|---|---|---|
| `ST_ERROR->ST_ERROR_DRAIN` | The abort/watchdog override explicitly excludes `ST_ERROR`; the `ST_ERROR` case returns to `ST_IDLE`. Request/response fault overrides are not expected to coexist with this state after drain. | OPEN pending formal/invariant proof |
| `ST_IDLE->ST_ERROR_DRAIN` | `ST_IDLE` is not busy; a start advances to `ST_A_REQ`, while read faults are generated by active read/prefetch requests. | OPEN pending formal/invariant proof |
| `ST_PREFETCH_WAIT->ST_A_REQ` | The transition is guarded by `!ENABLE_NEXT_K_PREFETCH`; the same disabled configuration takes `ST_MAC->ST_A_REQ` without entering `ST_PREFETCH_WAIT`. | Source-level structurally unreachable across the two legal profiles; no waiver approved pending formal confirmation |

No functional `covergroup`/`coverpoint` is declared in this Matrix testbench;
the scenario markers are directed checker evidence. Code coverage is merged
within each build profile, but 100% functional coverage, full line/condition
coverage, and full cross coverage are **not** established. The archives are
outside Git: `/tmp/nmaforge_v2_core_fault_coverage_871b752.tar.gz` (SHA-256
`f3aeb84e635112b669028bf007f89c4e87d073b7b8eb1e71792beec8ee389de4`),
`/tmp/nmaforge_v2_noprefetch_coverage_871b752.tar.gz` (SHA-256
`93206f0594d4fd6536d1a8ce9861d60d440c35f203be3e3c68a48e820f24d395`), and
Top Smoke logs `/tmp/nmaforge_v2_top_smoke_871b752.tar.gz` (SHA-256
`8bdbf261dfd53fd194a7282dddea32ee3cefa2ed6455b11a030e2ac69aab22c8`). Top
Smoke returned 0 with `TEST PASS` and the `0x52` tail/`0x53` CMDQ forwarding
markers; VCS emitted the existing `LOOP-REROLL-ENABLED` fixture notice.

## Fixed-SHA v2 RTL checker-sensitivity campaign — 2026-11-05

At test SHA `a015de58379ca1303ebfc1c4c3899d1fd77affa2`, a runner mutated
temporary copies of `ai_tensor_matrix_core.v`; checked-in product RTL was not
modified. VCS `V-2023.12-SP1_Full64` compiled each mutant once and ran the
corresponding functional checker on Seeds 20261105/06/07:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim product-opcode-mutation-regress \
  V2_OPCODE_MUTATION_OUT=/tmp/nmaforge_v2_opcode_mutations_a015de5 \
  PYTHON=python3.12
```

The run caught all 15/15 mutant-seed checks: output data and output address
corruption were caught by the independent producer memory-image Golden;
operand response-owner corruption by the opcode 0x52 completion/GEMV checker;
partial WSTRB by the Line protocol checker; and a wrong 0x53 tile tag by the
forwarding read-count checker. No compile warnings or errors were found in
mutant compile logs. Logs and the result summary are archived at
`/tmp/nmaforge_v2_opcode_mutations_a015de5_logs.tar.gz` (SHA-256
`9e7ae868d1746d54aaf209fa445562fd48cba8ec078cbd68ff2721660231e5b6`). Run ID:
`V2-OPCODE-MUTATION-5X3-A015DE5`.

This is a checker-sensitivity result for five selected RTL fault classes. It
does not test Completion mutation, external engine-owner mutation, every
fault-phase cross, or imply full v2 Mutation Closure.

## Normalized v2 Execution RTM

This RTM assigns stable `REQ-V2-*` identifiers to the implemented v2 contract.
The evidence is scoped to each named shape/testpoint; a `PASS` below does not
mean the whole opcode or v2 subsystem is signed off. “Assertion” identifies a
real SVA/formal property when one exists; otherwise it says `none` rather than
claiming a testbench fatal check is an assertion. Directed marker names are
functional scenario evidence. The URG code coverage results and their limits
are recorded below; there is not yet a functional covergroup database for the
new opcodes.

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
| REQ-V2-052-008: GEMV abort/reset/parity/protection recover without stale writes or lost response ownership | Opcode 0x52 lifecycle plus Matrix faults | `run_v2_opcode_fault_campaign`; checks expected error, accepted/returned response drain, destination sentinels and post-fault Golden | No GEMV-specific SVA; generic Matrix FSM formal only | 0x52 Parity, dense-B Protection, Abort during outstanding prefetch, Reset plus post-reset unowned response; three seeds | `V2-OPCODE-FAULT-3SEED-DE705EE`, seeds 20261105/06/07, SHA `de705ee6317557954af9cb396cda94b01eb1c432` | **PARTIAL**; these directed points pass, but all legal fault phases, external fabric response ownership and full fault-by-reset cross remain open; logs archive above |
| REQ-V2-052-009: supported GEMV path rejects transpose, stride, batch, head, reserved flags and invalid alignment | Opcode 0x52 descriptor legality | Validator directed `check_invalid` and boundary checker | None | unsupported descriptor field rejection | `V2-DESC-VALIDATOR-AC6B83F`, seed N/A, `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` | **PASS (directed validator scope)**; descriptor run log |
| REQ-V2-053-001: fused Matrix postprocess/requant order and packed Matrix-A layout match bit-exact Golden | Opcode 0x53 fused path | Core fused boundary checker; Top producer/consumer independent output-image checker | No opcode-specific SVA | signed requant boundaries and 16×16×16 output image | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, 20261105/06/07, `33e85287fbf37187fccb76e97be6effe888670e9`; Top run SHA `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PASS (tested path)**; [tile metrics CSV](../../benchmark/v2_p2_tile_forward_3seed.csv), core/Top logs and archives |
| REQ-V2-053-002: capture becomes valid only after accepted producer lines and consume uses exact tag or SPAD fallback | 512 B bounded tile-forward buffer | Core capture mask/final-line checker; tag hit and miss Golden/read-count checker | None | full capture mask; exact tag hit; mismatch miss and 32-read fallback | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, 20261105/06/07, `33e85287fbf37187fccb76e97be6effe888670e9`; Top run above | **PASS (tested core path)**; tile CSV and report; Top CMDQ producer/consumer also passes |
| REQ-V2-053-003: consume old bank while capture writes the opposite bank; preserve outputs and flip banks | Ping-pong buffer control | Core chain Golden + bank/tag comparison; Top CMDQ output/completion differential | None | simultaneous consume/capture, old-bank data, opposite-bank flip, 16 source-A reads saved | core run SHA `33e85287fbf37187fccb76e97be6effe888670e9`; Top `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`, seeds 20261105/06/07, `3a283c04724378c46747d907505eb82ea1ccbd4a` | **PASS (16×16 chain)**; tile CSV and Top archive |
| REQ-V2-053-004: producer writeback backpressure cannot outrun capture or alter committed image | Fused line writer and capture handshake | Core `tile_forward_backpressure_seen`, final line and complete memory image checks | None | line stall, all 16 accepted lines, capture mask `ffff` | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, 20261105/06/07, `33e85287fbf37187fccb76e97be6effe888670e9` | **PASS (directed line-ready stall)**; tile report/CSV; arbitrary held-response timing remains untested |
| REQ-V2-053-005: Abort/reset invalidate tile tag and prevent prior-epoch reuse | Local tile validity epoch | Core abort/reset probes; 0x53 consumer reset with accepted delayed B response, injected stale post-reset response, tag/count/write checks | No epoch-specific SVA | 0x53 tag invalidation/fallback; stale response after reset; three seeds | `V2-OPCODE-FAULT-3SEED-DE705EE`, seeds 20261105/06/07, SHA `de705ee6317557954af9cb396cda94b01eb1c432`; older 0x52 late-response run `59d1e5e` | **PARTIAL**; the selected 0x53 reset interleave now passes with sentinel preservation and post-reset recovery; other legal phase crosses and external-fabric ownership remain open; log archive above |
| REQ-V2-053-006: parity/protection/held response/Completion faults preserve 0x53 error and memory contract | Fused path fault lifecycle | `run_v2_opcode_fault_campaign`; read Parity, output-write Protection, held output-line Abort, reset-epoch stale response, sentinels and successful tile-chain recovery | No 0x53-specific SVA | Parity, Protection, held write under backpressure and Abort, selected Reset epoch; three seeds | `V2-OPCODE-FAULT-3SEED-DE705EE`, seeds 20261105/06/07, SHA `de705ee6317557954af9cb396cda94b01eb1c432` | **PARTIAL**; selected fault points pass; Completion fault injection, broader held-response/Reset crosses and URG disposition remain open; log archive above |
| REQ-V2-053-007: software-held source immutability and cross-engine SPAD access obey the forwarding contract | Explicitly ordered local handoff, no coherence | Contract reviewed; no cross-engine checker | None | source mutation/DMA or other-engine write during handoff NOT_RUN | `NOT_RUN@f4ed9c4`, seed N/A, candidate `f4ed9c4f5b711bd6554d588477957e9bf3ce3806` | **NOT_RUN**; spec requires source immutability, but there is no coherent cache or test evidence |
| REQ-V2-COM-003: new-feature assertions are connected and non-vacuous | Matrix FSM and top SVA | VC Formal proves existing Matrix guard set; Top SVA is AXI/quiescence scoped | Formal: 5/5 named Matrix assertions non-vacuous and 2/2 covers reached at `145363ddff5141177421ee7429fc65f78834830d`; no opcode-specific 0x52/0x53 assertion | `prefetch_wait`, `error_drain` covers; no v2 opcode transition cross | `V2-MATRIX-FSM-GUARDS-145363D`, formal run, SHA `145363ddff5141177421ee7429fc65f78834830d` | **PARTIAL**; this does not prove new opcode properties or full SVA connection coverage; `/tmp/nmaforge_v2_matrix_fsm_formal_33e8528/vc_formal.log` |
| REQ-V2-COM-004: all legal v2 functional bins are merged and every exclusion/waiver has disposition | URG functional/code coverage | VCS URG merge for three Seeds of Matrix core+GEMV+fault suite; separate Prefetch-OFF profile | No functional covergroup or coverage assertion | Prefetch-ON code URG: 93.76/90.67/92.42/96.50% Line/Condition/FSM/Branch; FSM 15/15 states, 50/55 transitions. Prefetch-OFF profile separate; three transition pairs remain unhit and undispositioned | `V2-DUT-COVERAGE-9TEST-DE705EE`, seeds 20261105/06/07, source/test SHA `de705ee6317557954af9cb396cda94b01eb1c432`; report replay at docs-only HEAD `871b752`; archive SHA above | **PARTIAL**; code coverage merged per legal compile profile, but functional coverage groups are absent, line/condition/FSM/branch are below 100%, three FSM transitions lack formal disposition, and no exclusions/waivers are approved |
| REQ-V2-COM-005: each new checker detects its assigned RTL fault through mutation | 0x52/0x53 Matrix datapath and forwarding checks | Temporary DUT mutants for output data, output address, operand response owner, WSTRB, and tile tag; each checker must emit its assigned fatal | No mutation-specific SVA | Five fault classes × three Seeds = 15/15 caught; Completion and external response-owner mutants remain open | `V2-OPCODE-MUTATION-5X3-A015DE5`, seeds 20261105/06/07, SHA `a015de58379ca1303ebfc1c4c3899d1fd77affa2` | **PARTIAL**; five selected mutants are caught, but Completion and engine-level owner mutations plus any additional new checker remain untested; external log archive above |

### Fixed run identities and reproducibility

- `V2-DESC-VALIDATOR-AC6B83F`: VCS `V-2023.12-SP1_Full64`; seed is not applicable because the test is directed. The run used `VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH VCS="/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10" make -C dv/block/control/sim descriptor-validator-regress DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_v2_descriptor_validator_ac6b83f`; compile/run logs are under `/tmp/nmaforge_v2_descriptor_validator_ac6b83f/`.
- `V2-GEMV-CORE-3SEED-18DAD2B`: VCS `V-2023.12-SP1_Full64`; Seeds 20261105/06/07; logs-only archive SHA-256 `4fd0ba313b484a2da588562ff62411b2951ca089bb703a74e49fed7f2bc506c1`.
- `V2-GEMV-FOUR-WAY-S20261105-K19-B0-P0` family: VCS `V-2023.12-SP1_Full64`, four-bank registered behavioral SPAD with seed-controlled Ready/latency; Seeds 20261105/06/07, 48/48 bit-exact Cache × Prefetch × shape × seed points.
- `V2-TILE-FORWARD-CORE-3SEED-33E8528`: VCS `V-2023.12-SP1_Full64`; 6/6 OFF/ON runs across Seeds 20261105/06/07; output images bit-exact. Raw CSV is checked in; raw simulator logs are in the referenced `/tmp` archive described in the tile replay report.
- `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`: VCS `V-2023.12-SP1_Full64`; clean detached worktree, `make ai_comp` then `make ai_run AI_RANDOM_CASES=4 AI_SEED=<seed> SEED=<seed>` for Seeds 20261105/06/07; logs-only archive SHA-256 `8e1bc2c3329de0ac11eedafed3972918baecf321c01b09990195662d691e35f6`.
- `V2-DUT-COVERAGE-9TEST-DE705EE`: VCS/URG `V-2023.12-SP1_Full64`; source/test files match `de705ee`, replay recorded at docs-only HEAD `871b752`; Seeds 20261105/06/07; default Prefetch-ON archive SHA-256 `f3aeb84e635112b669028bf007f89c4e87d073b7b8eb1e71792beec8ee389de4`.
- `V2-DUT-COVERAGE-6TEST-NP-871B752`: VCS/URG `V-2023.12-SP1_Full64`; supported Prefetch-OFF profile, Seeds 20261105/06/07; archive SHA-256 `93206f0594d4fd6536d1a8ce9861d60d440c35f203be3e3c68a48e820f24d395`.
- `V2-TOP-SMOKE-871B752`: VCS `V-2023.12-SP1_Full64`, `AI_RANDOM_CASES=4`, seed `20261105`, `TEST PASS`; archive SHA-256 `8bdbf261dfd53fd194a7282dddea32ee3cefa2ed6455b11a030e2ac69aab22c8`.
- `V2-MATRIX-FSM-GUARDS-145363D`: VC Formal `V-2023.12-SP2`; 5/5 named Matrix FSM assertions proven/non-vacuous and 2/2 state covers reached. It is not an opcode 0x52/0x53 assertion campaign.

The RTM currently has 21 requirement IDs: 12 scoped PASS, 8 PARTIAL, and 1
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
2. Extend the fixed-SHA `0x52`/`0x53` fault campaign to the remaining legal
   phase crosses, response holds, request backpressure, and completion-fault
   semantics; the selected 0x53 reset-epoch stale-response interleave now
   passes at `de705ee`.
3. Define and test tile-source immutability under cross-engine SPAD traffic;
   test repeated consume and producer/consumer interleavings.
4. Add functional covergroups for the directed `0x52`/`0x53` testpoints; review
   the merged code-coverage gaps and three residual FSM transitions; prove or
   formally disposition them without invalid stimulus. Audit assertion
   connectivity/non-vacuity and extend mutation to Completion and external
   engine-owner/checker faults.
5. Complete old-opcode compatibility regression beyond the selected Top
   Smoke and Matrix-core test points.
6. Run formal/LEC, CDC/RDC, DC, SRAM mapping, DFT preparation, and PPA only
   with the appropriate tool, constraints, libraries, and licenses. These
   results remain `NOT_RUN` or `BLOCKED_ENV` as applicable.

The v1.0 Compute Cluster remains **HOLD**; no system-wide or ASIC sign-off is
implied by the scoped v2 evidence above.
