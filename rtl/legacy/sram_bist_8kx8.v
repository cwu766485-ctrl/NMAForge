`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sram_bist_8kx8

// 模块功能：
//   单片 8K x 8-bit SRAM 的 BIST 控制器。
//
//   正常模式下，addr_fun/wen_fun/cen_fun/oen_fun/data_fun 直接透传给 SRAM。
//   BIST 模式下，本模块生成 SRAM 测试地址、测试数据和读写控制信号，
//   通过写 0、读 0 比较、写 1、读 1 比较等序列检查 SRAM 存储功能。
//
// 关键输出：
//   b_done：BIST 流程结束。
//   b_fail：BIST 比较失败标志。读出的数据与期望 pattern 不一致时置 1。
//
// 综合理解：
//   该模块主要由一个 BIST 状态机、一个测试地址计数器、一个 fail 寄存器、
//   以及功能模式/BIST 模式选择 mux 组成。
//////////////////////////////////////////////////////////////////////////////////


module sram_bist_8kx8
#(parameter WE_WIDTH = 1,
  parameter ADDR_WIDTH = 13,
  parameter DATA_WIDTH = 8
 )
 (
  //----------------------------------------------------------------------
  // 输入信号
  //----------------------------------------------------------------------
  input                      b_clk,        // BIST 状态机时钟。
  input                      b_rst_n,      // BIST 低有效复位。
  input                      b_te,         // BIST 使能。1：BIST 模式；0：功能模式。
  input [(ADDR_WIDTH-1):0]   addr_fun,     // 功能模式 SRAM 地址。
  input [(WE_WIDTH-1):0]     wen_fun,      // 功能模式 SRAM 写使能，低有效。
  input                      cen_fun,      // 功能模式 SRAM 片选，低有效。
  input                      oen_fun,      // 功能模式 SRAM 输出使能，低有效。
  input [(DATA_WIDTH-1):0]   data_fun,     // 功能模式 SRAM 写数据。
  input [(DATA_WIDTH-1):0]   ram_read_out, // SRAM 当前读数据，用于 BIST 比较。

  //----------------------------------------------------------------------
  // 输出到 SRAM 的最终信号
  //
  // b_te=0 时，这些信号选择功能模式输入。
  // b_te=1 时，这些信号选择 BIST 状态机生成的测试信号。
  //----------------------------------------------------------------------
  output [(ADDR_WIDTH-1):0]  addr_test, // 最终送入 SRAM 的地址。
  output [(WE_WIDTH-1):0]    wen_test,  // 最终送入 SRAM 的写使能，低有效。
  output                     cen_test,  // 最终送入 SRAM 的片选，低有效。
  output                     oen_test,  // 最终送入 SRAM 的输出使能，低有效。
  output [(DATA_WIDTH-1):0]  data_test, // 最终送入 SRAM 的写数据。
  output				     b_done,    // BIST 完成标志。

  output reg                 b_fail     // BIST 失败标志，1 表示读比较失败。
);

  //----------------------------------------------------
  // BIST 状态编码
  //
  // 状态名前缀含义：
  //   P1/P2/.../P6 表示 BIST 测试流程中的不同阶段。
  //   WRITE0/WRITE1 表示向 SRAM 写全 0 或全 1。
  //   READ0/READ1 表示读出 SRAM 数据。
  //   COMPARE0/COMPARE1 表示与期望的全 0 或全 1 pattern 比较。
  //----------------------------------------------------
  `define IDEL1         5'b00000
  `define P1_WRITE0     5'b00001
  `define IDEL2         5'b00010
  `define P2_READ0      5'b00011
  `define P2_COMPARE0   5'b00100
  `define P2_WRITE1     5'b00101
  `define IDEL3         5'b00110
  `define P3_READ1      5'b00111
  `define P3_COMPARE1   5'b01000
  `define P3_WRITE0     5'b01001
  `define P3_READ0      5'b01010
  `define P3_COMPARE0   5'b01011
  `define P3_WRITE1     5'b01100
  `define IDEL4         5'b01101
  `define P4_READ1      5'b01110
  `define P4_COMPARE1   5'b01111
  `define P4_WRITE0     5'b10000
  `define IDEL5         5'b10001
  `define P5_READ0      5'b10010
  `define P5_COMPARE0   5'b10011
  `define P5_WRITE1     5'b10100
  `define P5_READ1      5'b10101
  `define P5_COMPARE1   5'b10110
  `define P5_WRITE0     5'b10111
  `define IDEL6         5'b11000
  `define P6_READ0      5'b11001
  `define P6_COMPARE0   5'b11010
  
  // BIST 模式下生成的 SRAM 测试地址。
  reg [(ADDR_WIDTH-1):0] test_addr;
  
  // BIST 结束寄存器和置位控制。
  reg r_end;
  reg r_end_en;
 
  // 测试地址复位控制。配合 up1_down0 决定复位到 0 还是最大地址。
  reg test_addr_rst;

  // BIST 模式下产生的 SRAM 写使能，低有效。
  reg [(WE_WIDTH-1):0] wen_test_inner;

  // BIST 启动脉冲，用于清除 b_fail。
  reg rf_start;
  
  // 比较使能。为 1 时，将 ram_read_out 和 test_pattern 比较。
  reg check_en;

  // 测试 pattern 选择：
  //   pattern_sel=0 -> test_pattern 全 0。
  //   pattern_sel=1 -> test_pattern 全 1。
  reg pattern_sel;
  wire [(DATA_WIDTH-1):0] test_pattern;
  reg [4:0] cstate, nstate;
  // 地址扫描方向。1：递增扫描；0：递减扫描。
  reg up1_down0; 
  // 地址计数使能。1：地址步进；0：地址保持。
  reg count_en;  


  //-----------------------------------------------------------------
  // 主逻辑
  //-----------------------------------------------------------------

  //-----------------------------------------------------------------
  // 组合逻辑：done 输出和测试 pattern 生成
  //-----------------------------------------------------------------
  assign b_done = r_end;
  assign test_pattern = (pattern_sel == 1'b0) ? {DATA_WIDTH{1'b0}} : {DATA_WIDTH{1'b1}};

  //--------------------------------------------------------------------
  // 功能模式 / BIST 模式选择 mux
  //
  // 综合后的电路：
  //   这些 assign 会综合成一组 2:1 mux。
  //
  // b_te=0：
  //   SRAM 使用外部功能模式输入 addr_fun/wen_fun/cen_fun/oen_fun/data_fun。
  //
  // b_te=1：
  //   SRAM 使用 BIST 状态机生成的 test_addr/wen_test_inner/test_pattern。
  //---------------------------------------------------------------------
  assign data_test = (b_te == 1'b1) ? test_pattern   : data_fun;
  assign addr_test = (b_te == 1'b1) ? test_addr      : addr_fun;
  assign wen_test  = (b_te == 1'b1) ? wen_test_inner : wen_fun;
  assign cen_test  = (b_te == 1'b1) ? 1'b0           : cen_fun;
  assign oen_test  = (b_te == 1'b1) ? 1'b0           : oen_fun;

  //--------------------------------------------------------------------
  // 时序逻辑 1：BIST done 寄存器
  //
  // 综合后的电路：
  //   一个带低有效异步复位的 D 触发器。
  //
  // 行为：
  //   r_end_en 由状态机在最后一个比较阶段拉高。
  //   r_end 被置 1 后，通过 b_done 输出表示本片 SRAM 的 BIST 已完成。
  //--------------------------------------------------------------------
  always @(posedge b_clk , negedge b_rst_n) begin
    if (b_rst_n == 1'b0) 
       r_end<=1'b0;
    else if (r_end_en == 1'b1) 
       r_end<= 1'b1;
       else
         r_end <= 1'b0;
  end
  //--------------------------------------------------------------------
  // 时序逻辑 2：BIST 测试地址计数器
  //
  // 综合后的电路：
  //   ADDR_WIDTH 位 D 触发器 + 加 1/减 1 计数逻辑 + 复位选择 mux。
  //
  // 控制含义：
  //   test_addr_rst=1 时重装地址：
  //     up1_down0=1 -> 从 0 开始递增扫描。
  //     up1_down0=0 -> 从最大地址开始递减扫描。
  //
  //   count_en=1 时地址步进：
  //     up1_down0=1 -> test_addr + 1。
  //     up1_down0=0 -> test_addr - 1。
  //--------------------------------------------------------------------
  always @(posedge b_clk , negedge b_rst_n) begin
    if (b_rst_n == 1'b0) 
       test_addr <= {ADDR_WIDTH{1'b0}};
    else if (b_te == 1'b1) 
  	  if (test_addr_rst == 1'b1) 
           if (up1_down0 == 1'b1)
          	  test_addr<=  {ADDR_WIDTH{1'b0}};
           else
              test_addr<=  {ADDR_WIDTH{1'b1}};
     	else
           if (count_en == 1'b1)
               if (up1_down0 == 1'b1)
          	      test_addr<=  test_addr + 1'b1; // 地址从小往大扫描
               else
                  test_addr<=  test_addr - 1'b1; // 地址从大往小扫描
  end

  //--------------------------------------------------------------------
  // 时序逻辑 3：BIST fail 寄存器
  //
  // 综合后的电路：
  //   一个带低有效异步复位的 D 触发器。
  //
  // 行为：
  //   复位后默认为 1，表示尚未确认 SRAM 正常。
  //   BIST 从 IDEL1 启动时 rf_start 拉高，将 b_fail 清 0。
  //   任意比较周期中，如果读数据 ram_read_out != 期望 test_pattern，
  //   b_fail 被置 1，并保持失败结果。
  //--------------------------------------------------------------------
  always @(posedge b_clk , negedge b_rst_n)
    if (b_rst_n == 1'b0) 
       b_fail<=1'b1;
    else begin
      if ((b_te == 1'b1) && (rf_start == 1'b1)) // 重新启动清零
          b_fail<=  1'b0;

      if ((b_te == 1'b1) && (check_en == 1'b1) && !(test_pattern == ram_read_out)) // 写的跟读出的是否一致
          b_fail<=  1'b1;
     end
  
  //------------------------------------------------------------------------------
  // BIST 测试状态机总体流程
  //
  // 该状态机实现类似 March 的存储器测试序列，核心思想是：
  //   1. 先把所有地址写成 0。
  //   2. 按某个方向读 0、比较，再写 1。
  //   3. 反方向读 1、比较，再写 0。
  //   4. 多轮改变数据 pattern 和地址方向，覆盖 stuck-at、地址相关等常见故障。
  //
  // 简化流程：
  //   write 0                           地址 0 -> max
  //   read 0 -> compare -> write 1      地址 max -> 0
  //   read 1 -> compare -> write 0      地址 0 -> max
  //   write/read/compare 继续交替       直到最后一轮 compare 结束
  //------------------------------------------------------------------------------

  //--------------------------------------------------------------------
  // 时序逻辑 4：状态寄存器
  //
  // 综合后的电路：
  //   5-bit 状态寄存器，低有效异步复位到 IDEL1。
  //--------------------------------------------------------------------
  always @(posedge b_clk , negedge b_rst_n) begin
    if (b_rst_n == 1'b0) 
          cstate<=`IDEL1;
    else
          cstate<= nstate;
  end
  
  //--------------------------------------------------------------------
  // 组合逻辑：下一状态和 BIST 控制信号生成
  //
  // 综合后的电路：
  //   组合状态转移逻辑 + 输出译码逻辑。
  //
  // 默认值：
  //   每次进入 always 块先给所有控制信号默认值，避免 latch。
  //
  // 主要输出控制：
  //   wen_test_inner：BIST 写使能，0 写，1 读。
  //   pattern_sel   ：选择写/比较全 0 还是全 1。
  //   check_en      ：使能读数据比较。
  //   count_en      ：测试地址是否步进。
  //   up1_down0     ：地址递增或递减。
  //   test_addr_rst ：测试地址重装。
  //   r_end_en      ：最后一轮完成时置位 done。
  //--------------------------------------------------------------------
  always @(cstate or b_te or r_end or test_addr) begin
    up1_down0     = 1'b1;
    count_en      = 1'b0;
    r_end_en      = 1'b0;
    pattern_sel   = 1'b0;
    test_addr_rst = 1'b0;
    rf_start      = 1'b0;
    check_en      = 1'b0;
    wen_test_inner = {WE_WIDTH{1'b1}};
    nstate        = cstate;
    case (cstate)
      `IDEL1 :
          begin
             test_addr_rst = 1'b1;
             if (b_te == 1'b1 && r_end == 1'b0) begin
                   nstate   = `P1_WRITE0;
                   rf_start = 1'b1;
             end
          end
      `P1_WRITE0 :   // 初始化 SRAM：从低地址到高地址写全 0。
          begin
    	    count_en       = 1'b1;
    	    wen_test_inner = {WE_WIDTH{1'b0}};
    	    pattern_sel    = 1'b0;
             if (test_addr == {ADDR_WIDTH{1'b1}} ) begin
                  nstate        = `IDEL2;
                  test_addr_rst = 1'b1;
    	            up1_down0     = 1'b0;
             end
          end
      `IDEL2 :
          begin
    	      pattern_sel   = 1'b0;
    	      up1_down0     = 1'b0;
            test_addr_rst = 1'b1; 
            nstate        = `P2_READ0;
          end
      `P2_READ0 :
          begin
            nstate = `P2_COMPARE0;
          end
      `P2_COMPARE0 :  // 比较读出的数据是否为全 0。
          begin
             pattern_sel = 1'b0;
    	       check_en    = 1'b1;
             nstate      = `P2_WRITE1;
          end
      `P2_WRITE1 :  // 从高地址到低地址写全 1。
          begin
    	      up1_down0      = 1'b0;
    	      count_en       = 1'b1;
    	      wen_test_inner = {WE_WIDTH{1'b0}};
    	      pattern_sel    = 1'b1;
             if (test_addr == {ADDR_WIDTH{1'b0}}) begin
                  nstate        = `IDEL3;
                  test_addr_rst = 1'b1;
    	          up1_down0     = 1'b1;
             end
             else
                nstate        = `P2_READ0;
          end
      `IDEL3 :
          begin
             pattern_sel   = 1'b1;
             test_addr_rst = 1'b1;
             nstate        = `P3_READ1;
          end
      `P3_READ1 :
          begin
             nstate = `P3_COMPARE1;
          end
      `P3_COMPARE1 :  // 比较读出的数据是否为全 1。
          begin
            pattern_sel = 1'b1;
            check_en    = 1'b1;
            nstate      = `P3_WRITE0;
          end
      `P3_WRITE0 :
          begin
             wen_test_inner = {WE_WIDTH{1'b0}};
             pattern_sel    = 1'b0;
             nstate         = `P3_READ0;
          end
      `P3_READ0 :
          begin
            nstate = `P3_COMPARE0;
          end
      `P3_COMPARE0 :
          begin
            pattern_sel = 1'b0;
            check_en    = 1'b1;
            nstate      = `P3_WRITE1;
          end
      `P3_WRITE1 :
          begin
             wen_test_inner = {WE_WIDTH{1'b0}};
             pattern_sel    = 1'b1;
             count_en       = 1'b1;
             if (test_addr == {ADDR_WIDTH{1'b1}}) begin
                  nstate        = `IDEL4;
                  test_addr_rst = 1'b1;
             end
             else
                nstate        = `P3_READ1;
          end
      `IDEL4 :   // 准备下一轮读 1 / 比较 / 写 0 流程。
          begin
            pattern_sel   = 1'b1;
            test_addr_rst = 1'b1;
            nstate        = `P4_READ1;
          end
      `P4_READ1 :
          begin
            nstate = `P4_COMPARE1;
          end
      `P4_COMPARE1 :
          begin
            pattern_sel = 1'b1;
            check_en    = 1'b1;
            nstate      = `P4_WRITE0;
          end
      `P4_WRITE0 :
          begin
            wen_test_inner = {WE_WIDTH{1'b0}};
            pattern_sel    = 1'b0;
            count_en       = 1'b1;
             if (test_addr == {ADDR_WIDTH{1'b1}}) begin
                   nstate        = `IDEL5;
                   test_addr_rst = 1'b1;
             end
             else         
                nstate        = `P4_READ1;
          end
      `IDEL5 :  // 准备下一轮读 0 / 比较 / 写 1 / 读 1 / 比较 / 写 0 流程。
          begin
             pattern_sel   = 1'b1;
             test_addr_rst = 1'b1;
             nstate        = `P5_READ0;
          end
      `P5_READ0 :
          begin
             nstate = `P5_COMPARE0;
          end
      `P5_COMPARE0 :
          begin
             pattern_sel=1'b0;
             check_en=1'b1;
             nstate = `P5_WRITE1;
          end
      `P5_WRITE1 :
          begin
             wen_test_inner = {WE_WIDTH{1'b0}};
             pattern_sel   = 1'b1;
             nstate = `P5_READ1;
          end
      `P5_READ1 :
          begin
             nstate = `P5_COMPARE1;
          end
      `P5_COMPARE1 :
          begin
             pattern_sel=1'b1;
             check_en=1'b1;
             nstate = `P5_WRITE0;
          end
      `P5_WRITE0 :
          begin
             wen_test_inner = {WE_WIDTH{1'b0}};
             pattern_sel    = 1'b0;
             count_en       = 1'b1;
             if (test_addr == {ADDR_WIDTH{1'b1}}) begin
                   nstate        = `IDEL6;
                   test_addr_rst = 1'b1;
             end
             else
                nstate        = `P5_READ0;
          end
      `IDEL6 :
          begin
             pattern_sel   = 1'b0;
             test_addr_rst = 1'b1;
             nstate        = `P6_READ0;
          end
      `P6_READ0 :
          begin
             nstate        = `P6_COMPARE0;
          end
      `P6_COMPARE0 :
          begin
             pattern_sel = 1'b0;
             check_en    = 1'b1;
             count_en    = 1'b1;
             if (test_addr == {ADDR_WIDTH{1'b1}}) begin
                   nstate        = `IDEL1;
                   test_addr_rst = 1'b1;
                   r_end_en      = 1'b1;
             end
             else
                nstate = `P6_READ0;
          end
      default :
          begin
             nstate        = `IDEL1;
             test_addr_rst = 1'b1;
          end 
    endcase
  end
endmodule
