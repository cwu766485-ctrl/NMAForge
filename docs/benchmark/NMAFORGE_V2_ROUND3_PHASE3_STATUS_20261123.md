# Round 3 — Phases 1–3 Status and Evidence Summary

**Snapshot:** 2026-11-23
**Disposition:** `PARTIAL`
**Scope:** evidence consolidation for the three bounded phases. This is not a product-wide sign-off, model-quality result, ASIC PPA result, or Tiny-NPU system-speedup claim.

## Executive status

| Phase | Status | What the evidence establishes | What remains open |
|---|---|---|---|
| 1 — Fair benchmark | `PARTIAL` | Three INT8 GEMM shapes and `conv1x_mini.onnx` have independent Golden results on the recorded endpoints. | Tiny-NPU normalized GEMM includes modeled memory service; CNN timing endpoints differ. A same-source-SHA GEMM rerun differs from the earlier run and is unexplained. |
| 2 — Dataflow A/B | `PASS, scoped` | The 48-case GEMV cache/prefetch matrix is bit-exact over three seeds. Three 262,144-MAC Product Top CNN command paths each pass 20,480 Golden words. | No trained CNN, production DMA schedule, or full application latency. No area/timing comparison. |
| 3 — Model/DV status | `PARTIAL` | A sanitized H64 synthetic four-layer same-Top prefix-recompute result contains four 256-logit Golden matches; basic smoke and selected regressions have recorded outcomes. | H64 run has no immutable source-SHA binding and is not persistent-KV decode. DeiT evidence is a small patch-projection case, not full embedding or encoder. UVM smoke fails; formal targets are blocked by missing `vcf`. |

The global project status remains `PARTIAL`. The workstreams have different source SHAs and measurement boundaries; their results must not be combined into one pass count.

## Frozen identities and tools

| Evidence | Source identity | Run identity | Tools / configuration |
|---|---|---|---|
| Phase 1 GEMM and Mini-CNN rerun | NMAForge source/test `c4c2970ad8e66c93e00e854ef3befff4ccc9188b`; Tiny-NPU `harishsg993010/tiny-NPU` `8216c22b762011aa20c05fc2768423fd12dda59d` | `NMA-ROUND3-FAIR-FINAL-20261123`, seed `20261123` | VCS `V-2023.12-SP1_Full64`; Verilator `5.052 2026-09-05 rev v5.052`; Python `3.12.13`; NumPy `2.2.6`; ONNX `1.17.0` |
| Phase 2 GEMV ablation | RTL/test `c4c2970ad8e66c93e00e854ef3befff4ccc9188b` | 48 paired cases; seeds `20261122`, `20261123`, `20261124` | 16×16 array; outstanding depth 4; registered four-bank behavioral SPAD with seeded ready/latency |
| Phase 2 pointwise-CNN A/B | Product Top source `b31c8037d553d765a3529cb0b42bfde4d7ed224c` | `NMA-ROUND3-CNN-AB-20261122`, seed `20261122` | VCS `V-2023.12-SP1_Full64`; 128 KiB SPAD profile |
| H64 sanitized result | `source_sha_binding=UNBOUND` in the artifact | `H64-AUTOREG-20261123` is derived from the run directory, seed `20261116` | Synthetic model; raw compile/run logs were hash-recorded but not copied into this repository |
| Supplemental DV snapshot | Individual logs are hash-recorded in the evidence manifest; no single aggregate source SHA is asserted | `supplemental_dv_20261123` | VCS/formal results as individually listed below |

## Phase 1 — benchmark findings

### GEMM

All three NMAForge and Tiny-NPU cases passed their independent INT8 Golden checks. NMAForge cycles include Matrix controller plus behavioral SPAD. Tiny-NPU array cycles are direct RTL measurements; normalized cycles add a serialized 16-byte/cycle, one-cycle-response memory model. The ratio below is therefore a mixed measured/modeled normalized observation, not a matched-system speedup.

| Shape | Useful MACs | NMAForge cycles (measured) | Tiny-NPU array cycles (RTL) | Tiny-NPU normalized cycles (includes model) | NMA / normalized |
|---|---:|---:|---:|---:|---:|
| 16×16×16 | 4,096 | 173 | 52 | 151 | 1.1457 |
| 16×16×32 | 8,192 | 234 | 100 | 231 | 1.0130 |
| 32×32×64 | 65,536 | 1,301 | 790 | 1,305 | 0.9969 |

