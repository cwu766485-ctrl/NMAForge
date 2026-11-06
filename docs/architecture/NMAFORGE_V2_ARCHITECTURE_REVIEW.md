# NMAForge v2 Architecture Review

## Bounded benchmark priority update — 2026-11-06

The current task is limited to reusing minimum functional evidence, comparing
the pinned TinyNPU array on the requested fixed GEMM/GEMV matrix, inspecting
the existing Digits/CNN layouts, and assessing SPAD capacity statically. Full
DV closure, 100% code coverage, complete formal closure, and ASIC readiness
are explicitly not goals of this round.

At audit, the target was `feature/npu-architecture-v2` at
`219c9f26a85b9661185cd78ab6308ae3f13e3ea7`, 77 commits ahead of fetched
`origin/feature/npu-architecture-v2` `5d01a88a8a2a7b1add15fbedbb02096d686824ab`
(tree `bf7306bdeefeca415dd221f0a29305fdcef5b72c`); source tree at audit was
`e2e3f1d1cc7dfa4de3e3d78fd51fab76d6c43f24`.
`main` remains R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`. Product RTL
remains at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. The Matrix/CNM UVM
fairness edit already present in the worktree was preserved and is not part
of the benchmark/report change.

The fixed TinyNPU reference `8216c22b762011aa20c05fc2768423fd12dda59d` and
NMAForge source `219c9f2` were used for the 3-point GEMM and 4-point GEMV
matrix, seed `20261106`; all 7 outputs sets match independent INT32 Goldens.
TinyNPU cycles are direct-array measurements. Its common-memory endpoint is
an explicitly labeled single-port estimate, not TinyNPU memory RTL. Results,
stall counters, commands, and archived raw logs are in
[`benchmark comparison`](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md)
and machine-readable CSV/JSON.

The fixed-address Digits workload touches offset `0x55C00` (351,232 bytes)
from the SPAD base. Its complete padded simultaneous data objects total at
least 79,776 bytes. Thus current addresses require 512 KiB; a compact remap
has a static 128 KiB fit but no remapped run exists, while 64 KiB requires
streaming/reuse. The current mini-CNN map reaches offset `0x21080` (135,296
bytes), so its present map needs 256 KiB. The capacity analysis is static;
no smaller-SPAD mapper, cycle, bank-conflict, or PPA result is claimed.

Minimum functional evidence is reused from fixed RTL/test records: clean Top
smoke, exact trained Digits MLP outputs, exact mini-CNN intermediates/output,
and the scoped 0x52/0x53 regressions. v2 remains a functional/performance
candidate; full DV sign-off and ASIC readiness remain open.

**Review date:** 2026-11-06
**R250 baseline:** `main` `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Review starting commit:** `eb158880d11bf7f8baf13ece4a888107877356fd`  
**Latest clean Compute Cluster DV candidate SHA:** `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree `630e498ba467d84dd5359403cfe1ed1e5879f6e9`; Top smoke, three-seed Cluster UVM and focused 0x52/0x53 replay). The broader 19-test UVM/URG merge remains separately bound to `f9f32f71e7168350d74a75ede0a4a4b222844cc9`. The `16×16×256` case still exceeds the unchanged watchdog before Golden.
**Latest Transformer fixture functional replay SHA:** `9b835aeac33d43fd97a81496b1048d359cdff3d0` (86 fixed-weight descriptors; 301 Golden checks). Trained-model inference and measured cycles/token remain NOT_RUN.
**Current report branch HEAD before this report update:** `d7ca7f3da6492ad9130178128a1e9d38d69d78d6` (tree `307a564f7e6c1ca4e627d37f6a9984ab155c4e24`).
**Current published v2 branch tip:** `origin/feature/npu-architecture-v2` `5d01a88a8a2a7b1add15fbedbb02096d686824ab` (tree `bf7306bdeefeca415dd221f0a29305fdcef5b72c`).
**Product RTL SHA:** `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; no RTL change is present in the fixed test source or report-only commits.

## Executive disposition

The v2 branch is based on the requested R250 `main` SHA. It adds product-path
Shape-Adaptive GEMV (`0x52`) and fused GEMM requant/tile forwarding (`0x53`)
using the existing Matrix controller and 16×16/256-MAC array. The branch does
not add a second MAC array or change the 64-byte ABI-v7 descriptor layout.
The named Matrix performance and tile-forwarding experiments have reproducible
Golden-checked VCS evidence.

This is a **bounded v2 functional/performance candidate**, not a v1.0 Compute
Cluster sign-off, full v2 verification closure, ASIC sign-off, or a TinyNPU
performance win. Keep the overall Compute Cluster disposition at **HOLD**.

### Phase 0 source/worktree audit — 2026-11-06 (prior snapshot)

The isolated target is `feature/npu-architecture-v2`, source SHA
`fed6c3f320705361bbbf761b99c73b36014cae77`, tree
`0625812c7f8b6852ad0bc3f52701b49e536062b5`, clean and 53 commits ahead of
`origin/feature/npu-architecture-v2`. A live `git ls-remote` confirmed that
GitHub `main` remains the requested R250 SHA
`3041355528dffe856e2d5384027c6ee5df5d1b42` and R250 is the target branch's
merge base. Local `main` is stale/divergent and was not used as the baseline.

The VS Code worktree remains at `/home/ray/workspace/NMAForge` on local branch
`feat/shape-adaptive-gemv-v2`, SHA
`c290eba7697138a4fcf2cbbac9262264849f0aeb`, tree
`a7b3821eb9e425927322f2b3729a3c12ad08d9d4`. Its tree matches remote
`origin/feat/shape-adaptive-gemv-v2` (`03b619ce1b32331c8f01194a42e5efb43bcda033`),
while its commit history is 63 commits ahead and one behind that remote ref.
Relative to target v2, it has a distinct history: merge base
`b5b6ff25ed41fb5ea4c9a5043360063cec58f7ac`, with 497 target-only commits and
64 `feat/shape-adaptive-gemv-v2`-only commits. The IDE worktree has untracked
`novas.conf` and `novas.rc`; both remain untouched. No merge, cherry-pick,
reset, or cleanup was performed.

Git reports 216 registered worktrees: 136 existing and 80 missing; 10 existing
worktrees have uncommitted changes, including the IDE worktree. The active v2
worktree was clean during this inventory. The other worktrees were left
untouched. The target v2 `.gitignore` covers simulator databases, credentials,
licensed-tool files, PDK/library formats, and Nova local settings. A tracked
path audit found no matching private file or generated simulation database.

R250-to-product RTL differences remain limited to six files
(`ai_tensor_matrix_array.sv`, `ai_tensor_matrix_core.v`, opcode decode,
descriptor validator, parallel dispatcher, and Compute Cluster integration):
662 insertions and 80 deletions. The last RTL commit remains
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; no RTL change exists from that
commit through this audit snapshot. Both `0x52` and `0x53` use the existing
shared Matrix controller/array; there is no second 256-MAC array.

**Audit PASS at that snapshot:** exact R250 ancestry, remote-ref identity,
worktree identity, the six-file RTL delta, last RTL SHA, clean target tree,
private-file ignore coverage, and unchanged product RTL after `cd0a05d`.
At that snapshot the local v2 branch was 53 commits ahead and had not been
pushed. See the later Phase 0 status refresh below for the updated count and
push result. The separate IDE branch was not merged.

### Phase 0 status refresh — 2026-11-06

The audit start `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` and R250 SHA
`3041355528dffe856e2d5384027c6ee5df5d1b42` are both ancestors of the target
branch. At the evidence-commit parent `30fd00f28555029584d361df5d81289f6cd6b7bc`
(tree `160fdc923ff5080754ffd11f23ff599d6cf58281`), the active worktree
`/tmp/nmaforge-architecture-v2` is clean on
`feature/npu-architecture-v2`. Its cached remote-tracking tip is
`5d01a88a8a2a7b1add15fbedbb02096d686824ab`; the branch is 63 commits ahead,
zero behind. The cached `origin/main` remains the requested R250 SHA. A normal
`git push origin feature/npu-architecture-v2` was attempted and failed because
Git could not read the HTTPS username (`No such device or address`); no remote
ref was changed.

