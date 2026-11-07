# NMAForge v2 Round 6 Decision

**Disposition: `RESEARCH_BASELINE_PARTIAL`.** The fixed Round 6 tasks are
complete. No full DV sign-off, ASIC sign-off, TinyNPU system victory, or 400 MHz
closure is claimed. This report ends the round; it does not start Round 7.

## 1. Frozen identities and evidence

| Item | SHA / value |
|---|---|
| Reviewed starting HEAD | `1c0d147b0809c235de7caef6d68349f889556502` |
| GEMV Mapper and asymmetric unit-test fix | `e100aa2af78ab7a95febc17f265f389f996a8404` |
| TinyNPU benchmark wrapper fix | `54033ffd3a28378e867947e99598e79d2060fb9d` |
| Synthesis-flow report cleanup | `439e441` |
| Product RTL baseline | `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23` |
| TinyNPU reference | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| Functional / GEMV seed | `20261106` |
| Main comparison run ID | `R6-TINY-COMPARISON-S20261106` |
| VCS / DC | `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |
| Verilator / Python / NumPy / ONNX | `5.052` / `3.12.13` / `2.4.6` / `1.17.0` |

No product RTL changed in Round 6. The source changes are limited to GEMV
Mapper packing and a regression test, TinyNPU benchmark invocation, and the
DC script's pre-map report handling. `main` R250 and other worktrees were not
changed.

Machine-readable evidence:

- [TinyNPU GEMM/GEMV and CNN outputs](../../benchmark/tinynpu/benchmark_summary.json)
- [TinyNPU shape matrix CSV](../../benchmark/tinynpu/gemm_results.csv)
- [TinyNPU/CNN result CSV](../../benchmark/tinynpu/cnn_results.csv)
- [Transformer GEMM versus GEMV CSV](../../benchmark/v2_round6_transformer_decode_mapping_20261106.csv)
- [GEMV Cache × Prefetch CSV](../../benchmark/v2_round6_gemv_four_way_20261106.csv)
- [CNN Legacy versus Linear-Row CSV](../../benchmark/v2_round6_cnn_legacy_linearized_20261107.csv)

## 2. Transformer GEMV failure and fix

Opcode `0x52` consumes physical B rows in K-major order. For logical weights
`W[K,N]`, a physical row is `B[k,n] = W[k,n]`. The Mapper's old
`gemv_rhs()` instead transposed the data and constructed the row from
`matrix[n][k]`. This escaped a symmetric/low-discrimination Mapper check but
changed results for asymmetric weights.

The fix emits each row from `matrix[k_index]`, pads N lanes with zero, and
leaves signed byte encoding and K padding intact. An asymmetric signed INT8
test with one-hot A distinguishes the bad vector `[3,-7,11,-15]` from the
correct independent GEMM result `[9,10,11,12]`. It also checks physical row
bytes, padding, and the GEMV output. Matrix RTL was not changed.

The repaired VCS Top run completed all 86 descriptors with exact final
Prefill/Decode outputs and K/V cache images for both mappings:

| Mapping | Prefill cycles | Decode cycles | Total | Decode SPAD read / write |
|---|---:|---:|---:|---:|
| Default GEMM `0x30` | 5,682 | 5,715 | 11,397 | 1,880 / 1,048 B |
| Q/K/V GEMV `0x52` | 5,682 | 5,715 | 11,397 | 2,024 / 904 B |

Thus GEMV has **zero measured H=4 single-token Decode cycle improvement** in
this workload; it transfers 144 B more on reads and 144 B fewer on writes.
This is correct functional evidence, not an acceleration result. A separate
Matrix-core M=1 shape `1×13×17` measured 73 cycles with Next-K Prefetch OFF
and 69 with it ON, at the same 304 read bytes. That 5.5% microcase reduction
does not change the whole Transformer Decode result. The B-fold cache is
disabled at M=1. Batched M=8/16 results are reported separately below.

Commands and logs:

```bash
cd sw/tools
PYTHONPATH=. python3.11 -m unittest -v test_cimforge_mapper.py

cd dv/subsystem/top_smoke/sim
make ai_comp AI_TRANSFORMER_MAPPING_POLICY=gemm \
  AI_TRANSFORMER_MANIFEST=/tmp/nmaforge_r6_gemm_baseline_manifest.json
./simv +ntb_random_seed=20261106 +AI_RANDOM_CASES=0 +AI_SEED=20261106 \
  +AI_TRANSFORMER_ONLY -l /tmp/nmaforge_r6_gemm_baseline.log
