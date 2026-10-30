# Compute Cluster all-engine Abort/drain replay — R83

**Date:** 2026-10-30
**Exact clean code/test SHA:** `8c758b7f864f9b3b8bc8999a7913f874929107ab`
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

The final GitHub-bound replay used a clean worktree based on the published closeout branch tip and tested the exact code/test SHA above.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r83_github_8c758b7_uvm
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
| UVM compile log | `/tmp/nmaforge_r83_github_8c758b7_uvm/compile.log` | `07210aab8e99648dd5f17b5e0b7b81f2fb3a90968f55cb50da267dede332b52c` |
| Seed `20261025` | `/tmp/nmaforge_r83_github_8c758b7_uvm/seed_20261025/run.log` | `313fea45897e99e9e7ceffa39af008154ae5e3bee8a2538563aae78d3e180a45` |
| Seed `20261026` | `/tmp/nmaforge_r83_github_8c758b7_uvm/seed_20261026/run.log` | `42d231608274df971be4dca48c18304f23a14f870eb044695cc2072588d656d5` |
| Seed `20261027` | `/tmp/nmaforge_r83_github_8c758b7_uvm/seed_20261027/run.log` | `d2123b9558b09596901db49a5541459b90ac3b6c4ac78ec291b4e25dff99a8f2` |
| URG merge log | `/tmp/nmaforge_r83_github_8c758b7_uvm/urg_merged.log` | `fbdca7a2a123fe4cf30422582038c003492e997546fcbdebeec51a3c34660276` |
| Top Smoke compile log | `/tmp/nmaforge_r83_github/dv/subsystem/top_smoke/sim/ai_comp.log` | `4704ee195d545850fff123a2a04f7006ce9f446c8839097d9b0f6785752a41fd` |
| Top Smoke run log | `/tmp/nmaforge_r83_github/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | `97ac26c7c84d1dc742a29df5bbebb0b1ee52320075ffb888f1a17d353ffce8f1` |

Manifest: `/tmp/nmaforge_r83_github_8c758b7_uvm/SHA256SUMS.log`, SHA-256 `cead3602f6e528a11d25e8a8961157c1386b3bb96c772733b29fab60fdb91a2c`.

## Coverage and limits

URG reports 17/22 assertion properties with real successes, zero failures and incomplete attempts. Three top AXI AR/AW properties have attempts but no success in this compute-only profile; two UVM RAL properties have no attempts. Of three top AXI cover properties, W stall-to-accept matches; AR and AW do not. These are retained dispositions and are not hidden by the Abort pass. Raw top code coverage from R81 remains line/condition/FSM/branch `86.38/72.92/44.59/75.36%`; it is not functional coverage.

R83 proves one accepted-read Abort/drain point per real engine at the production top. It does not complete the full Engine × Fault × Phase × Reset matrix, independently prove every opcode's accepted-write prefix for all Abort timings, exercise simultaneous Abort with every fault class, or qualify an external AXI fabric. No product RTL or SPEC change was made. Consequently no requirement status is promoted: the 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL, and `CL-DV-v1.0` remains **HOLD**.
