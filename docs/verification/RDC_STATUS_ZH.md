# RDC 状态记录

更新时间：2026-09-29

## 已确认

- 工具：SpyGlass V-2023.12-SP1
- Top：`ai_accel_top`
- 运行目录：`dv/spyglass/a8_static/ai_accel_top/rdc/rdc_verify_struct/`
- 约束：`dv/spyglass/a8_constraints.sgdc`
- 当前约束声明一个时钟域 `aclk` 和一个异步低有效复位 `aresetn`。
- `spyglass.log` 显示已加载 `clock-reset` policy，并执行 RDC 相关规则。

## 当前结论

2026-09-29 从正确目录执行 `./run_spyglass_a8.sh rdc`。许可证已成功获取，
RDC 进入第 385/478 条规则 `Ar_resetcross01`（reset crossing）后持续展开；
`check.Linux4` 运行约 14 分钟，RSS 峰值约 14.7 GiB，随后被 WSL/系统 OOM killer
终止（shell 显示 `Killed`，命令退出码为 1）。未形成可审计的最终
violation/message summary。因此当前状态是：

```text
RDC run artifact: available
RDC final summary: missing (resource terminated)
RDC RTL violation result: unknown
RDC sign-off: unresolved
```

不能将本次结果写成 `0 violation`，也不能把 OOM 归因于 RTL；它只证明当前全顶层
RDC 运行配置超过本机可用内存。2026-09-28 的 12 GiB 虚拟内存预算 run 与本次
未显式限额 run 都未产出 final summary。

本次命令为：

```bash
cd dv/spyglass
./run_spyglass_a8.sh rdc
```

环境为 SpyGlass V-2023.12-SP1、WSL 约 15 GiB RAM/4 GiB swap。CDC 在同一环境中
已完成 `cdc_setup` 和 `cdc_verify_struct`，两者均为 0 error / 0 warning；本条不
外推为 RDC PASS。后续需要设置显式内存/时限预算，并在更大内存主机或经站点应用
工程师确认的分层/拆分 RDC policy 下，获取 final summary。

## 当前设计时钟事实

产品 top 目前只有 `aclk`。AXI-Lite、AXI4 master、DMA、scratchpad、compute cluster、completion writer 和 performance monitor 均连接到该时钟；异步 FIFO 原型尚未接入产品 top。

## 关闭条件

1. 为 RDC 设置可复现的内存与时限预算；若预算不足，明确报为 `resource-limited`，不覆盖旧日志。
2. 将 reset release、reset reconvergence、reset-domain crossing 作为可审计的子目标，优先取得各目标的文本 summary。
3. 只从文本报告提取 violation、error、warning、waiver 和 rule summary，不扫描二进制 `.sdb`。
4. 将最终 summary、预算和命令环境保存到本目录对应的审计记录。
5. 若引入 `ctrl_clk/compute_clk`，先更新 SGDC 时钟/复位意图，再重新执行 CDC/RDC。
