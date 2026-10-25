`timescale 1ns / 1ps

// Matrix command controller using a parameterized output-stationary INT8 array.
// The external descriptor and the legacy 4x4 tile-major SPAD layout are
// unchanged. A 16x16 array gathers four 4x4 row/column groups per K-word
// slice, accumulates one 16x16 macro-tile, then writes four results per line.
module ai_tensor_matrix_core #(
    parameter integer ARRAY_SIZE = 16
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        abort,
    input  wire [7:0]  op_mode,
    input  wire [31:0] src0_base,
    input  wire [31:0] src1_base,
    input  wire [31:0] bias_base,
    input  wire [31:0] dst_base,
    input  wire [15:0] m_size,
    input  wire [15:0] n_size,
    input  wire [15:0] k_words,
    input  wire [31:0] instance_count,
    input  wire [31:0] src0_batch_stride,
    input  wire [31:0] src1_batch_stride,
    input  wire [31:0] dst_batch_stride,
    input  wire        transpose_a,
    input  wire        transpose_b,
    input  wire        bias_enable,
    input  wire [4:0]  scale_shift,
    input  wire [1:0]  activation,
    input  wire [31:0] watchdog_limit,

    input  wire [31:0] bank0_data,
    input  wire [31:0] bank1_data,
    input  wire [31:0] bank2_data,
    input  wire [31:0] bank3_data,
    input  wire [3:0]  bank_parity_error,
    output reg         banked_read_valid,
    output reg  [31:0] banked_addr,
    input  wire        banked_ready,
    input  wire        banked_rsp_valid,
    input  wire        banked_protection_error,

    output reg         spad_valid,
    output reg         spad_write,
    output reg  [31:0] spad_addr,
    output reg  [31:0] spad_wdata,
    input  wire        spad_ready,
    input  wire        spad_rsp_valid,
    input  wire [31:0] spad_rdata,
    input  wire        spad_parity_error,
    input  wire        spad_protection_error,
    output reg         line_valid,
    output wire        line_write,
    output reg  [31:0] line_addr,
    output reg  [127:0] line_wdata,
    output wire [15:0] line_wstrb,
    input  wire        line_ready,
    input  wire        line_protection_error,

    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [31:0] result,
    output reg  [31:0] cycle_count,
    output reg  [31:0] element_count,
    output wire        perf_mac_active,
    output wire        perf_banked_wait
);
    localparam integer ARRAY_GROUPS = ARRAY_SIZE / 4;
    localparam integer TILE_INDEX_WIDTH =
        (ARRAY_SIZE <= 2) ? 1 : $clog2(ARRAY_SIZE);
    localparam integer ARRAY_INDEX_WIDTH =
        (ARRAY_SIZE * ARRAY_SIZE <= 2) ? 1 : $clog2(ARRAY_SIZE * ARRAY_SIZE);

    localparam [7:0] OP_TENSOR_GEMM       = 8'h30;
    localparam [7:0] OP_TENSOR_BATCH_GEMM = 8'h31;

    localparam [3:0] ERR_CONFIG     = 4'd1;
    localparam [3:0] ERR_OP         = 4'd2;
    localparam [3:0] ERR_ABORT      = 4'd3;
    localparam [3:0] ERR_WATCHDOG   = 4'd4;
    localparam [3:0] ERR_PARITY     = 4'd5;
    localparam [3:0] ERR_PROTECTION = 4'd6;

    localparam [3:0] ST_IDLE      = 4'd0;
    localparam [3:0] ST_A_REQ     = 4'd1;
    localparam [3:0] ST_A_WAIT    = 4'd2;
    localparam [3:0] ST_B_REQ     = 4'd3;
    localparam [3:0] ST_B_WAIT    = 4'd4;
    localparam [3:0] ST_BIAS_REQ  = 4'd5;
    localparam [3:0] ST_BIAS_WAIT = 4'd6;
    localparam [3:0] ST_PREP_MAC  = 4'd7;
    localparam [3:0] ST_MAC       = 4'd8;
    localparam [3:0] ST_WRITE     = 4'd9;
    localparam [3:0] ST_NEXT      = 4'd10;
    localparam [3:0] ST_DONE      = 4'd11;
    localparam [3:0] ST_ERROR     = 4'd12;

    reg [3:0] state_r;
    reg [15:0] m_r, n_r, k_words_r;
    reg [31:0] instance_count_r, instance_r;
    reg [15:0] row_tile_r, col_tile_r, k_group_r;
    reg [1:0] lane_r;
    reg [2:0] read_group_r;
    reg [TILE_INDEX_WIDTH-1:0] write_row_r, write_col_r;
    reg [1:0] write_lane_r;
    reg [TILE_INDEX_WIDTH:0] bias_index_r;
    reg transpose_a_r, transpose_b_r, bias_enable_r, bias_loaded_r;
    reg [4:0] scale_shift_r;
    reg [1:0] activation_r;
    reg [31:0] watchdog_limit_r;

    reg [31:0] a_batch_base_r, b_batch_base_r, dst_batch_base_r;
    reg [31:0] bias_batch_base_r;
    reg [31:0] a_tile_base_r, b_tile_base_r;
    reg [31:0] dst_row_tile_base_r, dst_tile_base_r, dst_row_addr_r;
    reg [31:0] bias_tile_base_r;
    reg [31:0] src0_batch_stride_r, src1_batch_stride_r, dst_batch_stride_r;
    reg [31:0] dst_row_stride_r;

    reg [31:0] a_tile_words_r [0:ARRAY_SIZE-1];
    reg [31:0] b_tile_words_r [0:ARRAY_SIZE-1];
    reg signed [31:0] bias_words_r [0:ARRAY_SIZE-1];

    wire [ARRAY_SIZE*ARRAY_SIZE*64-1:0] array_accumulator_vector;
    wire signed [63:0] array_selected_accumulator;
    wire [31:0] array_selected_result;
    wire array_selected_overflow;
    reg [ARRAY_SIZE*8-1:0] array_load_a, array_load_b;
    reg [1:0] array_load_lane;
    wire array_buffer_write_valid;
    wire array_buffer_write_bank;
    wire array_mac_enable;
    wire array_clear_accumulators;

    integer vector_i;
    integer reset_i;

    wire [31:0] row_tile_origin =
        {16'd0,row_tile_r} * ARRAY_SIZE;
    wire [31:0] col_tile_origin =
        {16'd0,col_tile_r} * ARRAY_SIZE;
    wire [31:0] rows_remaining = {16'd0,m_r} - row_tile_origin;
    wire [31:0] cols_remaining = {16'd0,n_r} - col_tile_origin;
    wire [31:0] valid_rows =
        rows_remaining > ARRAY_SIZE ? ARRAY_SIZE : rows_remaining;
    wire [31:0] valid_cols =
        cols_remaining > ARRAY_SIZE ? ARRAY_SIZE : cols_remaining;
    wire [31:0] a_group_count = valid_rows >> 2;
    wire [31:0] b_group_count = valid_cols >> 2;
    wire [31:0] m_tile_count =
        ({16'd0,m_r} + ARRAY_SIZE - 1) / ARRAY_SIZE;
    wire [31:0] n_tile_count =
        ({16'd0,n_r} + ARRAY_SIZE - 1) / ARRAY_SIZE;

    wire [31:0] matrix_tile_span_bytes =
        {16'd0,k_words_r} * ARRAY_GROUPS * 32'd16;
    wire [31:0] banked_word_offset =
        (({29'd0,read_group_r} * {16'd0,k_words_r}) +
          {16'd0,k_group_r}) << 4;
    wire [31:0] a_read_addr = a_tile_base_r + banked_word_offset;
    wire [31:0] b_read_addr = b_tile_base_r + banked_word_offset;
    wire [31:0] bias_read_addr =
        bias_tile_base_r + ({{(32-TILE_INDEX_WIDTH-1){1'b0}},bias_index_r} << 2);

    wire [31:0] line_byte_offset =
        {{(32-TILE_INDEX_WIDTH){1'b0}},write_col_r} << 2;
    wire [31:0] scalar_word_index =
        {{(32-TILE_INDEX_WIDTH-2){1'b0}},write_col_r,write_lane_r};
    wire [31:0] write_row_addr = dst_row_addr_r + line_byte_offset;
    wire line_store_eligible = (write_row_addr[3:0] == 4'd0);
    wire valid_operation = (op_mode == OP_TENSOR_GEMM) ||
                           (op_mode == OP_TENSOR_BATCH_GEMM);
    wire invalid_dimensions = (m_size == 0) || (n_size == 0) ||
                              (k_words == 0) || |m_size[1:0] ||
                              |n_size[1:0] || (ARRAY_SIZE < 4) ||
                              ((ARRAY_SIZE % 4) != 0);
    wire invalid_alignment = |src0_base[3:0] || |src1_base[3:0] ||
                             |dst_base[1:0] || (bias_enable && |bias_base[1:0]);
    wire last_k_group = (k_group_r == k_words_r - 1'b1);
    wire bank_response_has_parity_error = |bank_parity_error;
    wire watchdog_expired = busy && (watchdog_limit_r != 0) &&
                            (cycle_count >= watchdog_limit_r);
    wire output_write_accepted = (line_store_eligible && line_ready) ||
                                 (!line_store_eligible && spad_ready);
    wire output_write_has_protection_error =
        (line_store_eligible && line_protection_error) ||
        (!line_store_eligible && spad_protection_error);

    wire [31:0] write_index0 =
        ({{(32-TILE_INDEX_WIDTH){1'b0}},write_row_r} * ARRAY_SIZE) +
        {{(32-TILE_INDEX_WIDTH){1'b0}},write_col_r};
    wire [31:0] write_index1 = write_index0 + 32'd1;
    wire [31:0] write_index2 = write_index0 + 32'd2;
    wire [31:0] write_index3 = write_index0 + 32'd3;
    wire signed [63:0] write_acc0 =
        array_accumulator_vector[write_index0*64 +: 64];
    wire signed [63:0] write_acc1 =
        array_accumulator_vector[write_index1*64 +: 64];
    wire signed [63:0] write_acc2 =
        array_accumulator_vector[write_index2*64 +: 64];
    wire signed [63:0] write_acc3 =
        array_accumulator_vector[write_index3*64 +: 64];
    wire signed [31:0] write_bias0 =
        bias_enable_r ? bias_words_r[write_col_r] : 32'sd0;
    wire signed [31:0] write_bias1 =
        bias_enable_r ? bias_words_r[write_col_r+1'b1] : 32'sd0;
    wire signed [31:0] write_bias2 =
        bias_enable_r ? bias_words_r[write_col_r+2'd2] : 32'sd0;
    wire signed [31:0] write_bias3 =
        bias_enable_r ? bias_words_r[write_col_r+2'd3] : 32'sd0;
    wire [31:0] write_result0 =
        post_process_matrix(write_acc0,write_bias0,scale_shift_r,activation_r);
    wire [31:0] write_result1 =
        post_process_matrix(write_acc1,write_bias1,scale_shift_r,activation_r);
    wire [31:0] write_result2 =
        post_process_matrix(write_acc2,write_bias2,scale_shift_r,activation_r);
    wire [31:0] write_result3 =
        post_process_matrix(write_acc3,write_bias3,scale_shift_r,activation_r);
    wire [31:0] scalar_write_result =
        (write_lane_r == 2'd0) ? write_result0 :
        (write_lane_r == 2'd1) ? write_result1 :
        (write_lane_r == 2'd2) ? write_result2 : write_result3;

    assign perf_mac_active = (state_r == ST_MAC);
    assign perf_banked_wait = (state_r == ST_A_WAIT) ||
                              (state_r == ST_B_WAIT);
    assign line_write = 1'b1;
    assign line_wstrb = 16'hffff;

    function [7:0] matrix_tile_element;
        input [31:0] w0;
        input [31:0] w1;
        input [31:0] w2;
        input [31:0] w3;
        input [1:0] major;
        input [1:0] k_lane;
        input transpose;
        reg [31:0] selected_word;
        reg [1:0] word_index;
        reg [1:0] byte_index;
        begin
            word_index = transpose ? k_lane : major;
            byte_index = transpose ? major : k_lane;
            case (word_index)
                2'd0: selected_word = w0;
                2'd1: selected_word = w1;
                2'd2: selected_word = w2;
                default: selected_word = w3;
            endcase
            case (byte_index)
                2'd0: matrix_tile_element = selected_word[7:0];
                2'd1: matrix_tile_element = selected_word[15:8];
                2'd2: matrix_tile_element = selected_word[23:16];
                default: matrix_tile_element = selected_word[31:24];
            endcase
        end
    endfunction

    function [31:0] post_process_matrix;
        input signed [63:0] accumulated;
        input signed [31:0] bias_value;
        input [4:0] shift;
        input [1:0] activation_mode;
        reg signed [63:0] biased;
        reg signed [63:0] shifted;
        reg signed [63:0] activated;
        begin
            biased = accumulated + {{32{bias_value[31]}},bias_value};
            shifted = biased >>> shift;
            if (activation_mode == 2'd1)
                activated = shifted < 0 ? 64'sd0 : shifted;
            else if (activation_mode == 2'd2)
                activated = shifted < 0 ? 64'sd0 :
                            (shifted > 64'sd6 ? 64'sd6 : shifted);
            else
                activated = shifted;

            if (activated > 64'sh0000_0000_7fff_ffff)
                post_process_matrix = 32'h7fff_ffff;
            else if (activated < -64'sd2147483648)
                post_process_matrix = 32'h8000_0000;
            else
                post_process_matrix = activated[31:0];
        end
    endfunction

    always @* begin
        banked_read_valid = 1'b0;
        banked_addr = 32'd0;
        if (state_r == ST_A_REQ) begin
            banked_read_valid = 1'b1;
            banked_addr = a_read_addr;
        end else if (state_r == ST_B_REQ) begin
            banked_read_valid = 1'b1;
            banked_addr = b_read_addr;
        end

        spad_valid = (state_r == ST_BIAS_REQ) ||
                     ((state_r == ST_WRITE) && !line_store_eligible);
        spad_write = (state_r == ST_WRITE) && !line_store_eligible;
        spad_addr = (state_r == ST_BIAS_REQ) ? bias_read_addr :
                    (dst_row_addr_r + (scalar_word_index << 2));
        spad_wdata = scalar_write_result;

        line_valid = (state_r == ST_WRITE) && line_store_eligible;
        line_addr = write_row_addr;
        line_wdata = {write_result3,write_result2,write_result1,write_result0};

        if (state_r == ST_PREP_MAC)
            array_load_lane = 2'd0;
        else if ((state_r == ST_MAC) && (lane_r != 2'd3))
            array_load_lane = lane_r + 1'b1;
        else
            array_load_lane = lane_r;

        for (vector_i = 0; vector_i < ARRAY_SIZE; vector_i = vector_i + 1) begin
            array_load_a[vector_i*8 +: 8] = matrix_tile_element(
                a_tile_words_r[(vector_i/4)*4+0],
                a_tile_words_r[(vector_i/4)*4+1],
                a_tile_words_r[(vector_i/4)*4+2],
                a_tile_words_r[(vector_i/4)*4+3],
                vector_i%4,array_load_lane,transpose_a_r);
            array_load_b[vector_i*8 +: 8] = matrix_tile_element(
                b_tile_words_r[(vector_i/4)*4+0],
                b_tile_words_r[(vector_i/4)*4+1],
                b_tile_words_r[(vector_i/4)*4+2],
                b_tile_words_r[(vector_i/4)*4+3],
                vector_i%4,array_load_lane,transpose_b_r);
        end
    end

    assign array_buffer_write_valid = (state_r == ST_PREP_MAC) ||
                                      ((state_r == ST_MAC) &&
                                       (lane_r != 2'd3));
    assign array_buffer_write_bank = (state_r == ST_PREP_MAC) ?
                                     1'b0 : ~lane_r[0];
    assign array_mac_enable = (state_r == ST_MAC) && !abort &&
                              !watchdog_expired;
    assign array_clear_accumulators = ((state_r == ST_IDLE) && start) ||
                                      (state_r == ST_NEXT);

    ai_tensor_matrix_array #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .RESULT_INDEX_WIDTH(ARRAY_INDEX_WIDTH)
    ) mac_array_u (
        .clk(clk),
        .resetn(resetn),
        .clear_accumulators(array_clear_accumulators),
        .buffer_write_valid(array_buffer_write_valid),
        .buffer_write_bank(array_buffer_write_bank),
        .buffer_write_a(array_load_a),
        .buffer_write_b(array_load_b),
        .mac_enable(array_mac_enable),
        .mac_bank(lane_r[0]),
        .result_index(write_index0[ARRAY_INDEX_WIDTH-1:0]),
        .result_bias(32'sd0),
        .result_shift(5'd0),
        .result_activation(2'd0),
        .accumulator_vector(array_accumulator_vector),
        .selected_accumulator(array_selected_accumulator),
        .selected_result(array_selected_result),
        .selected_overflow(array_selected_overflow)
    );

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r <= ST_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            error_code <= 4'd0;
            result <= 32'd0;
            cycle_count <= 32'd0;
            element_count <= 32'd0;
            m_r <= 16'd0;
            n_r <= 16'd0;
            k_words_r <= 16'd0;
            instance_count_r <= 32'd0;
            instance_r <= 32'd0;
            row_tile_r <= 16'd0;
            col_tile_r <= 16'd0;
            k_group_r <= 16'd0;
            lane_r <= 2'd0;
            read_group_r <= 3'd0;
            write_row_r <= {TILE_INDEX_WIDTH{1'b0}};
            write_col_r <= {TILE_INDEX_WIDTH{1'b0}};
            write_lane_r <= 2'd0;
            bias_index_r <= {(TILE_INDEX_WIDTH+1){1'b0}};
            transpose_a_r <= 1'b0;
            transpose_b_r <= 1'b0;
            bias_enable_r <= 1'b0;
            bias_loaded_r <= 1'b0;
            scale_shift_r <= 5'd0;
            activation_r <= 2'd0;
            watchdog_limit_r <= 32'd0;
            a_batch_base_r <= 32'd0;
            b_batch_base_r <= 32'd0;
            dst_batch_base_r <= 32'd0;
            bias_batch_base_r <= 32'd0;
            a_tile_base_r <= 32'd0;
            b_tile_base_r <= 32'd0;
            dst_row_tile_base_r <= 32'd0;
            dst_tile_base_r <= 32'd0;
            dst_row_addr_r <= 32'd0;
            bias_tile_base_r <= 32'd0;
            src0_batch_stride_r <= 32'd0;
            src1_batch_stride_r <= 32'd0;
            dst_batch_stride_r <= 32'd0;
            dst_row_stride_r <= 32'd0;
            for (reset_i = 0; reset_i < ARRAY_SIZE; reset_i = reset_i + 1) begin
                a_tile_words_r[reset_i] <= 32'd0;
                b_tile_words_r[reset_i] <= 32'd0;
                bias_words_r[reset_i] <= 32'sd0;
            end
        end else begin
            done <= 1'b0;
            if ((state_r == ST_IDLE) && start)
                cycle_count <= 32'd0;
            else if (busy)
                cycle_count <= cycle_count + 1'b1;

            if (busy && abort && (state_r != ST_ERROR)) begin
                error_code <= ERR_ABORT;
                state_r <= ST_ERROR;
            end else if (watchdog_expired && (state_r != ST_ERROR)) begin
                error_code <= ERR_WATCHDOG;
                state_r <= ST_ERROR;
            end else begin
                case (state_r)
                    ST_IDLE: begin
                        busy <= 1'b0;
                        error <= 1'b0;
                        error_code <= 4'd0;
                        if (start) begin
                            m_r <= m_size;
                            n_r <= n_size;
                            k_words_r <= k_words;
                            instance_count_r <= (instance_count == 0) ?
                                                32'd1 : instance_count;
                            transpose_a_r <= transpose_a;
                            transpose_b_r <= transpose_b;
                            bias_enable_r <= bias_enable;
                            scale_shift_r <= scale_shift;
                            activation_r <= activation;
                            watchdog_limit_r <= watchdog_limit;
                            a_batch_base_r <= src0_base;
                            b_batch_base_r <= src1_base;
                            dst_batch_base_r <= dst_base;
                            bias_batch_base_r <= bias_base;
                            a_tile_base_r <= src0_base;
                            b_tile_base_r <= src1_base;
                            dst_row_tile_base_r <= dst_base;
                            dst_tile_base_r <= dst_base;
                            dst_row_addr_r <= dst_base;
                            bias_tile_base_r <= bias_base;
                            src0_batch_stride_r <= (src0_batch_stride == 0) ?
                                (({16'd0,m_size} >> 2) * {16'd0,k_words} * 32'd16) :
                                src0_batch_stride;
                            src1_batch_stride_r <= (src1_batch_stride == 0) ?
                                (({16'd0,n_size} >> 2) * {16'd0,k_words} * 32'd16) :
                                src1_batch_stride;
                            dst_batch_stride_r <= (dst_batch_stride == 0) ?
                                ({16'd0,m_size} * {16'd0,n_size} * 32'd4) :
                                dst_batch_stride;
                            dst_row_stride_r <= {14'd0,n_size,2'b00};
                            instance_r <= 32'd0;
                            row_tile_r <= 16'd0;
                            col_tile_r <= 16'd0;
                            k_group_r <= 16'd0;
                            read_group_r <= 3'd0;
                            write_row_r <= {TILE_INDEX_WIDTH{1'b0}};
                            write_col_r <= {TILE_INDEX_WIDTH{1'b0}};
                            write_lane_r <= 2'd0;
                            bias_index_r <= {(TILE_INDEX_WIDTH+1){1'b0}};
                            bias_loaded_r <= 1'b0;
                            element_count <= 32'd0;
                            busy <= 1'b1;
                            if (!valid_operation) begin
                                error_code <= ERR_OP;
                                state_r <= ST_ERROR;
                            end else if (invalid_dimensions || invalid_alignment) begin
                                error_code <= ERR_CONFIG;
                                state_r <= ST_ERROR;
                            end else begin
                                state_r <= ST_A_REQ;
                            end
                        end
                    end

                    ST_A_REQ: begin
                        if (banked_ready) begin
                            if (banked_protection_error) begin
                                error_code <= ERR_PROTECTION;
                                state_r <= ST_ERROR;
                            end else begin
                                state_r <= ST_A_WAIT;
                            end
                        end
                    end

                    ST_A_WAIT: begin
                        if (banked_rsp_valid) begin
                            if (bank_response_has_parity_error) begin
                                error_code <= ERR_PARITY;
                                state_r <= ST_ERROR;
                            end else begin
                                a_tile_words_r[read_group_r*4+0] <= bank0_data;
                                a_tile_words_r[read_group_r*4+1] <= bank1_data;
                                a_tile_words_r[read_group_r*4+2] <= bank2_data;
                                a_tile_words_r[read_group_r*4+3] <= bank3_data;
                                if (({29'd0,read_group_r} + 32'd1) < a_group_count) begin
                                    read_group_r <= read_group_r + 1'b1;
                                    state_r <= ST_A_REQ;
                                end else begin
                                    read_group_r <= 3'd0;
                                    state_r <= ST_B_REQ;
                                end
                            end
                        end
                    end

                    ST_B_REQ: begin
                        if (banked_ready) begin
                            if (banked_protection_error) begin
                                error_code <= ERR_PROTECTION;
                                state_r <= ST_ERROR;
                            end else begin
                                state_r <= ST_B_WAIT;
                            end
                        end
                    end

                    ST_B_WAIT: begin
                        if (banked_rsp_valid) begin
                            if (bank_response_has_parity_error) begin
                                error_code <= ERR_PARITY;
                                state_r <= ST_ERROR;
                            end else begin
                                b_tile_words_r[read_group_r*4+0] <= bank0_data;
                                b_tile_words_r[read_group_r*4+1] <= bank1_data;
                                b_tile_words_r[read_group_r*4+2] <= bank2_data;
                                b_tile_words_r[read_group_r*4+3] <= bank3_data;
                                if (({29'd0,read_group_r} + 32'd1) < b_group_count) begin
                                    read_group_r <= read_group_r + 1'b1;
                                    state_r <= ST_B_REQ;
                                end else if (bias_enable_r && !bias_loaded_r) begin
                                    read_group_r <= 3'd0;
                                    bias_index_r <= {(TILE_INDEX_WIDTH+1){1'b0}};
                                    state_r <= ST_BIAS_REQ;
                                end else begin
                                    read_group_r <= 3'd0;
                                    state_r <= ST_PREP_MAC;
                                end
                            end
                        end
                    end

                    ST_BIAS_REQ: begin
                        if (spad_ready) begin
                            if (spad_protection_error) begin
                                error_code <= ERR_PROTECTION;
                                state_r <= ST_ERROR;
                            end else begin
                                state_r <= ST_BIAS_WAIT;
                            end
                        end
                    end

                    ST_BIAS_WAIT: begin
                        if (spad_rsp_valid) begin
                            if (spad_parity_error) begin
                                error_code <= ERR_PARITY;
                                state_r <= ST_ERROR;
                            end else begin
                                bias_words_r[bias_index_r] <= spad_rdata;
                                if (({27'd0,bias_index_r} + 32'd1) < valid_cols) begin
                                    bias_index_r <= bias_index_r + 1'b1;
                                    state_r <= ST_BIAS_REQ;
                                end else begin
                                    bias_loaded_r <= 1'b1;
                                    state_r <= ST_PREP_MAC;
                                end
                            end
                        end
                    end

                    ST_PREP_MAC: begin
                        lane_r <= 2'd0;
                        state_r <= ST_MAC;
                    end

                    ST_MAC: begin
                        if (lane_r == 2'd3) begin
                            lane_r <= 2'd0;
                            if (last_k_group) begin
                                write_row_r <= {TILE_INDEX_WIDTH{1'b0}};
                                write_col_r <= {TILE_INDEX_WIDTH{1'b0}};
                                write_lane_r <= 2'd0;
                                dst_row_addr_r <= dst_tile_base_r;
                                state_r <= ST_WRITE;
                            end else begin
                                k_group_r <= k_group_r + 1'b1;
                                read_group_r <= 3'd0;
                                state_r <= ST_A_REQ;
                            end
                        end else begin
                            lane_r <= lane_r + 1'b1;
                        end
                    end

                    ST_WRITE: begin
                        if (output_write_accepted) begin
                            if (output_write_has_protection_error) begin
                                error_code <= ERR_PROTECTION;
                                state_r <= ST_ERROR;
                            end else begin
                                result <= line_store_eligible ? write_result3 :
                                                                  scalar_write_result;
                                if (line_store_eligible)
                                    element_count <= element_count + 32'd4;
                                else
                                    element_count <= element_count + 32'd1;

                                if (!line_store_eligible && (write_lane_r != 2'd3)) begin
                                    write_lane_r <= write_lane_r + 1'b1;
                                end else begin
                                    write_lane_r <= 2'd0;
                                    if (({28'd0,write_col_r} + 32'd4) < valid_cols) begin
                                        write_col_r <= write_col_r + 4;
                                    end else if (({28'd0,write_row_r} + 32'd1) < valid_rows) begin
                                        write_col_r <= {TILE_INDEX_WIDTH{1'b0}};
                                        write_row_r <= write_row_r + 1'b1;
                                        dst_row_addr_r <= dst_row_addr_r + dst_row_stride_r;
                                    end else begin
                                        state_r <= ST_NEXT;
                                    end
                                end
                            end
                        end
                    end

                    ST_NEXT: begin
                        k_group_r <= 16'd0;
                        read_group_r <= 3'd0;
                        lane_r <= 2'd0;
                        write_lane_r <= 2'd0;
                        bias_loaded_r <= 1'b0;
                        if (({16'd0,col_tile_r} + 32'd1) < n_tile_count) begin
                            col_tile_r <= col_tile_r + 1'b1;
                            b_tile_base_r <= b_tile_base_r + matrix_tile_span_bytes;
                            dst_tile_base_r <= dst_tile_base_r + (ARRAY_SIZE * 4);
                            dst_row_addr_r <= dst_row_tile_base_r;
                            bias_tile_base_r <= bias_tile_base_r + (ARRAY_SIZE * 4);
                            state_r <= ST_A_REQ;
                        end else if (({16'd0,row_tile_r} + 32'd1) < m_tile_count) begin
                            row_tile_r <= row_tile_r + 1'b1;
                            col_tile_r <= 16'd0;
                            a_tile_base_r <= a_tile_base_r + matrix_tile_span_bytes;
                            b_tile_base_r <= b_batch_base_r;
                            dst_row_tile_base_r <= dst_row_tile_base_r +
                                                   (dst_row_stride_r * ARRAY_SIZE);
                            dst_tile_base_r <= dst_row_tile_base_r +
                                               (dst_row_stride_r * ARRAY_SIZE);
                            dst_row_addr_r <= dst_row_tile_base_r +
                                              (dst_row_stride_r * ARRAY_SIZE);
                            bias_tile_base_r <= bias_batch_base_r;
                            state_r <= ST_A_REQ;
                        end else if ((instance_r + 1'b1) < instance_count_r) begin
                            instance_r <= instance_r + 1'b1;
                            row_tile_r <= 16'd0;
                            col_tile_r <= 16'd0;
                            a_batch_base_r <= a_batch_base_r + src0_batch_stride_r;
                            b_batch_base_r <= b_batch_base_r + src1_batch_stride_r;
                            dst_batch_base_r <= dst_batch_base_r + dst_batch_stride_r;
                            a_tile_base_r <= a_batch_base_r + src0_batch_stride_r;
                            b_tile_base_r <= b_batch_base_r + src1_batch_stride_r;
                            dst_row_tile_base_r <= dst_batch_base_r + dst_batch_stride_r;
                            dst_tile_base_r <= dst_batch_base_r + dst_batch_stride_r;
                            dst_row_addr_r <= dst_batch_base_r + dst_batch_stride_r;
                            bias_tile_base_r <= bias_batch_base_r;
                            state_r <= ST_A_REQ;
                        end else begin
                            state_r <= ST_DONE;
                        end
                    end

                    ST_DONE: begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b0;
                        state_r <= ST_IDLE;
                    end

                    ST_ERROR: begin
                        busy <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        state_r <= ST_IDLE;
                    end

                    default: state_r <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
