# R207 — FP single-result reset before completion retirement — 2026-11-02

## Fixed candidate and scope

- Test commit: `40b11572ca85ca67ef8ee54e19540a8dd2b42359` (`dv: cover FP single-result reset before retirement`).
- Test tree: `d542977155a9c80beec2a65509c2f3928f930baa`.
- UVM/mutation checkout: detached clean test tree `/tmp/nmaforge_r207_fp_reset_clean` at `d542977155a9c80beec2a65509c2f3928f930baa`.
- Top Smoke/seeded Top ran from documentation-only descendant `fffa1d1` (tree `c4ac33bc529ca6cb61717aa1792bad7f7097465a`); `rtl/` and `dv/` match the tested tree.
- Product RTL comparison: `git diff f87acc9bca3b3ecece385fadfd5623de6837ea8d -- rtl` is empty; no RTL or SPEC was changed.
- Tools: Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, UVM 1.2.
- Run IDs: `R207-FP-SINGLE-WRITE-RESET-CLEAN-3S-20261102`, `R207-MIXED-E2E-COV-16S-20261102`, `R207-DUT-MUTATION-7-20261102`.

This adds one legal reset point for a single-result FP operation. The BF16 `0x50` task computes 128 products of `1.0 × 1.0`, whose FP32 Golden result is `128.0` (`0x43000000`). The sequence observes all 128 accepted reads returned and the only result word accepted and committed while the engine is still busy; it then asserts shared reset before completion retirement. It checks the preserved result image, suppression of the old completion, no old-epoch writes/responses after reset release, and a fresh-epoch Golden task. This is a sole-result reset cut, not a partial output prefix.

## Results

| Gate | Result |
|---|---|
| Real-top Compute Cluster UVM | **PASS**, seeds `20261025/20261026/20261027`; the required `[CLUSTER_FP_RESET_SINGLE_WRITE_PASS]` marker hits on all three. UVM warning/error/fatal is `0/0/0` per seed. |
| Focused reset bins | **6/6 per seed**, including busy, sole result accepted, quiet reset/release, old completion suppression/result preservation, and new-epoch recovery. |
| Memory Scoreboard | Each seed checks 69,944 words from 64,051 writes; zero mismatch/unknown read/stale epoch. |
| Response-owner ledger | Each seed: 3,103 accepted, 3,084 checked, 19 reset-dropped; zero route/data/error mismatch and no pending responses. |
| Mixed E2E/AXI regression | **PASS**, 16 seeds `20261014, 712345, 987654, 20261015..20261027`; each required `[MIXED_E2E_PASS]` marker and UVM `0/0/0`. |
| Combined URG functional groups | **22/22 declared groups at 100.00%**, merging the 3 Cluster and 16 mixed E2E seed VDBs. This number is the declared covergroup score, not requirement or all-code coverage. |
| Assertions and cover properties | 20/22 assertions have real successes; 0 failures and 0 incomplete. The two no-attempt properties are UVM RAL `do_read`/`do_write` internals. All 3 AXI stall cover properties match. |
| Raw RTL/test coverage | Line 73.70%, condition 68.72%, FSM 46.69%, branch 64.70%; assertion score 92.00%. These remain below full code coverage. |
| Top Smoke / seeded Top | **PASS** at the documentation-only descendant with identical RTL/DV sources. Mapper reports 86 descriptors / 60 tensors; `ai_smoke` passes with 4 random cases, then `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` passes. The existing fixture warning `[LOOP-REROLL-ENABLED]` remains visible. |
| Real RTL mutation | **7/7 detected** by their assigned checker: Address→`CLUSTER_MEMORY_UNKNOWN`, Data→`CLUSTER_GOLDEN`, Response Owner→`CLUSTER_ENGINE_RESPONSE_OWNER`, WSTRB→`CLUSTER_MATRIX_WSTRB`, Completion Error→`CLUSTER_COMPLETION_ERROR_CODE`, Missing Done→`CLUSTER_MISSING_DONE`, Duplicate Done→`CLUSTER_DONE_WITHOUT_ACTIVE`. |
| Compile diagnostics | Cluster and all seven mutation compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. |

The test does not alter the already accepted sole output word after reset; it verifies that no additional old-epoch write/response leaks through and that completion is not retired from the reset task. The subsequent task demonstrates recovery and result correctness.

## Reproduction

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r207_clean_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r207_mixed_cov \
  MIXED_E2E_COV_SEEDS='20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027' \
  VCS_UVM='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
python3 dv/uvm/sim/run_compute_cluster_dut_mutations.py \
  --out /tmp/nmaforge_r207_clean_mutations \
  --vcs-home /tmp/nmaforge_vcs_home_linux_alias

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_smoke \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  SEED=20261025 AI_RANDOM_CASES=4 AI_SEED=12345

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_run \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=12345
```

The final 19-database URG merge is reproduced by the full input list recorded in the archived `combined_urg/dashboard.txt` and `RUN_MANIFEST.txt`.

## Requirement traceability and disposition

| Requirement | Disposition | Added bounded evidence | Run / seeds |
|---|---|---|---|
| `REQ-CL-017` | PARTIAL (unchanged) | Reset after the single FP result write; old-epoch output/response quiet checks and fresh-task recovery | `R207-FP-SINGLE-WRITE-RESET-CLEAN-3S-20261102`; `20261025/26/27` |
| `REQ-CL-018` | PARTIAL (unchanged) | Six focused reset/epoch bins per seed; old completion suppressed | Same run / seeds |
| `REQ-CL-019` | PARTIAL (unchanged) | Completion-tail sentinel and no-retirement check for reset task; new task completes | Same run / seeds |
| `REQ-CL-027` | PARTIAL (unchanged) | BF16 numeric Golden and task/completion attribution | Same run / seeds |
| `REQ-PC-006` | PARTIAL (unchanged) | Full Memory Scoreboard and output image/epoch checks | Same run / seeds |
| `REQ-PC-007` | PARTIAL (unchanged) | Real-top response-owner ledger; no route/data/error mismatch or pending response | Same run / seeds |

No RTM disposition is promoted. The complete 38-row matrix remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**. The broader production requester × fault × phase × reset × backpressure cross, Matrix FSM residuals, and remaining requirement-specific contract gaps are still open. Top Smoke and the 20-case seeded Top are now PASS at the documentation-only descendant tree with identical RTL/DV inputs; the Smoke compile retains the existing `[LOOP-REROLL-ENABLED]` fixture warning. Existing benchmark evidence is reported at its own fixed source/test SHA and is not relabeled as an R207 benchmark.

Text logs, compile logs, mutation evidence and URG reports are archived outside the repository at `/tmp/nmaforge_r207_fp_single_write_evidence.tar.gz`, SHA-256 `9a949ad380e1e32eb6d8bb469472e586864944dd7561e9a79fd10765ae073cb6`. VDBs, simulator executables, compiler directories, waveforms and license configuration are excluded.
