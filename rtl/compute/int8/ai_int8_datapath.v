`timescale 1ns / 1ps

// Stateless packed-INT8 arithmetic helper for ai_int8_compute_core.
// No register or handshake is introduced: the CALC-to-WRITE cycle boundary is
// retained exactly as in the original core.
module ai_int8_datapath(
    input  wire [31:0]        a_word,
    input  wire [31:0]        b_word,
    input  wire signed [63:0] accumulator,
    input  wire [4:0]         scale_shift,
    input  wire [1:0]         activation,
    output wire signed [63:0] accumulator_sum,
    output wire [31:0]        quantized_result
);
    localparam [1:0] ACT_RELU  = 2'd1;
    localparam [1:0] ACT_RELU6 = 2'd2;

    wire signed [7:0] a0 = a_word[7:0];
    wire signed [7:0] a1 = a_word[15:8];
    wire signed [7:0] a2 = a_word[23:16];
    wire signed [7:0] a3 = a_word[31:24];
    wire signed [7:0] b0 = b_word[7:0];
    wire signed [7:0] b1 = b_word[15:8];
    wire signed [7:0] b2 = b_word[23:16];
    wire signed [7:0] b3 = b_word[31:24];
    wire signed [31:0] product0 = a0 * b0;
    wire signed [31:0] product1 = a1 * b1;
    wire signed [31:0] product2 = a2 * b2;
    wire signed [31:0] product3 = a3 * b3;
    wire signed [63:0] shifted_sum;
    wire signed [63:0] activated_sum;

    assign accumulator_sum = accumulator + product0 + product1 +
                             product2 + product3;
    assign shifted_sum     = accumulator_sum >>> scale_shift;
    assign activated_sum   = (activation == ACT_RELU) ?
                           ((shifted_sum < 0) ? 64'sd0 : shifted_sum) :
                           ((activation == ACT_RELU6) ?
                           ((shifted_sum < 0) ? 64'sd0 :
                           ((shifted_sum > 64'sd6) ? 64'sd6 : shifted_sum)) :
                           shifted_sum);
    assign quantized_result = (activated_sum > 64'sd2147483647) ? 32'h7fff_ffff :
                              (activated_sum < -64'sd2147483648) ? 32'h8000_0000 :
                              activated_sum[31:0];
endmodule
