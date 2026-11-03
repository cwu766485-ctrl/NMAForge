# TinyNPU Matched Matrix Controller Replay — R273

## Result

The current published-closeout tree reproduces the NMAForge side of the three
matched signed INT8 GEMM workloads with the R259 controller results. Each
shape passes its independent INT32 output Golden on all three seeds. The TinyNPU
array cycle counts below are the separately measured values from pinned TinyNPU
SHA `8216c22b762011aa20c05fc2768423fd12dda59d` recorded in R259; this R273 run
does not rerun TinyNPU RTL.

This is a paired functional and cycle comparison, not a fully common-memory RTL
comparison or ASIC result.

## Reproducible identity

| Item | Value |
|---|---|
| Tested NMAForge commit/tree | `a72e5b45bfab7031f899c8497e5aa458ccd73dd9` / `e97cc69589cb246659e6de117661579d08963430` |
| Published closeout commit with identical tree | `dce948047fa1147e30fb3bd9debfc02bf8758a3d` |
| TinyNPU RTL | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| Run ID | `R273-TINY-MATCH-CONTROLLER-3S-20261104` |
| Seeds | `20261029`, `20261030`, `20261031` |
| NMAForge configuration | 16×16 array, outstanding depth 4, prefetch ON, A-tile cache ON |
| Memory model | Four-bank behavioral SPAD, registered one-cycle response, 10 ns testbench clock |
| Simulator | Synopsys VCS / URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |

The workloads use the pinned TinyNPU harness's deterministic signed INT8
operands and signed INT32 accumulation. Each seed reports all three workload
markers, and the testbench compares all 1,536 outputs per seed with its
independent reference image (4,608 output checks total).

## Results

| Shape | Useful MACs | NMAForge controller cycles | TinyNPU array RTL cycles (R259) | TinyNPU normalized endpoint (R259) | NMAForge delta vs normalized endpoint | NMAForge MAC/cycle | NMAForge PE utilization | NMAForge SPAD read/write bytes | NMAForge bank/line-write stalls |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16×16×16 | 4,096 | 152 | 52 | 151 | +1 (+0.7%) | 26.947 | 10.53% | 512 / 1,024 | 6 / 21 |
| 16×16×32 | 8,192 | 231 | 100 | 231 | 0 (0.0%) | 35.463 | 13.85% | 1,024 / 1,024 | 26 / 24 |
| 32×32×64 | 65,536 | 1,198 | 790 | 1,305 | −107 (−8.2%) | 54.705 | 21.37% | 6,144 / 4,096 | 149 / 70 |

Cycles and counters were identical across the three R273 seeds. For the largest
shape, NMAForge reads 50% more bytes than the TinyNPU normalized model. That
case is therefore not evidence of a same-bandwidth product advantage: the
NMAForge controller overlaps requests while TinyNPU's unavailable memory path
is represented by a serialized schedule.

The normalized TinyNPU endpoint assumes 16 bytes/cycle, one-cycle read
response, serialized load/compute/store, and two accumulator-clear cycles. It
is an explicit model around the separately measured TinyNPU array interval,
not a measured TinyNPU memory-controller result. NMAForge uses behavioral SRAM
and a 10 ns simulation clock. The reported 250 MHz effective-GOPS normalization
is not measured Fmax, power, or ASIC PPA.

## Command and evidence

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS_ARCH_OVERRIDE=linux \
make -C dv/block/compute/matrix/sim tinynpu-matched-controller-benchmark \
  SEED=20261029 \
  TINYNPU_MATCH_SEEDS='20261029 20261030 20261031' \
  OUTSTANDING_DEPTH=4 NEXT_K_PREFETCH_ENABLE=1 A_TILE_CACHE_ENABLE=1 \
  PHYSICAL_ARRAY_SIZE=16 \
  CORE_OUT_DIR=/tmp/nmaforge_r273_tiny_matched_current \
  VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs
```

The compile transcript contains no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal`
diagnostics. Source identities at execution were:

| File | SHA-1 |
|---|---|
| `dv/block/compute/matrix/tb/tb_ai_tensor_matrix_core_random.sv` | `8bdebccecbc20d684ae0f6059d3c1ca25ea68b02` |
| `dv/block/compute/matrix/sim/Makefile` | `704b150ed7d71712142d243a383f8917d9e4a7da` |
| `rtl/compute/matrix/ai_tensor_matrix_datapath.v` | `471f679a9d7157434f72af4eb9793dd7ab63e164` |
| `rtl/compute/matrix/ai_tensor_matrix_array.sv` | `24d471ae65e15db4461dcbf03c25f17903db230c` |
| `rtl/compute/matrix/ai_tensor_matrix_core.v` | `f8d56efa1caf777a9b2549fdffa99920a26d0d3e` |

The row-per-shape measurements are in [`tinynpu_matched_controller_r273.csv`](tinynpu_matched_controller_r273.csv). Compile and per-seed logs are archived outside Git at
`/tmp/nmaforge_r273_tiny_matched_current_logs.tar.gz`, SHA-256
`25ceff42b1a87fc6265789aa9be7eccb6de7ee3a6459880ec7371322c120dfe1`.

## Disposition

The current evidence shows near parity on the two smaller GEMMs and an
8.2%-lower cycle count than a serialized TinyNPU memory estimate on the larger
shape, at the cost of 50% more modeled input traffic. There is no demonstrated
same-memory-service TinyNPU win yet. GEMV/decode, larger CNN, trained-model
inference, and ASIC PPA/Fmax/power remain unmeasured. `REQ-CL-028` remains
`PARTIAL`; the overall Compute Cluster disposition remains 27 `PASS-SCOPED` /
11 `PARTIAL`, `CL-DV-v1.0 HOLD`.
