# Compute Cluster clean candidate replay R182 — 2026-11-02

## Purpose and exact candidate

R182 reruns the required integration gates on the latest local sign-off candidate after R181. It is reproducibility evidence only: it adds no new testpoint, grants no waiver, and promotes no requirement disposition.

| Item | Identity |
|---|---|
| Tested local commit | `39f54b7f72f24b3cc61a57b8ce8359807aefcc48` |
| Tested tree | `d18249b5338ca8324211078f3ca10fa0abad76cc` |
| Published equivalent | `64647ad338a3b176bca651ef9e197dae98c687ec` (same tree) |
| Checkout | Detached clean worktree `/tmp/nmaforge_r182_final_candidate_clean` |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64`; UVM 1.2; URG `V-2023.12-SP1` |
| UVM run ID | `R182-COMPUTE-CLUSTER-CLEAN-3S-20261102`; seeds `20261025`, `20261026`, `20261027` |
| Top Smoke run ID | `R182-TOP-SMOKE-20-20261102`; seed `20261025`, random cases `20`, random seed `12345` |
| Mutation run ID | `R182-CHECKER-SENSITIVITY-28-20261102`; campaign seed `20261025` |

## Results

The real-top Compute Cluster UVM regression passes on all three seeds. Each run reports UVM Warning/Error/Fatal counts `0/0/0`; the independent memory scoreboard and existing assertions remain enabled. The declared `cluster_cg` is `64/64` (100%), and `focused_compute_cg_applicable=100.0%` on each seed, with `cpl_read` explicitly reported N/A for this workload. The merged URG group score is `70.41%`; line/condition/FSM/branch/assert scores are `63.55/69.74/63.99/45.04/60.10/72.00%`. These scoped results do not constitute global coverage closure.

The 28/28 checker-sensitivity campaign passes its Make gates: Address, Data, Owner, WSTRB, Completion Error Code, Write After Error, Response Epoch, and Done/Missing-Done/Duplicate-Done on all seven engines are each detected by the named expected checker. Mutation logs intentionally contain UVM errors because the injected corruption must trigger the checker; those are not clean-regression runs.

Top Smoke passes after the mapper precheck and reports `TEST PASS`. The command also requests 20 random cases. The existing `LOOP-REROLL-ENABLED` message is retained as a simulator debug notice; no test failure is reported.

## Reproduction commands

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C /tmp/nmaforge_r182_final_candidate_clean/dv/uvm/sim \
  uvm_compute_cluster_regress uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r182_final_candidate_uvm \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r182_final_candidate_mutations \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
make -C /tmp/nmaforge_r182_final_candidate_clean/dv/subsystem/top_smoke/sim \
  ai_smoke SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=12345
```

## Archived evidence

The local evidence archive contains the three UVM logs and coverage databases, merged URG summaries, all 28 mutation logs and their coverage databases, and Top Smoke compile/run logs. Per-file hashes are in its `SHA256SUMS` manifest.

- Archive: `/tmp/nmaforge_r182_signoff_evidence.tar.gz`
- Archive SHA-256: `2f9032edb6696de21cdc23f325b2725df41aeb20dee93879f15c62e0f8e0ff52`
- Manifest SHA-256: `9b177d83ebbc6b1963cabfd73436f7b7eabcaef779508c37ca286f501e9ef89d`
- Extracted evidence directory: `/tmp/nmaforge_r182_signoff_evidence`

## Sign-off effect and remaining limits

The 38-requirement disposition remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**. R182 does not close the remaining legal fault/phase/reset combinations, all production response-owner/backpressure intersections, outstanding SPEC dispositions, or global functional coverage. It does not claim ASIC PPA, TinyNPU competitiveness, or complete NPU sign-off.
