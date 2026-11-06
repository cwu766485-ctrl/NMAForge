# NMAForge v2 DV Closure Status

## Scope change — 2026-11-06

Full DV closure is paused for this work round by explicit project direction.
The active target is the fixed TinyNPU performance baseline plus static SPAD
capacity analysis. No new coverage, mutation, formal, or UVM scope is being
opened. Existing fixed-SHA evidence is reused only for the minimum functional
check: clean Top smoke/completion, scoped INT8 GEMM and opcode `0x52`, the
scoped `0x53` fused path, exact trained Digits MLP output, and exact
`conv1x_mini` intermediate/output checks. The new seven-point TinyNPU matrix
also passes its independent INT32 Golden checks.

This is **not a v2 DV sign-off**. Existing PARTIAL / NOT_RUN / BLOCKED items,
coverage exclusions, SVA scope limits, and formal gaps remain unchanged. The
target branch's pre-existing uncommitted UVM fairness assertion edit is
preserved and was not included in these benchmark records.

**Status:** FULL CLOSURE PAUSED — scoped functional evidence exists; v2 sign-off is not ready.
**Latest clean Top/UVM/opcode replay candidate:** `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree `630e498ba467d84dd5359403cfe1ed1e5879f6e9`; Top smoke, three-seed Cluster UVM, focused 0x52/0x53 tests, and selected mutation checks). Product RTL is unchanged. Earlier broader coverage merges and other workload results remain bound to their own listed SHAs.
**Latest three-seed 20-random-workload compatibility replay:** testbench/tooling SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5`; directed smoke plus three 20-random-workload seeds pass legacy/v2 markers. The later clean `f9f32f7` Top Smoke replay is a shorter four-random-workload check and is not a UVM/URG coverage update.

**Earlier generic Cluster replay tree:** `65d56c5d6dd345effde6fdfdf70dad59f135a279`

**Latest 0x52/0x53 shape/fault/handshake replay:** clean test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; three seeds pass six GEMV shapes, eight selected fault-recovery bins, two handshake bins, and six tile-forward feature bins per run.
**Latest actual RTL-mutation replay:** clean test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; 21/21 mutant-seed checks caught across seven mutation classes and three seeds.
**Latest Matrix FSM formal replay:** `99566993256778d094c068a8733c074ade2f9921`; 5/5 assertions proved non-vacuous and 2/2 state covers reached. Latest 0x52-specific request formal replay: `b719ac6066616b17dfab4eed2429f8bdfdc49457`; 1/1 request stability property proven non-vacuous and 1/1 hold/release cover reached.
**Latest scoped cross-engine replay:** `86e0d6cbba3187bd1deeb18f664c559b606c878d` (tree `497eaef649c3995c97cb533a9c410417d63ee0de`); Top Smoke adds a scoped functional coverage group, with no product RTL change.
**Latest actual DUT mutation replay:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7`; seven temporary RTL mutants were caught by their assigned real Compute Cluster UVM checkers.
**Latest in-repository fabric reset replay:** clean candidate `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree `630e498ba467d84dd5359403cfe1ed1e5879f6e9`); three seeds pass selected `ai_accel_memory_fabric` reset/epoch and DMA/CNM recovery checks. This is bounded in-repository evidence, not arbitrary external-fabric qualification.
**Latest request/backpressure replay:** clean test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; three seeds pass named GEMV request-stall and fused output-write stall checks, and the address-hold checker catches its corresponding RTL mutation.
**Latest merged UVM coverage:** clean source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`; 3 Cluster seeds plus 16 mixed AXI/DMA E2E seeds merge without URG warnings. All 36 declared functional groups are 100%, with AR/AW/W stall-to-accept cover properties all matched. Code coverage, two no-attempt UVM RAL assertions, and requirement closure remain incomplete. See the clean-candidate 2026-11-06 entry below and [run record](../../benchmark/v2_clean_urg_19test_839b9af.json).

## 2026-11-06 — clean-candidate verification replay at `839b9af`

The detached clean worktree at source/test SHA
`839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` passes the Top `ai_smoke`, the
three-seed `uvm_compute_cluster_regress`, and the focused Matrix-core 0x52/0x53
shape, selected-fault, handshake, tile-forwarding, and mutation gates. The
three Cluster Seeds have UVM Warning/Error/Fatal `0/0/0`; Matrix profile state
partitions close exactly in all nine sampled profiles. The focused run catches
21/21 selected temporary RTL mutants across seven classes and three Seeds.

The merged three-Seed Cluster URG remains incomplete: Line/Condition/FSM/Branch/
Assertion/Functional-Group is `70.74/68.33/46.17/67.70/72.00/83.94%`; 17/22
assertions have successes, five are uncovered, two were not attempted, and
only one of three cover properties matches. The 22-row v2 RTM remains 14
PASS-scoped / 8 PARTIAL. These replay results establish candidate
reproducibility for the sampled paths, not complete v2 DV closure or v1.0
sign-off.

Run records with exact commands and tool versions:
[Top smoke](../../benchmark/v2_top_smoke_clean_839b9af.json),
[Cluster UVM/URG](../../benchmark/v2_clean_cluster_uvm_839b9af.json), and
[opcode/fault/mutation](../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json).
The benchmark at the same candidate is recorded separately in the
[performance report](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).

**Baseline:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`

## 2026-11-06 — real-CMDQ GEMV read-only A/B alias

The ABI-v7 validator rejects destination overlap with either operand, but it
does not prohibit the two read-only operand ranges from overlapping. Added a
real Top CMDQ `0x52` case with `srcA == srcB` and disjoint destination. The
test checks all 256 source bytes remain unchanged, all 16 signed INT32 outputs
against an independent Golden, two output guards, the completion record, and
accepted/returned Matrix reads. Each seed observes 17/17 reads and hits the
focused alias bin; merged URG confirms 3 hits and 100% for that declared bin.

VCS `V-2023.12-SP1_Full64` passes the complete three-seed Compute Cluster UVM
regression at clean detached SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5`
(tree `2d931c1c81997b482467d7fdf69302dd367975a1`). Seeds
`20261106/20261107/20261108` each pass with UVM Warning/Error/Fatal `0/0/0`.
Merged whole-test profile is Line/Condition/FSM/Branch/Assert/Group
`70.71/68.37/46.17/67.66/72.00/83.94%`; this is not v2 coverage closure.
The test makes no claim about software modifying shared operands while a
command is in flight. Product RTL remains unchanged at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

Run ID: `V2-CMDQ-GEMV-AB-ALIAS-3SEED-F19E929`. Machine-readable record:
[JSON](../../benchmark/v2_cmdq_gemv_ab_alias_f19e929.json). Logs and selected
URG text (simulator binary/VDB excluded):
`/tmp/nmaforge_v2_gemv_ab_alias_f19e929_logs.tar.gz`, SHA-256
`18e664689077d9608924af2b9ec08eb912d4979edc9e0cf36b816cbe936447ae`.

Exact replay command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_gemv_alias_f19e929 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261106 20261107 20261108'
```

## 2026-11-06 — real-CMDQ GEMV K=256 test-bound point

Testbench-only SHA `8758794c1f3bd6abb41c33276422b84ac5ee7a80` adds a `1×1×256`
opcode-0x52 descriptor to isolate the K=256 test-bound point while retaining
the existing 2,000-cycle Top task watchdog. The earlier `16×16×256` probe
exceeded that watchdog and produced no completion or Golden evidence; the
watchdog was not changed. This run makes no claim that the maximum M/N workload
at K=256 passed.

VCS `V-2023.12-SP1_Full64` passes three seeds `20261025/26/27` from clean
detached worktree `/tmp/nmaforge-v2-max-k-clean-8758794`. Each seed checks the
real CMDQ launch fields, one signed INT32 output against independent Golden,
two untouched output sentinels, ordered completion, and all 272/272 accepted /
returned Matrix reads. UVM Warning/Error/Fatal is `0/0/0` per seed. Merged URG
Line/Condition/FSM/Branch/Assert/Group is
`70.71/68.34/46.17/67.66/72.00/83.46%`; this is the full profile total, not
v2 closure. The evidence archive is
`/tmp/nmaforge_v2_k256_evidence_8758794.tar.gz`, SHA-256
`3ceac93b551949ad49a698309460fe0f978b5a7a71be74ec3f873727e17268b9`.

Exact command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_max_k_clean_8758794 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

## 2026-11-06 — real-CMDQ long-K GEMV at K=128

Testbench-only commit `e944133b43107839e5f5eea902251097a228b312` adds a
real opcode-0x52 `16×16×128` case. It checks all 256 signed INT32 outputs
against an independent Golden, two output guards, launch fields, ordered
completion, and 448/448 accepted/returned Matrix operand lines. The dedicated
`cmdq_product_gemv_long_k_cg` has one declared bin and scores 1/1 on each
Seed; merged URG records three hits and 100%.

VCS/URG `V-2023.12-SP1_Full64` passes the complete Compute Cluster UVM suite
from detached clean worktree `/tmp/nmaforge-v2-clean-e944133` on Seeds
`20261025/26/27`. Each seed has UVM Warning/Error/Fatal `0/0/0`. Aggregate
Line/Condition/FSM/Branch/Assert/Group is
`70.71/68.34/46.17/67.66/72.00/83.46%`; this does not close global v2
coverage. Product RTL is unchanged.

Run ID: `V2-CMDQ-GEMV-K128-3SEED-E944133`. Exact command:

```sh
git worktree add --detach /tmp/nmaforge-v2-clean-e944133 \
  e944133b43107839e5f5eea902251097a228b312
make -C /tmp/nmaforge-v2-clean-e944133/dv/uvm/sim \
  uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_long_k_clean_e944133 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Logs and selected URG text (simulator binary/VDB excluded):
`/tmp/nmaforge_v2_long_k_e944133_logs.tar.gz`, SHA-256
`167fb42c261c861d0bace89aefd6ef40695b5b5f01e85ac2c7e5b3b76b2f19b3`.

The earlier `16×16×256` real-CMDQ attempt at test SHA
`170ab5b585be819b1a72a22c7ea29be1881cfa21` hit the existing Top SVA
`MAX_TASK_CYCLES=2000` completion bound before producing a Golden result.
The bound was not relaxed. This is a timeout against the testbench bound, not
proof of a datapath mismatch; the larger M/N workload remains open. A separate
`1×1×256` K=256 test-bound point subsequently passed; see the clean replay below.
No product RTL changed.

## 2026-11-06 — real-CMDQ GEMV M/N/K alignment-tail cross

Testbench-only commit `0e9f12ec3701030c9e5978ad29b227c5e0c644a7` adds a
declared eight-bin coverage group for the M%4, N%16, and K%16 aligned/tail
states and four legal real-Top CMDQ GEMV cases to hit previously missing
combinations: `4×16×17`, `4×13×16`, `3×16×16`, and `3×13×16`. Existing
real-CMDQ cases supply the other four combinations. Each new case checks every
signed INT32 result against an independent Golden, two untouched output
guards, descriptor launch fields, completion payload/order, and equality of
accepted/returned Matrix reads. The added cases compare 203 output words and
83 operand-line responses per Seed.

VCS `V-2023.12-SP1_Full64` passed the complete real-Top Compute Cluster UVM
regression from detached clean worktree `/tmp/nmaforge-v2-clean-0e9f12e` on
Seeds `20261025/26/27`. The tail-cross group is 8/8 (100%) in every Seed and
in merged URG; each run has UVM Warning/Error/Fatal `0/0/0`. Merged
Line/Condition/FSM/Branch/Assert/Group coverage is
`70.71/68.34/46.17/67.66/72.00/82.96%`; this is the full profile total, not
v2 closure. No product RTL changed.

Run ID: `V2-CMDQ-GEMV-TAIL-CROSS-3SEED-0E9F12E`. Exact command:

```sh
git worktree add --detach /tmp/nmaforge-v2-clean-0e9f12e \
  0e9f12ec3701030c9e5978ad29b227c5e0c644a7
make -C /tmp/nmaforge-v2-clean-0e9f12e/dv/uvm/sim \
  uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_tail_cross_clean_0e9f12e \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Logs and selected URG text (simulator binary/VDB excluded):
`/tmp/nmaforge_v2_tail_cross_0e9f12e_logs.tar.gz`, SHA-256
`37c1faa781c24744236a32b51f23ec08ec2616da2a9866b9d63554c34aeb6a14`.
`REQ-V2-052-003/004` now have a real-Top representative for each alignment
tail state; full size/precision/postprocess combinations, alias/fault crosses,
and external held/late response ownership remain open. `REQ-V2-052-007`
remains PARTIAL.

## 2026-11-06 — real CMDQ rejection for 0x52 aliases/alignment/range

The real-top `ai_compute_cluster_e2e_test` now sends four malformed ABI-v7
GEMV descriptors through CMDQ fetch, decode, validation, and completion:
destination overlap with padded A, destination overlap with dense B, a
16-byte-misaligned source, and a padded-A span that actually crosses the
32-bit address-space limit. Each must retire `ERR_DESC`, leave both
destination sentinel words untouched, and generate no engine or DMA request.
The test also retains eight pre-existing invalid engine/macro descriptors.

An initial attempt at source/test SHA `0e4e02dd15545e9ea490965b47514d16730f1ae8`
used K=1 at source `0xfffffff0`; its 16-byte half-open span ends exactly at
`2^32`, which is legal under the validator's wrap rule. One request was
therefore observed. The test input, not RTL or the checker, was corrected to
K=17 (32-byte padded-A span) in commit
`c26064e3dda40ce26490c5c93b3e741529946c58`; the checker remains unchanged.

At fixed source/test SHA `c26064e3dda40ce26490c5c93b3e741529946c58` (tree
`1cd67e6dc3b21867a1180521bfe022464e213a75`), VCS and URG
`V-2023.12-SP1_Full64` passed three independent Seeds. Each seed reports
`cases=12/12`, `ERR_DESC=12`, no engine launch, zero compute/DMA-request cycles,
24/24 sentinel/guard comparisons, 12/12 focused functional bins, and UVM
warning/error/fatal counts `0/0/0`. The merged `cmdq_invalid_descriptor_cg`
is 100%. Aggregate URG remains Line/Condition/FSM/Branch/Assert/Group
`69.65/63.34/45.62/58.03/72.00/79.18%`; this is not full v2 coverage closure.

Run ID: `V2-CMDQ-GEMV-DESC-REJECT-3SEED-C26064E`. Exact command:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_gemv_cmdq_reject_c26064e \
  COMPUTE_CLUSTER_UVM_SEEDS='20261109 20261110 20261111'
