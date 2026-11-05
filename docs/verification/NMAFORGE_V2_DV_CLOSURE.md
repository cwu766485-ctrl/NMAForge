# NMAForge v2 DV Closure Status

**Status:** IN PROGRESS — scoped regressions pass; v2 sign-off is not ready.  
**Latest fixed RTL/test candidate SHA:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7`

**Candidate tree:** `e608e788cf5cc49165d835003c87920259cc84b4`

**Latest fault replay:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7` (tree `e608e788cf5cc49165d835003c87920259cc84b4`), including 0x53 Reset/Epoch, Parity, Protection, and held-write Abort scenarios.
**Latest RTL-mutation replay:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7`; 15/15 opcode-core mutant-seed checks caught.
**Latest scoped cross-engine replay:** `86e0d6cbba3187bd1deeb18f664c559b606c878d` (tree `497eaef649c3995c97cb533a9c410417d63ee0de`); Top Smoke adds a scoped functional coverage group, with no product RTL change.
**Latest actual DUT mutation replay:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7`; seven temporary RTL mutants were caught by their assigned real Compute Cluster UVM checkers.
**Latest in-repository fabric reset replay:** `f340acaa2cdf7c36075473b8bc6fd6dee8e59873` (tree `7fc556427be1597e64a602c10af4fdd855a0c343`); three seeds pass selected `ai_accel_memory_fabric` reset/epoch and DMA/CNM recovery checks.

**Baseline:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`

## Exact-candidate replay at `410b81d` — 2026-11-05

This fixed candidate was tested in the isolated worktree before this
report-only follow-up. No product RTL changed during these runs. The combined
run archive is `/tmp/nmaforge_v2_current_410b81_signoff_logs.tar.gz`, SHA-256
`c9f88930f24c3ca74140ba48e06d91f3fdbd0d37585fff0f9dac3ded15404ce5`.
VCS/URG was `V-2023.12-SP1_Full64`.

| Run ID | Command / evidence | Result and scope |
|---|---|---|
| `V2-GEMV-FAULT-CLEAN-410B81D-3SEED` | `make -C dv/block/compute/matrix/sim product-gemv-regress product-opcode-fault-regress`; output `/tmp/nmaforge_v2_current_410b81_matrix_core` | Seeds 20261105/06/07 pass GEMV Golden and tail cases plus 0x52 Parity/Protection/Abort/Reset and 0x53 reset-epoch stale-response, Parity, output Protection, held-write Abort, and post-fault tile-chain recovery. |
| `V2-TOP-SMOKE-410B81D` | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105` | `TEST PASS`; 0x52 CMDQ output cases, 0x53 forwarding producer/consumer, legal Matrix+SFU disjoint-region overlap and Golden pass. VCS emitted the existing `LOOP-REROLL-ENABLED` fixture debug-capacity notice. |
| `V2-DUT-URG-410B81D-3SEED` | `make ai_compute_cluster_cov AI_CLUSTER_COV_SEEDS='20261105 20261106 20261107'` | Top DUT-only URG: Line/Condition/FSM/Branch `86.75/77.62/44.33/84.56%`; Matrix core `88.34/78.32/51.52/84.95%`. Named v2 Matrix+SFU functional group `100%`; aggregate functional groups `20%` because four AXI responder groups were not sampled. This is not v2 functional closure. |
| `V2-CLUSTER-UVM-410B81D-3SEED` | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | All three real-top runs pass. Each checks 92,871 memory words, zero mismatch/unknown/stale/orphan; accepted/returned/reset-dropped response-owner ledger `5015/4995/20`, pending `0`; UVM Warning/Error/Fatal `0/0/0`. All seven engine pairs observed `21/21`; merged UVM URG Line/Condition/FSM/Branch/Assert/Group `69.65/62.71/45.62/58.03/72.00/79.18%`. This is generic Cluster scope, not opcode-specific v2 closure. |
| `V2-OPCODE-MUTATION-410B81D-5X3` | `make -C dv/block/compute/matrix/sim product-opcode-mutation-regress V2_OPCODE_MUTATION_SEEDS='20261105 20261106 20261107'` | 15/15 real temporary RTL mutant-seed checks caught: output data/address, operand response owner, WSTRB, and tile tag. |
| `V2-CLUSTER-DUT-MUTATION-410B81D-7X1` | `make -C dv/uvm/sim uvm_compute_cluster_dut_mutation SEED=20261025` | 7/7 real DUT mutants caught: SPAD address/data/response owner, Matrix WSTRB, Completion error code, Missing Done, Duplicate Done. |

