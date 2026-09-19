# CNM 文档迁移说明

本文档的架构动机、阶段演进、性能边界和源码依据已合并到
[CNM_EVALUATION_ZH.md](CNM_EVALUATION_ZH.md)，该文件是当前唯一中文 CNM 主文档。
本文件暂保留为旧路径兼容说明；后续新的技术结论只应写入主文档。

---

以下为历史正文，阅读时以主文档和当前 RTL 为准。

**状态（2026-08-26）：** A1、A2.2、A3.1 已实现并完成定向 benchmark；本文保留设计动机、演进逻辑与后续研究边界。可公开评估以 `CNM_EVALUATION.md` 为准，PPA 以 `TSMC28_SYNTHESIS_REPORT.md` 为准。
**对象：** NMAForge A8，512 KiB、4-bank scratchpad。
**一句话：** 把四个 SRAM bank 旁边的计算、累加和控制做得更独立，减少中央调度与跨 bank 的中间结果搬运。

## 1. 先说结论

NMAForge 当前已经是 **数字 CNM**：4 个 SRAM bank 旁各有一个 Local Controller 和
Local PE。A2.2 让每个 bank 独立进行地址推进、A/B request、ready/response-valid、
A ping-pong buffer 和本地累加；四个 local sum 仅在输出边界进入 Global Reducer。

实测表明它提高了 banked GEMV/GEMM 的受控 workload 吞吐，但不会自动提高全芯片最高频率。
当前 A8 的全芯片关键路径约为 3.89 ns，位于 SRAM 到 Softmax SFU 的路径，不在 banked VDOT。

## 2. 当前结构在做什么

### 基础名词

- **SRAM bank**：把一大块 SRAM 分成四块，可同时读四份数据。
- **PE（Processing Element）**：小计算单元。当前每个 PE 对四对 INT8 数据做乘法并相加。
- **VDOT**：向量点积，例如 `a0×b0 + a1×b1 + ...`。
- **GEMV**：矩阵乘向量，本质上是连续做很多个 VDOT。
- **partial sum**：一个 bank 算出的局部结果，最后还要与其他 bank 的结果相加。

原始基线每次从四个 bank 各取一个 32-bit word，四个 PE 同时执行：

```text
Bank0 数据 -> PE0 -- partial0 --\
Bank1 数据 -> PE1 -- partial1 ---+-> Global Reducer -> 最终结果
Bank2 数据 -> PE2 -- partial2 ---+
Bank3 数据 -> PE3 -- partial3 --/
```

四个 PE 每次合计完成 16 个 INT8 MAC。原始版本由中央 FSM 依次完成：

```text
申请读 A -> 等 A 返回 -> 申请读 B -> 等 B 返回 -> 四 PE 计算/归约
```

这是 A1/A2 改造前的“**四路并行计算 + 中央读控制 + 中央归约**”基线，而不是当前实现。

## 3. 想改成什么样

当前已实现的最小 CNM 架构如下：

```text
Bank0 <-> Local Controller0 <-> PE0 <-> local_acc0
Bank1 <-> Local Controller1 <-> PE1 <-> local_acc1
Bank2 <-> Local Controller2 <-> PE2 <-> local_acc2
Bank3 <-> Local Controller3 <-> PE3 <-> local_acc3
                                             |
                                  每个输出结束时才 Global Reduce
```

关键不是改 SRAM cell，也不需要模拟计算或 ADC。已经完成的关键改动是：

1. 每个 bank 有本地地址/读控制和本地累加器；
2. PE 计算一组又一组数据时，结果先留在自己的 `local_acc`；
3. 一个 VDOT 或一个 GEMV 输出完成后，才把四个 `local_acc` 送给 Global Reducer；
4. A2.1 已加入 A/B 读算流水、A 预取和双缓冲；A3.1 已加入 4×4 GEMM tile 数据复用与 B response 预取。

## 4. 能得到什么好处

### 4.1 降低中央归约和互连活动

假设一个输出有 `L=64` 组数据。当前每组都产生四个 partial sum 并进行全局归约：

```text
当前：4 个 partial sum × 64 组 = 256 次传输/归约输入
CNM：4 个 local_acc，在输出结束时交一次 = 4 次传输/归约输入
```

因此，**partial-sum 的全局通信**理论上可以降低约 64 倍。这不是总 SRAM 读取量降低
64 倍；它只说明中间结果不再每一组都跑去中央归约器。

### 4.2 提高 banked VDOT/GEMV 吞吐

当前中央控制每一组数据大致需要“读 A、等待、读 B、等待”四个阶段。若每个 bank 有
自己的流水控制器，就可以在计算第 n 组时准备第 n+1 组，减少等待空泡。

每个 bank 是单端口 SRAM，读 A 和读 B 至少仍要两次访问，因此不带数据复用时的理论
下界是约 2 cycle/组，而不是 1 cycle/组。在固定 64L INT8 MAC、单周期 SRAM response、
无 DMA 竞争的 benchmark 中，A2 对 L=16/64/256 GEMV 相对原始基线实测为 **1.73×/1.92×/1.98×**。

