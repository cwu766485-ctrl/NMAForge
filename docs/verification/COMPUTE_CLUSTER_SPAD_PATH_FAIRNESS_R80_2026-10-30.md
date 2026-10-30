# Compute SPAD MUX-to-Arbiter Fairness Evidence — R80 — 2026-10-30

## Result

**PASS for the bounded production MUX-to-arbiter request/response path tested here.** Exact clean code/test SHA: `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907`. Run ID: `R80-COMPUTE-SPAD-PATH-FAIRNESS-4096-E4C1E7A`. The test is deterministic; seed is not applicable. Product RTL and SPEC are unchanged.

## Commands and tools

Focused command:

```sh
make -C dv/subsystem/top_smoke/sim ai_compute_spad_path_fairness \
  COMPUTE_SPAD_PATH_RUN=/tmp/nmaforge_compute_spad_path_R80_clean_e4c1e7a \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Same-SHA smoke command:

```sh
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH \
  make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=20 AI_SEED=12345
```

Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`. The focused compile has no `Warning-`, `Error-`, or `[TFIPC]`. Top Smoke retains the existing `LOOP-REROLL-ENABLED` fixture warning and ends in `TEST PASS`.

## Checks

- The test composes production `ai_compute_spad_mux` and `ai_spad_arbiter`, with seven continuously requesting behavioral compute clients plus sustained banked and DMA requesters. Descriptor and completion requests are asserted together periodically to check descriptor priority and delayed completion service.
- A deterministic two-stage behavioral response model runs for 4,096 active scheduler cycles. It observes 4,096 accepted requests: per-engine compute grants are `193/194/193/193/193/193/193`; banked and DMA each receive 1,352 grants; descriptor and completion each receive 20 grants.
- Maximum per-engine request wait is 22 cycles against the 96-cycle check bound. Compute-group, banked and DMA client maximum waits are `4/4/4` cycles against the 32-cycle client bound.
- The scoreboard checks all 3,465 read responses for scheduler owner, returned address-derived data and modeled error; compute responses are also checked for one-hot engine routing, correct lane data/error, zero data in other lanes, and no response for writes. All seven engine read response counts equal their accepted read counts.
- All three SVA properties pass with zero failure, incomplete, or without-attempt counts. All four cover properties match: descriptor priority over completion, compute admission, banked admission, and DMA admission.
- DUT-only URG code coverage is reported separately: `ai_compute_spad_mux` line/condition/toggle/branch `100.00/70.83/44.39/100.00%`; `ai_spad_arbiter` `46.33/65.57/16.37/45.45%`. The low arbiter line/branch score is expected because line, CNM, several arbitration fallback classes and associated response modes are tied off in this focused harness. These numbers are not a Cluster coverage score.

## Evidence

The clean replay worktree is `/tmp/nmaforge_r80_clean_e4c1e7a`; run products are outside the repository:

| Artifact | Path | SHA-256 |
|---|---|---|
| VCS compile | `/tmp/nmaforge_compute_spad_path_R80_clean_e4c1e7a/compile.log` | `b0a297afa57a0908173bdc5bbd873abb2baf5521a9476df4d0acf58660d8c0d5` |
| Focused run | `/tmp/nmaforge_compute_spad_path_R80_clean_e4c1e7a/run.log` | `8520fc34c3c04b3e7c6a5732a5e0a7bd569d9c48341d15501c0741f3239691e8` |
| URG assertions/covers | `/tmp/nmaforge_compute_spad_path_R80_clean_e4c1e7a/urg/asserts.txt` | `f095578738d8602d20dfe16c95ecb3b8de77cf94af6b271ee3a788104691566e` |
| URG module report | `/tmp/nmaforge_compute_spad_path_R80_clean_e4c1e7a/urg/modinfo.txt` | `d6413dd12aedaec5ac4d156b4d753879e3bce6890523eeb74c2c6dc24f99cfb1` |
| Top Smoke run | `/tmp/nmaforge_r80_clean_e4c1e7a/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | `17e09daf97f5016e0c63617e79f46f865d5a18dc2b51504f66675b5286132ee9` |
| Top Smoke compile | `/tmp/nmaforge_r80_clean_e4c1e7a/dv/subsystem/top_smoke/sim/ai_comp.log` | `3bca141b69f9a1976b1868187aaa6bea48bff83fca3503f396ae2b56b765be26` |

## Limits and disposition

This proves a bounded arbitration and response-routing path through the production compute MUX and scheduler arbiter. It uses behavioral compute requesters, a behavioral response memory, and selected scalar/banked/DMA ports. It does not instantiate the seven production engines, the complete memory subsystem, physical SRAM, protection checker, downstream ready/backpressure, line/CNM traffic, completion writer, or completion-owner logic. It therefore does not satisfy the complete shared-SPAD ownership and error-recovery requirement by itself. `REQ-CL-014` stays **PARTIAL**; the 38-requirement disposition remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
