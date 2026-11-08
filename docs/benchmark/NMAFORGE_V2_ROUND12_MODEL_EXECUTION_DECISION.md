# NMAForge v2 Round 12 — Model Execution Decision

**Disposition: PARTIAL / HOLD**

Round 12 did not meet either Top-level exit criterion. The 262,144-MAC CNN workload and independent software Golden are reproducible, but VCS stopped at license checkout before RTL compilation. H=16 model generation is blocked by the current H=4 trainer/mapper contract; no H=16 model or descriptor stream was produced. No Top-level PASS, cycle count, or performance claim is made.

## Source and run identity

| Item | Value |
|---|---|
| Requested branch | feature/npu-architecture-v2 |
| Reviewed/source/test SHA | 28cd86e0c18d62e4ce6cfb14a2f43967cdce0d4d |
| Product RTL changed in Round 12 | No |
| VCS | V-2023.12-SP1_Full64 |
| Python | 3.12.13 |
| CNN seed | 20261108 |
| CNN Top run ID | R12-TOP-REP-CNN-128K-S20261108-RETRY2 |
| CNN offline Golden run ID | R12-CNN-OFFLINE-GOLDEN-S20261108 |
| H=16 preflight run ID | R12-H16-MAPPER-PREFLIGHT-20261108 |
| Top log | /tmp/nmaforge_r12_cnn_128k_20261108/run_retry2.log, SHA-256 87af108c5ba74e3ff241fe1243ed1ca34a7629ab66d56a012b35d73a5bc46249 |
| H=16 eight-token probe log | /tmp/nmaforge_r12_h16_probe8.log, SHA-256 b3938bff16541c9ddb713185da2b755cb8ddb5f9da12914c679a2ccaecc8e3b5 |
| H=16 16x16-weight probe log | /tmp/nmaforge_r12_h16_probe4.log, SHA-256 1136c20820b437c82e2120c29ed55f799f58c63a7973f2b8d58fa74cee569a38 |
| Machine-readable status | [round12_model_status.json](../../benchmark/representative/round12_model_status.json) |
| Machine-readable performance | [round12_performance.csv](../../benchmark/representative/round12_performance.csv) |

Work was performed in a clean isolated worktree at the reviewed SHA. The user's main worktree, its untracked novas.conf/novas.rc, main R250, and other worktrees were left untouched. Round 12 adds no RTL and carries no private PDK or license configuration.

## Phase 0 — 262,144-MAC CNN Top execution

### Workload contract and offline result

The deterministic workload is a two-layer pointwise INT8 CNN fixture:

- Input [1,16,32,16], represented as 512 spatial positions × 16 channels.
- Layer 1: 1x1 Conv, 16→16, INT32 accumulation, ReLU/clamp.
- Layer 2: 1x1 Conv, 16→16, INT32 accumulation, ReLU/clamp.
- Useful work: 2 × 512 × 16 × 16 = 262,144 MAC/inference.
- Weights are fixed-seed reproducible inference weights, **not trained**. It has no classification-accuracy claim.
- Top command chain: 0x30 GEMM → 0x36 Requant → 0x30 GEMM → 0x36 Requant; no Host intermediate compute or Im2col.
- The image uses 90,944 bytes for preload records; its highest used address is 0x19240 (102,976 bytes), within the 128 KiB candidate. This is static image/address accounting, not measured SRAM traffic or capacity characterization.

The generator and independent verifier passed twice with the same seed. The verifier independently decodes the physical Matrix A/B layouts, checks the four descriptor records and dependencies, recomputes INT32 matrix outputs and packed INT8 tensors, and compares 20,480 intermediate/final words.

| Artifact | SHA-256 |
|---|---|
| Input | f8514ef62fc2e83230d533ea2c82afb18a8d2b71e7324886679fd814e99561ea |
| Layer 1 weights | b780646f65d0247b5972c9125073988315d6ea4c2fe073ea4c1aa63a569b9d89 |
| Layer 2 weights | b37e120ac1afbc15ffc67c4ddc2f94368901ef0eca8f0120ae2cba6eb846efa0 |
| Expected output tensor | 22cb785cff0275f5cc4bba995800d65350231373effc4723734370b3f4860d5f |
| SPAD image | ed38edf71c161d44ddbadf2178aa203f51a09d9122a4e4bff7a6bef1f486d4c1 |
| Intermediate/final Golden image | 9e094fda9315fb86e39d20c084015772aaa21eb1bd1fbeb49d8ee72a59833b9d |

