# Compute Cluster Conv reset accepted-write prefix — R170

**Run ID:** `R170-PUBLISHED-82B748-CLEAN-3S-20261102`
**Test ID:** `TC-CL-R170-CONV-RESET-WRITE-PREFIX`
**Result:** `PASS` for this focused testpoint on the exact published clean SHA below.
**Requirement disposition:** unchanged; affected requirements remain `PARTIAL`.
**Product RTL/SPEC:** unchanged.

## Fixed source and test

The Conv reset-prefix test and mandatory per-seed regression marker were added in source commit `a702091b5db8937061f6b766ec7e1d60e6e5f2f2` (tree `041ffab053bcfb6fc83d6d34c61d5e60445b1c8c`). The published replay used exact branch HEAD `82b748898448800f807b947042d2bd0ed25c2951` (tree `1536a92a2af4c05fe5e10a1dff4e7907796ef5f1`) from detached clean worktree `/tmp/nmaforge_r170_published_clean_82b748`. `ai_compute_cluster_e2e_seq.svh` and the regression Makefile match the R170 source commit byte-for-byte.

The legal descriptor uses a 6×6 input and 3×3 unit kernel, producing a row-major 4×4 output. The sequence independently computes all 16 Golden values, seeds output and completion sentinels, asserts reset after the first accepted output write, and checks the accepted Golden prefix, untouched suffix, old-completion suppression, reset/release quiet windows, and full 16-word new-epoch Golden recovery.

## Clean published-SHA results

| Seed | Conv result | Memory scoreboard | UVM severity |
|---:|---|---|---|
| `20261025` | accepted prefix `1/16`; old completion suppressed; reset-dropped reads `0`; recovery `16/16` | 69,022 words; mismatch/unknown/stale epoch `0/0/0` | warning/error/fatal `0/0/0` |
| `20261026` | accepted prefix `1/16`; old completion suppressed; reset-dropped reads `0`; recovery `16/16` | 69,022 words; mismatch/unknown/stale epoch `0/0/0` | warning/error/fatal `0/0/0` |
| `20261027` | accepted prefix `1/16`; old completion suppressed; reset-dropped reads `0`; recovery `16/16` | 69,022 words; mismatch/unknown/stale epoch `0/0/0` | warning/error/fatal `0/0/0` |

The focused `conv_reset_prefix_cg` has six expected/covered bins on each seed. The three-seed URG merge reports 6/6 (100%), with each bin hit three times: `conv_task_busy`, `accepted_golden_prefix`, `reset_quiet_window`, `release_quiet_window`, `prefix_suffix_and_completion_preserved`, and `full_golden_recovery`. This is the focused testpoint result. The merged all-group URG score is 68.77% because this compute-only run leaves unrelated DMA/AXI groups unexercised or partial; it is not global coverage closure.

The same three-seed full UVM regression also exercises the existing C1 all-engine concurrency case: all seven production engines launch, all 21 engine pairs overlap, maximum active engines is 7, compute-request backpressure is observed for 2,694 cycles, and each engine's output/completion matches its independent Golden. This is one shared workload with deterministic queue ordering; fault/reset/latency crosses remain open.

The same exact SHA passes the 28/28 named checker-sensitivity campaign: address, data, response owner, WSTRB, completion error code, write-after-error, response epoch, and Done/Missing-Done/Duplicate-Done for all seven engines. These are assigned checker-sensitivity probes, not DUT RTL mutation testing. Top Smoke with 20 deterministic random cases (`SEED=20261025`, `AI_SEED=12345`) also passes (`TEST PASS`).

## Commands

Three-seed real-top UVM and merged URG:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_regress \
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r170_published_82b748_3seed \
COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Checker-sensitivity campaign:

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r170_published_82b748_3seed \
COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r170_published_82b748_mutation_28
```

Top Smoke and fixed 20-case Top run:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025
```

The only captured compile notice is the existing fixture `[LOOP-REROLL-ENABLED]` line-debug notice in `ai_transformer_workload.svh`; UVM compile has no warning/error/TFIPC diagnostics. The earlier license-server failures and one-minute timeout were historical attempts; the exact published-SHA retry above later acquired VCS and completed successfully.

## Evidence archive

Logs and coverage summaries are archived outside Git at `/tmp/nmaforge_r170_published_82b748_evidence.tar.gz` (SHA-256 `05a5173f5116d4381921cff0f51dc1b43bdb032b2e5e6f713f37e44822d1a00e`). The file checksum manifest is `/tmp/nmaforge_r170_published_82b748_evidence_sha256.txt` (SHA-256 `ea893754805557cd64fc776671f55ecf4f0ff13d462cc0bf0e6679bd30999c60`). It contains per-seed UVM logs, compile and URG summaries, all 28 mutation logs, and deterministic Top Smoke compile/run logs.

## Requirement disposition

| Requirement | Disposition | R170 evidence added | Why still open |
|---|---|---|---|
| `REQ-CL-017` | `PARTIAL` | Legal Conv reset after one accepted output; prefix/suffix and response/completion checks | Other fault classes, accepted-response phases, engines, and concurrent crossings remain open |
| `REQ-CL-018` | `PARTIAL` | Reset/release quiet windows and full new-epoch Conv recovery | The broader legal engine × fault × phase × reset space is not closed |
| `REQ-CL-019` | `PARTIAL` | Old completion suppression and successful recovery completion | Other completion owner, backpressure, error, and concurrency combinations remain open |
| `REQ-CL-027` | `PARTIAL` | Conv task completion and Memory Image Golden checks | Full error ABI and all-engine completion combinations remain open |
| `REQ-PC-006` | `PARTIAL` | `CLUSTER_MEMORY_SCOREBOARD`, 69,022 words per seed | Broader memory request/response and backpressure combinations remain open |
| `REQ-PC-007` | `PARTIAL` | All-engine C1 completion/Golden checks, production response-owner scoreboard, and Conv reset/epoch checker | The full regression observes all seven real engines, 21/21 pair overlaps, max-active 7, and 2,694 shared-mux backpressure cycles with Golden outputs; broad bank/latency/fault/reset ownership combinations remain open |

The full 38-row disposition stays **24 `PASS-SCOPED` / 14 `PARTIAL`**. No P0 issue is waived by this testpoint; `CL-DV-v1.0` remains **HOLD**.