```

Logs-only archive (simulation binaries and coverage databases excluded):
`/tmp/nmaforge_v2_cmdq_reject_c26064e_logs_v2.tar.gz`, SHA-256
`87bfc434c78426ccfade5cc2b583f5ea56a19d66b9366c7939e515b435142029`.
`REQ-V2-052-001`, `REQ-V2-052-002`, and `REQ-V2-052-009` gain real CMDQ
rejection evidence for these cases. Output overlap/wrap and alignment are
proven rejected before dispatch on the tested top path; broad legal shape
execution, fault × phase × reset crosses, and external-fabric response
ownership remain open. No product RTL changed; v2 DV remains **IN PROGRESS**.

## 2026-11-06 — legal opcode 0x52 through real Top CMDQ

Testbench commits `c3b6b4a2967edc17e8229151210132959b351f9b`,
`fc8f6db640d131b6fb6eeaf7db8c1a76fd0d6281`, and
`fd82e7323bbf73c428f1a1e72d784220f2440cd0` add a legal ABI-v7 3×5×5 GEMV
descriptor to the real Top CMDQ path, improve failure diagnostics, and teach
the passive UVM launch monitor that opcodes `0x52`/`0x53` belong to Matrix.
An initial run completed the task successfully but exposed the monitor's
missing opcode mapping; no DUT/RTL defect was found. Product RTL remains at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

At fixed source/test SHA `fd82e7323bbf73c428f1a1e72d784220f2440cd0` (tree
`780545809ed04b88fe97bd708dd67e54ef4a88ce`), VCS and URG
`V-2023.12-SP1_Full64` passed Seeds 20261112/13/14. Every seed launches
opcode `0x52` through CMDQ, checks all 15 signed INT32 outputs against an
independent Golden, preserves two output guards, verifies task completion,
and observes 8/8 Matrix accepted/returned reads. The named M/N/K-tail
functional group is 100% (3/3 bins and its cross). Each complete Top UVM seed
has zero Warning/Error/Fatal. The merged profile totals
Line/Condition/FSM/Branch/Assert/Group `70.12/67.96/45.62/67.30/72.00/79.92%`;
those are broad profile totals, not v2 sign-off closure.

Run ID: `V2-CMDQ-PRODUCT-GEMV-GOLDEN-3SEED-FD82E73`. Exact command:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_product_gemv_3seed_fd82e73 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261112 20261113 20261114'
```

Logs-only archive (no simulator or coverage databases):
`/tmp/nmaforge_v2_product_gemv_fd82e73_logs.tar.gz`, SHA-256
`bb8c975cacb5b48cebb2ef6cd6b802842d9654e21b095c6107141ceda6e24f5e`.
This advances `REQ-V2-COM-001`, `REQ-V2-052-003`, `REQ-V2-052-004`, and the
single-command accepted/returned portion of `REQ-V2-052-007`. It does not
close those broader requirements: maximum descriptor shapes, exhaustive
tail/alias/fault combinations, held external responses, multi-engine
0x52 response ownership, and complete error/reset crosses remain open.

## 2026-11-06 — minimum 0x52 GEMV descriptor through real Top CMDQ

Testbench-only commit `95301c46dfa6b9ee68f1e37a38f7767e3111d869` adds a
separate ABI-v7 1×1×1 GEMV command after the 3×5×5 tail test. Each 16-byte
operand line is initialized so the Top Memory Scoreboard has a complete known
image. Product RTL is unchanged.

At fixed source/test SHA `95301c46dfa6b9ee68f1e37a38f7767e3111d869` (tree
`abbb19e1c8205e3d8252e5685fd6ab6161970c3d`), VCS/URG
`V-2023.12-SP1_Full64` passed three complete real-Top Cluster UVM Seeds
20261115/16/17. Each case matches its independent signed INT32 Golden
(−2/−6/−12), preserves the adjacent sentinel, checks completion, and observes
2 accepted and 2 returned operand-line reads before retirement. The named
`cmdq_product_gemv_min_cg` is 100% (1/1 bin, three hits). The merged profile is
Line/Condition/FSM/Branch/Assert/Group
`70.12/67.95/45.62/67.30/72.00/80.61%`; aggregate coverage is not closure.
Every Seed has UVM Warning/Error/Fatal `0/0/0` and no
`CLUSTER_MEMORY_UNKNOWN` reports.

Run ID: `V2-CMDQ-PRODUCT-GEMV-MIN-BOUNDARY-3SEED-95301C4`. Exact fixed-SHA
command:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_product_gemv_min_3seed_95301c4 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261115 20261116 20261117'
```

Logs and URG text only (no simulator binaries or coverage databases):
`/tmp/nmaforge_v2_product_gemv_min_95301c4_logs.tar.gz`, SHA-256
`4d5b56b411b3c62a9d39a7da3f9c0f3f765612ce82baafe8eab6180970314ed6`.
`REQ-V2-COM-001` and `REQ-V2-052-003/004` gain minimum-shape evidence;
At this minimum-boundary SHA, `REQ-V2-052-007` remained PARTIAL because no
concurrent multi-engine 0x52 response-owner cross had yet been added. That
cross was added and replayed at `85e7db2`; exhaustive legal tails, fault ×
phase × reset crosses, and external-fabric responses remain open.

## 2026-11-06 — maximum 0x52 GEMV tile through real Top CMDQ

Testbench-only commit `92874788fb2cb2a2b15657a3621e5a275a9d5990` (tree
`8ddbc13844b9bb2f262c88c471dd60a4e3bbd428`) adds ABI-v7 M=N=K=16 GEMV via
the production Top CMDQ, Matrix dispatcher, banked SPAD, and completion path.
The test initializes the complete padded A/B physical lines, computes an
independent signed INT32 matrix-product Golden, checks all 256 outputs and two
guards, verifies completion result/element count, and compares accepted versus
returned Matrix reads. No product RTL changed.

At this fixed SHA, VCS/URG `V-2023.12-SP1_Full64` passed three Seeds
20261118/19/20. Each reports 32 accepted and 32 returned operand lines, all
256 bit-exact outputs, intact guards, and one successful completion. The
maximum-tile, minimum-shape, and M/N/K-tail functional groups each merge to
100%. The complete Top UVM run reports Warning/Error/Fatal `0/0/0` per Seed;
merged Line/Condition/FSM/Branch/Assert/Group is
`70.69/68.28/45.99/67.59/72.00/81.26%`, so the overall v2 coverage campaign
remains open.

Run ID: `V2-CMDQ-PRODUCT-GEMV-FULL-TILE-3SEED-9287478`. Exact fixed-SHA
clean-worktree command:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_product_gemv_fulltile_3seed_9287478 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261118 20261119 20261120'
```

The command ran in detached clean worktree `/tmp/nmaforge-v2-clean-9287478`.
Logs and URG text archive (no simulator executable or coverage database):
`/tmp/nmaforge_v2_product_gemv_fulltile_9287478_logs.tar.gz`, SHA-256
`b4249983a366d34e6e1e54f08c98d99e501ed234526c2fc7862a48f842e1a05d`.
`REQ-V2-COM-001` and `REQ-V2-052-003/004` gain this tested maximum tile point;
this does not establish all legal shapes, all tail combinations, arbitrary
runtime aliasing, or the complete fault × phase × reset matrix. Product RTL remains at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

## 2026-11-06 — concurrent real-CMDQ 0x52 GEMV + CNM response ownership

Testbench-only commit `85e7db2d12f5edfaed17e8ca3910bb504983779f` (tree
`e8f64f78f7986193bdc0d01dfbc01740a130edcb`) submits a maximum 16×16×16
opcode-0x52 GEMV and a legal CNM GEMV together through the real CMDQ and
four-bank behavioral SPAD, using disjoint operand/output ranges. Independent
Golden checks cover 256 Matrix outputs, two Matrix guards, all 16 CNM outputs,
and both ordered completion entries. The monitor checks accepted/returned
Matrix and CNM reads and requires Matrix/CNM route-mismatch counters to remain
unchanged.

Three independent Seeds `20261121/22/23` pass. Per seed, the UVM log reports
32/32 Matrix reads, CNM accepted/returned read accounting 4096/4096, 1024
CNM-tagged responses, zero route mismatches, and 178 cycles with both engines
busy. Eighteen cycles have simultaneous Matrix/CNM requests; the observed
grant counts are Matrix/CNM `0/18`. This run establishes legal concurrent
request traffic and response ownership for this pairing, not arbiter fairness.
The dedicated overlap/contention covergroup and cross are 100% in merged URG.
The full merged regression coverage is Line/Condition/FSM/Branch/Assert/Group
`70.69/68.25/45.99/67.59/72.00/81.86%`; it is not global v2 coverage closure.
The run reports zero UVM Warning/Error/Fatal per seed.

Run ID: `V2-CMDQ-GEMV-CNM-OWNER-CROSS-3SEED-85E7DB2`. It ran against fixed
SHA `85e7db2d12f5edfaed17e8ca3910bb504983779f` in detached clean worktree
`/tmp/nmaforge-v2-clean-85e7db2`; exact command:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_gemv_cnm_owner_clean_85e7db2 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261121 20261122 20261123'
```

VCS was `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`. Text logs and URG reports
only (no simulator binary or coverage database) are archived at
`/tmp/nmaforge_v2_gemv_cnm_owner_85e7db2_logs.tar.gz`, SHA-256
`f04f15c1dc76d64a027fc9bd296b02c40e771bf9d6b06f315dc48598637924b0`.
`REQ-V2-052-007` now has the previously missing concurrent 0x52/CNM owner
evidence, but remains **PARTIAL**: arbitrary held/late external responses,
fault/reset interleavings and all legal engine pairings are not closed.
Product RTL is unchanged. The UVM log gate was corrected from literal `100%%`
to `100%` after the simulator had passed but the post-run grep incorrectly
reported failure; the clean-SHA rerun passes the corrected gate.

## Current Compute Cluster UVM replay at `2999e03` — 2026-11-06

The latest fixed v2 tree was compiled and run with three independent seeds.
The current UVM sources and product RTL were unchanged for this replay; the
tree also contains the separately recorded Top Smoke contention testbench and
benchmark evidence. This is a real-top simulation using the behavioral
four-bank SPAD, not ASIC timing or sign-off coverage.

| Run ID | Command / evidence | Result and scope |
|---|---|---|
| `V2-CLUSTER-UVM-3SEED-2999E03` | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_phase1_uvm_c93d020 COMPUTE_CLUSTER_UVM_SEEDS='20261106 20261107 20261108'` | Three seeds pass. Each reaches all 21 observed engine-pair overlap bins; checks 18 Parity and 19 Protection cases, plus 72/72 legal engine/operand/phase Protection × Reset recovery points. The Memory scoreboard checks 92,871 words with zero mismatch, unknown, or stale-epoch reads; response ownership reports accepted/checked/reset-dropped `5015/4995/20`, zero route/data/error mismatch, and zero pending responses. UVM Warning/Error/Fatal is `0/0/0` per seed. |

The seed logs also show ordered Completion Queue backpressure/release, independent
Matrix/CNM response tags, Abort suppression, all-engine Reset recovery, and
post-fault Golden recovery. The line-write scoreboard observed 1,589 full
strobe writes and no partial or zero-strobe writes; this run does **not** close
the partial-WSTRB contract. Descriptor boundaries and opcode-specific 0x52/0x53
alias, overlap, tag, and held-response contracts remain separately scoped in
the RTM.

URG merged the three tests. The focused Compute Cluster covergroup reports
100.0% for its applicable bins and the observed pairwise-overlap group is
21/21. The aggregate report is lower: Line/Condition/FSM/Branch
`69.65/62.74/45.62/58.03%`, Group `79.18%`, and Assert `17/22` real successes
with zero failures or incomplete attempts. Five assertions are uncovered
(three top AXI properties without a success and two UVM RAL properties with no
attempts); two of three AXI stall-to-accept cover properties are also
unmatched. These are explicit open points, not passes inferred from the UVM
test result.

Exact tool versions: VCS and URG `V-2023.12-SP1_Full64`, UVM `1.2`. Logs and
text URG reports, excluding simulator binaries, waveforms, and VDBs, are
archived at `/tmp/nmaforge_v2_phase1_uvm_2999e03_logs.tar.gz`, SHA-256
`1596309ee89d002bf48c2733e2d0844781d61e80c6d1d1bec8ae712563186890`.
`CL-DV-v1.0` remains **HOLD** and v2 DV remains **IN PROGRESS**; this generic
Cluster replay does not replace opcode-specific v2 closure or complete the
RTM.

Exact invocation:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_phase1_uvm_c93d020 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261106 20261107 20261108'
```

## Current descriptor validator replay at `2999e03` — 2026-11-06

The fixed current candidate passes the directed opcode/descriptor validator.
It checks accept/reject rules and address-span overlap/wrap contracts; the
`engine_limit_claim=0` marker explicitly means this does not validate execution
at maximum encoded dimensions.

```text
DESCRIPTOR_VALIDATOR_PASS legal_opcodes=29 tile_pack=1 invalid_rules=33
boundary_accept=43/43 boundary_reject=26/26 tile_forward_accept=3/3
legacy_aux_compat=1 opcode_classes_consistent=1 engine_limit_claim=0
```

VCS is `V-2023.12-SP1_Full64`; compile Warning-/Error- counts are `0/0`.
Exact invocation:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/control/sim descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_v2_descriptor_validator_2999e03
```

Run ID `V2-DESC-VALIDATOR-2999E03`, source/test SHA
`2999e03252c79aed66116b753b64ee7e389b9a56`. Logs-only archive
`/tmp/nmaforge_v2_descriptor_validator_2999e03_logs.tar.gz`, SHA-256
`9fd7a4d1ced7bc62936dcd061ec72e063ea275b33c6d1e27bdbe8d92aa4d5299`.

## Current 0x52/0x53 focused replay at `2999e03` — 2026-11-06

With the VCS license available, the current fixed source/test candidate was
rerun through the dedicated Matrix-core campaigns. No product RTL was changed.
This supplements the generic seven-engine UVM run above; it does not merge all
compile profiles into a global v2 coverage result.

| Run ID | Result |
|---|---|
| `V2-GEMV-3SEED-2999E03` | Seeds 20261106/07/08 pass all six GEMV shape bins with independent bit-exact Golden: M1×13×17, M4×16×32, M8×16×19/65, and M16×16×19/65. The default profile has bounded cache and next-K prefetch enabled. |
| `V2-OPCODE-FAULT-3SEED-2999E03` | All seeds pass the eight declared selected fault bins spanning 0x52 Parity/Protection/Abort/Reset-orphan and 0x53 reset-epoch/Parity/writeback-Protection/held-write-Abort, with post-fault 0x52 Golden and 0x53 tile-chain recovery. |
| `V2-OPCODE-HANDSHAKE-3SEED-2999E03` | All seeds pass the three-cycle 0x52 bank-request stall and held 0x53 output-line payload; both recover to bit-exact outputs. Named handshake coverage is 2/2. |
| `V2-TILE-FORWARD-ONOFF-3SEED-2999E03` | Forwarding OFF and ON runs pass per seed. ON captures all 16 lines, exact-tag consumption saves 16 reads/256 B versus fallback, ping-pong flips bank, tag miss/repeated-consumer fallback, Abort/Reset/stale-tag guard and Golden checks pass. The three forwarding SVAs are attempted with zero failures and the cover matches three times per seed. |

For the default Matrix-core build, URG merges the nine GEMV/fault/handshake
runs and reports all four named groups (`v2_gemv_shape_cg`,
`v2_opcode_fault_cg`, `v2_opcode_handshake_cg`, and `v2_tile_forward_cg`) at
100%. Its code Line/Condition/FSM/Branch coverage is
`86.50/84.08/57.58/93.48%`, so this is not 100% code coverage or complete v2
functional coverage.

The isolated Tile Forwarding OFF/ON ablation uses different compile profiles
and is merged separately. The OFF profile's groups are all unsampled (0%); for
that fallback-only test the tile feature group is N/A because forwarding is
compiled out. This is a local test-scope disposition, not a global exclusion
or waiver. The isolated ON profile has 37.50% aggregate group score: Tile
Forwarding 100%, handshake 50%, and GEMV/fault unsampled. The ON/OFF test proves
the forwarding chain and fallback, but is not a replacement for the default
profile's complete four-group run. These separate results are not pooled.
The 0x52 runtime alias/overlap and maximum-descriptor execution space,
external late-response ownership, and complete fault × phase × reset
interactions remain open.

