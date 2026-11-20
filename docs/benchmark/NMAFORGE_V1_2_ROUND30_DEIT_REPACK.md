# NMAForge-V1.2 Round 30 — DeiT Repack and Continuous Attention

## Disposition

**0x3B Repack layout/physical-span checks: PASS. Continuous Product Top QKV → Repack → three-head Attention for all 197 queries: PASS. Streaming Runtime qualification: PARTIAL. Full Encoder Layer 0 and official DeiT inference: NOT RUN.**

This is a real single-Top-session attention data path, but it is not an Encoder Layer or a DeiT classification result. Keep that boundary in any summary.

## Baseline and tested source

- Research branch: `research/nmaforge-v1.2-round30-deit`.
- Tested base commit: `864ba16aa052fbb0f2bb8948133a54586cec6b26`.
- Product RTL diff SHA-256: `3da860fa51351257122cc613741e77bef975b426dde360806c50c10579a78b10`.
- Tracked source diff SHA-256 at run: `1114b805c89b9a2181526722dc65f21e95d5e438020d686efd51b2dbde63cea3`.
- VCS: `V-2023.12-SP1_Full64`, Rocky Linux WSL; seed `300030`.
- SPAD: 4 banks × 16,384 32-bit words = 262,144 bytes (256 KiB).

The tests ran against the base commit plus the recorded working-tree diff. Subsequent changes in this branch are report/reproduction metadata only; no product RTL was changed after the passing run.

## 0x3B contract correction

The Repack source is a padded sparse 4×4 Matrix-A tile image. The descriptor validator previously checked a dense `M*N` byte range, which understated the physical source span. For `M=208`, `N=192`, the correct span is `4*M*N = 159,744` bytes, from `0x02000` to exclusive end `0x29000`.

The Round 30 validator change checks that complete physical span, including alias rejection. `aux0[4]` selects packed INT8 Matrix-A input (256 bytes per tile); when clear, the existing sparse INT32 layout remains in effect (1,024 bytes per tile). Reserved `aux0[31:5]` bits remain checked. Repack source tile stepping now follows the selected layout. The SPEC and descriptor-validator directed test cover packed/legacy spans and backward-compatible legacy mode.

## Gate results

| Gate | Status | Evidence / boundary |
|---|---|---|
| B0: 0x3B layout and address validation | **PASS for tested layouts; overall PARTIAL** | Q-dense, K-major and V-Matrix-B standalone Product Top layouts; 197 valid + 11 padded rows; validator physical-span/alias tests. External AXI Descriptor Fetch was not run. |
| B0: focused Repack fault behavior | **PASS for directed cases** | Three layouts × three heads, backpressure, invalid descriptor, abort and in-flight reset; 6,144 Golden words. The directed TB asserts request stability under backpressure. This is not broad subsystem closure. |
| B1: real Q/K/V producer → Repack | **PASS** | Same unreset Top session; 468 actual QKV projection descriptors, followed by 0x3B reading the Product-written SPAD results. No Host intermediate activation readback/writeback. |
| B2: Repack → QK → non-causal Softmax(197) → pack → AV | **PASS** | 3 heads × 13 query blocks; all 197 valid queries and all 197 valid keys; padded query rows zeroed and invalid keys excluded. 361,920 streamed Golden words checked. |
| B3: bounded AXI-Lite ring / streaming | **PARTIAL** | 512-entry bounded CMDQ/CPLQ ring, 159 batches, 19 wraps and 9,564 streamed descriptors passed. External descriptor fetch and explicit streaming Abort/Reset/Backpressure recovery matrix remain unqualified. |
| Full Encoder Layer 0 | **NOT RUN** | No model-consistent continuous descriptor/Golden flow for head merge, output projection, residual, LN2, FFN/GELU and second residual is present in the Round 30 workload generator. |
| Official DeiT-Tiny / ImageNet classification | **NOT RUN** | Current QKV source is a fixed Round 26 workload fixture, not an official checkpoint image-classification run. |

### Continuous Top run

Exact command:

```bash
make -C dv/subsystem/top_smoke/sim ai_deit_round30_full_attention_256k \
  AI_DEIT_R30_FULL_RUN=/tmp/nmaforge_deit_round30_full_attention_passive_offset_run \
  AI_DEIT_R30_CONT_SOURCE=/tmp/nmaforge_deit_round26_qkv197_rerun/workload
```

