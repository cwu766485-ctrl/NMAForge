# R62 AXI Address-Stall and Reset-Recovery Replay

**Run ID:** `MIXED-AXI-ADDR-STALLED-D45B89A`  
**Exact clean code/test SHA:** `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`  
**Worktree:** `/tmp/nmaforge_cluster_r61_clean_d45b89a` (detached at the stated SHA)  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`; UVM 1.2.

## Command and result

From `/tmp/nmaforge_cluster_r61_clean_d45b89a/dv/uvm/sim`:

```sh
make uvm_mixed_precision_ddr_e2e_axi_stalls
```

**PASS, exit 0.** The existing top-level mixed-precision DDR E2E ran with `MIXED_E2E_SEED=20261015`, `MIXED_E2E_AXI_STALLS=1`, per-transaction jitter, ARREADY gap 2 and AWREADY gap 3. It reports the expected pre-DMA, post-reset, and post-DMA-reset configuration markers; real address-channel stall observations; and `MIXED_E2E_PASS`. UVM warning/error/fatal counts are `0/0/0`. The run also executes the existing DMA, reset-epoch, watchdog, abort, and recovery checks in this mixed-precision test.

The test's simulation report shows the SVA cover properties matched: `c_ar_stall_then_accept=14`, `c_aw_stall_then_accept=5`, and `c_w_stall_then_accept=12`. VCS compile/elaboration reports 0 errors and 0 warnings.

| Artifact | Path | SHA-256 |
|---|---|---|
| Compile log | `/tmp/nmaforge_cluster_r61_clean_d45b89a/dv/uvm/sim/uvm_compile.log` | `f1dcffe752bbdaa6c8df3b6402958c759b471e46725a35450a2a16232f24f4cd` |
| Run log | `/tmp/nmaforge_cluster_r61_clean_d45b89a/dv/uvm/sim/uvm_run_ai_mixed_precision_ddr_e2e_axi_stalls.log` | `e79f3a2672f15233e22a2b51cf6c708f80e506a5d58e9df551547c9376a8665a` |

## Coverage boundary

This is a separate mixed-precision top E2E run. Its VCS invocation did **not** enable `-cm`, it produced no VDB/URG database, and its cover-property match counts are not merged with R61's Compute Cluster database. Accordingly, this run improves evidence that legal AR/AW backpressure and the associated stability/burst checker paths are exercised, but it does not update R61's reported `22 properties / 17 successes / 5 uncovered`, nor provide a consolidated assertion-coverage disposition. A combined coverage-enabled replay remains a separate task if an aggregate SVA result is required.
