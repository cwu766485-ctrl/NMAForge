# NMAForge v2 Round 26 — Final Performance Review

**Disposition: `PARTIAL`.** The fixed GELU16 model now has a passing, persistent H16 Top run, and this source SHA has fresh GEMM/GEMV, Mini-CNN, trained-CNN/DMA, and pinned TinyNPU results. No RTL optimization was implemented: the profiled LayerNorm/Requant fusion candidate cannot preserve the currently checked LayerNorm intermediate with a single compatible output, while a dual-write path has no demonstrated cycle or traffic benefit. The TinyNPU runs are useful matched-workload evidence but do not share an equivalent controller, memory, or graph timing endpoint, so they support no system speedup claim.

## 1. Frozen source and evidence

| Item | Value |
|---|---|
| Reviewed source SHA / source tested | `f627596c2c11a47fbcef08d83a56e4d00e8bc355` |
| Source tree SHA | `a790ecf716a34163645df9f2249fbaee2b36fd68` |
| Product RTL tree SHA | `fae8778d62c06c324bf5be0b5cbfea6843141e08` |
| Round 26 RTL changes | None |
| TinyNPU source SHA | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| VCS | `V-2023.12-SP1_Full64` |
| Verilator | `5.052 2026-09-05 rev v5.052` |
| Python stack | Python `3.12.13`, NumPy `2.4.6`, ONNX `1.17.0`, PyTorch `2.7.1+cpu` |
| H16 Top run | `R26-H16-GELU16-PERSISTENT-S20261123`, seed `20261123` |
| Matrix run | `R26-MATRIX-GEMM-GEMV-S20261109`, seed `20261109` |
| CNN Top run | `R26-TRAINED-CNN-DMA-R0-S20261109`, seed `20261109`, sample 42 |

The VCS license was usable: Top and Matrix compile/link completed, then their simulations ran. The H16 compile log contains an existing `LOOP-REROLL-ENABLED` debug-capacity notice from the transformer fixture; VCS reported no compile errors. The tests use behavioral SPAD and testbench AXI memory. A 4 ns clock in H16/trained-CNN tests is a simulation assumption (250 MHz arithmetic reference), not an ASIC frequency result. The Mini-CNN NMA run used the Makefile default 10 ns period.

Exact commands, run IDs, artifact hashes, and sizes are in [`round26_run_manifest.json`](../../benchmark/representative/round26/round26_run_manifest.json). Raw output and machine-readable summaries are under [`benchmark/representative/round26/`](../../benchmark/representative/round26/).

## 2. Gate 0 — GELU16 QAT model on Top: PASS

The fixed model `benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json` has SHA-256 `e7a521c762b66e5754d6d95c411c163452e0c9b01088cb11631202338cd28225`. The independent INT8 reference reports 74.4629% next-token accuracy over 4,096 held-out predictions from 1,024 synthetic-task sequences, cross-entropy 0.78771 nats, and perplexity 2.19836. This is a trained finite-state synthetic sequence model, not a natural-language-pretrained GPT-2 model.

One VCS process performed a single reset and model/SPAD initialization, a four-token prefill, and eight decode steps without clearing KV state. Each decode step checked all 1,360 Golden words, final INT32 logits, and the physical KV-cache hash against the independent INT8 reference. The eight steps passed; descriptor intervals sum to the reported decode cycles.

| Phase | Cycles | Descriptors | Golden words | Useful MACs | SPAD read/write bytes |
|---|---:|---:|---:|---:|---:|
| Prefill, four tokens | 2,734 | 40 | 368 | 3,072 | 2,560 / 1,536 |
| Decode, eight tokens | 72,238 | 424 | 10,880 | 18,240 | 72,448 / 42,112 |
| Mean decode token | 9,029.75 | 53 | 1,360 | 2,280 average | 9,056 / 5,264 per step |

Per-token cycles were 8,896; 9,023; 9,081; 8,876; 9,198; 9,075; 9,055; and 9,034. Each step is bit-exact for logits and KV state. Inputs `[13, 28, 18, 11, 7, 6, 8, 13]` were supplied by the host in advance. Logits were checked but not fed back to choose subsequent inputs, so this is persistent **teacher-forced** decode, not autoregressive feedback. Host token selection, tokenizer work, model loading, and final output handling are outside the measured Top cycles.

