# Compute Cluster Matrix Benchmark — R82 — 2026-10-30

## Result and scope

R82 reruns the Matrix array-size and eight-configuration ablation benchmarks at
the selected exact code/test candidate `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907`.
The three seeds `20261025/26/27` produced identical cycles, bank traffic and
stall counts for every configuration/workload. All 165 cases passed the
existing independent INT32 Golden checks: 45 array-size points and 120
depth/prefetch/cache points. No RTL, SPEC or testbench files changed in R82.

This is Matrix block cycle/traffic evidence under the checked-in behavioral
SPAD model. It does not measure physical SRAM, ASIC frequency, power, area, or
an updated paired TinyNPU result. The top-level Serial/Parallel numbers below
are one functional UVM task profile, not a broad throughput characterization.

## Reproduction identity

| Item | Value |
|---|---|
| Code/test SHA | `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907` |
| Clean checkout | `/tmp/nmaforge_r80_clean_e4c1e7a` |
| Tool | Synopsys VCS `V-2023.12-SP1_Full64` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Array benchmark Run IDs | `R82-MATRIX-SIZE-E4C1-S20261025`, `R82-MATRIX-SIZE-E4C1-S20261026`, `R82-MATRIX-SIZE-E4C1-S20261027` |
| Ablation Run IDs | `R82-MATRIX-CONFIG-E4C1-S20261025`, `R82-MATRIX-CONFIG-E4C1-S20261026`, `R82-MATRIX-CONFIG-E4C1-S20261027` |
| Raw machine-readable output | [`compute_cluster_matrix_r82.csv`](compute_cluster_matrix_r82.csv), 165 rows, SHA-256 `ff40aabfcf27bb0fc16f83c04ac66c6c5213afb8f377f637d7a8230071870e6c` |
| External log manifest | `/tmp/nmaforge_r82_matrix_e4c1e7a/SHA256SUMS.log`, 72 inputs, SHA-256 `c00fb0edfeec38a21295f45807c162aa319a8ef5bf07907c768f4f1ea362cfe2` |

Commands, run logs and compile logs:

