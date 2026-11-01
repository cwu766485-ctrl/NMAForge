# Compute Cluster R156 clean replay addendum — R157

**Result: PASS for the named replay gates; Compute Cluster v1.0 remains HOLD.** R157 adds exact clean-worktree Top Smoke and checker-sensitivity replay to the R156 three-seed UVM result. It changes documentation only; RTL, SPEC, UVM tests, and build rules are unchanged from R156.

## Frozen identity

| Item | Identity |
|---|---|
| UVM/test source SHA | `96874695e7a5fa1865b1b9ad97e8546ff934b8d6` |
| UVM/test tree | `cf362140553abf17d9d2795cc80938adb94ec5c3` |
| Documentation-only candidate SHA | `f93ae080d8a8a4b308e47a3f37a1ffc52203ec26` |
| Documentation-only candidate tree | `f81c138da146d9df66175833afa6e09490a53373` |
| Tools | Synopsys VCS/URG `V-2023.12-SP1_Full64`; UVM 1.2; behavioral SPAD |

The Top Smoke and mutation targets ran in a detached clean worktree at the R156 documentation candidate. The previous three-seed Compute Cluster UVM regression ran in a detached clean worktree at the exact R156 test SHA. The only source/test difference is none: R156's later commit changes documentation only.

## Reproduction and results

| Gate | Command | Result |
|---|---|---|
| Top Smoke and seeded workload | `make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345` | PASS; mapper precheck `86 descriptors / 60 tensors`; 20 random cases; final `TEST PASS` |
| R156 UVM | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r156_clean_uvm COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'` | PASS on all three seeds; details and full scoreboard metrics in [R156 test report](COMPUTE_CLUSTER_MATRIX_PROTECTION_CNM_RESET_R156_2026-11-01.md) |
| Checker-sensitivity mutations | `make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r156_clean_mutation_build COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r156_clean_mutations VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'` | PASS, target exit 0; 28/28 injected observations caught by the expected Checker |

Mutation set: Address → `matrix_request_address`; Data → `memory_data`; Owner → `response_owner_route`; WSTRB → `matrix_write_mask`; Completion Error → `completion_error_code`; Write After Error → `write_after_error_prefix`; Response Epoch → `response_epoch`; and Done/Missing-Done/Duplicate-Done → `engine_done_lifecycle` on each of the seven engine bits. The UVM errors in these mutation logs are the expected checker detections; the Make target also verifies each injection marker, checker name, and nonzero UVM error.

The mutation compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Top Smoke retains the existing `[LOOP-REROLL-ENABLED]` workload-fixture warning. The standalone compute UVM does not exercise the AR/AW stall-to-accept coverpoints; its W cover matched once. Those are cover observations, not assertion failures, and remain workload/profile-specific evidence.

## Evidence archive

Logs-only replay archive, outside the repository: `/tmp/nmaforge_r156_clean_replay_logs.tar.gz`, SHA-256 `03b58803810bcbbded190d0fc66e04d9b712bc8ea92719ec626189ae8563c578`. It contains the Top Smoke compile/run transcript, mapper transcript, mutation compile transcript, all 28 individual mutation logs, and a command/result manifest. VCS executables and coverage databases are not included.

Selected transcript hashes:

| Artifact | SHA-256 |
|---|---|
| Mutation compile log | `ab001bf449755f1f398885a5dbf45e2da90666888bc6e6be65603aa84ff80143` |
| Top Smoke compile log | `3406ede6cf24402396aab4ad3a82e0aeb9d76cf4801e96a8cd7596a5068cdc60` |
| Top Smoke simulation log | `ffc50d32b2cbd4fb3da340790b534805ce296c51bd81c51d8d1ad8a48784ffdf` |
| Mapper precheck transcript | `6af6cfa98fe3803fda45e7ac72ed43dc256652784e7681dccefcd2118b28925c` |

## Sign-off disposition

R157 adds reproducibility evidence only. The 38-row RTM remains 24 `PASS-SCOPED`, 14 `PARTIAL`, 0 `BLOCKED_SPEC`, and 0 `NOT_RUN`; `CL-DV-v1.0` remains **HOLD**. In particular, checker sensitivity does not substitute for legal DUT fault-cross coverage. The remaining P0 work is still the legal production requester × fault × phase × Abort/Reset/backpressure space and its evidence-backed disposition; the enabled Matrix FSM's raw `49/53` remains profile-specific with the documented formal/test dispositions.
