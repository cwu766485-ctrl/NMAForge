# NMAForge v2 Round 22 — Performance Closure

**Disposition: PARTIAL.** The fixed GEMM/GEMV and H16 policy runs passed their Golden checks, and a trained-CNN Top DMA preload was measured for one held-out sample. Cross-project results still mix a measured NMAForge controller/SPAD endpoint with TinyNPU direct-array RTL plus modeled memory, and the CNN run does not time host preprocessing or final output readback. No system-level TinyNPU speedup or complete CNN end-to-end latency is claimed.

## Frozen design and run context

| Item | Value |
|---|---|
| Base source SHA | `098f48764fb31351eb415193787a175ef44bf77d` |
| Product RTL tree | `fae8778d62c06c324bf5be0b5cbfea6843141e08` |
| Round 22 test/benchmark source snapshot | `81755ccd966e8828fc13c6d7be85f25514423ffe8b3e77908b769d84ac2af8f3` (hash and per-file hashes in run manifest) |
| RTL change in Round 22 | None; RTL tree matches the Round 20 tested RTL at `7e38a224bfa9558b8b9145c0a9dd81e2786f202a` |
| ABI/profile | ABI-v7.4; 16×16 / 256 INT8 MAC; 128 KiB four-bank behavioral SPAD for research-model targets |
| TinyNPU SHA | `8216c22b762011aa20c05fc2768423fd12dda59d` |
| VCS / Verilator | VCS `V-2023.12-SP1_Full64`; Verilator `5.052 2026-09-05 rev v5.052` |
| Python / NumPy / ONNX / GCC | `3.12.13` / `2.4.6` / `1.17.0` / `8.5.0` |
| Main comparison seed | `20261120`; H16 decode seed `20261116`; CNN model-training seed `20261119`, Top simulation seed `20261120`, fixed held-out rank `0` (sample index `42`) |

The TinyNPU comparison rebuilt from the pinned source and its engine regression passed 6/6. VCS top smoke (`make ai_smoke`, seed 12345, four random cases) and seeded regression (`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`) passed. The compile emitted the existing loop-reroll informational warning; no compile or simulation error was observed. The first smoke log SHA-256 is `fafa1175b91a238ac7fa342de6a1d25af2c0e65eb156369b2a4062fbadc9ada0`; the shared log path was later overwritten by the seeded run, whose current log hash is recorded in `run_manifest.json`.

## 1. GEMM/GEMV paired evidence

Both sides used signed INT8 operands and INT32 accumulation with the same generated operand patterns and independent Golden. NMAForge cycles are measured Matrix controller + behavioral SPAD cycles through output commit. TinyNPU exposes a direct systolic-array endpoint without the corresponding scratchpad/controller interface. Its “common-memory” number is therefore a serialized model: 16 bytes/cycle, one-cycle read response, modeled operand reads/output writes, plus the Tiny direct-array cycles. It is useful for screening, but is not a same-RTL system endpoint. No cross-project speedup is asserted.

### GEMM

| Shape M×N×K | Useful MACs | NMA cycles (MAC-active) | NMA bank / line stalls | NMA array util. | Tiny direct cycles (PE util.) | Tiny modeled cycles | NMA / modeled ratio* | Golden |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| 16×16×16 | 4,096 | 172 (16) | 9 / 22 | 9.30% | 52 (30.77%) | 151 | 1.139× | PASS both |
| 16×16×32 | 8,192 | 268 (32) | 33 / 25 | 11.94% | 100 (32.00%) | 231 | 1.160× | PASS both |
| 32×32×64 | 65,536 | 1,411 (256) | 165 / 93 | 18.14% | 790 (32.41%) | 1,305 | 1.081× | PASS both |

NMAForge achieved respectively 23.81, 30.57, and 46.45 useful MAC/cycle at its measured controller/SPAD endpoint. The comparable model ratios show NMAForge using 8.1–16.0% more cycles than the mixed Tiny endpoint. The largest case also reads 6,144 B on NMAForge versus 4,096 B in the Tiny memory-service model, indicating additional operand traffic in this path. Tiny has no measured bank/line stall counters at this endpoint. These differences are research clues, not a product-level ranking.

### GEMV

