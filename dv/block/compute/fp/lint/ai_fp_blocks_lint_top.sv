// Small hierarchy root for isolated SpyGlass lint of the G1 FP arithmetic.
// This top intentionally has no SRAM, AXI fabric, or product-level constraints.
module ai_fp_blocks_lint_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clear,
    input  wire        accumulate,
    input  wire [15:0] bf16_a_bits,
    input  wire [15:0] bf16_b_bits,
    input  wire [15:0] fp16_a_bits,
    input  wire [15:0] fp16_b_bits,
    input  wire        subtract,
    input  wire [31:0] fp32_a_bits,
    input  wire [31:0] fp32_b_bits,
    input  wire [31:0] fp32_product_bits,
    output wire [31:0] bf16_product_fp32_bits,
    output wire [31:0] fp32_sum_bits,
    output wire [31:0] fp32_accumulator_bits,
    output wire [15:0] bf16_sum_bits,
    output wire [15:0] fp16_sum_bits
);
    ai_bf16_mul_fp32 u_bf16_mul_fp32 (
        .a_bits(bf16_a_bits),
        .b_bits(bf16_b_bits),
        .result_bits(bf16_product_fp32_bits)
    );

    ai_fp32_add u_fp32_add (
        .a_bits(fp32_a_bits),
        .b_bits(fp32_b_bits),
        .result_bits(fp32_sum_bits)
    );

    ai_fp32_accumulator u_fp32_accumulator (
        .clk(clk),
        .rst_n(rst_n),
        .clear(clear),
        .accumulate(accumulate),
        .product_bits(fp32_product_bits),
        .accumulator_bits(fp32_accumulator_bits)
    );

    ai_bf16_addsub u_bf16_addsub (
        .a_bits(bf16_a_bits),
        .b_bits(bf16_b_bits),
        .subtract(subtract),
        .result_bits(bf16_sum_bits)
    );

    ai_fp16_addsub u_fp16_addsub (
        .a_bits(fp16_a_bits),
        .b_bits(fp16_b_bits),
        .subtract(subtract),
        .result_bits(fp16_sum_bits)
    );
endmodule
