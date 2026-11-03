# Compute Cluster Matrix Configuration Comparison — R244

**Run status:** PASS for this defined Matrix controller benchmark. `REQ-CL-028` remains `PARTIAL`; this does not establish a TinyNPU advantage or close Compute Cluster sign-off.

## Reproducible identity

| Item | Value |
|---|---|
| Tested local commit | `c49b8f88e1571381e4822959b28a36ce5dce6157` |
| Tested tree | `3db422d6456edfaf9b5dc74460f9d5507a42c08c` |
| Published same-tree commit before this report | `44e1e09561d27e8b8a98be910b225f7f5f1ad816` |
| VCS | Synopsys `V-2023.12-SP1_Full64` |
| Run ID | `MATRIX-CONFIG-R244-3S-20261103` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Workload model | 16×16 physical array, behavioral SPAD, one-cycle bank response, 10 ns simulation period |

```sh
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261025 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_matrix_config_compare_r244_seed20261025_20261103 \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias

make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_matrix_config_compare_r244_20261103 \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias

make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261027 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_matrix_config_compare_r244_seed20261027_20261103 \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias
```

## Results

The eight configurations are outstanding depth 2/4 × next-K prefetch OFF/ON × A-tile cache OFF/ON. Each configuration ran five shapes; all 120 shape/configuration/seed runs passed the target's independent Golden checks. Results were deterministic across the three fixed seeds.

| Workload | D2/P0/C0 cycles | D4/P1/C1 cycles | Cycle change | SPAD read bytes, baseline → D4/P1/C1 | SPAD write bytes |
|---|---:|---:|---:|---:|---:|
| 4×4×32 | 99 | 76 | −23.2% | 256 → 256 | 64 → 64 |
| 8×8×32 | 135 | 116 | −14.1% | 512 → 512 | 256 → 256 |
| 16×16×32 | 265 | 233 | −12.1% | 1,024 → 1,024 | 1,024 → 1,024 |
| 16×32×32 | 504 | 417 | −17.3% | 2,048 → 1,536 | 2,048 → 2,048 |
| 32×32×64 | 1,698 | 1,187 | −30.1% | 8,192 → 6,144 | 4,096 → 4,096 |
| **Five-workload sum** | **2,701** | **2,029** | **−24.88%** | **12,032 → 9,472 (−21.28%)** | **7,488 → 7,488** |

At 32×32×64, measured-in-simulation MAC rate is 38.596→55.211 MAC/cycle and array utilization is 15.08%→21.57%. These are cycle-model statistics, not post-layout throughput. Across the five workloads, bank-stall cycles sum to 249→213, while line-write-stall cycles sum to 121→168. Thus the cycle and read-traffic improvement comes with more observed line-write waiting in the selected aggregate; output-write service remains an optimization target.

The individual ablations show that prefetch reduces cycles even on small shapes; A-tile cache reduces reads for the multi-N-tile shapes; and outstanding depth gives additional cycle benefit for larger shapes. The combined D4/P1/C1 result should not be read as an isolated contribution from any single feature.

## Measurement limits and artifacts

This is a behavioral RTL simulation with a one-cycle bank response. The CSV's `reference_gops_at_250mhz` is a frequency-normalized estimate from simulated cycles, not measured silicon throughput, ASIC PPA, or evidence that the design meets 250 MHz. No ASIC area, Fmax, or power was run here. The comparison does not include TinyNPU, common-memory constraints, GEMV/decode, full-cluster task scheduling, or model inference; those remain open.

Detailed 120-row CSV: [compute_cluster_matrix_config_comparison_r244.csv](compute_cluster_matrix_config_comparison_r244.csv)  
Raw compile/run logs and manifest: `/tmp/nmaforge_r244_matrix_evidence_20261103/`  
Archive: `/tmp/nmaforge_r244_matrix_evidence_20261103.tar.gz`  
Archive SHA-256: `e0ed112d064a5ef4816e560a06e59241aaa5b127200be084bd97882eefc4a9de`  
CSV SHA-256: `ce835cd2e4e3d625c3b5f9974bdedbe3367691a6c925b7c412e03d934154e1b8`