Make and simulator run exit status: **0**. The archived run marker is:

```text
DEIT_R30_CONTINUOUS_QKV_REPACK_3HEAD_ATTENTION_PASS prefix_desc=468 streamed_desc=9564 total_desc=10032 batches=159 query_blocks=13 valid_query_rows=197 ring_wraps=19 golden_words=361920 runtime_cycles=7949430 reset_events=0 host_intermediate_tensor_readback=0 host_intermediate_tensor_writeback=0 measurement=AXIL_publication_retirement_plus_Product_execution_golden_observation=passive_spad_backdoor
```

The three QKV producer checkpoints contain 29,952 words total. The test then uses 13 query blocks for each of three heads and checks the full attention stream. Golden observation uses a passive behavioral-SPAD backdoor after retired batches; it does not perturb AXI traffic and is not a host data-path conversion.

Runtime and resource evidence:

- 10,032 total descriptors: 468 QKV prefix + 9,564 attention/repack descriptors.
- 159 bounded publication/retirement batches; 19 ring wraps; no reset events.
- Runtime cycles: 7,949,430 for AXI-Lite publication/retirement, Product execution and passive Golden observation.
- SPAD high-water: 211,968 bytes. Descriptor ring `[221184,253952)` (32 KiB), completion ring `[253952,262144)` (8 KiB), reusable Repack/attention scratch below 16 KiB.
- Profiled QKV prefix: 402,889 command cycles; 905,189 representative-run endpoint cycles; DMA preload is excluded from that endpoint. Payload bytes and fixture/poison setup are separately listed in `performance.csv`.

Do not present 7,949,430 cycles as application host-to-host inference latency. This run begins from the fixed workload's LayerNorm output and preloaded weights/inputs; it does not execute a complete official DeiT inference. The `performance.csv` command/preload boundaries are preserved in the evidence directory.

### First failed observation and retry

The first passive-observer run reported a false mismatch at descriptor 155 because the testbench observer used the wrong absolute SPAD base offset. The address on the Product datapath was not changed. The observer offset was corrected and the final replay passed; both the failed attempt and disposition are retained under `benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor/passive_checker_retry1/`.

## Full Encoder continuation assessment

The passing run proves all-query Attention, not the next encoder operations. The current generator produces through per-head AV and lacks a complete, independently Golden-checked descriptor graph for head merge → output projection → residual/LN2 → FFN 192→768→192 → GELU → residual. Before claiming Layer 0, add the downstream quantized model tensors, consumer-compatible layouts, dependency events, allocation/lifetime plan, and output check to one continuous Top session. No host-produced intermediate may be inserted. Therefore this stage is recorded as **NOT RUN**, rather than inferred from individual operator support.

## Reproduction and evidence archive

Use (VCS and the project Python/NumPy environment are required):

```bash
bash benchmark/deit/round30/reproduce_round30_final.sh
```

The script extracts the archived QKV source workload to a fresh temporary directory, then runs the descriptor-validator regression, 128 KiB compatibility smoke and the 256 KiB continuous attention target. It preserves generated inputs and logs under the printed run directory. VCS licensing and Python 3.12/NumPy must be available.

Primary evidence:

- Continuous Top logs and source/workload archives: `benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor/`.
- Directed Repack logs: `benchmark/deit/round30/evidence/repack/round30-repack-directed-final_{compile,run}.log.gz`.
- Descriptor validator: `benchmark/deit/round30/evidence/validator/final_round30/`.
- Compatibility smoke: `benchmark/deit/round30/evidence/top_smoke/final_round30/`.
- Machine-readable full-run profile: `benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor/performance.csv`.
- Full-run SHA-256 list: `benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor/sha256sums.txt`.

## Remaining work

1. Qualify external descriptor fetch and streaming failure recovery with the same bounded ring semantics.
2. Generate and validate the full downstream Encoder Layer 0 descriptor graph, then run it continuously in Product Top.
3. Only after Layer 0 passes, stream all 12 official DeiT layers and classifier weights and measure labeled-image accuracy.

Round 30 does not claim Full Encoder, 12-layer inference, ImageNet accuracy, or full Runtime/DV closure.
