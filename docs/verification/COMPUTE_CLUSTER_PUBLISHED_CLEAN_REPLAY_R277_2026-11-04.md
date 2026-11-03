# Compute Cluster Published-HEAD Clean Replay — R277 — 2026-11-04

## Result

The published Compute Cluster closeout candidate was checked out at its exact
GitHub HEAD into a detached clean worktree. The real-top three-seed UVM,
Top Smoke, and fixed 20-case Top regression pass. The added Scalar/KV shared
read-region testpoint observes both production request owners and both tagged
responses during overlapping reads from the same read-only SPAD region.

This is exact-candidate reproducibility and bounded ownership evidence. It
closes no additional requirement row; Compute Cluster v1.0 remains **HOLD**.

## Frozen identity and tools

| Item | Value |
|---|---|
| GitHub closeout branch at run time | `feat/compute-cluster-closeout-audit` |
| Published commit / tree | `d1ca433198df6751324e646b3fe6c0586881edeb` / `ef191c5264f6cee083981e92e7624341698d8d5b` |
| Run ID | `R277-PUBLISHED-CLEAN-REPLAY-3S-20261104` |
| UVM seeds | `20261025`, `20261026`, `20261027` |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`; UVM 1.2 |
| Worktree | `/tmp/nmaforge_r277_published_clean`, detached at the published SHA and clean before execution |
| Product RTL | Unmodified |

## Results

| Check | Observed result |
|---|---|
| Scalar/KV shared read source | Each seed accepts reads from both production engines in the same read-only SPAD region; owner-tagged responses are observed for both; maximum simultaneous read owners is 2; Scalar/KV busy overlap is observed. Focused bin passes 1/1 per seed and 3/3 merged. |
| Real-top seven-engine UVM | 3/3 seeds pass the official `uvm_compute_cluster_regress` target. Each seed prints `COMPUTE_CLUSTER_REAL_UVM_PASS`. |
| Memory Scoreboard | Per seed: 77,501 writes and 96,595 words checked; zero data mismatch, unknown read, or stale epoch. |
| Response ownership | Per seed: 6,139 accepted / 6,119 checked / 20 reset-dropped; zero route/data/error mismatch and zero pending responses. |
| UVM severity | Per seed: warning/error/fatal `0/0/0`. |
| URG focused coverage | Merged `cp_scalar_kv_shared_read` is 3/3 (100%); `cluster_cg` is 64/64. These are declared UVM functional bins, not DUT RTL code coverage or requirement closure. |
| UVM compile diagnostics | No `Warning-`, `Error-`, or `[TFIPC]` matches in the VCS compile log. |
| Top Smoke | PASS; mapper reports 86 descriptors, 60 tensors, closed dataflow, poison enabled. The existing `[LOOP-REROLL-ENABLED]` fixture warning remains visible. |
| Seeded Top regression | `AI_RANDOM_CASES=20`, `AI_SEED=12345`; simulation ends with `TEST PASS`. |

The earlier R275/R276 license-blocked attempts are retained as attempt history.
VCS acquired the license for this replay using `-licwait 1`; the successful
run supersedes those attempts for this exact candidate and testpoint.

## Reproduction commands

From the repository root:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 VCS_ARCH_OVERRIDE=linux \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r276_shared_region_licwait_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

From `dv/subsystem/top_smoke/sim`:

```sh
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH make ai_smoke AI_RANDOM_CASES=4 AI_SEED=12345
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The Top Smoke compile retains its known fixture reroll warning; it is not hidden
or counted as a clean compile. The UVM compile itself has no matched warning,
error, or TFIPC diagnostic.

Logs and URG text summary are archived outside Git at
`/tmp/nmaforge_r277_published_clean_replay_logs.tar.gz` (SHA-256
`b4c225f78090a086adaa45adb3db5a6348fcadc921f094ea102acf0689373cb2`). The
archive excludes simulator binaries, VDBs, waveforms, and generated work
folders.

## Requirement disposition

The 38-row Execution RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL` / 0
`BLOCKED_SPEC` / 0 `NOT_RUN`; `CL-DV-v1.0` remains **HOLD**. The new focused
bin strengthens `REQ-PC-007` evidence for this Scalar/KV shared-region case,
but the broader production requester × engine × fault × phase × reset ×
backpressure ownership matrix is still incomplete. No requirement disposition
is promoted.

## TinyNPU comparison checkpoint

The latest paired GEMM report is R273. It reran the NMAForge controller on the
closeout tree available when R273 was run and checked 4,608 outputs; TinyNPU's measured
array cycles remain from pinned SHA
`8216c22b762011aa20c05fc2768423fd12dda59d` in R259, not a new R273 run.

| GEMM | NMAForge controller cycles | TinyNPU array RTL cycles | TinyNPU serialized memory endpoint | Difference vs endpoint |
|---|---:|---:|---:|---:|
| 16×16×16 | 152 | 52 | 151 | NMAForge +1 cycle (+0.7%) |
| 16×16×32 | 231 | 100 | 231 | Tie |
| 32×32×64 | 1,198 | 790 | 1,305 | NMAForge −107 cycles (−8.2%) |

TinyNPU's endpoint is a model (16 bytes/cycle, one-cycle read response,
serialized load/compute/store, two accumulator-clear cycles); TinyNPU's exposed
array wrapper has no matching SPAD request/response endpoint. At 32×32×64,
NMAForge reads 6,144 bytes versus 4,096 bytes in the TinyNPU model. The largest
case is promising but does not establish a same-bandwidth product advantage.
No matched GEMV/decode, larger CNN, trained-model inference, or candidate ASIC
PPA/Fmax/power comparison is available. See [R273 paired benchmark](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R273_2026-11-04.md)
and [R259 measurement details](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R259_2026-11-03.md).

## Review checkpoint

The frozen published tree is reproducible for the listed checks, and the new
Scalar/KV shared-read bin is covered on all three seeds. The remaining 11
partial requirement rows and the comparison limits above remain for review;
there is no release or TinyNPU superiority claim in this report.
