`timescale 1ns/1ps

// Isolated one-entry streaming SFU prototype for elementwise primitives.
// OP_RESIDUAL preserves signed 32-bit addition; OP_REQUANT applies arithmetic
// shift followed by the product INT8 saturation convention.
module ai_streaming_sfu (
    input logic clk, input logic resetn, input logic epoch_bump,
    input logic in_valid, output logic in_ready,
    input logic signed [31:0] in_a, input logic signed [31:0] in_b,
    input logic [1:0] op_mode, input logic [4:0] shift,
    output logic out_valid, input logic out_ready,
    output logic signed [31:0] out_data, output logic out_error,
    output logic [31:0] accepted_count, output logic [31:0] committed_count
);
    localparam logic [1:0] OP_RESIDUAL = 2'd0;
    localparam logic [1:0] OP_REQUANT = 2'd1;
    logic full_r, error_r;
    logic signed [31:0] data_r;
    logic signed [32:0] sum_w;
    logic signed [32:0] shifted_w;
    logic signed [31:0] requant_w;
    assign in_ready = !full_r || out_ready;
    assign out_valid = full_r;
    assign out_data = data_r;
    assign out_error = error_r;
    always_comb begin
        sum_w = $signed(in_a) + $signed(in_b);
        shifted_w = sum_w >>> shift;
        if (shifted_w > 33'sd127) requant_w = 32'sd127;
        else if (shifted_w < -33'sd128) requant_w = -32'sd128;
        else requant_w = shifted_w[31:0];
    end
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            full_r <= 1'b0; data_r <= '0; error_r <= 1'b0;
            accepted_count <= '0; committed_count <= '0;
        end else if (epoch_bump) begin
            full_r <= 1'b0; error_r <= 1'b0;
        end else begin
            if (out_valid && out_ready) begin
                full_r <= 1'b0;
                committed_count <= committed_count + 1'b1;
            end
            if (in_valid && in_ready) begin
                full_r <= 1'b1;
                accepted_count <= accepted_count + 1'b1;
                case (op_mode)
                    OP_RESIDUAL: begin data_r <= sum_w[31:0]; error_r <= 1'b0; end
                    OP_REQUANT: begin data_r <= requant_w; error_r <= 1'b0; end
                    default: begin data_r <= '0; error_r <= 1'b1; end
                endcase
            end
        end
    end
`ifndef SYNTHESIS
    property p_output_stable_until_ready;
        @(posedge clk) disable iff (!resetn || epoch_bump)
        out_valid && !out_ready |=> out_valid && $stable({out_data,out_error});
    endproperty
    assert property (p_output_stable_until_ready);
`endif
endmodule
