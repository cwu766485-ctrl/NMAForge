# Architecture Optimization — Milestone 1 Matrix Prefetch and Scheduling

## Decision

**REWORK / NO NEW MATRIX RTL ADMITTED.** Gate 0 identified Matrix operand wait as
a real measured opportunity, but Milestone 1 did not demonstrate a second safe
schedule beyond the existing depth-4, next-K and A/B-cache mechanisms. The
product RTL is unchanged in this milestone. Do not add a FIFO, SRAM port, MAC
array or speculative fault mode.

References are explicit:

- approved `nmaforge`: `c93ea144713d5fafe2e8a5509029927cd6859e75`;
- Phase 4 CNN candidate: `b1dd75b8d1b6bb0465bdb3452df556a7919f7c4d`;
- Gate 0 inventory: `df2bdecc2cfb1989285555f8c1511815b59ab307`;
- this research branch: commit containing this report;
- Round 29 Matrix ablation source/log evidence: `f2bed3dd7386b1b9cc79c20bb065d06354b1beca`;
- VCS: `V-2023.12-SP1_Full64`, default four-bank behavioral SPAD, 256 MACs.

## Existing-control ablation

Round 29 measured the same Matrix core, operands and randomized registered
four-bank responder over three seeds for depth 2/4, next-K prefetch OFF/ON and
B-fold/A-tile cache settings. Every point reported bit-exact Golden. The full
raw CSV is `benchmark/representative/round29/matrix/gemv_ablation.csv`; the
GEMM control sweep is archived in `benchmark/representative/round28/matrix_ablation.csv`.

| Workload | Weak control setting | Full existing setting | Improvement | Changed traffic |
|---|---:|---:|---:|---:|
|16×16×16 GEMM|211 cycles (D2/P0/C0)|175 cycles (D4/P1/C1)|17.1%|512B reads in both archived rows|
|16×16×32 GEMM|316|263|16.8%|1,024B reads in both archived rows|
|32×32×64 GEMM|2,118|1,407|33.6%|8,192→6,144B reads|
|M8×16×19 GEMV, B-cache/prefetch off|217 cycles|153 cycles (B-cache + prefetch)|29.5%|864→560B reads|
|M8×16×65 GEMV, B-cache/prefetch off|533|383|28.1%|2,720→1,696B reads|
|M16×16×65 GEMV, B-cache/prefetch off|1,072|613|42.8%|5,440→2,368B reads|

The existing configuration is therefore retained as the baseline for any new
experiment. It already overlaps accepted next-K requests with MAC preparation,
reuses A/B tiles under their lifetime rules and limits outstanding reads to four.
A logical `prefetch_wait` counter is not by itself physical bank conflict: all
requests still pass through the sole `ai_spad_arbiter` admission point.

## Fresh measurement attempt and limitation

The requested exact missing rows (GEMV M=1/4/8/16 × K=32/64/128 where absent,
and GEMM K=128 rows) require a new compile/run using the current candidate tree.
The commands were started with identical output directories and seeds:

```bash
make -C dv/block/compute/matrix/sim product-gemv-regress \
  SEEDS='20261109 20261110 20261111' \
  CORE_OUT_DIR=/tmp/nmaforge-archopt-runs/gemv
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEEDS='20261109 20261110 20261111' \
  PIPELINE_BENCH_OUT=/tmp/nmaforge-archopt-runs/config
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  ARRAY_SEEDS='20261109 20261110 20261111' \
  ARRAY_OUT_DIR=/tmp/nmaforge-archopt-runs/sizes
```

VCS compilation reached the Synopsys license request and stopped with
`Cannot connect to the license server` / `VCS-BASE-COMPILE` unavailable. No new
cycles, Golden, traffic or fault result is accepted from that attempt. The
missing rows remain `NOT_RUN` in the Gate 0 CSV. This is an environment block,
not a performance result.

## Candidate assessment

**Candidate A — existing controls.** PASS as a baseline ablation. The measured
benefit above is already present in the current Matrix RTL/configuration; it is
not a new candidate gain. Keep D4/P1/A-cache/B-cache enabled where the existing
parameter and ownership contracts permit.

**Candidate B — double-buffered operand fetch.** REWORK. A second operand buffer
could only help if the closed-loop arbiter grants a next-K request early enough
without overwriting the active tile. The current logs show outstanding depth
reaching four and prefetch/response/line stalls moving with randomized service.
No cycle-accurate model proving an additional removable interval was completed;
therefore no RTL change is justified. The model must include request acceptance,
2-cycle registered response, bank ownership, parity/protection response, abort,
reset and tile lifetime before implementation.

**Candidate C — FSM scheduling.** REWORK. The current FSM has measurable request,
wait and prefetch states, but a static trace cannot distinguish an avoidable bubble
from a true RAW dependency or a denied arbiter grant. Build a reacting multi-client
arbiter model, then compare issue order against the actual response-owner ledger.

## Safety and cost boundary

Any admitted change must preserve `ai_spad_arbiter` as the only data admission
point, maintain per-request authorization/parity and response ownership, drain
accepted reads on abort/watchdog/reset, and keep output commit ordered. No
transparent cache or earlier validated copy may replace a required SRAM read.
The current evidence supports zero additional SRAM bytes/ports and zero MACs;
any proposed operand double buffer would add flops and muxes whose width/lifetime
must be measured before RTL.

## Milestone 1 result and next step

- Numerical Golden: PASS for the archived three-seed existing-control ablation.
- Fault/reset: PASS in the associated Matrix product regressions; no new
  candidate RTL was run in this blocked fresh attempt.
- New RTL: NOT_RUN / LICENSE_BLOCKED.
- ≥10% target: existing-control ablation exceeds it on meaningful GEMM/GEMV
  shapes, but this is not a new optimization and cannot be counted twice.
- Product decision: **REWORK**, preserve current controls.

Milestone 2 should start only after a clean VCS license is available. First
extend the product Matrix testbench to submit the missing M/K rows through the
actual descriptor/controller path. Then compare the existing 0x52 K-fold path
against the isolated shape-adaptive wrapper under identical traffic. M1/M4 may
be candidates; M8/M16 must fall back to the existing mapping when measured
slower. True M=1 descriptor support requires an ABI/spec review before changing
public fields. No product RTL or ABI change is authorized by this report.