The first two normalized rows show more cycles for NMAForge; the largest is within four cycles of the modeled Tiny-NPU endpoint. None supports a system-level win. An earlier 2026-11-22 run under the same recorded source/test SHA reported NMAForge cycles `151 / 241 / 1,290`. The available run artifacts do not explain the differences from `173 / 234 / 1,301`; reproducibility reconciliation is open.

### `conv1x_mini.onnx`

Model SHA-256: `1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640`. Input seed: `99`; SHA-256: `a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`.

| Endpoint | Cycles | Boundary |
|---|---:|---|
| NMAForge CMDQ compute | 1,874 | 8 descriptors; includes Product-side command execution, with SPAD read/write 3,360 / 1,600 B |
| NMAForge testbench host layout | 1,080 | Modeled AXI operations: 144 B read, 576 B written; not CPU wall time |
| NMAForge phase subtotal | 2,954 | Compute plus host-layout fixture only; excludes preload, descriptor programming, final readback, and orchestration |
| Tiny-NPU graph smoke | 4,781 | Graph dispatcher plus testbench DMA/SRAM shim; setup excluded |

Both sides passed the 1,872-useful-MAC Golden. The endpoints do not match, so there is no CNN speedup calculation. The detailed run command, hashes, and archived evidence boundary are in the [Phase 1 report](NMAFORGE_V2_ROUND3_PHASE1_FAIR_BENCHMARK.md) and its linked CSV/JSON files.

## Phase 2 — GEMV and CNN dataflow findings

### GEMV cache/prefetch A/B

All 48 cases passed bit-exact Golden checks. The following are three-seed arithmetic means; bytes are read traffic per command.

| M×N×K | Cache/prefetch OFF/OFF cycles, bytes | Prefetch only cycles | Cache only cycles, bytes | Cache + prefetch cycles |
|---|---:|---:|---:|---:|
| 8×16×19 | 197.00, 864 B | 190.00 | 151.33, 560 B | 151.00 |
| 8×16×65 | 537.00, 2,720 B | 512.00 | 388.67, 1,696 B | 376.33 |
| 16×16×19 | 393.33, 1,728 B | 385.00 | 258.67, 816 B | 260.00 |
| 16×16×65 | 1,079.33, 5,440 B | 1,031.33 | 630.00, 2,368 B | 617.00 |

Cache is the consistent contributor to read-traffic and cycle reduction in these tested shapes. Prefetch-only gains are smaller and do not reduce read bytes. Cache plus prefetch is slightly slower than cache alone for 16×16×19. Treat this as a bounded standalone matrix experiment, not a Product Top model result or PPA conclusion.

### 262,144-MAC pointwise-CNN Product Top command A/B

The workload uses deterministic inference weights, not trained weights. All three modes used the same workload seed and passed `20,480/20,480` Golden words.

| Mode | Descriptors | CMDQ cycles | Reduction vs legacy | Fixture preload cycles | SPAD read/write bytes | SFU busy cycles |
|---|---:|---:|---:|---:|---:|---:|
| Legacy GEMM + requant | 4 | 60,930 | 0% | 136,415 | 98,304 / 81,920 | 53,252 |
| First-layer fused | 3 | 34,324 | 43.67% | 136,295 | 65,536 / 49,152 | 26,625 |
| Both fused, Linear-Row | 2 | 7,708 | 87.35% | 136,175 | 32,768 / 16,384 | 0 |

These are command-window A/B results, not production end-to-end latency. Fixture preload includes poison/sentinel initialization; it is not a production DMA schedule. The reported `useful_array_utilization_pct=100` is not a measured physical utilization result. Full accounting and exact workload commands are in the [Phase 2 report](NMAFORGE_V2_ROUND3_PHASE2_DATAFLOW_ABLATION.md) and [run manifest](../../benchmark/representative/round3/cnn_layout_ab/run_manifest.json).

## Phase 3 — model and DV status

### H64 four-layer autoregressive smoke

The sanitized artifact reports a synthetic H64 model on the same Product Top instance and records four contexts, each with 256 logits matching its independent Golden. Host intermediate-tensor writes are zero; Host reads RTL logits, selects argmax, and supplies feedback. Prompt: `[1, 7, 42, 3]`; generated tokens: `[114, 162, 193, 193]`.

The run is **prefix-recompute**, not persistent-KV decode. Its `4,343,004` cycles include prefix recomputation and feedback; they must not be presented as persistent decode latency or cycles/token. It makes no language-model quality claim. The artifact explicitly says the source SHA is unbound because no immutable run manifest was present. The run ID is directory-derived. The raw log hashes are listed in the manifest, but raw logs were not copied because the H64 log failed credential-like-pattern screening. The public evidence is the sanitized JSON and four logit CSVs only.

