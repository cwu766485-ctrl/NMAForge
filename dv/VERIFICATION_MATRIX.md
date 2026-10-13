# NMAForge block and subsystem verification matrix

`dv/subsystem/top_smoke/sim/` remains the legacy directed/smoke regression.
`dv/uvm/` owns
shared AXI agents, the top-level environment and final end-to-end tests.  The
directories below separate focused debug from system integration; their UVM
tests are planned work, not evidence of completion.

## Block level

| Block | Test object | How it is stimulated | Checker / oracle | Acceptance |
|---|---|---|---|---|
| DMA | `ai_axi128_dma` | UVM suite contains 1-D/2-D load, gather, narrow 32→128-bit transition, 1-D/2-D store, BID/RID newest-first responses, 4 KiB, abort and deterministic back-pressure tests. | Load/store address-data scoreboard, AXI4 slave BFM, SPAD model, command covergroup; SVA for AR/AW/W stability, ID ranges and 4 KiB boundary. | **Runtime regression passed in VCS on 2026-08-13:** all 11 directed/random tests, with zero UVM errors/fatals; VDBs merged. Current random-stress command coverage is 67.86%, so multi-seed expansion, bin review and code/assertion coverage closure remain. |
| Scratchpad arbiter | `ai_spad_arbiter` | Synthetic descriptor, completion, scalar, line, banked and DMA clients issue overlapping reads/writes with randomized ready. | Reference grant scheduler and per-client response scoreboard; priority and bounded-fairness assertions. | Control-plane priority preserved; data-plane requests are neither lost nor duplicated; every eligible client eventually progresses. |
| Command processor | `ai_command_processor` | Publish legal/illegal descriptors, dependency events, internal/external descriptor sources, queue-full/empty and abort cases. | Command lifecycle model for CMDQ head, event bits and expected completion order; four-word completion property. | Invalid descriptors do not launch; dependency blocks then releases correctly; head/tail advance exactly once; completion becomes visible only after word 3. |
| Control | `axi_lite_reg_if` + `ai_accel_regs` | Dedicated block UVM drives independent AW/W timing, B/R back-pressure, reset/identity, WSTRB, RO/unaligned/out-of-page error, busy-lock/abort, IRQ/W1C and randomized register traffic. | P0 RAL map, active agent plus passive monitor, scoreboard/coverage and valid-stability/abort/IRQ SVA. | 2026-08-13: six VCS tests passed with `UVM_ERROR=0`/`UVM_FATAL=0`, including frontdoor RAL access; a real AW/W dispatch bug was fixed. Functional/code-coverage closure and multi-seed review remain open. |
| CNM | `ai_banked_cnm_core` + local controllers | Random lane masks, bank addresses, partial tail groups and ping-pong/pre-fetch timing. | Python/SystemVerilog dot-product model and lane ownership assertions. | Per-lane data and final reduction match; no bank response is consumed twice; `busy/done/error` contract holds. |
| Matrix | `ai_tensor_matrix_core` | Random INT8 4x4 GEMM/batch-GEMM shapes, transpose/stride, bias, activation and requantization. | Bit-aware matrix golden model and output-tile scoreboard. | Every output tile matches golden including saturation/layout; no premature done; coverage hits transpose and tail cases. |
| SFU | `ai_tensor_sfu_core` | Directed extremes plus constrained-random Softmax, RMSNorm/LayerNorm, residual, GELU/SiLU and requant inputs. | Fixed-point golden with declared tolerance/bit contract; range and divide-by-zero assertions. | Result matches the chosen integer contract; no overflow/wrap beyond spec; all states exit. |
| Mixed-precision FP dot | `ai_mixed_precision_dot_fp32_core` + BF16/FP16 multipliers and FP32 accumulator | Directed special values plus seeded BF16/FP16 vectors; randomized SPAD response/back-pressure, 14 expected-error and 6 reset-in-flight cases in UVM, including abort before read acceptance on A/B. | Independent raw-bit Python oracle, bus-observing scoreboard, request/writeback SVA and format/length/class/sign/stall coverage. | Two-seed VCS/URG: 162/162 scoreboard transactions per seed (142 numeric + 14 expected-error + 6 reset), UVM errors/warnings/fatals 0, successful-result covergroup 100%. `ai_mixed_precision_dot_fp32_core` line/condition/FSM/branch 98.32/63.50/87.80/83.33%; all `state_r` states/transitions hit (23/23). `pending_error_r` transitions 13/18; remaining bins and partial condition/branch coverage await disposition. |
| CNN/KV | line-buffer core and `ai_kv_cache_engine` | Random convolution window/boundary and KV head/token/stride addressing. | Feature-map/KV address reference model. | Correct window/address generation, no out-of-range SPAD request, and expected output/handshake. |

## Subsystem level

