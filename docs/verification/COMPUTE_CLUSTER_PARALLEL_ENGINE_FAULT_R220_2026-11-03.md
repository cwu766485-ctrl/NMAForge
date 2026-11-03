# R220: Matrix parity failure during seven-engine execution

**Date:** 2026-11-03  
**Published test candidate:** `decc918e238f5ff153677c8f6cb2c3d3dd30ee18`  
**Source tree:** `36a0d2efe257e02fb3fbaced91c5f8a2b13f7381`  
**Product RTL/SPEC:** unchanged from the published parent `61e7a1a9dcbf756718f1bf5823c1d5c240ea6fc5`  
**Tools:** VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`

## Change

Added a directed production-top UVM scenario after the existing seven-engine
Golden execution. It launches the same seven legal engine workloads through
CMDQ, injects a Matrix input parity fault while the other engines are active,
and checks:

- Matrix retires with `ERR_PARITY` (`0x52`) and does not alter its output
  sentinel.
- All six other engines complete successfully; their completion result and
  element fields and full output images match independent expected values.
- All seven completion task IDs and statuses map to the correct engine owner.
- The observed Matrix overlap mask is `1110111`, maximum active-engine count is
  seven, and compute-request backpressure is nonzero.
- The focused `engine_parallel_fault_cg` bin is sampled only after those checks
  pass. The regression Makefile requires this pass marker on every seed.

The error completion's result and element fields are not defined by the
applicable contract, so the checker intentionally does not assert values for
those fields. It checks the specified error status and separately verifies no
Matrix writeback. No product RTL was changed.

## Results

The three-seed real-top regression passed on `20261025`, `20261026`, and
`20261027`. Each run reports the focused point at `1/1` and `100.0%`, overlap
mask `1110111`, maximum active engines `7`, request-backpressure delta `2338`,
and UVM severity `0/0/0`.

The existing 16-seed mixed-precision/DDR/AXI regression also passed. A combined
URG merge of the 3 Compute Cluster and 16 mixed E2E runs contains 27 declared
functional covergroups; all 27 are at `100.00%`. This is declared functional
covergroup coverage only. Raw RTL line/condition/FSM/branch coverage remains
`73.95/69.39/46.69/64.95%`. Assertions have 20/22 real successes, zero
failures/incomplete, and two UVM RAL internal properties without attempts; the
three AXI stall cover properties match 3/3.

Top Smoke passed, including the mapper check (`86` descriptors, `60` tensors).
Its existing `LOOP-REROLL-ENABLED` fixture warning remains visible.

## Reproduction

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r220e_parallel_fault_20261103 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r220e_mixed_cov_20261103

make -C dv/subsystem/top_smoke/sim ai_smoke
```

The combined URG input list and invocation are preserved in
`combined_urg/dashboard.txt` in the logs-only archive.

- Logs-only evidence archive: `/tmp/nmaforge_r220_evidence_20261103.tar.gz`
- Archive SHA-256: `945b88fbcca863f56ef482853a0763644a8cb8ea5797f2910725ea72b931a72a`
- File manifest SHA-256: `6c91611be40731c6c56ac5c635694cf32d9671ae77851d8654d9eb9498f5f4a5`

## Requirement and sign-off impact

This closes one specific parallel Matrix-parity recovery point and improves
evidence for `REQ-CL-017/019/027` and `REQ-PC-006/007`. It does not close the
broader legal Engine × Fault × Phase × Reset/backpressure matrix or all
production requester/response-owner interactions. No requirement disposition
is promoted: the 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and
`CL-DV-v1.0` remains **HOLD**. The 27/27 result must not be read as raw RTL
coverage closure or complete v1.0 sign-off.
