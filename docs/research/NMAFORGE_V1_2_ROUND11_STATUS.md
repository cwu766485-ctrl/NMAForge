# NMAForge v1.2 Round 11 — QK Layout Repair Status

## Scope and Base

Research branch `research/nmaforge-v1.2-round11`, based on Round 10 commit
`346a47ef75e3c0f9ac5239520106a3577381f1b8`. Work is isolated in
`/tmp/nmaforge-v1.2-round11`. No product RTL, ABI, product branch, or PR was
modified. No queue-depth increase or reset-based workaround was used.

## Gate Summary

| Gate | Status | Evidence |
|---|---|---|
| G0 QK layout root cause/repair | PASS for Matrix-A tile layout; append mode remains incompatible | Independent layout checker; Product Top 229-descriptor run; all 31/31 checkpoints pass, including four complete QK score tensors |
| G1 Token 0/1/4/5 and 0–5 persistent decode | NOT RUN | No token-at-a-time planner or per-token Product Top retirement loop in this change |
| G2 CMDQ/CPLQ streaming and wrap | NOT RUN for H64 workload | Existing generic smoke wrap does not exercise H64 batches; 321-descriptor static batch was not submitted |
| G3 continuous decode vs full recompute plus fault recovery | NOT RUN | No uninterrupted token-by-token execution to compare |

Round 11 does **not** close Persistent H64 Decode.

Compatibility regression `make ai_smoke` passes with `TEST PASS` (VCS
`LOOP-REROLL-ENABLED` fixture warning remains); log SHA-256 is
`7cf35bf89d13412b89fb0e937ffe75c7bf6fce059984a9579ba8d36871bd9cf5`.

## G0 Root Cause

For logical `K[token,feature]`, the `KV_WRITE 0x43 flags=1` append equation
places each byte at:

```text
word = (feature_group * token_groups + token_group) * 4 + feature_lane
byte = token_lane
```

The Matrix-B packer for QK's required `B[feature,token] = K[token,feature]`
places it at:

```text
word = (token_group * feature_groups + feature_group) * 4 + token_lane
byte = feature_lane
```

Thus append produces the physical Matrix-B representation of `K[token,feature]`
rather than `K^T[feature,token]`. The operation transposes both the 4x4 tile
grid and the byte lane within each tile. Matrix Core `transpose_b` only swaps
the selected word and byte lane inside the current 4x4 load group; it does not
permute the 4x4 group grid. It cannot implement the full 16x16 transpose.

The checker uses the Product append address equation and the shared mapper's
`_pack_matrix_b_physical()` implementation. For a seeded 16x16 INT8 K tile it
reports 64/64 physical word mismatches for append vs QK, 238/256 logical B
element mismatches after interpreting append as a Matrix-B tile, and 48/64
word mismatches after the local `transpose_b` mapping. The existing Matrix-A
tile ordering is byte-for-byte equal to QK's required Matrix-B layout: 0/64
word mismatches.

This is an operand-layout incompatibility, not a KV append/read correctness
failure. No host-produced K values are inserted into the DUT. The legal
no-RTL workaround is to store K in Matrix-A order using existing `KV_WRITE`
`flags=0` word writes; V may keep using append. This requires four K word
writes per token per head (16 K descriptors/token across four heads), versus
one append descriptor per token/head. The previously validated full-tile K
write remains the compact batch reference but cannot update the cache
incrementally.

## G0 Product Top Evidence

The append failure was reproduced unchanged on the Round 11 base:

```text
descriptor=47 address=0x4100 expected=0xfffffdc7 actual=0x00000187
```

The corrected Matrix-A tile Product Top workload passes all 31 intermediate
Golden checkpoints and final memory comparison. Its four QK score checkpoints
are descriptors 42, 62, 82, and 102; each is checked across all 256 words.
The run is still a six-token cache-backed batch, not sequential Decode.

Tool: Synopsys VCS `V-2023.12-SP1_Full64`, 10 ns clock, behavioral 128 KiB
four-bank SPAD, seed `20261115`.

