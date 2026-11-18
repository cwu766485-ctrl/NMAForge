# NMAForge v1.2 Round 27 — DeiT Product Top Integration Status

## Disposition

**Staged Product Top qualification: PASS. Continuous DeiT data path: PARTIAL.**

This branch reproduces the official DeiT-Tiny projection and one three-head
attention query block, each with Product RTL compute and independent integer
Golden checks. They are two distinct Product Top invocations. The second
invocation consumes a host-readback/repacked Q/K/V payload, so this evidence
does not satisfy same-Top, no-host-intermediate deployment. Full 197-query
attention and Encoder Layer 0 were not run.

## Frozen source and model

| Item | Value |
|---|---|
| Round26 parent/source SHA | `19254b4e6a756ca8bf54ced5b287311214e5e99c` |
| Product RTL base before Round26 evidence scripts | `d81a982e262f4fa4f74dde45c92bfb65983fc02d` |
| VCS | `V-2023.12-SP1_Full64` |
| VCS seed | `20261117` |
| Python | `3.12.13` |
| DeiT checkpoint | `facebook/deit-tiny-patch16-224`, non-distilled |
| Checkpoint SHA-256 | `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c` |
| Config SHA-256 | `e8786a68c993c04b8721c4d379e4f9de6a9564fba5987704dbf8696d53b7972d` |
| Preprocessor config SHA-256 | `90d1ae427c27d2b9dcb01f6a62ba96aa67aac2de1697c59cd212055b5035c4a2` |
| SPAD configuration | 4 banks × 16,384 32-bit words = 256 KiB |

The Round27 audit and CSV are generated from immutable archived Round26 run
artifacts. No Product RTL was changed for this status package.

## Gate status

| Gate | Status | Evidence / remaining condition |
|---|---|---|
| Official 197×192 Q/K/V projection | `PRODUCT_TOP_PASS_STAGED` | 468 descriptors; 29,952 packed Golden words match. The input LN packed tensor came from a prior Product Top run. |
| Three-head QK → non-causal Softmax(197) → Probability Pack → AV, Query 0–15 | `PRODUCT_TOP_PASS_STAGED` | 735 descriptors; 25,536 Golden words match; all three heads are executed in RTL. |
| QKV → attention without host tensor readback/repacking | `PARTIAL` | Not implemented. The attention generator consumes the QKV Product readback, reorders head/layout data, and builds a new external DMA payload for a second Top invocation. |
| All 197 query rows | `NOT_RUN` | Only Query rows 0–15 were executed. |
| Head merge, output projection, Residual1, LN2, FFN/GELU, Residual2 | `NOT_RUN` | No complete Encoder Layer 0 Top execution. |
| Twelve layers, final LN, CLS, classification head, labeled-image accuracy | `NOT_RUN` | Blocked on a correct continuous Layer 0 runtime. |
| GPT-2 track | `PARTIAL` | See the independent GPT-2 Round27 report; Product Top integer function passes. The extended candidate is 1.005 pp above the train-only bigram on accuracy, but its CE/PPL remain worse, so quality closure is PARTIAL. |

## Measured Product Top evidence

| Stage | Descriptors | Golden | Useful MACs | Command cycles | Late-DMA session cycles* | DMA payload | SPAD read/write | Data high-water |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Q/K/V projection, 197 valid + 11 padded rows | 468 | 29,952 words | 21,786,624 | 402,889 | 1,083,365 | 112,896 B | 2,905,344 / 119,808 B | 211,968 B |
| Three-head Attention Q0–15 × K0–196 | 735 | 25,536 words | 1,210,368 | 594,012 | 1,291,324 | 82,944 B | 914,304 / 102,144 B | 200,448 B |

`*` The recorded session interval includes the stage's late DMA and command
execution but excludes initial memory-image preload. It is not a combined
model latency because the stages are separate Top sessions and the attention
stage has a host-built repack payload.

