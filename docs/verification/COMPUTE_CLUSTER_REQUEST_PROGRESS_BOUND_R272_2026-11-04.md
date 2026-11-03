# Compute Cluster Bounded Request-Progress Evidence — R272

**Disposition:** supplemental evidence for `REQ-CL-014`; the requirement remains `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Scope and identity

R272 adds a regression guard to the existing real-top seven-engine workload. It requires the six ports expected to contend in that legal workload (`stalled_mask=1110111`) to be observed, checks each measured consecutive `valid && !ready` interval against a 256-cycle regression bound, samples an explicit functional coverage group, and makes the Make target require its PASS marker. The bound is twice the prior three-seed observed maximum of 126 cycles. It is a regression guard for this fixed workload, not a SPEC-wide fairness limit.

No product RTL changed. The test was run with source/test tree `d56158d205ddb6c1b84950a9c8464e2ed2e07303`, based on the published closeout tree `cadb05ab7406f4f04b923f5cdc01396839dcc3cf` at `1dd5ec702f24e2d61ae6113e4fde288ff86fcd16`.

| Item | Value |
|---|---|
| Test ID | `TC-CL-R272-ALL-ENGINE-BOUNDED-PROGRESS` |
| Run ID | `CL-REQUEST-PROGRESS-BOUND-R272-3S-20261104` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Tool | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |
| Coverage group | `ai_compute_cluster_e2e_seq::engine_progress_bound_cg`, 100.00% |

## Commands

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_ARCH_OVERRIDE=linux \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r272_progress_bound_final \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261104 AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS_ARCH_OVERRIDE=linux
```

## Results

All three UVM seeds pass the new bounded-progress checker and the existing seven-engine Golden/completion checks. Each seed observes the same maximum consecutive request waits:

```text
engine ports 0..6: {12, 14, 53, 0, 64, 126, 14} cycles
stalled port mask: 1110111
regression bound: 256 cycles
progress coverage: 100.0%
```

All seven production engines launch; all 21 real engine pairs overlap. The independent Memory Scoreboard checks 96,595 words and 77,501 writes per seed with zero mismatch, unknown read, or stale epoch. The response-owner ledger reports 6,139 accepted, 6,119 checked, and 20 reset-dropped reads, with zero route/data/error mismatches and zero pending entries. UVM warning/error/fatal counts are `0/0/0` on every seed. The UVM compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

Top Smoke reports `TEST PASS`, including the mapper precheck (86 descriptors, 60 tensors) and 20 seeded random cases. Its existing VCS `[LOOP-REROLL-ENABLED]` debug-capacity warning remains.

The test only measures actual production-engine traffic under the repository's behavioral SPAD model. It does not inject arbitrary downstream SRAM service delay, qualify an external memory fabric, or prove a general fairness theorem. Therefore it adds a checked fixed-workload progress point but does not close the broad `REQ-CL-014` clause.

## Evidence archive

- Archive: `/tmp/nmaforge_r272_progress_bound_evidence.tar.gz`
- SHA-256: `a0966edb31e2915156f23267b39384e780936e6b0749999cea5472ed7693fb4f`
- Includes the VCS compile log, three seed logs, merged URG report, and Top Smoke compile/run logs.

The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; Phase A exit conditions are not met.
