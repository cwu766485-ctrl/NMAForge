# SFU 定点数值合同

**状态：冻结，用于 Compute Cluster v1.3 的 REQ-CL-023 检查。**本合同定义 RTL 现有的确定性定点运算，不把它们描述成精确实数 Softmax、GELU 或 SiLU。验收使用本文件的整数公式和独立 Python 模型逐位比较。

## 通用范围

- 合同范围内向量长度为 `1..65535`；所有 SPAD 基地址按 32-bit word 对齐。数值回归覆盖长度 `1, 2, 3, 4, 7, 8, 15, 16`。
- Softmax、RMSNorm、LayerNorm、GELU、SiLU 输入按有符号 16-bit 数值符号扩展到 word；Softmax/GELU/SiLU 输入为 Q8.8。超出此范围的输入暂不属于本合同的验收域。
- Normalization 的 gamma 使用有符号 Q0.15 word；LayerNorm beta 为有符号 INT32 输出域偏置。Residual 输入为有符号 INT32。Requant 输入为有符号 INT32，右移量 `0..31`。
- 有符号 `>>>` 是算术右移（负值向负无穷方向取整）；除法按无符号幅值做整数除法后恢复符号，即向 0 截断；整数平方根向下取整。所有标为 `sat32` 的结果饱和到 `[-2^31, 2^31-1]`。
- `epsilon=0` 的 RMSNorm/LayerNorm 输入被规范化为 raw value `1`；Causal Softmax 的 epsilon 字段表示 query index，不做该替换。

## Opcode 运算

| Opcode / 运算 | 冻结整数语义 |
|---|---|
| `0x32` Softmax Q15 | `m=max(x)`；`d=x-m`；近似指数 `E(d)` 见下式；`S=sum(E)`；输出 `min(floor(E*2^15/S), 32768)`。合法输入下 `S>0`。 |
| `0x39` Causal Softmax Q15 | query 是 `[0,length-1]` 的零基、包含端点索引。先对 `x[0..query]` 使用相同 Softmax 公式；`i>query` 的输出为 0。 |
| `0x33` RMSNorm | `mean_sq=floor(sum(x²)/N)`；`root=isqrt(mean_sq+epsilon)`；`inv=floor(2^30/root)`；`g=sat32((x*gamma)>>>15)`；`y=sat32((g*inv)>>>30)`。无 gamma base 时 gamma 取 `32768`。 |
| `0x38` LayerNorm | `mean=trunc0(sum(x)/N)`；`var=floor(sum((x-mean)²)/N)`；`root=isqrt(var+epsilon)`；`inv=floor(2^30/root)`；`g=sat32(((x-mean)*gamma)>>>15)`；`y=sat32(((g*inv)>>>30)+beta)`。beta 关闭时 beta 为 0。 |
| `0x34` Residual INT32 | `y=sat32((x+y)>>>shift)`；加法先在 64-bit 有符号域完成。 |
| `0x35` GELU Q8.8 近似 | `x<=-512` 时 0；`x>=512` 时 x；否则 `(x*(x+512))>>>10`。 |
| `0x37` SiLU Q8.8 近似 | `x<=-768` 时 0；`x>=768` 时 x；否则 `trunc0(x*(x+768)/1536)`。 |
| `0x36` Requant INT8 | `v=x>>>shift`；饱和到 `[-128,127]`。非打包输出为符号扩展 INT8；打包时按输入顺序将 4 个低字节放入 word `[7:0]`、`[15:8]`、`[23:16]`、`[31:24]`。末尾不完整 word 将剩余元素放在低字节，未用高字节为 0。 |

负 delta 的 Q15 指数近似定义为：令 `a=-d`、`q=floor(a/256)`、`r=a mod 256`。当 `q>=15` 时 `E=0`；否则 `b=floor(32768/2^q)`、`n=floor(b/2)`，`E=b-floor((b-n)*r/256)`。`d>=0` 时 `E=32768`。这条公式是可复现的实现合同，不附加相对真实指数函数的误差保证。

## 错误、写回和验证边界

- Softmax 的零除数、normalization 的零平方根/除法器错误按 `ERR_NUMERIC` 结束；合法正长度和上述输入域不得触发这些错误。
- 结果按输出 word 顺序提交；每个被 SPAD 接受的写均由 memory image scoreboard 对拍。错误前已接受的输出是保留前缀，不回滚；错误被观察后不得再接受该任务的后续输出写。
- VCS `SFU-RAND-NUM-EDGE-3S-20261028` 用独立 `ai_a3_reference.py` 对 8 个 opcode、8 个长度、64 个 vector/seed 做 bit-exact 检查；输入包含符号边界、PWL 分段边界、epsilon=0、gamma、beta 和 INT32 溢出边界、Requant 饱和和所有合法 shift。另有原有 randomized latency、fault、reset 和 recovery 检查。该证据只覆盖表列域和实际 testpoint，不表示对任意长度/全 32-bit 输入或理想实数函数误差收敛。
