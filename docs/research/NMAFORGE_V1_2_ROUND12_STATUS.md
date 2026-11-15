# NMAForge v1.2 Round 12 — QK-Compatible KV Append

## Candidate and Isolation

Research branch: `research/nmaforge-v1.2-round12`  
Base: Round 11 commit `0438a65e33649fa094679b21171cc4054a920c29`  
Product RTL/ABI and PR #7/#8: unchanged.  
The working tree is `/tmp/nmaforge-v1.2-round12`.

## Gate Results

| Gate | Result | Evidence |
|---|---|---|
| G0 layout / mode contract | **PASS, scoped** | Independent 16x16 checker: QK-compatible append 0/64 packed-word mismatches; Matrix-A tile 0/64; legacy append 64/64. Research contract in [QK KV spec](NMAFORGE_V1_2_ROUND12_QK_COMPAT_KV_SPEC.md). |
| G1 real Product Top | **PASS, scoped to six-token batch** | Real K projection, Requant, flags=0x02 KV writes, Product KV readback, four-head QK/softmax/AV, output projection and FFN. 31/31 checkpoints; no reset between descriptors. DMA preload is real. |
| G2 persistent decode / queue streaming | **NOT COMPLETE** | The 249-descriptor workload fits the existing 256-entry queue. No software CPLQ consumer, batch publisher, Queue Wrap, or Token 0–5 per-token retirement planner was added. |
| G3 directed fault / benchmark | **PARTIAL** | Random request backpressure and 0–7-cycle registered responses, 16-token block layout, accepted-read Abort and one-word packed-write Abort prefix pass. QK-mode parity/protection and reset-with-outstanding tests are not run. Product Top normal-path A/B and legacy append negative control completed. |

Round 12 does not claim Persistent Decode PASS. The Product Top result is a
single six-token batch with cache-backed attention operands, matching Round 11
scope.

## Root Cause and RTL Repair

The initial `flags=0x02` RTL test left the expected word at `0x4100` unchanged.
`qk_cache_word_addr` placed the `<< 2` after an unparenthesized address sum;
Verilog precedence shifted the entire sum, so `0x4100` became `0x10400`. The
address is now computed from an explicit packed-word index multiplied by four.

Product Top initially rejected the generated KV_READ at descriptor 39 because
the validator extension had constrained legacy `flags=0` reads to version 5.
Round 11's valid workload uses ABI v7. The validator now limits version 6 to
the new `0x43/flags=0x02` mode, while retaining legacy flags 0/1 acceptance and
the existing KV_READ behavior.

The old `flags=0x01` mapping writes `[token,feature]` Matrix-B order. QK needs
`K^T[feature,token]`; Matrix Core `transpose_b` only permutes within the local
4x4 load group. The independent checker reports 64/64 physical word
mismatches for old append and 48/64 after local `transpose_b`. Both the
existing Matrix-A tile representation and new QK-compatible append match the
canonical QK packer at 0/64 mismatches.

## Product Top A/B

Tool: Synopsys VCS `V-2023.12-SP1_Full64`; 10 ns clock; behavioral 128 KiB SPAD
configured as four 32 KiB banks; seed `20261115`. Both passing runs use the same
six tokens `1,7,42,3,5,8`, model, DMA weight payload, Product Top, completion
conditions, and checkpoints.

| Variant | Descriptors | End-to-end cycles | SPAD read/write bytes | DMA payload | Useful/executed/padding MACs |
|---|---:|---:|---:|---:|---:|
| Matrix-A tile | 229 | 338,050 | 346,496 / 222,208 | 49,152 B | 297,600 / 819,200 / 521,600 |
| QK-compatible append | 249 | 340,602 | 345,856 / 221,568 | 49,152 B | 297,600 / 819,200 / 521,600 |

The new mode cuts 640 B of SPAD reads and 640 B of writes in this batch, but
adds 20 descriptors and is 2,552 cycles (0.76%) slower. Combined SPAD traffic
falls by 1,280 B, about 0.23% of the Matrix-A tile run's measured SPAD traffic.
This is not a performance win. Its possible value is the per-token cache write
granularity, which has not yet been evaluated in a persistent decode loop.

The existing Matrix-B token append negative control fails at descriptor 47,
address `0x4100`: expected `0xfffffdc7`, actual `0x00000187`. Matrix-A word mode
generates 321 descriptors and remains unrun because the current queue has 256
entries; no queue-depth change or streaming implementation is claimed.

## Block and Golden Evidence

The KV/CNN block VCS run checks all 64 words for a 16x16 K tile across token
indices 0–15 and both head boundaries. It observes 64 accepted reads and 64
accepted writes. Added fault points verify Abort with an accepted read and an
Abort after the first accepted packed write, preserving the one-word committed
prefix and untouched suffix. Existing legacy KV, flags=0x01 append, reset
recovery, address boundary, and convolution checks remain in the same run.

