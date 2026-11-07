# NMAForge v2 Performance and PPA Final — Round 4

**Status: RESEARCH_BASELINE_PARTIAL.** This bounded round completed the available profiling audit and a pinned TinyNPU ONNX-CNN replay. The current-source Top replay, model-level GEMV mapping experiment, matched Transformer comparison, and 400 MHz synthesis did not complete. No new RTL or Mapper behavior is claimed.

## 1. Frozen source and evidence boundary

- Repository: cwu766485-ctrl/NMAForge
- Target branch at review: feature/npu-architecture-v2
- Reviewed remote HEAD: 59c5d14d14c3d951435c1f94e8b4f497e97690d5
- main R250: 3041355528dffe856e2d5384027c6ee5df5d1b42
- Product RTL baseline recorded by the prior fixed-source reports: cd0a05d8ecd8cfb6c3f39b559788a2531e324b23
- TinyNPU reference SHA: 8216c22b762011aa20c05fc2768423fd12dda59d
- No product RTL, Mapper, testbench, or source-list files were changed in this round. This report is the only intended repository change.

The reviewed candidate is isolated in a temporary worktree. RTL, Top smoke sources, Mapper, and benchmark scripts at 59c5d14 have identical contents to the previously measured 4dab736 candidate. This makes the Round 3 trained-CNN and trained-toy-Transformer records reusable as same-source evidence. The older conv1x_mini NMAForge measurement is from source/test SHA 9576e539c21fe6312763c4745a90dc032c6457e0, which differs in relevant RTL/test files; it is historical context, not a current-candidate replay.

No main or other worktree was modified. The GitHub target branch and main were checked before this report was prepared; they pointed to 59c5d14 and R250 respectively.

## 2. Phase results

| Phase | Status | Disposition |
|---|---|---|
| P0 — CNN / Transformer profile | PARTIAL | Reused exact-source functional/performance baselines and completed profile-counter audit. The existing model harness does not export the requested per-command exclusive cycle partition. |
| P1 — Transformer GEMV mapping | NOT_RUN | Mapper legality was audited. No GEMV policy was changed and no GEMV-mapped Transformer was executed. Current VCS license acquisition failed before simulation. |
| P2 — TinyNPU comparison | PARTIAL | Pinned TinyNPU conv1x_mini graph run passed with the shared Golden. It has no current-source, same-boundary NMAForge timing partner. Existing GEMM/GEMV microbenchmarks remain mixed measured/modeled historical comparisons. |
| P3 — 300/400/450 MHz synthesis | BLOCKED_ENV | Synopsys DC shell, standard-cell library, SRAM timing models, and SDC were unavailable. No synthesis or PPA numbers are reported. |

## 3. P0 — CNN and Transformer performance baseline

### 3.1 Trained ten-class CNN

The fixed model has 2,736 useful MACs per image and 16 CMDQ descriptors. At the exact-source 4dab736 candidate, all 396 held-out images passed every checked intermediate and final integer Golden; software and RTL classified 384/396 images (96.97%). These are behavioral Top results with a four-bank behavioral SPAD.

| Per image | Legacy layout | Fused linear-row | Change |
|---|---:|---:|---:|
| Top CMDQ interval | 3,193 cycles | 2,712 cycles | −15.1% |
| Testbench Host layout | 1,080 cycles | 0 cycles | −1,080 |
| Measured task interval | 4,273 cycles | 2,712 cycles | −36.5% |
| Compute SPAD read/write | 6,048 / 1,920 B | 5,472 / 1,776 B | −576 / −144 B |
| Host-layout read/write | 144 / 576 B | 0 / 0 B | removed |
| Total observed SPAD traffic | 8,688 B | 7,248 B | −16.6% |
| Useful MAC / task-interval cycle | 0.640 | 1.009 | derived |

The Host-layout interval is the testbench's simulated AXI sequence, not software wall time. The comparison removes the Host transform with the opt-in 0x53 linear-row output mode; it combines fused output handling and consumer-layout selection. It does not isolate the individual contribution of requant fusion versus linear-row layout.

