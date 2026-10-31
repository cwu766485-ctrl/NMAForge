# Compute Cluster final published SHA replay — R121

**Run ID:** `R121-CLEAN-HEAD-53229E2-3S`  
**Exact published review SHA:** `53229e2db16cfbd5a6acbf5824e3b366272a51f2`  
**Tree:** `397730f25759e451f1ebd6be80a6df46ce69c1f1`  
**UVM/test content:** R120 `894559c0c373dcef667074d304f94164f8514fee`, unchanged in this tree  
**Product RTL/SPEC baseline:** R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, SPEC v1.8  
**Checkout:** empty detached worktree `/tmp/nmaforge_exact_final_53229e2`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`

## Commands and result

From `dv/subsystem/top_smoke/sim`:

```sh
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

From `dv/uvm/sim`:

```sh
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_exact_final_53229e2_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

All commands exit 0. The mapper precheck passes with 86 descriptors and 60 tensors; both top tests end in `TEST PASS`. The three real-top UVM seeds each report `0/0/0` UVM warning/error/fatal, 18/18 parity cases, 19/19 Protection cases, 21/21 production-engine pair overlaps, seven accepted-read Abort/drain cases, 7/7 post-sampled-Abort output-write suppression, and 33,510 memory words checked with no mismatch or unknown read. The focused compute functional group is 100.0% applicable coverage per seed. URG merges all three VDBs.

This replay confirms that the restored Top Smoke target, seeded Top Regression, and R120 test content reproduce together at the exact published review SHA. It adds no test or product RTL changes and closes no additional RTM row. The current disposition remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.

## Coverage and SVA disposition

The merged URG dashboard reports mixed DUT/TB/UVM line/condition/FSM/branch/assert/group scores of `68.71/61.46/40.99/58.71/72.00/29.72%` (overall score 55.27%). These are raw mixed code/assert/group metrics, not functional testpoint closure. The 100.0% result above is only the declared applicable focused compute group.

UVM compile reports zero VCS `Warning-*`/`Error-*` diagnostics and no `[TFIPC]` message. In this Compute Cluster workload, merged URG records 17/22 assertion properties with real successes, zero failures/incomplete, and two UVM RAL internals without attempts. Three top AXI AR/AW properties have no real success in this workload; the AR/AW stall-to-accept covers are not hit here, while the W cover hits three times. This test does not issue the DMA AXI traffic needed for those properties. The separate R92/R102 AXI workloads provide their non-vacuous AR/AW/W assertion and cover evidence. `ai_smoke` also prints the existing `LOOP-REROLL-ENABLED` fixture diagnostic for `ai_transformer_workload.svh`; its elaboration completes with zero errors and zero warnings.

## Evidence artifacts

Generated VCS/URG files remain outside the repository:

- Logs and text summaries: `/tmp/nmaforge_exact_final_53229e2_evidence/`
- VCS databases and full URG report: `/tmp/nmaforge_exact_final_53229e2_uvm/`

| Artifact | SHA-256 |
|---|---|
| `mapper_precheck.log` | `72251079b4eea046747283a47d471d2ee700919a0e49bd2c2e602cc66d0acd88` |
| `ai_smoke.log` | `6592e2b257c18389c5dd882b6b8d38b1db9b6a87e42ce9069ec2f295090aafd1` |
| `ai_run_20_seed_12345.log` | `327041c8895b7f02191eb7ee121a106d6a35cb40d1de5a992ed85b19516e2598` |
| `uvm_compile.log` | `e1d7585503009119c342e58f80931e7c777ce5e67ac339ccc8d4f855031c7ef4` |
| `uvm_seed_20261025.log` | `534b95ea1889ba8c4c9b9371ba534fdb01c168d0fe5683505d4fb1368c53d6ce` |
| `uvm_seed_20261026.log` | `aadb3b388dbcff51ada2b974b904ff2e05226278d98d391bf933eb5c30f76942` |
| `uvm_seed_20261027.log` | `0be17b4e39df3bf43dacc6f80ec003d004e75506a79a3a298be13bfbe9b50d50` |
| `urg_merged.log` | `2847e29ab1650d4bc1558d89ed7a609ae5ed8829648f736a9e00333283448c6b` |
| `urg_dashboard.txt` | `7394979df5a449822b41f5935f4fd64896f73194f8582f03d6bb65bfa96eee06` |
| `urg_asserts.txt` | `872bc9b474ec12d4437f391dade86d2ae5271428295fd3ca0097d70d77c26d66` |
| `urg_groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