The original IDE worktree remains on `feat/shape-adaptive-gemv-v2` at
`c290eba7697138a4fcf2cbbac9262264849f0aeb`, with only untracked
`novas.conf` and `novas.rc`. Its history is separate from the target branch:
the merge base is `b5b6ff25ed41fb5ea4c9a5043360063cec58f7ac`; relative to that
base, the IDE branch has 64 unique commits and the target branch has 507. No
merge or cherry-pick was made.

The full Git worktree inventory reports 216 registered paths: 136 exist and
80 are missing and marked prunable. Ten existing worktrees are dirty: the IDE
worktree, `/tmp/nmaforge-v2-gemv-baseline-8cff286`,
`/tmp/nmaforge_r153_clean`, `/tmp/nmaforge_r153_final_clean`,
`/tmp/nmaforge_r153_top_clean`, `/tmp/nmaforge_r160_subsystem_cov_34e0`,
`/tmp/nmaforge_r163_clean_f2e671d`, `/tmp/nmaforge_r164_clean_db7588b`,
`/tmp/nmaforge_r166_subsystem_clean_8be88c1`, and
`/tmp/nmaforge_r281_matrixfsm`. They were left untouched; no missing worktree
was pruned. The temporary clean replay worktrees created for the 16-seed and
merged URG runs were removed after archiving their text-only evidence.

The exact R250-to-target RTL diff remains six files and `662 insertions / 80
deletions`: Matrix array/core, opcode decode, descriptor validator, parallel
dispatcher, and Compute Cluster integration. The last product RTL commit is
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; `git diff` confirms no RTL changes
after it. The ignored/private-file audit in the prior Phase 0 section remains
valid; the new committed evidence consists of Markdown and JSON only.

**Refresh PASS:** review-start and R250 ancestry, current source/tree identity,
target branch/worktree cleanliness, full worktree inventory, exact R250 RTL
diff, and no product RTL changes after the recorded product commit.
**OPEN:** GitHub synchronization is blocked by missing HTTPS credentials; the
local target branch remains ahead 63. Dirty IDE/other worktrees and the 80
missing/prunable registrations were preserved.

### Phase 0 status refresh — current clean replay candidate `839b9af`

Before this report-only update, the target worktree was at
`d7ca7f3da6492ad9130178128a1e9d38d69d78d6` / tree
`307a564f7e6c1ca4e627d37f6a9984ab155c4e24`, clean on
`feature/npu-architecture-v2` and 71 commits ahead of its cached
remote-tracking tip `5d01a88a8a2a7b1add15fbedbb02096d686824ab`. The clean test
candidate used for the new VCS evidence is
`839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` / tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`; both the requested review start
and R250 remain ancestors of the target branch.

The live worktree inventory now reports 217 registered paths: 137 present
and 80 missing/prunable; 11 present worktrees are dirty, including this target
report worktree while its three benchmark artifacts are being added. The IDE
worktree remains on `feat/shape-adaptive-gemv-v2` at
`c290eba7697138a4fcf2cbbac9262264849f0aeb` / tree
`a7b3821eb9e425927322f2b3729a3c12ad08d9d4`, with only `novas.conf` and
`novas.rc` untracked. Its merge base with target v2 is
`b5b6ff25ed41fb5ea4c9a5043360063cec58f7ac`; target v2 has 515 unique commits
and the IDE branch 64. No other worktree was cleaned, merged, or changed.

Both requested ancestry checks pass. The R250-to-v2 RTL diff is still six
files (`662` insertions, `80` deletions), and the last product RTL commit
remains `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; no product RTL is changed
by this report/benchmark update. `.gitignore` checks confirm exclusions for
`.env`, private library content under `external/private`, and simulator
databases; the current tracked-file scan remains free of simulator databases
and matching private library artifacts.

### Latest real-Top GEMV tail-state cross — 2026-11-06

