// Combinational IEEE binary16 x binary16 -> binary32 multiply.
// The 11x11-bit significand product is exact in binary32; no result rounding
// is needed for finite inputs. NaNs are canonicalized and 0 x Inf is invalid.
module ai_fp16_mul_fp32 (
    input  wire [15:0] a_bits,
    input  wire [15:0] b_bits,
    output reg  [31:0] result_bits
);

    reg [4:0] a_exponent;
    reg [4:0] b_exponent;
    reg [9:0] a_fraction;
    reg [9:0] b_fraction;
    reg [10:0] a_significand;
    reg [10:0] b_significand;
    reg [21:0] significand_product;
    reg [31:0] normalized_significand;
    reg result_sign;
    reg [7:0] result_exponent_field;
    integer a_scale;
    integer b_scale;
    integer product_scale;
    integer product_msb;
    integer result_exponent;
    integer i;

    always @* begin
        a_exponent = a_bits[14:10];
        b_exponent = b_bits[14:10];
        a_fraction = a_bits[9:0];
        b_fraction = b_bits[9:0];
        result_sign = a_bits[15] ^ b_bits[15];

        a_significand = 11'b0;
        b_significand = 11'b0;
        significand_product = 22'b0;
        normalized_significand = 32'b0;
        result_exponent_field = 8'b0;
        a_scale = 0;
        b_scale = 0;
        product_scale = 0;
        product_msb = 0;
        result_exponent = 0;
        i = 0;
        result_bits = 32'b0;

        if (((a_exponent == 5'h1f) && (a_fraction != 10'b0)) ||
            ((b_exponent == 5'h1f) && (b_fraction != 10'b0))) begin
            result_bits = 32'h7fc0_0000;
        end else if (((a_exponent == 5'h1f) && (b_exponent == 5'h00) &&
                      (b_fraction == 10'b0)) ||
                     ((b_exponent == 5'h1f) && (a_exponent == 5'h00) &&
                      (a_fraction == 10'b0))) begin
            result_bits = 32'h7fc0_0000;
        end else if ((a_exponent == 5'h1f) || (b_exponent == 5'h1f)) begin
            result_bits = {result_sign, 8'hff, 23'b0};
        end else begin
            // A subnormal binary16 value is fraction * 2**-24; a normal
            // value is significand * 2**(exponent_field - 25).
            if (a_exponent == 5'h00) begin
                a_significand = {1'b0, a_fraction};
                a_scale = -24;
            end else begin
                a_significand = {1'b1, a_fraction};
                a_scale = $signed({1'b0, a_exponent}) - 32'sd25;
            end
            if (b_exponent == 5'h00) begin
                b_significand = {1'b0, b_fraction};
                b_scale = -24;
            end else begin
                b_significand = {1'b1, b_fraction};
                b_scale = $signed({1'b0, b_exponent}) - 32'sd25;
            end

            if ((a_significand == 11'b0) || (b_significand == 11'b0)) begin
                result_bits = {result_sign, 31'b0};
            end else begin
                significand_product = a_significand * b_significand;
                product_scale = a_scale + b_scale;
                for (i = 0; i < 22; i = i + 1)
                    if (significand_product[i])
                        product_msb = i;

                result_exponent = product_scale + product_msb;
                // The binary16 product range [-48, 31] is entirely within
                // the normal binary32 exponent range [-126, 127].
                normalized_significand =
                    {10'b0, significand_product} << (23 - product_msb);
                result_exponent_field = result_exponent + 127;
                result_bits = {result_sign, result_exponent_field,
                               normalized_significand[22:0]};
            end
        end
    end

endmodule
