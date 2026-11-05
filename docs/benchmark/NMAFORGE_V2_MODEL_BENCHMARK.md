# NMAForge v2 Model Benchmark

**Status date:** 2026-11-06
**R250 baseline:** `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**Latest v2 RTL/test candidate replay:** `410b81dfd37992a760b28258bb7e8c6b6f5017d7`
**Latest paired benchmark source SHA:** `c3a59f08d8c07a8da973010d0f23d5d6d7eed61b`
**TinyNPU reference:** `8216c22b762011aa20c05fc2768423fd12dda59d`

## Trained Digits MLP: matched RTL replay

The 360-image sklearn Digits test set was run against the same trained INT8
weights on R250 and v2. Both runs used seed `20261029`, the same model SHA and
the same independent integer Golden. The v2 path uses the real top and Matrix
datapath, ABI-v7 descriptors, CMDQ/CPLQ, and the opt-in fused `0x53`
Matrix output path. No host computation supplies hidden activations or logits.

| Measure | R250 | v2 candidate | Change |
|---|---:|---:|---:|
| Test images correct | 352/360 | 352/360 | unchanged |
| INT8 accuracy | 97.78% | 97.78% | unchanged |
| Exact RTL logits CSV | `7980fb67…10360e9c` | `7980fb67…10360e9c` | byte-identical |
| CMDQ descriptors | 69 | 46 | −23 |
| Doorbell-to-completion-tail cycles | 110,155 | 34,761 | −68.44% |
| Executed padded MACs | 1,884,160 | 1,884,160 | unchanged |
| MAC/cycle over full interval | 17.1046 | 54.2033 | 3.17× rate |
| Estimated 256-lane utilization | 6.68% | 21.17% | derived from RTL cycles |
| Layout-related busy cycles | 76,613 SFU tile-pack | 26,444 fused Matrix cycles | counter classes differ |
| Layout-related bytes | 117,760 accepted SPAD conversion bytes | 23,552 fused tile-write bytes | meanings differ; do not ratio |
| SPAD initialization traffic | 58,064 B | 56,224 B | setup only |

The model archive SHA-256 is
`e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`; the
integer Golden-logit SHA-256 is
`8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc`.
The R250 and v2 RTL logits files are byte-identical and have SHA-256
`7980fb678505ae0590d13c2f590b9523a98bedee7c3037936ccacb9b10360e9c`.

The timing counter starts immediately before the CMDQ doorbell write and stops
when the hardware completion tail reaches 46. It includes command execution,
completion commits and the hardware-visible completion interval. It excludes
testbench SPAD preload and post-run output reads/comparison. The fused-path
counter and legacy SFU tile-pack counter measure different internal events, so
their cycles are listed separately. The traffic fields likewise have different
definitions; no byte-reduction ratio is claimed here. Array utilization is a
derived simulation metric using 256 INT8 MAC lanes, not silicon utilization.

Exact replay command on the tested candidate SHA:

```sh
VCS_ARCH_OVERRIDE=linux \
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_digits_inference \
  AI_DIGITS_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  AI_DIGITS_RUN=/tmp/nmaforge_v2_digits_33e8528_replay
```

Result: VCS `V-2023.12-SP1_Full64`, Python 3.12.13, NumPy 2.4.6,
scikit-learn 1.9.1; `DIGITS_INFERENCE_PASS`, 360/360 outputs checked against
the independent integer Golden. Raw logs and generated model/input artifacts
are under `/tmp/nmaforge_v2_digits_33e8528_replay`; they are intentionally not
committed.

Machine-readable records: [CSV](../../benchmark/v2_digits_model_comparison.csv)
and [JSON](../../benchmark/v2_digits_model_comparison.json). The CSV includes
the field definitions and timing endpoints; empty stage fields mean that the
run did not instrument that stage.

## CNN and Transformer status

| Workload | Status | Evidence and boundary |
|---|---|---|
| ONNX `conv1x_mini` paired graph | **PASS; NMAForge side replayed at `d1867da`** | Current run `V2-TINYNPU-REPLAY-CURRENT-D1867DA-S20261029` rechecked all intermediate tensors and 4/4 outputs against the pinned model Golden. NMAForge: 1,985 compute + 1,080 host-layout cycles; TinyNPU: 4,781 graph cycles from prior run `TINY-COMPARE-V2C3A59-S20261029`. Different timing boundaries; no speedup ratio. |
| Trained-weight CNN | **NOT_RUN** | No trained CNN weight package and independent Golden are available in the current tree. |
| Tiny Transformer | **NOT_RUN** | The fixed-weight descriptor fixture is not a pretrained-model deployment. No trained model, Prefill/Decode Golden, or current v2 run is claimed. |
| Host / DMA / compute / writeback / graph cycle split | **PARTIAL** | Digits has a top-level CMDQ interval and a fused Matrix activity counter; the current run does not separately time host, DMA, writeback and orchestration. Its input preload is testbench setup outside the timed interval. |

The current paired CNN uses the exact ONNX asset supplied by the pinned
TinyNPU checkout and archives model/input hashes with its machine-readable
results. Reproduction logs are archived at
`/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59_logs.tar.gz`
(SHA-256 `6825223159a0d75c6f876fc971d7b02f30be4fef5ae0c7d91911374add385cdf`);
the archive is outside Git to keep generated simulation logs out of the
repository. Exact commands and all measured/modelled boundaries are in the
[replay record](NMAFORGE_V2_TINYNPU_REPLAY_2026-11-05.md). No ASIC PPA,
measured Fmax, power, or energy result is inferred from these RTL runs.

## Next model-benchmark closure

1. Add common Memory Adapter behavior to TinyNPU or keep its memory service
   explicitly modeled; do not merge the two endpoints into a single score.
2. Add a trained CNN and a small trained Transformer only with independent
   software Goldens and hardware-executed operators; keep host fallback
   separately measured. Both remain **NOT_RUN**.
3. Instrument distinct host, DMA, compute, writeback, and graph-orchestration
   windows for the larger model runs.
4. Preserve this Digits replay as the fixed regression and report each
   workload independently. Do not aggregate unlike cycle windows.

## Current fixed-candidate Digits replay — `410b81d`

The trained INT8 sklearn Digits MLP was rerun from the current fixed v2
candidate using the real top SPAD/CMDQ/CPLQ path and opcode `0x53`. Run ID is
`V2-DIGITS-410B81D-S20261029`. VCS
`V-2023.12-SP1_Full64`; Python 3.12.13, NumPy 2.4.6, scikit-learn 1.9.1.
Command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
AI_DIGITS_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
AI_DIGITS_RUN=/tmp/nmaforge_v2_digits_current_410b81 \
make ai_digits_inference \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10'
```