The exact `REQ-V2-*` evidence delta is:

| Requirement rows | Current SHA evidence added | Disposition |
|---|---|---|
| `REQ-V2-052-003/004/006/008` | Three-seed GEMV and fault core replay; signed INT8/INT32 Golden, M/N/K tails, Cache/Prefetch behavior, selected fault recovery | Remain scoped PASS or PARTIAL as listed in the RTM; broader legal shapes, fault-phase crosses and shared external response ownership remain open. |
| `REQ-V2-053-001/002/005/006` | Top CMDQ producer/consumer replay plus three-seed tag, ping-pong, Reset/Epoch, Parity, Protection and held-write recovery | Remain scoped PASS/PARTIAL; arbitrary held-response timing, Completion fault injection and all cross-engine contracts remain open. |
| `REQ-V2-COM-004` | Current 3-seed Top URG with one v2 functional group | **PARTIAL**; 100% applies only to the named Matrix+SFU handoff group; overall functional group score is 20%. |
| `REQ-V2-COM-005` | Current 15/15 opcode mutations and 7/7 Cluster DUT mutations | **PARTIAL**; these are selected mutations, not exhaustive checker-to-fault mapping for every new feature. |
| `REQ-V2-COM-006` | In-repository `ai_accel_memory_fabric` coordinated reset with DMA reads outstanding and CNM accepted SPAD response / pending result write; owner flush and fresh DMA/CNM recovery | **PASS (selected repository-fabric scope)**; three reset functional groups are 100%, and owner/tag SVAs have real successes. This does not establish behavior for arbitrary external SoC fabrics or close opcode-specific fault/reset crosses. |

The UVM run has three top AXI stall assertions with 660,281 attempts each:
`c_ar_stall_then_accept` and `c_aw_stall_then_accept` have zero matches,
while `c_w_stall_then_accept` has one. These remain unexercised assertion
checks for this run and require targeted traffic or a documented scope
disposition. No assertion success is inferred from the overall UVM PASS.

Exact command environment included
`VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias`, `VCS_ARCH_OVERRIDE=linux`,
and `PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH`. Top URG report is
`/tmp/nmaforge_v2_current_410b81_top_cov/top_only_urg/dashboard.txt`; Cluster
URG report is
`/tmp/nmaforge_v2_current_410b81_cluster_uvm/urg_merged/dashboard.txt`.
This adds current-candidate evidence, but full v2 DV remains **IN PROGRESS**.

The exact invocation set was:

```sh
make -C dv/block/compute/matrix/sim \
  product-gemv-regress product-opcode-fault-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_current_410b81_matrix_core \
  SEEDS='20261105 20261106 20261107'

make -C dv/subsystem/top_smoke/sim ai_smoke \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105

make -C dv/subsystem/top_smoke/sim ai_compute_cluster_cov \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg AI_RANDOM_CASES=4 \
  AI_CLUSTER_COV_RUN=/tmp/nmaforge_v2_current_410b81_top_cov \
  AI_CLUSTER_COV_SEEDS='20261105 20261106 20261107'

make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_current_410b81_cluster_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/block/compute/matrix/sim product-opcode-mutation-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' PYTHON=python3.12 \
  V2_OPCODE_MUTATION_OUT=/tmp/nmaforge_v2_current_410b81_opcode_mutation \
  V2_OPCODE_MUTATION_SEEDS='20261105 20261106 20261107'

make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_v2_current_410b81_dut_mutation \
  SEED=20261025
```

