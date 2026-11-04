# Published-Head Compute Cluster Clean Replay — R296

**Disposition:** Reproducibility PASS at the exact published closeout SHA; no requirement status is promoted. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

| Item | Evidence |
|---|---|
| Test IDs | `TC-CL-R296-LATEST-CLEAN-UVM`, `TC-CL-R296-MIXED-E2E-COV`, `TC-CL-R296-UVM-COMBINED-URG`, `TC-CL-R296-TOP-SMOKE`, `TC-CL-R296-TOP-RANDOM-20` |
| Run IDs | `R296-CLUSTER-UVM-3S-20261104`, `R296-MIXED-E2E-16S-20261104`, `R296-UVM-COVERAGE-MERGE-19T-20261104`, `R296-TOP-SMOKE-20261104`, `R296-TOP-RANDOM20-SEED12345-20261104` |
| Published candidate | GitHub closeout SHA `4336885e42772c054d96a213a684c4d59b05093d`; tree `6493d87190023c0d067a4c1f66580c5d7119ded4` |
| Worktree | Detached clean worktree `/tmp/nmaforge_r296_latest_clean` at the exact candidate SHA before simulation |
| Tools | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |
| Evidence archive | `/tmp/nmaforge_r296_latest_clean_replay_logs.tar.gz`; SHA-256 `dd2a1cf91329e22401e5634af1fe5ff9d5087bd4f13f6f059ef27f2af827d185` |

## Results

The production-top Compute Cluster UVM target passed seeds `20261025`, `20261026`, and `20261027`. Each seed reports UVM warning/error/fatal counts `0/0/0`, 100% applicable focused Compute Cluster coverage, and 21/21 real engine-pair overlap bins. The Memory Scoreboard checks 146,755 words with zero mismatch, unknown read, or stale epoch. The response-owner ledger records 10,678 accepted, 10,658 checked, and 20 reset-dropped reads, with zero route/data/error mismatch and no pending response.

The 16-seed mixed-precision DDR/AXI E2E coverage target passes its descriptor order/layout, FP16/BF16 K and length, invalid-descriptor, transaction-jitter/stall, reset/recovery and DMA-error checks with UVM severity `0/0/0` per seed. The combined URG command merges those 16 VDBs with the three R296 Cluster VDBs; all 37 declared functional groups reach 100.00%, and AR/AW/W stall-to-accept covers match 166/70/126.

Top Smoke passed the 86-descriptor / 60-tensor mapper precheck and printed `TEST PASS`. The fixed top regression with `AI_RANDOM_CASES=20`, `AI_SEED=12345`, and simulator seed `12345` also printed `TEST PASS`.

The Cluster-only three-seed URG group score is 84.38%. A separate 16-seed mixed DDR/AXI E2E coverage run passes, and the combined 19-test URG merge reaches 37/37 declared functional groups (100.00%). The combined aggregate line/condition/FSM/branch/assert/group summary is 76.19/71.43/53.31/67.46/92.00/100.00%; module-definition line/condition/FSM/branch/assert coverage is 74.79/69.49/50.32/65.14/84.62%. These are hierarchy-wide metrics, not DUT-only closure. URG lists two UVM RAL internal assertions without attempts, zero assertion failures/incomplete, and AXI AR/AW/W stall-to-accept matches 166/70/126. The top-smoke compile retains the known `[LOOP-REROLL-ENABLED]` warning.

This replay uses behavioral scratchpad and responder models. It proves that the published candidate reproduces the named regressions; it does not close the remaining legal requester/fault/phase/reset/backpressure combinations or establish ASIC sign-off.

## Commands

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r296_latest/uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r296_latest/mixed_e2e \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

# The combined 19-test URG argument list is stored in combined_urg.command
# inside the evidence archive.

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
| Mixed E2E compile | `be5a2dc390cb2f2fa01a70375f3fc4a58b813a1b313492a73c87f5df7745d187` |
| Combined URG dashboard | `d9654bc95293f238e8d8152bf99a19c8ab623f736e9199bf1548d25c784a5803` |
| Combined URG assertions | `0228aabe94d1947c586f85951a278338c0782cf6add495fe4c2f2bf3cae58841` |
| Combined URG functional groups | `c7bc06fbc08504f5cc09c613e833f03c037d10c4f9ae7a43bf54090d80aa3be4` |
| Top Smoke compile | `6b7b0f32efd6cc8fa0d1c971c302ebe81ad942ee0a32615abb05a566dc30d454` |
| Top Smoke run | `145405b57a5f72e84a5bb443a4a22de53c64e71fb92f3ced83c4fb370d218b8d` |
| Fixed 20-case Top run | `667fae6eab0ae31f18c7c8b1ba0d7319e6ba9c8da8d2f76c655933385af94076` |

R296 establishes 100% across the 37 declared functional groups represented in the combined merge. Those groups are not equivalent to closing every legal bin in each Requirement; no Requirement is promoted and the sign-off disposition remains HOLD.