VCS `V-2023.12-SP1_Full64` exact invocation:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim \
  product-gemv-regress product-opcode-fault-regress \
  product-opcode-handshake-regress core-tile-forward-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  SEEDS='20261106 20261107 20261108' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_phase1_matrix_2999e03 \
  V2_OPCODE_HANDSHAKE_OUT=/tmp/nmaforge_v2_phase1_handshake_2999e03 \
  TILE_FORWARD_REGRESS_OUT=/tmp/nmaforge_v2_phase1_tile_forward_2999e03
```

All six tile-forwarding configuration compile logs have zero `Warning-` and
`Error-` diagnostics. The log-only evidence archive (including all seed logs,
per-configuration assertion reports, manifest, and machine-readable run
summary; excluding binaries, waveforms and VDBs) is
`/tmp/nmaforge_v2_opcode_phase1_2999e03_logs.tar.gz`, SHA-256
`50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a`.
No v2 requirement status is promoted solely by these named-bin results.

## Current Matrix core replay at `9956699` — 2026-11-05

The only source change since the preceding evidence was in the Matrix testbench:
the `8×4×8` valid shape now uses a directed three-cycle bank-response delay
while bank Ready remains randomized. That keeps its existing high-water ≥2
coverage check seed-independent; no checker or product RTL was changed. The
three-seed run initially exposed a seed-sensitive miss at `20261109`, which
reproduced with high-water 1; after this stimulus correction the same case
reaches high-water 2 on all three seeds.

| Run ID | Command / evidence | Result and scope |
|---|---|---|
| `V2-MATRIX-CORE-3SEED-9956699` | `make -C dv/block/compute/matrix/sim core-random-regress ... SEEDS='20261108 20261109 20261110'` | All three seeds pass 18 functional and 35 fault cases, response drain checks, and line contract checks. Seeded Ready/stalls remain active. |
| `V2-GEMV-0X52-3SEED-9956699` | Product GEMV runs invoked by `core-random-regress` | Five shapes per seed pass independent Golden: `4×16×32`, `1×13×17`, `8×16×19`, `16×16×19`, `16×16×65`; includes M/N/K tails, bounded B cache and prefetch counters. |
| `V2-OPCODE-FAULT-3SEED-9956699` | `make -C dv/block/compute/matrix/sim product-opcode-fault-regress ... SEEDS='20261108 20261109 20261110'` | All seeds pass selected 0x52 parity/protection/abort/reset-orphan and 0x53 reset-epoch/stale-response, parity, output protection, held-line Abort and recovery checks. |
| `V2-MATRIX-NOPREFETCH-3SEED-9956699` | `make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress ... SEEDS='20261108 20261109 20261110'` | All seeds pass the fallback plus five size workloads `4×4×32`, `8×8×32`, `16×16×32`, `16×32×32`, `32×32×64`; this profile covers the legal `ST_MAC→ST_A_REQ` transition. |
| `V2-GEMV-NOPREFETCH-3SEED-9956699` | Direct `+MATRIX_PRODUCT_GEMV_ONLY` runs on the Prefetch-OFF build | All seeds pass the same five independent-Golden GEMV shapes; this run reaches `ST_A_REQ→ST_PREP_MAC` in the legal B-cache path. |
| `V2-OPCODE-MUTATION-5X3-9956699` | `make -C dv/block/compute/matrix/sim product-opcode-mutation-regress ... V2_OPCODE_MUTATION_SEEDS='20261108 20261109 20261110'` | 15/15 temporary RTL mutant-seed checks caught across output data, output address, operand response owner, WSTRB, and forwarding tag. |
| `V2-MATRIX-FSM-FORMAL-9956699` | `make -C dv/block/compute/matrix/formal fsm-guards OUT=/tmp/nmaforge_v2_fsm_formal_9956699 VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf` | VC Formal `V-2023.12-SP2`: 5/5 non-vacuous assertions proved, 2/2 covers reached, setup gate PASS. |

Exact invocation set:

```sh
export VCS_ARCH_OVERRIDE=linux
export VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
export PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH

make -C dv/block/compute/matrix/sim core-random-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261108 20261109 20261110' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_core_random_9956699

make -C dv/block/compute/matrix/sim product-opcode-fault-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261108 20261109 20261110' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_core_random_9956699

make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261108 20261109 20261110' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_v2_noprefetch_9956699

for seed in 20261108 20261109 20261110; do
  /tmp/nmaforge_v2_noprefetch_9956699/simv +SEED=$seed +MATRIX_PRODUCT_GEMV_ONLY \
    -cm line+cond+fsm+branch \
    -cm_dir /tmp/nmaforge_v2_noprefetch_9956699/coverage.vdb \
    -cm_name no_prefetch_gemv_$seed \
    -l /tmp/nmaforge_v2_noprefetch_9956699/gemv_product_seed_$seed.log
done

make -C dv/block/compute/matrix/sim product-opcode-mutation-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  V2_OPCODE_MUTATION_OUT=/tmp/nmaforge_v2_opcode_mutations_9956699 \
  V2_OPCODE_MUTATION_SEEDS='20261108 20261109 20261110'

urg -dir /tmp/nmaforge_v2_core_random_9956699/coverage.vdb \
  -dir /tmp/nmaforge_v2_noprefetch_9956699/coverage.vdb \
  -metric line+cond+fsm+branch -format text \
  -report /tmp/nmaforge_v2_core_random_9956699/urg_merged_all_profiles

make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_v2_fsm_formal_9956699 \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

VCS and URG are `V-2023.12-SP1_Full64`. Merged URG covers 15 tests across
Prefetch-ON and Prefetch-OFF core/GEMV/fault profiles. It reports
Line/Condition/FSM/Branch `95.21/90.74/95.45/97.10%`; Matrix FSM has 15/15
states and 52/55 transitions. The remaining three raw transitions are
`ST_ERROR→ST_ERROR_DRAIN`, `ST_IDLE→ST_ERROR_DRAIN`, and
`ST_PREFETCH_WAIT→ST_A_REQ`. Current-SHA formal proves the corresponding
one-step exclusions non-vacuously; the Prefetch-Wait and Error-Drain state
covers are both reached. No bins were waived or forced by illegal state
injection. Other code/feature bins and opcode-specific SVA remain open, so
this is not v2 DV sign-off.

The formal harness uses a constrained legal 4×4 GEMM descriptor and registered
SPAD ownership assumptions. It proves these default-profile control guards,
not opcode-specific 0x52/0x53 lifecycle behavior. VCF reports benign
`search_path`/`link_library` setup-option warnings and a time-unit adjustment;
`check_fv_setup` reports no setup issues.

Exact default-profile commands and merged reports are recorded in evidence
archive `/tmp/nmaforge_v2_dv_9956699_evidence_formal-final.tar.gz`, SHA-256
`0200c8db782fd3a2038ff7ae17053b6b7fd94e16ed6267912a106510d866ad43`.
The archive includes per-seed logs, URG text reports and VDBs, mutation logs
and mutated RTL copies; simulator executables are excluded.

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
| `REQ-V2-052-003/004/006/008` | Three-seed Prefetch-ON and Prefetch-OFF GEMV replay now covers six named shapes with independent bit-exact Golden; 8 selected fault/recovery bins hit across three Seeds | Tested shapes/faults advance; full legal shape space, complete fault × phase × reset crosses and shared external response ownership remain open. |
| `REQ-V2-053-001/002/005/006` | Top CMDQ producer/consumer replay plus three-seed tag, ping-pong, Reset/Epoch, Parity, Protection and held-write recovery | Remain scoped PASS/PARTIAL; arbitrary held-response timing, Completion fault injection and all cross-engine contracts remain open. |
| `REQ-V2-COM-004` | Latest same-source 19-test URG merge at `f9f32f7`: 36/36 declared functional groups at 100%; Line/Condition/FSM/Branch/Assert `74.13/71.59/47.45/71.10/92.00%`; all four AXI responder groups and DMA error-position group are now sampled | **PARTIAL**; declared groups are complete for this plan, but legal v2 scenario inventory, residual code/FSM bins, and requirement-level exclusion/waiver disposition are not closed. |
| `REQ-V2-COM-005` | Current 18/18 opcode mutations (six classes × three Seeds), including request-address hold, and 7/7 Cluster DUT mutations | **PARTIAL**; selected mutations now exercise the request stability checker, but are not exhaustive checker-to-fault mapping for every new feature. |
| `REQ-V2-COM-006` | In-repository `ai_accel_memory_fabric` coordinated reset with DMA reads outstanding and CNM accepted SPAD response / pending result write; owner flush and fresh DMA/CNM recovery | **PASS (selected repository-fabric scope)**; three reset functional groups are 100%, and owner/tag SVAs have real successes. This does not establish behavior for arbitrary external SoC fabrics or close opcode-specific fault/reset crosses. |
| `REQ-V2-COM-002` | Clean Top compatibility replay at current source/test SHA: fixed legacy checks plus 20 randomized workloads per seed, including Tensor GEMM `0x30` and Batch GEMM `0x31` | **PASS (tested legacy modes/shapes)**; three Seeds pass independent Golden comparisons and existing v2 smoke checks. Exhaustive compatibility across every shape, aux combination, and concurrent fault interaction remains outside this run. |

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
functional scenario evidence. The URG code and functional covergroup results
and their limits are recorded below. Current feature groups cover only the
named Matrix-core scenarios and do not substitute for the Top/Cluster RTM.