| Measurement | Result |
|---|---:|
| Descriptors / Golden checkpoints | 229 / 31 PASS |
| Command / end-to-end cycles | 266,858 / 338,050 (DMA preload included) |
| DMA | 45 transfers / 49,152 bytes |
| KV write / read bytes | 1,408 / 2,048 |
| SPAD read / write bytes | 346,496 / 222,208 |
| Useful / executed / padding MAC | 297,600 / 819,200 / 521,600 |
| Peak live allocation / highest address | 68,608 / 130,640 bytes |
| Per-token cycles | NOT MEASURED |

Reproduce the failing append experiment:

```sh
cd /tmp/nmaforge-v1.2-round11/dv/subsystem/top_smoke/sim
make ai_h64_kv_roundtrip_top AI_H64_KV_RUN=/tmp/nmaforge_round11_append_qk_20261115 AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_KV_SEED=20261115 'AI_H64_KV_GENERATOR_FLAGS=--kv-attention --tokens 1,7,42,3,5,8 --kv-k-write-mode token-append'
```

Reproduce the passing compatible layout:

```sh
cd /tmp/nmaforge-v1.2-round11/dv/subsystem/top_smoke/sim
make ai_h64_kv_roundtrip_top AI_H64_KV_RUN=/tmp/nmaforge_round11_tile_qk_20261115 AI_H64_KV_PYTHON=/tmp/nmaforge_round10_venv/bin/python AI_H64_KV_SEED=20261115 'AI_H64_KV_GENERATOR_FLAGS=--kv-attention --tokens 1,7,42,3,5,8 --kv-k-write-mode matrix-a-tile'
cd /tmp/nmaforge-v1.2-round11
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/check_h64_kv_qk_layout.py --seed 20261115 --size 16 --json benchmark/gpt2_compat/results/round11_kv_qk_layout.json
/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/compare_h64_kv_recompute.py --seed 20261115 --tokens 1,7,42,3,5,8 --kv-k-write-mode matrix-a-tile
```

The independent Full-Recompute comparison passes all 16 named tensor
boundaries for the six-token batch, including all active causal QK score cells,
probability/AV rows, Residual1, LN2, FFN down accumulation, and Residual2.
This comparison remains a batch-level Golden result, not sequential RTL
decode evidence.

## Next Blocker

The next deterministic implementation is a token-scoped descriptor planner:
project one token, write K into Matrix-A cache positions with `flags=0` word
writes, append V, read historical K/V, then execute that token's QK, causal
softmax, AV, output projection and FFN. Each token's descriptor group must be
published only after the previous group retires and CPLQ entries are consumed.
That planner and producer/consumer ring logic are not implemented here. Static
`matrix-a-word` remains 321 descriptors for the six-token batch and was not
run; no queue extension is claimed. Queue-full, wrap, H64 abort/reset recovery,
and cache-dependency sensitivity tests remain open.

## Artifact Hashes

| Artifact | SHA-256 |
|---|---|
| Append failure log | `bf07e4c823c8b53a0e6603b192c18328d666911c7b8c64516f5553b20c4fc7b2` |
| Append compile log | `a598bbd230ffc6f04e8f64339cdb1d1f9503a9715562b9876efe6687a8eb37c2` |
| Matrix-A tile PASS log | `82eff13524395a7ddbd9306b487c6ad4d70ccce3eaa786eb8d378b2c694aa6b4` |
| Matrix-A tile compile log | `1d489e51cadef33f97e68c1e48ea74721fd28a54e5dc721ed04b2a0670e9a337` |
| Matrix-A tile manifest | `afbf72085be15ca11c3be8084a558b512e6246c9d9d46767220cae4767e528c2` |
| Matrix-A tile checkpoint Golden | `e0d819ebbcd3ab6de587a61087380f39766af15834905c1f262f9a0c27604aed` |
| Layout checker result | `79c4a2c369f3954bcf3a8853c4439e6d92eb8823e5d119d9e08879ef9dd0f043` |