Testbench-only SHA `0e9f12ec3701030c9e5978ad29b227c5e0c644a7` closes the
declared eight-state M%4 × N%16 × K%16 alignment/tail cross on real opcode-0x52
CMDQ traffic. Each of the three Seeds hits all eight named bins and checks
independent signed INT32 outputs, output guards, completion, and accepted/
returned read ownership. Merged URG reports this focused group at 100%; full
profile coverage remains Line/Condition/FSM/Branch/Assert/Group
70.71/68.34/46.17/67.66/72.00/82.96%. This covers representative shapes in
each state, not every supported dimension, alias, fault, or lifecycle
combination. The entire v2 DV status remains IN PROGRESS and product RTL is
unchanged. Run command and archive hash are in the [DV closure
report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

### Latest real-CMDQ long-K GEMV — 2026-11-06

Testbench-only SHA `e944133b43107839e5f5eea902251097a228b312` also passes a
16×16×128 opcode-0x52 workload on Seeds 20261025/26/27. Each run compares all
256 signed INT32 outputs against an independent Golden, checks two guards and
ordered completion, and drains 448/448 accepted/returned Matrix reads. The
dedicated long-K functional group is 100%. Merged UVM URG line/condition/FSM/
branch/assert/group is `70.71/68.34/46.17/67.66/72.00/83.46%`; this remains
scoped evidence and does not close global v2 coverage. An attempted K=256
Top-CMDQ case exceeded the existing `MAX_TASK_CYCLES=2000` testbench bound
before a Golden result; no checker was relaxed, and K=256 remains open pending
latency-contract review. Product RTL is unchanged. Exact command and logs-only
archive hash are in the [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

### Latest fixed-source verification addendum — 2026-11-06

At fixed test source SHA `2999e03252c79aed66116b753b64ee7e389b9a56`, VCS
`V-2023.12-SP1_Full64` ran the real seven-engine Cluster UVM regression on
Seeds 20261106/07/08, the Matrix 0x52/0x53 focused campaigns on the same
Seeds, and the descriptor validator boundary suite. Cluster UVM passed all
seven engine-pair overlap bins (21/21), selected parity/protection/reset
crosses, and memory/response ownership checks. The Matrix campaigns passed
the six named GEMV shapes and selected opcode fault/handshake/tile-forward
bins with independent Golden checks. Descriptor boundary validation passed
43/43 accepts and 26/26 rejects. Run commands, archive hashes, URG results,
and scope limits are in the [v2 DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

These replays strengthen the named test evidence but do not close the full
REQ-V2 RTM. Partial WSTRB was not exercised (the Cluster scoreboard observed
full WSTRB only); several code-coverage and assertion bins remain unhit;
external-fabric response behavior, complete fault × phase × reset coverage,
and all-checker mutation mapping remain open. No test result is transferred
to a different SHA, and no product RTL changed.

### Latest real-CMDQ descriptor rejection replay — 2026-11-06

Testbench-only commit `c26064e3dda40ce26490c5c93b3e741529946c58` adds four
ABI-v7 opcode `0x52` malformed descriptors to the real Top CMDQ sequence:
output aliases padded A, output aliases dense B, 16-byte source misalignment,
and a 32-byte padded-A source span that actually wraps past `2^32`. Across
Seeds 20261109/10/11, all twelve invalid descriptors (eight legacy/engine
cases plus four GEMV cases) retire `ERR_DESC`; there are zero launch or
compute/DMA request cycles and all 24 sentinel/guard words remain unchanged.
The focused `cmdq_invalid_descriptor_cg` is 100% (12/12). Aggregate UVM URG
is Line/Condition/FSM/Branch/Assert/Group `69.65/63.34/45.62/58.03/72.00/79.18%`;
v2 remains IN PROGRESS. The first input attempt used K=1 and ended exactly at
`2^32`, so it correctly was not treated as a wrap; the committed test uses
K=17. Product RTL is unchanged. Full command, logs, and archive checksum are
recorded in [DV closure](../verification/NMAFORGE_V2_DV_CLOSURE.md).

### Latest legal 0x52 real-CMDQ replay — 2026-11-06

At source/test SHA `fd82e7323bbf73c428f1a1e72d784220f2440cd0`, the Top UVM
sequence executes an ABI-v7 `0x52` descriptor for M=3, N=5, K=5 through the
production CMDQ fetch, descriptor validator, Matrix dispatcher, shared
banked-SPAD path, and completion writer. Three seeds pass all 15 independent
INT32 Golden outputs, two destination guards, completion fields, and 8/8
accepted/returned Matrix reads. The M/N/K-tail group and its cross are 100%.

The first attempt did complete the command, but the passive UVM launch
monitor returned no launch sample because its opcode-to-engine mapping omitted
the new `0x52` and `0x53` Matrix opcodes. The monitor is now corrected; this
was a verification observability issue, not a product RTL issue. Product RTL
remains at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. The full command,
aggregate URG totals, and log archive checksum are in the
[DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

The 3×5×5 replay closes one legal CMDQ GEMV shape and single-engine response
drain; the 1×1×1 minimum boundary is tested separately below. Maximum
supported shapes, exhaustive legal tails, multi-engine 0x52 ownership, and the
complete fault × phase × reset matrix were open at that replay; later maximum-
tile and concurrent-owner replays are recorded below. v2 DV remains **IN PROGRESS**.

### Minimum legal GEMV boundary — 2026-11-06

The real Top CMDQ regression also executes opcode `0x52` at M=N=K=1 on fixed
source/test SHA `95301c46dfa6b9ee68f1e37a38f7767e3111d869` (tree
`abbb19e1c8205e3d8252e5685fd6ab6161970c3d`). Three Seeds pass signed
independent Golden outputs −2, −6, and −12, preserve the adjacent output guard,
check completion, and drain 2/2 accepted/returned operand lines. Its dedicated
minimum-shape URG bin is 100% (3/3 hits). This closes only the minimum
descriptor/data point; maximum-dimension execution was still open at this SHA
and is covered by the following replay. Full GEMV DV remains open. Product RTL
is unchanged.

### Maximum legal GEMV tile — 2026-11-06

At fixed test SHA `92874788fb2cb2a2b15657a3621e5a275a9d5990` (tree
`8ddbc13844b9bb2f262c88c471dd60a4e3bbd428`), the real Top CMDQ sequence runs
opcode `0x52` at M=N=K=16 on Seeds 20261118/19/20. Each Seed checks 256 signed
INT32 outputs against an independent Golden, two output guards, completion
status/result/elements, and 32 accepted/32 returned Matrix operand lines. The
dedicated maximum-tile functional group is 100% (3/3 hits); merged aggregate
Line/Condition/FSM/Branch/Assert/Group is 70.69/68.28/45.99/67.59/72.00/81.26%.
This proves the maximum descriptor/data point on the Top CMDQ path. Other
intermediate shapes, tail combinations, fault phases, concurrent response
ownership, and the v2 RTM remain open. Product RTL was not modified. Exact
command and log checksum are recorded in the [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

### Concurrent production GEMV + CNM response ownership — 2026-11-06

Testbench-only commit `85e7db2d12f5edfaed17e8ca3910bb504983779f` (tree
`e8f64f78f7986193bdc0d01dfbc01740a130edcb`) adds a second real Top CMDQ
descriptor beside the maximum legal 0x52 GEMV: opcode 0x21 CNM GEMV uses
disjoint source/destination regions. Three Seeds pass independent full output
Goldens, guards, ordered completions, 32/32 Matrix request/response ownership,
CNM accepted/returned read accounting, and zero Matrix/CNM response-route
mismatches. Each run observes 178 cycles with both engines busy; 18 same-cycle
request collisions were granted to CNM (Matrix/CNM grants 0/18). This records
the observed arbitration order; it is not a fairness or starvation proof.

The focused owner overlap/contention covergroup is 100%. Merged UVM URG is
Line/Condition/FSM/Branch/Assert/Group
`70.69/68.25/45.99/67.59/72.00/81.86%`; this does not close overall v2
coverage. Run ID, exact clean-worktree command, report details, and logs-only
archive checksum are recorded in the [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).
No product RTL changed; the product RTL SHA remains
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

### Phase 0 worktree relationship audit — 2026-11-06

The requested feature work was run in a separate worktree on
`feature/npu-architecture-v2`, currently tested through source SHA
`c26064e3dda40ce26490c5c93b3e741529946c58`. The original VS Code worktree at
`/home/ray/workspace/NMAForge` remains on `feat/shape-adaptive-gemv-v2`, HEAD
`c290eba7697138a4fcf2cbbac9262264849f0aeb`, tree
`a7b3821eb9e425927322f2b3729a3c12ad08d9d4`, and has two pre-existing
untracked files (`novas.conf`, `novas.rc`) which were preserved. The branches
are not interchangeable: their merge base is `b5b6ff25ed41fb5ea4c9a5043360063cec58f7ac`,
with 446 commits unique to the target feature branch and 64 unique to the
original `feat/shape-adaptive-gemv-v2` branch. No merge/cherry-pick was
performed. At audit time GitHub `main` still resolved to R250
`3041355528dffe856e2d5384027c6ee5df5d1b42`; the published v2 branch was
`5d01a88a8a2a7b1add15fbedbb02096d686824ab` (tree
`bf7306b...`).

### Latest v2 verification-only update — 2026-11-06

The current v2 product RTL was not changed. Testbench/mutation-runner commit
`ab96d47876beb4d7e47fef01e43b4c4716dd176a`
proved that all 18 selected opcode mutant-seed runs (six classes × three Seeds)
were caught, including request-address instability while `VALID&&!READY`.
Formal-only commit `b719ac6066616b17dfab4eed2429f8bdfdc49457` then proved the 0x52
request-hold property non-vacuously and reached its hold/release cover. These
results are scoped: v2 requirements, 0x53 lifecycle SVA, external response
ownership and sign-off remain open. Product RTL and benchmark results are
unchanged. Exact commands, RTM changes and archive checksums are in the [v2 DV
closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

### 0x53 forwarding commit/tag runtime SVA — 2026-11-06

At testbench/build commit `6a253386f53638a1206a75e359d6020ba27765cb`, VCS
`V-2023.12-SP1_Full64` passes two 0x53 forwarding SVA on Seeds
20261120/21/22: the full-capture commit and destination-tag property, plus
tag stability between commits. Each seed reports 2/2 assertions attempted,
zero failures, and three matches for the valid-tag cover. The existing six
named forwarding functional bins remain 100%, including the bit-exact
producer/consumer, tag miss, SPAD fallback, Bank Flip, Abort and Reset cases.

This is runtime assertion evidence on the real Matrix-core simulation, not a
formal proof of all forwarding lifecycle cases. `REQ-V2-COM-003` remains
PARTIAL; external fabric response ownership, broader legal fault/reset crosses
and full v2 sign-off remain open. The exact command and archive checksum are
recorded in the [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md). The archived ON/OFF evidence is SHA-256 `92efa5d9763114cc6fdf121d2b22744c06852ff6e9c66072503d054a53656f15`.

### Premature-valid SVA and checker-sensitivity mutations — 2026-11-06

Verification-only commit `ed17ab1c257c0f7947cf78e60730da31c4548138` adds a
third 0x53 assertion that rejects `tile_forward_valid` rising before the full
tagged capture commits. VCS `V-2023.12-SP1_Full64` passes the forwarding
ON/OFF regression for Seeds 20261123/24/25: the enabled profile has 3/3
assertions attempted, zero failures, three valid-rise cover matches per seed,
and all six named forwarding functional bins hit. The complete golden outputs
remain bit-exact.

The subsequent mutation runner at `4df2efeefafa49f6832af9bc7fa8a71005b28fa9`
passes seven injected RTL defects across those three seeds (21/21): output
data/address, operand response owner, WSTRB, bad tile tag, premature validity,
and a request-address change during backpressure. The tag mutant is now caught
by the earlier valid/tag SVA, so the expected checker mapping was updated to
that direct property. This does not complete mutation closure; all-v2-checker
mapping, broader legal fault/reset crosses, external response ownership and
overall v2 DV remain open. Exact commands and evidence archive checksums are
recorded in the [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

## Baseline and source audit

Remote `origin/main` resolves to the requested R250 SHA, and the merge base of
the current candidate and R250 is exactly that SHA. Review start
`eb158880d11bf7f8baf13ece4a888107877356fd` is an ancestor of the feature
branch. The local `main` ref is stale and divergent (22 local-only commits,
350 remote-only commits); all comparisons here use the explicit remote R250
SHA, not local `main`. The v2 branch contains 44 commits after R250 and no
baseline-only commits. Its delta has 73 tracked paths: 6 RTL, 12 DV, 3
software, 33 benchmark, 18 documentation, and 1 tool path.

The most recent product RTL change is
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23` (`fix(gemv): reject aliased
descriptor output spans`). The RTL tree has no diff from this commit through
candidate `ac6b83f`. Subsequent changes include Matrix and Top testbench/build
updates and SpyGlass project/triage updates; benchmark, review, and replay
commits are listed in the Phase 0 audit below. Every test result retains its
own source SHA instead of inheriting the documentation HEAD.

### Phase 0 candidate and worktree audit — 2026-11-05

| Item | Audited state |
|---|---|
| Target branch/worktree | `feature/npu-architecture-v2`, SHA `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164`, tree `dbf5060ac465ef4bb913543024182b298f675413`, clean, tracking `origin/feature/npu-architecture-v2` exactly. |
| Baseline | `origin/main` = R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`; target merge base is that SHA. |
| VS Code worktree | `/home/ray/workspace/NMAForge`, branch `feat/shape-adaptive-gemv-v2`, HEAD `c290eba7697138a4fcf2cbbac9262264849f0aeb`, tree `a7b3821eb9e425927322f2b3729a3c12ad08d9d4`; untracked `novas.conf` and `novas.rc` preserved. Its tree matches `origin/feat/shape-adaptive-gemv-v2` at `03b619ce1b32331c8f01194a42e5efb43bcda033`; that branch has two commits absent from the target v2 branch. Merge base with target v2 is `b5b6ff25ed41fb5ea4c9a5043360063cec58f7ac`; the refs have 2 shape-branch-only and 389 v2-branch-only commits. No merge or cherry-pick was made. |
| All registered worktrees | 204 registrations: 114 clean, 10 dirty, 80 missing/prunable. No worktree was cleaned or pruned. The other dirty paths are `/tmp/nmaforge-v2-gemv-baseline-8ff286` (Matrix TB edit), `/tmp/nmaforge_r153_clean` and `_final_clean` (`uvm/`), `/tmp/nmaforge_r153_top_clean` (`uvm_mutation/`), `/tmp/nmaforge_r160_subsystem_cov_34e0` (evidence/URG outputs), `/tmp/nmaforge_r163_clean_f2e671d` (evidence/UVM outputs), `/tmp/nmaforge_r164_clean_db7588b` (v1 report edits and CSV), `/tmp/nmaforge_r166_subsystem_clean_8be88c1` (coverage output), and `/tmp/nmaforge_r281_matrixfsm` (local `novas.conf`/`novas.rc`). All were left untouched. |
| Repository hygiene | Existing ignore rules cover VCS `simv*`, `.vdb`, `csrc`, logs/waves, SpyGlass databases, PDK/library formats, private keys, and `.env`. This audit adds ignore patterns for `*.lic`, `*.license`, `*.licence`, `license.dat`, `novas.conf`, and `novas.rc`; none of these paths is tracked. |

The six RTL paths changed from R250 are `ai_tensor_matrix_array.sv`,
`ai_tensor_matrix_core.v`, `ai_accel_opcode_decode.v`,
`ai_descriptor_validator.v`, `ai_parallel_compute_dispatcher.v`, and
`ai_accel_compute_cluster.v` (662 insertions, 80 deletions). This is an
additive Matrix mapping/validator/dispatch integration; the existing 16×16,
256-MAC array remains the only Matrix array. The exact opcode behavior and
limits are summarized below and specified in
[`NPU_ARCHITECTURE_V2_SPEC.md`](../spec/NPU_ARCHITECTURE_V2_SPEC.md).

#### Commit history after the last RTL change

The following 25 commits follow the last RTL commit. They contain verification
test/build updates, benchmark evidence, static-analysis setup, or reports;
there is no later RTL diff:

| Commit | Change |
|---|---|
| `d4d09ad58f882a5e2d59091073fd447bbb3dfaca` | Publish matched GEMV Cache×Prefetch ablation. |
| `9801cb606abdf1a76610cc3a5462c99c5b62ec7f` | Link evidence to published commits. |
| `453e5d2194e452eb1dc5e80ce95e8cf2043d058b` | Add Top CMDQ tile-forward differential. |
| `56de6a7aafa55db2e13127256d4983636341f55c` | Fix Matrix test ring-tail and GEMV profile expectations. |
| `8bae6168b64e06990f2f821cf4322a14ac4ae696` | Record license-restored VCS checks. |
| `eb158880d11bf7f8baf13ece4a888107877356fd` | Supersede blocked replay statuses. |
| `550ef39f22c22c39eb3bfd7f38dbc574b630e163` | Freeze baseline and correct TinyNPU ratio direction. |
| `52c1d2a75732b8d4c33191b0e3e85fc98d31d67c` | Record three-Seed Matrix sweep and ablation. |
| `3affab2611fc2075d3af180e60eddf829522b577` | Align GEMV tail test gate with emitted marker. |
| `15e901a46553b2b842d2ad1d391a94ef688600d2` | Add four-way Cache×Prefetch ablation target. |
| `b9d593e5f55869ff4a47748013a4b15dcd60f83f` | Use supported Python for GEMV summary. |
| `ae410661d4f31247be08f2e87ea761452e56a164` | Include M8 GEMV profiles in summary. |
| `a015f59a04a1efdd9b1debee6be7c7d12475b05e` | Record four-way GEMV ablation. |
| `33e85287fbf37187fccb76e97be6effe888670e9` | Add multi-Seed tile-forward regression target. |
| `145363ddff5141177421ee7429fc65f78834830d` | Archive architecture/model replay evidence. |
| `c3a59f08d8c07a8da973010d0f23d5d6d7eed61b` | Repair v2 SpyGlass source coverage and readiness report. |
| `be77e765d00dc607da74a82fa75a8ce5c8c5f251` | Replay paired TinyNPU GEMM and CNN. |
| `47e7340fc1a31193ae00ea5dc01d8d9a676df963` | Add paired small-M GEMV benchmark. |
| `0b1d33704f4895cf48b0f5e1d3f452d61b3df535` | Invoke the paired TinyNPU script through Bash. |
| `6b7d6462393ab25ce409c0491037ea8458055741` | Archive matched GEMV evidence. |
| `294ffec475c6da5ef140e9e35d0d30bafc4fc93b` | Refresh baseline and paired benchmark audit. |
| `18dad2ba4c502680893094bb726d88377d33eb9b` | Replay tile forwarding on the current branch. |
| `307eac8b1f148a0727833d35642a2d942ca15932` | Include GEMV in replay disposition. |
| `3a283c04724378c46747d907505eb82ea1ccbd4a` | Record current GEMV recovery replay. |
| `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` | Record clean Top CMDQ replay. |

The target branch is clean and exact with its remote. The R250 baseline ref is
unchanged. These checks confirm repository identity and history only; they do
not promote v1.0 or close v2 DV, model, or ASIC requirements.

The active integration top remains `rtl/top/ai_accel_top.v`. The v2 product
changes are concentrated in:

| Path | Role |
|---|---|
| `rtl/compute/matrix/ai_tensor_matrix_core.v` | Adds `0x52` K-fold GEMV, reuse/prefetch controls, fused `0x53` requantization, and bounded tile capture/consume. |
| `rtl/compute/matrix/ai_tensor_matrix_array.sv` | Maps GEMV output rows and K-fold lanes onto the existing array. |
| `rtl/control/descriptor/ai_accel_opcode_decode.v` | Classifies `0x52` and `0x53` as Matrix operations. |
| `rtl/control/descriptor/ai_descriptor_validator.v` | Validates the added opcode contracts, dimensions, addresses, spans, and alias restrictions. |
| `rtl/control/queue/ai_parallel_compute_dispatcher.v` | Routes both opcodes to the existing Matrix engine slot. |
| `rtl/top/fabric/compute/ai_accel_compute_cluster.v` | Wires the existing Matrix path; no new compute engine is instantiated. |
| `sw/include/cimforge_regs.h`, `sw/tools/cimforge_mapper.py` | Defines opcodes/flags and validates supported descriptor fields. |
| Matrix and top testbenches | Directed Golden, descriptor, output-image, completion, reset/Abort, and feature-ablation checks. |

The code paths preserve the existing AXI4/AXI4-Lite, CMDQ/CPLQ, four-bank
SPAD arbiter, and ABI-v7 descriptor layout. Opcode-level opt-in keeps the
legacy `0x30/0x31` Matrix contract separate. The current tests provide useful
legacy regression points, but they are not a complete proof of every legacy
opcode under every interaction.

## Opcode implementation audit

| Opcode | Implemented behavior | Descriptor constraints in current RTL | Verified subset |
|---|---|---|---|
| `0x52` | Signed INT8 GEMV mapped as K-fold work on the shared 16×16 Matrix array, with partial-sum reduction. Uses the existing 1 KiB reuse array for bounded B-fold caching, A-line reuse, and optional next-K prefetch. | ABI v7; exact `1≤M,N≤16`, `K≥1`; dense padded A rows and dense B rows; contiguous INT32 output; optional bias. Current product gate rejects transpose, nonzero strides, extra aux/flags, unsupported batch/head fields, address-span overflow, and output overlap with A/B/enabled bias. | Existing core shape/config checks plus real Top CMDQ Golden at M=N=K=1, 3×5×5 and 16×16×16; max point checks 256 outputs and 32/32 returned reads across three Seeds. Descriptor range/alias replay is archived separately; exhaustive shape/fault matrix remains open. |
| `0x53` | Matrix GEMM INT32 post-processing followed by signed INT8 requantization and native Matrix-A-layout output. `aux0[4:0]` is shift; `aux0[5]` opts into capture; `aux0[6]` opts into matching-tag consume. | ABI v7; upper aux bits zero; capture is bounded to M=N=16 and one tile; consume is bounded to M=16, K=4, no A transpose, and one tile. Exact source tag is required. A miss uses the regular SPAD path. Both producer and consumer retain SPAD writeback. | Three-Seed Matrix-core OFF/ON Golden ablation with capture backpressure, final-line commit, exact-tag hit/miss, ping-pong bank flip, reset invalidation, Abort invalidation, and drain. Three-Seed product Top CMDQ differential compares all output words/completions and source-A reads. |

The `0x52` validator computes half-open byte spans for padded A, dense B,
contiguous INT32 output, and enabled bias. It rejects output/input overlap and
wrapped spans; exact adjacent spans remain legal. The `0x53` local forwarding
storage is two banks × 16 lines × 128 bits = 512 B plus control state. These
are architectural RTL declarations, not synthesized area.

Detailed normative contract: [v2 architecture spec](../spec/NPU_ARCHITECTURE_V2_SPEC.md).
The inherited R250 system hierarchy and constraints are summarized in the
[Phase 0 baseline](NPU_ARCHITECTURE_V2_PHASE0_BASELINE.md).

## Reproduced evidence at named source identities

| Evidence | Source/test identity | Result | Boundary |
|---|---|---|---|
| 4×4/8×8/16×16 Matrix size and depth/prefetch/A-cache sweep | `550ef39f22c22c39eb3bfd7f38dbc574b630e163` | 165/165 Golden points pass across three Seeds. | Four-bank behavioral SPAD with one-cycle read latency; not ASIC timing. |
| Product GEMV B-fold cache × next-K prefetch | RTL/test `b9d593e5f55869ff4a47748013a4b15dcd60f83f` | 48/48 full output images pass; four shapes × four feature settings × three Seeds. | Seeded behavioral SPAD ready/response model; stall counters may overlap and are not summed. |
| Current-branch product GEMV shape regression | `307eac8b1f148a0727833d35642a2d942ca15932` | 15/15 Golden shape/Seed points pass: M4, M1/N-tail/K-tail, M8, M16 K19/K65 over three Seeds. | VCS Matrix-core regression with registered behavioral four-bank SPAD. |
| Current-branch Matrix core functional/fault regression | `307eac8b1f148a0727833d35642a2d942ca15932` | Three Seeds each pass 18 functional cases, 35 fault cases, and line contract checks. | Shared Matrix core lifecycle evidence; not a full feature-specific 0x52/0x53 fault matrix. |
| Tile-forward core OFF/ON | `294ffec475c6da5ef140e9e35d0d30bafc4fc93b` | 6/6 feature/Seed runs bit-exact. Mean consumer cycles 141→118; selected source-A reads 32→16 (512→256 B). | Matrix-core directed responder; no ASIC or whole-system inference. |
| Clean Top CMDQ `0x52` + `0x53` smoke | `3a283c04724378c46747d907505eb82ea1ccbd4a`, detached clean worktree | 3/3 Seeds `TEST PASS`; each checks `0x52` N/K tails and `0x53` image/completion differential. | Top behavioral SPAD; VCS `LOOP-REROLL-ENABLED` notice remains. |
| Current-candidate descriptor boundary/alias suite | `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` | 29 opcode legal cases; 33 invalid rules; accepted boundaries 43/43; rejected boundaries 26/26; tile-forward descriptors 3/3. | `V2-DESC-VALIDATOR-AC6B83F`, VCS `V-2023.12-SP1_Full64`; scope is directed validator checks. |
| Trained Digits MLP, R250 vs v2 | R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`; v2 `33e85287fbf37187fccb76e97be6effe888670e9` | Same model, seed and Golden; 352/360 correct and byte-identical RTL logits. CMDQ interval 110,155→34,761 cycles (−68.44%). | Real top RTL with testbench-preloaded behavioral SPAD; timing and byte counters are scoped in the model report. |
| Paired TinyNPU GEMM/CNN | NMAForge `c3a59f08d8c07a8da973010d0f23d5d6d7eed61b`; TinyNPU `8216c22b762011aa20c05fc2768423fd12dda59d` | Three paired GEMM shapes pass Golden; Tiny engine regression 6/6; same ONNX mini CNN passes Golden on both. GEMM NMA/Tiny-modeled ratios are 1.1391/1.1385/1.0659. | VCS + Verilator RTL simulation; Tiny memory endpoint is modeled, CNN timing windows differ; no general speedup claim. |
| Paired small-M GEMV | NMAForge `0b1d33704f4895cf48b0f5e1d3f452d61b3df535`; TinyNPU `8216c22b762011aa20c05fc2768423fd12dda59d` | `1×13×17` and `8×16×19` pass Golden. NMA measured cycles 76/158; Tiny direct array 100/100 and serialized modeled endpoint 126/170. | TinyNPU uses padded direct-array mapping and has no tested product GEMV/SPAD path; ratios 0.6032/0.9294 are mixed-boundary only. |
| Static analysis and Matrix FSM guards | RTL/test `145363ddff5141177421ee7429fc65f78834830d` | SpyGlass lint 0 errors/465 warnings; CDC 0 unsynchronized crossings/2 warnings; targeted Matrix formal 5/5 non-vacuous assertions and 2/2 covers. RDC timed out; PPA not run. | Scope and exact commands are in the [ASIC readiness report](../verification/NMAFORGE_V2_ASIC_READINESS.md). |

Exact Top/core commands and raw evidence locations are in the [multi-Seed
replay record](../verification/V2_P2_TILE_FORWARD_MULTISEED_REPLAY_2026-11-05.md).
Current-SHA GEMV, descriptor, and Matrix core fault run identities are in the
[v2 DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).
The Matrix size sweep and GEMV ablation details are in the [P1 benchmark
report](../benchmark/NMAFORGE_V2_P1_MATRIX_BENCHMARK.md) and [GEMV
ablation](../benchmark/NMAFORGE_V2_GEMV_CACHE_PREFETCH_ABLATION.md).

## Review findings and open work

- No RTL evidence justifies a second array. The measured B-fold cache is the
  dominant tested GEMV improvement; next-K prefetch provides smaller,
  workload-dependent gains. A new bank-aware issue scheduler has not been
  justified by a controlled bank-conflict experiment and remains unimplemented.
- `0x52` now has six named shapes, descriptor accept/reject boundaries,
  selected request backpressure, and selected fault recovery at the fixed
  source SHA. Remaining: broader legal N/K tail combinations, runtime alias
  execution/sentinel checks, all-phase fault/reset crosses, and concurrent
  engine response ownership tied directly to opcode requests.
- `0x53` now has selected tag hit/miss, Bank Flip, repeated-consumer fallback,
  reset epoch, parity/protection recovery, held line-write, and three runtime
  assertions. Remaining: arbitrary held-response timing, Completion fault
  injection, broader cross-engine coherence and complete reset/fault phase
  coverage. Its 512 B local storage has no current-candidate DC
  area/Fmax/power result.
- VCS functional Golden checks are not coverage closure. A merged current-SHA
  requirement RTM, functional/code coverage disposition, non-vacuity audit,
  and mutation report for every new checker are not complete.
- The TinyNPU tools are now available and the named GEMM/CNN and small-M GEMV
  replays have passed at the source identities above. A true TinyNPU memory
  adapter, broader GEMV shapes, trained-weight CNN/Transformer comparisons,
  and phase-aligned system endpoints remain open; mixed modeled results are
  not a product-level win claim.
- DC, formal/LEC, CDC/RDC, SRAM mapping, DFT readiness, power and physical PPA
  are not closed by these VCS runs. ASIC readiness remains `NOT_RUN` or
  `BLOCKED_ENV` by individual tool/input; do not claim Tapeout Ready.
- v1.0 Compute Cluster stays **HOLD**. This branch's scoped v2 tests do not
  resolve the inherited 38-requirement sign-off record.
- The matched trained Digits MLP replay is a scoped model result, not a
  TinyNPU comparison. A four-class Digits CNN with trained convolution filters
  now passes all 159 held-out inputs through Top CMDQ and matches its
  independent integer Golden, but this is not a ten-class result or a TinyNPU
  comparison. The 86-descriptor Transformer functional fixture passes; its
  deterministic test weights are not trained weights. Separate
  Host/DMA/Compute/Writeback/Graph phase counters and trained Transformer
  inference remain open.

## Current decision

Continue v2 on this isolated feature branch with reproducible benchmark and
verification increments. Preserve R250 `main` untouched. The next useful
closure is the remaining fixed-SHA v2 RTM/fault matrix, runtime alias and
response-ownership checks, and disposition of unhit legal coverage/assertion
bins. The existing Top-level contention result is useful baseline evidence,
but no alternate scheduler is justified. Proceed to later model and PPA work
only after Phase 1 closure or a formally reviewed scope disposition.

## Follow-up exact-candidate audit and replay — 2026-11-05

- The target code/test worktree started this increment at `917af306cdc30ccabd608f5a3e94023cfd0b27e7`, exactly matching `origin/feature/npu-architecture-v2`; the test-only commit is `0870a76b803ad01b8c23d812cfddd9cbb399f74e`, tree `bb7b6acef1e4262c7facd0b259b9f413cd559975`. The RTL path diff from `917af30` to `0870a76` is empty. The new source paths are `dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv` and `dv/subsystem/top_smoke/sim/Makefile`.
- `origin/main` remains R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`; local `main` is stale at `585f3a162c6a80b822563dc30f05a54332041539` (22 local-only / 350 remote-only commits), so baseline comparisons continue to use `origin/main`. Target v2 and `origin/feat/shape-adaptive-gemv-v2` differ by 402 target-only and 2 shape-branch-only commits at this audit; no merge/cherry-pick was performed.
- The IDE worktree `/home/ray/workspace/NMAForge` remains on `feat/shape-adaptive-gemv-v2` at `c290eba7697138a4fcf2cbbac9262264849f0aeb`, with user-owned untracked `novas.conf` and `novas.rc`; neither was touched. A fresh inventory found 204 registered worktrees: 124 present and 80 missing/prunable. Ten other present worktrees contain uncommitted user/generated files, listed in the earlier Phase 0 audit; they were left untouched.
- Fixed-SHA Top Smoke passes on seeds 20261105/06/07. The new `0x53` legal Matrix+SFU scenario sees 23 accepted SFU SPAD accesses during Matrix consume per seed; source and output-image checks are bit-exact. Logs archive SHA-256: `fb2f2d70128fc919a4d767b11c1257024760a3e9b5019a68b44286cef78662c2`.
- Current-SHA VCS/URG DUT-only Top coverage (27 module definitions, three Seeds) is 86.75% Line, 77.62% Condition, 44.33% FSM and 84.56% Branch; Matrix core has 15/15 states and 25/55 transitions. The four existing AXI-memory testbench groups are at 0%, and no v2 feature covergroups exist. These results do not close functional coverage or FSM disposition. Coverage archive SHA-256: `691b2e6b5b896a5ec1638796939899ba751a43f1611edc6386dd550bddc052f0`.
- Exact run IDs, commands and limits are in the [v2 DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md). This increment establishes legal unrelated-region Matrix+SFU concurrency and code-coverage evidence only; it does not establish DMA overwrite handling, full ownership crosses, v2 DV sign-off, ASIC PPA or TinyNPU superiority.

## Follow-up functional coverage at `86e0d6c` — 2026-11-05

- Added a VCS functional covergroup for the legal 0x53 Matrix+SFU handoff. Its sampled bins check Matrix/SFU overlap, at least one accepted SFU SPAD access while Matrix consumes, no compute-client attempt to write the tagged source, bit-exact output checks, and overlap × access cross. The Top Smoke gate fails unless this group reaches 100% for the directed scenario.
- `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105` passes. `make ai_compute_cluster_cov AI_CLUSTER_COV_RUN=/tmp/nmaforge_v2_86e0d6c_dut_cov AI_CLUSTER_COV_SEEDS='20261105 20261106 20261107' AI_RANDOM_CASES=4` also passes all three seeds and URG merge. VCS/URG is `V-2023.12-SP1_Full64`.
- The new group is 100% in each run and merged. The four existing AXI-memory covergroups are 0%, so overall functional-group coverage is 20%. DUT-only Line/Condition/FSM/Branch is 86.75/77.62/44.33/84.56%; Matrix core FSM is 15/15 states and 25/55 transitions. This is scoped coverage, not complete legal-v2 coverage or FSM closure.
- Test-only commit `86e0d6cbba3187bd1deeb18f664c559b606c878d` (tree `497eaef649c3995c97cb533a9c410417d63ee0de`). No product RTL changed. Coverage archive SHA-256 `eb25d2725fa8e3252c0140d0c7254c3abfc03fd1ef44d1ecbd2283e75becd4f8`; the exact record is in the [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).
- `REQ-V2-053-007` remains **PARTIAL** because DMA overwrite, additional engine pairings, held-response ownership, and fault/reset crosses are untested. The aggregate `REQ-V2-COM-004` remains **PARTIAL** because feature-wide bins and residual FSM transitions are open.

## Follow-up actual DUT mutation replay at `bdfda3c` — 2026-11-05

- The existing UVM mutation harness compiled temporary RTL copies and injected seven real DUT defects: shared-SPAD address, data and response owner; Matrix WSTRB; Completion error code; missing Done; and duplicate Done. Each was caught by its assigned scoreboard/checker (7/7) at seed 20261025; the source worktree remained unchanged.
- Exact command, VCS version, Run ID, checker names and archive SHA-256 are recorded in the [v2 DV closure RTM](../verification/NMAFORGE_V2_DV_CLOSURE.md). The earlier opcode-core mutation suite separately remains 15/15 across three seeds.
- `REQ-V2-COM-005` remains **PARTIAL**: the selected Completion and engine-owner faults now have direct evidence, while mutation mapping for every new-feature checker and wider fault-phase interactions remain open. No sign-off or RTL behavior change is claimed.

## Current clean-worktree compatibility replay — 2026-11-06

At candidate SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`), a detached clean-worktree Top
Smoke replay passed with VCS `V-2023.12-SP1_Full64`. It exercised legacy paths,
three product GEMV descriptors, the `0x53` producer/consumer path, Matrix/SFU
cross-engine immutability, and the Matrix/CNM profiling scenario. The simulator
reported `TEST PASS` and no `ERROR:` lines; the known fixture
`LOOP-REROLL-ENABLED` compile notice remains. This is a compatibility smoke
result only; it adds no RTM closure and does not change the identified product
RTL SHA. Details and checksums are in the [DV closure evidence](../verification/NMAFORGE_V2_DV_CLOSURE.md)
and [machine record](../../benchmark/v2_top_smoke_clean_839b9af.json).

The same candidate SHA/tree also passes clean-worktree three-seed
`uvm_compute_cluster_regress` for Seeds 20261128/29/30 with zero UVM
Warning/Error/Fatal. The nine Matrix profile state partitions close, but URG
functional group coverage is 83.94%, five assertions are uncovered, and only
one of three cover properties matches. Thus the reproducible baseline is
stronger, while the remaining v2 DV evidence still prevents full closure. See
the [DV report](../verification/NMAFORGE_V2_DV_CLOSURE.md), [performance
report](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md), and [run
metadata](../../benchmark/v2_clean_cluster_uvm_839b9af.json).

## Follow-up system-level contention benchmark at `17b09e0` — 2026-11-05

- The real Compute Cluster UVM regression passes Seeds 20261025/26/27 with the shared `ai_spad_arbiter`, all seven engines, independent Golden checks and ordered CMDQ completions. Same four-task serial/parallel work measures 1,696/1,137 RTL cycles (ratio 1.492; equal 4,352 B read and 2,688 B write traffic). The three-task staged case measures 1,239/1,070 cycles (ratio 1.158).
- Real Matrix/CNM contention produces 333 observation cycles, 320 admitted collisions, 320 Matrix wait cycles, and 320 held-payload checks with zero ownership/stability violations. This establishes contention under the current policy but does not compare an alternative scheduler or justify new RTL. Detailed boundaries and machine data are in the [performance report](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).
- Run ID `V2-CLUSTER-SERIAL-PARALLEL-CONTENTION-3SEED-17B09E0`; source/test SHA `17b09e068e988ca35480ffd638d865872e9ba564`; logs archive SHA-256 `a2c2daa85ba57c1617239498c60636763584707f43bb93c345f5e01f7c6d8fbe`.

## Current exact-candidate verification and benchmark replay — `410b81d`

The isolated worktree tested source/test SHA
`410b81dfd37992a760b28258bb7e8c6b6f5017d7`, tree
`e608e788cf5cc49165d835003c87920259cc84b4`. Direct `git ls-remote` showed
published v2 branch commit `6862c68035387fe70441b617b6797b6e070963a6` with
that same tree; R250 `main` remains `3041355528dffe856e2d5384027c6ee5df5d1b42`.
The IDE worktree was not changed. This increment made no product RTL changes;
the only code addition is a CSV/JSON/SVG merger for already completed
three-seed GEMV measurements, alongside evidence/report files.

The current `git worktree list --porcelain` inventory reports 204 registrations:
124 present and 80 missing. Eleven present worktrees have changes: this v2
worktree (the report and benchmark files being prepared), the IDE worktree
`/home/ray/workspace/NMAForge` (two pre-existing untracked files), and nine
other pre-existing research/evidence worktrees. No other worktree was cleaned,
pruned, reset, or edited. `.gitignore` still covers simulator databases,
license files, `.env`, `novas.conf`/`novas.rc`, and library/database extensions.

- Matrix 0x52/0x53 focused suite, Top Smoke, real seven-engine Cluster UVM,
  three-seed URG, 15 opcode-core mutations and seven real Cluster DUT
  mutations ran with VCS `V-2023.12-SP1_Full64`. Current run IDs, commands,
  scoped coverage and caveats are in the
  [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).
- A follow-up three-seed run at report/test SHA `f340acaa2cdf7c36075473b8bc6fd6dee8e59873`
  passes coordinated reset/epoch checks for the repository's
  `ai_accel_memory_fabric`: DMA reads outstanding, accepted CNM SPAD response
  owner flush, CNM pending-result-write reset, then fresh DMA/CNM Golden
  recovery. The three named reset functional groups are 100%; owner/tag
  assertions have real successes and zero failures. This is not a claim about
  arbitrary external SoC fabrics, opcode-specific fault/reset closure, or full
  v2 sign-off. Evidence archive SHA-256 is
  `14144bdc62932d8040a1b5be72b27f83e6f4f8e52286a8658b1570fdfe3717c5`.
- A clean current-source Top Smoke compatibility replay at
  `5f6e282f191b421bdbefc3d252690a9a0c93eb1c` passes three Seeds with 20
  randomized cases each. It checks legacy `0x30` Tensor GEMM and `0x31`
  two-head Batch GEMM Golden outputs as well as existing v2 Top cases. This
  closes `REQ-V2-COM-002` for the tested modes/shapes only; broad legacy aux,
  shape and fault-interaction coverage remains open. Logs archive SHA-256:
  `a56378fc6a1364ee4fdcc8f34dcf21b47068270d473ba7b848cdaef6b2a65b3c`.
- The four-way GEMV ablation passed 48/48 bit-exact Golden points and exact
  exclusive-state cycle partition at this candidate. Its machine records are
  [CSV](../../benchmark/v2_p2_gemv_cache_prefetch_4way_410b81d.csv),
  [JSON](../../benchmark/v2_p2_gemv_cache_prefetch_4way_410b81d_summary.json)
  and [SVG](../../benchmark/v2_p2_gemv_cache_prefetch_4way_410b81d.svg).
- The seven-engine UVM measured one four-task serial/parallel workload at
  1,696/1,137 cycles with equal 4,352 B read and 2,688 B write traffic. This
  is overlap under the existing scheduler, not an alternate-arbiter result.
  The [machine summary](../../benchmark/v2_p2_cluster_serial_parallel_410b81d_summary.json)
  records its one-workload, behavioral-SPAD boundary.
- The trained Digits model was rerun at this fixed source/test SHA and remains
  bit-exact with 352/360 classifications and 34,761 CMDQ cycles. A later
  bounded four-class CNN demo is recorded below; it has fixed convolution
  filters and a trained readout, so full trained-CNN and Transformer deployment
  are not closed.
- Current-candidate SpyGlass lint completed with 0 errors, 465 warnings and 5
  infos. CDC setup stalled without producing a report; bounded RDC stopped at
  `Ar_resetcross01`. The open reset release contract and wide-mux analysis
  limitation are detailed in the [ASIC readiness report](../verification/NMAFORGE_V2_ASIC_READINESS.md).
- A current-HEAD NMAForge replay at docs-only descendant `d1867da` rechecked
  three pinned TinyNPU GEMM vectors and the fixed `conv1x_mini` graph. All
  NMAForge Golden checks pass; the measured/modelled GEMM ratios remain above
  1.0 and CNN timing boundaries differ. See the machine data and limits in the
  [performance](../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md) and
  [model](../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md) reports.

The active branch remains a v2 architecture candidate: v1.0 Compute Cluster
is **HOLD**, v2 feature-wide DV closure is **IN PROGRESS**, TinyNPU parity is
not established, and ASIC readiness is **NOT READY**.

## Named functional-coverage follow-up — 2026-11-06

Testbench/build commit `380f96114dba022300db09fb217264c3a606a2fd` keeps the
two selected innovations on the shared Matrix array and adds directed feature
coverage only: GEMV six-shape tails, selected opcode fault recovery, and
repeated-consumer tile forwarding. Three same-profile URG groups report 100%
over 12 tests; the Prefetch-OFF result is separately reported. Product RTL and
all existing performance/model measurements are unchanged. The covered bins
do not close all 0x52/0x53 descriptor variants, legal cross-engine fault
combinations, or system-level assertions. The v2 decision remains a bounded
candidate, not full DV sign-off; details and archive checksum are in the
[DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

## Trained CNN demo and compatibility smoke — 2026-11-06

- Test/build commit `835f958b5f486b3f3e4808e735a788721f4f1441`; no product RTL
  changed. The four-class Digits demo uses fixed edge filters and a trained
  INT8 head. Its initial one-sample replay was later expanded at `de22e46` to
  all 159 held-out cases through separate real Top CMDQ runs; each stage and
  final logits match an independent Golden, with 158/159 hardware-checked
  classifications correct. This remains a scoped demo, not a fully trained
  convolutional network.
- VCS `V-2023.12-SP1_Full64`: `ai_trained_cnn_demo`, fixed TinyNPU CNN
  compatibility replay and `ai_smoke` all pass. Smoke includes legacy GEMM,
  opcode 0x52/0x53 and CNM markers; existing `LOOP-REROLL-ENABLED` note remains
  and no new compile error was observed.
- Machine record:
  [CSV](../../benchmark/v2_trained_cnn_demo_835f958.csv) and
  [JSON](../../benchmark/v2_trained_cnn_demo_835f958.json). The trained
  Transformer, stage-separated full-model timing, full v2 DV closure and ASIC
  readiness remain open.

## Full held-out CNN Top replay — 2026-11-06

- Test harness commit `de22e4652a54dfe7537e14585bdf3ae6f08fe9fb`, tree
  `29d35cadabd84872081dc7f6d51a7398cfb431b5`; product RTL is unchanged.
- Run ID `V2-TRAINED-CNN-TOP-DATASET-DE22E46`: 159/159 Top CMDQ instances
  passed, all intermediate and output Golden checks exact, 158/159 classified
  correctly. Each sample uses 1,985 compute cycles plus 1,080 host-layout
  cycles in the behavior-SPAD testbench.
- Per-sample CSV and run summary:
  [CSV](../../benchmark/v2_trained_cnn_dataset_de22e46.csv),
  [JSON](../../benchmark/v2_trained_cnn_dataset_de22e46.json). All run logs,
  model, inputs and Goldens archive SHA-256
  `dfacc9a6a7e17150def4814cfe9baad11b8c21675d75db1505c0b907c80de1be`.
- Four convolution filters remain fixed; only the classifier head is trained.
  No TinyNPU comparison, trained Transformer, full timing decomposition, DV
  sign-off, or ASIC readiness is claimed.

## Current model and Top compatibility evidence — 2026-11-06

- At model/tooling source SHA `9b835aeac33d43fd97a81496b1048d359cdff3d0`,
  the four shared 3×3 convolution filters and INT8 classifier are both trained.
  All 159 held-out Digits labels 0–3 passed separate real Top CMDQ runs with
  every checked intermediate and final integer Golden exact (159/159 correct).
  This remains a four-class scope, not a ten-class model or TinyNPU result.
- The existing 86-descriptor Transformer prefill/decode fixture passes the Top
  path and its intermediate/KV Golden checks at the same source SHA. Its weights
  are deterministic test weights; trained-model inference and cycles/token are
  still NOT_RUN.
- `ai_smoke` plus three 20-random-workload Top runs pass on the same candidate.
  These are compatibility/smoke results only; they do not alter the v2 URG/RTM
  status of 14 PASS-scoped / 8 PARTIAL.
- Machine evidence is in the [model report](../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md)
  and [Top compatibility record](../../benchmark/v2_top_smoke_compat_9b835ae.json).
  Product RTL remains unchanged at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`;
  v2 DV remains IN PROGRESS and ASIC PPA remains BLOCKED_ENV/NOT_RUN.

## Post-review fixed-candidate validation — 2026-11-06

- At testbench/tooling SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5`, three
  clean Compute Cluster UVM seeds exercise `0x52` with `srcA == srcB`; all
  256 source bytes remain unchanged, 16 signed INT32 outputs match Golden,
  both guards and completion pass, and Matrix read ownership drains 17/17.
- The same fixed SHA passes Top `ai_smoke` and three `ai_run` regressions with
  20 random workloads each. This confirms the exercised legacy and `0x52`/
  `0x53` smoke paths remain functional after the testbench addition. It does
  not close the RTM's remaining partials or add a coverage merge.
- Its real-Top matched UVM workload also reproduces 1.158× staged and 1.492×
  queued/parallel cycle ratios with unchanged SPAD byte counts; this remains a
  behavioral-SPAD NMAForge comparison, not TinyNPU or ASIC evidence.
- Machine records: [GEMV alias](../../benchmark/v2_cmdq_gemv_ab_alias_f19e929.json)
  and [Top compatibility](../../benchmark/v2_top_smoke_compat_f19e929.json).
  Matched workload metrics are in [CSV](../../benchmark/v2_p2_cluster_serial_parallel_f19e929.csv)
  and [JSON](../../benchmark/v2_p2_cluster_serial_parallel_f19e929.json).
  Full evidence and limits are in the [DV closure report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

## GitHub publication check — 2026-11-06

At local commit `36c42c2827acb7a8267aacd9cf0f253271c72d0f`, the v2 branch was
55 commits ahead of `origin/feature/npu-architecture-v2`. The authorized push
command `git push origin HEAD:refs/heads/feature/npu-architecture-v2` failed
with exit 128 because this non-interactive environment could not read the
GitHub HTTPS username. A live read-only `git ls-remote` afterward confirmed
that the remote v2 ref remains `5d01a88a8a2a7b1add15fbedbb02096d686824ab` and
`main` remains R250. No remote ref was changed. Local commits remain intact;
publication is **BLOCKED_AUTH** pending GitHub credentials in the execution
environment.

## Current-candidate focused feature replay — 2026-11-06

At clean source SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`, the 0x52 GEMV,
0x52/0x53 fault recovery, handshake, Tile Forwarding ON/OFF, and temporary RTL
mutation targets pass three Seeds. Each Seed passes six GEMV shape bins, eight
selected fault bins, two handshake bins, and six enabled tile-forward bins;
tile SVA is attempted 3/3 with no failures, and the seven mutation classes are
caught in all Seeds (21/21). These are scoped core results: full fault-phase-
reset crosses, external response timing, all-engine ownership pairs, and
exhaustive checker-to-mutation mapping remain open. The overall v2 RTM stays
14 PASS-scoped / 8 PARTIAL. Evidence is in the [DV report](../verification/NMAFORGE_V2_DV_CLOSURE.md)
and [machine record](../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json).

## Same-SHA mixed UVM coverage merge — `839b9af`

The mixed AXI/DMA E2E matrix was rerun at the same clean candidate as the
three-seed Compute Cluster UVM regression. The 19-test URG merge reaches
36/36 declared functional groups (100%) and matches all three AR/AW/W
stall-to-accept cover properties. RTL code Line/Condition/FSM/Branch remains
`74.15/71.55/47.45/71.14%`; 20/22 assertions have successes and two UVM RAL
assertions have no attempts. This closes the declared groups in this test
plan, not all code/FSM bins or v2 requirements: the RTM remains 14
PASS-scoped / 8 PARTIAL. The exact evidence is in the [DV report](../verification/NMAFORGE_V2_DV_CLOSURE.md)
and [machine JSON](../../benchmark/v2_clean_urg_19test_839b9af.json).

The subsequent authorized Git push attempt at local commit
`325fe78bead175fc4eda1fae2ed74929f61ba331` failed before authentication:
Git could not read the GitHub HTTPS username. The v2 branch remained 73 commits
ahead of its cached remote ref at the time; no remote update is claimed.
