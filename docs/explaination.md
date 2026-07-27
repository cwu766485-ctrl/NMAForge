1. scratchpad-based INT8 accelerator = 基于片上 SRAM 工作区的 INT8 计算加速器
scratchpad 可以理解成“软件可控的片上 SRAM 工作区”。
它和 cache 不一样：
cache：硬件自动决定数据放哪、什么时候替换。
scratchpad：软件/driver/host 明确把数据搬进去、明确告诉硬件从哪里读。

2. descriptor command queue
descriptor 就是一条“任务描述符”。
它不是数据本身，而是告诉硬件要干什么。
op          = GEMV                  
src_a_addr  = 0x0000_1000           请硬件从 scratchpad 的 A 地址和 B 地址取数据，
src_b_addr  = 0x0000_2000           做一次 INT8 GEMV，
dst_addr    = 0x0000_3000           结果写到 dst_addr，
m           = 16                    做完后可选产生 interrupt。
n           = 32
data_type   = INT8
scale       = 2
irq_en      = 1

command queue 就是很多条 descriptor 排成队列：
cmd_queue[0] -> 做 GEMV
cmd_queue[1] -> 做 VADD
cmd_queue[2] -> 做 GEMM
cmd_queue[3] -> 做 L1DIST

3. completion queue = 完成信息
硬件执行完一条 descriptor 后，会往 completion queue 里写一条结果
desc_id     = 5
status      = DONE
error_code  = 0
cycles      = 128
result_addr = 0x0000_3000
host 轮询或者中断后读取 completion queue，就知道：
第 5 个任务完成了
有没有错误
用了多少周期
结果在哪里
command queue      completion queue
host -> 硬件任务     硬件 -> host结果

4. INT8 GEMV / GEMM compute datapath
General Matrix Vector multiplication
矩阵 x 向量
Y = A * X
General Matrix Matrix multiplication
矩阵 x 矩阵
C = A * B
INT8 GEMV/GEMM compute datapath 就是专门做这些计算的数据通路：
SRAM读A/B数据
   |
INT8 sign/zero extend
   |
乘法器 int8 x int8
   |
int32 accumulator
   |
可选 scale / round / saturate
   |
写回 int8/int16/int32 结果

5. SRC/DST/LENGTH/OP/CTRL.start 是啥？是不是 bring-up 相关？
是的，严格说它们就是这个 IP 的软件可见控制接口，bring-up 时主机就是靠这些寄存器把硬件跑起来。
在 [rtl/vec_accel_regs.v (line 97)](E:/workspace/chip/CIMForge/rtl/vec_accel_regs.v:97) 里有寄存器地址：
ADDR_CTRL        = 8'h00
ADDR_SRC0_BASE   = 8'h08
ADDR_SRC1_BASE   = 8'h0c
ADDR_DST_BASE    = 8'h10
ADDR_LENGTH      = 8'h14
ADDR_CONFIG      = 8'h44
含义是：
SRC0_BASE  = 第一个输入向量/矩阵的起始地址
SRC1_BASE  = 第二个输入向量/权重的起始地址
DST_BASE   = 结果写回地址
LENGTH     = 处理多少个 32-bit word
OP         = 做什么运算，放在 CTRL.bit[3:1]
CTRL.start = 写 1 启动一次任务
典型 bring-up 流程就是：
1) Host 通过 AHB 往 scratchpad SRAM 写输入数据
2) Host 写 SRC0_BASE / SRC1_BASE / DST_BASE / LENGTH / CONFIG
3) Host 写 CTRL.start=1 + op_mode
4) 硬件 core 开始从 SRAM 读数据、计算、写结果
5) Host 轮询 STATUS.done，或等 irq
6) Host 从 DST_BASE 或 RESULT 读结果
所以你之前看到的：
写 0x0001_0000 = CTRL.start + OP_VADD
意思是：访问寄存器窗口的 CTRL 寄存器，写入 start=1，并设置 op_mode=VADD。
因为顶层用 [rtl/vec_accel_top.v (line 136)](E:/workspace/chip/CIMForge/rtl/vec_accel_top.v:136) 里的：
assign reg_region  = haddr[16];
assign sram_region = !haddr[16];
所以地址划分是：
haddr[16] = 0 -> SRAM 窗口
haddr[16] = 1 -> 寄存器窗口
也就是：
0x0000_0000 ~ 0x0000_FFFF -> scratchpad SRAM
0x0001_0000 ~ 0x0001_00FF -> 控制寄存

