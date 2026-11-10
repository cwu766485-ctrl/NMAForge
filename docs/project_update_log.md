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
