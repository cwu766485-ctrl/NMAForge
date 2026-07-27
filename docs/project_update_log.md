# Project Update Log

## 2026-07-26 - A6 wide-AXI and tensor-dataflow upgrade (in progress)

- Started after local baseline commit `30d533c`.  The A5 DMA has up to four
  same-order read bursts but no AXI ID signals; it is therefore not an
  out-of-order engine.  The A6 implementation will add a 128-bit payload
  datapath, explicit read/write IDs and response scoreboarding before claiming
  multi-ID ordering capability.
- The A6 acceptance scope also includes a scratchpad-resident Conv3x3/DWConv
  sliding-window frontend and a KV-cache address generator used by a causal
  Transformer command chain.  Each feature will receive directed RTL and
  memory-model regression coverage before the next board build.
- Added `ai_axi128_dma_ooo`: a 128-bit AXI4 transport engine with four tagged
  read-line slots (`ARID=1..4`) and four independently tracked write responses
  (`AWID/BID=8..11`). `RID` selects the owning line buffer before it drains as
  four scalar scratchpad writes. Directed Icarus regression returns read and
  write responses in reverse-ID order: PASS.
- Added and integrated descriptor-v5 A6 compute primitives:
  `OP_CONV3X3_LINEBUF=0x16`, `OP_DWCONV3X3_LINEBUF=0x17`, and
  `OP_KV_WRITE=0x43` / `OP_KV_READ=0x44`. The convolution path has three
  rotating internal line buffers; KV addressing is
  `token*src0_stride + head*src1_stride + element*4`. Directed line-buffer
  convolution and KV read/write regression: PASS. The synthesizable
  `ai_accel_top` hierarchy also compiles with Icarus.
- The external A5 top-level M_AXI ABI remains 32-bit while the A6 engine is
  being integrated behind an explicit 128-bit AXI wrapper/descriptor-response
  demultiplexer. No board-performance or full A6 AXI claim is made until that
  wrapper replaces the current A5 port and the VCS memory model exercises it.
- ABI migration has now started: `ai_accel_top.M_AXI` exposes 128-bit
  WDATA/RDATA, 16-bit WSTRB and 4-bit AXI IDs; legacy A5 write traffic is
  explicitly packed into lane 0. `axi_desc_fetch` now fetches a 64-byte
  descriptor as four 128-bit beats on reserved ID 0. `DMA_CFG.bit1` is the
  pending A6-wide backend selector; it is deliberately constrained to direct
  contiguous DMA so legacy 2D/gather/tile semantics cannot silently change.
- Completed top-level A5/A6 DMA ownership mux: `DMA_CFG.WIDE128` selects the
  contiguous 128-bit tagged engine, while 2D/gather/tile jobs force the A5
  backend. `RID=0` is routed to descriptor/legacy traffic and `RID=1..4` to
  A6; `BID=8..11` is accepted only by A6. The complete synthesizable top
  hierarchy compiles after this wiring change.
- RTL-close P0 correction: A6 `ARREADY` is now qualified with
  `!axi_desc_busy`, preventing a descriptor-priority handshake from being
  misinterpreted as an accepted tagged DMA request.
- RTL-close acceptance attempt: synthesizable top hierarchy passes Icarus
  compile. The legacy smoke TB cannot yet compile because its local
  `axi_lite_tasks.svh` include is absent and its M_AXI declarations still use
  the pre-A6 32-bit ABI; this is an explicit verification migration blocker,
  not a pass. XCZU15EG OOC synthesis was launched and reached RTL component
  statistics without an HDL error before the 124-second command window
  expired; no new timing/utilization report was produced, so synthesis is not
  yet counted as accepted.
- 128-bit smoke migration completed: `tb_ai_accel_smoke` now declares the
  128-bit/ID M_AXI ABI; `axi_memory_model` accepts 32-bit A5 and 128-bit A6
  reads and packs four words per wide response. Full Icarus smoke with
  `AI_RANDOM_CASES=0` reaches `TEST PASS` at 96.29 us. Directed A6 tagged
  DMA reorder and CNN/KV datapath regressions also pass. The SVA now allows
  both 32-bit and 128-bit INCR requests and checks their size-dependent 4KiB
  boundary.
- Rocky-8.10 / `ray` was used for the final Synopsys acceptance. A complete
  `cp -a` initially blocked in Windows 9P I/O while copying 821 MiB of
  documentation, so the one copy process was stopped and replaced by a
  non-destructive, still `cp -a`-based functional sync of RTL, verification,
  software, FPGA source lists, configuration, and this log. Generated
  `.Xil`/`.srcs`, demo archives, and large reference documents remain on the
  Windows source tree; no WSL target file was deleted. `cmp` confirmed that
  `ai_accel_top.v`, `ai_axi128_dma_ooo.v`, `ai_accel.f`, and the smoke TB match
  the Windows source before VCS was started.
- In the interactive Synopsys environment (required to load `VCS_HOME`),
  `make ai_smoke` completed with `TEST PASS` at 132.14 us. The fixed-seed
  command `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` also completed with
  `TEST PASS` at 262.32 us. Both runs cover the integrated AXI/DMA,
  CMDQ/descriptor/completion, GEMV/GEMM, Conv3x3/DWConv, error, and reset
  recovery flows.
- The A6-only tests were also compiled and run with VCS rather than relying
  only on Icarus: `tb_ai_axi128_dma_ooo` reported `A6 AXI128 OOO DMA PASS` at
  495 ns, while `tb_ai_a6_datapaths` reported
  `A6 CNN line-buffer + KV cache PASS` at 1.095 us.
- The post-A6 XCZU15EG OOC synthesis did complete (no HDL/tool fatal): 24,941
  LUT, 15,429 FF, 128 RAMB36, and 46 DSP blocks. It is **not timing closed**
  at the 100 MHz OOC constraint: setup WNS is -0.118 ns, TNS -17.574 ns over
  309 endpoints; hold WHS is +0.083 ns. DRC contains 247 DSP-pipelining
  methodology warnings (DPIP/DPOP/DPOR), not DRC errors. This is a genuine
  A6 timing-closure action item, not an FPGA deployment pass.
- Final local `git diff --check` reports no whitespace errors. Verilator is
  not installed on either the Windows host or the Rocky WSL image, so this
  log does not claim a new Verilator lint pass; VCS compilation is the RTL
  compile evidence for this acceptance run.
- A6 OOC timing closure repair: the violating 35-level Conv3x3 write path
  crossed 3x3 arithmetic/address generation, the scratchpad arbiter,
  protection, and the wide-DMA error fanout in one cycle. `CALC` already had
  a dedicated cycle, so `ai_conv3x3_linebuffer_core` now captures its output
  address and INT32 sum there; `WRITE` consumes only those registers. This
  preserves the existing CALC-to-WRITE cycle schedule and scratchpad handshake
  while creating a real timing boundary. Post-change VCS `make ai_smoke`
  remains `TEST PASS` at 132.14 us.
- Vivado 2024.1 XCZU15EG 100 MHz OOC re-synthesis completed with 0 errors and
  0 critical warnings. Setup is now closed (WNS +0.829 ns, TNS 0, zero failing
  endpoints); hold remains closed (WHS +0.083 ns). The cost is 1 LUT and 64
  FF (24,942 LUT / 15,493 FF / 128 RAMB36 / 46 DSP), with no BRAM or DSP change.
  This is an OOC synthesis result, not post-route or board timing sign-off;
  the next critical path is in the tensor SFU output cone.
- Added a reproducible TSMC40 Design Compiler pre-layout profile under `syn/`.
  The 512 KiB scratchpad is represented as four ASIC-only 32Kx32 TDP macro
  boundaries, rather than inferring flip-flops from the Xilinx XPM model. No
  matching TSMC40 SRAM macro `.db` was confirmed, so SRAM area/leakage/access
  timing are intentionally excluded. The first 5.0 ns (200 MHz) standard-cell
  logic run completed: setup WNS/TNS = 0.00/0.00 ns, with 231,178.79 library
  area units and 92,660 leaf cells. Its critical path is the tensor-SFU
  accumulator/reduction cone (4.87 ns arrival versus 4.87 ns required), not a
  macro path. The run has pre-layout model limitations: ideal clock and wire
  load, zero macro area, one max-capacitance violation, and residual min-delay
  WNS -0.03 ns / TNS -0.34 ns over 62 paths. It is therefore an ASIC logic
  feasibility point, not a final 200 MHz or full-chip PPA claim.
- The 4.0 ns (250 MHz) pressure run also completed with setup WNS/TNS
  0.00/0.00 ns at 234,895.89 logic area units (+1.6% against the 5.0 ns
  run), 93,920 leaf cells, and a 3.89 ns critical matrix-core lane-to-INT32
  accumulator path. It establishes that DC can optimize the current logic to
  meet a 250 MHz *setup* target under the selected ideal-clock/WLM model.
  It does **not** close min delay: `hold_timing.rpt` reports WNS -0.03 ns,
  TNS -0.39 ns across 67 paths, while two max-capacitance violations and the
  unresolved zero-area SRAM macro remain. The script was strengthened after
  this run to use an explicit incremental hold-only repair pass; the 4.0 ns
  PPA number must remain labelled pre-layout logic-only until a real SRAM
  macro view, CTS, placement, extracted RC and PrimeTime STA are available.
- The 4.0 ns point was rerun after adding `compile -incremental
  -only_hold_time`. The final TSMC40 pre-layout report has setup WNS/TNS
  0.00/0.00 ns, hold WNS/TNS 0.00/0.00 ns and zero max-transition/
  max-capacitance violations. Hold repair increased leaf cells from 93,920 to
  95,423 and standard-cell area from 234,895.89 to 245,394.28 units (+4.5%),
  primarily buffer/inverter area (8,455.91 to 18,947.24 units). This is the
  measured cost of making the min-delay constraint explicit. It remains a
  250 MHz **pre-layout logic-only feasibility point**, not a final ASIC Fmax:
  one SRAM macro type/four instances are still zero-area black boxes, clocks
  are ideal, the WLM is estimated, and the DC check-design report contains
  356 non-fatal lint-style potential problems that need a separate lint
  cleanup before any sign-off claim.
- Started a separate TSMC28 HPC+ ASIC profile using the locally available
  nominal TT/0.9 V/25 C standard-cell library and real SRAM timing views.
  The installed memory compiler supplies only 4Kx32 single-port macros, so
  the 512 KiB scratchpad is represented by 32
  `TS1N28HPCPL2SVTB4096X32M4MWBASO` instances (8 per logical bank), not an
  unresolved 32Kx32 black box. This is protocol-compatible because
  `ai_spad_arbiter` admits exactly one scalar-or-banked scheduler request per
  cycle and the existing host interface rejects overlapping scheduler access.
  The 28nm adapter, DC script, PVT pairing and 4.0 ns baseline run are being
  validated independently of the preserved 40nm study.

## 2026-07-26 - A5 board-measurement RTL increment

- Added a safe one-entry A/B operand prefetch path to `ai_tensor_matrix_core`;
  its ownership remains through `ai_spad_arbiter` and it waits for both
  registered scratchpad responses before switching K groups.
- Marked the sixteen INT8 multiplier nets with Xilinx DSP inference intent.
- Added `OP_CAUSAL_SOFTMAX_Q15 (0x39)` for decoder masking.  `aux0[15:0]` is
  the query index and future positions produce zero probability.
- Added software-clearable matrix/DMA observability registers at `0x174` to
  `0x198`, documented in `CIMFORGE_A5_PERFORMANCE.md`.
- Updated the smoke test for the new ABI, matrix counters and causal softmax.
- Validation: Vivado 2024.1 `xvlog` + `xelab` completed and `xsim a5_smoke
  -runall` reported `TEST PASS` at 269770 ns.  The final prefetch protection
  check was included in that run.
- FPGA evidence: the source-equivalent XCZU15EG (`xczu15eg-ffvb1156-2-i`)
  out-of-context synthesis completed with 0 errors and 0 critical warnings;
  it reports 17,232 LUTs, 10,414 FFs, 128 RAMB36 and 38 DSP48E2.  At the
  100 MHz OOC constraint it reports WNS=+0.829 ns and WHS=+0.083 ns, with no
  failing setup or hold endpoints.  The DRC contains 215 DSP-pipelining and
  asynchronous-load *warnings*, not DRC errors; explicit DSP register
  pipelining remains a timing-optimization item.  This OOC result is not a
  placed-and-routed board timing closure or bitstream acceptance result.
- Board-test software: extended `cimforge_bringup.c` with `dma256` and
  `gemm4x4x8` performance microbenchmarks.  XSCT rebuilt the standalone A53
  application against the existing board XSA; the resulting ELF compiled and
  links with entry point `0x00100000`.  That build validates the new C/ABI,
  but the old XSA/bitstream must be regenerated from this A5 RTL before a
  board measurement is accepted.
- Final board implementation: the rebuilt XCZU15EG PS/PL design routed and
  produced `cimforge_board.bit`, `cimforge_board.xsa` and
  `cimforge_board.ltx`.  At 100 MHz, formal routed timing reports
  WNS=+0.094 ns, WHS=+0.010 ns, TNS=THS=0 and zero failing endpoints.
  Routed utilization is 30,630 LUTs, 29,679 FFs, 189 RAMB36 + 1 RAMB18 and
  38 DSP48E2; the accelerator hierarchy itself is 17,287 LUTs, 10,489 FFs,
  128 RAMB36 and 38 DSP48E2.  Routed DRC has 0 errors and 224 warnings,
  principally DSP input/output-pipeline advice, asynchronous-reset DSP
  packing limitations, and generated SmartConnect/debug-net warnings.
- New-XSA software handoff: XSCT rebuilt `cimforge_fsbl.elf` and the updated
  `cimforge_bringup.elf` after implementation.  Hardware download and UART/
  ILA observation remain the next, physical-board acceptance step.

这个文件用于记录本项目每次实质性更新。后续凡是修改 RTL、验证平台、综合脚本、文档结构或项目路线，都在这里追加记录。

> Note: this file is a chronological development log. Some early entries refer to
> documents that have since been archived under `docs/archive_legacy/`. For the
> current code-version specification, start from `docs/README.md`,
> `docs/architecture.md`, `docs/test_plan.md`, and
> `docs/verification_report.md`.
## 2026-05-30 - AHB/SRAM protocol boundary enhancement

### 目标

完成短期目标中的 AHB 协议边界和 SRAM 行为补强，使项目从教学级 SRAM controller 进一步靠近简历级小型 RTL IP。

### RTL 更新

更新文件：

- `rtl/ahb_slave_if.v`
- `rtl/sramc_top.v`

主要变化：

- `ahb_slave_if` 增加 `SRAM_WAIT_CYCLES` 参数，用 `hready_resp` 插入可配置 wait-state。
- 支持以下 AHB burst 类型：
  - `SINGLE`
  - `INCR`
  - `INCR4`
  - `INCR8`
  - `INCR16`
- 不支持 `WRAP4 / WRAP8 / WRAP16`，遇到后返回 `hresp = ERROR`。
- 增加非法访问检查：
  - illegal `hsize`
  - unaligned halfword access
  - unaligned word access
  - malformed `SEQ` transfer
  - burst 内 `hsize` 改变
  - burst `SEQ` 地址没有按 `hsize` 自动递增
- 非法访问不会落到 SRAM array，避免错误写入。
- `hresp` 在响应周期返回：
  - `2'b00`：OKAY
  - `2'b01`：ERROR
- `sramc_top` 增加 `SRAM_WAIT_CYCLES` 参数，并传递给 `ahb_slave_if`。

### SV 验证平台更新

更新文件：

- `verif/agent/ahb/ahb_slv_if.sv`
- `verif/agent/ahb/ahb_slv_pkt.sv`
- `verif/agent/ahb/ahb_slv_generator.sv`
- `verif/agent/ahb/ahb_slv_driver_base.sv`
- `verif/agent/ahb/ahb_slv_driver.sv`
- `verif/agent/ahb/ahb_slv_scoreboard.sv`
- `verif/env/ahb_slv_fcoverage.sv`
- `verif/tb/ahb_sramc_svtb_top.sv`
- `verif/tests/ahb_sramc_base_test.sv`
- `verif/tests/ahb_sramc_test.sv`
- `docs/ahb_sram_protocol.md`

主要变化：

- transaction `ahb_slv_pkt` 增加：
  - `hburst`
  - `hresp`
  - `hready_resp`
  - `expect_error`
- interface clocking block 增加：
  - driver 输出 `hburst`
  - driver 输入 `hready_resp/hresp`
  - monitor 输入 `hburst/hready_resp/hresp`
- driver 支持 wait-state：
  - 地址阶段后进入数据阶段
  - 等待 `hready_resp == 1`
  - 再采样 `hrdata/hresp`
- generator 增加：
  - legal single write/read pair
  - legal `INCR4` burst write/read sequence
  - illegal access case
- scoreboard 增加：
  - `expect_error` 检查
  - 期望 ERROR 时只检查 `hresp`
  - 非期望 ERROR 时报告错误
