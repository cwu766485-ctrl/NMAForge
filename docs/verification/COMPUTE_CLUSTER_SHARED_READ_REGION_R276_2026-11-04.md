# Scalar/KV Shared-Read Region Regression Attempt — R276

**Disposition: `BLOCKED_ENV`.** VCS could not obtain a license before compiling the updated UVM sequence. The three seed simulations are `NOT_RUN`; no new Golden, response-ownership, or coverage result is claimed.

## Candidate and testpoint

| Item | Value |
|---|---|
| Published closeout branch base | `feat/compute-cluster-closeout-audit` |
| Exact code/test SHA attempted | `58a4c3664bd7925db93f63eebcd2e489e4122fae` |
| Tree SHA | `cd46c494161084efe13f80e4eaf294acc582dc37` |
| Run ID | `R276-SHARED-READ-REGION-CLEAN-3S-20261104` |
| Seeds | `20261025`, `20261026`, `20261027` — **NOT_RUN** |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64` |

The test-only monitor watches accepted reads by production Scalar and KV engines across the shared immutable 128-word input region, records their owner-tagged responses, and requires overlapping in-flight read owners during the existing seven-engine C1 task. It retains the independent Scalar result, KV cache image, and completion checks. The focused check is intended to add bounded evidence for `REQ-PC-007`; the requirement remains `PARTIAL` pending an actual run and broader ownership/fault/reset coverage.

## Command and result

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  VCS_ARCH_OVERRIDE=linux \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r276_shared_region_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The command exited `2` at `uvm_compute_cluster_compile`; VCS exited `255` with “Cannot connect to the license server” and “Failed to obtain license.” No SV compilation, seed execution, or URG merge occurred. The attempted executable is the installed VCS under `/opt/Synopsys`; using the alternate `/tmp` alias had the same license failure in the preceding R275 attempt.

Captured command transcript: `/tmp/nmaforge_r276_shared_region_attempt.log`, SHA-256 `2f23e98519ebd35842612711d26657ad647645c3d02b094341f010766933c6fc`.

## Requirement impact

No disposition changes. `REQ-PC-007` remains `PARTIAL`, `REQ-PC-008` remains scoped to its previously executed Scalar/SFU shared-read case, and the aggregate remains 27 `PASS-SCOPED` / 11 `PARTIAL`. `CL-DV-v1.0` remains **HOLD**.
