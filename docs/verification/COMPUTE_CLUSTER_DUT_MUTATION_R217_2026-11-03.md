# Compute Cluster Real RTL Mutation Campaign — R217

## Result

**PASS: 7/7 temporary RTL mutants were caught by their assigned production checkers at the exact published R216 code SHA.** VCS compiled each mutant separately; the campaign script verified the expected checker ID and returned 0.

| Mutant | Injected defect area | Expected checker | Observed severity |
|---|---|---|---|
| Address | Add 4 bytes to a selected SPAD request address | `CLUSTER_MEMORY_UNKNOWN` | UVM_ERROR |
| Data | Flip bit 0 of selected SPAD write data | `CLUSTER_GOLDEN` | UVM_FATAL |
| Response owner | Route a response to the next engine | `CLUSTER_ENGINE_RESPONSE_OWNER` | UVM_ERROR |
| WSTRB | Clear a Matrix Line write-strobe lane | `CLUSTER_MATRIX_WSTRB` | UVM_ERROR |
| Completion error | Change the success error code from 0 to 1 | `CLUSTER_COMPLETION_ERROR_CODE` | UVM_FATAL |
| Missing Done | Suppress Scalar `engine_done` | `CLUSTER_MISSING_DONE` | UVM_ERROR |
| Duplicate Done | Duplicate Scalar Done onto the KV engine bit | `CLUSTER_DONE_WITHOUT_ACTIVE` | UVM_ERROR |

The UVM errors/fatals above are expected mutation detections. The campaign requires the named checker for every mutant and fails if a mutant reaches a normal functional pass without detection.

## Source identity and reproduction

- Run ID: `R217-DUT-MUTATION-7-20261103`
- Exact published code/test SHA: `09f9d31209fdcc803ec322cf3822bd51e763665a`
- Tree: `9778101254417c7272c37d8177e319e70849c8b4`
- Seed: `20261025`
- Tools: Synopsys VCS `V-2023.12-SP1_Full64`; URG coverage instrumentation enabled.
- Temporary mutant sources and all generated binaries/databases were kept outside the repository. Checked-in RTL, UVM sources, and SPEC were not modified by the campaign.

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r216_published_dut_mutation_09f9d312
```

The command exited 0 and printed `COMPUTE_CLUSTER_DUT_MUTATION_PASS: 7/7 real RTL mutants caught`. Seven compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The logs-only archive is `/tmp/nmaforge_r217_dut_mutation_09f9d312_20261103.tar.gz`, SHA-256 `aa905e9e582c5431ce3d207c53299856cc6fa3a88e3db51b7bb9069949755e85`.

## Scope limits

This is a seven-case, single-fault sensitivity campaign at one seed. It does not measure an exhaustive mutation score, prove all checker combinations, or close the legal Engine × Fault × Phase × Reset/backpressure cross. `REQ-CL-017/027`, `REQ-PC-006/007`, the 38-row disposition (24 `PASS-SCOPED` / 14 `PARTIAL`), and `CL-DV-v1.0 HOLD` remain unchanged.