| Requirement | RTL feature | Test / checker | Assertion | Coverage / disposition point | Run ID, seed, source SHA | Status and evidence path |
|---|---|---|---|---|---|---|
| REQ-V2-COM-001: ABI-v7 routes 0x52/0x53 to the shared Matrix engine | Opcode decode, descriptor validator, dispatcher | `tb_ai_descriptor_validator`; Top CMDQ output/completion checks | No v2-specific SVA | legal opcode classification; actual CMDQ dispatch; 0x52 3×5×5, 1×1×1 and 16×16×16 launch snapshots | `V2-DESC-VALIDATOR-AC6B83F`, `V2-DESC-VALIDATOR-2999E03`; `V2-TOP-CMDQ-CLEAN-3SEED-3A283C0`, 20261105/06/07; `V2-CMDQ-PRODUCT-GEMV-FULL-TILE-3SEED-9287478`, 20261118/19/20, SHA `92874788fb2cb2a2b15657a3621e5a275a9d5990` | **PASS (scoped)**; validator log `/tmp/nmaforge_v2_descriptor_validator_ac6b83f/run.log`; Top archive `/tmp/nmaforge_v2_top_cmdq_clean_3seed_3a283c0_logs.tar.gz`; full test run is archived below |
| REQ-V2-COM-002: v2 additions preserve legacy 0x30/0x31 behavior and aux compatibility | Additive opcode ABI; old Tensor GEMM/Batch GEMM dispatch and legacy writeback | `tb_ai_descriptor_validator`; clean Top Smoke Golden checks for 0x30 4×4 GEMM and 0x31 two-head Batch GEMM; 20 randomized legacy GEMV/GEMM/Conv/Depthwise workloads per seed | No v2-specific compatibility SVA; independent output/completion comparisons are active | Directed 0x30 outputs (7 comparisons) and 0x31 two-head outputs (4 comparisons) per seed; fixed smoke and random Golden comparisons pass | `V2-LEGACY-TOP-COMPAT-3SEED-5F6E282`, seeds 20261108/09/10, source/test SHA `5f6e282f191b421bdbefc3d252690a9a0c93eb1c`, tree `4a5e0a1da1ab7d5a910c6f0a9417304d8a752cb2`; legacy aux compatibility also passes in current `V2-DESC-VALIDATOR-2999E03` | **PASS (tested legacy modes/shapes)**; all seeds report `TEST PASS`, Golden comparisons, and the existing v2 smoke markers. Not exhaustive across all legacy shapes, aux combinations, or fault/concurrency interactions; logs archive below |
| REQ-V2-052-001: accept only the documented dense GEMV descriptor subset and legal boundaries | Opcode 0x52 validator | `tb_ai_descriptor_validator` fatal/count checks; real Top CMDQ invalid-descriptor sequence | None | 43/43 boundary accepts, 26/26 validator rejects; 33 invalid-rule cases; Top invalid descriptor bins 12/12 including four 0x52 rejects; real CMDQ now also executes minimum 1×1×1 and maximum 16×16×16 boundaries | `V2-DESC-VALIDATOR-2999E03`, `V2-CMDQ-GEMV-DESC-REJECT-3SEED-C26064E`, and `V2-CMDQ-PRODUCT-GEMV-FULL-TILE-3SEED-9287478` (20261118/19/20; SHA `92874788fb2cb2a2b15657a3621e5a275a9d5990`) | **PASS (directed validator and tested Top boundary points)**; maximum and minimum endpoint behavior now have execution evidence; intermediate shape space remains open; invalid-descriptor logs/archive SHA-256 `87bfc434c78426ccfade5cc2b583f5ea56a19d66b9366c7939e515b435142029` |
| REQ-V2-052-002: reject output overlap with padded A, dense B, enabled bias, and 32-bit address wrap | Opcode 0x52 span validation | Directed overlap/overflow vectors and `check_invalid`; real Top CMDQ A/B alias and true padded-A wrap rejects | None | adjacent A/output acceptance; A, B, bias overlap rejects; Top A/B aliases and 32-byte source span crossing `2^32` rejected with no compute/DMA requests | `V2-DESC-VALIDATOR-2999E03` plus `V2-CMDQ-GEMV-DESC-REJECT-3SEED-C26064E`, seeds 20261109/10/11, SHA `c26064e3dda40ce26490c5c93b3e741529946c58` | **PASS (directed validator and tested Top cases)**; each seed verifies `ERR_DESC`, sentinel preservation, and no requests; runtime aliasing of externally changing inputs remains a software ownership contract; logs/archive above |
| REQ-V2-052-003: signed INT8 GEMV, optional bias/postprocess and INT32 outputs match independent Golden | Shared 256-MAC Matrix array, opcode 0x52 mapping | `check_dense_gemv_case`; per-element INT32 Golden and complete output checks | No opcode-specific SVA | Six named shapes per Seed, with bit-exact Golden; clean 839 replay also checks six bins over three Seeds | Earlier ON/OFF and ON-only Run IDs above; `V2-OPCODE-CLEAN-839B9AF-3SEED`, seeds 20261128/29/30, SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` | **PASS (six tested shapes/configurations)**; clean logs/summary [JSON](../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json); broader legal shape space remains open |
| REQ-V2-052-004: mask M/N/K tails and never write beyond logical output span | Opcode 0x52 K-fold and scalar-tail output | `check_dense_gemv_tail_case`, `check_dense_gemv_mrows_tail_case`; per-element output and line/scalar-write-count checks | None | M1×13×17; M8×16×19/65; M16×16×19/65; six named shape bins; Prefetch ON/OFF in earlier runs, plus clean 839 three-seed default-ON replay | Earlier ON/OFF Run IDs above; `V2-OPCODE-CLEAN-839B9AF-3SEED`, seeds 20261128/29/30, SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` | **PASS (these six shapes only)**; clean log archive/checker details in [JSON](../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json); full legal M/N/K space remains open |
| REQ-V2-052-005: B-fold cache returns correct values, saves repeated B reads, and bypasses K beyond 64 | Existing bounded local reuse array | Core independent INT32 Golden, cache-hit/read-saved counters, response drain | None | 4 shapes × 4 Cache/Prefetch combinations × 3 Seeds = 48/48 bit-exact points; K65 bypass behavior and exclusive state-cycle closure checked | `V2-GEMV-FOUR-WAY-3SEED-839B9AF`, seeds 20261128/29/30, source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` | **PASS (tested shapes/configs)**; [48-point CSV](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed.csv), [summary JSON](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed_summary.json), [ablation report](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md); other shapes remain open |
| REQ-V2-052-006: bounded next-K prefetch uses an inactive buffer and overlaps legal MAC work | Existing double operand buffers / prefetch controller | Core checks active/inactive buffer, handoff, completed/overlap counters and Golden | Generic Matrix FSM guard only; see COM-003 | Prefetch-ON and compiled-OFF profiles pass six named GEMV shapes; clean four-way suite has 48/48 Golden points, matched state-cycle closure and recorded overlap counters | Earlier ON/OFF Run IDs above; `V2-GEMV-FOUR-WAY-3SEED-839B9AF`, seeds 20261128/29/30, SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` | **PASS (tested profiles)**; machine CSV/JSON linked under REQ-V2-052-005; starvation/fairness under other engines remains open |
| REQ-V2-052-007: count accepted reads, return responses to the correct command, and drain before completion | Matrix response FIFO / outstanding tracker | Single-core responder ledger plus `run_v2_opcode_handshake_campaign`; real Top CMDQ Matrix/CNM owner monitor; request VALID/address stability monitor | No v2 ownership SVA; active TB protocol checker allows cancellation only for Abort, error, or watchdog | Clean 839 three-seed Cluster UVM: real CMDQ 0x52 GEMV + CNM both pass independent Golden/ordered completions; Matrix 32/32 reads, CNM 4096/4096 read ledger, 0 route mismatch, owner bin 100%. Also 3 extended shapes and 8/8 M/N/K alignment-tail states; core request stall/address hold is checked separately | `V2-CLEAN-CLUSTER-UVM-839B9AF-3SEED`, seeds 20261128/29/30, SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`; `V2-OPCODE-CLEAN-839B9AF-3SEED` for core stall; [Cluster JSON](../../benchmark/v2_clean_cluster_uvm_839b9af.json), [opcode JSON](../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json) | **PARTIAL**; this closes the tested concurrent Matrix/CNM pair and named shapes only. Arbitrary held/late external responses, every engine pairing and full fault/reset ownership matrix remain open |
| REQ-V2-052-008: GEMV abort/reset/parity/protection recover without stale writes or lost response ownership | Opcode 0x52 lifecycle plus Matrix faults | `run_v2_opcode_fault_campaign`; expected error, accepted/returned response drain, destination sentinel and post-fault Golden; real-Top Cluster scoreboard for adjacent Matrix/CNM lifecycle crosses | No GEMV-specific SVA; generic Matrix FSM formal only | Clean opcode-core run covers 8/8 selected fault bins across both opcodes per Seed, including 0x52 parity, dense-B Protection, outstanding-prefetch Abort and reset/stale-response checks. Same-SHA Top Cluster run separately passes Matrix/CNM parity-owner, parity-Abort, parity-reset, and protection/reset scenarios with Golden recovery | `V2-OPCODE-CLEAN-839B9AF-3SEED` plus `V2-CLEAN-CLUSTER-UVM-839B9AF-3SEED`, seeds 20261128/29/30, SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`; machine records linked above | **PARTIAL**; the 0x52 fault suite is core-level and Top lifecycle crosses use the Matrix GEMM path. A real-CMDQ 0x52 fault × phase × reset matrix and arbitrary external response ownership remain open; selected logs are in the opcode and Cluster text archives |
| REQ-V2-052-009: supported GEMV path rejects transpose, stride, batch, head, reserved flags and invalid alignment | Opcode 0x52 descriptor legality | Validator directed `check_invalid` and boundary checker; real Top CMDQ misalignment reject | None | unsupported descriptor field rejection; source-base 16-byte alignment also exercised on Top | `V2-DESC-VALIDATOR-2999E03` and `V2-CMDQ-GEMV-DESC-REJECT-3SEED-C26064E`, seeds 20261109/10/11, source/test SHA `c26064e3dda40ce26490c5c93b3e741529946c58` | **PASS (directed validator and tested Top alignment scope)**; each seed checks `ERR_DESC`, no dispatch/request and intact sentinel; archive above |
| REQ-V2-053-001: fused Matrix postprocess/requant order and packed Matrix-A layout match bit-exact Golden | Opcode 0x53 fused path | Core fused boundary checker; Top producer/consumer independent output-image checker | No opcode-specific SVA | Signed requant boundaries and 16×16×16 output image; three-seed repeated-consumer and legacy-SPAD fallback images bit-exact | Core run `V2-TILE-FORWARD-ONOFF-3SEED-2999E03`, seeds 20261106/07/08, SHA `2999e03252c79aed66116b753b64ee7e389b9a56`; earlier Top run `3A283C0` remains its recorded system evidence | **PASS (tested path)**; current logs `/tmp/nmaforge_v2_opcode_phase1_2999e03_logs.tar.gz` (SHA-256 `50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a`) and existing [tile metrics CSV](../../benchmark/v2_p2_tile_forward_3seed.csv) |
| REQ-V2-053-002: capture becomes valid only after accepted producer lines and consume uses exact tag or SPAD fallback | 512 B bounded tile-forward buffer | Core capture mask/final-line and tag hit/miss/repeated-consumer Golden/read-count checkers | Three active SVA: complete capture commits exact destination tag; valid may rise only after complete tagged capture; committed tag stays stable between commits | Full capture; exact hit; mismatch miss; first consume hit then one-shot invalidation; same-tag repeat uses 32-read SPAD fallback; current 3-seed replay also reports 3/3 SVA attempts and zero failures per seed | `V2-TILE-FORWARD-SVA-3SEED-ED17AB1` (seeds 20261123/24/25) and `V2-TILE-FORWARD-ONOFF-3SEED-2999E03` (seeds 20261106/07/08, SHA `2999e03252c79aed66116b753b64ee7e389b9a56`) | **PASS (named core scenarios + runtime SVA)**; assertions 3/3 attempted, 0 failures; cover 3 matches/seed; capture, consumer outputs and fallback remain bit-exact; broader tag/alias combinations remain open |
| REQ-V2-053-003: consume old bank while capture writes the opposite bank; preserve outputs and flip banks | Ping-pong buffer control | Core chain Golden + bank/tag comparison; Top CMDQ output/completion differential | None | Concurrent consume/capture; opposite-bank flip; 16 source-A reads saved; 3-seed Golden | `V2-TILE-FORWARD-ONOFF-3SEED-2999E03`, seeds 20261106/07/08, SHA `2999e03252c79aed66116b753b64ee7e389b9a56`; earlier Top run `3A283C0` | **PASS (16×16 chain)**; first-consumer measurement remains 16 reads/256 B versus 32 reads/512 B without forwarding; current log archive `/tmp/nmaforge_v2_opcode_phase1_2999e03_logs.tar.gz` (SHA-256 `50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a`) and tile CSV |
| REQ-V2-053-004: producer writeback backpressure cannot outrun capture or alter committed image | Fused line writer and capture handshake | `tile_forward_backpressure_seen`, line address/data/WSTRB stability monitor, final-line and complete output-image Golden checks | None | Producer holds a complete output line under `line_ready=0`; all 16 lines are accepted once; capture mask `ffff`; handshake covergroup URG=2/2; ON/OFF Golden remains bit-exact | `V2-OPCODE-HANDSHAKE-3SEED-2999E03` and `V2-TILE-FORWARD-ONOFF-3SEED-2999E03`; seeds 20261106/07/08, SHA `2999e03252c79aed66116b753b64ee7e389b9a56` | **PASS (directed local line-ready stall)**; arbitrary external response hold and system-level Completion backpressure remain open; archive `/tmp/nmaforge_v2_opcode_phase1_2999e03_logs.tar.gz`, SHA-256 `50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a` |
| REQ-V2-053-005: Abort/reset invalidate tile tag and prevent prior-epoch reuse | Local tile validity epoch | Core abort/reset probes; 0x53 consumer reset with accepted delayed B response and injected stale response; sentinel and recovery checkers | No epoch-specific SVA | Reset/Abort tag invalidation bins hit across three Seeds; stale response is discarded | `V2-OPCODE-FAULT-3SEED-2999E03` and `V2-TILE-FORWARD-ONOFF-3SEED-2999E03`, seeds 20261106/07/08, SHA `2999e03252c79aed66116b753b64ee7e389b9a56` | **PARTIAL**; selected interleaves pass; other legal phases and external-fabric ownership remain open; current archive `/tmp/nmaforge_v2_opcode_phase1_2999e03_logs.tar.gz`, SHA-256 `50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a` |
| REQ-V2-053-006: parity/protection/held response/Completion faults preserve 0x53 error and memory contract | Fused path fault lifecycle | `run_v2_opcode_fault_campaign`; Parity, output Protection, held output-line Abort, reset-epoch stale response, sentinels and post-fault tile-chain recovery | No 0x53-specific SVA | Selected Parity, Protection, held-write/Abort, Reset and recovery bins; three Seeds; 8/8 aggregate named opcode fault bins | `V2-OPCODE-FAULT-3SEED-2999E03`, seeds 20261106/07/08, SHA `2999e03252c79aed66116b753b64ee7e389b9a56` | **PARTIAL**; Completion fault injection, broader held-response/reset crosses and all-engine mutation mapping remain open; current archive `/tmp/nmaforge_v2_opcode_phase1_2999e03_logs.tar.gz`, SHA-256 `50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a` |
| REQ-V2-053-007: software-held source immutability and cross-engine SPAD access obey the forwarding contract | Explicitly ordered local handoff, no coherence | Top monitor watches seven compute write clients and Matrix line writes; CMDQ Matrix consumer + independent SFU output-image checker | No new SVA | Matrix 0x53 consume overlaps SFU SPAD traffic to a disjoint range; functional bins cover Matrix/SFU overlap, accepted consume-period traffic, no source write attempt, and Golden success (100% in this scoped group) | `V2-0X53-CROSS-ENGINE-COV-3SEED-86E0D6C`, seeds 20261105/06/07, SHA `86e0d6cbba3187bd1deeb18f664c559b606c878d` | **PARTIAL**; legal Matrix+SFU unrelated-region concurrency and its scoped functional group pass 3/3 seeds. This does not test DMA overwrite, illegal source mutation injection, every other-engine pairing, or full response-owner/error crosses; software must keep the tagged source immutable |
| REQ-V2-COM-003: new-feature assertions are connected and non-vacuous | Matrix FSM guards, 0x52 GEMV bank request hold, and 0x53 forwarding commit/tag contract | VC Formal `run_fsm_guards.tcl` and `run_gemv_request_stability.tcl`; VCS 0x53 forwarding-chain regression | Legacy Matrix guard set: 5/5 formally proven; 0x52 request hold: 1/1 proven non-vacuous; 0x53 capture/tag/valid-rise SVA: 3/3 attempted with 0 failures on all three Seeds | 0x52 hold/release cover reached at depth 4; 0x53 valid-rise cover matched 3 times per Seed and explicit commit counter was nonzero | `V2-MATRIX-FSM-FORMAL-9956699`, `V2-GEMV-REQ-STABILITY-FORMAL-B719AC6`, plus `V2-TILE-FORWARD-SVA-3SEED-ED17AB1` and current `V2-TILE-FORWARD-ONOFF-3SEED-2999E03` (seeds 20261106/07/08, SHA `2999e03252c79aed66116b753b64ee7e389b9a56`) | **PARTIAL**; 0x53 properties are simulation assertions, not a formal proof. Multi-engine ownership, broader error/reset contracts and complete v2 assertion scope remain open; archives `/tmp/nmaforge_v2_tile_rise_sva_ed17ab1_evidence.tar.gz` and `/tmp/nmaforge_v2_opcode_phase1_2999e03_logs.tar.gz`, SHA-256 `50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a` for the current replay |
| REQ-V2-COM-004: all legal v2 functional bins are merged and every exclusion/waiver has disposition | URG functional/code coverage | Same-SHA 3-seed Cluster UVM plus 16-seed mixed AXI/DMA E2E; profiles with different compile parameters remain separate | Active covergroups use in-sequence `get_coverage()` fatal checks; 0x53 SVA reports separately inspected | At `839b9af`: 36/36 declared groups are 100%; Line/Condition/FSM/Branch/Assert is 74.15/71.55/47.45/71.14/92.00%; 20/22 assertions have real successes, two UVM RAL no-attempts, and all 3 top AXI stall covers match. No waiver was added | `V2-CLEAN-CLUSTER-AND-AXI-DMA-URG-19TEST-839B9AF`; 3 Cluster seeds 20261128/29/30 plus 16 mixed-E2E seeds 20261109–24; source SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`; [machine report](../../benchmark/v2_clean_urg_19test_839b9af.json) | **PARTIAL**; all declared groups close for this plan only. Remaining legal scenario inventory, residual code/FSM bins, and requirement-level exclusion/waiver disposition are open; no v2 sign-off implied |
| REQ-V2-COM-005: each new checker detects its assigned RTL fault through mutation | 0x52/0x53 Matrix datapath/forwarding and shared Compute Cluster lifecycle | Actual temporary DUT mutants for shared-SPAD address/data/response owner, Matrix WSTRB, Completion error code, missing Done, and duplicate Done; current opcode-core mutations cover output data/address, operand response owner, WSTRB, tile tag, early valid, and stalled request address | Mutation-specific checker/SVA detects each assigned fault; temporary mutation only, product RTL unchanged | At `839b9af`: seven opcode mutation classes × three Seeds = 21/21 caught; separate shared Cluster campaign 7/7 | `V2-OPCODE-CLEAN-839B9AF-3SEED`, seeds 20261128/29/30, source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`; [machine report](../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json) | **PARTIAL**; selected RTL faults are detected, but exhaustive mutation-to-checker mapping for every new feature/checker and the full fault-phase cross remain open |
| REQ-V2-COM-006: coordinated reset flushes in-repository shared-fabric owners and allows clean DMA/CNM recovery | `ai_accel_memory_fabric`, DMA and banked CNM shared reset/epoch lifecycle | `subsystem_memory_fabric_reset_regress`; DMA memory scoreboard plus `MEMORY_FABRIC_RESET_ONLY_PASS` and `DMA_CNM_RESET_RECOVERY_PASS` checks. It exercises four DMA reads outstanding while CNM has an accepted SPAD read without its response, and a second phase with CNM awaiting result write | URG records `ap_single_response_owner` (3,921 real successes) and `ap_cnm_response_tag` (144 real successes); both have zero failures/incomplete | `dma_cnm_shared_reset_cg`, `dma_reset_phase_cg`, and `cnm_reset_phase_cg` each 100.00% in the focused report | `V2-MEMORY-FABRIC-RESET-CLEAN-839B9AF-3SEED`, seeds 20261128/29/30, source SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`, tree `630e498ba467d84dd5359403cfe1ed1e5879f6e9`; [machine record](../../benchmark/v2_memory_fabric_reset_clean_839b9af_3seed.json) | **PASS (selected in-repository fabric scope)**; all seeds report UVM Warning/Error/Fatal `0/0/0` and post-reset DMA/CNM Golden recovery. Does not close 0x52/0x53-specific reset-phase crosses or arbitrary external fabric behavior; text archive `/tmp/nmaforge_v2_clean_839b9af_memory_fabric_reset_text.tar.gz`, SHA-256 `eff1b22cc9d071d1d02c75ef98c3317944cea11a3a70d0e8bee0bb8397a8abb7` |

### Current clean-candidate RTM evidence delta (`f9f32f7`)

These rows bind this turn's focused replay to the existing requirements. They add
evidence for named points only; the status column preserves the broader open
scope and does not treat these tests as subsystem sign-off.

| Requirement | RTL feature / test / checker | Assertion / coverage result | Run ID, Seed, SHA, evidence path | Disposition |
|---|---|---|---|---|
| REQ-V2-052-003/004 | Opcode `0x52` shared-array GEMV; `product-gemv-regress`; per-element signed INT32 Golden, output guard and write-count checks | Six declared shapes (`4×16×32`, `1×13×17`, `8×16×19/65`, `16×16×19/65`); 6/6 bins per Seed, 18/18 seed-bin observations, bit-exact | `V2-GEMV-SHAPES-3SEED-F9F32F7`; Seeds 20261106/07/08; source SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; [machine evidence](../../benchmark/v2_opcode_f9f32f7_3seed.json), text archive `/tmp/nmaforge_v2_opcode_f9f32f7_logs.tar.gz` SHA-256 `8c016bfa910b36c09a7ad5f398c3cbb025b676f8ded30627755af293bc391ef8` | PASS for these shapes; full supported shape/alias/fault cross remains open |
| REQ-V2-052-005/006 | B-fold cache and bounded next-K prefetch counters in the same GEMV core regressions | K19/K65 bounded reuse and Prefetch-enabled points sampled; independent Golden passes; four-way performance replay separately measures ON/OFF | `V2-GEMV-SHAPES-3SEED-F9F32F7`; Seeds 20261106/07/08; same source SHA; [machine evidence](../../benchmark/v2_opcode_f9f32f7_3seed.json) and [8-configuration replay](../../benchmark/v2_matrix_config_closure_f9f32f7_3seed.csv) | PASS for the tested enabled profile; other contention/fairness conditions remain open |
| REQ-V2-052-007 | Banked request handshake and response ledger; request-stall test checks no accept while blocked, stable request address, completion and Golden recovery | 2/2 named backpressure bins per Seed; accepted/returned ownership checked in the local responder; this is not arbitrary external held/late response coverage | `V2-OPCODE-HANDSHAKE-3SEED-F9F32F7`; Seeds 20261106/07/08; source SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; [machine evidence](../../benchmark/v2_opcode_f9f32f7_3seed.json) | PARTIAL; external fabric response hold, all engine pairings and complete abort/reset ownership matrix remain open |
| REQ-V2-052-008 / REQ-V2-053-005/006 | Opcode fault campaigns: `0x52` Parity/Protection/Abort/reset-orphan; `0x53` Reset/Epoch/Parity/writeback Protection/held-write Abort; sentinel and post-fault Golden checks | 8/8 named fault-recovery bins per Seed (24/24 observations); no cross-product over every phase/fault/reset combination | `V2-OPCODE-FAULT-3SEED-F9F32F7`; Seeds 20261106/07/08; source SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; [machine evidence](../../benchmark/v2_opcode_f9f32f7_3seed.json) | PARTIAL; selected lifecycle points pass; full legal fault × phase × reset crosses remain open |
| REQ-V2-053-002/003/004 | `0x53` bounded tile capture/tag/consume/fallback/bank-flip and held output line; Golden image, capture mask, source read and payload stability checkers | Six declared forwarding bins per Seed; commit/tag runtime assertions observed nonzero activity; 2/2 handshake bins per Seed | `V2-OPCODE-HANDSHAKE-3SEED-F9F32F7` plus `V2-OPCODE-FAULT-3SEED-F9F32F7`; Seeds 20261106/07/08; source SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; [machine evidence](../../benchmark/v2_opcode_f9f32f7_3seed.json) | PASS for selected lifecycle points; broad cross-engine and lifecycle combinations remain open |
| REQ-V2-COM-005 | Seven temporary RTL mutations: output data/address, response operand owner, WSTRB, tile tag, early tile valid, request-address stability | Seven mutation classes × three Seeds = 21/21 assigned checkers detect the fault; no product RTL changed | `V2-OPCODE-MUTATION-7X3-F9F32F7`; Seeds 20261106/07/08; source/test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`; [machine evidence](../../benchmark/v2_opcode_f9f32f7_3seed.json), text evidence archive above | PARTIAL; mutation map is representative, not exhaustive for all checker/fault pairs |

