# NMAForge 地址图

地址来源：`rtl/top/ai_accel_top.v` 的 `SPAD_BASE/SPAD_LIMIT` 与
`rtl/control/axi_lite/ai_accel_regs.v` 的寄存器常量。

| 区域 | 地址 | 大小 | 接口 | 说明 |
|---|---:|---:|---|---|
| Register window | `0x0000_0000`–`0x0000_01B0`（已定义最高寄存器） | 由合法地址检查覆盖 512 B 页 | AXI4-Lite | `ai_accel_regs` |
| Scratchpad host window | `0x0001_0000`–`0x0008_FFFF` | 512 KiB | AXI4-Lite host port | 4 banks × 128 KiB |

顶层将 AXI-Lite 地址折叠为 aperture-relative low 20 bits 后再译码；寄存器要求
4-byte 对齐和完整 `WSTRB=4'hf` 写入。其余地址或非法写访问返回 `SLVERR`。
