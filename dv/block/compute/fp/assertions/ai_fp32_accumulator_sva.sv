// Temporal control checks for the sequential FP32 accumulator wrapper.
// Arithmetic bit-exactness remains covered by the independent Python vectors.
module ai_fp32_accumulator_sva (
    input wire        clk,
    input wire        rst_n,
    input wire        clear,
    input wire        accumulate,
    input wire [31:0] product_bits,
    input wire [31:0] accumulator_bits
);
    wire [31:0] add_result_bits;

    ai_fp32_add u_expected_add (
        .a_bits(accumulator_bits),
        .b_bits(product_bits),
        .result_bits(add_result_bits)
    );

    property clear_wins_and_clears;
        @(posedge clk) disable iff (!rst_n)
            clear |=> (accumulator_bits == 32'h00000000);
    endproperty

    property accumulate_writes_add_result;
        @(posedge clk) disable iff (!rst_n)
            (accumulate && !clear) |=>
                (accumulator_bits == $past(add_result_bits));
    endproperty

    property idle_holds_value;
        @(posedge clk) disable iff (!rst_n)
            (!clear && !accumulate) |=>
                (accumulator_bits == $past(accumulator_bits));
    endproperty

    assert property (clear_wins_and_clears)
        else $error("FP32 accumulator clear priority/zero timing failure");
    assert property (accumulate_writes_add_result)
        else $error("FP32 accumulator accumulate timing failure");
    assert property (idle_holds_value)
        else $error("FP32 accumulator idle hold failure");
endmodule
