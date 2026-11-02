# R199 — Final published closeout HEAD replay attempt — 2026-11-02

## Candidate identity

- Closeout branch: `feat/compute-cluster-closeout-audit`
- Published candidate SHA: `353695f4badca20a8a12a515393af0d59a4b66b5`
- Candidate tree: `c79b4f100adc83400a486adc5de007d311bfe1ee`
- Underlying RTL/test SHA: `f87acc9bca3b3ecece385fadfd5623de6837ea8d` (R198 and its descendants changed documentation only)
- Clean detached worktree: `/tmp/nmaforge_r199_clean_353695f`
- Run ID: `CL-CLEAN-HEAD-REPLAY-R199-20261102`
- Tool: Synopsys VCS `V-2023.12-SP1_Full64`

## Attempt and disposition

The exact published HEAD was checked out detached with a clean worktree. The requested three-seed Compute Cluster UVM replay was started:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r199_uvm_20261102 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

VCS repeatedly reported that it could not connect to the license server and queued while waiting for `VCS-BASE-COMPILE/VCSCompiler_Net`. A local TCP reachability check of the configured license endpoints also failed. The compile was interrupted after the repeated connection failure; no simulator executable was generated and no seed simulation ran.

**Result: `BLOCKED_ENV`, not PASS or RTL FAIL.** Top Smoke, seeded Top regression, and the final combined coverage merge were not run at R199. The last successful evidence remains separately bound to the code/test SHA `f87acc9...`: R194 real-top UVM and mutation campaign, R195 AXI SVA/Top replay, R197 fabric tests, and R198 Matrix Line tests. These records are not relabeled as runs at the documentation-only commit `353695f`.

## Evidence archive

The logs-only archive is `/tmp/nmaforge_r199_blocked_evidence_20261102.tar.gz` (SHA-256 `d9459a09a06ad173323a04f65c494ef7b79f9e334e240cd83ac5a67cafe99376`). It contains the VCS compile log, observed license blocker, run manifest, and per-file checksums. No generated simulator, coverage database, or waveform is included.

## Sign-off impact

R199 changes no requirement disposition. The RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**. The clean replay must be rerun after the configured VCS license service is reachable from this workspace. Phase A exit criteria are not met.
