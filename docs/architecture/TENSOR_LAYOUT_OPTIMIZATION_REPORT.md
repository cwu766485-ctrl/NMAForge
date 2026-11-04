# Tensor Layout Optimization — Fused Matrix Requant Writeback

**Status:** First v2 fused-layout implementation is functionally demonstrated;
additional fault/shape coverage and PPA are open.
**Baseline:** NMAForge R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`.
**Implementation:** `9be15655eab23352aa8b8b3c9e07f0eeed55be59`.
**Simulator:** Synopsys VCS `V-2023.12-SP1_Full64`.

## What changed

The old Digits hidden-layer path used three descriptors per batch:

```text
Matrix GEMM + bias + ReLU → INT32 SPAD write
SFU read → INT8 requant → Matrix-A layout pack → SPAD write
Matrix GEMM + bias
```

The v2 candidate adds opcode `0x53`, leaving legacy Matrix opcodes `0x30/0x31`
unchanged. It performs the same Matrix bias/shift/activation and INT32 clamp,
then applies the SFU-compatible signed INT8 requant and emits the packed
`[row_group][N/4 group][row_lane]` Matrix-A layout through the existing 128-bit
SPAD line port. A four-word holding buffer gathers one word per row using the
existing four-result write datapath; it does not add a second MAC array or a
16-wide post-processing datapath. The following GEMM consumes that output
directly.

The descriptor uses `aux0[4:0]` for the second requant shift. High bits must be
zero. Fused destination base and nonzero instance stride must be 16-byte
aligned. The destination stores `M*N` bytes per instance. The descriptor
validator, opcode decoder, Matrix dispatcher, software header, mapper bounds
check, and product-top path all recognize the new opcode.

## Matched Digits result

Both runs use the trained model SHA-256
`e0351dbfa9198937fef05b3adcfc0e5a7f705524eaaede0dcb89892cde9e2c3b`, dataset
seed `20261029`, 360 test samples, VCS behavioral SPAD, and the same 10 ns
simulation clock. The independent Golden logit SHA-256 is
`8a9606b5c31ff4f203731726f89d7caf5f73b59d0cbddf0945a1ac454d855afc` in both
runs.

| Metric | Legacy Matrix + SFU | Fused opcode `0x53` |
|---|---:|---:|
| CMDQ descriptors | 69 | 46 |
| End-to-end command cycles | 110,155 | 34,761 |
| Useful signed INT8 MACs | 1,884,160 | 1,884,160 |
| Effective MAC/cycle | 17.1046 | 54.2033 |
| 16×16 array utilization | 6.68% | 21.17% |
| Digits exact-logit result | 360/360 Golden match | 360/360 Golden match |
| Classification accuracy | 352/360 (97.78%) | 352/360 (97.78%) |
| Hidden activation intermediate traffic | 117,760 B | 23,552 B |

The end-to-end CMDQ interval fell by 68.44% for this workload. The measured
hidden-activation movement fell by 80%: the old path read 4,096 INT32 bytes
and wrote 1,024 packed bytes per batch; the fused path writes the same 1,024
packed bytes per batch directly. The 23,552-byte figure covers only this
hidden-activation path, not total Matrix input, weight, output, completion, or
DMA traffic.

The legacy `rtl_layout_cycles=76,613` counter measures SFU tile-pack busy
cycles. The new `rtl_fused_matrix_cycles=26,444` counter measures all busy
cycles of the fused Matrix command. These stage counters have different
definitions and are not a direct stage-to-stage speedup comparison. The
end-to-end CMDQ cycles use the same interval definition and are comparable.

## Reproduction evidence

The checked-in harnesses generate all model, memory image, Golden, simulator,
and log files beneath `/tmp`:

```bash
make ai_digits_inference \
  AI_DIGITS_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  AI_DIGITS_RUN=/tmp/nmaforge_v2_fused_digits_r250_20261104

make ai_smoke

make core-random-regress \
  CORE_OUT_DIR=/tmp/nmaforge_v2_matrix_core_fused_boundary_20261104 \
  SEEDS='20261021 20261022 20261023'
```

Run IDs and evidence paths:

| Run ID | Evidence | Result |
|---|---|---|
| `V2-R250-DIGITS-LEGACY-20261104` | `/tmp/nmaforge_v2_digits_r250_20261104/run.log`, `golden_comparison.json` | 360/360 logits and 97.78% accuracy PASS; 110,155 cycles |
| `V2-FUSED-DIGITS-20261104` | `/tmp/nmaforge_v2_fused_digits_r250_20261104/run.log`, `golden_comparison.json`, `workload/digits_hidden_expected.memh` | full hidden Matrix-A image and all logits PASS; 34,761 cycles |
| `V2-FUSED-CORE-3SEED-20261104` | `/tmp/nmaforge_v2_matrix_core_fused_boundary_20261104/run_seed_20261021.log` through `run_seed_20261023.log` | existing 18-case/fault/reset regression plus fused saturation boundary PASS for all three seeds |
| `V2-FUSED-TOP-SMOKE-20261104` | `/tmp/nmaforge-architecture-v2/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | product top ends `TEST PASS` |

The fused boundary regression checks exact packed output words for +127, +128,
−128, and −129 inputs, requiring saturation to +127/+127/−128/−128. It also
checks one aligned full-line write, the 16-element completion count, and no
remaining banked responses. Top-level Digits verification checks all 5,888
hidden activation words in SPAD against an independent Python Golden before
checking every final logit.

## Limits and open issues

- This is behavioral RTL simulation, not an ASIC timing or area result. No
  synthesis, PPA, power, or physical SRAM timing claim is made.
- Fused-op-specific Abort/Reset during gather and held-line commit, parity,
  protection faults, and broader `M/N/K` tile tails still need directed
  verification. Existing legacy Matrix fault/reset tests passed, but do not
  close these new-op-specific scenarios.
- The integrated Digits workload covers `M=16`, `N=64`, `K=64`; the focused
  saturation test covers `M=N=K=4`. Other shape and batch-stride combinations
  remain `NOT_RUN` for opcode `0x53`.
- The v1.0 Compute Cluster remains **HOLD**. This optimization does not change
  its sign-off disposition, and the full v2 requirement, coverage, mutation,
  TinyNPU matched-benchmark, model, and PPA work remains open.
