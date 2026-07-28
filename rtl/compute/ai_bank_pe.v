`timescale 1ns / 1ps

// One bank-local packed-INT8 processing element.  It consumes one 32-bit
// activation word and one 32-bit weight word (four signed INT8 lanes) and
// produces their dot4 partial sum.
module ai_bank_pe(
    input  wire [31:0] act_word,
    input  wire [31:0] weight_word,
    output wire signed [31:0] partial_sum
);
    reg signed [7:0] a0, a1, a2, a3;
    reg signed [7:0] w0, w1, w2, w3;
    reg signed [31:0] p0, p1, p2, p3;

    always @(*) begin
        a0 = act_word[7:0];   a1 = act_word[15:8];
        a2 = act_word[23:16]; a3 = act_word[31:24];
        w0 = weight_word[7:0];   w1 = weight_word[15:8];
        w2 = weight_word[23:16]; w3 = weight_word[31:24];
        p0 = a0 * w0; p1 = a1 * w1;
        p2 = a2 * w2; p3 = a3 * w3;
    end

    assign partial_sum = p0 + p1 + p2 + p3;
endmodule
