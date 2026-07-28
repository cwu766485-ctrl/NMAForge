`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: sramc_top
//
// 功能：
//   AHB SRAM controller 顶层封装。
//
// 结构：
//   AHB bus -> ahb_slave_if -> sram_core -> 8 x sram_bist wrapper -> RA1SH
//
// 模式：
//   bist_en=0, dft_en=0 : 正常 AHB 访问 SRAM。
//   bist_en=1           : BIST 控制器接管每片 SRAM 做自测试。
//   dft_en=1            : SRAM wrapper 输出 DFT 观测数据。
//
// 说明：
//   这个项目里的 DFT/BIST 是 memory wrapper/MBIST 概念模型，不包含完整工业 DFT
//   常见的 scan chain、JTAG/TAP、fuse repair、ATPG 约束等内容。
//////////////////////////////////////////////////////////////////////////////////

module sramc_top #(
    parameter integer SRAM_WAIT_CYCLES = 1
)(
    input  wire          hclk,
    input  wire          sram_clk,
    input  wire          hresetn,

    input  wire          hsel,
    input  wire          hwrite,
    input  wire          hready,
    input  wire [2:0]    hsize,
    input  wire [2:0]    hburst,
    input  wire [1:0]    htrans,
    input  wire [31:0]   hwdata,
    input  wire [31:0]   haddr,

    input  wire          dft_en,
    input  wire          bist_en,

    output wire          hready_resp,
    output wire [1:0]    hresp,
    output wire [31:0]   hrdata,

    output wire          bist_done,
    output wire [7:0]    bist_fail
);

    wire        bank_sel;
    wire [3:0]  bank0_csn;
    wire [3:0]  bank1_csn;
    wire        sram_w_en;
    wire [12:0] sram_addr;
    wire [31:0] sram_wdata;

    wire [7:0] sram_q0;
    wire [7:0] sram_q1;
    wire [7:0] sram_q2;
    wire [7:0] sram_q3;
    wire [7:0] sram_q4;
    wire [7:0] sram_q5;
    wire [7:0] sram_q6;
    wire [7:0] sram_q7;

    ahb_slave_if #(
        .SRAM_WAIT_CYCLES(SRAM_WAIT_CYCLES)
    ) ahb_slave_if_u(
        .hclk          (hclk),
        .hresetn       (hresetn),
        .hsel          (hsel),
        .hwrite        (hwrite),
        .hready        (hready),
        .hsize         (hsize),
        .htrans        (htrans),
        .hburst        (hburst),
        .hwdata        (hwdata),
        .haddr         (haddr),

        .sram_q0       (sram_q0),
        .sram_q1       (sram_q1),
        .sram_q2       (sram_q2),
        .sram_q3       (sram_q3),
        .sram_q4       (sram_q4),
        .sram_q5       (sram_q5),
        .sram_q6       (sram_q6),
        .sram_q7       (sram_q7),

        .hready_resp   (hready_resp),
        .hresp         (hresp),
        .hrdata        (hrdata),

        .sram_w_en     (sram_w_en),
        .sram_addr_out (sram_addr),
        .sram_wdata    (sram_wdata),
        .bank_sel      (bank_sel),
        .bank0_csn     (bank0_csn),
        .bank1_csn     (bank1_csn)
    );

    sram_core sram_core_u(
        .hclk         (hclk),
        .sram_clk     (sram_clk),
        .hresetn      (hresetn),

        .sram_addr    (sram_addr),
        .sram_wdata_in(sram_wdata),
        .sram_wen     (sram_w_en),
        .bank_sel     (bank_sel),
        .bank0_csn    (bank0_csn),
        .bank1_csn    (bank1_csn),

        .bist_en      (bist_en),
        .dft_en       (dft_en),

        .sram_q0      (sram_q0),
        .sram_q1      (sram_q1),
        .sram_q2      (sram_q2),
        .sram_q3      (sram_q3),
        .sram_q4      (sram_q4),
        .sram_q5      (sram_q5),
        .sram_q6      (sram_q6),
        .sram_q7      (sram_q7),

        .bist_done    (bist_done),
        .bist_fail    (bist_fail)
    );

endmodule
