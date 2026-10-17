// Control-only formal abstraction for ai_mixed_precision_dot_fp32_core.
// Arithmetic datapath values are intentionally constant: the properties run
// through this harness concern request/response, slot ownership, error and FSM
// control, and these outputs do not feed those control cones in the RTL.
module ai_bf16_mul_fp32 (
    input  wire [15:0] a_bits,
    input  wire [15:0] b_bits,
    output wire [31:0] result_bits
);
    assign result_bits = 32'b0;
endmodule

module ai_fp16_mul_fp32 (
    input  wire [15:0] a_bits,
    input  wire [15:0] b_bits,
    output wire [31:0] result_bits
);
    assign result_bits = 32'b0;
endmodule

module ai_fp32_accumulator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        clear,
    input  wire        accumulate,
    input  wire [31:0] product_bits,
    output wire [31:0] accumulator_bits
);
    assign accumulator_bits = 32'b0;
endmodule
