# Scalar INT8 Numeric Campaign — R51 (Superseded)

**Disposition:** `SUPERSEDED / EXCLUDED FROM COMPLIANCE EVIDENCE`
**Original test commit:** `5b1d282b97d091e806b035c4a93556f5ac250c37`
**Reason:** The 14-case campaign treated reserved/unassigned activation encoding `3` as a required testpoint. Although the run passed its checks, this is outside the software-legal input contract in SPEC v1.6. It must not be counted as legal functional coverage or requirement closure.

R51 is retained in Git history and in its original run artifacts as an exploratory AS-IS datapath probe. Its PASS marker, case count, and activation bin are superseded and excluded from all active sign-off claims. No product RTL was changed as part of R51.

The compliant replacement is [R52](COMPUTE_CLUSTER_SCALAR_INT8_NUMERIC_R52.md), which removes the reserved-encoding stimulus and coverage bin, then passes three clean-worktree seeds using only assigned activation values `0`, `1`, and `2`. R52 supplies scoped VDOT/GEMV/GEMM arithmetic evidence; the full `REQ-CL-020` remains PARTIAL because legacy Conv and broader opcode/shape/fault coverage are still open.
