# Compute Cluster Final Published-Tree Replay — R250

**Result:** The current published source/test tree reproduces the real seven-engine UVM regression, Top Smoke, 16-seed mixed-precision E2E regression, seven actual RTL mutations, and merged URG report. All 28 declared functional coverage groups are hit. This confirms the declared testpoint target for these tests; it is **not** 100% RTL code coverage and does **not** close Phase A sign-off.

## Frozen identity and tools

| Item | Value |
|---|---|
| Published `main` parent commit | `703c248949c5ca2d36a0cbb4949fc6b16c0741c7` |
| Published / replay source-test tree | `da34f7e314fccf3793372c59768ebac541fa22a7` |
| Local detached replay commit | `cad73af4ac62f12e0d277208b87dd9db129c1330` |
| Local replay tree | `da34f7e314fccf3793372c59768ebac541fa22a7` |
| VCS / URG | `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |
| Clean worktree | `/tmp/nmaforge_r246_mutation_clean` |

The replay source-test tree matches published `main` exactly. R250 contains documentation changes only; the simulation source was not modified.

## Commands and results

| Run ID | Command | Result |
|---|---|---|
| `R250-CLUSTER-UVM-3S` | `VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/uvm/sim uvm_compute_cluster_regress VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r250_final_sha_cluster_3seed COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | PASS on all three seeds. Each seed checks 92,871 Memory Scoreboard words and 73,190 writes, with zero mismatch, unknown read, stale epoch, orphan response, or remaining owner entry. Response accounting is 5,015 accepted / 4,995 checked / 20 reset-dropped. UVM warnings/errors/fatals are 0/0/0. |
| `R250-TOP-SMOKE` | `VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261103 AI_RANDOM_CASES=20 AI_SEED=12345 VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs` | PASS; smoke ends `TEST PASS`, and the 86-descriptor Transformer chain completes. Existing `[LOOP-REROLL-ENABLED]` compile warning remains. |
| `R250-MIXED-E2E-16S` | `VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias MIXED_E2E_COV_OUT=/tmp/nmaforge_r250_final_sha_mixed_16seed` | PASS on seeds `20261014–20261027`, `712345`, `987654`; every seed has zero UVM warning/error. Includes FP16/BF16/INT8 Golden checks, AXI backpressure/error, reset epoch and recovery. |
| `R250-DUT-MUTATION-7` | `VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/uvm/sim uvm_compute_cluster_dut_mutation VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r250_final_sha_mutation` | PASS: 7/7 actual RTL mutations are detected by their intended checker: Address, Data, Response Owner, WSTRB, Completion Error, Missing Done, Duplicate Done. |
| `R250-URG-MERGE-19T` | URG merge of the three Cluster seed VDBs and 16 mixed E2E seed VDBs | PASS: 19 tests; 28/28 declared functional groups score 100%; all 3/3 AXI stall-to-accept cover properties match. |

Combined URG hierarchy line/condition/FSM/branch/assert coverage is `73.99/69.39/47.24/64.95/92.00%`. Of 22 assertion properties, 20 have real successes and zero failures/incomplete; two UVM RAL internal `do_read`/`do_write` properties have no attempts. The AR/AW/W stall-to-accept cover properties match `166/70/126` times. These metrics include DUT, testbench and UVM hierarchy; they are not DUT-only coverage and must not be called 100% code coverage.

## Requirement disposition and remaining work

The full 38-row Execution RTM was audited: all 38 IDs are present, with 24 scoped pass dispositions and 14 `PARTIAL`. No requirement status is promoted by this replay. The partial rows are `REQ-CL-002/005/006/010/014/015/017/018/019/020/027/028` and `REQ-PC-006/007`.

Remaining closure is requirement-level: freeze per-engine descriptor maxima/stride/alias/overflow contracts; complete legal seven-engine requester × fault × phase × response-backpressure × reset/epoch intersections; close simultaneous completion/error and CPLQ backpressure obligations; and disposition remaining feature-specific coverage. The Matrix enabled-profile FSM raw count remains `49/53`; R249 provides legal-profile dispositions for four residual transitions, not an artificial 100% raw count. `OPEN-CL-002` and the broader ownership/fault/reset items remain in the Open-Issue List.

**Decision:** `CL-DV-v1.0` remains **HOLD**. The R250 evidence supports declared testpoint coverage and exact-tree reproducibility, but it does not satisfy the full Phase A exit conditions. No ASIC PPA or whole-NPU sign-off is claimed.

## Evidence archive

Text logs, URG summaries and SHA-256 manifest: `/tmp/nmaforge_r250_final_sha_evidence_20261103.tar.gz`, SHA-256 `9f4865a09e93152548da30c85e25ac3afcd94d6ab05abdd56930c71c6d34b57a`. The archive excludes VDBs, simulator binaries, compiler output trees, waveforms, and credentials.
