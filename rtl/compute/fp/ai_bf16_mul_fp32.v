// Combinational BF16 x BF16 -> FP32 multiply.
// Finite products are exact at BF16 precision (at most 16 significand bits);
// only FP32 subnormal quantization and exponent overflow require rounding.
module ai_bf16_mul_fp32 (
    input  [15:0] a_bits,
    input  [15:0] b_bits,
    output reg [31:0] result_bits
);

    reg [7:0] a_exponent;
    reg [7:0] b_exponent;
    reg [6:0] a_fraction;
    reg [6:0] b_fraction;
    reg [7:0] a_significand;
    reg [7:0] b_significand;
    reg [15:0] significand_product;
    reg [31:0] normalized_significand;
    reg [31:0] subnormal_rounded;
    reg [31:0] remainder_mask;
    reg [31:0] remainder;
    reg [31:0] halfway;
    reg result_sign;
    integer a_scale;
    integer b_scale;
    integer product_scale;
    integer product_msb;
    integer result_exponent;
    reg [7:0] exponent_field;
    integer subnormal_shift;
    integer right_shift;
    integer i;

    always @* begin
        a_exponent = a_bits[14:7];
        b_exponent = b_bits[14:7];
        a_fraction = a_bits[6:0];
        b_fraction = b_bits[6:0];
        result_sign = a_bits[15] ^ b_bits[15];

        a_significand = 8'b0;
        b_significand = 8'b0;
        significand_product = 16'b0;
        normalized_significand = 32'b0;
        subnormal_rounded = 32'b0;
        remainder_mask = 32'b0;
        remainder = 32'b0;
        halfway = 32'b0;
        a_scale = 0;
        b_scale = 0;
        product_scale = 0;
        product_msb = 0;
        result_exponent = 0;
        exponent_field = 0;
        subnormal_shift = 0;
        right_shift = 0;
        i = 0;
        result_bits = 32'b0;

        // All NaN inputs and invalid 0 x Inf products use canonical FP32 qNaN.
        if (((a_exponent == 8'hff) && (a_fraction != 7'b0)) ||
            ((b_exponent == 8'hff) && (b_fraction != 7'b0))) begin
            result_bits = 32'h7fc00000;
        end else if (((a_exponent == 8'hff) && (b_exponent == 8'h00) &&
                      (b_fraction == 7'b0)) ||
                     ((b_exponent == 8'hff) && (a_exponent == 8'h00) &&
                      (a_fraction == 7'b0))) begin
            result_bits = 32'h7fc00000;
        end else if ((a_exponent == 8'hff) || (b_exponent == 8'hff)) begin
            result_bits = {result_sign, 8'hff, 23'b0};
        end else begin
            // BF16 value = significand * 2**scale. Normals include the hidden
            // bit; subnormals use the same fixed scale and no hidden bit.
            if (a_exponent == 8'h00) begin
                a_significand = {1'b0, a_fraction};
                a_scale = -133;
            end else begin
                a_significand = {1'b1, a_fraction};
                a_scale = a_exponent;
                a_scale = a_scale - 134;
            end
            if (b_exponent == 8'h00) begin
                b_significand = {1'b0, b_fraction};
                b_scale = -133;
            end else begin
                b_significand = {1'b1, b_fraction};
                b_scale = b_exponent;
                b_scale = b_scale - 134;
            end

            if ((a_significand == 8'b0) || (b_significand == 8'b0)) begin
                // This includes every signed-zero x finite case. 0 x Inf was
                // handled above; the output zero sign is always input XOR.
                result_bits = {result_sign, 31'b0};
            end else begin
                significand_product = {8'b0, a_significand} *
                                      {8'b0, b_significand};
                product_scale = a_scale + b_scale;
                for (i = 0; i < 16; i = i + 1) begin
                    if (significand_product[i])
                        product_msb = i;
                end
                result_exponent = product_scale + product_msb;

                if (result_exponent > 127) begin
                    result_bits = {result_sign, 8'hff, 23'b0};
                end else if (result_exponent >= -126) begin
                    // At most 16 product bits are normalized into the 24-bit
                    // FP32 significand, so this path has no precision loss.
                    normalized_significand =
                        {16'b0, significand_product} << (23 - product_msb);
                    exponent_field = result_exponent + 127;
                    result_bits = {result_sign, exponent_field[7:0],
                                   normalized_significand[22:0]};
                end else begin
                    // FP32 subnormal quantum is 2**-149.  Round the exact
                    // product / quantum to nearest, ties to even.
                    subnormal_shift = product_scale + 149;
                    if (subnormal_shift >= 0) begin
                        subnormal_rounded =
                            {16'b0, significand_product} << subnormal_shift;
                    end else begin
                        right_shift = -subnormal_shift;
                        if (right_shift > 16) begin
                            // Product is <= 65535, strictly below half of
                            // 2**right_shift for right_shift >= 17.
                            subnormal_rounded = 32'b0;
                        end else begin
                            subnormal_rounded =
                                {16'b0, significand_product} >> right_shift;
                            remainder_mask = (32'd1 << right_shift) - 1'b1;
                            remainder = {16'b0, significand_product} &
                                        remainder_mask;
                            halfway = 32'd1 << (right_shift - 1);
                            if ((remainder > halfway) ||
                                ((remainder == halfway) &&
                                 subnormal_rounded[0])) begin
                                subnormal_rounded = subnormal_rounded + 1'b1;
                            end
                        end
                    end

                    if (subnormal_rounded == 32'b0) begin
                        result_bits = {result_sign, 31'b0};
                    end else if (subnormal_rounded >= 32'h00800000) begin
                        // Rounding the top subnormal bin can carry to min-normal.
                        result_bits = {result_sign, 8'h01, 23'b0};
                    end else begin
                        result_bits = {result_sign, 8'h00,
                                       subnormal_rounded[22:0]};
                    end
                end
            end
        end
    end

endmodule
