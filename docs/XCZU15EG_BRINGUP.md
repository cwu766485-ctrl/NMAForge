# NMAForge XCZU15EG bring-up 与 FPGA 部署

本文面向仓库当前的 XCZU15EG AXI AI 主线，覆盖从板卡连接、生成部署文件到
DDR DMA、命令队列、计算、completion 和 PL-to-PS IRQ 的**实板验收流程**。所有流程均为
JTAG 临时加载，不会写入 QSPI 或 eMMC。本文是操作手册；截至 2026-08-26，仓库的可信
硬件证据仍是 100 MHz standalone-IP OOC，实现和完整板级端到端验收必须以本手册产生的
JTAG/UART/ILA 日志为准，不能因脚本存在而视为已通过。

## 1. 板卡连接

1. 关闭板卡主电源，将启动拨码 `SW1` 置为 `0000`（PS JTAG）。
2. 连接板载 USB Type-C/JTAG 口与电脑，再接通板卡主电源。
3. Windows 设备管理器应出现板载 FTDI 设备。原理图中 FTDI channel A 是
   Zynq JTAG，channel B 连接 PS UART 的 MIO38/MIO39；PS UART 的 COM 号由本机
   当前枚举结果决定，以下 `COM11` 仅为示例。
4. 串口参数为 `115200, 8 data bits, no parity, 1 stop bit, no flow control`。
5. `SW2` 是 PS reset。JTAG 出现持续的 `AXI AP transaction error` 时，先停止脚本，
   将板卡主电源断开至少 5 秒后重新上电；仅重启 Vivado `hw_server` 通常不能清除
   DAP 的 sticky error。

硬件依据应由板卡拥有者在本地提供；厂商原理图和参考工程不随公开仓库分发。不要把电脑上的 COM
编号写死到 RTL 或 bitstream；换 USB 端口后 Windows 可能重新分配编号。

## 2. 工具和产物

本流程使用 Vivado/Vitis 2024.1，并要求它们已在 `PATH` 或通过脚本参数显式指定：

```text
vivado
xsct
```

在仓库根目录生成整板 bitstream、XSA 和 ILA probes：

```powershell
fpga\xczu15eg\scripts\run_board_build.ps1
```

生成与该 XSA 匹配的 A53 FSBL 和 NMAForge 裸机自检 ELF：

```powershell
fpga\xczu15eg\scripts\build_baremetal.ps1
```

所需部署文件位于忽略的本地构建目录：

```text
fpga/xczu15eg/build/board/cimforge_board.runs/impl_1/cimforge_system_wrapper.bit
fpga/xczu15eg/build/board/cimforge_board.xsa
fpga/xczu15eg/build/board/cimforge_board.ltx
fpga/xczu15eg/build/baremetal/cimforge_fsbl.elf
fpga/xczu15eg/build/baremetal/cimforge_bringup.elf
```

不要混用其他 XSA 生成的 FSBL/BSP；PS DDR、MIO、时钟和 fabric interrupt ID 必须
与当前 block design 一致。当前 ABI v7.2 和统一 DMA 已使用 64-bit 外部地址，裸机链接脚本
仍建议把程序和静态测试缓冲放在低 4 GiB 的 PS DDR 中，以便兼容当前板级软件和调试工具。

## 3. 连接和快速自检

打开 Vivado Hardware Manager 后，目标链应包含 `xczu15_0`、`arm_dap_1`，XSCT
应能看到 PSU、APU 和 Cortex-A53 targets。仓库的自动化脚本会再次连接本机
`hw_server`。

CPU-independent DAP smoke 可作为诊断工具：

```powershell
fpga\xczu15eg\scripts\run_jtag_validate.ps1
```

它临时配置 PL、执行 XSA 生成的 PSU 初始化，并通过 DAP 检查版本、512 KiB
scratchpad 边界、PS DDR DMA、external descriptor、VDOT、completion、sticky IRQ
和 DMA store。成功标记为：

```text
CIMFORGE_HW_VALIDATION_PASS
```

若 DAP 在首次 AXI 访问时超时，不要连续重试。执行完整掉电恢复后，优先运行下一节
的 FSBL/裸机流程，由 FSBL 完成 PS 初始化。

## 4. 完整 FPGA 部署与运行验收

