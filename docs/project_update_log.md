# Project update log

## NMAForge v2.0 Gate 0-2 — 2026-11-14

Research baseline fixed to PR #8 candidate `0492c47d12cd11bcc22be1930da7af77ed870b6e` in isolated branch `research/nmaforge-v2-product-baseline`. The existing Top Transformer fixture passed with 86 descriptors and full intermediate/KV/completion checks; the existing H16 incremental path passed four decode stages with independent Golden comparison and average 8,183.50 simulated cycles/token. New Gate 1 tooling generated the requested 4-layer/Hidden-64/4-head/FFN-256/vocabulary-256/context-16 deterministic INT8 fixture and 41-node lowering plan; Golden passed, but the fixture is explicitly pseudo-weight and RTL execution is NOT_RUN. New Gate 2 DAMS/SVSE synthesizable research prototypes passed an independent VCS testbench (`DAMS_SVSE_PASS accepted=3 denied=1`) without product ABI integration. See `docs/research/NMAFORGE_V2_GATE0_BASELINE.md` and `docs/research/NMAFORGE_V2_GATE1_GATE2_STATUS.md`. Reproduction uses VCS `V-2023.12-SP1_Full64`, Python environment `/tmp/nmaforge_round10_venv`, and the commands in those reports. No product branch or PR was merged.

## Round 27 — incomplete session

Prepared historical baseline extracts and an incomplete review at `docs/benchmark/NMAFORGE_V2_ROUND27_ARCHITECTURE_FREEZE_REVIEW.md`. Withdrew unsupported LayerNorm phase allocations; phases remain unmeasured. Corrected large GEMM historical read traffic to 6,144 B. No RTL experiment, simulation, synthesis, freeze decision, commit or push completed. Historical extraction uses `git show 800c5b0:<artifact-path>`. Git metadata writes failed with read-only `.git/index.lock`; escalation was aborted.

## GEMM / LN scheduling optimization — published candidate

Branch renamed to `nmaforge`; old remote `nmaforege` removed after verifying the
new remote. RTL/test SHA `b2b3b0b5942f9218ed574a04e946104109dc2c99`. Two bounded
changes overlap GEMM A/B prefetch and LN Gamma arithmetic/Beta fetch, with no new
data state or SPAD ports. Same H16 decode: 66,931 → 65,771 cycles / 8 tokens;
trained CNN CMDQ: 12,947 → 12,351, unchanged independent Golden and traffic.
Three-seed Matrix/SFU, depth-2/fallback, Top Smoke, 20-case seeded Top and paired
trained QKV pass. Tiny timing now distinguishes array phases and unmeasured
transfer/commit; no unequal-boundary system speedup. Basic lint warning counts
remain inherited; no physical Fmax claim. Status DESIGN_PARTIAL. Exact commands,
raw artifacts, timing boundaries and risks: [review](design/schedule_optimization/REVIEW.md)
and [reproduction](design/schedule_optimization/REPRODUCTION.md).

## 2026-11-10 — Final roadmap Stage A: fair benchmark and candidate review

Branch `nmaforge`, reviewed `da5a6691c7582d54c7a2da643e01d296f8da2d68`;
product RTL unchanged (`rtl` tree479f24f33af0ccfa87fd7458ac9c43f94aae7398).
Added passive DV phase/address/AXI observation, portable benchmark runners,
public hashed evidence and `docs/research/` architecture/proposal/freeze reports.
H16 persistent Golden65,771/8=8,221.375 cycles/token; CNN same-weight mappings
65,429/22,983/12,351 CMDQ cycles,20,800 Golden words each. New exclusive profiles
close to total cycles/accepted bytes. Tiny pinned native graph4,742 measured/
modeled cycles (old4781 includes39 prestart),64 KiB byte-wide data SRAM;
no system speedup from unmatched boundaries. Same-boundary array18/34/264 versus
54/102/792 is a harness compute-only comparison, not system or PPA evidence.

Replayed `make -C dv/subsystem/top_smoke/sim ai_smoke` and
`make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345`: PASS.
`core-tile-forward-ablation`,128 KiB common CNN, trained CNN/H16 Golden,
independent held-out reference, pairedQ/K/V and Tiny seven array cases/six engine
tests PASS. `python3.12 tools/benchmark/stage_a/validate.py`: PASS hashes,
cycle/byte closure, budgets and invalid-ratio rejection. Exact commands and tool
versions in `docs/research/REPRODUCTION.md`; no current-source synthesis/Fmax claim.
400 MHz is2.5 ns;4 ns is250 MHz. H32 allocation fits but untrained/unmapped;
H64 resident128 KiB allocation does not fit. A3 deferred for partial-sum/live-set
proof; B2 proposed128 B Matrix→Requant cache requires all-writer coherence and
parity/protection review. **DESIGN_PARTIAL; Stage A stops for architecture review,
no Stage B/C product edits or next stage automatically started.**

