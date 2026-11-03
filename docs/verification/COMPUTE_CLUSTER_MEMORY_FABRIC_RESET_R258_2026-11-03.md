# Selected `ai_accel_memory_fabric` reset replay — R258

**Run ID:** `CL-MEM-FABRIC-RESET-R258-3S`

**Fixed source/test SHA:** `795142a3c3acf90e238371661b9a0f8e2ffa5ccb`

**Source tree:** `23e9c70d2f0689a464be61e51f790cf6e72f0843`

**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`

**Disposition:** PASS for the user-selected, in-repository `ai_accel_memory_fabric` reset/epoch scope. The 38-requirement Compute Cluster disposition remains 25 `PASS-SCOPED` / 13 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Scope

This clean-checkout replay instantiates production `rtl/top/fabric/memory/ai_accel_memory_fabric.v`. Each of seeds `20261025`, `20261026`, and `20261027` exercises two reset cut points with four DMA reads outstanding:

1. CNM has an accepted SPAD read whose registered response is pending.
2. CNM has consumed its operands and is waiting to write its result.

After each shared reset, the test checks owner/epoch flush and runs fresh DMA and CNM work. Each seed observes two reset setups, two `DMA_CNM_RESET_RECOVERY_PASS` events, one overall `MEMORY_FABRIC_RESET_ONLY_PASS` marker, three successful DMA scoreboard comparisons of 32 words each, and no UVM warning/error/fatal. URG reports all three declared reset covergroups at 100%. The response-owner assertions report 3,921 and 144 real successes respectively, with zero failure/incomplete.

This verifies the repository fabric boundary and its DMA/CNM reset behavior. The external AXI responder is behavioral; this is not an arbitrary SoC AXI/DDR fabric qualification or broad seven-engine fault/reset/backpressure closure.

## Reproduction

From `dv/subsystem/dma_spad/sim`:

```sh
make subsystem_memory_fabric_reset_regress \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r258_fabric_reset_clean_795142a \
  MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027' \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Result: `MEMORY_FABRIC_RESET_REGRESS_PASS`; the compiled test ran on the clean source/test SHA above. The compile log contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Each seed log contains both pending-response and result-write reset cut points, the two reset/recovery pass markers, and severity counts `0/0/0`.

| Checker / coverage group | Result |
|---|---:|
| `dma_cnm_shared_reset_cg` | 100% |
| `cnm_reset_phase_cg` | 100% |
| `dma_reset_phase_cg` | 100% |
| `ap_single_response_owner` | 3,921 real successes; 0 failures/incomplete |
| `ap_cnm_response_tag` | 144 real successes; 0 failures/incomplete |
| DMA scoreboard checks | 3 × 32 words/seed; all matched |
| UVM severity, each seed | 0 / 0 / 0 |

Evidence archive: `/tmp/nmaforge_r258_fabric_reset_evidence_20261103.tar.gz`, SHA-256 `e99de7d2806140f842592b569f0f53eae25cede8bdde2f17745e29b1001d80a8`. Per-seed log hashes and archived URG reports are in `LOG_SHA256SUMS` and `RUN_MANIFEST.md` inside the archive.

## Requirement traceability

| Requirement | Disposition | Test / checker | Result and remaining scope | Run / evidence |
|---|---|---|---|---|
| `REQ-CL-018` | `PARTIAL` | `TC-PC-R258-FABRIC-RESET`; reset epoch groups, owner flush and recovery | Both selected fabric reset phases recover; engine × fault × phase × reset combinations remain open. | `CL-MEM-FABRIC-RESET-R258-3S`, seeds `20261025/26/27`; per-seed logs and `urg/groups.html` in the archive |
| `REQ-PC-006` | `PARTIAL` | DMA scoreboard, CNM lane response accounting, post-reset Golden checks | Selected DMA/CNM reset recovery passes; requester × fault × backpressure coverage remains open. | Same run; per-seed logs and `urg/groups.html` |
| `REQ-PC-007` | `PARTIAL` | `ap_single_response_owner`, `ap_cnm_response_tag`, owner/epoch checkers | Non-vacuous fabric-boundary owner evidence passes; full seven-engine contention/fault/reset coverage remains open. | Same run; `urg/asserts.html` and per-seed logs |
| `REQ-PC-010` | `PARTIAL` | Shared-reset acknowledgment, owner epoch and recovery checkers | Repository SPAD fabric passes; external AXI responder remains behavioral. | Same run; per-seed logs and `compile.log` |

No requirement is promoted by this replay. `CL-DV-v1.0` remains HOLD until the other open P0 requirements are closed or formally dispositioned and the full fixed-SHA exit review passes.