| Shape M×N×K | Useful MACs | NMAForge `0x52` cycles | NMA read/write B | Tiny direct-array RTL cycles | Tiny modeled common-memory cycles | NMA / modeled ratio* | NMA GEMV profile observation |
|---|---:|---:|---:|---:|---:|---:|---|
| 1×13×17 | 221 | 68 | 304 / 52 | 100 | 126 | 0.540× | Prefetch wait 36 cycles; arbiter 7; counters overlap |
| 8×16×19 | 2,432 | 163 | 560 / 512 | 100 | 170 | 0.959× | 22 bank stalls; 36 arbiter-stall events |
| 16×16×19 | 4,864 | 266 | 816 / 1,024 | 100 | 218 | 1.220× | 30 bank stalls; 46 arbiter-stall events |
| 16×16×65 | 16,640 | 637 | 2,368 / 1,024 | 244 | 459 | 1.388× | Prefetch wait 365 cycles; arbiter 90; counters overlap |

The modeled ratios suggest a favorable small-M result, near parity at M=8, and worse results at M=16, especially for K=65. TinyNPU pads the GEMV data into its 16×16 direct array; it has no tested product GEMV descriptor/SPAD path. Its service cycles above are modeled, not measured memory RTL. The NMA stall/event counters can overlap and must not be summed as exclusive time.

Machine-readable source tables: [`matched_gemm.csv`](../../benchmark/representative/round22/matched_gemm.csv), [`gemv_results.csv`](../../benchmark/tinynpu/gemv_results.csv), and [`gemv_summary.json`](../../benchmark/tinynpu/gemv_summary.json). The complete comparison run summary and its limitations are in [`benchmark_summary.json`](../../benchmark/tinynpu/benchmark_summary.json). A separate NMA GEMM-vs-GEMV same-operand sweep for M=8/16 was not rerun in Round 22; the policy evidence below is an actual H16 M=1 model run, while the M=8/16 rows above compare GEMV implementations across projects. No automatic Mapper rule was introduced.

## 2. Shape policy on H16 incremental Decode

The same fixed H16 synthetic projection model, host-supplied token IDs 4–7, Seed `20261116`, prefill, and KV state were run twice. Only the Q/K/V projection mapping changed: 24 QKV descriptors across the four decode steps changed from opcode `0x30` to `0x52`; the rest of the descriptor chain remained the same. Both runs completed the real Top incremental append/read path. All per-step intermediate words and updated KV contents matched each run’s independent Golden. Cross-policy expected output words and KV hashes also match; address-inclusive memory-image hashes differ because the extra GEMV weight panels shift tensor allocation addresses.

| Token | GEMM cycles | GEMV QKV cycles | Change | GEMM / GEMV SFU cycles | GEMM / GEMV Matrix MAC-active cycles | GEMM / GEMV SPAD read B | GEMM / GEMV SPAD write B |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 4 | 8,735 | 8,693 | −42 (−0.48%) | 6,865 / 6,865 | 176 / 104 | 8,160 / 8,640 | 4,688 / 4,112 |
| 5 | 8,809 | 8,767 | −42 (−0.48%) | 6,939 / 6,939 | 176 / 104 | 8,160 / 8,640 | 4,688 / 4,112 |
| 6 | 8,883 | 8,841 | −42 (−0.47%) | 7,013 / 7,013 | 176 / 104 | 8,160 / 8,640 | 4,688 / 4,112 |
| 7 | 8,964 | 8,922 | −42 (−0.47%) | 7,094 / 7,094 | 176 / 104 | 8,160 / 8,640 | 4,688 / 4,112 |
| **Average** | **8,847.75** | **8,805.75** | **−42 (−0.475%)** | **27,911 / 27,911 total** | **704 / 416 total** | **32,640 / 34,560 total** | **18,752 / 16,448 total** |

Over the four decode steps, 6,976 useful MACs are unchanged. Whole-decode throughput is 0.1971 versus 0.1980 useful MAC/cycle. GEMV lowers Matrix MAC-active cycles by 41%, but the Matrix request/response wait grows, read traffic rises 5.9%, and complete token latency improves by less than 0.5%. SFU busy totals are 27,911 cycles on both runs (78.9% / 79.2% of their respective decode totals). Summing exclusive per-descriptor intervals gives this profile: `0x38` LayerNorm 11,932 cycles; `0x39` Softmax 2,699; `0x36` Requant 6,520; `0x35` GELU 1,592; `0x34` residual/head merge 6,360; `0x43` KV append 1,264; `0x44` KV read 1,312; and Matrix opcodes `0x30` 3,712 cycles for GEMM vs `0x30` 1,952 + `0x52` 1,592 for GEMV. These per-op intervals sum exactly to the respective four-token totals. Thus the single-token shape change does not justify a new Matrix datapath; the existing exact SFU path remains the dominant optimization target. The H16 weights are a synthetic projection fixture, not a trained language model, and the four tokens are supplied by the host.

