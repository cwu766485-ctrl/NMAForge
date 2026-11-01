# Matrix FSM Formal Replay on the R164 Candidate — R165

## Identity

- Run ID: `R165-MATRIX-FSM-FORMAL-CLEAN-R164-20261102`
- Executed clean candidate: `5a1bc0753df677c906c8f8036540a4c3edd54e58`
- Candidate tree: `32d7bee7f278e4477ed633763188680b2bd59235`
- Underlying UVM/test source: R164 `db7588be34200ac68ac66072799adca54ad287a5`
- Matrix RTL SHA-256: `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad`
- Formal harness SHA-256: `78c292a3f7471b195335cfe61f8a1abd6070c4ae91f6ff80351e4d2a6d06e1db`
- Tool: Synopsys VC Formal `V-2023.12-SP2`
- Disposition: PASS for the named assertions and covers; Matrix raw enabled-profile FSM coverage remains 49/53 by the separate R154 VCS/URG replay.

R165 reruns the existing production `ai_tensor_matrix_core` harness without changing RTL, assumptions, assertions, or formal configuration. The checked-out R164 candidate worktree was clean. No internal state forcing or illegal response injection was used.

## Reproduction

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r164_matrix_fsm_formal_clean_5a1bc07 \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

The command exited 0. Formal setup reports `No setup issues found`. All five assertions are proven and non-vacuous; both reachability covers hit:

| Property | Result | Depth |
|---|---|---:|
| `ap_prefetch_wait_does_not_fall_back_to_a_req` | Proven, non-vacuous | 23 |
| `ap_idle_has_no_outstanding_reads` | Proven, non-vacuous | 117 |
| `ap_error_has_no_outstanding_reads` | Proven, non-vacuous | 118 |
| `ap_idle_does_not_enter_error_drain` | Proven, non-vacuous | 119 |
| `ap_error_does_not_reenter_error_drain` | Proven, non-vacuous | 119 |
| `cp_prefetch_wait_reachable` | Covered | 11 |
| `cp_error_drain_reachable` | Covered | 5 |

VC Formal emitted non-fatal `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND` diagnostics. The proof log has no setup error, assertion failure, counterexample, or `TFIPC` diagnostic. Wall time was 114.62 seconds.

## Transition disposition

The separate exact Matrix simulation replay R154 remains the source of the 49/53 enabled-profile raw transition count. Its four residual transitions retain these scoped dispositions:

| Transition | Disposition |
|---|---|
| `ST_PREFETCH_WAIT→ST_A_REQ` | Guard-incompatible for `ENABLE_NEXT_K_PREFETCH=1`; the non-vacuous prefetch-wait guard is re-proven at R165. The legal edge is exercised in the separate prefetch-disabled profile. |
| `ST_IDLE→ST_ERROR_DRAIN` | Guard-incompatible in the legal model: idle has no accepted outstanding read and drain entry requires `busy`; the idle invariant is re-proven at R165. |
| `ST_ERROR→ST_ERROR_DRAIN` | Guard-incompatible: error does not re-enter drain; the non-vacuous guard is re-proven at R165. |
| `ST_MAC→ST_A_REQ` | Prefetch-profile-specific legal fallback; covered by the separate three-seed prefetch-disabled run, not expected in the enabled-profile database. |

This is an evidence replay, not 100% raw FSM coverage. It does not prove the full Matrix parameter/fault/reset space and does not close `REQ-CL-010`.

Evidence log: `/tmp/nmaforge_r164_matrix_fsm_formal_clean_5a1bc07/vc_formal.log`  
SHA-256: `cb7f6225dbddcc311cadac46b5d21894c7e2d169bc97ff8b7cb1154518849902`

The full disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `REQ-CL-010` remains `PARTIAL`, `REQ-CL-022` remains `PASS-SCOPED*`, and `CL-DV-v1.0` remains **HOLD**.
