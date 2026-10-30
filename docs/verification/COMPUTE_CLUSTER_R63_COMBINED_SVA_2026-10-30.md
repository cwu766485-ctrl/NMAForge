# R63 Combined Compute Cluster and AXI SVA Replay

**Run ID:** `CLUSTER-AXI-SVA-COMBINE-D45B89A`  
**Exact clean code/test SHA:** `d45b89af0c5aab2107a5db6bbf0a6ab754e81656`  
**Worktree:** `/tmp/nmaforge_cluster_r61_clean_d45b89a` (detached at the stated SHA)  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, UVM 1.2.

## Provenance and commands

The combined URG uses two workloads on the same testbench/product SHA: R61's three-seed real Compute Cluster run (`20261030`, `20261025`, `20261026`) and a separate mixed-precision DDR E2E with legal AXI address-channel stalls (`20261015`, AR gap 2, AW gap 3). It merges both compile databases and all four run databases. This keeps workload provenance explicit while allowing the shared top-level protocol properties to accumulate real successes.

From `/tmp/nmaforge_cluster_r61_clean_d45b89a/dv/uvm/sim`:

```sh
/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb \
  -timescale=1ns/1ns +define+VCS \
  -cm line+cond+branch+fsm+assert \
  -cm_dir /tmp/nmaforge_cluster_r63_combined/compile.vdb \
  -Mdir=/tmp/nmaforge_cluster_r63_combined/csrc \
  -top tb_ai_accel_uvm -f ai_accel_uvm.f \
  -o /tmp/nmaforge_cluster_r63_combined/simv_uvm \
  -l /tmp/nmaforge_cluster_r63_combined/compile.log

/tmp/nmaforge_cluster_r63_combined/simv_uvm \
  +UVM_TESTNAME=ai_mixed_precision_ddr_e2e_test \
  +MIXED_E2E_SEED=20261015 +ntb_random_seed=20261015 \
  +MIXED_E2E_AXI_STALLS=1 +MIXED_E2E_AXI_TXN_JITTER=1 \
  +MIXED_E2E_AR_GAP=2 +MIXED_E2E_AW_GAP=3 \
  -cm line+cond+branch+fsm+assert \
  -cm_dir /tmp/nmaforge_cluster_r63_combined/mixed_axi_stalls.vdb \
  -l /tmp/nmaforge_cluster_r63_combined/mixed_axi_stalls.log

/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir /tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/compile.vdb \
  /tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/seed_20261030/coverage.vdb \
  /tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/seed_20261025/coverage.vdb \
  /tmp/nmaforge_cluster_r61_clean_d45b89a/uVM/seed_20261026/coverage.vdb \
  /tmp/nmaforge_cluster_r63_combined/compile.vdb \
  /tmp/nmaforge_cluster_r63_combined/mixed_axi_stalls.vdb \
  -format text -report /tmp/nmaforge_cluster_r63_combined/urg_merged \
  -log /tmp/nmaforge_cluster_r63_combined/urg_merged.log
```

The coverage-enabled mixed-precision test passes (`MIXED_E2E_PASS`) with UVM warning/error/fatal `0/0/0`; AR/AW backpressure is observed in the responder. VCS compile/elaboration has 0 errors and 0 warnings. URG completes successfully and loads the full design database.

## Combined assertion result

URG reports 22 properties: **20 with real successes**, zero failures, zero incomplete, and two without attempts. The two without attempts are UVM register-model `do_read`/`do_write` internals, not DUT protocol assertions. All three AXI stall-to-accept covers match.

| Top AXI property | Real successes |
|---|---:|
| `a_ar_burst_stays_within_4k` | 11 |
| `a_ar_payload_stable_until_accept` | 14 |
| `a_aw_burst_stays_within_4k` | 8 |
| `a_aw_payload_stable_until_accept` | 5 |
| `a_w_payload_stable_until_accept` | 15 |
| `c_ar_stall_then_accept` | 14 matches |
| `c_aw_stall_then_accept` | 5 matches |
| `c_w_stall_then_accept` | 15 matches |

The Compute Cluster run remains the source for seven-engine arithmetic, shared-SPAD, parity, abort/reset, checker, and 5,445-word memory-image results. The mixed-precision test contributes AXI stalls and reset/error lifecycle activity. The merged assertion report does not combine their functional testpoint percentages or imply a full 38-requirement sign-off.

| Artifact | Path | SHA-256 |
|---|---|---|
| Combined compile log | `/tmp/nmaforge_cluster_r63_combined/compile.log` | `b8e6f314766cee2f3703a1e6993e7981e5eab5d7c7b4066df7be9b112a490ea7` |
| Mixed AXI-stall run | `/tmp/nmaforge_cluster_r63_combined/mixed_axi_stalls.log` | `434cb9f24958e8442c077555b4a4fa6e6d1d8b44319ee8aa5980ecd564dc547a` |
| URG log | `/tmp/nmaforge_cluster_r63_combined/urg_merged.log` | `351f8818ee7cd684d8507aa56084d7ffe15679604139fa76817dc4d27c944e8c` |
| URG assertion summary | `/tmp/nmaforge_cluster_r63_combined/urg_merged/asserts.txt` | `e2389cd4194d1459605c655c83a91028a307bf0214e3221b74040527bd038561` |

## Disposition

This closes the non-vacuity gap for the five top-level AXI AR/AW/W burst/payload assertions on the named legal traffic, and all three AXI stall-to-accept covers now match in a coverage-enabled same-SHA replay. Two UVM RAL properties remain without attempts. This does not close external-fabric compliance, all engine/fault/phase/reset combinations, Matrix partial/zero WSTRB unsupported behavior, remaining partial requirements, or other sign-off items. Compute Cluster v1.0 remains **HOLD**.
