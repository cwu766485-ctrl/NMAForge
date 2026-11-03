# Compute Cluster Final Candidate Clean Replay R240 — 2026-11-03

## Purpose and source identity

This replay checks that the latest published closeout candidate still runs through the real-top Compute Cluster UVM and the restored top Smoke bench. It adds reproducibility evidence only; it does not change any Requirement disposition.

| Item | Value |
|---|---|
| Published GitHub commit | `9659a16e37e10780df7a2e9209d0d7dce2826fa2` |
| Published tree | `a7d5bb00c51e7ded82d2d289c4e7b2421cc5e5f1` |
| Clean local replay commit | `15d3e6ecd323f357c53d8e5c013ade72a8dddba7` |
| Local replay tree | `a7d5bb00c51e7ded82d2d289c4e7b2421cc5e5f1` |
| Replay checkout | Detached clean worktree `/tmp/nmaforge_r240_clean` |
| Run ID | `R240-FINAL-CANDIDATE-UVM-TOPSMOKE-3S-20261103` |
| Tools | Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |

The local clean checkout has the identical Git tree to the published branch head. The report therefore records both commit identifiers rather than treating two independently-created commits as the same SHA.

## Commands and results

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r240_cluster_20261103 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261103 AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

Both targets pass. The top Smoke mapper emits `TRANSFORMER_MAPPER_PASS` for 86 descriptors and the simulation ends with `TEST PASS` after 20 random cases. Its compile log contains the tool's `Warning-[LOOP-REROLL-ENABLED]` optimization notice; no RTL compile error was reported.

The three Compute Cluster UVM seeds each report `COMPUTE_CLUSTER_REAL_UVM_PASS` and UVM severity `0/0/0`. Each seed checks 92,871 Memory Image words with zero mismatch, unknown, or stale-epoch reads. The engine response ledger is identical on each seed: 5,015 accepted reads, 4,995 returned and checked, 20 reset-dropped, no pending entries, and zero route/data/error mismatch. The focused `cluster_cg` is 64/64 (100%) in each seed.

The real-engine run observes all 21/21 pair overlaps and a maximum of seven active engines. Request-backpressure is observed for six engines (mask `1110111`); Matrix/CNM banked contention admits 320 colliding requests and checks 320 held Matrix payloads with zero owner or hold violations. The randomized parity cross is 18/18. These checks do not model an arbitrarily stalled SRAM downstream interface; full requester fairness under external memory backpressure remains open.

The merged three-seed URG report gives 70.42% line, 65.51% condition, 45.96% FSM, 60.64% branch, 72.00% assertion, and 79.18% aggregate group coverage. These are whole-UVM-hierarchy metrics. They are not DUT-only metrics or evidence that all functional Requirements are closed. The cluster-specific declared functional group is 100%, while the broader v1.0 disposition remains 24 `PASS-SCOPED` and 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Archived evidence

Logs and text coverage summaries are archived at `/tmp/nmaforge_r240_evidence_20261103.tar.gz`, SHA-256 `b137662f59950a940aac0ef323f5fa3b56a422ad77f3d767045b9fbcc2f0b231`.

| Evidence | SHA-256 |
|---|---|
| UVM compile log | `15d2ec40c901c63b2aadb1699873a5fe4f675fbe9bcf526f0d43e5b507b9b220` |
| UVM seed 20261025 | `407d4665d47de321e37d6162353e8672251af6e64c8010c12e917e46b44d469a` |
| UVM seed 20261026 | `f291b285957f1c8e25d444875c13eaa057fe59e6a922085b30c7b5877cee469d` |
| UVM seed 20261027 | `66bd9c85e52b92bd499e844a57abb9f747e2470f5173b928fb4ef24bdea22d9a` |
| Top Smoke compile log | `8f56dfec4ab38c720aa7a2b7d2a0e9f697838ccde238b279e664ade545dc6670` |
| Top Smoke run log | `4bdae445892c704d53ad23a165c9f8cf4e7068218a320a8413cba85223692cfb` |

## Sign-off impact and remaining work

No Requirement is promoted by this replay. Existing partial dispositions remain, including broader engine/fault/phase/reset crosses, descriptor boundaries and shape coverage, full external error-ABI intersections, complete legal FSM transition disposition, and production-engine fairness under downstream memory pressure. Existing benchmark results also remain scoped to their documented RTL source, workload, and behavioral-memory assumptions. ASIC PPA is not measured here.

The v1.0 exit condition is not met: do not declare Compute Cluster Functional DV sign-off. Continue with the open Requirement evidence and approved dispositions before starting product-path architecture changes.