The replay passed 360/360 independent integer Golden logit checks and
classified 352/360 images (97.78%). It issued 46 descriptors and took 34,761
doorbell-to-completion-tail RTL cycles for 1,884,160 padded MACs, or 54.2033
MAC/cycle and 21.17% derived 256-lane utilization. The run logged 26,444
fused Matrix activity cycles and 23,552 bytes of fused tile writes. These
counters retain their own semantics and are not ASIC measurements.

Current artifact identities:

- Trained INT8 model SHA-256: `e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`.
- Independent integer Golden logits SHA-256:
  `8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc`.
- RTL logits CSV SHA-256:
  `7980fb678505ae0590d13c2f590b9523a98bedee7c3037936ccacb9b10360e9c`.
- Machine-readable current run record:
  [JSON](../../benchmark/v2_digits_410b81d.json) records the SPAD
  initialization-image, model, Golden and output hashes, endpoint, tool
  versions, and run limits.
- Combined run archive:
  `/tmp/nmaforge_v2_current_410b81_gemv_digits.tar.gz`, SHA-256
  `26b751910afa296181c1e85aab39910b71f0cdd49e196f493a5cdf1a22f9d5fa`.

The 360-image output and cycle result reproduce the previously reported v2
Digits result at this newer source/test SHA. This is not a trained CNN or
Transformer run. Separate Host, DMA, Compute, Writeback, and graph-orchestration
timers remain uninstrumented; ASIC PPA remains outside this simulation result.

## Current-candidate paired CNN functional replay — `d1867da`

The fixed-weight `conv1x_mini.onnx` workload was replayed through the current
NMAForge top, Matrix/SFU datapaths, CMDQ/CPLQ and behavioral SPAD. Executed Git
HEAD was `d1867da79a84b17451d63e919f9ce1e8ef4df098`; the intervening changes
from v2 source/test SHA `410b81dfd37992a760b28258bb7e8c6b6f5017d7` are
documentation and benchmark records only. VCS was
`V-2023.12-SP1_Full64`; Python 3.12.13, NumPy 2.4.6 and ONNX 1.17.0.

NMAForge passed all intermediate tensors and all four final output bytes.
The timed RTL window was 1,985 compute cycles plus 1,080 host-layout cycles;
SPAD traffic was 3,360 read / 1,600 write bytes for compute, with 144 read /
576 write bytes for host layout. The fixed TinyNPU model SHA is
`1ac385ac18394ac5826a7eb426e99c2199bf6417055f7e3f461c40c1b1811640` and the
input is generated with seed 99. TinyNPU's 4,781-cycle graph result is from
the pinned-reference replay at TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`; its timing boundary differs, so
no speedup ratio is reported. This is a fixed reference graph, not a trained
CNN model.

Reproduction command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/subsystem/top_smoke/sim ai_tinynpu_cnn_match \
  AI_TINYNPU_CNN_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  AI_TINYNPU_CNN_RUN=/tmp/nmaforge_v2_tinynpu_cnn_current_d1867da \
  AI_TINYNPU_CNN_MODEL=/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59/reference/source/models/conv1x_mini.onnx \
  AI_TINYNPU_CNN_GOLDEN=/tmp/nmaforge_tinynpu_bench_20261105_20261029_v2c3a59/tiny_cnn/graph_cnn/golden.bin
```

The [current CNN CSV](../../benchmark/v2_tinynpu_current_d1867da_cnn.csv)
records both sides and their timing boundaries. Logs, generated manifest and
input/expected SPAD images are archived at
`/tmp/nmaforge_v2_tinynpu_current_d1867da_logs.tar.gz` (SHA-256
`018d11dc90159192f0fb13c5e5901269b66be7ff8013bf4891cfd26b1e9e7885`).
The model has fixed reference weights; trained CNN and trained Transformer
remain **NOT_RUN**.

## Verification-only update — 2026-11-06

The latest testbench/build candidate is `380f96114dba022300db09fb217264c3a606a2fd`
(tree `79aaf0782aba0da18d7109b74ae2bd343a473181`), with no product RTL
change. No model workload was rerun on this test-only commit. The Digits,
fixed `conv1x_mini`, and TinyNPU comparison results above remain bound to
their named source SHAs; trained-weight CNN/Transformer and separated stage
timing remain **NOT_RUN**. The v2 feature coverage evidence is recorded in the
[DV report](../verification/NMAFORGE_V2_DV_CLOSURE.md).
