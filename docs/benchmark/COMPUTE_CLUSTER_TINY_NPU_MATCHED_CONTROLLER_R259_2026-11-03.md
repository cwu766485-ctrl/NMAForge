# Matched-vector TinyNPU Matrix Controller Replay — R259

**Result:** PASS for the three named 16×16-array GEMM workloads on the
NMAForge Matrix controller. This is a paired functional/cycle experiment, not
an ASIC result and not a fully common-memory RTL comparison.

## Reproducible identity

| Item | Value |
|---|---|
| NMAForge RTL baseline | `ae2415390a32f58318255a9534fade6467c7f1a8` |
| TinyNPU | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| Run ID | `R259-TINY-MATCH-CONTROLLER-D4P1C1-20261103` |
| Seeds | `20261029`, `20261030`, `20261031` |
| NMAForge configuration | 16×16 array, outstanding depth 4, next-K prefetch ON, A-tile cache ON |
| Memory model | Behavioral banked SPAD; registered one-cycle response; 10 ns simulation period |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64` |

The vectors are exactly the signed INT8 operands used by the pinned TinyNPU
array harness:

```text
A[r,k] = ((3*r + 2*k + 1) % 9) - 4
B[k,c] = ((2*k - 3*c + 5) % 9) - 4
C       = A × B, signed INT32 accumulation
```

Each run checks every output against the independent integer Golden. The
focused controller harness reports 3/3 workload markers per seed (9/9 total);
the checked output counts are 256, 256, and 1,024 per workload on every seed.
Cycle, traffic, and stall values are identical across all three seeds.

## Results

The NMAForge interval starts at Matrix command acceptance and ends after the
last output write and `done`. TinyNPU array cycles are directly simulated. Its
common endpoint adds the existing explicit serialized-memory estimate: 16
bytes/cycle, one-cycle read response, load/compute/store serialization, and
two accumulator-clear cycles. TinyNPU does not expose the corresponding SPAD
request/response interface in this wrapper.

| Shape | Useful MACs | NMAForge controller cycles | TinyNPU array RTL cycles | TinyNPU normalized endpoint | NMAForge delta vs normalized TinyNPU | NMAForge MAC/cycle | NMAForge SPAD read/write bytes |
|---|---:|---:|---:|---:|---:|---:|---:|
| 16×16×16 | 4,096 | 152 | 52 | 151 | +1 (+0.7%) | 26.947 | 512 / 1,024 |
| 16×16×32 | 8,192 | 231 | 100 | 231 | 0 (0.0%) | 35.463 | 1,024 / 1,024 |
| 32×32×64 | 65,536 | 1,198 | 790 | 1,305 | −107 (−8.2%) | 54.705 | 6,144 / 4,096 |

All NMAForge cases use the same D4/P1/C1 profile and fixed one-cycle bank
response; they pass their independent Golden and drain all reads. NMAForge
records bank/line-write stalls of 6/21, 26/24, and 149/70 cycles respectively.
TinyNPU's exposed wrapper does not provide comparable stall counters.

## Interpretation and limits

This improves the paired comparison: the previous NMAForge paired run used
variable 0–3-cycle bank response, while this replay fixes the same one-cycle
behavioral response used by the Matrix ablation. With the exact same vectors,
NMAForge is within one cycle for 16×16×16 and ties the modeled endpoint for
16×16×32. For 32×32×64 it is 8.2% lower in cycles than the serialized TinyNPU
memory estimate, while issuing 6,144 read bytes versus TinyNPU's modeled 4,096
read bytes. The cycle gap therefore does not show a same-bandwidth service
advantage: NMAForge's banked controller overlaps work, whereas TinyNPU's
missing memory wrapper is represented by a serialized estimate.

The largest-shape result is promising, but it is not a defensible product-level
TinyNPU win. A true common-resource comparison still needs a TinyNPU memory
adapter or an equivalent RTL wrapper and the same enforced memory service on
both sides. No GEMV/decode, larger CNN, trained-model, ASIC PPA, Fmax, or power
claim is made. The 250 MHz effective-GOPS field emitted by the testbench is a
normalization assumption only.

## Command and evidence

```sh
make -C dv/block/compute/matrix/sim tinynpu-matched-controller-benchmark \
  SEED=20261029 \
  TINYNPU_MATCH_SEEDS='20261029 20261030 20261031' \
  OUTSTANDING_DEPTH=4 NEXT_K_PREFETCH_ENABLE=1 A_TILE_CACHE_ENABLE=1 \
  PHYSICAL_ARRAY_SIZE=16 \
  CORE_OUT_DIR=/tmp/nmaforge_tinynpu_d4p1c1_matched_controller_ae24153 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

The tested testbench SHA-1 is `9b636a119389b2089c5ef3902c551c3b61c11bba`,
the Makefile SHA-1 is `72cdf002c906bf933b3430d1b356d93f3c71467b`, and the unchanged
Matrix RTL SHA-1 is `820dbe2925eef1abd2b79b7176f13706cbde6a50`. Logs and compile
transcript are archived outside Git at
`/tmp/nmaforge_tinynpu_d4p1c1_matched_controller_ae24153/r259_logs.tar.gz`
(SHA-256 `5af0f432672053b14d7a40b3906e0bbf37fe995227556f57dbce1dcefb568ac3`).
Generated simulator binaries, coverage databases, and raw logs are not checked
into the repository.

The row-per-seed machine-readable results are in
[`matched_controller_r259.csv`](../../benchmark/tinynpu/matched_controller_r259.csv).
