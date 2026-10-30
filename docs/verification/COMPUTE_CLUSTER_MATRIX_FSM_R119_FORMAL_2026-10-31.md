# Matrix FSM formal replay — R119

**Run ID:** `CL-MATRIX-FSM-FPV-R119-480EB-SOURCES`
**Published RTL/SPEC and formal-source identity:** unchanged from code/test SHA `4797a7710a18670d820f8f3815959091f9636e75`; this replay ran from documentation-only descendant `394b305` of published closeout snapshot `480eb443b835f8cbe771682e91ff6d97acae0a99`.
**Tool:** Synopsys VC Formal `V-2023.12-SP2`; FPV license checked out.
**Result:** PASS; five non-vacuous properties proven and both reachability covers hit.
**Disposition:** Raw prefetch-enabled Matrix FSM coverage remains 49/53 transitions. No illegal stimulus was added and no requirement status changed.

## Command and evidence

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r118_matrix_fsm_934dcfb \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

The target exited `0`. VC Formal reports `No setup issues found`, 5/5 assertions proven and non-vacuous, and 2/2 covers reached. The full log is `/tmp/nmaforge_r118_matrix_fsm_934dcfb/vc_formal.log`, SHA-256 `6c2fbca535c7254fcc879740a6be908c14d02fa3a229f06bfd513384c555e966`; formal artifacts remain outside Git.

## Property results

| Property | Result | Disposition |
|---|---|---|
| `ap_prefetch_wait_does_not_fall_back_to_a_req` | Proven, non-vacuous | With prefetch enabled, `ST_PREFETCH_WAIT` does not fall back to `ST_A_REQ`. |
| `ap_idle_has_no_outstanding_reads` | Proven, non-vacuous | Idle state has no accepted banked reads outstanding. |
| `ap_error_has_no_outstanding_reads` | Proven, non-vacuous | Error state has no accepted banked reads outstanding. |
| `ap_idle_does_not_enter_error_drain` | Proven, non-vacuous | The guard-incompatible `ST_IDLE→ST_ERROR_DRAIN` transition is excluded. |
| `ap_error_does_not_reenter_error_drain` | Proven, non-vacuous | The guard-incompatible `ST_ERROR→ST_ERROR_DRAIN` transition is excluded. |
| `cp_prefetch_wait_reachable` | Covered at depth 11 | Confirms the prefetch guard source state is reachable. |
| `cp_error_drain_reachable` | Covered at depth 5 | Confirms the error-drain state is reachable. |

The formal top uses the production 16×16 Matrix core, prefetch and A-tile cache enabled, a legal 4×4×3 descriptor, and an assumption that each banked response has a previously accepted request owner. Start, Abort, and fault timing are otherwise unconstrained. The third guard-incompatible transition is `ST_PREFETCH_WAIT→ST_A_REQ` and is covered by its dedicated assertion. `ST_MAC→ST_A_REQ` is a legal profile-specific transition and is exercised by the separately compiled prefetch-disabled simulation profile (R58). Preserve the raw enabled-profile result at 49/53; the proof is a disposition of the named guards, not 100% FSM coverage across configurations or integrated fault/reset combinations.

## Tool diagnostics

The log retains `COM_OPT009` (no `search_path`), `COM_OPT010` (no `link_library`), `CLOCK_W_UNIT_ADJUST`, `LEARNED_DATA_NOT_FOUND`, and `HOST_OVERLOADED`. VC Formal checked out the FPV license, reported a clean setup, completed all properties/covers, and returned success with no counterexample or formal error. The loaded-host warning increased run time; it did not change the result.

No RTM requirement disposition changes: status remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains **HOLD**.
