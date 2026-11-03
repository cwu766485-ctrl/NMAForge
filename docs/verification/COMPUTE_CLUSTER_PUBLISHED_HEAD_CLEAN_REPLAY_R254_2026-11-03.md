# Compute Cluster Published-HEAD Replay — R254

**Date:** 2026-11-03
**Branch:** `feat/compute-cluster-closeout-audit`
**Exact published HEAD:** `859da92eb5a7b4ecf11f92d594d260f844b4a9c7`
**Tree:** `ec1dc8bcd15ee66155723a815250d5d481efcce2`
**Worktree:** clean detached checkout at that exact commit; generated outputs stayed under `/tmp` or ignored build paths.
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Runs

### Production Compute Cluster UVM

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_published_r253_859da_uvm_3seed \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

All three seeds pass with UVM severity `0/0/0`. Each seed checks 93,839 Memory Image words with zero mismatch, unknown read, or stale epoch. The response-owner ledger reports 5,887 accepted, 5,867 checked, and 20 reset-dropped reads, zero route/data/error mismatch, and zero pending entries.

The real-top sequence observes all seven production engines, 21/21 real engine-pair overlaps, the legal 18/18 randomized-order parity cases, and 72/72 declared legal Protection/reset/recovery points. The R253 two-channel Depthwise CMDQ sequence checks 8/8 signed INT32 outputs, 2/2 ordered completions, and sentinels per seed. These are bounded testpoints; they do not close all descriptor or fault/phase combinations.

### Top Smoke and seeded top run

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both exit zero and end in `TEST PASS`. The mapper precheck reports 86 descriptors and 60 tensors. The compile retains the existing `[LOOP-REROLL-ENABLED]` fixture warning. The seeded run also prints the VCS ASLR save/restore information message.

### Mixed-precision / AXI E2E coverage

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_published_859da_mixedcov_20261103 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

All 16 configured seeds pass. The regression covers the FP16/BF16 `K=1..4` cross, all six descriptor-order/layout bins, AXI read/write gaps, AR/AW ready stalls, DMA error position, Abort, reset, and recovery. Its gates confirm the named functional bins and assertions.

### Actual RTL mutation campaign

```sh
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_published_859da_dut_mutation_20261103 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The campaign exits zero: `COMPUTE_CLUSTER_DUT_MUTATION_PASS: 7/7 real RTL mutants caught`. Temporary source copies are used; product RTL is unchanged.

| Temporary RTL mutation | Expected checker | Result |
|---|---|---|
| SPAD address offset | `CLUSTER_MEMORY_UNKNOWN` | Caught |
| Write-data bit flip | `CLUSTER_GOLDEN` | Caught |
| Response-owner rotation | `CLUSTER_ENGINE_RESPONSE_OWNER` | Caught |
| Matrix WSTRB corruption | `CLUSTER_MATRIX_WSTRB` | Caught |
| Completion error-code corruption | `CLUSTER_COMPLETION_ERROR_CODE` | Caught |
| Missing engine Done | `CLUSTER_MISSING_DONE` | Caught |
| Wrong-engine duplicate Done | `CLUSTER_DONE_WITHOUT_ACTIVE` | Caught |

The seven mutant compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Expected UVM errors/fatals in mutant simulations are the checker detections required by the campaign.

## Merged coverage and assertions

URG merges the 16 mixed-precision/AXI runs and the three real Compute Cluster runs: **19 tests, 31/31 declared functional covergroups at 100%**. This is the declared functional testpoint result for this suite, not 100% RTL code coverage or full requirement closure.

The merged design hierarchy reports line/condition/FSM/branch/assert/group scores of `74.67/74.01/47.24/64.99/92.00/100.00%`. Assertions have 20/22 real successes, zero failures and zero incomplete attempts. Two UVM RAL internal properties have no attempts. The AXI AR/AW/W stall-to-accept covers match 166/70/126 times.

## Requirement and sign-off disposition

This exact-SHA replay confirms reproducibility, the 31 declared functional groups, and targeted checker sensitivity. It does not promote RTM rows. The current disposition remains **24 `PASS-SCOPED` / 14 `PARTIAL`**, and `CL-DV-v1.0` remains **HOLD**.

Remaining closure includes the per-engine descriptor dimensions/stride/alias/overflow contract, the full legal engine × fault × phase × reset/backpressure/owner space, and final requirement-level disposition. Matrix's default enabled-profile raw state count remains 49/53 with its four transitions individually dispositioned; this replay does not turn that raw count into 53/53.

## Evidence archive

Logs and URG text reports, excluding VDBs, simulator binaries, `csrc`, and waveforms:

- `/tmp/nmaforge_published_859da_evidence_20261103.tar.gz`
- Archive SHA-256: `9f9eddd2b36a407f31c0cbcf5965552afd896848434f06c77d27301c6946f8ab`
- `SHA256SUMS` SHA-256: `a0bc0ec2045b602ef679f1d3992ac37f8a4c45bc0bddbc045e82d3af29e76a04`
