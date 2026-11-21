# Round 29 performance evidence

VCS V-2023.12-SP1_Full64, Verilator 5.052; simulation clocks are not Fmax. H16/CNN use 128 KiB SPAD, smoke defaults to 512 KiB, Matrix block uses registered seeded behavioral responses. Model SHA and paired per-token logits/KV hashes are in raw manifest/CSV. No Golden or numeric precision changed.

| Metric | Round 28 baseline replay | Round 29 |
|---|---:|---:|
| Four-token prefill | 2,734 cycles | 2,734 cycles |
| Eight persistent teacher-forced decode tokens | 70,318 cycles | 69,358 cycles |
| Decode mean | 8,789.75 cycles/token | 8,669.75 cycles/token |
| LN descriptor | 343 cycles | 328 cycles |
| LN busy | 332 cycles | 317 cycles |
| Decode descriptors / Golden words | 424 / 10,880 | 424 / 10,880 |
| Decode SPAD read/write | 72,448 / 42,112 B | 72,448 / 42,112 B |
| Trained CNN MACs | 570,164 | 570,164 |
| CNN CMDQ / DMA window | 12,947 / 3,019 cycles | 12,947 / 3,019 cycles |
| CNN Golden words | 20,800 | 20,800 |

New decode saving is 960 cycles, 120/token, 1.3652% fewer cycles (1.01384× speed ratio). Every token's logits/KV physical hash equals baseline, and all tensor Golden words pass. Model/weights identical GELU16 H16/2-head/1-layer synthetic-task model. Host input tokens are teacher-forced; no autoregressive feedback claim. Relative to historical Round 26, combined reductions are 9,029.75→8,669.75, but only Round 28→29 is this experiment.

CNN remains 44.0383 useful MAC/cycle, 64,064/16,640 B compute SPAD traffic, 10,944 B live DMA input. Host preprocessing/GAP/argmax/readback are excluded; no complete host+device latency claim.

Pinned TinyNPU SHA 8216c22b762011aa20c05fc2768423fd12dda59d rebuilt/replayed. Common GEMM Golden passes: NMA 175/263/1407 controller+SPAD cycles, Tiny 52/100/790 direct-array cycles. Common product GEMV shapes have NMA 75/150/255/612 versus Tiny 100/100/100/244 cycles with common arithmetic; same endpoint caveat. Trained H16 projections/FFN mathematical kernels are supported but no exact trained-weight common Transformer subgraph with unified quantization/endpoints is established. No cross-design speedup is computed.

Common conv1x_mini ONNX: identical model/Golden, both four final bytes exact. NMA 1,985 CMDQ cycles plus separate 1,080 testbench layout cycles; Tiny 4,781 graph cycles includes graph/DMA shim. These are incompatible boundaries and explicitly not a system speedup. Neither side's SPAD capacity establishes matched memory service. Tiny array endpoint has no matching shared SPAD request port; NMA graph run has 128 KiB SPAD and Tiny graph shim uses configured SRAM0_DEPTH=65536, not an asserted capacity equivalence.
