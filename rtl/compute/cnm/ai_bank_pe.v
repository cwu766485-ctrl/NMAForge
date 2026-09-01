`timescale 1ns / 1ps

// One bank-local packed-INT8 processing element.  It consumes one 32-bit
// activation word and one 32-bit weight word (four signed INT8 lanes) and
// produces their dot4 partial sum.
module ai_bank_pe(
    input  wire [31:0] act_word,
    input  wire [31:0] weight_word,
    output wire signed [31:0] partial_sum
);
    // Keep every product 32-bit signed before summation.  This preserves the
    // original accumulation width and avoids a lane expression silently
    // narrowing before it reaches the bank-local accumulator.
    wire signed [7:0] act_lane0 = act_word[7:0];
    wire signed [7:0] act_lane1 = act_word[15:8];
    wire signed [7:0] act_lane2 = act_word[23:16];
    wire signed [7:0] act_lane3 = act_word[31:24];
    wire signed [7:0] weight_lane0 = weight_word[7:0];
    wire signed [7:0] weight_lane1 = weight_word[15:8];
    wire signed [7:0] weight_lane2 = weight_word[23:16];
    wire signed [7:0] weight_lane3 = weight_word[31:24];

    wire signed [31:0] product0 = act_lane0 * weight_lane0;
    wire signed [31:0] product1 = act_lane1 * weight_lane1;
    wire signed [31:0] product2 = act_lane2 * weight_lane2;
    wire signed [31:0] product3 = act_lane3 * weight_lane3;

    assign partial_sum = product0 + product1 + product2 + product3;
endmodule
