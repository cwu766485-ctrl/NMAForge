# NMAForge v2 Architecture Review

**Review date:** 2026-11-05  
**R250 baseline:** `main` `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Review starting commit:** `eb158880d11bf7f8baf13ece4a888107877356fd`  
**Current reviewed candidate:** `feature/npu-architecture-v2` `ac6b83ff7f12e626ea1d2c91ad3a0d2f7bcef164`
**Candidate tree:** `dbf5060ac465ef4bb913543024182b298f675413`
**Latest test-only candidate:** `feature/npu-architecture-v2` `86e0d6cbba3187bd1deeb18f664c559b606c878d` (tree `497eaef649c3995c97cb533a9c410417d63ee0de`); this commit adds a Top Smoke functional coverage group and its gate, with no RTL delta.

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
| `0x52` | Signed INT8 GEMV mapped as K-fold work on the shared 16×16 Matrix array, with partial-sum reduction. Uses the existing 1 KiB reuse array for bounded B-fold caching, A-line reuse, and optional next-K prefetch. | ABI v7; exact `1≤M,N≤16`, `K≥1`; dense padded A rows and dense B rows; contiguous INT32 output; optional bias. Current product gate rejects transpose, nonzero strides, extra aux/flags, unsupported batch/head fields, address-span overflow, and output overlap with A/B/enabled bias. | Real Top CMDQ Golden for M4×16×32, M1×13×17, M8×16×19; Matrix-core 48/48 four-way Cache×Prefetch Golden checks for M8/M16 × K19/K65 over three Seeds. Descriptor range/alias replay is archived separately. |
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
- `0x52` still needs broader M/N/K tails, address alias/range/fault/reset and
  backpressure coverage tied to the current candidate; operand immutability
  under concurrent engines must be specified and checked.
- `0x53` still needs held-response, parity/protection, broader Abort/Reset,
  repeated consumers, and cross-engine coherence coverage. Its 512 B local
  storage has no current-candidate DC area/Fmax/power result.
- VCS functional Golden checks are not coverage closure. A merged current-SHA
  requirement RTM, functional/code coverage disposition, non-vacuity audit,
  and mutation report for every new checker are not complete.
- The TinyNPU tools are now available and the named GEMM/CNN and small-M GEMV
  replays have passed at the source identities above. A true TinyNPU memory
  adapter, broader GEMV shapes, trained CNN/Transformer comparisons, and
  phase-aligned system endpoints remain open; mixed modeled results are not a
  product-level win claim.
- DC, formal/LEC, CDC/RDC, SRAM mapping, DFT readiness, power and physical PPA
  are not closed by these VCS runs. ASIC readiness remains `NOT_RUN` or
  `BLOCKED_ENV` by individual tool/input; do not claim Tapeout Ready.
- v1.0 Compute Cluster stays **HOLD**. This branch's scoped v2 tests do not
  resolve the inherited 38-requirement sign-off record.
- The matched trained Digits MLP replay is a scoped model result, not a
  TinyNPU comparison. Separate Host/DMA/Compute/Writeback/Graph phase counters
  are still missing; trained CNN and Transformer deployment remain `NOT_RUN`.

## Current decision

Continue v2 on this isolated feature branch with reproducible benchmark and
verification increments. Preserve R250 `main` untouched. The next useful
closure is a current-SHA v2 RTM/fault matrix and controlled Top-level
memory-contention experiment, followed by independent DC/PPA readiness when
the licensed libraries and constraints are available.

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
