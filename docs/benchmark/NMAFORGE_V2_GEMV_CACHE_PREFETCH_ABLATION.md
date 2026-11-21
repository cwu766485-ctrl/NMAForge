# v2 Product GEMV B-fold Cache × Next-K Prefetch Ablation

## Run and controls

- Run ID: `V2-GEMV-CACHE-PREFETCH-FOURWAY-20261105-07`.
- RTL/test source SHA: `b9d593e5f55869ff4a47748013a4b15dcd60f83f`; result parser commit: `ae410661d4f31247be08f2e87ea761452e56a164`.
- Seeds: `20261105`, `20261106`, `20261107`; VCS `V-2023.12-SP1_Full64`.
- Four variants: B-fold Cache OFF/ON × Next-K Prefetch OFF/ON, fixed 16×16 array, 4 outstanding reads, 256 INT8 MACs.
- Workloads: M=8/16, N=16, K=19/65. All variants run the same shapes and seed-controlled responder pattern; 48/48 output-image checks match the independent signed INT8/INT32 Golden.
- Memory model: registered four-bank behavioral SPAD with randomized ready and response latency. This is functional RTL measurement, not SRAM timing or ASIC PPA.

Exact VCS command:

```bash
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' PYTHON=python3.12 \
make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation \
  SEEDS='20261105 20261106 20261107' \
  GEMV_FOUR_WAY_OUT=/tmp/nmaforge_v2_gemv_four_way_b9d593e
```

Full per-seed machine data: [`CSV`](../../benchmark/v2_p2_gemv_cache_prefetch_4way.csv), with raw compile/run logs under `/tmp/nmaforge_v2_gemv_four_way_b9d593e`. The helper checks compile-time feature defines, seed markers, Golden markers, expected B-cache hit/read savings, prefetch completion/overlap, and per-command stage/stall profiles.

## Results

Each row is the mean of three seeds. `Arb/Resp/WB` are the corresponding observational stall counters; `Bank/Line` are testbench request/line backpressure counters. Stall counters can overlap and must not be added together. FSM state-cycle counters are mutually exclusive state occupancy; `Prefetch overlap` intentionally overlaps MAC cycles.