### Fixed run identities and reproducibility

| Requirement | Added test/checker evidence | Coverage | Run identity | Disposition |
|---|---|---|---|---|
| REQ-V2-052-003/004 | Real Top CMDQ GEMV Golden/guards/completion for all M%4 × N%16 × K%16 aligned/tail states; new shapes `4×16×17`, `4×13×16`, `3×16×16`, `3×13×16` complete the four previously unhit states | Dedicated `cmdq_product_gemv_tail_cross_cg`: 8/8 user bins, 100% in each of three Seeds and merged URG; 203/203 new output words and 8/8 guards across three Seeds; accepted/returned lines 25/25, 20/20, 19/19, 19/19 per Seed | `V2-CMDQ-GEMV-TAIL-CROSS-3SEED-0E9F12E`, Seeds 20261025/26/27, SHA `0e9f12ec3701030c9e5978ad29b227c5e0c644a7`, tree `18983dbf8708c101bc83aa9ed0902d6370037468` | PASS for the eight declared alignment/tail states and representative shapes; not exhaustive over legal dimensions, aux/postprocess, aliases or fault/lifecycle crosses; logs/URG archive SHA-256 `37c1faa781c24744236a32b51f23ec08ec2616da2a9866b9d63554c34aeb6a14` |
| REQ-V2-052-003/004 | Real Top CMDQ signed INT8 GEMV at K=128 with independent INT32 Golden, full output image, guards, ordered completion | `cmdq_product_gemv_long_k_cg`: 1/1 bin per Seed and 3 merged hits; 256/256 outputs and two guards per Seed; 448/448 accepted/returned Matrix reads | `V2-CMDQ-GEMV-K128-3SEED-E944133`, Seeds 20261025/26/27, SHA `e944133b43107839e5f5eea902251097a228b312`, tree `430f9ce0c794f6e6a059d56ade7d9112b8a3079f` | PASS for this 16×16×128 point only. Historical `16×16×256` probe hit the unchanged `MAX_TASK_CYCLES=2000` before Golden; the reduced `1×1×256` test-bound point is recorded in the next row. Logs-only archive SHA-256 `167fb42c261c861d0bace89aefd6ef40695b5b5f01e85ac2c7e5b3b76b2f19b3` |
| REQ-V2-052-003/004 | Real Top CMDQ opcode-0x52 K=256 test-bound point; independent signed INT32 Golden, output guards, completion | `cmdq_product_gemv_long_k_cg`: 1/1 per Seed, 3/3 merged; 1/1 result and 2/2 guards per Seed; 272/272 accepted/returned Matrix reads | `V2-CMDQ-GEMV-K256-1X1-3SEED-8758794`, Seeds 20261025/26/27, SHA `8758794c1f3bd6abb41c33276422b84ac5ee7a80`, tree `6f51976ea8f736e08783487afe892afa8a3a8b36` | PASS for the `1×1×256` point only. The `16×16×256` shape remains unverified because it exceeded the unchanged 2,000-cycle Top task watchdog. Evidence archive SHA-256 `3ceac93b551949ad49a698309460fe0f978b5a7a71be74ec3f873727e17268b9` |
| REQ-V2-052-007 | Real CMDQ accepted/returned Matrix reads for the four added aligned/tail representatives, checked before completion | `4×16×17` 25/25, `4×13×16` 20/20, `3×16×16` 19/19, `3×13×16` 19/19 in each of three Seeds; eight-state group merged 100% | `V2-CMDQ-GEMV-TAIL-CROSS-3SEED-0E9F12E`, Seeds 20261025/26/27, SHA `0e9f12ec3701030c9e5978ad29b227c5e0c644a7` | PARTIAL; proves serial Top response drains for these cases; arbitrary held/late external responses and broader multi-engine/fault/reset ownership remain open |
| REQ-V2-052-007 | Real CMDQ 16×16×128 operand-read accepted/returned ownership and drain before completion | 448/448 accepted/returned Matrix reads per Seed; no pending read at completion; dedicated long-K group merged 100% | `V2-CMDQ-GEMV-K128-3SEED-E944133`, Seeds 20261025/26/27, SHA `e944133b43107839e5f5eea902251097a228b312` | PARTIAL; ownership closes for this serial long-K point, while arbitrary held/late external responses and broader multi-engine/fault/reset ownership remain open; archive SHA-256 `167fb42c261c861d0bace89aefd6ef40695b5b5f01e85ac2c7e5b3b76b2f19b3` |
| REQ-V2-052-007 | Real CMDQ K=256 point counts accepted/returned Matrix responses on the shared top path | 272/272 reads accepted/returned per Seed; completion checked and output Golden/sentinels pass | `V2-CMDQ-GEMV-K256-1X1-3SEED-8758794`, Seeds 20261025/26/27, SHA `8758794c1f3bd6abb41c33276422b84ac5ee7a80` | PARTIAL; serial tested ownership point passes. Arbitrary held/late response timing, external fabric ownership and wider multi-engine/fault/reset matrix remain open; archive SHA-256 `3ceac93b551949ad49a698309460fe0f978b5a7a71be74ec3f873727e17268b9` |
| REQ-V2-COM-001 | Real Top CMDQ fetch/decode/dispatch of ABI-v7 opcode `0x52`; passive launch monitor classifies `0x52`/`0x53` as Matrix | 3×5×5 tail, 1×1×1 minimum, and 16×16×16 maximum launch snapshots match descriptor fields | `V2-CMDQ-PRODUCT-GEMV-GOLDEN-3SEED-FD82E73`, `V2-CMDQ-PRODUCT-GEMV-MIN-BOUNDARY-3SEED-95301C4`, and `V2-CMDQ-PRODUCT-GEMV-FULL-TILE-3SEED-9287478` | PASS for these product-CMDQ shape points; broader mode matrix open |
| REQ-V2-052-003/004 | Independent signed INT32 Golden; complete output image and two sentinels; completion status/result/elements checked | 15/15 output elements per Seed; M/N/K tail bins 3/3 plus cross 1/1 | Same run ID/SHA | PASS for legal shape 3×5×5 only; full supported shape domain open |
| REQ-V2-052-003/004 | Independent signed INT32 Golden and complete 16-byte operand line images for minimum descriptor | 1/1 output and guard per Seed; minimum-shape group 1/1 bin, 3 hits; 2/2 operand reads accepted/returned | `V2-CMDQ-PRODUCT-GEMV-MIN-BOUNDARY-3SEED-95301C4`, seeds 20261115/16/17, SHA `95301c46dfa6b9ee68f1e37a38f7767e3111d869` | PASS for M=N=K=1 only; maximum endpoint is covered by the separate row below, while full shape matrix remains open |
| REQ-V2-052-003/004 | Independent signed INT32 Golden for maximum descriptor, complete output image, guards, completion and accepted/returned ownership | 256/256 output words and 2/2 guards per Seed; max-tile group 1/1 bin, 3 hits; 32/32 operand lines accepted/returned | `V2-CMDQ-PRODUCT-GEMV-FULL-TILE-3SEED-9287478`, seeds 20261118/19/20, SHA `92874788fb2cb2a2b15657a3621e5a275a9d5990` | PASS for M=N=K=16 only; all legal shapes and exhaustive tail combinations remain open |
| REQ-V2-052-003/004 | Real CMDQ 0x52 GEMV for intermediate M/N/K shapes, including K>64, independent signed INT32 Golden, output guards, completion and accepted/returned ownership | `1×16×17`, `8×13×65`, `15×16×31`; per Seed 360/360 output words and 6/6 guards; across three Seeds 1,080/1,080 outputs and 18/18 guards; dedicated URG shape bins 3/3 (100%); 19/19, 106/106 and 61/61 Matrix reads respectively, each fully returned | `V2-CMDQ-GEMV-EXTENDED-SHAPES-3SEED-0696C16`, seeds 20261124/25/26, SHA `0696c16bd1346207ad5421d21247c719ea018111` | PASS for these three additional product-top shapes; full legal shape space, alias/fault crosses and all K boundaries remain open |
| REQ-V2-052-007 | Count real Matrix banked request accepts and Matrix-tagged responses before completion; concurrently submit CNM and preserve independent response owners | Single GEMV endpoint sizes drain 2/2, 8/8, 32/32; concurrent GEMV/CNM drains Matrix 32/32 and CNM 4096/4096, zero route mismatch, both ordered completions and both Golden images pass; named overlap/owner group 100% | `V2-CMDQ-GEMV-CNM-OWNER-CROSS-3SEED-85E7DB2`, Seeds 20261121/22/23, SHA `85e7db2d12f5edfaed17e8ca3910bb504983779f` | PARTIAL; the real Top pairing closes this tested multi-engine case. Arbitrary external held/late responses and remaining fault/reset/pairing matrix are open |
| REQ-V2-052-001 | Legal opcode-0x52 read-only A/B input alias (`srcA == srcB`) is accepted by ABI-v7 validation and dispatched through real Top CMDQ | Alias covergroup 1/1 per Seed; launch snapshot confirms equal sources and disjoint output | `V2-CMDQ-GEMV-AB-ALIAS-3SEED-F19E929`, Seeds 20261106/07/08, SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5` | PASS for this legal read-only alias point; other legal span intersections are not exhaustively sampled |
| REQ-V2-052-003/004 | Alias execution preserves the shared 256-byte source image and produces all 16 signed INT32 Golden outputs | 256 B unchanged, 16/16 outputs bit-exact, two output guards unchanged, successful completion per Seed | `V2-CMDQ-GEMV-AB-ALIAS-3SEED-F19E929`, Seeds 20261106/07/08, SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5` | PASS for shape `1×16×16` only; no concurrent software writes to aliased operands were attempted |
| REQ-V2-052-007 | Alias command drains every accepted Matrix response before successful completion | 17/17 accepted/returned Matrix reads per Seed; no ownership/count mismatch before completion | `V2-CMDQ-GEMV-AB-ALIAS-3SEED-F19E929`, Seeds 20261106/07/08, SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5` | PARTIAL; closes this serial alias point only; arbitrary held/late responses and the full multi-engine/fault/reset matrix remain open |
| REQ-V2-COM-002 | Preserve supported legacy opcode behavior alongside v2 additions on fixed source/test SHA | Directed Top Smoke plus 20 seeded random workloads per seed; legacy GEMM and existing 0x52/0x53 markers and independent checks pass | `V2-TOP-SMOKE-COMPAT-20X-3SEED-F19E929`, seed 20261106 smoke + seeds 20261106/07/08, SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5` | PASS for exercised modes and workloads only; not exhaustive legacy shape/aux/fault compatibility |

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
- `V2-LEGACY-TOP-COMPAT-3SEED-5F6E282`: clean detached worktree at source/test SHA `5f6e282f191b421bdbefc3d252690a9a0c93eb1c`, tree `4a5e0a1da1ab7d5a910c6f0a9417304d8a752cb2`; VCS `V-2023.12-SP1_Full64`; compile with `make -C dv/subsystem/top_smoke/sim ai_comp`, then run `./simv +ntb_random_seed=$seed +AI_RANDOM_CASES=20 +AI_SEED=$seed +ACLK_PERIOD_NS=10.0` for seeds 20261108/09/10. Each run reports `TEST PASS`; directed legacy checks include seven Tensor GEMM (`0x30`) outputs and four two-head Batch GEMM (`0x31`) outputs, alongside randomized legacy GEMV/GEMM/Conv/Depthwise Golden comparisons and the current 0x53 smoke path. The known `LOOP-REROLL-ENABLED` debug-capacity notice is present; the simulation logs contain no `ERROR:` lines. Logs-only archive `/tmp/nmaforge_v2_top_compat_5f6e282_logs.tar.gz`, SHA-256 `a56378fc6a1364ee4fdcc8f34dcf21b47068270d473ba7b848cdaef6b2a65b3c`; VCS executables/databases are excluded.
- `V2-MATRIX-FSM-GUARDS-145363D`: VC Formal `V-2023.12-SP2`; 5/5 named Matrix FSM assertions proven/non-vacuous and 2/2 state covers reached. It is not an opcode 0x52/0x53 assertion campaign.

