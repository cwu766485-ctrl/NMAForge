# G1 BF16 乘法器 Block 报告

日期：2026-10-13
状态：独立乘法 block 已通过当前工作区的 VCS 定向与随机 bit-exact 仿真；G1 整体尚未完成。

## 验证范围

- RTL：`rtl/compute/fp/ai_bf16_mul_fp32.v`
- 独立参考：`dv/block/compute/fp/model/fp_reference.py`
- 向量生成：`dv/block/compute/fp/model/generate_mul_vectors.py`
- Testbench：`dv/block/compute/fp/tb/tb_ai_bf16_mul_fp32.sv`
- 算子：BF16 × BF16 → FP32，RNE；canonical qNaN；覆盖 ±0、subnormal、Inf、NaN、下溢和溢出边界。
- 本模块是组合逻辑，没有 request/response handshake、内部状态或累加器；不代表完整 dot-product engine。

## 可复现命令与结果

在 Rocky Linux 8.10、Synopsys VCS V-2023.12-SP1_Full64 环境中执行。应从已加载本机 license 配置的交互式 WSL shell、仓库根目录运行；本机还需将 `VCS_HOME` 指向已安装的 VCS 版本。报告不记录任何 license server/凭据值。

```bash
# Set VCS_HOME to the locally installed VCS release; license configuration stays local.
export PATH="$VCS_HOME/bin:$PATH"
make -C dv/block/compute/fp/sim test SEED=20261013 RANDOM_CASES=10000
(cd dv/block/compute/fp/model && PYTHONDONTWRITEBYTECODE=1 python3.12 -m unittest -v test_fp_reference.py)
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=1791860897
```

结果：

- Focused VCS：`FP_BF16_MUL_FP32_PASS vectors=10032`，32 个 directed + 10,000 个固定种子随机 vectors，0 mismatch，退出码 0。日志在本机 `/tmp/nmaforge_bf16_mul_fp32/`，未复制进仓库。
- Raw-bit Python reference：16/16 tests 通过。
- `make ai_smoke`：top testbench `TEST PASS`。
- Seeded top regression：`TEST PASS`，20 个随机用例；NTB seed `1791860897`、workload seed `12345`。
- `git diff --check`：通过。
- Top smoke compile 仍有一条既有 `Warning-[TFIPC] Too few instance port connections`，位于 `rtl/top/fabric/compute/ai_accel_compute_cluster.v:163` 的 `ai_banked_cnm_core` 实例。它不是新增 BF16 端口造成的，不能将这次构建描述成零 warning。

随机向量由独立 raw-bit Python reference 生成。随机输入覆盖完整 16-bit 原始编码空间，但随机样本数量不等同于数值类别 coverage closure；特殊值和舍入边界另由 directed vectors 检查。该测试不是形式等价证明，也不是 UVM signoff。

## 集成状态与限制

RTL 已加入 top smoke、top UVM、SpyGlass lint、SpyGlass 静态项目和两套 FPGA RTL source list；top smoke 与 seeded regression 已在更新后的 smoke filelist 上通过。它尚未被 `ai_accel_compute_cluster` 实例化，也没有接入 `ai_command_processor`、descriptor opcode、SPAD 读写或 completion 生命周期。因此，当前 PASS 只证明独立乘法 block 对该参考模型的逐位一致性，以及源清单更新未破坏现有 top 工作负载。

仍待完成：

1. 非融合 FP32 累加器及长链逐步舍入验证。
2. BF16/FP16 Add/Sub 独立算术 block 与 corner-case 验证。
3. 对完整 block 设计补充更广的 SVA/coverage 与 lint/综合检查。
4. 为整个算术 block 补充更广的 SVA/coverage 与 lint/综合检查；SpyGlass、DC 与 FPGA OOC 仍未在本批次运行。

本结果不包含 DC PPA、Vivado OOC、SpyGlass signoff、FP16 RTL 或端到端 opcode 验证。