The originating exact invocation was not preserved in the committed evidence. Do not reconstruct or publish a guessed command as a reproduction command. Bind a future replay to a committed source/test SHA and immutable run manifest.

### DeiT and H4 Transformer

The recorded DeiT Product Top check is a scoped single-patch projection: 12,288 useful MACs, 256 Golden words, 2,442 command cycles and 40,961 fixture cycles, including 25,680 B fixture preload. It is not the complete 197×192 patch embedding, attention, or encoder. The H4 transformer inference target passed at 86 descriptors; this is not an H64 or DeiT model result.

### Supplemental regression outcomes

| Check | Status | Recorded result / limit |
|---|---|---|
| SPAD arbiter directed regression | `PASS` | Ownership, fairness, parity, fallback, priority, protection, contention, and seeded round-robin markers present |
| SPAD arbiter formal decode invariants | `BLOCKED_ENV / NOT_RUN` | `vcf` unavailable; make exit 2 |
| SPAD arbiter formal fairness bounds | `BLOCKED_ENV / NOT_RUN` | `vcf` unavailable; make exit 2 |
| FP read/protection/parity formal | `BLOCKED_ENV / NOT_RUN` | `vcf` unavailable; make exit 2 |
| Matrix core randomized regression | `PASS` | VCS seed `20261021` |
| DMA UVM regression | `PASS, scoped` | 0 UVM errors/fatals; scoreboard 20 passes; coverage 70%, error coverage 0% |
| Top `ai_smoke` | `PASS, scoped` | VCS top smoke |
| DeiT patch projection | `PASS, scoped` | Single-patch test only; see above |
| H4 transformer inference | `PASS, scoped` | 86 descriptors; not H64 model-quality evidence |
| UVM compile | `PASS, compile only` | Zero elaboration errors/warnings |
| UVM smoke | `FAIL` | Exit 2; `CLUSTER_MEMORY_EMPTY`, zero returned words, `UVM_ERROR=1`, fatal=0 |

Exact supplemental make commands, per-log SHA-256 values, and dispositions are in [`supplemental_dv_status.csv`](evidence/round3-20261123/supplemental_dv_status.csv). This table is a bounded evidence snapshot, not full DV closure.

## Reproduction artifacts and provenance limits

- [Phase 1 benchmark report](NMAFORGE_V2_ROUND3_PHASE1_FAIR_BENCHMARK.md)
- [Phase 2 dataflow report](NMAFORGE_V2_ROUND3_PHASE2_DATAFLOW_ABLATION.md)
- [Curated machine-readable evidence](evidence/round3-20261123/)
- [Log/artifact hash manifest](evidence/round3-20261123/log_manifest.json)
- [Pointwise-CNN Product Top run manifest](../../benchmark/representative/round3/cnn_layout_ab/run_manifest.json)

Raw simulator logs remain in originating `/tmp` directories and are not part of this commit. The manifest records their SHA-256 and `archived_raw_log=false`. The curated evidence has SHA-256 entries and can be independently checked against the manifest. H64 evidence is intentionally sanitized.

No product RTL was modified for this documentation/evidence consolidation. No private PDK, license, SRAM macro data, generated simulator database, or raw run log is included.

## Next actions

1. Reconcile the 2026-11-22 and 2026-11-23 GEMM cycle deltas using the same explicit seed, runtime configuration, endpoint, and source/test SHA; preserve both historical records until explained.
2. Rerun H64 prefix-recompute only if needed, with a source-bound immutable run manifest; separately implement and measure persistent-KV decode before claiming that capability.
3. Investigate the UVM smoke `CLUSTER_MEMORY_EMPTY` failure from its first missing scoreboard return; retain the current failing evidence until fixed and rerun.
4. When `vcf` is available, execute the blocked formal targets and record tool/version and exit status. Keep CDC/RDC and lint disposition separate from the benchmark status.
5. For Tiny-NPU, establish genuinely matched controller/memory and timing boundaries before computing a system comparison. For CNN, include required production input/weight transfer and output handling rather than fixture poison/setup costs.
6. Continue DeiT only from a real full-token path; the current patch-projection test is a local functional check, not full embedding or encoder closure.

Do not start a new architecture or sign-off scope from this summary. The next work should close the listed evidence gaps and preserve the current partial dispositions.