| Shape | B-cache | Prefetch | Cycles | MAC/cycle | Array util. | SPAD read/write | Bank/line stalls | Arb/response/writeback waits | Prefetch overlap/wait-state | B-fold hits/read tx saved |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| M8×N16×K19 | 0 | 0 | 200.7 | 12.13 | 4.74% | 864/512 B | 18.3/12.0 | 30.3/53.3/12.0 | 0.0/0.0 | 0.0/0.0 |
| M8×N16×K19 | 0 | 1 | 195.7 | 12.43 | 4.86% | 864/512 B | 24.3/11.0 | 35.3/15.0/11.0 | 8.0/93.3 | 0.0/0.0 |
| M8×N16×K19 | 1 | 0 | 156.0 | 15.63 | 6.10% | 560/512 B | 10.0/14.3 | 24.3/33.3/14.3 | 0.0/0.0 | 5.0/19.0 |
| M8×N16×K19 | 1 | 1 | 152.3 | 15.97 | 6.24% | 560/512 B | 14.0/11.0 | 25.0/10.7/11.0 | 8.0/59.7 | 5.0/19.0 |
| M8×N16×K65 | 0 | 0 | 544.3 | 15.29 | 5.97% | 2720/512 B | 62.0/11.3 | 73.3/173.7/11.3 | 0.0/0.0 | 0.0/0.0 |
| M8×N16×K65 | 0 | 1 | 520.0 | 16.01 | 6.25% | 2720/512 B | 64.3/9.7 | 74.0/15.7/9.7 | 32.0/370.7 | 0.0/0.0 |
| M8×N16×K65 | 1 | 0 | 391.0 | 21.29 | 8.31% | 1696/512 B | 38.0/11.3 | 49.3/107.7/11.3 | 0.0/0.0 | 16.0/64.0 |
| M8×N16×K65 | 1 | 1 | 383.0 | 21.73 | 8.49% | 1696/512 B | 37.0/12.0 | 49.0/10.7/12.0 | 32.0/241.0 | 16.0/64.0 |
| M16×N16×K19 | 0 | 0 | 393.7 | 12.36 | 4.83% | 1728/1024 B | 38.3/18.3 | 56.7/105.7/18.3 | 0.0/0.0 | 0.0/0.0 |
| M16×N16×K19 | 0 | 1 | 382.7 | 12.71 | 4.97% | 1728/1024 B | 37.7/18.3 | 56.0/31.0/18.3 | 16.0/181.7 | 0.0/0.0 |
| M16×N16×K19 | 1 | 0 | 261.0 | 18.66 | 7.29% | 816/1024 B | 21.7/18.3 | 40.0/51.7/18.3 | 0.0/0.0 | 15.0/57.0 |
| M16×N16×K19 | 1 | 1 | 262.7 | 18.52 | 7.23% | 816/1024 B | 14.3/25.0 | 39.3/18.0/25.0 | 16.0/84.3 | 15.0/57.0 |
| M16×N16×K65 | 0 | 0 | 1075.0 | 15.48 | 6.05% | 5440/1024 B | 97.3/24.3 | 121.7/339.7/24.3 | 0.0/0.0 | 0.0/0.0 |
| M16×N16×K65 | 0 | 1 | 1029.7 | 16.16 | 6.31% | 5440/1024 B | 111.3/17.0 | 128.3/30.7/17.0 | 64.0/734.3 | 0.0/0.0 |
| M16×N16×K65 | 1 | 0 | 627.3 | 26.53 | 10.36% | 2368/1024 B | 44.3/22.0 | 66.3/150.0/22.0 | 0.0/0.0 | 48.0/192.0 |
| M16×N16×K65 | 1 | 1 | 632.3 | 26.32 | 10.28% | 2368/1024 B | 47.7/26.3 | 74.0/20.0/26.3 | 64.0/354.7 | 48.0/192.0 |

## Findings

With prefetch disabled, enabling B-fold Cache reduced cycles/read bytes by 22.3%/35.2% for M8,K19; 28.2%/37.6% for M8,K65; 33.7%/52.8% for M16,K19; and 41.6%/56.5% for M16,K65. Output traffic is unchanged (512 B for M8, 1,024 B for M16). This is the strongest measured benefit in this experiment.

With B-cache disabled, enabling prefetch reduced mean cycles by 2.5%, 4.5%, 2.8%, and 4.2% for the four shapes, without reducing SPAD read bytes. With B-cache enabled, prefetch changed cycles by −2.4%, −2.0%, +0.6%, and +0.8%; the two M16 cases therefore show a small regression inside this model. Prefetch sharply lowers observed response-wait cycles by moving work into prefetch/overlap, but its additive latency benefit is modest and workload dependent.

The experiment does not implement a new bank-reordering scheduler. It quantifies existing B-fold reuse and Next-K prefetch. The strong read-traffic reduction supports keeping bounded B-fold reuse; the measured prefetch gain is not enough to justify extra issue-scheduling RTL without a bank-address contention study and synthesis cost. No new Bank-Aware Issue RTL is retained from this experiment.

## Counter semantics and limits

- FSM phase counters (`a_req`, `a_wait`, `b_req`, `b_wait`, `prep_mac`, `mac`, `write`, `next`, `prefetch_wait`) are state occupancy and are mutually exclusive by state.
- `prefetch_overlap_cycles` counts cycles in MAC while prefetch is active; it overlaps MAC cycles by definition.
- `arbiter_stall`, `response_wait`, `writeback_wait`, `bank_stalls`, and `line_stalls` are event counters, not a partition of total latency. Some can overlap; do not sum them into a cycle breakdown.
- This run covers product GEMV M8/M16, N16, K19/K65 only. M1 and other tails/ranges are covered by the separate three-seed `product-gemv-regress`; this ablation does not cover concurrent engines, Abort, Reset, protection, or real SRAM.
- The simulation clock and 250 MHz reference are not measured Fmax. PPA remains `NOT_RUN`.