- coverage 增加：
  - illegal hsize bin
  - hburst coverage
  - hresp coverage
  - expected legal/error coverage
  - burst/response cross coverage

### 文档更新

新增 `docs/ahb_sram_protocol.md`，记录：

- AHB transfer 支持范围
- illegal access 处理规则
- wait-state 行为
- burst 行为
- 当前特殊 SRAM bank/lane 地址映射
- 后续验证 coverage checklist

### 验证结果

已执行：

```bash
iverilog -g2012 -o NUL -f verif/sim/rtl.f
```

结果：

- RTL-only 编译通过。

未执行：

- Questa/VCS 完整 SV 仿真。

原因：

- 当前本地 Windows 环境没有 Questa/VCS。
- SV 平台使用了 Icarus Verilog 不完整支持的特性，例如 clocking block、constraint、covergroup。

### 下一步建议

1. 在 VNC 服务器上运行 Questa/VCS 完整仿真。
2. 用 Verdi 检查：
   - illegal access 的 `hresp`
   - wait-state 的 `hready_resp`
   - burst SEQ 地址检查
   - SRAM array 是否没有被 illegal access 写入
3. 若仿真稳定，继续补：
   - AHB monitor
   - test plan
   - coverage checklist
   - SpyGlass lint

## 2026-06-02 - Project roadmap adjusted to vector accelerator

### 目标

将长期路线从“直接引入 CIM-inspired SOM accelerator”调整为更适合数字 IC 前端设计/验证求职的“AHB/AXI SRAM-based Vector Accelerator”。

### 文档更新

更新文件：

- `docs/project_prospective.md`

主要变化：

- 将项目目标更新为：
  - AHB/AXI 总线接口
  - SRAM scratchpad
  - register control/status
  - vector compute engine
  - interrupt/status reporting
  - SV/UVM 验证
  - lint/DC 综合闭环
- 新增推荐架构：
  - register block
  - SRAM scratchpad controller
  - vector compute engine
  - result/status/interrupt block
- 定义第一阶段可实现操作：
  - `VADD`
  - `VSUB`
  - `VMAC`
  - `L1DIST`
- 定义寄存器规划：
  - `CTRL`
  - `STATUS`
  - `SRC0_BASE`
  - `SRC1_BASE`
  - `DST_BASE`
  - `LENGTH`
  - `SCALE_SHIFT`
  - `IRQ_STATUS`
- 将 CIM/SOM 调整为 Stage 5 研究扩展，而不是当前主线。

### 当前结论

更推荐先完成：

> AHB-Lite configurable SRAM-based vector accelerator supporting scratchpad access, vector add/sub/MAC/L1 distance, wait-state-aware SRAM scheduling, error handling, interrupt/status reporting, and SV class-based verification.

然后再把 CIM/SOM 作为论文特色和研究扩展加入。

## 2026-06-02 - Stage 4 vector accelerator RTL implemented

### 目标

完成 Stage 4 的最小 RTL 闭环：在原 AHB SRAM controller 基础上扩展一个可由 AHB-Lite 配置的片上 SRAM 向量计算加速器。

### RTL 更新

新增文件：

- `rtl/vec_accel_regs.v`
- `rtl/vec_accel_core.v`
- `rtl/vec_accel_top.v`

修改文件：

- `rtl/ahb_slave_if.v`
- `verif/sim/rtl.f`

主要变化：

- 新增寄存器窗口：
  - `CTRL`
  - `STATUS`
  - `SRC0_BASE`
  - `SRC1_BASE`
  - `DST_BASE`
  - `LENGTH`
  - `SCALE_SHIFT`
  - `IRQ_STATUS`
  - `RESULT`
- 新增向量计算核心，支持：
  - `VADD`
  - `VSUB`
  - `VMAC`
  - `L1DIST`
- 新增加速器顶层：
  - `0x0000_0000 ~ 0x0000_ffff` 映射为 scratchpad SRAM。
  - `0x0001_0000 ~ 0x0001_00ff` 映射为控制寄存器。
  - compute busy 时，AHB 访问 SRAM 窗口返回 ERROR。
  - compute busy 时，AHB 仍可访问寄存器窗口。
- 修正 `ahb_slave_if` 同步 SRAM 读时序：
  - 原逻辑在发出 SRAM 读命令的同一响应周期返回 `hrdata`，会读到上一笔数据。
  - 新逻辑提前发出 SRAM 读命令，在响应周期返回稳定读数据。

### 验证更新

新增文件：

- `verif/tb/tb_vec_accel_smoke.sv`

smoke test 流程：

1. 通过 AHB 写入两组输入向量到 scratchpad SRAM。
2. 配置 `SRC0_BASE/SRC1_BASE/DST_BASE/LENGTH/CTRL`。
3. 启动 `VADD`。
4. 轮询 `STATUS.done`。
5. 从 scratchpad 读回结果并检查。

已通过用例：

```text
src0 = {10, 20}
src1 = {1,  2}
dst  = {11, 22}
```

### 当前定位

当前 Stage 4 不是晶体管级存内计算，而是：

> 片上 SRAM scratchpad 向量计算加速器。

它可以作为面向嵌入式 SoC 的轻量级数据预处理/向量计算 IP。后续可以继续扩展 AXI-Lite、DMA、UVM 验证和 DC 综合流程。

## 2026-06-02 - Stage 4 design boundary finalized

### 目标

在进入系统验证前，先收敛 Stage 4 的设计最终状态，避免验证阶段一边测一边大幅改架构。

### RTL 更新

修改文件：

- `rtl/vec_accel_regs.v`
- `rtl/vec_accel_core.v`
- `rtl/vec_accel_top.v`

主要变化：

- `vec_accel_core` 新增计算地址范围检查：
  - 32-bit 计算地址限制在 `0x0000_0000 ~ 0x0000_3ffc`。
  - `length=0`、非法 `op_mode`、地址不对齐、地址越界都会进入 error。
- `vec_accel_regs` 新增 busy 期间配置写保护：
  - 计算运行中，不允许改写 `CTRL/SRC0_BASE/SRC1_BASE/DST_BASE/LENGTH/SCALE_SHIFT`。
  - 计算运行中仍允许清 `STATUS` 和 `IRQ_STATUS`。
- `vec_accel_top` 新增 `COMPUTE_ADDR_MAX` 参数并传递给计算核心。

### Smoke Test 更新

修改文件：

- `verif/tb/tb_vec_accel_smoke.sv`

新增覆盖：

- `VADD`
- `VSUB`
- `VMAC`
- `L1DIST`

已通过结果：

```text
src0 = {10, 20}
src1 = {1,  2}

VADD   -> {11, 22}
VSUB   -> {9,  18}
VMAC   -> 50
L1DIST -> 27
```

### 当前结论

Stage 4 的 AHB-Lite 版本设计边界已经收敛。后续进入验证阶段时，DUT 可以固定为：

> AHB-Lite configurable scratchpad-based vector accelerator supporting VADD/VSUB/VMAC/L1DIST, register control/status, SRAM arbitration, busy/error protection, interrupt status, and address boundary checks.

## 2026-06-03 - Stage 4 verification test plan added

### 目标

在改造 SV 验证平台前，先为 AHB-Lite SRAM 向量计算加速器 v1.0 建立验证计划，明确功能点、异常点、scoreboard 检查规则和覆盖率目标。

### 文档更新

新增文件：

- `docs/vec_accel_testplan.md`

主要内容：

- DUT 范围和地址空间
- 控制寄存器定义
- `VADD/VSUB/VMAC/L1DIST` 操作模式
- 标准软件启动流程
- 验证环境组件规划
- 功能测试点：
  - reset
  - register access
  - scratchpad SRAM access
  - vector operation
  - error/protection
  - interrupt/status
- scoreboard 检查规则
- functional coverage 计划
- regression test 列表
- 验证完成标准

### 下一步

按该 test plan 改造现有 class-based SV 平台：

1. 将 DUT 切换为 `vec_accel_top`。
2. transaction 支持 SRAM 访问、寄存器访问和计算任务。
3. scoreboard 加入向量计算 golden model。
4. coverage 覆盖 op/length/address/error/irq/wait-state。

## 2026-06-03 - Class-based SV platform retargeted to vector accelerator

### 目标

按照 `docs/vec_accel_testplan.md`，将现有 class-based SV 验证平台从旧 `sramc_top` 逐步改造成面向 `vec_accel_top` 的验证平台。

### SV 平台更新

修改文件：

- `verif/agent/ahb/ahb_slv_pkt.sv`
- `verif/agent/ahb/ahb_slv_generator.sv`
- `verif/agent/ahb/ahb_slv_scoreboard.sv`
- `verif/env/ahb_slv_fcoverage.sv`
- `verif/tb/ahb_sramc_svtb_top.sv`
- `verif/tests/ahb_sramc_base_test.sv`
- `verif/tests/ahb_sramc_test.sv`
- `verif/sim/Makefile`
- `verif/sim/Makefile.questasim`
- `verif/sim/Makefile_questasim`

主要变化：

- testbench DUT 从 `sramc_top` 切换为 `vec_accel_top`。
- packet 增加：
  - `check_hrdata`
  - `expected_hrdata`
  - `vec_op`
  - `vec_len`
  - `purpose`
- generator 改为生成向量加速器 directed sequence：
  - 写输入向量到 scratchpad SRAM
  - 配置寄存器
  - 启动 `VADD/VSUB/VMAC/L1DIST`
  - 轮询 `STATUS`
  - 读回结果并标记期望值
  - 增加 `length=0` error case
- scoreboard 增加：
  - 寄存器访问识别
  - 指定读数据期望值检查
  - 向量结果读回检查
- coverage 增加：
  - SRAM/register 地址区域
  - `vec_op`
  - checked/unchecked read
  - region/response cross
- VCS Makefile 增强：
  - 使用 `-full64`
  - 使用 `-debug_access+all`
  - 使用 `-kdb` 方便 Verdi 调试
  - 支持 `make WAVE=1` 生成 VPD
  - 支持 `make verdi` 打开波形

### 本地检查结果

已执行：

```bash
iverilog -g2012 -o NUL -f verif/sim/rtl.f
iverilog -g2012 -o vec_accel_smoke.vvp -f verif/sim/rtl.f verif/tb/tb_vec_accel_smoke.sv
vvp vec_accel_smoke.vvp
```

结果：

- RTL-only 编译通过。
- `tb_vec_accel_smoke` 通过：
  - `VADD`
  - `VSUB`
  - `VMAC`
  - `L1DIST`

### VNC VCS 验证结果

已上传并在 VNC 服务器运行：

```text
<user>@<vnc-server>:~/sv_project/ahb-lite-sram-vector-accelerator
```

执行命令：

```bash
cd ~/sv_project/ahb-lite-sram-vector-accelerator/verif/sim
make clean
make
make clean
make WAVE=1
```

结果：

- VCS 编译通过。
- class-based SV 仿真通过。
- scoreboard 结果：
  - PASS count = 317
  - ERROR count = 0
- test result：
  - `ahb_sramc_base_test` TEST PASS
- functional coverage：
  - 49.83%
- 已生成 VPD 波形：
  - `verif/sim/vcdplus.vpd`

说明：

- 当前 coverage 仍偏低，因为 directed suite 只覆盖了第一批核心功能点。
- 后续需要继续补 random/error/busy/unaligned/burst 等用例提高覆盖率。

## 2026-06-03 - SV directed testcase coverage expansion

### 目标

围绕 AHB/SRAM 边界和向量加速器寄存器行为补 directed testcase，提高 function coverage，并先在 VCS 上确认平台稳定。

### 更新文件

- `verif/agent/ahb/ahb_slv_generator.sv`
- `verif/agent/ahb/ahb_slv_scoreboard.sv`

### 新增测试点

- SRAM byte / halfword / word 读写访问。
- illegal `hsize`。
- unaligned halfword / word 访问。
- unsupported WRAP burst：`WRAP4 / WRAP8 / WRAP16`。
- `INCR / INCR4 / INCR8 / INCR16` burst 采样。
- `HTRANS_BUSY` no-op 传输。
- 计算 busy 期间访问 scratchpad SRAM，期望 `hresp = ERROR`。
- 计算 busy 期间写配置寄存器，期望 `hresp = ERROR`。
- 非法 `op_mode`。
- `src0/src1/dst` 地址不对齐。
- `src0/src1/dst` 地址越界。
- `irq_en = 0` 和 `irq_en = 1` 两种启动情况。
- `STATUS` / `IRQ_STATUS` 写 1 清除。
- `length = 1 / 2 / 3 / 4 / 16` 以及合法边界地址访问。

### Scoreboard 更新

- `HTRANS_IDLE / HTRANS_BUSY` 现在按 no-op 处理，不再误走 SRAM 参考模型比较。
- 保持 `expect_error` 对 `hresp = ERROR` 的检查。
- 保持显式读数据检查 `check_hrdata / expected_hrdata`。

### VCS 验证结果

远端目录：

```text
~/sv_project/ahb-lite-sram-vector-accelerator/verif/sim
```

执行：

```bash
make clean && make
```

结果：

- `TEST PASS`
- Scoreboard PASS count：1424
- Scoreboard ERROR count：0
- Functional coverage：88.89%

### 备注

本次尝试用 `urg -dir simv.vdb -report urgReport` 导出 code coverage summary，但当前 VNC 环境中的 URG 运行崩溃，未得到可用 dashboard。后续可改用 Verdi/DVE 打开 `simv.vdb`，或调整 VCS/URG 环境后再导出 code coverage。

## 2026-06-04 - Functional coverage improvement to 98.33%

### 目标

继续补强 class-based SV directed testcase，并修正 function coverage model 中不合理的不可达 cross 组合，使覆盖率提升来自真实测试点和合理 coverage 建模。

### 更新文件

- `verif/agent/ahb/ahb_slv_generator.sv`
- `verif/env/ahb_slv_fcoverage.sv`

### 新增测试点

- `HTRANS_IDLE` no-op transfer。
- 读方向 illegal `hsize`。
- SRAM 8 个 `haddr[15:13]` lane/bank 选择覆盖。
- `SEQ` without active burst，期望 `hresp = ERROR`。
- `INCR4` burst 中途改变 `hsize`，期望 `hresp = ERROR`。
- `INCR4` burst 中途地址不连续，期望 `hresp = ERROR`。
- `INCR` burst 中途地址不连续，期望 `hresp = ERROR`。
- register space 未定义地址读写，期望 `hresp = ERROR`。
- register space 非 word access，期望 `hresp = ERROR`。

### Coverage model 更新

`cross_burst_resp` 中排除以下不合理或非当前目标组合：

- unsupported WRAP burst + OKAY response。
- INCR8 + ERROR response。
- INCR16 + ERROR response。

说明：

- WRAP burst 在当前设计中明确不支持，因此 WRAP + OKAY 是不可达组合。
- INCR8/INCR16 的合法路径已覆盖；错误路径不是当前 test plan 的目标，后续若要专门验证长 burst 错误恢复，可以再把这两个 ignore_bins 拆掉并补对应 case。

### VCS 验证结果

远端目录：

```text
~/sv_project/ahb-lite-sram-vector-accelerator/verif/sim
```

执行：

```bash
make clean && make
```

结果：

- `TEST PASS`
- Scoreboard PASS count：1442
- Scoreboard ERROR count：0
- Functional coverage：98.33%

### 后续

下一步应导出 code coverage summary，重点看 line/branch/condition/FSM/toggle 的真实缺口。code coverage 不建议直接追求裸 100%，需要区分可补 testcase 的缺口和设计中不可达、非目标或 DFT/BIST 相关分支。

## 2026-06-04 - Verification closure strengthening

### 目标

进一步补齐 test plan 中仍偏弱的 directed case，并让验证平台直接检查 DUT 的 `irq` 输出，而不是只间接检查 `IRQ_STATUS`。

### 更新文件

- `verif/agent/ahb/ahb_slv_if.sv`
- `verif/agent/ahb/ahb_slv_pkt.sv`
- `verif/agent/ahb/ahb_slv_driver_base.sv`
- `verif/agent/ahb/ahb_slv_driver.sv`
- `verif/agent/ahb/ahb_slv_generator.sv`
- `verif/agent/ahb/ahb_slv_scoreboard.sv`
- `verif/env/ahb_slv_fcoverage.sv`
- `verif/tb/ahb_sramc_svtb_top.sv`
- `docs/vec_accel_verification_status.md`

### 新增/增强点

- 将 `vec_accel_top.irq` 接入 SV interface。
- transaction 增加 `irq/check_irq/expected_irq`。
- driver 在每笔 transaction 完成时采样 `irq`。
- scoreboard 支持在显式读检查时同步比较 `hrdata` 和 `irq`。
- 新增 reset 默认值检查：
  - `CTRL`
  - `STATUS`
  - `SRC0_BASE`
  - `SRC1_BASE`
  - `DST_BASE`
  - `LENGTH`
  - `SCALE_SHIFT`
  - `IRQ_STATUS`
  - `RESULT`
