# Compute Cluster Depthwise Three-Channel CMDQ Evidence — R297

**Disposition:** PASS for the named three-channel sequential Depthwise testpoint. This adds bounded real-top evidence to `REQ-CL-015` and `REQ-CL-024`; it does not close either full requirement or `OPEN-CL-002`.

## Fixed candidate and reproducibility

| Item | Evidence |
|---|---|
| Test ID | `TC-CL-R297-DEPTHWISE-3CH-CMDQ` |
| Run ID | `R297-DEPTHWISE-3CH-CLEAN-3S-20261104` |
| Local source/test SHA and tree | `e578a1ec427e2b4160aac29206d4b24e4ae768b0` / `f1ba5c43b3fb33f455f68d4f3298ab9b478a56eb` |
| Published GitHub equivalent-tree commit | `be64e44601557a70af26dd713d294d1dc4c020c3`, branch `feat/compute-cluster-closeout-audit` |
| Worktree | Detached clean `/tmp/nmaforge_r297_depthwise_clean` |
| Tools | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |
| Evidence archive | `/tmp/nmaforge_r297_depthwise_clean_evidence.tar.gz`; SHA-256 `117df9ba3f6235ded5e726ec76874aec874ce553a59e81b2f9a202b2b89a51f9` |

## Test and result

Three sequential opcode `0x17` descriptors run through the production CMDQ dispatcher and Conv/Depthwise engine. Each channel has independent 4×4 input, 3×3 weight and 2×2 output regions. The test checks the observed launch addresses and dimensions, twelve signed INT32 outputs against an independent window Golden, each ordered completion and both output guards per channel.

| Seed | Result | Memory Scoreboard | Response-owner ledger | UVM severity |
|---:|---|---|---|---|
| `20261025` | 12/12 Golden words; 3/3 completions; 3-channel bin 1/1 | 146,796 checked; 0 mismatch/unknown/stale | 10,703 accepted; 10,683 checked; 20 reset-dropped; 0 mismatch/pending | 0/0/0 |
| `20261026` | 12/12 Golden words; 3/3 completions; 3-channel bin 1/1 | 146,796 checked; 0 mismatch/unknown/stale | 10,703 accepted; 10,683 checked; 20 reset-dropped; 0 mismatch/pending | 0/0/0 |
| `20261027` | 12/12 Golden words; 3/3 completions; 3-channel bin 1/1 | 146,796 checked; 0 mismatch/unknown/stale | 10,703 accepted; 10,683 checked; 20 reset-dropped; 0 mismatch/pending | 0/0/0 |

The same clean candidate passes Top Smoke: the mapper reports 86 descriptors / 60 tensors and the simulation prints `TEST PASS`. Its existing `[LOOP-REROLL-ENABLED]` compile warning remains.

## Scope and remaining work

This test proves one legal three-channel sequence at a fixed 4×4 shape. It does not establish an architectural channel maximum, cover arbitrary channel counts or channel interleaving, or close the remaining per-engine shape, alias/stride/zero-value, KV boundary, and fault/reset crosses. No requirement disposition is promoted: the 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Reproduction commands

```bash
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_phasea_depthwise_r297_clean_replay \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

cd dv/subsystem/top_smoke/sim
make ai_smoke SEED=20261025 AI_RANDOM_CASES=4 AI_SEED=12345
```
