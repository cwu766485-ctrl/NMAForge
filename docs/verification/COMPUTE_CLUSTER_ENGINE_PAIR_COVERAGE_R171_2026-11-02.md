# Compute Cluster real-engine pair coverage — R171

**Run ID:** `R171-REAL-TOP-PAIR-COVERAGE-3S-20261102`  
**Test ID:** `TC-CL-R171-ENGINE-PAIR-OVERLAP-COV`  
**Result:** `PASS` for the seven-engine pair-overlap functional coverage point.  
**Test source SHA:** `70a02834b3360d779cd6f54c3318f93177d032d1` (tree `9701bcaa7417c0cb7babdeab4996d6714cbbf04f`).  
**Published clean replay SHA:** `8a2d5f85add54f81019df1a8d6a29ad08bbe88d6` (same tree), replayed from detached clean worktree `/tmp/nmaforge_r171_published_clean_8a2d5f`.  
**Product RTL/SPEC:** unchanged; selected product baseline remains `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, SPEC v1.8.

## Testpoint and checker

The real-top C1 workload launches all seven production engines. Its existing cycle monitor forms a 21-bit mask from pairs observed simultaneously in `engine_busy`; the test requires the mask to equal `21'h1f_ffff`. The new `engine_pair_overlap_cg` defines one named URG bin for every unordered pair. It samples only bits observed by that cycle monitor, checks the sampled-bin count and covergroup score are both complete, then emits `CLUSTER_ALL_ENGINE_PAIR_COVERAGE_PASS`. The regression Make target requires this marker for every seed.

No illegal state or artificial pair was injected. This functional coverage is separate from RTL code coverage and does not claim coverage of every pair under every fault, bank conflict, reset phase, or backpressure condition.

## Results

| Seed | Pair overlap / URG group | Memory scoreboard | UVM warning/error/fatal |
|---:|---|---|---|
| `20261025` | 21/21; 100.00% | 69,022 words; mismatch/unknown/stale = 0/0/0 | 0/0/0 |
| `20261026` | 21/21; 100.00% | 69,022 words; mismatch/unknown/stale = 0/0/0 | 0/0/0 |
| `20261027` | 21/21; 100.00% | 69,022 words; mismatch/unknown/stale = 0/0/0 | 0/0/0 |

All seven output images and completion records also pass the existing independent Golden checks. The all-engine marker records maximum active engines `7` and `2,694` shared compute-request backpressure cycles. The merged URG group `engine_pair_overlap_cg` reports 21 expected, 0 uncovered, 21 covered (100.00%); each of its 21 bins is hit once per seed. `cluster_cg` is 64/64. The full testbench-group score is 70.41% because unrelated DMA/AXI and other groups are not covered by this compute-only run; this is not overall coverage closure.

The same worktree passes Top Smoke with the 86-descriptor mapper precheck and 20 random cases (`TEST PASS`). It reports the existing fixture `[LOOP-REROLL-ENABLED]` line-debug notice. The UVM compile log has no `Warning-`, `Error-`, or `TFIPC` diagnostics; VCS reports successful elaboration with 0 errors and 0 warnings.

## Commands

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r171_published_replay_8a2d5f \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

# From dv/subsystem/top_smoke/sim
make ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025
```

The regression uses Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, and UVM 1.2. Per-seed logs and merged coverage are under `/tmp/nmaforge_r171_published_replay_8a2d5f/urg_merged`. The external evidence archive includes both the initial candidate run and this published clean replay; it is `/tmp/nmaforge_r171_paircov_evidence.tar.gz` (SHA-256 `1a374d4b4f866752e7a7e2e7e8cf005a311cfc4573ed03e431376a12d981d7ae`); its manifest is `/tmp/nmaforge_r171_paircov_evidence/MANIFEST.sha256` (SHA-256 `a9a9f4c0be8bc514add59ef12da409d404e800913e371fbed8bac67b907a6590`).

## Requirement and sign-off boundary

This adds explicit three-seed bin evidence for `REQ-PC-001` and supplements the existing production-top pairwise Golden evidence. `REQ-PC-007` remains `PARTIAL`: exhaustive shared-SPAD owner, bank, fault, reset, and backpressure crosses are still open. No requirement is promoted by R171. The 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
