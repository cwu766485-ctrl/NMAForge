`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: vec_accel_core
//
// Function:
//   Sequential scratchpad-based vector compute engine.
//
// Supported op_mode:
//   0: VADD   dst[i] = src0[i] + src1[i]
//   1: VSUB   dst[i] = src0[i] - src1[i]
//   2: VMAC   acc += (src0[i] * src1[i]) >> scale_shift, write final acc
//   3: L1DIST acc += abs(src0[i] - src1[i]), write final acc
//   4: VMUL   dst[i] = (src0[i] * src1[i]) >> scale_shift
//   5: SOM_RECALL scan weight neurons and return winner index
//   6: SOM_UPDATE update selected neuron weights in place
//
// CONFIG support:
//   signed_mode : signed arithmetic when set, unsigned arithmetic otherwise
//   saturate_en : saturating add/sub/mul/accumulate when set
//   round_en    : add half LSB before right shift for multiply-based ops
//   data_width  : 0=int32, 1=packed int16x2, 2=packed int8x4
//////////////////////////////////////////////////////////////////////////////////

module vec_accel_core #(
    parameter integer SRAM_WAIT_CYCLES = 1,
    parameter [31:0]  COMPUTE_ADDR_MAX = 32'h0000_3ffc
)(
    input  wire        hclk,
    input  wire        hresetn,

    input  wire        start,
    input  wire        soft_reset,
    input  wire [2:0]  op_mode,
    input  wire [31:0] src0_base,
    input  wire [31:0] src1_base,
    input  wire [31:0] dst_base,
    input  wire [15:0] length,
    input  wire [4:0]  scale_shift,
    input  wire [31:0] src0_stride,
    input  wire [31:0] src1_stride,
    input  wire [31:0] dst_stride,
    input  wire        signed_mode,
    input  wire        saturate_en,
    input  wire        round_en,
    input  wire [1:0]  data_width,
    input  wire [15:0] neuron_count,
    input  wire [31:0] neuron_stride,
    input  wire [15:0] neuron_index,

    input  wire [31:0] sram_rdata,

    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [31:0] result,
    output reg  [3:0]  error_code,
    output reg  [31:0] cycle_count,
    output reg  [15:0] element_count,
    output reg  [31:0] som_best_distance,
    output reg  [15:0] som_winner_index,

    output reg         sram_req,
    output reg         sram_w_en,
    output reg  [31:0] sram_addr,
    output reg  [31:0] sram_wdata
);

    localparam OP_VADD   = 3'd0;
    localparam OP_VSUB   = 3'd1;
    localparam OP_VMAC   = 3'd2;
    localparam OP_L1DIST = 3'd3;
    localparam OP_VMUL   = 3'd4;
    localparam OP_SOM_RECALL = 3'd5;
    localparam OP_SOM_UPDATE = 3'd6;

    localparam DW_WORD = 2'd0;
    localparam DW_HALF = 2'd1;
    localparam DW_BYTE = 2'd2;

    localparam ERR_NONE       = 4'd0;
    localparam ERR_LENGTH     = 4'd1;
    localparam ERR_OP         = 4'd2;
    localparam ERR_ALIGN      = 4'd3;
    localparam ERR_RANGE      = 4'd4;
    localparam ERR_STRIDE     = 4'd5;
    localparam ERR_CONFIG     = 4'd9;
    localparam ERR_NEURON     = 4'd10;

    localparam ST_IDLE       = 4'd0;
    localparam ST_READ0      = 4'd1;
    localparam ST_READ0_WAIT = 4'd2;
    localparam ST_READ1      = 4'd3;
    localparam ST_READ1_WAIT = 4'd4;
    localparam ST_CALC       = 4'd5;
    localparam ST_WRITE      = 4'd6;
    localparam ST_WRITE_WAIT = 4'd7;
    localparam ST_DONE       = 4'd8;
    localparam ST_ERROR      = 4'd9;

    reg [3:0]  state_r;
    reg [7:0]  wait_cnt_r;
    reg [15:0] index_r;
    reg [31:0] src0_data_r;
    reg [31:0] src1_data_r;
    reg [31:0] calc_data_r;
    reg [31:0] acc_r;
    reg [2:0]  op_r;
    reg [31:0] src0_base_r;
    reg [31:0] src1_base_r;
    reg [31:0] dst_base_r;
    reg [15:0] length_r;
    reg [4:0]  scale_shift_r;
    reg [31:0] src0_stride_r;
    reg [31:0] src1_stride_r;
    reg [31:0] dst_stride_r;
    reg        signed_mode_r;
    reg        saturate_en_r;
    reg        round_en_r;
    reg [1:0]  data_width_r;
    reg [15:0] neuron_count_r;
    reg [31:0] neuron_stride_r;
    reg [15:0] neuron_index_r;
    reg [15:0] neuron_loop_r;
    reg [31:0] current_distance_r;
    reg [31:0] best_distance_r;
    reg [15:0] winner_index_r;
    reg [3:0]  start_error_code;

    wire        wait_done;
    wire        last_element;
    wire        last_neuron;
    wire        write_each_element;
    wire        som_recall_op;
    wire        som_update_op;
    wire        som_op;
    wire [63:0] src0_elem_offset;
    wire [63:0] src1_elem_offset;
    wire [63:0] dst_elem_offset;
    wire [63:0] src1_neuron_offset;
    wire [63:0] start_src0_last_offset;
    wire [63:0] start_src1_last_offset;
    wire [63:0] start_dst_last_offset;
    wire [63:0] start_src1_neuron_offset;
    wire [64:0] start_src0_last_addr_ext;
    wire [64:0] start_src1_last_addr_ext;
    wire [64:0] start_dst_last_addr_ext;
    wire [31:0] src0_addr;
    wire [31:0] src1_addr;
    wire [31:0] dst_addr;
    wire [31:0] elem_result;
    wire [31:0] som_update_result;
    wire [31:0] acc_term;
    wire [31:0] acc_next;
    wire [31:0] recall_distance_next;
    wire        recall_best_update;
    wire [31:0] recall_best_next;
    wire [15:0] recall_winner_next;
    wire [31:0] processed_elements_ext;
    wire        length_valid;
    wire        op_valid;
    wire        data_width_valid;
    wire        stride_valid;
    wire        neuron_valid;
    wire        neuron_stride_valid;
    wire        addr_aligned;
    wire        addr_in_range;

    function [31:0] round_shift_u;
        input [63:0] value;
        input [4:0]  shift;
        input        round_cfg;
        reg [63:0] adjusted;
        reg [63:0] shifted;
        begin
            adjusted = value;
            if (round_cfg && (shift != 5'd0))
                adjusted = adjusted + (64'd1 << (shift - 5'd1));
            shifted = adjusted >> shift;
            round_shift_u = shifted[31:0];
        end
    endfunction

    function [31:0] round_shift_s;
        input signed [63:0] value;
        input [4:0]         shift;
        input               round_cfg;
        reg signed [63:0] adjusted;
        reg signed [63:0] shifted;
        begin
            adjusted = value;
            if (round_cfg && (shift != 5'd0)) begin
                if (value >= 0)
                    adjusted = adjusted + (64'sd1 <<< (shift - 5'd1));
                else
                    adjusted = adjusted - (64'sd1 <<< (shift - 5'd1));
            end
            shifted = adjusted >>> shift;
            round_shift_s = shifted[31:0];
        end
    endfunction

    function [31:0] sat32;
        input signed [64:0] value;
        input               signed_cfg;
        input               sat_cfg;
        begin
            if (!sat_cfg) begin
                sat32 = value[31:0];
            end else if (signed_cfg) begin
                if (value > 65'sd2147483647)
                    sat32 = 32'h7fff_ffff;
                else if (value < -65'sd2147483648)
                    sat32 = 32'h8000_0000;
                else
                    sat32 = value[31:0];
            end else begin
                if (value[64:32] != 33'd0)
                    sat32 = 32'hffff_ffff;
                else
                    sat32 = value[31:0];
            end
        end
    endfunction

    function [15:0] sat16;
        input signed [63:0] value;
        input               signed_cfg;
        input               sat_cfg;
        begin
            if (!sat_cfg) begin
                sat16 = value[15:0];
            end else if (signed_cfg) begin
                if (value > 64'sd32767)
                    sat16 = 16'h7fff;
                else if (value < -64'sd32768)
                    sat16 = 16'h8000;
                else
                    sat16 = value[15:0];
            end else begin
                if (value[63:16] != 48'd0)
                    sat16 = 16'hffff;
                else
                    sat16 = value[15:0];
            end
        end
    endfunction

    function [7:0] sat8;
        input signed [63:0] value;
        input               signed_cfg;
        input               sat_cfg;
        begin
            if (!sat_cfg) begin
                sat8 = value[7:0];
            end else if (signed_cfg) begin
                if (value > 64'sd127)
                    sat8 = 8'h7f;
                else if (value < -64'sd128)
                    sat8 = 8'h80;
                else
                    sat8 = value[7:0];
            end else begin
                if (value[63:8] != 56'd0)
                    sat8 = 8'hff;
                else
                    sat8 = value[7:0];
            end
        end
    endfunction

    function [31:0] ext16_to_32;
        input [15:0] value;
        input        signed_cfg;
        begin
            ext16_to_32 = signed_cfg ? {{16{value[15]}}, value} : {16'd0, value};
        end
    endfunction

    function [31:0] ext8_to_32;
        input [7:0] value;
        input       signed_cfg;
        begin
            ext8_to_32 = signed_cfg ? {{24{value[7]}}, value} : {24'd0, value};
        end
    endfunction

    function [31:0] calc_word_result;
        input [2:0]  op;
        input [31:0] a;
        input [31:0] b;
        input [4:0]  shift;
        input        signed_cfg;
        input        sat_cfg;
        input        round_cfg;
        reg signed [64:0] s_value;
        reg signed [63:0] s_prod;
        reg signed [63:0] s_adjusted;
        reg signed [63:0] s_shifted;
        reg [63:0] u_prod;
        reg [63:0] u_adjusted;
        reg [63:0] u_shifted;
        begin
            s_value = 65'sd0;
            u_prod = 64'd0;
            s_prod = 64'sd0;
            s_adjusted = 64'sd0;
            s_shifted = 64'sd0;
            u_adjusted = 64'd0;
            u_shifted = 64'd0;
            case (op)
                OP_VADD: begin
                    if (signed_cfg)
                        s_value = $signed(a) + $signed(b);
                    else
                        s_value = {33'd0, a} + {33'd0, b};
                    calc_word_result = sat32(s_value, signed_cfg, sat_cfg);
                end
                OP_VSUB: begin
                    if (signed_cfg)
                        s_value = $signed(a) - $signed(b);
                    else
                        s_value = {33'd0, a} - {33'd0, b};
                    calc_word_result = sat32(s_value, signed_cfg, sat_cfg);
                end
                OP_VMUL: begin
                    if (signed_cfg) begin
                        s_prod = $signed(a) * $signed(b);
                        s_adjusted = s_prod;
                        if (round_cfg && (shift != 5'd0)) begin
                            if (s_prod >= 0)
                                s_adjusted = s_adjusted + (64'sd1 <<< (shift - 5'd1));
                            else
                                s_adjusted = s_adjusted - (64'sd1 <<< (shift - 5'd1));
                        end
                        s_shifted = s_adjusted >>> shift;
                        calc_word_result = sat32({s_shifted[63], s_shifted}, signed_cfg, sat_cfg);
                    end else begin
                        u_prod = a * b;
                        u_adjusted = u_prod;
                        if (round_cfg && (shift != 5'd0))
                            u_adjusted = u_adjusted + (64'd1 << (shift - 5'd1));
                        u_shifted = u_adjusted >> shift;
                        calc_word_result = sat32({1'b0, u_shifted}, signed_cfg, sat_cfg);
                    end
                end
                default: begin
                    calc_word_result = 32'd0;
                end
            endcase
        end
    endfunction

    function [15:0] calc_lane16;
        input [2:0]  op;
        input [15:0] a;
        input [15:0] b;
        input [4:0]  shift;
        input        signed_cfg;
        input        sat_cfg;
        input        round_cfg;
        reg signed [31:0] sa;
        reg signed [31:0] sb;
        reg signed [63:0] sp;
        reg [63:0] up;
        reg signed [63:0] value;
        begin
            sa = signed_cfg ? {{16{a[15]}}, a} : {16'd0, a};
            sb = signed_cfg ? {{16{b[15]}}, b} : {16'd0, b};
            value = 64'sd0;
            case (op)
                OP_VADD: value = sa + sb;
                OP_VSUB: value = sa - sb;
                OP_VMUL: begin
                    if (signed_cfg) begin
                        sp = sa * sb;
                        value = $signed(round_shift_s(sp, shift, round_cfg));
                    end else begin
                        up = {48'd0, a} * {48'd0, b};
                        value = {32'd0, round_shift_u(up, shift, round_cfg)};
                    end
                end
                default: value = 64'sd0;
            endcase
            calc_lane16 = sat16(value, signed_cfg, sat_cfg);
        end
    endfunction

    function [7:0] calc_lane8;
        input [2:0]  op;
        input [7:0]  a;
        input [7:0]  b;
        input [4:0]  shift;
        input        signed_cfg;
        input        sat_cfg;
        input        round_cfg;
        reg signed [31:0] sa;
        reg signed [31:0] sb;
        reg signed [63:0] sp;
        reg [63:0] up;
        reg signed [63:0] value;
        begin
            sa = signed_cfg ? {{24{a[7]}}, a} : {24'd0, a};
            sb = signed_cfg ? {{24{b[7]}}, b} : {24'd0, b};
            value = 64'sd0;
            case (op)
                OP_VADD: value = sa + sb;
                OP_VSUB: value = sa - sb;
                OP_VMUL: begin
                    if (signed_cfg) begin
                        sp = sa * sb;
                        value = $signed(round_shift_s(sp, shift, round_cfg));
                    end else begin
                        up = {56'd0, a} * {56'd0, b};
                        value = {32'd0, round_shift_u(up, shift, round_cfg)};
                    end
                end
                default: value = 64'sd0;
            endcase
            calc_lane8 = sat8(value, signed_cfg, sat_cfg);
        end
    endfunction

    function [31:0] calc_element_result;
        input [2:0]  op;
        input [31:0] a;
        input [31:0] b;
        input [4:0]  shift;
        input [1:0]  width_cfg;
        input        signed_cfg;
        input        sat_cfg;
        input        round_cfg;
        begin
            case (width_cfg)
                DW_HALF: begin
                    calc_element_result = {
                        calc_lane16(op, a[31:16], b[31:16], shift, signed_cfg, sat_cfg, round_cfg),
                        calc_lane16(op, a[15:0],  b[15:0],  shift, signed_cfg, sat_cfg, round_cfg)
                    };
                end
                DW_BYTE: begin
                    calc_element_result = {
                        calc_lane8(op, a[31:24], b[31:24], shift, signed_cfg, sat_cfg, round_cfg),
                        calc_lane8(op, a[23:16], b[23:16], shift, signed_cfg, sat_cfg, round_cfg),
                        calc_lane8(op, a[15:8],  b[15:8],  shift, signed_cfg, sat_cfg, round_cfg),
                        calc_lane8(op, a[7:0],   b[7:0],   shift, signed_cfg, sat_cfg, round_cfg)
                    };
                end
                default: begin
                    calc_element_result = calc_word_result(op, a, b, shift, signed_cfg, sat_cfg, round_cfg);
                end
            endcase
        end
    endfunction

    function [31:0] abs_word;
        input [31:0] a;
        input [31:0] b;
        input        signed_cfg;
        reg signed [32:0] sa;
        reg signed [32:0] sb;
        begin
            if (signed_cfg) begin
                sa = $signed(a);
                sb = $signed(b);
                abs_word = (sa >= sb) ? (sa - sb) : (sb - sa);
            end else begin
                abs_word = (a >= b) ? (a - b) : (b - a);
            end
        end
    endfunction

    function [31:0] acc_term_calc;
        input [2:0]  op;
        input [31:0] a;
        input [31:0] b;
        input [4:0]  shift;
        input [1:0]  width_cfg;
        input        signed_cfg;
        input        round_cfg;
        reg [31:0] term0;
        reg [31:0] term1;
        reg [31:0] term2;
        reg [31:0] term3;
        begin
            term0 = 32'd0;
            term1 = 32'd0;
            term2 = 32'd0;
            term3 = 32'd0;

            if (op == OP_VMAC) begin
                case (width_cfg)
                    DW_HALF: begin
                        term0 = ext16_to_32(calc_lane16(OP_VMUL, a[15:0],  b[15:0],
                                                        shift, signed_cfg, 1'b0, round_cfg),
                                             signed_cfg);
                        term1 = ext16_to_32(calc_lane16(OP_VMUL, a[31:16], b[31:16],
                                                        shift, signed_cfg, 1'b0, round_cfg),
                                             signed_cfg);
                        acc_term_calc = term0 + term1;
                    end
                    DW_BYTE: begin
                        term0 = ext8_to_32(calc_lane8(OP_VMUL, a[7:0],   b[7:0],
                                                      shift, signed_cfg, 1'b0, round_cfg),
                                            signed_cfg);
                        term1 = ext8_to_32(calc_lane8(OP_VMUL, a[15:8],  b[15:8],
                                                      shift, signed_cfg, 1'b0, round_cfg),
                                            signed_cfg);
                        term2 = ext8_to_32(calc_lane8(OP_VMUL, a[23:16], b[23:16],
                                                      shift, signed_cfg, 1'b0, round_cfg),
                                            signed_cfg);
                        term3 = ext8_to_32(calc_lane8(OP_VMUL, a[31:24], b[31:24],
                                                      shift, signed_cfg, 1'b0, round_cfg),
                                            signed_cfg);
                        acc_term_calc = term0 + term1 + term2 + term3;
                    end
                    default: begin
                        acc_term_calc = calc_word_result(OP_VMUL, a, b, shift, signed_cfg, 1'b0, round_cfg);
                    end
                endcase
            end else begin
                case (width_cfg)
                    DW_HALF: begin
                        term0 = abs_word(ext16_to_32(a[15:0], signed_cfg),
                                         ext16_to_32(b[15:0], signed_cfg),
                                         signed_cfg);
                        term1 = abs_word(ext16_to_32(a[31:16], signed_cfg),
                                         ext16_to_32(b[31:16], signed_cfg),
                                         signed_cfg);
                        acc_term_calc = term0 + term1;
                    end
                    DW_BYTE: begin
                        term0 = abs_word(ext8_to_32(a[7:0], signed_cfg),
                                         ext8_to_32(b[7:0], signed_cfg),
                                         signed_cfg);
                        term1 = abs_word(ext8_to_32(a[15:8], signed_cfg),
                                         ext8_to_32(b[15:8], signed_cfg),
                                         signed_cfg);
                        term2 = abs_word(ext8_to_32(a[23:16], signed_cfg),
                                         ext8_to_32(b[23:16], signed_cfg),
                                         signed_cfg);
                        term3 = abs_word(ext8_to_32(a[31:24], signed_cfg),
                                         ext8_to_32(b[31:24], signed_cfg),
                                         signed_cfg);
                        acc_term_calc = term0 + term1 + term2 + term3;
                    end
                    default: begin
                        acc_term_calc = abs_word(a, b, signed_cfg);
                    end
                endcase
            end
        end
    endfunction

    function [31:0] acc_add;
        input [31:0] acc;
        input [31:0] term;
        input        signed_cfg;
        input        sat_cfg;
        reg signed [64:0] s_value;
        begin
            if (signed_cfg)
                s_value = $signed(acc) + $signed(term);
            else
                s_value = {33'd0, acc} + {33'd0, term};
            acc_add = sat32(s_value, signed_cfg, sat_cfg);
        end
    endfunction

    function [31:0] sat32_update;
        input signed [64:0] value;
        input               signed_cfg;
        input               sat_cfg;
        begin
            if (!sat_cfg) begin
                sat32_update = value[31:0];
            end else if (signed_cfg) begin
                sat32_update = sat32(value, 1'b1, 1'b1);
            end else if (value < 65'sd0) begin
                sat32_update = 32'd0;
            end else if (value > 65'sd4294967295) begin
                sat32_update = 32'hffff_ffff;
            end else begin
                sat32_update = value[31:0];
            end
        end
    endfunction

    function [15:0] sat16_update;
        input signed [63:0] value;
        input               signed_cfg;
        input               sat_cfg;
        begin
            if (!sat_cfg) begin
                sat16_update = value[15:0];
            end else if (signed_cfg) begin
                sat16_update = sat16(value, 1'b1, 1'b1);
            end else if (value < 64'sd0) begin
                sat16_update = 16'd0;
            end else if (value > 64'sd65535) begin
                sat16_update = 16'hffff;
            end else begin
                sat16_update = value[15:0];
            end
        end
    endfunction

    function [7:0] sat8_update;
        input signed [63:0] value;
        input               signed_cfg;
        input               sat_cfg;
        begin
            if (!sat_cfg) begin
                sat8_update = value[7:0];
            end else if (signed_cfg) begin
                sat8_update = sat8(value, 1'b1, 1'b1);
            end else if (value < 64'sd0) begin
                sat8_update = 8'd0;
            end else if (value > 64'sd255) begin
                sat8_update = 8'hff;
            end else begin
                sat8_update = value[7:0];
            end
        end
    endfunction

    function [31:0] som_update_word;
        input [31:0] x;
        input [31:0] w;
        input [4:0]  alpha;
        input        signed_cfg;
        input        sat_cfg;
        reg signed [64:0] sx;
        reg signed [64:0] sw;
        reg signed [64:0] delta;
        reg signed [64:0] next_value;
        begin
            sx = signed_cfg ? {{33{x[31]}}, x} : {33'd0, x};
            sw = signed_cfg ? {{33{w[31]}}, w} : {33'd0, w};
            delta = sx - sw;
            next_value = sw + (delta >>> alpha);
            som_update_word = sat32_update(next_value, signed_cfg, sat_cfg);
        end
    endfunction

    function [15:0] som_update_lane16;
        input [15:0] x;
        input [15:0] w;
        input [4:0]  alpha;
        input        signed_cfg;
        input        sat_cfg;
        reg signed [63:0] sx;
        reg signed [63:0] sw;
        reg signed [63:0] delta;
        reg signed [63:0] next_value;
        begin
            sx = signed_cfg ? {{48{x[15]}}, x} : {48'd0, x};
            sw = signed_cfg ? {{48{w[15]}}, w} : {48'd0, w};
            delta = sx - sw;
            next_value = sw + (delta >>> alpha);
            som_update_lane16 = sat16_update(next_value, signed_cfg, sat_cfg);
        end
    endfunction

    function [7:0] som_update_lane8;
        input [7:0] x;
        input [7:0] w;
        input [4:0] alpha;
        input       signed_cfg;
        input       sat_cfg;
        reg signed [63:0] sx;
        reg signed [63:0] sw;
        reg signed [63:0] delta;
        reg signed [63:0] next_value;
        begin
            sx = signed_cfg ? {{56{x[7]}}, x} : {56'd0, x};
            sw = signed_cfg ? {{56{w[7]}}, w} : {56'd0, w};
            delta = sx - sw;
            next_value = sw + (delta >>> alpha);
            som_update_lane8 = sat8_update(next_value, signed_cfg, sat_cfg);
        end
    endfunction

    function [31:0] som_update_calc;
        input [31:0] x;
        input [31:0] w;
        input [4:0]  alpha;
        input [1:0]  width_cfg;
        input        signed_cfg;
        input        sat_cfg;
        begin
            case (width_cfg)
                DW_HALF: begin
                    som_update_calc = {
                        som_update_lane16(x[31:16], w[31:16], alpha, signed_cfg, sat_cfg),
                        som_update_lane16(x[15:0],  w[15:0],  alpha, signed_cfg, sat_cfg)
                    };
                end
                DW_BYTE: begin
                    som_update_calc = {
                        som_update_lane8(x[31:24], w[31:24], alpha, signed_cfg, sat_cfg),
                        som_update_lane8(x[23:16], w[23:16], alpha, signed_cfg, sat_cfg),
                        som_update_lane8(x[15:8],  w[15:8],  alpha, signed_cfg, sat_cfg),
                        som_update_lane8(x[7:0],   w[7:0],   alpha, signed_cfg, sat_cfg)
                    };
                end
                default: begin
                    som_update_calc = som_update_word(x, w, alpha, signed_cfg, sat_cfg);
                end
            endcase
        end
    endfunction

    assign wait_done = (wait_cnt_r == 8'd0);
    assign last_element = (index_r == (length_r - 16'd1));
    assign last_neuron = (neuron_loop_r == (neuron_count_r - 16'd1));
    assign som_recall_op = (op_r == OP_SOM_RECALL);
    assign som_update_op = (op_r == OP_SOM_UPDATE);
    assign som_op = som_recall_op || som_update_op;
    assign write_each_element = (op_r == OP_VADD) || (op_r == OP_VSUB) ||
                                (op_r == OP_VMUL) || som_update_op;

    assign src0_elem_offset = {48'd0, index_r} * {32'd0, src0_stride_r};
    assign src1_elem_offset = {48'd0, index_r} * {32'd0, src1_stride_r};
    assign dst_elem_offset  = {48'd0, index_r} * {32'd0, dst_stride_r};
    assign src1_neuron_offset = {48'd0, (som_recall_op ? neuron_loop_r :
                                         (som_update_op ? neuron_index_r : 16'd0))} *
                                {32'd0, neuron_stride_r};
    assign src0_addr = src0_base_r + src0_elem_offset[31:0];
    assign src1_addr = src1_base_r + src1_neuron_offset[31:0] + src1_elem_offset[31:0];
    assign dst_addr  = dst_base_r  + dst_elem_offset[31:0];

    assign elem_result = calc_element_result(op_r, src0_data_r, src1_data_r, scale_shift_r,
                                             data_width_r, signed_mode_r, saturate_en_r, round_en_r);
    assign som_update_result = som_update_calc(src0_data_r, src1_data_r, scale_shift_r,
                                               data_width_r, signed_mode_r, saturate_en_r);
    assign acc_term = acc_term_calc(op_r, src0_data_r, src1_data_r, scale_shift_r,
                                    data_width_r, signed_mode_r, round_en_r);
    assign acc_next = acc_add(acc_r, acc_term, signed_mode_r, saturate_en_r);
    assign recall_distance_next = acc_add(current_distance_r, acc_term, signed_mode_r, saturate_en_r);
    assign recall_best_update = (neuron_loop_r == 16'd0) ||
                                (recall_distance_next < best_distance_r);
    assign recall_best_next = recall_best_update ? recall_distance_next : best_distance_r;
    assign recall_winner_next = recall_best_update ? neuron_loop_r : winner_index_r;
    assign processed_elements_ext = length_r * neuron_count_r;

    assign start_src0_last_offset = {48'd0, (length - 16'd1)} * {32'd0, src0_stride};
    assign start_src1_last_offset = {48'd0, (length - 16'd1)} * {32'd0, src1_stride};
    assign start_dst_last_offset  = {48'd0, (length - 16'd1)} * {32'd0, dst_stride};
    assign start_src1_neuron_offset = {48'd0, ((op_mode == OP_SOM_RECALL) ? (neuron_count - 16'd1) :
                                               ((op_mode == OP_SOM_UPDATE) ? neuron_index : 16'd0))} *
                                      {32'd0, neuron_stride};

    assign start_src0_last_addr_ext = {33'd0, src0_base} + {1'b0, start_src0_last_offset};
    assign start_src1_last_addr_ext = {33'd0, src1_base} +
                                      {1'b0, start_src1_neuron_offset} +
                                      {1'b0, start_src1_last_offset};
    assign start_dst_last_addr_ext  = {33'd0, dst_base} +
                                      (((op_mode == OP_VADD) || (op_mode == OP_VSUB) || (op_mode == OP_VMUL)) ?
                                       {1'b0, start_dst_last_offset} : 65'd0);

    assign length_valid = (length != 16'd0);
    assign op_valid = (op_mode <= OP_SOM_UPDATE);
    assign data_width_valid = (data_width <= DW_BYTE);
    assign stride_valid = (src0_stride != 32'd0) &&
                          (src1_stride != 32'd0) &&
                          (dst_stride  != 32'd0) &&
                          (((op_mode == OP_SOM_RECALL) || (op_mode == OP_SOM_UPDATE)) ?
                           (neuron_stride != 32'd0) : 1'b1);
    assign neuron_valid = ((op_mode == OP_SOM_RECALL) ? (neuron_count != 16'd0) :
                          ((op_mode == OP_SOM_UPDATE) ? ((neuron_count != 16'd0) &&
                                                         (neuron_index < neuron_count)) : 1'b1));
    assign neuron_stride_valid = (((op_mode == OP_SOM_RECALL) || (op_mode == OP_SOM_UPDATE)) ?
                                  (neuron_stride[1:0] == 2'b00) : 1'b1);
    assign addr_aligned = (src0_base[1:0] == 2'b00) &&
                          (src1_base[1:0] == 2'b00) &&
                          (dst_base[1:0]  == 2'b00) &&
                          (src0_stride[1:0] == 2'b00) &&
                          (src1_stride[1:0] == 2'b00) &&
                          (dst_stride[1:0]  == 2'b00) &&
                          neuron_stride_valid;
    assign addr_in_range = length_valid &&
                           (src0_base <= COMPUTE_ADDR_MAX) &&
                           (src1_base <= COMPUTE_ADDR_MAX) &&
                           (dst_base  <= COMPUTE_ADDR_MAX) &&
                           (start_src0_last_addr_ext <= {33'd0, COMPUTE_ADDR_MAX}) &&
                           (start_src1_last_addr_ext <= {33'd0, COMPUTE_ADDR_MAX}) &&
                           (start_dst_last_addr_ext  <= {33'd0, COMPUTE_ADDR_MAX});

    always @(*) begin
        start_error_code = ERR_NONE;
        if (!length_valid)
            start_error_code = ERR_LENGTH;
        else if (!op_valid)
            start_error_code = ERR_OP;
        else if (!data_width_valid)
            start_error_code = ERR_CONFIG;
        else if (!neuron_valid)
            start_error_code = ERR_NEURON;
        else if (!stride_valid)
            start_error_code = ERR_STRIDE;
        else if (!addr_aligned)
            start_error_code = ERR_ALIGN;
        else if (!addr_in_range)
            start_error_code = ERR_RANGE;
    end

    always @(*) begin
        sram_req   = 1'b0;
        sram_w_en  = 1'b1;
        sram_addr  = 32'd0;
        sram_wdata = 32'd0;

        case (state_r)
            ST_READ0, ST_READ0_WAIT: begin
                sram_req  = 1'b1;
                sram_w_en = 1'b1;
                sram_addr = src0_addr;
            end
            ST_READ1, ST_READ1_WAIT: begin
                sram_req  = 1'b1;
                sram_w_en = 1'b1;
                sram_addr = src1_addr;
            end
            ST_WRITE, ST_WRITE_WAIT: begin
                sram_req   = 1'b1;
                sram_w_en  = 1'b0;
                sram_addr  = som_update_op ? src1_addr :
                             (write_each_element ? dst_addr : dst_base_r);
                sram_wdata = calc_data_r;
            end
            default: begin
            end
        endcase
    end

    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            state_r        <= ST_IDLE;
            wait_cnt_r     <= 8'd0;
            index_r        <= 16'd0;
            src0_data_r    <= 32'd0;
            src1_data_r    <= 32'd0;
            calc_data_r    <= 32'd0;
            acc_r          <= 32'd0;
            op_r           <= OP_VADD;
            src0_base_r    <= 32'd0;
            src1_base_r    <= 32'd0;
            dst_base_r     <= 32'd0;
            length_r       <= 16'd0;
            scale_shift_r  <= 5'd0;
            src0_stride_r  <= 32'd4;
            src1_stride_r  <= 32'd4;
            dst_stride_r   <= 32'd4;
            signed_mode_r  <= 1'b0;
            saturate_en_r  <= 1'b0;
            round_en_r     <= 1'b0;
            data_width_r   <= DW_WORD;
            neuron_count_r <= 16'd1;
            neuron_stride_r <= 32'd4;
            neuron_index_r <= 16'd0;
            neuron_loop_r  <= 16'd0;
            current_distance_r <= 32'd0;
            best_distance_r <= 32'hffff_ffff;
            winner_index_r <= 16'd0;
            busy           <= 1'b0;
            done           <= 1'b0;
            error          <= 1'b0;
            result         <= 32'd0;
            error_code     <= ERR_NONE;
            cycle_count    <= 32'd0;
            element_count  <= 16'd0;
            som_best_distance <= 32'd0;
            som_winner_index  <= 16'd0;
        end else if (soft_reset) begin
            state_r       <= ST_IDLE;
            wait_cnt_r    <= 8'd0;
            index_r       <= 16'd0;
            acc_r         <= 32'd0;
            neuron_loop_r  <= 16'd0;
            current_distance_r <= 32'd0;
            best_distance_r <= 32'hffff_ffff;
            winner_index_r <= 16'd0;
            busy          <= 1'b0;
            done          <= 1'b0;
            error         <= 1'b0;
            result        <= 32'd0;
            error_code    <= ERR_NONE;
            cycle_count   <= 32'd0;
            element_count <= 16'd0;
            som_best_distance <= 32'd0;
            som_winner_index  <= 16'd0;
        end else begin
            done <= 1'b0;

            if (busy)
                cycle_count <= cycle_count + 32'd1;

            case (state_r)
                ST_IDLE: begin
                    busy  <= 1'b0;
                    error <= 1'b0;

                    if (start) begin
                        busy           <= 1'b1;
                        op_r           <= op_mode;
                        src0_base_r    <= src0_base;
                        src1_base_r    <= src1_base;
                        dst_base_r     <= dst_base;
                        length_r       <= length;
                        scale_shift_r  <= scale_shift;
                        src0_stride_r  <= src0_stride;
                        src1_stride_r  <= src1_stride;
                        dst_stride_r   <= dst_stride;
                        signed_mode_r  <= signed_mode;
                        saturate_en_r  <= saturate_en;
                        round_en_r     <= round_en;
                        data_width_r   <= data_width;
                        neuron_count_r <= neuron_count;
                        neuron_stride_r <= neuron_stride;
                        neuron_index_r <= neuron_index;
                        neuron_loop_r  <= 16'd0;
                        index_r        <= 16'd0;
                        acc_r          <= 32'd0;
                        current_distance_r <= 32'd0;
                        best_distance_r <= 32'hffff_ffff;
                        winner_index_r <= 16'd0;
                        cycle_count    <= 32'd0;
                        element_count  <= 16'd0;
                        som_best_distance <= 32'd0;
                        som_winner_index  <= 16'd0;
                        error_code     <= start_error_code;

                        if (start_error_code != ERR_NONE) begin
                            state_r <= ST_ERROR;
                        end else begin
                            wait_cnt_r <= SRAM_WAIT_CYCLES[7:0];
                            state_r    <= ST_READ0;
                        end
                    end
                end

                ST_READ0: begin
                    state_r <= ST_READ0_WAIT;
                end

                ST_READ0_WAIT: begin
                    if (!wait_done) begin
                        wait_cnt_r <= wait_cnt_r - 8'd1;
                    end else begin
                        src0_data_r <= sram_rdata;
                        wait_cnt_r  <= SRAM_WAIT_CYCLES[7:0];
                        state_r     <= ST_READ1;
                    end
                end

                ST_READ1: begin
                    state_r <= ST_READ1_WAIT;
                end

                ST_READ1_WAIT: begin
                    if (!wait_done) begin
                        wait_cnt_r <= wait_cnt_r - 8'd1;
                    end else begin
                        src1_data_r <= sram_rdata;
                        state_r     <= ST_CALC;
                    end
                end

                ST_CALC: begin
                    case (op_r)
                        OP_VADD, OP_VSUB, OP_VMUL: begin
                            calc_data_r <= elem_result;
                            state_r     <= ST_WRITE;
                        end
                        OP_SOM_UPDATE: begin
                            calc_data_r <= som_update_result;
                            state_r     <= ST_WRITE;
                        end
                        OP_SOM_RECALL: begin
                            current_distance_r <= recall_distance_next;
                            if (last_element) begin
                                best_distance_r <= recall_best_next;
                                winner_index_r  <= recall_winner_next;
                                if (last_neuron) begin
                                    result            <= {16'd0, recall_winner_next};
                                    som_best_distance <= recall_best_next;
                                    som_winner_index  <= recall_winner_next;
                                    element_count     <= processed_elements_ext[15:0];
                                    error_code        <= ERR_NONE;
                                    state_r           <= ST_DONE;
                                end else begin
                                    neuron_loop_r      <= neuron_loop_r + 16'd1;
                                    index_r            <= 16'd0;
                                    current_distance_r <= 32'd0;
                                    wait_cnt_r         <= SRAM_WAIT_CYCLES[7:0];
                                    state_r            <= ST_READ0;
                                end
                            end else begin
                                index_r    <= index_r + 16'd1;
                                wait_cnt_r <= SRAM_WAIT_CYCLES[7:0];
                                state_r    <= ST_READ0;
                            end
                        end
                        OP_VMAC, OP_L1DIST: begin
                            acc_r <= acc_next;
                            if (last_element) begin
                                calc_data_r <= acc_next;
                                state_r     <= ST_WRITE;
                            end else begin
                                index_r    <= index_r + 16'd1;
                                wait_cnt_r <= SRAM_WAIT_CYCLES[7:0];
                                state_r    <= ST_READ0;
                            end
                        end
                        default: begin
                            error_code <= ERR_OP;
                            state_r    <= ST_ERROR;
                        end
                    endcase
                end

                ST_WRITE: begin
                    wait_cnt_r <= SRAM_WAIT_CYCLES[7:0];
                    state_r    <= ST_WRITE_WAIT;
                end

                ST_WRITE_WAIT: begin
                    if (!wait_done) begin
                        wait_cnt_r <= wait_cnt_r - 8'd1;
                    end else if (write_each_element && !last_element) begin
                        index_r    <= index_r + 16'd1;
                        wait_cnt_r <= SRAM_WAIT_CYCLES[7:0];
                        state_r    <= ST_READ0;
                    end else begin
                        result        <= som_update_op ? {16'd0, neuron_index_r} : calc_data_r;
                        element_count <= length_r;
                        error_code    <= ERR_NONE;
                        if (som_update_op) begin
                            som_best_distance <= 32'd0;
                            som_winner_index  <= neuron_index_r;
                        end
                        state_r       <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    state_r <= ST_IDLE;
                end

                ST_ERROR: begin
                    busy          <= 1'b0;
                    error         <= 1'b1;
                    done          <= 1'b1;
                    result        <= 32'd0;
                    element_count <= 16'd0;
                    state_r       <= ST_IDLE;
                end

                default: begin
                    error_code <= ERR_NONE;
                    state_r    <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
