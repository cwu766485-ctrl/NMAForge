# Compute Cluster Memory Fabric Reset Replay — R228

**Date:** 2026-11-03  
**Candidate SHA:** `186c175dc984729fb488e32fb7132ddd287b4968`  
**Candidate tree:** `666e3d7051e24132dfb922900c0ba85bee5b37eb`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`  
**Run ID:** `R228-MEMORY-FABRIC-RESET-CLOSEOUT-CANDIDATE-3S-20261103`  
**Seeds:** `20261025`, `20261026`, `20261027`

## Result

The selected in-repository `ai_accel_memory_fabric` reset/epoch regression passes all three seeds:

```sh
make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r227_memory_fabric_reset_20261103 \
  MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'
```

Each seed observes four DMA reads outstanding while CNM has an accepted SPAD read awaiting its registered response, resets the shared fabric, checks that the old response owner/epoch is flushed, and requires both DMA and CNM to complete fresh post-reset work. A second cut resets after CNM operand reads complete while its result write is pending. The target's independent recovery checks pass both phases on each seed.

| Evidence | Result |
|---|---|
| `dma_cnm_shared_reset_cg` | 100% |
| `cnm_reset_phase_cg` | 100% |
| `dma_reset_phase_cg` | 100% |
| `ap_single_response_owner` | 3,969 attempts, 3,921 successes, 0 failures/incomplete |
| `ap_cnm_response_tag` | 3,969 attempts, 144 successes, 0 failures/incomplete |
| UVM severity per seed | Warning/Error/Fatal `0/0/0` |
| Compile diagnostics | No `Warning-`, `Error-`, or `[TFIPC]` matches |

The RTM mapping is limited to this defined point: `REQ-CL-018` stays PARTIAL because other legal fault/phase/reset combinations remain; `REQ-PC-006` and `REQ-PC-007` stay PARTIAL because this does not test all production requesters and pairwise contention; `REQ-PC-010` remains PASS-SCOPED for the repository fabric reset contract. This run does not qualify an arbitrary external AXI/DDR fabric.

## Evidence archive

Raw output directory: `/tmp/nmaforge_r227_memory_fabric_reset_20261103`. Logs-only archive: `/tmp/nmaforge_r228_memory_fabric_reset_r226_20261103.tar.gz`, SHA-256 `02624ca29a3e1514a348f27e31534b70ce5c4ae4f2440bc63e0dc816342020b9`. The archive includes compile/run logs, URG group and assertion reports, and their checksum manifest; simulator binaries and coverage databases are excluded.

## Sign-off impact

This replays the user-selected in-repository memory-fabric reset/epoch contract at the closeout candidate and confirms the scoped `OPEN-CL-003` disposition. It is not evidence for external fabric behavior and does not close `CL-COV-002/006` or promote the 38-row RTM. The current count remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
