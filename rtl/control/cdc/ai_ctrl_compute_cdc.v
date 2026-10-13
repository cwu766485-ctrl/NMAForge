`timescale 1ns / 1ps

// Experimental two-clock boundary. The product top remains single-clock;
// this wrapper is the controlled integration point for a future clk_ctrl /
// clk_compute partition.
module ai_ctrl_compute_cdc #(
    parameter integer CMD_DATA_WIDTH = 128,
    parameter integer CPL_DATA_WIDTH = 128,
    parameter integer DEPTH = 16
)(
    input wire ctrl_clk, input wire ctrl_resetn,
    input wire ctrl_cmd_valid, output wire ctrl_cmd_ready,
    input wire [CMD_DATA_WIDTH-1:0] ctrl_cmd_data,
    output wire ctrl_cpl_valid, input wire ctrl_cpl_ready,
    output wire [CPL_DATA_WIDTH-1:0] ctrl_cpl_data,
    input wire compute_clk, input wire compute_resetn,
    output wire compute_cmd_valid, input wire compute_cmd_ready,
    output wire [CMD_DATA_WIDTH-1:0] compute_cmd_data,
    input wire compute_cpl_valid, output wire compute_cpl_ready,
    input wire [CPL_DATA_WIDTH-1:0] compute_cpl_data
);
    wire command_fifo_rd_valid;
    wire command_fifo_rd_ready;
    wire [CMD_DATA_WIDTH-1:0] command_fifo_rd_data;
    reg command_stage_valid;
    reg [CMD_DATA_WIDTH-1:0] command_stage_data;

    wire completion_fifo_rd_valid;
    wire completion_fifo_rd_ready;
    wire [CPL_DATA_WIDTH-1:0] completion_fifo_rd_data;
    reg completion_stage_valid;
    reg [CPL_DATA_WIDTH-1:0] completion_stage_data;

    // The staging register is the only consumer-facing state in the
    // destination clock domain.  It can be consumed and refilled in one
    // cycle, so the FIFO never needs a second entry of buffering here.
    assign compute_cmd_valid = command_stage_valid;
    assign compute_cmd_data = command_stage_data;
    assign command_fifo_rd_ready = !command_stage_valid || compute_cmd_ready;

    assign ctrl_cpl_valid = completion_stage_valid;
    assign ctrl_cpl_data = completion_stage_data;
    assign completion_fifo_rd_ready = !completion_stage_valid || ctrl_cpl_ready;

    ai_async_fifo #(.DATA_WIDTH(CMD_DATA_WIDTH), .DEPTH(DEPTH)) command_fifo (
        .wr_clk(ctrl_clk), .wr_resetn(ctrl_resetn), .wr_valid(ctrl_cmd_valid),
        .wr_ready(ctrl_cmd_ready), .wr_data(ctrl_cmd_data), .wr_full(),
        .rd_clk(compute_clk), .rd_resetn(compute_resetn), .rd_valid(command_fifo_rd_valid),
        .rd_ready(command_fifo_rd_ready), .rd_data(command_fifo_rd_data), .rd_empty(),
        .wr_overflow(), .rd_underflow());
    ai_async_fifo #(.DATA_WIDTH(CPL_DATA_WIDTH), .DEPTH(DEPTH)) completion_fifo (
        .wr_clk(compute_clk), .wr_resetn(compute_resetn), .wr_valid(compute_cpl_valid),
        .wr_ready(compute_cpl_ready), .wr_data(compute_cpl_data), .wr_full(),
        .rd_clk(ctrl_clk), .rd_resetn(ctrl_resetn), .rd_valid(completion_fifo_rd_valid),
        .rd_ready(completion_fifo_rd_ready), .rd_data(completion_fifo_rd_data), .rd_empty(),
        .wr_overflow(), .rd_underflow());

    always @(posedge compute_clk or negedge compute_resetn) begin
        if (!compute_resetn) begin
            command_stage_valid <= 1'b0;
            command_stage_data <= {CMD_DATA_WIDTH{1'b0}};
        end else begin
            if (command_stage_valid && compute_cmd_ready)
                command_stage_valid <= 1'b0;
            if (command_fifo_rd_valid && command_fifo_rd_ready) begin
                command_stage_data <= command_fifo_rd_data;
                command_stage_valid <= 1'b1;
            end
        end
    end

    always @(posedge ctrl_clk or negedge ctrl_resetn) begin
        if (!ctrl_resetn) begin
            completion_stage_valid <= 1'b0;
            completion_stage_data <= {CPL_DATA_WIDTH{1'b0}};
        end else begin
            if (completion_stage_valid && ctrl_cpl_ready)
                completion_stage_valid <= 1'b0;
            if (completion_fifo_rd_valid && completion_fifo_rd_ready) begin
                completion_stage_data <= completion_fifo_rd_data;
                completion_stage_valid <= 1'b1;
            end
        end
    end
endmodule
