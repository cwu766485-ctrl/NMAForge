# Real CMDQ Scalar INT8 Maximum-Length VDOT — R299

## Result

R299 exercises the maximum 16-bit VDOT length through the real descriptor queue, validator, dispatcher, Scalar engine, completion queue, and scratchpad image. It closes the specific top-level maximum-length testpoint that R298 had covered only at the standalone core. It does not close all of `REQ-CL-020` or Compute Cluster sign-off.

The fixed code/test SHA is `25398a29f8678b0bf1b6a1638d0711334e6e8a2e`, tree `01441cb22cbdb1d3feeeb0ad88bf229089f0078e`; the GitHub branch contains the equivalent tree at commit `8f60d4f64d19f1b4be8f68e3c99d2bef236f0b53`. The three-seed replay ran from a detached clean worktree at the fixed local SHA.

The test initializes all 65,535 packed input words at `0x00010000` through `0x0004fffc` to `0x80808080`, then submits real CMDQ opcode `0x10`, length `0xffff`, task ID `0x08b1`, with both operands aliasing that vector. The launch monitor checks the dispatched opcode, both source addresses, destination, and exact length. An independent 64-bit accumulator computes `4,294,901,760`; the completion and destination image must contain the signed INT32 saturated value `0x7fffffff`. The test checks one completion, the first and last initialized input words, and an adjacent destination guard. All three seeds report 458,847 elapsed testbench cycles from pre-doorbell start through observed completion; this includes queue/polling overhead and is not a datapath benchmark.

The maximum legal command exceeded the old fixed 2,000-cycle top-level watchdog. The verification-only SVA now latches a finite bound for Scalar VDOT of `2,000 + length × 24` cycles (1,574,840 cycles at length 65,535); every other task retains the original 2,000-cycle bound. The UVM completion poll is also bounded at 8,192 intervals × 256 clocks. No product RTL or descriptor ABI changed.

## Fixed-SHA regression

Tool versions: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

| Test | Command | Result |
|---|---|---|
| Real seven-engine Compute Cluster UVM with maximum-length Scalar CMDQ case | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r299_clean_sha_25398a2 COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | 3/3 seeds pass; maximum VDOT completion and Golden pass on each; focused applicable Compute Cluster coverage 100.0% on each seed |
| UVM memory/response evidence, each seed | From the same run logs | 277,882 Memory Scoreboard words checked; mismatches, unknown reads, and stale epochs all 0. Owner ledger: 141,773 accepted, 141,753 checked, 20 reset-dropped; route/data/error mismatches 0 and pending 0. UVM warning/error/fatal `0/0/0` |
| Top Smoke | `make ai_smoke` from `dv/subsystem/top_smoke/sim` | Mapper precheck 86 descriptors / 60 tensors; `TEST PASS` |
| Fixed Top random regression | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` from `dv/subsystem/top_smoke/sim` | `TEST PASS` |

Coverage and assertion limits are explicit. The merged UVM URG report has 36 groups and an overall score of 84.38%; the Compute Cluster `cluster_cg` and the targeted Cluster functional groups are 100%. Three top AXI assertion properties are uncovered in this UVM workload (AR payload stability, AR 4-KiB boundary, AW payload stability), two AR/AW stall cover properties are unhit, and two UVM RAL internal assertions have no attempts. There are zero assertion failures or incomplete attempts. The compile log has no new warning and no `[TFIPC]` warning. Top Smoke retains the existing `[LOOP-REROLL-ENABLED]` fixture warning. These results do not claim 100% overall RTL/UVM coverage or assertion closure.

## Requirement disposition

`REQ-CL-020` remains `PASS-SCOPED`: the maximum encoded Scalar VDOT length now has a real CMDQ/dispatcher/completion proof, while broader opcode-specific shape, address-range, aliasing, and fault-phase limits remain outside this point. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The R299 run does not disposition remaining P0 gaps or promote a sign-off claim.

## Reproduction and evidence

- Run ID: `R299-CMDQ-SCALAR-VDOT-MAXLEN-CLEAN-3S-20261104`
- Clean worktree: `/tmp/nmaforge_r299_clean`
- Evidence archive: `/tmp/nmaforge_r299_evidence_20261104.tar.gz`
- Archive SHA-256: `9668db8c2f6822c6ba51c9385851eebc19a29251377e769031802acb9e9b71f9`
- Test source: `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh`
- Verification watchdog/SVA: `dv/subsystem/top_smoke/env/ai_accel_sva.sv`

The archive contains the UVM compile and per-seed logs, merged URG assertions/groups/dashboard, and captured Top Smoke and Top random-regression logs. Generated executables and raw coverage databases are excluded.