### Top result and performance status

The exact Make target was run twice; the final bounded retry captured a combined log. Workload generation and offline Golden passed, then VCS reported Cannot connect to the license server and Failed to obtain license before source compilation. No simv was produced and no simulation began. No alternative compatible simulator (verilator, iverilog, xrun, or vsim) is installed in this environment.

| Requirement | Status | Evidence |
|---|---|---|
| Four descriptor fields and static 128 KiB address fit | PASS_STATIC | Independent workload verifier; high-water 0x19240 |
| Independent intermediate/final software Golden | PASS_OFFLINE | 4 tensors, 20,480 checked words; SHA above |
| Top compilation / four completions / Top Golden | BLOCKED_ENV | VCS license checkout failure before compile |
| Command and Matrix cycles | NOT_RUN | No simulation |
| Matrix active/wait and utilization | NOT_RUN | No simulation |
| SPAD read/write traffic and preload cycles | NOT_RUN | Preload image bytes are static; not measured traffic |
| Fused/layout/overlap ablation | NOT_RUN | Phase 1 requires a successful Top Golden first |

The descriptor validator accepts ordinary Matrix M,N when nonzero and multiples of four; the Matrix controller iterates M in 16-row tiles. Thus M=512,N=16,K=16 is representable by the ordinary GEMM descriptor and the workload uses legal dimensions. This is a source-level contract review only: the descriptor chain and the M=512 execution were not compiled or exercised at Top. Round 12 does not treat this static observation as proof of hardware support.

Phase 1 optimizations were correctly held because the Top Golden gate did not pass. The present workload is 1x1 pointwise convolution; a 3x3 convolution design study and any lowering/Im2col traffic measurement remain open.

## Phase 2 — H=16 two-head Transformer

### Shape/ABI support audit

| Layer | Software-only restriction | Descriptor/RTL primitive | H=16 two-head chain status |
|---|---|---|---|
| Trainer/model export | train_transformer_micro.py accepts only output path, seed and step count; trains a four-symbol, four-token H=4 fixture with six 4x4 matrices. | No hardware restriction implied. | BLOCKED_MAPPER_SUPPORT: no H=16 trained weights or independent H=16 Golden. |
| Q/K/V projection | Mapper requires four input token IDs in [0,3] and six 4x4 matrices. | Ordinary 0x30 Matrix allows nonzero M/N/K with M,N multiples of four and tiled execution; 8x16x16 QKV shapes fit those dimension rules. | NOT_RUN: mapper emits no H=16 descriptors; VCS unavailable for Top check. |
| Single-token projection | Decode data and Q/K/V tensors are hard-coded to four features/rows. | 0x52 bounds M,N to 1..16, requires K>0 and aligned dense operand bases; H=16 M=1,N=16,K=16 is within stated fields. | NOT_RUN: no H=16 GEMV mapper, weight packing, or Golden check. |
| Head split, QK, Softmax, AV, merge | No head axis or per-head address/layout allocator exists in the mapper. | Matrix can execute tile GEMM; 0x39 causal Softmax and 0x38 LayerNorm are separate primitives. | NOT_RUN: two-head split/merge and per-head tensor layout/quantization contract are not mapped. Primitive presence is not an end-to-end result. |
| Residual, LayerNorm, FFN | H4 tensors and offsets are fixed in mapper. | LayerNorm small-vector fast path covers length <=16; ordinary GEMM handles aligned FFN shapes. | NOT_RUN: no H16 tensor addressing, descriptors, or independent per-layer Golden. |
| KV cache, Prefill, Decode | KV command emission is fixed to one head, four features, four prefill tokens and a five-token window. | KV engine address fields support token and head indices with byte strides; this does not define the required H16 packing by itself. | NOT_RUN: no H16 head stride/address plan, Prefill/Decode queue, or cache Golden. |
| Top workload loader | The generic Top loader accepts up to 128 descriptors and checks emitted memory-image/Golden pairs. | It can execute a supplied bounded descriptor image via CMDQ. | Loader is reusable in principle; no H16 image exists. The descriptor-count bound must be checked once mapping is implemented. |

