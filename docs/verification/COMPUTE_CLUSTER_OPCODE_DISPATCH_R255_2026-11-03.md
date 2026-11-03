# Compute Cluster Opcode Dispatch Closure — R255

Date: 2026-11-03  
Tested commit/tree: `26a47132a2ad5d6c8c1fe36c8bc2d00183020e83` / `ed5ffb0dd340671623849038cc4ddb16e2cef4b2`  
Base closeout commit: `8cf80381d306c92fc2599239159faa6034267c2a`  
Product RTL/SPEC changes: none

## Result

The real-top CMDQ sequence launched all 24 normal opcodes in the frozen
Compute Cluster opcode table: `0x10–0x17`, `0x20/0x21`, `0x30–0x39`,
`0x43/0x44`, and `0x50/0x51`. At each observed launch, an independent SPEC
mapping was compared with the seven actual engine `start` pins. Exactly the
expected one-hot engine started for each opcode. Every descriptor was accepted,
completed with normal status, and retired with all engines idle.

The focused `opcode_dispatch_cg` has 24 user bins. Each bin hit once per seed;
merged URG reports 24/24 covered, 0 uncovered, 100%. This closes the exact
normal opcode-to-engine selection contract in `REQ-CL-002`. It is not numeric
Golden coverage for every opcode: `REQ-CL-015` and per-engine shape, numerical,
fault, and descriptor-boundary coverage remain separately scoped.

## Execution Evidence

| Item | Evidence |
|---|---|
| Test ID | `TC-CL-R255-OPCODE-DISPATCH-24` |
| Run ID | `R255-COMPUTE-CLUSTER-OPCODE-DISPATCH-CLEAN-3S-20261103` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Checker | `expected_engine_for_dispatch_opcode()` against hierarchical actual `engine_start_select[6:0]`; launch opcode, exactly-one launch, completion owner/status, and idle-at-retirement checks |
| Focused coverage | 24/24 per seed; merged URG 24/24, 100%; every opcode bin count is 3 |
| UVM severity | 0 warnings, 0 errors, 0 fatals per seed |
| Memory image | 95,025 words checked/seed; 0 mismatch, 0 unknown read, 0 stale epoch |
| Response owner ledger | 6,137 accepted, 6,117 checked, 20 reset-dropped, 0 route/data/error mismatch, 0 pending/seed |
| Tool versions | VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |

The tests ran from a detached clean worktree at the tested commit. Exact command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_opcode_dispatch_final_run_20261103 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Each seed log contains `CLUSTER_OPCODE_DISPATCH_PASS` and
`COMPUTE_CLUSTER_REAL_UVM_PASS`. The focused group details are in
`urg_merged/grpinfo.txt`.

Evidence archive (compile log, three seed logs, and merged URG `grpinfo.txt`):
`/tmp/nmaforge_opcode_dispatch_r255_evidence_final_20261103.tar.gz`  
SHA-256: `9bb5d14b360462378ac54301e5eab458e683af999c2903fc3d857fba702f5491`

## Requirement Disposition

| Requirement | Status | Evidence / remaining boundary |
|---|---|---|
| `REQ-CL-002` | `PASS-SCOPED` | All 24 legal normal opcodes launch exactly the SPEC-selected engine through the real CMDQ path. |
| `REQ-CL-015` | `PARTIAL` | This run checks successful retirement but does not compare every operation's complete numerical output against a per-opcode Golden. |
| `OPEN-CL-002` | Open | Per-engine maximum legal shapes, stride/alias rules, and remaining address-overflow boundaries are not closed by opcode dispatch. |

The aggregate Requirement table moves from 24 `PASS-SCOPED` / 14 `PARTIAL` to
25 `PASS-SCOPED` / 13 `PARTIAL`. `CL-DV-v1.0` remains **HOLD**; this result does
not constitute Compute Cluster sign-off.
