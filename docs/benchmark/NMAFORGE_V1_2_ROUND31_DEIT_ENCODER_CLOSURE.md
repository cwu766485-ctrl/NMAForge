# NMAForge-V1.2 Round 31 — DeiT Encoder Layer 0 Closure

## Disposition

**PARTIAL.** Round 31 now passes one 16-query block through three-head Attention, AV requantization, official Layer-0 Wo projection/head accumulation, and final INT8 output on the Product Top. This closes a bounded physical handoff slice, not the full 197-query Encoder Layer 0. Remaining work is to extend the same lifetime schedule to all 13 query blocks and add Residual1, LN2, FFN/GELU, and Residual2. No Product RTL was changed.

The historical Round 30 all-197-query evidence below is reused and was not rerun. A separate Round 31 16-query Product Top run was executed on the integrated branch.

## Baseline and reused evidence

| Item | Value |
|---|---|
| Round 31 branch | `research/nmaforge-v1.2-round31-deit` |
| Round 31 branch start | `1ec352ea261892eb882824bf476f3df76e8ae986` |
| Round 30 tested base | `864ba16aa052fbb0f2bb8948133a54586cec6b26` |
| Product RTL diff SHA-256 at Round 30 run | `3da860fa51351257122cc613741e77bef975b426dde360806c50c10579a78b10` |
| Tracked source diff SHA-256 at Round 30 run | `1114b805c89b9a2181526722dc65f21e95d5e438020d686efd51b2dbde63cea3` |
| Historical Run ID / seed | `round30-deit-full197-passive` / `300030` |
| Simulator | VCS `V-2023.12-SP1_Full64` |
| SPAD configuration | 4 banks, 16,384 32-bit words/bank, 262,144 bytes total |
| Archived evidence hash manifest | `benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor/sha256sums.txt` |

## New Round 31 Product Top slice

| Item | Value |
|---|---|
| Branch / Product RTL source | `research/nmaforge-v1.2-integrated-model-dv` / `ad58507fa5052ccec61e05428c4e36e493796b8b` |
| Product RTL aggregate SHA-256 | `57bb84647e5bc34fe5a833e7d4895b7ef1b969fc747d462f1f1a53d1ce05bc68` |
| Run ID / seed | `nmaforge-v1.2-round31-deit-wo-16q-integrated-v1` / `310031` |
| Simulator / SPAD | VCS `V-2023.12-SP1_Full64`; 4 banks × 16,384 words × 4 B = 256 KiB |
| Official checkpoint SHA-256 | `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` |
| Generated workload manifest SHA-256 | `a2d04c4e948cd54d26098b1281bf6c886501c87d254865d888ff01c46fd9974b` |
| VCS / Make exit code | 0 / 0 |

The new run uses pinned official Layer-0 output-dense weights. It publishes 864 descriptors after the 468-command QKV prefix: 744 Attention plus 120 AV requant/Output Projection commands. The bounded ring retires 64 batches with two wraps. All 72,384 batch Golden words pass, including all 768 words of the 16×192 final INT8 projection output.

The AV producer keeps four contiguous 16×16 INT32 panels per head. The first generator attempt treated those panels as one row-major 16×64 source and failed its first AV-requant Golden at `0x3004` (`expected=fcd9ff05`, `actual=fcd80203`). The corrected workload requantizes four-row panel slices and places each packed result at the corresponding full Matrix-A tile row-group offset. The corrected VCS run passes; this was a software layout correction, not an RTL change.

The Wo matrix and bias are streamed through the real Product DMA: 48 events, 37,632 bytes, 9,408 checked words, 162 AXI read bursts, 2,352 read beats, and 11,670 simulated DMA cycles. The end-of-stage command-path window is 821,466 cycles. The output quantization reports zero weight saturation and operator-local max absolute error 0.185593 versus the float Wo projection of the integer Attention AV reference. This is not whole-model accuracy. There are zero host intermediate-activation readback/writeback words; Golden observation uses the passive behavioral-SPAD backdoor.