### 4.3 特定数据布局下可能降低 SRAM 动态功耗

最简单 VDOT 的 A、B 都必须读，因此“只做 CNM”并不会减少其基本 SRAM 读次数。
但 GEMV/attention 中，一个 activation 往往会服务多个输出或多个本地 weight。若把它
读进 Local PE buffer 后重复使用，就能减少重复 SRAM 读和互连翻转，功耗才更可能下降。

因此 CNM 的功耗优势取决于**数据复用和数据布局**，不是名字本身。应通过 VCD/SAIF
活动率和综合功耗模型验证，不能先承诺具体毫瓦数。

## 5. CNM 不能保证什么

- 不保证把全芯片频率从 250 MHz 提高到 333/400 MHz。
- 不保证最简单 VDOT 的 SRAM 读次数降低。
- 不保证不增加面积：四个 local controller、FIFO/缓冲和累加寄存器需要额外逻辑。
- 不应在没有 A/B 测试前宣称“低功耗”或“2 倍性能”。

当前全芯片关键路径是：

```text
SRAM 输出 -> scratchpad 数据选择 -> Softmax SFU 的 sum_exp 累加寄存器
```

其当前 pre-layout 到达时间约为 3.87 ns。CNM 主要优化 banked VDOT/GEMV；若目标是提高
整个芯片最高频率，还必须单独给 SFU 的指数近似和累加路径增加流水级。

## 6. 怎么证明它真的有效

同一份输入、同一频率下比较旧版和 CNM 版，并保证结果 bit-exact。至少记录：

| 指标 | 意义 |
|---|---|
| 总周期数 | 直接计算 speedup：旧周期 / 新周期 |
| MAC/cycle、PE 利用率 | PE 是否少等待、更多时间在计算 |
| SRAM A/B 读取次数 | 是否真的减少重复读取 |
| 仲裁等待、读响应等待周期 | 瓶颈是否从中央调度中移除 |
| Global Reducer 输入次数 | 是否实现“每输出一次归约” |
| 跨 bank 数据字节数 | 中间结果搬运是否下降 |
| 面积、WNS/TNS、活动功耗 | 确认性能收益没有被面积/时序/功耗抵消 |

推荐工作负载：先测 VDOT，再测 `L=16/64/256` 的 GEMV，最后测一个小 attention tile。

## 7. 推荐做法

演进采用了不重写整个 A8 的方式：保持 CMDQ、DMA、描述符、完成项和寄存器 ABI，先改 opcode
`0x20/0x21` 的 banked VDOT/GEMV，再扩展到 A3.1 GEMM tile：

1. 保持 CMDQ、DMA、描述符、完成项和寄存器 ABI 不变；
2. 加四个 local accumulator；
3. 只在一个输出结束时 Global Reduce；
4. 增加周期、SRAM 读和归约次数计数器；
5. 用随机 INT8、不同向量长度、abort/protection 等场景与旧版对拍；
6. 再决定是否加入独立 bank FSM、预取和双缓冲。

| 阶段 | 改什么 | 预期价值 |
|---|---|---|
| A1 | 每个 bank 加 local accumulator | 已实现；L=256 的全局归约输入事件由 1024 降至 4 |
| A2.2 | 每 bank 独立 Local Controller、地址发生器、读/算流水、双缓冲 | 已实现；大 GEMV 实测 1.98× 同频周期加速 |
| A3.1 | 4×4 GEMM tile、activation/operand 复用与预取 | 已实现；L=256 受控 GEMM 实测 3.97× 相对原始、约 2× 相对 A2 |

当前实现已同时展示 bank-local accumulation、独立流水控制和 GEMM tile 数据复用；后续 A3.2
只应在 UVM/DMA 竞争/SAIF 数据揭示新瓶颈后再定义。

## 8. 项目表述

当前可写：

> NMAForge 是全数字 Compute-Near-Memory 加速器：四个 SRAM bank 分别邻接 Local Controller
> 和 Local PE，在 bank 内完成读请求、预取和累加，仅在输出边界做 Global Reduce。受控 VCS
> benchmark 中，A2 大 GEMV 相对原始版本最高 1.98×，A3.1 GEMM tile 最高 3.97×；功耗收益
> 仍需正确 SAIF 映射和同 workload 的 PPA 对比证明。

## 9. 源码依据

- 原始中央控制/reduction 基线仅保留其历史 benchmark 结论；相应 RTL/TB 已从当前仓库移除，
  不再作为主线回归或实现输入。
- 当前 CNM core 与 local controller：`rtl/compute/cnm/ai_banked_cnm_core.v`、`rtl/compute/cnm/ai_bank_local_controller.v`
- 单个 INT8 dot4 PE：`rtl/compute/cnm/ai_bank_pe.v`
- 四 bank 同行读取：`rtl/memory/ai_scratchpad.v`
- 统一仲裁：`rtl/memory/ai_spad_arbiter.v`
- 当前关键路径证据：`docs/verification/TSMC28_SYNTHESIS_REPORT.md`