The current measured mean is above the exploratory 7,000 cycles/token target. The R24 9,039-cycle result is not a before/after baseline for this run because the model/quantization and workload differ. Round 26 demonstrates no decode cycle reduction from an RTL optimization.

### Per-op decode profile

| Opcode | Operation | Descriptors | Cycles | Decode share |
|---|---|---:|---:|---:|
| `0x30` | GEMM | 128 | 8,688 | 12.03% |
| `0x34` | Residual | 24 | 12,720 | 17.61% |
| `0x35` | GELU | 8 | 3,184 | 4.41% |
| `0x36` | Requant | 104 | 14,816 | 20.51% |
| `0x38` | LayerNorm | 64 | 23,872 | 33.05% |
| `0x39` | Causal Softmax | 16 | 3,806 | 5.27% |
| `0x43` | KV Write | 48 | 2,528 | 3.50% |
| `0x44` | KV Read | 32 | 2,624 | 3.63% |
| **Total** |  | **424** | **72,238** | **100.00%** |

SFU busy totals 55,926 cycles (77.42% of the decode interval) as an overlapping activity counter. It is not an exclusive phase and is not added to the opcode total. Matrix active totals 1,664 cycles, or 208/token; KV busy totals 3,152 cycles. See [`opcode_profile.csv`](../../benchmark/representative/round26/transformer/opcode_profile.csv) and [`persistent_decode.csv`](../../benchmark/representative/round26/transformer/persistent_decode.csv).

## 3. Gate 1 — SFU optimization assessment: PARTIAL

The current workload is LayerNorm-heavy. A 16-element LayerNorm descriptor takes 373 cycles; the 64 LayerNorm descriptors account for 23,872 cycles. The candidate bounds below are optimistic cycle-removal ceilings, not predicted results or measured savings.

| Candidate | Profile interval | Zero-cost upper bound | Main cost/constraint | Disposition |
|---|---:|---:|---|---|
| Exact LayerNorm row batching | 23,872 cycles / 33.05% | 1.494× | Would batch exact per-row statistics; descriptor and arithmetic shares were not isolated, and additional multi-row state/control has no measured cost. Removing all LN work is not attainable because normalization is required. | Not implemented |
| Residual + LayerNorm | 12,720 / 17.61% | 1.214× | LayerNorm uses `src0` for data, `src1` for gamma, and `beta_base` for beta. A separate residual operand requires new descriptor/operand semantics and must preserve the rounded residual intermediate. | Not implemented |
| LayerNorm + Requant output | 3,552 / 4.92% | 1.052× | Most bounded candidate. The top workload checks the INT32 LayerNorm intermediate. A single packed output would remove a checked tensor; producing both outputs retains writes and has no demonstrated traffic/cycle gain. | Selected for follow-up analysis; not implemented |

The 3,552-cycle bound is the two 222-cycle Requant descriptors per token across eight tokens. It is a screening ceiling, not realized improvement. If that entire interval vanished at zero replacement cost, mean decode would be 8,585.5 cycles/token, still above the 7,000 target. Removing all LayerNorm cycles gives a mathematically optimistic 6,045.75 cycles/token, but eliminates required arithmetic and is not an implementable design estimate.

No ABI, golden, or RTL modification was made. This preserves the current exact fixed-point contract and all intermediate checks. Accordingly, there is no Round 26 optimized-versus-baseline Top comparison and no new register, mux, area, or timing estimate. VCS compiled the unchanged Top source; SpyGlass/DC/latch-width reports were not run because RTL was unchanged and full signoff was outside this round.

## 4. Gate 2 — GEMM/GEMV controller profile: data collected; policy closure PARTIAL

Three GEMM cases and the fixed GEMV shape set passed Golden on the current source SHA. Matrix measurements include the controller and a one-cycle behavioral SPAD. Activity counters can overlap; no dedicated exclusive `Setup Cycles` counter is emitted, so request/wait values are shown separately and are not added to total cycles.