Two parser probes with synthetic identity matrices confirmed current software rejection without changing checks:

1. Eight prefill IDs fail at the four-ID [0,3] model contract.
2. Four IDs with 16x16 weights fail at the required 4x4 weight shape.

These are mapper-contract diagnostics only. They are not trained-model or Top failures and do not show that the RTL arithmetic primitive itself rejects 16-wide GEMM.

### Gate disposition

| Gate | Status | Round 12 result |
|---|---|---|
| G1 — reproducible H=16 training/export, shape validation, independent software Golden | BLOCKED_MAPPER_SUPPORT | Existing trainer/export is H4-only; no H16 artifact generated. |
| G2 — Q/K/V GEMM descriptor and Top Golden | NOT_RUN | Source dimension fields are representable, but the H16 mapper and Top run are absent. |
| G3 — head split, QK, Softmax, AV and merge | NOT_RUN | No multi-head layout/address mapping or Golden. |
| G4 — Residual, LayerNorm and FFN | NOT_RUN | No H16 descriptor/tensor chain or Golden. |
| G5 — KV-cache, Prefill and single-token Decode | NOT_RUN | No H16 cache layout or Top execution. |

No H=16 Prefill/Decode latency, accuracy, useful MAC, GEMM/GEMV benefit, cache effect, or SPAD traffic is available. H4 history remains separate: Round 11 reports a previously checked 86-descriptor H4 fixture; it is not Round 12 H16 evidence.

## Commands and reproduction

Executed from the clean Round 12 source SHA:

    make -C dv/subsystem/top_smoke/sim ai_representative_cnn \
      AI_REPRESENTATIVE_RUN=/tmp/nmaforge_r12_cnn_128k_20261108_retry2 \
      AI_REPRESENTATIVE_PYTHON=python3.12 AI_REPRESENTATIVE_SEED=20261108

This target ran these software steps before VCS checkout failed:

    python3.12 benchmark/representative/generate_pointwise_cnn_workload.py \
      --seed 20261108 --out-dir /tmp/nmaforge_r12_cnn_128k_20261108_retry2/workload
    python3.12 benchmark/representative/verify_pointwise_cnn_workload.py \
      --workload-dir /tmp/nmaforge_r12_cnn_128k_20261108_retry2/workload

The diagnostics were:

    python3.12 sw/tools/cimforge_mapper.py \
      --model-json /tmp/nmaforge_r12_h16_probe8.json \
      --svh /tmp/nmaforge_r12_h16_probe8.svh \
      --manifest /tmp/nmaforge_r12_h16_probe8_manifest.json
    python3.12 sw/tools/cimforge_mapper.py \
      --model-json /tmp/nmaforge_r12_h16_probe4.json \
      --svh /tmp/nmaforge_r12_h16_probe4.svh \
      --manifest /tmp/nmaforge_r12_h16_probe4_manifest.json

Both probes intentionally use synthetic 16x16 identity matrices and stop at existing mapper validation. They are not an H16 mapping implementation.

## Decision and remaining work

Round 12 status is PARTIAL; the requested representative-model baseline is not ready to claim. There is no Round 12 product RTL change. The CNN's offline Golden is useful for replay when VCS license service is available, but Top PASS and all simulated performance metrics remain open. The H16 path requires parameterizing training/model schema, tensor/head address allocation, matrix and SFU descriptors, KV strides/cache lifetime, independent software Golden, and the representative Top image generation before its five gates can be tested.

The next actionable items are limited to the unmet Round 12 gates: restore a working authorized VCS checkout and rerun the fixed CNN; implement/test an H16 shape-aware model/export/mapper path, then run G1–G5 in order. Until those exist, no representative CNN optimization, H16 GEMV speedup, or two-innovation model-level benefit is demonstrated. This report records the stopping point for this round and does not claim v2 sign-off or full Transformer inference.