Summed across the 396 independent image runs, the fused path represents 1,083,456 useful MACs and 1,073,952 CMDQ cycles. This is a reproducible larger aggregate throughput workload, but it is not a larger per-inference CNN: each image still has only 2,736 useful MACs. A larger per-inference CNN was not run.

### 3.2 Transformer

The reusable trained synthetic task is one layer, one head, hidden size 4, four-token Prefill and one-token Decode. Its weights are trained/exported by the checked-in integer training flow; the task is cyclic next-symbol prediction, not a language-model quality benchmark.

| Interval | Cycles | SPAD read/write | Useful MACs |
|---|---:|---:|---:|
| Prefill | 5,682 | 1,936 / 1,072 B | included below |
| Single-token Decode | 5,715 | 1,880 / 1,048 B | included below |
| Combined | 11,397 | 3,816 / 2,120 B | 640 |

The Top checked 301 intermediate, final, and KV-cache values across 86 ABI-v7 descriptors. The selected task case predicted 4/4 Prefill and 1/1 Decode symbols; the exhaustive held-out task score in the prior training report was 694/1,008 token predictions (68.85%). This establishes functional composition for a small synthetic task, not representative Transformer throughput.

Combined useful work divided by the full interval is 0.056 useful MAC/cycle. This is a coarse end-to-end efficiency indicator, not a physical PE-active-cycle utilization measurement. The small matrix shapes and descriptor-heavy graph leave the 16×16 array underfilled. A wider/deeper Transformer and per-op timing were not measured.

### 3.3 Requested cycle breakdown and bottleneck finding

The requested partition was: useful compute active cycles, descriptor fetch/dispatch, SPAD/DMA wait, arbiter/bank conflict, output writeback, Host work, and total inference cycles.

The CNN and Transformer logs provide totals, descriptor counts, aggregate read/write traffic, and the CNN Host-layout interval. The Top model harness does not print a per-command partition for descriptor dispatch, compute-active state, SPAD/DMA response waits, bank conflict, or output writeback. Matrix RTL contains passive FSM and stall counters, but the model-level harness does not export them in these runs. Counter groups also include overlapping event counts and must not be added as if they formed an exclusive partition.

The measured facts are: (a) CNN layout handling costs 1,080 simulated cycles in Legacy and is removed by the linear-row route; (b) the remaining fused CNN Top interval is 2,712 cycles; (c) the hidden-4 Transformer uses 86 descriptors for only 640 useful MACs and takes 11,397 cycles. The interpretation that descriptor/setup and small-shape underutilization dominate the Transformer is a static inference, not a measured per-stage profile. A larger CNN/Transformer profile is OPEN.

## 4. P1 — Shape-Adaptive GEMV on Transformer Decode

### 4.1 Mapper audit

At the reviewed source SHA, cimforge_mapper.py defines GEMM opcode 0x30 and fused opcode 0x53, but no 0x52 GEMV opcode or selectable GEMM/GEMV policy. The Transformer Mapper generates eight Decode GEMM operations: Q/K/V projection, QK, Attention×V, output projection, FFN-up, and FFN-down. All use the current four-wide hidden shape; the Decode activation is stored as four rows with only row zero carrying the new token.

The v2 spec allows 0x52 only for dense row-major signed INT8, 1≤M,N≤16 and K≥1, with 16-byte row padding/alignment. It disallows transpose flags, nonzero strides, and unsupported auxiliary fields. A potential M=1 Decode map would therefore need to:
- emit a single live row rather than the current padded 4-row GEMM result;
- provide B operands in the 0x52 row-major K×N layout, including materializing the current transposed/column-oriented weight and attention operands where needed;
- preserve zero/padding semantics expected by later residual, normalization, pack, and KV descriptors; and
- check whether the additional packing/clearing work offsets the reduced array work.