Each command used `VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias`,
`VCS_ARCH_OVERRIDE=linux`, and
`PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH`. The direct GEMV
four-way and Digits commands are recorded in the
[performance](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md) and
[model](../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md) reports respectively.

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
| REQ-V2-053-007: software-held source immutability and cross-engine SPAD access obey the forwarding contract | Explicitly ordered local handoff, no coherence | Top monitor watches seven compute write clients and Matrix line writes; CMDQ Matrix consumer + independent SFU output-image checker | No new SVA | Matrix 0x53 consume overlaps SFU SPAD traffic to a disjoint range; functional bins cover Matrix/SFU overlap, accepted consume-period traffic, no source write attempt, and Golden success (100% in this scoped group) | `V2-0X53-CROSS-ENGINE-COV-3SEED-86E0D6C`, seeds 20261105/06/07, SHA `86e0d6cbba3187bd1deeb18f664c559b606c878d` | **PARTIAL**; legal Matrix+SFU unrelated-region concurrency and its scoped functional group pass 3/3 seeds. This does not test DMA overwrite, illegal source mutation injection, every other-engine pairing, or full response-owner/error crosses; software must keep the tagged source immutable |
| REQ-V2-COM-003: new-feature assertions are connected and non-vacuous | Matrix FSM and top SVA | VC Formal proves existing Matrix guard set; Top SVA is AXI/quiescence scoped | Formal: 5/5 named Matrix assertions non-vacuous and 2/2 covers reached at `145363ddff5141177421ee7429fc65f78834830d`; no opcode-specific 0x52/0x53 assertion | `prefetch_wait`, `error_drain` covers; no v2 opcode transition cross | `V2-MATRIX-FSM-GUARDS-145363D`, formal run, SHA `145363ddff5141177421ee7429fc65f78834830d` | **PARTIAL**; this does not prove new opcode properties or full SVA connection coverage; `/tmp/nmaforge_v2_matrix_fsm_formal_33e8528/vc_formal.log` |
| REQ-V2-COM-004: all legal v2 functional bins are merged and every exclusion/waiver has disposition | URG functional/code coverage | VCS URG merge for current Top Smoke DUT-only scope (27 module definitions) across three Seeds; earlier Matrix core/GEMV/fault and Prefetch-OFF runs remain separately identified | One v2-specific functional group samples the legal 0x53 cross-engine handoff; no new SVA | Current Top URG: 86.75/77.62/44.33/84.56% Line/Condition/FSM/Branch; Matrix FSM 15/15 states, 25/55 transitions. New 0x53 group 100%; overall functional group score 20% because four existing AXI-memory groups score 0%. Remaining 0x52/0x53 bins and FSM transitions have no approved disposition | `V2-DUT-COVERAGE-TOP-3SEED-86E0D6C`, seeds 20261105/06/07, source/test SHA `86e0d6cbba3187bd1deeb18f664c559b606c878d`; archive SHA below | **PARTIAL**; only the legal Matrix+SFU handoff group is complete. Broader feature bins, exclusions/waivers, and remaining FSM transition reachability are not closed; aggregate percentages do not establish sign-off |
| REQ-V2-COM-005: each new checker detects its assigned RTL fault through mutation | 0x52/0x53 Matrix datapath/forwarding and shared Compute Cluster lifecycle | Actual temporary DUT mutants for shared-SPAD address/data/response owner, Matrix WSTRB, Completion error code, missing Done, and duplicate Done; separate opcode-core mutants for output data/address, operand response owner, WSTRB, and tile tag | Mutation-specific SVA: none; each injected defect must trigger its assigned scoreboard/checker | Current-candidate actual-DUT campaign: 7/7 mutation classes caught at seed 20261025; opcode-core campaign: 5 classes × 3 seeds = 15/15 caught | `V2-DUT-MUTATION-7X1-BDFDA3C`, seed 20261025, SHA `bdfda3c408a1367ac6b1788ebb9bdb0e5b6f7d47`; `V2-OPCODE-MUTATION-5X3-A015DE5`, seeds 20261105/06/07, SHA `a015de58379ca1303ebfc1c4c3899d1fd77affa2` | **PARTIAL**; these selected RTL faults are detected, including Completion and shared response owner. Exhaustive mutation-to-checker mapping for every new feature/checker and the full fault-phase cross remain open; see both external logs archives |
| REQ-V2-COM-006: coordinated reset flushes in-repository shared-fabric owners and allows clean DMA/CNM recovery | `ai_accel_memory_fabric`, DMA and banked CNM shared reset/epoch lifecycle | `subsystem_memory_fabric_reset_regress`; DMA memory scoreboard plus `MEMORY_FABRIC_RESET_ONLY_PASS` and `DMA_CNM_RESET_RECOVERY_PASS` checks. It exercises four DMA reads outstanding while CNM has an accepted SPAD read without its response, and a second phase with CNM awaiting result write | URG records `ap_single_response_owner` (3,921 real successes) and `ap_cnm_response_tag` (144 real successes); both have zero failures/incomplete. These are exercised owner/tag properties, not a universal external-fabric epoch proof | `dma_cnm_shared_reset_cg`, `dma_reset_phase_cg`, and `cnm_reset_phase_cg` each 100.00% in the merged report. Whole-report functional group score is only 23.98%; other subsystem groups are outside this scenario | `V2-MEMORY-FABRIC-RESET-3SEED-F340ACA`, seeds 20261025/26/27, source SHA `f340acaa2cdf7c36075473b8bc6fd6dee8e59873`, tree `7fc556427be1597e64a602c10af4fdd855a0c343` | **PASS (selected in-repository fabric scope)**; all three seeds report zero UVM Warning/Error/Fatal and post-reset DMA/CNM Golden recovery. Does not close 0x52/0x53-specific reset-phase crosses or arbitrary external fabric behavior; logs/URG archive and checksum below |

