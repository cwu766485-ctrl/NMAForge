`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// SRAM core DFT/BIST 结构说明
//
// sram_core 把 8 片 8K x 8-bit SRAM wrapper 拼成一个 64KB 级别的存储阵列：
//   bank0: sram0~sram3，组成一个 32-bit bank。
//   bank1: sram4~sram7，组成另一个 32-bit bank。
//
// 每一片 SRAM 都不是直接例化 RA1SH，而是例化 sram_bist：
//   sram_core -> sram_bist -> sram_bist_8kx8 + RA1SH
//
// 这样做的目的：
//   1. 功能模式下，AHB 访问通过 sram_core 分发到指定 SRAM byte lane。
//   2. BIST 模式下，每片 SRAM wrapper 可以独立自测并返回 done/fail。
//   3. DFT 模式下，每片 wrapper 可以输出压缩后的测试观测数据。
//
// 当前代码的工程化修正：
//   组合 always 块给所有 sram_cs*_data_in 默认值，避免未选 byte lane 推断 latch。
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sram_core
//
// 模块功能：
//   SRAM 存储阵列核心封装。
//
//   本模块内部例化 8 个 sram_bist，每个 sram_bist 包含一片 8K x 8-bit
//   SRAM 行为模型和 BIST/DFT 包装逻辑。
//
// 存储组织：
//   bank0：sram0、sram1、sram2、sram3，合起来组成一个 32-bit bank。
//   bank1：sram4、sram5、sram6、sram7，合起来组成另一个 32-bit bank。
//
//   每片 SRAM 是 8-bit 数据宽度，因此 32-bit 访问需要同时选中一个 bank
//   里的 4 片 SRAM；16-bit 访问选中 2 片；8-bit 访问选中 1 片。
//
// 该模块的主要职责：
//   1. 根据 bank_sel 和 bank*_csn 将 sram_wdata_in 拆成 8-bit 写数据。
//   2. 把地址、片选、读写控制广播/分发到 8 个 sram_bist 实例。
//   3. 汇总每片 SRAM 的 BIST done/fail 结果。
//////////////////////////////////////////////////////////////////////////////////

module sram_core(
    //----------------------------------------------------------------------
    // 时钟、复位
    //----------------------------------------------------------------------
    input             hclk,       // 控制/BIST 逻辑时钟。
    input             sram_clk,   // SRAM 存储单元时钟。
    input             hresetn,    // 低有效复位。

    //----------------------------------------------------------------------
    // 来自 ahb_slave_if 的 SRAM 访问控制
    //----------------------------------------------------------------------
    input             sram_wen,       // SRAM 读写控制。1：读；0：写。
    input  [12:0]     sram_addr,      // 每片 8K SRAM 的片内地址。
    input  [31:0]     sram_wdata_in,  // AHB 写入的 32-bit 数据。
    input             bank_sel,       // bank 选择。1：访问 bank0；0：访问 bank1。
    input  [3:0]      bank0_csn,      // bank0 内 4 片 SRAM 的片选，低有效。
    input  [3:0]      bank1_csn,      // bank1 内 4 片 SRAM 的片选，低有效。
    input             bist_en,        // BIST 测试模式使能。
    input             dft_en,         // DFT 测试模式使能。

    //----------------------------------------------------------------------
    // 8 片 SRAM 的读数据输出
    //
    // bank0：
    //   sram_q0 -> byte0
    //   sram_q1 -> byte1
    //   sram_q2 -> byte2
    //   sram_q3 -> byte3
    //
    // bank1：
    //   sram_q4 -> byte0
    //   sram_q5 -> byte1
    //   sram_q6 -> byte2
    //   sram_q7 -> byte3
    //----------------------------------------------------------------------
    output [7:0]      sram_q0,
    output [7:0]      sram_q1,
    output [7:0]      sram_q2,
    output [7:0]      sram_q3,
    output [7:0]      sram_q4,
    output [7:0]      sram_q5,
    output [7:0]      sram_q6,
    output [7:0]      sram_q7,

    //----------------------------------------------------------------------
    // BIST 汇总结果
    //----------------------------------------------------------------------
    output            bist_done,  // 8 片 SRAM 的 BIST 全部完成时为 1。
    output [7:0]      bist_fail   // 每一位对应一片 SRAM，1 表示对应 SRAM 测试失败。
);

    //----------------------------------------------------------------------
    // 送入每片 8-bit SRAM 的写数据
    //
    // sram_wdata_in 是 32-bit 总线数据。这里根据当前访问的 bank 和片选，
    // 将其中的低 8/16/32 bit 拆分到对应的 SRAM byte lane。
    //----------------------------------------------------------------------
    reg [7:0] sram_cs0_data_in;
    reg [7:0] sram_cs1_data_in;
    reg [7:0] sram_cs2_data_in;
    reg [7:0] sram_cs3_data_in;
    reg [7:0] sram_cs4_data_in;
    reg [7:0] sram_cs5_data_in;
    reg [7:0] sram_cs6_data_in;
    reg [7:0] sram_cs7_data_in;

    //----------------------------------------------------------------------
    // 每片 SRAM 的 BIST 原始结果
    //----------------------------------------------------------------------
    wire bist_done0;
    wire bist_fail0;
    wire bist_done1;
    wire bist_fail1;
    wire bist_done2;
    wire bist_fail2;
    wire bist_done3;
    wire bist_fail3;
    wire bist_done4;
    wire bist_fail4;
    wire bist_done5;
    wire bist_fail5;
    wire bist_done6;
    wire bist_fail6;
    wire bist_done7;
    wire bist_fail7;

    wire       bank0_bistdone;
    wire       bank1_bistdone;
    wire [3:0] bank0_bistfail;
    wire [3:0] bank1_bistfail;

    //----------------------------------------------------------------------
    // BIST 结果汇总
    //
    // done：
    //   一个 bank 内 4 片 SRAM 都 done，该 bank 才算 done。
    //   两个 bank 都 done，顶层 bist_done 才为 1。
    //
    // fail：
    //   直接把 8 片 SRAM 的 fail bit 拼成 8-bit 输出。
    //----------------------------------------------------------------------
    assign bank0_bistdone = (bist_done3 && bist_done2) && (bist_done1 && bist_done0);
    assign bank0_bistfail = {bist_fail3, bist_fail2, bist_fail1, bist_fail0};

    assign bank1_bistdone = (bist_done7 && bist_done6) && (bist_done5 && bist_done4);
    assign bank1_bistfail = {bist_fail7, bist_fail6, bist_fail5, bist_fail4};

    assign bist_done = bank0_bistdone && bank1_bistdone;
    assign bist_fail = {bank1_bistfail, bank0_bistfail};

    //----------------------------------------------------------------------
    // 早期写法参考：直接根据片选三态驱动每片 SRAM 写数据。
    //
    // 当前 RTL 没有采用三态总线写法，而是在下面 always 块里用组合逻辑
    // 给每片 SRAM 的写数据寄存型变量赋值。
    //----------------------------------------------------------------------
//    assign sram_cs0_data_in = (~sram_wen&~bank0_csn[0]&bank_sel) ?sram_wdata_in[7:0]    :{8{1'bz}};
//    assign sram_cs1_data_in = (~sram_wen&~bank0_csn[1]&bank_sel) ?sram_wdata_in[15:8]   :{8{1'bz}};
//    assign sram_cs2_data_in = (~sram_wen&~bank0_csn[2]&bank_sel) ?sram_wdata_in[23:16]  :{8{1'bz}};
//    assign sram_cs3_data_in = (~sram_wen&~bank0_csn[3]&bank_sel) ?sram_wdata_in[31:24]  :{8{1'bz}};
//    assign sram_cs4_data_in = (~sram_wen&~bank1_csn[0]&~bank_sel)?sram_wdata_in[7:0]    :{8{1'bz}};
//    assign sram_cs5_data_in = (~sram_wen&~bank1_csn[1]&~bank_sel)?sram_wdata_in[15:8]   :{8{1'bz}};
//    assign sram_cs6_data_in = (~sram_wen&~bank1_csn[2]&~bank_sel)?sram_wdata_in[23:16]  :{8{1'bz}};
//    assign sram_cs7_data_in = (~sram_wen&~bank1_csn[3]&~bank_sel)?sram_wdata_in[31:24]  :{8{1'bz}};

    //----------------------------------------------------------------------
    // always 块：按 bank 和 byte lane 分发写数据
    //
    // 综合后的电路：
    //   这是组合逻辑，主要会综合成多路选择器和译码逻辑。
    //
    // 输入控制：
    //   bank_sel = 1：当前访问 bank0，对应 sram_cs0~sram_cs3。
    //   bank_sel = 0：当前访问 bank1，对应 sram_cs4~sram_cs7。
    //
    //   bank*_csn 低有效：
    //     4'b1110：8-bit 访问 byte0。
    //     4'b1101：8-bit 访问 byte1。
    //     4'b1011：8-bit 访问 byte2。
    //     4'b0111：8-bit 访问 byte3。
    //     4'b1100：16-bit 访问低半字 byte0/byte1。
    //     4'b0011：16-bit 访问高半字 byte2/byte3。
    //     4'b0000：32-bit 访问 4 个 byte lane 全部有效。
    //
    // 数据映射：
    //   8-bit  写：把 sram_wdata_in[7:0] 写到被选中的那一片 SRAM。
    //   16-bit 写：把 [7:0]、[15:8] 写到被选中的两片 SRAM。
    //   32-bit 写：把 [7:0]、[15:8]、[23:16]、[31:24] 写到 4 片 SRAM。
    //
    // 注意：
    //   这个 always 块没有在每个分支给所有 sram_cs*_data_in 默认赋值，
    //   default 分支也是空语句，因此综合时可能推断 latch 来保持未赋值
    //   byte lane 的旧数据。当前仅补注释，不改变原设计行为。
    //----------------------------------------------------------------------
    always@(*) begin
        sram_cs0_data_in = 8'd0;
        sram_cs1_data_in = 8'd0;
        sram_cs2_data_in = 8'd0;
        sram_cs3_data_in = 8'd0;
        sram_cs4_data_in = 8'd0;
        sram_cs5_data_in = 8'd0;
        sram_cs6_data_in = 8'd0;
        sram_cs7_data_in = 8'd0;

        if(!hresetn) begin
            sram_cs0_data_in = 8'd0;
            sram_cs1_data_in = 8'd0;
            sram_cs2_data_in = 8'd0;
            sram_cs3_data_in = 8'd0;
            sram_cs4_data_in = 8'd0;
            sram_cs5_data_in = 8'd0;
            sram_cs6_data_in = 8'd0;
            sram_cs7_data_in = 8'd0;
        end
        else begin
            if(bank_sel) begin
                case(bank0_csn)
                    // bank0，8-bit 写：只更新被选中的 1 片 SRAM 写数据。
                    4'b1110: begin
                        sram_cs0_data_in = sram_wdata_in[7:0];
                    end
                    4'b1101: begin
                        sram_cs1_data_in = sram_wdata_in[7:0];
                    end
                    4'b1011: begin
                        sram_cs2_data_in = sram_wdata_in[7:0];
                    end
                    4'b0111: begin
                        sram_cs3_data_in = sram_wdata_in[7:0];
                    end

                    // bank0，16-bit 写：更新低半字或高半字对应的 2 片 SRAM。
                    4'b1100: begin
                        sram_cs0_data_in = sram_wdata_in[7:0];
                        sram_cs1_data_in = sram_wdata_in[15:8];
                    end
                    4'b0011: begin
                        sram_cs2_data_in = sram_wdata_in[7:0];
                        sram_cs3_data_in = sram_wdata_in[15:8];
                    end

                    // bank0，32-bit 写：4 个 byte lane 全部更新。
                    4'b0000: begin
                        sram_cs0_data_in = sram_wdata_in[7:0];
                        sram_cs1_data_in = sram_wdata_in[15:8];
                        sram_cs2_data_in = sram_wdata_in[23:16];
                        sram_cs3_data_in = sram_wdata_in[31:24];
                    end
                    default:;
                endcase
            end
            else begin
                case(bank1_csn)
                    // bank1，8-bit 写：只更新被选中的 1 片 SRAM 写数据。
                    4'b1110: begin
                        sram_cs4_data_in = sram_wdata_in[7:0];
                    end
                    4'b1101: begin
                        sram_cs5_data_in = sram_wdata_in[7:0];
                    end
                    4'b1011: begin
                        sram_cs6_data_in = sram_wdata_in[7:0];
                    end
                    4'b0111: begin
                        sram_cs7_data_in = sram_wdata_in[7:0];
                    end

                    // bank1，16-bit 写：更新低半字或高半字对应的 2 片 SRAM。
                    4'b1100: begin
                        sram_cs4_data_in = sram_wdata_in[7:0];
                        sram_cs5_data_in = sram_wdata_in[15:8];
                    end
                    4'b0011: begin
                        sram_cs6_data_in = sram_wdata_in[7:0];
                        sram_cs7_data_in = sram_wdata_in[15:8];
                    end

                    // bank1，32-bit 写：4 个 byte lane 全部更新。
                    4'b0000: begin
                        sram_cs4_data_in = sram_wdata_in[7:0];
                        sram_cs5_data_in = sram_wdata_in[15:8];
                        sram_cs6_data_in = sram_wdata_in[23:16];
                        sram_cs7_data_in = sram_wdata_in[31:24];
                    end
                    default:;
                endcase
            end
        end
    end

    //-------------------------------------------------------------------------
    // 例化 8 个带 BIST/DFT 包装的 SRAM
    //
    // 每个 sram_bist 对应一片 8K x 8-bit SRAM：
    //   u_sram_bist0~3 属于 bank0。
    //   u_sram_bist4~7 属于 bank1。
    //
    // 所有 SRAM 共用：
    //   hclk、sram_clk、hresetn、sram_addr、sram_wen、bist_en、dft_en。
    //
    // 每片 SRAM 独立接收：
    //   片选 bit、8-bit 写数据、8-bit 读数据、BIST done/fail。
    //-------------------------------------------------------------------------

    // bank0 byte0
    sram_bist u_sram_bist0(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank0_csn[0]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs0_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q0         ),
        .bist_done        (bist_done0      ),
        .bist_fail        (bist_fail0      )
        );

    // bank0 byte1
    sram_bist u_sram_bist1(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank0_csn[1]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs1_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q1         ),
        .bist_done        (bist_done1      ),
        .bist_fail        (bist_fail1      )
        );

    // bank0 byte2
    sram_bist u_sram_bist2(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank0_csn[2]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs2_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q2         ),
        .bist_done        (bist_done2      ),
        .bist_fail        (bist_fail2      )
        );

    // bank0 byte3
    sram_bist u_sram_bist3(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank0_csn[3]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs3_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q3         ),
        .bist_done        (bist_done3      ),
        .bist_fail        (bist_fail3      )
        );

    // bank1 byte0
    sram_bist u_sram_bist4(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank1_csn[0]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs4_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q4         ),
        .bist_done        (bist_done4      ),
        .bist_fail        (bist_fail4      )
        );

    // bank1 byte1
    sram_bist u_sram_bist5(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank1_csn[1]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs5_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q5         ),
        .bist_done        (bist_done5      ),
        .bist_fail        (bist_fail5      )
        );

    // bank1 byte2
    sram_bist u_sram_bist6(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank1_csn[2]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs6_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q6         ),
        .bist_done        (bist_done6      ),
        .bist_fail        (bist_fail6      )
        );

    // bank1 byte3
    sram_bist u_sram_bist7(
        .hclk             (hclk            ),
        .sram_clk         (sram_clk        ),
        .sram_rst_n       (hresetn         ),
        .sram_csn_in      (bank1_csn[3]    ),
        .sram_wen_in      (sram_wen        ),
        .sram_addr_in     (sram_addr       ),
        .sram_wdata_in    (sram_cs7_data_in),
        .bist_en          (bist_en         ),
        .dft_en           (dft_en          ),

        .sram_data_out    (sram_q7         ),
        .bist_done        (bist_done7      ),
        .bist_fail        (bist_fail7      )
        );

endmodule
