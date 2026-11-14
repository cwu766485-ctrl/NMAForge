# BPF-TE Fault Precision Report

Round 5 Gate B evidence:

| Fault/phase | Evidence | Result |
|---|---|---|
| Read parity fault | Configurable `inject_parity_error_cfg=4'b0001`; real CNM read | `BPF_TE_CNM_PARITY_FAULT_PASS`, error code 6 |
| Atomic one-bank denial | Existing all-or-none Atomic regression, `bank_allow=0111` | zero bank writes, PASS |
| Epoch with outstanding read | H1 real CNM request plus `epoch_bump` | `BPF_TE_EPOCH_ABORT_PASS`, code 3 |
| Abort after accepted read | Engine abort path | PASS in epoch scenario |
| Matrix Line commit | Four nonzero Line commits, WSTRB `ffff` | PASS, memory image observed |
| Response owner/tag | Atomic and arbiter SVA | non-vacuous PASS |
| No stale response | Epoch tag comparison and flush | old response dropped; engine aborts |
| Write protection | Configurable CNM write protection input; output commit denied | `BPF_TE_CNM_WRITE_PROTECTION_PASS`, error code 6 |
| Reset with outstanding transaction | Existing Round 3 adapter regression | PASS at primitive scope; real-engine replay pending |

The research top no longer hard-codes bank availability or parity injection;
the inputs are `bank_allow_cfg`, `inject_parity_error_cfg`,
`cnm_write_protection_error_cfg`, and `matrix_line_protection_error_cfg`.
The independent checks use output memory probes and transaction-level outputs,
not internal accumulator state. SVA reports 2/2 assertions and 2/2 cover
properties with real attempts in the real-engine test.

Remaining bounded gap: a separate directed write-protection/abort-prefix test
is still required for full P0 closure. This is recorded as open rather than
waived.
