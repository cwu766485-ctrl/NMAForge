# G1 FP32 加法器 Block 报告

日期：2026-10-13
状态：独立组合 FP32 RNE 加法器已通过当前工作区的定向与固定种子随机 bit-exact 仿真；G1 整体尚未完成。

## 验证范围

- RTL：`rtl/compute/fp/ai_fp32_add.v`
- 独立参考：`dv/block/compute/fp/model/fp_reference.py` 中的 `fp32_add_bits`
- 向量生成：`dv/block/compute/fp/model/generate_fp32_add_vectors.py`
- Testbench：`dv/block/compute/fp/tb/tb_ai_fp32_add.sv`
- 运算：IEEE-754 binary32 加法，round-to-nearest ties-to-even (RNE)、gradual underflow、canonical qNaN；不输出 IEEE exception flags。
- 该模块为组合算术 block；不包含累加寄存器、握手、命令生命周期或 scratchpad 访问。

## 可复现命令与结果

在 Rocky Linux 8.10、Synopsys VCS V-2023.12-SP1_Full64 环境中，于加载本机 VCS 环境的交互式 WSL shell 中执行：

```bash
# Set VCS_HOME to the locally installed VCS release; license configuration stays local.
export PATH="$VCS_HOME/bin:$PATH"
make -C dv/block/compute/fp/sim add-test SEED=20261013 RANDOM_CASES=10000
make -C dv/block/compute/fp/sim add-test SEED=987654321 RANDOM_CASES=100000
(cd dv/block/compute/fp/model && PYTHONDONTWRITEBYTECODE=1 python3.12 -m unittest -v test_fp_reference.py)
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=1791860897
```

结果：

- 首轮 focused VCS：`FP32_ADD_PASS vectors=10036`，36 个 directed + 10,000 个固定种子随机原始位型，0 mismatch，退出码 0。
- 加大随机量复核：`FP32_ADD_PASS vectors=100036`，36 个 directed + 100,000 个固定种子随机原始位型，0 mismatch，退出码 0。
- Python raw-bit reference 单元测试：16/16 通过。
- 加入 BF16 乘法器和 FP32 加法器后的 top `ai_smoke`：`TEST PASS`。
- 同一 source-list 状态下 seeded top regression：20 个随机用例 `TEST PASS`；workload seed `12345`、NTB seed `1791860897`。
- Top 编译仍有一条既有 `Warning-[TFIPC] Too few instance port connections`，位置为 `rtl/top/fabric/compute/ai_accel_compute_cluster.v:163` 的 `ai_banked_cnm_core` 实例；本批没有将该告警误报为零 warning。

随机输入按原始 32-bit 编码生成；两个随机规模都通过独立 Python raw-bit oracle 比对。随机样本不等同于功能覆盖率闭合，也不构成形式等价或 UVM signoff。

## 集成状态与限制

FP32 加法器已加入 top smoke、top UVM、SpyGlass lint/static 和两套 FPGA RTL source list；顶层 smoke 与 seeded regression 均在该 source-list 状态下通过。模块尚未被产品 compute cluster 实例化，也未接入 BF16 dot、descriptor opcode、scratchpad 或 completion 生命周期。因此 PASS 仅代表独立组合加法器在已测向量上的逐位一致性，以及新增 source-list 项未破坏现有 top 工作负载。

后续仍须完成：

1. 有状态 FP32 累加器已实现并独立对拍，验证证据见 [`FP_G1_FP32_ACCUMULATOR_REPORT.md`](FP_G1_FP32_ACCUMULATOR_REPORT.md)。
2. BF16/FP16 Add/Sub block 已通过独立回归，证据见 [`FP_G1_ADDSUB_REPORT.md`](FP_G1_ADDSUB_REPORT.md)。
3. 对完整 block 设计补充 SVA、coverage、lint/综合检查。
4. G2 才进行 opcode、命令生命周期、SPAD 顺序读写与 completion 集成。

本结果不包含 DC PPA、Vivado OOC、SpyGlass signoff 或端到端 opcode 验证。
