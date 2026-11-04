# Compute Cluster Real-RTL Mutation Campaign — R316

**Run ID:** `R316-DUT-MUTATION-CLEAN-20261104`  
**Tested code/test SHA:** `695d348e4bb8ad77ed26ff502013765261606995`  
**Source tree:** `03c33489ad9743bfb480c38c76a24df1e5e102d5`  
**Published equivalent code commit:** `175d04ce7c0fdcb0772669812a7e10e337d951a7` (same source tree)  
**Worktree:** clean `/tmp/nmaforge_r315_clean_695d348`  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`; seed `20261025`

## Reproduction

Run from `dv/uvm/sim` at the tested source/test SHA:

```sh
make uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r315_dut_mutation_20261104 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The campaign compiles temporary RTL source copies. It does not patch product
RTL. Each run must trigger its assigned checker, and the campaign rejects a
normal Compute Cluster PASS marker for a mutant.

## Results

| Mutated behavior | Expected checker | Observed checker | Result |
|---|---|---|---|
| Address offset | `CLUSTER_MEMORY_UNKNOWN` or Golden | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| SPAD write data bit flip | Golden or Memory Mismatch | `CLUSTER_GOLDEN` | Caught |
| Response owner rotation | `CLUSTER_ENGINE_RESPONSE_OWNER` | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix Line WSTRB bit clear | Matrix WSTRB or Golden | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion error code corruption | `CLUSTER_COMPLETION_ERROR_CODE` | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Missing engine Done | `CLUSTER_MISSING_DONE` | `CLUSTER_MISSING_DONE` | Caught |
| Duplicate/unowned engine Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |
| Request payload changes while stalled | `CLUSTER_REQUEST_STABILITY` | `CLUSTER_REQUEST_STABILITY` | Caught |

The campaign exits `COMPUTE_CLUSTER_DUT_MUTATION_PASS: 8/8`. All eight mutant
compile logs have no `Warning-`, `Error-`, `[TFIPC]`, or fatal diagnostic.
Checker errors/fatals in mutant simulation logs are expected injected-fault
outcomes, not passing functional simulations.

## Requirement and sign-off effect

R316 confirms the named Address, Data, Owner, WSTRB, Completion, Done-lifecycle
and stalled-request checkers are sensitive on the current R315 source/test
tree. This is checker-sensitivity evidence only. It does not prove the entire
legal fault × engine × phase × reset × backpressure space, and closes no
Requirement. The 38-row RTM remains **27 `PASS-SCOPED` / 11 `PARTIAL`**;
`CL-DV-v1.0` remains **HOLD**.

## Evidence archive

Mutant source copies, per-mutant compile and run logs, summary, and checksums
are archived outside Git at
`/tmp/nmaforge_r316_clean_695d348_dut_mutation_evidence.tar.gz` (SHA-256
`bb079d12e70c2e448f1e8d3b006529d575bf49d879376fa361fa4273981ef0a4`).
