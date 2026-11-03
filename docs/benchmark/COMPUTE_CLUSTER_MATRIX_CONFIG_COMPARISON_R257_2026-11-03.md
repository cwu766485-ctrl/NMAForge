# Compute Cluster Matrix Configuration Comparison — R257

**Run status:** PASS for one fixed seed and the named 16×16 Matrix controller benchmark. This is an exact-candidate recheck of the R244 ablation, not a multi-seed sign-off; `REQ-CL-028` remains `PARTIAL`.

## Reproducible identity

| Item | Value |
|---|---|
| Tested checkout commit | `bfade42558b8d8713bbd325f41fb1f1604e622c6` |
| Tested tree | `d996718a9883a4c3fc03e816a2389fbbd26c6d1f` |
| RTL/UVM source content | Same as R256 test commit `2f52008e5bbbc4051fa8f912082ef94d7069cc88`; benchmark RTL/testbench/build inputs unchanged |
| GitHub branch at replay | `feat/compute-cluster-closeout-audit`, same tree `d996718a9883a4c3fc03e816a2389fbbd26c6d1f` |
| VCS | Synopsys `V-2023.12-SP1_Full64` |
| Run ID | `MATRIX-CONFIG-R257-CANDIDATE-1S-20261103` |
| Seed | `20261026` |
| Workload model | 16×16 physical array, behavioral SPAD, one-cycle bank response, 10 ns simulation period |

```sh
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH \
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_matrix_config_compare_r257_2f52008
```

The run covers outstanding depth 2/4 × next-K prefetch OFF/ON × A-tile cache OFF/ON and the five workloads below. Every shape/configuration completed its independent Golden checks: 40/40. All eight VCS compile logs have no `Warning`, `Error`, or `[TFIPC]` matches.

## Results

| Workload | D2/P0/C0 cycles | D4/P1/C1 cycles | Change | SPAD read bytes, baseline → D4/P1/C1 | Bank stalls, baseline → D4/P1/C1 | Line-write stalls, baseline → D4/P1/C1 |
|---|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99 | 76 | −23.2% | 256 → 256 | 4 → 3 | 1 → 0 |
| 8×8×32 | 135 | 116 | −14.1% | 512 → 512 | 11 → 12 | 2 → 3 |
| 16×16×32 | 265 | 233 | −12.1% | 1,024 → 1,024 | 25 → 24 | 22 → 28 |
| 16×32×32 | 504 | 417 | −17.3% | 2,048 → 1,536 | 53 → 38 | 22 → 65 |
| 32×32×64 | 1,698 | 1,187 | −30.1% | 8,192 → 6,144 | 156 → 136 | 74 → 72 |
| **Five-workload sum** | **2,701** | **2,029** | **−24.88%** | **12,032 → 9,472 (−21.28%)** | **249 → 213** | **121 → 168** |

For 32×32×64, the measured simulation rate is 42.145→55.211 MAC/cycle and array utilization is 16.46%→21.57%. The aggregate benefit depends on combining the features: at D4/P1/C1, cache lowers read bytes by 21.28% against D4/P1/C0; prefetch lowers cycles by 12.9% against D4/P0/C1; depth 4 lowers cycles by 6.0% against D2/P1/C1. Line-write waiting increases in the selected aggregate, so output service remains a bottleneck.

## Limits and artifacts

This is behavioral RTL simulation with a one-cycle bank response. `reference_gops_at_250mhz` in the CSV is a frequency-normalized estimate from simulated cycles; it does not show that the design meets 250 MHz and is not ASIC PPA or measured silicon throughput. No area, Fmax, power, TinyNPU common-memory comparison, or full-cluster task throughput was run here. The earlier R244 three-seed result remains the multi-seed benchmark evidence; this single-seed replay confirms the same deterministic counts on the R257 candidate content.

Detailed CSV: [compute_cluster_matrix_config_comparison_r257.csv](compute_cluster_matrix_config_comparison_r257.csv), SHA-256 `9289b6fe8fa9f4c8592205826b357c02e2b3e14fd30125ef7124ab7184df8aa7`  
Raw logs: `/tmp/nmaforge_matrix_config_compare_r257_2f52008/`  
Logs-only archive: `/tmp/nmaforge_r257_matrix_evidence_20261103.tar.gz`, SHA-256 `c7c54fa78e988058622f3d110a9d1c26db747dac2b92151e6dc23565686e09a7`
