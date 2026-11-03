# Compute Cluster Actual RTL Mutation Campaign — R280

## Result

The actual-RTL mutation runner passes **7/7** on published source/test SHA
`487794dfa2d931391fd5ac82f16626b7c6f878e5` / tree
`c01a4e15f4f72ca120aa5e7d41094173c011f9ea`. Each temporary mutant is caught
by its expected production checker. Mutation source copies and run products
stay under `/tmp`; the clean worktree source remains unchanged.

This closes the declared checker-sensitivity campaign point, not the legal
fault × phase × engine × reset coverage matrix. No requirement disposition is
promoted. The 38-row RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and
`CL-DV-v1.0` remains **HOLD**.

## Identity and evidence

| Item | Value |
|---|---|
| Test ID | `TC-CL-R280-ACTUAL-RTL-MUTATION-CAMPAIGN` |
| Run ID | `R280-DUT-MUTATION-7OF7-PUBLISHED-20261104` |
| Published source/test SHA | `487794dfa2d931391fd5ac82f16626b7c6f878e5` |
| Git tree | `c01a4e15f4f72ca120aa5e7d41094173c011f9ea` |
| Seed | `20261025` |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64` |
| Runner | `dv/uvm/sim/run_compute_cluster_dut_mutations.py` |
| Runner SHA-256 | Recorded in the archive manifest |
| Evidence archive | `/tmp/nmaforge_r280_mutation_evidence.tar.gz` |
| Archive SHA-256 | `9270b0afca3e4a4f54e4f3f27063392cf0b23d41842dbe260eba540a42fbd46d` |

## Mutation-to-checker results

| Mutation | Expected checker | Observed checker | Result |
|---|---|---|---|
| Address | `CLUSTER_MEMORY_UNKNOWN` | `CLUSTER_MEMORY_UNKNOWN` | PASS |
| Data | `CLUSTER_GOLDEN` | `CLUSTER_GOLDEN` | PASS |
| Response owner | `CLUSTER_ENGINE_RESPONSE_OWNER` | `CLUSTER_ENGINE_RESPONSE_OWNER` | PASS |
| Matrix WSTRB | `CLUSTER_MATRIX_WSTRB` | `CLUSTER_MATRIX_WSTRB` | PASS |
| Completion error | `CLUSTER_COMPLETION_ERROR_CODE` | `CLUSTER_COMPLETION_ERROR_CODE` | PASS |
| Missing done | `CLUSTER_MISSING_DONE` | `CLUSTER_MISSING_DONE` | PASS |
| Duplicate done | `CLUSTER_DONE_WITHOUT_ACTIVE` | `CLUSTER_DONE_WITHOUT_ACTIVE` | PASS |

Each mutation produced the required checker failure. No mutation was accepted
as a normal test pass. All seven compile logs have no `Warning-`, `Error-`, or
`[TFIPC]` diagnostics. The mutation runner did not modify tracked RTL or
testbench files.

## Reproduction

Run from `dv/uvm/sim` on the published SHA:

```sh
make uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r279_dut_mutations \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

## Limits

Mutation sensitivity proves the named observation/checker paths respond to
these injected defects. It does not prove that all legal fault/phase/reset
scenarios are covered, nor that the full Compute Cluster is signed off. Keep
the remaining 11 `PARTIAL` requirements open until their legal testpoints and
dispositions are reviewed.