- 新增 soft reset idle 写入和读回检查。
- 新增配置寄存器 readback testcase。
- 新增 `CTRL.start` 读回为 0 的检查。
- 新增 `dst` 地址不对齐和 `dst` 地址越界 case。
- 新增 `length=8` case。
- 新增第二组 `VMAC`，覆盖不同 `scale_shift`。
- functional coverage 增加：
  - `vec_len`
  - `irq`
  - `check_irq`
  - `irq/check_irq` cross

### VCS 验证结果

远端目录：

```text
~/sv_project/ahb-lite-sram-vector-accelerator/verif/sim
```

执行：

```bash
make clean && make
```

结果：

- `TEST PASS`
- Scoreboard PASS count：1841
- Scoreboard ERROR count：0
- Functional coverage：98.68%

### 测试点闭合状态

新增 `docs/vec_accel_verification_status.md`：

- 正式测试点总数：35
- DONE：33
- PARTIAL：2
- TODO：0

剩余两个 PARTIAL：

- `RST_002 soft_reset`：当前仅覆盖 idle 下 soft reset 写入和读回；设计当前不开放 busy 中 soft reset abort。
- `SRAM_005 wait-state`：driver 已按 `hready_resp` 等待采样，但还没有独立 wait-state coverpoint/assertion。

## 2026-06-04 - First code coverage closure pass

### 目标

在 functional coverage 和 scoreboard 已稳定的基础上，导出并分析 VCS code coverage，区分真实 testcase 缺口和当前阶段不应计入的 BIST/DFT 路径。

### 更新文件

- `verif/agent/ahb/ahb_slv_generator.sv`
- `verif/sim/Makefile`
- `verif/sim/parse_vcs_cov.py`
- `docs/vec_accel_code_coverage.md`

### 新增 testcase

补充半字访问 bank/lane 覆盖：

- bank0 low halfword read/write
- bank0 high halfword read/write
- bank1 high halfword read/write

这些 case 提升了：

- `ahb_slave_if` 半字读出路径覆盖
- `sram_core` 半字写数据分发路径覆盖

### 新增脚本

新增 `verif/sim/parse_vcs_cov.py`：

- 直接解析 `simv.vdb/snps/coverage/db/testdata/test/*.xml`
- 输出 ALL 和 MAIN 两类 summary
- 作为 `urg` 不稳定时的文本 fallback

Makefile 新增：

```bash
make cov_text
```

### VCS 验证结果

执行：

```bash
make clean && make
```

结果：

- `TEST PASS`
- Scoreboard PASS count：1844
- Scoreboard ERROR count：0
- Functional coverage：98.68%

### Code coverage 结果

全量统计包含 testbench、主功能 RTL、BIST/DFT 路径：

| Metric | Coverage |
|---|---:|
| Line | 39.32% |
| Branch | 41.63% |
| Condition | 63.77% |
| FSM | 4.41% |
| Toggle | 55.22% |

当前主功能范围只统计：

- `vec_accel_top`
- `vec_accel_regs`
- `ahb_slave_if`
- `vec_accel_core`
- `sram_core`

主功能结果：

| Metric | Coverage |
|---|---:|
| Line | 96.34% |
| Branch | 95.21% |
| Condition | 84.91% |
| FSM | 74.19% |
| Toggle | 53.31% |

## 2026-06-04 - SVA assertion checker added

在现有 class-based SV directed regression 基础上，加入独立 SVA checker，让协议和关键状态约束不只依赖 scoreboard transaction 级检查。

更新文件：
- `verif/env/vec_accel_sva.sv`
- `verif/tb/ahb_sramc_svtb_top.sv`
- `verif/sim/Makefile`
- `verif/sim/Makefile.questasim`
- `verif/sim/Makefile_questasim`
- `docs/vec_accel_sva_assertions.md`

新增断言范围：
- AHB legal/illegal request response 检查。
- wait-state 期间 `hresp` 保持 `OKAY`。
- `hready_resp/hresp` ready 时不能为 X/Z。
- SRAM/register 非法访问必须返回 `ERROR`。
- compute busy 期间访问 SRAM 或写配置寄存器必须返回 `ERROR`。
- `core_sram_req` 只能在 `core_busy` 期间出现。
- `core_done` 不能和 `core_busy` 同时为 1。
- `core_error` 必须伴随 `core_done`。
- `core_start` 后必须在超时上限内完成或报错。

实现说明：AHB 响应检查采用 pending request monitor 方式。请求发起时锁存预期是否合法，等 `hready_resp` 返回时只检查一次，避免 driver 在 wait/response 阶段保持地址控制信号时，checker 把同一笔 transfer 重复识别为新请求。所有断言失败均使用 `$fatal(1, ...)`，因此后续 regression 中只要 SVA 失败，`make run` 会直接返回失败。

VCS 验证结果：
```text
TEST PASS
Scoreboard PASS count  = 1844
Scoreboard ERROR count = 0
Functional coverage    = 98.68%
SVA FAIL count         = 0
```

### 结论

当前 directed verification 的主功能 line/branch 已超过 95%。全量 code coverage 低主要因为 BIST/DFT 子模块未在当前功能验证阶段启用。后续应补 waiver/exclude 文档、SVA assertion 和 constrained-random regression，而不是盲目追求裸 100%。

## 2026-06-04 - Verification documentation added

新增两份验证文档：

- `docs/test_plan.md`
- `docs/verification_report.md`

本次文档化内容：

- 明确当前 DUT 范围：AHB-Lite SRAM vector accelerator。
- 明确当前 SV directed testbench 架构：generator、driver、passive monitor、scoreboard、functional coverage、SVA checker。
- 记录 scoreboard 已升级为 expected stream 与 monitor actual stream 双路比较。
- 整理 reset、register、SRAM/AHB、burst、vector op、error、busy protection、irq 等测试点。
- 记录当前 VCS 回归结果：

```text
TEST PASS
Scoreboard PASS count  = 1844
Scoreboard ERROR count = 0
Functional coverage    = 98.68%
Monitor transactions   = 1979
SVA failure            = 0
```

当前阶段结论：

- 主功能 directed SV 验证已经具备阶段性 closure 条件。
- BIST/DFT、AXI/DMA、UVM、lint/formal/DC 不属于当前已完成范围。
- 下一步建议做最新 code coverage 导出、coverage waiver、constrained-random 和多 seed regression。

## 2026-06-05 - RTL v2 branch upgrade started

在新分支 `feature/ssp-vector-accelerator-rtl` 上开始 RTL v2 升级，目标是增强寄存器可观测性和计算配置能力，同时保持原 AHB 顶层接口不变。

本次 RTL 改动：

- `rtl/vec_accel_regs.v`
  - 新增只读 `VERSION`、`CAPABILITY`。
  - 新增只读 `ERROR_CODE`。
  - 新增只读 `CYCLE_COUNT`、`ELEMENT_COUNT`。
  - 新增可写 `SRC0_STRIDE`、`SRC1_STRIDE`、`DST_STRIDE`，默认值为 4 byte。
  - 对只读寄存器写访问返回 `hresp=ERROR`。

- `rtl/vec_accel_core.v`
  - 新增 `VMUL`，`op_mode=4`。
  - 支持三路可配置 stride。
  - 增加 `error_code`、`cycle_count`、`element_count` 输出。
  - 增加 stride 为 0、stride 未对齐、stride 导致越界等启动前配置检查。

- `rtl/vec_accel_top.v`
  - 保持 AHB 顶层端口不变。
  - 连接新增寄存器配置和 core 观测信号。

- `verif/env/vec_accel_sva.sv`
  - 更新寄存器地址白名单。
  - 增加只读寄存器写访问的 ERROR 预期。

- `verif/agent/ahb/ahb_slv_generator.sv`
  - 原 unknown register case 从 `0x10024` 移到 `0x10044`，因为 `0x10024` 已成为 `VERSION`。
  - RTL v3 中 `0x10044` 已成为 `CONFIG`，unknown register case 继续移到 `0x10080`。

VCS 兼容性回归：

```text
make clean
make comp
make run

TEST PASS
Scoreboard ERROR count = 0
Functional coverage    = 98.68%
```

当前说明：

- 本次只保证旧 directed regression 不被破坏。
- 新增 `VMUL/stride/error_code/perf counter` 还需要下一步补 dedicated testcase、scoreboard 参考模型和 coverage bins。

## 2026-06-05 - RTL v3 config/IRQ/packed datapath upgrade

继续在 `feature/ssp-vector-accelerator-rtl` 分支增强 vector accelerator RTL，目标是把计算配置能力补到更接近工程 IP 的形态。

本次 RTL 改动：

- 新增 `CONFIG` 寄存器：
  - `signed_mode`：支持有符号/无符号计算切换。
  - `saturate_en`：支持饱和加减乘和累加。
  - `round_en`：multiply-based 操作右移前增加 rounding。
  - `data_width`：支持 32-bit word、packed int16x2、packed int8x4。
- 新增 IRQ 寄存器：
  - `IRQ_ENABLE`：独立中断输出使能。
  - `IRQ_MASK`：屏蔽中断输出但保留 pending。
  - `IRQ_CLEAR`：写 1 清 pending 中断。
- `vec_accel_core` 扩展：
  - `VADD/VSUB/VMUL` 支持 word/int16/int8 packed lane 计算。
  - `VMAC/L1DIST` 支持 packed lane reduce 到 32-bit accumulator。
  - 增加 illegal `data_width=3` 配置检查，对应 `ERROR_CODE=9`。
- `vec_accel_sva` 和 directed negative testcase 同步新版寄存器地图。

当前说明：

- VNC/VCS 编译通过，旧 directed regression 通过：

```text
TEST PASS
Scoreboard PASS count  = 1844
Scoreboard ERROR count = 0
Functional coverage    = 98.68%
```

- 后续验证需要补 CONFIG/packed/IRQ 专项 testcase、scoreboard 参考模型和 coverage bins。
- CIM 论文方向暂不直接实现 bitcell 级 CIM macro，只保留为后续 CIM-inspired near-memory compute 展望。

## 2026-06-05 - CIM-inspired SOM RTL mode added

在保持 AHB 顶层接口不变的前提下，把 vector accelerator 扩展为可讲清楚的 near-memory/SOM accelerator 原型。

本次 RTL 改动：

- `rtl/vec_accel_regs.v`
  - 新增 `NEURON_COUNT`、`NEURON_STRIDE`、`NEURON_INDEX`。
  - 新增只读 `SOM_BEST_DIST`、`SOM_WINNER`。
  - `VERSION` 更新到 `0x0004_0000`，`CAPABILITY` 标记 SOM 能力。

- `rtl/vec_accel_core.v`
  - 新增 `op_mode=5 SOM_RECALL`。
    - `SRC0_BASE` 存输入向量 X。
    - `SRC1_BASE` 存 weight matrix。
    - 地址映射：`W_addr = SRC1_BASE + neuron * NEURON_STRIDE + element * SRC1_STRIDE`。
    - 对每个 neuron 计算 L1 distance，输出 winner index 和 best distance。
  - 新增 `op_mode=6 SOM_UPDATE`。
    - 对 `NEURON_INDEX` 指定的 neuron weight vector 原地更新。
    - 更新公式：`W_new = W_old + ((X - W_old) >> SCALE_SHIFT)`。
    - 支持 word/int16/int8 packed 数据宽度。
  - 新增 `ERROR_CODE=10`，用于非法 SOM neuron 配置。

- `rtl/vec_accel_top.v`
  - 连接新增 SOM 配置和结果信号，AHB 顶层端口保持不变。

- `verif/env/vec_accel_sva.sv`
  - 更新寄存器白名单和可写寄存器表。

- `verif/agent/ahb/ahb_slv_generator.sv`
  - 旧 illegal op case 从 `op=5` 改到 `op=7`，因为 `op=5/6` 已分配给 SOM。

VNC/VCS smoke regression：

```text
TEST PASS
Scoreboard PASS count  = 1844
Scoreboard ERROR count = 0
Functional coverage    = 98.68%
```

当前说明：

- 这一步完成的是 RTL 功能接入和旧回归兼容。
- SOM_RECALL/SOM_UPDATE 还需要下一步补 dedicated testcase、scoreboard 参考模型和 coverage bins。
- 该实现属于数字 RTL near-memory compute，不声称实现论文中的 8T SRAM bitcell CIM macro。

## 2026-06-05 - SOM directed verification and architecture documentation

完成 SSP vector/SOM accelerator 版本的优先级 1-4：

- 补充 SOM directed testcase：
  - `SOM_RECALL` word case：3 个 neuron，检查 `SOM_WINNER/SOM_BEST_DIST/RESULT`。
  - `SOM_UPDATE` word case：检查指定 neuron weight 原地更新。
  - `SOM_RECALL` packed int16 case：覆盖 packed lane 的 winner search。
  - `SOM_UPDATE` packed int8 case：覆盖 packed lane 的 update datapath。
- scoreboard 增强：
  - 增加寄存器模型，跟踪 source/destination/stride/config/neuron 配置。
  - 增加 SOM recall/update reference model。
  - 对 `SOM_BEST_DIST`、`SOM_WINNER` 和更新后的 weight memory 做比较。
- functional coverage 增强：
  - 增加 `data_width`、`neuron_count`、`som_winner_pos` coverpoint。
  - 增加 op/data_width 和 SOM/neuron cross。
- 新增 `docs/architecture.md`：
  - 记录顶层结构、寄存器表、op mode、packed datapath、SOM memory layout、recall/update FSM 行为和验证结构。
- testbench 结束条件增强：
  - driver 增加 `done` 和 `packets_sent`。
  - test 不再固定等待 5000 cycles，而是等待 driver 完整发完 packet 后再 report。

VNC/VCS regression：

```text
Generation finished, packets = 2574
Driver done, total packets sent = 2574
TEST PASS
Scoreboard PASS count  = 2413
Scoreboard ERROR count = 0
Functional coverage    = 88.54%
```

当前说明：

- 新增 SOM coverage cross 后，functional coverage 百分比下降是预期现象，因为 coverage space 扩大了。
- 下一步如果继续拉 coverage，应补 illegal neuron config、SOM small_many neuron、更多 op/data_width 组合，或把不属于目标的 cross bin 标为 ignore。

## 2026-06-05 - DC sanity script added

新增 synthesis sanity 脚本：

- `syn/dc_sanity_vec_accel.tcl`
  - 读取 AHB slave interface、vector/SOM register block、vector/SOM core、top。
  - `analyze/elaborate/link/check_design/report_area/report_reference`。
  - 该脚本用于 DC 语法和结构可综合性检查，不做工艺库映射。
- `syn/sram_core_blackbox.v`
  - synthesis-only SRAM core blackbox。
  - 原 `RA1SH.v` 是仿真 SRAM 行为模型，包含 `!==`、timing check、specify 等仿真用结构，不应直接送入 DC。
  - 工程上 SRAM array 应由 memory compiler macro 或 blackbox boundary 接入。

VNC/DC sanity result：

```text
Presto compilation completed successfully.
Elaborated 1 design.
Current design is now 'vec_accel_top'.
check_design completed with warnings, no fatal error.
sram_core is treated as blackbox boundary.
```

当前说明：

- 这说明 RTL 已经具备进入 DC 前端读入/展开检查的基础。
- 真正 `compile` 到 gate-level netlist 仍需要标准单元 `.db` 工艺库、SRAM macro `.db/.lib`、约束文件 SDC、时钟/IO delay/false path/multicycle path 设置。
- 下一步若做 DC 正式综合，需要先准备 library setup 和约束，而不是继续使用仿真 SRAM 行为模型。

## 2026-06-06 - Constrained-random and multi-seed regression baseline

为验证闭环建立第一版受约束随机和多种子回归能力：

- generator 新增真正调用 `ahb_slv_pkt.randomize()` 的随机 SRAM write/read pair。
- generator 新增随机向量任务，随机选择 op、length 和 IRQ enable。
- 新增 `verif/sim/run_regression.sh`，自动执行多个 seed、检查 TEST PASS、scoreboard error 和 SVA failure，并合并 VCS code coverage。
- 升级 `parse_vcs_cov.py`，支持读取并按位合并多个 seed 的 VCS coverage XML。
- Makefile 新增 `make regress` 和 `make regress_cov`。

首轮结果：

```text
Seeds                     = 101 202 303 404 505
Random SRAM pairs         = 50 / seed
Random vector cases       = 4 / seed
Regression PASS seeds     = 5
Regression FAIL seeds     = 0
Functional coverage       = 89.58%

Main line coverage        = 71.24%
Main branch coverage      = 86.43%
Main condition coverage   = 84.44%
Main FSM coverage         = 75.00%
Main toggle coverage      = 42.57%
```

该结果作为验证闭环的首个可重复基线。下一步将针对未覆盖功能组合和代码路径补充 testcase，而不是仅增加随机数量。

## 2026-06-06 - Directed verification closure pass

针对首轮覆盖率缺口补充定向 testcase：