The current toy has K=4. It does not exercise the long-K folding/cache regime that produced the strongest opcode-0x52 benefit; the command-local B-fold cache is targeted at M>4. Thus the toy is a poor workload for proving Innovation 1 even if the Mapper were changed. No descriptor migration or policy change was made without a runnable Top Golden and cycle comparison.

### 4.2 Existing Cache × Prefetch ablation

The following fixed-shape experiment remains historical evidence from source/test SHA b9d593e5f55869ff4a47748013a4b15dcd60f83f, parser SHA ae410661d4f31247be08f2e87ea761452e56a164, three seeds 20261105/06/07, 16×16 array, behavioral four-bank SPAD, and 48/48 Golden checks. It is not Transformer model-level evidence.

| Shape | Cache OFF / Prefetch OFF | Cache ON / Prefetch OFF | Cache cycle / read change | Cache ON / Prefetch ON |
|---|---:|---:|---:|---:|
| M8 N16 K19 | 200.7 cyc / 864 B | 156.0 cyc / 560 B | −22.3% / −35.2% | 152.3 cycles |
| M8 N16 K65 | 544.3 cyc / 2,720 B | 391.0 cyc / 1,696 B | −28.2% / −37.6% | 383.0 cycles |
| M16 N16 K19 | 393.7 cyc / 1,728 B | 261.0 cyc / 816 B | −33.7% / −52.8% | 262.7 cycles |
| M16 N16 K65 | 1,075.0 cyc / 5,440 B | 627.3 cyc / 2,368 B | −41.6% / −56.5% | 632.3 cycles |

With Cache enabled, Prefetch ON versus OFF changed these four means by −2.4%, −2.0%, +0.6%, and +0.8%, respectively. Prefetch provides shape-dependent overlap but little additional latency benefit in this bounded test. No result proves model-level Decode acceleration. The four-way raw data is benchmark/v2_p2_gemv_cache_prefetch_4way.csv; detailed run command and counter semantics remain in docs/benchmark/NMAFORGE_V2_GEMV_CACHE_PREFETCH_ABLATION.md.

**P1 disposition:** NOT_RUN for a Transformer GEMV variant and its four requested model-level configurations. No current-source Decode cycles, traffic, utilization, or Golden comparison for 0x52 are available.

## 5. P2 — TinyNPU comparisons

### 5.1 New pinned TinyNPU CNN replay

Review run label: R4-TINYNPU-CNN-CONV1X-MINI-20261107 (assigned for this report; the script itself does not emit a run ID). TinyNPU source SHA was verified as 8216c22b762011aa20c05fc2768423fd12dda59d. Exact command:

    TINYNPU_WORK_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference \
    TINY_NPU_ROOT=/tmp/nmaforge_tinynpu_8216c22b/reference/source \
    TINYNPU_CNN_OUT=/tmp/nmaforge_round4_tinynpu_cnn \
    PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
    VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator \
    JOBS=4 bash benchmark/tinynpu/run_tinynpu_cnn.sh

Tool versions: Verilator 5.052, Python 3.12.13. The model was conv1x_mini.onnx, SHA-256 1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640. TinyNPU compiled 13 instructions/11 tensor descriptors, completed the graph in 4,781 cycles, and passed its 4-byte output comparison. Golden SHA-256: 94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c. Runtime transfer log showed 1,088 B DMA read and 4 B DMA write. The SRAM image file is 3,147,776 B; that file size is not the measured transfer traffic.

This is a TinyNPU Graph/RTL run. It does not have a paired NMAForge run at the reviewed 59c5 source/test SHA. The earlier NMAForge result for this ONNX workload (1,985 Top compute cycles plus 1,080 simulated Host-layout cycles) is bound to 9576e539c21fe6312763c4745a90dc032c6457e0, whose relevant RTL/test files differ from 59c5. The shared Golden verifies output agreement, but the older NMAForge timing cannot be divided into the new TinyNPU cycle count as a Round 4 speedup. Neither side currently provides a same-boundary decomposition of compute, dispatch, DMA and Host work for this pair.