`V2-CMDQ-GEMV-EXTENDED-SHAPES-3SEED-0696C16` used fixed source/test SHA
`0696c16bd1346207ad5421d21247c719ea018111` (tree
`94c8488a9c79f4ad3f0ee771ab43d7528fe285d0`) in detached clean worktree
`/tmp/nmaforge-v2-clean-0696c16`. Exact command:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C /tmp/nmaforge-v2-clean-0696c16/dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_gemv_extended_shapes_clean_0696c16 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261124 20261125 20261126'
```

VCS and URG are `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; clean compile
reported 0 errors and 0 warnings. All three seeds pass the full Cluster UVM
target with UVM Warning/Error/Fatal `0/0/0`. Each added shape has independent
Golden, two untouched sentinels, ordered completion, and accepted=returned
Matrix responses. The dedicated URG group is 3/3 (100%); merged aggregate
Line/Condition/FSM/Branch/Assert/Group is `70.71/68.29/46.17/67.66/72.00/82.43%`.
The Memory Scoreboard checks 98,199 words per seed with zero mismatches,
unknown reads or stale-epoch reads; the response ledger is
`5015/4995/20`, with zero route/data/error mismatch and no pending response.
Logs plus text URG reports only (no VDB or simulator binary) are archived at
`/tmp/nmaforge_v2_gemv_extended_shapes_0696c16_logs.tar.gz`, SHA-256
`cef415263d6d3c3b56a0137c8b5a1561282eae2b7043284bde0484439faa70b7`.
This expands tested shapes; the full supported descriptor space and overall
v2 sign-off remain open.

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

The clean Top compatibility replay used:

```sh
export VCS_ARCH_OVERRIDE=linux \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH
make -C dv/subsystem/top_smoke/sim ai_comp
for seed in 20261108 20261109 20261110; do
  ./simv +ntb_random_seed=$seed +AI_RANDOM_CASES=20 +AI_SEED=$seed \
    +ACLK_PERIOD_NS=10.0 \
    -l /tmp/nmaforge_v2_top_compat_5f6e282_seed_$seed.log
done
```

The RTM currently has 22 requirement IDs: 14 scoped PASS, 8 PARTIAL, and 0
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
5. Extend old-opcode compatibility beyond the tested 0x30/0x31 modes/shapes to
   remaining legacy descriptors, aux combinations, and fault/concurrency
   interactions; the current clean three-seed Top Golden suite is scoped.
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

## Named v2 feature coverage replay — 2026-11-06

Testbench/build commit `380f96114dba022300db09fb217264c3a606a2fd` (tree
`79aaf0782aba0da18d7109b74ae2bd343a473181`) adds six named GEMV shape bins,
eight selected 0x52/0x53 fault bins, six Tile Forwarding bins, and a Makefile
gate for the Prefetch-OFF GEMV shape regression. Product RTL is unchanged.
VCS/URG is `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

| Run ID | Seeds / build profile | Result |
|---|---|---|
| `V2-GEMV-SHAPES-PREFETCH-ON-3SEED-380F961` | 20261108/09/10; depth 4, Prefetch ON | Six shapes each seed pass bit-exact INT32 Golden: M4×16×32, M1×13×17, M8×16×19/65, M16×16×19/65. URG shape group 6/6. |
| `V2-GEMV-SHAPES-PREFETCH-OFF-3SEED-380F961` | 20261108/09/10; depth 4, Prefetch OFF | Same six Golden points pass; separate URG shape group 6/6. Prefetch-OFF VDB is kept separate because the compile-time DUT condition shape differs. |
| `V2-OPCODE-FAULT-3SEED-380F961` | 20261108/09/10; default feature build | Selected 0x52 Parity, B Protection, outstanding-prefetch Abort and Reset/stale response; 0x53 Reset epoch, Parity, output Protection, held-write Abort/recovery. Eight named bins each hit on all Seeds. |
| `V2-TILE-FORWARD-3SEED-380F961` | 20261108/09/10; forwarding OFF and ON | Six ON bins each seed: committed capture, tagged consume/bank flip, tag-miss SPAD fallback, Reset invalidation, Abort invalidation and repeated-tag SPAD fallback. Golden passes in both profiles. First consume uses 16 reads/256 B with one forwarding hit and 16 reads saved; a second consume of the same tag correctly falls back to 32 SPAD reads after one-shot invalidation. |

The same-profile Prefetch-ON URG merge contains 12 tests. The three named
groups (`v2_gemv_shape_cg`, `v2_opcode_fault_cg`,
`v2_tile_forward_cg`) each score 100% (6/6, 8/8, 6/6). Selected Matrix
hierarchy Line/Condition/FSM/Branch is 93.90/90.88/92.42/96.62%; this is not
Top or full-v2 code coverage. The separate Prefetch-OFF URG report confirms
the six GEMV shape bins at 100%; different compile-time profiles were not
merged into the code-coverage percentages. No illegal state was injected; no new functional bins were waived, forced, or excluded. Existing code-coverage exclusions remain governed by the Matrix URG configuration and were not recertified here.

Exact regression commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim core-random-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261108 20261109 20261110' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_matrix_coverage_3seed_20261106

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim product-opcode-fault-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261108 20261109 20261110' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_opcode_cov_20261106

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim core-tile-forward-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261108 20261109 20261110' \
  TILE_FORWARD_REGRESS_OUT=/tmp/nmaforge_v2_tile_coverage_3seed_20261106

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim core-no-prefetch-gemv-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261108 20261109 20261110' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_v2_no_prefetch_gemv_shapes_20261106
```

URG merged only compatible Prefetch-ON VDBs; Prefetch-OFF was reported
separately. The evidence archive includes the logs, VDBs, URG text reports and
command manifest:
`/tmp/nmaforge_v2_feature_coverage_380f961_evidence.tar.gz`, SHA-256
`6529ad5fdbd74f9441be0882180aecde077f6b388fed9bca4a2bccef7f0d63ad`.

These results close only the named shape/fault/forwarding testpoints. Matrix
alias/range variants, full fault × phase × reset × engine crosses, external
fabric ownership, full Top functional groups, opcode-specific SVA and all
requirement-level exclusions remain open. `REQ-V2-COM-004` therefore remains
**PARTIAL**, and overall v2 DV remains **IN PROGRESS**.

## Opcode 0x52 request stability formal replay — 2026-11-06

Formal-only commit `b719ac6066616b17dfab4eed2429f8bdfdc49457` (tree
`d269b738226282ea1057f1832fcd41ee51e61b6e`) adds a bounded dedicated harness
for the legal Opcode 0x52 GEMV descriptor M=1, N=1, K=1. Product RTL is
unchanged. VC Formal `V-2023.12-SP2` completed with no setup issues:

- `ap_gemv_request_stable_until_accept`: **proven 1/1, non-vacuous 1/1**.
  The property requires request VALID and address to stay stable during
  `VALID&&!READY`; Abort, watchdog, or an already-owned fault response are
  explicit cancellation cases.
- `cp_gemv_request_backpressure_release`: **covered 1/1 at depth 4**, reaching
  two blocked samples followed by request acceptance.

Exact command:

```sh
make -C dv/block/compute/matrix/formal gemv-request-stability \
  GEMV_REQUEST_OUT=/tmp/nmaforge_v2_gemv_req_sva_b719ac6
```

The run took 114.68 seconds and used the in-repository Matrix core with a
bounded M1×N1×K1 descriptor, 16×16 array, four outstanding slots, and an
accepted-owner assumption for responses. Evidence archive:
`/tmp/nmaforge_v2_gemv_req_sva_b719ac6_evidence.tar.gz`, SHA-256
`e8f19d5fde55c5067265f8e9d7a2e203a515d4933723ecc50ff5d3f2762ac189`.

This closes only the 0x52 request stability property. `REQ-V2-COM-003` remains
**PARTIAL** because 0x53 lifecycle assertions, broader error/reset behavior,
response ownership across multiple engines, and top-level SVA coverage are still
open. Overall v2 DV remains **IN PROGRESS**.

## Request-address stability mutation replay — 2026-11-06

The current testbench candidate is `ab96d47876beb4d7e47fef01e43b4c4716dd176a`
(tree `1126cb6e650545fdc0bad003c321a77fe552e3a4`). This is a testbench and
mutation-runner-only change; product RTL is unchanged. Run ID
`V2-OPCODE-MUTATION-6X3-AB96D47` used VCS
`V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, and Seeds 20261111/12/13.

Six temporary RTL mutations were injected and each was caught for all three
Seeds (18/18 total): output data, output address, operand response owner,
WSTRB, tile tag, and bank request address changing while `VALID&&!READY`.
The new request-address mutant triggers the active Matrix request stability
checker; the response-owner mutant triggers the existing GEMV Completion /
Golden check. The runner also verifies that a mutation run cannot accidentally
pass via the normal test marker.

On the same candidate SHA, the compatibility rerun passed the Matrix core's
18 functional and 35 fault cases, the selected 0x52/0x53 fault campaign, the
request/line backpressure campaign, and the Prefetch-OFF six-shape GEMV
campaign across the same three Seeds. The merged request-handshake URG group
remains 2/2 (100%), with three hits per bin. These are scoped results and do
not close v2 DV.

Exact commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim product-opcode-mutation-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  PYTHON=python3.12 \
  V2_OPCODE_MUTATION_OUT=/tmp/nmaforge_v2_opcode_mutation_e7daa34_retry_20261106 \
  V2_OPCODE_MUTATION_SEEDS='20261111 20261112 20261113'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim \
  product-opcode-handshake-regress core-random-regress \
  product-opcode-fault-regress core-no-prefetch-gemv-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261111 20261112 20261113' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_mutation_compat_20261106 \
  V2_OPCODE_HANDSHAKE_OUT=/tmp/nmaforge_v2_mutation_compat_20261106/handshake \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_v2_mutation_compat_20261106/no_prefetch

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_v2_mutation_compat_20261106/coverage.vdb \
  -format text \
  -report /tmp/nmaforge_v2_mutation_compat_20261106/urg \
  -log /tmp/nmaforge_v2_mutation_compat_20261106/urg.log
```

Evidence archive:
`/tmp/nmaforge_v2_request_mutation_ab96d47_evidence.tar.gz`, SHA-256
`f137212c354e79f890c4c36f78ca9197694b6853524b1a87b6b9ba5add7fcb03`.

`REQ-V2-COM-005` remains **PARTIAL**: six selected mutation classes do not
prove every checker mapping or every fault × phase × reset combination.
Overall v2 DV remains **IN PROGRESS**; full requirement closure, external
fabric response ownership, broader legal fault crosses, and opcode-specific
non-vacuous SVA remain open.

## 2026-11-06 update — premature tile-valid SVA and mutation replay

Verification-only commit `ed17ab1c257c0f7947cf78e60730da31c4548138` (tree
`4e1378de8c9f72028941878cacf98bbc280d8dca`) adds a third 0x53 runtime SVA:
`p_tile_forward_valid_rises_after_complete_commit`. It checks that a rising
forwarding-valid signal follows a complete 16-line capture and carries the
producer destination tag. The forwarding ON/OFF regression passes on Seeds
20261123/24/25: enabled mode reports 3/3 assertions attempted, zero failures,
the valid-rise cover matches three times per seed, and the six named
forwarding bins remain 6/6 with bit-exact Golden checks. This is simulation
evidence; it does not promote `REQ-V2-COM-003` from PARTIAL or imply formal
proof of every 0x53 lifecycle.

Exact SVA regression command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim core-tile-forward-regress \
  SEEDS='20261123 20261124 20261125' \
  TILE_FORWARD_REGRESS_OUT=/tmp/nmaforge_v2_tile_rise_sva_ed17ab1
```

Run ID: `V2-TILE-FORWARD-SVA-3SEED-ED17AB1`; evidence archive
`/tmp/nmaforge_v2_tile_rise_sva_ed17ab1_evidence.tar.gz`, SHA-256
`c90995c1161d13ee8d6b7d4ad8efe8e3ebaa51d289818f69960ca666be859f56`.

Mutation-runner commits `f1363b8fc61a17db2310e406bb18943cdfac0da8` and
`4df2efeefafa49f6832af9bc7fa8a71005b28fa9` add an actual temporary RTL
premature-valid mutant and map both it and tag corruption to the new direct
SVA. The mapping was updated because the stronger assertion now catches tag
corruption before the later read-count checker. No source RTL is modified by
the runner. The final run passes seven actual mutation classes over the same
three Seeds (21/21 caught): output data, output address, response operand
owner, WSTRB, bad forwarding tag, premature valid, and request-address change
while stalled. Each mutation is caught by its assigned checker and none
reaches the normal test PASS marker.

Exact mutation command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
python3 dv/block/compute/matrix/sim/run_v2_opcode_mutations.py \
  --out /tmp/nmaforge_v2_opcode_mutations_4df2efe \
  --vcs '/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  --vcs-home /tmp/nmaforge_vcs_home_linux_alias \
  --seeds 20261123 20261124 20261125
```

Run ID: `V2-TILE-FORWARD-MUTATION-7X3-4DF2EFE`; final candidate tree is
`71a655d67ff82de6ecab8fadeb10864cb4f95006`. Evidence archive
`/tmp/nmaforge_v2_opcode_mutations_4df2efe_evidence.tar.gz`, SHA-256
`c40414a6e9944fb6c9af9ba53065051256bc21d47d098a10185052f860bbecf6`.
`REQ-V2-COM-005` remains **PARTIAL**: this expands checker-sensitivity
evidence for these seven defects, not a complete mutation mapping of all v2
checkers or all fault × phase × reset interactions. Product RTL, ABI, and
benchmark values are unchanged; v2 DV remains **IN PROGRESS**.

## Request and writeback backpressure replay — 2026-11-06

Testbench/build commit `e7daa34d17d8b3c06d2aaf16c1cc66d3bf8ff50a` (tree
`3807f483155df1be4271c25a165a64512a83d04e`) adds a Matrix bank-request
VALID/address stability monitor and a deterministic not-ready control. Product
RTL is unchanged. The monitor treats Abort, an asserted error, and watchdog
expiry as valid cancellation paths; an initial replay exposed that the generic
Matrix watchdog test uses the third path, so the checker was corrected and
the full three-seed rerun passed.

| Run ID | Seeds / scope | Result |
|---|---|---|
| `V2-OPCODE-HANDSHAKE-3SEED-E7DAA34` | 20261111/12/13; default Prefetch-ON Matrix profile | Each seed holds the first 0x52 bank request at `VALID&&!READY` for at least three cycles, checks unchanged address and zero accepts while blocked, releases READY, then passes all output INT32 Golden checks and drains responses. The 0x53 chain checks held output-line payload and complete producer/consumer Golden. URG handshake group `gemv_bank_request_backpressure` and `fused_line_write_backpressure` is 2/2, 100%, with three hits per bin. |
| `V2-MATRIX-CORE-COMPAT-3SEED-E7DAA34` | 20261111/12/13; existing 18 functional + 35 fault Matrix core cases and six GEMV shape tests | All three seeds pass after adding the request-stability monitor. |
| `V2-OPCODE-FAULT-3SEED-E7DAA34` | 20261111/12/13 | Selected existing 0x52/0x53 fault recovery bins remain 8/8 with response drain and Golden recovery. |
| `V2-GEMV-SHAPES-PREFETCH-OFF-3SEED-E7DAA34` | 20261111/12/13 | All six named GEMV shapes remain bit-exact with Prefetch OFF; coverage group is 6/6 per seed. |

