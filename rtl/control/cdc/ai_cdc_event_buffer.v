`timescale 1ns / 1ps

// One-entry elastic buffer for a pulse-only compute-domain event producer.
// ai_command_processor has no event-ready input; the command-path wrapper
// therefore prevents a new command from starting while this entry is busy.
module ai_cdc_event_buffer #(
    parameter integer DATA_WIDTH = 199
)(
    input  wire                  clk,
    input  wire                  resetn,
    input  wire                  in_valid,
    input  wire [DATA_WIDTH-1:0] in_data,
    output wire                  out_valid,
    input  wire                  out_ready,
    output wire [DATA_WIDTH-1:0] out_data,
    output wire                  overflow
);
    reg                  valid_r;
    reg [DATA_WIDTH-1:0] data_r;
    reg                  overflow_r;
    wire                 out_fire = valid_r && out_ready;

    assign out_valid = valid_r;
    assign out_data = data_r;
    assign overflow = overflow_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid_r    <= 1'b0;
            data_r     <= {DATA_WIDTH{1'b0}};
            overflow_r <= 1'b0;
        end else if (in_valid) begin
            if (!valid_r || out_fire) begin
                data_r  <= in_data;
                valid_r <= 1'b1;
            end else begin
                overflow_r <= 1'b1;
            end
        end else if (out_fire) begin
            valid_r <= 1'b0;
        end
    end
endmodule