QKV useful MAC/command-cycle is 54.076; attention useful MAC/command-cycle is
2.0376. Attention's recorded SFU busy counter is 403,361 cycles and overlaps
other command activity; it must not be added to command cycles. All 197 valid
keys participate in each query's non-causal Softmax normalization; 11 physical
padding keys are excluded by valid-length handling. The current evidence is for
one 16-row query block only.

The independent audit reports:

```text
ROUND27_STAGED_AUDIT_PASS qkv_words=29952 qkv_desc=468 attention_desc=735 attention_dma_bytes=82944 continuous=PARTIAL
```

## Continuous-path blocker and minimum next implementation

The staged generator documents its exact boundary in
`benchmark/deit/round26/generate_deit_attention3_qblock.py`: it validates the
Q/K/V Product readback, extracts head tensors, repacks Q and transposed K plus
Matrix-B V, then uses late DMA in a new Top run. This host-side activation
transform is the current blocker; the two PASS markers cannot be composed into
a continuous PASS.

The RTL/spec currently has Matrix transpose flags, Matrix-A packed output,
SFU Matrix-A packing, and external-to-SPAD indexed gather DMA. The present
gather path copies indexed 32-bit words; it does not provide a general
SPAD-resident byte-lane transpose from Matrix-A `[row,feature]` output into all
per-head Q/K/V consumer layouts. A bounded next design should first prove
whether the Matrix reader's existing transpose mode can consume the producer
layout directly. If not, the minimum candidate is an explicitly specified
on-chip tile layout bridge with byte-lane permutation, source/destination
strides, valid-row masking, completion/fence semantics, and abort/reset
behavior—not a generic tensor reshape engine.

The combined staged sequence is 468 + 735 = 1,203 descriptors. The current
attention run uses a 768-entry descriptor ring whose descriptor area is
`[0x31000,0x3D000)` and completion area `[0x3D000,0x40000)`, exactly filling
256 KiB. QKV separately uses 512 entries. A single continuous session therefore
also needs a validated queue refill/retirement runtime; enlarging only a
testbench array does not establish that support.

## Reproduction and raw evidence

Run the two staged Product Top sessions and audit the committed canonical
evidence with [the reproduction instructions](../../benchmark/deit/round27/REPRODUCE.md)
and [wrapper](../../benchmark/deit/round27/reproduce_round27_staged.sh).

| Artifact | SHA-256 |
|---|---|
| QKV compile log | `731d0e815a2cc02f0b4f026f44da881a494967d5d9e91f7da84ba336c7c38f7c` |
| QKV run log | `e229f1ae24c27acf8edeab49c4d15216f59c71f422a83ef29051e0aea077fbe1` |
| Attention compile log | `9eb0a057050b85ee70998f2f9fdfb65a2ecd9a5eddab33601a34249c7976a2cf` |
| Attention run log | `84a9c026a227cf86eac610f874355419f1ed394c56c07b37856009151ce72b54` |
| QKV Product readback | `6709046be52a7bb6ba409b8dbb9724251bd7f7577aadb49e27ba18d88eb876ba` |
| Attention Golden | `4d75908811bdd47d5db5ead20f1d67d392b08b5f8971039005e28992f60eb3d9` |

The full VCS logs are retained losslessly as `compile.log.gz` and `run.log.gz`
under `benchmark/deit/round27/evidence/`; the SHA-256 values above and in the
audit are computed over the uncompressed original bytes. Manifests, memory
images, payloads, Golden files, and QKV readback are alongside them. Summary
metrics are in `round27/round27_staged_product_top_metrics.csv` and the
machine-readable audit is `round27/round27_staged_product_top_audit.json`.

## Decision

The official checkpoint's QKV projections and one complete three-head
attention query block have staged Product Top evidence. This is useful model
operator evidence, not full DeiT deployment. The next acceptance gate remains
one continuous Top path from LN/QKV through on-chip layout conversion, all
attention query blocks, output projection, residuals, LN2, and FFN, with the
same 256 KiB SPAD and a queue runtime that retires/refills descriptors safely.
