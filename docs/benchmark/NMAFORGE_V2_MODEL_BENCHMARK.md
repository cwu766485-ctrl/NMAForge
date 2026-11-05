# NMAForge v2 Model Benchmark

**Status date:** 2026-11-05  
**R250 baseline:** `3041355528dffe856e2d5384027c6ee5df5d1b42`  
**v2 RTL/test candidate:** `33e85287fbf37187fccb76e97be6effe888670e9`  
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
| ONNX `conv1x_mini` paired graph | **PASS on replay SHA `c3a59f0`** | Run `TINY-COMPARE-V2C3A59-S20261029`, TinyNPU SHA `8216c22b762011aa20c05fc2768423fd12dda59d`. Same model SHA `1ac385ac…1811640` and input SHA `a74587bf…705898`; NMAForge checked all intermediate tensors and 4/4 outputs. NMAForge: 1,985 compute + 1,080 host-layout cycles; TinyNPU: 4,781 graph cycles. Different boundaries; no speedup ratio. |
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
