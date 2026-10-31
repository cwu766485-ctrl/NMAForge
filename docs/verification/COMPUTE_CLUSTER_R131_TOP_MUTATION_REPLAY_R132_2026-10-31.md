# R131 Exact-SHA Top Smoke and Mutation Replay — R132

**Date:** 2026-10-31  
**Run ID:** `R132-R131-TOP-SMOKE-MUTATION-20261031`  
**Executed source SHA:** `207cc3896cb635ff04e7095fc18c435080507724`  
**Source tree:** `caed517e162270fc2f64beb5382fecdccb651bd5`  
**Product RTL/SPEC:** unchanged; this is supplemental verification on R131 code.  
**Tools:** VCS/URG `V-2023.12-SP1`; UVM 1.2.

## Top Smoke

From `/tmp/nmaforge_r131_clean_207cc38/dv/subsystem/top_smoke/sim`:

```sh
make ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345 \
  AI_CLUSTER_COV_RUN=/tmp/nmaforge_r131_top_smoke_cov_20261031
```

The mapper precheck passed with 86 descriptors and 60 tensors. VCS completed the 20-case Top Smoke with `TEST PASS`; the log ends with the owned command-fetch response check and reset recovery idle check. This is a Top Smoke result, not a complete NPU model-inference validation.

## Checker-sensitivity mutation campaign

From `/tmp/nmaforge_r131_clean_207cc38/dv/uvm/sim`:

```sh
make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r131_mutation_build_20261031 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r131_mutation_20261031
```

Result: `COMPUTE_CLUSTER_MUTATION_CAMPAIGN_PASS`, 28/28. Every run's log contains the injected mutation, the expected checker marker, and the expected nonzero UVM error that demonstrates checker sensitivity. The Make target verified the checker name for each run:

| Mutation | Expected checker |
|---|---|
| Address | `matrix_request_address` |
| Data | `memory_data` |
| Response owner | `response_owner_route` |
| WSTRB | `matrix_write_mask` |
| Completion error code | `completion_error_code` |
| Write after error | `write_after_error_prefix` |
| Response epoch | `response_epoch` |
| Done / Missing Done / Duplicate Done × engines 0–6 | `engine_done_lifecycle` |

These are passive-observation/checker mutations. They verify the listed checkers respond to injected monitor-side corruption; they are not DUT fault-injection coverage and do not prove every system fault scenario.

## Evidence and disposition

Generated logs are outside the repository:

- Top smoke compile log: `/tmp/nmaforge_r131_clean_207cc38/dv/subsystem/top_smoke/sim/ai_comp.log`, SHA-256 `e9f285c60f0425acf4a2a6b4595f42710cb8141db61e1d695906cffd2e9f7874`.
- Top smoke run log: `/tmp/nmaforge_r131_clean_207cc38/dv/subsystem/top_smoke/sim/ai_accel_smoke.log`, SHA-256 `1308fec8a95ad84b31337bfc4995731abb712940ab657a28dd8168431c52c18b`.
- Mutation compile log: `/tmp/nmaforge_r131_mutation_build_20261031/compile.log`, SHA-256 `f95bff510ad10149f4171af662fd25bd940a27f5bc923f6678978b6017624a10`.
- 28 individual mutation logs and their SHA-256 values: `/tmp/nmaforge_r131_mutation_20261031/SHA256SUMS`, manifest SHA-256 `0924a3714a1f6e61c3f80f32a5d76e934139774ef3b3ac107f3cf8752a2411ae`.

R132 closes the R131 report's `NOT_RUN` status for Top Smoke and the named checker-sensitivity campaign at the exact R131 source SHA. It does not close uncovered legal Engine × Fault × Phase × Reset combinations, mixed functional/code coverage, or any additional requirement. The RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.
