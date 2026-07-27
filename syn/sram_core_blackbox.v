// Synthesis-only SRAM core blackbox.
//
// The simulation RTL uses a behavioral RA1SH SRAM model with timing checks and
// four-state operators. Those constructs are not intended for Design Compiler.
// In an ASIC flow this boundary is replaced by memory compiler macros.

module sram_core(
    input             hclk,
    input             sram_clk,
    input             hresetn,

    input             sram_wen,
    input  [12:0]     sram_addr,
    input  [31:0]     sram_wdata_in,
    input             bank_sel,
    input  [3:0]      bank0_csn,
    input  [3:0]      bank1_csn,
    input             bist_en,
    input             dft_en,

    output [7:0]      sram_q0,
    output [7:0]      sram_q1,
    output [7:0]      sram_q2,
    output [7:0]      sram_q3,
    output [7:0]      sram_q4,
    output [7:0]      sram_q5,
    output [7:0]      sram_q6,
    output [7:0]      sram_q7,

    output            bist_done,
    output [7:0]      bist_fail
);
endmodule
