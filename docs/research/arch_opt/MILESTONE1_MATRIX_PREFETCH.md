# Milestone 1 — Matrix Operand Prefetch and Scheduling

## Decision

**REWORK / NO NEW MATRIX RTL ADMITTED.** The completed product Top campaign measures the missing GEMV and K=128 GEMM rows through descriptor, CMDQ, Matrix controller, single SPAD arbiter, registered response, completion, and strict Golden checking. Existing D4/P1/C1 controls remain the selected baseline. No second buffer, SRAM port, MAC, or speculative fault mode is justified by the measured traces.

Baseline product RTL: `c93ea144713d5fafe2e8a5509029927cd6859e75`.
Research source commit before this run: `c8457126ddd482438216920708912312c945cd4a`.
Simulation: VCS `V-2023.12-SP1_Full64`, 4 ns behavioral clock, 128 KiB four-bank SPAD, 256 INT8 MAC. A simulation period is not an Fmax claim.

## Fresh real-Top coverage

`tools/benchmark/phase1/run.py` now submits these descriptors. Every row reported `REPRESENTATIVE_MODEL_PASS`, and the independent signed INT32 Golden scan passed:

| Product operation | Shapes measured |
|---|---|
| GEMM `0x30` | 4×4×32, 16×16×16, 16×16×32, 16×16×128, 32×32×64 |
| GEMV `0x52` | M=1,4,8,16; N=16; K=16,32,64,128 |

Raw profiles and command files are archived under `/tmp/nmaforge-archopt-m1-runs/top-suite` for this run. `benchmark/research/arch_opt/MILESTONE1_TOP_BASELINE.csv` contains exact cycles, traffic, response latency and exclusive-state measurements.

| Shape | CMDQ cycles | Read/Write bytes | Useful MAC/cycle | Operand wait |
|---|---:|---:|---:|---:|
| GEMM 4×4×32 | 126 | 256 / 64 | 4.063 | 11 |
| GEMM 16×16×128 | 522 | 4096 / 1024 | 62.774 | 221 |
| GEMM 32×32×64 | 986 | 6144 / 4096 | 66.467 | 312 |
| GEMV M1 K32 | 143 | 544 / 64 | 3.580 | 49 |
| GEMV M4 K32 | 161 | 640 / 256 | 12.720 | 52 |
| GEMV M8 K64 | 325 | 1536 / 512 | 25.206 | 147 |
| GEMV M16 K128 | 1109 | 7168 / 1024 | 29.547 | 697 |

Every measured read response had the expected two-cycle registered latency. The isolated Top profile had zero denied-request cycles and zero multi-client request cycles. Observed Operand Wait is therefore not evidence of a physical four-bank conflict. H32 remains the meaningful concurrent case: 350,189 cycles, 14,600 Matrix Operand Wait cycles and 4,288 request-form arbitration waits across eight decode windows.

## Existing-switch ablation

The corrected three-seed D2/D4, prefetch and cache sweep is **existing configuration evidence**, not a new RTL gain. The CSV is `/tmp/nmaforge-archopt-runs/config-20261111/matrix_config_comparison.csv`; it covers 4×4×32, 8×8×32, 16×16×32, 16×32×32 and 32×32×64. D4/P1/C1 reduces 32×32×64 from 1,671 to 1,135 cycles in that core responder campaign, with Golden PASS. This must not be counted again as a new optimization.

Candidate A (existing A/B caches, next-K prefetch, depth-4 outstanding reads) is retained as the product baseline. Candidate B (another double buffer) has no demonstrated removable interval: the active path already uses ping-pong tiles and the Top traces show registered responses and no denied grants in the isolated matrix suite. Candidate C (request rescheduling) lacks a closed-loop grant opportunity; changing issue order without a competing client only moves the same mandatory two-cycle responses.

The H32 trace instead ranks SFU fetch/response and control as the larger opportunity: 67,952 fetch-issue + 134,144 response + 29,456 arithmetic/control + 15,093 pipeline-wait exclusive cycles. That work belongs to the separately scoped safe SFU study and is not silently implemented here.

## Milestone result

- Real product Top missing rows: **PASS**.
- Strict Golden and response ledger: **PASS**.
- New Matrix RTL: **REJECTED / NOT JUSTIFIED** by current evidence.
- ≥10% new workload gain: **NOT DEMONSTRATED**; existing switch gains are baseline configuration evidence only.
- Protection, reset, abort and ownership contracts: unchanged.

Milestone 2 should reuse product `0x52` and compare its M1/M4 mapping with the existing shape-adaptive research wrapper under identical Top memory service. M8/M16 should keep the established path whenever adaptive mapping is slower. No duplicate GEMV engine or public ABI change is proposed.
