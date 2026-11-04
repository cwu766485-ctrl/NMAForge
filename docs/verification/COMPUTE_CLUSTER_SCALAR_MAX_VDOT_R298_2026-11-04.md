# Scalar INT8 Maximum-Length VDOT — R298

## Result

The standalone Scalar INT8 core now has a reproducible boundary test at the maximum encoded VDOT length (`length=16'hffff`). At fixed code/test SHA `d64911bdf624b19ade908b51a55e6de798f43b65` (tree `bec012726cd3c84d5b82f99bd22876cb5ff9514e`), the test passes on three seeds in a detached clean worktree. The equivalent-tree GitHub commit is `b2c6e043c199b908e276b789ff841e7a2953848d`.

Each packed input word contains four signed `-128` lanes, and both operands read that word. Each K step therefore contributes `65,536`; the independent exact sum is `4,294,901,760`. The core returns the specified signed INT32 saturation value `0x7fffffff`. The checker observes exactly 131,070 accepted reads and 131,070 returned responses, verifies the output word at `0x0003fffc` (SPAD word 65,535), and confirms the response ledger is empty. The test does not force internal state or alter product RTL.

The maximum-length point is one more Scalar arithmetic boundary, not full `REQ-CL-020` closure: the block test does not validate real CMDQ descriptor dispatch at this length, and the broader opcode/shape/address and legal fault-phase requirements remain scoped as open work. The 38-row disposition remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Fixed-SHA replay

Tool: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

| Test | Command | Seeds | Result |
|---|---|---|---|
| Scalar maximum-length boundary | `make -C dv/block/compute/int8/sim numeric-regress SEED=<seed> OUT=/tmp/nmaforge_r298_clean_numeric_<seed>` | `20261025/26/27` | 3/3 pass; each reports `SCALAR_INT8_MAX_LENGTH_PASS`, 15 total direct-core cases, and drained reads |
| Real seven-engine Compute Cluster UVM | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r298_latest_clean/uvm COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` | `20261025/26/27` | 3/3 pass; per seed 146,796 Memory Scoreboard words, zero mismatch/unknown/stale; owner ledger 10,703 accepted / 10,683 checked / 20 reset-dropped, no route/data/error mismatch or pending response; UVM warning/error/fatal `0/0/0` |
| Top Smoke | `make ai_smoke SEED=20261025 AI_RANDOM_CASES=4 AI_SEED=12345` | `20261025` | mapper checks 86 descriptors / 60 tensors; `TEST PASS` |
| Fixed Top regression | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | `12345` | `TEST PASS` |

Top Smoke retains the existing VCS `[LOOP-REROLL-ENABLED]` fixture warning. No new UVM compile warning, error, or `[TFIPC]` warning was found.

## Evidence

- Logs-only archive: `/tmp/nmaforge_r298_evidence_20261104.tar.gz`
- SHA-256: `89b6d8d5c631d7760f5467b2d490a753792005aa9bef7038028e46bdb5aa08ab`
- Clean worktree: `/tmp/nmaforge_r298_scalar_max_clean`
- Test sources: `dv/block/compute/int8/tb/tb_ai_int8_numeric.sv`, `dv/block/compute/int8/sim/Makefile`

This archive contains the VCS compile/run logs and replay manifest; generated executables and coverage databases are excluded.