Independent cache-vs-full-recompute Golden comparison passes 16 tensor
boundaries: four QK score tensors (21 active causal entries each), four Q15
probability tensors, four AV tensors, Residual1, LN2, FFN-down accumulation,
and Residual2. This Python comparison is separate from the Product Top 31/31
checkpoint evidence.

`descriptor-validator-regress` emits
`DESCRIPTOR_VALIDATOR_PASS legal_opcodes=29 tile_pack=1 invalid_rules=37 ...`;
the direct VCS simulation exits 0. In this environment the Make wrapper
returned status 2 after that PASS marker, so the wrapper status is recorded as
an unresolved flow issue rather than called a Make-target PASS. `ai_smoke`
passes with `TEST PASS`; its existing `LOOP-REROLL-ENABLED` fixture warning
remains.

## Decision

**REWORK for research; do not productize now.** The address/layout mechanism is
correct in block RTL and Product Top. It reduces cache traffic in the batch,
but loses end-to-end cycles and adds descriptors. Keep the candidate isolated
only to test whether token-at-a-time append can replace the 321-descriptor
Matrix-A word plan and support true online cache reads. Stop if that comparison
does not deliver a meaningful decode-cycle or traffic benefit. Do not alter the
product ABI or merge this mode.

## Reproduction and Logs

```sh
cd /tmp/nmaforge-v1.2-round12
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/check_h64_kv_qk_layout.py \
  --seed 20261115 --size 16 \
  --json benchmark/gpt2_compat/results/round12_kv_qk_layout.json
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/compare_h64_kv_recompute.py \
  --seed 20261115 --tokens 1,7,42,3,5,8 --kv-k-write-mode qk-compatible-append
make -C dv/block/compute/cnn_kv/sim random-latency-test \
  SEED=20261115 OUT_DIR=/tmp/nmaforge_round12_kv_finalpass
make -C dv/subsystem/top_smoke/sim ai_h64_kv_roundtrip_top \
  AI_H64_KV_RUN=/tmp/nmaforge_round12_qk_product_fixed \
  AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python \
  AI_H64_KV_SEED=20261115 \
  'AI_H64_KV_GENERATOR_FLAGS=--kv-attention --tokens 1,7,42,3,5,8 --kv-k-write-mode qk-compatible-append'
make -C dv/subsystem/top_smoke/sim ai_smoke
```

Matrix-A tile A/B uses the same top target and generator flags, replacing the
last generator option with `--kv-k-write-mode matrix-a-tile`. The legacy
negative control uses `--kv-k-write-mode token-append` and is expected to stop
at descriptor 47.

Raw logs and generated workload artifacts:

- QK-compatible Product Top: `/tmp/nmaforge_round12_qk_product_fixed/`
- Matrix-A tile Product Top: `/tmp/nmaforge_round12_matrix_a_tile/`
- Legacy append negative control: `/tmp/nmaforge_round12_legacy_append_fail/`
- KV/CNN block and coverage: `/tmp/nmaforge_round12_kv_finalpass/`
- Descriptor validator: `/tmp/nmaforge_round12_validator_final/`
- Layout checker JSON: `benchmark/gpt2_compat/results/round12_kv_qk_layout.json`
- A/B table: `benchmark/gpt2_compat/results/round12_kv_qk_ablation.csv`

Selected SHA-256 values:

| Artifact | SHA-256 |
|---|---|
| QK Product Top compile log | `a498c7bbfc7573efa6cbde06137c59d53a7825cc5e3ab582826b7dfff7015eef` |
| QK Product Top run log | `b7525e2edc9c105b75ffc4bc46187655088e5210f6a56af9a752bb93b0a1ac72` |
| QK manifest | `727bb29a5732212ea3215bd55be6d4e9eab25cf8eddd79953672ffe4a0d43440` |
| QK checkpoint Golden | `5a2dbd52ffb83ad0c649a28474ca909cb0b79bec5a249e4dbad3704a3027ac9e` |
| Matrix-A tile run log | `1bb2308ede81b52b4f2e3dcde9f614cd04cca3d124a73f0f05a630412fe4df2b` |
| Legacy append negative-control log | `691fa1c22fba8bb258e3f8e2c1e714e4ac1ac63a3296ef2cb8873c3dde8814e2` |
| KV/CNN block run log | `745c843e93c4a7e4cae4a080e70aa539bad8e764dd8f5eb2381ce3cbabe5bff4` |
| Validator run log | `e6341d0c70d6671864a0803142600d8578d25d33dda71e729c72cabe99648221` |
