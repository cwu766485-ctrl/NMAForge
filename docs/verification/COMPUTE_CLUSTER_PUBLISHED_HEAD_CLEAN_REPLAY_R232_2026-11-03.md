# Compute Cluster Published-HEAD Clean Replay — R232

**Date:** 2026-11-03
**Published branch:** `feat/compute-cluster-closeout-audit`
**Published HEAD tested:** `3259d4da158d56aebe41c227c426b6b4b74a0f72`
**Published tree:** `94211f35e486adab92203d92c1792086089cc71b`
**Product/test source identity:** `c5755985b0e5b1e1a850122ece983a37be112272`, tree `b0ee13ed91399ce0f982c36a6f5e55e9857e2061`; `rtl/`, `dv/`, and `docs/spec/` are unchanged between this source identity and the published HEAD.
**Run IDs:** `R232-PUB3259-TOP-SMOKE-20261103`, `R232-PUB3259-CLUSTER-UVM-3S-20261103`, `R232-PUB3259-MIXED-E2E-16S-20261103`, `R232-PUB3259-RTL-MUTATION-28-20261103`, `R232-PUB3259-COMBINED-URG-20261103`
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Exact published-head replay

All commands ran from clean worktree `/tmp/nmaforge_r232_published` at the published SHA above. No product RTL, SPEC, or test source changed during the runs.

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs

make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r232_published_compute_20261103 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r232_mixed_e2e_cov_20261103
```

Top Smoke ends with `TEST PASS`; its mapper precheck covers 86 descriptors and 60 tensors. The compile retains the existing `[LOOP-REROLL-ENABLED]` fixture warning. There are no compile errors or `[TFIPC]` diagnostics.

The real seven-engine Compute Cluster UVM passes all three seeds with UVM warning/error/fatal counts `0/0/0`. Each run checks the complete Memory Image: 73,190 writes and 92,871 checked words, with zero mismatches, unknown reads, or stale-epoch reads. The response-owner ledger accepts 5,015 reads, checks 4,995 responses, accounts for 20 reset-dropped reads, and ends with zero route/data/error mismatches and no pending responses. Observed engine-pair overlap is 21/21; the legal Protection × reset × recovery testpoint reports 7/7 engines, 12/12 legal engine/operand pairs, and 6/6 declared phases (72/72); the randomized parity set reports 18/18.

The 16-seed mixed-precision E2E coverage target passes all Make-gated tests and reports UVM severity `0/0/0` per seed. AXI AR/AW/W stall-to-accept cover properties match 166/70/123 times. This supplies the AR/AW stimulus absent from the compute-only workload.

## Combined functional coverage and assertions

The following URG merge combines the three Compute Cluster seeds with the 16 E2E seeds and their compile databases:

```sh
/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r232_published_compute_20261103/compile.vdb \
       /tmp/nmaforge_r232_published_compute_20261103/seed_*/coverage.vdb \
       /tmp/nmaforge_r232_mixed_e2e_cov_20261103/simv_uvm.vdb \
       /tmp/nmaforge_r232_mixed_e2e_cov_20261103/seed_*/coverage.vdb \
  -format text -report /tmp/nmaforge_r232_combined_urg_20261103 \
  -log /tmp/nmaforge_r232_combined_urg_20261103.log
```

URG reports **28/28 declared functional covergroups at 100%**. The combined simulation-hierarchy line/condition/FSM/branch/assert/group figures are `73.95/69.39/47.24/64.95/92.00/100.00%`. These code-coverage figures include the UVM testbench hierarchy and are not DUT-only metrics. The 22 assertions have 20 real successes, zero failures and incomplete attempts, and two UVM RAL internal properties without attempts. All three AXI cover properties match; all five top AXI master protocol assertions record real successes. The two RAL properties are explicitly disclosed, not treated as covered.

This is closure of the **declared functional covergroups for these merged test plans**. It does not mean 100% RTL line/condition/FSM/branch coverage or 100% requirement closure.

## Actual RTL mutation campaign

The existing mutation target finishes with `COMPUTE_CLUSTER_MUTATION_CAMPAIGN_PASS` and **28/28 expected checker catches** at seed `20261025`: Address, Data, Response Owner, WSTRB, Completion Error Code, Write After Error, and Response Epoch; plus Done, Missing Done, and Duplicate Done for all seven engines. Each mutation log contains both the injection marker and the assigned checker-catch marker. The product source in the clean worktree was not changed by this campaign.

Executed command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r232_dut_mutation_20261103
```

