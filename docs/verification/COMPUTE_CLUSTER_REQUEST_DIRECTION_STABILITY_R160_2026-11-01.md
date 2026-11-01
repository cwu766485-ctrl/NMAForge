# Compute Cluster request-direction stability gate — R160

**Result:** PASS for the declared legal request-direction stall classes. `REQ-CL-006` remains PARTIAL and `CL-DV-v1.0` remains HOLD.

## Frozen source and execution

- Exact tested source SHA: `e9b0b682a92145361302c17542b6e49a73fae57e`
- Source tree: `451b66ed5c820ebade584fe261de43c3c8d2cdc9`
- Published review branch source commit: `8aad6e1d334bfc94cf3d2fd29750d6b8152e0e8a` (tree-identical to the tested SHA)
- Worktree: `/tmp/nmaforge_r160_dir_stability_clean_e9b0b68`
- Run ID: `R160-UVM-DIRECTION-STABILITY-3S-20261101`
- Seeds: `20261025`, `20261026`, `20261027`
- Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`

The change is testbench-only. It records read/write direction only on actual stalled request cycles, checks the legal interface directions at the end of each real-top UVM run, and makes the directional marker mandatory in the default three-seed Make target. Product RTL, SPEC, and external interfaces are unchanged.

## Requirement and checker evidence

| Requirement | Disposition | Test ID | Checker / measured evidence | Run ID / Seed | Evidence |
|---|---|---|---|---|---|
| `REQ-CL-006` | PARTIAL | `TC-CL-R160-REQUEST-DIRECTION-STABILITY` | Passive payload stability monitor; per-requester direction masks; Make target requires the named pass marker. 17/17 legal direction classes observed per seed; no stability violations. | `R160-UVM-DIRECTION-STABILITY-3S-20261101`; `20261025/26/27` | `/tmp/nmaforge_r160_clean_e9b0b68_evidence_v2/uvm/seeds/seed_*/run.log`; archive `/tmp/nmaforge_r160_clean_e9b0b68_evidence_v2.tar.gz` |

The 17 declared classes are: read and write stalls on Scalar, FP, SFU, Conv, and KV (10); write stalls on the generic CNM request interface (1); Matrix banked read stall (1); Matrix Line write stall (1); and read stalls on four independent CNM lanes (4). CNM generic reads use the four lane interfaces. The Matrix generic request slot is unused by the production path and is not counted as a legal class. Direction encoding in the log is `{read,write}`; the generic engine masks are `{11,11,10,00,11,11,11}` and Matrix Line is `10`.

The 17/17 tally is a checker-enforced monitor-observation denominator, not a new URG covergroup.

Each seed logs:

```text
[CLUSTER_REQUEST_STABILITY_PASS] engine stalled mask=1110111 cycles={1505,1151,244,0,1900,1537,1855} direction={11,11,10,00,11,11,11}; Matrix banked checks=5196 fault-cancel=4, Matrix line checks=426 direction=10, CNM lane checks={1060,1060,1060,1060}
```

Three-seed full Compute Cluster UVM passes with UVM warning/error/fatal `0/0/0`. URG reports `cluster_cg` 64/64 (100%) within that declared group. The 16-group mixed URG score remains 64.86%; several unrelated DMA/AXI groups are unhit in this compute workload, so this is not global functional coverage closure.

## Reproduced commands and results

From the exact clean worktree:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r160_clean_e9b0b68_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'

make ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r160_clean_e9b0b68_mutation_build \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r160_clean_e9b0b68_mutations \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'
```

All three targets pass. Top Smoke reports mapper precheck for 86 descriptors/60 tensors and `TEST PASS` over 20 cases. The passive checker-sensitivity campaign catches all 28/28 named observation mutations with their expected checkers. The existing Top Smoke fixture emits `[LOOP-REROLL-ENABLED]`; the UVM compile has no `TFIPC`, `Warning-`, or `Error-` diagnostics. The campaign checks monitor sensitivity and is not a DUT RTL mutation score.

The logs-only archive contains the three UVM run logs, compile/URG summaries, Top Smoke logs, and 28 mutation logs. Its SHA-256 is `c02fad56df52cec017d81c2c4b10966724f9ac777dcbdfc23b0c65c5fa48acce`; the file manifest is `/tmp/nmaforge_r160_clean_e9b0b68_evidence_v2_sha256.txt`.

## Closure boundary

R160 strengthens the direction × requester portion of `REQ-CL-006` and `CL-COV-002`; it does not cover every stall phase, operation progress point, requester pair, memory-backpressure case, or fault/reset cross. It adds no legal Engine × Fault × Phase × Reset closure and does not disposition unrelated unhit global functional bins. The 38-row RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.