The handshake replay does not close multi-engine response ownership, arbitrary
external response holds, all legal fault × phase × reset crosses, or Top-level
Completion backpressure. `REQ-V2-052-007` remains PARTIAL and `REQ-V2-053-004`
is PASS only for the directed local line-ready stall. Overall v2 DV remains
IN PROGRESS.

Exact command set (run from repository root):

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim product-opcode-handshake-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261111 20261112 20261113' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_opcode_handshake_final_20261106 \
  V2_OPCODE_HANDSHAKE_OUT=/tmp/nmaforge_v2_opcode_handshake_final_20261106/run

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim core-random-regress \
  product-opcode-fault-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261111 20261112 20261113' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_handshake_compat_rerun_20261106

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/block/compute/matrix/sim core-no-prefetch-gemv-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
  SEEDS='20261111 20261112 20261113' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_v2_handshake_no_prefetch_20261106

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_v2_opcode_handshake_final_20261106/coverage.vdb \
  -format text \
  -report /tmp/nmaforge_v2_opcode_handshake_final_20261106/urg \
  -log /tmp/nmaforge_v2_opcode_handshake_final_20261106/urg.log
```

Evidence archive:
`/tmp/nmaforge_v2_opcode_handshake_e7daa34_evidence.tar.gz`, SHA-256
`20f88eb467383ad65c1ba29d819af053cafc3326dca06f4c0f4c4816bf9e7cb8`.

## 2026-11-06 update — 0x53 forwarding commit/tag SVA at `6a25338`

Testbench/build-only commit `6a253386f53638a1206a75e359d6020ba27765cb`
(tree `588806486bd6b22fc0444cd0e29dc108d9f993d3`) adds two concurrent SVA
to the real Matrix-core forwarding test. The commit property checks that a
successful producer reaches `ST_DONE` with all 16 capture-mask bits set, then
publishes a valid Tile with the producer destination tag. The stability
property prevents that committed tag from changing between complete capture
commits. Product RTL, descriptor ABI, and forwarding capacity are unchanged.

The distinction between committed validity and the live capture mask matters:
while a consumer reads the old bank, the producer may fill the opposite bank,
so a valid old Tile can coexist with a partial new capture mask. The assertions
therefore check the commit edge and tag lifetime instead of equating the
current capture mask with the currently valid bank.

VCS `V-2023.12-SP1_Full64` ran the forwarding ON/OFF ablation on three Seeds.
For the enabled forwarding profile, each Seed reports two assertions attempted
with zero failures, one cover attempted with three matches, one observed
non-vacuous commit, and the six named functional bins at 100%. The complete
producer/consumer outputs remain bit-exact; the chain records one forwarding
hit, 16 source-A reads (256 B), and an opposite-bank flip. Tag-miss/repeated
consumer fallback, Abort, Reset invalidation and recovery also pass. Disabled
forwarding continues to use the SPAD path.

Exact command (from repository root):

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim core-tile-forward-regress \
  SEEDS='20261120 20261121 20261122' \
  TILE_FORWARD_REGRESS_OUT=/tmp/nmaforge_v2_tile_sva_6a25338
```

Run ID: `V2-TILE-FORWARD-SVA-3SEED-6A25338`. The archive contains the three
enabled-profile compile/run/assertion reports:
`/tmp/nmaforge_v2_tile_sva_6a25338_evidence.tar.gz`, SHA-256
`92efa5d9763114cc6fdf121d2b22744c06852ff6e9c66072503d054a53656f15`.
This advances the named `REQ-V2-053-002` scenarios and adds runtime assertion
evidence to `REQ-V2-COM-003`; it is not a formal proof of the complete 0x53
lifecycle. Broader cross-engine ownership and all fault × phase × reset
contracts remain open. Overall v2 DV remains **IN PROGRESS**.

## 2026-11-06 — three-seed Top compatibility replay after testbench update

The testbench source commit `835f958b5f486b3f3e4808e735a788721f4f1441`
(tree `653d605abd1e3a5bb414721694c46e6897086115`) was used for three
`ai_run` simulations with 20 randomized workloads each. The later tooling
commit `de22e46` did not change RTL or the compiled testbench module.

| Run ID | `AI_SEED` | VCS `ntb_random_seed` | Result |
|---|---:|---:|---|
| `V2-TOP-SMOKE-20X-835F958-20261130` | 20261130 | 1793945994 | PASS; legacy GEMM, GEMV `0x52`, tile-forward `0x53`, CNM and 20 randomized workloads |
| `V2-TOP-SMOKE-20X-835F958-20261131` | 20261131 | 1793945994 | PASS; same directed checks and 20 randomized workloads |
| `V2-TOP-SMOKE-20X-835F958-20261132` | 20261132 | 1793945995 | PASS; same directed checks and 20 randomized workloads |

Exact command for each row:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=<seed>
```

This is top-level regression/compatibility evidence. It does not add v2 feature
functional coverage bins, close residual requirement PARTIALs, or refresh the
three-seed URG aggregate. The current scoped v2 RTM remains 22 IDs: 14
PASS-scoped and 8 PARTIAL; overall v2 DV is **IN PROGRESS**. Logs archive:
`/tmp/nmaforge_v2_ai_run_3seed_835f958_logs.tar.gz`, SHA-256
`7b71e6a3b5815173e8bc256fec0d323b6efe0d71e5f41f171ef4496ac5df3117`.
Machine records are in
[`v2_top_smoke_20cases_835f958.csv`](../../benchmark/v2_top_smoke_20cases_835f958.csv)
and [`v2_top_smoke_20cases_835f958.json`](../../benchmark/v2_top_smoke_20cases_835f958.json).

## 2026-11-06 — current model candidate Top Smoke compatibility replay

At clean source SHA `9b835aeac33d43fd97a81496b1048d359cdff3d0` (tree
`04215a9fb125e57aa6a9ce6ead2410f59bafa2b7`), product RTL is still
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. `make ai_smoke` passes on seed
20261106 with four randomized workloads and all six required 0x52/0x53/CNM
markers. The same compiled candidate then passes `ai_run` with 20 randomized
workloads each on seeds 20261106/07/08. Each log has exactly one `TEST PASS`,
zero `ERROR:` lines, the directed GEMV, forwarding, cross-engine immutability,
and Matrix/CNM profile markers; simulation times are 984,560,000 ps,
981,920,000 ps, and 991,190,000 ps respectively. This is a Top Smoke replay,
not UVM or a coverage merge.

Exact commands (run from the repository root):

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_run \
  AI_RANDOM_CASES=20 AI_SEED=20261106 SEED=20261106
```

The second command was repeated with both seed values set to `20261107` and
`20261108`. The machine-readable record is
[`v2_top_smoke_compat_9b835ae.json`](../../benchmark/v2_top_smoke_compat_9b835ae.json).
The logs-only archive is
`/tmp/nmaforge_v2_top_smoke_compat_9b835ae_3seed_evidence.tar.gz` (SHA-256
`a6eb548b5e37dd2fba1df0513635bed43705d5eafebaa376ecbb13d8abc75159`). This
does not add functional coverage bins or alter the scoped RTM disposition of
14 PASS-scoped / 8 PARTIAL; v2 DV remains **IN PROGRESS**.

## 2026-11-06 — fixed-candidate Top compatibility after GEMV alias test addition

At clean detached testbench SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5`
(tree `2d931c1c81997b482467d7fdf69302dd367975a1`), the Top Smoke compile and
directed `ai_smoke` pass on seed 20261106 with four random workloads. Then
`ai_run` passes 20 random workloads on each seed 20261106/07/08. Every run
reports one `TEST PASS`, zero `ERROR:` lines, and the legacy GEMM, 0x52 GEMV,
0x53 fused/cross-engine immutability, and Matrix/CNM profile markers. Simulation
times are 984,560,000 ps, 981,920,000 ps, and 991,190,000 ps for the three
20-case runs. Compilation shows the pre-existing
`LOOP-REROLL-ENABLED` fixture debug-capacity notice; there are no compile
errors. This is compatibility evidence only, not a new coverage merge or full
v2 DV sign-off. Product RTL remains unchanged.

Run ID `V2-TOP-SMOKE-COMPAT-20X-3SEED-F19E929`. Machine-readable record:
[JSON](../../benchmark/v2_top_smoke_compat_f19e929.json). Logs-only archive:
`/tmp/nmaforge_v2_top_compat_f19e929_logs.tar.gz`, SHA-256
`c8054cc1ea0bc0e07f96c96f963806e159845cfc56c3ca17e8c0fd0de0e10f5f`.

Exact commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_run \
  AI_RANDOM_CASES=20 AI_SEED=<seed> SEED=<seed>
```

The second command was repeated with `<seed>` set to `20261106`, `20261107`,
and `20261108`. This confirms tested compatibility at the new testbench
candidate SHA; global v2 coverage remains at the URG values above.

## 2026-11-06 — Top Smoke after Transformer timing instrumentation

At testbench SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9` with unchanged
product RTL `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, `ai_smoke` passes on
seed 20261106 with four randomized workloads. Required markers pass for
GEMV `0x52`, fused `0x53`, cross-engine source immutability and the Matrix/CNM
profile; the log has one `TEST PASS` and no simulation `ERROR:` line. This
checks that the new Transformer completion-tail timer did not disturb other
Top paths. It is a compatibility run and adds no UVM/URG bins; the v2 RTM
remains 14 PASS-scoped / 8 PARTIAL.

Run ID `V2-TOP-SMOKE-POST-TRANSFORMER-TIMING-F9F32F7-S20261106`. Exact command
from `dv/subsystem/top_smoke/sim`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106
```

Machine record: [JSON](../../benchmark/v2_top_smoke_post_transformer_timing_f9f32f7.json).
Logs-only archive outside Git:
`/tmp/nmaforge_v2_top_smoke_post_transformer_timing_f9f32f7_logs.tar.gz`,
SHA-256 `6667deb76dfbfbbfd51219785f27cf283ab7dcb92df57e07f757439dfaf7b428`.

## Clean-worktree current-candidate Top Smoke replay — 2026-11-06

The fixed test/tooling commit `f9f32f71e7168350d74a75ede0a4a4b222844cc9` was
checked out detached into `/tmp/nmaforge-v2-clean-f9f32f7`; no worktree edits
were present. VCS `V-2023.12-SP1_Full64` ran:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106
```

The command exited 0 and emitted one `TEST PASS`, 301/301 Transformer
intermediate/final/KV Golden checks, and no `ERROR:` lines. Required smoke
markers passed for 0x52 basic and two tail GEMVs, 0x53 producer/consumer,
cross-engine SFU overlap with source immutability, and Matrix/CNM cycle closure
with bit-exact Golden. Run ID
`V2-CLEAN-WORKTREE-TOP-SMOKE-F9F32F7-S20261106`. Logs-only archive:
`/tmp/nmaforge_v2_clean_f9f32f7_smoke_logs.tar.gz`, SHA-256
`1eda8105b2c528ca32110c8f6a5e86b0934e4ba9cc71f59613afb51c5b6e3714`.

This is clean-worktree compatibility and selected functional evidence only.
It does not add UVM/URG coverage or close the full `REQ-V2-*` RTM; residual
fault × phase × reset, held/late external response, and coverage disposition
items remain open. The 10 ns simulation clock is not a physical timing claim.

## Clean-worktree seven-engine UVM replay at current test candidate — 2026-11-06

At detached source/test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`
(tree `0b20e98298852d2648f83d10723c55aabe3a9149`), VCS
`V-2023.12-SP1_Full64` ran `uvm_compute_cluster_regress` for Seeds
20261106/07/08. Each Seed passed with UVM Warning/Error/Fatal `0/0/0` and
all seven observed engine-pair overlap bins (21/21). The selected workload
also exercised shared Matrix/CNM response ownership, parity/protection,
Abort/Reset recovery, full Completion Queue backpressure, and independent
Golden checks. The real queued four-task workload measured 1,696 serial
cycles and 1,137 parallel CMDQ cycles (1.492×); this is VCS RTL simulation
with behavioral four-bank SPAD, not silicon timing.

Merged URG across the three runs reports Line/Condition/FSM/Branch/Assert/
Functional Group `70.71/68.37/46.17/67.66/72.00/83.94%`. The targeted
engine-pair group is 21/21, but overall groups are not closed: five groups
remain at zero (four AXI memory stall groups and DMA error-position coverage),
AXI4 is 50.28%, AXI-Lite 87.50%, URG has 17/22 assertions successful with
five uncovered and two without attempts, and only 1/3 cover properties
matched. These unhit bins remain visible; no exclusions or waivers were added.
The run does not close arbitrary external held/late responses, all legal
fault × phase × reset crosses, or the complete v2 RTM.

Exact command:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_cluster_clean_f9f32f7 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261106 20261107 20261108'
```

Run ID `V2-COMPUTE-CLUSTER-UVM-CLEAN-F9F32F7-3SEED`. Text logs and URG
summaries (no VDB/compiled simulator databases) are archived at
`/tmp/nmaforge_v2_cluster_clean_f9f32f7_3seed_logs_urg_text.tar.gz`, SHA-256
`5b5bef7586349e335e563ee3eaae1dfa56ad9536a583aadd0d711f08b93e9f2d`.
Machine record: [JSON](../../benchmark/v2_cluster_clean_f9f32f7_3seed.json).
This advances selected Cluster RTM evidence only; v2 DV stays **IN PROGRESS**.

## Compatible 19-test Cluster + mixed AXI/DMA URG merge — 2026-11-06

At clean source/test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`
(tree `0b20e98298852d2648f83d10723c55aabe3a9149`), I ran the mixed precision
DDR/AXI E2E coverage target on 16 independent Seeds, 20261109–20261124. Every
seed passed with UVM Warning/Error/Fatal `0/0/0`, first/last-beat DMA error
positions checked, and the AR/AW gap configuration cross completed. Its
standalone profile has 100% E2E, DMA error-position, and four AXI memory-model
functional groups. The standalone total group score is 90.86% because this
test alone does not replay the Cluster group; this is recorded separately.

Exact simulation command (run from the repository root):

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_v2_mixcov_f9f32f7_16seed \
  MIXED_E2E_COV_SEEDS='20261109 20261110 20261111 20261112 20261113 20261114 20261115 20261116 20261117 20261118 20261119 20261120 20261121 20261122 20261123 20261124'
```

The Cluster and mixed profiles were then merged with URG because they have
identical source/test SHA and tree, UVM top, source list, and line/condition/
branch/FSM/assert metrics; they differ only in runtime test and seed. URG
completed without warnings and reports 19 tests. All 36 declared functional
covergroups are 100%, including Cluster, E2E, DMA error-position, AXI AR/AW
stall and AXI response/write-data gap groups. The combined top AXI cover
properties match AR/AW/W `161/67/126` times. Of 22 assertions, 20 have real
successes and zero fail/incomplete; the two without attempts are UVM RAL
`do_read` and `do_write`. Hierarchy Line/Condition/FSM/Branch/Assert is
`74.13/71.59/47.45/71.10/92.00%` (overall score `76.04%`). These percentages
are not all functional requirements or RTL bins.