The target currently reads `COMPUTE_CLUSTER_MUTATION_OUT`; the supplied `COMPUTE_CLUSTER_DUT_MUTATION_OUT` variable was unused, so it used its generated default output directory `/tmp/nmaforge_compute_cluster_mutations_20261103_123720_305878236` and compile directory `/tmp/nmaforge_real_compute_cluster_uvm_20261103_123720_305878236`. The campaign itself exited zero. For a future rerun, set `COMPUTE_CLUSTER_MUTATION_OUT` to select the archive directory.

## Requirement trace and sign-off impact

The current RTM rows remain `24 PASS-SCOPED / 14 PARTIAL`; no disposition is promoted by this replay.

| Requirement rows | R232 testpoint / checker evidence | Coverage and result | Run ID / seeds |
|---|---|---|---|
| `REQ-CL-006`, `REQ-CL-014` | Real engine-pair overlap, request-stability monitor, arbiter/owner checks | 21/21 observed engine pairs; accepted payloads held through stalls; UVM clean | `R232-PUB3259-CLUSTER-UVM-3S`; `20261025/26/27` |
| `REQ-CL-010` | Matrix WSTRB and Line checkers; WSTRB RTL mutation | Full-strobe legal writes and assigned mutation checker observed; partial/zero WSTRB remain unsupported by the frozen contract | Same UVM and `R232-PUB3259-RTL-MUTATION-28`; seed `20261025` |
| `REQ-CL-017`, `REQ-CL-018`, `REQ-CL-019`, `REQ-CL-027` | Error, Protection/reset recovery, Abort, completion-owner and lifecycle checkers | Protection/reset 72/72 declared legal bins; parity 18/18; Mutation 28/28. Other legal fault × phase × reset × backpressure combinations remain open | Same cluster UVM and mutation runs |
| `REQ-PC-006` | `CLUSTER_MEMORY_SCOREBOARD`, output image and epoch checks | 92,871 words/seed; zero mismatch, unknown read, or stale epoch; accepted engine WSTRB was full-only | Same cluster UVM run |
| `REQ-PC-007` | `CLUSTER_ENGINE_RESPONSE_OWNER` ledger and response mux checker | 5,015 accepted / 4,995 checked / 20 reset-dropped; zero mismatch and pending entries | Same cluster UVM run |
| Functional group coverage / SVA | Combined URG group bins, top AXI protocol assertions, AR/AW/W cover properties | 28/28 groups; 20/22 assertions with real success, 0 failure/incomplete, 2 UVM RAL no-attempts; AXI covers 166/70/126 in the combined report | `R232-PUB3259-COMBINED-URG`; 19 simulation seeds |

These rows gain current exact-published-head evidence but remain `PARTIAL` where the full requirement clause extends beyond the named testpoints. The remaining partial clauses include descriptor maximum/stride/alias/overflow legality and broad opcode dispatch (`REQ-CL-002/015`), complete descriptor-latch coverage (`REQ-CL-005`), exhaustive legal requester/backpressure and fault/phase/reset crosses (`REQ-CL-006/014/017/018/019`, `REQ-PC-006/007`), Matrix integration/FSM scope (`REQ-CL-010`), wider scalar numeric/descriptor coverage (`REQ-CL-020`), and the complete benchmark contract (`REQ-CL-028`). See the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) and [Open-Issue List](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).

**Decision:** `CL-DV-v1.0` remains **HOLD**. The R232 archive contains 70 source logs/text reports and a SHA-256 manifest, but excludes VCS executables, `csrc`, waveforms, and coverage databases: `/tmp/nmaforge_r232_final_evidence_20261103.tar.gz`, SHA-256 `ac1f65990fd2aef1b044a680170878ac8f327eb848f53be722b9a13801b2e0ba`; manifest SHA-256 `e0a76a5e80bfb283e4d2435d9990e7613daa3ecab8a7f93fbc5593caef9bdc66`.
