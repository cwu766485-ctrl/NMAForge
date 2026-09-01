# NMAForge 文档索引

[English documentation](README.md) · [项目中文 README](../README_ZH.md)

本文档集描述当前的全数字近存张量加速器。公开仓库刻意不包含受许可约束的 PDK、
厂商板卡资料、凭据、生成报告和个人环境操作记录。

| 文档 | 用途 |
|---|---|
| [SPEC_ZH.md](SPEC_ZH.md) / [SPEC.md](SPEC.md) | 中英文 ABI v7.2 规格：接口、队列、DMA、算子与边界。 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 模块所有权、控制/数据流与数字 CNM 数据通路。 |
| [VPLAN.md](VPLAN.md) | 验证计划、已有证据和待收口项。 |
| [TSMC28_SYNTHESIS_REPORT.md](TSMC28_SYNTHESIS_REPORT.md) | 脱敏后的商用 28nm pre-layout 综合证据及边界。 |
| [XCZU15EG_BRINGUP.md](XCZU15EG_BRINGUP.md) | 板卡拥有者使用的 bring-up 流程；厂商资料在仓库外。 |
| [CNM_BANK_LOCAL_PE_RESEARCH_ZH.md](CNM_BANK_LOCAL_PE_RESEARCH_ZH.md) | bank-local 数字 CNM 的设计动机。 |
| [CNM_EVALUATION.md](CNM_EVALUATION.md) | 可公开的 CNM benchmark/评估摘要和适用边界。 |
| [PUBLIC_RELEASE.md](PUBLIC_RELEASE.md) | 可公开内容与安全 GitHub 发布流程。 |

## 文档规则

- 修改 ABI 可见行为时，先更新规格和软件头文件，再修改 RTL。
- 只记录真实运行过的工具结果，并注明 PVT/约束以及 pre-layout、post-route 或实板边界。
- 长期架构/证据放入上表主题文档；私有更新日志、聊天导出和工具缓存不进入 Git。
- 公开项目名统一为 **NMAForge**；历史 `CIMFORGE_*` ABI 标识仅为源码兼容保留。
