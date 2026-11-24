# NMAForge-V1.2 Round 24 — DeiT Attention Closure

## Disposition

**Full 197-row LayerNorm: PASS. Full 197-token Q/K/V projection: PASS. First complete AV-backed query block: FAIL. Encoder Layer 0: NOT_RUN.** The failure is reproducible at the first checked AV output word. The current evidence narrows the failure boundary to packed probability / AV operand availability, but does not yet prove whether the defect is in packing, descriptor addressing, or the matrix reader. No product RTL was changed.

## Frozen source and environment

- Branch: `research/nmaforge-v1.2-round24-deit`
- Base/source RTL SHA: `d81a982e262f4fa4f74dde45c92bfb65983fc02d`
- VCS: `V-2023.12-SP1_Full64`
- Seed: `20261117`
- SPAD: four banks, 16,384 words/bank, 256 KiB total
- Queue geometry: 512 entries; CMDQ `[221184,253952)`, CPLQ `[253952,262144)`; queue allocation 40,960 B
- Product RTL and numeric contract: unchanged. The only testbench edit adds optional read-only AV tracing gated by `+AI_DEIT_AV_TRACE`; it neither forces nor modifies DUT state.
- Official checkpoint file hash recorded by the generators: `pytorch_model.bin` SHA-256 `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c`; `config.json` SHA-256 `e8786a68c993c04b8721c4d379e4f9de6a9564fba5987704dbf8696d53b7972d`; `preprocessor_config.json` SHA-256 `90d1ae427c27d2b9dcb01f6a62ba96aa67aac2de1697c59cd212055b5035c4a2`.

The full checkpoint-derived SPAD memory and DMA payload images are intentionally not included in Git. Their SHA-256 values remain recorded in the workload manifests/evidence inventory; regenerate them from the pinned checkpoint and scripts before replay. Golden outputs, descriptors, readbacks, manifests and logs are retained. VCS logs are stored as lossless `.log.gz` archives (decompress to recover original bytes); the Round 23 compile log is explicitly prior-round provenance, while the AV trace path has its own Round 24 compile log.

## Gate results

| Gate | Result | Evidence |
|---|---|---|
| Full 197-row H192 LayerNorm and packed output | **PASS** | 197 valid rows; 19,200 checked Golden words; 246 descriptors; run log hash `9024a34d05d32697178c818a52b8615c778977af59acd61bf03952af805b863d` |
| Full K/V projection and connection to first 16 Q rows | **PASS** | 197 valid tokens × 192 channels, 11 zero-padded physical rows; 20,736 Golden words; 324 descriptors; run log hash `d1f43a4ec5e25b4bd87bccca3d9143a4533999bbc064671cc13100d0da1770c0` |
| Query-block prefix QK/Softmax/pack (head 0 fixture) | **PASS, partial scope** | 16 queries × 197 valid keys; 197-key Softmax opcode `0x32`; prefix-pack run completed 241 descriptors, log hash `71c798305d47fc8102d8d1d175182abe277c02a6c29afc032f289bd4ca83f03c` |
| AV and complete three-head attention block | **FAIL / NOT_CLOSED** | AV first mismatch at output `0x00028000`, expected `0x0000024c`, actual `0x000002ce`; trace run archive `attention_head0/fail_trace_run6.log.gz`, raw log hash `fdcb1ba27f8bca02cfb05279203cd03e1b89720ff6e893af08c27cc63d01b38f` |
| Full 197-query attention / Encoder Layer 0 | **NOT_RUN** | Blocked by AV failure; no Output Projection, Residual, LN2 or FFN closure claimed |
| 12-layer model / classifier | **NOT_RUN** | Requires a complete Layer 0 first |

### LayerNorm and K/V numbers

The LayerNorm workload used 246 descriptors and 157 late-DMA events (122,880 payload bytes). It checked 19,200 Golden words. Logged command cycles were 973,932; the staged-session end-to-end counter was 1,457,632 and excludes the prior embedding execution. SPAD read/write counters were 1,139,712 / 228,096 B. Matrix MAC counter was 6,912 cycles and SFU busy was 888,649 cycles. The workload manifest reports a 219,904 B data high-water mark and a disjoint static allocation/lifetime check.

The Q/K/V stage used 324 descriptors and 144 late-DMA events (112,896 payload bytes), checking 20,736 Golden words. Command cycles were 289,705; staged-session end-to-end was 788,741. SPAD read/write counters were 2,011,392 / 82,944 B; matrix MAC counter was 62,208 cycles. The stage consumes a previously Product-Top-verified LayerNorm packing via a DMA-loaded staged session; it is not a single continuous embedding→LN→QKV Top invocation. The manifest records 197 valid rows, 11 explicitly zero-padded rows, and 179,200 B data high-water.