### Fixed run identities and reproducibility

- `V2-DESC-VALIDATOR-AC6B83F`: VCS `V-2023.12-SP1_Full64`; seed is not applicable because the test is directed. The run used `VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH VCS="/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10" make -C dv/block/control/sim descriptor-validator-regress DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_v2_descriptor_validator_ac6b83f`; compile/run logs are under `/tmp/nmaforge_v2_descriptor_validator_ac6b83f/`.
- `V2-GEMV-CORE-3SEED-18DAD2B`: VCS `V-2023.12-SP1_Full64`; Seeds 20261105/06/07; logs-only archive SHA-256 `4fd0ba313b484a2da588562ff62411b2951ca089bb703a74e49fed7f2bc506c1`.
- `V2-GEMV-FOUR-WAY-S20261105-K19-B0-P0` family: VCS `V-2023.12-SP1_Full64`, four-bank registered behavioral SPAD with seed-controlled Ready/latency; Seeds 20261105/06/07, 48/48 bit-exact Cache × Prefetch × shape × seed points.
- `V2-TILE-FORWARD-CORE-3SEED-33E8528`: VCS `V-2023.12-SP1_Full64`; 6/6 OFF/ON runs across Seeds 20261105/06/07; output images bit-exact. Raw CSV is checked in; raw simulator logs are in the referenced `/tmp` archive described in the tile replay report.
- `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`: VCS `V-2023.12-SP1_Full64`; clean detached worktree, `make ai_comp` then `make ai_run AI_RANDOM_CASES=4 AI_SEED=<seed> SEED=<seed>` for Seeds 20261105/06/07; logs-only archive SHA-256 `8e1bc2c3329de0ac11eedafed3972918baecf321c01b09990195662d691e35f6`.
- `V2-DUT-COVERAGE-9TEST-DE705EE`: VCS/URG `V-2023.12-SP1_Full64`; source/test files match `de705ee`, replay recorded at docs-only HEAD `871b752`; Seeds 20261105/06/07; default Prefetch-ON archive SHA-256 `f3aeb84e635112b669028bf007f89c4e87d073b7b8eb1e71792beec8ee389de4`.
- `V2-DUT-COVERAGE-6TEST-NP-871B752`: VCS/URG `V-2023.12-SP1_Full64`; supported Prefetch-OFF profile, Seeds 20261105/06/07; archive SHA-256 `93206f0594d4fd6536d1a8ce9861d60d440c35f203be3e3c68a48e820f24d395`.
- `V2-TOP-SMOKE-871B752`: VCS `V-2023.12-SP1_Full64`, `AI_RANDOM_CASES=4`, seed `20261105`, `TEST PASS`; archive SHA-256 `8bdbf261dfd53fd194a7282dddea32ee3cefa2ed6455b11a030e2ac69aab22c8`.
- `V2-0X53-CROSS-ENGINE-IMMUTABLE-3SEED-0870A76`: VCS `V-2023.12-SP1_Full64`; `make ai_comp` followed by `./simv +ntb_random_seed=<seed> +AI_RANDOM_CASES=4 +AI_SEED=<seed> +ACLK_PERIOD_NS=10.0` for seeds 20261105/06/07. All three logs report full `TEST PASS`, Matrix/SFU busy overlap, 23 accepted SFU SPAD accesses while Matrix consumes the tagged tile, no compute-client source write attempt, unchanged 64-word source image, and bit-exact Matrix/SFU output images and completions. Logs-only archive `/tmp/nmaforge_v2_cross_engine_three_seed_final_0870a76_logs.tar.gz`, SHA-256 `fb2f2d70128fc919a4d767b11c1257024760a3e9b5019a68b44286cef78662c2`. Testbench checks seven compute SPAD request clients and Matrix line writes; it does not monitor DMA traffic in this scenario and adds no coverage database.
- `V2-DUT-COVERAGE-TOP-3SEED-0870A76`: VCS/URG `V-2023.12-SP1_Full64`, exact test source SHA `0870a76b803ad01b8c23d812cfddd9cbb399f74e`; `make ai_compute_cluster_cov AI_CLUSTER_COV_RUN=/tmp/nmaforge_v2_0870a76_dut_cov AI_CLUSTER_COV_SEEDS='20261105 20261106 20261107' AI_RANDOM_CASES=4`. All 3 seeded runs emit `TEST PASS` and the cross-engine Golden marker. DUT-only Top Smoke URG reports 86.75% Line, 77.62% Condition, 44.33% FSM, 84.56% Branch; Matrix core FSM is 15/15 states and 25/55 transitions. The four existing AXI-memory testbench groups are 0%; no v2 functional covergroups were added. Evidence archive `/tmp/nmaforge_v2_0870a76_dut_cov_evidence.tar.gz`, SHA-256 `691b2e6b5b896a5ec1638796939899ba751a43f1611edc6386dd550bddc052f0`; includes VDB, URG reports, compile/run logs.
- `V2-DUT-COVERAGE-TOP-3SEED-86E0D6C`: VCS/URG `V-2023.12-SP1_Full64`, source SHA `86e0d6cbba3187bd1deeb18f664c559b606c878d`; command above, Seeds 20261105/06/07. The cross-engine group checks overlap, accepted consume-period SPAD access, no source write attempt, bit-exact Golden and a pair cross; it scores 100% in each run and merged. DUT-only code coverage is 86.75/77.62/44.33/84.56% Line/Condition/FSM/Branch, Matrix FSM 15/15 states and 25/55 transitions. Overall functional group score is 20% because the four existing AXI-memory groups score 0%; the new group covers only this legal 0x53 scenario. Evidence `/tmp/nmaforge_v2_86e0d6c_dut_cov_evidence.tar.gz`, SHA-256 `eb25d2725fa8e3252c0140d0c7254c3abfc03fd1ef44d1ecbd2283e75becd4f8`; includes VDB, URG reports, compile/run logs.
- `V2-MEMORY-FABRIC-RESET-3SEED-F340ACA`: VCS/URG `V-2023.12-SP1_Full64`; source/test SHA `f340acaa2cdf7c36075473b8bc6fd6dee8e59873`, tree `7fc556427be1597e64a602c10af4fdd855a0c343`; command `make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress` with `MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'`, VCS `-licwait 10`, and output `/tmp/nmaforge_v2_fabric_reset_f340aca`. All three seeds report `MEMORY_FABRIC_RESET_ONLY_PASS`, two `DMA_CNM_RESET_RECOVERY_PASS` events, and UVM Warning/Error/Fatal `0/0/0`. Three named reset groups score 100.00% in merged URG. Assertion summary is 13/31 with real successes, 0 failures, 0 incomplete, and two no-attempt UVM RAL properties; `ap_single_response_owner` and `ap_cnm_response_tag` have real successes. Logs-only archive `/tmp/nmaforge_v2_fabric_reset_f340aca_logs.tar.gz`, SHA-256 `14144bdc62932d8040a1b5be72b27f83e6f4f8e52286a8658b1570fdfe3717c5`. VCS databases and simulator binaries are excluded. Scope is the in-repository fabric and this reset interleave only.
- `V2-MATRIX-FSM-GUARDS-145363D`: VC Formal `V-2023.12-SP2`; 5/5 named Matrix FSM assertions proven/non-vacuous and 2/2 state covers reached. It is not an opcode 0x52/0x53 assertion campaign.

