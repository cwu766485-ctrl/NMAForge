# Matrix FSM formal replay — R144

**Run ID:** `CL-MATRIX-FSM-FPV-R144-TESTSHA-4008D73`  
**Test source SHA:** `4008d73f800fd470ed2ff8b9c4f7068053d5b041`  
**Checkout tree:** `66336b80edbb6d818a9d5e55c83230a7b1898c88` (documentation-only descendant; RTL and formal sources unchanged)  
**Matrix RTL SHA-256:** `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad`  
**Tool:** Synopsys VC Formal `V-2023.12-SP2`; FPV and runtime licenses checked out.  
**Result:** PASS; 5/5 assertions proven and non-vacuous, 2/2 reachability covers reached.  
**Disposition:** The existing scoped FSM disposition reproduces on the current selected candidate. Raw enabled-profile Matrix FSM coverage remains 49/53; no illegal transition stimulus was added.

## Command and evidence

```sh
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r143_matrix_fsm \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

The target exited `0`, reported `No setup issues found`, and found no formal errors. The full log is `/tmp/nmaforge_r143_matrix_fsm/vc_formal.log`, SHA-256 `d00c49de45309da2194df488a7c6b391b002836054950de85257ebd64d6ad03f`.

| Property | Result |
|---|---|
| `ap_prefetch_wait_does_not_fall_back_to_a_req` | Proven, non-vacuous |
| `ap_idle_has_no_outstanding_reads` | Proven, non-vacuous |
| `ap_error_has_no_outstanding_reads` | Proven, non-vacuous |
| `ap_idle_does_not_enter_error_drain` | Proven, non-vacuous |
| `ap_error_does_not_reenter_error_drain` | Proven, non-vacuous |
| `cp_prefetch_wait_reachable` | Covered at depth 11 |
| `cp_error_drain_reachable` | Covered at depth 5 |

The formal run retains non-fatal `COM_OPT009`/`COM_OPT010` diagnostics for unset `search_path` and `link_library`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND`. Setup completed cleanly; all selected properties and covers completed. This does not convert the mixed cluster URG FSM percentage into 100% and does not prove the full fault/phase/reset cross. `REQ-CL-010` remains PARTIAL.
