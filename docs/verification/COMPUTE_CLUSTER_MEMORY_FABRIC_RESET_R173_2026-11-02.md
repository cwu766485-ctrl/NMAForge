# Selected `ai_accel_memory_fabric` reset replay — R173

**Run ID:** `CL-MEM-FABRIC-RESET-R173-3S`

**Fixed source/test SHA:** `8a2d5f85add54f81019df1a8d6a29ad08bbe88d6`

**Source tree:** `9701bcaa7417c0cb7babdeab4996d6714cbbf04f`

**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`

**Disposition:** PASS for the selected in-repository `ai_accel_memory_fabric` reset/epoch scope. The 38-requirement Compute Cluster disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Scope

The user selected `rtl/top/fabric/memory/ai_accel_memory_fabric.v` as the fabric boundary for this reset review. The test instantiates that production fabric through the DMA/SPAD subsystem and checks its registered SPAD response owner and reset epoch. The external AXI responder is behavioral; this result does not qualify an arbitrary SoC DDR/AXI fabric.

Each seed exercises two legal shared-reset cut points while four DMA reads are accepted and outstanding:

1. CNM has an accepted SPAD read whose registered response has not returned.
2. CNM has consumed its operands and is waiting to commit its result.

At each cut point, the sequence checks reset acknowledgment, idle/drained DMA and CNM state, absence of stale response ownership, then runs fresh DMA and CNM work. The DMA scoreboard checks 32 transferred words; CNM checks all four lanes' reads/responses, one output write, and readback against the independent result. A separate Protection regression on the same clean code snapshot covers denied CNM sources/destination and recovery (recorded in R99).

## Reproduction and result

From `dv/subsystem/dma_spad/sim`:

```sh
make subsystem_memory_fabric_reset_regress \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r173_fabric_reset_8a2d5f \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Seeds `20261025`, `20261026`, and `20261027` all pass. Every log contains the pending-SPAD-response setup and `MEMORY_FABRIC_RESET_ONLY_PASS`; UVM warning/error/fatal counts are `0/0/0`. The VCS compile log contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

| Checker / coverage group | Result |
|---|---:|
| `dma_cnm_shared_reset_cg` | 100% |
| `cnm_reset_phase_cg` | 100% |
| `dma_reset_phase_cg` | 100% |
| `ap_single_response_owner` | 3,921 real successes, 0 failures, 0 incomplete |
| `ap_cnm_response_tag` | 144 real successes, 0 failures, 0 incomplete |

The complete logs and VDB/URG results are archived at `/tmp/nmaforge_r173_fabric_reset_8a2d5f.tar.gz` (SHA-256 `7413dab5db5095ed71b263756cb3ea16c0151b31119dd2512a4aad61c8b60b2f`). The archive contains `RUN_MANIFEST.md` and `LOG_SHA256SUMS`.

## Requirement disposition

This replay reconfirms closure of `OPEN-CL-003` for the user-selected repository `ai_accel_memory_fabric` boundary. It adds reset-epoch evidence to `REQ-CL-018`, `REQ-PC-006`, and `REQ-PC-007`; those requirements stay `PARTIAL` because legal engine × fault × phase × reset, production requester-pair, and broader memory/backpressure crossings are not complete. `REQ-PC-010` also remains `PARTIAL`: R173 does not turn the behavioral external AXI responder into platform-fabric evidence. No full Cluster or whole-NPU sign-off is claimed.

| Requirement | Status | Test ID / checker | Coverage and observed result | Run ID / seeds | Evidence path |
|---|---|---|---|---|---|
| `REQ-CL-018` | `PARTIAL` | `TC-PC-R173-FABRIC-RESET`; reset-epoch phase groups, stale-owner/quiet checks, recovery checks | `dma_cnm_shared_reset_cg`, `cnm_reset_phase_cg`, and `dma_reset_phase_cg` are each 100%; pending accepted CNM response is flushed and both reset phases recover | `CL-MEM-FABRIC-RESET-R173-3S`; `20261025/26/27` | `/tmp/nmaforge_r173_fabric_reset_8a2d5f/seed_*/run.log`; `/tmp/nmaforge_r173_fabric_reset_8a2d5f/urg/groups.html` |
| `REQ-PC-006` | `PARTIAL` | Same test; DMA scoreboard and CNM lane accepted/response counters | 32 DMA words match; every CNM lane has matching accepted/returned counts; broad requester × fault × backpressure coverage remains open | Same run and seeds | Same per-seed logs and reset URG report |
| `REQ-PC-007` | `PARTIAL` | Same test; `ap_single_response_owner`, `ap_cnm_response_tag`, owner/data Golden checkers | 3,921/144 assertion successes, zero failure/incomplete; this is fabric-boundary DMA/CNM evidence, not full production-engine pair coverage | Same run and seeds | `/tmp/nmaforge_r173_fabric_reset_8a2d5f/urg/asserts.html`; per-seed logs |
| `REQ-PC-010` | `PARTIAL` | Same test; DMA/CNM reset acknowledgment, owner-epoch and recovery checkers | Selected repository SPAD fabric reset passes; external AXI R/B model is behavioral, so platform-fabric qualification remains outside evidence | Same run and seeds | Same per-seed logs and archive |
