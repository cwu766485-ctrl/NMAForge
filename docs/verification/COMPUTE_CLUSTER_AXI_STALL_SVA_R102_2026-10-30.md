# Current-Candidate AXI Stall SVA Closure Gate — R102

**Date:** 2026-10-30  
**Exact code/test commit:** `d0b94ec74865f1f68af14de12113a8c19caf5204`  
**Run ID:** `MIXED-AXI-STALL-SVA-R102-20261015`  
**Disposition:** named behavioral AXI stall/reset E2E and all three stall-to-accept SVA cover gates PASS; Compute Cluster v1.0 remains HOLD.

## Change

The existing `uvm_mixed_precision_ddr_e2e_axi_stalls` Make target already required AR/AW backpressure markers and zero UVM warning/error/fatal counts, but it did not require the corresponding SVA `stall_then_accept` covers to match. R102 adds a nonzero-match gate for AR, AW and W covers. A test can no longer pass this target based only on stimulus markers while one of these three SVA cover properties stays vacuous.

## Exact replay

Command:

```sh
cd dv/uvm/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
  make uvm_mixed_precision_ddr_e2e_axi_stalls
```

The target exited 0 on exact code/test commit `d0b94ec74865f1f68af14de12113a8c19caf5204`. Tool: Synopsys VCS `V-2023.12-SP1_Full64`. The temporary VCS compatibility path maps the installed `linux64` files for this WSL2 host and does not modify the installed tool tree.

| Checker/testpoint | VCS result |
|---|---:|
| AR stall then accept | 3,287 attempts; 14 matches |
| AW stall then accept | 3,287 attempts; 5 matches |
| W stall then accept | 3,287 attempts; 12 matches |
| ARREADY backpressure | observed gaps 1–3 cycles; configured gap 2 |
| AWREADY backpressure | observed gaps 1–2 cycles; configured gap 3 |
| UVM warning/error/fatal | 0/0/0 |

The E2E also passes FP16, BF16 and INT8 DDR Golden checks, two two-beat DMA SLVERR bursts, reset-interrupted AR and AW/W without an old B response, accelerator-only reset with DDR service alive, DMA reset, post-reset recovery, watchdog completion, and software Abort. The mixed E2E raw per-run functional coverage marker is 54.3%; this is one seeded workload result, not complete requirement coverage.

Generated evidence is outside Git: `/tmp/nmaforge_r102_axi_sva_20261030/run.log` (SHA-256 `a744836e4140701a88399031c0e4f8a843573f7f8db36df2d34a0d06b2d0a955`) and `compile.log` (SHA-256 `4e456cce05894ce4d42085ce18e65beb01a254ae3fb0aec1eaf7c614c77735c8`). The test uses the checked-in behavioral DDR responder; this is not qualification of an arbitrary external fabric or physical DDR.

## Sign-off impact

R102 strengthens current-candidate SVA non-vacuity enforcement for this named AXI stall/reset workload. It does not close broad compute requester × fault/backpressure crosses or change any RTM disposition. The overall requirement table remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN**, and `CL-DV-v1.0` remains **HOLD**.
