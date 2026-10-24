# Multi-Engine NPU Compute Cluster Verification

The selected regression covers the five compute groups under `rtl/compute`:
CNM, CNN/KV, mixed-precision FP, Matrix, and SFU. It uses direct block tests,
the real `ai_accel_top` command path, and shared DMA/SPAD subsystem traffic.
Register, opcode, fixed-point, and memory contracts come from
`docs/spec/SPEC_ZH.md` and `docs/architecture/ARCHITECTURE.md`.

## Run the aggregate

From the repository root:

```sh
make -C dv/subsystem/tensor_datapath/sim cluster_regress
```

The aggregate runs:

1. CNM A2.2/GEMV checks, an 8-length signed INT8 oracle, six fault exits, and
   reset recovery on three seeds.
2. CNN line-buffer and KV tests with 24 convolution cases (12 depthwise) and
   24 KV round trips per seed, including config/error/abort/watchdog, active
   reset, recovery, 0–7-cycle response latency, and ready stalls.
3. 10,072 Matrix datapath cases per seed, six full-core numerical/layout/
   recovery cases and ten fault cases per seed, on three seeds; plus the A3
   benchmark.
4. 64 SFU oracle vectors plus seven error cases and reset recovery per seed on
   three seeds, covering all eight opcodes, supported vector lengths,
   randomized SPAD latency, and ready back-pressure.
5. Ten DMA–SPAD–CNM subsystem seeds with protection/parity errors, abort/drain,
   recovery, and real DMA overlap with compute traffic.
6. Three seeded BF16 compatibility-wrapper runs, three seeded FP16/BF16 add/sub
   runs with 20,032 reference vectors each, three 212-transaction mixed-format
   FP UVM runs, FP parity checks, and FP reference tests.
7. A4 reference tests, top smoke with 20 seeded INT8 cases, and formal proof of
   serial dispatch across the seven-engine cluster.
8. Five top DUT coverage seeds plus three-seed code coverage for each direct
   compute block. URG merges matching module definitions and includes the
   command processor's `ai_tile_pipeline` instance in the top scope.

Override `CLUSTER_TAG`, `CLUSTER_OUT`, `COMPUTE_SEEDS`, `COMPUTE_COV_SEEDS`,
`DMA_SPAD_SEEDS`, `FP_SEEDS`, `AI_RANDOM_CASES`, and `AI_SEED` as needed.
Generated VCS, formal, and URG artifacts are stored under `/tmp`; DMA–SPAD
per-seed artifacts are moved there after the regression.

## Current result

The 2026-10-23 multi-seed run completed with
`MULTI_ENGINE_COMPUTE_CLUSTER_PASS`. DUT-only merged VCS/URG coverage covers
all 23 definitions in `rtl/compute`; the report also includes
`ai_accel_compute_cluster`. Merged module-definition line/condition/FSM/branch
coverage is 92.17% / 88.59% / 52.00% / 86.00%; the top-only five-seed view is
74.99% / 64.87% / 30.93% / 61.36%. This is raw partial code coverage, not
closure or signoff. Detailed per-module metrics, functional counts, command,
and residual work are in the
[compute-engine status](../../../docs/verification/COMPUTE_ENGINE_STATUS.md)
and [2026-10-23 validation record](../../../docs/verification/COMPUTE_ENGINE_BLOCK_VALIDATION_2026-10-23.md).

The command processor dispatches one compute command at a time. Formal proves
the selected serial-dispatch and onehot ownership properties and reaches all
seven engine covers; it does not prove arithmetic or full-top behavior.
Simultaneous engine starts remain unsupported. Multi-fault × abort × reset
combinations, residual raw bins, full-domain FP parity proof, and project-wide
UVM/formal/LEC/DFT closure remain open.
