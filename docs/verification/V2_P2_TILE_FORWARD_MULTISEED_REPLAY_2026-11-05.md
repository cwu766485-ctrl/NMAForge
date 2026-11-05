# v2 Tile Forwarding Multi-Seed Replay — 2026-11-05

## Frozen source and environment

- Branch: `feature/npu-architecture-v2`
- Tested commit: `33e85287fbf37187fccb76e97be6effe888670e9`
- Tested tree: `560dc1cbfc1bb13003670354d77271e3708ec0a7`
- Parent: published `a015f59a04a1efdd9b1debee6be7c7d12475b05e`
- Baseline: R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`
- VCS: Synopsys `V-2023.12-SP1_Full64`
- Host Python: `3.12.13`
- All generated simulator, log, and coverage artifacts stayed under `/tmp`.

The replay used an isolated detached worktree at the tested commit for Top
Smoke. The Tile Forwarding core ablation ran from the same clean committed
source tree. No RTL or testbench source changed between these runs.

## Commands and outcomes

The Matrix-core producer/consumer ablation compared the same descriptors and
seed with the optional feature compiled OFF and ON:

```sh
VCS_ARCH_OVERRIDE=linux \
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
PYTHON=python3.12 \
make -C dv/block/compute/matrix/sim core-tile-forward-regress \
  SEEDS='20261105 20261106 20261107' \
  TILE_FORWARD_REGRESS_OUT=/tmp/nmaforge_v2_p2_tile_forward_33e8528
```

Result: **PASS**, 6/6 feature/seed runs. Every producer and consumer output
image matched the independent packed INT8 Golden. The checks exercised capture
backpressure and final-line commit, exact-tag consume, tag-miss SPAD fallback,
ping-pong bank flip, reset invalidation, Abort invalidation, and response
drain. There were no post-Abort output commits and no stale-tag consume.

The real Top CMDQ differential replay used the `0x53` producer/consumer
sequence, baseline SPAD readback and opt-in capture/consume in each smoke run.
The source was compiled once in the clean detached worktree, then the
following `ai_run` was repeated for each Seed. Every run was gated by the
`0x52` normal/tail markers, the `0x53` output/completion differential marker,
and `TEST PASS`:

```sh
make -C dv/subsystem/top_smoke/sim ai_comp
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261107 SEED=20261107
```

Result: **PASS**, 3/3 Seeds. Each log contains bit-exact `0x52` M4×16×32,
M1×13×17, and M8×16×19 Golden checks and a real-CMDQ `0x53` 16×16×16
producer/consumer differential. The top checker compares all output words
and completions and reports 16 source-A banked reads in the baseline versus
zero in the forwarding run. The existing VCS `[LOOP-REROLL-ENABLED]` notice
remains; no new warning was introduced by this run.

## Core-ablation data

| Seed | Producer cycles OFF/ON | Consumer cycles OFF/ON | Two-command cycles OFF/ON | Consumer source-A reads OFF/ON | Source-A bytes saved | Golden |
|---:|---:|---:|---:|---:|---:|---|
| 20261105 | 147 / 147 | 141 / 118 | 288 / 265 | 32 / 16 | 256 B | bit-exact |
| 20261106 | 148 / 148 | 141 / 118 | 289 / 266 | 32 / 16 | 256 B | bit-exact |
| 20261107 | 152 / 152 | 141 / 118 | 293 / 270 | 32 / 16 | 256 B | bit-exact |
| Mean | 149 / 149 | 141 / 118 | 290 / 267 | 32 / 16 | 256 B | bit-exact |

For this bounded 16×16×16 producer/consumer test, the forwarding path lowers
consumer controller latency by 16.31% and the measured two-command interval
by 7.93%. It avoids 16 128-bit source-A reads (256 bytes) per consumer. The
test keeps the producer and consumer's 16 output line writes each. These are
Matrix-core testbench cycles and selected source-A traffic; they are not
whole-system latency, a general SPAD bandwidth result, or ASIC measurements.

Machine-readable per-Seed data is in
[`benchmark/v2_p2_tile_forward_3seed.csv`](../../benchmark/v2_p2_tile_forward_3seed.csv).
Raw core logs are under
`/tmp/nmaforge_v2_p2_tile_forward_33e8528/seed_{20261105,20261106,20261107}/enable_{0,1}/run.log`.
Top Smoke logs are under `/tmp/nmaforge_v2_top_clean_33e8528/seed_*.log`;
the detached worktree was `/tmp/nmaforge-v2-top-clean-33e8528`.

## Disposition and remaining closure

The earlier license-blocked Top CMDQ run is superseded for the tested
`0x52`/`0x53` cases by this fixed-SHA clean-worktree replay. Tile forwarding
now has three-Seed core ablation and three-Seed product-top CMDQ evidence.
This does **not** close all v2 verification or sign off the whole feature.

Still open: held-response/fault-phase combinations specific to forwarding,
Parity and Protection behavior for both new opcodes, repeated-consumer and
cross-engine coherence contracts, broader M/N/K support, a fully merged
coverage disposition, mutation checks for every new checker, current-SHA
TinyNPU matched benchmarks, and DC/PPA/power. `CL-DV-v1.0` remains **HOLD**;
v2 ASIC readiness is not claimed.
