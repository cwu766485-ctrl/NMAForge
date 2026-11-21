# NMAForge performance target: paired model kernels and SFU improvements

**DESIGN_PARTIAL.** Two product RTL optimizations improve persistent H16 performance with exact numerical outputs. A shared trained-weight Q/K/V projection benchmark now passes on both designs. End-to-end TinyNPU performance parity is not established; no system speedup is claimed from array/controller endpoints.

Candidate branch `feat/nmaforge-tinynpu-performance`, independent worktree `/tmp/nmaforge-performance`, baseline `5f5291f057aad3ab5ab0a6c73aed1bbb064e5038`. Implementation commits are `e62fc34` (Residual response scheduling) and `443d46f` (exact dividend bit-length skip and dedicated tests). Raw hash manifest is in `benchmark/representative/performance_target/manifest.json`; final checkout HEAD includes harness and documentation. Existing branches/worktrees preserved.

## Measured H16 improvements

Same GELU16 trained H16/2-head/1-layer weights, four-token prefill and eight persistent teacher-forced decode tokens, seed 20261123. Independent reference and all tensor/intermediate checks retained. Every token's logits and physical KV hashes match baseline. 128 KiB behavioral SPAD, identical model and descriptor schedule.

| Variant | Eight decode cycles | Cycles/token | Incremental saving |
|---|---:|---:|---:|
| Round 29 baseline replay | 69,358 | 8,669.750 | — |
| Residual B-response datapath | 67,774 | 8,471.750 | 1,584 cycles |
| Plus exact leading-zero divider skip | 66,931 | 8,366.375 | 843 cycles |

Combined 2,427 cycles saved, 3.4992% fewer cycles, same-design speed ratio 1.03626×. Historical 9,029.75 cycles/token→8,366.375 is 7.3465% fewer cycles, but is not this round's independent paired experiment. SPAD read/write traffic and 424 decode descriptors remain unchanged. Required INT32 intermediate tensors remain visible. Prefill/opcode details and SFU state counters are in raw logs, not inferred from busy totals.

Residual previously latched B, spent an extra state producing sum/shift/sat32, then wrote the output. New path multiplexes accepted B response into the existing residual datapath and registers the same exact output immediately. No new arithmetic unit, register, buffer or memory port. Parity/protection/abort/watchdog priority remains. New timing risk is response→add/shift/saturation→output register, to be examined physically; no Fmax claim.

Divider significant_bit_count previously used WIDTH-bit_index, which is the leading-zero position rather than the dividend bit length. For common values this retained unnecessary leading-zero iterations. Correct bit_index+1 skips only zero leading bits, preserving restoring division's quotient and remainder. This affects accelerated Softmax and LN reciprocal paths only; unaccelerated behavior remains unchanged. For 2^30, iterations reduce 34→31. Dedicated 1,260-case unsigned test checks zero/divisor-zero, every leading-bit position, high/low divisors and random full-width quotient/remainder against SV / and %. Focused SFU independent Golden passes seeds 20261109/10/11, 64 numeric vectors +9 selected errors per seed with abort/reset/recovery. No arithmetic precision change.

## Trained Transformer common computation

New shared fixture uses model prefill tokens [0,14,20,29], independent reference's embedding+position preparation and original wq/wk/wv INT8 weights. Each projection is 4×16×16, three total, 3,072 useful MACs. Byte-identical A/B files feed both RTL harnesses. Each design emits all 192 raw INT32 projection outputs; they match the independent reference and each other. A common host shift/saturate reference then matches all 192 quantized values. **Quantization and embedding preparation are not RTL-timed** and no full QKV graph or attention result is implied.

NMAForge product Matrix controller, 128-bit banked seeded behavioral responder: 95 cycles/projection, 320 B reads, 256 B writes, 16 MAC-active cycles. TinyNPU pinned direct systolic-array endpoint: 52 cycles/projection, source/weights preloaded into C++ host. Same arithmetic, different memory/control endpoints: MATCHED_COMPUTE. Do not use 95/52 as system speedup or infer measured common-memory performance. A transparent serialized Tiny memory estimate would add ceil(320/16)+1+ceil(256/16) plus setup, but remains MIXED_MEASURED_MODELED and is not a winning/losing result.

This closes trained-weight arithmetic comparability for Q/K/V projections, not unified Transformer end-to-end latency. TinyNPU's LN/Softmax approximations and scaling differ, so full graph equivalence needs an explicit shared contract, not changed Goldens.

## CNN and Matrix results

Trained 570,164-MAC both-fused CNN: unchanged 12,947 CMDQ +3,019 DMA window cycles, 20,800 Golden words PASS. Compute SPAD 64,064/16,640 B, 44.0383 useful MAC/cycle. Same original weights/payload; no full held-out accuracy rerun or host preprocessing/GAP/argmax/readback timing claim.

Shared conv1x_mini rerun: NMA 1,985 CMDQ cycles and separate 1,080 testbench-layout cycles, same four output bytes Golden PASS. Tiny graph 4,781-cycle evidence remains the previous pinned replay; no new Tiny CNN graph run here. Different endpoints preclude system ratio. NMA SPAD is 128 KiB; Tiny engine wrapper defaults to 4,096-address SRAM arrays and its graph wrapper has a separate configuration, neither an asserted matching capacity/service model.

Three common GEMMs still pass 175/263/1407 cycles with product controller; Tiny array rerun remains 52/100/790. Matrix core randomized numeric/fault regression and product GEMV rerun pass. Product 0x52 values remain 75/150/255/612 for the established matched shapes. Array remains 16×16/256-MAC. No Matrix FIFO/port/array additions. Aggregate prefetch/bank/arbiter counts overlap; no unsupported claim of a causal Matrix scheduling fix.

## Validation and remaining gap

Final RTL: VCS default smoke and 20-case seed 12345 regression PASS; H16 Golden/logits/KV PASS; trained CNN and common mini-CNN PASS; SFU three-seed PASS; divider 1,260 cases PASS. Verilator 5.052 lint/elaboration exits zero with 17 inherited warnings, no added warning category; warnings are debt, not signoff. No DC/SpyGlass/DFT/backend requested or performed. No private library/license material archived.

Remaining work to establish system parity: common measured memory/controller endpoint or explicitly separate transfer/dispatch/compute phases on both systems; same full graph with compatible quantization; complete host boundaries; SRAM macro timing and critical-path review. Residual removes a register cut, increasing timing risk even while cycle count falls. The project is now more comparable and faster in measured H16 workload, but unconditional parity with TinyNPU has not been demonstrated.
