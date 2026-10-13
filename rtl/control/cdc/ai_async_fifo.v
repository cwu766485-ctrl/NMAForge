`timescale 1ns / 1ps

// CDC-safe dual-clock FIFO for command/completion payloads.
// DEPTH must be a power of two. Reset assertion is asynchronous per domain;
// pointer release is synchronized by the normal two-flop pointer crossings.
module ai_async_fifo #(
    parameter integer DATA_WIDTH = 128,
    parameter integer DEPTH = 16,
    parameter integer ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  wr_clk,
    input  wire                  wr_resetn,
    input  wire                  wr_valid,
    output wire                  wr_ready,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,
    input  wire                  rd_clk,
    input  wire                  rd_resetn,
    output wire                  rd_valid,
    input  wire                  rd_ready,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty,
    output wire                  wr_overflow,
    output wire                  rd_underflow
);
    localparam integer PTR_WIDTH = ADDR_WIDTH + 1;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH-1:0] wr_ptr_bin, wr_ptr_gray;
    reg [PTR_WIDTH-1:0] rd_ptr_bin, rd_ptr_gray;
    // Preserve these two-stage synchronizers through implementation and keep
    // the flops colocated where the target flow honors ASYNC_REG.
    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_wr1, rd_gray_wr2;
    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_rd1, wr_gray_rd2;
    reg wr_overflow_r, rd_underflow_r;
    wire wr_fire = wr_valid && wr_ready;
    wire rd_fire = rd_valid && rd_ready;
    wire [PTR_WIDTH-1:0] wr_bin_next = wr_ptr_bin + wr_fire;
    wire [PTR_WIDTH-1:0] rd_bin_next = rd_ptr_bin + rd_fire;
    wire [PTR_WIDTH-1:0] wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    wire [PTR_WIDTH-1:0] rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;
    wire wr_full_next = (wr_gray_next == {~rd_gray_wr2[PTR_WIDTH-1:PTR_WIDTH-2],
                                           rd_gray_wr2[PTR_WIDTH-3:0]});
    assign wr_full = (wr_ptr_gray == {~rd_gray_wr2[PTR_WIDTH-1:PTR_WIDTH-2],
                                      rd_gray_wr2[PTR_WIDTH-3:0]});
    assign wr_ready = !wr_full;
    assign rd_empty = (rd_ptr_gray == wr_gray_rd2);
    assign rd_valid = !rd_empty;
    // Show-ahead read. The payload is held stable while rd_valid is asserted
    // and rd_ready is low, which is the required ready/valid contract.
    assign rd_data = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
    assign wr_overflow = wr_overflow_r;
    assign rd_underflow = rd_underflow_r;

    always @(posedge wr_clk or negedge wr_resetn) begin
        if (!wr_resetn) begin
            wr_ptr_bin <= {PTR_WIDTH{1'b0}};
            wr_ptr_gray <= {PTR_WIDTH{1'b0}};
            rd_gray_wr1 <= {PTR_WIDTH{1'b0}};
            rd_gray_wr2 <= {PTR_WIDTH{1'b0}};
            wr_overflow_r <= 1'b0;
        end else begin
            rd_gray_wr1 <= rd_ptr_gray;
            rd_gray_wr2 <= rd_gray_wr1;
            // Sticky diagnostic: a rejected write remains observable until
            // the write side is reset, so software/testbench cannot miss a
            // one-cycle full condition.
            if (wr_valid && wr_full)
                wr_overflow_r <= 1'b1;
            if (wr_fire) begin
                mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
                wr_ptr_bin <= wr_bin_next;
                wr_ptr_gray <= wr_gray_next;
            end
        end
    end

    always @(posedge rd_clk or negedge rd_resetn) begin
        if (!rd_resetn) begin
            rd_ptr_bin <= {PTR_WIDTH{1'b0}};
            rd_ptr_gray <= {PTR_WIDTH{1'b0}};
            wr_gray_rd1 <= {PTR_WIDTH{1'b0}};
            wr_gray_rd2 <= {PTR_WIDTH{1'b0}};
            rd_underflow_r <= 1'b0;
        end else begin
            wr_gray_rd1 <= wr_ptr_gray;
            wr_gray_rd2 <= wr_gray_rd1;
            // Sticky diagnostic: a rejected read remains observable until
            // the read side is reset.
            if (rd_ready && rd_empty)
                rd_underflow_r <= 1'b1;
            if (rd_fire) begin
                rd_ptr_bin <= rd_bin_next;
                rd_ptr_gray <= rd_gray_next;
            end
        end
    end
endmodule