## 2026-11-10 — Stage B Matrix→Requant contract/model: REJECT

Baseline1b455b355c8604272cbc49a81f5564db9a4e4f05; independent candidate Worktree
`/tmp/nmaforge-stage-b-candidate`, branch`experiment/stage-b-matrix-requant`.
No product RTL/ABI/model/Golden edits. Gate0 real memory fabric+SFU VCS test
reproduces silent post-commit SRAM upset → ERR_PARITY/no outputs, write-allowed/
read-denied → ERR_PROTECTION, and ready-but-denied Line → no commit. A coherent
cached copy cannot observe unsignaled SRAM corruption; transparent read removal
is rejected. No Gate2 candidate RTL or B2-enabled measurement was fabricated.

Independent transaction suite7 tests PASS; replay64 dependency-proven leases/
2,048 reads/8,192 B,512 packed Golden words;47 latency/hit/invalidation model
cases. Ideal unapproved1-clock cache+2 clocks/lease estimates6.033% cycle saving;
strict per-read checking saves0 reads and proves no latency gain. New relaxed
fault-observation mode described for architecture review only; no bit allocated.

Fresh B1 persistentH16=65,771/8=8,221.375 cycles/token,72,448 read/42,112 write B;
all8 token metrics and9 full stage Golden snapshots identical to Stage A.
CNN three mappings65,429/22,983/12,351 cycles Golden PASS; focused SFU64+9 and
Matrix18+35 cases seed20261110 PASS; Top Smoke PASS. Exact commands, public hashes,
limitations and no-RTL ASIC disposition in
`docs/research/STAGE_B_TRANSFORMER_FORWARDING_REPORT.md` and
`benchmark/research/stage_b/manifest.json`. Actual added hardware state0; no
synthesis/Fmax/energy claim. **REJECT**; no A3 or next-stage implementation started.


## 2026-11-10 — Stage C architecture feasibility and H32 expansion

Status **PARTIAL** at unchanged product RTL tree
`479f24f33af0ccfa87fd7458ac9c43f94aae7398`, baseline `4e65a2ac`.
A3 transparent bypass REJECT: current SRAM parity/protection cannot be replaced
by a committed cached copy; Stage B fault contract VCS replay passes. K64 exact
four-part model matches3328 CNN outputs but512B does not establish a profitable
same-array continuation schedule; no product RTL experiment admitted.
H32/L2/heads2/context16/FFN128/vocab32 trained and mapped to existing ABI:
4full-prefill +8persistent-decode tokens,92928word strict Golden PASS,367788decode
cycles/8=45973.5/token,546816read/227840write B,79872B SPAD high water. Final
model's disjoint-trajectory test accuracy3.19% is explicitly a research limitation;
overlapping initial-seed metrics are withdrawn as generalization evidence.
H16 stays65771/8, CNN best12351cycles and independent20800wordGolden passes.
VCS Top smoke, seeded20,40Matrix config cases,16productGEMV ablations and9common
Tiny memory-service kernels pass. Native Tiny conv1x_mini4742cycles has unmatched
DMA/endpoints; no system speedup or frontend freeze/PPA claim. Reproduce with
`tools/benchmark/stage_c/run_top.sh`, `run_bench.sh`, `validate.py` and the exact
commands in `docs/research/STAGE_C_ARCHITECTURE_DECISION.md`. Evidence and SHA
inventory: `benchmark/research/stage_c/`. Stage C stops; no automatic Stage D.

## 2026-11-11 Asia/Singapore — SPAD128 Gate 0/1 candidate

