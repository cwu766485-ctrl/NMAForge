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
