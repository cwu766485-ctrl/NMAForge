`timescale 1ns / 1ps

// Fixed four-bank reduction tree.  The widened output retains all carry bits
// from four signed INT32 bank-local partial sums.
module ai_reduction_tree(
    input  wire signed [31:0] partial0,
    input  wire signed [31:0] partial1,
    input  wire signed [31:0] partial2,
    input  wire signed [31:0] partial3,
    output wire signed [33:0] sum
);
    wire signed [32:0] sum01 = {partial0[31], partial0} + {partial1[31], partial1};
    wire signed [32:0] sum23 = {partial2[31], partial2} + {partial3[31], partial3};
    assign sum = {sum01[32], sum01} + {sum23[32], sum23};
endmodule