Dedicated branch `feat/spad-128k-closure`, based on nmaforge `95c4387bb0ac57ff4fa427fd3c1202320ad0940b`: defaults aligned to8192words/bank (128KiB), optional32768 retained, constant geometry rejection, capacity-derived Digits/MiniCNN fixtures and concurrent smoke placements. Full smoke now checks final TEST PASS; original128KiB fixture failure (23 errors) retained. Isolated VCS replay: `SPAD128_OUT=<fresh-absolute-dir> SPAD128_PYTHON=<python3.12-with-model-dependencies> SPAD128_DATASET=1 bash tools/benchmark/spad128/run.sh`. Mandatory Golden, boundary, parity/protection and512KiB compatibility evidence is in `benchmark/research/spad128`; validate with `python3.12 tools/benchmark/spad128/validate.py`. H16=65771/8decodecycles, H32=367788/8, CNN bothfused=12351CMDQ cycles preserved. Verilator warnings match same-capacity baseline but remain unresolved, no signoff/PPA/Fmax claim. See `docs/design/SPAD_CONFIG_REGRESSION.md`. Stop for architecture review before Gate2/performance RTL; no product-branch merge.

## Phase 1 — architecture and benchmark closure review

Approved baseline `48790076b351cb9d49e1785247d32a1f51b8286d`, isolated branch
`feat/phase1-architecture-benchmark`; no product RTL changes. Passive monitor
closes every exclusive CMDQ window and scheduler read-response ledger. Fixed
Top GEMM4×4×32/16×16×16/32×32×64:126/186/986cycles; product0x52M1/4/8:
143/161/213cycles. TrainedCNN both-fused remains12,351 and H16Decode65,771/8,
strict Golden PASS. Qualified synthetic H32period3model:367,051/8Decode,
79.17%SFU; FP32/INT8blind accuracy100%, lag3ruleoracle100% (no language claim).
12common-adapter Tiny raw kernels PASS; no native/fullsystem speedup.
Verilator5.052 warning counts reproduced, temporary default diagnostic only;
all product warnings retain explicit dispositions. Recommend one next RTL
experiment: exactlength32LNmean/variance division specialization, analytical
≤4.60%H32cycle reduction; no implemented improvement claimed. Second candidate
prefetch scheduling deferred without incremental evidence. DESIGN_PARTIAL.

Reproduce with `tools/benchmark/phase1/README.md`; public proof:
`python3 tools/benchmark/phase1/validate.py`. VCSV-2023.12-SP1Top directed workloads,
independent Golden and20randomcases/seed12345 PASS; existingMatrix8config×5shape
ablation PASS. Main, product and other worktrees preserved. Six linked reports
under `docs/performance/`, `docs/research/` and `docs/design/` document boundaries,
model limitations, numeric/fault obligations and remaining freeze risks.

## Phase 2 — exact LN32 RTL candidate and streaming feasibility

Reviewed Phase1 `ae7fd31eced13dcb9dbd70533da60559511d0a90` (no product RTL
changes); merged and published `nmaforge` at
`cb08797e612355b404f9eb697a34f99628deebfd`. Dedicated candidate branch
`feat/phase2-exact-sfu` extends only exact length32 LN mean/variance division.
Measured fixed H32 eight-token decode367051 ->350155cycles (4.603175%);
H16=65771 and trainedCNN both-fused=12351 unchanged. Strict integer arithmetic,
mandatory SRAM address/order/traffic, Logits/KV/intermediate Golden, protection/
parity, reset/abort/watchdog, three-seed SFU and Top smoke/seeded20 PASS.
No new flops/ports/MAC or ABI change. No new focused lint warnings; inherited
Top issues remain and no area/Fmax/signoff claim is made. Gate2 requant model
projects conditional incremental43504cycles/12.4242% but does not prove dynamic
fault timing or closed-loop arbitration. No streaming RTL admitted/implemented.
Decision RETAIN_LN32 / DESIGN_PARTIAL. Five reports in `docs/research/phase2/`;
commands in `tools/benchmark/phase2/README.md`; public archive validated with
`python3 tools/benchmark/phase2/validate.py`. Stop after Gates1/2.

## Frontend closeout Gate2–5 candidate

Created isolated `candidate/frontend-closeout` from remote product c93ea14. Tested RTL fc60f95; retained protected ping-pong, bounded offline mapper, existing output DMA scheduling and source-fault response drain fix. Fixed mux combinational temporary and split return dependencies; Verilator LATCH10→0/UNOPTFLAT3→0. CNN11376cycles; delivery19507→15437; H16/H32 65771/350155. Scoped Golden/fault tests pass. Seven-engine UVM128KiB fails old0x7d000fixture; global DV HOLD. ASIC mapping blocked by absent configured libraries/macros/wrappers. No merge or PPA/signoff claim. See NMAFORGE_FRONTEND_CLOSEOUT.md and reproducible run.sh; evidence manifest pins RTL/workloads. Original worktrees and PR#5 preserved.

