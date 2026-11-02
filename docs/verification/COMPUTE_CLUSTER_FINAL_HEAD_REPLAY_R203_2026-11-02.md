# R203 — Clean latest-HEAD VCS replay retry — 2026-11-02

## Candidate and run identity

- Local detached candidate: `518b75541e32878998c9dd478a692f0ba27c0982`
- Candidate tree: `03c034bf30e5bbb2af2200411fa0b1e674ebf3d6`
- Published same-tree closeout commit: `18059052b73ad1507f7b754108b9c84ed75a929a`
- Underlying RTL/test content remains the previously tested `f87acc9bca3b3ecece385fadfd5623de6837ea8d` tree; this candidate changes documentation/checker only.
- Clean detached worktree: `/tmp/nmaforge_r203_clean_518b755`
- Run ID: `CL-CLEAN-HEAD-REPLAY-R203-20261102`
- Tool: Synopsys VCS `V-2023.12-SP1_Full64`

## Attempt and result

The three-seed `uvm_compute_cluster_regress` target was started from the clean worktree with seeds `20261025/20261026/20261027` and a 120-second wall-clock limit. VCS again reported that it could not connect to the configured license service, queued for `VCS-BASE-COMPILE/VCSCompiler_Net`, and did not produce the simulator executable before the timeout terminated the compile.

**Result: `BLOCKED_ENV`, not PASS or RTL FAIL.** No seed ran. Top Smoke, seeded Top, and combined coverage merge were not run at this candidate. The endpoint reachability probe also reported the configured TCP endpoints unreachable. No VCS process remained after timeout.

Exact target and relevant command settings:

```sh
timeout -k 5s 120s env VCS_ARCH_OVERRIDE=linux \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r203_uvm_20261102 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The raw log remains outside the repository at `/tmp/nmaforge_r203_compile.log`; SHA-256 `3103ee7046612a59855f0094d61574a4ce4c2c4cf71d0454eafc0fce10e6b95c`.

## Sign-off impact

R203 adds no requirement evidence and changes no disposition. The RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The latest clean exact-HEAD regression is still blocked by license-service reachability. Do not relabel earlier PASS runs at `f87acc9` as evidence at this documentation-only candidate.