- 补充 `VERSION/CAPABILITY/ERROR_CODE`、stride、CONFIG、neuron 配置寄存器读回。
- scoreboard 新增非零读值检查，验证合法任务完成后的 `CYCLE_COUNT`，并精确检查 `ELEMENT_COUNT`。
- 补充 IRQ enable/mask/pending/clear/output 行为。
- 补充 `VMUL`、non-unit stride、packed INT16/INT8，以及 signed/saturate/round 全部计划内用例。
- 补充 stride zero/misaligned/range、illegal data width、illegal neuron 配置及错误码检查。
- 补充 4-neuron SOM recall winner-last 场景。
- 修正普通 vector testcase 的 coverage 元数据，避免其被错误标记为前一个 SOM case 的配置。

VCS 五种子回归结果：

```text
Seeds                     = 101 202 303 404 505
Random SRAM pairs         = 50 / seed
Random vector cases       = 4 / seed
Regression PASS seeds     = 5
Regression FAIL seeds     = 0
Functional coverage       = 97.59% / seed

Main line coverage        = 88.34%
Main branch coverage      = 95.48%
Main condition coverage   = 86.35%
Main FSM coverage         = 75.00%
Main toggle coverage      = 50.09%
```

当前 test plan 共提取 53 个测试点，状态为 `53 DONE / 0 PARTIAL / 0 TODO`。验证已覆盖主要 AHB/SRAM 协议行为、计算模式、寄存器控制、错误保护和 SOM 边界。后续提高重点不再是补功能测试点，而是根据 VCS uncovered report 审查不可达代码，并定向补齐有价值的核心 FSM/line/condition 缺口。

## 2026-06-23 - Artix-7 100T FPGA bring-up framework and Vivado synthesis

### Hardware basis and FPGA framework

Added `fpga/xilinx_a7_100t/` as an isolated non-project Vivado flow for the
hardware described in `docs/hardware/`.

- The Allegro hardware netlist identifies the fitted device as
  `XC7A100T-2FGG484`; the flow therefore targets `xc7a100tfgg484-2`.
- The board smoke top uses the 50 MHz oscillator `FPGA_SYSCLK_50M` on `W19`.
  `FPGA_CLK` is the JTAG `TCK_0` connection and is not used as a fabric clock.
- The smoke LEDs use the board nets routed to `F20`, `D21`, and `E21`.
  The configuration `DONE` LED is intentionally excluded.
- `fpga_ai_accel_smoke_top` instantiates `ai_accel_top` and a synthesizable
  AXI4-Lite initiator. The initiator writes `[1,2,3,4]` and `[5,6,7,8]` into
  scratchpad, runs `VDOT_INT8`, and checks both `RESULT` and the scratchpad
  output against `70`.
- The accelerator master AXI port is tied off only for this first on-board
  smoke test. DMA, external descriptor fetch, DDR3, and MIG are explicitly
  outside this test's scope.
- Added scripts for IP synthesis, smoke synthesis, implementation/bitstream,
  and JTAG programming. The programming script requires exactly one visible
  JTAG FPGA device and refuses ambiguous chains.
- The PowerShell entry script resolves `vivado.bat` from `PATH`, `VIVADO_HOME`,
  or the standard `D:\Xilinx\Vivado\2024.1` / `C:\Xilinx\Vivado\2024.1`
  locations. `-VivadoPath` supports any non-standard installation.

### Vivado 2024.1 synthesis results

Vivado `2024.1` was run on 2026-06-23 against `xc7a100tfgg484-2`.

| Target | Result | Timing | Key utilisation | DRC interpretation |
| --- | --- | --- | --- | --- |
| `ai_accel_top` at 100 MHz | Synthesis completed: 0 errors, 0 critical warnings, 58 warnings | Fails: WNS -4.456 ns, TNS -91995.164 ns, 183923 failing endpoints | 31684 LUT (49.97%), 23552 LUTRAM (123.96% of available LUTRAM), 2257 FF, 3 DSP, 0 BRAM | Raw IP has 323 unconstrained top-level I/O, more than the device's remaining 285 user I/O. This is expected for an unwrapped AXI IP and must not be used directly for bitstream generation. |
| `fpga_ai_accel_smoke_top` at board 50 MHz | Synthesis completed: 0 errors, 0 critical warnings, 66 warnings | Meets: WNS +6.102 ns, TNS 0.000 ns; hold slack +0.129 ns | 16767 LUT (26.45%), 11969 LUTRAM (62.99%), 1096 FF, 3 DSP, 0 BRAM, 4 IOB | All four top-level board I/O are LOC-constrained. The 15 DRC warnings are DSP pipeline recommendations (`DPIP-1`, `DPOP-1`, `DPOP-2`), not bitstream-blocking violations. |

Generated artefacts:

- `fpga/xilinx_a7_100t/build/ip_synth/ai_accel_top_synth.dcp`
- `fpga/xilinx_a7_100t/build/ip_synth/reports/`
- `fpga/xilinx_a7_100t/build/smoke_synth/fpga_ai_accel_smoke_top_synth.dcp`
- `fpga/xilinx_a7_100t/build/smoke_synth/reports/`

### Decision and next step

The 50 MHz smoke wrapper is synthesis-clean and has adequate setup margin for
implementation and first board download. The 100 MHz raw-IP result is not a
board sign-off: the full scratchpad infers distributed RAM beyond the device's
dedicated LUTRAM capacity and its external AXI interface is intentionally not
pin-constrained. Before exposing DMA/DDR on the board, replace or partition the
scratchpad into BRAM-backed storage and add the appropriate memory subsystem
and XDC constraints. The immediate board command is:

```powershell
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target bitstream
.\fpga\xilinx_a7_100t\scripts\run_vivado_synth.ps1 -Target program
```

## 2026-06-24 - Project renamed to CIMForge

Renamed the local repository and project identity from
`sram-controller-design-based-on-AHB-bus-main` to
`cimforge-fpga-accelerator`.

The project-facing name is **CIMForge: FPGA Compute-in-Memory Accelerator**.
It communicates the FPGA implementation target and the CIM-inspired
near-memory compute focus while remaining concise enough for a resume, a
repository title, and an interview discussion. The original upstream URL in
`NOTICE.md` remains unchanged for attribution.

## 2026-06-25 - FPGA bring-up flow cleanup and update log ordering

### FPGA flow cleanup

继续整理 `fpga/xilinx_a7_100t/` 上板验证框架，使其从“可综合脚本”补齐到“可实现、可下载”的第一版 bring-up flow。

本次整理点：

- 确认 `program_smoke_bitstream.tcl` 与 `run_vivado_synth.ps1 -Target program` 连接完整。
- `run_vivado_synth.ps1` 支持从 `PATH`、`VIVADO_HOME`、常见 Vivado 安装路径或 `-VivadoPath` 找到 `vivado.bat`。
- `program` 模式支持 `-Bitstream` 覆盖默认 bit 文件路径，并支持 `-HwServerUrl` 指向远程 hardware server。
- `program_smoke_bitstream.tcl` 会检查 bitstream 是否存在、打开 hardware manager、连接 JTAG，并在发现多个 JTAG FPGA 设备时拒绝自动选择，避免误下载。
- Vivado Tcl 中 `read_verilog` 改为列表展开形式，避免 non-project batch flow 把多个文件路径当成单个参数。
- `read_xdc` 调整到综合前读取，使板级时钟/IO 约束进入综合阶段；`CONFIG_VOLTAGE/CFGBVS` 保留在综合后通过 Tcl 设置，避免 XDC 在 `current_design` 未稳定时依赖设计对象。
- `README.md` 补充 program/download 入口说明。

### Update log cleanup

整理 `docs/project_update_log.md`：

- 修复文件开头说明文字的编码损坏问题。
- 按日期从过去到现在重排所有 `## YYYY-MM-DD` 更新块。
- 同一日期内按项目演进逻辑排序，便于阅读项目从 AHB/SRAM、vector accelerator、SV 验证、AI/DMA/IP 化到 FPGA bring-up 的推进过程。

### 当前限制

本地 PowerShell 环境未提供 Vivado 可执行命令，因此本次只完成脚本和文档层面的静态整理；真正的 bitstream 生成和 JTAG 下载仍需在 Vivado 环境中执行。

## 2026-06-26 - AI accelerator architecture closure and bring-up notes

### Current implemented architecture

Confirmed that the current main architecture has moved beyond the earlier register-configured AHB vector/SOM accelerator. The latest implemented RTL path is the independent `ai_accel_top` AI accelerator subsystem:

```text
AXI4-Lite control/register interface
  + descriptor command queue
  + AXI4 master DMA load/store
  + 64KB scratchpad buffering
  + INT8 VDOT/GEMV/GEMM_TILE compute datapath
  + scratchpad completion queue
  + IRQ/status/error/performance reporting
```

The older `vec_accel_top` path is still useful as project background and a bring-up-friendly register-configured accelerator, but the current project headline should be `CIMForge: AXI/DMA scratchpad INT8 AI accelerator IP`.

### Implemented RTL modules

| Module | Role |
|---|---|
| `rtl/ai_accel_top.v` | New AI accelerator top-level integration |
| `rtl/axi_lite_reg_if.v` | AXI4-Lite register and scratchpad access front-end |
| `rtl/ai_accel_regs.v` | Control/status, doorbell, command queue, completion queue, DMA config, IRQ, error and counters |
| `rtl/axi_dma_master.v` | AXI4 master DMA load/store between external memory and scratchpad |
| `rtl/ai_scratchpad.v` | 64KB scratchpad with host/debug and internal access paths |
| `rtl/ai_desc_fetch.v` | Scratchpad descriptor fetch |
| `rtl/axi_desc_fetch.v` | External-memory descriptor fetch through AXI read channel |
| `rtl/ai_int8_compute_core.v` | INT8 VDOT/GEMV/GEMM_TILE datapath |
| `rtl/ai_completion_writer.v` | Completion entry writer into scratchpad completion queue |

### Software-visible execution model

The AI path supports both direct register start and descriptor/doorbell start. The more important industrial-style flow is:

```text
1. Software prepares input/weight/output buffers in external memory or scratchpad.
2. Software writes one 64-byte command descriptor.
3. Software configures CMDQ_BASE/CMDQ_HEAD/CMDQ_SIZE and writes DOORBELL.
4. Hardware fetches the descriptor from scratchpad or external memory.
5. DMA optionally loads tensor tiles from external memory into scratchpad.
6. INT8 compute core executes VDOT/GEMV/GEMM_TILE from scratchpad data.
7. DMA or scratchpad writer stores results.
8. Completion writer records task_id/status/error/result/element_count.
9. Registers update STATUS/ERROR_CODE/IRQ_STATUS/performance counters.
```

### Descriptor and completion semantics

The command descriptor is 64 bytes. The key fields are:

| Word | Field |
|---:|---|
| 0 | `op` and `task_id` |
| 1 | `src0_base` |
| 2 | `src1_base` |
| 4 | `dst_base` |
| 5 | `M/N` |
| 6 | `K_WORDS/LENGTH` |
| 9 | `QUANT_ACT` |

The scratchpad completion entry is 16 bytes:

| Word | Field |
|---:|---|
| 0 | `task_id` |
| 1 | `status/error` |
| 2 | `result` |
| 3 | `element_count` |

`CMDQ_SIZE>0` enables ring behavior:

```text
descriptor_addr = CMDQ_BASE_LO + CMDQ_HEAD * 64
completion_addr = CPLQ_BASE_LO + CPLQ_TAIL * 16
```

The first implementation is a single-outstanding ring consumer. It supports head/tail wrap and task_id propagation, but not a multi-outstanding scheduler.

### DMA and compute scope

DMA scope:

- 32-bit AXI4 INCR burst.
- Single outstanding transaction.
- External memory to scratchpad load.
- Scratchpad to external memory store.
- Multi-burst transfer.
- 4KB boundary split.
- AXI response error capture.

Compute scope:

- `VDOT_INT8`
- `GEMV_INT8`
- `GEMM_INT8_TILE`
- packed signed INT8 lanes, four lanes per 32-bit word
- accumulator, quantization shift and ReLU-style post-process

### Bring-up notes folded into this log

The temporary `docs/bringup_register_config.md` content was folded into this update log and removed to avoid documentation fragmentation. For the old `vec_accel_top` path, the safe explanation remains:

```text
AHB-Lite register control
  + AHB-visible scratchpad SRAM
  + register-configured vector/SOM compute engine
  + status/done/error/irq completion
```

For the latest `ai_accel_top` path, use:

```text
AXI-Lite configured, descriptor-driven scratchpad INT8 accelerator with DMA,
command/completion queues, VDOT/GEMV/GEMM_TILE compute and IRQ/error reporting.
```

### Verification entry

The current smoke entry is:

```bash
cd verif/sim
make ai_smoke AI_RANDOM_CASES=6 AI_SEED=20260621
```

The existing smoke scope covers AXI-Lite access, scratchpad access, descriptor fetch, command queue wrap, completion entry, VDOT/GEMV/GEMM, DMA load/store, multi-burst transfer, 4KB split, AXI response error injection and random INT8 GEMV/GEMM checks.

### VCS rerun on 2026-06-26

Re-ran the AI accelerator smoke test on the VNC/VCS environment:

```bash
cd ~/sv_project/ai_accel_work/run/verif/sim
make ai_smoke AI_RANDOM_CASES=6 AI_SEED=20260621
```

Result:

```text
TEST PASS
```

The log covered version readback, AXI-Lite split access and SLVERR, VDOT, GEMV,
GEMM tile, scratchpad command queue wrap, completion queue entries, DMA load,
DMA store, multi-burst DMA, 4KB boundary split, AXI response error injection,
external descriptor fetch, invalid descriptor completion, and random INT8
GEMV/GEMM checks.

## 2026-07-15 - 补录：A1 冻结、A2 RTL 收敛与综合现状

> 本节补录 2026-06-26 之后已经完成、但此前未写入本日志的工作。后续本轮
> 上板 P0 与 RTL 加固将继续按里程碑追加记录。

### 调度职责与顶层集成

- 将 queue、descriptor、compute launch、completion 生命周期调度从
  `ai_accel_regs` 完整迁移到 `ai_command_processor`。
- `ai_accel_regs` 仅保留 AXI-Lite 配置寄存器、doorbell/控制脉冲、sticky
  状态与 IRQ 回写。
- `ai_spad_arbiter` 成为 scalar scratchpad scheduler 端口的唯一仲裁者，固定
  优先级为 descriptor、completion writer、compute、DMA；顶层不再保留独立
  scratchpad mux。
- command processor 统一管理 `CMDQ_HEAD` 和 `CPLQ_TAIL` 推进，并确保
  completion 四个 word 全部提交后才发布 tail。

### A1/A2 版本与文档

- 从已验证的 A1 提交 `a5d64a8` 创建 `a1-baseline` tag；隔离 XSim AI smoke
  结果为 `TEST PASS`。
- A2 的主要提交为：
  - `75b849f`：tile pipeline 与卷积数据流；
  - `0a38bf3`：A2 规格与卷积随机回归收敛；
  - `c034c8c`：统一 AXI AI 架构文档。
- 当前 A2 设计冻结 tag 为 `a2-rtl-design-complete`，指向 `c034c8c`。
- 将原 `CIMFORGE_A2_ARCHITECTURE.md` 合并到 `docs/architecture.md`，根目录
  README 明确 AXI-Lite/AXI4 AI accelerator 是当前主线；AHB 仅为 legacy
  教学/回归路径。

### A2 数据流与计算能力

- descriptor v2、两上下文 tile pipeline、ping-pong buffer ownership、
  load/compute/store 依赖与性能计数器已经接入。
- 支持 2D DMA、4KB 边界切分、back-pressure、保护检查和 completion 错误回写。
- 支持 VDOT、GEMV、GEMM tile、Conv3x3 im2col、DWConv3x3，以及 bias、
  quantization shift、ReLU/ReLU6 后处理。
- Python golden model 随机回归 1000 cases 通过；XSim A2 随机 RTL 回归
  20 cases 通过。

### FPGA 综合实测

- Artix-7 A2 综合：7351 LUT、4735 FF、16 RAMB36、8 DSP；setup WNS
  `-10.342 ns`，说明该器件/当前组合路径尚未达到目标频率。
- XCZU15EG（`xczu15eg-ffvb1156-2-i`）重新综合：`synth_design` 0 error、
  0 critical warning；7629 LUT、4739 FF、16 RAMB36E2、8 DSP48E2；setup
  WNS `+0.195 ns`、TNS 0。
- XCZU15EG 综合后 hold 为 WHS `-0.055 ns`、THS `-49.743 ns`、1918
  endpoints。该结果来自未布局的 standalone synth timing，需通过 OOC/post-route
  实现确认并完成 hold closure，不能作为最终上板时序结论。
- 当前 setup 最差路径位于 `ai_int8_compute_core` 动态地址乘法及保护/仲裁到
  scratchpad BRAM write-enable 的组合链；standalone 顶层还存在未绑定管脚引起的
  NSTD/UCIO DRC。

### 本轮开始前的已知 P0 遗留项

