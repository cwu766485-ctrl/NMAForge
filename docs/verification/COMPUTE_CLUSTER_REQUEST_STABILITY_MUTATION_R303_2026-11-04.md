# Compute Cluster Request-Stability Checker Mutation — R303

**Result:** PASS for the declared mutation campaign (8/8); no Requirement is promoted. `REQ-CL-006` and `CL-DV-v1.0` remain **PARTIAL** and **HOLD**.

## Candidate and run

| Item | Evidence |
|---|---|
| Fixed source/test commit | `fed63427b3d00e66a4cce2c01771dc762e393015` |
| Tree | `b00a1e755e9df9490694e42e9bb4dd21df800b84` |
| Base | Published closeout SHA `2b72a1cc8b60b69e7be353df7fcb296a47f9da37`; frozen R158 ancestor `8e3735e930f01c4a6bbb6a79251e153611dfcda2` |
| Run ID | `R303-STALL-PAYLOAD-MUTATION-CLEAN-20261104` |
| Test | `uvm_compute_cluster_dut_mutation`, seed `20261025` |
| Tool | Synopsys VCS `V-2023.12-SP1_Full64` |
| Execution | Detached clean worktree `/tmp/nmaforge_r303_clean_fed6342`; 8/8 temporary RTL mutants caught by their assigned Checker |
| Compile diagnostics | Zero `Warning-`, `Error-`, or `[TFIPC]` lines across eight compile logs |
| Logs archive | `/tmp/nmaforge_r303_clean_mutation_fed6342_logs.tar.gz`; SHA-256 `a5bd0596070bf0c61d4883c1522a9997a818582e7931dc40c08ce05d1d385263` |

Command:

```sh
python3 dv/uvm/sim/run_compute_cluster_dut_mutations.py \
  --out /tmp/nmaforge_r303_clean_mutation_fed6342 \
  --vcs-home /opt/Synopsys/vcs/V-2023.12-SP1
```

The added `stalled_request_payload` mutation changes the KV engine's request address for one sampled cycle only after a valid request has remained unaccepted for at least four cycles. The address returns to its specified value before acceptance. The passive request-stability Checker reports the expected `CLUSTER_REQUEST_STABILITY` failure; the run records exactly two violation observations for the address change and restoration. It does not change product RTL or depend on a broken accepted transfer.

| Mutation | Assigned Checker observed |
|---|---|
| Address | `CLUSTER_MEMORY_UNKNOWN` |
| Data | `CLUSTER_GOLDEN` |
| Response Owner | `CLUSTER_ENGINE_RESPONSE_OWNER` |
| WSTRB | `CLUSTER_MATRIX_WSTRB` |
| Completion Error | `CLUSTER_COMPLETION_ERROR_CODE` |
| Missing Done | `CLUSTER_MISSING_DONE` |
| Duplicate Done | `CLUSTER_DONE_WITHOUT_ACTIVE` |
| Stalled Request Payload | `CLUSTER_REQUEST_STABILITY` |

Mutation runs intentionally terminate on the expected Checker error/fatal; those expected messages are not clean functional-test severity. This is checker-sensitivity evidence, not a positive UVM regression or full mutation-space closure. The broad legal requester × fault × phase × reset × backpressure intersections remain open, so `REQ-CL-006` stays PARTIAL and no sign-off claim changes.
