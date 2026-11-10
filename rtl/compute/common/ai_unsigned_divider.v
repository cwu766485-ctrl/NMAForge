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
    // When asserted, skip only zero leading dividend bits. The quotient and
    // remainder remain exact; callers without this optimization tie it low.
    input  wire                 accelerate,
    input  wire [WIDTH-1:0]     dividend,
    input  wire [WIDTH-1:0]     divisor,
    output reg                  busy,
    output reg                  done,
    output reg                  error,
    output reg  [WIDTH-1:0]     quotient,
    output reg  [WIDTH-1:0]     remainder
);
    localparam integer COUNT_BITS = $clog2(WIDTH+1);
    localparam [COUNT_BITS-1:0] WIDTH_COUNT = WIDTH;
    reg [WIDTH-1:0] dividend_r, divisor_r, quotient_r;
    reg [WIDTH:0] remainder_r;
    reg [COUNT_BITS-1:0] count_r;
    wire division_by_zero = (divisor == {WIDTH{1'b0}});
    wire final_iteration = (count_r == {{(COUNT_BITS-1){1'b0}}, 1'b1});
    wire [WIDTH:0] shifted_remainder = {remainder_r[WIDTH-1:0],dividend_r[WIDTH-1]};
    wire subtract_ok = shifted_remainder >= {1'b0,divisor_r};
    wire [WIDTH:0] next_remainder = subtract_ok ?
                                      shifted_remainder-{1'b0,divisor_r} : shifted_remainder;
    wire [WIDTH-1:0] next_quotient = {quotient_r[WIDTH-2:0],subtract_ok};

    function [COUNT_BITS-1:0] significant_bit_count;
        input [WIDTH-1:0] value;
        integer bit_index;
        reg found_one;
        begin
            significant_bit_count = {COUNT_BITS{1'b0}};
            found_one = 1'b0;
            for (bit_index=WIDTH-1; bit_index>=0; bit_index=bit_index-1) begin
                if (!found_one && value[bit_index]) begin
                    significant_bit_count = bit_index + 1;
                    found_one = 1'b1;
                end
            end
            if (!found_one)
                significant_bit_count = {{(COUNT_BITS-1){1'b0}},1'b1};
        end
    endfunction

    wire [COUNT_BITS-1:0] active_bit_count = accelerate ?
        significant_bit_count(dividend) : WIDTH_COUNT;
    wire [COUNT_BITS-1:0] leading_zero_shift = WIDTH_COUNT - active_bit_count;
    wire [WIDTH-1:0] normalized_dividend = dividend << leading_zero_shift;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            busy<=0; done<=0; error<=0; quotient<=0; remainder<=0;
            dividend_r<=0; divisor_r<=0; quotient_r<=0; remainder_r<=0; count_r<=0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                error <= division_by_zero;
                if (division_by_zero) begin
                    quotient<=0; remainder<=dividend; done<=1;
                end else begin
                    busy<=1; dividend_r<=normalized_dividend; divisor_r<=divisor;
                    quotient_r<=0; remainder_r<=0; count_r<=active_bit_count;
                end
            end else if (busy) begin
                dividend_r <= {dividend_r[WIDTH-2:0],1'b0};
                remainder_r <= next_remainder;
                quotient_r <= next_quotient;
                count_r <= count_r-1'b1;
                if (final_iteration) begin
                    busy<=0; done<=1; error<=0;
                    quotient<=next_quotient; remainder<=next_remainder[WIDTH-1:0];
                end
            end
        end
    end
endmodule