Reproduce with `make -C dv/subsystem/top_smoke/sim ai_deit_round31_attention_output_projection_256k` and the run override in [the evidence README](../../benchmark/deit/round31/evidence/attention_output_projection_16q/README.md). Raw compile/run/generator logs, generated workload, final output Golden, performance CSV, and hashes are archived under `benchmark/deit/round31/evidence/attention_output_projection_16q/`. The existing `LOOP-REROLL-ENABLED` compile notice remains in the raw log.

The archived hash manifest was checked with `sha256sum -c`; every listed file passed. The compressed run log ends with the exact pass marker below and `$finish`:

```text
DEIT_R30_CONTINUOUS_QKV_REPACK_3HEAD_ATTENTION_PASS prefix_desc=468 streamed_desc=9564 total_desc=10032 batches=159 query_blocks=13 valid_query_rows=197 ring_wraps=19 golden_words=361920 runtime_cycles=7949430 reset_events=0 host_intermediate_tensor_readback=0 host_intermediate_tensor_writeback=0 measurement=AXIL_publication_retirement_plus_Product_execution_golden_observation=passive_spad_backdoor
```

The archived Make and simulator exit status is 0. The exact historical command is:

```bash
make -C dv/subsystem/top_smoke/sim ai_deit_round30_full_attention_256k \
  AI_DEIT_R30_FULL_RUN=/tmp/nmaforge_deit_round30_full_attention_passive_offset_run \
  AI_DEIT_R30_CONT_SOURCE=/tmp/nmaforge_deit_round26_qkv197_rerun/workload
```

Round 30 starts from the fixed full-KV QKV Product projection workload, whose source is an existing DeiT workload fixture. Within the single unreset Top session, Product-written Q/K/V feed Repack and Attention; no host intermediate activation readback or writeback is reported. Golden observation uses a passive behavioral-SPAD backdoor after retired batches.

### AV scratch lifetime audit

The historical Attention generator does not retain the complete `[197, 192]` AV result tensor. In `benchmark/deit/round30/generate_qkv_attention_continuous.py`, each head receives a 4 KiB INT32 AV scratch window at `AV_BASE + head * 0x1000`. Four subtiles write at `av_base + i * 0x400` (`i=0..3`). The same per-head addresses are reused for every `query_start` (13 blocks: 12×16 rows plus the final 5 valid rows). Thus the recorded `persistent_av_bytes=12,288` means three current-query-block scratch windows, not all-query AV storage. The run checks each retired query-block batch against Golden before those addresses are reused; it establishes complete Attention computation, but not a persistent head-merged layer output.

Round 31 implements and measures the query-block-major handoff for one 16-row block: 48 four-row panel requants place the three heads into reusable Matrix-A scratch, then the Wo tiles are streamed and retired before their windows are reused. It does not retain a full `197×192` AV tensor. If AV were retained as INT32, that full tensor would occupy 151,296 bytes; as packed INT8 it would occupy 37,824 bytes. Neither amount is part of the historical Round 30 211,968-byte high-water. The new allocation ends below `0x16000`; full Layer 0 liveness and capacity are still unmeasured.

## Reused results and limits

| Measurement | Historical value | Boundary / interpretation |
|---|---:|---|
| Valid queries / keys | 197 / 197 | All 3 heads; final query block has 5 valid rows |
| QKV prefix descriptors | 468 | Fixed fixture LayerNorm output and preloaded workload inputs/weights |
| Attention/Repack descriptors | 9,564 | Streamed through a bounded 512-entry AXI-Lite CMDQ/CPLQ ring |
| Total descriptors / batches / wraps | 10,032 / 159 / 19 | Ring publication and retirement; no reset events |
| Attention Golden words | 361,920 | Passive observation after retired batches |
| Runtime cycles | 7,949,430 | Publication/retirement, Product execution and passive Golden observation; **not host-to-host inference latency** |
| CMDQ / representative endpoint cycles | 402,889 / 905,189 | DMA preload is excluded from the representative endpoint |
| SPAD read / write bytes | 2,905,344 / 119,808 | As reported by archived run |
| DMA payload bytes | 112,896 | Workload load accounting; host fixture bytes and poison setup are separately reported |
| SPAD high-water | 211,968 B | Queue ring `[221184,253952)`, completion ring `[253952,262144)`, reusable scratch below 16 KiB |