Each decode step has 50 descriptors. The full 240-row descriptor interval profile and stage-level counters are archived in [`h16_descriptor_cycles.csv`](../../benchmark/representative/round22/h16_descriptor_cycles.csv) and [`h16_decode_comparison.csv`](../../benchmark/representative/round22/h16_decode_comparison.csv). Full results, manifests and the model are in the same [Round 22 evidence directory](../../benchmark/representative/round22/).

## 3. Trained CNN data movement and Fused result

The frozen trained Digits CNN has 570,164 useful MAC/inference, 346/360 held-out INT8 classifications (96.11%), and prior full Top replay evidence of 360/360 samples with 7,488,000/7,488,000 exact output/intermediate word checks. The product RTL tree is unchanged from that tested RTL. Round 22 reran a single rank-0 sample through the DMA-preload path and both-fused Row-Major mode; its 20,800 Golden words passed, and the predicted label matched the held-out label. The one-sample replay is not a new 360-image accuracy run.

| Measurement | Round 22 result | Boundary / meaning |
|---|---:|---|
| Production payload | 10,944 B | 7,488 B packed Im2col input including 12 padded rows; 3,328 B weights; 128 B descriptors; zero DMA padding |
| Valid Im2col input | 7,056 B | Remaining 432 B are padding in the 208-row physical Matrix input |
| DMA transfer | 10,944 B, 4 transactions, 45 AR bursts, 684 R beats | Actual Top DMA over the behavioral AXI model |
| Mean / max read response latency | 47.6 / 50 cycles per burst | AXI model observation, not physical DDR timing |
| DMA setup + transfer window | 3,019 cycles | Includes register programming, DMA, and status polling; DMA busy is an overlapping 2,879-cycle counter |
| Both-fused Row-Major CMDQ | 12,947 cycles | Same output-compatible `0x53` mode; 20,800 words Golden checked |
| DMA-window + CMDQ subtotal | 15,966 cycles | Not full end-to-end; excludes host preprocessing, other setup, final production readback and postprocessing |
| CMDQ useful throughput | 44.04 useful MAC/cycle | 570,164 / 12,947; reported Matrix-active utilization 82.37% |
| SPAD traffic during compute | 64,064 B read / 16,640 B written | Counters from the Top command window |

The production payload has 8.61× fewer bytes than the old 94,176-byte AXI-Lite image load because that old image included 83,232 bytes of poisoned/sentinel words. In the new run those 20,808 words were initialized through test-only AXI-Lite writes outside the production DMA timing window; they are checker preconditions, not model data. This is a payload accounting improvement, not an 8.61× latency improvement.

The first-layer fused historical baseline is 35,184 CMDQ cycles with complete output Golden; both-layer fused Row-Major is 12,947 cycles, a 63.2% command-window reduction relative to first-layer fusion. Legacy was 61,310 CMDQ cycles, so the legacy/both-fused command-window ratio is 4.74×. These are same-model, output-compatible command-window results, with Round 20’s exhaustive Golden retained. They do not establish a full system latency ratio because host preparation and final output-read timing are still incomplete. Round 22 did not rerun all 360 samples through the new DMA preload path. No model-level serialized-vs-overlap CNN run was performed; the earlier three-tile 13.01% overlap probe is not used as a CNN speedup claim.

