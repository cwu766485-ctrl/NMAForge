# R206 — Exact-candidate clean-worktree replay — 2026-11-02

## Candidate and run identity

- Candidate SHA: `0b6332a60d63c78c4145ed40e5e5efc275c491d3`
- Tree: `bde94d427d993302376c69eb81e168cf5c938cce`
- Checkout: detached, clean worktree `/tmp/nmaforge_r206_clean_0b6332a`
- RTL, UVM and Top Smoke source files match `f87acc9bca3b3ecece385fadfd5623de6837ea8d`; the intervening commits change documentation/evidence only.
- Tools: Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`, UVM 1.2.
- Run IDs: `CL-CLEAN-HEAD-REPLAY-R206-20261102`, `CL-COVERAGE-R206-20261102`, `CL-MUTATION-R206-20261102`.

The user restored license access before this run. VCS compiled and all commands below completed; this supersedes the earlier R203 `BLOCKED_ENV` attempt for this candidate.

## Results

| Gate | Result |
|---|---|
| Real-top Compute Cluster UVM | **PASS**, seeds `20261025/26/27`; each reports UVM warning/error/fatal `0/0/0`. The real seven-engine run observes 21/21 engine pairs, max-active 7, and 2,694 compute-request backpressure cycles. The Memory Scoreboard checks 69,656 words, records 63,880 writes, and reports zero mismatch, unknown read, stale epoch, or orphan response. The owner ledger reports 2,847 accepted, 2,828 checked and 19 reset-dropped responses, with zero route/data/error mismatches and no pending entries. |
| Shared-engine and completion-pressure points | **PASS** on all three seeds: Matrix/CNM banked collision and response ownership; full CPLQ holds the fourth completion until software advances the head; ordered retirement, wrap and four output Goldens pass. |
| KV readback through CMDQ | **PASS** as part of the real C1 path: opcode `0x44` reads the head/token cache entry into a separate SPAD region; all 128 words are compared with the independent expected image and the completion task/result/count are checked. This is one legal address/stride point, not the full KV descriptor space. |
| Mixed precision / AXI E2E | **PASS**, all 16 configured seeds; zero nonzero UVM warning/error/fatal summaries. The top AR/AW/W stall-to-accept covers match 166/70/126 times in the merged report. |
| Combined declared functional coverage | URG merges 3 Compute Cluster and 16 mixed E2E seed databases: **21/21 declared functional groups at 100.00%**. This is declared functional-bin coverage, not all legal requirement combinations or code coverage. |
| Raw mixed RTL/test coverage | Line/condition/FSM/branch `73.70/68.72/46.69/64.70%`. Assertions: 20/22 have real successes, zero failures/incomplete; the two without attempts are UVM RAL internals. All 3 cover properties match. |
| Real RTL mutation | **PASS, 7/7**: Address, Data, Response Owner, WSTRB, Completion Error, Missing-Done and Duplicate-Done were each detected by their assigned checker. Mutation compilations have no `Warning-`, `Error-` or `[TFIPC]` diagnostics. |
| Top Smoke | **PASS**, mapper precheck reports 86 descriptors / 60 tensors; the 4-case smoke ends `TEST PASS`. The 20-case seeded Top run (`AI_SEED=12345`) also ends `TEST PASS`. The existing fixture `LOOP-REROLL-ENABLED` warning remains. |

Both UVM compile logs have no `Warning-`, `Error-` or `[TFIPC]` diagnostics. The compute-only UVM assertion merge by itself has two AXI AR/AW stall covers without matches; the separate 16-seed mixed run supplies the real AXI traffic and matches all three AR/AW/W covers.

## Reproduction commands

The exact commands, including VCS environment overrides and seeds, are preserved in the evidence archive manifest. Main targets:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r206_uvm_0b6332a \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r206_mixed_cov_0b6332a \
  MIXED_E2E_COV_SEEDS='20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r206_mutation_0b6332a

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_smoke \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  SEED=20261025 AI_RANDOM_CASES=4 AI_SEED=12345

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_run \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=12345
```

## Sign-off impact and remaining work

This replay fixes the reproducibility/evidence snapshot at the current clean candidate. It does **not** close the remaining legal descriptor/shape coverage, full requester × fault × phase × reset/backpressure space, every Matrix FSM transition, or a measured common-memory/TinyNPU comparison. No requirement disposition is promoted: the 38-row RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**. The 21/21 figure is limited to declared functional covergroups; it must not be described as all-testpoint or all-requirement closure.

Logs and text URG reports are archived outside the repository at `/tmp/nmaforge_r206_clean_replay_evidence_0b6332a.tar.gz`, SHA-256 `f02b897f4d5ea82a92c1ce50608dda590753d13adf51f740992f0d1c86b7a2b7`. The archive excludes VDBs, executables, compiler directories, waveforms and license configuration.
