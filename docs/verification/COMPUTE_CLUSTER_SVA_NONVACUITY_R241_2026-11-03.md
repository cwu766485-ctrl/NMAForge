# AXI Protocol SVA Non-vacuity Replay R241 — 2026-11-03

## Source and run identity

| Item | Value |
|---|---|
| Candidate tree | `a7d5bb00c51e7ded82d2d289c4e7b2421cc5e5f1` |
| Published parent commit | `9659a16e37e10780df7a2e9209d0d7dce2826fa2` |
| Run ID | `R241-AXI-SVA-NONVACUITY-20261103` |
| Test / seed | `ai_mixed_precision_ddr_e2e_test` / `20261015` |
| Tools | Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |

This is a focused top-level AXI protocol SVA check on the same source tree as [R240](COMPUTE_CLUSTER_FINAL_CANDIDATE_REPLAY_R240_2026-11-03.md). It supplies DMA traffic and randomized bounded AXI stalls, which are not part of the Compute Cluster-only sequence.

## Run and results

The existing `make uvm_mixed_precision_ddr_e2e_axi_stalls` target passes at this tree with:

```sh
make uvm_mixed_precision_ddr_e2e_axi_stalls \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

The test uses seed `20261015`, AR/AW configured gaps 2/3, per-transaction jitter, and exercises pre-DMA, post-reset, and post-DMA-reset phases. The test ends with `MIXED_E2E_PASS`; UVM severity is `0/0/0`.

I separately rebuilt and reran that test with `-cm assert`, then merged its assertion database with URG. Results:

| Assertion / cover | Attempts | Real successes / matches | Failures | Incomplete |
|---|---:|---:|---:|---:|
| `a_ar_payload_stable_until_accept` | 3,287 | 14 | 0 | 0 |
| `a_aw_payload_stable_until_accept` | 3,287 | 5 | 0 | 0 |
| `a_w_payload_stable_until_accept` | 3,287 | 12 | 0 | 0 |
| `c_ar_stall_then_accept` | 3,287 | 14 | 0 | 0 |
| `c_aw_stall_then_accept` | 3,287 | 5 | 0 | 0 |
| `c_w_stall_then_accept` | 3,287 | 12 | 0 | 0 |

Across this test's assertion database, 20/22 assertions have real successes; there are zero failures and zero incomplete attempts. The only two without attempts are UVM RAL internal `do_read` and `do_write` properties, not DUT protocol assertions. All three declared AXI stall-to-accept cover properties match.

The earlier R240 Cluster-only run had no AR/AW stall cover matches because its workload does not exercise AXI DMA address channels. This focused test resolves that testpoint gap. It does not close the Compute Cluster's broader engine/fault/phase/reset/backpressure Requirement crosses, nor does it promote any RTM disposition.

## Archived evidence

Archive: `/tmp/nmaforge_r241_sva_evidence_20261103.tar.gz`  
SHA-256: `a73812e601186fccd772f45c05b2606bcfca400e65e9cf93933fc6ab01373202`

| Evidence | SHA-256 |
|---|---|
| VCS compile log | `6f813eb922f2be80d8b84dc036e0c9f10324959e9ec61dd66204d8ac8155cd51` |
| VCS run log | `6e31c0245508372a3ec6165ebd552479e2461918f64d41069eacb119cc9f4a22` |
| URG assertion report | `14d300bc21313b09ef78cc1ac783232ecd693225a147f24f1d9d684876c065df` |

Compile completed without `TFIPC`, `Warning-`, or `Error-` diagnostics. No RTL or checker source was changed.

## Sign-off impact

This closes the named AR/AW/W stall-to-accept stimulus and non-vacuity review point only. The full v1.0 status remains 24 `PASS-SCOPED` and 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