| GEMM M×N×K | Total cycles | MAC active | Useful MAC/cycle | Bank stalls | Line stalls | Prefetch wait | Arbiter stall | Writeback wait | Outstanding high water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16×16×16 | 175 | 16 | 23.406 | 20 | 25 | 47 | 45 | 25 | 3 |
| 16×16×32 | 263 | 32 | 31.148 | 27 | 26 | 104 | 53 | 26 | 4 |
| 32×32×64 | 1,407 | 256 | 46.579 | 162 | 96 | 674 | 258 | 96 | 4 |

The 32×32×64 case has the largest observed data/controller pressure: 384 bank reads (6,144 bytes), 162 bank stalls, 96 line stalls, 674 prefetch-wait activity cycles, and 258 arbiter-stall activity cycles. Its 256 MAC cycles are a small portion of the 1,407 total. These counters are not mutually exclusive. The existing prefetch overlaps 240 cycles and the tile cache has 32 hits; no Round 26 scheduling changes were applied.

GEMV results are recorded in [`round26_gemm_controller_profile.csv`](../../benchmark/representative/round26/round26_gemm_controller_profile.csv). For M=8/16, the B-fold cache saved observed B reads (19 for 8×16×19, 64 for 8×16×65, 57 for 16×16×19, and 192 for 16×16×65). These cases do not include same-operand paired `0x30` GEMM runs for each exact shape, so they do not validate an automatic shape-selection policy. No Mapper policy or descriptor-reuse change was made.

## 5. Gate 3 — CNN transfer and compute accounting: PARTIAL

### Trained 570,164-MAC CNN, one current Top sample

The fixed trained 3×3 + pointwise INT8 CNN ran through two CMDQ descriptors in Top RTL, with all 20,800 expected tensor words passing for sample 42 (label 1, predicted 1). Model SHA-256 is `763a86d8a4ad508bd3ec34106163891f26870a98868889b0bc6c8bfe285370f8`; workload-memory SHA-256 is `7d2dea09ee8003d15fa05dfacdfd078697482173cabb061ff5a43e1a87666e17`.

| Measured field | Result |
|---|---:|
| Useful MACs | 570,164 |
| CMDQ execution | 12,947 cycles |
| Actual DMA live payload | 10,944 bytes |
| DMA setup + transfer window | 3,019 cycles (2,879 DMA busy) |
| AXI reads | 45 bursts / 684 beats; max observed latency 50 cycles |
| Top SPAD reads / writes during compute | 64,064 / 16,640 bytes |
| Matrix active / total CMDQ | 2,704 / 12,947 cycles |
| Useful MAC/cycle | 44.0383 |
| Array utilization field | 82.37% (testbench-derived metric) |
| DMA + CMDQ subtotal | 15,966 cycles |

The 4 ns clock period is simulated timing only. The DMA payload excludes 83,232 bytes of test-only poison/sentinel initialization; those bytes are not required production transfers. The prior held-out classifier evidence for the same model reports 346/360 correct (96.11%); Round 26 reran one Top sample, not the full held-out set.

Host Im2col alone has a generator sub-timer of 0.497 ms for 7,056 valid im2col bytes. Total workload-generation script wall time was 1.60 s and includes golden creation and file emission, so it is not an inference-time estimate. The workload also performs 8×8-to-16×16 upsampling, coordinate-plane creation, and input/weight packing; their production Host time is not separated. Global average/argmax is identified as host postprocessing but was not timed. Final output readback and the full host-plus-device inference endpoint were not measured. Thus 15,966 cycles is only the measured DMA+CMDQ subtotal, not end-to-end latency.

### Common `conv1x_mini.onnx`

Both systems ran the same ONNX model SHA-256 `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`. NMAForge's deterministic input hash matches TinyNPU's image input, and both final four-byte outputs passed the same Golden.

| System | Cycles | Included boundary | Traffic evidence |
|---|---:|---|---|
| NMAForge Top | 1,985 CMDQ cycles + separate 1,080 testbench Host-layout cycle counter | Starts with SPAD preloaded; reports command path and a separate modeled layout counter | Compute SPAD 3,360 B read / 1,600 B write; Host layout counter 144 B read / 576 B write |
| TinyNPU | 4,781 graph cycles | ONNX graph dispatch through graph simulator and behavioral DMA/SRAM shim | Six DMA loads totaling 1,088 B, one 4 B store in the log |