| Subsystem | What is connected | How it is tested | Checker / acceptance |
|---|---|---|---|
| DMA–SPAD | `ai_axi128_dma` ↔ `ai_spad_arbiter` ↔ `ai_scratchpad` | Interleave DMA traffic with compute-like clients; inject DDR reordering, SPAD contention and protection errors. | End-to-end byte scoreboard plus arbiter/DMA assertions.  Accept only if data is correct, control traffic retains priority and all error paths terminate cleanly. |
| Queue–completion | register ABI ↔ command processor ↔ descriptor fetch ↔ completion writer | Software-like CMDQ/CPLQ producer/consumer sequences with dependency waits, bad descriptors, reset and abort. | Queue model checks pointer ownership and completion ordering.  Accept only if no overwrite/underflow occurs and CPLQ tail moves after all four completion words. |
| Tensor datapath | tile pipeline ↔ DMA/SPAD ↔ CNM/matrix/SFU/KV | Run multi-command tensor fragments with ping-pong buffers and randomized memory latency. | Golden tensor results, buffer-ownership scoreboard, overlap/stall counters.  Accept only if results match, buffer handoff is safe, and no deadlock/starvation occurs. |
| FP16 DDR-to-compute | `ai_axi128_dma` ↔ scratchpad ↔ queued `0x51` FP16 dot ↔ completion writer ↔ DMA | Directed top smoke loads two packed FP16 words from the AXI memory model, computes the dot, then stores FP32 result back to the model. | Checks both SPAD operands, FP32 result, shared completion and external-memory result (`0x41300000`). Passed in current `ai_smoke`; does not model DDR PHY or randomized DDR errors. |
| Top smoke | `ai_accel_top` ↔ AXI-Lite tasks ↔ AXI4 memory model | Directed register/DMA/queue/compute, BF16/FP16 command tests, FP16 DDR path and Transformer micro-workload. | `TEST PASS`, SVA clean, expected completion/result checks and fixed-point reference gate pass.  This is regression evidence, not UVM coverage closure. |

## Evidence status

VCS smoke/directed tests, the current mixed BF16/FP16 block UVM regression and
the FP16 DDR directed top path provide bring-up evidence. Mixed-dot successful-
result functional coverage reports 100%. UVM includes configuration,
operand-parity, read/write-protection, abort, watchdog, and active-state reset
cases. All `state_r` transitions are covered; composite pending-error priority
and some condition/branch coverage still need disposition. These results are
not substitutes for randomized DDR/error-path stress.

## 下一步
| 阶段 | 验证层级 | 验证对象 | 主要内容 | 通过标准 |
|---|---|---|---|---|
| 0 | 基线 | 全项目 | 固化 RTL/filelist/ABI、整理 test plan、lint triage | 顶层 smoke 可复现、路径唯一 |
| 1 | Block | AXI-Lite control | RAL、寄存器读写、WSTRB、IRQ、reset、sticky error | 2026-08-13 六项 VCS 回归通过；寄存器镜像、协议与本地 SVA 均通过。coverage closure 与多 seed 仍待完成。 |
| 2 | Block | DMA | 1D、2D、gather、32/128-bit、store/BID、4 KiB、abort、随机 back-pressure | DDR↔SPAD scoreboard 正确；ID/RLAST/BID/abort SVA 通过；DMA coverage 达标 |
| 3 | Block | SPAD arbiter | descriptor/completion/DMA/compute 多客户端争用、优先级、round-robin | 无丢包/重复；控制面优先；无饥饿 |
| 4 | Block | Command processor | descriptor 合法性、CMDQ/CPLQ 指针、event dependency、error/abort | 不合法任务不启动；head/tail 所有权正确；completion 原子提交 |
| 5 | Block | CNM / Matrix / SFU / CNN-KV | INT8 算法正确性、边界值、transpose、量化、Softmax/Norm、卷积窗口、KV 地址 | 与 Python bit-aware golden 匹配；无死锁、无越界 |
| 6 | Subsystem | DMA–SPAD | DMA 通过 arbiter 访问真实 scratchpad，同时叠加 compute-like client | 数据正确、仲裁正确、protection/error 可恢复 |
| 7 | Subsystem | Queue–completion | AXI-Lite 配置 → CMDQ → processor → completion writer | completion 四个 word 完成后才推进 tail；reset/abort 正确 |
| 8 | Subsystem | Tensor datapath | tile pipeline、ping-pong buffer、DMA + SPAD + matrix/SFU/CNM/KV | 多 command golden 正确；buffer ownership 安全；无 deadlock |
| 9 | Top UVM | `ai_accel_top` | 软件可见 ABI、随机 CMDQ、乱序 DDR、IRQ、reset、Transformer command-chain | 端到端结果、completion、错误恢复、性能计数器一致 |
| 10 | 静态/形式/覆盖率 | 全 RTL | SpyGlass lint/CDC/RDC、关键 SVA formal、functional/code coverage closure | P0 lint 清零或有 waiver；CDC/RDC 收口；coverage 达标 |
| 11 | FPGA/板级 | XCZU15EG | bitstream、DDR DMA、IRQ、ILA、性能计数器、长时间稳定性 | 实测数据与仿真一致，日志与性能报告归档 |
