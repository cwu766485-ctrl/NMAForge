# Compute Cluster memory-fabric reset published-head replay — R291

## Identity and result

| Item | Evidence |
|---|---|
| Run ID | `R291-PUBLISHED-HEAD-MEMORY-FABRIC-RESET-20261104` |
| Exact source/test SHA | `e1fcde57c70936f2eb2cd8ed9aea14303a61c717` |
| Tree | `b353adf9035d5a45a1575cdbde827773051b5c1e` |
| Tool | Synopsys VCS / URG `V-2023.12-SP1_Full64` |
| Result | PASS, three fixed seeds; UVM severity `0/0/0` per seed |
| Evidence archive | `/tmp/nmaforge_r291_fabric_reset_published_logs.tar.gz`, SHA-256 `ca622a4e9858f73ea0b0b403cdb9a995fdfbdaee4915485eb967deae6b5e88d9` |

The detached worktree was at the exact published RTL/test SHA. The replay made no source changes. The tested integration includes the repository's production `ai_accel_memory_fabric`, `ai_spad_arbiter`, DMA, scratchpad, and CNM paths, plus the testbench's behavioral AXI memory responder.

## Reproduction

```sh
make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r291_fabric_reset_published
```

The default `URG=urg` attempt completed compile and simulation but the Make target stopped at report generation because `urg` was not on `PATH` (exit 127). Re-running with the installed URG path above completed the target successfully; the initial path issue did not affect simulation results.

## Testpoints and evidence

Seeds `20261025`, `20261026`, and `20261027` each reach both reset cut points: four accepted DMA reads outstanding while a CNM SPAD read response is pending, and DMA outstanding while CNM waits to write its result. The test checks reset flushes old response ownership, no stale response leaks into the new epoch, and fresh DMA plus CNM work completes after recovery. The target requires the pending-SPAD setup marker, both CNM recovery markers, `MEMORY_FABRIC_RESET_ONLY_PASS`, and zero UVM warnings/errors/fatals in every seed log.

| Test ID / checker | Result |
|---|---|
| `TC-PC-R291-REPOSITORY-MEMORY-FABRIC-RESET` / reset epoch, response owner, quiet-window and DMA/CNM recovery checkers | 3/3 seeds pass |
| `dma_cnm_shared_reset_cg` | 100% |
| `cnm_reset_phase_cg` | 100% |
| `dma_reset_phase_cg` | 100% |
| `ap_single_response_owner` | 3,921 real successes, 0 failures, 0 incomplete |
| `ap_cnm_response_tag` | 144 real successes, 0 failures, 0 incomplete |

Compile diagnostics contain no `Warning-`, `Error-`, or `[TFIPC]` entries. Checksums for compile and per-seed logs, and the URG groups/assertions reports, are in the archive manifest.

## Requirement disposition and limits

This is a latest-published-source replay of the repository-owned fabric reset test. It supports the selected reset contract in `REQ-CL-018` and `REQ-PC-010`; their existing scoped dispositions are unchanged. It does not qualify an arbitrary external SoC AXI fabric, production external memory responder, all seven-engine reset phases, or the broader legal fault × phase × reset matrix. `REQ-CL-018` remains `PARTIAL`; the overall Compute Cluster remains **HOLD**. This evidence does not promote any requirement status.
