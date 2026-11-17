# NMAForge-V1.2 Round 23 — DeiT Encoder Unblock

## Disposition

**Padding-descriptor fix: PASS. Full valid-row LayerNorm and packed Golden: PASS. QKV Projection for Query rows 0–15: PASS. Three-head QK→Softmax→AV block: NOT_RUN. Encoder Layer 0: NOT_RUN.**

The Round 22 first failure was Descriptor 209, deit_ln_token_197, ERR_DESC. The descriptor validator correctly accepts only real token indices 0–196. The workload generator incorrectly emitted a LayerNorm descriptor for padding row 197. The validator was not changed.

The fix runs LayerNorm only on 197 valid token rows. The packed matrix output contains 200 physical rows; rows 197–199 are zero-filled via the actual fenced DMA path immediately before the final pack descriptor. This matters because the LN scratch tile is reused and its earlier zero initialization is overwritten.

## Product Top evidence

- Research branch: research/nmaforge-v1.2-round23-deit
- Baseline HEAD before Round 23: e64ead0b37c8774e3d73a55a650e770d70839e99
- Product RTL changed: no
- Generator: benchmark/deit/round22/generate_deit_ln197_qkv_block.py
- Generator SHA-256: 4af10c13833271e7b6e33bd43005269132af350cd868dbe642044bb0437a3efb
- Checkpoint: facebook/deit-tiny-patch16-224, non-distilled; hashes in evidence manifest.
- Seed: 20261117.
- VCS: V-2023.12-SP1_Full64; compile and run exit status 0; 32 RTL modules elaborated. KDB summary reported 0 errors / 0 warnings. VCS also printed its non-error LOOP-REROLL-ENABLED optimization notice.

The prior Full Patch Embedding Product Top run verified 9,984 embedding words against the official-checkpoint integer Golden. Its actual Product Top readback was used to seed this workload. Embedding and this Round 23 run are separate Top simulations; the report does not describe them as one continuous Top session.

The Round 23 workload contains 246 descriptors:
- 197 LayerNorm descriptors for valid rows 0–196 only.
- 13 Matrix-A pack descriptors, with the last tile M=8 and physical rows 192–199.
- 36 real Q/K/V GEMM tiles for query rows 0–15 across all 192 output channels.

The final tile's three padded rows are explicitly zeroed using three 192-word late DMA events (2,304 bytes) before descriptor 209. The full late-DMA plan has 149 fenced events and 116,736 bytes.

Results from the actual Product Top run:

| Measurement | Result |
|---|---:|
| Golden words checked | 18,816 |
| Golden mismatches | 0 |
| Valid LayerNorm rows | 197 |
| Invalid padding LayerNorm descriptors | 0 |
| Q/K/V GEMM tiles | 36 |
| Query rows projected | 16 |
| Useful MACs | 1,769,472 |
| Command cycles | 967,036 |
| Command session + late-DMA activity + output readback cycles (initial Top image preload excluded) | 1,443,824 |
| Late DMA bytes / fenced events | 116,736 / 149 |
| SPAD reads / writes | 1,133,568 B / 226,560 B |
| Matrix MAC cycles | 6,912 |
| SFU busy cycles | 883,657 |
| DMA active overlap cycles | 30,985 |
| Data allocation high-water | 219,904 B of 262,144 B |

The memory manifest reports disjoint allocation intervals, 40,960 bytes for CMDQ/CPLQ, and a 219,904-byte data high-water mark. The 1,443,824-cycle session metric excludes the initial SPAD memory-image preload (dma_preload_included=0) and includes command execution, the late-DMA session, and output readback. The run also reports 107,328 bytes of test-only Poison setup; this is not production model traffic. The embedding itself was produced/read back in a separate earlier Product Top session, so this is not a full image-to-QKV end-to-end latency. The aggregate useful-MACs/command-cycle ratio is 1.8298. It is not a standalone array utilization figure.

## Exact reproduction

Workload generation, using the actual Product Top embedding readback:

    /tmp/nmaforge_deit_round17_venv/bin/python benchmark/deit/round22/generate_deit_ln197_qkv_block.py --model-dir /tmp/nmaforge_deit_round17 --base-manifest /tmp/round23_deit/base/workload/manifest.json --base-golden /tmp/round23_deit/base/workload/model_golden.memh --embedding-dump /tmp/round23_deit/base/embedding_readback.log --out-dir /tmp/round23_deit/workload_final

VCS compilation command is in evidence/compile_command.txt. VCS run command is in evidence/run_command.txt. Compressed original compile and run logs, input/output memory images, Golden, DMA payload and late-DMA plan are in benchmark/deit/round23/evidence/.

Key SHA-256 values:
- manifest: 57fec6f6680c8d63e0ff6353a09a79dcfd130cace26e655c084b0e27e91962d8
- model memory: 54a1db04020b01d620ebc363e41aff62bb057d8bbaa71fc5d8b9ae549e80bdf5
- Golden memory: 0f25139b6eb9728ad7a31a00a9711a5e9582550680cbc1a76626a1e5ff8993e6
- DMA payload: 0eb809cb8a2166e98a11b5a08403a14af964490adbc6b707e70a84530166572d
- late-DMA plan: 83c0c1d009b2c4e2b82b8a0288794b1b2fb6047c22f3b773c4433fccecaefbc3

## Gate boundary and remaining blocker

**Completed:** legal valid-row LayerNorm descriptor generation, all 197 LayerNorm rows, 197×192 packed output with zero padding, and real Q/K/V projection for the first 16 query rows.

**Not completed:** the Q/K/V projection of all 197 keys/values needed for attention, a connected QK→full-197-key non-causal Softmax→AV query block, the remaining 181 Q rows, Output Projection, Residual, LN2, FFN 192→768→192, GELU, and Encoder Layer 0.

Round 18 has a separate Product Top test for a 197-element Softmax row, but that isolated test does not prove that real QK scores from this workload feed one 197-key normalization and then AV. It is therefore not counted as Attention PASS.

No padding validator or Product RTL was weakened. The next required integration step is to provision and produce all K/V rows under a feasible descriptor/SPAD lifetime schedule, then connect one 16-query block to the full-key Softmax and AV path with independent intermediate Golden checks.
