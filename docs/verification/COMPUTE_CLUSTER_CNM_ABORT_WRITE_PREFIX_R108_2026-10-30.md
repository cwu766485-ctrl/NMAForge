# Compute Cluster CNM accepted-write Abort prefix — R108

**Date:** 2026-10-30  
**Exact code/test SHA:** `26448b12e545498d31ce8665723db97e10e2c1e2`  
**Product RTL/SPEC baseline:** R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; R108 changes UVM sequence and regression gate only.  
**Run IDs:** `CLUSTER-CNM-ABORT-WRITE-PREFIX-R108-3S`, `CLUSTER-MUTATION-R108-28`, `TOP-SMOKE-R108`, `TOP-RANDOM-R108-20`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Testpoint

Run a legal production-top CNM GEMV with 16 output rows and K=4 packed words per lane. The sequence builds an independent signed INT8 Golden for every output, initializes the complete destination with sentinels, and waits for an actual accepted CNM output write before issuing software Abort. It records accepted write addresses/data, counts four-lane CNM request and response handshakes, checks the completion owner and `ERR_ABORT`, compares the committed prefix against the Golden and checks the entire unaccepted suffix remains unchanged.

All seeds accept exactly one of 16 output writes before Abort, drain 40/40 CNM reads, and pass the completion and full memory-image checks. The accepted output address and payload match the independent Golden. Focused applicable Compute Cluster coverage remains 100%; this marker is a gated directed testpoint, not a claim that the broader fault cross or global requirement coverage is closed.

## Reproduction

Clean detached replay worktree: `/tmp/nmaforge_r108_clean_26448b1`, HEAD `26448b12e545498d31ce8665723db97e10e2c1e2`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r108_clean_replay_20261030 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r108_clean_mut_compile_20261030 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r108_clean_mutations_20261030 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  > /tmp/nmaforge_r108_clean_mutation_make.log 2>&1

cd dv/subsystem/top_smoke/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat make ai_smoke
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All commands exit `0`. The clean three-seed regression includes compile, simulations, URG merge and explicit per-seed marker gates. UVM compile has no `Warning-`, `Error-` or `[TFIPC]` diagnostic. The exact-SHA checker-sensitivity campaign passes 28/28 named passive-observation mutations; it is not RTL fault injection or a DUT mutation score. Same-SHA Top Smoke and the 20-case seeded Top run pass; Top Smoke retains the existing `[LOOP-REROLL-ENABLED]` fixture warning and mapper precheck reports 86 descriptors / 60 tensors. Each UVM seed reports warning/error/fatal `0/0/0`, no memory mismatch/unknown read, `stale_epoch=0`, no orphan response, and all pending response queues empty. The compute-only URG profile has 17/22 assertion properties with real successes and zero failure/incomplete; two UVM RAL properties have no attempts and three AXI properties have no real success in this profile. Its W stall-to-accept cover matches once; AR/AW do not match here. The separate R102 behavioral AXI workload remains the evidence for AR/AW.

## Results

| Seed | Accepted output prefix | CNM reads accepted/returned | Memory scoreboard | Focused applicable coverage | UVM W/E/F |
|---|---:|---:|---:|---:|---:|
| `20261025` | `1/16` Golden words | `40/40` | 33,491 checked; 0 mismatch, 0 unknown, 0 stale | 100.0% | `0/0/0` |
| `20261026` | `1/16` Golden words | `40/40` | 33,491 checked; 0 mismatch, 0 unknown, 0 stale | 100.0% | `0/0/0` |
| `20261027` | `1/16` Golden words | `40/40` | 33,491 checked; 0 mismatch, 0 unknown, 0 stale | 100.0% | `0/0/0` |

Every run completes with owner task ID `0774` and status/error `0x32`. The destination suffix retains all 15 preloaded sentinels. The command reports `pending={0,0,0,0,0,0}` at test end.

## Artifact hashes

Generated logs and databases stay outside Git: UVM/URG under `/tmp/nmaforge_r108_clean_replay_20261030/`, checker-sensitivity mutations under `/tmp/nmaforge_r108_clean_mutations_20261030/`, and Top make logs under `/tmp/nmaforge_r108_clean_top_*_make.log`.

| Artifact | SHA-256 |
|---|---|
| Clean UVM compile log | `0cca448db6bb627c3e8b88a8973663ced4c4947fe3cff92b6cacb00930b32a6b` |
| Seed `20261025` log | `a76d11c07347375adf0a8e9b905b2e42161b937a2ba41c7352808a58afd1aab9` |
| Seed `20261026` log | `c06c9ed3be8a70fc3b11c2275ae6ddd2bbf71e0e614f2a54e955f7001b6f944d` |
| Seed `20261027` log | `6b7db37a2a9fac7ec258acd3f5b71afae856298b8440a0c07b4c773cb5a40344` |
| URG merged log | `2ec64b30464817901b7bf91088e622720a34c2dab7b158f6408dba7555f0e1ff` |
| Mutation campaign driver log | `c6bdef4f8bb10d3100096589ddb01cfdc4faf869d5dd655e69a1de92151ca719` |
| 28 mutation-log SHA-256 manifest | `/tmp/nmaforge_r108_mutation_SHA256SUMS.txt`, SHA-256 `1b0df0266547d0577991438e1f2d8b9762253959c6029dcef423d5b975c9b0e5` |
| Top Smoke make log | `d4c73c8bf17be5300491c367719d1314f3e68fcd71346852e999a2a3cbcb86f4` |
| 20-case Top make log | `72f900e7ba9e29cd4b4ef5683e1b714d75604652674aafafa6c9833725fd81be` |

## Disposition

R108 adds one real-top CNM accepted-write Abort prefix point for this legal descriptor and timing point. It strengthens `REQ-CL-019` error-prefix evidence and `REQ-PC-006/007` owner/drain evidence. It does not close all CNM prefix lengths, cross-engine fault/phase/reset combinations, or shared-SPAD contention under the full backpressure matrix. The 38-row RTM remains `24 PASS-SCOPED / 14 PARTIAL`; `CL-DV-v1.0` remains **HOLD**. Product RTL, SPEC, error ABI and requirement dispositions are unchanged.
