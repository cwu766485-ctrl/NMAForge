// Stateless fixed-point math used by ai_tensor_sfu_core.
//
// The core keeps every memory, divider and square-root state boundary.  This
// module contains only the combinational arithmetic that is sampled by those
// existing boundaries, so it introduces no extra execution cycles.
module ai_tensor_sfu_math (
    input  wire signed [31:0] softmax_delta_q8_8,
    input  wire signed [31:0] requant_value,
    input  wire [4:0]         requant_shift,

    input  wire signed [31:0] residual_x,
    input  wire signed [31:0] residual_y,
    input  wire [4:0]         residual_shift,
    input  wire signed [31:0] gamma_x,
    input  wire signed [31:0] gamma,

    input  wire signed [31:0] norm_x,
    input  wire [31:0]        norm_inv_rms,
    input  wire signed [31:0] norm_beta,
    input  wire               norm_add_beta,

    input  wire signed [63:0] gelu_product,
    input  wire signed [63:0] silu_product,

    output wire [31:0]        softmax_exp_q15,
    output wire [31:0]        requant_i8_value,
    output wire [31:0]        residual_value,
    output wire [31:0]        gamma_scaled_value,
    output wire [31:0]        normalization_value,
    output wire [31:0]        gelu_q8_8_value,
    output wire [31:0]        silu_q8_8_value
);

    function [31:0] exp2_q15;
        input signed [31:0] delta_q8_8;
        reg [31:0] magnitude;
        reg [7:0] fraction;
        reg [7:0] integer_part;
        reg [31:0] base_value;
        reg [31:0] next_value;
        begin
            if (delta_q8_8 >= 0)
                exp2_q15 = 32'd32768;
            else begin
                magnitude = -delta_q8_8;
                integer_part = magnitude[15:8];
                fraction = magnitude[7:0];
                if (integer_part >= 8'd15)
                    exp2_q15 = 32'd0;
                else begin
                    base_value = 32'd32768 >> integer_part;
                    next_value = base_value >> 1;
                    exp2_q15 = base_value -
                               (((base_value - next_value) * fraction) >> 8);
                end
            end
        end
    endfunction

    function [31:0] clamp_i32;
        input signed [63:0] value;
        begin
            if (value > 64'sh0000_0000_7fff_ffff)
                clamp_i32 = 32'h7fff_ffff;
            else if (value < -64'sd2147483648)
                clamp_i32 = 32'h8000_0000;
            else
                clamp_i32 = value[31:0];
        end
    endfunction

    function [31:0] requant_i8;
        input signed [31:0] value;
        input [4:0] shift;
        reg signed [31:0] shifted;
        begin
            shifted = value >>> shift;
            if (shifted > 127)
                requant_i8 = 32'h0000_007f;
            else if (shifted < -128)
                requant_i8 = 32'hffff_ff80;
            else
                requant_i8 = {{24{shifted[7]}}, shifted[7:0]};
        end
    endfunction

    wire signed [63:0] residual_sum = $signed(residual_x) + $signed(residual_y);
    wire signed [63:0] residual_shifted = residual_sum >>> residual_shift;
    wire signed [63:0] gamma_product = $signed(gamma_x) * $signed(gamma);
    wire signed [63:0] norm_scaled =
        ($signed(norm_x) * $signed(norm_inv_rms)) >>> 30;
    wire signed [63:0] norm_with_beta = norm_scaled + $signed(norm_beta);

    assign softmax_exp_q15 = exp2_q15(softmax_delta_q8_8);
    assign requant_i8_value = requant_i8(requant_value, requant_shift);
    assign residual_value = clamp_i32(residual_shifted);
    assign gamma_scaled_value = clamp_i32(gamma_product >>> 15);
    assign normalization_value = clamp_i32(norm_add_beta ?
                                             norm_with_beta : norm_scaled);
    assign gelu_q8_8_value = clamp_i32(gelu_product >>> 10);
    assign silu_q8_8_value = clamp_i32(silu_product / 64'sd1536);

endmodule
