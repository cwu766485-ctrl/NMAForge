# Compute Cluster Engine Request Wait Observation — R243

**Disposition:** supplemental evidence for `REQ-CL-014`; requirement remains `PARTIAL` and `CL-DV-v1.0` remains **HOLD**.

## Fixed identity and commands

| Item | Value |
|---|---|
| Tested local commit | `0d81c00f118b93396312f85bc05afd1298a69392` |
| Published same-tree commit | `29c470c62a89d8854574df970daaaf26d38946de` |
| Tested tree | `97f4a57aef5313a75a445d981d51a944188430e0` |
| Tools | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |
| Cluster run ID | `CL-COMPUTE-CLUSTER-ENGINE-WAIT-R243-3S-20261103` |
| Seeds | `20261025`, `20261026`, `20261027` |

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r243_wait_20261103 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261103 AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

## Results

All three real-top Compute Cluster UVM seeds passed. Each reported UVM warning/error/fatal counts `0/0/0`. The response-owner ledger reported 5,015 accepted reads, 4,995 checked responses, 20 reset-dropped reads, no route/data/error mismatches, and no pending responses. The Memory Scoreboard checked 92,871 words and 73,190 writes, with zero mismatch, unknown read, or stale epoch.

The passive monitor measured maximum consecutive `engine_req_valid && !engine_req_ready` spans by engine port as `{12,14,53,0,64,126,14}` cycles on every seed; stalled mask `1110111`. The regression gate checks the six ports expected to stall in this workload. This is observed traffic only: no downstream SRAM delay or arbitrary-ready pattern was injected, so the result does not establish a general starvation bound or close the full `REQ-CL-014` fairness clause.

Top Smoke passed: mapper precheck reported 86 descriptors and 60 tensors, then simulation reported `TEST PASS`. The existing VCS `[LOOP-REROLL-ENABLED]` compile warning remains visible. Cluster UVM compilation had no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. This run does not produce a new merged coverage claim; the declared-group and raw-code coverage references remain R238/R240.

## Evidence archive

Logs and manifest: `/tmp/nmaforge_r243_wait_evidence_20261103/`  
Archive: `/tmp/nmaforge_r243_wait_evidence_20261103.tar.gz`  
SHA-256: `52ac4189e8da742ddf0882b797d92d9bca5f9870e83da359802f7995453d713f`

| Artifact | SHA-256 |
|---|---|
| Cluster compile log | `c58a31632e96ee79ab8c993e3955ac29200d886c9e8ddba9c6fe4f64cd5e1dc6` |
| Seed `20261025` run log | `beb9af46984f6d08ecd9e91869fd1ed25c5115ccab59a1b0f0d4cdeed7da26e6` |
| Seed `20261026` run log | `cf756ccb43cf84b97002d39c7bccf85938e2ced83833d82879409cb6ac2af186` |
| Seed `20261027` run log | `ca2206a49623ae90472910a0034c83aa71efa6699f0f1a97e1bd66ed2f4230ab` |
| URG merged log | `86f55b61a4b536950c54f35cde9f080ee04e5bf1605d27f4c22cedf88d8b7e90` |
| Top Smoke compile log | `b1fd5a2511dbd1894e8a504f5d1da24001e7e4f58493698b895e871990e52746` |
| Top Smoke simulation log | `69aadb6afa2759cae1b05c9202207ffc8ed62946017ae2dd36a7eccbaf734ee9` |

The implementation change is testbench-only: per-port wait counters and an explicit pass marker were added; product RTL was not modified. The published commit contains the same tested tree.
