# Scalar GEMV Accepted-Write Abort Prefix — R129

Date: 2026-10-31
Run ID: R129-SCALAR-GEMV-ABORT-PREFIX-3S-20261031
Executed clean-worktree test SHA: 8b511e474727fe13439f99674d1a30b46005f274
Published test-content SHA: 1ba30c7f85d5b07c13eddb7aef3e6929f7d9624d
Tree: 4a52f377cf93d008e8effd1310b94478713e82fc (identical local and published tree)
Product RTL/SPEC identity: R99 product baseline c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413; SPEC v1.8 unchanged. This changes the UVM sequence and required regression gate only.
Tools: Synopsys VCS V-2023.12-SP1_Full64; URG V-2023.12-SP1.

## Testpoint

A legal real-CMDQ Scalar GEMV descriptor runs M=16, K=64 with deterministic signed INT8 operands. The monitor requests Abort after the first accepted output write. Each run must observe a nonempty proper output prefix, check each committed word against an independent signed integer Golden, preserve every uncommitted destination sentinel, drain accepted reads, observe ERR_ABORT (0x32), and reject any output write after the Abort sampling edge.

| Seed | Accepted output prefix | Accepted reads returned | Post-Abort output writes | UVM warning/error/fatal |
|---|---:|---:|---:|---:|
| 20261025 | 1/16 | 130/130 | 0 | 0/0/0 |
| 20261026 | 1/16 | 130/130 | 0 | 0/0/0 |
| 20261027 | 1/16 | 130/130 | 0 | 0/0/0 |

For each seed, the sole committed result equals the Golden output for row 0; the remaining 15 destination words retain their original sentinel values. The completion task ID and status/code are checked in SPAD. The full memory scoreboard reports 34,637 writes and 42,107 checked words with zero mismatch, unknown read, stale-epoch response, or orphan response.

## Clean replay

Detached checkout: /tmp/nmaforge_r129_scalar_abort_clean_20261031/checkout at the exact executed SHA.

Command:

    make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r129_scalar_abort_clean_20261031/run COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

The required Make gate passes for all three seeds and prints COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS. Compile log has no Warning-, Error-, or TFIPC diagnostics. The declared focused cluster_cg is 100%; this is the declared group, not whole-design functional or code coverage. The merged mixed DUT/testbench/UVM dashboard is 55.92% overall (line/condition/FSM/branch/assert/group: 69.27/63.14/41.91/59.51/72.00/29.72%). URG reports 17/22 assertion properties with real successes, zero failures/incomplete; three AXI properties have no real successes in this compute-only workload, two UVM RAL properties have no attempts, AR/AW stall covers are unhit, and the W stall cover matches three times.

Top Smoke: NOT_RUN at R129. Mutation campaign: NOT_RUN at R129. This change is UVM sequence and gate only; prior exact-source RTL smoke and mutation evidence retain their recorded SHAs.

## Artifact paths and hashes

Raw artifacts remain outside Git at /tmp/nmaforge_r129_scalar_abort_clean_20261031/run/.

| Artifact | SHA-256 |
|---|---|
| compile.log | 1a5bd5443581d502196df98f1b3cebc97a4c620edb1d8d57140d5dd2ab828631 |
| seed_20261025/run.log | 7a7da951ce3d7e7d7039a4edef287da5c402e6a530bee1bb88ef4c07eb76c933 |
| seed_20261026/run.log | 069232ee4e6fc27f73dc026356a13d2c142bb5adcc759926a5311bcd886d7756 |
| seed_20261027/run.log | c90d8f3825ab86d388941f592a5f119da17b2f885836637ecf69d099d435fd69 |
| urg_merged.log | 1e5a945f78074fa0c173b9160766a061941fca8939b69e1964249d8477e1eec2 |
| urg_merged/dashboard.txt | df17cd359e12b9d875a6a0484cc7c41c80b76c1d3b32ab3aefbb90890be82cf8 |
| urg_merged/groups.txt | cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f |
| urg_merged/asserts.txt | baa15dec2618fde077c27aff97b1d1cfac2564c7ffcd1c9f907edcabce296ff9 |

## Requirement impact

R129 adds a bounded accepted-write Abort prefix point to REQ-CL-017/019/027 and memory-ledger evidence to REQ-PC-006. Those requirements remain PARTIAL: legal engine × fault × phase × reset crosses, all error phases, and broader requester/backpressure combinations remain open. The overall 38-row disposition stays 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD.