The common `conv1x_mini.onnx` point also passed on both implementations: NMAForge reports 1,985 CMDQ cycles plus 1,080 Host layout cycles (3,065 phase cycles total), while TinyNPU reports 4,781 graph cycles. Both share the model SHA and input SHA and match Golden, but NMAForge excludes preload/descriptor programming/final read and TinyNPU includes graph dispatch with a testbench DMA/SRAM shim. No speedup is computed. The workload generator reports 0.287 ms for its Im2col operation, but this is only the recorded generation subroutine time and excludes image upsample/coordinate-plane generation and full application setup. It is not a complete host latency measurement. Golden readback itself occurs after CMDQ and checks 20,800 words, but its production readback interval is not separately timed. Details are in [`cnn_dma_profile.json`](../../benchmark/representative/round22/cnn_dma_profile.json), [`cnn_dma_profile.csv`](../../benchmark/representative/round22/cnn_dma_profile.csv), and [`cnn_dma_payload_summary.json`](../../benchmark/representative/round22/cnn_dma_payload_summary.json).

## 4. SRAM resources and decision

NMAForge was exercised with a 128 KiB four-bank **behavioral** SPAD research profile, not mapped SRAM macros. The pinned TinyNPU tree contains SRAM module and bank parameters, but this direct-array benchmark does not expose an equivalent integrated controller/memory endpoint or a verified total mapped capacity. Therefore the often-cited 72 KiB TinyNPU figure is not treated here as verified, and no SRAM-capacity advantage is claimed. The 16×16 MAC resource is nominally 256 INT8 MACs on each side, but the surrounding control and storage structures differ.

The original 0x52 GEMV and 0x53 fused Row-Major dataflow remain useful research contributions. The evidence supports `0x53` on the trained CNN command path and `0x52` for selected small-M shapes; it does **not** support a general GEMV speedup or system-level TinyNPU win. The fixed-shape H16 experiment says to keep GEMV mapping optional and shape-specific. No product RTL optimization was justified in this round. Performance closure is **PARTIAL** until a common measured controller/memory endpoint and complete CNN application boundary are available.

## Reproduction and evidence

- TinyNPU rebuild, 3 GEMM + 4 GEMV comparison and Mini CNN: see exact environment/command in [`run_manifest.json`](../../benchmark/representative/round22/run_manifest.json) and fixed run tables in [`benchmark/tinynpu/`](../../benchmark/tinynpu/).
- H16 GEMM path: `make -C dv/subsystem/top_smoke/sim ai_h16_incremental_decode AI_H16_INCREMENTAL_RUN=/tmp/nmaforge_round22_h16_gemm AI_H16_INCREMENTAL_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python AI_H16_INCREMENTAL_SEED=20261116 AI_H16_INCREMENTAL_POLICY=gemm`.
- H16 GEMV path: generate with `sw/tools/generate_h16_incremental_decode.py --model /tmp/nmaforge_round22_h16_gemm/model.json --projection-policy gemv_qkv --out /tmp/nmaforge_round22_h16_gemv/workload`, then run the same compiled Top `simv` with `+AI_H16_INCREMENTAL_DIR=/tmp/nmaforge_round22_h16_gemv/workload` and log to `/tmp/nmaforge_round22_h16_gemv/run.log`.
- Trained CNN DMA path: `make -C dv/subsystem/top_smoke/sim ai_representative_trained_cnn_dma AI_REPRESENTATIVE_DMA_RUN=/tmp/nmaforge_round22_cnn_dma_retry AI_REPRESENTATIVE_DMA_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python AI_REPRESENTATIVE_DMA_SEED=20261120 AI_REPRESENTATIVE_DMA_TEST_RANK=0`.
- Smoke: `make -C dv/subsystem/top_smoke/sim ai_smoke`; seeded regression: `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` from `dv/subsystem/top_smoke/sim`.
- Exact model/input/payload/run-log hashes and tools are recorded in [`run_manifest.json`](../../benchmark/representative/round22/run_manifest.json); compact proof markers are in [`pass_markers.txt`](../../benchmark/representative/round22/pass_markers.txt).

### Remaining closure items

1. Run all 360 CNN samples with the new DMA load path and time the actual application boundary, including host preparation and final output readback.
2. Compare serialized and legal overlap for the complete CNN, not just the earlier microprobe.
3. Establish an equivalent measured TinyNPU controller/memory endpoint or retain native endpoints separately; verify total storage capacity from a real integrated implementation.
4. Run a same-input NMA GEMM-vs-GEMV M=8/16 sweep; only M=1 has a model-level mapping pair in this round.
5. Train a representative language model before making any H16 model-quality claim. Current H16 results are synthetic workload/functional evidence only.
6. Do not proceed from this report to SpyGlass, DC, timing closure, or PPA as part of Round 22; those are outside this task.
