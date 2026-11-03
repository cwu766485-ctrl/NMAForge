# Matrix FSM Clean Replay — R229

**Date:** 2026-11-03  
**Candidate SHA:** `c5755985b0e5b1e1a850122ece983a37be112272`  
**Candidate tree:** `b0ee13ed91399ce0f982c36a6f5e55e9857e2061`  
**Tools:** VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; VC Formal `V-2023.12-SP2`  
**Run IDs:** `R229-MATRIX-CORE-DEFAULT-3S-20261103`, `R229-MATRIX-CORE-NOPREFETCH-3S-20261103`, `R229-MATRIX-FSM-FORMAL-20261103`  
**Seeds:** `20261025`, `20261026`, `20261027`

## VCS regressions

The default 16×16 Matrix profile (`MAX_OUTSTANDING_READS=4`, A-tile cache enabled, next-K prefetch enabled) passes 18 functional and 35 fault/recovery cases on each of the three seeds. Each run also checks the Line contract: full WSTRB, 16-byte alignment, 312 held-payload stability observations, legal unaligned scalar fallback, and Protection rejection. Partial/zero Line WSTRB remains unsupported by SPEC and was not stimulated.

The separately compiled prefetch-disabled profile passes the fallback point and all five benchmark shapes on each seed. It observes the legal `ST_MAC→ST_A_REQ` fallback. This profile uses the benchmark-only sequence, so its lower overall raw coverage (URG score 51.97%) is not presented as full fault-suite closure. The default-profile three-seed URG summary is line/condition/FSM/branch `96.10/89.69/93.55/92.66%`.

## Formal reachability and disposition

VC Formal reports no setup issues and proves all five legal-profile assertions non-vacuously. Both reachability covers pass: `ST_PREFETCH_WAIT` at depth 11 and `ST_ERROR_DRAIN` at depth 5. The formal assumptions constrain a legal 4×4×3 descriptor and responses to accepted reads; this is a bounded profile disposition, not an exhaustive proof over arbitrary descriptors.

The enabled-profile raw `state_r` transition count remains **49/53**. Three missed transitions are excluded by the proven legal-profile guards; the remaining `ST_MAC→ST_A_REQ` fallback occurs with prefetch disabled and is observed in the separate profile. No FSM state is forced and no unowned response is injected. The result documents reachability and legal exclusions without changing the raw count to 100%.

VC Formal emitted nonfatal `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, and first-run `LEARNED_DATA_NOT_FOUND` messages. The flow reported `No setup issues found`, with no assertion failure. Both VCS compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Reproduction

```sh
make -C dv/block/compute/matrix/sim \
  core-random-regress core-no-prefetch-fallback-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  CORE_OUT_DIR=/tmp/nmaforge_r228_matrix_core_20261103 \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r228_matrix_core_no_prefetch_20261103 \
  SEEDS='20261025 20261026 20261027'

make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r228_matrix_fsm_formal_20261103 \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf

/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r228_matrix_core_20261103/coverage.vdb \
  -format text -report /tmp/nmaforge_r228_matrix_core_20261103/urg_merged \
  -log /tmp/nmaforge_r228_matrix_core_20261103/urg.log

/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r228_matrix_core_no_prefetch_20261103/coverage.vdb \
  -format text -report /tmp/nmaforge_r228_matrix_core_no_prefetch_20261103/urg_merged \
  -log /tmp/nmaforge_r228_matrix_core_no_prefetch_20261103/urg.log
```

Evidence archive: `/tmp/nmaforge_r229_matrix_fsm_clean_replay_20261103.tar.gz`, SHA-256 `664a65f8e9aee4ba8957bad9cb9f3e3f49d2205a6759cfd23c90d428e4282380`. It contains the compile/run logs, URG summaries, formal log, and checksum manifest; binaries and coverage databases are excluded.

## Sign-off impact

This confirms the existing Matrix FSM legal-profile disposition at the current closeout source tree. `REQ-CL-010` remains PARTIAL because broader Matrix parameters, descriptors, fault/reset integration and Compute Cluster clauses are not closed by this block regression. No RTM status changes: 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains **HOLD**.