6. external memory descriptor fetch / DMA load-store / scratchpad buffering / INT8 compute / completion writeback / IRQ-status-error
1) external memory descriptor fetch = 硬件自己从外部 DDR/系统内存读取任务描述符
硬件自己取这个任务，不需要 CPU 每次写一堆寄存器。
2) DMA load/store = 硬件自己搬数据
DMA load：从外部 memory 搬到片上 scratchpad。
DMA store：从 scratchpad 把结果搬回外部 memory。
scratchpad buffering = 用片上 SRAM 做临时缓存/工作区
completion writeback = 硬件把任务完成结果写回 completion queue
IRQ/status/error = 中断、状态、错误码

7. vector/SOM compute engine
就是 [rtl/vec_accel_core.v (line 24)](E:/workspace/chip/CIMForge/rtl/vec_accel_core.v:24) 这个模块。
它支持这些 op：
OP_VADD       = 0
OP_VSUB       = 1
OP_VMAC       = 2
OP_L1DIST     = 3
OP_VMUL       = 4
OP_SOM_RECALL = 5
OP_SOM_UPDATE = 6
vector engine 做的是：
VADD:   dst[i] = src0[i] + src1[i]
VSUB:   dst[i] = src0[i] - src1[i]
VMUL:   dst[i] = src0[i] * src1[i]
VMAC:   acc += src0[i] * src1[i]
L1DIST: acc += abs(src0[i] - src1[i])

SOM engine 做的是：
SOM_RECALL:
  拿输入向量 X 和多个 neuron weight 比较
  找 L1 distance 最小的 winner
SOM_UPDATE:
  对指定 neuron 做权重更新
  W_new = W_old + ((X - W_old) >> scale_shift)
它的状态机在 [rtl/vec_accel_core.v (line 89)](E:/workspace/chip/CIMForge/rtl/vec_accel_core.v:89)：
ST_IDLE
ST_READ0
ST_READ0_WAIT
ST_READ1
ST_READ1_WAIT
ST_CALC
ST_WRITE
ST_WRITE_WAIT
ST_DONE
ST_ERROR
这说明它是一个顺序型计算核心：读 src0，等 SRAM；读 src1，等 SRAM；计算；必要时写回；循环处理下一个元素。

8. sram_region 和 reg_region
它俩是顶层地址译码，用 haddr[16] 把一个 AHB 地址空间分为两块。
在 [rtl/vec_accel_top.v (line 136)](E:/workspace/chip/CIMForge/rtl/vec_accel_top.v:136)：
assign reg_region  = haddr[16];
assign sram_region = !haddr[16];
意思是：
haddr[16] = 0 -> sram_region = 1 -> 访问 scratchpad SRAM
haddr[16] = 1 -> reg_region  = 1 -> 访问配置/状态寄存器
对应地址：
0x0000_0000 ~ 0x0000_FFFF -> SRAM window
0x0001_0000 ~ 0x0001_FFFF -> register window
区别：
sram_region:
  host 读写片上 SRAM 数据区，比如输入向量、权重、结果 buffer。

reg_region:
  host 读写控制寄存器，比如 SRC0_BASE、DST_BASE、LENGTH、CTRL.start、STATUS。
举例：
写 0x0000_0100 -> 往 scratchpad SRAM 写数据
写 0x0001_0008 -> 配置 SRC0_BASE 寄存器
写 0x0001_0000 -> 写 CTRL，启动任务
读 0x0001_0004 -> 读 STATUS
所以这不是两个 SRAM 区，而是：
数据区 vs 控制区

