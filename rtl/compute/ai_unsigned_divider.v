`timescale 1ns / 1ps

// Iterative unsigned divider used by the A3 fixed-point SFU.  One quotient bit
// is generated per cycle so division does not become a single long
// combinational path.  DIVISOR=0 returns ERROR with a zero quotient.
module ai_unsigned_divider #(
    parameter integer WIDTH = 64
)(
    input  wire                 clk,
    input  wire                 resetn,
    input  wire                 start,
    input  wire [WIDTH-1:0]     dividend,
    input  wire [WIDTH-1:0]     divisor,
    output reg                  busy,
    output reg                  done,
    output reg                  error,
    output reg  [WIDTH-1:0]     quotient,
    output reg  [WIDTH-1:0]     remainder
);
    localparam integer COUNT_BITS = $clog2(WIDTH+1);
    reg [WIDTH-1:0] dividend_r, divisor_r, quotient_r;
    reg [WIDTH:0] remainder_r;
    reg [COUNT_BITS-1:0] count_r;
    wire [WIDTH:0] shifted_remainder = {remainder_r[WIDTH-1:0],dividend_r[WIDTH-1]};
    wire subtract_ok = shifted_remainder >= {1'b0,divisor_r};
    wire [WIDTH:0] next_remainder = subtract_ok ?
                                      shifted_remainder-{1'b0,divisor_r} : shifted_remainder;
    wire [WIDTH-1:0] next_quotient = {quotient_r[WIDTH-2:0],subtract_ok};

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            busy<=0; done<=0; error<=0; quotient<=0; remainder<=0;
            dividend_r<=0; divisor_r<=0; quotient_r<=0; remainder_r<=0; count_r<=0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                error <= (divisor==0);
                if (divisor==0) begin
                    quotient<=0; remainder<=dividend; done<=1;
                end else begin
                    busy<=1; dividend_r<=dividend; divisor_r<=divisor;
                    quotient_r<=0; remainder_r<=0; count_r<=WIDTH;
                end
            end else if (busy) begin
                dividend_r <= {dividend_r[WIDTH-2:0],1'b0};
                remainder_r <= next_remainder;
                quotient_r <= next_quotient;
                count_r <= count_r-1'b1;
                if (count_r==1) begin
                    busy<=0; done<=1; error<=0;
                    quotient<=next_quotient; remainder<=next_remainder[WIDTH-1:0];
                end
            end
        end
    end
endmodule
