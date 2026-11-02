# Compute Cluster Real RTL Mutation Campaign R212 — 2026-11-02

## Result

**PASS: 7/7 temporary RTL mutants were detected by their assigned production UVM checkers.** Each mutant compiled separately with Synopsys VCS `V-2023.12-SP1_Full64`, ran the real `ai_compute_cluster_e2e_test` with seed `20261025`, emitted the expected checker marker, and did not reach `[COMPUTE_CLUSTER_REAL_UVM_PASS]`. The campaign script exited 0.

| Mutant | Deliberate temporary defect | Expected checker | Result |
|---|---|---|---|
| Address | Add 4 bytes to the selected SPAD request address in `ai_compute_spad_mux.v` | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| Data | Flip bit 0 of selected SPAD write data in `ai_compute_spad_mux.v` | `CLUSTER_GOLDEN` | Caught |
| Response Owner | Route the response valid/data/error to the next engine in `ai_compute_spad_mux.v` | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| WSTRB | Clear one byte lane in Matrix Line write strobe in `ai_tensor_matrix_core.v` | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion Error | Change successful completion error code from 0 to 1 in `ai_parallel_compute_dispatcher.v` | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Missing Done | Suppress Scalar `engine_done` in `ai_accel_compute_cluster.v` | `CLUSTER_MISSING_DONE` | Caught |
| Duplicate Done | Duplicate Scalar Done onto the KV engine bit in `ai_accel_compute_cluster.v` | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

## Reproduction and source identity

- Run ID: `R212-DUT-MUTATION-7-20261102`
- Test seed: `20261025`
- Executed command: `make uvm_compute_cluster_dut_mutation COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r211_dut_mutation_20261102`
- Tool: Synopsys VCS `V-2023.12-SP1_Full64`
- Published closeout code base: `54db4eefcba06f3af83bef1c76ffb62ea2d2c85f`; executable RTL/UVM/test inputs are identical to code commit `744d99716ce97f92912a4eda490eac27d2d9056a`.
- The mutations were applied only to temporary source copies under `/tmp`; repository RTL, UVM test sources, SPEC, and checkers were not changed for this campaign.
- Seven compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` compile diagnostics. UVM errors/fatals in each mutant run are the expected checker detections; the harness requires the exact checker marker and rejects a normal PASS marker.

## Limits

This is a targeted seven-case single-defect mutation campaign. It demonstrates checker sensitivity for representative address, data, owner, WSTRB, completion-error, missing-Done, and duplicate-Done defects. It is not an exhaustive mutation score and does not close the legal Engine × Fault × Phase × Reset/backpressure matrix. Requirement dispositions are unchanged; the full RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

Logs, mutant source copies, file lists, script, and summary are archived at `/tmp/nmaforge_r211_dut_mutation_evidence_20261102.tar.gz` (SHA-256 `7b594830689596be85e49f4cfc8e83261c5be11f5bf7f69700d68cb0d36eea9e`).
