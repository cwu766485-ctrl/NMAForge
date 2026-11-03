# Scalar/KV Shared-Source Ownership Attempt — R275

**Disposition: `BLOCKED_ENV`.** The real-top three-seed UVM regression did not reach SystemVerilog parsing or elaboration because VCS could not connect to the configured license server. The new testpoint has no simulation result, no measured coverage, and no PASS claim.

## Candidate and intended testpoint

| Item | Value |
|---|---|
| Published closeout branch | `feat/compute-cluster-closeout-audit` |
| Exact code/test SHA attempted | `5b8e6e5decf972b07230bd7828f7d8f2ccd43307` |
| Tree SHA | `b400539d73bd5a8acdc65cbd77fc4c9fddaec02c` |
| Run ID | `R275-SHARED-READ-ALIAS-CLEAN-3S-20261104` |
| Intended seeds | `20261025`, `20261026`, `20261027` — **NOT_RUN** |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64` |

The test-only change makes the real C1 Scalar VDOT and KV write descriptors read the same immutable 128-word SPAD source. It checks each engine's accepted request, tagged response, result/cache image, and completion, with a focused functional bin and Makefile gate. This is intended additional ownership evidence for `REQ-PC-007`; it does not change product RTL or SPEC. Since compilation was blocked, none of those checks or the focused coverage bin has been exercised.

## Command and result

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  VCS_ARCH_OVERRIDE=linux \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r275_shared_alias_capture_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The command exited `2` at `uvm_compute_cluster_compile`; VCS exited `255` with “Cannot connect to the license server” / “Failed to obtain license.” The process terminated before compiling any SV source. The environment variables `SNPSLMD_LICENSE_FILE` and `LM_LICENSE_FILE` were set, but neither configured endpoint was reachable from this workspace at the time of the attempt. No seed simulation or URG merge ran.

The independent fixed-point reference command passed:

```sh
make -C dv/subsystem/top_smoke/sim ai_a4_ref
```

Result: `A4_REFERENCE_PASS cases=1000 seed=20260722`. This is a software reference check and does not count as RTL or UVM evidence.

## Requirement impact

No Requirement disposition changes. `REQ-PC-007` remains `PARTIAL`; existing `REQ-PC-008` remains scoped to its previously tested Scalar/SFU shared-read case. The 38-row aggregate remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

The captured command transcript is outside Git at `/tmp/nmaforge_r275_shared_alias_attempt.log`, SHA-256 `092886555beefaed6dea9e2b000156566e538b11b41dc689e43f1d7b8d042b90`.
