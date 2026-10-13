// Non-fused sequential FP32 accumulator register wrapper.
// Each accepted accumulate cycle performs exactly one RNE FP32 addition.
module ai_fp32_accumulator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clear,
    input  wire        accumulate,
    input  wire [31:0] product_bits,
    output reg  [31:0] accumulator_bits
);
    wire [31:0] sum_bits;

    ai_fp32_add u_fp32_add (
        .a_bits(accumulator_bits),
        .b_bits(product_bits),
        .result_bits(sum_bits)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            accumulator_bits <= 32'h00000000;
        else if (clear)
            accumulator_bits <= 32'h00000000;
        else if (accumulate)
            accumulator_bits <= sum_bits;
    end
endmodule
