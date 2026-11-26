# NMAForge-V1.2 Round 28 — DeiT Continuous Product Top Path Audit

**Disposition: `PARTIAL`.** Round 27 proves the 197-row Q/K/V projections and three-head 16-query attention block separately on Product Top. It does not prove a continuous QKV-to-attention session: QKV outputs are read back, repacked by the host, DMA-loaded into a second Top invocation, then consumed by Product RTL.

## Frozen evidence

| Item | Projection | Attention block |
|---|---|---|
| Run ID | `round27_deit_qkv197_20261118` | `round27_deit_attention3_qblock_20261118` |
| Tested source SHA | `19254b4e6a756ca8bf54ced5b287311214e5e99c` | same |
| Product RTL tree SHA | `76975cd7bf554ea127f1c9abcb649664e228587c` | same |
| Tool / seed | VCS `V-2023.12-SP1_Full64`, seed `20261117` | same |
| Product Top result | `PRODUCT_TOP_PASS_STAGED_INPUT` | `PRODUCT_TOP_PASS_STAGED_QKV_INPUT` |
| Descriptors / Golden words | 468 / 29,952 | 735 / 25,536 |
| Command cycles | 402,889 | 594,012 |
| DMA payload / setup | 112,896 B / 35,058 cycles | 82,944 B / 25,074 cycles |
| SPAD read / write | 2,905,344 / 119,808 B | 914,304 / 102,144 B |
| Output evidence | Q/K/V Product readback equals independent Golden | QK → non-causal Softmax(197) → packed probability → AV Golden passes |

The projection run consumes an archived Product LayerNorm output; the attention run consumes a Golden-checked QKV readback after host layout conversion. Both tests pass their declared staged boundary. Neither is a same-session model pipeline.

## Physical layout audit

The new deterministic audit at [`audit_qkv_attention_layout.py`](../../benchmark/deit/round28/audit_qkv_attention_layout.py) reuses the raw Product readback, the archived QKV independent Golden, and the exact staged attention DMA payload.

Results in [`qkv_attention_layout_audit.json`](../../benchmark/deit/round28/results/qkv_attention_layout_audit.json):

- Q, K, and V each have 9,984 physical readback words compared; each has zero mismatches against the independent projection Golden.
- All three projections are Matrix-A tiled, physical shape `[208,192]` with 197 valid rows and 11 padded rows.
- For each head, the attention consumer needs Q as dense row-major `[16,64]`, K as K-major `[64,208]`, and V in Matrix-B `[208,16]` panels.
- Reconstructed Q/K/V logical operands match all consumer-layout checks for all three heads; invalid key rows are zeroed.
- Rebuilt staged payload exactly matches all 20,736 archived 32-bit words. Payload SHA-256: `54e8638a82f983bbf874d7f96224deb48c3c1c7b381de5396b49ed5b22aff245`.
- Payload is 82,944 bytes: 3,072 B Q, 39,936 B K, and 39,936 B V. It contains 4,224 zero-padding bytes; 78,720 B are logical non-padding input values.
- Re-run of the audit after removing a duplicate JSON field passed; audit script SHA-256 is `c3523157d9ec53c71aac3b2fe9c8014fe87ae2997bce9aa61c7f572a1bcd65f5`.

This isolates the current blocker: the archived QKV values are correct, and the host repack is deterministic and value-preserving, but the physical Matrix-A producer layout is not directly aliased to the three consumer layouts. The existing staged run's 197-key normalization and padding exclusion remain intact.

## Why existing opcodes do not close the boundary

The current descriptor contract exposes Matrix-A packing for `0x36` (`flags[5]`) and a bounded Matrix-A source mode for normalization (`flags[6]`). The `0x36` Matrix-A packer reads a linear INT32 source and emits Matrix-A layout; it does not transpose a Matrix-A QKV tensor into K-major GEMV storage or Matrix-B AV panels. The existing `0x52` GEMV input contract consumes dense A rows and dense B rows; the QKV physical Matrix-A tensor therefore needs address/lane transformation before those reads. No descriptor-only alias expresses all Q, K, and V layouts simultaneously.

