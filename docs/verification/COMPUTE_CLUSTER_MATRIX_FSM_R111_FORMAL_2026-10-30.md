# Matrix FSM formal replay at R110 SHA (R111)

**Run ID:** `R111 MATRIX-FSM-FPV-CLEAN-R110-20261030`
**Exact clean code/test SHA:** `95864f7027ccbec22a09b0a61832c68d3ca08098`
**RTL/SPEC identity:** product RTL and SPEC v1.8 are unchanged from R99 base `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; this candidate adds the R110 testbench-only banked-owner probe.
**Tool:** Synopsys VC Formal `V-2023.12-SP2`, FPV license checked out.
**Result:** PASS, scoped formal disposition; no Matrix transition bins were forced.

## Reproduction

From a detached clean worktree at the exact SHA above:

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r110_matrix_fsm_clean_95864f7 \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

The Make gate exited successfully after checking the formal log for five proven
assertions, two covered reachability properties, a clean setup, and no formal
errors. `vc_formal.log`: `/tmp/nmaforge_r110_matrix_fsm_clean_95864f7/vc_formal.log`,
SHA-256 `20c1476c507bf550c1d624db4419b49afc589dc4630bfc2a5ade8251c4b1a8c8`.
The log reports `No setup issues found` and total runtime 47.44 seconds.

## Assertion and cover results

| Property | Result | Meaning in this model |
|---|---|---|
| `ap_prefetch_wait_does_not_fall_back_to_a_req` | Non-vacuous, proven | With prefetch enabled, `ST_PREFETCH_WAIT` does not transition to `ST_A_REQ`. |
| `ap_idle_has_no_outstanding_reads` | Non-vacuous, proven | `ST_IDLE` has zero outstanding banked reads. |
| `ap_error_has_no_outstanding_reads` | Non-vacuous, proven | `ST_ERROR` has zero outstanding banked reads. |
| `ap_idle_does_not_enter_error_drain` | Non-vacuous, proven | `ST_IDLE` does not transition to `ST_ERROR_DRAIN`. |
| `ap_error_does_not_reenter_error_drain` | Non-vacuous, proven | `ST_ERROR` does not transition back to `ST_ERROR_DRAIN`. |
| `cp_prefetch_wait_reachable` | Covered at depth 11 | Confirms the source state of the prefetch guard is reachable. |
| `cp_error_drain_reachable` | Covered at depth 5 | Confirms the error-drain state is reachable. |

The model uses the production 16×16 Matrix core with prefetch and A-tile cache
enabled, a legal 4×4×3 descriptor, and an assumption that a banked response
has a previously accepted request owner. Reset sequencing is constrained as
documented in `ai_matrix_fsm_formal_top.sv`. Start, Abort, and fault timing are
otherwise unconstrained. These results disposition the three guard-incompatible
edges in the default prefetch-enabled profile; they do not prove all possible
shape/configuration combinations or every integrated fault/Abort/Reset cross.
The legal `ST_MAC→ST_A_REQ` edge remains covered by the separate prefetch-off
simulation profile. Preserve the raw enabled-profile result of 49/53 FSM
transitions; do not report 100% FSM coverage.

The log also contains generic `COM_OPT009`/`COM_OPT010` option warnings,
`CLOCK_W_UNIT_ADJUST`, and `LEARN_CANNOT_SAVE_DATA` warnings from the learned-data
cache on shared storage. The formal setup gate passes, all assertions are proven,
both covers are reached, and no formal error or counterexample is reported.
These messages are retained as tool diagnostics rather than hidden or treated as
design failures.

This evidence changes no requirement disposition: the RTM remains 24
PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD.
