# Compute Cluster fixed-SHA AXI SVA and Top Smoke replay — R195

**Run ID:** `R195-AXI-SVA-TOP-REPLAY-20261102`  
**Fixed code SHA:** `f87acc9bca3b3ecece385fadfd5623de6837ea8d`  
**Tree:** `cfc7ba4955488ae58d58f36deec368173c6ec98c`  
**Checkout:** `/tmp/nmaforge_r194_clean_f87acc9`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, UVM 1.2

This replay uses the same clean candidate as R194. Product RTL and SPEC are unchanged. It separately exercises the AXI stall properties that have no matches in the compute-only R194 regression.

## AXI stall-to-accept SVA workload

Command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_axi_stalls
```

The target passes its required pre-DMA and post-reset per-transaction AXI jitter, reset and error checks. UVM severity is `0/0/0`; mixed FP16/BF16/INT8 DDR oracles pass; the scoreboard checks 152 memory words with zero mismatch/unknown/stale epoch, and the response-owner ledger drains 19/19 reads without mismatch or pending response.

The real SVA cover matches are:

| Cover property | Attempts | Matches |
|---|---:|---:|
| `c_ar_stall_then_accept` | 3,287 | 14 |
| `c_aw_stall_then_accept` | 3,287 | 5 |
| `c_w_stall_then_accept` | 3,287 | 12 |

The AXI memory model also reports nonzero observed ARREADY and AWREADY stalls. The UVM compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. This closes the named assertion-stimulus gap on this fixed code SHA; it does not close the wider production engine/fault/reset coverage matrix.

## Top Smoke and seeded top regression

Commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_smoke

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both complete with `TEST PASS`. The mapper precheck reports 86 descriptors and 60 tensors. The seeded run records `AI_RANDOM_CASES=20` and `AI_SEED=12345`. Top Smoke compilation retains the existing `[LOOP-REROLL-ENABLED]` warning in `ai_transformer_workload.svh`; no compile error is reported.

## Evidence archive and sign-off effect

Logs-only archive: `/tmp/nmaforge_r195_axi_sva_top_evidence_20261102.tar.gz`  
SHA-256: `bd1cfc4479831560b0dcbcd8c9bd961fa09e11ca5cb83b927c7c7cc9d39301be`

The archive contains the AXI UVM compile/run logs, Top Smoke compile/run logs, and a manifest with commands and file hashes; binaries, VDBs and waveforms are excluded.

R195 confirms same-SHA reproducibility and real AR/AW/W stall-cover activation. It changes no requirement disposition: 24 requirements remain `PASS-SCOPED`, 14 remain `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. The broader legal requester × fault × phase × reset/backpressure crosses, descriptor contract gaps, functional-coverage disposition and independent 38-row review remain open.
