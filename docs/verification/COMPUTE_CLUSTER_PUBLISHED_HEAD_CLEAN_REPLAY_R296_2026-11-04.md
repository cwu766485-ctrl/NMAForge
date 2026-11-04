# Published-Head Compute Cluster Clean Replay — R296

**Disposition:** Reproducibility PASS at the exact published closeout SHA; no requirement status is promoted. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

| Item | Evidence |
|---|---|
| Test IDs | `TC-CL-R296-LATEST-CLEAN-UVM`, `TC-CL-R296-TOP-SMOKE`, `TC-CL-R296-TOP-RANDOM-20` |
| Run IDs | `R296-CLUSTER-UVM-3S-20261104`, `R296-TOP-SMOKE-20261104`, `R296-TOP-RANDOM20-SEED12345-20261104` |
| Published candidate | GitHub closeout SHA `4336885e42772c054d96a213a684c4d59b05093d`; tree `6493d87190023c0d067a4c1f66580c5d7119ded4` |
| Worktree | Detached clean worktree `/tmp/nmaforge_r296_latest_clean` at the exact candidate SHA before simulation |
| Tools | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |
| Evidence archive | `/tmp/nmaforge_r296_latest_clean_replay_logs.tar.gz`; SHA-256 `749f6cc079c09ecfc96e4de408ee95312f2ac2474bd47ae04ecb87af564b6105` |

## Results

The production-top Compute Cluster UVM target passed seeds `20261025`, `20261026`, and `20261027`. Each seed reports UVM warning/error/fatal counts `0/0/0`, 100% applicable focused Compute Cluster coverage, and 21/21 real engine-pair overlap bins. The Memory Scoreboard checks 146,755 words with zero mismatch, unknown read, or stale epoch. The response-owner ledger records 10,678 accepted, 10,658 checked, and 20 reset-dropped reads, with zero route/data/error mismatch and no pending response.

Top Smoke passed the 86-descriptor / 60-tensor mapper precheck and printed `TEST PASS`. The fixed top regression with `AI_RANDOM_CASES=20`, `AI_SEED=12345`, and simulator seed `12345` also printed `TEST PASS`.

The merged three-seed UVM URG score is 84.38% across declared groups. Whole-module-definition line/condition/FSM/branch coverage is 71.07/65.08/48.84/60.41%; these metrics include the elaborated test hierarchy and are not DUT-only closure. URG lists two UVM RAL internal assertions with no attempts. The compute-only run's AR/AW stall-to-accept cover properties have attempts but no matches; separate mixed DDR/AXI evidence R241 records AR/AW/W matches 14/5/12. The top-smoke compile retains the known `[LOOP-REROLL-ENABLED]` warning.

This replay uses behavioral scratchpad and responder models. It proves that the published candidate reproduces the named regressions; it does not close the remaining legal requester/fault/phase/reset/backpressure combinations or establish ASIC sign-off.

## Commands

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r296_latest/uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261025 AI_RANDOM_CASES=4 AI_SEED=12345

make -C dv/subsystem/top_smoke/sim ai_run \
  SEED=12345 AI_RANDOM_CASES=20 AI_SEED=12345
```

## Log hashes

| Log | SHA-256 |
|---|---|
| UVM compile | `55783b354bc18ccb1fe003cd579e5210e5727b69620dba77a71248cb3ece9cd7` |
| UVM seed 20261025 | `f1dfc92119282d31adbbb5b5ea8bbce1e07f0efd598db02f4794a8082cfcb589` |
| UVM seed 20261026 | `dc2e6be971975ad5ddb0496368aaab9fa4be325fc60df20cbfc1c8de76739661` |
| UVM seed 20261027 | `7770f417e8a6de68e98c5f50619a3aa03424c219df0718f51e3d85efc5496758` |
| Top Smoke compile | `6b7b0f32efd6cc8fa0d1c971c302ebe81ad942ee0a32615abb05a566dc30d454` |
| Top Smoke run | `145405b57a5f72e84a5bb443a4a22de53c64e71fb92f3ced83c4fb370d218b8d` |
| Fixed 20-case Top run | `667fae6eab0ae31f18c7c8b1ba0d7319e6ba9c8da8d2f76c655933385af94076` |

R296 is a published-SHA reproducibility record. It adds no functional-coverage credit beyond the named bins and does not change the sign-off disposition.
