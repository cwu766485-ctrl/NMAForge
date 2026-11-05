# NMAForge v2 DV Closure Status

**Status:** IN PROGRESS — scoped regressions pass; v2 sign-off is not ready.  
**Reviewed source/test SHA:** `33e85287fbf37187fccb76e97be6effe888670e9`  
**Tree:** `560dc1cbfc1bb13003670354d77271e3708ec0a7`  
**Baseline:** R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`

This is the first current-candidate evidence map for v2. The v2 architecture
spec does not yet assign a normalized `REQ-V2-*` ID set; the rows below are
working requirement statements derived from that spec and must be normalized
before a formal v2 sign-off. They do not replace the v1.0 38-row RTM.

## Reproducible runs

All commands below ran from a detached clean worktree at the reviewed SHA.
Artifacts were isolated under `/tmp`; no VCS database or generated simulator
binary is committed.

```sh
make -C dv/block/control/sim descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_v2_descriptor_validator_33e8528

make -C dv/block/compute/matrix/sim product-gemv-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_product_gemv_33e8528

make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261105 20261106 20261107' \
  CORE_OUT_DIR=/tmp/nmaforge_v2_core_regress_33e8528

make -C dv/block/compute/matrix/sim core-tile-forward-regress \
  SEEDS='20261105 20261106 20261107' \
  TILE_FORWARD_REGRESS_OUT=/tmp/nmaforge_v2_p2_tile_forward_33e8528

