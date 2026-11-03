# Compute Cluster Actual RTL Mutation Replay — R265

**Result:** 7/7 temporary RTL mutations were detected by their assigned production Checkers on the latest published closeout tree. This is checker-sensitivity evidence only; it does not close a Requirement or change the sign-off decision.

## Fixed candidate and environment

| Item | Evidence |
|---|---|
| GitHub branch | `feat/compute-cluster-closeout-audit` |
| Published commit | `07ad6c4378c09a688aee28cca5aed675a3a74dd6` |
| Tree | `f498f5b1aa1ae723162562870b562f0de2e9a73f` |
| Worktree | Detached clean worktree; no source edits during the campaign |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64`; UVM 1.2 |
| Seed | `20261025` |
| Run ID | `R265-DUT-MUTATION-CLEAN-20261103` |

The mutation runner copies and changes one RTL source per temporary variant under `/tmp`; the checked-out product RTL remains unchanged. The runner requires the named checker ID in each run log and rejects any mutant that reaches the normal UVM PASS marker.

## Results

| Mutation | Temporary RTL fault | Required Checker | Result |
|---|---|---|---|
| Address | Increment selected SPAD address by one word | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| Data | Flip one selected write-data bit | `CLUSTER_GOLDEN` | Caught |
| Response owner | Route response valid/data/error to the next engine | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix WSTRB | Change full Line mask `16'hffff` to `16'hfffe` | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion error | Corrupt successful completion error code | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Missing Done | Suppress Scalar Done | `CLUSTER_MISSING_DONE` | Caught |
| Duplicate Done | Duplicate Scalar Done on the KV slot | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

All seven VCS compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The UVM error/fatal in each mutated run is the expected checker detection; the harness exits PASS only after matching the assigned checker ID.

## Reproduction

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
python3 dv/uvm/sim/run_compute_cluster_dut_mutations.py \
  --out /tmp/nmaforge_r264_dut_mutations_20261103 \
  --vcs-home /tmp/nmaforge_vcs_home_linux_alias \
  --seed 20261025 --timeout 600
```

Observed final marker:

```text
COMPUTE_CLUSTER_DUT_MUTATION_PASS: 7/7 real RTL mutants caught
```

Logs-only evidence archive: `/tmp/nmaforge_r265_dut_mutation_logs_20261103.tar.gz`  
SHA-256: `edbb92285bfe4c0228602d641d8f2d7b36f8749783f27819ff565fcfa6fce94c`

The archive contains compile/run text logs and a per-file SHA-256 manifest. VDBs, simulator binaries, `csrc`, waveforms, and generated tool databases are excluded.

## Requirement trace and disposition

This checker-sensitivity run contributes evidence to the Address/Data/Response-Owner, Matrix WSTRB, Completion Error, and exactly-once lifecycle checker points in `REQ-CL-010/011/013/027` and `REQ-PC-006/007`. It does not exercise the corresponding legal fault/phase/reset/backpressure cross and does not promote any row. The current RTM remains **27 PASS-SCOPED / 11 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
