# NMAForge execution frontier

## Round 5 terminal disposition — 2026-11-07

This fixed comparison round is complete and **stops here**. Reviewed base
source/test SHA and initial GitHub target HEAD were both
`73caef0f32140d1635816f1eb4ea28372523e80c`; the TinyNPU reference remains
`8216c22b762011aa20c05fc2768423fd12dda59d`. `main` R250 and unrelated
worktrees were not modified.

Completed evidence: paired NMAForge/TinyNPU `conv1x_mini` Golden replay;
current-source 3 GEMM + 4 GEMV NMAForge/TinyNPU Direct Array cases, all
Golden-pass; 396-sample ten-class CNN Legacy/Linear-Row comparison; baseline
Transformer H4 GEMM path, 301/301 pass; and the opt-in Transformer `0x52`
Q/K/V experiment, recorded as FAIL with 175 Decode mismatches. Same-system
CNN speedups are reported. No cross-system TinyNPU speedup is claimed because
the memory/controller and graph timing boundaries differ.

The available TSMC28 / DC environment was checked. The bounded Matrix Core
mapping attempts did not produce valid synthesis reports; no 300/400/450 MHz
PPA result is claimed. Catalog-only 128/512 KiB macro area is reported with
the single-port-vs-dual-port limitation. The fixed evidence, scripts, and
remaining limitations are in
[`NMAFORGE_V2_ROUND5_FINAL_COMPARISON.md`](../../benchmark/NMAFORGE_V2_ROUND5_FINAL_COMPARISON.md)
and `benchmark/v2_round5_*_20261107.*`.

Final state is `RESEARCH_BASELINE_PARTIAL`. Do not auto-start another DV,
RTL, Transformer, benchmark, or synthesis phase after this publication.

## Focused Research Round 3 — delivery snapshot, 2026-11-06

Implementation candidate `4dab73646989615c5479de0bac76d1488a102758` adds the
deterministic trained INT8 micro-Transformer flow and bounded `0x53 aux0[7]`
linear-row output layout. The run uses the existing 16×16 array, 256 INT8
MACs, four-bank SPAD, AXI/CMDQ/CPLQ, and ABI-v7; no new compute engine or
second array is added.

The 128 KiB Transformer-only Top run passes 86 descriptors and 301
intermediate/final/KV Goldens (5,682 Prefill / 5,715 one-token Decode cycles).
The ten-class CNN legacy and linear-row runs each pass all 396 Top samples
against independent Goldens and classify 384/396. Per-sample measurements are
in the model report. The new linear-row path moves total task interval from
4,273 to 2,712 cycles by combining fused requant and consumer-ready output
layout; this result does not isolate the two mechanisms. Existing GEMV
Cache×Prefetch and Tile Forwarding ablations remain bound to their original
run SHAs; no new GEMV-heavy Transformer decode ablation was run.

`ai_smoke` passes on seed `20261106`; VCS is `V-2023.12-SP1_Full64`. PPA is
`BLOCKED_ENV` (no public foundry SRAM/library/SDC set), TinyNPU system-level
speedup is unproven, and full v2 DV sign-off remains open. Implementation
commit is `4dab73646989615c5479de0bac76d1488a102758`. Final Round 3 report
commit and remote branch head are in the handoff. **Stop condition:** after
publishing this bounded report package, do not automatically start another
RTL, coverage, model, or ASIC phase.

## Research finalization stop point — 2026-11-06

**Final disposition: `RESEARCH_BASELINE_PARTIAL`; this task stops here.** The
fixed deliverables completed in this round are the ten-class trained Digits
CNN Top replay (396/396 exact intermediate Golden passes, 96.97% held-out
accuracy), the fixed TinyNPU GEMM/GEMV evidence carried with its original
source SHA and endpoint limits, `conv1x_mini` Golden validation, a passing
Top smoke, and 128 KiB/512 KiB behavioral-SPAD replays for two CNN workloads.
The compact profile keeps four banks, 128-bit lines, and the existing 256-MAC
array. Product RTL remains at SHA
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; R250 `main` remains
`3041355528dffe856e2d5384027c6ee5df5d1b42`.

Not complete: trained-weight Transformer Demo; TinyNPU graph-runtime CNN
cycles; 256/64 KiB RTL model runs; reduced-capacity Digits MLP/Transformer
replay; complete DV closure; and DC/physical PPA. No new RTL compute engine
or product RTL change was made. The final report package includes the
Architecture Walkthrough, benchmark/model/DV/ASIC snapshots, per-sample CNN
CSVs, and machine-readable capacity CSV/JSON.

VCS Top smoke Run ID `TOP-SMOKE-9EE5879-S20261106`, source/test SHA
`9ee5879edec64644e33386aae6bba9b3885d3b07`, seed `20261106`, VCS
`V-2023.12-SP1_Full64`; result `TEST PASS`. Capacity/model Run ID
`V2-SPAD-CAPACITY-STUDY-20261106-9576E53`, source/test SHA
`9576e539c21fe6312763c4745a90dc032c6457e0`, seed `20261029`, same VCS
version; two CNN workloads pass at 128/512 KiB. Raw logs are archived at
`/tmp/nmaforge_v2_research_capacity_logs_9576e53.tar.gz` with SHA-256
`fd2c5c9816de8a9fefc1a4c07bb218d216a105b360b2ea0b5f61ae9ecb87a447`.
The smoke run record is
[`v2_finalization_top_smoke_9ee5879.json`](../../../benchmark/v2_finalization_top_smoke_9ee5879.json).
The final Git commit is reported with the handoff; no next engineering phase
is automatically started.

## Current bounded objective — 2026-11-06

The open-ended v2 DV closure loop is paused by project direction. This round
is limited to fixed-SHA core-function evidence reuse, the specified TinyNPU
GEMM/GEMV matrix, existing model correctness records, and static Scratchpad
capacity analysis. No additional coverage, mutation, formal, UVM, RTL
architecture, or ASIC tasks are being started.

Audit snapshot before the report package: branch
`feature/npu-architecture-v2`, source SHA
`219c9f26a85b9661185cd78ab6308ae3f13e3ea7`, product RTL SHA
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, 77 commits ahead of fetched
GitHub branch head `5d01a88a8a2a7b1add15fbedbb02096d686824ab`; `main` remains R250
`3041355528dffe856e2d5384027c6ee5df5d1b42`. The source tree was
`e2e3f1d1cc7dfa4de3e3d78fd51fab76d6c43f24` and the fetched remote tree was
`bf7306bdeefeca415dd221f0a29305fdcef5b72c`. All other worktrees and
pre-existing uncommitted edits were preserved. One UVM fairness assertion
edit remains uncommitted and is excluded from this report/benchmark commit.

The fixed NMAForge/TinyNPU matrix is complete: GEMM 3/3 and GEMV 4/4 Golden
PASS at seed 20261106. TinyNPU timing is direct array only; the single-port
memory endpoint is modeled and labeled estimated. The B-fold cache and fused
output ablations reuse their earlier fixed-SHA evidence. Current bottlenecks
are Matrix bank/line/arbitration/writeback wait at large GEMM and low useful
lane occupancy for small-M GEMV. The 512/256/128/64 KiB analysis is static:
current Digits and CNN fixed maps only fit 512 KiB together; compact 128 KiB
is a byte-count candidate for Digits but has not been mapped or timed.

Reports and machine outputs are in
[`NMAFORGE_V2_TINYNPU_BASELINE_SUMMARY.md`](../../benchmark/NMAFORGE_V2_TINYNPU_BASELINE_SUMMARY.md),
the [TinyNPU performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md),
and `benchmark/v2_tinynpu_*_current_20261106.{csv,json}` plus
`benchmark/v2_spad_capacity_static_20261106.{csv,json}`. Full DV remains
PARTIAL/HOLD; TinyNPU common-memory RTL, reduced-SPAD model runs, and current
ASIC PPA remain NOT_RUN/BLOCKED_ENV. This objective stops after the report
package is published on `feature/npu-architecture-v2` through the connected
GitHub App as fast-forward snapshot commit
`9a61b4852b61e830c2e284c3b980242a76410148`, parent
`5d01a88a8a2a7b1add15fbedbb02096d686824ab`. Its tree
`c78b01dd28074512cdb56304a4c629cd47fb03f8` matches local commit
`3d4b97666af79d01329b1307fe3560f0e7db5fea`. Standard Git transport lacked
authentication. Remote history and `main` were preserved; the separate
uncommitted UVM worktree edit was excluded. No further engineering phase is
started here.

## Prior DV handoff snapshot (historical)

At that earlier update, the clean validation candidate was
`839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`), replayed with Top smoke,
three-seed Cluster UVM, focused 0x52/0x53 tests/mutations, four-way GEMV
benchmark, and in-repository memory-fabric reset. The product RTL remains
unchanged from `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. The old note that
GitHub sync was blocked applies only to that earlier attempt; the current
target branch and fetched GitHub ref are documented above. The matched Cluster
serial/parallel workload was `f19e92934cd6273d327621c43cb17291cf1a9aa5`, and
the Top contention workload was `c93d020880710a2804685fd85bb98c2e9c56f290`.
The latest 0x53 runtime SVA source/test SHA was
`ed17ab1c257c0f7947cf78e60730da31c4548138`; formal request-hold evidence was
at `b719ac6066616b17dfab4eed2429f8bdfdc49457`. The historical frontier was a
short handoff for the next engineering task; it
does not duplicate per-run evidence. The current Compute Cluster sign-off and
benchmark work is tracked in the execution RTM and open-issue report.

Latest per-command Top Matrix profile source/test SHA is
`839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`; replays the profile first measured
at `f530fe2`). The real Top `16×32×64` Matrix
profile passes three Seeds in standalone, staged Matrix+CNM, and writeback
contention scenarios. Internal cycles are 490/533/844; arbiter-stall events
are 0/43/354; writeback-wait is 0/0/84. Each run's 15 exclusive state buckets
sum to Matrix `cycle_count`, records 3,072 B read and 2,048 B written, and
passes the existing Golden. UVM Warning/Error/Fatal is 0/0/0. The earlier
`8adf916` standalone-only record remains separately available. These profiles
do not yet provide per-command breakdown for CNM/SFU engines or every queued
multi-engine workload. See the clean-candidate [machine CSV/JSON](../../../benchmark/v2_top_matrix_cluster_profile_839b9af_3seed.csv)
and [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).
The RTM and sign-off status do not change.

## 2026-11-06 — 16-seed mixed AXI/DMA coverage and compatible URG merge

At source/test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9` (tree
`0b20e98298852d2648f83d10723c55aabe3a9149`), 16 mixed precision DDR/AXI E2E
seeds pass with UVM severity `0/0/0`; the named E2E, DMA error-position and
four AXI memory-model groups are 100%. A same-source/top/source-list-compatible
URG merge combines these with the three real Cluster seeds: 19 tests and
36/36 declared functional groups at 100%. Combined code coverage is Line /
Condition / FSM / Branch `74.13/71.59/47.45/71.10%`; 20/22 assertions have
real successes (two UVM RAL properties have no attempts), and AR/AW/W cover
matches are `161/67/126`. This closes only this declared test plan, not all v2
requirements or all RTL bins; the RTM remains 14 PASS-scoped / 8 PARTIAL and
v2 DV is **IN PROGRESS**. Product RTL is unchanged. Run IDs, exact commands,
archive hashes and scope limits are in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md)
and machine-readable records [mixed E2E](../../../benchmark/v2_mixed_axi_dma_cov_f9f32f7_16seed.json),
[19-test merge](../../../benchmark/v2_merged_urg_f9f32f7_19test.json).

## 2026-11-06 — Phase 0 worktree and source baseline refresh

The active target worktree is clean on `feature/npu-architecture-v2`; its
audit snapshot is `30fd00f28555029584d361df5d81289f6cd6b7bc` / tree
`160fdc923ff5080754ffd11f23ff599d6cf58281`, 63 commits ahead and zero behind
cached `origin/feature/npu-architecture-v2`. Both requested review start
`ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164` and R250
`3041355528dffe856e2d5384027c6ee5df5d1b42` are ancestors. The R250-to-v2 RTL
diff remains six files (`662` insertions, `80` deletions); no product RTL has
changed after `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. The IDE branch and
other dirty worktrees were preserved. Push was attempted but HTTPS credential
lookup failed, so no GitHub ref changed. Full inventory and branch relationship
are in the [architecture review](../../architecture/NMAFORGE_V2_ARCHITECTURE_REVIEW.md).

## 2026-11-06 update — 0x52 read-only A/B alias verification

Commit `f19e92934cd6273d327621c43cb17291cf1a9aa5` adds a real Top CMDQ
`1×16×16` case with `srcA == srcB`, independent output memory, and a named
alias coverage bin. A clean three-seed Compute Cluster UVM/URG regression
passes; each seed checks 256 unchanged source bytes, 16/16 signed INT32
Golden outputs, two output guards, completion, and 17/17 accepted/returned
Matrix reads. The merged bin is 3/3 hits at 100%; whole-test coverage remains
`70.71/68.37/46.17/67.66/72.00/83.94%` Line/Condition/FSM/Branch/Assert/Group.
This is scoped alias evidence, not v2 coverage closure. Product RTL is
unchanged. Run ID, archive checksum, and exact command are in the [DV closure
report](../../verification/NMAFORGE_V2_DV_CLOSURE.md) and [machine record](../../../benchmark/v2_cmdq_gemv_ab_alias_f19e929.json).

## 2026-11-06 update — current-source four-way GEMV ablation

At source/test SHA `a4dcc6b609878811fcd48a0310401609d4952c62`, the matched
Cache × Prefetch matrix reruns 48/48 Golden points on Seeds 20261105/06/07.
All 48 exclusive state-cycle partitions close exactly to command cycles; all
33 measured values per point match the earlier `85e7db2` replay. The product
RTL SHA remains `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. CSV, JSON, exact
command and archive checksum are in the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).

## 2026-11-06 update — real-CMDQ GEMV M/N/K alignment-tail cross