Descriptor-validator old reserved-bit vector corrected to bit8 (bit7 is existing Row-Major). Re-run PASS29legal/33invalid/43accepted/26rejected; failing-before log retained. SpyGlass single-clock depth256 CDC0errors/2warnings; final lint0errors/467warnings. No broad static waiver.

## 2026-11-13 — Compact SPAD line-stalled CNM Golden closure

On branch `experiment/compact-spad-dv`, preserved the existing uncommitted
fixture/monitor work. Reproduced seed `20261025` mismatch at cycle 39390:
CNM Golden[8] expected `0x12c8`, actual `0x109b`, address `0x14020`. A trace
replay with the original destination captured first corruption at cycle 34660:
CNM tag 5 wrote row 0 output `0x0a58` to `0x14000`, overwriting row 8/K0/lane0
in the live B image `[0x13000,0x15000)`. At cycle 35463 CNM read that location
and returned the overwritten value. Root cause is fixture allocation/lifetime;
no DUT RTL change.

Moved the line-stall CNM output to `[0x16000,0x16040)`, retained workload,
Golden, overlap and stall checks, and corrected compact fixture ranges/lifetimes
found by the full regression. Added a hard 128 KiB bound to `spad_write()`,
restored the original Matrix/CNM input images before parameter-latch tests, and
used parity-consistent descriptor backdoor mutation while scheduler traffic is
active. Full allocation map and transaction evidence:
`docs/verification/COMPUTE_CLUSTER_LINE_STALLED_CNM_FIX_2026-11-13.md`.

VCS `V-2023.12-SP1_Full64`: full Compute Cluster UVM seeds 20261025,
20261026, 20261027 PASS with 0 UVM warnings/errors/fatals per seed; line-stall
checks=92, violations=0, overlap=1840 cycles, seven-engine pair coverage=21/21.
`make ai_smoke` PASS; `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS.
SpyGlass lint completed with 0 errors/467 warnings/5 infos; CDC setup 0 errors,
1 warning/9 infos; CDC structure 0 errors, 2 warnings/38 infos. RDC was
interrupted after remaining at `Ar_resetcross01` (385/478) with about 6.6 GB
RSS; it has no result. This is a DV bugfix closure, not static-analysis or
ASIC sign-off. Logs, coverage databases and URG report remain under `/tmp`.
# 2026-11-13 Compute Cluster DV Closure Round 2 baseline

- Reviewed `bugfix/compact-spad-line-stalled-cnm` (`76805a45d8914ecdc998d98b419c8a19053b1daa`) against `candidate/frontend-closeout` (`f919bb787dab1a4e3bef44b5308ead56d6e77b72`): two commits ahead, no product RTL changes.
- Recompiled exact source and passed Compute Cluster UVM seeds `20261025/26/27`; each line-stall test observed 92 stability checks, zero violations, and 1840 overlap cycles. UVM severity counts were zero.
- Rebuilt DUT-only Top Smoke coverage from one VCS compile and merged three seeds under `/tmp/nmaforge_round2_dutcov_sha76805a45_20261113`: line 85.74%, condition 76.97%, FSM 43.74%, branch 82.09%. Kept full UVM coverage (69.46/67.13/43.47/66.26%, assertions 72%, groups 83.94%) as a separate database because it contains verification environment hierarchy.
- Existing AXI stall directed test on the same compiled UVM image hit AR/AW/W stall-to-accept covers 14/5/12 times. The main compute-cluster regression had zero AR/AW matches, proving those tests are peripheral DMA stimulus gaps for that test, not unreachable cover properties.
- Added `dv/uvm/tests/check_compact_spad_alloc.py` for compact concurrent live-range bounds/overlap and the row-8 CNM B lane calculation; wired it into the Compute Cluster UVM compile target.
- Initial uncovered-bin triage, compact interval table, SVA disposition, scoped RTM and remaining work are in `docs/verification/COMPUTE_CLUSTER_DV_CLOSURE_ROUND2_2026-11-13.md`. DV remains OPEN; full bin-by-bin disposition, SpyGlass/RDC closure and ASIC readiness remain.
- Reproduction: `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_round2_uvm_sha76805a45_20261113`; `make -C dv/subsystem/top_smoke/sim ai_compute_cluster_cov AI_CLUSTER_COV_RUN=/tmp/nmaforge_round2_dutcov_sha76805a45_20261113 AI_CLUSTER_COV_SEEDS='20261025 20261026 20261027'`.
