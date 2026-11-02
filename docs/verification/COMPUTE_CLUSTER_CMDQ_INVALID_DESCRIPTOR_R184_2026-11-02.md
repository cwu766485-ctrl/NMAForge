# R184 CMDQ invalid-descriptor rejection evidence — 2026-11-02

## Fixed candidate

- Local clean-worktree code/test SHA: `15e3b5a608ae405fafbd551d26c975ab895c5d7c`.
- Tested tree: `28b0d8bd6adf4443711a7aab5c079317c2666848`.
- GitHub branch commit: `c07fb019753de8b23ed6150f4166a184a696042d` (same tree; published on `feat/compute-cluster-closeout-audit`).
- Product RTL and SPEC are unchanged. The change adds a real-top CMDQ invalid-descriptor matrix and a mandatory Make gate.
- Run IDs: `R184-CMDQ-INVALID-DESCRIPTOR-3S-20261102`, `R184-CHECKER-SENSITIVITY-28-20261102`, `R184-TOP-SMOKE-20-20261102`.

## Commands and environment

Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`, Rocky Linux under WSL2; license was available. Each test was run from a detached clean worktree at the fixed local SHA.

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r184_clean_run \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r184_clean_run \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r184_clean_mutations

cd dv/subsystem/top_smoke/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
make ai_smoke SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=12345
```

## Results

The new focused test rejects eight invalid descriptors submitted through the real CMDQ path: Scalar, CNM, Matrix, SFU, Conv, KV, Mixed FP, and Macro parent. Per seed, the checker requires `ERR_DESC`, ordered CMDQ head advancement to 8, no engine launch or compute/DMA request cycle, and all 16 sentinel words unchanged. Each seed reports 8/8 cases, 8/8 focused bins, and zero UVM warnings/errors/fatals. The `cluster_cg` group is 64/64.

Merged URG for this compute-only regression reports 71.89% all-group coverage; mixed DUT/testbench/UVM line, condition, FSM, branch, assertion, and group metrics are 70.11%, 64.65%, 45.04%, 60.31%, 72.00%, and 71.89%. These are not DUT-only or global closure figures. Seventeen of 22 assertion properties have real successes with no failures/incomplete; two are UVM RAL internals without attempts, and two of three AXI stall covers are not exercised by this compute-only workload.

The separately gated passive checker-sensitivity campaign passes 28/28 expected mutations. These are checker observations, not RTL fault injections and not an RTL mutation score. Top Smoke passes its mapper precheck (86 descriptors / 60 tensors) and 20 random cases; the existing `[LOOP-REROLL-ENABLED]` fixture warning remains.

## Disposition and limits

R184 adds real-CMDQ rejection evidence for `REQ-CL-002` and narrows the invalid-descriptor portion of `OPEN-CL-002`. It does not prove every opcode/engine pairing or every descriptor field/dimension/stride/alias/alignment/overflow/numeric boundary. No requirement status is promoted: the 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. This test does not close the outstanding legal fault × phase × engine × reset crosses, global memory ownership cases, or all functional/code/FSM coverage.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_r184_cmdq_invalid_descriptor_logs.tar.gz`.

SHA-256: `3c7cd394f9e267a3ffadf0ca69784a238182e2f637575a7ea85c94a2d249d1e4`.

The archive contains the run manifest, per-seed UVM logs, compile/URG summaries, all 28 mutation logs, Top Smoke logs, and checksums. It excludes generated VCS/VDB trees.
