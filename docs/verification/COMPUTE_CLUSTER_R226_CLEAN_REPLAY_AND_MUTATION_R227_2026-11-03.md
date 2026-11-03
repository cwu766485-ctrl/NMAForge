# Compute Cluster R226 Clean Replay and RTL Mutation — R227

**Date:** 2026-11-03  
**Candidate SHA:** `186c175dc984729fb488e32fb7132ddd287b4968`  
**Candidate tree:** `666e3d7051e24132dfb922900c0ba85bee5b37eb`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`  
**Run ID:** `R227-R226-EXACT-SHA-CLEAN-REPLAY-MUTATION-20261103`

## Exact-candidate replay

The clean `work/phasea-r226` worktree passed Top Smoke and the existing three-seed real-top Compute Cluster UVM regression at the candidate SHA above. The UVM command was:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs

make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_phaseA_r226_replay \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

All three UVM seeds ended with zero UVM warnings/errors/fatals. Per seed, the response-owner ledger checked 4,995 responses from 5,015 accepted reads, accounted for 20 reset-dropped reads, and ended with no route/data/error mismatch or pending response. The Memory Scoreboard checked 92,871 words with zero mismatch, unknown read, or stale epoch. Legal seven-engine Protection × operand × six-phase coverage reached 72/72, and the pre-consume parity/reset cross reached 12/12. These are scoped testpoint results; they do not close the full engine × fault × phase × reset × backpressure space.

Top Smoke ends with `TEST PASS`. Its compile retains the existing `Warning-[LOOP-REROLL-ENABLED]`; this is recorded rather than hidden. The UVM compile log contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Actual RTL mutation campaign

The production UVM test and checker ran against seven temporary RTL source mutations at the same candidate SHA, seed `20261025`:

| Temporary RTL fault | Production checker | Result |
|---|---|---|
| SPAD address offset | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| SPAD write-data bit flip | `CLUSTER_GOLDEN` | Caught |
| Response routed to wrong engine | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix line WSTRB bit cleared | `CLUSTER_MATRIX_WSTRB` | Caught |
| Successful completion error code changed | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Scalar Done suppressed | `CLUSTER_MISSING_DONE` | Caught |
| Wrong-engine Duplicate Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

The RTM trace is supplemental and scoped: Address/Data plus the per-seed memory-image replay map to `REQ-PC-006`; Response Owner maps to `REQ-PC-007`; Matrix WSTRB maps to `REQ-CL-010`; Completion Error, Missing Done and Duplicate Done map to `REQ-CL-011/013/027`. The three-seed clean replay provides current-candidate evidence for the existing `REQ-CL-017/018/019/027` and `REQ-PC-006/007` partial rows. These rows stay partial because the run does not span every legal fault, requester, phase, reset, or backpressure combination.

The campaign command was:

```sh
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_phaseA_r226_dut_mutations_20261103
```

Result: **7/7 real RTL mutants were caught by their assigned production checkers**. Each mutation was compiled from a temporary source copy; product RTL in the candidate worktree was not modified. All seven mutant compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The UVM errors/fatals in mutant run logs are the expected detection events, not clean-run severity.

Evidence archive: `/tmp/nmaforge_r227_dut_mutations_r226_20261103.tar.gz`, SHA-256 `a763b2226004bed9aa6c81928ab9370272e22545a25fef6f7c450022f627e31d`. Archive manifest SHA-256: `ab5be37fe263cef3b65727943ae76fcb61d7b9cbcf2f3670b5ee3fa42e12a640`. It contains the seven temporary source copies and filelists, compile/run logs, summary, and checksums; simulator binaries and coverage databases are excluded. The uncompressed run directory is `/tmp/nmaforge_phaseA_r226_dut_mutations_20261103`.

## Sign-off impact

This replay confirms reproducibility and sensitivity of seven named production checkers at the exact R226 closeout candidate. It does not close the remaining legal fault/phase/reset/backpressure crosses, unsupported descriptor-contract questions, or other partial RTM clauses. No RTM disposition is promoted: the 38-row matrix remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD** pending review and closure of the listed open items.
