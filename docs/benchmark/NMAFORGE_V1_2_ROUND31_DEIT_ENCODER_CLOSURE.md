# NMAForge-V1.2 Round 31 — DeiT Encoder Layer 0 Closure

## Disposition

**PARTIAL.** Round 30 provides reusable evidence for continuous Product Top execution through all-query, three-head Attention. Round 31 did not produce a continuous Encoder Layer 0 execution. The first unimplemented integration boundary is the physical handoff from the three per-head AV outputs to a merged 192-channel tensor consumed by Output Projection. There is no Round 31 failing descriptor/address/value because no Layer 0 descriptor graph or run was available to execute.

No Product RTL was modified in this track. The historical Round 30 evidence below is explicitly reused and was not rerun on the Round 31 branch.

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

This evidence proves the QKV → Repack → QK → non-causal Softmax(197) → Probability Pack → AV path for all 197 queries and three heads. It does **not** prove Head Merge, Output Projection, Residual1, LN2, FFN/GELU, Residual2, a complete 197×192 Layer 0 output, official checkpoint image inference, or classification accuracy.

## Round 31 gates

| Gate | Status | Evidence / remaining condition |
|---|---|---|
| Round 30 continuous Attention baseline | PASS — historical evidence reused | Same Top session, 197 queries, 3 heads, 361,920 Golden words; no Round 31 rerun |
| Round 31 start from current DeiT branch | PASS | Branch starts at `1ec352ea261892eb882824bf476f3df76e8ae986`; no tracked RTL changes made |
| AV head merge → Output Projection input | NOT RUN / first missing integration boundary | No producer/consumer descriptor+layout path and no independent Layer 0 graph/G​​olden run in the existing Round 30 flow; not a recorded RTL mismatch |
| Output Projection → Residual1 → LN2 → FFN/GELU → Residual2 | NOT RUN | Must run continuously from Product-generated prior tensors; no Host intermediate refill |
| Complete Layer 0, 197×192 Golden | NOT RUN | No Round 31 VCS compile/run or Layer 0 pass claim |
| External Descriptor Fetch / streaming recovery | PARTIAL | Round 30 proves bounded AXI-Lite ring publication/retirement, wrap and batching; external descriptor fetch and full reset/abort/backpressure recovery remain unqualified |
| Twelve layers / classifier / labeled-image accuracy | NOT RUN | Layer 0 is not closed |

Because no new RTL was changed, no new SPEC/DV/SVA obligation was introduced. The existing Round 30 Repack specification and directed evidence remain the source for the completed Attention path.

## Minimal next implementation boundary

1. Define the three AV output physical layouts and quantized scales in a Layer 0 tensor manifest.
2. Add a bounded, independently golden-checked Head Merge dataflow into the consumer layout required by the existing 192→192 Output Projection. Prefer existing pack/writeback or DMA address-generation facilities; charge any conversion cycles and bytes.
3. Extend the same descriptor/lifetime planner with Output Projection, Residual1, LN2, FFN up/GELU/down and Residual2. Reuse activation storage only after completion retirement and dependency-fence checks.
4. Run the whole graph in one unreset Product Top session, compare every intermediate tensor and the final 197×192 output against an independent integer Golden, and retain the raw VCS logs and allocation high-water.

The reported 256 KiB high-water leaves 50,176 bytes below capacity, but this is only the Round 30 Attention workload. It does not establish that Layer 0 temporaries fit; measure the complete liveness graph before proposing SPAD expansion.

## Machine-readable evidence

- Reused historical profile: `benchmark/deit/round31/round31_reused_round30_attention.csv`
- Round 31 gate status: `benchmark/deit/round31/round31_gate_status.json`
- Original VCS logs, workload archives, retry disposition and hashes: `benchmark/deit/round30/evidence/continuous_attention/full_197_passive_backdoor/`
- Round 30 architecture report: `docs/benchmark/NMAFORGE_V1_2_ROUND30_DEIT_REPACK.md`

`round31_reused_round30_attention.csv` is a byte-for-byte copy of the Round 30 profile with provenance made explicit in its filename and this report. It is not a new Round 31 measurement.
