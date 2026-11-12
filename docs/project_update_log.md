# Project update log

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

## Phase 3 — throughput architecture research, stop after Gates 0–2

Phase 2 LN32 review PASS; GitHub PR #4 merged into `nmaforge` at
`c93ea144713d5fafe2e8a5509029927cd6859e75`, remote verified. Phase 3 isolated
`feat/phase3-throughput` has no product RTL changes (RTL tree
`fe0e999fa187c4ed52a512d27509d5922e6137eb`). Fresh VCS LN32 integer/fault/
reset/abort/watchdog, full fixed Top workloads, independent CNN, H16/H32
Logits/KV/tensor and seeded20 regressions PASS; H32=350155/8, H16=65771/8,
CNN both-fused=12351 cycles remain unchanged. Focused Verilator has no new
warnings; inherited top static issues and mapped timing remain open.
SFU 1/2/4-lane transaction models reconstruct 672 scalar segments (448 decode)
and project conditional42.8427–53.3387% latency reduction, but real parity-prefix
and cross-region protection counterexamples prevent fault admission. STOP SFU;
no vector RTL or transparent bypass. CNN's4160pack edges are useful work;
four existing postprocess lanes plus a second128bit ordered buffer project
975 saved cycles/7.8941%, validated by1560 abstract FIFO cases and1040 original
Golden line payloads, not candidate RTL. Present for the next decision, no
implementation started. Pinned Tiny contract is desk-reviewed historical
adapter evidence only; no full-system speedup. Product DESIGN_PARTIAL.
Reports: `docs/research/phase3/`; exact commands:
`tools/benchmark/phase3/README.md`. Public checks:
`python3 tools/benchmark/phase2/validate.py` and
`python3 tools/benchmark/phase3/validate.py`. No automatic next phase.

## Phase 4 Gate 2 — CNN ping-pong candidate

Dedicated `feat/phase4-cnn-writeback`, product base c93ea144713d5fafe2e8a5509029927cd6859e75.
Implemented two ordered output line buffers, existing four postprocess lanes,
no new MAC/SRAM port or ABI change. Actual CNN CMDQ12351→11376cycles,7.8941%;
65 writeback windows80→65cycles; all1040Golden payload/address/WSTRB/order match.
H16/H32 unchanged65771/350155cycles per8tokens. Three seed ON/OFF numerical,
fault/backpressure/reset/abort/watchdog, canonical ai_smoke/seeded20 PASS;
Verilator baseline/candidate warning inventory identical, inherited severe Top
warnings still open. Commands `tools/benchmark/phase4/README.md`, reports
`docs/research/phase4/`. This checkpoint precedes architecture-only SFU study;
no SFU RTL or automatic product merge, no signoff/Fmax claim.

### Phase4 architecture-only continuation

Gate2 checkpoint73ebc74f5e155c614d3eeb4f5bee12315ed7f633 pushed; remote SHA matched.
SFU study `python3.12 tools/benchmark/phase4/sfu_protocol_model.py --out /tmp/nma-p4/sfu_protocol`:
196immutable/disjoint and279recovery cases PASS, but ordered retirement still
changes Host-write/permission-revoke observations. REJECT unrestricted pipeline
after two targeted rounds, no SFU RTL. Real unchanged-SFU/scratchpad/protection
Phase3 parity-prefix and adjacent-region counterexamples re-run PASS. Remaining
three Phase4 reports document benchmark boundaries and DESIGN_PARTIAL decision;
CNN retained as PR candidate, no automatic product merge or Phase5.

## Architecture optimization Milestone 1 — real product Top coverage

On branch `feat/arch-opt-m1`, runner `tools/benchmark/phase1/run.py` was extended
for the missing product Top matrix rows: GEMM 4x4x32, 16x16x16/32/128,
32x32x64 and product 0x52 GEMV M=1/4/8/16, K=16/32/64/128. VCS
V-2023.12-SP1_Full64, 4 ns behavioral clock, default 128 KiB four-bank SPAD.
All 21 descriptors reported `REPRESENTATIVE_MODEL_PASS`; signed INT32 Golden,
two-cycle response ledger and traffic checks passed. The attribution artifact is
`benchmark/research/arch_opt/MILESTONE1_TOP_BASELINE.csv`; raw profiles are
under `/tmp/nmaforge-archopt-m1-runs/top-suite`. The corrected report is
`docs/research/arch_opt/MILESTONE1_MATRIX_PREFETCH.md`.

Measured isolated Top examples: GEMM 32x32x64=986 cycles (6144/4096 B,
312 operand-wait), GEMM 16x16x128=522 cycles (4096/1024 B), GEMV M1 K32=143
cycles (544/64 B), M4 K32=161 cycles (640/256 B), M8 K64=325 cycles
(1536/512 B), M16 K128=1109 cycles (7168/1024 B). All reads had two-cycle
registered latency; no denied or multi-client request cycles occurred in the
isolated suite. H32 concurrent attribution remains 350189 cycles with 14600
Matrix operand-wait and 4288 request-form arbitration waits. Existing D4/P1/C1
ablation is retained as baseline evidence only; no new Matrix RTL is admitted.

Validation: `python3.12 tools/benchmark/phase4/validate.py` PASS;
`cd dv/subsystem/top_smoke/sim && make ai_smoke` PASS (`TEST PASS`), including
random GEMV/GEMM, CNN/Transformer, protection, abort/reset recovery;
`git diff --check` and Python compile PASS. Commit `25372669d097e030e79ca5d7ce68ab41c68921a2`
pushed and verified at `origin/feat/arch-opt-m1`. Product RTL is unchanged;
Milestone 2 remains a separate shape-adaptive 0x52 study.
