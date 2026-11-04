# Compute Cluster + mixed DDR/AXI combined coverage — R305

**Result:** The declared 19-run verification plan reaches 37/37 functional covergroups at 100%. The result closes the declared functional-group coverage gate for this plan, but does not close all clauses in the 38-row Requirement Traceability Matrix. `CL-DV-v1.0` remains **HOLD**.

## Fixed candidate and runs

| Item | Evidence |
|---|---|
| Published candidate tested | `e5cce9fdaf76b7ba01a04fa95721e35894a0beb8` |
| Candidate tree | `9c2f92c0244391700f1968e7c3882d0359473db6` |
| Worktree | New detached clean worktree; no tracked RTL, UVM, or test changes during the runs |
| VCS / URG | Synopsys VCS/URG `V-2023.12-SP1_Full64` |
| Compute Cluster run | `R305-COMPUTE-CLUSTER-3S-20261104`; seeds `20261025/26/27` |
| Mixed precision DDR/AXI run | `R305-MIXED-E2E-16S-20261104`; seeds `20261014,712345,987654,20261015..20261027` |
| Combined coverage run | `R305-COMBINED-URG-19RUN-20261104` |
| Logs-only archive | `/tmp/nmaforge_r305_evidence_e5cce9f.tar.gz`; SHA-256 `d8ba31f822f39550d8b610b705e37c4155f9d232fd90421b4598e519eb4e3235` |

## Commands

From `dv/uvm/sim`:

```sh
make uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r305_mixed_e5cce9f \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r305_cluster_e5cce9f \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The mixed-E2E target passed its per-seed checks for all six descriptor orders/layouts, four SPAD banks, six invalid-descriptor cases, FP16/BF16 K=1..4, all 16 length pairs, AXI AR/AW gaps, read/write response gaps, DMA SLVERR first/last-beat positions, reset, abort, watchdog, and recovery. Its gates require each declared mixed-E2E and AXI coverage group at 100%, AXI AR/AW/W stall covers to match, and design SVA to have real attempts/successes without failure/incomplete.

Combined URG was generated with VCS `urg -full64`, using the Compute Cluster compile database, its three seed databases, and all 16 mixed-E2E seed databases.

## Coverage and checker audit

| Measure | Result | Interpretation |
|---|---:|---|
| Declared functional covergroups | 37/37 at 100% | All groups in this 19-run plan meet their configured goals. This is not 37/38 Requirements and does not prove every legal requirement cross. |
| Combined URG line / condition / FSM / branch | 76.21 / 71.45 / 53.49 / 67.49% | Whole-top hierarchy includes DUT, assertions, testbench, and UVM code; not DUT-only closure. |
| Assertion properties with real successes | 20/22 | Zero assertion failures and zero incomplete properties. The two without attempts are UVM RAL internals `uvm_reg_map::do_read` and `do_write`; they are not DUT SVA ports. |
| Cover properties | 3/3 matched | No cover property is unhit in this merged plan. |
| UVM severity | 0 warnings / 0 errors / 0 fatals | Each of the 19 runs passes its target gate. |
| Compile diagnostics | 0 `Warning-`, `Error-`, or `[TFIPC]` | Both current-head VCS compile logs are clean for these diagnostics. |

The aggregate URG score is 76.77% and assertion score is 92.00%; neither is used as a requirement-closure percentage. The functional group total is 100%, while the 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`. The remaining partials still include wider production requester × fault × phase × reset/backpressure intersections, Matrix integration/FSM clauses, per-engine error contracts, full owner/memory-scope evidence, and comparable performance clauses. R305 therefore promotes no Requirement and does not authorize v1.0 sign-off. See the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md) for dispositions.
