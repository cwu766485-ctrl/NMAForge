# Phase 1.1 A1 Real RTL Replay

Product RTL is unchanged at `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`. The Top simulator was compiled from the current checkout with VCS `V-2023.12-SP1_Full64`, `+define+VCS`, `AI_SPAD_WORDS_PER_BANK=8192`, and the existing `ai_accel.f`. The simulator and all run output are outside the repository under `/tmp/nmaforge_phase11_a1_rtl` and `/tmp/nmaforge_phase11_a1_replay3`.

## Layouts

P0 uses the candidate CNN generator's original regions: input `0x00000`, W1 `0x02000`, RAW1 guard `0x03000`, ACT1 `0x10000`, W2 `0x14000`, RAW2 guard `0x15000`, output `0x19000`, descriptors `0x1a000`, completions `0x1a200`. P1 relocates the same word values and poison guards to input `0`, W1 `7488`, RAW1 `9792`, ACT1 `63040`, W2 `76352`, RAW2 `77376`, output `90688`, descriptors `94016`, completions `94144`. All ranges stay within `[0,131072)` and are non-overlapping. Descriptor pointer words 1/2/4 are rewritten to the P1 bases; ABI field meaning is unchanged.

The source workload is `benchmark/research/phase1/cnn/both_fused_row_major/{model_memory,model_golden}.memh.gz`. Its manifest hash is `d6c20d3400cb2c3599ae7df0f4da941a9b27b64441ac8f54bee522a8d2f5371e`; the generator source hash is `0b5f532d67dd8a4883d526fc7eac30aa85d7a227c141de00f46dec0cd016c3a2`, identical to the file at the product RTL SHA. P1 changes addresses only; the Golden values and useful MAC count `570164` are unchanged.

## Results

| Metric | P0 | P1 | Interpretation |
|---|---:|---:|---|
| RTL Golden | PASS | PASS | Independent memory-image Golden, 20,800 words checked |
| Command cycles | 11,376 | 11,376 | No compute/control speedup |
| DMA payload | 10,944 B | 10,944 B | Same live bytes |
| DMA preload window | 3,019 cycles | 2,979 cycles | 40-cycle boundary improvement from 4→3 aligned DMA segments |
| DMA busy | 2,879 | 2,874 | Same payload, different burst grouping |
| SPAD reads | 64,064 B | 64,064 B | No dataflow traffic reduction |
| SPAD writes | 16,640 B | 16,640 B | No writeback change |
| High-water exclusive | 107,040 B | 94,176 B | 12,864 B / 12.02% address-space packing reduction |
| Peak live storage | NOT_MEASURED | NOT_MEASURED | Static allocation is not a temporal occupancy proof |

P0 and P1 both report Matrix MAC 2,704 cycles, request wait 9, response wait 7, writeback 1,040, and the same command profile. P1 therefore demonstrates engineering improvement in address packing and DMA segment consolidation, not reduced SRAM macro area, not a new compute dataflow, and not an architecture-level performance gain.

## Safety

`python3 dv/uvm/tests/check_compact_spad_alloc.py` passed the compact CNM negative allocation checks, including row-8 B lanes `0x13080/84/88/8c`, the original `[0x13000,0x15000)` B region, and the relocated output `[0x16000,0x16040)`. The full compact CNM line-stall regression remains the negative fixture for unauthorized overlap. On the same exact candidate simulator, the existing Top fault/reset smoke passed `parallel abort ordered drain`, all-engine-pair abort drain, protection denial and reset recovery. Those checks use the established fixture rather than injecting a new fault into the packed CNN address map; a packed-layout-specific fault/abort/reset trace remains a follow-up.

## Reproduction

```bash
mkdir -p /tmp/nmaforge_phase11_a1_rtl/csrc
cd dv/subsystem/top_smoke/sim
vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps \
  +define+VCS +define+AI_REPRESENTATIVE_LONG_TASK \
  +define+AI_SPAD_WORDS_PER_BANK=8192 \
  +incdir+../../../block/control/agent +incdir+../../../block/dma/agent \
  +incdir+../fixtures -Mdir=/tmp/nmaforge_phase11_a1_rtl/csrc \
  -top tb_ai_accel_smoke -f ai_accel.f \
  ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
  -o /tmp/nmaforge_phase11_a1_rtl/simv \
  -l /tmp/nmaforge_phase11_a1_rtl/compile.log
cd ../../..
python3.12 tools/benchmark/phase0_1/run_a1_replay.py \
  --simv /tmp/nmaforge_phase11_a1_rtl/simv \
  --out /tmp/nmaforge_phase11_a1_replay3 \
  --source-workload benchmark/research/phase1/cnn/both_fused_row_major \
  --python python3.12
python3.12 tools/benchmark/phase0_1/profile_dataflow.py \
  --replay /tmp/nmaforge_phase11_a1_replay3 \
  --out /tmp/nmaforge_phase11_a1_profile
```