- 将动态地址乘法改为增量地址生成，并以 post-route 报告完成 setup/hold 验收。
- 建立 XCZU15EG PS/PL AXI、时钟、复位、IRQ 和地址映射集成流程，消除将裸
  accelerator 顶层当板级 top 导致的 IO DRC。
- 加固 AXI reset/abort、scratchpad 同址冲突语义和 queue/back-pressure 边界。
- 补齐多 tile、奇数 tile、queue wrap/full、abort/reset、端口碰撞压力回归。
- 提供 bitstream/ILA/裸机寄存器与 DDR bring-up 资产，形成可复现的上板路径。

## 2026-07-15 - 本轮里程碑 1：XCZU15EG 板卡与 RTL P0 审计

### 板卡资料核对

- 检查 `docs/hardware/xczu15eg/XCZU15EG_SCH_0515.pdf`，共 33 页，并实际
  渲染核对第 1、3、4、25 页：
  - PS reference clock 为 33.3333 MHz；
  - PS MIO/QSPI/eMMC/USB/以太网均由 PS bank 500/501/502 连接；
  - PS DDR4 SODIMM 由 bank 504 连接，是 accelerator 通过 PS HP/HPC AXI
    端口访问 DDR 的目标；
  - 板上还提供 200 MHz PL DDR4 差分时钟，但首版 accelerator bring-up 不依赖
    额外 PL DDR 控制器。
- 检查厂家 `1.mem_test` 工程，确认器件为
  `xczu15eg-ffvb1156-2-i`、PS `pl_clk0` 为 100 MHz，并存在已经验证过的
  ZynqMP PS DDR/MIO 配置。后续板级工程将复用该 PS 配置，再显式开启：
  - PS `M_AXI_HPM0_FPD` 到 accelerator AXI-Lite control；
  - accelerator AXI master 到 PS `S_AXI_HP0_FPD`/DDR；
  - `pl_ps_irq0`；
  - `proc_sys_reset` 生成同步释放的 PL reset。

### RTL/流程审计结论

- 最高优先级组合路径来自三处通用乘法地址生成：
  - `ai_int8_compute_core` 的 row/col/K 地址乘法；
  - `ai_banked_compute_core` 的 `row * length`；
  - `ai_tile_pipeline` 的 `stride * tile_index`。
  这些地址均可用启动时基址和逐输出/逐 tile 增量寄存器替代。
- `ai_scratchpad` 已采用保守而确定的冲突语义：scheduler/banked 端口活动时
  host/debug 访问返回错误并不落 RAM；scheduler 端口优先，因此本轮重点是补齐
  冲突回归和文档，而不是引入不确定的 TDP 同址读写行为。
- 当前 `axi_dma_master` 没有 abort 输入；tile pipeline 的 abort 又被固定为 0。
  这会使软件 abort 后已有 AXI burst 仍继续工作，是上板前必须加固的真实协议风险。
- XCZU15EG 现有脚本只做裸顶层 synth，未使用 OOC/post-route，因此 NSTD/UCIO
  和 synth-only hold 不能代表板级结果。需要同时提供 IP OOC 实现和 PS/PL 板级实现
  两条可复现流程。
- 当前仓库没有 bare-metal 软件目录；需要补齐寄存器头文件、cache flush/invalidate、
  DDR descriptor/data/completion smoke 和超时/错误诊断。

## 2026-07-15 - 本轮里程碑 2：地址生成与 abort/AXI 写通道加固

### RTL 更新

- `ai_int8_compute_core` 新增当前 A/B vector、bias 和 output 的增量地址寄存器，
  移除 scratchpad 请求路径上的 `row * N * K`、`row * K` 和 `col * K`。
- `ai_banked_compute_core` 使用逐行递增的 weight/output 基址，移除
  `row * length`；同时接入统一 abort 和 watchdog。
- `ai_tile_pipeline` 使用 next-load/next-store 外部地址寄存器，移除
  `stride * tile_index`，保持 tile 乱序执行、顺序 store 的原有 ownership 语义。
- `core_abort` 已接入 command processor、tile pipeline、scalar、banked core 和 DMA；
  CMDQ 在 fetch/decode/run 阶段收到 abort 后停止继续消费后续 descriptor。
- `axi_dma_master` 增加协议安全的 abort：
  - AR 未握手时可取消；AR 已握手后拉高 RREADY drain 到 RLAST；
  - AW 已握手后继续发送完整 W burst 并等待 B，再报告 abort；
  - scratchpad store 读取错误改为 deferred error，避免 AW 已提交后提前退出而
    将 AXI slave 留在未完成 transaction；
  - read response/protection 错误也会 drain 已提交 burst。
- scratchpad 冲突策略保持 scheduler 优先、host 返回 SLVERR，不改变 RAM 同址
  读写语义。

### 即时验证

执行 Vivado XSim 对应的完整 AI smoke（含默认随机回归）：

```powershell
xvlog -sv -d VCS -i ../agents/axi_lite -i ../agents/ai_dma \
  -f ai_accel.f ../env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv
xelab tb_ai_accel_smoke -s ai_p0_smoke -debug typical
xsim ai_p0_smoke -runall
```

结果：`TEST PASS`。覆盖 VDOT/GEMV/GEMM、Conv1x1/Conv3x3/DWConv3x3、
banked compute、ping-pong tile、1D/2D DMA、4KB split、descriptor v2、queue
wrap、保护错误和随机计算。首次运行发现 deferred error 三目表达式会将 idle X
传播到正常 store 数据，修正为始终锁存有效 `spad_rdata` 后复跑通过。

## 2026-07-15 - 本轮里程碑 3：P0 压力回归与验证驱动加固

### 新增边界场景

- 将 ping-pong 测试从 2 个 tile 扩展为 3 个 tile，覆盖 buffer0/buffer1 交替、
  buffer0 再利用、奇数 tile 收尾和增量 input/output stride，结果依次为
  `10/8/12`，`TILE_COMPLETED=3`。
- 增加 DMA load 的 in-flight abort：AR 接受后发出 `ABORT`，DMA 禁止继续写
  scratchpad、保持 `RREADY` 到 `RLAST`，最后报告 `DMA_ERROR_CODE=5`。
- 增加 DMA store 的 in-flight abort：AW 接受后仍发完完整 W burst 并接收 B，
  然后报告 `DMA_ERROR_CODE=5`，不遗留 write outstanding。
- 增加 AXI read 进行中的系统复位恢复。板级假设是 accelerator 与 PS AXI fabric
  由同一 `proc_sys_reset` 同步释放；复位后版本寄存器可读且 DMA/AXI 均为空闲。

### AXI-Lite 验证驱动修复

新增 abort 用例暴露了原通用写任务的两个相位竞态：

1. 发 AW/W 时 `BREADY` 仍为 1，快速 B response 可能在任务开始等待前已被消费；
2. 若任务恰好从上升沿调用，VALID 在该上升沿之后才拉高、下一个下降沿便撤销，
   中间没有采样上升沿，实际未发生 AW/W handshake。

`verif/agents/axi_lite/axi_lite_tasks.svh` 已改为请求前背压 B、统一在下降沿发起
AW/W、确保 VALID 跨越至少一个上升沿，并给 AW/W/B 各加入 100-cycle 超时，避免
回归环境本身无限挂死。

### 回归证据

使用 Vivado 2024.1 绝对路径执行 `xvlog/xelab/xsim`；当前 PowerShell 未自动继承
Vivado `bin` 到 PATH，因此不能只写裸命令。最终完整 `ai_p0_smoke` 结果为
`TEST PASS`，包含默认 20 轮 GEMV/GEMM/Conv3x3/DWConv3x3 随机对拍及上述新增场景。
`git diff --check` 无空白错误，只有 Windows 工作区的 LF/CRLF 提示。

## 2026-07-15 - 本轮里程碑 4：XCZU15EG 上板资产初版

- `ai_accel_top` 已增加 AXI4-Lite、AXI4、clock/reset 和 IRQ 的 Vivado interface
  metadata，使其能作为 Block Design module reference 被正确分组连接。
- 增加 XCZU15EG standalone OOC synth/post-route 两级流程；post-route 脚本同时报告
  setup、hold、utilization、DRC、methodology、power，并在负 slack 时失败。
- 增加 PS/PL 板级工程脚本：从厂商 `mem_test.xpr` 克隆板卡 PS DDR/MIO 配置，连接
  HPM0 control、HP0 DDR、100 MHz PL clock、同步 reset 和 IRQ，控制窗固定为
  `0xA0000000..0xA001ffff`，并集成 8 probe ILA。
- 增加 Vitis standalone A53 bare-metal smoke：含寄存器头文件、cache
  flush/invalidate、DDR DMA load/store、external descriptor、scratchpad completion、
  VDOT=70 和 timeout/error 诊断。
- 重写 `fpga/xczu15eg/README.md`，明确 OOC、板级 bitstream/XSA/ILA、软件导入步骤、
  32-bit DDR 地址限制和 AXI reset/abort 规则。

本节记录的是资产已经创建；板级 Tcl、bitstream 和 XSA 必须在实际 Vivado 运行通过后
才能把状态提升为“已验证”。

### completion tail 语义修复

在本轮 RTL diff 审计中发现：`CPLQ_SIZE=0` 时 direct/one-shot 命令没有写 completion，
但旧逻辑仍对 `CPLQ_TAIL` 自增，原 smoke 还把该错误行为写成了期望值。现已删除
`ai_command_processor` 中所有“未启用 completion 仍推进 tail”的分支，并增加两条
明确回归：direct command 后 tail 保持 0，禁用 completion queue 的 descriptor 命令后
tail 也保持 0。修复后重新执行完整 XSim，包含 abort/reset/随机回归，结果 `TEST PASS`。
这使实现重新满足“只有四个 completion word 全部提交后才能发布 tail”的所有权约束。

### OOC post-route 首轮试跑

队列 tail 修复前生成的 OOC DCP 已完成一次 XCZU15EG place/route，用于验证流程和
关键路径改造是否有效：100 MHz 下 setup slack `+0.903 ns`、hold slack `+0.023 ns`，
报告生成过程 0 error。由于随后修复了 `ai_command_processor` 的 tail 语义，本结果只作
趋势证据，不作为最终签核；已按最新 RTL 重新启动 synthesis，之后必须再跑一次
post-route 才能更新最终 closure 状态。

### bare-metal 交叉编译检查

本机 Vitis 2024.1 提供 `aarch64-none-elf-gcc`。第一次直接引用 Vitis 通用
standalone 头文件时因缺少由 BSP 生成的 `bspconfig.h` 失败；随后改用厂商
`mem_test` 已导出的 A53 standalone BSP include，并执行：

```powershell
aarch64-none-elf-gcc -std=c11 -Wall -Wextra -Werror -fsyntax-only `
  -I sw/include -I <vendor-a53-bspinclude> sw/baremetal/cimforge_bringup.c