make ai_comp AI_TRANSFORMER_MAPPING_POLICY=gemv_qkv \
  AI_TRANSFORMER_MANIFEST=/tmp/nmaforge_r6_gemv_manifest.json
./simv +ntb_random_seed=20261106 +AI_RANDOM_CASES=0 +AI_SEED=20261106 \
  +AI_TRANSFORMER_ONLY -l /tmp/nmaforge_r6_gemv.log
```

Mapper unit result: 7/7 PASS. Top logs:
`/tmp/nmaforge_r6_gemm_baseline.log` and `/tmp/nmaforge_r6_gemv.log`.

## 3. TinyNPU benchmark and boundary

The pinned TinyNPU regression passed its engine reference check 6/6, three
GEMM shapes, four GEMV shapes, and `conv1x_mini.onnx` Golden. Both systems use
the same deterministic signed INT8 operands and independent INT32 Golden for
the matched GEMM matrix.

| GEMM shape | NMAForge Matrix controller + behavioral SPAD | TinyNPU array RTL | TinyNPU serialized-memory estimate | NMA / estimate |
|---|---:|---:|---:|---:|
| 16×16×16 | 173 cycles | 52 cycles | 151 cycles | 1.146× |
| 16×16×32 | 259 | 100 | 231 | 1.121× |
| 32×32×64 | 1,380 | 790 | 1,305 | 1.058× |

NMAForge timing includes its Matrix controller and one-cycle four-bank
behavioral SPAD. TinyNPU's raw number is array-only. Its normalized estimate
adds serialized load/store service at 16 B/cycle, one-cycle read response and
two accumulator-clear cycles. The NMA/estimate ratios mean 5.8–14.6% more
cycles for the NMAForge measured endpoint under this model. They are
**mixed measured/modeled cycle ratios**, not a same-memory full-system
speedup. TinyNPU has higher direct-array MAC/cycle for all three GEMMs.

For the exact shared `conv1x_mini.onnx` model (1,872 MACs; model SHA-256
`1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`; input
SHA-256 `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`),
both systems pass output Golden:

| Endpoint | Compute / graph cycles | Host layout | Notes |
|---|---:|---:|---|
| NMAForge Legacy | 1,985 CMDQ cycles | 1,080 testbench-emulated cycles | Excludes preload, descriptor setup and final host read |
| NMAForge `0x53` Linear-Row | 1,504 CMDQ cycles | 0 | Same VCS model, bit-exact |
| TinyNPU ONNX Graph | 4,781 graph cycles | N/A | Graph dispatcher and DMA/SRAM testbench shim |

The graph and CMDQ start/stop windows and initialization work are not equal;
therefore **no CNN cross-system speedup is computed**. Full-system Transformer
QKV/FFN comparison is `NOT_RUN`: there is no matching TinyNPU graph artifact
and memory-service endpoint with these same weights, quantization, and
per-layer output checks in this run. Primitive GEMV/GEMM rows do not substitute
for that model-level comparison.

Exact command:

```bash
TINYNPU_BENCH_OUT=/tmp/nmaforge_r6_tiny_comparison_final \
TINYNPU_WORK_ROOT=/tmp/nmaforge_r6_tiny_reference \
TINY_NPU_ROOT=/tmp/nmaforge_research_tinynpu_8216c22 \
PYTHON=/tmp/nmaforge_r6_py/bin/python \
VERILATOR=/tmp/nmaforge_r6_verilator_src/bin/verilator \
SEED=20261106 BENCH_RUN_ID=R6-TINY-COMPARISON-S20261106 \
bash benchmark/tinynpu/run_comparison.sh
```

The CNN's same-system Legacy→Linear-Row compute interval is 1,985→1,504
cycles: `1.320×` ratio, or 24.2% fewer compute cycles. Including the
testbench-emulated Legacy layout, the phase interval is 3,065→1,504 cycles:
`2.038×`, or 50.9% fewer simulated cycles. Neither is a TinyNPU speedup.

## 4. Innovation results

### Shape-Adaptive GEMV, B-fold cache and prefetch

The fixed four-way seed `20261106` test used a registered four-bank behavioral
SPAD and exact Golden:

| Shape | Both OFF | Prefetch only | Cache only | Cache + Prefetch | B-read bytes OFF→Cache |
|---|---:|---:|---:|---:|---:|
| 8×16×19 | 197 | 194 | 147 | 148 | 864→560 |
| 8×16×65 | 544 | 532 | 398 | 381 | 2,720→1,696 |
| 16×16×19 | 391 | 382 | 270 | 265 | 1,728→816 |
| 16×16×65 | 1,071 | 1,033 | 627 | 629 | 5,440→2,368 |

Cache-only reduces cycles by 25.4–41.5% versus both OFF and cuts B reads by
35.2–56.5%. Prefetch-only is 1.5–3.7% lower cycles. Combined prefetch is
slightly worse than cache alone at 8×16×19 and 16×16×65. These effects apply
to batched GEMV microbenchmarks; the H=4/M=1 Decode Top showed no gain.

### Fused epilogue, Linear-Row and Tile Forwarding

The `conv1x_mini` Legacy/Linear-Row pair is exact and combines fused epilogue
with consumer-ready output layout; it does not separate those two effects.
Historical trained ten-class CNN evidence is 3,193→2,712 CMDQ cycles across
396 exact samples. Historical trained Digits MLP evidence is 110,155→34,761
cycles with exact Golden. A separate directed Tile Forwarding core test
measured 288→265 producer+consumer cycles (7.99%), reducing consumer A reads
from 512 to 256 B. These are different workloads/experiments and must not be
multiplied. A Round 6 fused-requant-only result and a matched full Transformer
fused-path result remain open.

## 5. 300/400 MHz synthesis and 128 KiB SRAM

The 300 MHz Matrix Core command used Design Compiler `V-2023.12-SP1`, the
licensed full TSMC28 HPC+ RVT SSG 0.72 V / 125°C `.db`, and the checked-in
`syn/run_compute_cluster_round5.tcl` at `NMAFORGE_DC_COMPILE_MODE=standard`.
The SDC uses 3.333333 ns period, 100 ps uncertainty, 50 ps transitions,
250 ps max/50 ps min IO delays, 20 fF output load, and no false or multicycle
exceptions. The full parameterized Matrix Core elaborated, then
`compile -map_effort high` spent the 240 s bound mapping the 16×16 array. Exit
status was 124 and no mapped netlist or report was produced. Earlier probes
found that a Liberty `.lib` is not accepted as DC's target DB and a 43-cell
clock-gating subset lacks required logic gates; the final attempt used the
full RVT DB successfully and reached mapping. This is a mapping-time limit,
not a license blocker.

| Requested point | Status | Evidence |
|---|---|---|
| Matrix Core 300 MHz | `INCOMPLETE_TIMEOUT` | Full elaboration, mapping did not finish in 240 s |
| Matrix Core 400 MHz | `NOT_RUN` | No mapped 300 MHz baseline to evaluate |
| Matrix Core 450 MHz | `NOT_RUN` | Not started |
| Compute Cluster 400 MHz | `NOT_RUN` | Not started |

No cell area, WNS/TNS, critical path, Fmax or power number is claimed for this
round. The repo's historical 250 MHz pre-layout evidence is a separate
configuration and does not answer Round 6.

Capacity-only SRAM geometry: the 4096×32, 16 KiB single-port macro has LEF
area 35,239.86555 µm². Eight macros total 128 KiB and 0.281919 mm² geometry;
32 total 512 KiB and 1.127676 mm² geometry. The SRAM Liberty candidates use
0.81 V / 0.9 V corners; a compatible 0.72 V timing view was not found. The
macro is single-port while the behavioral scratchpad gives Host and scheduler
independent ports. An adapter must arbitrate/time-multiplex these sources and
preserve response latency/holds, writes, and parity. Until then 128 KiB is a
capacity/geometry candidate only, not an integrated or timing-qualified SRAM
implementation.

## 6. Remaining open items

- H=4 Transformer GEMV mapping is correct but provides no measured Decode
  cycle improvement; a representative trained M=8/16 GEMV-heavy Transformer
  workload was not run.
- TinyNPU full CNN/Transformer endpoints with matched memory service and equal
  start/stop boundaries are not available; no cross-system system speedup is
  proven.
- Requant fusion alone is not separated from Linear-Row layout in the CNN
  model comparison. Full Top Tile Forwarding and model-level interaction are
  still open.
- Matrix Core mapped synthesis exceeded the 240 s bound. Matrix 400/450 MHz,
  Cluster 400 MHz, PPA, and workload power remain open.
- 128 KiB macro timing/port adapter, parity implementation, and integrated
  physical cost remain open.
- Full DV closure, broad v2 fault/fault-phase crossing, complete UVM, Formal,
  Mutation, CDC/RDC, and Tapeout Readiness remain explicitly outside Round 6.

Current disposition remains `RESEARCH_BASELINE_PARTIAL`; do not mark v2 signed
off or start another round automatically.
