# Compute Cluster KV FSM Residual Transition Closure — R223

**Disposition:** PASS for the four previously unhit `ai_kv_cache_engine.state_r` transitions in this block-level test. This closes only the named KV FSM testpoint; it does not change the Compute Cluster sign-off decision.

## Fixed source and tools

- Clean-worktree tested source SHA: `0e273b8974dbfa593452f7a6a7996c78ddfe4a6e`.
- Source tree: `eef6ed76de2e402c2447735ce6d3b2df87d103ed`.
- Parent: `cd99517a88acda013eae13d73d934d482d63a03f`.
- GitHub-published equivalent code commit: `5ed4d89b9a182c0cbaf08672f6d1d268020f81e5`, with the same source tree.
- Product RTL was not changed. `rtl/compute/kv/ai_kv_cache_engine.v` SHA-256: `a4247a32f5e5278b0898dc9712be165b3b34d76267b955df6a8e82db265fa94d`.
- VCS: Synopsys `V-2023.12-SP1_Full64`; URG: Synopsys `V-2023.12-SP1`.

## Test and legal transition triggers

Test ID `TC-KV-FSM-RESIDUAL-4`; Run ID `R223-KV-FSM-CLEAN-3S-20261103`.

The test uses normal KV transactions and external handshake/ready behavior. It does not force or deposit DUT state:

| Previously unhit transition | Legal trigger and checker |
|---|---|
| `ST_DONE → ST_ERROR` | Let the documented watchdog expire while the transaction remains busy in completion; check watchdog error retirement. |
| `ST_READ_WAIT → ST_IDLE` | Accept a legal read, hold its response, then assert asynchronous reset; check the old-epoch read is explicitly counted as reset-dropped and no response is attributed after reset. |
| `ST_WRITE → ST_ERROR` | Hold the legal write unaccepted with SPAD ready low, then assert Abort; check Abort error retirement and destination sentinel preservation. |
| `ST_WRITE → ST_IDLE` | Hold the legal write unaccepted with SPAD ready low, then assert asynchronous reset; check reset cancellation and no write side effect. |

The focused checker requires all four transitions (`4/4`) on every seed and checks error status, memory sentinels, response ownership, and end-of-test owner-ledger drainage. The reset case accounts for its accepted pending read as one intentional reset drop: `accepted_reads = responses + reset_dropped`, with no pending entry at test end.

## Clean regression evidence

Executed from the clean detached worktree:

```sh
make -C dv/block/compute/cnn_kv/sim random-latency-regress \
  SEEDS='20261025 20261026 20261027' \
  OUT_DIR=/tmp/nmaforge_r223_clean_kv_0e273b8 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

All three seeds pass. Each prints `KV_FSM_RESIDUAL_TRANSITIONS_PASS ... bins=4/4`; the owner ledger closes with exactly one reset-dropped response per seed:

| Seed | Accepted reads | Responses | Reset-dropped | Directed bins |
|---|---:|---:|---:|---:|
| `20261025` | 4,446 | 4,445 | 1 | 4/4 |
| `20261026` | 4,585 | 4,584 | 1 | 4/4 |
| `20261027` | 3,962 | 3,961 | 1 | 4/4 |

URG merges these three test databases and reports `ai_kv_cache_engine.state_r` at **6/6 states and 15/15 transitions (100%)**. This is raw block FSM coverage; it is not a Compute Cluster wide coverage claim. The CNN+KV testbench aggregate dashboard is line `100.00%`, condition `93.63%`, FSM `75.00%`, branch `97.37%` and score `91.50%`.

The same clean source tree passes Top Smoke:

```sh
cd dv/subsystem/top_smoke/sim
make ai_smoke
```

The run ends in `TEST PASS`; the mapper precheck reports 86 descriptors and 60 tensors. The existing `[LOOP-REROLL-ENABLED]` fixture compile warning remains and is not hidden or treated as a test failure. The KV block compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

The same clean tree also passes the fixed-seed 20-case Top regression:

```sh
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

The run reports VCS `+ntb_random_seed=1793677008`, `AI_SEED=12345`, and ends in `TEST PASS`.

### Exact-candidate real-top UVM replay

After the focused KV run, the same clean tested source SHA passes the three-seed real-top Compute Cluster UVM regression:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r223_final_uvm_0e273b8 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Each seed reports UVM warning/error/fatal `0/0/0`, checks 92,871 memory words after 73,190 writes with zero mismatch/unknown/stale/orphan, and drains the response-owner ledger: accepted 5,015, checked 4,995, reset-dropped 20, route/data/error mismatches 0, pending 0. Each seed also passes the mandatory real-engine overlap, Matrix/CNM collision and hold, seven-engine parity, reset/recovery, Abort, Protection, and Completion Queue checks enforced by the Makefile gate.

The three-seed UVM URG dashboard is score `79.18%`; line/condition/FSM/branch are `70.42/65.51/45.96/60.64%`. Assertions have 17/22 real successes, zero failures/incomplete, and two UVM RAL internal no-attempts; the AR/AW payload/burst assertion properties have attempts but no real success. Of the three SVA cover properties, W stall-to-accept matches once and AR/AW stall-to-accept have zero matches in this Compute Cluster-only workload. These bins remain uncovered here; the separate mixed AXI E2E evidence is not merged into this run.

### Selected in-repository memory-fabric reset/epoch replay

On the same clean source SHA, the user-selected `ai_accel_memory_fabric` reset target also passes three seeds:

```sh
make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r223_final_fabric_reset_0e273b8 \
  MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'
```

Each seed resets with four DMA reads outstanding and an accepted CNM SPAD read awaiting its response, then runs two post-reset DMA/CNM recovery phases. UVM severity is `0/0/0` per seed. URG reports the three declared fabric reset groups (`dma_cnm_shared_reset_cg`, `cnm_reset_phase_cg`, `dma_reset_phase_cg`) at 100%; `ap_single_response_owner` has 3,921 real successes and `ap_cnm_response_tag` has 144, with zero failure/incomplete. The compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. This qualifies only the selected repository fabric and its modeled responder; it does not qualify an arbitrary external fabric implementation.

## Evidence and requirement disposition

Focused KV/Top Smoke logs-only archive: `/tmp/nmaforge_r223_kv_fsm_evidence_20261103.tar.gz`, SHA-256 `889d646d9a538fb0c899c69ab4175f8f7a29efd2f0c5c53c5dd49973aafcb060`. The latest consolidated exact-candidate archive is `/tmp/nmaforge_r223_full_clean_evidence_20261103_v3.tar.gz`, SHA-256 `8d094780c06d9ee353dbeb7645d32cb10b358c62453d39c97ff80af6e153157f`; it contains KV, Top Smoke, fixed-seed Top, three-seed real-top UVM, selected memory-fabric reset logs and URG reports. Archives are logs/reports only and exclude databases, binaries, and waveforms.

`REQ-CL-025` remains **PASS-SCOPED**. R223 adds the four-transition KV FSM evidence to its existing KV address/Protection/Golden evidence and clean replay for the named real-top/fabric tests. Exhaustive KV stride/alias products, broader per-engine descriptor contracts, external-fabric qualification and the remaining partial requirement clauses are still open. No requirement status is promoted by these testpoints. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
