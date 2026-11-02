# R186 — Matrix FSM legal-profile clean replay — 2026-11-02

## Fixed candidate

- Clean test candidate SHA: `65c83c75c0a8a1518f186a345f414416a6acc2dd`.
- Tree: `c281484182e997a316c45c1f8d1e6f5a927c8065`.
- Product RTL and formal harness hashes: Matrix core `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad`; FSM harness `78c292a3f7471b195335cfe61f8a1abd6070c4ae91f6ff80351e4d2a6d06e1db`.
- Test/Run IDs: `R186-MATRIX-CORE-3S-20261102`, `R186-MATRIX-NOPREFETCH-3S-20261102`, `R186-MATRIX-FSM-FORMAL-20261102`.
- Product RTL, SPEC and formal properties are unchanged. The replay uses the legal prefetch-enabled and compile-time prefetch-disabled profiles.

## Commands

Tool versions: Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; VC Formal `V-2023.12-SP2`.

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_r185_matrix_fsm_core \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress \
  SEEDS='20261025 20261026 20261027' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r185_matrix_no_prefetch \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'

make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r185_matrix_fsm_formal \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf

/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r185_matrix_fsm_core/coverage.vdb \
  -format text -report /tmp/nmaforge_r185_matrix_fsm_core/urg_merged \
  -log /tmp/nmaforge_r185_matrix_fsm_core/urg.log
```

All commands ran in detached Clean Worktree `/tmp/nmaforge_r185_clean` at the fixed candidate SHA.

## Results

The default 16×16, four-outstanding, prefetch-enabled profile passes 18 directed/random functional cases and 35 fault/recovery cases on each of three seeds. The Make-gated Matrix Line contract also passes for every seed: full WSTRB, aligned Line writes, stalled-request stability, legal scalar fallback for non-Line-aligned output, and Protection denial. VCS compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. URG reports core-module line/condition/FSM/branch coverage of 96.10/89.69/93.55/92.66%; this is the Matrix block workload, not whole-design coverage.

The prefetch-disabled profile passes its three-seed fallback target and all five size benchmark workloads per seed. `ST_MAC→ST_A_REQ` is observed as a legal compile-time-profile fallback; the test does not force state values or inject illegal responses.

At this candidate, VC Formal reports no setup issues, proves all five guard/invariant assertions non-vacuously, and covers both `ST_PREFETCH_WAIT` and `ST_ERROR_DRAIN` (depths 11 and 5). The formal source/harness hashes match the previously reviewed R165 harness. Formal emits non-fatal `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND` messages; there are no formal setup errors or assertion failures.

The dedicated R154 transition accounting remains 49/53 in the enabled profile. The four residual raw transitions retain evidence-based dispositions: three are guard-incompatible under the formal environment, and the fourth is the legal prefetch-disabled fallback above. No illegal stimulus or forced internal state is used. This replay supports the dispositions; it does not claim 100% raw FSM bins and does not close all of `REQ-CL-010`.

## Requirement disposition

`REQ-CL-010` remains `PARTIAL`: Matrix FSM residuals are dispositioned for the reviewed legal profiles, while broader Matrix parameter/fault/reset integration and remaining requirement clauses are still open. Overall RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_r186_matrix_fsm_evidence.tar.gz`.

Archive SHA-256: `1873975efc159ec205a464e6bb2352b7ec08727199d7c8f88c06f242f2a4c0ca`.

Manifest SHA-256: `06ba00aa29de5f4dfe1825234e796bea575927cf5f21c4e2506948f917644c90`.