The TinyNPU compile and run logs are retained outside Git under /tmp/nmaforge_round4_tinynpu_cnn (compile.log, onnx_compile.log, run.log). The checked-in source, model and Golden can regenerate the run.

### 5.2 Fixed GEMM/GEMV shape matrix

The existing matrix at NMAForge source/test SHA 219c9f26a85b9661185cd78ab6308ae3f13e3ea7, seed 20261106, remains a mixed measured/modeled historical comparison. NMAForge controller/behavioral-SPAD cycles were measured; TinyNPU direct-array cycles were measured; TinyNPU common-memory service was estimated as serialized 16 B/cycle input/output service plus one read response and two accumulator-clear cycles. Both sides passed independent INT32 Goldens.

| Workload | Shape | NMA cycles | Tiny direct-array cycles | Tiny estimated endpoint | NMA / estimated endpoint |
|---|---|---:|---:|---:|---:|
| GEMM | 16×16×16 | 173 | 52 | 151 | 1.1457 |
| GEMM | 16×16×32 | 259 | 100 | 231 | 1.1212 |
| GEMM | 32×32×64 | 1,380 | 790 | 1,305 | 1.0575 |
| GEMV | 1×13×17 | 66 | 100 | 122 | 0.5410 |
| GEMV | 8×16×19 | 148 | 100 | 164 | 0.9024 |
| GEMV | 16×16×19 | 264 | 100 | 205 | 1.2878 |
| GEMV | 16×16×65 | 634 | 244 | 441 | 1.4376 |

Ratios above 1 mean more NMAForge cycles than the estimated TinyNPU endpoint. These data show small-M GEMV is mixed: NMAForge is below the modeled endpoint for the first two shapes and above it for the M16 tails. Large GEMM remains close under this particular memory estimate, with NMAForge slightly slower. These are not system-level TinyNPU wins/losses because TinyNPU's memory service is not RTL-measured, and this matrix was not replayed at Round 4 source/test SHA.

### 5.3 Transformer pairing

No common trained Transformer model was run on both RTL paths. The NMAForge hidden-4 synthetic model is not matched to a TinyNPU graph/descriptor workload at the same weights, quantization, sequence length, and completion boundary. Prefill, single-token Decode, and multi-token Decode TinyNPU comparisons are therefore NOT_RUN. No system-level Transformer speedup is claimed.

## 6. P3 — 128/512 KiB and synthesis

The existing behavioral capacity study uses the same four-bank interface and 256-MAC array. At historical source/test SHA 9576e539c21fe6312763c4745a90dc032c6457e0, the fixed conv1x_mini and ten-class Digits CNN maps produced equal measured cycles at 128 and 512 KiB. This applies only to those compact fixed maps; it does not establish universal model fit or equal physical area. The 512 KiB configuration stores 4,194,304 bits, while 128 KiB stores 1,048,576 bits, a 75% reduction in nominal SRAM bits. Macro count and area depend on the actual SRAM compiler/macro organization and are not inferred here.

The 300/400/450 MHz synthesis request is BLOCKED_ENV:
- Synopsys dc_shell and dcnxt_shell are not available in PATH. The local /usr/bin/dc is GNU dc (a calculator), not Design Compiler.
- TSMC28_STDCELL_DB, TSMC28_SRAM_MACRO_DIR, TSMC28_SRAM_LIB, and SDC_FILE are unset.
- No usable Round 4 Design Compiler setup with matching cell/SRAM timing libraries, corner, constraints, and clock/IO definitions was available in this worktree.

Therefore logic area, macro area, WNS/TNS, critical path, Fmax, power, and energy/inference are NOT_RUN / BLOCKED_ENV. The simulation's 10 ns clock and any historical assumed frequency are not ASIC timing evidence. No 300, 400, or 450 MHz PASS/FAIL result is asserted.

## 7. Reproduction record

### Reused Round 3 model evidence