make -C dv/subsystem/top_smoke/sim ai_comp
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261106 SEED=20261106
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=4 AI_SEED=20261107 SEED=20261107
```

The runs used the following VCS setup:

```sh
VCS_ARCH_OVERRIDE=linux
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10'
```

## Working traceability matrix

| Requirement statement | Test ID / checker | Coverage evidence | Run ID / seed | Status and scope |
|---|---|---|---|---|
| Route `0x52`/`0x53` through ABI-v7 validator, dispatcher and existing Matrix engine | `DESCRIPTOR_VALIDATOR_PASS`; `TEST PASS` | 29 legal opcode cases; 33 invalid-rule checks; opcode classification consistent | `V2-DESC-VALIDATOR-33E8528`, fixed SHA; Top run `V2-TOP-CMDQ-0x52-0x53-3SEED`, Seeds 20261105/06/07 | **PASS-SCOPED** for tested routing and descriptor classes |
| `0x52` signed INT8 GEMV matches independent INT32 Golden | `MATRIX_CORE_GEMV_KFOLD_PASS`; Top `MATRIX_PRODUCT_GEMV_DESCRIPTOR_PASS` | Full outputs compared; 4×16×32 and bias/post-process Top case | `V2-PRODUCT-GEMV-3SEED`, Seeds 20261105/06/07 | **PASS-SCOPED** |
| `0x52` handles M/N/K tails without out-of-span writes | `MATRIX_CORE_GEMV_KFOLD_TAIL_PASS`, `MATRIX_CORE_GEMV_KFOLD_MROWS_TAIL_PASS`; Top markers | M1×13×17, M8×16×19, M16×16×19 and M16×16×65; scalar tail and line counts checked | `V2-PRODUCT-GEMV-3SEED` and `V2-TOP-CMDQ-0x52-0x53-3SEED`, 3 Seeds | **PASS-SCOPED** for these shapes; not exhaustive M/N/K space |
| `0x52` descriptor range and write-alias checks | `DESCRIPTOR_VALIDATOR_PASS` | 33 invalid rules; 43/43 accepted and 26/26 rejected boundaries | `V2-DESC-VALIDATOR-33E8528`, fixed SHA | **PASS-SCOPED** for directed validator cases |
| `0x52` Abort/Reset/Parity/Protection and held-response recovery | Matrix fault markers exercise shared core lifecycle; no equivalent complete opcode-specific cross | Generic Matrix core 18 functional + 35 fault cases/Seed; not an opcode-0x52 full fault matrix | `V2-MATRIX-CORE-3SEED-33E8528`, 3 Seeds | **PARTIAL**; add feature-specific fault-phase and accepted-response checks |
| `0x53` fused requant, native layout and legacy SPAD writeback remain bit-exact | Top `MATRIX_FUSED_TILE_FORWARD_CMDQ_PASS`; core chain marker | Baseline/forwarded output images and completions compared; writeback retained | `V2-TOP-CMDQ-0x52-0x53-3SEED`, 3 Seeds | **PASS-SCOPED** for 16×16×16 chain |
| `0x53` capture/consume, exact tag, fallback, ping-pong bank, backpressure, Abort and Reset | `MATRIX_TILE_FORWARD_CHAIN_PASS`, `MATRIX_TILE_FORWARD_MISS_FALLBACK_PASS`, `MATRIX_TILE_FORWARD_ABORT_RESET_PASS` | Capture mask/final line, tag hit/miss, bank flip, reset flush, Abort invalidation and request drain | `V2-TILE-FORWARD-CORE-3SEED-33E8528`, OFF/ON × 3 Seeds | **PASS-SCOPED** for bounded 512 B tile path |
| New-opcode Parity/Protection, held response, repeated consumer and cross-engine coherence | No full v2 checker set yet | Not closed by the current directed suite | NOT_RUN | **PARTIAL / NOT_RUN** |
| Matrix line contract: alignment, WSTRB, stable backpressure and Protection response | `MATRIX_LINE_CONTRACT_PASS` | Full WSTRB, aligned write, stalled stability (299–348 cycles), scalar fallback, protection error | `V2-MATRIX-CORE-3SEED-33E8528`, 3 Seeds | **PASS-SCOPED**; partial WSTRB is explicitly unsupported |
| Checker mutation sensitivity and non-vacuous v2 assertions | No current-SHA feature-specific mutation/non-vacuity report | Not merged or audited | NOT_RUN | **NOT_RUN** |
| Full v2 functional/code coverage closure | VCS `line+cond+fsm+branch` was enabled in Matrix runs | Databases not merged; no coverage-bin disposition/percentage is claimed | NOT_RUN | **NOT_RUN** |

The product GEMV machine-readable profiles are in
[`v2_p2_product_gemv_3seed.csv`](../../benchmark/v2_p2_product_gemv_3seed.csv).
Tile Forwarding raw metrics are in
[`v2_p2_tile_forward_3seed.csv`](../../benchmark/v2_p2_tile_forward_3seed.csv).
Raw logs remain under the `/tmp` directories named above. Stage occupancy
counters are state cycles; arbitration, response, writeback, bank, and line
stall counters are event counts that may overlap. They must not be added as
though they partition total latency.

## Open closure items

1. Normalize the v2 requirement IDs and generate a signed-off execution RTM
   with Test ID, checker, coverage bin, Run ID, seed, SHA, and evidence for
   every requirement.
2. Add current-SHA feature-specific `0x52`/`0x53` Parity, Protection,
   held-response, request backpressure, Abort, Reset, and stale-epoch tests.
3. Define and test tile-source immutability under cross-engine SPAD traffic;
   test repeated consume and producer/consumer interleavings.
4. Review/merge current-SHA functional coverage; audit assertions for
   connectivity and non-vacuity; run actual RTL checker mutations for every
   v2 error class.
5. Complete old-opcode compatibility regression beyond the selected Top
   Smoke and Matrix-core test points.
6. Run formal/LEC, CDC/RDC, DC, SRAM mapping, DFT preparation, and PPA only
   with the appropriate tool, constraints, libraries, and licenses. These
   results remain `NOT_RUN` or `BLOCKED_ENV` as applicable.

The v1.0 Compute Cluster remains **HOLD**; no system-wide or ASIC sign-off is
implied by the scoped v2 evidence above.