```

结果 0 error/0 warning。该结果确认 C 类型、cache API、AArch64 barrier 和寄存器头文件
可编译；最终链接/运行仍必须使用本项目板级 XSA 生成的新 BSP。软件还增加了 descriptor、
input、weight、output 四类指针的高 32-bit 检查，避免 A2 的 32-bit AXI 地址被静默截断。

### PS/PL Block Design 实际验证

为 `build_board.tcl` 增加 `CIMFORGE_VALIDATE_ONLY=1` 快速模式，并用 Vivado 2024.1
实际迭代验证。过程中发现并修复三类问题：

1. module-reference AXI segment 默认被自动分配成 4 GiB，`set_property` 无法改成
   128 KiB；改用 `assign_bd_address -force -offset 0xA0000000 -range 128K`。
2. 厂商 PS 的 PL0 实际频率为 `99,999,001 Hz`，顶层 metadata 写死
   `100,000,000 Hz` 会造成 SmartConnect frequency DRC；移除固定 `FREQ_HZ`，让频率
   从 PS clock 正确传播。同时过滤 Vivado 2024.1 中只读的 PS 派生配置属性。
3. native ILA 若直接探测 module-reference AXI 的输入成员，会把 ready/response sink
   从 interface net 拆成无源标量网并绑 0；改为只探测 accelerator 驱动的 IRQ、
   ARVALID/RREADY/AWVALID/WVALID/WLAST/BREADY 和 AXI-Lite BVALID。

最终 `board_validate4.log` 为 0 error、0 critical warning，明确显示 control segment
`0xA0000000 [128K]`、accelerator M_AXI 到 `HP0_DDR_LOW [2G]`，并输出
`CIMForge board block design validation completed.`。DDR high 因 A2 master 地址宽度为
32 bit 被排除，这是已记录的架构限制，不是连接失败。

### 最新 RTL 的 XCZU15EG closure

在 completion tail 修复后重新生成 OOC synthesis DCP 并重新执行完整 post-route：

- synthesis：7,584 LUT、4,907 FF、16 RAMB36E2、0 DSP48E2；setup `+1.940 ns`，
  hold `+0.076 ns`；0 error、0 critical warning；
- routed：7,471 LUT、4,907 FF、16 RAMB36E2、0 DSP48E2；setup `+1.335 ns`，
  hold `+0.026 ns`；DRC violations 0；
- methodology 只保留 OOC 顶层未设置外部 input/output delay 的 `TIMING-18` warning，
  板级时钟和互连约束由已验证的 PS/SmartConnect BD 继续复核。

因此状态提升为“XCZU15EG standalone IP 100 MHz setup/hold closure PASS”。随后只移除了
module-reference metadata 中的固定 `FREQ_HZ`，让板级 PS 的 99,999,001 Hz 实际频率
传播；该属性变化不改变综合逻辑和时序路径。整板 bitstream 与实板运行仍未宣告完成。

### 整板 bitstream/XSA/LTX 完成

执行完整 `build_board.tcl`。Windows 本地 run scheduler 在 `launch_runs impl_1` 后只留下
queue marker，未自动创建 implementation 子进程；使用 Vivado 已生成、参数完全相同的
`impl_1/runme.bat` 隐藏启动该 run，原 batch 进程继续 `wait_on_run` 并完成后续报告和
导出。最终证据：

- `cimforge_system_wrapper.bit`（约 27.4 MiB）生成成功；
- `cimforge_board.xsa` 和 `cimforge_board.ltx` 生成成功；
- routed utilization：17,318 LUT、19,223 FF、40 RAMB36E2、0 DSP48E2；
- routed timing：setup `+1.092 ns`、hold `+0.011 ns`，setup/hold failing endpoint 均为 0；
- bitgen：0 error、0 critical warning；
- routed DRC：0 error、4 warning。3 个 `PDCN-1569` 和 1 个 `RTSTAT-10` 全部位于
  Vivado 自动生成的 debug hub，不在 accelerator/PS DDR/AXI 数据路径。

因此“可复现生成整板 bitstream/XSA/ILA + 100 MHz setup/hold closure”已经完成。
“实体板 DDR DMA/IRQ/ILA/裸机 PASS”仍需拿到板卡后执行 `sw/baremetal` 才能关闭。

同时复跑 Python golden model：`--cases 1000 --seed 12345`，结果 `PASS`；两份新增
PowerShell wrapper 经 parser 检查无语法错误。根 README 已更新为当前 XCZU15EG 结果，
不再把早期 Artix-7 负 slack 当作当前主目标状态。

### 本地 Git 提交范围确认

提交前执行 staged diff、空白错误和敏感信息检查：计划提交 21 个实现、验证、软件、
FPGA 流程及文档文件，`git diff --cached --check` 通过，未发现账号、口令、服务器地址、
许可证或 token。`docs/hardware/**`、厂商 demo/资料和 Vivado 生成目录均未进入暂存区，
保留工作区中原有的用户修改。此次本地提交信息为
`Harden XCZU15EG AI accelerator bring-up`。

## 2026-07-15 - 当前架构、优势与验证阶段复核

- 只读核对 `README.md`、`docs/architecture.md`、XCZU15EG 构建说明、AI smoke、
  性能计数器 RTL 和验证目录，确认当前主线为 AXI-Lite 控制面、AXI4 数据面、
  command/completion queue、统一 scratchpad arbiter、双 context tile pipeline 和
  scalar/4-bank INT8 compute。
- 确认 AI 主线现有验证是 directed/random SystemVerilog smoke + Python golden model；
  仓库里的 class-based AHB 环境属于 legacy track，当前没有面向 AXI AI 主线的完整
  UVM environment、coverage closure 或 scoreboard/agent 回归体系。
- 固化优势量化边界：4-bank 路径相对 scalar 的计算宽度为 16 对 4 INT8 MAC，理论
  宽度提升 4 倍；ping-pong 相对完全串行 load/compute/store 的理想稳态加速上限为
  `(L+C+S)/max(L+S,C)`，不超过 2 倍；AXI32@100 MHz 单方向理论 payload 上限
  400 MB/s。以上均是模型/上限，实板 sustained 性能必须读取 `PERF_*` 后报告。
- 修正架构文档中两处遗留的“尚未 timing closure”表述，使其与最新 OOC
  `+1.335/+0.026 ns` 和整板 `+1.092/+0.011 ns` setup/hold 结果一致。
- 当前阶段结论：A2 RTL 功能设计、XSim/Python 功能回归、Vivado OOC/整板实现和
  bitstream/XSA 生成已完成；实体板 DDR/IRQ/ILA/裸机验证与 AXI AI UVM/VCS coverage、
  lint/CDC/formal/工业签核尚未完成。

## 2026-07-15 - Scratchpad 容量评估

- 核对 `ai_scratchpad`、顶层地址译码、banked row 接口、板级 AXI aperture 和最新
  utilization report。当前 64 KiB 由 4 bank × 4096 × 32 bit 构成，综合占用
  16 个 RAMB36E2；整板连同 ILA 共占 40/744 个 BRAM tile（5.38%），器件另有
  112 个未使用 URAM。
- 结论：64 KiB 足以作为 A2 功能冻结、协议验证和小 tile bring-up 基线，但对于较真实
  的 Conv/GEMM 工作集偏小，尤其是同时容纳共享权重和两个 input/output context 时。
  扩容主要提升 tile 尺寸、数据复用和减少 DDR 分块次数，不会自动提高 MAC 峰值。
- 建议保留 64 KiB compatibility profile，并在 A3 增加参数化 XCZU15EG profile，优先
  评估 256 KiB。按当前 BRAM 映射估算，128/256 KiB scratchpad 分别使用约 32/64 个
  RAMB36E2；保持现有 24-BRAM ILA 时整板约为 56/88 个，即 7.53%/11.83%，资源充足。
- 当前扩容并非只改一个 depth 参数：Vivado XPM 的 memory/address width、12-bit banked
  row、arbiter/top wiring、64 KiB host window decode、板级 128 KiB aperture、软件
  capability/地址检查、scratchpad 分区表和回归边界均需一起参数化。未在本次问答中直接
  修改 RTL，以免在实体板验证前破坏已经 closure 的 A2 基线。

## 2026-07-15 - 512 KiB 参数化 scratchpad 实施启动

- 用户确认采用 512 KiB 默认容量，并授权联动修改 SRAM/scratchpad 相关 RTL、验证、
  FPGA 集成、软件和文档。本轮先检查 `git status --short`，确认仅有上一轮
  `architecture.md`/本日志修改以及用户原有的硬件资料状态；继续保持厂商资料不暂存、
  不修改。
- 固定容量假设审计发现：`ai_scratchpad` 虽暴露 `WORDS_PER_BANK`，但 XPM
  `MEMORY_SIZE/ADDR_WIDTH`、row slice、banked compute/arbiter 的 12-bit row、顶层
  64 KiB mask、板级 128 KiB aperture 和软件映射仍为硬编码。因此本轮目标定义为：
  4 bank、默认每 bank 32768 word（合计 512 KiB），所有 row/interface/decode 参数由
  顶层容量参数一致派生，并增加最高合法地址和越界访问回归。

### 参数化 RTL 与首轮回归

- `ai_accel_top.SPAD_WORDS_PER_BANK` 默认设为 32768，容量、row
  width 和 host window end 由常量表达式派生；`ai_scratchpad` 的 XPM 与 behavioural
  arrays 使用同一 depth/row 参数。为避免 row width 泄漏和高地址截断，banked core、
  arbiter、scratchpad 之间的接口由固定 12-bit row 改成 32-bit byte address，row 只在
  scratchpad 内部生成。
- 顶层 host decode 改为范围比较，寄存器页增加高位校验，`0x90000` 等 scratchpad
  窗口外地址不再通过低地址位别名到 `CTRL`。新增只读 `SPAD_INFO@0x164` 返回字节容量，
  VERSION 更新为 `0x10000002`；scheduler、banked 和 completion 均加入参数化末地址检查。
- Artix-7 wrapper/OOC synthesis 显式保留 4096 words/bank 的 64 KiB compatibility
  profile；XCZU15EG/通用顶层默认使用 512 KiB。板级 PS aperture 同步改为 1 MiB，
  覆盖 register page 与 `0x10000..0x8ffff` host scratchpad window。
- XSim 使用 `xvlog/xelab/xsim` 完整运行默认 20 轮随机 smoke，结果 `TEST PASS`。
  新增并通过 `SPAD_INFO=0x80000`、最高合法 word `0x7fffc`、首个非法地址
  `0x80000` 读写 SLVERR，以及 banked VDOT 在最高两个 16-byte row 的测试；原有
  queue、completion、DMA、abort/reset、Conv/GEMM 和 ping-pong 回归均未退化。

### 512 KiB XCZU15EG 首轮时序试跑

- XCZU15EG OOC synthesis 完成：`7854 LUT / 4946 FF / 128 RAMB36E2 / 0 DSP`，综合后
  setup/hold 为 `+0.147/+0.084 ns`，DRC 0 violation。四个 32K x 32 bank 各由 32 个
  RAMB36E2 实现，容量映射与 512 KiB 目标一致。
- 首轮 OOC post-route 完成但未签核：setup WNS/TNS 为 `-0.516/-15.022 ns`（32 个
  failing endpoints），hold WHS `+0.023 ns`，DRC 0 violation。关键路径包含深度 BRAM
  级联读出到 banked compute 以及量化/累加数据路径。因此不宣告 closure，下一步将
  scratchpad 读延迟从 1 拍固化为 2 拍，并同步修改 host 和 scheduler response 契约后
  重跑功能与物理回归。

### 两拍 SRAM 读协议与功能回归

- XPM `READ_LATENCY_A/B` 固化为 2，VCS/XSim behavioural RAM 增加等价输出级；
  `ai_spad_arbiter` 同步延迟 client/error tag，AXI-Lite read FSM 增加第二个 wait state。
- 重新执行 `xvlog/xelab/xsim` snapshot `ai_512k_pipe2`，完整 smoke 结果 `TEST PASS`。
  20 轮随机计算、queue/completion、DMA/abort/reset、ping-pong、最高合法 word、越界
  SLVERR 与高地址 banked VDOT 均通过。
- AArch64 bare-metal 使用 Vitis 2024.1 `aarch64-none-elf-gcc -Wall -Wextra -Werror
  -fsyntax-only` 通过；Python golden model `--cases 1000 --seed 12345` 通过。

### 512 KiB XCZU15EG 最终 OOC/board closure

- 两拍读出后 OOC synthesis 为 7,854 LUT、4,952 FF、128 RAMB36E2、0 DSP48E2，
  setup/hold `+2.684/+0.084 ns`；post-route 为 7,780 LUT、4,952 FF、128 RAMB36E2，
  setup/hold `+0.836/+0.023 ns`，0 failing endpoint，DRC violation 0。
- `CIMFORGE_VALIDATE_ONLY=1` 板级验证通过：PS control segment 为
  `0xA0000000 [1M]`，HP0 DDR、IRQ、clock/reset 和 ILA 连接未退化。
- 完整整板 synth/place/route/bitgen 通过：17,624 LUT、19,274 FF、152 RAMB36E2、
  0 DSP48E2，setup/hold `+1.625/+0.012 ns`，0 timing failing endpoint。Routed DRC 为
  0 error/4 warning，仍为 Vivado `dbg_hub` 的 3 个 `PDCN-1569` 与 1 个 `RTSTAT-10`。
  `cimforge_system_wrapper.bit`、`cimforge_board.xsa` 和 `cimforge_board.ltx` 均重新生成。
- 结论：512 KiB 已从“容量参数修改”提升为功能回归、OOC 时序、整板时序
  和 bitstream 都闭环的 XCZU15EG 默认 profile；实体板上 DDR/IRQ/ILA 运行仍待拿到板卡后验证。

### Artix-7 64 KiB compatibility profile 检查

- 使用 `synth_design -generic SPAD_WORDS_PER_BANK=4096` 实际综合
  `xc7a100tfgg484-2`：0 error、0 synthesis critical warning，7,535 Slice LUT、4,956 FF、
  16 RAMB36E1、0 DSP，确认默认 512 KiB 改造仍可在 Artix wrapper 中回退到 64 KiB。
- 该裸 IP 非 OOC Artix 脚本的 synthesis timing WNS 为 `-6.713 ns`，关键路径是
  banked reduction/quantization 的 41 级 LUT/CARRY4 逻辑；DRC 的 UCIO/NSTD 等也来自将 AXI IP
  端口当作物理 IO。因此此步只是 64 KiB 参数编译/资源检查，不宣称 Artix
  100 MHz closure；当前签核目标仍是已通过的 XCZU15EG。

### 最终提交审计

- 再次执行 `git status --short`、工作区 diff 统计和 `git diff --check`；确认本轮交付仅涉及
  scratchpad 参数化联动的 RTL、验证、软件、XCZU15EG/Artix profile 与架构文档。
- 敏感信息扫描未发现账号、口令、服务器地址或许可证内容。本地 Vivado 生成的
  `clockInfo.txt`、用户原有的 `docs/hardware/**` 删除状态、未跟踪板卡资料及厂商 demo
  均明确排除在提交范围之外。

## 2026-07-17 - XCZU15EG 实体板 bring-up 与部署启动

- 操作前执行 `git status --short`，确认仅有 Vivado 生成的 `clockInfo.txt`、用户原有硬件
  资料删除状态和未跟踪厂商资料；本轮继续保持这些内容不被修改或暂存。
- 读取并目视核对 `docs/hardware/xczu15eg/XCZU15EG_SCH_0515.pdf` 的启动模式和 USB-JTAG
  页面。确认 SW1 支持 `0000` PS JTAG 启动，板载 FTDI 通道 A 连接 Zynq JTAG，通道 B
  的 `BDBUS0/1` 连接 PS UART MIO38/39；Windows 枚举到 JTAG 线缆对应 FTDI 设备及
  COM9/COM10/COM11，其中 PS UART 对应通道 B（COM10）。
- 使用 Vivado Hardware Manager 只读枚举 JTAG 链，检测到线缆 `Xilinx/15051A`、PL
  器件 `xczu15_0` 和 `arm_dap_1`，与目标 XCZU15EG 匹配。该步骤未写 QSPI/eMMC。
- 新增 XSCT JTAG 部署与硬件自检脚本：脚本将复用当前已 closure 的 bitstream 和生成的
  `psu_init.tcl`，系统复位后配置 PL，并通过停止的 A53/DAP 完成寄存器、512 KiB
  scratchpad 边界、PS DDR DMA、external CMDQ、VDOT、completion、IRQ sticky 状态和
  DMA store 验证；运行结果写入忽略目录下的 `build/board/hw_validation.log`。

### 实板部署自动化与首次连接结果

- 使用 Vivado Hardware Manager 和 XSCT 实际连接板卡，识别到线缆
  `Xilinx/15051A`、`xczu15_0`、`arm_dap_1`，并在初次连接时枚举到 PSU、RPU、APU
  和四个 Cortex-A53 target，确认 USB-JTAG、器件型号和电脑驱动正常。该过程只做
  JTAG 临时访问，没有写 QSPI/eMMC。
- 新增 `build_baremetal.ps1`/`generate_baremetal.tcl`，直接从当前整板 XSA 通过 HSI
  生成 A53 standalone BSP、ZynqMP FSBL 和 bring-up 应用；生成的 linker region 从
  DDR 地址 0 调整到 `0x00100000`，保证代码、descriptor 和 DMA buffer 位于 A2
  32-bit master 可访问的低 4 GiB。Vitis 2024.1 实际完成编译链接，生成
  `cimforge_fsbl.elf` 和 `cimforge_bringup.elf`。
- 裸机测试增加真实 PL-to-PS interrupt 验收：根据当前 XSA 生成的
  `XPAR_FABRIC_ACCEL_0_IRQ_INTR=121` 初始化 GIC，注册 level-sensitive ISR，要求
  command completion 后 ISR 实际执行并清除 sticky `IRQ_STATUS`，不再只轮询寄存器。
- 新增 `jtag_run_baremetal.tcl`/`run_baremetal.ps1`，自动完成 system reset、bitstream
  下载、XSA/FSBL 初始化、A53 ELF 下载、返回码检查和 COM10 UART 并行采集；只有
  JTAG 日志出现 `CIMFORGE_BAREMETAL_PASS` 且 UART 出现完整 PASS 文本时才返回成功。
- 首轮 CPU-independent DAP smoke 中，PL 配置成功；随后先后修正了 generated
  `psu_init.tcl` 的 Tcl global scope 调用方式，以及 PL isolation/reset removal 调用。
  在修正前的一次 `0xA0000044` AXI 访问超时使 DAP 留下 sticky
  `AXI AP transaction error, status 0x30000021`。尝试 system/PS/DAP reset 和重启
  `hw_server` 后仍未清除；当前 JTAG 链与 PL 仍可见，但 PSU/APU 暂不可访问，已停止
  继续发送 AXI transaction，等待板卡主电源断开至少 5 秒后重上电再运行 FSBL 流程。
- 新增 `docs/XCZU15EG_BRINGUP.md`，固化 SW1/SW2、FTDI channel、COM10/115200、
  构建/部署命令、PASS 标记、日志位置、ILA 定位方法和 DAP sticky error 恢复规则；
  同步更新 FPGA、software 和根 README。当前已完成可复现的部署资产，实体
  DDR DMA/CMDQ/VDOT/completion/GIC IRQ PASS 尚未在 DAP 恢复后取得，因此不宣称
  实板验收完成。
- 增加不访问 PS/DAP 的 `verify_ila.tcl`/`run_verify_ila.ps1`，用于给当前已配置器件
  关联 LTX 并检查 bitstream 中的 ILA/debug probes 是否可发现；日志同样保存在忽略的
  `build/board` 下，脚本只在看到 `CIMFORGE_ILA_VALIDATION_PASS` 时返回成功。
- 实际执行首次 ILA attach：Vivado 成功读取 LTX，但报告当前已配置器件的
  `dbg_hub` 未被检测到；结合 DAP sticky error、PS target 消失和 PL0 clock 由 PS
  输出，判定为 PS/FSBL 尚未恢复导致 debug-hub free-running clock 未启动。脚本提示
  已补充“先完成板卡掉电恢复和 FSBL 初始化”，当前不将该结果误报为 LTX PASS。
- 重新核对 Windows PnP 实例：FTDI serial B/C/D 分别为 COM10/COM11/COM9，确认
  PS UART 默认 `COM10` 与原理图 channel B 一致。随后从当前 XSA 再次全量运行
  `build_baremetal.ps1`；一次过短的外部命令超时导致残留文件锁，清理退出进程后重新
  运行成功，FSBL 与应用均完成编译链接。最终 ELF entry/LOAD address 为
  `0x00100000`，符号表包含 `accel_irq_handler`、`XScuGic_InterruptHandler` 和 `main`；
  PowerShell 四个 wrapper 均通过 parser 检查。构建中的 warning 来自 Xilinx 2024.1
  BSP/driver 源码，CIMForge 应用自身编译链接成功。

### 掉电恢复后的实体部署继续

- 用户完成板卡掉电重启后重新运行 XSCT target probe，DAP sticky error 已消失，PSU、
  RPU、APU 和四个 Cortex-A53 target 均恢复，确认物理复位有效。
- 首次完整 `run_baremetal.ps1` 在 system reset 后、bitstream 下载前失败：此时
  `PS TAP` 和 `PSU` 同时满足 XSCT 的 `level == 0` 过滤器，脚本拒绝选择多个 target；
  该次未访问 accelerator/DDR。已改为按名称唯一选择 `PSU`，并让 wrapper 在 JTAG
  日志已出现明确 FAIL 时立即停止串口等待，随后重新执行实体部署。
- 修复 target 选择后再次部署：bitstream 下载成功，FSBL 到达 `XFsbl_Exit`；应用
  运行 60 秒未到 `_exit`。暂停 A53 后读取异常上下文，PC 位于
  `Xil_SyncErrorHandler`，`FAR_EL3=0xA0000044`、`ESR_EL3=0x96000210`，精确定位为
  第一次 VERSION 读取的 synchronous external abort，而非 DDR/ELF/GIC 软件异常。
- 此时独立执行 LTX attach 成功，Vivado 发现 `hw_ila_1` 和 215 个 probes，证明
  bitstream、PL0 clock 和 debug hub 正常。随后运行显式执行 PSU init、PL isolation
  removal/reset config/post config 的 DAP smoke，在同一地址复现 AXI AP timeout 并再次
  形成 DAP sticky error，确认故障位于 PS HPM0 到 PL AXI-Lite 控制通路。
- 对 routed DCP 做静态网表审计：`rst_pl_peripheral_aresetn` 不是常量，有真实 reset
  controller driver 和三个 load；HPM0 nets 及 control SmartConnect 逻辑均保留。与板商
  已验证的 `10.pl_ps_gpio_test` 对比后，将控制通路改为板商同款 AXI Interconnect，
  显式连接 ACLK/S00_ACLK/M00_ACLK 与全部 ARESETN，并增加 System ILA 被动监控完整
  AXI-Lite interface、原生 ILA 增加 peripheral_aresetn probe；DDR 数据面 SmartConnect
  保持不变。Vivado 2024.1 `CIMFORGE_VALIDATE_ONLY=1` 已通过，地址仍为
  `0xA0000000 [1M]`，准备重新生成整板 bitstream/XSA/LTX。

### AXI-Lite 实板故障的 ILA 定位与 RTL 修复

- AXI Interconnect + 双 ILA 版本完成整板综合、布局布线和 bitgen：0 error、0 critical warning；最终
  setup/hold 为 `+1.188/+0.011 ns`，所有 timing constraints met。导出新的
  `cimforge_board.xsa`/`cimforge_board.ltx`，并由新 XSA 重建 FSBL 与裸机应用。
- 掉电恢复后确认 PS TAP、PMU、PL、PSU、RPU、APU 和四个 Cortex-A53 target 全部可见；下载新 bit、
  FSBL 到达 `XFsbl_Exit`，但应用在第一次 VERSION 读继续进入 `Xil_SyncErrorHandler`，异常证据为
  `ESR_EL3=0x96000210`、`FAR_EL3=0xA0000044`。正式 JTAG 流程补入 XSA 匹配的
  `psu_ps_pl_isolation_removal`、`psu_ps_pl_reset_config`、`psu_post_config`，排除单独下载 bit 时
  FSBL 未处理 PL partition 的隔离遗漏。
- ILA attach 验证通过：发现 native `hw_ila_1`（215 probes）和 System ILA `hw_ila_2`（32 probes）。
  native ILA 捕获确认 `rst_pl/peripheral_aresetn` 始终为 1；System ILA 捕获第一次读事务已到达
  accelerator，`ARADDR=0xA0000044`、`RDATA=0x10000002` 正确，但 `RRESP=SLVERR`。因此 PS、
  HPM0、AXI Interconnect、时钟、复位和寄存器内容均正常，根因收敛为 accelerator 的地址解码。
- 根因是 RTL smoke 一直以零基址驱动，而板级 AXI Interconnect 会把完整系统地址送到 slave。
  `ai_accel_regs.word_access` 因地址高位非零错误地产生 SLVERR，顶层 scratchpad window 也会把
  `0xA0010000` 误判为寄存器访问。顶层现将 1 MiB aperture 的低 20 位统一归一化后再送寄存器、
  scratchpad、host protection 和 host RAM 端口。
- AI smoke 新增 `0xA0000044` VERSION 和 `0xA0010008` scratchpad 完整映射地址测试。本机 Vivado
  `xvlog/xelab/xsim` 完整回归通过，两个新增用例及原有 DMA/CMDQ/completion/VDOT/GEMM/Conv/
  DWConv/ping-pong/随机回归最终均为 `TEST PASS`。下一步重新生成整板镜像并复跑实板验收；在实板
  DDR DMA、CMDQ、VDOT、completion、GIC IRQ 全部通过前不宣告完成、也不提交 Git。

### 实板首笔 AXI-Lite 写阻塞的二次 ILA 收敛

- 重新初始化 PSU、下载 bitstream、执行 FSBL 与 PS-PL isolation/reset/post-config 后，A53 不再进入
  synchronous exception，但裸机程序的 PC 连续停留在 `0x00100cfc`；反汇编定位在首次
  `DMA_STATUS` 写附近，说明完整地址修复已使读通路恢复，而写通路仍有总线等待。
- System ILA 以首个 `AWVALID` 为触发采集 4096 点：`AWADDR=0xA00000B4` 与
  `WDATA=0x00000006/WSTRB=0xf` 分别在相邻时钟完成 `AWREADY/WREADY` 握手；随后从机 ready
  进入请求/响应阶段，但全部 4096 点中 `BVALID` 始终为 0，未产生写响应，A53 因而停在首笔写。
- 审计发现原 smoke driver 在发起写之前主动拉低 `BREADY`，没有覆盖 Zynq PS/AXI Interconnect
  将 `BREADY` 预先保持为高的实板行为。开始把写响应拆成显式 `WR_RESP_ARM/WR_RESP` 两阶段，
  保证 `BVALID` 至少完整保持一拍并只在采样到 `BVALID && BREADY` 后撤销；同时新增
  preasserted-BREADY 定向测试。修改后将重跑完整 XSim、整板实现与实板验收。
- 使用 Vivado 2024.1 `xvlog/xelab/xsim` 执行修改后的完整 AI smoke；新增用例让 AW 先于 W
  一拍到达并从事务开始就持续置高 `BREADY`，写回读 `IRQ_ENABLE=1` 通过。原有完整地址、
  512 KiB 边界、DMA、CMDQ/completion、VDOT/GEMM/Conv/DWConv、保护与随机回归最终均为
  `TEST PASS`。开始重新生成包含写响应修复的整板 bitstream/XSA/LTX。
- 修复版整板构建完成：AI OOC/整板综合与 bitgen 均为 0 error、0 critical warning，最终 routed
  setup/hold slack 为 `+1.024/+0.011 ns`；routed DRC 为 0 error、7 个既有 Xilinx debug hub/
  AXI downsizer 生成逻辑 warning。`cimforge_board.bit/.xsa/.ltx` 已同步导出，FSBL 与裸机 ELF
  也已从该 XSA 重新生成。
- 实板重新执行 system reset、bitstream 下载、FSBL 与 PS/PL isolation/reset/post-config：FSBL
  到达 `XFsbl_Exit`，post-config 通过；但应用在 60 秒内仍未到 `_exit`，本轮标记失败且不提交。
  下一步读取 A53 停留地址和异常寄存器，并用 System ILA 确认修复后的 B response 是否出现，
  再判断阻塞是否已经推进到 DMA 数据面、CMDQ 或 IRQ 阶段。
- 修复镜像的第二次 System ILA 捕获显示写 FSM 的低 ready 区间从两拍增至三拍，证明新
  `WR_RESP_ARM` RTL 已进入实板；但 `BVALID` 仍为 0，A53 PC 仍固定在 `0x00100cfc`。
  检查 Vivado 生成的 `cimforge_system.v` 找到决定性结构证据：accelerator 的
  `s_axi_bvalid` 只连接到 native ILA probe7，而 `ctrl_ic.M00_AXI_bvalid` 被生成成常量
  `1'b0`。根因是把 module-reference AXI interface 的成员同时作为 scalar pin 接到 native
  ILA，导致 Vivado 将该成员从 interface net 上拆离；之前仅警告不要探测 AXI 输入成员并不充分。
- 板级脚本改为 native ILA 不再直接探测任何 AXI interface member，probe7 改为非接口的 IRQ
  观测副本；完整 S_AXI 继续仅由 System ILA 监控。先用 validate-only 检查生成 wrapper 的
  BVALID 连线，再重新执行完整实现和实体板验收。
- 移除非法 native ILA AXI-member tap 后的最终整板构建完成：synth/impl/bitgen 0 error、
  0 critical warning，最终 routed setup/hold slack 为 `+0.913/+0.012 ns`，routed DRC 0 error、
  7 个既有生成 IP warning；新的 bitstream/XSA/LTX 已同步导出。
- 新镜像实板运行已在 60 秒内命中应用 `_exit`，证明 AXI-Lite 首笔写死锁已消失；验收脚本随后
  因读取 XSCT 不存在的 `x0` 名称失败。该 A53 target 实际使用 `r0..r30` 命名，脚本改为读取/
  解析 `r0`；应用后寄存器检查也改为重新启用 force-memory-access 并选择 PSU/DAP，避免 A53
  target 的默认 memory map 拒绝 PL aperture。此项属于验收脚本兼容性修复，需复跑确认应用
  返回码及全部后效。
- 在 A53 第一次 VERSION load 后下断点：CPU `r2=0x10000002`，PSU/DAP 同址同为
  `0x10000002`，证明 PL R channel 与 A53 可见值一致。进一步审计启动代码发现 `main` 返回后先调用
  `__libc_fini_array` 再调用 `exit`，因此 `_exit` 断点处的 `r0` 已被覆盖，不能代表 main 结果。
- 裸机程序新增 `cimforge_validation_result` DDR 验收变量，所有 main 退出路径写入明确的 0/错误码
  并执行 cache flush；JTAG 脚本在 `_exit` 读取该符号，不再依赖 ABI 临时寄存器。后效快照曾显示
  `DMA_STATUS=busy` 且 VDOT/completion 仍为 0，说明应用可能在 DMA 阶段失败；需用新结果码精确定位。
- 第一轮结果变量读取在应用命中 `_exit` 后失败，原因是 XSCT `mrd` 不接受 `&symbol` 地址表达式
  （该语法仅被 `bpadd` 等命令解析）。JTAG 脚本改用 XSA/ELF 同工具链的
  `aarch64-none-elf-nm` 提取 `cimforge_validation_result` 地址，再通过 DAP 读取；支持
  `CIMFORGE_NM` 环境覆盖。
- 结果变量机制复跑成功读取 `application_return=2`，精确定位为应用的 DDR-to-scratchpad DMA
  load 失败；VERSION、512 KiB capability 和 GIC setup 均已越过。开始读取 DMA status/error/
  programming registers 并检查 M_AXI/HP0 数据面。
- DAP 后效为 `DMA_STATUS=busy`、`DMA_ERROR=0`、`DMA_EXT=0x00103c00`、长度 1，而 VDOT 与
  completion 尚未产生。检查最终 wrapper 发现与 BVALID 同源的第二处拆线：native ILA 直接探测的
  M_AXI `ARVALID/AWVALID/WVALID/WLAST/RREADY/BREADY` 均只连到 ILA，SmartConnect S00 对应输入
  被绑成 `1'b0`，因此 DMA 已启动但请求不可能到达 HP0。
- 板级集成改为 native ILA 只观察非接口 IRQ/reset；System ILA 扩为两个完整 AXI monitor slots，
  SLOT0 监控 S_AXI 控制面、SLOT1 监控 M_AXI 数据面。开始 validate-only 检查所有 M_AXI handshake
  成员均保持真实连线，随后需再次生成最终镜像。
- 双 slot System ILA 的 validate-only 结构检查通过：SmartConnect S00 的
  `ARVALID/AWVALID/BREADY/RREADY/WLAST/WVALID` 全部连接到 `data_axi_*`，控制面 BVALID 也仍连接
  `ctrl_axi_lite_BVALID`，不再存在 handshake 常量绑零。开始重新生成最终整板镜像。
- 双-slot System ILA 最终整板构建完成：synth/route/bitgen 0 error、0 critical warning，最终 routed
  setup/hold slack 为 `+1.116/+0.011 ns`，routed DRC 0 error、7 个既有生成 IP warning；新
  bitstream/XSA/LTX 已导出。
- `CIMFORGE_VALIDATE_ONLY=1` 已通过；新生成 wrapper 的
  `ctrl_ic.M00_AXI_bvalid(ctrl_axi_lite_BVALID)` 为真实接口连线，不再是 `1'b0`。该结构检查
  直接关闭了 native ILA 拆线风险，开始重新执行最终整板 synth/place/route/bitgen。

### 最终实板验收继续与 UART 通道校正

- 最终镜像重新下载后，FSBL 到达 `XFsbl_Exit`，PS/PL isolation、reset 与 post-config 均完成；
  裸机 ELF 的 `cimforge_validation_result` 返回 0。JTAG 后效检查读得
  `VERSION=0x10000002`、`SPAD_INFO=0x00080000`、`IRQ_STATUS=0`，证明应用内部已经完成
  DDR load/store DMA、external CMDQ descriptor、VDOT、四字 completion 与 GIC ISR/W1C 清中断。
- 对 COM9/COM10/COM11 做同一次启动的并行原始监听：COM9 无数据、COM10 仅有一个 NUL，
  COM11 捕获 FSBL banner、`CIMForge XCZU15EG bring-up` 和完整 PASS 文本。因此将当前电脑的
  默认 PS UART 从先前按 FTDI 后缀推断的 COM10 校正为实测 COM11；COM 号仍属于主机动态分配，
  不写入 RTL 或 bitstream。
- 已同步修改裸机验收 wrapper 默认串口及 bring-up/software/FPGA 文档。下一步使用正式 wrapper
  复跑并生成 `baremetal_jtag.log`/`baremetal_uart.log`，随后执行独立 DAP 验收和 ILA attach，
  仅在三类日志全部出现 PASS 后完成本地 Git 提交。
- 使用默认 COM11 正式执行 `run_baremetal.ps1`，流程以退出码 0 完成。JTAG 日志确认 PSU/APU/A53
  可用、FSBL 到达 `XFsbl_Exit`、PS/PL isolation/reset 已释放、`application_return=0`，且后效
  VERSION/capacity/IRQ 均匹配；UART 日志同时捕获 FSBL banner 与
  `PASS: version/DDR DMA/CMDQ/VDOT/completion/IRQ all verified`。正式验收日志分别保存为
  `build/board/baremetal_jtag.log` 和 `build/board/baremetal_uart.log`。
- 随后执行 CPU-independent `run_jtag_validate.ps1`，退出码 0。DAP 独立读写验证覆盖 512 KiB
  scratchpad 首尾、两路 DDR-to-SPAD DMA load、external CMDQ、VDOT 结果 70、四字 completion、
  sticky IRQ、SPAD-to-DDR DMA store；日志报告 `command_cycles=10`、`elements=1` 并以
  `CIMFORGE_HW_VALIDATION_PASS` 结束，保存于 `build/board/hw_validation.log`。
- 最后执行 `run_verify_ila.ps1`，Vivado Hardware Manager 成功关联最终 LTX，发现 native
  `hw_ila_1`（215 probes）和双槽 System ILA `hw_ila_2`（72 probes）；验收日志以
  `CIMFORGE_ILA_VALIDATION_PASS` 结束并保存为 `build/board/ila_validation.log`。至此 bitstream、
  FSBL/ELF、DDR DMA、CMDQ/VDOT/completion、GIC IRQ 和 ILA 连接的本轮实板 P0 验收全部通过。
- 提交前执行 tracked status、差异统计与 `git diff --check`，未发现 whitespace error；对本轮文档、
  RTL、软件和脚本扫描 VNC 地址、账号、口令与 license 配置，未发现敏感信息。`clockInfo.txt`、
  用户原有的 `docs/hardware/**` 删除/新增、厂商 demo 和所有 `build/**` 生成物继续明确排除在提交外。
- 本轮 19 个设计、验证、软件与部署文件已完成本地 Git 提交，提交主题为
  `Complete XCZU15EG hardware bring-up`；未执行远端 push。

## 2026-07-21 - 工业化与求职路线写入 prospective

- 操作前检查 tracked worktree，确认仅有用户原有的 `clockInfo.txt` 和 `docs/hardware/**` 删除状态；
  大量未跟踪厂商 demo/生成文件继续保持不修改、不暂存。
- 更新 `docs/project_prospective.md` 的当前基线：scratchpad 由早期 64 KiB 更正为参数化 512 KiB，
  并记录 A2 已完成 XCZU15EG timing/bitstream、DDR DMA、CMDQ、VDOT、completion、GIC IRQ 和 ILA
  实板 P0 验收，旧章节作为演进记录保留。
- 新增“FPGA P0 通过后的工业化与求职路线图”，按 baseline freeze、AXI AI UVM、VCS coverage、
  lint/CDC/RDC/formal、板上性能量化、瓶颈驱动架构优化、DC/PT/Formality/门级仿真和求职材料
  八步推进；每一阶段均给出交付物、通过标准与停止条件，避免继续无指标堆算子。

## 2026-07-22 - A3 Transformer 前端升级启动

- 操作前检查 tracked worktree：本轮开始前除上一轮尚未提交的
  `docs/project_prospective.md`/`docs/project_update_log.md` 外，仅有用户原有的
  `clockInfo.txt` 与 `docs/hardware/**` 状态；继续保持硬件资料和生成目录不修改、不暂存。
- 审计确认 A2 数据面为单时钟、4-bank/512 KiB scratchpad；现有 scalar core 每拍执行 packed
  dot4，banked core 每次读取四个 bank、完成 16 个 INT8 MAC，但尚无 4x4 output tile、tensor
  stride/transpose/batch、Vector/SFU 或 descriptor dependency 字段。DMA 已有 2D、4 KiB split 和
  load/compute/store tile overlap，仍是单 outstanding、最大 16 beat。
- A3 采用“保持 A2 opcode/实板路径兼容，新增 descriptor v3 primitive”的实施边界：新增 4x4
  INT8/INT32 matrix engine、tile 内 transpose 与 batch address generation、Softmax/RMSNorm/
  residual/GELU/requant Vector/SFU、事件依赖调度，以及面向 DDR tensor tile 的更长 burst；完整
  Transformer block 由多条基础 command 链接，不以占位 `OP_MHA` 冒充端到端支持。

### A3 RTL、ABI 与定向回归实现

- 新增 `ai_tensor_matrix_core`：4x4 output-stationary INT8 PE tile，每个 MAC 周期执行
  16 个乘法，INT64 累加、INT32 饱和写回，支持 bias/shift/ReLU/ReLU6、tile 内
  transpose、batch/head 和三路 batch stride。
- 新增 `ai_tensor_sfu_core`、64-bit iterative divider 和 integer square-root：实现稳定
  Q15 softmax、RMSNorm、residual、GELU、SiLU 和 INT8 requant。定点与近似规则同步写入
  `verif/ref/ai_a3_reference.py`，不把近似 SFU 描述为浮点等价实现。
- descriptor fetch 的 16-word ABI 扩展为 v3；command processor 新增 16-bit dependency
  event scoreboard、wait/signal/clear、65535-cycle timeout 和 error 12。新增算子仅接受
  descriptor v3，A2 opcode 与 v2 路径保持兼容。
- 顶层把 matrix/SFU 接入既有 command processor 和唯一 scratchpad arbiter；寄存器块仍
  只负责配置、doorbell 和 sticky status。`VERSION` 升为 `0x10000003`，CAP 新增 matrix、
  SFU、descriptor-v3、DMA64 位，`EVENT_STATUS` 位于 `0x168`。
- AXI DMA 最大 burst 从 16 提升到 64 beat，保留 4 KiB split、2D、protection、abort/drain
  与单 outstanding 语义；源文件清单已同步更新到 AI smoke、Artix-7 和 XCZU15EG。
- 扩展 XSim smoke，覆盖 4x4 GEMM、batch+transpose、全部 SFU、事件依赖/清除、completion
  ordering 和首个 64-beat AR burst，同时保留 A2 directed 与 20 组随机回归。调试时发现
  arbiter 把 scratchpad 写握手误当作 read response，导致 SFU 连续写/读消费陈旧响应；
  修正为只有读请求产生 `rsp_valid` 后，完整回归于 243700 ns 输出 `TEST PASS`。
- 新增独立 A3 架构/ABI/数值契约文档 `docs/CIMFORGE_A3_TRANSFORMER.md`。当前 XSim 结果是
  Windows 功能交叉检查，不能替代 Linux/VNC 上的 VCS coverage；A3 的 Vivado 综合、
  定点随机模型和 A3 bitstream 实板复验仍作为本轮后续 gate。
- 执行 A3 Python golden model：`python verif/ref/ai_a3_reference.py --cases 1000
  --seed 20260722`，结果为 `A3_REFERENCE_PASS cases=1000 seed=20260722`。
- 首次 XCZU15EG OOC synthesis 虽为 0 error/critical warning，但 100 MHz setup WNS 为
  `-4.464 ns`；最差路径从 SFU state/address 经 scratchpad live bank mux、两级 DSP 和
  饱和逻辑到 output register，共 63 logic levels，因此未把“综合成功”误记为时序通过。
- 修复 XPM `READ_LATENCY=2` 的 host/compute bank tag 对齐，并把 SFU square、gamma、
  reciprocal scaling、GELU/SiLU product 分级寄存；RMSNorm 的 post-gamma INT32 saturation
  同步固化到 golden model 和数值规范。修改后行为 RAM smoke 在 243940 ns `TEST PASS`，
  不定义 `VCS`、直接链接 XPM 的完整 smoke 也在 218460 ns `TEST PASS`。
- descriptor v3 的 `head_count` 最终审计发现已完成 fetch/launch、但 matrix 尚未消费；修复为
  硬件执行 batch×head 个 flattened tensor instance，三个 stride 表示相邻 instance 的跨度。
  回归改为 `batch=1, head=2`，XPM smoke 对两个 head 的 transpose GEMM 均检查通过并最终
  输出 `TEST PASS`。
- 最终 Vivado 2024.1 XCZU15EG OOC synthesis 为 0 error、0 critical warning；资源为
  16,115 LUT、9,106 FF、128 RAMB36E2、22 DSP48E2，100 MHz setup/hold 为
  `+1.067/+0.083 ns`，0 failing endpoint。OOC DRC 的 151 项为 DSP pipeline 方法学 warning，
  不是 DRC error；post-route 与 A3 bitstream 实板验收仍未执行，不能沿用 A2 实板 PASS。
- 最终执行 `git diff --check` 并审计三份 source list；硬件资料、厂商 demo、Vivado build/
  log 与用户既有 dirty changes 均保持在本轮交付范围之外。

## 2026-07-22 - A4 验证前设计闭环启动

- 用户要求在进入 Linux/VNC 验证前补齐 A3 明确列出的设计缺口。重新划分边界：
  `LayerNorm`、macro-fused QKV/MHA/FFN、KV-cache gather 和 AXI multi-outstanding 属于
  RTL/ABI 设计；VCS coverage、UVM、lint/CDC/formal 属于随后在虚拟机执行的验证；
  post-route 与 A3/A4 bitstream 实板运行属于实现和系统验收，不伪装成“验证前设计”。
- A3 未直接加入上述功能的原因是 descriptor v3 只有两路普通输入和一路辅助地址，无法
  无歧义携带完整 MHA 的 Q/K/V、多个权重、临时 buffer 与 KV-cache 元数据；原 DMA 也没有
  AXI ID/transaction FIFO，简单提高 outstanding 属性会违反 abort/error/drain 语义。本阶段
  采用可执行的 A4 ABI 与真实状态机，不增加只有 opcode 名称的占位功能。
- A4 默认采用 macro-fusion：一个 v4 parent descriptor 指向由 v3 primitive descriptor 组成的
  micro-command list，硬件内部展开、失败即停、聚合 cycle/element，只发布一次 completion。
  这减少 CMDQ/completion/IRQ 开销但不虚称已经完成跨算子数据通路融合；后者必须由性能数据
  证明值得实现。LayerNorm 作为真实 SFU primitive 实现；KV gather 与 outstanding 深度继续
  保持 AXI 4 KiB、顺序 response、abort drain 和 scratchpad ownership 约束。
- 完成 `OP_LAYERNORM_Q15(0x38)`：三遍读取分别计算 signed mean、variance 与 normalize，
  复用 64-bit square accumulation、integer sqrt、unsigned divider/Q30 reciprocal；支持 Q15
  gamma 默认值、可选 gamma 和 INT32 beta。第一次 XPM 全量 smoke 在 `a4_ln.log` 中对
  `[1,2,3,4] + beta=10` 得到 `[9,10,11,12]`，最终 `TEST PASS`；Python 命令最初从
  `verif/sim` 使用了错误相对路径，随后在仓库根目录纠正并以 1000 cases 通过。
- 完成 descriptor v4 macro scheduler：`QKV_PROJ(0x40)` 限定 3 child，`MHA(0x41)` 与
  `FFN(0x42)` 支持 3..256 child；parent 可指向 scratchpad 或 AXI child list。command
  processor 逐条重新 fetch/validate/launch，禁止嵌套宏，聚合 result/cycles/elements，只提交
  一个 parent completion；child fetch/descriptor/dependency/compute 失败时 fail-stop。
- 完成 A4 DMA load planner：最多 4 笔同 ID AR outstanding，4-entry metadata FIFO 保存
  destination/length 并利用 AXI 同 ID 顺序回包；保留 64-beat、4 KiB split、2D 和完整
  abort/error drain。写路径明确保持单 AW/W/B 流，因此 capability 命名为 read outstanding。
  验证 memory model 同步扩展为 4-entry AR queue，使 smoke 能观测首个 RLAST 前接受 2 笔 AR。
- 完成 KV gather：`DMA_CFG(0x16c)` 控制 gather/read outstanding，`DMA_GATHER_INDEX(0x170)`
  指向 scratchpad 内绝对 DDR byte-address 表；每个索引加载一个 `ROW_WORDS` KV row，按
  `SPAD_STRIDE` 写入目标 tile。store+gather、零 row count 和未对齐 index/address 均按配置错误
  处理。首轮 `a4_full.log` 对两行非连续 DDR 数据的四个 word 全部通过，并保留 1D/2D/
  4 KiB/response-error/abort/A2/A3 随机回归，最终为 `TEST PASS`。
- VERSION 更新为 `0x10000004`，CAP[16:19] 分别表示 LayerNorm、macro v4、DMA gather 与
  DMA read outstanding；同步更新 C ABI、descriptor helper、XSim test、A4 参考组合模型、
  `docs/CIMFORGE_A4_TRANSFORMER.md` 及 architecture 入口。Python 1000-case 结果为
  `A4_REFERENCE_PASS cases=1000 seed=20260722`；`git diff --check` 无 whitespace error，
  仅报告仓库既有 LF/CRLF 转换提示。
- 最终 XPM sign-off smoke 增加三种 parent opcode 连续执行和 invalid-child fail-stop：QKV、
  MHA、FFN completion 的 task/status/result/elements 均正确，失败宏以 parent task ID 返回
  descriptor error、elements=0 且不置成功 event；`a4_signoff.log` 于 244270 ns 输出
  `TEST PASS`。
- XCZU15EG OOC 首次调用因外层执行超时仍在后台继续，重试造成两个流程写同一 build；按启动
  时间识别并终止后启动的重复组时，Windows 进程树同时退出，因此随后只启动一个 Vivado
  任务并给予 600 s 超时，完整生成报告/DCP。该清理只处理本轮 Vivado 进程，未删除 build、
  用户硬件资料或其他 dirty 文件。
- 最终 Vivado 2024.1 `xczu15eg-ffvb1156-2-i`、100 MHz OOC：17,560 LUT、9,896 FF、
  128 RAMB36E2、22 DSP48E2，setup/hold `+0.772/+0.083 ns`、0 failing endpoint，综合
  0 error/0 critical warning。相对 A3 增加 1,445 LUT 与 790 FF，BRAM/DSP 不变；151 个
  DRC warning 仍为 DSP pipeline/reset 方法学项，不冒充 post-route DRC 或整板通过。
- 收尾审计：三份 AI source list 均包含 divider/sqrt/tensor matrix/tensor SFU；使用 MinGW GCC
  对 `sw/include/cimforge_regs.h` 做 C11 `-Wall -Wextra -Werror -fsyntax-only` 检查通过；再次
  运行 1000-case A4 reference 通过；最终 `git diff --check` 无 whitespace error，仅有既有
  LF/CRLF 提示。工作区中的 hardware PDF/demo、`.srcs/`、`tmp/`、`clockInfo.txt` 及用户删除
  项均保持原状，未纳入或清理。

## 2026-07-22 - A4 Transformer RTL 八项能力复核

- 本轮仅做实现状态审计，未继续扩张 RTL。4x4 matrix、local 4x4 transpose、batch/head、
  matrix+SFU、Softmax、RMSNorm/LayerNorm、descriptor v3/v4、event dependency、macro
  completion aggregation、DMA64/2D/gather/read-outstanding 均有真实 RTL，不是占位 opcode。
- 仍需准确限定：matrix 是 16 个并行 INT8 product、16 个 64-bit output-stationary accumulator，
  但 A/B tile fetch、4 lane MAC 和 16 word writeback 尚未流水重叠；transpose 只覆盖 4x4 local
  tile，descriptor 只有 batch stride，没有任意 row leading dimension；matrix/SFU 虽分离，顶层
  仍为 single-issue，通用 tensor buffer ownership 和跨 engine 并行尚未实现。
- Softmax 已实现 max-subtraction、PWL exp2、sum 和 iterative divide 的 Q15 输出，但真实模型上的
  KL/max-error、显式 `1/sqrt(head_dim)` scale 和长序列误差门限属于即将进行的验证/数值收敛项。
  QKV/MHA/FFN 是 command-level macro fusion，不是跨算子 datapath fusion。
- DMA 已支持配置深度 1..4 的同 ID read outstanding，smoke 已证明首个 RLAST 前接受 2 笔 AR；
  深度 4 饱和、随机 back-pressure/error/abort 交叉将在 VCS 阶段覆盖。store 仍是单 AW/W/B，
  当前不在无性能证据情况下增加 write outstanding；更高优先级是测量 32-bit AXI@100 MHz 的
  实际瓶颈，再决定 128-bit data width、descriptor/weight prefetch 或更深 outstanding。

## 2026-07-22 - A4 Linux/VCS 验证基线升级与本机预检

- 操作前检查 `git status --short`：保留用户已有的 `clockInfo.txt`、`docs/hardware/**` 删除/新增、
  FPGA demo 与既有 RTL/文档改动；本轮仅修改 `verif/**` 和本日志，不重置、不清理任何用户文件。
- 按 `docs/wsl_linux_instruction.md` 检查：当前 Codex Windows 执行上下文中的 `wsl -l -v` 没有已注册
  发行版；`F:\\WSL\\Rocky-8.10\\ext4.vhdx` 存在，但未执行 `wsl --import-in-place`，避免破坏用户已有
  WSL 注册/会话。`F:\\tsmc40_bridge\\` 当前也不存在，故尚不能把本项目直接复制或调度到 Linux。已新增
  Linux 侧入口 `verif/sim/run_ai_smoke_linux.sh`：在 Linux 文件系统内的 checkout、完成 EDA 环境初始化并
  启动 bridge 后，脚本会运行 A4 fixed-point reference、VCS compile 和 directed quick smoke，并将结果写入
  `verif/sim/results/`。
- 扩展 `ai_accel_sva.sv`：检查 M_AXI 读地址的 32-bit INCR 属性、4 KiB boundary、RLAST/AR 配对，以及
  outstanding 数不超过 `DMA_CFG[10:8]`（0 按 1）配置。扩展 smoke：256-word / 4 x 64-beat 读 DMA，要求
  第一个 RLAST 前接受 4 个 AR，并检查四个 burst 边界数据；原有 64-beat、2D、gather、response error、abort、
  descriptor、A3/A4 command/SFU 测试全部保留。Makefile 新增 `ai_quick`、`ai_a4_ref` 和 `ai_precheck` 目标。
- 本机 Vivado 2024.1 XSim 验证实际执行：
  `xvlog -sv -d VCS -i ../agents/axi_lite -i ../agents/ai_dma -f ai_accel.f ../env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv`；
  `xelab tb_ai_accel_smoke -s a4_verif_upgrade -debug typical`；
  `xsim a4_verif_upgrade -runall -log a4_verif_upgrade.log`。编译/展开均为 0 error；完整 smoke 输出
  `PASS: A4 DMA read outstanding saturated at 4`、KV gather/LayerNorm/macro completion/fail-stop 通过，最终
  `TEST PASS` 于 278250 ns。此为 Windows XSim 功能预检，不替代 WSL Linux 上的 VCS/UVM/coverage 签核。
- 后续 Linux 最小动作：bridge 脚本默认项目是 `~/ic/tsmc40_smoke`，因此在目标 WSL shell 中、
  CIMForge 已位于 Linux 文件系统后必须显式指定其 Linux 绝对路径，例如
  `TSMC40_PROJECT_DIR=/home/<user>/ic/CIMForge nohup bash /mnt/f/tsmc40_bridge.sh > /mnt/f/tsmc40_bridge_host.log 2>&1 &`，确认
  `/mnt/f/tsmc40_bridge/status.txt` 显示 `ready` 与项目绝对路径；随后可由 bridge 运行
  `bash verif/sim/run_ai_smoke_linux.sh`，再升级至多 seed VCS regression 与 coverage。

## 2026-07-22 - WSL bridge 接通与 VCS 环境实测

- 用户在 Rocky WSL 以 `ray` 启动 bridge，`status.txt` 已确认 `ready`、项目为
  `/mnt/e/workspace/chip/CIMForge`。该路径映射 Windows 工作区 `E:\\workspace\\chip\\CIMForge`；
  `F:` 仅承载 `tsmc40_bridge` 的 command/result/status 控制文件，不保存项目副本。项目未再复制到
  Linux，避免将 `.srcs`、Vivado 产物、demo 和大量小文件重复搬运。用户已有的 `~/ic/CIMForge`
  并非 Git checkout，且可能包含先前中断复制留下的嵌套目录；本轮不删除、不使用它。
- bridge 只读诊断确认：`vcs` 位于 `/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs`，license 环境变量存在；
  但 VCS 2023.12 在当前 `6.6.87.2-microsoft-standard-WSL2` 内核上由编译器本体明确拒绝。
  `VCS_ARCH_OVERRIDE=linux64` 可正确定位 `linux64` 安装目录，随后仍报 WSL2 不受支持，因此不通过
  伪造系统版本绕过工具支持边界。Linux VCS/UVM/coverage 回归需改在已支持的 VNC/Linux EDA 环境执行；
  Windows XSim smoke 仍是本地功能回归证据。
- bridge 检查发现默认 `python3` 为 3.6.8，不能解析 reference model 的
  `from __future__ import annotations`；系统同时已有 Python 3.11/3.12。更新 Makefile 与
  `run_ai_smoke_linux.sh`，自动选择第一个 Python >=3.7，并在 VCS 运行前执行 `vcs -ID` 预检，
  以便明确报告环境失败。实际执行
  `make -C verif/sim ai_a4_ref AI_REF_CASES=1000 AI_REF_SEED=20260722` 自动选择 `python3.12`，
  输出 `A4_REFERENCE_PASS cases=1000 seed=20260722`。