These are not the same start/end boundary. The NMAForge Host-layout field is a testbench cycle counter, not measured CPU wall time; the TinyNPU graph includes its graph/transfer path. Therefore there is no CNN system speedup result. Details are in [`round26_cnn_measurements.csv`](../../benchmark/representative/round26/round26_cnn_measurements.csv), the NMA/Tiny manifests, and their raw logs.

## 6. Gate 4 — TinyNPU comparison: matched workloads, unmatched endpoints

TinyNPU was freshly built/run from the pinned source using Verilator 5.052. Its six engine regression tests passed. The matrix GEMM/GEMV cases use the same mathematical shapes and both implementations pass Golden, but TinyNPU reports direct-array input-to-array-stable cycles while NMAForge reports controller cycles with behavioral SPAD service. TinyNPU does not report corresponding byte/stall counters in this endpoint. Raw cycles and MAC/cycle are therefore presented side by side in [`round26_shape_comparison.csv`](../../benchmark/representative/round26/round26_shape_comparison.csv), classified as not comparable for system speedup.

Raw endpoint observations:

- GEMM: NMAForge measured 175 / 263 / 1,407 cycles, and TinyNPU direct array measured 52 / 100 / 790 cycles for 16×16×16, 16×16×32, and 32×32×64. NMAForge's useful MAC/cycle was 23.41 / 31.15 / 46.58; TinyNPU's was 78.77 / 81.92 / 82.96. NMAForge's extra controller and SPAD servicing contributes cycles that are absent from the direct-array endpoint.
- GEMV: NMAForge measured 75 / 150 / 255 / 612 cycles versus TinyNPU's 100 / 100 / 100 / 244 for 1×13×17, 8×16×19, 16×16×19, and 16×16×65. The M=1 raw result is lower for NMAForge at this endpoint pair; the batched raw results are higher. Since endpoints differ, neither is a system win/loss.
- Mini CNN: both final results are byte-exact, but graph/transfer/Host boundaries differ as described above.
- Trained CNN and H16 Transformer on TinyNPU: not run as matched models.

There is no same-model Transformer subgraph run on TinyNPU in this round. No cross-project system speedup is claimed.

## 7. Disposition and architecture recommendation

| Gate | Status | Evidence-based conclusion |
|---|---|---|
| GELU16 QAT model on Top | **PASS** | Four-token prefill and eight persistent teacher-forced decode steps; every logits/KV/tensor Golden check passes. |
| SFU optimization | **PARTIAL** | Bottleneck profile is closed; no new RTL optimization demonstrated because the bounded fused candidate conflicts with the checked INT32 intermediate contract. |
| GEMM/GEMV controller profiling | **PASS for fixed cases; PARTIAL for policy** | Fixed shapes pass and stalls are visible; no paired-shape policy experiment or scheduler change. |
| CNN full application timing | **PARTIAL** | Current trained-CNN DMA+CMDQ and Mini-CNN Top are measured; complete Host, readback, and postprocessing boundaries remain unmeasured. |
| TinyNPU comparison | **PARTIAL** | Fresh pinned runs and shared Golden; no equivalent system endpoints or Transformer model run. |

Keep the current two innovations as research candidates: Shape-Adaptive GEMV shows B-read reuse in batched cases, while the H16 workload does not prove model-level GEMV improvement; fused row-major CNN execution has strong local CMDQ evidence, while full host/device accounting remains incomplete. This round does not establish TinyNPU leadership or justify an architecture-freeze claim based on complete application performance. Keep RTL unchanged before formal front-end signoff; any later optimization should first instrument the exact LN-to-Requant tensor dependency and preserve all checked intermediates.

## 8. Reproduction and artifact index

The VCS/TinyNPU raw logs are stored losslessly as `.log.gz`; H16 per-token/profile CSV/JSON, CNN manifests/memory/Golden, and shape/counter tables are under [`benchmark/representative/round26/`](../../benchmark/representative/round26/). `round26_run_manifest.json` contains source/model/weight/data hashes, seeds, exact expanded commands, tool versions, and SHA-256/byte size for every archived evidence file except the manifest itself. It includes no private license endpoint, PDK, SRAM library, or EDA database.
