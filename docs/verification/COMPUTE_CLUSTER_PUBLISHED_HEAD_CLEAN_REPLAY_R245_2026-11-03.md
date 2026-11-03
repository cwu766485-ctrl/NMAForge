# Compute Cluster Published-HEAD Clean Replay — R245

## Candidate and scope

| Item | Value |
|---|---|
| Published GitHub SHA | `8078ed55af3b72652e74308483c20bd0d18a6cc9` |
| Git tree | `4ce6125303d67caaf656770a81357f90f749a77b` |
| Worktree | Detached clean worktree `/tmp/nmaforge_r245_published_clean` |
| Run ID | `CL-COMPUTE-CLUSTER-CLEAN-REPLAY-R245-3S-20261103` |
| VCS / URG | Synopsys V-2023.12-SP1_Full64 / V-2023.12-SP1 |

This is a reproducibility replay of the exact published `main` commit after the R243 report correction. No RTL, UVM, SPEC, or benchmark source changed for this replay.

## Commands and results

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r245_published_8078ed5 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261103 AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

Both commands passed. The three real-top seven-engine Cluster seeds each report UVM warning/error/fatal `0/0/0`, 92,871 Memory Scoreboard words checked, 73,190 writes, zero mismatch/unknown/stale observations, and a drained response-owner ledger: 5,015 accepted, 4,995 checked, 20 reset-dropped, zero route/data/error mismatch, and zero pending. The observed per-engine maximum request waits are `{12,14,53,0,64,126,14}` (stalled mask `1110111`); these runs do not inject downstream SRAM stalls.

Top Smoke mapper precheck passes with 86 descriptors and 60 tensors, and the fixed 20-case top regression ends in `TEST PASS`. The existing `[LOOP-REROLL-ENABLED]` fixture compile notice remains visible.

## Coverage and disposition

URG merges the three Cluster VDBs. The focused `cluster_cg` is 64/64 (100%). The mixed group score is 79.18%; mixed hierarchy line/condition/FSM/branch/assert/group is `70.46/65.51/45.96/60.64/72.00/79.18%`. These metrics include DUT, SVA, testbench, and UVM code and are not DUT-only coverage or global functional closure.

Assertions have 17/22 properties with real successes, zero failures/incomplete. Three AXI AR/AW properties have attempts but no real success; two UVM RAL internal properties have no attempts. AR/AW stall-to-accept covers do not match in this compute-only workload; W matches once per seed. Separate R241 evidence covers AR/AW/W stalls under its mixed-precision E2E source/test identity.

This replay makes no requirement disposition changes. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The broader R238 3-Cluster plus 16 mixed-E2E campaign remains the relevant merged cross-workload coverage evidence.

## Evidence archive

Archive: `/tmp/nmaforge_r245_clean_replay_evidence_20261103.tar.gz`  
SHA-256: `0c3749f6bb326f25158e7c5ad7861521e6d2c5ef7728c4a06cb4d0da0eb2f210`

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `8865cce93a690566d586f8a5476d7bc474ce23ba7acf9b223ab340f6a668755e` |
| Seed 20261025 | `4d758ced638106048a35cf69a64dfdd3efed0674fa61a1fdf8cc11066adf639a` |
| Seed 20261026 | `6429630f61618f1d2fdb7694382b7b19dd16ad18b0a324c6e556a5c897b52bf9` |
| Seed 20261027 | `4a5090a601dc2eac756bde62f560fbabfcd46bc578eeb01749dc6cb0b57906d4` |
| URG dashboard | `1133baa799a1cc80ce927e183f103ba7bfa342ccab8f0512dc4f77500c0ae1b1` |
| URG group detail | `af0e40ac437fe42855b2948be6cb9ab5e4135c95f6f38d757f07e665a6554d43` |
| URG assertion detail | `0f874d0efdc1e8002deea5d1de45432883dbb668da3eca7a38fa2001b0652f33` |
| Top Smoke compile | `3d760e71e4c28ca16b3db2687ed6c6749a7a1c11f2539cf6024e7c289d87cc35` |
| Top Smoke run | `307f670b20c4ba785e498c33e26f78a6e3ad84a0b1690502a4e3f02747db9661` |
