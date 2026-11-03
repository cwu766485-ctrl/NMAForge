# Compute Cluster Final Candidate Clean Replay — R260

**Decision:** reproducibility evidence only; `CL-DV-v1.0` remains **HOLD**.
**Exact candidate:** `724d1f0b3774643df35e14d7cb9ff0e3ad534ac8`
**Tree:** `7e168fdbc5e90725d4a924f20b7fb2b1b842d03c`
**Clean replay:** detached worktree created at the exact candidate; it was clean before simulation.
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`.

The replay includes the published R259 Matrix/TinyNPU matched-vector harness and R258 memory-fabric reset evidence. No product RTL was changed by R259; this replay checks the current published test/source tree as one fixed candidate.

## Runs

| Run ID | Command / configuration | Result |
|---|---|---|
| `R260-UVM-CLUSTER-3S-724D1F0-20261103` | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r260_finalclean_724d1f0/uvm COMPUTE_CLUSTER_UVM_BASE_OUT=/tmp/nmaforge_r260_finalclean_724d1f0/uvm_base VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` | PASS, 3/3 seeds. Each has UVM severity 0/0/0; 95,043 Memory Scoreboard words, zero mismatch/unknown/stale; response ledger 6,139 accepted, 6,119 checked, 20 reset-dropped, zero route/data/error mismatches, zero pending. Applicable focused compute coverage is 100%; completion-read is explicitly N/A for this scenario. |
| `R260-MIXED-E2E-16S-724D1F0-20261103` | `make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_SEEDS='20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027' MIXED_E2E_COV_OUT=/tmp/nmaforge_r260_finalclean_724d1f0/mixed_e2e VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg` | PASS, 16/16 seeds; each UVM severity is 0/0/0. The six order/layout bins, four SPAD banks, six validator bins, FP16/BF16 K=1..4 and all 16 length pairs pass. URG has 20/22 assertions with real successes and zero failures/incomplete; the two no-attempt properties are UVM RAL internals. AXI AR/AW/W stall-to-accept covers match 166/70/123 times. Mixed hierarchy group score is 90.86%; it is not a global closure metric. |
| `R260-TOP-SMOKE-20-724D1F0-20261103` | `PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025` | PASS; mapper precheck reports 86 descriptors / 60 tensors, 20 random cases complete, `TEST PASS`. The existing `[LOOP-REROLL-ENABLED]` fixture warning remains. |
| `R260-DUT-MUTATION-7-724D1F0-20261103` | `make -C dv/uvm/sim uvm_compute_cluster_dut_mutation COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r260_finalclean_724d1f0/mutation VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` | PASS, 7/7 temporary RTL mutants caught by the expected checkers: Address, Data, Response Owner, WSTRB, Completion Error, Missing Done and Duplicate Done. |

The mixed-E2E SVA table has 20/22 successful assertions, no failures or incomplete attempts, and the two uncovered UVM RAL read/write properties have no attempts. The compute-only UVM also reports workload-scoped AXI AR/AW cover misses; the separate mixed-E2E run supplies nonzero AR/AW/W cover evidence. These do not imply every SVA or every legal system cross is closed.

## Disposition and limits

The 38-row RTM remains **25 PASS-SCOPED / 13 PARTIAL / 0 FAIL / 0 BLOCKED_SPEC / 0 NOT_RUN**. R260 changes no requirement disposition. The 100% compute-focused coverage figure applies only to its declared applicable group; the mixed E2E and hierarchy metrics are reported separately. The Matrix raw enabled-profile FSM remains 49/53 with the documented guard/fallback dispositions. `CL-DV-v1.0` stays **HOLD** pending closure or approved disposition of the remaining requirement gaps.

This replay establishes current-tree reproducibility for the listed tests. It does not establish external AXI fabric qualification beyond the exercised behavioral responder, complete legal Engine × Fault × Phase × Reset × Backpressure coverage, ASIC PPA, whole-NPU sign-off, or a TinyNPU system-level performance win. The R259 matched-vector benchmark remains a separate controller-level comparison with a modeled TinyNPU memory endpoint.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_compute_cluster_r260_724d1f0_logs.tar.gz`
SHA-256: `aabbf232f30e26f732618d312ddad30e115df9fbaeea51a718502ca313a9b4f1`
The archive contains 71 log, URG text-report, mutation-summary and checksum-manifest files. It excludes VDBs, simulator binaries, C++ build directories and waveforms. The per-file manifest SHA-256 is `868769500f272e8e8cd05302ee87f519a6c5e45f8429bafbf9151f87cc8d5c25`.
