# Real CMDQ-to-CNM VDOT launch — R122

**Run ID:** `R122-CNM-VDOT-020-3S-20261031`
**Exact published code/test SHA:** `6161a6b292cb086e7bd2271b0d9c8234034865a1`
**Tree:** `affc79c077acd7edaf31f143844a00bc143b32ea`
**Product RTL/SPEC baseline:** `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; no product RTL or SPEC changed in R122.
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`.

## Scope

R122 closes a specific top-level dispatch evidence gap with one legal CNM banked VDOT task. The sequence writes three K words across four SPAD banks, publishes a legal CMDQ descriptor for opcode `0x20`, and observes the actual engine launch through the passive top interface monitor. It checks the sampled opcode and descriptor fields, exactly one completion, and an independent signed INT8 Golden for all 48 byte products. The expected result is `208`.

This is one opcode/engine/shape point. It does not verify every supported opcode-to-engine route or descriptor boundary, so `REQ-CL-002` and `REQ-CL-015` remain **PARTIAL**. The overall 38-requirement disposition remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.

## Exact clean-worktree commands

The runs below were executed from an empty detached checkout at the exact published SHA above. All output was directed to `/tmp`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r122_exact_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r122_exact_uvm \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r122_exact_mutations
```

All targets exited 0. The mapper precheck reports 86 descriptors and 60 tensors. Top Smoke ends with `TEST PASS`; the 20-case seeded top regression passes. The existing `LOOP-REROLL-ENABLED` fixture diagnostic remains in Top Smoke output.

## UVM, Golden, and mutation results

For seeds `20261025`, `20261026`, and `20261027`:

- `CLUSTER_OPCODE_LAUNCH_PASS` reports `opcode=0x20 engine=CNM`, one completion, independent 48-product Golden, and `result=208` exactly once per seed.
- The full memory scoreboard checks 33,550 words; mismatches, unknown reads, and stale-epoch responses are all zero. The scoreboard records 33,157 writes and 1,030 full-WSTRB Line writes per seed.
- The declared `cluster_cg` functional coverage group reaches 100.00% per seed. This is the applicable group for this UVM test, not a whole-design functional-coverage claim.
- UVM warning/error/fatal counts are `0/0/0`; all queues drain.

At the same exact SHA, all 28/28 checker-sensitivity mutations are detected. The campaign includes address, data, response owner, WSTRB, completion error code, write-after-error, response epoch, and Done/missing-Done/duplicate-Done observation faults across the seven engine Done paths. These are passive checker-sensitivity mutations, not RTL mutation score or DUT fault injection.

## URG and assertion disposition

URG merges the three R122 VDBs. The mixed DUT/testbench/UVM report has overall score 55.34%; line/condition/FSM/branch/assertion/group scores are `68.72/61.89/40.99/58.71/72.00/29.72%`. These raw code/assert/group figures do not replace the 100% result for the specific `cluster_cg` group.

Seventeen of 22 assertion properties have real successes; there are zero failures and zero incomplete properties. Two UVM RAL internal properties have no attempts. This compute-only workload does not create DMA AXI AR/AW traffic, so AR/AW properties and their stall-to-accept covers are not closed by R122; the separate R92/R102 behavioral AXI runs provide that evidence. The UVM compile log contains no VCS `Warning-*`, `Error-*`, or `[TFIPC]` diagnostics.

## Evidence artifacts

Generated logs, VDBs, and mutation outputs are retained outside the repository:

- UVM compile: `/tmp/nmaforge_r122_exact_uvm/compile.log`
- Per-seed UVM runs: `/tmp/nmaforge_r122_exact_uvm/seed_20261025/run.log`, `/tmp/nmaforge_r122_exact_uvm/seed_20261026/run.log`, `/tmp/nmaforge_r122_exact_uvm/seed_20261027/run.log`
- Merged URG: `/tmp/nmaforge_r122_exact_uvm/urg_merged.log` and `/tmp/nmaforge_r122_exact_uvm/urg_merged/{dashboard.txt,asserts.txt,groups.txt}`
- Top Smoke, seeded top, and mapper logs: `/tmp/nmaforge_r122_exact_evidence/`
- 28 mutation logs: `/tmp/nmaforge_r122_exact_mutations/`; checksum manifest: `/tmp/nmaforge_r122_exact_evidence/mutation_sha256sums.txt`

| Artifact | SHA-256 |
|---|---|
| `mapper_precheck.log` | `72251079b4eea046747283a47d471d2ee700919a0e49bd2c2e602cc66d0acd88` |
| `ai_smoke.log` | `96e7b0e8284c81b709103376a25eb8b168fdee77490ee6c825608674bc3c7945` |
| `ai_run_20_seed_12345.log` | `a68e7a6b36267a921ec2429f03e5d938a8eb3501ceb7e65fddf9a8bdfd7877b6` |
| `uvm compile.log` | `74649c0e0cedad37a6e30cc2828edb7fe1e18e7fd58d054a217e560a6d41fa44` |
| `seed_20261025/run.log` | `1b4adabeccb9c9635576d89cc10dde8df89d03817fa85840c95cc05522b227e9` |
| `seed_20261026/run.log` | `5a45fab79dd9df62c758a1591cb74ecfdc7cd15ecc1b52e74e165abd7b1cb8e4` |
| `seed_20261027/run.log` | `1af06a9fb0174fc3f91d46b4c2fec89b2ddf9e9401a8cdd64205ecc7510dc74b` |
| `urg_merged.log` | `2c9ed00f8cd33cc0922ab80664e2b14a23ea5bb218dd11bed7ef86ad780bce01` |
| `urg_merged/dashboard.txt` | `0825f3083dcadb0a1c02bc75aa8db08e638c8aed1b6674fa7bd4e252a8df8d22` |
| `urg_merged/asserts.txt` | `a5b2179a239679dd432dce74541e80fc940d8ff6d0576910a87971ed2f7ca8e4` |
| `urg_merged/groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
| `mutation_sha256sums.txt` | `20945c232bb27b541223420223b4d5e3b2d91a10d52a67e54cb78409317b4a20` |

**Evidence limits:** These are exact-source simulation results using the checked-in behavioral scratchpad selected by `+define+VCS`. They establish the named functional and checker-sensitivity points. They are not ASIC PPA, system-wide code-coverage closure, or full CMDQ dispatch closure.
