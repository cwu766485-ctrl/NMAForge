# Compute Cluster FP16 accepted-read Abort, zero-result prefix — R163

**Date:** 2026-11-01  
**Exact test SHA:** `f2e671de1c5d0a9a7f6c23d49b34c9d8a9501432`  
**Tree:** `e79fa9bfd27c992816c02f4dfd364b6aed5fcc23`  
**Product RTL/SPEC:** unchanged; product baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, Compute Cluster SPEC v1.8  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`, UVM 1.2, behavioral SPAD (`+define+VCS`).

## Result

PASS for the named FP16 accepted-read Abort point. The existing seven-engine Abort sweep now also launches FP16 opcode `0x51` (`task_id=0x0767`). SPEC v1.8 defines this operation as producing one FP32 result word, so this scenario checks the legal zero-output prefix (`0/1`) and does not claim an intermediate partial prefix.

Each of seeds `20261025`, `20261026`, and `20261027` records the same result:

| Check | Result per seed |
|---|---|
| FP16 reads accepted / returned | `4 / 4` |
| Completion | `ERR_ABORT`, status/code `0x32`, task ID `0x0767` |
| FP32 output words / accepted prefix | `1 / 0 of 1` |
| Output sentinels | `8/8` preserved |
| Output writes after Abort sampling | `0` |
| Full independent Memory Scoreboard | `68,712` words; zero mismatch, unknown read, or stale epoch |
| UVM warning / error / fatal | `0 / 0 / 0` |

The sequence checks an accepted SPAD read before issuing Abort, observes Abort sampling, drains every accepted read before completion, checks the completion owner/task/error fields and engine idle state, and verifies the complete sentinel output region. The regression Make target requires the named FP16 pass marker on every seed. URG's existing `cluster_cg` is `64/64` (100%); the all-group mixed score is `64.86%`. R163 adds a required directed run marker, not a new URG covergroup/bin, so no FP16-specific URG percentage is claimed.

## Exact-SHA clean replay

All commands ran from detached clean worktree `/tmp/nmaforge_r163_clean_f2e671d` at the exact SHA/tree above.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r163_clean_f2e671d/uvm

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r163_clean_f2e671d/uvm \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r163_clean_f2e671d/mutations

cd dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The clean regression target passes all three seeds. The checker-sensitivity campaign passes `28/28` assigned-checker probes (Address, Data, Owner, WSTRB, Completion Error Code, Write After Error, Response Epoch, and Done/Missing-Done/Duplicate-Done for all seven engines). These are passive-observation mutations, not DUT fault coverage. Top Smoke maps 86 descriptors / 60 tensors and prints `TEST PASS`; the 20-case seeded top regression also prints `TEST PASS`. The existing fixture warning `[LOOP-REROLL-ENABLED]` remains.

## Requirement disposition

| Requirement | Status | Test ID / checker | Run ID / seed | Evidence |
|---|---|---|---|---|
| `REQ-CL-017` | PARTIAL | `TC-CL-R163-FP16-ABORT-ZERO-PREFIX`; accepted-read Abort/drain, output handshake cutoff, sentinel image checker | `R163-UVM-FP16-ZERO-PREFIX-CLEAN-3S-20261101`; `20261025/26/27` | Per-seed UVM logs in the archive |
| `REQ-CL-019` | PARTIAL | Completion status/code/task-ID, completion tail, engine-idle checker | Same run / seeds | Same archive |
| `REQ-CL-027` | PARTIAL | FP16 engine error/Completion ABI checker | Same run / seeds | Same archive |
| `REQ-PC-006` | PARTIAL | `CLUSTER_MEMORY_SCOREBOARD`; complete output sentinel image and accepted-response ledger | Same run / seeds | Same archive |

No requirement is promoted: other Abort timings, accepted-output completion, parity/protection/watchdog faults, reset interaction, concurrent owners, and broader engine × fault × phase × reset combinations remain open. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Evidence archive

Logs-only archive (VDB, simulator binaries, and generated work directories excluded): `/tmp/nmaforge_r163_clean_f2e671d_logs.tar.gz`  
SHA-256: `b6a88bd167754d9c92a03df9ae882eae2511a61f6fd3b30d526213e1cb29cfc7`
