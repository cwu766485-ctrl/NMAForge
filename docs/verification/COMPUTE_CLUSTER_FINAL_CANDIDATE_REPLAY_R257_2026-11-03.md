# Compute Cluster Final Candidate Replay — R257

**Date:** 2026-11-03  
**Decision:** reproducibility evidence only; `CL-DV-v1.0` remains **HOLD**.  
**Tested RTL/UVM content:** R256 commit `2f52008e5bbbc4051fa8f912082ef94d7069cc88`, tree `92f873219161c71368f235f3c1e2751191f32a66`.  
**Replay checkout:** detached clean docs commit `fba97870a85e3d8d7fe784f4b45120af15a9aade`, tree `505c71f6db156f7361753abccda31a39763e50a1`. The checkout differs from R256 only in documentation; the tested RTL, UVM, scripts, and source lists match the R256 code/test tree. The replay tree was byte-identical to published closeout branch head `5b707eea38baf816068ca5f7e7c87bb7852cf576` when checked.

## Runs

All runs used Synopsys VCS `V-2023.12-SP1_Full64`; mixed-coverage merging used URG from the same installation. Outputs were kept under `/tmp` and are not committed.

| Run | Command / configuration | Result |
|---|---|---|
| Seven-engine real-top Cluster UVM | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_fp16_cmdq_r256_clean_2f52008 VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` | PASS, 3/3 seeds; UVM severity 0/0/0; each seed checks 95,043 Memory Scoreboard words with zero mismatch/unknown/stale; owner ledger drains. Includes the R256 FP16 CMDQ numeric point. |
| Mixed-precision DDR/AXI E2E coverage | `make uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_SEEDS='20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027' MIXED_E2E_COV_OUT=/tmp/nmaforge_r257_mixed_cov_2f52008 VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg` | PASS, 16/16 seeds; zero UVM warning/error/fatal in each run. |
| Combined URG | `urg -full64 -dir <R256 compile.vdb> <three Cluster seed coverage.vdbs> <sixteen mixed seed coverage.vdbs> -format text -report /tmp/nmaforge_r257_combined_urg_2f52008` | PASS, 19 tests; 33/33 declared functional groups at 100%; 20/22 assertions have real successes, zero failures/incomplete, and the two no-attempt properties are UVM RAL internals. Three AXI stall-to-accept covers match. Combined hierarchy line/condition/FSM/branch/assert is 75.96/70.99/53.12/67.07/92.00%; this includes testbench/UVM hierarchy and is **not DUT-only closure**. |
| Top Smoke | `PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH make ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025` from `dv/subsystem/top_smoke/sim` | PASS; `TEST PASS`, mapper precheck reports 86 descriptors / 60 tensors. Existing fixture warning `[LOOP-REROLL-ENABLED]` remains. |
| Actual RTL mutation campaign | `make uvm_compute_cluster_dut_mutation COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r257_dut_mutations_2f52008 VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` from `dv/uvm/sim` | PASS, 7/7 temporary mutants detected by their expected checkers: Address, Data, Response Owner, WSTRB, Completion Error, Missing Done, Duplicate Done. This is checker-sensitivity evidence, not functional coverage closure. |

## Evidence archive

Logs-only archive: `/tmp/nmaforge_compute_cluster_r257_evidence_20261103.tar.gz`  
SHA-256: `d803e4209d805ba74a4a4f37a179d701de95f9b0e11652b8ff776f769e2e9ce3`  
The archive includes the manifest, per-seed logs, compile logs, URG text reports, Top Smoke logs, and mutation logs. It excludes VDBs, simulator binaries, and waveforms.

## Disposition and limits

The 38-row Execution RTM remains **25 PASS-SCOPED / 13 PARTIAL / 0 FAIL / 0 BLOCKED_SPEC / 0 NOT_RUN**. No requirement is promoted by this replay. Matrix enabled-profile FSM coverage remains 49/53; R249's formal guard dispositions and legal fallback are separately documented, while `REQ-CL-010` stays PARTIAL. Legal integrated Engine × Fault × Phase × Reset × Backpressure combinations, full descriptor boundaries and several requirement clauses remain open. Functional-group coverage at 100% does not mean code coverage or requirement closure is 100%.

This replay confirms that the R256 tested code/test content and the published closeout branch are reproducible for the listed gates. It does not establish arbitrary external-fabric reset behavior, ASIC PPA, whole-NPU sign-off, or a TinyNPU performance win. Keep `CL-DV-v1.0` on **HOLD** until each remaining requirement has an approved disposition and evidence.