Exact replay commands for the latest fixed test candidate `86e0d6c` (run from
the repository root):

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  make -C dv/subsystem/top_smoke/sim ai_smoke \
    AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  make -C dv/subsystem/top_smoke/sim ai_compute_cluster_cov \
    AI_CLUSTER_COV_RUN=/tmp/nmaforge_v2_86e0d6c_dut_cov \
    AI_CLUSTER_COV_SEEDS='20261105 20261106 20261107' AI_RANDOM_CASES=4
```

The repository-fabric reset replay used:

```sh
export VCS_ARCH_OVERRIDE=linux \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH
make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027' \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_v2_fabric_reset_f340aca
```

The RTM currently has 22 requirement IDs: 13 scoped PASS, 9 PARTIAL, and 0
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
   current 22-row RTM is normalized but still contains PARTIAL rows.
2. Extend the fixed-SHA `0x52`/`0x53` fault campaign to the remaining legal
   phase crosses, response holds, request backpressure, and completion-fault
   semantics. The current `410b81d` replay covers selected Reset/Epoch stale
   response, Parity, Protection, and held-write Abort cases; it is not the full
   Engine × Fault × Phase × Reset matrix.
3. Define and test tile-source immutability under cross-engine SPAD traffic;
   test repeated consume and producer/consumer interleavings.
4. Add functional covergroups for the directed `0x52`/`0x53` testpoints; review
   the merged code-coverage gaps and three residual FSM transitions; prove or
   formally disposition them without invalid stimulus. Audit assertion
   connectivity/non-vacuity and map mutations to every new-feature checker.
5. Complete old-opcode compatibility regression beyond the selected Top
   Smoke and Matrix-core test points.
6. Run formal/LEC, CDC/RDC, DC, SRAM mapping, DFT preparation, and PPA only
   with the appropriate tool, constraints, libraries, and licenses. These
   results remain `NOT_RUN` or `BLOCKED_ENV` as applicable.

The v1.0 Compute Cluster remains **HOLD**; no system-wide or ASIC sign-off is
implied by the scoped v2 evidence above.

## Actual DUT mutation replay at `bdfda3c` — 2026-11-05

The real-DUT harness builds each mutant from a temporary source copy and runs
the Compute Cluster UVM sequence. The product source and file list in the
worktree are not modified. All seven selected RTL defects were rejected by
their intended checker:

| Mutant | Checker observed |
|---|---|
| Shared SPAD address offset | `CLUSTER_MEMORY_UNKNOWN` |
| Shared SPAD write-data bit flip | `CLUSTER_GOLDEN` |
| Shared SPAD response routed to wrong engine | `CLUSTER_ENGINE_RESPONSE_OWNER` |
| Matrix WSTRB bit dropped | `CLUSTER_MATRIX_WSTRB` |
| Completion error code corrupted | `CLUSTER_COMPLETION_ERROR_CODE` |
| Scalar engine Done suppressed | `CLUSTER_MISSING_DONE` |
| Scalar Done duplicated onto KV engine | `CLUSTER_DONE_WITHOUT_ACTIVE` |

Run command (VCS `V-2023.12-SP1_Full64`, seed 20261025):

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_v2_dut_mutation_bdfda3c
```

Result: `COMPUTE_CLUSTER_DUT_MUTATION_PASS: 7/7 real RTL mutants caught`.
Run ID `V2-DUT-MUTATION-7X1-BDFDA3C`; source SHA
`bdfda3c408a1367ac6b1788ebb9bdb0e5b6f7d47`, tree
`89eac43b0b9aa6811608f6587272ec564ea2b456`. Logs-only archive:
`/tmp/nmaforge_v2_dut_mutation_bdfda3c_logs.tar.gz`, SHA-256
`a4104e43f95243d75525bab9023f75d7d6831a3fe75eec2333efb7b21d87e95b`.
This is checker-sensitivity evidence for seven selected fault classes. It does
not close every v2 checker, fault-phase cross, functional coverage item, or
the v2 sign-off.
