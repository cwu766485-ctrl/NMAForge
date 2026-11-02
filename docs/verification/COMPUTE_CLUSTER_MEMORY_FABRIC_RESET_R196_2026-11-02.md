# Selected `ai_accel_memory_fabric` reset replay — R196

**Run ID:** `CL-MEM-FABRIC-RESET-R196-3S-20261102`  
**Fixed source/test SHA:** `f87acc9bca3b3ecece385fadfd5623de6837ea8d`  
**Source tree:** `cfc7ba4955488ae58d58f36deec368173c6ec98c`  
**Worktree:** detached clean checkout `/tmp/nmaforge_r194_clean_f87acc9`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`  
**Disposition:** PASS for the selected in-repository `ai_accel_memory_fabric` reset/epoch testpoint. The full Cluster disposition is unchanged at 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Scope

The test uses the production `rtl/top/fabric/memory/ai_accel_memory_fabric.v` through the DMA/SPAD subsystem. On every seed it exercises two shared-reset cut points while four DMA reads are outstanding: (1) CNM has an accepted SPAD read whose registered response has not returned and (2) CNM has consumed its operands and awaits the result write. It checks reset acknowledgment, reset-epoch owner flush, no stale response, and fresh DMA/CNM recovery. This does not qualify an arbitrary external AXI/DDR fabric; the external responder is behavioral.

## Reproduction

From the clean worktree:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r194_memory_fabric_reset_20261102 \
  MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'
```

The first invocation compiled and completed all three simulations but returned 127 at the URG aggregation step because `urg` was not on `PATH`. Re-running the same target with the installed URG path explicitly supplied completed the aggregation. No test source or RTL changed between attempts.

| Seed | Required pass marker | UVM warning/error/fatal | Reset phase recovery markers |
|---|---|---:|---:|
| `20261025` | PASS | `0/0/0` | 2/2 |
| `20261026` | PASS | `0/0/0` | 2/2 |
| `20261027` | PASS | `0/0/0` | 2/2 |

The aggregated URG reports all three declared groups at 100.00%: `dma_cnm_shared_reset_cg`, `cnm_reset_phase_cg`, and `dma_reset_phase_cg`. `ap_single_response_owner` records 3,921 real successes and `ap_cnm_response_tag` records 144; each has zero failures and zero incomplete attempts. The VCS compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Requirement traceability

| Requirement | Disposition | Test ID / checker | Coverage / observed result | Run ID / seeds | Evidence path |
|---|---|---|---|---|---|
| `REQ-CL-018` | `PARTIAL` | `TC-PC-R196-FABRIC-RESET`; reset-epoch groups, pending-owner flush, quiet/reset and fresh-work recovery checks | Three declared reset groups 100%; accepted CNM SPAD response is pending at reset and both reset cut points recover. Broader legal Engine × Fault × Phase × Reset remains open. | `CL-MEM-FABRIC-RESET-R196-3S-20261102`; `20261025/26/27` | `/tmp/nmaforge_r196_memory_fabric_reset_evidence_20261102/seed_*/run.log`; `groups.html` |
| `REQ-PC-006` | `PARTIAL` | Same test; DMA scoreboard, SPAD request/response ledger and post-reset Golden checks | DMA/CNM reset recovery and accepted-response flush pass; full production requester × fault × backpressure combinations remain open. | Same run and seeds | Same logs; `asserts.html` |
| `REQ-PC-007` | `PARTIAL` | Same test; `ap_single_response_owner`, `ap_cnm_response_tag`, owner/epoch checkers | 3,921/144 assertion successes, zero failure/incomplete; this is DMA/CNM selected-fabric reset evidence, not complete seven-engine production-pair coverage. | Same run and seeds | `asserts.html`; per-seed logs |
| `REQ-PC-010` | `PASS-SCOPED` for existing defined reset contract | Same test; DMA/CNM reset acknowledgment, epoch flush and recovery | Selected in-repository SPAD fabric behavior passes; arbitrary external AXI target-fabric compliance is outside this test. | Same run and seeds | Per-seed logs and archive |

This exact-candidate replay confirms `OPEN-CL-003` for the user-selected in-repository fabric. It does not change any requirement status: `REQ-CL-018`, `REQ-PC-006`, and `REQ-PC-007` stay `PARTIAL`; the aggregate 38-row decision stays 24 `PASS-SCOPED` / 14 `PARTIAL` and **HOLD**.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_r196_memory_fabric_reset_evidence_20261102.tar.gz`  
SHA-256: `7eee9b67718896402ad2882a7f9a145287d0a101e8a0fb903f7d481681095879`

It contains the compile log, three run logs, URG `groups.html` and `asserts.html`, a run manifest, and per-file SHA-256 checksums. Coverage databases and generated executables are not included.
