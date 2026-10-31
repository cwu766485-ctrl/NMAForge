# Compute Cluster Memory Fabric Clean Replay — R125

**Date:** 2026-10-31  
**Selected target:** repository `ai_accel_memory_fabric`, production `ai_spad_arbiter`, and registered four-bank SPAD  
**Clean replay checkout:** `5ea67bd125bb1ed20af8b86369e2cf8112f25131`, tree `f51fb9d694c8ae2c825d5ae2a9d39ae867776c8f`  
**Functional RTL/DV/SPEC content:** identical to R124 tested content `752c9e0327c18b8775f3bfac62f4cf5483dc38d7` (published same-content source commit `863771c1062ff8390dc82c705594c5cef3289e3c`, tree `9232a92b09f4fed7573ecdc50c786f5680b8281e`). The replay checkout adds R124 documentation only; `git diff --quiet 752c9e0 -- rtl dv docs/spec` passed.  
**Tools:** VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Results

The selected in-repository fabric reset test and three banked owner/reset tests were rerun on the clean R124 source content. All four regressions pass for seeds `20261025`, `20261026`, and `20261027`; each run reports UVM warning/error/fatal `0/0/0`.

| Run ID | Target and command | Result |
|---|---|---|
| `CL-MEM-FABRIC-RESET-R125-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r125b_fabric_reset_5ea67bd MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Pending DMA/CNM SPAD responses are flushed; both CNM reset phases and fresh DMA/CNM recovery pass. All 3 declared reset covergroups are 100%. |
| `CL-BANKED-RESET-R125-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_banked_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_RESET_OUT=/tmp/nmaforge_r125_banked_reset_5ea67bd BANKED_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Accepted banked response is flushed; four-cycle reset-release quiet window and tagged four-bank recovery pass. Focused coverage 100%; `ap_banked_response_tag`: 450 attempts, 3 real successes, 0 failures/incomplete. |
| `CL-BANKED-CONTENTION-R125-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_banked_contention_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CONTENTION_OUT=/tmp/nmaforge_r125_banked_contention_5ea67bd BANKED_CONTENTION_SEEDS='20261025 20261026 20261027'` | PASS. Simultaneous Core/Banked requests exercise production arbitration, response-owner isolation, and initialized-memory Golden data. Focused coverage 100%; banked response-tag SVA: 429 attempts, 3 real successes, 0 failures/incomplete. |
| `CL-BANKED-CORE-RESET-R125-3S` | `make -C dv/subsystem/dma_spad/sim subsystem_banked_core_reset_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg BANKED_CORE_RESET_OUT=/tmp/nmaforge_r125_banked_core_reset_5ea67bd BANKED_CORE_RESET_SEEDS='20261025 20261026 20261027'` | PASS. Core response ownership is checked while a Banked response is pending; reset flush, quiet window, and dual-owner Golden recovery pass. Focused coverage 100%; Core tag `471/3`, Banked tag `471/3`, single-owner `471/441` attempts/successes, all with 0 failures/incomplete. |

The first invocation used Make's default `URG=urg`: VCS simulation passed all three seeds, but the command stopped at report generation because `urg` was not on `PATH`. The tool exists at `$VCS_HOME/bin/urg`; the successful commands above set that executable explicitly. This was an environment path issue; no test or checker was changed.

## Artifact hashes

SHA-256 is listed for each compile log, seed `run.log` in order `20261025/20261026/20261027`, and the generated URG `dashboard.html`, `groups.html`, and `asserts.html`.

| Run ID | Compile log | Seed run logs (`25 / 26 / 27`) | URG dashboard / groups / asserts |
|---|---|---|---|
| Fabric reset | `da381d70ad2a52a1271787c996ecc8b626a9c6eddbfcfefcd9dc975faa5fc79d` | `9e423e63b53ba41eddd7ba0526961b29dc5b8e81c129190b81919cdb49f28698` / `68fc40091baf8820ca121afe97b7d1c630260ccd52c582518c65914378d68a7b` / `3891f8d1bbd26b729e9d3edef57d985402dee11cba2b5d81bcc05a146bfa8c08` | `56e1f3dace1549dc33284860ee6c6388ad97538e09696277e0e34faf8a37b8ee` / `bae883e0154ca4590d44f1fdaf8bf21f829118f5abe2c0a039054bbbe57a1fcf` / `a7008899b3b3dca8c844e165c675f4cf7ca9621e2353c11b93987da09f55067c` |
| Banked reset | `185d21e1bf819250721736294ff538b6beda2265d292a1adf44568967c8cc703` | `88a462b90482f343452541e5a95c19e15532d60fdcc7ebd3048af08702f7864a` / `7bc3d27bed9baa7d4d4bc688092c9d2951a88f1f4948adab787092610608d151` / `519725fcc20ced0a69bed03b8b3b1c0e1e4f7977c8b9e264cc360a067ef65221` | `4b210f6b355e29b0a5bbbd7da226e27a0a4e6813b1f1f0eb315b18dead428134` / `aef3f4867ae844bb4aa15985ebf1a6c8f021b1e8ac58e4a1ca1fb651816e1b83` / `0f640e079e194365c8ab1b2f5fed390b7e931b8a383cbb89ad0fb513f9fd50bf` |
| Banked contention | `96e81ec499f99db36f531afa9e1186ca25fa7ae5bf6878761c5066dcec3edb40` | `893ed04ccb2d370b5388ef3cf734ed4851d97fc3c0574dc91c5a81887f3e2ef7` / `24dcf70c9808c0c86ac474490b8d2e78df3628c85c4321fad163844cc7411ce6` / `c8e7fb0de8396c05ba133ce54cd6d8edb8d2ae5f44bfaa7c282a99041e6e104f` | `ce8029dec0265c29c0e6b17158c9bd99c274211fbc3f57aa5deb87ce9c9e0977` / `2755e7703ea2ce4e04f1299d36a3a1aa1e089c667c7178fec9c18f94a46bb061` / `4fb97246c5674eb13822e5b90c163f0090bbeaaf49ea8bd64afe785e6587b0d7` |
| Core/Banked reset | `de13f27375b4fcdf20f3ab9e3bc3504c3042fe5a210553530f7360eccc417ae3` | `ce438cac93dc02ded718787224d86700e0f70eb1f6262b248ae87c87777a8d10` / `5bd9dd176f76513897472a9296306a38fb664252ace871c6b4b8f6fdc2728291` / `fafb8312ff798ebd74d2a2b5c80944010a85ea0aa61bdee7254715b1ecf349b3` | `6efd90619893b11baab8d2366b199d56dbcbb6d7d637cd7f770a765f24393d37` / `e84a2771fb2cdc87019ca1bf909fc7fd5cfaa299c0e152c3cc985b2450393c0c` / `2d641ccbd9b8d7860ca5698f4a207b7e85346d6b4725ebd6db921416dc6354a8` |

Raw VCS/URG artifacts remain outside Git under the four `/tmp/nmaforge_r125*` roots listed in the commands. No PPA or arbitrary external AXI fabric result is claimed.

## Requirement disposition

This replay confirms the selected in-repository `ai_accel_memory_fabric` reset/epoch and banked owner evidence on current R124 functional source content. It does not add new stimulus and does not promote a requirement. `OPEN-CL-003` remains closed for the selected in-repository target. `REQ-CL-018` and `REQ-PC-007` remain **PARTIAL** because production-engine fault/backpressure/reset combinations and the broader legal Engine × Fault × Phase × Reset cross are still open. The 38-row disposition remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.
