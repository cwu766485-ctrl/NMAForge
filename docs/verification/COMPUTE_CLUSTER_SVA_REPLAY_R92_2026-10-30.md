# Compute Cluster SVA and AXI backpressure replay — R92

**Run ID:** `R92-COMBINED-AXI-SVA-4C5B9D`
**Result:** PASS for the named assertion and cover properties; Compute Cluster v1.0 remains **HOLD**.
**R91 Cluster code/test SHA:** `43a84cac688a56e789162dfa5a8106551779abdb`.
**R92 mixed E2E tree SHA:** `4c5b9d4237f5b6e6d04013222c8108ca60d5a6d9`.
**Source identity:** the intervening commit records R91 documentation only; `rtl/`, `dv/`, and `docs/spec/` are byte-identical between these trees.
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Commands

The Cluster database is from the exact-clean R91 three-seed replay. The 16-seed mixed-precision DDR/AXI E2E was freshly run at the R92 tree:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_candidate_4c5b_axi_cov_20261030
```

URG then merged the R91 Cluster compile database and three seed databases with the R92 E2E compile database and all 16 E2E seed databases:

```sh
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir /tmp/nmaforge_candidate_43a84_clean_20261030/compile.vdb \
  /tmp/nmaforge_candidate_43a84_clean_20261030/seed_20261025/coverage.vdb \
  /tmp/nmaforge_candidate_43a84_clean_20261030/seed_20261026/coverage.vdb \
  /tmp/nmaforge_candidate_43a84_clean_20261030/seed_20261027/coverage.vdb \
  -dir /tmp/nmaforge_candidate_4c5b_axi_cov_20261030/simv_uvm.vdb \
  $(find /tmp/nmaforge_candidate_4c5b_axi_cov_20261030 -maxdepth 2 \
      -path '*/coverage.vdb' -type d | sort) \
  -format text \
  -report /tmp/nmaforge_candidate_4c5b_combined_sva_20261030/urg_merged \
  -log /tmp/nmaforge_candidate_4c5b_combined_sva_20261030/urg_merged.log
```

The find expansion supplies the 16 concrete E2E VDB paths (and only those paths). All commands exited zero.

## Results

| Check | Result |
|---|---:|
| Mixed-precision E2E regression | **16/16 seeds PASS**; each run has UVM warning/error/fatal `0/0/0` |
| Mixed E2E functional coverage | **100% of the target's named bins**: six descriptor orders/layouts, four SPAD banks, six validator classes, FP16/BF16 K=1..4 and all 16 FP16×BF16 length pairs |
| E2E AXI responder coverage | **100%** in each of the four checked per-transaction groups: AR-ready stall, AW-ready stall, read-response gap, and write-data gap |
| Combined URG assertions | **20/22** properties have real successes; zero failures and zero incomplete attempts |
| Combined URG cover properties | **3/3** AXI stall-to-accept covers match |
| Mixed E2E compile diagnostics | Zero `Warning-`, `Error-`, or `[TFIPC]` diagnostics |

The two assertion properties without attempts are UVM RAL `do_read` and `do_write` internals. They are not DUT protocol checks. The five top-level AXI assertions all have real successes:

| AXI property | Real successes |
|---|---:|
| AR burst stays within 4 KiB | 176 |
| AR payload stable until accepted | 166 |
| AW burst stays within 4 KiB | 83 |
| AW payload stable until accepted | 70 |
| W payload stable until accepted | 126 |

The AXI stall-to-accept cover matches are AR `166`, AW `70`, and W `126`. The R91 Cluster run separately contributes its 64/64 applicable focused Cluster covergroup. The merged report lists the E2E covergroup and four per-transaction responder groups at 100%; the E2E and Cluster functional coverage remain attributable to their separate workloads. This is not a unified full-design coverage percentage.

The 16 E2E seeds are `20261014` through `20261027`, plus `712345` and `987654`. The Make target checks every run's FP16/BF16 result, descriptor validation, DMA SLVERR positions, active-compute and DMA reset behavior, reset recovery, software Abort, and configured AR/AW/read-response/write-data jitter before passing the regression.

## Limits and disposition

This closes the previously unhit AR/AW stall antecedents for the named top AXI master SVA under the checked-in behavioral memory responder and mixed-precision DMA workload. The R91 compute-only test and R92 AXI E2E are distinct workload databases; their functional scores are not added together. The two UVM RAL assertion internals remain without attempts. The responder is behavioral, so this does **not** qualify the product against an external target fabric or close `OPEN-CL-003`. It also does not close broad requester × fault × phase × reset crosses or the remaining partial requirements. RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.

## Artifact paths and checksums

All generated VCS/URG databases and logs remain outside Git under `/tmp`:

| Artifact | Path | SHA-256 |
|---|---|---|
| R92 E2E compile log | `/tmp/nmaforge_candidate_4c5b_axi_cov_20261030/compile.log` | `412392550a39439ec498ea506b29d196d97dd845ec1be231a74fb471652d3ba8` |
| R92 E2E URG log | `/tmp/nmaforge_candidate_4c5b_axi_cov_20261030/urg_merged.log` | `559ef1a6e8659dc5d041f6c9761619013e2e661ef2c7ded290cd001d7f92d031` |
| R92 make/regression log | `/tmp/nmaforge_candidate_4c5b_axi_cov_20261030_make.log` | `22004e891dae33a86de198ad6a2a233ea6affdc82261095a5fd361d9c76d5520` |
| Combined URG log | `/tmp/nmaforge_candidate_4c5b_combined_sva_20261030/urg_merged.log` | `e2a359d38e4ead4c3b126fe44011f7d0f636385ced900aceac0861135ff0481b` |
| Combined assertion report | `/tmp/nmaforge_candidate_4c5b_combined_sva_20261030/urg_merged/asserts.txt` | `2cc18d2c7a1b6540fbfac48e0b506172d4598c72c425e3287c12741c55fd2b01` |
| Combined group report | `/tmp/nmaforge_candidate_4c5b_combined_sva_20261030/urg_merged/groups.txt` | `3372edb09782074aeaa4ed6514eb6a9f0955cc97d6be059c43c789726923c026` |
| Combined functional-bin report | `/tmp/nmaforge_candidate_4c5b_combined_sva_20261030/urg_merged/grpinfo.txt` | `0cea5ba446bf832dcc05aca10a896ae187bb63eefcfdd17c347195166a633b49` |
| Full raw-log checksum manifest | `/tmp/nmaforge_candidate_4c5b_combined_sva_20261030/RUN_MANIFEST.md` | `215130205849a894a79ee0ecb1bd8c78d7922c5a1c0b8cd2256cda0ebe3d1949` |