The preceding table is the reused 197-query Round 30 profile. The new Round 31 profile is a different 16-query measurement: 821,466 Product Top command-path cycles, 48 Wo DMA events / 37,632 bytes / 11,670 DMA cycles, and 72,384 Golden words checked in total. The cycle window includes AXI-Lite publication/retirement, Product execution, DMA fences and batch Golden observations; it excludes model-file staging into the behavioral external-memory array. It is not host-to-host latency or silicon throughput.

This evidence proves the QKV → Repack → QK → non-causal Softmax(197) → Probability Pack → AV path for all 197 queries and three heads. It does **not** prove Head Merge, Output Projection, Residual1, LN2, FFN/GELU, Residual2, a complete 197×192 Layer 0 output, official checkpoint image inference, or classification accuracy.

## Round 31 gates

| Gate | Status | Evidence / remaining condition |
|---|---|---|
| Round 30 continuous Attention baseline | PASS — historical evidence reused | Same Top session, 197 queries, 3 heads, 361,920 Golden words; no Round 31 rerun |
| Round 31 start from current DeiT branch | PASS | Branch starts at `1ec352ea261892eb882824bf476f3df76e8ae986`; no tracked RTL changes made |
| AV head merge → Output Projection | PARTIAL PASS — one 16-query block | 48 panel-row-group AV requants, streamed official Wo tiles, INT32 head/partial accumulation, and all 768 final INT8 output words pass; 181/197 valid query rows remain |
| Output Projection → Residual1 → LN2 → FFN/GELU → Residual2 | NOT RUN | Must run continuously from Product-generated prior tensors; no Host intermediate refill |
| Complete Layer 0, 197×192 Golden | NOT RUN | No Round 31 VCS compile/run or Layer 0 pass claim |
| External Descriptor Fetch / streaming recovery | PARTIAL | Round 30 proves bounded AXI-Lite ring publication/retirement, wrap and batching; external descriptor fetch and full reset/abort/backpressure recovery remain unqualified |
| Twelve layers / classifier / labeled-image accuracy | NOT RUN | Layer 0 is not closed |

Because no new RTL was changed, no new SPEC/DV/SVA obligation was introduced. The existing Round 30 Repack specification and directed evidence remain the source for the completed Attention path.

## Minimal next implementation boundary

1. Extend the passing query-block schedule to all 13 blocks, including the final 5 valid rows, and prove source/destination lifetimes across reuse.
2. Add Residual1, LN2, FFN up/GELU/down and Residual2 with dependencies and scratch reuse after completion retirement.
3. Run all 197 valid queries in one unreset Product Top session and compare every intermediate plus the full 197×192 final tensor against an independent integer Golden.
4. Continue through the remaining eleven Encoder layers, final LayerNorm and classifier; then evaluate real images with official weights before making any accuracy claim.

The reported 256 KiB high-water leaves 50,176 bytes below capacity, but this is only the Round 30 Attention workload. It does not establish that Layer 0 temporaries fit; measure the complete liveness graph before proposing SPAD expansion.

## Machine-readable evidence

- New 16-query Product Top profile: `benchmark/deit/round31/evidence/attention_output_projection_16q/performance.csv`
- New 16-query Product Top manifest/logs/workload: `benchmark/deit/round31/evidence/attention_output_projection_16q/`
- Reused historical profile: `benchmark/deit/round31/round31_reused_round30_attention.csv`
- Round 31 gate status: `benchmark/deit/round31/round31_gate_status.json`
- Original VCS logs, workload archives, retry disposition and hashes: `benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor/`
- Round 30 architecture report: `docs/benchmark/NMAFORGE_V1_2_ROUND30_DEIT_REPACK.md`
- AV scratch lifetime audit: `benchmark/deit/round31/round31_av_scratch_audit.csv` and `round31_av_scratch_audit.json`

`round31_reused_round30_attention.csv` is a byte-for-byte copy of the Round 30 profile with provenance made explicit in its filename and this report. It is not a new Round 31 measurement.
