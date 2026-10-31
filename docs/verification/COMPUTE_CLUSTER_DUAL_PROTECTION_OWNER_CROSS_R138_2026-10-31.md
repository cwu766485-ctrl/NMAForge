# Compute Cluster R138 — Matrix/CNM dual Protection owner cross

Date: 2026-10-31
Run ID: `R138-MATRIX-CNM-DUAL-PROTECTION-3S-20261031`

## Scope and source identity

R138 adds a legal real-top parallel CMDQ case in which Matrix and CNM are both active when CNM's denied output write is sampled, while Matrix separately reaches its denied Line writeback. Both engines must retire `ERR_PROTECTION` (`0x62`) in CMDQ order. The check verifies each denied address, engine activity, Matrix/CNM response counters, no response-route mismatch, both completion IDs/statuses, and every word in both destination sentinel images.

The test does not claim a same-cycle two-engine fault or define cross-engine error priority. The two Protection events occur at different operation phases within one overlapping parallel workload. Matrix operands and CNM operands remain readable; the CNM region is read-only (`PERM=0xD`) and Matrix's destination remains outside writable regions. Descriptor and completion regions remain legal.

The clean test-source commit is `3ac517c23338bfe07dad5563669a625f61471d33` (tree `46de8701e3ce91d4f6e038878b423d4385c919c8`). Product RTL and SPEC are unchanged from the existing candidate. Files changed for the test are `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh` and `dv/uvm/sim/Makefile`; the regression gate now requires the R138 marker for each seed.

## Execution

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r138_clean_replay_run_20261031 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

VCS: `V-2023.12-SP1_Full64`; URG: `V-2023.12-SP1`. The command exits 0 and the regression target reports `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS` for all three seeds. Compilation reports zero `Warning-`, `Error-`, `[TFIPC]`, and `Fatal` matches. Each run reports UVM warning/error/fatal `0/0/0`.

## Results

| Seed | Both active at CNM denial | Matrix/CNM overlap cycles | Shared bank accepts | Matrix/CNM responses | Route mismatch | Destination image |
|---|---:|---:|---:|---:|---:|---|
| 20261025 | Yes | 102 | 47 | 128 / 64 | 0 | Both sentinel images unchanged |
| 20261026 | Yes | 102 | 47 | 128 / 64 | 0 | Both sentinel images unchanged |
| 20261027 | Yes | 102 | 47 | 128 / 64 | 0 | Both sentinel images unchanged |

All seeds check Matrix then CNM task IDs in the completion queue and `0x62` for each status/error word. The independent memory scoreboard reports 40,297 writes and 43,603 checked words per seed, with zero mismatch, unknown read, stale-epoch response, or orphan response. The existing focused `cluster_cg` is 64/64 (100%) per seed. The new named directed point is separately required by the Make regression gate; it is not a new URG covergroup bin.

Merged mixed URG remains line 69.31%, condition 63.45%, FSM 41.91%, branch 59.59%, assertion 72.00%, group 29.72%, and overall 56.00%. These code coverage figures do not measure requirement closure. R138 adds no SVA and does not disposition unrelated assertion bins.

## Requirement traceability and disposition

R138 adds a bounded testpoint to `REQ-CL-017`, `REQ-CL-019`, `REQ-CL-027`, `REQ-PC-006`, and `REQ-PC-007`: parallel Matrix/CNM Protection errors, ordered completion, owner response activity, scoreboard consistency, and protected writeback sentinels. These requirements remain `PARTIAL`; this point does not cover all engines, fault types, reset phases, accepted-write prefixes, or requester/backpressure combinations. The overall 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Evidence artifacts

Artifacts are retained in `/tmp/nmaforge_r138_clean_replay_run_20261031/`.

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `e92269608851234fc5cbb19505f124b98ecf2850d4e27e7d5fc062aa55c3c189` |
| `seed_20261025/run.log` | `4c226726c8142dbabb7854a47a5c801a65e5ae2855516905d291eed5ca080acc` |
| `seed_20261026/run.log` | `35d035f037cc3d2c39f2fce4fb06dfdde64f2dece205a64315ec91e64468a8a9` |
| `seed_20261027/run.log` | `d1a1f09f6aacc4f7b5e1d489049e3a1ee0e6fd9b42e9a03cd2f307ca1cc52d2d` |
| `urg_merged/dashboard.txt` | `2691c84bf24d2f325be1854945cd2ed05e91ee50d3613a0c0ade155915273a93` |
| `urg_merged/groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
| `urg_merged/asserts.txt` | `1ad24c72ea13f1b729f7f77f6facf3296b320c14b409a2fecacd4eac944e6958` |
