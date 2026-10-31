# Scalar Legacy Conv CMDQ Coverage — R137

**Run ID:** `R137-SCALAR-LEGACY-CONV-CMDQ-3S-20261031`
**Published test commit:** `4b587cf1ded4f3d4786698c17d6fa875e3a7bd53`
**Clean local replay commit:** `3916c70b2ac9cf2846917b9b847cb430e2ec7553`
**Tree identity:** `eec76b8e2aec19e531c40939635b820c4a2829d5` (published and executed trees match)
**Product RTL/SPEC:** unchanged; UVM sequence only.
**Tools:** VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Scope and result

R137 adds real CMDQ-to-Scalar launches for the three legacy Conv opcodes that previously lacked a normal-result top-level testpoint:

| Opcode | Operation | Descriptor shape | Independent checker |
|---|---|---:|---|
| `0x13` | Conv1x1 | 2×2×K2 | Descriptor launch snapshot, signed packed-INT8 dot Golden, all four output words and completion |
| `0x14` | Im2col Conv3x3 | 2×2×K9 | Nine-word im2col K dimension, signed packed-INT8 dot Golden, all four output words and completion |
| `0x15` | Depthwise Conv3x3 | 2×2×K2 | Flattened per-output A addressing and per-channel B reuse, signed packed-INT8 dot Golden, all four output words and completion |

Each descriptor is fetched and validated by the real top, then observed at the Scalar launch interface. The test verifies descriptor order and fields, three completions, the complete 12-word output image, and no relaunch while the Scalar engine is busy. The declared R137 legacy-Conv opcode testpoint set hits **3/3 opcodes and 12/12 outputs per seed**. This is 100% of this named testpoint set; it is not 100% of REQ-CL-020 or global functional/code coverage.

The three-seed real-top UVM clean replay passes seeds `20261025`, `20261026`, and `20261027`. Per seed, the complete scoreboard checks 42,803 words with 37,553 writes, zero mismatch/unknown/stale-epoch/orphan responses, and UVM warning/error/fatal `0/0/0`. The existing focused `cluster_cg` is 100% applicable in this run. The mixed URG report is **56.00%** overall (line 69.31%, condition 63.45%, FSM 41.91%, branch 59.59%, assertion 72.00%, group 29.72%); these figures include DUT, testbench and UVM code and are not functional requirement closure.

R137 does not close REQ-CL-002/015/020: these three opcodes have one representative legal shape each; broader shape/numeric classes, descriptor boundaries and fault crosses remain open. Overall status remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains **HOLD**.

## Reproduction

```sh
make -C /tmp/nmaforge_r137_clean_replay/dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r137_clean_replay_run_20261031 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C /tmp/nmaforge_r137_clean_replay/dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=20 AI_SEED=12345 \
  AI_CLUSTER_COV_RUN=/tmp/nmaforge_r137_clean_replay_top_20261031
```

Both commands exit zero. Top Smoke passes the mapper precheck (`86` descriptors, `60` tensors) and reports `TEST PASS`. Its existing `[LOOP-REROLL-ENABLED]` fixture compile warning remains present and is not suppressed. The UVM compile log has no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal` diagnostics.

## Coverage and checker disposition

| Evidence | Result |
|---|---|
| New legacy Conv opcode bins | `0x13/0x14/0x15`: 3/3 per seed |
| Independent output Golden | 12/12 words per seed; 36/36 across the three seeds |
| Ordered completion / launch | 3/3 per seed; descriptor fields match observed Scalar launch |
| Full memory scoreboard | 42,803 words/seed; zero mismatch, unknown, stale epoch or orphan response |
| Focused `cluster_cg` | 100.00% applicable bins |
| Mixed URG | 56.00% overall; not functional sign-off coverage |
| URG assertions | 17/22 real successes; zero failure/incomplete; three AXI assertions without real success in this compute-only profile; two UVM RAL properties without attempts |
| AXI stall covers | W stall matches 3; AR/AW stall covers unhit in this compute-only profile |
| Top Smoke | `TEST PASS`; existing `[LOOP-REROLL-ENABLED]` compile warning |

## Artifact paths and SHA-256

Artifacts remain outside the repository under `/tmp`.

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `d5b694a53e9b1c77e6088b9a88a932f482d94026c0b131438098bf58d8d45388` |
| `seed_20261025/run.log` | `7c9e334c948ae2eecfbd8014f741946328c7fecd40faeba5482c88b25f95c209` |
| `seed_20261026/run.log` | `1982601f2bcc7505f78eae21ab4094855ee94e87f9219b9e3dd2c125b35a7ef9` |
| `seed_20261027/run.log` | `c965535ce602f54ca7b92ef2b8150994cc5ff9d31bf3dadcf28a6bfe7935b931` |
| `urg_merged/dashboard.txt` | `003a362133d9aa71b60b00f4505ef04485e99c46fb451b8a8fae0755275455d7` |
| `urg_merged/groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
| `urg_merged/asserts.txt` | `e9c141f83a8a06a578fbde831a94620dc9a460b3ec8e03e87fdfec4195ddd733` |
| Top Smoke `make.log` | `c1f8f6512654d85d5e30824f4d58c7e583e565d1a57b9944a7643e2ebdb1eda7` |
| Top Smoke `ai_comp.log` | `f62a7ccfd49ca18807eb88fe5d4a901c57045f4582ab509e90d4f3556bb1616a` |

Raw logs: `/tmp/nmaforge_r137_clean_replay_run_20261031/` and `/tmp/nmaforge_r137_clean_replay_top_20261031/`.
