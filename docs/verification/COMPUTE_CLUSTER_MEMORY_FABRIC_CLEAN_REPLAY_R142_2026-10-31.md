# Compute Cluster Memory Fabric Clean Replay — R142

**Date:** 2026-10-31  
**Selected target:** in-repository `ai_accel_memory_fabric`, production `ai_spad_arbiter`, registered four-bank SPAD, and the named reset/owner UVM harnesses.  
**Executed checkout:** local documentation commit `8f582444df74cd4877758a1cda0d6a61c82f6e3f`, tree `08542ec6a95b720985ad3a83914f54065012dddb`. The RTL, simulation source/test inputs, and SPEC are unchanged from R142 test commit `c87e137aaab2c708beffc1d7bdfb378829dcab1e` (tree `301ceb34e0eeba231a296ac35f52ea131240c8d3`); the intervening commit only records R142 evidence in documents.  
**Tools:** VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`. All runs used seeds `20261025`, `20261026`, and `20261027`.

## Results

All four targets pass on the same RTL/DV source content. Every seed reports UVM warning/error/fatal `0/0/0`.

| Run ID | Testpoint | Result |
|---|---|---|
| `R142-MEM-FABRIC-RESET-3S-20261031` | Reset with accepted DMA and CNM SPAD work pending; CNM reset phases; DMA/CNM fresh-work recovery | PASS; all 3 declared reset groups are 100%. `ap_cnm_response_tag`: 3,969 attempts / 144 real successes / 0 failures / 0 incomplete. `ap_single_response_owner`: 3,969 / 3,921 / 0 / 0. |
| `R142-BANKED-RESET-3S-20261031` | Flush an accepted banked response, quiet window after reset, tagged four-bank recovery | PASS; focused reset group 100%. `ap_banked_response_tag`: 450 attempts / 3 real successes / 0 failures / 0 incomplete. |
| `R142-BANKED-CONTENTION-3S-20261031` | Simultaneous Core and Banked requests through the production arbiter; response-owner and Golden data checks | PASS; focused group 100%. Core and Banked tag assertions each have 429 attempts / 3 real successes / 0 failures / 0 incomplete. |
| `R142-BANKED-CORE-RESET-3S-20261031` | Check Core response while Banked is pending, reset flush, quiet interval, and dual-owner recovery | PASS; focused group 100%. Core tag `471/3`, Banked tag `471/3`, and single-owner `471/441` attempts/successes; all have 0 failures / 0 incomplete. |

The reset tests check that an accepted request does not produce an old-epoch response after reset and that fresh post-reset requests return the expected four-bank data. The two banked/Core tests exercise the production arbiter and response routing. Their requesters are testbench-driven; these tests do not replace integrated production Matrix-engine contention.

## Exact commands

```sh
make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r142_fabric_reset_c87_20261031 \
  MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/dma_spad/sim subsystem_banked_reset_regress \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  BANKED_RESET_OUT=/tmp/nmaforge_r142_banked_reset_c87_20261031 \
  BANKED_RESET_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/dma_spad/sim subsystem_banked_contention_regress \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  BANKED_CONTENTION_OUT=/tmp/nmaforge_r142_banked_contention_c87_20261031 \
  BANKED_CONTENTION_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/dma_spad/sim subsystem_banked_core_reset_regress \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  BANKED_CORE_RESET_OUT=/tmp/nmaforge_r142_banked_core_reset_c87_20261031 \
  BANKED_CORE_RESET_SEEDS='20261025 20261026 20261027'
```

Compile log, all 12 per-seed logs, and URG dashboard/groups/assertion reports are hashed in `/tmp/nmaforge_r142_fabric_SHA256SUMS` (28 evidence files; manifest SHA-256 `9061af1457cd553fcd8c46581c7d72d115adc2d1d8cf58218c48a629fa4e5654`). VCS/URG output and coverage databases remain outside Git.

## Scope disposition

This confirms the user's selected **in-repository `ai_accel_memory_fabric`** reset/epoch target at the R142 RTL/DV source content. It does not qualify an arbitrary external AXI fabric, the production Matrix engine on the banked request port, or the full seven-engine requester × fault × backpressure × reset matrix. The selected-fabric reset issue remains closed for this named target; `REQ-CL-018` and `REQ-PC-007` remain `PARTIAL`, as the integrated production-engine cases remain incomplete. The 38-row disposition stays 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
