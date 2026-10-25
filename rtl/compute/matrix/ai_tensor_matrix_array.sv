`timescale 1ns / 1ps

// Parameterized output-stationary INT8 matrix array.
//
// Each operand-buffer write loads one complete K-slice vector.  The two
// operand banks allow the controller to load the next K-slice while the
// current bank updates all ARRAY_SIZE*ARRAY_SIZE local accumulators.
// Address generation, SPAD arbitration and descriptor handling remain owned
// by the surrounding matrix controller.
module ai_tensor_matrix_array #(
    parameter integer ARRAY_SIZE = 8,
    parameter integer RESULT_INDEX_WIDTH =
        (ARRAY_SIZE*ARRAY_SIZE <= 1) ? 1 : $clog2(ARRAY_SIZE*ARRAY_SIZE)
)(
    input  wire                                  clk,
    input  wire                                  resetn,
    input  wire                                  clear_accumulators,

    input  wire                                  buffer_write_valid,
    input  wire                                  buffer_write_bank,
    input  wire [ARRAY_SIZE*8-1:0]               buffer_write_a,
    input  wire [ARRAY_SIZE*8-1:0]               buffer_write_b,

    input  wire                                  mac_enable,
    input  wire                                  mac_bank,

    input  wire [RESULT_INDEX_WIDTH-1:0]         result_index,
    input  wire signed [31:0]                    result_bias,
    input  wire [4:0]                            result_shift,
    input  wire [1:0]                            result_activation,
    output wire [ARRAY_SIZE*ARRAY_SIZE*64-1:0]     accumulator_vector,
    output reg signed [63:0]                     selected_accumulator,
    output reg [31:0]                            selected_result,
    output reg                                   selected_overflow
);
    localparam integer RESULT_COUNT = ARRAY_SIZE * ARRAY_SIZE;
    localparam [1:0] ACT_RELU  = 2'd1;
    localparam [1:0] ACT_RELU6 = 2'd2;

    reg [ARRAY_SIZE*8-1:0] operand_a_buffer [0:1];
    reg [ARRAY_SIZE*8-1:0] operand_b_buffer [0:1];
    reg signed [63:0] accumulator [0:RESULT_COUNT-1];
    wire signed [15:0] product [0:RESULT_COUNT-1];
    integer index;

    genvar row;
    genvar col;
    genvar acc_index;
    generate
        for (row = 0; row < ARRAY_SIZE; row = row + 1) begin : g_row
            for (col = 0; col < ARRAY_SIZE; col = col + 1) begin : g_col
                localparam integer PRODUCT_INDEX = row*ARRAY_SIZE + col;
                wire signed [7:0] a_value =
                    operand_a_buffer[mac_bank][row*8 +: 8];
                wire signed [7:0] b_value =
                    operand_b_buffer[mac_bank][col*8 +: 8];
                (* use_dsp = "yes" *)
                assign product[PRODUCT_INDEX] = a_value * b_value;
            end
        end
        for (acc_index = 0; acc_index < RESULT_COUNT; acc_index = acc_index + 1) begin : g_accumulator_export
            assign accumulator_vector[acc_index*64 +: 64] = accumulator[acc_index];
        end
    endgenerate

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            operand_a_buffer[0] <= {ARRAY_SIZE*8{1'b0}};
            operand_a_buffer[1] <= {ARRAY_SIZE*8{1'b0}};
            operand_b_buffer[0] <= {ARRAY_SIZE*8{1'b0}};
            operand_b_buffer[1] <= {ARRAY_SIZE*8{1'b0}};
            for (index = 0; index < RESULT_COUNT; index = index + 1)
                accumulator[index] <= 64'sd0;
        end else begin
            if (buffer_write_valid) begin
                operand_a_buffer[buffer_write_bank] <= buffer_write_a;
                operand_b_buffer[buffer_write_bank] <= buffer_write_b;
            end

            if (clear_accumulators) begin
                for (index = 0; index < RESULT_COUNT; index = index + 1)
                    accumulator[index] <= 64'sd0;
            end else if (mac_enable) begin
                for (index = 0; index < RESULT_COUNT; index = index + 1)
                    accumulator[index] <= accumulator[index] +
                        {{48{product[index][15]}}, product[index]};
            end
        end
    end

    reg signed [63:0] biased_value;
    reg signed [63:0] shifted_value;
    reg signed [63:0] activated_value;
    always @* begin
        selected_accumulator = 64'sd0;
        if (result_index < RESULT_COUNT)
            selected_accumulator = accumulator[result_index];

        biased_value = selected_accumulator +
                       {{32{result_bias[31]}}, result_bias};
        shifted_value = biased_value >>> result_shift;
        if (result_activation == ACT_RELU)
            activated_value = (shifted_value < 0) ? 64'sd0 : shifted_value;
        else if (result_activation == ACT_RELU6)
            activated_value = (shifted_value < 0) ? 64'sd0 :
                              (shifted_value > 64'sd6 ? 64'sd6 : shifted_value);
        else
            activated_value = shifted_value;

        selected_overflow = 1'b0;
        if (activated_value > 64'sh0000_0000_7fff_ffff) begin
            selected_result = 32'h7fff_ffff;
            selected_overflow = 1'b1;
        end else if (activated_value < -64'sd2147483648) begin
            selected_result = 32'h8000_0000;
            selected_overflow = 1'b1;
        end else begin
            selected_result = activated_value[31:0];
        end
    end
endmodule
