# Compute Cluster regression output-path reproducibility — R87

**Date:** 2026-10-30  
**Exact clean code/test SHA:** `402c8ce4689ae48cfee624f1f5fdca66d534bbbf`  
**Product RTL/SPEC baseline:** `9d4e9abdba1f745644a485960620fa6bbc4979db`; R87 changes only the UVM Makefile output-path expansion.  
**Run ID:** `CLUSTER-REGRESSION-OUT-PATH-STABILITY-3S-402C8CE`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Change and clean replay

The Compute Cluster UVM and mutation output defaults previously embedded recursive `$(shell date ...)` expansions. GNU Make reevaluated those expressions at each reference, so a compile prerequisite could create `simv_uvm` under one timestamp path while a mutation recipe tried to launch a later path. R87 captures one nanosecond-resolution run stamp with `:=` and derives both default directories from it.

From the exact clean checkout at `402c8ce4689ae48cfee624f1f5fdca66d534bbbf`, with no output-directory overrides:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress uvm_compute_cluster_mutation
```

This command exits 0. Compile, all three regression seeds, and the mutation executable share the stable UVM output directory `/tmp/nmaforge_real_compute_cluster_uvm_20261030_195723_811632609`; all 28 mutation logs are under `/tmp/nmaforge_compute_cluster_mutations_20261030_195723_811632609`. The three seeds (`20261025/26/27`) each pass all gated real-top testpoints, including the R86 Matrix Abort-prefix point. Each reports 15,021 scoreboard writes, 17,352 checked words, zero mismatch/unknown/stale response, focused applicable compute coverage 100%, and UVM warning/error/fatal `0/0/0`. The campaign catches all 28 expected passive observation mutations. Expected UVM errors inside mutation logs are the checker reactions being tested; they are not DUT test failures.

The same clean SHA passes `make ai_smoke` from `dv/subsystem/top_smoke/sim` and prints `TEST PASS`. It retains the existing fixture warning `[LOOP-REROLL-ENABLED]` at `ai_transformer_workload.svh:9`. UVM compilation has no `Warning-`, `Error-` or `[TFIPC]` diagnostics.

## Artifact hashes

Generated logs and databases stay outside the repository.

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `71742717acd130e2d46c4205f514c13c3ef7d122ce1d88c99d08a273d74e0a03` |
| Seed 20261025 log | `e793545ec5ed28207088412e45c3cb90d92c74550eb007e319706024bd8aeaf3` |
| Seed 20261026 log | `4768b1d3b357d4c84303e148c8ccab62956efcc0bc254e18080a0241cde30446` |
| Seed 20261027 log | `9d62ebfb7c386738536da4cedb05f11dd7734a6ea53bbab3d130cf2177ff8302` |
| URG merged log | `baea0d7da2df6b63d4bdcbfddac7adc4a34e2ec840464f22849d415bb2f50023` |
| 28 mutation-log SHA-256 manifest | `ff56bb723150a6c9c44d3b9264a831fbff846c48ae395ad9d34931069b08ea1b` |
| Top Smoke log | `558d128bd04c7e076c0c9da5f9b1b7a35e177ff92c9295b6cf6cd2ad03a5b18b` |

## Disposition

R87 improves repeatability of the existing UVM and checker-sensitivity commands; it adds no functional testpoint and changes no product RTL, SPEC or requirement disposition. The RTM remains 24 PASS-SCOPED / 14 PARTIAL, and `CL-DV-v1.0` remains HOLD. URG is still 17/22 assertion properties with real successes, five uncovered and no failure/incomplete; R87 does not close assertion connectivity or the functional gaps. The target external-fabric reset contract and broader legal Engine × Fault × Phase × Reset crosses remain open.
