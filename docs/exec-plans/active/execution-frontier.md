Warning: truncated output (original token count: 29796)
Total output lines: 1360

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
phase Protection × Reset recovery points, checks 92,871 memory word…17796 tokens truncated…main open.

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
