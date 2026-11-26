# Round 28 design performance — DESIGN_PARTIAL

Product candidate `feat/nmaforge-rtl-finalize`, baseline `800c5b0ab1f0b9de5937c65e7c5f57b6d6fbc92c`, RTL implementation `3f108df` (full identity in raw manifest). Tools: VCS V-2023.12-SP1_Full64 and Verilator 5.052. Behavioral memories and simulation clock periods are not ASIC timing or Fmax. Raw CSV/JSON, Golden hashes and lossless logs are in `benchmark/representative/round28/`.

## Paired H16 GELU16

Same model SHA-256 `e7a521c762b66e5754d6d95c411c163452e0c9b01088cb11631202338cd28225`, same original weights, seed 20261123, four-token prefill, eight persistent teacher-forced decode tokens. Model loading and host token selection are excluded on both sides.

| Metric | Baseline | Candidate |
|---|---:|---:|
| Eight decode tokens | 72,238 cycles | 70,318 cycles |
| Average decode | 9,029.75 | 8,789.75 cycles/token |
| LN descriptor interval | 373 | 343 cycles |
| LN busy | 362 | 332 cycles |
| Eight-token LN descriptor sum | 23,872 | 21,952 cycles |
| Decode descriptors | 424 | 424 |
| Golden tensor words | 10,880 | 10,880 |
| Decode SPAD read/write | 72,448 / 42,112 B | 72,448 / 42,112 B |

Savings: 1,920 cycles, 2.6579% fewer cycles, speed ratio 1.0273×. Each token saves 240 cycles. Per-token logits/KV physical and reference hashes match before/after. All tensor checks pass. Prefill unchanged; raw prefill and matrix/SFU/KV profiles are preserved in session logs. This optimization changes arithmetic waiting only, not traffic. It does not meet the prior exploratory 7,500-cycle target.

## Matrix and CNN

Three matched GEMMs, depth=4/prefetch=1/A-cache=1: 175/263/1407 cycles, 23.406/31.148/46.579 useful MAC/cycle, read bytes 512/1024/6144 and write bytes 1024/1024/4096. Eight configurations and full raw state/traffic counters were rerun with the same input seed; see microarchitecture review and `matrix_ablation.csv`. No Matrix RTL modification retained.

Trained 570,164-MAC CNN sample 42: both-fused row-major, 12,947 CMDQ cycles, 3,019 DMA setup/transfer cycles (2,879 busy), live payload 10,944 B; compute SPAD reads/writes 64,064/16,640 B, 44.0383 useful MAC/cycle. All 20,800 tensor words pass. Matches Round 26 device performance. Historical held-out 96.11% is not a new full-set accuracy test. Host preprocessing/pooling/argmax and final readback are excluded and remain unmeasured.

## Pinned TinyNPU

SHA `8216c22b762011aa20c05fc2768423fd12dda59d` rebuilt and run. Seven common shapes pass all arithmetic Golden values; six engine tests pass. Product 0x52 replay, not isolated research wrapper, supplies NMAForge GEMV values.

| Common workload | NMAForge cycles | TinyNPU cycles | Classification |
|---|---:|---:|---|
| GEMM 16×16×16 | 175 | 52 | MATCHED_COMPUTE |
| GEMM 16×16×32 | 263 | 100 | MATCHED_COMPUTE |
| GEMM 32×32×64 | 1407 | 790 | MATCHED_COMPUTE |
| GEMV 1×13×17 | 75 | 100 | MATCHED_COMPUTE |
| GEMV 8×16×19 | 150 | 100 | MATCHED_COMPUTE |
| GEMV 16×16×19 | 255 | 100 | MATCHED_COMPUTE |
| GEMV 16×16×65 | 612 | 244 | MATCHED_COMPUTE |
| conv1x_mini.onnx | 1,985 CMDQ + separate 1,080 layout counter | 4,781 graph | NOT_COMPARABLE for system latency |

Array-only TinyNPU versus controller+SPAD NMAForge cycles are not equivalent endpoints, despite common arithmetic. No system speedup is claimed. CNN same ONNX model/hash and final four bytes pass; layout counter is not measured CPU latency. No new common Transformer graph is implemented: common GEMM/GEMV are only projection/FFN arithmetic building blocks, not a matched complete subgraph. LN/Softmax numeric equivalence would require explicit fixed-point adaptation; broad controller rewriting is outside this round.

## Reproduction

Run from candidate root, use fresh outputs. Python interpreter used: `/tmp/nmaforge_arch_v2_py312/bin/python` (3.12 environment). Pinned Verilator executable: `/tmp/nmaforge_verilator_5.052/bin/verilator`.

```sh
R28_OUT=/tmp/r28_replay R28_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python bash tools/benchmark/run_round28_h16.sh
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/compute/sfu/sim random-latency-test PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python SEED=20261109 OUT_DIR=/tmp/r28_sfu_replay
make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261109 MATRIX_CONFIG_OUT=/tmp/r28_matrix_replay
make -C dv/block/compute/matrix/sim core-tile-forward-ablation SEED=20261109 TILE_FORWARD_OUT_DIR=/tmp/r28_forward_replay
```

For the exact three common GEMMs, each depth=2/4, prefetch=0/1, cache=0/1 tuple was compiled with `core-random-compile OUTSTANDING_DEPTH=<d> NEXT_K_PREFETCH_ENABLE=<p> A_TILE_CACHE_ENABLE=<c> CORE_OUT_DIR=<fresh-dir> SEED=20261109`, then `<fresh-dir>/simv +SEED=20261109 +TINY_NPU_MATCH_MULTI -l <fresh-dir>/run.log`. Product GEMV used default tuple binary with `+MATRIX_PRODUCT_GEMV_ONLY`.

CNN generation, verification and DMA preparation use existing scripts and Round 26 exact command recipe, replacing `/tmp/nmaforge_round26_cnn_20261109/workload` with `/tmp/nmaforge-round28-runs/cnn` and simulation binary with `/tmp/nmaforge-round28-runs/opt/simv`. All shape/base/count flags remain identical. See Round 26 manifest for complete expanded arguments.

TinyNPU runs use `TINYNPU_WORK_ROOT=/tmp/nmaforge-round28-runs/tiny`, `TINYNPU_GEMM_OUT=.../tiny/gemm`, `TINYNPU_CNN_OUT=.../tiny/cnn`, `VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator`, `PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python`, `JOBS=2` with `benchmark/tinynpu/run_tinynpu_{gemm,cnn}.sh`. Common NMA CNN uses `ai_tinynpu_cnn_match_128k` with that source's ONNX and generated golden.bin, Python environment and a fresh run directory.

VCS smoke and seeded regression PASS; SFU 64 numeric cases + 9 error cases and selected abort/reset/recovery checks PASS. Existing LOOP-REROLL-ENABLED compile notice remains, no new Error- diagnostic. No full UVM, SpyGlass, synthesis, DFT or backend run was requested or performed.