确认没有串口终端占用 `COM11`，执行：

```powershell
fpga\xczu15eg\scripts\run_baremetal.ps1 -Port COM11
```

脚本按以下顺序工作：

1. system reset 并通过 JTAG 下载当前 512 KiB bitstream；
2. 加载当前 XSA 的寄存器描述，下载并运行 A53 FSBL；
3. 下载裸机 ELF 到 PS DDR，并在 Cortex-A53 #0 上运行；
4. 并行采集 PS UART；
5. 交叉检查 ELF 返回码、PL 版本、scratchpad 容量和 IRQ 清除状态。

裸机测试覆盖：

- AXI-Lite `VERSION=0x10000008` 和 `SPAD_INFO=0x00080000`；
- cache-maintained PS DDR -> scratchpad DMA load；
- 位于 PS DDR 的 descriptor ring 和 command queue doorbell；
- INT8 VDOT/基础命令链，期望结果由当前 ABI v7.2 workload manifest 和 golden model 给出；
- 四字 completion entry 及发布顺序；
- PL level interrupt 经 GIC 到 A53 ISR，并由 ISR W1C 清除 sticky status；
- scratchpad -> PS DDR DMA store。

必须同时出现以下两类成功证据：

```text
CIMFORGE_BAREMETAL_PASS
PASS: version/DDR DMA/CMDQ/VDOT/completion/IRQ all verified
```

日志保存在：

```text
fpga/xczu15eg/build/board/baremetal_jtag.log
fpga/xczu15eg/build/board/baremetal_uart.log
```

## 5. ILA 与验收边界

当前 LTX 包含 accelerator IRQ、AXI4 read/write request handshakes 和 AXI-Lite
write response 等 probes。出现实板失败时，可在 Vivado Hardware Manager 中给已编程
器件关联 `cimforge_board.ltx`，用 ILA 区分以下问题：

已编程且已由 FSBL 启动 PL0 clock 的器件，其 LTX/debug-core 匹配关系可用以下命令
自动检查；该命令本身不访问 PS/DAP：

```powershell
fpga\xczu15eg\scripts\run_verify_ila.ps1
```

成功日志标记为 `CIMFORGE_ILA_VALIDATION_PASS`，保存在
`fpga/xczu15eg/build/board/ila_validation.log`。

- 没有 AXI request：软件配置、doorbell 或 command processor 问题；
- request 有而 response 不回来：PS HP0/DDR、地址或 AXI protocol 问题；
- completion 完成但无 IRQ：interrupt wiring、GIC ID/trigger 或 sticky status 问题。

一次可签字的 bring-up 至少需要保存：bitstream/XSA 对应的 Git commit、整板 timing
和 DRC 报告、JTAG PASS 日志、UART PASS 日志，以及失败时的 ILA 波形。当前脚本验证的
是 JTAG 临时部署；QSPI/eMMC 启动镜像、上电自启动和长期压力/温度测试属于下一阶段。

## 6. 常见故障

| 现象 | 处理 |
|---|---|
| 找不到 JTAG cable | 检查板卡主电源、USB 数据线和 FTDI 驱动，关闭其他占用 Hardware Server 的工具 |
| 只有 PS TAP/PL，没有 PSU/APU | 板卡掉电至少 5 秒后重上电，再重新连接 XSCT |
| `DAP status 0x30000021` | 停止 AXI 访问，执行掉电恢复或按 SW2；恢复后先跑 FSBL 流程 |
| `debug hub core was not detected` | 先运行 FSBL/裸机部署，确认 PS 输出的 PL0 free-running clock 已启动，再检查 LTX |
| 串口日志为空但 JTAG 运行正常 | 确认 `COM11` 未被占用；COM 号由 Windows 动态分配，可并行监听 FTDI 串口实例确认实际 PS UART |
| VERSION/SPAD_INFO 不匹配 | bitstream 与软件头文件/ELF 不是同一提交，重新生成整板产物和 ELF |
| DDR DMA timeout/error | 检查 FSBL 是否完成、buffer 是否低于 4 GiB，并用 ILA 查看 HP0 AXI handshakes |
| IRQ 未进入 ISR | 检查 XSA 生成的 `XPAR_FABRIC_ACCEL_0_IRQ_INTR`、GIC level trigger 和 `pl_ps_irq0` |
