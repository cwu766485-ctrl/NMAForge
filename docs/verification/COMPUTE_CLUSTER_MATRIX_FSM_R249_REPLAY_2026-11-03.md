# Matrix FSM Reachability Disposition Replay — R249

**Result:** PASS for the enabled-profile Matrix functional/fault regression, the legal prefetch-disabled fallback profile, and the scoped VC Formal guards/covers. No internal state was forced and no unowned response was injected. This closes the disposition of the four residual raw transitions for the tested profile contract; it does **not** close all of `REQ-CL-010` or promote any RTM row.

## Frozen identity and tools

| Item | Value |
|---|---|
| Local clean commit | `a6fdf5f251340a418f35fe19820f9384a9328869` |
| Tree | `074c0411a84e4e971898f4b864d5d7a77852b1a7` |
| Published `main` at replay | `34d0c5605bd08ba16227e59bad95d97b0ead4297` (same tree) |
| Matrix core SHA-256 | `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad` |
| Formal harness SHA-256 | `78c292a3f7471b195335cfe61f8a1abd6070c4ae91f6ff80351e4d2a6d06e1db` |
| VCS / URG | `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |
| VC Formal | `V-2023.12-SP2` |
| Seeds | `20261025`, `20261026`, `20261027` |

## Commands and results

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/block/compute/matrix/sim \
  core-random-regress core-no-prefetch-fallback-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_r249_matrix_enabled_20261103 \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r249_matrix_noprefetch_20261103 \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'

make -C dv/block/compute/matrix/formal fsm-guards \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_r249_matrix_fsm_formal_20261103
```

The default enabled profile passes 18 functional and 35 fault/recovery cases on each seed. The Matrix Line contract checks full WSTRB, 16-byte alignment, 312 stalled-payload stability observations, scalar fallback and Protection rejection. URG reports Matrix-core line/condition/FSM/branch coverage `96.10/89.69/93.55/92.66%`; the primary FSM has 49/53 raw transitions and the prefetch FSM has 9/9.

The separate `ENABLE_NEXT_K_PREFETCH=0` profile passes its fallback marker and five benchmark shapes on all three seeds. It is benchmark-only stimulus and is not used to claim full no-prefetch fault/FSM coverage.

VC Formal reports no setup issues, proves 5/5 assertions and all 5 are non-vacuous. It covers Prefetch Wait at depth 11 and Error Drain at depth 5. Runtime was 113.27 seconds. Non-fatal messages include `COM_OPT009/010`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND`; there are no property failures, counterexamples, or `TFIPC` diagnostics.

## Four raw enabled-profile transition misses

| Transition | Disposition and evidence |
|---|---|
| `ST_PREFETCH_WAIT→ST_A_REQ` | The default prefetch-enabled profile must not fall back to a new A request while prefetch handoff is pending. `ap_prefetch_wait_does_not_fall_back_to_a_req` is proven non-vacuously; the legal fallback is observed when prefetch is disabled. |
| `ST_IDLE→ST_ERROR_DRAIN` | No accepted outstanding read exists in IDLE, and the legal-state invariant is formally proven; the IDLE-to-drain edge exclusion is also proven. |
| `ST_ERROR→ST_ERROR_DRAIN` | ERROR does not re-enter drain; the no-outstanding invariant and edge exclusion are formally proven. |
| `ST_MAC→ST_A_REQ` | This is the legal compile-time fallback for `ENABLE_NEXT_K_PREFETCH=0`; `MATRIX_NO_PREFETCH_FALLBACK_PASS` is observed on all three seeds. It is not expected in the enabled-profile raw count. |

Thus the enabled-profile raw count remains 49/53; the misses are accounted for by legal configuration or proven guards, not converted into artificial coverage hits. The raw FSM percentage is not reported as 100%.

## Requirement status and evidence

The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`. `REQ-CL-010` remains `PARTIAL` because broader Matrix parameter/descriptor behavior, integration, and fault/reset/backpressure intersections remain outside this scoped FSM proof. `CL-DV-v1.0` remains **HOLD**.

Text logs, URG reports and manifest are archived at `/tmp/nmaforge_r249_matrix_fsm_evidence_20261103.tar.gz`, SHA-256 `107924a06561c4af8e53de229254dbc4daca18dabb3b7d1aef9ac40b317329fc`. The archive excludes VDBs, simulator binaries, formal databases and waveforms.
