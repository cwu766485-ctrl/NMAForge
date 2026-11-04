# R308 — Published Candidate RTL Checker-Sensitivity Campaign

**Result:** PASS, 8/8 temporary real-RTL mutants were detected by their intended Compute Cluster Checker. This demonstrates checker sensitivity only; it does not claim design correctness or close any Requirement by itself.

## Frozen source and run

| Item | Value |
|---|---|
| Candidate HEAD | `25752497b5c4a6adc48d2d7a1c4ad4dccf9b9afa` |
| Candidate tree | `40d70106cd94c8fd4c2a0cb386ab6680917cae33` |
| RTL/DV code/test tree | `48b0f4935ca4ae809c96d9f529be61a5bfb1312a` (same as R307; no RTL/DV changes) |
| Run ID / seed | `R308-RTL-MUTATION-8X-20261104` / `20261025` |
| Tool | Synopsys VCS V-2023.12-SP1_Full64 |
| Command | `make -C dv/uvm/sim uvm_compute_cluster_dut_mutation COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r308_mutation_25752497_20261104 VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` |
| Logs archive | `/tmp/nmaforge_r308_mutation_25752497_20261104_logs.tar.gz` |
| Archive SHA-256 | `6996e7c22506b392be14b16912d73d35dba1865c37646b0933000345754ea925` |

The target creates temporary mutated source copies under `/tmp`; it does not patch product source files. Each mutant was compiled and run against the real UVM testbench. The designated Checker was required to report the expected defect, and the runner rejects any mutant that reaches the normal PASS marker. All eight compile log pairs contain zero `Warning-`, `Error-`, and `[TFIPC]` diagnostics. The archive contains text logs and summaries only, not simulator binaries, object trees, or VDBs.

## Mutation results and Requirement evidence

| Mutation | Intended Checker observed | Related Requirement evidence | Disposition |
|---|---|---|---|
| Address offset | `CLUSTER_MEMORY_UNKNOWN` | `REQ-PC-006` | Sensitivity proven; functional memory/fault scope remains PARTIAL |
| Write-data bit flip | `CLUSTER_GOLDEN` | `REQ-PC-006` | Sensitivity proven; functional memory/fault scope remains PARTIAL |
| Response-owner rotation | `CLUSTER_ENGINE_RESPONSE_OWNER` | `REQ-PC-007` | Sensitivity proven; full owner/fault/concurrency scope remains PARTIAL |
| Matrix WSTRB corruption | `CLUSTER_MATRIX_WSTRB` | `REQ-CL-010`, `REQ-CL-015`, `REQ-PC-006` | Sensitivity proven; legal descriptor and complete Matrix/system scope remain PARTIAL |
| Completion error-code corruption | `CLUSTER_COMPLETION_ERROR_CODE` | `REQ-CL-027` | Sensitivity proven; full error ABI and priority matrix remains PARTIAL |
| Missing Done | `CLUSTER_MISSING_DONE` | `REQ-CL-019`, `REQ-CL-027` | Sensitivity proven; full completion lifecycle contract remains PARTIAL |
| Duplicate Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | `REQ-CL-019`, `REQ-CL-027` | Sensitivity proven; full completion lifecycle contract remains PARTIAL |
| Stalled request payload mutation | `CLUSTER_REQUEST_STABILITY` | `REQ-CL-006` | Sensitivity proven; broader legal request/fault/reset/progress scope remains PARTIAL |

The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; no row is promoted by this campaign and `CL-DV-v1.0` remains **HOLD**. See the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) and the [R307 exact-candidate replay](COMPUTE_CLUSTER_PUBLISHED_HEAD_REPLAY_R307_2026-11-04.md).