No Product RTL or ABI was changed in Round 28. A bounded candidate, if implemented in a later change, is a parameterized SPAD-to-SPAD tensor repack primitive supporting source Matrix-A coordinates, head/column selection, valid-row count, zero padding, and the three declared target layouts. It must be specified and tested before integration. This audit is not evidence that such a primitive exists.

### Candidate boundary tradeoff (not implemented or timed)

The following is a data-volume/logic-boundary comparison derived from the archived one-query-block workload. It is not a measured cycle or area result.

| Candidate | Data movement for this block | Expected RTL impact | Evidence status |
|---|---|---|---|
| Producer write-layout mode | Write the consumer payload directly: 82,944 B (the current projection writes 119,808 B of Q/K/V Matrix-A tiles before conversion) | Changes Matrix writeback address generation and INT8 lane packing; K transpose and V Matrix-B packing add destination muxing to the critical write path | Functional/cycle/area NOT_RUN; no writer implementation to test |
| SFU/SPAD repack primitive | Read 78,720 B valid source values and write 82,944 B including padding; 19,680 source words + 20,736 destination words | Adds source-layout decode, head/row/column counters, target-layout address generation, byte-lane packing, and bounded descriptor validation; can leave Matrix writeback unchanged | Logical values PASS in offline audit only; Product RTL cycles/area NOT_RUN |

The producer mode avoids a separate repack pass but puts three output formats into the Matrix writeback path. The repack primitive keeps the Matrix path stable and centralizes conversion, at the cost of 40,416 32-bit SPAD word operations for this payload (transaction count only; cycle count depends on bank conflicts/arbitration and is unmeasured). There is no legitimate area estimate yet: neither candidate has been synthesized. I recommend prototyping the repack primitive first because its interface can be bounded to source Matrix-A, head selection, valid rows, and Q/K/V consumer formats; retain the writer alternative only if measured repack latency proves unacceptable.

The attention payload itself is 20,736 SPAD words. Round 27 used 735 descriptors for one 16-query block across three heads. A continuous run also needs streaming publication/retirement because the archived QKV plus attention descriptors exceed a 768-entry queue. A testbench array enlargement would not provide this runtime behavior.

## Reproduction

Run from the Round 28 DeiT worktree with the archived Round 26/27 evidence present:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python benchmark/deit/round28/audit_qkv_attention_layout.py \
  --qkv-dump benchmark/deit/round27/evidence/qkv197/qkv_readback.txt \
  --qkv-golden benchmark/deit/round27/evidence/qkv197/model_golden.memh \
  --attention-payload benchmark/deit/round26/evidence/attention3_qblock/workload/dma_payload.memh \
  --out benchmark/deit/round28/results/qkv_attention_layout_audit.json
```

Environment: Python 3.12.13, NumPy 2.5.4. This command is an offline byte/layout audit, not a VCS simulation. The Product Top compile/run logs and their uncompressed SHA-256 values are recorded in the two Round 27 manifests above.

Round 28 added no RTL or ABI changes, so no new VCS run is claimed. Product RTL source and DV files are unchanged between tested source `19254b4e6a756ca8bf54ced5b287311214e5e99c` and Round 28 branch base `bd1c36382ec251ac4d351d540b498d2b40f9e7c2`; the new evidence is the reproducible offline audit plus this disposition.

## Gate status

| Gate | Status | Evidence / remaining condition |
|---|---|---|
| Round 27 Q/K/V Product Projection | PASS, staged input | 29,952 words match; LayerNorm was an earlier Product Top result |
| Three-head 16-query attention block | PASS, staged QKV input | 25,536 words match; QK/Softmax/pack/AV run in Product Top |
| Physical producer-to-consumer audit | PASS | Q/K/V values and staged physical payload exactly reconstructed |
| Single-session LayerNorm → QKV → on-chip layout conversion → attention | NOT MET | Requires on-chip layout conversion plus a runtime that streams and retires descriptors without reset |
| Full 197-query attention / Encoder Layer 0 | NOT RUN in this branch | Not covered by the 16-query staged block |
| Twelve-layer classification | NOT RUN | Blocked on complete Layer 0/runtime first |

**Track disposition: `STAGED_BLOCKS_PASS / CONTINUOUS_PRODUCT_TOP_PARTIAL`.** This branch records the concrete boundary and evidence; it does not claim full DeiT deployment.
