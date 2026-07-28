`timescale 1ns / 1ps

// Single admission point for every scheduler-side scratchpad transaction.
// A request is committed only on valid && ready.  Scalar read responses are
// returned two cycles later and tagged with the requesting client; banked reads
// use the same request/response timing but carry a four-bank row response.
module ai_spad_arbiter(
    input wire clk, input wire resetn,
    input wire desc_valid, input wire desc_write, input wire [31:0] desc_addr, input wire [31:0] desc_wdata, output wire desc_ready,
    input wire cpl_valid, input wire cpl_write, input wire [31:0] cpl_addr, input wire [31:0] cpl_wdata, output wire cpl_ready,
    input wire core_valid, input wire core_write, input wire [31:0] core_addr, input wire [31:0] core_wdata, output wire core_ready,
    input wire banked_valid, input wire [31:0] banked_addr, output wire banked_ready,
    input wire dma_valid, input wire dma_write, input wire [31:0] dma_addr, input wire [31:0] dma_wdata, output wire dma_ready,
    output reg spad_valid, output reg spad_write, output reg [31:0] spad_addr, output reg [31:0] spad_wdata,
    output reg spad_banked_valid, output reg [31:0] spad_banked_addr,
    input wire [31:0] spad_rdata, input wire spad_error,
    output reg rsp_valid, output reg [2:0] rsp_client,
    output wire [31:0] rsp_rdata, output reg rsp_error
);
    localparam [2:0] CLIENT_DESC=3'd0, CLIENT_CPL=3'd1, CLIENT_CORE=3'd2,
                     CLIENT_BANKED=3'd3, CLIENT_DMA=3'd4;
    reg accept_valid;
    reg accept_response;
    reg [2:0] accept_client;
    reg accept_valid_d;
    reg [2:0] accept_client_d;
    reg accept_error_d;

    always @(*) begin
        spad_valid=1'b0; spad_write=1'b0; spad_addr=32'd0; spad_wdata=32'd0;
        spad_banked_valid=1'b0; spad_banked_addr=32'd0;
        accept_valid=1'b0; accept_response=1'b0; accept_client=CLIENT_DMA;
        if (desc_valid) begin
            spad_valid=1'b1; spad_write=desc_write; spad_addr=desc_addr; spad_wdata=desc_wdata; accept_valid=1'b1; accept_response=!desc_write; accept_client=CLIENT_DESC;
        end else if (cpl_valid) begin
            spad_valid=1'b1; spad_write=cpl_write; spad_addr=cpl_addr; spad_wdata=cpl_wdata; accept_valid=1'b1; accept_response=!cpl_write; accept_client=CLIENT_CPL;
        end else if (core_valid) begin
            spad_valid=1'b1; spad_write=core_write; spad_addr=core_addr; spad_wdata=core_wdata; accept_valid=1'b1; accept_response=!core_write; accept_client=CLIENT_CORE;
        end else if (banked_valid) begin
            spad_banked_valid=1'b1; spad_banked_addr=banked_addr; accept_valid=1'b1; accept_response=1'b1; accept_client=CLIENT_BANKED;
        end else if (dma_valid) begin
            spad_valid=1'b1; spad_write=dma_write; spad_addr=dma_addr; spad_wdata=dma_wdata; accept_valid=1'b1; accept_response=!dma_write; accept_client=CLIENT_DMA;
        end
    end

    assign desc_ready   = accept_valid && accept_client==CLIENT_DESC;
    assign cpl_ready    = accept_valid && accept_client==CLIENT_CPL;
    assign core_ready   = accept_valid && accept_client==CLIENT_CORE;
    assign banked_ready = accept_valid && accept_client==CLIENT_BANKED;
    assign dma_ready    = accept_valid && accept_client==CLIENT_DMA;
    // Scratchpad read data and error are valid throughout the response cycle;
    // rsp_valid/rsp_client identify which request produced them.
    assign rsp_rdata = spad_rdata;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            accept_valid_d<=0; accept_client_d<=0; accept_error_d<=0;
            rsp_valid<=0; rsp_client<=0; rsp_error<=0;
        end else begin
            // Ready acknowledges every admitted transaction, but only reads
            // create a response.  Emitting a response for a write can be
            // mistaken for the following read when one client performs a
            // write/read sequence on adjacent cycles.
            accept_valid_d<=accept_response;
            accept_client_d<=accept_client;
            accept_error_d<=spad_error;
            rsp_valid<=accept_valid_d;
            rsp_client<=accept_client_d;
            rsp_error<=accept_error_d;
        end
    end
endmodule
