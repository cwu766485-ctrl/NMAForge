# Matrix FSM Formal Replay at the Published Closeout Tree — R136

**Replay metadata**

- Run ID: `R136-MATRIX-FSM-FORMAL-CLEAN-486A-20261031`
- Published source: GitHub commit `486a348c021fe629ebc8198fd555a02a836643e3`
- Executed clean checkout: local commit `d5a3c9058ddc8215d9903f8506c1bf2668315fc7`
- Tree: `a2e3aafe29262b9237c97d7f4d90e4a9f22e118b`
- Tool: Synopsys VC Formal `V-2023.12-SP2`; Base and FPV runtime licenses checked out.

The run uses the existing production `ai_tensor_matrix_core` formal harness and leaves RTL, harness, assumptions, and configuration unchanged.

## Reproduction

```sh
make -C /tmp/nmaforge_r135_clean_486a/dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r135_matrix_fsm_486a_20261031 \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

**Result:** PASS; command exit status 0. Setup reports no issues. Five assertions are proven and each is non-vacuous. Both reachability covers hit. Formal runtime is 114.40 seconds.

| Property | Result | Safe/cover depth |
|---|---|---:|
| `ap_prefetch_wait_does_not_fall_back_to_a_req` | Non-vacuous, proven | 22 |
| `ap_idle_has_no_outstanding_reads` | Non-vacuous, proven | 122 |
| `ap_error_has_no_outstanding_reads` | Non-vacuous, proven | 121 |
| `ap_idle_does_not_enter_error_drain` | Non-vacuous, proven | 122 |
| `ap_error_does_not_reenter_error_drain` | Non-vacuous, proven | 123 |
| `cp_prefetch_wait_reachable` | Covered | 11 |
| `cp_error_drain_reachable` | Covered | 3 |

The harness retains the documented legal descriptor and accepted-response owner assumptions. No FSM state is forced. The existing enabled-prefetch raw transition result remains **49/53**. The four raw misses are not converted into artificial hits: the three default-profile guard/invariant cases retain their formal disposition, while legal `ST_MAC→ST_A_REQ` remains covered in the separate prefetch-disabled Matrix simulation (R58). These proofs do not establish every configuration or every integrated fault/Abort/Reset cross and do not promote `REQ-CL-010/022` to fully closed.

VC Formal emitted non-fatal `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND` diagnostics. There was no setup issue, formal error, or counterexample.

**Evidence:** `/tmp/nmaforge_r135_matrix_fsm_486a_20261031/vc_formal.log`

**SHA-256:** `c107d0e13774b340e9ebc8e4c9718eaa752eaf7ed6249dc28fd225d919022df0`

No RTM disposition changes: 24 PASS-SCOPED / 14 PARTIAL; `REQ-CL-010` remains PARTIAL and `REQ-CL-022` remains PASS-SCOPED* with its existing qualification; `CL-DV-v1.0` remains **HOLD**.
