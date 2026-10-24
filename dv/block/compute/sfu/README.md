# SFU block verification

Run the direct three-seed randomized gate from the repository root:

```sh
make -C dv/block/compute/sfu/sim random-latency-regress \
  SEEDS='20261021 20261022 20261023' OUT_DIR=/tmp/nmaforge_sfu_multi_seed
```

The test generates eight length points (1, 2, 3, 4, 7, 8, 15, 16) for each
implemented opcode: Softmax, causal Softmax, RMSNorm, LayerNorm, residual,
GELU, requant, and SiLU. A Python fixed-point reference model supplies the
expected words. The direct core testbench adds randomized scratchpad request
stalls and 0–7-cycle ordered response latency, then checks all writes,
element counts, and read/response accounting. GELU and SiLU vectors exercise
below-threshold, threshold, and above-threshold signed Q8.8 values. The
2026-10-23 three-seed VCS regression passed 64/64 vectors per seed with
1,038/1,038 reads/responses and 426 total writes per seed; maximum response
latency was 7 cycles. Each seed also checks eight error/interaction cases (invalid length,
unsupported opcode, unaligned input, SPAD protection/parity, abort, and
watchdog), reset while active, and normal oracle traffic after reset. The
DUT-only line/condition/FSM/branch VDB accumulates all three runs.
Vector and simulation artifacts stay under `/tmp`.

The causal Softmax vectors include query token zero at lengths 1 and 7. The
contract treats the query index as zero-based and inclusive, so token zero
keeps only the first score and expects `[32768, 0, ...]`. The RTL preserves
zero for opcode `0x39` while retaining the nonzero epsilon default for
normalization operators. The top smoke separately checks the directed
Transformer SFU cases. This gate is simulation evidence, not formal or
code-coverage closure. Interaction additions inject parity after 8 of 16
responses, combine watchdog/parity/protection with abort, and assert reset
while those inputs are active. Each of the three seeds checks prefix
writeback, drain, error priority, and post-reset recovery. Numeric-error
reachability and other error/reset combinations remain open. The merged module metrics are summarized in the
[compute-engine status](../../../../docs/verification/COMPUTE_ENGINE_STATUS.md).
