`timescale 1ns / 1ps

// Single admission point for every scheduler-side scratchpad transaction.
// A request is committed only on valid && ready.  Scalar read responses are
// returned two cycles later and tagged with the requesting client; banked reads
// use the same request/response timing but carry a four-bank row response.
//
// Descriptor fetch and completion commit are short control-plane operations
// and retain strict priority.  Core, banked-core, and DMA data-plane clients
// are selected round-robin, preventing a continuously asserted compute stream
// from starving payload DMA forever.
module ai_spad_arbiter(
    input wire clk, input wire resetn,
    input wire desc_valid, input wire desc_write, input wire [31:0] desc_addr, input wire [31:0] desc_wdata, output wire desc_ready,
    input wire cpl_valid, input wire cpl_write, input wire [31:0] cpl_addr, input wire [31:0] cpl_wdata, output wire cpl_ready,
    input wire core_valid, input wire core_write, input wire [31:0] core_addr, input wire [31:0] core_wdata, output wire core_ready,
    input wire core_line_valid, input wire core_line_write,
    input wire [31:0] core_line_addr, input wire [127:0] core_line_wdata,
    input wire [15:0] core_line_wstrb, output wire core_line_ready,
    input wire banked_valid, input wire [31:0] banked_addr, output wire banked_ready,
    // CNM A2.2 is one scheduler client, but carries one independent address
    // for each physical SRAM bank in a single admitted transaction.
    input wire [3:0] cnm_valid,
    input wire [31:0] cnm_addr0, input wire [31:0] cnm_addr1,
    input wire [31:0] cnm_addr2, input wire [31:0] cnm_addr3, output wire [3:0] cnm_ready,
    input wire dma_valid, input wire dma_write, input wire [31:0] dma_addr, input wire [31:0] dma_wdata, output wire dma_ready,
    input wire dma_line_valid, input wire dma_line_write,
    input wire [31:0] dma_line_addr, input wire [127:0] dma_line_wdata,
    input wire [15:0] dma_line_wstrb, output wire dma_line_ready,
    output reg spad_valid, output reg spad_write, output reg [31:0] spad_addr, output reg [31:0] spad_wdata,
    output reg spad_line_valid, output reg spad_line_write,
    output reg [31:0] spad_line_addr, output reg [127:0] spad_line_wdata,
    output reg [15:0] spad_line_wstrb,
    output reg spad_banked_valid, output reg [31:0] spad_banked_addr,
    output reg [3:0] spad_cnm_valid,
    output reg [31:0] spad_cnm_addr0, output reg [31:0] spad_cnm_addr1,
    output reg [31:0] spad_cnm_addr2, output reg [31:0] spad_cnm_addr3,
    input wire [31:0] spad_rdata, input wire spad_error,
    input wire spad_parity_error, input wire spad_line_error,
    input wire [3:0] spad_line_parity_error,
    output reg rsp_valid, output reg [2:0] rsp_client, output reg rsp_is_line,
    output reg [3:0] cnm_rsp_valid,
    output wire [2:0] request_client,
    output wire [31:0] rsp_rdata, output reg rsp_error
);
    localparam [2:0] CLIENT_DESC=3'd0, CLIENT_CPL=3'd1, CLIENT_CORE=3'd2,
                     CLIENT_BANKED=3'd3, CLIENT_DMA=3'd4;
    // data_rr_r names the first data-plane client considered after the two
    // control-plane clients.  The selected client moves the cursor to its
    // successor, giving Core -> Banked -> DMA round-robin arbitration.
    localparam [1:0] RR_CORE   = 2'd0;
    localparam [1:0] RR_BANKED = 2'd1;
    localparam [1:0] RR_DMA    = 2'd2;
    reg accept_valid;
    reg accept_response;
    reg accept_is_line;
    reg [2:0] accept_client;
    reg accept_valid_d;
    reg [2:0] accept_client_d;
    reg accept_error_d;
    reg accept_is_line_d;
    reg [1:0] data_rr_r;
    reg [3:0] accept_cnm_mask_d;

    always @(*) begin
        spad_valid=1'b0; spad_write=1'b0; spad_addr=32'd0; spad_wdata=32'd0;
        spad_line_valid=1'b0; spad_line_write=1'b0; spad_line_addr=32'd0;
        spad_line_wdata=128'd0; spad_line_wstrb=16'd0;
        spad_banked_valid=1'b0; spad_banked_addr=32'd0;
        spad_cnm_valid=4'd0; spad_cnm_addr0=32'd0; spad_cnm_addr1=32'd0;
        spad_cnm_addr2=32'd0; spad_cnm_addr3=32'd0;
        accept_valid=1'b0; accept_response=1'b0; accept_is_line=1'b0;
        accept_client=CLIENT_DMA;
        if (desc_valid) begin
            spad_valid=1'b1; spad_write=desc_write; spad_addr=desc_addr; spad_wdata=desc_wdata; accept_valid=1'b1; accept_response=!desc_write; accept_client=CLIENT_DESC;
        end else if (cpl_valid) begin
            spad_valid=1'b1; spad_write=cpl_write; spad_addr=cpl_addr; spad_wdata=cpl_wdata; accept_valid=1'b1; accept_response=!cpl_write; accept_client=CLIENT_CPL;
        end else begin
            case (data_rr_r)
              RR_CORE: begin
                if (core_line_valid) begin
                    spad_line_valid=1'b1; spad_line_write=core_line_write; spad_line_addr=core_line_addr; spad_line_wdata=core_line_wdata; spad_line_wstrb=core_line_wstrb; accept_valid=1'b1; accept_response=!core_line_write; accept_is_line=1'b1; accept_client=CLIENT_CORE;
                end else if (core_valid) begin
                    spad_valid=1'b1; spad_write=core_write; spad_addr=core_addr; spad_wdata=core_wdata; accept_valid=1'b1; accept_response=!core_write; accept_client=CLIENT_CORE;
                end else if (|cnm_valid) begin
                    spad_cnm_valid=cnm_valid; spad_cnm_addr0=cnm_addr0; spad_cnm_addr1=cnm_addr1; spad_cnm_addr2=cnm_addr2; spad_cnm_addr3=cnm_addr3; accept_valid=1'b1; accept_response=1'b1; accept_client=CLIENT_BANKED;
                end else if (banked_valid) begin
                    spad_banked_valid=1'b1; spad_banked_addr=banked_addr; accept_valid=1'b1; accept_response=1'b1; accept_client=CLIENT_BANKED;
                end else if (dma_line_valid) begin
                    spad_line_valid=1'b1; spad_line_write=dma_line_write; spad_line_addr=dma_line_addr; spad_line_wdata=dma_line_wdata; spad_line_wstrb=dma_line_wstrb; accept_valid=1'b1; accept_response=!dma_line_write; accept_is_line=1'b1; accept_client=CLIENT_DMA;
                end else if (dma_valid) begin
                    spad_valid=1'b1; spad_write=dma_write; spad_addr=dma_addr; spad_wdata=dma_wdata; accept_valid=1'b1; accept_response=!dma_write; accept_client=CLIENT_DMA;
                end
              end
              RR_BANKED: begin
                if (|cnm_valid) begin
                    spad_cnm_valid=cnm_valid; spad_cnm_addr0=cnm_addr0; spad_cnm_addr1=cnm_addr1; spad_cnm_addr2=cnm_addr2; spad_cnm_addr3=cnm_addr3; accept_valid=1'b1; accept_response=1'b1; accept_client=CLIENT_BANKED;
                end else if (banked_valid) begin
                    spad_banked_valid=1'b1; spad_banked_addr=banked_addr; accept_valid=1'b1; accept_response=1'b1; accept_client=CLIENT_BANKED;
                end else if (dma_line_valid) begin
                    spad_line_valid=1'b1; spad_line_write=dma_line_write; spad_line_addr=dma_line_addr; spad_line_wdata=dma_line_wdata; spad_line_wstrb=dma_line_wstrb; accept_valid=1'b1; accept_response=!dma_line_write; accept_is_line=1'b1; accept_client=CLIENT_DMA;
                end else if (dma_valid) begin
                    spad_valid=1'b1; spad_write=dma_write; spad_addr=dma_addr; spad_wdata=dma_wdata; accept_valid=1'b1; accept_response=!dma_write; accept_client=CLIENT_DMA;
                end else if (core_line_valid) begin
                    spad_line_valid=1'b1; spad_line_write=core_line_write; spad_line_addr=core_line_addr; spad_line_wdata=core_line_wdata; spad_line_wstrb=core_line_wstrb; accept_valid=1'b1; accept_response=!core_line_write; accept_is_line=1'b1; accept_client=CLIENT_CORE;
                end else if (core_valid) begin
                    spad_valid=1'b1; spad_write=core_write; spad_addr=core_addr; spad_wdata=core_wdata; accept_valid=1'b1; accept_response=!core_write; accept_client=CLIENT_CORE;
                end
              end
              default: begin // RR_DMA
                if (dma_line_valid) begin
                    spad_line_valid=1'b1; spad_line_write=dma_line_write; spad_line_addr=dma_line_addr; spad_line_wdata=dma_line_wdata; spad_line_wstrb=dma_line_wstrb; accept_valid=1'b1; accept_response=!dma_line_write; accept_is_line=1'b1; accept_client=CLIENT_DMA;
                end else if (dma_valid) begin
                    spad_valid=1'b1; spad_write=dma_write; spad_addr=dma_addr; spad_wdata=dma_wdata; accept_valid=1'b1; accept_response=!dma_write; accept_client=CLIENT_DMA;
                end else if (core_line_valid) begin
                    spad_line_valid=1'b1; spad_line_write=core_line_write; spad_line_addr=core_line_addr; spad_line_wdata=core_line_wdata; spad_line_wstrb=core_line_wstrb; accept_valid=1'b1; accept_response=!core_line_write; accept_is_line=1'b1; accept_client=CLIENT_CORE;
                end else if (core_valid) begin
                    spad_valid=1'b1; spad_write=core_write; spad_addr=core_addr; spad_wdata=core_wdata; accept_valid=1'b1; accept_response=!core_write; accept_client=CLIENT_CORE;
                end else if (|cnm_valid) begin
                    spad_cnm_valid=cnm_valid; spad_cnm_addr0=cnm_addr0; spad_cnm_addr1=cnm_addr1; spad_cnm_addr2=cnm_addr2; spad_cnm_addr3=cnm_addr3; accept_valid=1'b1; accept_response=1'b1; accept_client=CLIENT_BANKED;
                end else if (banked_valid) begin
                    spad_banked_valid=1'b1; spad_banked_addr=banked_addr; accept_valid=1'b1; accept_response=1'b1; accept_client=CLIENT_BANKED;
                end
              end
            endcase
        end
    end

    assign desc_ready   = accept_valid && accept_client==CLIENT_DESC;
    assign cpl_ready    = accept_valid && accept_client==CLIENT_CPL;
    assign core_ready   = accept_valid && accept_client==CLIENT_CORE &&
                          !accept_is_line;
    assign core_line_ready = accept_valid && accept_client==CLIENT_CORE &&
                             accept_is_line;
    assign banked_ready = accept_valid && accept_client==CLIENT_BANKED;
    assign cnm_ready    = {4{accept_valid && accept_client==CLIENT_BANKED}};
    assign dma_ready    = accept_valid && accept_client==CLIENT_DMA &&
                          !accept_is_line;
    assign dma_line_ready = accept_valid && accept_client==CLIENT_DMA &&
                            accept_is_line;
    // Scratchpad read data and error are valid throughout the response cycle;
    // rsp_valid/rsp_client identify which request produced them.
    assign rsp_rdata = spad_rdata;
    assign request_client = accept_client;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            accept_valid_d<=0; accept_client_d<=0; accept_error_d<=0;
            accept_is_line_d<=0;
            rsp_valid<=0; rsp_client<=0; rsp_is_line<=0; rsp_error<=0;
            cnm_rsp_valid<=0; accept_cnm_mask_d<=0;
            data_rr_r<=0;
        end else begin
            // Ready acknowledges every admitted transaction, but only reads
            // create a response.  Emitting a response for a write can be
            // mistaken for the following read when one client performs a
            // write/read sequence on adjacent cycles.
            accept_valid_d<=accept_response;
            accept_client_d<=accept_client;
            accept_cnm_mask_d<=spad_cnm_valid;
            accept_is_line_d<=accept_is_line;
            accept_error_d<=accept_is_line ? spad_line_error : spad_error;
            rsp_valid<=accept_valid_d;
            cnm_rsp_valid<= (accept_valid_d && accept_client_d==CLIENT_BANKED) ? accept_cnm_mask_d : 4'd0;
            rsp_client<=accept_client_d;
            rsp_is_line<=accept_is_line_d;
            rsp_error<=accept_error_d |
                       (accept_is_line_d ? |spad_line_parity_error :
                                           spad_parity_error);
            if (accept_valid) begin
                case (accept_client)
                  CLIENT_CORE:   data_rr_r<=RR_BANKED;
                  CLIENT_BANKED: data_rr_r<=RR_DMA;
                  CLIENT_DMA:    data_rr_r<=RR_CORE;
                  default:       data_rr_r<=data_rr_r;
                endcase
            end
        end
    end
endmodule
