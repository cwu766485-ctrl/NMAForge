`timescale 1ns / 1ps

// Port declaration used only by SpyGlass static analysis.
// The implementation is the foundry 28nm SRAM macro, which is linked through
// its .db/.lib views by the DC/STA flow.  Keeping this model storage-free is
// deliberate: lint/CDC/RDC shall analyse the wrapper and control protocol,
// not manufacture a behavioural SRAM implementation.
module TS1N28HPCPL2SVTB4096X32M4MWBASO (
    input  wire        SLP,
    input  wire        SD,
    input  wire        CLK,
    input  wire        CEB,
    input  wire        WEB,
    input  wire        CEBM,
    input  wire        WEBM,
    input  wire        AWT,
    input  wire [11:0] A,
    input  wire [31:0] D,
    input  wire [31:0] BWEB,
    input  wire [11:0] AM,
    input  wire [31:0] DM,
    input  wire [31:0] BWEBM,
    input  wire        BIST,
    output wire [31:0] Q
);
endmodule
