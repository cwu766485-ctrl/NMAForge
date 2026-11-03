# R225 — Compute Cluster actual RTL mutation replay — 2026-11-03

## Frozen baseline and command

- Baseline RTL/UVM SHA: `0e273b8974dbfa593452f7a6a7996c78ddfe4a6e`.
- Baseline tree: `eef6ed76de2e402c2447735ce6d3b2df87d103ed`.
- VCS: `V-2023.12-SP1_Full64`.
- Seed: `20261025`.
- Run ID: `R225-COMPUTE-CLUSTER-DUT-MUTATION-7-20261103`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r224_dut_mutations_0e273b8
```

The runner copies each product RTL source into a temporary mutation directory, applies one exact source replacement, builds a mutant filelist, and runs the production `ai_compute_cluster_e2e_test`. It does not patch the baseline worktree. The campaign gate requires the assigned checker to report the fault and rejects the normal UVM PASS marker.

## Results

| Temporary RTL fault | Assigned checker | Result |
|---|---|---|
| SPAD address offset | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| SPAD write-data bit flip | `CLUSTER_GOLDEN` | Caught |
| Response routed to wrong engine | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix line WSTRB bit cleared | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion error code changed | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Scalar Done suppressed | `CLUSTER_MISSING_DONE` | Caught |
| Wrong engine Done asserted | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

The target exits successfully with `COMPUTE_CLUSTER_DUT_MUTATION_PASS: 7/7 real RTL mutants caught`. Every defect reaches its assigned checker; no mutant reaches the normal `COMPUTE_CLUSTER_REAL_UVM_PASS` marker. VCS compile logs have no `Warning-`, `Error-`, or `[TFIPC]` matches. The UVM errors/fatals in the mutant run logs are the expected detection events.

This is actual RTL mutation sensitivity for seven named defects at one seed. It is not exhaustive mutation closure, randomized fault-cross coverage, or full sign-off evidence by itself. No requirement disposition is promoted: the RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Evidence archive

Archive: `/tmp/nmaforge_r225_mutation_evidence_20261103.tar.gz`.

- Archive SHA-256: `3e46e53d2e929b7f6779aab324a8d97300d4e238d3cb1de163fbc74d2595b53e`.
- Included manifest SHA-256: `036cedfc4924f2ba189e824f3f67856bedb1658e5e2b046d2c9d815cf83038a7`.
- Contents: per-mutant source copy, filelist, compile log, run log, mutation summary and checksum manifest. Compiled binaries and coverage databases are excluded.