The 16-query attention workload contains 245 descriptors, 16 full-length 197-key Softmax operations, 11 physical padding keys explicitly zero-cleared before use, and 605,184 useful MACs for the selected head-0 fixture. Prefix QK/Softmax/pack completed with 170,019 command cycles and a 428,450 staged-session counter; it is not AV or three-head closure. The observed Softmax command cycles ranged from 7,724 to 7,844 per row in the captured profile, so SFU is already a large cost even before AV succeeds.

## AV failure localization

The failing run is archived as `attention_head0/fail_trace_run6.log.gz`; its compile is `attention_head0/compile.log.gz`. The first observed failure is at Golden word index 7488, address `0x00028000`. The read-only trace shows the matrix AV reader selecting the intended base regions (`A=0x0001c000`, `B=0x00024000`), but sampled bank words at requested addresses are frequently the poison pattern `0xa55aa55a`; the first probability word has only a narrow non-poison lane (`0x00000109`) while other lanes remain poison. This establishes that the expected packed probabilities / V operands are not both present in the physical words consumed by AV. It does **not** prove whether the producer pack, bank/lane mapping, address/stride descriptor, or read-response interpretation is the root cause. Do not change Matrix RTL based on this trace alone.

The separate prefix-pack run proves its 241-descriptor QK/Softmax/pack prefix completes and provides `prefix_pack_readback.txt`; it does not prove AV. A repeated AV run also failed at the same first output word. Shell completion status alone is not accepted as PASS where the log contains a simulator `Fatal`.

## Memory and numeric contract

The full LN workload has 197 valid token rows and 11 zero rows for 208-row physical packing; it does not issue LayerNorm on padding. The QKV workload reuses the verified LayerNorm output in Matrix-A layout. The first-query workload uses three 64-channel heads, 16 queries and 197 valid keys, padded physically to 208. Softmax runs on length 197; the 11 physical padding keys are excluded/zeroed rather than included in the denominator. Recorded QK shift is 5. INT8 projection uses symmetric round-to-even weight quantization, INT32 accumulation/bias and signed saturation as encoded by the workload manifest. All 256 KiB allocations reserve the 40 KiB queue area and keep the data high-water below descriptor base.

## Reproduction

Commands below assume the existing VCS environment and previously built Round 23 `simv`; the archived compile provenance is identified above. Workload generators are in `benchmark/deit/round24/` and can recreate descriptor/golden packages from the pinned local checkpoint.

```bash
# Full LayerNorm run (exact invocation retained at the top of its run log)
/tmp/round23_deit/simv +ntb_random_seed=20261117 +AI_RANDOM_CASES=0 \
  +AI_SEED=20261117 +ACLK_PERIOD_NS=10.0 +AI_REPRESENTATIVE_MODEL \
  +AI_REPRESENTATIVE_LATE_DMA +AI_DEIT_R21_LN_DEBUG \
  +AI_REPRESENTATIVE_DMA_PAYLOAD=/tmp/round24_deit_ln_fulltile/workload/dma_payload.memh \
  +AI_REPRESENTATIVE_DMA_PLAN=/tmp/round24_deit_ln_fulltile/workload/late_dma_plan.memh \
  +AI_REPRESENTATIVE_MEMORY=/tmp/round24_deit_ln_fulltile/workload/model_memory.memh \
  +AI_REPRESENTATIVE_GOLDEN=/tmp/round24_deit_ln_fulltile/workload/model_golden.memh \
  +AI_REPRESENTATIVE_DESC_BASE=221184 +AI_REPRESENTATIVE_CPL_BASE=253952 \
  +AI_REPRESENTATIVE_DESC_COUNT=246 +AI_REPRESENTATIVE_QUEUE_SIZE=512 \
  +AI_REPRESENTATIVE_USEFUL_MACS=1769472 \
  +AI_REPRESENTATIVE_DUMP_FILE=/tmp/round24_deit_ln_fulltile/rtl_ln_dump.txt \
  +AI_REPRESENTATIVE_DUMP_A_BASE=32768 +AI_REPRESENTATIVE_DUMP_A_WORDS=9984 \
  -l /tmp/round24_deit_ln_fulltile/run.log

# Full K/V projection command is preserved verbatim in evidence/qkv_full_kv/run.log.
# AV trace compile/run commands are preserved verbatim in evidence/attention_head0/compile.log.gz
# and evidence/attention_head0/fail_trace_run6.log.gz (lossless gzip archives).
```

Evidence inventory: `benchmark/deit/round24/evidence/evidence_manifest.json`. Original log hashes and compressed archive hashes, along with Golden/readback files, are indexed there. The full source image, DMA payload, official checkpoint and simulator build products are not committed.

## Next diagnostic boundary

Before extending this path, compare the exact packed INT8 probability bytes and the full V matrix at their producer write addresses against the corresponding AV descriptor's physical bank/lane read order. Then decode one nonzero, nonsymmetric 4×4 AV tile through the same Product Top descriptors. Keep the three-head/full Encoder status **open** until AV's complete output matches the independent integer Golden.
