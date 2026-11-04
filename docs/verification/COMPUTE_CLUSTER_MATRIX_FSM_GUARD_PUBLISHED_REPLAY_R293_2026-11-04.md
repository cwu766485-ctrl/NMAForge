# Matrix FSM guard proof on published candidate — R293

## Identity and result

| Item | Evidence |
|---|---|
| Test ID | `TC-CL-R293-MATRIX-FSM-GUARD-PUBLISHED` |
| Run ID | `R293-MATRIX-FSM-GUARD-PUBLISHED-20261104` |
| Exact source/test SHA | `e1fcde57c70936f2eb2cd8ed9aea14303a61c717` |
| Tree | `b353adf9035d5a45a1575cdbde827773051b5c1e` |
| Tool | Synopsys VC Formal `V-2023.12-SP2` |
| Result | PASS: 5/5 assertions proven and non-vacuous; 2/2 covers reached |
| Evidence archive | `/tmp/nmaforge_r293_matrix_fsm_published_logs.tar.gz`, SHA-256 `3975b8382520174c3f785b01841ef55af397a1c7c3c5afa022dadbe319a25274` |

The run was made in a detached clean worktree at the exact published test SHA. No RTL or SVA changed.

## Reproduction

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r293_matrix_fsm_published \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

Formal proved all five assertions non-vacuously: `ap_idle_has_no_outstanding_reads`, `ap_idle_does_not_enter_error_drain`, `ap_error_has_no_outstanding_reads`, `ap_error_does_not_reenter_error_drain`, and `ap_prefetch_wait_does_not_fall_back_to_a_req`. Both configured reachability covers hit: `cp_error_drain_reachable` at depth 5 and `cp_prefetch_wait_reachable` at depth 11. Setup reported no issues. The log contains non-fatal `COM_OPT009/010` (this harness has no library cells), `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND` notices. The Make proof gate passed.

## Remaining transition disposition

The enabled-prefetch profile's prior raw URG count remains 49/53; this formal replay did not recompute the counter. The four misses retain the following evidence-based disposition:

| Transition | Disposition |
|---|---|
| `ST_PREFETCH_WAIT → ST_A_REQ` | Guarded out in the enabled-prefetch profile by the non-vacuously proven prefetch-wait property; the fallback is covered in the separate prefetch-disabled simulation profile. |
| `ST_IDLE → ST_ERROR_DRAIN` | Excluded under the legal-state/no-outstanding-read invariant, supported by non-vacuous formal guard proof. |
| `ST_ERROR → ST_ERROR_DRAIN` | Excluded under the legal-state/no-outstanding-read invariant, supported by non-vacuous formal guard proof. |
| `ST_MAC → ST_A_REQ` | Belongs to the separately compiled prefetch-disabled profile; its functional regression is recorded in R281. |

No illegal FSM state was injected to raise the counter. `REQ-CL-010` remains `PARTIAL` because Matrix descriptor integration and broader legal request/response × fault × phase × reset/backpressure evidence remain open. No requirement status changes; `CL-DV-v1.0` remains **HOLD**.
