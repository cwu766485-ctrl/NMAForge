`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: RA1SH
//
// Description:
//   Technology-independent 8K x 8-bit synchronous single-port SRAM behavior
//   model used only for RTL simulation and education.
//
// Interface convention:
//   CEN = 0 selects the memory.
//   WEN = 0 writes D to A on the rising edge of CLK.
//   WEN = 1 reads A and registers the result on the rising edge of CLK.
//   OEN = 0 enables Q; OEN = 1 drives Q to zero in this digital model.
//
// Integration note:
//   ASIC synthesis should replace this module with a memory-compiler macro.
//   FPGA implementation should replace it with inferred BRAM or vendor XPM.
//////////////////////////////////////////////////////////////////////////////////

module RA1SH #(
    parameter integer BITS       = 8,
    parameter integer WORD_DEPTH = 8192,
    parameter integer ADDR_WIDTH = 13
) (
    output wire [BITS-1:0]       Q,
    input  wire                  CLK,
    input  wire                  CEN,
    input  wire                  WEN,
    input  wire [ADDR_WIDTH-1:0] A,
    input  wire [BITS-1:0]       D,
    input  wire                  OEN
);

    reg [BITS-1:0] mem [0:WORD_DEPTH-1];
    reg [BITS-1:0] q_r;

    always @(posedge CLK) begin
        if (!CEN) begin
            if (!WEN)
                mem[A] <= D;
            else
                q_r <= mem[A];
        end
    end

    assign Q = OEN ? {BITS{1'b0}} : q_r;

endmodule