```sh
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 BENCH_OUT_DIR=/tmp/nmaforge_r81_matrix_size_e4c1e7a \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261025 BENCH_OUT_DIR=/tmp/nmaforge_r81_matrix_size_20261025_e4c1e7a \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261027 BENCH_OUT_DIR=/tmp/nmaforge_r81_matrix_size_20261027_e4c1e7a \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs

PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 MATRIX_CONFIG_OUT=/tmp/nmaforge_r81_matrix_config_e4c1e7a \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261025 MATRIX_CONFIG_OUT=/tmp/nmaforge_r81_matrix_config_20261025_e4c1e7a \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261027 MATRIX_CONFIG_OUT=/tmp/nmaforge_r81_matrix_config_20261027_e4c1e7a \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

Each size-sweep seed runs five signed INT8 GEMM shapes on each 4×4, 8×8 and
16×16 physical array. Each ablation seed runs the same five shapes on 16×16
with Outstanding Depth 2/4 × Next-K Prefetch OFF/ON × A-Tile Cache OFF/ON.
The behavioral bank response is fixed at one cycle; the simulation clock is
10 ns. The reported GOPS column in the CSV is only normalized to an assumed
250 MHz and is not measured Fmax.

## Array-size sweep

Each cell reports `cycles; MAC/cycle; array utilization; SPAD read/write
bytes; bank/line stalls`. The same vectors and INT32 accumulation Golden are
used across all array sizes.

| GEMM shape | Physical 4×4 | Physical 8×8 | Physical 16×16 |
|---|---|---|---|
| 4×4×32 | 76; 6.737; 42.11%; 256/64 B; 3/0 | 76; 6.737; 10.53%; 256/64 B; 3/0 | 76; 6.737; 2.63%; 256/64 B; 3/0 |
| 8×8×32 | 259; 7.907; 49.42%; 768/256 B; 14/2 | 116; 17.655; 27.59%; 512/256 B; 12/3 | 116; 17.655; 6.90%; 512/256 B; 12/3 |
| 16×16×32 | 957; 8.560; 53.50%; 2,560/1,024 B; 63/17 | 397; 20.635; 32.24%; 1,536/1,024 B; 27/31 | 233; 35.159; 13.73%; 1,024/1,024 B; 24/28 |
| 16×32×32 | 1,788; 9.163; 57.27%; 4,608/2,048 B; 93/34 | 709; 23.109; 36.11%; 2,560/2,048 B; 59/35 | 417; 39.290; 15.35%; 1,536/2,048 B; 38/65 |
| 32×32×64 | 6,543; 10.016; 62.60%; 18,432/4,096 B; 384/86 | 2,447; 26.782; 41.85%; 10,240/4,096 B; 235/87 | 1,187; 55.211; 21.57%; 6,144/4,096 B; 136/72 |

The 16×16 array reduces 32×32×64 from 6,543 to 1,187 cycles versus 4×4
(5.51× fewer cycles), while utilization falls from 62.60% to 21.57%. Small
shapes under-fill a 16×16 array: 4×4×32 reaches 2.63% utilization. These are
controller-cycle and simulated operand-delivery observations; no clock or
power claim follows from them.

## Eight-way microarchitecture ablation

Each cell reports `cycles / banked 128-bit read requests`; read bytes are
requests × 16. Output line-write bytes are common to all configurations for a
given workload and are retained in the CSV. The reference is depth 2,
prefetch OFF, cache OFF (`d2p0c0`).

| Shape | d2p0c0 | d2p0c1 | d2p1c0 | d2p1c1 | d4p0c0 | d4p0c1 | d4p1c0 | d4p1c1 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99/16 | 99/16 | 76/16 | 76/16 | 99/16 | 99/16 | 76/16 | 76/16 |
| 8×8×32 | 135/32 | 135/32 | 116/32 | 116/32 | 135/32 | 135/32 | 116/32 | 116/32 |
| 16×16×32 | 265/64 | 265/64 | 248/64 | 248/64 | 242/64 | 242/64 | 233/64 | 233/64 |
| 16×32×32 | 504/128 | 445/96 | 483/128 | 424/96 | 486/128 | 442/96 | 469/128 | 417/96 |
| 32×32×64 | 1,698/512 | 1,471/384 | 1,555/512 | 1,294/384 | 1,636/512 | 1,411/384 | 1,443/512 | 1,187/384 |

For 32×32×64, the best tested configuration `d4p1c1` reduces cycles from
1,698 to 1,187 (30.1%), bank read bytes from 8,192 to 6,144 (25.0%), and
total modeled SPAD traffic including the 4,096-byte output from 12,288 to
10,240 bytes (16.7%). For 16×32×32, the same comparison is 504 to 417 cycles
(17.3%) and bank reads 2,048 to 1,536 bytes (25.0%). Cache gives no benefit
for the two smallest shapes or 16×16×32 because there is no reusable A tile
across column macro tiles in those cases. Prefetch reduces cycles on the
smallest cases; increasing depth helps the larger cases, with the best result
requiring both.

## Real Compute Cluster task timing

The R81 exact-candidate seven-engine UVM run logs include one real top task
profile (seed `20261021`, VCS functional simulation, behavioral SPAD):

| Mode | Work | Cycles | Comparison |
|---|---|---:|---|
| Serial | Matrix 565 + CNM 217 + SFU 457 | 1,239 | Three task baseline |
| Staged | Matrix+CNM pair 613, then SFU 457 | 1,070 | 1.158× versus the same three tasks serially |
| Four-task serial reference | Matrix/CNM/SFU/SFU | 1,696 | Reference for four-task parallel case |
| Parallel | Same Matrix/CNM/SFU/SFU task set | 1,137 | 1.492× versus four-task serial; completion order `0600,0601,0602,0603`; observed shared-SPAD contention 38 cycles |

This is a single directed task bundle; it is not a full workload distribution,
does not attribute every cycle to each engine, and does not model physical
SRAM timing.

## Evidence limits and disposition

- `effective_gops_250mhz` is arithmetic normalization using the stated clock
  assumption. No ASIC PPA, physical SRAM timing, power, area, or Fmax was run.
- These R82 Matrix numbers are not a refreshed TinyNPU paired run. The existing
  TinyNPU report uses its own pinned RTL SHA and explicitly modeled memory
  endpoint; see [`NMAFORGE_VS_TINY_NPU.md`](NMAFORGE_VS_TINY_NPU.md).
- R82 adds benchmark evidence to `REQ-CL-028`; it does not close the remaining
  requirement clauses or promote its disposition. The 38-item RTM remains
  24 PASS-SCOPED / 14 PARTIAL, and `CL-DV-v1.0` remains HOLD. Actual external
  fabric reset/epoch qualification, complete legal engine/fault/phase/reset
  crosses, and broader production-engine memory ownership remain open.
