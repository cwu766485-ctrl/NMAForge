# Compute Cluster memory-fabric clean replay — R153 — 2026-11-01

## Candidate and result

These runs replay the user-selected in-repository ai_accel_memory_fabric and
production ai_spad_arbiter on the R153 clean test candidate SHA
6e47629f103e3ab36948c5bb4eadc196cd27dfb4, tree
21478d7e4a595e17b27f7b0e89810d3617a4fd82. The published same-tree test
commit is 79b84addfb870aa96ef99e5ccff9d4f1b2dba0af. Synopsys VCS
V-2023.12-SP1_Full64 and URG V-2023.12-SP1 run seeds 20261025, 20261026,
and 20261027 for each target.

| Run ID | Testpoint | Named functional group | Non-vacuous assertion evidence |
|---|---|---|---|
| R153-FABRIC-RESET-3S-20261101 | Accepted DMA/CNM SPAD work, reset epoch flush, fresh-work recovery | dma_cnm_shared_reset_cg: 100%; target requires 3/3 reset groups | ap_cnm_response_tag 3969 attempts / 144 successes / 0 failures / 0 incomplete; ap_single_response_owner 3969 / 3921 / 0 / 0 |
| R153-BANKED-RESET-3S-20261101 | Accepted banked-response flush, reset quiet window, tagged recovery | banked_reset_epoch_cg: 100% | ap_banked_response_tag 450 / 3 / 0 / 0; ap_single_response_owner 450 / 429 / 0 / 0 |
| R153-BANKED-CONTENTION-3S-20261101 | Simultaneous Core and Banked requests through the production arbiter | banked_core_contention_cg: 100% | ap_core_response_tag 429 / 3 / 0 / 0; ap_banked_response_tag 429 / 3 / 0 / 0; ap_core_grant_owner 429 / 3 / 0 / 0 |
| R153-BANKED-CORE-RESET-3S-20261101 | Core response while Banked is pending, reset flush, quiet window, dual-owner recovery | banked_core_reset_epoch_cg: 100% | ap_core_response_tag 471 / 3 / 0 / 0; ap_banked_response_tag 471 / 3 / 0 / 0; ap_single_response_owner 471 / 441 / 0 / 0 |

All twelve seed runs report UVM warning/error/fatal 0/0/0. These percentages
apply to the named covergroups only; they are not global functional or code
coverage closure.

## Exact commands

Run from the repository root:

    make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r153_fabric_reset MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'
    make -C dv/subsystem/dma_spad/sim subsystem_banked_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_RESET_OUT=/tmp/nmaforge_r153_banked_reset BANKED_RESET_SEEDS='20261025 20261026 20261027'
    make -C dv/subsystem/dma_spad/sim subsystem_banked_contention_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CONTENTION_OUT=/tmp/nmaforge_r153_banked_contention BANKED_CONTENTION_SEEDS='20261025 20261026 20261027'
    make -C dv/subsystem/dma_spad/sim subsystem_banked_core_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CORE_RESET_OUT=/tmp/nmaforge_r153_banked_core_reset BANKED_CORE_RESET_SEEDS='20261025 20261026 20261027'

## Scope and evidence

The reset/owner checks exercise the selected repository fabric, registered
four-bank SPAD and production arbiter. Core/Banked requesters in the two
arbitration tests are testbench-driven. This is not production Matrix-engine
banked contention, nor the full seven-engine requester × fault × phase ×
backpressure × reset matrix; REQ-CL-018 and REQ-PC-007 remain PARTIAL.

The logs-only archive is
/tmp/nmaforge_r153_fabric_clean_replay_3seed.tar.gz, SHA-256
dc37d948d0f1038b71d7298a97a4fe6a32e955050e116a15015f17109e3ad0d0.
It includes each target's compile and Make logs, three per-seed logs, selected
URG assertion/group HTML, and per-file SHA-256 values. Simulator binaries and
coverage databases are excluded.

This adds current-candidate reproducibility evidence for the selected fabric
slice. It does not change the 38-requirement disposition: 24 PASS-SCOPED / 14
PARTIAL; Compute Cluster v1.0 remains **HOLD**.