Run IDs are `V2-MIXED-AXI-DMA-COVERAGE-CLEAN-F9F32F7-16SEED` and
`V2-COMPUTE-CLUSTER-AND-AXI-DMA-URG-MERGE-19TEST-F9F32F7`. The exact full URG
command and input VDB paths are in the [merged JSON record](../../benchmark/v2_merged_urg_f9f32f7_19test.json); the per-seed simulation command and results are in the [mixed-E2E JSON record](../../benchmark/v2_mixed_axi_dma_cov_f9f32f7_16seed.json). Text-only archives (no VDB or simulator binary) are `/tmp/nmaforge_v2_mixcov_f9f32f7_16seed_logs_urg_text.tar.gz`, SHA-256 `d74bf68171e6798e2a5b25fffc9d3ea7e6dd49e9d3e2e3efb3abbf738c13abe5`, and `/tmp/nmaforge_v2_combined_urg_f9f32f7_19test_text.tar.gz`, SHA-256 `9ec6f0c496ada3e8ac3188ef863ac4a795a8232c603ad457a4e39d7a30562f86`.

This closes the declared functional groups in this 19-test plan only. It does
not close every legal 0x52/0x53 shape, fault × phase × reset cross, external
held/late response contract, residual code/FSM bin or waiver disposition. The
RTM remains 14 PASS-scoped / 8 PARTIAL; v2 DV stays **IN PROGRESS**. No product
RTL or coverage waiver changed.

## Fixed-SHA opcode shape, fault, handshake, and mutation replay — 2026-11-06

At detached clean test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`
(tree `0b20e98298852d2648f83d10723c55aabe3a9149`), VCS
`V-2023.12-SP1_Full64` passed the focused Matrix targets on Seeds
20261106/07/08:

- `product-gemv-regress`: all six selected opcode 0x52 shapes (including
  `M=1`, N/K tails, M-row tails, and `K=65`) match the independent Golden;
  the declared six-bin shape group is 6/6 per Seed.
- `product-opcode-fault-regress`: 8/8 declared recovery bins per Seed cover
  0x52 Parity, Protection, Abort, reset-orphan and 0x53 reset-epoch, Parity,
  writeback Protection, and held-write Abort with post-fault Golden recovery.
- `product-opcode-handshake-regress`: 2/2 bins per Seed exercise a three-cycle
  0x52 request stall and held 0x53 output-line payload; both recover to
  bit-exact Golden. Tile Forwarding has 6/6 declared feature bins per Seed in
  the selected campaigns, with runtime assertions reporting non-vacuous
  capture/commit activity.
- `product-opcode-mutation-regress`: 21/21 checks caught seven temporary RTL
  mutations over three Seeds: output data, output address, response operand
  owner, WSTRB, tile tag, early tile valid, and request-address hold.

The exact commands, per-Seed logs, mutation checker reports and archive hashes
are in the [machine record](../../benchmark/v2_opcode_f9f32f7_3seed.json) and
`/tmp/nmaforge_v2_opcode_f9f32f7_logs.tar.gz` (SHA-256
`8c016bfa910b36c09a7ad5f398c3cbb025b676f8ded30627755af293bc391ef8`). Only
text evidence is archived; VCS databases and executables are excluded. No
product RTL changed. These results close only the named testpoints; full legal
shape/alias/range coverage, arbitrary external held/late responses, complete
fault × phase × reset crosses and overall URG coverage remain open.

## Top Matrix profile telemetry replay — 2026-11-06

At fixed source/test SHA `8adf916e4e8a0e3b2f2e01acc85bacb59fbb8f47` (tree
`a8c232664436c5b1d1f2888eff34439edb40430d`), the full Compute Cluster UVM
regression passed on Seeds 20261125/26/27 with UVM Warning/Error/Fatal `0/0/0`
per Seed. The new passive profile checks that all 15 exclusive Matrix FSM
state counters equal the internal `cycle_count` and records Matrix-only SPAD
bytes; each Seed passes the existing 512-word Golden and A-tile reuse check.
This is a testbench consistency check and performance evidence, not a new v2
functional coverage bin. No RTM disposition changed; v2 DV remains **IN
PROGRESS**. Exact command, archive checksum and CSV/JSON are in the
[performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).

The follow-up fixed-SHA UVM replay `f530fe2c4c98204312b7ed16616cb9d9747670b2`
(tree `919ebb411a7b47e0e0b3dfd2084852a83a2a5034`) adds two more passive
Matrix observations per Seed under the existing staged Matrix/CNM and
Matrix-writeback/CNM tests. Seeds 20261128/29/30 pass all existing Cluster
checks with UVM Warning/Error/Fatal `0/0/0`; all 9 command profiles have
exclusive FSM bucket sums equal to Matrix `cycle_count`. The line-stall
scenario records 84 Matrix writeback-wait cycles and 354 arbiter-stall events,
while the existing Golden and payload-stability checks pass. No new
functional coverage bins or RTM dispositions are claimed. Machine evidence,
the exact command and text-log archive checksum are in the
[performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md)
and [JSON record](../../benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.json).

## Clean-worktree Top Smoke compatibility at the current candidate — 2026-11-06

Detached clean worktree at source SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`
(tree `630e498ba467d84dd5359403cfe1ed1e5879f6e9`) passes `make ai_smoke` with
VCS `V-2023.12-SP1_Full64`. The run reports `TEST PASS`, 1,683 `PASS:` log
lines, and zero simulation `ERROR:` lines. The existing compile-time
`LOOP-REROLL-ENABLED` fixture notice remains. Required markers confirm three
product GEMV cases, the `0x53` CMDQ tile-forward path, legal Matrix/SFU
cross-engine immutability, and the Matrix/CNM performance profile. The smoke
uses four randomized cases (`AI_SEED=12345`) and does not replace seeded UVM,
URG, or full v2 coverage closure. No RTM status changes.

Exact command and parameters, source/tree identity, marker list, and archive
checksums are in the [machine record](../../benchmark/v2_top_smoke_clean_839b9af.json).
Text-only run log archive: `/tmp/nmaforge_v2_top_smoke_839b9af_logs.tar.gz`,
SHA-256 `6fb7768b7b9d03a33b1c56d8b63a5ae44d8608b63492f106e4e04e6ee1dd2dae`.

## Clean-worktree three-seed Cluster replay at the same candidate — 2026-11-06

At the same detached clean source SHA/tree, the full
`uvm_compute_cluster_regress` target passes Seeds 20261128/29/30. Each seed
reports UVM Warning/Error/Fatal `0/0/0`, the full Cluster pass marker, the
existing seven-engine Golden and owner/recovery checks, and three Matrix
profiles. Across the nine profiles, all 15 exclusive Matrix FSM state buckets
sum exactly to the Matrix internal cycle counter. The stand-alone,
Matrix+CNM staged, and Matrix writeback-stall cases reproduce the previously
reported profile means.

URG merges three tests. Aggregate Line/Condition/FSM/Branch/Assert/Functional
Group coverage is `70.74/68.33/46.17/67.70/72.00/83.94%`; `cluster_cg` is
100%, while total declared group score is 83.94%. Of 22 assertions, 17 have
real successes and zero fail/incomplete; five are uncovered, including two
without attempts. One of three cover properties matches. Therefore the replay
confirms reproducibility at the fixed candidate but does not close aggregate
coverage or promote the 22-row RTM: it remains 14 PASS-scoped / 8 PARTIAL and
v2 DV remains **IN PROGRESS**.

Exact command, tool versions, URG details and profile artifact paths are in
the [machine record](../../benchmark/v2_clean_cluster_uvm_839b9af.json). The
9-row [CSV](../../benchmark/v2_top_matrix_cluster_profile_839b9af_3seed.csv)
and [JSON](../../benchmark/v2_top_matrix_cluster_profile_839b9af_3seed.json)
are derived from the run logs by the checked-in summarizer. Text-only log and
URG archive `/tmp/nmaforge_v2_clean_839b9af_cluster_3seed_text.tar.gz`,
SHA-256 `4d036d428c8e72a10490bb7eaf9534158a8df185d46722453e49038a374993f9`;
coverage databases and simulator outputs are excluded.

## Clean-worktree 0x52/0x53 feature and mutation replay — 2026-11-06

At the same fixed candidate SHA/tree, three seeds pass the Matrix-core 0x52/0x53
focused gates. The exact target set was `product-gemv-regress`,
`product-opcode-fault-regress`, `product-opcode-handshake-regress`,
`core-tile-forward-regress`, and `product-opcode-mutation-regress`.

| Scope | Evidence per Seed | Result |
|---|---|---|
| Opcode `0x52` GEMV | Six named shape bins; each run checks signed INT32 Golden, complete outputs, and response drain | 3/3 seeds pass; 6/6 bins each |
| `0x52`/`0x53` selected fault recovery | Parity/Protection/Abort/Reset and stale epoch cases | 3/3 seeds pass; 8/8 declared bins each |
| Request/line backpressure | `0x52` request VALID/address hold; `0x53` held line payload and recovery | 3/3 seeds pass; 2/2 bins each |
| Tile Forwarding ON/OFF | Capture/tag/consume, repeated-consumer fallback, ping-pong, miss fallback, abort/reset; enabled runtime assertions | 3/3 seeds pass; enabled 6/6 bins, 3/3 assertions attempted with no failure, 1/1 cover property matched |
| Actual temporary RTL mutation | Data, address, response operand owner, WSTRB, tile tag, early valid, request-address hold | 21/21 mutant-seed probes detected by the assigned checker |

This replays the selected feature checks at the candidate SHA; it does not
close every legal M/N/K combination, every fault × phase × reset cross,
external held/late fabric responses, all cross-engine ownership pairs, or the
full checker-to-fault mutation matrix. The three-test Cluster-only URG profile
at this same SHA scored 83.94% declared groups; the 19-test cross-suite merge
below reaches 100% for its declared functional groups. The 22-row RTM remains
14 PASS-scoped / 8 PARTIAL. No product RTL or coverage disposition changed.

The exact command, per-checker map, seed results, open items and archive hash
are in the [machine record](../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json).
Text-only logs, assertion reports and mutation summary:
`/tmp/nmaforge_v2_clean_839b9af_opcode_dv_3seed_text.tar.gz`, SHA-256
`5890df6674f1120041d58e05f709ab76ab8a87ac08e97f2b9fffeb1c3d046ff0`.

## Clean-candidate 19-test Cluster + AXI/DMA URG merge — `839b9af`

To close the unhit AXI/DMA functional groups seen in the three-test Cluster
profile, I reran the mixed precision DDR/AXI E2E coverage matrix on the same
clean source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`). The run used 16 Seeds
`20261109`–`20261124`; every seed passed the target's functional, DMA first/
last-beat error, reset recovery, descriptor, AXI gap/jitter checks with UVM
Warning/Error/Fatal `0/0/0`. Those VDBs were then merged with the three
same-SHA Cluster UVM VDBs for Seeds `20261128/29/30`.

URG reports 19 tests and 36/36 declared functional groups at 100%. The three
AXI AR/AW/W stall-to-accept cover properties match `161/67/126` times. The
combined code/ assertion summary is Line/Condition/FSM/Branch/Assert
`74.15/71.55/47.45/71.14/92.00%`; 20/22 assertions have real successes,
zero failures and zero incomplete attempts. The two assertions without
attempts are UVM RAL `do_read` and `do_write`. This reaches 100% only for the
declared functional groups in this 19-test plan. It does not close residual
RTL/FSM bins or all v2 requirement spaces; the v2 RTM remains 14 PASS-scoped /
8 PARTIAL and v2 DV remains **IN PROGRESS**. No functional exclusions or
waivers were added, and no illegal-state stimulus was used.

Exact 16-seed simulation command and exact URG input database list are in the
[machine record](../../benchmark/v2_clean_urg_19test_839b9af.json). The text
archive with mixed E2E seed logs and combined URG report is
`/tmp/nmaforge_v2_clean_839b9af_urg_19test_text.tar.gz`, SHA-256
`6a4ef4e3fd25cf4ec18baee37cfd43c4374a109a2b9c35ff40c07c0435f1e9b6`;
the standalone 16-seed logs/URG archive is
`/tmp/nmaforge_v2_clean_839b9af_mixcov_16seed_text.tar.gz`, SHA-256
`1ded9f9b381b8dbaa3916df6ba1f1cb494dd1cfa0e437c206593348a75c788db`.
Coverage VDBs, simulator executables and waveforms remain outside Git.

## Clean-candidate in-repository fabric reset replay — `839b9af`

The focused `subsystem_memory_fabric_reset_regress` was rerun in the clean
worktree at source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`
(tree `630e498ba467d84dd5359403cfe1ed1e5879f6e9`) using VCS
`V-2023.12-SP1_Full64` and URG `V-2023.12-SP1`, Seeds
`20261128/20261129/20261130`. All three runs passed with UVM
Warning/Error/Fatal `0/0/0`; each had both DMA/CNM recovery markers and the
overall reset pass marker. URG reports the three scoped reset groups at 100%.
`ap_single_response_owner` recorded 3,921 successes and
`ap_cnm_response_tag` 144 successes, with zero failures/incomplete attempts.

This exercises reset with outstanding DMA AXI reads and an accepted CNM SPAD
response, followed by fresh DMA/CNM Golden recovery. It does not qualify an
arbitrary external fabric and does not close the opcode-specific 0x52/0x53
reset-phase matrix. The exact invocation is in the [machine record](../../benchmark/v2_memory_fabric_reset_clean_839b9af_3seed.json);
the text log/URG archive is `/tmp/nmaforge_v2_clean_839b9af_memory_fabric_reset_text.tar.gz`,
SHA-256 `eff1b22cc9d071d1d02c75ef98c3317944cea11a3a70d0e8bee0bb8397a8abb7`.
Coverage databases and simulator executables remain outside Git. No RTL changed.

## Same-SHA Top owner, tail and recovery cross checks — `839b9af`

The three-seed `uvm_compute_cluster_regress` at the same clean candidate also
contains real CMDQ 0x52 GEMV + CNM concurrency, extended GEMV shapes, and
Matrix/CNM fault/reset owner checks. All three seeds report the concurrent
GEMV/CNM Golden and ordered-completion marker with zero route mismatches; the
GEMV accepted/returned read ledger is 32/32 and the CNM read ledger is
4096/4096. The eight declared M/N/K alignment-tail combinations and the three
extended shapes pass their per-seed Golden, guard, completion and response
ownership checks. The same cluster run passes selected Matrix parity-owner,
parity-Abort, parity-reset and Protection/reset recovery crosses with CNM.

This remains bounded evidence: the real-top parity/protection/reset crosses
exercise the ordinary Matrix path, while 0x52-specific error recovery is
covered separately at Matrix-core level. It does not prove the complete real
CMDQ 0x52 fault × phase × reset matrix or arbitrary external response timing.
The three-test Cluster-only URG profile is 83.94% for its 35 declared groups;
do not confuse it with the compatible 19-test merge's 36/36 group result.
Exact commands, tool versions and source/tree identities are in the [Cluster
machine record](../../benchmark/v2_clean_cluster_uvm_839b9af.json); text logs
and URG summary are in `/tmp/nmaforge_v2_clean_839b9af_cluster_3seed_text.tar.gz`,
SHA-256 `4d036d428c8e72a10490bb7eaf4f9534158a8df185d46722453e49038a374993f`.
No RTL changed.
