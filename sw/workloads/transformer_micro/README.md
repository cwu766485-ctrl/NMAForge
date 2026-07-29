# 4×4 Transformer 端到端微型工作负载

这个 workload 不是新增一批孤立算子，而是验证现有算子能否通过 ABI v7 descriptor
真正串成数据依赖闭环：

```text
Q/K/V GEMM
→ QK^T
→ 逐行 Softmax
→ Attention × V
→ 输出投影
→ Residual + LayerNorm
→ FFN GEMM + GELU + GEMM
→ Residual + LayerNorm
```

规模固定为 4 token、hidden size 4、单 attention head，以控制 RTL 仿真时间。
`sw/tools/cimforge_mapper.py` 负责 scratchpad 地址分配、row/column packed INT8
布局转换、ABI v7 descriptor 编码和 bit-accurate golden result。它还检查每条
命令的输入是否已由常量或前序命令生产，并用 poison pattern 初始化所有输出，
防止预填 golden 导致假通过。它会生成：

- `manifest.json`：软件可读的 tensor/descriptor 映射；
- `verif/generated/ai_transformer_workload.svh`：VCS smoke 使用的确定性 fixture。

生成并运行：

```bash
make -C verif/sim ai_transformer_gen
cd verif/sim
make ai_transformer
```

Softmax 输出为 Q0.15，进入下一次 INT8 GEMM 前会右移 8 bit 并饱和；该量化边界用于
验证硬件组合和数据布局，不代表训练后模型的最终量化策略。