9. DOORBELL 和 CMDQ_HEAD
DOORBELL 可以理解成“敲门通知硬件开始干活”
软件先在 command queue 里准备好一个 descriptor，也就是一条任务描述：
op = GEMV / GEMM / VDOT
src0_base
src1_base
dst_base
length / M / N / K
quant / activation
task_id
然后软件写 DOORBELL，告诉硬件：
命令我已经放好了，你可以开始取 descriptor 执行了。
CMDQ_HEAD 是命令队列的读指针。硬件根据它知道当前应该取第几条 descriptor。
比如：
CMDQ_BASE = 0x0000_4000
CMDQ_HEAD = 3
每条 descriptor = 64 bytes
那么硬件取 descriptor 的地址就是：
0x0000_4000 + 3 * 64
执行完这一条以后，硬件把 CMDQ_HEAD 加 1。如果到队列末尾，就 wrap 回 0。
所以：
DOORBELL = 启动通知
CMDQ_HEAD = 当前硬件要消费哪条命令

10.软件怎么使用
软件使用这个 IP 的流程一般是：
1) 准备输入数据和权重
2) 通过 DMA 把数据搬进 scratchpad
3) 配置计算任务
4) 写 DOORBELL 启动
5) 等待 done / IRQ
6) 读取结果或 completion
7) 必要时用 DMA 把结果搬回外部 memory
更具体一点，比如做一次 INT8 GEMV：
第一步：准备数据
软件在 DDR 里准备：
input vector
weight matrix
output buffer
第二步：配置 DMA load
软件写 DMA 寄存器：
DMA_EXT_ADDR  = DDR 里 input/weight 的地址
DMA_SPAD_ADDR = scratchpad 里的目标地址
DMA_LENGTH    = 搬多少 byte
DMA_CTRL      = start load
DMA 会把数据从外部 memory 搬到片上 scratchpad。
第三步：配置计算任务
软件配置计算寄存器，或者写一条 descriptor：
OP_MODE   = GEMV
SRC0_BASE = input vector 在 scratchpad 的地址
SRC1_BASE = weight matrix 在 scratchpad 的地址
DST_BASE  = output 在 scratchpad 的地址
M_SIZE    = 输出行数
K_WORDS   = 每行多少 packed int8 word
QUANT_ACT = 量化/激活配置
如果用 command queue，则软件把这些字段写成一条 64-byte descriptor，然后更新 CMDQ_HEAD / 写 DOORBELL。
第四步：启动硬件
简单寄存器模式：
写 CTRL.start = 1
队列模式：
写 DOORBELL = 1
含义是：
软件告诉硬件：任务已经准备好了，可以开始执行。
第五步：硬件执行
硬件内部流程是：
descriptor fetch
-> 从 scratchpad 读 input/weight
-> INT8 compute core 计算
-> 结果写回 scratchpad
-> completion writer 写完成记录
-> STATUS.done = 1
-> 如果 IRQ_ENABLE=1，则 irq 拉高
第六步：软件收尾
软件可以轮询：
while ((STATUS & DONE) == 0) {
    ;
}
也可以等中断：
IRQ 拉高 -> CPU 进入中断服务函数
然后软件读取：
STATUS
RESULT
ERROR_CODE
completion entry
如果结果要回 DDR，再启动 DMA store：
DMA_EXT_ADDR  = DDR output buffer
DMA_SPAD_ADDR = scratchpad output 地址
DMA_LENGTH    = 输出长度
DMA_CTRL      = start store

11. CIM 是 Compute-In-Memory，存内计算。
真正 CIM 的意思是：
计算发生在 memory macro 内部，甚至发生在 bitcell / bitline / sense amplifier 附近。
比如 SRAM CIM 可能会做：
在 bitline 上做加法/乘加
利用 SRAM cell 同时读多行
在 sense amplifier 附近完成部分 MAC
用模拟电压/电流代表计算结果