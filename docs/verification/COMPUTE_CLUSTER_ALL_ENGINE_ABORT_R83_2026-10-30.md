# Compute Cluster all-engine Abort/drain replay — R83

**Date:** 2026-10-30  
**Exact clean code/test SHA:** `120847b8c9b334179b6d667e7f500681c6d70b15`  
**Product RTL/SPEC baseline:** unchanged from product RTL `9d4e9abdba1f745644a485960620fa6bbc4979db`, Compute Cluster SPEC v1.8.  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Result

PASS for this directed accepted-read Abort/drain slice. Each of the seven real top-level engines ran one legal task, accepted at least one SPAD read, received software Abort, wrote one `ERR_ABORT` completion with the expected task ID, returned every accepted read response before completion, and reached idle. The per-engine counts below were identical in all three seeds `20261025`, `20261026`, and `20261027`:

| Engine | Opcode | Task ID | Accepted reads | Returned reads | Completion |
|---|---:|---:|---:|---:|---|
| Scalar INT8 | `0x10` | `0x0760` | 2 | 2 | `ERR_ABORT`, status/code `0x32` |
| Mixed FP | `0x50` | `0x0761` | 4 | 4 | `ERR_ABORT`, status/code `0x32` |
| CNM | `0x21` | `0x0762` | 16 lane reads | 16 lane responses | `ERR_ABORT`, status/code `0x32` |
| Matrix | `0x30` | `0x0763` | 4 banked reads | 4 banked responses | `ERR_ABORT`, status/code `0x32` |
| SFU | `0x35` | `0x0764` | 1 | 1 | `ERR_ABORT`, status/code `0x32` |
| Conv | `0x16` | `0x0765` | 2 | 2 | `ERR_ABORT`, status/code `0x32` |
| KV | `0x43` | `0x0766` | 2 | 2 | `ERR_ABORT`, status/code `0x32` |

The UVM regression gates seven per-engine case markers and the final `abort mask=1111111` marker on every seed. The independent memory scoreboard reports 14,736 writes, 17,249 checked words, zero mismatch, zero unknown reads, zero stale epoch responses, and zero orphan responses per seed. UVM warning/error/fatal counts are `0/0/0`. Existing focused applicable compute covergroup remains 100% (31/31 variables); the new seven-engine directed sweep is independently gated by its 7/7 run markers and is not represented as a new URG covergroup bin.

## Reproduction

The run used a detached clean worktree at the exact code/test SHA above.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r83_clean_120847b_uvm
```

The three seeds passed and URG merged the run databases. From the same clean worktree:

```sh
cd dv/subsystem/top_smoke/sim
make ai_smoke
```

Top Smoke printed `TEST PASS` after the 86-descriptor mapper precheck. Its compile retains the existing fixture warning `[LOOP-REROLL-ENABLED]`; no new RTL warning was introduced. The UVM compile log contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Evidence

| Artifact | Path | SHA-256 |
|---|---|---|
| UVM compile log | `/tmp/nmaforge_r83_clean_120847b_uvm/compile.log` | `bec6dee9c440c3dc7a58b2cb98995201c9567545e5e28f73f864cc552c4a8308` |
| Seed `20261025` | `/tmp/nmaforge_r83_clean_120847b_uvm/seed_20261025/run.log` | `616921754580b271d37c51e0aba40e05af47c0c3fa215b2e5e6b0b9ea8189bec` |
| Seed `20261026` | `/tmp/nmaforge_r83_clean_120847b_uvm/seed_20261026/run.log` | `25179efbe88f0d8b1858f6a2bac10fa9e6e19542d222aaab4785cd0a940b6c9a` |
| Seed `20261027` | `/tmp/nmaforge_r83_clean_120847b_uvm/seed_20261027/run.log` | `1ab53d7b45cab9eebf8a267451da16d8c5eba7516dd906b9e1f0b75afb1f41d5` |
| URG merge log | `/tmp/nmaforge_r83_clean_120847b_uvm/urg_merged.log` | `eb012c63c4c88f4f016c820ed4178eecb577a2866b479f0b38d98e1ad5298219` |
| Top Smoke compile log | `/tmp/nmaforge_r83_clean_120847b/dv/subsystem/top_smoke/sim/ai_comp.log` | `2427a140207075a0826c7be9609ad54db2fea03312cd2a23d4d22ac384d7cde9` |
| Top Smoke run log | `/tmp/nmaforge_r83_clean_120847b/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | `e9f3bcf88d005b8eb1e3159cf46222a15d52042e5e5f11ce2475acc9b16c721b` |

Manifest: `/tmp/nmaforge_r83_clean_120847b_uvm/SHA256SUMS.log`, SHA-256 `b951f0f9fb677732e0a7001823f16614843b1210c4a209242e711e21beff379a`.

## Coverage and limits

URG reports 17/22 assertion properties with real successes, zero failures and incomplete attempts. Three top AXI AR/AW properties have attempts but no success in this compute-only profile; two UVM RAL properties have no attempts. Of three top AXI cover properties, W stall-to-accept matches; AR and AW do not. These are retained dispositions and are not hidden by the Abort pass. Raw top code coverage from R81 remains line/condition/FSM/branch `86.38/72.92/44.59/75.36%`; it is not functional coverage.

R83 proves one accepted-read Abort/drain point per real engine at the production top. It does not complete the full Engine × Fault × Phase × Reset matrix, independently prove every opcode's accepted-write prefix for all Abort timings, exercise simultaneous Abort with every fault class, or qualify an external AXI fabric. No product RTL or SPEC change was made. Consequently no requirement status is promoted: the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL, and `CL-DV-v1.0` remains **HOLD**.