Testbench-only commit `0e9f12ec3701030c9e5978ad29b227c5e0c644a7` adds a
functional covergroup for all eight aligned/tail combinations and four new
legal descriptors on the real Top CMDQ path. Three Seeds each hit 8/8 bins;
every added shape checks independent signed INT32 Golden outputs, two guards,
ordered completion, and accepted/returned Matrix reads. Clean detached replay
passes with VCS/URG `V-2023.12-SP1`; UVM severity is 0/0/0. Merged profile
Line/Condition/FSM/Branch/Assert/Group is
`70.71/68.34/46.17/67.66/72.00/82.96%`. This closes only the declared
alignment-tail cross, not all legal dimension combinations or v2 DV. Product
RTL is unchanged. Run ID `V2-CMDQ-GEMV-TAIL-CROSS-3SEED-0E9F12E`; exact command
and logs-only archive checksum are recorded in the [DV closure
report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## 2026-11-06 update — real-CMDQ GEMV long-K point

Testbench-only SHA `e944133b43107839e5f5eea902251097a228b312` passes a
16×16×128 GEMV on three Seeds. Each run checks 256 independent signed INT32
Golden outputs, two guards, ordered completion, and 448/448 accepted/returned
Matrix reads. The named long-K group is 100%; aggregate profile
Line/Condition/FSM/Branch/Assert/Group is
`70.71/68.34/46.17/67.66/72.00/83.46%`. A `16×16×256` attempt exceeded the
existing 2,000-cycle Top completion bound before Golden comparison. A separate
`1×1×256` test-bound point now passes at SHA `8758794`; the larger M/N workload
remains open and no timeout/checker limit was changed. Product RTL is unchanged.
Run ID `V2-CMDQ-GEMV-K128-3SEED-E944133`; exact command and logs-only archive
checksum are in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## 2026-11-06 update — real-CMDQ K=256 test-bound point

At clean SHA `8758794c1f3bd6abb41c33276422b84ac5ee7a80`, VCS/URG
`V-2023.12-SP1_Full64` passes three Seeds for an opcode-0x52 `1×1×256`
descriptor. Each Seed checks the independent signed INT32 result, two output
sentinels, ordered completion, and 272/272 accepted/returned Matrix reads;
UVM severity is `0/0/0`. Merged URG Line/Condition/FSM/Branch/Assert/Group is
`70.71/68.34/46.17/67.66/72.00/83.46%`. This adds a scoped K=256 test point,
not a claim that `16×16×256` meets the existing watchdog. The evidence archive
`/tmp/nmaforge_v2_k256_evidence_8758794.tar.gz` has SHA-256
`3ceac93b551949ad49a698309460fe0f978b5a7a71be74ec3f873727e17268b9`; run
identity and command are in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## 2026-11-06 update — real-CMDQ GEMV extended shapes

Commit `0696c16bd1346207ad5421d21247c719ea018111` adds real Top CMDQ
execution for `1×16×17`, `8×13×65`, and `15×16×31` opcode-0x52 descriptors.
Three Seeds pass independent signed INT32 Golden checks for every result,
guards, completion payload/order, and Matrix accepted/returned response counts.
The dedicated URG group is 3/3 (100%) and the existing full Cluster regression
passes from a detached clean worktree. Product RTL is unchanged. Merged overall
coverage remains Line/Condition/FSM/Branch/Assert/Group
`70.71/68.29/46.17/67.66/72.00/82.43%`; this does not close all legal GEMV
shapes or v2 DV. Exact command and logs archive checksum are in the [DV
closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## 2026-11-06 update — fixed-candidate GEMV Cache × Prefetch benchmark

At fixed source SHA `85e7db2d12f5edfaed17e8ca3910bb504983779f`, the existing
four-configuration GEMV ablation passed 48/48 Golden points on Seeds
20261105/06/07. B-fold Cache reduced cycles 22.3–41.6% and read bytes
35.2–56.5% on the four measured shapes. Prefetch ON improved cached M8 cases
2.0–2.4% and regressed cached M16 cases 0.6–0.8%. These are Matrix-core
behavioral-SPAD results, not Top throughput, ASIC PPA, or TinyNPU wins.
Machine-readable outputs and command are in the
[performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md);
logs-only archive SHA-256 is
`b685a500285bdbfc737292d09771f2d23df69840e301773a6ad91c243c07fc60`.

## 2026-11-06 update — concurrent opcode-0x52 GEMV + CNM ownership

Testbench/Makefile commit `85e7db2d12f5edfaed17e8ca3910bb504983779f` passes
the full Compute Cluster UVM regression from detached clean worktree on Seeds
20261121/22/23. The test submits maximum-shape 0x52 GEMV and CNM GEMV through
one real CMDQ, checks independent full output Goldens, guards, ordered
completions, accepted/returned ownership, and zero route mismatches. Named
owner coverage is 100%; aggregate Line/Condition/FSM/Branch/Assert/Group is
`70.69/68.25/45.99/67.59/72.00/81.86%`. Collision grants were Matrix/CNM
`0/18`, so this does not establish fairness. Product RTL is unchanged. Run ID,
exact command, and logs-only archive checksum are recorded in the
[v2 DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## 2026-11-06 update — real-Top 16×16 Matrix/CNM contention profile

Expanded the legal parallel CMDQ profile from a 4×4 Matrix micro-workload to
16×16 Matrix GEMM (`k_words=16`) concurrent with a 16-row banked CNM GEMV.
The testbench uses non-overlapping SPAD regions and nonzero uniform inputs;
all 256 Matrix outputs equal 64 and all 16 CNM outputs equal 96. No product
RTL changed. Source/test SHA `c93d020880710a2804685fd85bb98c2e9c56f290`,
tree `24180541c76b1ad4d27b2e97313e7d97a5df2016`, VCS
`V-2023.12-SP1_Full64`. Full Top `ai_smoke` passed for Seeds 20261106,
20261107, and 20261108; each run also passed its four randomized cases.

Every seed reports a 445-cycle profile window, 93 cycles with both engines
busy, and 20 same-cycle Matrix/CNM request collisions. Matrix busy-phase
buckets close at 318 cycles (64 MAC, 17 request wait, 23 response wait, 64
writeback, 150 other); CNM closes at 145 (16 compute, 0 request wait, 0
response wait, 16 writeback, 113 other). Data traffic is 2,560 B read and
1,088 B written; Matrix outstanding-read high-water is 2. There are no
response-valid aliases and the checked outputs/completions are bit-exact.
The large `other` buckets remain unexplained, and the profile window includes
testbench register access overhead.

The result confirms this directed legal workload exercises shared-arbiter
contention. It does not compare serial versus parallel for the same workload,
does not compare an alternate scheduler policy, and has no area/timing cost
measurement; no Bank-Aware Issue RTL change is justified. Behavioral SPAD
cycle counts are not ASIC results. Machine evidence is in
`benchmark/v2_p2_cluster_top_contention_c93d020.csv` and its summary JSON.
Logs-only archive SHA-256:
`b44e858972a704438b803d10146558b5554089a26c19729200619cc0af88ebeb`.

Verification/profile commit `c93d020880710a2804685fd85bb98c2e9c56f290`
has been mirrored to the GitHub v2 branch as commit
`a9328376a6b80ff3d59ee13cd25073c5c91b8191` (identical source tree).
Phase 2 remains open for matched serial/parallel ablation, comparable memory
service, and per-command stall correlation. Phase 3 trained CNN/Tiny
Transformer remain NOT_RUN; Phase 4 PPA is BLOCKED_ENV; v1.0 sign-off remains
HOLD.

## 2026-11-06 update — 0x53 valid-rise SVA and mutation sensitivity

Added a third runtime assertion to the 0x53 forwarding core regression. VCS
`V-2023.12-SP1_Full64` passes three Seeds with 3/3 assertions attempted, zero
failures, three valid-rise cover matches per Seed, and all six named
forwarding functional bins hit. Golden output remains bit-exact. A follow-on
actual-RTL mutation campaign injects seven defects across the same Seeds and
all 21/21 are caught, including premature validity directly by the new SVA.
The tile-tag mutant also trips this earlier property, and the runner's
expected checker was changed to match that direct detection. No product RTL,
ABI, or benchmark result changed.

`REQ-V2-053-002` remains PASS for named core scenarios. `REQ-V2-COM-003`
remains PARTIAL because these 0x53 checks are runtime simulation assertions,
not a complete formal proof. `REQ-V2-COM-005` remains PARTIAL because this is
selected checker-sensitivity evidence, not exhaustive v2 mutation closure.
The RTM remains 14 PASS-scoped / 8 PARTIAL; v1.0 Compute Cluster remains
HOLD; v2 DV remains IN PROGRESS. Evidence IDs, exact commands, and archive
hashes are in the [v2 DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## NMAForge v2 next-round plan status — 2026-11-05

Phase 0 audit is complete. Remote `main` remains R250
`3041355528dffe856e2d5384027c6ee5df5d1b42`; the local `main` ref has drifted,
so comparisons use the explicit R250 SHA. The VS Code worktree remains on
`feat/shape-adaptive-gemv-v2` with two untracked local simulator config files;
all ten dirty worktrees and eighty missing/prunable registrations were
preserved. The latest product RTL change remains
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; no product RTL changed in the
following report commits. See the Phase 0 section in the [v2 architecture
review](../../architecture/NMAFORGE_V2_ARCHITECTURE_REVIEW.md) for branch/tree
identities, worktree inventory, `.gitignore` audit, and post-RTL history.

Phase 1 is **IN PROGRESS**. The DV report has 22 normalized `REQ-V2-*`
rows: 14 PASS-scoped, 8 PARTIAL, and 0 NOT_RUN. At test candidate
`9956699`, three-seed Matrix core/GEMV, selected 0x52/0x53 fault recovery,
Prefetch-OFF fallback, and 15/15 selected opcode mutations pass their stated
scopes. Merged Matrix URG covers 15 tests: Line/Condition/FSM/Branch
95.21/90.74/95.45/97.10%, 15/15 states and 52/55 transitions. The three raw
unhit transitions have current-SHA, non-vacuous formal guard proofs; no bins
were waived or reached through illegal-state injection. Opcode-specific SVA,
arbitrary external-SoC SPAD response ownership, the full legal fault × phase ×
reset crosses, and complete functional-bin disposition remain open. Top
DUT-only URG is still the separate earlier 86.75/77.62/44.33/84.56%; the
Matrix+SFU handoff group is 100%, while four existing AXI groups are
unsampled and total Top functional-group coverage is 20%. These figures do
not close v2 DV or imply full coverage. See run identities and scope in the
[DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

**Latest generic Cluster replay (2026-11-06):** fixed tree
`2999e03252c79aed66116b753b64ee7e389b9a56` passes the real-top seven-engine
UVM regression on Seeds `20261106/07/08`. Each seed observes all 21 engine
pairs, passes 18 Parity + 19 Protection cases and 72/72 legal engine/operand/
phase Protection × Reset recovery points, checks 92,871 memory words with zero
mismatch/unknown/stale reads, and drains the response-owner ledger
`5015/4995/20` with no route/data/error mismatch or pending response. Focused
applicable Compute Cluster bins are 100%, but merged aggregate
Line/Condition/FSM/Branch is `69.65/62.74/45.62/58.03%`; assertions are 17/22
with zero failures/incomplete, and AR/AW stall covers remain unmatched. This
generic Cluster run does not close v2 opcode-specific contracts or change the
14 PARTIAL RTM rows. Logs-only archive SHA-256:
`1596309ee89d002bf48c2733e2d0844781d61e80c6d1d1bec8ae712563186890`.

The current candidate also passes the directed descriptor validator
(43/43 boundary accepts, 26/26 rejects, 33 invalid rules, 3/3 tile-forward
accepts, and legacy AUX compatibility), plus three-seed Matrix 0x52 GEMV,
selected 0x52/0x53 fault recovery, request/line backpressure, and Tile
Forwarding ON/OFF regressions. Default-profile URG merges nine tests: all four named v2 Matrix
covergroups are 100%; code Line/Condition/FSM/Branch is 86.50/84.08/57.58/93.48%.
Forwarding OFF/ON ablation coverage is intentionally kept in separate build
profiles; the isolated OFF profile has no sampled v2 groups, while the ON
profile has 100% tile-group coverage and 37.50% aggregate group score because
other features are not part of that test. This is not a global waiver or full
v2 closure. Maximum-dimension execution is still unverified. See the DV report
for all bins, commands, profiles, and logs-only opcode archive SHA-256
`50283ae0441734f1c044b45fae8e8d7f4206470641331e77cba7fe4df974d25a`; descriptor
validator archive SHA-256 `9fd7a4d1ced7bc62936dcd061ec72e063ea275b33c6d1e27bdbe8d92aa4d5299`.

The repository `ai_accel_memory_fabric` boundary also has a three-seed
coordinated reset/epoch replay at SHA
`f340acaa2cdf7c36075473b8bc6fd6dee8e59873`: its three named reset groups
reach 100%, owner/tag SVAs have real successes, and post-reset DMA plus CNM
Golden recovery passes. This adds one scoped PASS row (`REQ-V2-COM-006`), not
closure of arbitrary external-fabric behavior or the opcode-specific
fault/reset matrix. The whole URG report's functional group score is 23.98%
for that subsystem run. Logs-only archive SHA-256:
`14144bdc62932d8040a1b5be72b27f83e6f4f8e52286a8658b1570fdfe3717c5`.

Legacy compatibility also has a current-source clean Top replay at SHA
`5f6e282f191b421bdbefc3d252690a9a0c93eb1c`: three Seeds with 20 random
workloads each all pass. Each run checks seven `0x30` Tensor GEMM outputs,
four `0x31` Batch GEMM outputs and existing v2 smoke paths. This closes
`REQ-V2-COM-002` for those tested modes/shapes; other aux, shape and
fault/concurrency combinations remain open. Archive SHA-256:
`a56378fc6a1364ee4fdcc8f34dcf21b47068270d473ba7b848cdaef6b2a65b3c`.

Phase 2 has a fixed-candidate four-way GEMV ablation, real Top serial/parallel
and Matrix/CNM contention runs, and a current NMAForge-side TinyNPU GEMM/CNN
replay. The TinyNPU common-memory endpoint remains modeled, no scheduler
alternative was compared, and the measured/modelled cycle ratios show no
NMAForge win on the three GEMM shapes. Phase 3 has trained Digits MLP and a
fixed-weight reference CNN only; trained CNN and Tiny Transformer remain
NOT_RUN. Phase 4 has 465 SpyGlass lint warnings, incomplete CDC/RDC, and DC PPA
BLOCKED_ENV; no ASIC readiness claim is made. v1.0 remains HOLD.
Phase 3 has a trained Digits MLP only; trained CNN and Tiny Transformer are
NOT_RUN. Phase 4 has 465 SpyGlass lint warnings, incomplete RDC, and DC PPA
BLOCKED_ENV; no ASIC readiness claim is made. v1.0 remains HOLD.

## Current TinyNPU paired replay — 2026-11-05

Run `TINY-COMPARE-V2C3A59-S20261029` completed on NMAForge source SHA
`c3a59f08d8c07a8da973010d0f23d5d6d7eed61b` and TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`: paired 16×16×16, 16×16×32 and
32×32×64 signed INT8 GEMM Golden PASS on both designs; matrix size sweep 15/15;
TinyNPU engine regression 6/6; same ONNX `conv1x_mini` CNN Golden PASS on both.
The TinyNPU GEMM memory schedule is estimated and serialized. NMAForge/TinyNPU
normalized ratios are 1.1391/1.1385/1.0659 (greater than one means NMAForge
used more cycles). CNN endpoints differ; no CNN speedup is stated. See the
[replay report](../../benchmark/NMAFORGE_V2_TINYNPU_REPLAY_2026-11-05.md),
machine-readable CSV/JSON under `benchmark/tinynpu/`, and its external log
archive checksum in the report. Trained CNN, Tiny Transformer, true TinyNPU
memory adapter, broader small/thin GEMV coverage, and DC PPA remain open.

The focused paired `0x52` small-M replay `GEMV-MATCH-V2-S20261029` also passes
at NMAForge SHA `0b1d33704f4895cf48b0f5e1d3f452d61b3df535` for `1×13×17` and
`8×16×19` against TinyNPU `8216c22b762011aa20c05fc2768423fd12dda59d`.
NMAForge measures 76/158 controller+behavioral-SPAD cycles; TinyNPU direct
array RTL measures 100/100, with serialized memory estimates of 126/170 total.
The mismatched endpoints are explicitly caveated and are not a system-level
speedup claim. See the [small-GEMV replay report](../../benchmark/NMAFORGE_V2_SMALL_GEMV_TINYNPU_2026-11-05.md)
and its CSV/JSON/SVG artifacts.

## Current v2 candidate replay — 2026-11-05

At fixed source/test SHA `33e85287fbf37187fccb76e97be6effe888670e9` (tree
`560dc1cbfc1bb13003670354d77271e3708ec0a7`), the Tile Forwarding core OFF/ON
ablation passes 6/6 runs across Seeds 20261105–20261107. Producer/consumer
Golden images match; mean consumer cycles are 141→118 and source-A reads are
32→16 (512→256 B). Capture backpressure, final-line commit, tag hit/miss,
bank flip, reset/Abort invalidation, and response drain are checked. A clean
detached Top Smoke worktree at the same SHA passes 3/3 Seeds, including `0x52`
M/N/K tails and the real-CMDQ `0x53` output/completion differential (16→0
source-A bank reads). The exact commands and evidence are in the [fixed-SHA
replay report](../../verification/V2_P2_TILE_FORWARD_MULTISEED_REPLAY_2026-11-05.md).
The core OFF/ON target was replayed again at clean branch SHA `294ffec`; all
six runs retained bit-exact Golden, tag-miss fallback, Abort/Reset flush, and
completion PASS markers. The latest logs-only checksum is in that report.
The same candidate also replays the trained 360-image Digits MLP against R250
using the exact same model and Golden and byte-identical RTL logits: 110,155→
34,761 doorbell-to-completion-tail cycles (−68.44%), with 352/360 correct in
both runs. See the [model benchmark](../../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md),
[CSV](../../../benchmark/v2_digits_model_comparison.csv), and
[JSON](../../../benchmark/v2_digits_model_comparison.json).
These supersede the earlier license-blocked attempts for the tested points;
parity/protection, held-response fault phases, cross-engine coherence, merged
coverage disposition, broader GEMV shapes/common TinyNPU memory service, trained
CNN/Transformer, and PPA remain open. The v1.0 disposition remains **HOLD**.

## Current static-analysis and formal evidence — 2026-11-05

At RTL/test candidate `145363ddff5141177421ee7429fc65f78834830d`, SpyGlass
lint completes with 0 errors but 465 warnings; structural CDC reports 0
unsynchronized crossings and 0 convergence with two warnings. RDC timed out
after 180 seconds at `Ar_resetcross01`. Matrix FSM VC Formal passes 5/5
non-vacuous assertions and 2/2 covers. DC Base-vs-v2 PPA is BLOCKED_ENV by
missing private standard-cell/SRAM views and public flow script. See the
[ASIC readiness report](../../verification/NMAFORGE_V2_ASIC_READINESS.md).


## Latest Compute Cluster evidence

**R250 final published-tree replay (2026-11-03):** Exact published source/test tree `da34f7e314fccf3793372c59768ebac541fa22a7` passes three-seed seven-engine UVM, Top Smoke, 16-seed mixed E2E, and 7/7 actual RTL mutation checks. URG combines 19 tests: 28/28 declared functional groups, all 3 AXI stall covers, 20/22 assertions with real successes, zero failures/incomplete; two no-attempt properties are UVM RAL internals. Hierarchy line/condition/FSM/branch/assert is 73.99/69.39/47.24/64.95/92.00%, not 100% code coverage. The audited RTM remains 24 scoped pass dispositions / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. See [R250 report](../../verification/COMPUTE_CLUSTER_FINAL_TREE_REPLAY_R250_2026-11-03.md), logs-only archive SHA-256 `9f4865a09e93152548da30c85e25ac3afcd94d6ab05abdd56930c71c6d34b57a`.

**R249 Matrix FSM disposition replay (2026-11-03):** At the exact published tree 074c0411a84e4e971898f4b864d5d7a77852b1a7, enabled-profile Matrix core passes 18 functional + 35 fault/recovery cases on each of three seeds; prefetch-disabled fallback and all five benchmark shapes pass on three seeds. VC Formal proves 5/5 non-vacuous assertions and reaches both state covers. The four residual enabled-profile transitions are accounted for by three proven guard dispositions and one legal prefetch-disabled fallback. Raw enabled-profile FSM remains 49/53; REQ-CL-010 remains PARTIAL and CL-DV-v1.0 remains **HOLD**. See [R249 report](../../verification/COMPUTE_CLUSTER_MATRIX_FSM_R249_REPLAY_2026-11-03.md); logs-only archive SHA-256 107924a06561c4af8e53de229254dbc4daca18dabb3b7d1aef9ac40b317329fc.

**R248 final published-tree replay (2026-11-03):** Exact published `main` tree `00431c3f0c05d11de2d8cf90f69ce0020c7944bf` passes three-seed seven-engine UVM, Top Smoke, 16-seed mixed-precision/AXI regression, and 7/7 actual RTL mutation checks. The merged URG plan reports 28/28 declared functional groups at 100%, 3/3 AXI stall-to-accept covers, 20/22 assertions with real successes, and zero failure/incomplete; the two no-attempt properties are UVM RAL internals. Raw line/condition/FSM/branch coverage is 73.99/69.39/47.24/64.95%. This meets the declared testpoint target only: the 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL` and `CL-DV-v1.0` remains **HOLD**. See [R248 report](../../verification/COMPUTE_CLUSTER_FINAL_TREE_REPLAY_R248_2026-11-03.md), logs-only archive SHA-256 `fd62fa63ad1978b53a091e50d6f809dfe4b05e49c93b6e44dbded8ef20ce184c`.

R247 reruns the production Descriptor Validator and Scalar INT8 numeric/core gates on the tree identical to published `main` (`be7ec4aeaff3d4a75e504809ba70327dc9ec5bbf`). The validator passes 27 opcode classifications, 21 invalid rules, 38 accepted and 26 rejected boundary vectors; its `engine_limit_claim=0` remains explicit. Scalar INT8 passes 14 cases on each of three seeds, including Abort/Watchdog/Reset priority and recovery Golden. These are bounded `REQ-CL-002/020` evidence, not requirement closure. See the [R247 report](../../verification/COMPUTE_CLUSTER_BOUNDARY_REPLAY_R247_2026-11-03.md), archive SHA-256 `c879d12dce3d435cb90db63eb14e742730b5c22c4ee21c4915b3923356905210`.

R246 reruns the actual RTL mutation campaign against exact published closeout SHA `269c2a0de8cf226dd01c3f86c05e180908252b04` / tree `61e365cc5a37998c0bf2688981cbb89f278eace2`. Seven temporary mutants are compiled and injected; the configured Address, Data, Response Owner, WSTRB, Completion Error, Missing Done, and Duplicate Done checkers all detect their mutation. This is checker-sensitivity evidence only; the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` HOLD. See the [R246 report](../../verification/COMPUTE_CLUSTER_DUT_MUTATION_R246_2026-11-03.md); logs-only archive SHA-256 `6a1f8f19078135b86b8a695ac1a951fe0b259cdd7acb8ce2d827ce9ed55b6a8b`.

R245 replays the exact published `main` SHA `8078ed55af3b72652e74308483c20bd0d18a6cc9` from a detached clean worktree. Three real-top Cluster seeds and Top Smoke pass; each seed checks 92,871 Memory Image words with zero mismatch/unknown/stale and drains its response-owner ledger. URG focused `cluster_cg` is 64/64, mixed group score is 79.18%, and assertions have 17/22 real successes with zero failure/incomplete. This confirms published-tree reproducibility only; the 38-row RTM stays 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` HOLD. See the [R245 replay report](../../verification/COMPUTE_CLUSTER_PUBLISHED_HEAD_CLEAN_REPLAY_R245_2026-11-03.md).

R244 reruns the eight depth/prefetch/A-Tile Cache Matrix configurations on the current test tree (`3db422d6456edfaf9b5dc74460f9d5507a42c08c`): all 120 shape/configuration/seed Golden points pass. D4/P1/C1 reduces the five-workload cycle sum 2,701→2,029 (24.88%) and SPAD read bytes 12,032→9,472 (21.28%); writes are unchanged, while measured line-write stalls increase. This remains one-cycle behavioral-SPAD evidence, not ASIC PPA or a TinyNPU win. See the [R244 report](../../benchmark/COMPUTE_CLUSTER_MATRIX_CONFIG_COMPARISON_R244_2026-11-03.md) and [CSV](../../benchmark/compute_cluster_matrix_config_comparison_r244.csv).

R243 adds passive per-engine request-wait observation and reruns real seven-engine UVM plus Top Smoke on the exact published code tree. Three seeds pass with clean memory and owner ledgers; maximum request waits are `{12,14,53,0,64,126,14}` cycles. URG reports `cluster_cg=64/64`, group score 79.18%, and 17/22 assertion successes with zero failure/incomplete; three AXI AR/AW assertions have no real success and two UVM RAL assertions have no attempts. No downstream SRAM stall is injected, so `REQ-CL-014` remains PARTIAL. See the [R243 report](../../verification/COMPUTE_CLUSTER_ENGINE_REQUEST_WAIT_R243_2026-11-03.md).

R240 is the latest detached clean-worktree replay of the published closeout tree: three real-top Cluster seeds and Top Smoke pass; 92,871 Memory Image words/seed have zero mismatch/unknown/stale and `cluster_cg` is 64/64. R241 separately records non-vacuous AXI AR/AW/W payload-stability assertions and stall-to-accept covers. See the [R240 replay](../../verification/COMPUTE_CLUSTER_FINAL_CANDIDATE_REPLAY_R240_2026-11-03.md) and [R241 SVA report](../../verification/COMPUTE_CLUSTER_SVA_NONVACUITY_R241_2026-11-03.md).

R235 re-audits the exact R232 published-head UVM logs for the seven-engine writeback Protection × full-CPLQ × ordered-wrap point: 7/7 engines on all three seeds, correct error mapping and sentinels, and clean memory/owner scoreboards. This testpoint is now traced to the `c5755985` RTL/DV identity; the wider fault/phase/reset/backpressure matrix remains open. See the [R235 audit](../../verification/COMPUTE_CLUSTER_P0_PROTECTION_CPLQ_REPLAY_R235_2026-11-03.md).

R234 is the earlier same-RTL benchmark snapshot; R244 refreshes its 8-way ablation at the later test tree. Common-memory TinyNPU and PPA comparisons remain open.

R233 additionally passes all nine Control UVM tests, including frontdoor RAL read/write, with zero UVM severity. All seven Control AXI-Lite assertions have real successes; two UVM library `uvm_reg_map` properties remain no-attempts and are explicitly disclosed. This does not alter the Phase A HOLD.

R232 replayed the exact published closeout HEAD 3259d4da158d56aebe41c227c426b6b4b74a0f72 from a clean worktree. Top Smoke, three-seed real seven-engine Compute Cluster UVM, 16-seed mixed E2E coverage, and the 28/28 actual RTL mutation campaign pass. Combined URG reports 28/28 declared functional covergroups at 100%; all AR/AW/W stall-to-accept cover properties match. Each Cluster seed checks 92,871 Memory Image words with zero mismatch/unknown/stale and drains the owner ledger. The combined simulation hierarchy still reports line/condition/FSM/branch coverage 73.95/69.39/47.24/64.95%, with two UVM RAL internal assertions without attempts.

The declared testpoint target is met for this merged plan. The full Phase A exit criteria are not met: the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL, so CL-DV-v1.0 stays HOLD. Next, strengthen legal downstream-stall/fairness evidence without claiming a bound absent from SPEC, close requirement-level fault × phase × reset × backpressure interactions and descriptor max/stride/alias/overflow boundaries, then review Matrix integration and remaining benchmark scope. Keep v2.0 product changes behind the v1.0 review.

See the [R232 report](../../verification/COMPUTE_CLUSTER_PUBLISHED_HEAD_CLEAN_REPLAY_R232_2026-11-03.md), [Execution RTM](../../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md), [Open-Issue List](../../verification/COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md), and [Sign-off Readiness](../../verification/COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md). The logs-only archive is /tmp/nmaforge_r232_final_evidence_20261103.tar.gz, SHA-256 ac1f65990fd2aef1b044a680170878ac8f327eb848f53be722b9a13801b2e0ba.

## Project baseline

NMAForge is a synthesizable AXI-Lite/AXI4 digital compute-near-memory
accelerator. The only chip integration top is `rtl/top/ai_accel_top.v`. Product
behavior comes from `docs/spec/SPEC_ZH.md` / `SPEC.md`; ownership and dataflow
come from `docs/architecture/ARCHITECTURE.md`.

Key architecture rules:

- `ai_spad_arbiter` is the only scheduler-side scratchpad admission point.
- `ai_command_processor` owns command lifecycle and queue-pointer advancement.
- Completion commits all four words before advancing the completion tail.
- AXI valid/ready, ID, LAST, back-pressure, reset, and abort-drain behavior
  must remain protocol-correct.
- Ordinary compute descriptors can overlap across engines through
  `ai_parallel_compute_dispatcher`; each engine has one active slot and
  completions retire in CMDQ order. See the Compute Cluster SPEC v1.1.

## Historical branch evidence snapshots

On the isolated closeout branch, exact clean candidate SHA
`43a84cac688a56e789162dfa5a8106551779abdb` passes the three-seed real-top
Compute Cluster UVM, all 28 named checker-sensitivity mutations, Top Smoke,
and the 20-case seeded Top regression. Each UVM seed checks 17,388 memory
words with zero mismatch/unknown/stale/orphan response and 100% of the
applicable focused cluster bins. URG remains 17/22 assertion successes with
zero failures/incomplete; AR/AW stall properties are not activated by this
compute-only sequence. This adds reproducibility only: the RTM remains 24
PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. See the
[R91 replay report](../../verification/COMPUTE_CLUSTER_CLEAN_REPLAY_R91_2026-10-30.md).

The VCS license is available in the current environment. On research branch
`feat/tinynpu-model-inference`, run `DIGITS-RTL-20261029-FINAL` passed: a trained
INT8 digits MLP ran through the real top-level Matrix/SFU/CMDQ/CPLQ path and
matched an independent integer Golden for all checked values. The run reports
the host layout bridge separately; it does not claim host-free inference. See
the [digits inference report](../../benchmark/REAL_MODEL_INFERENCE.md).

At source SHA `08c34322879c688afd505ddf41fa4b2a5dc93ac0`, the pinned TinyNPU
benchmark passed: 22 GEMM rows, including three common 16×16-array shapes
(16×16×16, 16×16×32, 32×32×64) with every output matched against the independent
INT32 Golden on both designs. TinyNPU's engine regression passed 6/6. The same
`conv1x_mini.onnx` graph passed on both tops; NMAForge checked all intermediate
tensors and outputs byte-exactly using eight CMDQ descriptors. Its recorded
windows are 1,985 compute cycles plus 1,080 host-layout cycles; TinyNPU's graph
smoke is 4,781 testbench cycles. Run ID `TINY-COMPARE-20261029-S20261029`; VCS
`V-2023.12-SP1_Full64`, Verilator 5.052, NumPy 2.1.3, ONNX 1.17.0. Memory
setup and timing boundaries differ, so there is no CNN or GEMM speedup claim.
Paired evidence is in [`cnn_results.csv`](../../../benchmark/tinynpu/cnn_results.csv)
and [`gemm_results.csv`](../../../benchmark/tinynpu/gemm_results.csv), with
machine summaries in the same directory. TinyNPU's direct-array measurements
exclude SRAM and graph DMA, so equal-bandwidth comparison remains open.

On current follow-up SHA `27638d191f3aabbe9e8fecc350b76849b5ab51d3`, the
license-enabled real Compute Cluster UVM regression passed three seeds with
14/14 selected parity cases, 100% applicable focused coverage, 5,368 checked
words per seed, and zero UVM warning/error/fatal. The 25/25 checker-sensitivity
mutation campaign also passed. These results reconfirm their named evidence;
the full RTM remains 24 PASS-SCOPED / 14 PARTIAL. Current top `ai_smoke` passed
with its existing `[LOOP-REROLL-ENABLED]` fixture warning.

The paired TinyNPU benchmark is archived as run
`TINY-COMPARE-20261029-S20261029`: three tiled INT8 GEMM shapes and the
`conv1x_mini.onnx` CNN pass independent Golden checks on both designs. The GEMM
cycle windows differ (NMAForge includes controller/SPAD; TinyNPU directly
drives its array), so no normalized speedup is reported. See the benchmark
README, CSV/JSON summaries, and R38 in the [Execution RTM](../../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

The trained digits MLP and the 86-descriptor Transformer fixture also passed
again on current local SHA `6115212e8587f2ca3374787df358761eada7d7ee` with VCS
`V-2023.12-SP1_Full64`. Digits matched the independent integer Golden for all
360 samples (352 correct, 97.78%) over 69 descriptors; its 70,656-cycle host
layout bridge remains separately counted. The fixed-weight Transformer
fixture checked all intermediate/completion words and ended in `TEST PASS`.
Both compiles retain `[LOOP-REROLL-ENABLED]`; neither result claims pretrained
language-model inference. See the [inference report](../../benchmark/REAL_MODEL_INFERENCE.md).

The three-seed Matrix size/ablation replay at SHA
`110e0c9db49eb1a7a558c955347accfde87f963e` passed 45/45 size cases and 120/120
configuration cases. Run ID `MATRIX-PERF-20261025-20261026-20261027-110e0c9d`; CSV/JSON evidence is
in [`benchmark/compute_performance.csv`](../../../benchmark/compute_performance.csv)
and [`benchmark/compute_performance_summary.json`](../../../benchmark/compute_performance_summary.json).

The checked-in 86-descriptor prefill/decode fixture also reran with VCS on this
SHA and passed all tensor/completion checks. It uses deterministic functional
weights; it is not a trained or pretrained GPT-style model deployment.

The current branch is research work based on the v1.0 audit candidate, not a
replacement sign-off baseline. The audited candidate remains
`9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`; its final audit records 24
PASS-SCOPED and 14 PARTIAL requirements and concludes CL-DV-v1.0 is not signed.
The digits experiment does not change that disposition.

The isolated shape-adaptive kernel also passed a fresh VCS replay on its current
source SHA `8c19eaf43c4b70a61272d698f1cb7aa9a191f27d`: three seeds, 12 shapes
per seed, baseline/GEMV Golden checks, Abort/Reset, and invalid-dimension
rejection all passed. Run ID `SHAPE-ADAPTIVE-20261029-8c19eaf4`; the compile
log has no Warning, Error, or `[TFIPC]` diagnostics. Its four-way memory
prefetch schedule remains an analytical fixed-bandwidth model, not an integrated
SPAD measurement. See the [shape-adaptive report](../../research/SHAPE_ADAPTIVE_TENSOR_ENGINE.md).

| Area | Current evidence | Open work |
|---|---|---|
| CNM, CNN/KV, FP, Matrix, SFU | Selected block/subsystem/top regression passed. Raw DUT-only code coverage is partial. | See [compute-engine status](../../verification/COMPUTE_ENGINE_STATUS.md) and [detailed run record](../../verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-21.md). |
| A10 G0/V1–V5 | Current workstream status and strongest evidence are in the [A10 RTM](../../verification/A10_DV_RTM.md). | Full-domain FP parity proof, residual code/assertion coverage, broad interaction closure and fixed-SHA manifest remain open. |
| Static analysis | Evidence and license/tool boundaries are in [static analysis](../../verification/STATIC_ANALYSIS_REPORT.md), [SpyGlass triage](../../../dv/spyglass/LINT_TRIAGE.md), and [CDC/RDC status](../../verification/CDC_DUAL_CLOCK_DISPOSITION_ZH.md). | Resolve or disposition remaining warnings and advanced-tool gaps. |
| Physical and board | [TSMC28 report](../../verification/TSMC28_SYNTHESIS_REPORT.md) is pre-layout evidence; [XCZU15EG guide](../../verification/XCZU15EG_BRINGUP.md) defines board bring-up. | Post-layout multi-corner sign-off and board evidence are not claimed. |

## Next work

1. Close the remaining Compute Cluster P0/P1 items in the
   [execution RTM](../../verification/COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)
   and [open-issue report](../../verification/COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).
2. Freeze the reviewed source and test manifest, then replay the remaining
   required gates on one clean SHA. R35 already replays the focused group from
   clean test commit `cb9717e` with RTL/SPEC byte-identical to the review candidate.
3. Continue the FP parity-to-writeback proof from the [FP formal frontier](../../../dv/block/compute/fp/formal/README.md); an inconclusive timeout is not a pass.
4. Keep LEC, DFT, post-layout PPA, and board results as separate closure gates.
5. Continue the isolated `feat/shape-adaptive-gemv-v2` branch. Its 256-MAC
   kernel passes three-seed RTL Golden checks at SHA `8c19eaf`; the
   bandwidth/prefetch schedule is analytical and still needs an actual
   double-buffered SPAD path, bank-arbitration tests, and synthesis evidence.

## Canonical commands

Run from the repository root unless noted:

```sh
make -C dv/subsystem/tensor_datapath/sim cluster_regress
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/command_processor/formal completion-ownership
```

For RTL edits, run the focused target and `ai_smoke`. For queue, DMA,
scratchpad, top, or source-list changes, also run the seeded top regression
when the EDA environment is available. Record exact commands and PASS evidence
in the owning report; run `git diff --check` before handoff.

## 2026-10-30 update — R61 checker sensitivity replay

- Code/test commit: `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`.
- Exact clean-SHA replay: 3-seed Compute Cluster UVM PASS, 28/28 checker-sensitivity probes caught, Top Smoke PASS, 20-case seeded top regression PASS.
- Focused applicable compute testpoint group: 100% for these seeds; not full RTL/RTM closure.
- Open: external-fabric late-response/reset qualification, legal Engine × Fault × Phase × Reset crosses, Matrix descriptor/partial-WSTRB contract limits, AXI AR/AW SVA real-success gaps, and remaining partial RTM dispositions. CL-DV-v1.0 remains HOLD.
- Evidence: [R61 report](../../verification/COMPUTE_CLUSTER_R61_CHECKER_SENSITIVITY_2026-10-30.md).

## 2026-10-30 update — R62 separate AXI address-stall E2E

- Exact clean code/test SHA: `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`.
- `make uvm_mixed_precision_ddr_e2e_axi_stalls`: PASS; legal AR/AW backpressure configured, UVM severity `0/0/0`, AR/AW/W SVA cover matches `14/5/12`.
- Separate workload with no `-cm` database; do not merge its match counts into R61 URG (`22 properties; 17 success; 5 uncovered`). Consolidated SVA coverage remains open.
- Evidence: [R62 replay report](../../verification/COMPUTE_CLUSTER_R62_AXI_STALL_REPLAY_2026-10-30.md).

## 2026-10-30 update — R63 combined SVA closure evidence

- Exact clean code/test SHA `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`.
- URG merged R61 three-seed Compute Cluster VDBs with a separately identified coverage-enabled mixed-precision AR/AW stall E2E at the same SHA.
- 20/22 assertions have real successes; zero failures/incomplete; the two no-attempts are UVM RAL internals. Five top AXI AR/AW/W assertions succeeded; AR/AW/W stall covers matched 14/5/15.
- Functional coverage remains separately attributed to its workload. Broader fault/reset/fabric gaps remain; CL-DV-v1.0 stays HOLD.
- Evidence: [R63 combined SVA report](../../verification/COMPUTE_CLUSTER_R63_COMBINED_SVA_2026-10-30.md).


## 2026-10-30 update — R92 current-source SVA coverage

- R92: 16-seed coverage-enabled mixed-precision DDR/AXI E2E PASS; zero UVM warnings/errors/fatals and no UVM compile `Warning-`, `Error-`, or `[TFIPC]` diagnostics.
- Combined with exact R91 Cluster workload VDBs from byte-identical RTL/DV/SPEC source content, URG reports 20/22 assertion successes, zero failures/incomplete, and AR/AW/W stall covers `166/70/126` (3/3 hit). The two no-attempts are UVM RAL internals.
- E2E and AXI responder coverage bins meet their specified goals; functional coverage remains separately attributed by workload.
- Behavioral responder only: `OPEN-CL-003`, broad legal fault/phase/reset crosses, and the 14 PARTIAL RTM rows remain. `CL-DV-v1.0` is **HOLD**.
- Report: [R92 SVA replay](../../verification/COMPUTE_CLUSTER_SVA_REPLAY_R92_2026-10-30.md); raw log and report hashes are in the external `/tmp/nmaforge_candidate_4c5b_combined_sva_20261030/RUN_MANIFEST.md`.

## 2026-10-31 update — R123 CNM descriptor latch

- Executed clean test SHA `750fd0f9d27c8c2b0f0b9ed6f4a82f6cacb7ca45`, tree `c8b47296ee6492e8d258f4aa7dc46ebd97844711`; same tree published at test-only SHA `1abf84864a5b6f0f1d3ef5da72fe67b41df3b367`.
- Three-seed real-top UVM PASS: legal scalar SPAD write overlaps active CNM GEMV and mutates its fetched descriptor word; 16/16 outputs match signed four-bank K=64 Golden 47,104, both completions pass, scoreboard checks 41,776 words/seed with zero mismatch/unknown/stale/orphan, UVM severity `0/0/0`.
- Top Smoke PASS; checker sensitivity PASS `28/28`; declared `cluster_cg` is 100%. Mixed URG remains 55.34% with 17/22 assertion properties having real successes; five properties have no real success in this compute-only workload. No product RTL/SPEC changed.
- `REQ-CL-005` gains one bounded point and remains PARTIAL. RTM stays 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` stays **HOLD**. See [R123 report](../../verification/COMPUTE_CLUSTER_CNM_PARAMETER_LATCH_R123_2026-10-31.md).


## 2026-10-31 update — R124 CNM latch regression gate

- Executed clean code/test SHA `752c9e0327c18b8775f3bfac62f4cf5483dc38d7`, tree `9232a92b09f4fed7573ecdc50c786f5680b8281e`; published same-tree test content `863771c1062ff8390dc82c705594c5cef3289e3c`.
- Default three-seed UVM requires and passes `[CLUSTER_CNM_PARAMETER_LATCH_PASS]`; each seed checks 41,776 words with zero mismatch/unknown/stale/orphan and UVM severity `0/0/0`. Top Smoke and 28/28 checker-sensitivity mutations pass.
- This is a regression gate for one bounded CNM descriptor-latch testpoint. `REQ-CL-005` remains PARTIAL; 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.
- Evidence: [R124 report](../../verification/COMPUTE_CLUSTER_CNM_LATCH_REGRESSION_GATE_R124_2026-10-31.md).


## 2026-10-31 update — R125 selected fabric replay

- Clean replay checkout `5ea67bd125bb1ed20af8b86369e2cf8112f25131`; product RTL/DV/SPEC match the published R124 functional source content.
- Selected `ai_accel_memory_fabric` reset/epoch, banked reset, Core/Banked contention, and Core/Banked reset regressions pass on three seeds each. Applicable focused coverage groups reported by all four targets are 100%; owner SVAs have real successes and zero failure/incomplete.
- `OPEN-CL-003` remains closed for this selected fabric. `REQ-CL-018/PC-007` remain PARTIAL because broad production-engine fault/backpressure/reset combinations are still open; overall 24 PASS-SCOPED / 14 PARTIAL, **HOLD**.
- Evidence: [R125 clean replay report](../../verification/COMPUTE_CLUSTER_MEMORY_FABRIC_CLEAN_REPLAY_R125_2026-10-31.md).


## 2026-10-31 update — R126 requester stability gate

- Published same-tree test-gate content: `45497791e86468703303542a5961423a0311242c`; exact local replay: `175673b0930a81a00732ddff2cf825f358465cf9`.
- Three-seed Compute Cluster UVM passes. Each seed records nonzero stall samples for six scalar clients, Matrix banked/Line, and all four CNM lanes; existing checker reports zero stability violations and UVM severity `0/0/0`.
- Focused compute functional bins remain 100% for their declared scope. `REQ-CL-006` stays PARTIAL for broader stall × direction × phase combinations; overall 24 PASS-SCOPED / 14 PARTIAL, **HOLD**.
- Evidence: [R126 request-stability report](../../verification/COMPUTE_CLUSTER_REQUEST_STABILITY_GATE_R126_2026-10-31.md).


## 2026-10-31 update — R127 Scalar CMDQ GEMV/GEMM dispatch

- Executed test SHA 0b68ad884fa35f4f9b858953ffa5f3513fc124b4; published same-tree test content d9aae22f8a885a4075258a9ca8c27dbaa79bb80d, tree e1334264bb8962ed2d508affb0d273d89b6650ed.
- Three-seed VCS top UVM requires and passes sequential Scalar GEMV opcode 0x11 then GEMM 0x12 dispatch; checks launch fields/order, no busy relaunch, both completions, and 6/6 independent signed K=2 Golden outputs. Each scoreboard checks 41,832 words with zero mismatch/unknown/stale/orphan; severity 0/0/0.
- Top Smoke PASS; mapper reports 86 descriptors/60 tensors. Existing LOOP-REROLL-ENABLED warning retained.
- This narrows REQ-CL-002/015/020 only; all remain PARTIAL. Overall RTM is 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD.
- Evidence: [R127 report](../../verification/COMPUTE_CLUSTER_SCALAR_CMDQ_GEMV_GEMM_R127_2026-10-31.md).


## 2026-10-31 update — R128 Scalar CMDQ numeric boundaries

- Exact clean-worktree test SHA dfbebbd8c8ee68458c4261f74f041e816b6b0284; published same-tree content 0e38b482e13eefa759441ac8ed1ab3d4d6246b37, tree a5adb3db01aee36f8363eb63a67194d5078d2398.
- Three-seed VCS top UVM passes seven legal Scalar GEMV M=1/K=1 CMDQ descriptors covering signed bias extrema, saturation, arithmetic shift 31, and identity/ReLU/ReLU6. Every seed hits case_mask=7f, checks 7/7 Golden outputs/completions, and checks 41,961 memory words with zero mismatch/unknown/stale/orphan; UVM severity 0/0/0.
- Focused declared cluster_cg is 100%. URG assertion and AXI profile residuals remain disclosed.
- REQ-CL-002/015/020 gain bounded evidence and remain PARTIAL; RTM stays 24 PASS-SCOPED / 14 PARTIAL, CL-DV-v1.0 HOLD.
- Evidence: [R128 report](../../verification/COMPUTE_CLUSTER_SCALAR_CMDQ_NUMERIC_BOUNDARY_R128_2026-10-31.md).

## 2026-10-31 update — R129 Scalar GEMV accepted-write Abort prefix

- Exact clean-worktree test SHA 8b511e474727fe13439f99674d1a30b46005f274; published same-tree content 1ba30c7f85d5b07c13eddb7aef3e6929f7d9624d, tree 4a52f377cf93d008e8effd1310b94478713e82fc.
- Three VCS seeds pass legal real-CMDQ Scalar GEMV M=16/K=64 Abort after one accepted output write; Golden prefix 1/16, 15 intact sentinels, 130/130 reads drained, ERR_ABORT 0x32, zero post-Abort writes, UVM severity 0/0/0.
- Memory scoreboard checks 42,107 words with zero mismatch/unknown/stale/orphan. Focused cluster_cg is 100%; overall mixed URG score 55.92%. No RTL/SPEC change.
- REQ-CL-017/019/027 and REQ-PC-006 gain bounded evidence and remain PARTIAL. RTM remains 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 HOLD.
- Top Smoke and mutation campaign were not rerun for this UVM-only change.
- Evidence: R129 report (../../verification/COMPUTE_CLUSTER_SCALAR_GEMV_ABORT_PREFIX_R129_2026-10-31.md).

## 2026-11-02 update — R197 selected memory-fabric owner/contention/reset replay

- Fixed code/test SHA `f87acc9bca3b3ecece385fadfd5623de6837ea8d`; detached clean worktree at the matching tree `cfc7ba4955488ae58d58f36deec368173c6ec98c`.
- Four existing banked owner/contention/reset targets pass three seeds each with UVM severity `0/0/0`; contention and reset functional groups are 100%, and owner/tag assertions have real success with no failure/incomplete.
- The same SHA's R194 real-top UVM reports 320 Matrix/CNM shared-bank admissions per seed, 768 Matrix and 1,120 CNM responses, and zero owner/hold/route mismatch.
- This strengthens only selected fabric and named production Matrix/CNM points. `REQ-PC-006/007` and `REQ-CL-018` remain PARTIAL; aggregate status remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD.
- No RTL or test source changed. Evidence: [R197 report](../../verification/COMPUTE_CLUSTER_MEMORY_FABRIC_OWNER_CONTENTION_RESET_R197_2026-11-02.md); logs-only archive SHA-256 `83f03ec53a1e0344e017ccd9b8af20bfab7d0c0c8e2757ad4fe418f10e54d153`.

## 2026-11-02 update — R198 Matrix Line contract clean replay

- Fixed code/test SHA `f87acc9bca3b3ecece385fadfd5623de6837ea8d`; detached clean worktree at tree `cfc7ba4955488ae58d58f36deec368173c6ec98c`.
- The enabled 16×16 Matrix core regression passes 18 numerical/layout and 35 fault/recovery cases on each of three seeds. It checks full WSTRB, 16-byte Line alignment, 312 stall-stability samples, unaligned scalar fallback and Protection error. Partial/zero WSTRB are unsupported by SPEC v1.5.
- The separately compiled prefetch-disabled fallback and five-workload marker pass all three seeds. This uses the block-level one-cycle behavioral SPAD model, not ASIC timing or PPA.
- `OPEN-CL-004` is replayed at the current candidate; `REQ-CL-010` remains PARTIAL because the enabled raw FSM is 49/53 and wider request/fault crosses remain open. Overall status remains 24 PASS-SCOPED / 14 PARTIAL, HOLD.
- Evidence: [R198 report](../../verification/COMPUTE_CLUSTER_MATRIX_LINE_CONTRACT_R198_2026-11-02.md); archive SHA-256 `1a0099840d43316a6bb320a6fd4d5da2b51b5702c003fd0d00df202cd1fd8690`.

## 2026-11-02 update — R199 exact published-HEAD replay attempt

- Clean detached checkout: published closeout HEAD `353695f4badca20a8a12a515393af0d59a4b66b5`, tree `c79b4f100adc83400a486adc5de007d311bfe1ee`; underlying RTL/test SHA remains `f87acc9bca3b3ecece385fadfd5623de6837ea8d`.
- The three-seed UVM compile queued for `VCS-BASE-COMPILE/VCSCompiler_Net`; VCS and a local reachability check could not reach the configured license service. No sim image or test seed ran. Result is `BLOCKED_ENV`; Top Smoke, seeded Top, and combined coverage merge remain NOT_RUN at this exact HEAD.
- Prior PASS evidence stays tied to its exact tested code/test SHA. RTM remains 24 PASS-SCOPED / 14 PARTIAL; CL-DV-v1.0 remains **HOLD**.
- Evidence: [R199 report](../../verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R199_2026-11-02.md); archive SHA-256 `d9459a09a06ad173323a04f65c494ef7b79f9e334e240cd83ac5a67cafe99376`.

## 2026-11-02 update — R200 Execution RTM integrity checker

- Added `tools/verify_compute_cluster_rtm.py` to check expected IDs, duplicate/missing rows, disposition labels, six-column formatting, and required Test/Checker, Coverage, Run/Seed, and Evidence fields.
- `python3 tools/verify_compute_cluster_rtm.py` passes 28/28 `REQ-CL` plus 10/10 `REQ-PC` rows; disposition counts are 24 PASS-SCOPED / 14 PARTIAL. The check does not verify historical artifact contents or promote sign-off.
- Evidence: [R200 report](../../verification/COMPUTE_CLUSTER_RTM_INTEGRITY_R200_2026-11-02.md). Exact published-HEAD VCS replay remains `BLOCKED_ENV` under R199.

## 2026-11-02 update — R202 RTM evidence-link audit

- Extended the RTM checker to verify repository-relative Markdown evidence targets. All 92/92 linked targets resolve; it deliberately excludes absolute `/tmp` artifacts and does not inspect evidence sufficiency.
- The 38-row matrix and its 24 PASS-SCOPED / 14 PARTIAL dispositions are unchanged; CL-DV-v1.0 remains **HOLD**.
- Evidence: [R202 report](../../verification/COMPUTE_CLUSTER_RTM_LINK_AUDIT_R202_2026-11-02.md). VCS rerun remains pending license-server reachability.

## 2026-11-02 update — R203 exact latest-HEAD replay retry

- A detached clean worktree at local commit `518b75541e32878998c9dd478a692f0ba27c0982` (tree `03c034bf30e5bbb2af2200411fa0b1e674ebf3d6`; published same-tree commit `18059052b73ad1507f7b754108b9c84ed75a929a`) was used for the three-seed Compute Cluster UVM target.
- VCS could not reach the configured license service, queued for `VCS-BASE-COMPILE/VCSCompiler_Net`, and was stopped by the 120-second timeout before producing a simulator image. No seed, Top Smoke, or seeded Top test ran. Result: `BLOCKED_ENV`.
- RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**. No product RTL or test source changed.
- Evidence: [R203 report](../../verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R203_2026-11-02.md); raw log remains outside repository at `/tmp/nmaforge_r203_compile.log`, SHA-256 `3103ee7046612a59855f0094d61574a4ce4c2c4cf71d0454eafc0fce10e6b95c`.

## 2026-11-02 update — R204 latest clean-candidate verification

- The user restored VCS license access. A detached clean worktree at `bce4f81ef37158cf80e46f5804256c8e7531a9d9` passes three-seed Compute Cluster UVM, Top Smoke, a 20-case seeded Top run, 16-seed mixed E2E coverage, and 7/7 real RTL mutations.
- Combined URG reports all 21 declared functional groups at 100%; RTL/test line/condition/FSM/branch coverage is 73.70/68.72/46.69/64.70%. Assertions are 20/22 with zero failures/incomplete and two UVM RAL no-attempts; all 3 cover properties match.
- The clean replay closes the immediate environment/reproducibility gap only. RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD** pending legal cross and contract dispositions.
- Evidence: [R204 report](../../verification/COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R204_2026-11-02.md); archive `/tmp/nmaforge_r204_evidence_20261102.tar.gz`, SHA-256 `9f32c098463213e338cd6ef4a9da9b44631771b17f48c0350bc7fbca4d3a490f`.

## 2026-11-05 update — v2 candidate status at `33e8528`

- Baseline audit: published `main` is still R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`; the v2 branch merge-base is that SHA, and review start `eb158880d11bf7f8baf13ece4a888107877356fd` is an ancestor. No v1 closeout branch was merged and `main` was not modified. See [v2 architecture review](../../architecture/NMAFORGE_V2_ARCHITECTURE_REVIEW.md).
- P1 Matrix performance replay at `550ef39f22c22c39eb3bfd7f38dbc574b630e163` passed 165/165 Golden points (array sizes plus 8-way depth/prefetch/A-cache ablation) on three Seeds. It uses a one-cycle behavioral SPAD and is not PPA.
- Product GEMV Cache×Prefetch replay at RTL/test SHA `b9d593e5f55869ff4a47748013a4b15dcd60f83f` passed 48/48 full output Golden points across M8/M16, K19/K65, four settings, and three Seeds. Existing B-fold reuse dominates the measured benefit; no additional bank-aware scheduler RTL was justified.
- At fixed current candidate `33e85287fbf37187fccb76e97be6effe888670e9`, Tile Forwarding core OFF/ON passes 6/6 runs and real Top CMDQ Smoke passes 3/3 Seeds. Mean core consumer cycles are 141→118; the selected consumer source-A reads fall 32→16 (512→256 B). See [fixed-SHA replay report](../../verification/V2_P2_TILE_FORWARD_MULTISEED_REPLAY_2026-11-05.md) and [machine-readable run matrix](../../../benchmark/architecture_v2_experiment_matrix.csv).
- The older VCS license failures remain historical attempts only. The license-restored descriptor-validator replay at commit `cc7c6b23ef0aa34d50033603c3f8f77489b30220` passed its named 33 invalid-rule, boundary, and tile-forward descriptor checks. Those validator counts retain that exact earlier identity; this update does not imply a current-SHA validator rerun.
- Open: new-opcode Parity/Protection and wider fault-phase coverage, held-response/error recovery, cross-engine coherence, complete RTM/coverage/mutation closure, current-SHA TinyNPU matched benchmark, DC/PPA/power, trained CNN/Transformer inference, and ASIC readiness. `CL-DV-v1.0` remains **HOLD**; no TinyNPU win or Tapeout readiness is claimed.

## 2026-11-05 update — v2 legal cross-engine forwarding check at `0870a76`

- Added a Top CMDQ scenario for the documented non-coherent `0x53` contract: while Matrix consumes the tagged `0xb000` tile, an SFU command reads/writes disjoint SPAD regions. The testbench watches seven compute write clients plus Matrix line writes for source-tile write attempts and checks both complete output images and completion records.
- VCS `V-2023.12-SP1_Full64`; `make ai_comp`, then `./simv +ntb_random_seed=<seed> +AI_RANDOM_CASES=4 +AI_SEED=<seed> +ACLK_PERIOD_NS=10.0` on seeds 20261105/06/07. All three runs pass. Each sees Matrix/SFU busy overlap and 23 accepted SFU SPAD accesses while consume is active; source is unchanged and both Golden images are bit-exact. Existing `LOOP-REROLL-ENABLED` fixture notice remains informational.
- Code/test commit `0870a76b803ad01b8c23d812cfddd9cbb399f74e` (tree `bb7b6acef1e4262c7facd0b259b9f413cd559975`). No product RTL changed. Logs archive SHA-256 `fb2f2d70128fc919a4d767b11c1257024760a3e9b5019a68b44286cef78662c2` at `/tmp/nmaforge_v2_cross_engine_three_seed_final_0870a76_logs.tar.gz`.
- `REQ-V2-053-007` advances from `NOT_RUN` to **PARTIAL**. This proves legal unrelated Matrix+SFU traffic only; DMA overwrite, intentional illegal source mutation, all engine pairings, and full owner/error crosses remain open. The source-immutability rule remains a software contract, not hardware coherence. v2 sign-off remains **IN PROGRESS**.

## 2026-11-05 update — scoped v2 feature coverage at `86e0d6c`

- Added a functional covergroup and Top Smoke gate for the legal 0x53 Matrix+SFU disjoint-region handoff. The group samples Matrix/SFU overlap, accepted SFU SPAD traffic during consume, no attempted compute write to the source tile, Golden success, and an overlap × traffic cross.
- `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105` passes. DUT-only Top URG at fixed test SHA `86e0d6cbba3187bd1deeb18f664c559b606c878d` passes seeds 20261105/06/07. The new v2 group scores 100% on all seeds and in merged URG.
- Overall functional group score is 20%: four existing AXI-memory groups remain at 0%. DUT-only Line/Condition/FSM/Branch is 86.75/77.62/44.33/84.56%; Matrix FSM is 15/15 states, 25/55 transitions. Feature-wide bins, transition disposition, and exclusions remain open; no sign-off claim.
- Code/test SHA `86e0d6cbba3187bd1deeb18f664c559b606c878d`, tree `497eaef649c3995c97cb533a9c410417d63ee0de`. No RTL changed. Coverage archive `/tmp/nmaforge_v2_86e0d6c_dut_cov_evidence.tar.gz`, SHA-256 `eb25d2725fa8e3252c0140d0c7254c3abfc03fd1ef44d1ecbd2283e75becd4f8`.

## 2026-11-05 update — actual v2 candidate DUT mutation replay at `bdfda3c`

- Replayed `make -C dv/uvm/sim uvm_compute_cluster_dut_mutation` with VCS `V-2023.12-SP1_Full64`, seed 20261025, and temporary source variants only. All seven injected RTL defects were caught by their intended checker: shared-SPAD address/data/response owner, Matrix WSTRB, Completion error code, missing Done, and duplicate Done (7/7).
- Run ID `V2-DUT-MUTATION-7X1-BDFDA3C`, source SHA `bdfda3c408a1367ac6b1788ebb9bdb0e5b6f7d47`, tree `89eac43b0b9aa6811608f6587272ec564ea2b456`. Logs archive `/tmp/nmaforge_v2_dut_mutation_bdfda3c_logs.tar.gz`, SHA-256 `a4104e43f95243d75525bab9023f75d7d6831a3fe75eec2333efb7b21d87e95b`.
- `REQ-V2-COM-005` advances in evidence but remains **PARTIAL**: every checker for every new feature has not yet been mutation-mapped, and broader fault-phase crosses, functional coverage and sign-off remain open. No product RTL changed.

## 2026-11-05 update — current-candidate GEMV four-way replay at `17b09e0`

- VCS `V-2023.12-SP1_Full64` rerun passed 48/48 independent-Golden points: four Cache×Prefetch configurations, shapes M8/M16 × N16 × K19/K65, Seeds 20261105/06/07; depth 4 and 16×16 array. The memory endpoint is a registered four-bank behavioral SPAD responder, not full Top contention.
- B-fold Cache reduced cycles 22.26–41.64% and reads 35.19–56.47% in these workloads. Next-K Prefetch added 2.05–2.35% on the M8 cases with Cache ON but regressed the M16 cases by 0.64–0.80%. Writes were unchanged. Useful throughput in both-enabled runs is 15.97–26.32 MAC/cycle and 6.24–10.28% of 256-MAC peak across the tested shapes.
- The checked summarizer confirms mutually exclusive state cycles close exactly to Command Cycles on all 48 points; stall/active counters remain explicitly overlapping. Outputs: `benchmark/v2_p2_gemv_cache_prefetch_4way_17b09e0.{csv,svg}` and `benchmark/v2_p2_gemv_cache_prefetch_4way_17b09e0_summary.json`. Evidence archive `/tmp/nmaforge_v2_gemv_four_way_17b09e0_logs.tar.gz`, SHA-256 `c22d07de2b86de467e8fe05d6426cfd5cb6bf8fada4260b4535a5badc6a24681`.
- No Bank-Aware Issue RTL is added: these runs do not include contending engines on the system Arbiter. The Top contention experiment, wider M/N/K shapes, and PPA cost remain open.

## 2026-11-05 update — real Cluster contention benchmark at `17b09e0`

- `make -C dv/uvm/sim uvm_compute_cluster_regress` passes on Seeds 20261025/26/27 and merges URG. The same four-task CMDQ workload measures 1,696 serial vs 1,137 parallel cycles (ratio 1.492, 32.96% fewer cycles) with equal 4,352 B reads / 2,688 B writes. A matched three-task staged case measures 1,239 serial vs 1,070 staged cycles (ratio 1.158).
- The production Compute Cluster and shared Arbiter record 333 Matrix/CNM bank collision cycles, 320 admitted collisions, 320 Matrix wait cycles, 320 held-payload checks and zero ownership/hold/route violations. Matrix line backpressure checks also pass with 84 stable-payload observations and zero violations.
- Run ID `V2-CLUSTER-SERIAL-PARALLEL-CONTENTION-3SEED-17B09E0`, source/test SHA `17b09e068e988ca35480ffd638d865872e9ba564`; outputs are the `v2_p2_cluster_*_17b09e0` CSV/JSON/SVG files. Logs archive SHA-256 `a2c2daa85ba57c1617239498c60636763584707f43bb93c345f5e01f7c6d8fbe`.
- The observed benefit is from allowing this legal queued workload to overlap under the existing scheduler. No alternate Bank-Aware Issue policy was compared; the evidence does not justify RTL changes or a general speedup claim. Per-engine stall partition, other workload shapes and PPA remain open.

## 2026-11-05 update — current fixed candidate `410b81d`

- Candidate source/test SHA `410b81dfd37992a760b28258bb7e8c6b6f5017d7`, tree `e608e788cf5cc49165d835003c87920259cc84b4`; direct remote check found published branch commit `6862c68035387fe70441b617b6797b6e070963a6` with the same tree. Published `main` remains R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`. No product RTL changed in this increment.
- Fixed-SHA VCS results: Matrix 0x52/0x53 three-seed fault/GEMV replay, Top Smoke, Top URG, seven-engine Cluster UVM, 15 opcode-core mutation checks, and seven DUT mutations all passed in their stated scope. Overall v2 DV is still **IN PROGRESS**, with unexercised SVA matches, incomplete functional groups and requirement rows. See the [DV report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
- Current GEMV Cache×Prefetch benchmark passes 48/48 Golden points with exact cycle-partition closure. B-fold Cache reduces cycles/read bytes on all four tested shapes; Prefetch benefit depends on M. Current serial/parallel Cluster benchmark is 1,696/1,137 cycles (1.492× for one workload), same SPAD bytes, behavioral four-bank RAM. This does not prove alternate-arbiter benefit. Raw artifacts and caveats are in the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).
- Current Digits rerun passes 360/360 Golden outputs, 352/360 classification, 34,761 cycles at source/test SHA `410b81d`. Trained CNN and Transformer remain **NOT_RUN**; no TinyNPU win is claimed. See the [model report](../../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md).
- ASIC: current-candidate lint completed (0 errors, 465 warnings, 5 infos); the scripted CDC attempt stalled and bounded RDC timed out, while DC/LEC/physical runs remain unavailable or not run. Status remains **NOT ASIC READY**; see the [ASIC readiness report](../../verification/NMAFORGE_V2_ASIC_READINESS.md).
- Evidence archives: `/tmp/nmaforge_v2_current_410b81_signoff_logs.tar.gz` SHA-256 `c9f88930f24c3ca74140ba48e06d91f3fdbd0d37585fff0f9dac3ded15404ce5`; `/tmp/nmaforge_v2_current_410b81_gemv_digits.tar.gz` SHA-256 `26b751910afa296181c1e85aab39910b71f0cdd49e196f493a5cdf1a22f9d5fa`. Generated simulator databases/logs remain outside Git.

## 2026-11-05 update — current-candidate TinyNPU workload replay at `d1867da`

- Current NMAForge 16×16 Matrix run passed the pinned TinyNPU GEMM vectors at 16×16×16, 16×16×32 and 32×32×64 with independent Golden. Cycles are 172/263/1,391; measured SPAD reads are 512/1,024/6,144 B. Pinned TinyNPU direct-array cycles are 52/100/790; serialized memory endpoints are estimated at 151/231/1,305 cycles. Ratios NMAForge measured / TinyNPU estimated are 1.1391/1.1385/1.0659, so these points do not show an NMAForge win.
- Current top-level fixed `conv1x_mini` replay passes all intermediate tensors and four outputs byte-exact: 1,985 compute cycles, 1,080 host-layout cycles, 3,360/1,600 B compute SPAD read/write. TinyNPU's 4,781-cycle graph value is carried from its pinned prior replay and has a different timing boundary; no ratio is claimed.
- Run HEAD `d1867da79a84b17451d63e919f9ce1e8ef4df098`; product RTL/test files are unchanged from candidate `410b81d`. VCS `V-2023.12-SP1_Full64`; Python 3.12.13 / NumPy 2.4.6 / ONNX 1.17.0. Exact CSV/JSON and limits are in the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md) and [model report](../../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md). Archive `/tmp/nmaforge_v2_tinynpu_current_d1867da_logs.tar.gz`, SHA-256 `018d11dc90159192f0fb13c5e5901269b66be7ff8013bf4891cfd26b1e9e7885`.
- The current environment does not have Verilator; the pinned TinyNPU executable was not rebuilt in this replay. Trained CNN/Transformer, current TinyNPU RTL rebuild, and common RTL memory adapter remain OPEN.

## 2026-11-05 update — repository memory-fabric reset/epoch replay

- `make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress` passes seeds 20261025/26/27 at source/test SHA `f340acaa2cdf7c36075473b8bc6fd6dee8e59873` (tree `7fc556427be1597e64a602c10af4fdd855a0c343`), with VCS/URG `V-2023.12-SP1_Full64`. Each seed checks reset with four DMA reads outstanding and a CNM accepted SPAD read without its response, plus reset while CNM awaits its result write; both fresh DMA and CNM tasks recover and pass memory Golden checks.
- The named groups `dma_cnm_shared_reset_cg`, `dma_reset_phase_cg`, and `cnm_reset_phase_cg` are each 100.00% in merged URG. `ap_single_response_owner` has 3,921 real successes; `ap_cnm_response_tag` has 144; assertion failures/incomplete are zero. Whole-report functional group score is 23.98%, so this targeted result does not imply full v2 coverage or arbitrary external-fabric behavior.
- Run ID `V2-MEMORY-FABRIC-RESET-3SEED-F340ACA`; logs/selected URG pages archive `/tmp/nmaforge_v2_fabric_reset_f340aca_logs.tar.gz`, SHA-256 `14144bdc62932d8040a1b5be72b27f83e6f4f8e52286a8658b1570fdfe3717c5`. Generated VCS/coverage databases remain outside the repository. `REQ-V2-COM-006` passes only for this in-repository reset/recovery scope; v2 sign-off remains **IN PROGRESS**.

## 2026-11-05 update — legacy Top compatibility replay

- Clean detached worktree at source/test SHA `5f6e282f191b421bdbefc3d252690a9a0c93eb1c`, tree `4a5e0a1da1ab7d5a910c6f0a9417304d8a752cb2`; VCS `V-2023.12-SP1_Full64`. `make -C dv/subsystem/top_smoke/sim ai_comp` followed by `./simv +ntb_random_seed=$seed +AI_RANDOM_CASES=20 +AI_SEED=$seed +ACLK_PERIOD_NS=10.0` for seeds 20261108/09/10. All three logs report `TEST PASS`.
- Each seed checks 7 legacy `0x30` Tensor GEMM outputs and 4 legacy `0x31` two-head Batch GEMM outputs, plus randomized GEMV/GEMM/Conv/Depthwise results and current v2 smoke paths. This closes `REQ-V2-COM-002` for these tested modes/shapes only; exhaustive descriptor, aux-field and fault/concurrency compatibility remains open. No product RTL or testbench source was changed.
- Logs archive `/tmp/nmaforge_v2_top_compat_5f6e282_logs.tar.gz`, SHA-256 `a56378fc6a1364ee4fdcc8f34dcf21b47068270d473ba7b848cdaef6b2a65b3c`. The only compile notice is the existing `LOOP-REROLL-ENABLED` debug-capacity message.

## 2026-11-05 update — current static-analysis evidence at `410b81d`

- SpyGlass V-2023.12-SP1 lint ran on the current fixed candidate: 0 errors, 465 warnings, 5 infos, 0 waivers. Warnings are triaged by rule in [LINT_TRIAGE](../../../dv/spyglass/LINT_TRIAGE.md); counts are not unique defect counts because `W415a` and `InitValUsingNBA` overlap.
- The scripted CDC run stalled during `cdc_setup` with no report for 6m10s and was terminated (exit 143); current CDC remains **NOT_RUN**. RDC was bounded to 180s, reached `Ar_resetcross01` at rule 385/478 and about 6.1 GB RSS, then timed out (exit 124); it remains **NOT_RUN**.
- The historical structural CDC CSV identifies `Reset_sync04` on the shared async `aresetn` feeding two `aclk` state pipelines. The written spec does not freeze reset deassertion timing, so integration reset contract and release verification stay **OPEN**. `FLAT_504` marks partial analysis of a 16,384-bit Matrix accumulator mux against a 1,024-bit limit; it is not waived or treated as a functional pass.
- DC executable exists, but private libraries/SDC and the referenced DC script do not. Base-vs-v2 PPA is **BLOCKED_ENV**; no ASIC metrics are reported. Evidence snapshot `/tmp/nmaforge_v2_410b81_static_eda.tar.gz`, SHA-256 `178d3267e55304a0c173a9fc89facd547fb7926b516c3c672e1e9ed710dfab60`.

## 2026-11-06 update — v2 feature coverage at `380f961`

- Testbench/build-only commit `380f96114dba022300db09fb217264c3a606a2fd` (tree `79aaf0782aba0da18d7109b74ae2bd343a473181`); no product RTL changed. Added six named GEMV shape bins, eight selected 0x52/0x53 fault bins, six Tile Forwarding bins, and a reproducible Prefetch-OFF GEMV target.
- VCS `V-2023.12-SP1_Full64`, Seeds 20261108/09/10: Prefetch ON and OFF each pass all six GEMV Golden shapes; selected opcode faults pass 8/8 named bins; Tile Forwarding passes 6/6 bins in each enabled run. Repeated same-tag consume returns to SPAD after one-shot tag invalidation and remains bit-exact.
- Same-profile URG merge is 12 tests with all three new feature groups at 100%. Matrix selected-hierarchy code coverage is Line/Condition/FSM/Branch 93.90/90.88/92.42/96.62%. Prefetch-OFF is separately reported because its DUT compile-time structure differs. No global v2 closure is claimed.
- Evidence archive `/tmp/nmaforge_v2_feature_coverage_380f961_evidence.tar.gz`, SHA-256 `6529ad5fdbd74f9441be0882180aecde077f6b388fed9bca4a2bccef7f0d63ad`. Exact run IDs, commands, and RTM status are in [DV Closure](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
- Current state: v1.0 Compute Cluster **HOLD**; v2 DV **IN PROGRESS**; performance values remain tied to prior benchmark SHAs; trained CNN/Transformer **NOT_RUN**; ASIC readiness **NOT READY**. Next: close remaining descriptor alias/range, broader legal fault-phase crosses, feature SVA and system-level coverage without changing product RTL absent a demonstrated defect.

## 2026-11-06 update — v2 request/backpressure checks at `e7daa34`

- Testbench/build-only commit `e7daa34d17d8b3c06d2aaf16c1cc66d3bf8ff50a` (tree `3807f483155df1be4271c25a165a64512a83d04e`); product RTL is unchanged. Added deterministic 0x52 three-cycle bank request backpressure, a VALID/address stability monitor with legal Abort/error/watchdog cancellation, and a separate URG group for GEMV request stall plus 0x53 held line-write backpressure.
- VCS `V-2023.12-SP1_Full64`, Seeds 20261111/12/13: handshake campaign, existing 18 functional + 35 fault Matrix-core regression, selected 0x52/0x53 opcode-fault campaign, and Prefetch-OFF six-shape GEMV replay all pass. The new URG handshake group is 2/2 (100%), three hits per bin; each released GEMV request completes bit-exact and drains.
- A first checker run correctly exposed the existing legal watchdog cancellation path; the checker now permits that cancellation and the final three-seed compatibility run passes. This was a testbench checker correction, not an RTL failure.
- Evidence archive `/tmp/nmaforge_v2_opcode_handshake_e7daa34_evidence.tar.gz`, SHA-256 `20f88eb467383ad65c1ba29d819af053cafc3326dca06f4c0f4c4816bf9e7cb8`. Exact commands and remaining scope are in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
- Current state remains: v1.0 Compute Cluster **HOLD**; v2 DV **IN PROGRESS**; `REQ-V2-052-007` PARTIAL pending multi-engine owner/hostile response evidence; `REQ-V2-053-004` PASS only for directed local line-ready stall. No benchmark, model, or PPA results changed. Next: broaden legal fault × phase/reset scenarios and add opcode-specific non-vacuous SVA; keep external-fabric behavior separate from repository-fabric evidence.


## 2026-11-06 update — request-address mutation at `ab96d47`

- Testbench/mutation-runner-only commit `ab96d47876beb4d7e47fef01e43b4c4716dd176a` (tree `1126cb6e650545fdc0bad003c321a77fe552e3a4`); product RTL is unchanged. Run ID `V2-OPCODE-MUTATION-6X3-AB96D47`, VCS `V-2023.12-SP1_Full64`, Seeds 20261111/12/13: six actual temporary mutations × three Seeds = 18/18 caught. Mutations cover output data, output address, response operand owner, WSTRB, tile tag, and bank request address instability during `VALID&&!READY`.
- The address-hold mutant is detected by the request stability checker; response-owner corruption is detected by the GEMV Completion/Golden checker. On this SHA, the three-seed Matrix core 18-functional/35-fault, selected opcode fault, request/line backpressure, and Prefetch-OFF six-shape campaigns pass. URG handshake group is 2/2 with three hits per bin. Exact commands and limitations are in [DV Closure](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
- Evidence archive `/tmp/nmaforge_v2_request_mutation_ab96d47_evidence.tar.gz`, SHA-256 `f137212c354e79f890c4c36f78ca9197694b6853524b1a87b6b9ba5add7fcb03`.
- The increased mutation count improves checker evidence only; it does not close all checker mappings, opcode-specific SVA, external response ownership, legal fault × phase × reset crosses, or the full v2 RTM. Overall v2 DV remains **IN PROGRESS**. Performance, model, and ASIC results are unchanged; TinyNPU parity is not established and ASIC readiness remains **NOT READY**.


## 2026-11-06 update — current-candidate Matrix eight-way ablation

- Run `V2-MATRIX-EIGHT-CONFIG-3SEED-36D4B9B` used current source/test SHA `36d4b9b4bbafe769b452afc003033d2a222a682f`, fixed 16×16/256-MAC array, five GEMM workloads, one-cycle behavioral bank response, three Seeds, and all eight depth/prefetch/A-Tile Cache combinations. VCS `V-2023.12-SP1_Full64`; 120/120 independent Golden points passed.
- Across the five workloads, depth 4 + Prefetch + Cache averaged 2,038.33 summed cycles vs 2,720.00 baseline (−25.06%), with read bytes 12,032→9,472 (−21.28%) and writes unchanged at 7,488 B. Weighted MAC/cycle is 34.07→45.46; weighted utilization 13.31%→17.76%. Per-workload best settings vary, so no universal winner is claimed. Stall/event observations overlap and are not additive.
- CSV/JSON/SVG are in [the benchmark artifacts](../../../benchmark/v2_matrix_config_closure_f9f32f7_3seed.csv); the exact command and model caveats are in the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md). Raw compile/run logs archive SHA-256 `003c1dedc0de9d3b9875dec63a218fade601e1a09d9b928b791bb250599741fd`.
- This is controller RTL simulation using behavioral SPAD and does not replace the multi-engine Top contention benchmark or provide ASIC PPA/TinyNPU victory. Current v2 DV remains **IN PROGRESS**, trained CNN/Transformer remain **NOT_RUN**, and ASIC readiness remains **NOT READY**.


## 2026-11-06 update — Opcode 0x52 request stability formal

- Formal-only commit `b719ac6066616b17dfab4eed2429f8bdfdc49457` (tree `d269b738226282ea1057f1832fcd41ee51e61b6e`); product RTL is unchanged. VC Formal `V-2023.12-SP2` completed `gemv-request-stability`: setup clean, request hold property 1/1 proven and non-vacuous, hold/release cover 1/1 reached at depth 4. The bounded descriptor is M1×N1×K1 with an accepted-response-owner assumption.
- Evidence archive `/tmp/nmaforge_v2_gemv_req_sva_b719ac6_evidence.tar.gz`, SHA-256 `e8f19d5fde55c5067265f8e9d7a2e203a515d4933723ecc50ff5d3f2762ac189`. The [DV report](../../verification/NMAFORGE_V2_DV_CLOSURE.md) records the property, exact command, and scope.
- This closes only the 0x52 request VALID/address stability assertion. 0x53 lifecycle SVA, broader error/reset proof, cross-engine response ownership, and full v2 RTM remain open; overall v2 DV remains **IN PROGRESS**.

## 2026-11-06 update — 0x53 forwarding runtime SVA at `6a25338`

- Testbench/build commit `6a253386f53638a1206a75e359d6020ba27765cb` (tree `588806486bd6b22fc0444cd0e29dc108d9f993d3`) adds two SVA for complete 16-line Tile commit and destination-tag stability. Product RTL is unchanged.
- VCS `V-2023.12-SP1_Full64`, Seeds 20261120/21/22: forwarding ON/OFF chain regression passes. Each enabled run has 2/2 assertion attempts, zero failures, one cover with three matches, non-vacuous commit evidence, and 6/6 named functional bins. Golden outputs, tag-miss fallback, repeated-consumer SPAD fallback, Bank Flip, Abort and Reset checks pass.
- Evidence archive `/tmp/nmaforge_v2_tile_sva_6a25338_evidence.tar.gz`, SHA-256 `92efa5d9763114cc6fdf121d2b22744c06852ff6e9c66072503d054a53656f15`. Exact command and RTM disposition are in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
- `REQ-V2-053-002` advances for the tested core cases; `REQ-V2-COM-003` remains PARTIAL because 0x53 is runtime assertion evidence rather than formal proof, and broader error/reset and cross-engine ownership checks remain open. v2 DV stays **IN PROGRESS**.

## 2026-11-06 update — 0x52 real CMDQ descriptor rejection

- Testbench-only commit `c26064e3dda40ce26490c5c93b3e741529946c58` adds real-top invalid GEMV descriptors for padded-A alias, dense-B alias, 16-byte source misalignment, and a true 32-byte source-span wrap. An initial K=1 vector ended exactly at `2^32` and correctly did not qualify as wrap; it was corrected to K=17. RTL and checker strictness did not change.
- VCS/URG `V-2023.12-SP1_Full64`; `V2-CMDQ-GEMV-DESC-REJECT-3SEED-C26064E`; Seeds 20261109/10/11. All three pass 12/12 invalid CMDQ descriptors, `ERR_DESC=12`, no launch, zero compute/DMA request cycles, 24/24 sentinel/guard checks, and 12/12 focused bins. Focused URG group `cmdq_invalid_descriptor_cg` is 100%. Aggregate Line/Condition/FSM/Branch/Assert/Group is 69.65/63.34/45.62/58.03/72.00/79.18%; this is not global coverage closure.
- Logs-only archive: `/tmp/nmaforge_v2_cmdq_reject_c26064e_logs_v2.tar.gz`, SHA-256 `87bfc434c78426ccfade5cc2b583f5ea56a19d66b9366c7939e515b435142029`. Full scope and exact command are in [DV Closure](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
- Phase 0 confirmed the original `/home/ray/workspace/NMAForge` branch `feat/shape-adaptive-gemv-v2` is divergent from the target v2 branch: merge base `b5b6ff25ed41fb5ea4c9a5043360063cec58f7ac`, target branch 446 unique commits, original branch 64 unique commits. Original worktree HEAD `c290eba7697138a4fcf2cbbac9262264849f0aeb` has pre-existing untracked `novas.conf` and `novas.rc`; both were left untouched. No branch merge/cherry-pick was done.
- Current status remains v1.0 Compute Cluster **HOLD**, v2 DV **IN PROGRESS**, trained CNN/Transformer **NOT_RUN**, and ASIC readiness **NOT READY**. Next smallest DV task: expand legal 0x52 alias/range rejection to runtime external/in-flight SPAD scenarios and map those requirements to accepted/returned/discarded response evidence; then repeat fixed-SHA Clean Replay and refresh RTM. Broader benchmark/model/ASIC plan items remain OPEN as documented.

## 2026-11-06 update — legal 0x52 GEMV through real Top CMDQ

- Testbench/build-only commits `c3b6b4a2967edc17e8229151210132959b351f9b`,
  `fc8f6db640d131b6fb6eeaf7db8c1a76fd0d6281`, and
  `fd82e7323bbf73c428f1a1e72d784220f2440cd0` exercise and observe an ABI-v7
  0x52 GEMV descriptor at M=3, N=5, K=5 through the production Top CMDQ path.
  Product RTL remains at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.
- VCS/URG `V-2023.12-SP1_Full64`, Run ID
  `V2-CMDQ-PRODUCT-GEMV-GOLDEN-3SEED-FD82E73`, Seeds 20261112/13/14: 3/3
  complete Top UVM passes, 0 Warning/Error/Fatal per Seed; each checks 15/15
  independent INT32 outputs, two guards, completion fields, and 8/8 accepted
  versus returned Matrix reads. The named tail group/cross is 100%; merged
  Line/Condition/FSM/Branch/Assert/Group is 70.12/67.96/45.62/67.30/72.00/79.92%,
  so this is scoped evidence rather than global closure.
- Logs-only archive `/tmp/nmaforge_v2_product_gemv_fd82e73_logs.tar.gz`,
  SHA-256 `bb8c975cacb5b48cebb2ef6cd6b802842d9654e21b095c6107141ceda6e24f5e`.
  The test exposed that the passive UVM monitor did not classify 0x52/0x53 as
  Matrix; the testbench mapping was corrected. No product RTL defect/change.
- Exact command and requirement dispositions are in
  [DV Closure](../../verification/NMAFORGE_V2_DV_CLOSURE.md). Maximum legal
  shapes, exhaustive tail/alias/fault phases, and concurrent response-owner
  checks remain open. Benchmark/model/PPA evidence is unchanged and remains
  pinned to its own source SHAs.


## 2026-11-06 update — minimum legal 0x52 GEMV boundary

- Testbench-only commit `95301c46dfa6b9ee68f1e37a38f7767e3111d869` (tree
  `abbb19e1c8205e3d8252e5685fd6ab6161970c3d`) adds M=N=K=1 through the real
  Top CMDQ path and initializes the complete 16-byte A/B operand lines. Product
  RTL remains at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.
- VCS/URG `V-2023.12-SP1_Full64`, Run ID
  `V2-CMDQ-PRODUCT-GEMV-MIN-BOUNDARY-3SEED-95301C4`, Seeds 20261115/16/17:
  all three full UVM Seeds pass; outputs −2/−6/−12 match independent signed
  INT32 Golden, guards and completions pass, and accepted/returned operand reads
  are 2/2. The dedicated minimum-shape URG bin is 100% (three hits); aggregate
  Group is 80.61%, not global closure. Logs-only archive SHA-256
  `4d5b56b411b3c62a9d39a7da3f9c0f3f765612ce82baafe8eab6180970314ed6`.
- Exact command and requirement disposition are in [DV Closure](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
  Maximum dimensions, all tail/fault combinations, concurrent opcode-specific
  ownership, model benchmarks, and PPA remain open.

## 2026-11-06 update — maximum legal 0x52 GEMV tile

- Testbench-only commit `92874788fb2cb2a2b15657a3621e5a275a9d5990` (tree
  `8ddbc13844b9bb2f262c88c471dd60a4e3bbd428`) adds M=N=K=16 opcode `0x52`
  through real Top CMDQ. The independent Golden checks all 256 signed INT32
  outputs, two destination guards, completion result/elements, and accepted /
  returned Matrix operand lines. Product RTL remains at
  `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.
- VCS/URG `V-2023.12-SP1_Full64`, Run ID
  `V2-CMDQ-PRODUCT-GEMV-FULL-TILE-3SEED-9287478`, fixed-SHA detached clean
  worktree, Seeds 20261118/19/20: 3/3 full UVM passes, 32/32 operand line
  responses per Seed, all 256 outputs and guards match; UVM severity is
  0/0/0. The 1×1×1, 3×5×5-tail, and 16×16×16 focused groups are each 100%.
  Aggregate Line/Condition/FSM/Branch/Assert/Group is
  70.69/68.28/45.99/67.59/72.00/81.26%, not full coverage closure.
- Exact command and archive checksum are recorded in the [DV closure
  report](../../verification/NMAFORGE_V2_DV_CLOSURE.md). Logs-only archive:
  `/tmp/nmaforge_v2_product_gemv_fulltile_9287478_logs.tar.gz`, SHA-256
  `b4249983a366d34e6e1e54f08c98d99e501ed234526c2fc7862a48f842e1a05d`.
- This closes the tested maximum M/N/K endpoint only. Intermediate shape
  space, concurrent 0x52 engine ownership, all fault/reset phases, trained
  model demos, updated benchmark comparison, and ASIC readiness remain open.

## 2026-11-06 update — current-candidate model regression replay

- Fixed-candidate commit `4b99d107270a572aec798de007f8c7167749d4af`, product
  RTL still `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. VCS
  `V-2023.12-SP1_Full64`; both existing model flows recompiled and passed.
- Digits Run ID `V2-DIGITS-4B99D10-S20261029`: 360/360 exact integer-Golden
  logits, 352/360 accuracy, 34,761 CMDQ cycles, 1,884,160 padded MACs.
- Fixed TinyNPU CNN Run ID `V2-CNN-4B99D10-S20261029`: all intermediate
  tensors and 4/4 outputs exact; 1,985 compute cycles plus 1,080 separately
  measured host-layout cycles. It is not a trained CNN and is not a fair
  timing comparison to TinyNPU's differently bounded 4,781-cycle graph run.
- Machine-readable rows: [CSV](../../../benchmark/v2_model_replay_4b99d10.csv)
  and [JSON](../../../benchmark/v2_model_replay_4b99d10.json). Log archive
  `/tmp/nmaforge_v2_model_replay_4b99d10_logs.tar.gz`, SHA-256
  `acd7e8e44778ce5c3465798708f8e32ddbeb979f64030fd92c2756d42acfb801`.
- Trained CNN, Tiny Transformer, separate host/DMA/compute/writeback timers,
  common-memory TinyNPU endpoint, and system-level v2 closure remain open.

## 2026-11-06 update — scoped trained CNN demo

- Test/build commit `835f958b5f486b3f3e4808e735a788721f4f1441`; product RTL SHA
  is unchanged at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.
- Fixed four edge filters plus trained INT8 readout on Digits 0–3: software
  integer test 158/159 (99.37%). One held-out example passed real Top CMDQ;
  checked convolution, activation/layout, FC and final logits all matched the
  independent Golden. This is scoped: kernels fixed, one sample on Top.
- `ai_trained_cnn_demo`, fixed `conv1x_mini` compatibility replay, and
  `ai_smoke` all pass with VCS `V-2023.12-SP1_Full64`. Golden/model/input and
  logs archive SHA-256 `f0919d1f3b74ff6442ec33c300c7fdf9f88e4f6e842004288f5b4582c691287e`.
- Results:
  [CSV](../../../benchmark/v2_trained_cnn_demo_835f958.csv) and
  [JSON](../../../benchmark/v2_trained_cnn_demo_835f958.json). Full trained CNN,
  Tiny Transformer, full-model cycle decomposition and ASIC PPA remain open.

## 2026-11-06 update — full held-out CNN dataset on Top RTL

- Harness commit `de22e4652a54dfe7537e14585bdf3ae6f08fe9fb`; product RTL
  unchanged at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. Run ID
  `V2-TRAINED-CNN-TOP-DATASET-DE22E46`, VCS
  `V-2023.12-SP1_Full64`: 159/159 independent Top CMDQ runs passed and every
  intermediate/output Golden matched; 158/159 hardware-checked classifications
  correct.
- Per sample 1,985 compute + 1,080 host-layout cycles; 3,360/1,600 B compute
  read/write and 144/576 B host-layout read/write. This is behavior-SPAD RTL,
  with testbench input preload excluded; no TinyNPU win is claimed.
- [Per-sample CSV](../../../benchmark/v2_trained_cnn_dataset_de22e46.csv),
  [summary JSON](../../../benchmark/v2_trained_cnn_dataset_de22e46.json), evidence
  archive SHA-256 `dfacc9a6a7e17150def4814cfe9baad11b8c21675d75db1505c0b907c80de1be`.
- The filters are fixed and only the classifier readout is trained. A trained
  Transformer, per-stage host/DMA/compute/writeback instrumentation, final DV
  closure and ASIC readiness remain open.

## 2026-11-06 update — compatibility regression after testbench update

- Testbench binary/source `835f958b5f486b3f3e4808e735a788721f4f1441`, product
  RTL `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`; VCS
  `V-2023.12-SP1_Full64`. Three `ai_run` executions with 20 randomized cases
  each passed for `AI_SEED` 20261130, 20261131 and 20261132, with legacy GEMM,
  GEMV `0x52`, forwarding `0x53`, CNM and smoke markers present.
- This is regression evidence only; no new URG/functional coverage was
  collected. Logs archive SHA-256
  `7b71e6a3b5815173e8bc256fec0d323b6efe0d71e5f41f171ef4496ac5df3117`.
  The v2 DV RTM remains 14 PASS-scoped / 8 PARTIAL of 22 IDs.

## 2026-11-06 update — full Top replay with trained CNN convolution filters

Product RTL remains unchanged at
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. Model/test-harness candidate
`9b835aeac33d43fd97a81496b1048d359cdff3d0` trains four shared 3×3 convolution
filters (NumPy/Adam) and an INT8 readout on Digits labels 0–3. Under VCS
`V-2023.12-SP1_Full64`, Python 3.12.13, NumPy 2.4.6, and scikit-learn 1.9.1,
Run ID `V2-TRAINED-CNN-TOP-DATASET-9B835AE` passed all 159 held-out samples
through separate real Top CMDQ runs; all checked intermediate/output Goldens
matched and 159/159 predictions were correct on this four-class split. Each
sample reports 1,985 RTL compute cycles, 1,080 separately counted host-layout
cycles, 1,872 useful MACs, and 3,360/1,600 B compute read/write traffic.
This remains a behavioral-SPAD result, not ASIC PPA or a TinyNPU comparison.

Machine-readable evidence is in
[`v2_trained_cnn_top_dataset_9b835ae.csv`](../../../benchmark/v2_trained_cnn_top_dataset_9b835ae.csv)
and [JSON](../../../benchmark/v2_trained_cnn_top_dataset_9b835ae.json). The
outside-Git evidence archive SHA-256 is
`c2eb02228567c4f33d5a53a5020c67b7a927cdd2095b3e193c32ff46669ff71d`.
Ten-class CNN, trained Tiny Transformer, common-memory TinyNPU comparison,
stage-level host/DMA/compute/writeback timing, v2 DV closure, and PPA remain
open.

## 2026-11-06 update — fixed-weight Transformer Top fixture

At detached source SHA `9b835aeac33d43fd97a81496b1048d359cdff3d0` with product
RTL unchanged at `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, the existing
4-token prefill / 1-token decode fixture passed `make ai_transformer` on VCS
`V-2023.12-SP1_Full64`, Seed 20261106. The software mapper generated 86 ABI-v7
descriptors and 60 tensors; Top simulation passed 301 checked Transformer
intermediate/final/KV values and reported `TEST PASS`. Weights are fixed
hand-authored test values; this is not trained-model inference. End-to-end
latency and cycles/token are NOT_RUN; the 64-cycle Matrix MAC counter is not a
model latency measurement.

Run ID `V2-TRANSFORMER-FIXED-WEIGHTS-TOP-9B835AE-S20261106`. Machine-readable
record: [JSON](../../../benchmark/v2_transformer_fixture_9b835ae.json). Evidence
archive SHA-256:
`9b994707c392f0b2ba98cbb26f0235c5fea97c2ece7b5fe6bd0a306caf668387`.
The trained Transformer, common-memory TinyNPU comparison, and v2 DV/ASIC
closure remain open.

## 2026-11-06 update — three-seed Top Smoke compatibility

At clean model/tooling candidate SHA `9b835aeac33d43fd97a81496b1048d359cdff3d0`
and unchanged product RTL SHA `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`,
`ai_smoke` passes on seed 20261106 with four random workloads, then `ai_run`
passes 20 random workloads per seed on 20261106/07/08. All three logs include
the directed 0x52 GEMV, 0x53 forwarding/cross-engine, and Matrix/CNM profile
markers, one `TEST PASS`, and no error lines. This is current-candidate Top
compatibility evidence, not UVM or URG coverage. Run ID
`V2-TOP-SMOKE-COMPAT-20X-3SEED-9B835AE`; machine record:
[JSON](../../../benchmark/v2_top_smoke_compat_9b835ae.json). Logs archive SHA-256:
`a6eb548b5e37dd2fba1df0513635bed43705d5eafebaa376ecbb13d8abc75159`.

## 2026-11-06 update — fixed-SHA Top compatibility after UVM alias test

At fixed testbench/tooling SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5`,
directed `ai_smoke` passes and `ai_run` passes 20 random workloads on each of
Seeds 20261106/07/08. All runs contain the legacy GEMM, 0x52 GEMV, 0x53 fused
and cross-engine immutability, Matrix/CNM profile markers, one `TEST PASS`,
and zero error lines. The only compile notice is the known
`LOOP-REROLL-ENABLED` fixture debug-capacity message. This adds fixed-candidate
compatibility evidence, not URG bins or sign-off. Run ID
`V2-TOP-SMOKE-COMPAT-20X-3SEED-F19E929`; report and log archive details are in
the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md) and
[machine record](../../../benchmark/v2_top_smoke_compat_f19e929.json).

## 2026-11-06 update — matched Cluster serial/parallel replay

The same fixed SHA `f19e92934cd6273d327621c43cb17291cf1a9aa5` runs a three-seed
real Top Compute Cluster UVM benchmark. Matrix+CNM+SFU improves from 1,239 to
1,070 doorbell-to-tail cycles (1.158×), and Matrix+CNM+SFU+SFU from 1,696 to
1,137 cycles (1.492×); each matched pair reads and writes identical SPAD byte
counts. Independent Goldens, ordered completions, source scoreboard and
response ownership pass. The separate Matrix/CNM banked collision test records
320 admitted collisions/Matrix wait cycles and zero held-payload or owner
violations per seed. Behavioral SPAD only; per-command exclusive stall-state
timeline and alternate-arbiter A/B remain open. Details and artifacts are in
the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).

## 2026-11-06 update — fixed-weight Transformer replay on current candidate

At test/tooling SHA `3f87b033cb49c95f9ecb139b532714873a6c9476`, the generated
ABI-v7 4-token prefill/1-token decode fixture passed VCS Top CMDQ: 86
descriptors, 60 tensors, 301/301 intermediate/final/KV checks, and `TEST PASS`.
Product RTL remains `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`. This is a
hand-authored fixed-weight functional fixture; trained Transformer inference,
end-to-end cycles/token, stage timing, and TinyNPU comparison remain open. Run
ID `V2-TRANSFORMER-FIXED-WEIGHTS-TOP-3F87B03-S20261106`; evidence and command
are in the [model report](../../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md) and
[machine record](../../../benchmark/v2_transformer_fixed_weights_3f87b03.json).

## 2026-11-06 update — Transformer Prefill/Decode cycle timing

At fixed test/tooling SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9`, three
Top testbench runs on Seeds 20261106/07/08 captured the same completion-tail
timing: 5,682 cycles for four-token Prefill, 5,715 cycles for one Decode
token, and 11,397 cycles combined. Each run passed 301 bit-exact
intermediate/final/KV checks. These are behavioral Top CMDQ cycles for the
fixed-weight fixture; trained weights, steady-state decode, TinyNPU parity,
and silicon PPA remain open. Run ID
`V2-TRANSFORMER-FIXED-WEIGHTS-TIMED-TOP-F9F32F7-3SEED`; details are in the
[model report](../../benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md) and
[JSON](../../../benchmark/v2_transformer_timing_f9f32f7_3seed.json).

## 2026-11-06 update — Phase 0 source and worktree audit

The audited v2 candidate was `fed6c3f320705361bbbf761b99c73b36014cae77`
(tree `0625812c7f8b6852ad0bc3f52701b49e536062b5`), clean and 53 commits
ahead of the live GitHub v2 branch at that point. GitHub `main` still matched
R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`. The IDE branch
`feat/shape-adaptive-gemv-v2` remains a distinct history and was not merged;
its two untracked local Nova settings were preserved. Inventory: 216
registered worktrees, 136 present, 80 missing, and 10 present worktrees with
changes; no worktree was cleaned or reset. R250-to-product RTL is still the
same six-file diff, with last RTL commit `cd0a05d`; no newer RTL modifications
were introduced. Details are in the [architecture audit](../../architecture/NMAFORGE_V2_ARCHITECTURE_REVIEW.md).

## 2026-11-06 update — Top Smoke after timing monitor change

The exact testbench SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9` passes
`ai_smoke` on Seed 20261106 with four randomized workloads. The 0x52 GEMV,
0x53 fused/cross-engine, and Matrix/CNM markers pass; one `TEST PASS`, zero
simulation errors. This adds compatibility evidence only, not UVM/URG
coverage. Run ID `V2-TOP-SMOKE-POST-TRANSFORMER-TIMING-F9F32F7-S20261106`;
record and archived logs are linked from the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## 2026-11-06 update — GitHub sync blocked by missing HTTPS identity

The local v2 branch was 55 commits ahead at the authorized push attempt.
`git push origin HEAD:refs/heads/feature/npu-architecture-v2` exited 128:
Git could not read the HTTPS username in this non-interactive environment.
Read-only remote verification confirms the v2 branch is unchanged at
`5d01a88a8a2a7b1add15fbedbb02096d686824ab`; no remote update occurred. All
local commits remain intact. Upload requires working GitHub authentication.
The ASIC environment recheck also leaves Base-vs-v2 PPA **BLOCKED_ENV**;
details are in the [ASIC readiness report](../../verification/NMAFORGE_V2_ASIC_READINESS.md).

## 2026-11-06 update — Clean-worktree Top Smoke replay at `f9f32f7`

Detached clean worktree `f9f32f71e7168350d74a75ede0a4a4b222844cc9` passed
`make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106` with VCS
`V-2023.12-SP1_Full64`; 301/301 Transformer checks passed, all required
0x52/0x53 and Matrix/CNM markers were present, and no simulation `ERROR:`
was logged. Run ID `V2-CLEAN-WORKTREE-TOP-SMOKE-F9F32F7-S20261106`; archive
and checksum are recorded in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).
This replay adds no UVM/URG closure; v2 DV remains IN PROGRESS.

## 2026-11-06 update — Seven-engine UVM replay at `f9f32f7`

Detached clean SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9` passed the
three-seed `uvm_compute_cluster_regress` for Seeds 20261106/07/08 with UVM
Warning/Error/Fatal `0/0/0` each and engine-pair overlap 21/21. Merged URG is
Line/Condition/FSM/Branch/Assert/Functional Group `70.71/68.37/46.17/67.66/72.00/83.94%`; five functional groups remain at zero, and assertion/cover properties are not fully hit. This is selected evidence, not coverage closure. Logs, exact command, and machine record are in the [DV report](../../verification/NMAFORGE_V2_DV_CLOSURE.md).

## 2026-11-06 update — Opcode focused checks and mutation at `f9f32f7`

Three clean-SHA seeds passed six declared 0x52 GEMV shape bins, eight selected
0x52/0x53 fault-recovery bins, two handshake bins and six tile-forward bins.
Seven actual temporary RTL mutations across three Seeds were all detected
(21/21). This adds current candidate evidence without changing product RTL;
remaining shape/range/fault cross coverage and overall URG closure stay open.
Evidence and precise commands are in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md) and [JSON](../../../benchmark/v2_opcode_f9f32f7_3seed.json).

## 2026-11-06 update — Eight-configuration Matrix replay at `f9f32f7`

Current fixed test SHA `f9f32f71e7168350d74a75ede0a4a4b222844cc9` passed
all 120 Golden points across 3 Seeds × 5 workloads × 8 configurations at a
16×16/256-MAC array and one-cycle behavioral four-bank response model. Depth 4
+ Prefetch + A-Tile Cache summed to 1,987 cycles, 26.46% below the baseline;
A-Tile Cache reduced read bytes by 21.28% with unchanged writes. Full metrics,
source and tool identities, CSV/JSON/SVG, exact command and archive checksum
are in the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).
This is Matrix-controller RTL evidence, not TinyNPU parity or ASIC PPA.

## 2026-11-06 update — current-candidate clean Top Smoke at `839b9af`

- A detached clean worktree at source SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` / tree `630e498ba467d84dd5359403cfe1ed1e5879f6e9` passes `make ai_smoke` on VCS `V-2023.12-SP1_Full64`: `TEST PASS`, 1,683 `PASS:` lines, no simulation `ERROR:` lines. Required GEMV, tile-forward, Matrix/SFU cross-engine, and Matrix/CNM profile markers all match.
- The compile keeps the known `LOOP-REROLL-ENABLED` fixture warning. Smoke sampling uses four random cases; no UVM coverage or RTM disposition is promoted.
- Exact command, runtime seed, evidence archive checksum, and result limits are recorded in the [DV closure report](../../verification/NMAFORGE_V2_DV_CLOSURE.md) and [machine record](../../../benchmark/v2_top_smoke_clean_839b9af.json). Product RTL is unchanged; v2 DV remains **IN PROGRESS**.

## 2026-11-06 update — clean three-seed Cluster UVM at `839b9af`

- In the same detached clean worktree, `uvm_compute_cluster_regress` passes Seeds 20261128/29/30 with UVM Warning/Error/Fatal `0/0/0` and the seven-engine Golden/ownership/recovery checks.
- All nine standalone/staged/line-stall Matrix profiles close their exclusive FSM state sum to Matrix `cycle_count`; the means reproduce the previous `f530fe2` run. Current profile CSV/JSON and URG evidence are linked from the [DV report](../../verification/NMAFORGE_V2_DV_CLOSURE.md), [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md), and [run metadata](../../../benchmark/v2_clean_cluster_uvm_839b9af.json).
- URG aggregate group coverage is 83.94%, with raw Line/Condition/FSM/Branch/Assert at 70.74/68.33/46.17/67.70/72.00%; 17/22 assertions have successes and 1/3 cover properties matches. This confirms the test points while leaving aggregate coverage and RTM partials open. v2 DV remains **IN PROGRESS**; model/PPA status is unchanged.

## 2026-11-06 update — clean 0x52/0x53 feature gates at `839b9af`

- Three-seed Matrix-core GEMV, fault, handshake, Tile Forwarding ON/OFF, and mutation gates pass. Named GEMV coverage is 6/6, selected fault coverage 8/8, handshake 2/2, and enabled forwarding 6/6 per seed; 3/3 forwarding assertions are attempted with zero failures.
- Seven actual temporary RTL mutations are caught on three Seeds (21/21): output data/address, response operand owner, WSTRB, tile tag, early-valid, and request-address hold. The RTM remains PARTIAL where the tests do not cover the full legal shape space, fault-phase-reset matrix, external response ownership, and exhaustive checker mapping.
- Exact command, checker map, limits, and archive checksum are in the [machine record](../../../benchmark/v2_opcode_dv_clean_839b9af_3seed.json) and [DV report](../../verification/NMAFORGE_V2_DV_CLOSURE.md). Product RTL is unchanged; v2 DV remains **IN PROGRESS**.

## 2026-11-06 — Phase 2 clean-candidate four-way GEMV benchmark

At clean source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`, the
16×16/256-MAC Matrix core ran four shapes across B-fold Cache × Next-K
Prefetch ON/OFF and Seeds `20261128/20261129/20261130`. All 48/48 independent
Golden points passed and every exclusive state partition closed to command
cycles. B-fold Cache reduced mean cycles 21.9–40.7% and read bytes 35.2–56.5%
across the sampled shapes. Prefetch gains were small and not universal: with
Cache ON it improved three cases 2.2–3.1% and regressed 16×16×65 by 0.4%.
This is registered four-bank behavioral-SPAD Matrix-core evidence only; it
does not prove full Top or TinyNPU superiority. Product RTL is unchanged.

The 48-point [CSV](../../../benchmark/v2_gemv_four_way_clean_839b9af_3seed.csv),
[JSON](../../../benchmark/v2_gemv_four_way_clean_839b9af_3seed_summary.json),
and [chart](../../../benchmark/v2_gemv_four_way_clean_839b9af_3seed.svg) are
checked in. Text-only logs and per-Seed summaries are outside Git at
`/tmp/nmaforge_v2_clean_839b9af_gemv_four_way_text.tar.gz` (SHA-256
`4210b6af9cc45212732fa23ae69df1fbfe5ec3ae6d3335f76815fd4b5d9afa58`). Exact
commands and remaining comparisons are in the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).

## 2026-11-06 — clean-candidate in-repository fabric reset

At the same clean source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0`,
the focused DMA/CNM shared-memory-fabric reset regression passed Seeds
`20261128/29/30`. All three reset groups reached 100%; the response-owner and
CNM-tag assertions recorded 3,921 and 144 real successes with zero failures.
Every seed had UVM Warning/Error/Fatal `0/0/0` and fresh post-reset DMA/CNM
Golden recovery. This closes only the selected in-repository fabric reset
scope, not arbitrary external fabric behavior or 0x52/0x53-specific reset
crosses. See the [DV report](../../verification/NMAFORGE_V2_DV_CLOSURE.md) and
[machine record](../../../benchmark/v2_memory_fabric_reset_clean_839b9af_3seed.json).

## 2026-11-06 — Matrix/CNM arbiter fairness investigation

The current clean-candidate UVM logs report 18 simultaneous 0x52 GEMV/CNM
request conflicts per seed, with collision grants Matrix/CNM `0/18` in all
three seeds. Both outputs, ownership ledgers and ordered completions still
pass. Inspection of `ai_spad_arbiter.v` shows CNM is considered before the
Matrix banked requester in every data-class branch; the class-level round
robin does not arbitrate between those two members. Sustained-CNM starvation
is therefore a credible risk, but the existing Top workload is not itself a
continuous-valid liveness proof.

Before RTL modification, the planned focused acceptance is a legal sustained
CNM/Matrix arbitration test: both clients must receive grants with bounded
wait, response tags and Golden data must remain correct, and existing Top,
Cluster, reset/fault regressions must stay green. This is an audit of the
existing shared-arbiter contract, not a third compute innovation. At this
checkpoint, product RTL remains unchanged; the bottleneck evidence and
acceptance criteria are in the [performance report](../../benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md).

## Current phase disposition

| Area | Status at the current evidence set | Remaining gate |
|---|---|---|
| Phase 0 — baseline/worktrees | PASS for ancestry, branch relationship, source diff and inventory snapshot | GitHub synchronization is BLOCKED_AUTH in this environment |
| Phase 1 — v2 DV | IN PROGRESS; 19-test same-SHA URG has 36/36 declared functional groups at 100%; code Line/Condition/FSM/Branch is 74.15/71.55/47.45/71.14%; RTM remains 14 PASS-scoped / 8 PARTIAL | Close remaining legal requirement/checker gaps and residual RTL/FSM bins; two UVM RAL assertions have no attempts |
| Phase 2 — performance | PARTIAL; four-way Matrix-core GEMV ablation is 48/48 Golden PASS | Same-task TinyNPU endpoint and broader Top/all-engine stall/timing breakdown |
| Phase 3 — model demo | PARTIAL; trained Digits MLP and four-class CNN have separate Top results | Trained Transformer; uniform model timing split and TinyNPU common-workload comparison |
| Phase 4 — ASIC readiness | NOT READY; PPA BLOCKED_ENV, physical steps NOT_RUN | Private implementation inputs, resolved lint/CDC/RDC/formal, then matched DC and physical flow |

The latest evidence changes no v1.0 or v2 sign-off disposition. Minimum next
work is to close the remaining v2 DV requirement/checker gaps, then run a
matched TinyNPU workload on an explicitly shared timing boundary. No product
RTL change is justified by the four-way ablation alone.

## Research Closure Round 2 — final bounded disposition (2026-11-06)

This bounded round is complete and frozen at code commit
`acfaec281f5414c0e357c1dc7985b79a829c8c30` plus the following evidence/report
commit. Product RTL is still
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.

| Work item | Status | Evidence / limitation |
|---|---|---|
| 128/512 KiB trained Digits MLP | PASS | Same compact map, 360 outputs Golden-exact, 34,761 cycles, 97.78%; 93,184 B high-water |
| Transformer fixture at 128 KiB | PARTIAL | 301 fixture Golden/KV checks and timing pass; enclosing smoke fails 23 unrelated large-SPAD/all-engine cases |
| Trained Transformer | NOT_RUN / BLOCKED_MODEL_PIPELINE | No trained checkpoint/training flow; mapper weights are deterministic fixture values |
| CNN fused flatten/layout | NOT_RUN_INCOMPATIBLE_LAYOUT | `0x53` tile-A output does not directly match current consumer flat K=144 operand |
| >128 KiB live-set streaming | NOT_RUN | No suitable checked-in workload; no streaming/DMA-cost result |
| TinyNPU model-level matched timing | PARTIAL | Fixed GEMM/GEMV evidence retained; CNN endpoints differ, no ratio; Tiny Transformer not run |
| ASIC PPA | BLOCKED_ENV / NOT_RUN | No private SRAM macro/library/SDC; only storage-bit arithmetic |

Machine-readable details: [round-2 record](../../benchmark/v2_round2_research_closure_20261106.json)
and [MLP capacity CSV](../../benchmark/v2_round2_capacity_mlp_20261106.csv).
No new verification, RTL, streaming, ASIC, or model task is started after this
bounded closeout. Overall state remains **RESEARCH_BASELINE_PARTIAL**.
