`timescale 1ns / 1ps

// 64-bit unsigned integer square root.  A bounded 32-step binary search keeps
// the RMSNorm reciprocal-square-root path sequential and synthesis friendly.
module ai_integer_sqrt(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire [63:0] radicand,
    output reg         busy,
    output reg         done,
    output reg  [31:0] root
);
    reg [63:0] radicand_r;
    reg [32:0] low_r, high_r;
    reg [31:0] answer_r;
    reg [5:0] count_r;
    wire [32:0] mid_ext = (low_r+high_r)>>1;
    wire [31:0] mid = mid_ext[31:0];
    wire [63:0] mid_square = mid*mid;
    wire fits = mid_square<=radicand_r;
    wire [31:0] next_answer = fits ? mid : answer_r;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            busy<=0; done<=0; root<=0; radicand_r<=0;
            low_r<=0; high_r<=0; answer_r<=0; count_r<=0;
        end else begin
            done<=0;
            if (start && !busy) begin
                busy<=1; radicand_r<=radicand; low_r<=0;
                high_r<=33'h0_ffff_ffff; answer_r<=0; count_r<=0;
            end else if (busy) begin
                answer_r<=next_answer;
                if (fits)
                    low_r<={1'b0,mid}+33'd1;
                else if (mid==0)
                    high_r<=0;
                else
                    high_r<={1'b0,mid}-33'd1;
                count_r<=count_r+1'b1;
                if (count_r==6'd31 || low_r>high_r) begin
                    busy<=0; done<=1; root<=next_answer;
                end
            end
        end
    end
endmodule
