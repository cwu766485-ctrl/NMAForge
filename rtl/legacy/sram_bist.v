`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// DFT/BIST 学习说明
//
// 这个模块不是一个真正完整的工业 DFT 子系统，而是一个 SRAM wrapper：
//   function path : sram_core 直接访问 RA1SH。
//   BIST path     : sram_bist_8kx8 接管 RA1SH，自动写/读固定测试 pattern。
//   DFT observe   : dft_en=1 时，输出端不看正常 SRAM 读数据，而看 dft_data_r。
//
// 三条路径的关系：
//   1. 功能模式 bist_en=0, dft_en=0
//      addr_fun/wen_fun/cen_fun/data_fun 经过 sram_bist_8kx8 透传到 RA1SH。
//
//   2. BIST 模式 bist_en=1
//      sram_bist_8kx8 内部状态机产生 addr/wen/cen/data，访问 RA1SH。
//      它检查读回值是否符合预期，并输出 bist_done/bist_fail。
//
//   3. DFT 观察模式 dft_en=1
//      dft_data 把 SRAM 地址、数据和控制信号压缩成 8-bit 观测值。
//      dft_data_r 是一拍寄存后的观测结果，用来帮助测试模式下观察内部状态。
//
// 工业项目里的 DFT 通常还会包含 scan chain、test clock mux、memory BIST
// controller、repair/fuse、test mode constraint 等。这里主要用于学习“功能路径、
// BIST 路径、测试观察路径如何在 RTL 里接起来”。
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sram_bist

// 模块功能：
//   单片 8K x 8-bit SRAM 的包装模块。
//
//   该模块把一片 SRAM 行为模型 RA1SH 和一个 BIST 控制器 sram_bist_8kx8
//   包在一起，并在功能模式、BIST 模式、DFT 模式之间做选择。
//
// 工作模式：
//   1. 功能模式：bist_en=0、dft_en=0
//      外部 sram_core 传入的地址、片选、写使能和写数据直接访问 SRAM。
//
//   2. BIST 模式：bist_en=1
//      sram_bist_8kx8 接管 SRAM 的地址、写使能、片选、输出使能和写数据，
//      自动执行写 0、读比较、写 1、读比较等测试流程。
//
//   3. DFT 模式：dft_en=1
//      sram_data_out 不再直接输出 SRAM 读数据，而是输出 DFT 观测数据。
//////////////////////////////////////////////////////////////////////////////////

module sram_bist(
    //----------------------------------------------------------------------
    // 功能模式输入信号
    //----------------------------------------------------------------------
    input         hclk,           // 控制/BIST 逻辑时钟。
    input         sram_clk,       // SRAM 存储阵列时钟。
    input         sram_rst_n,     // 低有效复位。
    input         sram_csn_in,    // 功能模式 SRAM 片选，低有效。0：选中。
    input         sram_wen_in,    // 功能模式 SRAM 写使能，低有效。0：写；1：读。
    input [12:0]  sram_addr_in,   // 功能模式 SRAM 片内地址。
    input [7:0 ]  sram_wdata_in,  // 功能模式 SRAM 写数据。
    input         bist_en,        // BIST 模式使能。
    input         dft_en,         // DFT 模式使能。

    //----------------------------------------------------------------------
    // 输出信号
    //----------------------------------------------------------------------
    output [7:0 ] sram_data_out,  // 功能模式下为 SRAM 读数据；DFT 模式下为 DFT 观测数据。
    output        bist_done,      // BIST 完成标志。
    output        bist_fail       // BIST 失败标志，1 表示测试失败。
);

    //----------------------------------------------------------------------
    // 送入 SRAM 行为模型 RA1SH 的最终控制/数据信号
    //
    // 这些信号由 sram_bist_8kx8 输出。sram_bist_8kx8 内部会根据 bist_en
    // 选择功能模式输入，或者选择 BIST 状态机生成的测试信号。
    //----------------------------------------------------------------------
    wire        sram_csn;
    wire        sram_wen;
    wire        sram_oen;
    wire [12:0] sram_a;
    wire [7:0]  sram_d;
    wire [7:0]  data_out;

    //----------------------------------------------------------------------
    // DFT 观测数据
    //----------------------------------------------------------------------
    wire [7:0] dft_data;
    reg  [7:0] dft_data_r;

    wire [12:0] sram_addr;
    wire [7:0]  sram_wdata;

    // BIST 逻辑时钟。bist_en=0 时关断为 0，减少 BIST 逻辑无效翻转。
    wire bist_clk;

    genvar K;

    //----------------------------------------------------------------------
    // 功耗优化风格：
    //   当功能片选 sram_csn_in 为 1，也就是 SRAM 没被选中时，
    //   将地址和写数据清 0，避免未访问 SRAM 的输入端无意义翻转。
    //----------------------------------------------------------------------
    assign sram_addr  = sram_csn_in ? 13'd0 : sram_addr_in;
    assign sram_wdata = sram_csn_in ? 8'd0  : sram_wdata_in;

    //----------------------------------------------------------------------
    // DFT 观测数据生成
    //
    // 将 SRAM 地址、数据和控制信号做异或压缩，形成一个 8-bit 观测向量。
    // 这类逻辑主要用于 DFT/测试模式，正常功能验证一般不需要深究。
    //----------------------------------------------------------------------
    assign dft_data = (sram_d ^ sram_a[7:0]) ^ {sram_csn, sram_wen, sram_oen, sram_a[12:8]};

    //----------------------------------------------------------------------
    // always 块：DFT 观测数据寄存
    //
    // 综合后的电路：
    //   8 个带低有效异步复位的 D 触发器。
    //
    // 行为：
    //   复位时清 0。
    //   dft_en=1 时，在 hclk 上升沿采样 dft_data。
    //   dft_en=0 时保持原值。
    //----------------------------------------------------------------------
    always @(posedge hclk or negedge sram_rst_n) begin
        if(!sram_rst_n)
            dft_data_r <= 8'd0;
        else if(dft_en)
            dft_data_r <= dft_data;
    end

    // DFT 模式输出 DFT 观测数据；其他模式输出 SRAM 行为模型的读数据。
    assign sram_data_out = dft_en ? dft_data_r : data_out;

    //----------------------------------------------------------------------
    // 工艺库保持单元占位说明
    //
    // 真实 ASIC 实现里可能需要用标准单元对 data_out 做保持或测试隔离。
    // 当前 RTL 仿真模型不例化这些工艺库单元。
    //----------------------------------------------------------------------
    /*
    generate for(K = 0; K < 8; K = K+1 )
    begin :hold
        // BHDBWP7T holdQ (.Z(data_out[K]));
    end
    endgenerate
    */

    //----------------------------------------------------------------------
    // BIST 时钟选择
    //
    // 真实芯片实现中一般用专用 clock mux 标准单元。
    // 当前模型用组合赋值表示：bist_en=1 时 BIST 状态机使用 hclk。
    //----------------------------------------------------------------------
    // CKMUX2D2BWP7T U_bist_clk_mux (.I0(1'b0), .I1(hclk), .S(bist_en), .Z(bist_clk));
    assign bist_clk = bist_en ? hclk : 1'b0;

    //----------------------------------------------------------------------
    // SRAM 行为模型实例
    //----------------------------------------------------------------------
    RA1SH u_RA1SH(
        .Q      (data_out), // SRAM 读数据输出。
        .CLK    (sram_clk), // SRAM 时钟。
        .CEN    (sram_csn), // SRAM 片选，低有效。
        .WEN    (sram_wen), // SRAM 写使能，低有效。
        .A      (sram_a),   // SRAM 地址。
        .D      (sram_d),   // SRAM 写数据。
        .OEN    (sram_oen)  // SRAM 输出使能，低有效。
    );

    //----------------------------------------------------------------------
    // BIST 控制器实例
    //
    // addr_fun/wen_fun/cen_fun/oen_fun/data_fun 是功能模式输入。
    // addr_test/wen_test/cen_test/oen_test/data_test 是最终送入 RA1SH 的信号。
    //
    // sram_bist_8kx8 内部根据 b_te：
    //   b_te=0：addr_test 等输出选择 *_fun 功能信号。
    //   b_te=1：addr_test 等输出选择 BIST 状态机生成的测试信号。
    //----------------------------------------------------------------------
    sram_bist_8kx8 u_sram_bist_8kx8(
        .b_clk       (bist_clk),
        .b_rst_n     (sram_rst_n),
        .b_te        (bist_en),

        .addr_fun    (sram_addr),
        .wen_fun     (sram_wen_in),
        .cen_fun     (sram_csn_in),
//      .oen_fun     (~sram_wen_in),
        .oen_fun     (1'b0),       // 输出使能低有效，这里保持打开。
        .data_fun    (sram_wdata),

        .ram_read_out(sram_data_out),
        .data_test   (sram_d),
        .addr_test   (sram_a),
        .wen_test    (sram_wen),
        .cen_test    (sram_csn),
        .oen_test    (sram_oen),

        .b_done      (bist_done),
        .b_fail      (bist_fail)
    );

endmodule
