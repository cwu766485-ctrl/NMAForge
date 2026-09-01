`timescale 1ns / 1ps

// Combinational INT8 matrix datapath shared by the tensor matrix engine.
module ai_tensor_matrix_datapath(
    input  wire [31:0] a0,
    input  wire [31:0] a1,
    input  wire [31:0] a2,
    input  wire [31:0] a3,
    input  wire [31:0] b0,
    input  wire [31:0] b1,
    input  wire [31:0] b2,
    input  wire [31:0] b3,
    input  wire [1:0]  lane,
    input  wire        transpose_a,
    input  wire        transpose_b,

    output wire signed [7:0] a_lane0,
    output wire signed [7:0] a_lane1,
    output wire signed [7:0] a_lane2,
    output wire signed [7:0] a_lane3,
    output wire signed [7:0] b_lane0,
    output wire signed [7:0] b_lane1,
    output wire signed [7:0] b_lane2,
    output wire signed [7:0] b_lane3,

    (* use_dsp = "yes" *) output wire signed [15:0] product0,
    (* use_dsp = "yes" *) output wire signed [15:0] product1,
    (* use_dsp = "yes" *) output wire signed [15:0] product2,
    (* use_dsp = "yes" *) output wire signed [15:0] product3,
    (* use_dsp = "yes" *) output wire signed [15:0] product4,
    (* use_dsp = "yes" *) output wire signed [15:0] product5,
    (* use_dsp = "yes" *) output wire signed [15:0] product6,
    (* use_dsp = "yes" *) output wire signed [15:0] product7,
    (* use_dsp = "yes" *) output wire signed [15:0] product8,
    (* use_dsp = "yes" *) output wire signed [15:0] product9,
    (* use_dsp = "yes" *) output wire signed [15:0] product10,
    (* use_dsp = "yes" *) output wire signed [15:0] product11,
    (* use_dsp = "yes" *) output wire signed [15:0] product12,
    (* use_dsp = "yes" *) output wire signed [15:0] product13,
    (* use_dsp = "yes" *) output wire signed [15:0] product14,
    (* use_dsp = "yes" *) output wire signed [15:0] product15,

    input  wire signed [63:0] acc0,
    input  wire signed [63:0] acc1,
    input  wire signed [63:0] acc2,
    input  wire signed [63:0] acc3,
    input  wire signed [31:0] bias0,
    input  wire signed [31:0] bias1,
    input  wire signed [31:0] bias2,
    input  wire signed [31:0] bias3,
    input  wire               bias_enable,
    input  wire [4:0]         scale_shift,
    input  wire [1:0]         activation,
    input  wire signed [63:0] scalar_acc,
    input  wire signed [31:0] scalar_bias,
    output wire [31:0]        post_scalar,
    output wire [31:0]        post0,
    output wire [31:0]        post1,
    output wire [31:0]        post2,
    output wire [31:0]        post3
);
    localparam [1:0] ACT_RELU  = 2'd1;
    localparam [1:0] ACT_RELU6 = 2'd2;

    function signed [7:0] byte_at;
        input [31:0] word;
        input [1:0] index;
        begin
            case (index)
                2'd0: byte_at = word[7:0];
                2'd1: byte_at = word[15:8];
                2'd2: byte_at = word[23:16];
                default: byte_at = word[31:24];
            endcase
        end
    endfunction

    function signed [7:0] tile_elem;
        input [31:0] w0;
        input [31:0] w1;
        input [31:0] w2;
        input [31:0] w3;
        input [1:0] major;
        input [1:0] lane_index;
        input       transpose;
        reg [31:0] selected;
        reg [1:0] word_index;
        reg [1:0] byte_index;
        begin
            word_index = transpose ? lane_index : major;
            byte_index = transpose ? major : lane_index;
            case (word_index)
                2'd0: selected = w0;
                2'd1: selected = w1;
                2'd2: selected = w2;
                default: selected = w3;
            endcase
            tile_elem = byte_at(selected, byte_index);
        end
    endfunction

    function [31:0] post_process;
        input signed [63:0] accumulated;
        input signed [31:0] bias_value;
        input [4:0] shift;
        input [1:0] activation_mode;
        reg signed [63:0] biased;
        reg signed [63:0] shifted;
        reg signed [63:0] activated;
        begin
            biased = accumulated + {{32{bias_value[31]}}, bias_value};
            shifted = biased >>> shift;
            if (activation_mode == ACT_RELU)
                activated = shifted < 0 ? 64'sd0 : shifted;
            else if (activation_mode == ACT_RELU6)
                activated = shifted < 0 ? 64'sd0 :
                            (shifted > 64'sd6 ? 64'sd6 : shifted);
            else
                activated = shifted;

            if (activated > 64'sh0000_0000_7fff_ffff)
                post_process = 32'h7fff_ffff;
            else if (activated < -64'sd2147483648)
                post_process = 32'h8000_0000;
            else
                post_process = activated[31:0];
        end
    endfunction

    assign a_lane0 = tile_elem(a0, a1, a2, a3, 2'd0, lane, transpose_a);
    assign a_lane1 = tile_elem(a0, a1, a2, a3, 2'd1, lane, transpose_a);
    assign a_lane2 = tile_elem(a0, a1, a2, a3, 2'd2, lane, transpose_a);
    assign a_lane3 = tile_elem(a0, a1, a2, a3, 2'd3, lane, transpose_a);
    assign b_lane0 = tile_elem(b0, b1, b2, b3, 2'd0, lane, transpose_b);
    assign b_lane1 = tile_elem(b0, b1, b2, b3, 2'd1, lane, transpose_b);
    assign b_lane2 = tile_elem(b0, b1, b2, b3, 2'd2, lane, transpose_b);
    assign b_lane3 = tile_elem(b0, b1, b2, b3, 2'd3, lane, transpose_b);

    assign product0  = a_lane0 * b_lane0;
    assign product1  = a_lane0 * b_lane1;
    assign product2  = a_lane0 * b_lane2;
    assign product3  = a_lane0 * b_lane3;
    assign product4  = a_lane1 * b_lane0;
    assign product5  = a_lane1 * b_lane1;
    assign product6  = a_lane1 * b_lane2;
    assign product7  = a_lane1 * b_lane3;
    assign product8  = a_lane2 * b_lane0;
    assign product9  = a_lane2 * b_lane1;
    assign product10 = a_lane2 * b_lane2;
    assign product11 = a_lane2 * b_lane3;
    assign product12 = a_lane3 * b_lane0;
    assign product13 = a_lane3 * b_lane1;
    assign product14 = a_lane3 * b_lane2;
    assign product15 = a_lane3 * b_lane3;

    assign post_scalar = post_process(scalar_acc, scalar_bias,
                                      scale_shift, activation);
    assign post0 = post_process(acc0, bias_enable ? bias0 : 32'sd0,
                                scale_shift, activation);
    assign post1 = post_process(acc1, bias_enable ? bias1 : 32'sd0,
                                scale_shift, activation);
    assign post2 = post_process(acc2, bias_enable ? bias2 : 32'sd0,
                                scale_shift, activation);
    assign post3 = post_process(acc3, bias_enable ? bias3 : 32'sd0,
                                scale_shift, activation);

endmodule