- Exact behavioral RTL/test source equivalence check:
  git diff --quiet 4dab73646989615c5479de0bac76d1488a102758 HEAD -- rtl dv/subsystem/top_smoke/tb dv/subsystem/top_smoke/sim sw/tools benchmark/tinynpu
- CNN Run IDs:
  V2-TRAINED-CNN-TOP-DATASET-4DAB736-LEGACY_LAYOUT
  V2-TRAINED-CNN-TOP-DATASET-4DAB736-LINEARIZED
- Transformer Run ID: V2-TRAINED-TRANSFORMER-TOP-4DAB736-S20261106
- Seed: 20261106; trained synthetic model SHA-256:
  55cef19181c84dda9f99e940a0a749c1499fc1ccb176b966b1e13462f8ae3c03
- CNN model SHA-256:
  ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726
- CNN test set SHA-256:
  cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107
- Tools: VCS V-2023.12-SP1_Full64, Python 3.12.13, NumPy 2.4.6.
- Full prior commands are in docs/benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md. Per-image CSVs/logs were archived outside Git under /tmp/nmaforge_round3_4dab_cnn_{legacy,linear}.

### Round 4 VCS attempt

The requested trained-Transformer replay was invoked with:

    VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
    PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
    make -C dv/subsystem/top_smoke/sim ai_transformer_trained \
      PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
      VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
      AI_SPAD_WORDS_PER_BANK=8192 \
      AI_TRANSFORMER_TRAINED_MODEL=/tmp/nmaforge_r4_transformer/trained_cyclic_h4.json \
      AI_TRANSFORMER_MANIFEST=/tmp/nmaforge_r4_transformer/manifest.json \
      AI_TRANSFORMER_SEED=20261106 AI_TRANSFORMER_STEPS=20000

Training/export and Mapper preflight completed: model SHA-256 55cef19181c84dda9f99e940a0a749c1499fc1ccb176b966b1e13462f8ae3c03; 86 descriptors, 60 tensors, dataflow closed, poison enabled. VCS compile then failed to acquire a license before the Top simulation started. Status: BLOCKED_ENV, not a functional PASS. The command was not retried after observing that the previously compiled simulator also failed to acquire a license.

### Round 4 TinyNPU CNN replay

Command and output: see §5.1. Run ID R4-TINYNPU-CNN-CONV1X-MINI-20261107; deterministic workload, seed N/A. TinyNPU SHA was verified before execution. Status: PASS for TinyNPU Graph execution and final Golden.

### Synthesis environment check

    command -v dc_shell
    command -v dcnxt_shell
    test -n "$TSMC28_STDCELL_DB"
    test -n "$TSMC28_SRAM_MACRO_DIR"
    test -n "$TSMC28_SRAM_LIB"
    test -n "$SDC_FILE"

All Design Compiler / library / SDC checks were unavailable or unset.

## 8. Conclusions and open issues

**Supported by current or exact-source evidence**
- The 0x53 fused linear-row CNN route removes the 1,080-cycle simulated Host-layout stage and reduces its Top CMDQ interval by 15.1% for the fixed trained Digits CNN; all 396 images remain bit-exact and classification is unchanged.
- Existing B-fold Cache has material read-traffic and cycle benefits on four fixed GEMV shapes; incremental Prefetch benefit is small and shape dependent.
- TinyNPU at the pinned SHA executes conv1x_mini correctly in 4,781 graph cycles and matches the compiler Golden.

**Not established**
- That 0x52 improves a real Transformer Decode workload.
- A representative, wider/deeper Transformer performance profile.
- A same-source, same-boundary Round 4 NMAForge-vs-TinyNPU CNN speedup.
- A TinyNPU Transformer comparison at common weights and memory service.
- A closed mutually-exclusive cycle/stall partition for model-level Top runs.
- Any 300/400/450 MHz synthesis, ASIC area, Fmax, power, or energy result.
- Full Compute Cluster DV or ASIC sign-off.

This round leaves the project at **RESEARCH_BASELINE_PARTIAL**. The report records the current evidence and blockers; no new RTL optimization or wider verification task was started.
