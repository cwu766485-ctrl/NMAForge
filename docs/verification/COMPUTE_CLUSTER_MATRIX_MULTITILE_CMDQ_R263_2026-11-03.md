# Compute Cluster Matrix Multi-Tile CMDQ Evidence — R263

**Result:** PASS for the declared 32×32×64 INT8 GEMM point; `REQ-CL-015` remains `PARTIAL`.

## Frozen candidate and run

| Item | Evidence |
|---|---|
| Code/test SHA | `c57216edbbd53f545a3a30c7f1ffa35935a705a5` |
| Tree SHA | `a9473130bf208a759139cc1c3d09cd8231d2cb9b` |
| Product RTL | Unchanged by R263; Matrix consumes the existing ABI v7 Tensor GEMM descriptor (`0x30`). |
| Test ID / Run ID | `TC-CL-R263-MATRIX-CMDQ-MULTITILE` / `R263-MATRIX-MULTITILE-CLEAN-3S-C57216E-20261103` |
| Tools | Synopsys VCS / URG `V-2023.12-SP1_Full64` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Clean output | `/tmp/nmaforge_r263_c57216e/uvm` |

Command, run from the clean committed worktree at the code/test SHA above:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r263_c57216e/uvm \
  COMPUTE_CLUSTER_UVM_BASE_OUT=/tmp/nmaforge_r263_c57216e/uvm_base \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The VCS compile completed with 0 errors and 0 warnings. The full existing real-top Compute Cluster regression and all mandatory Makefile log gates passed on all three seeds. Each run reported UVM warning/error/fatal `0/0/0`, checked 96,595 Memory Scoreboard words with zero mismatch, unknown read, or stale epoch, and drained the response-owner ledger (`accepted=6139`, `checked=6119`, `reset_dropped=20`, `pending=0`).

## Directed testpoint

The sequence submits a legal real CMDQ Matrix descriptor with M=32, N=32 and K=64. M and N span two 16×16 Array tiles each. It independently generates signed INT8 operands, packs them into the existing 4×4 tile-major SPAD layout, and computes a signed INT32 software Golden. The checker compares all 1,024 output words, the completion task/status/result/element count, and sentinels immediately before and after the output image.

All three seeds pass with 1,051 doorbell-to-completion cycles, 1,024/1,024 Golden outputs, one matching completion, and both output guards unchanged. The dedicated `matrix_multitile_shape_cg` bin `two_by_two_array_tiles` is 3/3 in merged URG (100%). The regression target requires the detailed PASS marker for each seed.

| Requirement | Disposition | Checker and observation | Run / seeds | Evidence |
|---|---|---|---|---|
| `REQ-CL-015` | `PARTIAL` | `TC-CL-R263-MATRIX-CMDQ-MULTITILE`; independent signed INT32 Golden, complete output image, completion owner/result/elements, two output guards, and `matrix_multitile_shape_cg` | `R263-MATRIX-MULTITILE-CLEAN-3S-C57216E-20261103`; `20261025/26/27` | Per-seed logs and merged URG in `/tmp/nmaforge_r263_matrix_multitile_clean3s_c57216e.tar.gz`; SHA-256 `cc54b4cdb7ef8ec1f8fae258f8af8bf4bde115c3089936f5f3acf9db81957381` |

This is one legal two-by-two Array-tile point, not the engine's maximum descriptor shape. It does not cover every opcode × shape × numeric class, unusual alignment/stride/alias contract, or broader fault/phase cross. It does not change the 38-row disposition (27 `PASS-SCOPED` / 11 `PARTIAL`) or the overall `CL-DV-v1.0` **HOLD** decision.
