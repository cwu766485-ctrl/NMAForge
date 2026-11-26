# Phase 1 — trained CNN system boundary

Status: **RTL/independent Golden PASS; complete system latency NOT_MEASURED**.
RTL SHA `48790076b351cb9d49e1785247d32a1f51b8286d`;128KiB/four-bank,
256INT8MAC, VCS V-2023.12-SP1_Full64,4ns simulation, behavioral registered SRAM.
Model remains `benchmark/representative/models/r19_trained_digits_3x3_cnn.json`.
Model, input image, descriptor, DMA payload, Golden and output SHA256 are pinned
in the [Phase1 manifest](../../benchmark/research/phase1/manifest.json) and each
CNN manifest. Reproduce with
[run.py and supplement.py](../../tools/benchmark/phase1/README.md).

## Mathematical and quality contract

The trained digits graph retains570,164 useful MAC, including its bias plane:
`196*(36*63+1+64*10)`. Padded208-row/16-channel array work692,224MAC is separately
reported. The host resizes the sample, generates coordinate planes, performs
Im2col/quantization, packs native operands and builds descriptors. RTL performs
both GEMMs and selected epilogues. Host GAP/argmax reduces the final logits.
This is not a complete convolution/host-free system implementation.

All three mappings retain the same trained parameters, input/sample42 and fixed
rounding/saturation. Existing metadata: FP32 accuracy95.5556%, INT8 accuracy
96.1111% over360held-out examples. This Phase1 run checks sample42/class1 and
20,800 exact Golden words/mapping, not the full360example dataset in RTL.
Do not claim that one RTL example re-estimates dataset accuracy.

## Fresh measured segments

| Segment | Legacy | First fused | Both fused row-major |
|---|---:|---:|---:|
|Descriptors|4|3|2|
|CMDQ doorbell→last completion cycles|65,429|22,983|12,351|
|Compute accepted SPAD reads B|130,624|77,376|64,064|
|Compute accepted SPAD writes B|83,200|29,952|16,640|
|Useful MAC/CMDQ cycle|8.7142|24.8081|46.1634|
|DMA setup+transfer cycles|3,051|3,035|3,019|
|DMA busy cycles, subset of previous row|2,911|2,895|2,879|
|Actual DMA payload B|11,072|11,008|10,944|
|Queue configuration cycles / writes|54 /9|54 /9|54 /9|
|Output AXI-Lite readback cycles|4,992|4,992|4,992|
|Output bytes / words|3,328 /832|3,328 /832|3,328 /832|
|Host preprocess seconds, single instrumented call|0.000775984|0.000368538|0.000332701|
|Host GAP+argmax median ns,100 repeats|8,908|5,187|5,177|

Host timing uses Python3.12.13/numpy on this CPU, warmup before100postprocessing
samples. Preprocess timings are single samples and include software scheduling
noise; they are not hardware cycle measurements. Binary packing/descriptor
construction has no separate timer. The retained output byte digest is identical:
`04b138d012cc69ccdbd28dfb2c36f187bf0c6b7e91596dd088d4e93641c3a5f6`.

Both-fused DMA has four transactions:7,488B atSPAD0,2,304B at8,192,
1,024B at81,920,128B descriptors at106,496. The plan's actual10944B transfer is
not the sparse memory-image address span.83232B poison setup is test-only and
excluded. AXI reads45bursts/684beats,10944B; aggregate AR→last-R latency2142clocks
across45bursts, maximum50. The testbench AXI memory/backpressure model is used;
there is no external DRAM-controller/package latency model.

## Layout and full-inference limitations

Legacy and first-fused mappings explicitly requant/pack intermediate or final
INT32 outputs through SFU. Existing0x53 both-fused row-major performs shifts,
activation, packing and row-major output within the measured Matrix writeback.
Thus no separate on-device Pack/Layout descriptor remains in this CNN case.
Host input Im2col/packing remains outside CMDQ and was not removed by0x53.

The CMDQ timer includes operand service, compute, output materialization,
descriptor scheduling and final completion commit. It excludes initial DMA,
queue setup, host preprocess, output readback and host postprocess. DMA busy is a
subset of preload, not an additional cost. Descriptor bytes are already in DMA
payload.832output words are deployment output readback;20,800Golden words are
verification traffic and must not be charged as application output.

**Full inference boundary** would begin with original host image availability
and end with class prediction, including preprocessing, binary packing, command
construction, transfer, device work, readback and GAP/argmax on an integrated
execution timeline. That timeline is absent. The simulator also inserts checker/
poison activity between segments. Summing the listed disjoint hardware segments
can describe a partial budget, but does not establish measured full inference.
CPU seconds must never be added to RTL clocks. No end-to-end throughput/Fmax or
TinyNPU system speedup is claimed.

Existing fusion ablation removes53,078CMDQ cycles relative to legacy with the
same output. That benefit already exists at the approved RTL baseline. New
candidate A must identify work beyond that baseline, rather than count the same
fusion a second time. Remaining5,200writeback-state clocks include only1,040
accepted16Bstores;4,160packing/control clocks are a future implementation issue,
not evidence that another independent Pack stage exists.
