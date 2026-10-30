# Compute Cluster Matrix accepted-write Abort prefix — R86

**Date:** 2026-10-30  
**Exact clean code/test SHA:** `3d6fe5c58631bdeb6333b6e3572f24eeba7da1ef`  
**Product RTL/SPEC baseline:** `9d4e9abdba1f745644a485960620fa6bbc4979db`; R86 changes only the UVM sequence and regression gate.  
**Run ID:** `CLUSTER-MATRIX-ABORT-WRITE-PREFIX-3S-3D6FE5C`  
**Tool:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Testpoint

The real Matrix engine executes a legal 4×4 INT8 GEMM tile with K=16 elements. The destination is 32-bit aligned and intentionally offset from a 16-byte boundary, exercising the SPEC v1.5 scalar-write fallback. Software Abort is issued after the first accepted scalar output write. An independent signed integer Golden checks every accepted output address/data as a contiguous row-major prefix and verifies every unaccepted destination word retains its sentinel. The monitor also requires no Matrix Line request, balances all accepted Matrix banked reads with owner-tagged responses, and checks `ERR_ABORT` completion.

All three seeds deterministically accept six of 16 scalar output words, drain eight accepted reads, and leave the ten-word suffix unchanged. This is one Matrix shape, alignment class, prefix length, and Abort phase. It does not establish aligned 128-bit Line abort prefixes, other Matrix shapes or prefix lengths, other engines' prefix contracts, or the full Engine × Fault × Phase × Reset matrix.

## Exact clean replay

Fresh detached worktree: `/tmp/nmaforge_r86_remote_3d6fe5c`, HEAD `3d6fe5c58631bdeb6333b6e3572f24eeba7da1ef`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r86_remote_3d6fe5c_uvm
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r86_remote_3d6fe5c_uvm \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r86_remote_3d6fe5c_mutation
```

UVM ran from the detached worktree root. Smoke and seeded top commands ran from `dv/subsystem/top_smoke/sim`. Mutation ran from the worktree root. All four commands exited 0. The top UVM seeds `20261025/26/27` each reported:

- `accepted_output_prefix=6/16`, `read_drain=8/8`, `line_fallback=1`, completion `ERR_ABORT`;
- independent memory scoreboard: 15,021 writes, 17,352 checked words, zero mismatch/unknown/stale responses;
- UVM warning/error/fatal `0/0/0`;
- focused applicable compute group `31/31`; Matrix prefix marker hit once per seed.

The 28-case passive checker-sensitivity campaign passes all 28 expected catches, including address, data, owner, WSTRB, completion error, post-error write, response epoch, and seven-engine Done/missing/duplicate Done. This is observation-checker sensitivity, not DUT RTL mutation coverage. The merged URG assertion report has 17/22 properties with real successes, zero failures/incomplete and five uncovered; two UVM RAL properties have no attempts. Its AXI cover properties match 1/3 (W only) in this compute workload. Top Smoke and the 20-case seeded top run both print `TEST PASS`; Top Smoke retains the existing fixture warning `[LOOP-REROLL-ENABLED]` at `ai_transformer_workload.svh:9`. UVM compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

## Evidence hashes

Generated simulator outputs remain under `/tmp` and are not committed.

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `3e8ce4e9149a708e976c14f242009083ee8ab7ec081254745c7dab56610da276` |
| Seed 20261025 run log | `87ec5dccc77d7f7c7fde48d13bc739c736054dc3c511169997cfbbaa30d1aef6` |
| Seed 20261026 run log | `801164eabd8dbf3b997a8685f8a8c38f9cfc231e321080d98d47e4bceaa374b5` |
| Seed 20261027 run log | `bbe524cf64e28ab0330fef89f22e8ff446bdd9d714a7c2e087de2da3b62474e1` |
| URG merge log | `7ac654286d22c471a21eebb466d36eefb5fb696a709718eb0950a0c68da721fb` |
| URG assertion report | `05f2f0725989b7d659e95f6cfaf41d0b8bbee34b478d511cd45cf4e2b0716d42` |
| URG dashboard | `3a3d98a8cdfb171fa18a3a1c3f7e5e84264de41e33817fcd2db652a2c4e64fc0` |
| Top Smoke compile log | `76592160818e7a5cbdb756d453f82c53c8663344050c5655452c57f267632b62` |
| Top Smoke run log | `33328c482525723602e814e1f63a34d1f48a4daa63ebd15ec3bff82b658eebe4` |
| 20-case seeded Top run log | `6f98ddb53d04dbcabcfe8eb0f8307364d258268fff95bbf5c79acf677f70317c` |
| Checker-sensitivity campaign output log | `44f1d5dadf94f46421e567d2e23f1618efa92150c5ce4825e80901c10a0301e3` |
| 28 mutation-log SHA manifest | `d2dec6ccd26fcb3c2f092bb10ec78e68c76bc84b3e8b8eac30eb5d8d3d718714` |

## Disposition

R86 adds one real-top Matrix scalar-fallback accepted-write-prefix point without changing product RTL, SPEC, or any requirement disposition. `REQ-CL-017`, `REQ-CL-019`, and broader Matrix output-contract requirements remain PARTIAL because aligned Line-path Abort, additional shapes/prefixes, other fault phases, and the full legal cross remain open. The 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains HOLD.
