# Compute Cluster Request Stall Recovery — R270

## Scope and disposition

R270 adds legal scheduler-admission backpressure followed by acceptance on eight real request paths in the seven-engine Compute Cluster sequence. The directed checks hold each selected request unaccepted for eight clock cycles, check request stability/progress, release the stall, and continue through the existing Golden, Memory Scoreboard, and ordered-completion checks.

This is supplemental evidence for `REQ-CL-006` and shared-SPAD requirements `REQ-PC-006/007`. It does not close those requirements: broader request classes, downstream fabric behavior, fairness, and fault/phase/reset combinations remain open. No product RTL changed. The RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Candidate and changes

- Test candidate: `28736c57d493ae1af0983d3cb989185b9c684422`
- Tree: `e1e00a16135f70e9cbed71e46363f7a182ca244e`
- Parent: R269 local commit `37e900621ca340b77ae64b9a0ba2b632b3b833b4` (same tested tree as the published R269 candidate)
- Changed files: `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh`, `dv/uvm/sim/Makefile`
- The Make gate now requires all eight directed recovery markers and explicitly requires the new Matrix banked-read, SFU, Conv, and KV cases.

| Requirement | Test ID | Checker | Coverage / Result | Run ID / Seed | Evidence |
|---|---|---|---|---|---|
| `REQ-CL-006` | `TC-CL-R270-REQUEST-STALL-RECOVERY` | Request-valid/payload hold and post-release acceptance; seven-engine Golden and ordered-completion checks | 8/8 directed points per seed: Scalar, FP, Matrix banked read, Matrix Line write, four CNM lanes, SFU, Conv, KV; requirement remains `PARTIAL` | `CL-REQ006-SPAD-STALLED-REQUEST-R270-CLEAN-3S-20261104`; `20261025/26/27` | Per-seed `run.log` in `/tmp/nmaforge_r270_req006_clean_evidence.tar.gz`; SHA-256 below |
| `REQ-PC-006` | `TC-CL-R270-REQUEST-STALL-RECOVERY` | Full Memory Scoreboard: accepted writes, checked words, mismatch, unknown read, stale epoch | 77,501 writes and 96,595 checked words per seed; zero mismatch/unknown/stale; requirement remains `PARTIAL` | Same run / seeds | Same archive; full scoreboard lines in each `seed_*/run.log` |
| `REQ-PC-007` | `TC-CL-R270-REQUEST-STALL-RECOVERY` | Seven-engine accepted/checked/reset-dropped response-owner ledger | 6,139 accepted / 6,119 checked / 20 reset-dropped; zero route/data/error mismatch and pending=0 per seed; requirement remains `PARTIAL` | Same run / seeds | Same archive; owner-ledger lines in each `seed_*/run.log` |

## Reproduction

- Run ID: `CL-REQ006-SPAD-STALLED-REQUEST-R270-CLEAN-3S-20261104`
- Clean tested SHA: `28736c57d493ae1af0983d3cb989185b9c684422`
- Seeds: `20261025`, `20261026`, `20261027`
- Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`
- Per-seed UVM severity: warning/error/fatal `0/0/0`
- UVM compile diagnostics: no `Warning-`, `Error-`, or `[TFIPC]` diagnostics
- Clean worktree: `/tmp/nmaforge_r270_req006_clean`
- Regression output: `/tmp/nmaforge_r270_req006_clean_3seed`
- Logs-only evidence archive: `/tmp/nmaforge_r270_req006_clean_evidence.tar.gz`
- Archive SHA-256: `7a7afca755d2d9a5fd0f1d058bb7907d403cc1be3bff5660b29cd6e8a147057a`

Commands:

```bash
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
  make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r270_req006_clean_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
  make -C dv/subsystem/top_smoke/sim ai_smoke
```

The clean three-seed regression returns 0 and `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`. Each run log contains exactly eight `CLUSTER_REQUEST_STALL_INJECT_PASS` markers and its own `COMPUTE_CLUSTER_REAL_UVM_PASS`. Top Smoke returns 0 and prints `TEST PASS`; the existing fixture `LOOP-REROLL-ENABLED` warning remains.

## Limits and remaining work

The stall is introduced in the testbench at the scheduler admission point. This verifies legal held-request behavior and recovery on the selected production-client paths. It does not qualify arbitrary external fabric reset/epoch semantics, memory response latency/error contracts, scheduler fairness under unconstrained contention, or the full engine × fault × phase × reset cross. Those gaps keep `REQ-CL-006`, `REQ-PC-006`, and `REQ-PC-007` open. The whole-Cluster RTM disposition and sign-off decision are unchanged.
