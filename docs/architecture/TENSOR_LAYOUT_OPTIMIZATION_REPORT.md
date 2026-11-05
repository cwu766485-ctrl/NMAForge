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

## Bounded fused-tile forwarding experiment

**Implementation SHA:** `3124ba4b3be31402641da2352510f4db3a9954c6`.
**Run ID:** `V2-TILE-FORWARD-ABL-20261105`.

The new v2-only opt-in uses opcode `0x53 aux0[5]` to capture a complete 16×16
requantized tile and `aux0[6]` to consume the exact-tag prior tile as Matrix A.
It adds two 16-line × 128-bit local banks (512 B / 4,096 bits plus control).
The producer and consumer still commit their output lines to SPAD; this path
only avoids reading the prior tile back from SPAD. A tag mismatch falls back
to the normal read path. The descriptor validator rejects unsupported
capture/consume shapes and preserves the legacy `0x30/0x31` contract.

The paired VCS run used seed `20261105`, VCS `V-2023.12-SP1_Full64`, and the
registered four-bank behavioral responder in the Matrix core testbench. Both
variants ran the same producer/consumer descriptors and independent packed
INT8 Golden. The consumer used ready bank requests and the testbench's
zero-latency response override; this is a controlled RTL ablation, not a
general memory-service or ASIC result.

| Measure | Forwarding disabled | Forwarding enabled |
|---|---:|---:|
| Producer cycles | 147 | 147 |
| Consumer cycles | 141 | 118 |
| Producer + consumer cycles | 288 | 265 |
| Consumer banked reads | 32 (512 B) | 16 (256 B) |
| Consumer output line writes | 16 (256 B) | 16 (256 B) |
| Golden | bit-exact | bit-exact |

For this one M=N=16, K=4 chain, consumer latency fell 16.31% and the two-command
interval fell 7.99%. The consumer saved 16 banked line reads, or 256 B; output
write traffic did not change. The enabled test also passed producer
line-ready back-pressure and last-line commit, exact-tag miss fallback with
Golden and all 32 reads, ping-pong bank flip, reset invalidation, and Abort
invalidation with no output line commit.

Evidence paths:

- `/tmp/nmaforge_tile_forward_ablation_20261105_final/enable_0/run.log`
- `/tmp/nmaforge_tile_forward_ablation_20261105_final/enable_1/run.log`
- `/tmp/nmaforge_tile_forward_core_regress_final_20261105/run_seed_20261105.log` through `run_seed_20261107.log`
- `/tmp/nmaforge_v2_descriptor_validator_final_20261105/run.log`
- `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`

The core regression passed all 18 legacy randomized cases and 35 fault cases
on each of three seeds. Top Smoke passed; its pre-existing
`LOOP-REROLL-ENABLED` VCS warning remains. Descriptor validation reports 29
legal opcodes, 29 invalid-rule checks, 42/42 accepted boundaries, 26/26
rejected boundaries, and 3/3 tile-forward descriptor cases. The mapper unit
test passed 3 cases under Python 3.12.

### Real-top CMDQ differential test added — 2026-11-05

Test commit `826647976284803227b645abc60ae6f514714ada` adds a Top Smoke
producer/consumer pair through the actual descriptor validator, CMDQ,
dispatcher, Matrix controller, and SPAD. It first runs the pair with ordinary
SPAD readback, then captures the producer tile and consumes the exact tag while
capturing the consumer into the opposite local bank. The checker compares all
64 packed output words per consumer, both producers, all four completions, and
the accepted A-source request count. Its expected result is 16 A-tile reads in
the SPAD baseline and zero with forwarding, with legacy SPAD writeback retained.

The exact command was
`timeout -k 3s 45s make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105`.
The Python mapper precheck passed, but VCS `V-2023.12-SP1_Full64` failed before
SV compilation with `Cannot connect to the license server` / `Failed to obtain
license`. The result is **BLOCKED_ENV / NOT_RUN**: no simulator image, CMDQ
run, output comparison, or forwarding-read measurement exists for this test.
The previous core ablation does not substitute for this real-top test. Its
fresh status is also included in the [execution frontier](../exec-plans/active/execution-frontier.md).

## Limits and open issues

- This is behavioral RTL simulation, not an ASIC timing or area result. No
  synthesis, PPA, power, or physical SRAM timing claim is made.
- Tile forwarding has PASS evidence only at the Matrix core and
  descriptor-validator boundaries. A top-level CMDQ differential test is now
  checked in but remains **NOT_RUN** as documented above. Multi-seed
  feature-specific regression, new-feature parity/protection, and held-line
  Abort cases remain open.
- The forwarding subset is one 16×16 capture and one M=16/K=4 consume; broader
  `M/N/K` tails, repeated consumers, and cross-engine coherence are unsupported.
  Software must not overwrite the tagged source tile between producer and
  opted-in consumer.
- The 512 B local tile banks have not been synthesized. Register/BRAM/SRAM
  mapping, area, Fmax, and power remain `NOT_RUN`.
- The integrated Digits workload covers `M=16`, `N=64`, `K=64`; the focused
  saturation test covers `M=N=K=4`. Other shape and batch-stride combinations
  remain `NOT_RUN` for opcode `0x53`.
- The v1.0 Compute Cluster remains **HOLD**. This optimization does not change
  its sign-off disposition, and the full v2 requirement, coverage, mutation,
  TinyNPU matched-benchmark, model, and PPA work remains open.
