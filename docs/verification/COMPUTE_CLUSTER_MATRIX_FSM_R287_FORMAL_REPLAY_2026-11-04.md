# Matrix FSM Formal Replay — R287

## Result

| Field | Value |
|---|---|
| Test ID | `TC-CL-R287-MATRIX-FSM-FORMAL-REPLAY` |
| Run ID | `R287-MATRIX-FSM-FORMAL-20261104` |
| Fixed test SHA | `01a4114118cc0664c52602c6bed6a1e33b76681c` |
| Git tree | `1f4e183723b359b3e3b1eb556619929849df8ea6` |
| Tool | Synopsys VC Formal `V-2023.12-SP2` |

The current fixed test tree was checked against the production Matrix core and the existing SVA harness. VC Formal completed with a clean setup, proving all five assertions non-vacuously and reaching both configured covers. No RTL or SVA was modified for this replay.

| Formal result | Observed |
|---|---:|
| Assertions proven | 5/5 |
| Assertions non-vacuous | 5/5 |
| Reachability covers | 2/2 |
| `cp_prefetch_wait_reachable` | covered at depth 11 |
| `cp_error_drain_reachable` | covered at depth 3 |
| Setup issues / property failures | 0 / 0 |

The reviewed source identities are Matrix core SHA-256 `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad`, SVA harness SHA-256 `78c292a3f7471b195335cfe61f8a1abd6070c4ae91f6ff80351e4d2a6d06e1db`, and formal Tcl SHA-256 `fda7921a3932e21c752831b25c03ca12ed2f97cb1c262664d3e6a017f5ab60e6`. The Matrix core and harness hashes match R281/R249; R286 changes only the Cluster UVM sequence and Makefile.

## Transition accounting

The enabled-prefetch Matrix FSM remains **49/53 raw transitions**. That raw count is not presented as 100%. The four remaining transitions retain these dispositions from the existing focused simulation/formal evidence:

| Raw transition miss | Disposition |
|---|---|
| `ST_PREFETCH_WAIT → ST_A_REQ` | The enabled-prefetch path is blocked by the non-vacuously proven `ap_prefetch_wait_does_not_fall_back_to_a_req`; the legal fallback is exercised with prefetch disabled. |
| `ST_IDLE → ST_ERROR_DRAIN` | Excluded by the legal-state/no-outstanding-read invariant and non-vacuously proven edge guard. |
| `ST_ERROR → ST_ERROR_DRAIN` | Excluded by the legal-state/no-outstanding-read invariant and non-vacuously proven edge guard. |
| `ST_MAC → ST_A_REQ` | Legal only in the separately compiled prefetch-disabled profile; its three-seed simulation evidence is recorded in R281. |

R287 reruns the formal guards/covers only; it does not recompute the 49/53 URG counter or rerun the Matrix functional/fallback suites. R281's three-seed functional and fallback regression remains the evidence for those simulation points on an unchanged Matrix core and harness.

## Reproduction and archive

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r287_matrix_formal \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

The run took 130.02 seconds. Non-fatal tool messages were `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND`; the setup gate found no setup issue, the VCS KDB step reported zero errors and warnings, and the Make target passed. The archived formal log is `/tmp/nmaforge_r287_matrix_formal_evidence_20261104.tar.gz`, SHA-256 `5e89ee962f50577130f7e9ddd341503c5467ac0c401a5417b33afe4d35d74fa8`.

## Sign-off effect

This replay resolves the stale documentation statement that the reviewed invalid-state paths lacked formal disposition. It does not close `REQ-CL-010`: descriptor/parameter integration and broader legal request/response × fault × phase × reset/backpressure coverage remain open. No Requirement disposition changes; `REQ-CL-010` remains `PARTIAL`, the RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
