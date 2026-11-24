# Round 31 one-block DeiT Output Projection evidence

This archive contains a new VCS Product Top run on the integrated research
branch. It continues one 16-query, three-head Round 30 Attention block through
AV requantization, streamed official Layer-0 Wo weights, INT32 projection and
head accumulation, and final INT8 Output Projection. The 768 final output
words and all intermediate batch Goldens passed.

## Reproduction

The official checkpoint is not included. Supply the pinned checkpoint with
SHA-256 `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` at
`/tmp/nmaforge_deit_tiny_b3428f18_pytorch_model.bin`, then run:

```bash
make -C dv/subsystem/top_smoke/sim ai_deit_round31_attention_output_projection_256k \
  AI_DEIT_R31_WO_RUN=/tmp/nmaforge_deit_round31_wo_top_integrated_v3 \
  AI_DEIT_R31_WO_SOURCE=../../../../benchmark/deit/round26/evidence/qkv197/workload
```

The exact Product RTL aggregate, TB, Makefile, generator, workload, model,
Golden, tool, configuration, command and exit codes are in `run_manifest.json`.
`workload/` contains the generated descriptor batches, batch Goldens, source
images, DMA payloads/plans and generator manifest. The raw VCS compile, run,
and generator logs are losslessly archived as gzip files; no VCS binary or
generated compiler directory is included. The compile log records the existing
`LOOP-REROLL-ENABLED` debug-capacity warning.

## Scope

This is a 16-of-197-query Output Projection slice, not Encoder Layer 0 closure.
Residual1, LN2, FFN/GELU, Residual2, the remaining 181 query rows, the other
eleven layers, and image classification accuracy remain NOT_RUN. Runtime
cycles are simulated Product Top command-path cycles and are not application
latency or silicon performance.
