# R224 — Matrix FSM fixed-candidate replay — 2026-11-03

## Frozen source identity

- RTL/test SHA: `0e273b8974dbfa593452f7a6a7996c78ddfe4a6e`.
- Tree SHA: `eef6ed76de2e402c2447735ce6d3b2df87d103ed`.
- The test was run in the detached clean worktree. The production Matrix RTL and formal harness are unchanged from the earlier reviewed source: `ai_tensor_matrix_core.v` SHA-256 `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad`; `ai_matrix_fsm_formal_top.sv` SHA-256 `78c292a3f7471b195335cfe61f8a1abd6070c4ae91f6ff80351e4d2a6d06e1db`.
- Tools: VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; VC Formal `V-2023.12-SP2`.
- Seeds: `20261025`, `20261026`, `20261027`.
- Run IDs: `R224-MATRIX-CORE-DEFAULT-3S-20261103`, `R224-MATRIX-CORE-NOPREFETCH-3S-20261103`, `R224-MATRIX-FSM-FORMAL-20261103`.

## Reproduction commands

```sh
make -C dv/block/compute/matrix/sim \
  core-random-regress core-no-prefetch-fallback-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_r223_matrix_core_0e273b8 \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r223_matrix_no_prefetch_0e273b8 \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'

make -C dv/block/compute/matrix/formal fsm-guards \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_r223_matrix_fsm_formal_0e273b8

/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r223_matrix_core_0e273b8/coverage.vdb \
  -format text -report /tmp/nmaforge_r223_matrix_core_0e273b8/urg_merged \
  -log /tmp/nmaforge_r223_matrix_core_0e273b8/urg.log

/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r223_matrix_no_prefetch_0e273b8/coverage.vdb \
  -format text -report /tmp/nmaforge_r223_matrix_no_prefetch_0e273b8/urg_merged \
  -log /tmp/nmaforge_r223_matrix_no_prefetch_0e273b8/urg.log
```

## Results

The enabled 16×16 profile (`MAX_OUTSTANDING_READS=4`, A-tile cache on, next-K prefetch on) passes 18 functional cases and 35 fault/recovery cases on each seed. Its line contract passes full WSTRB, aligned Line writes, stalled-payload stability, legal scalar fallback and Protection rejection. The merged Matrix-core URG result is line/condition/FSM/branch `96.10/89.69/93.55/92.66%`; `state_r` covers all 15 states and 49/53 transitions, while `prefetch_state_r` covers 5/5 states and 9/9 transitions.

The prefetch-disabled profile passes its fallback marker and all five benchmark shapes on all three seeds. It observes the legal compile-time fallback `ST_MAC→ST_A_REQ`; its `+MATRIX_BENCHMARK_ONLY` workload does not exercise the full fault-state space, so its low raw FSM percentage is not merged with or compared as a full-core regression result.

VC Formal reports no setup issues, proves all five assertions non-vacuously, and reaches both `ST_PREFETCH_WAIT` and `ST_ERROR_DRAIN` covers (depth 11 and 5). The proven guards establish no outstanding reads in IDLE/ERROR, prohibit the default-profile prefetch-wait fallback, and prohibit IDLE/ERROR from entering the error-drain state. Formal assumptions constrain a legal 4×4×3 descriptor and require a response to have an accepted-read owner; this is a bounded legal-profile disposition, not exhaustive proof over all descriptors or a complete transition proof.

The four enabled-profile raw transition misses remain visible and dispositioned: `ST_ERROR→ST_ERROR_DRAIN`, `ST_IDLE→ST_ERROR_DRAIN`, and `ST_PREFETCH_WAIT→ST_A_REQ` are excluded by the proven legal-profile guards; `ST_MAC→ST_A_REQ` is observed in the separately compiled prefetch-disabled profile. No internal state is forced and no unowned response is injected. The raw enabled-profile 49/53 count remains 49/53.

VCS compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` matches. VC Formal emits nonfatal `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND` messages; its setup check passes and there are no assertion failures. The no-prefetch benchmark-only VDB is intentionally not evidence of complete fallback-profile FSM coverage.

## Requirement disposition

`REQ-CL-010` remains `PARTIAL`: this replay confirms Matrix FSM guard/profile dispositions and block behavior on the fixed candidate, but does not close all Matrix parameter, descriptor, fault/reset, or Compute Cluster integration clauses. No requirement status is promoted. The full RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Evidence archive

Logs and text URG reports: `/tmp/nmaforge_r224_matrix_fsm_evidence_20261103_v3.tar.gz`.

- Archive SHA-256: `f341b29f719e3dc129e7124dd8f9d981f87ec567fc5e15ce4ed49723a5a5565e`.
- Included manifest SHA-256: `468c031e9c4096a20878f4893d149b9f3b9d36a8b4c21974952f072a3800469d`.
