`timescale 1ns / 1ps

// Matrix command controller using a parameterized output-stationary INT8 array.
// The external descriptor and the legacy 4x4 tile-major SPAD layout are
// unchanged. A 16x16 array gathers four 4x4 row/column groups per K-word
// slice, accumulates one 16x16 macro-tile, then writes four results per line.
module ai_tensor_matrix_core #(
    parameter integer ARRAY_SIZE = 16,
    parameter integer MAX_OUTSTANDING_READS = 4,
    parameter integer ENABLE_A_TILE_CACHE = 1
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
    // Keep one A macro-tile's K groups for reuse across adjacent N tiles.
    // Larger K commands remain legal and bypass this bounded local cache.
    localparam integer A_TILE_CACHE_K_WORDS = 16;
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
    localparam [3:0] ST_ERROR_DRAIN = 4'd13;
    localparam [3:0] ST_PREFETCH_WAIT = 4'd14;
    localparam [2:0] PF_IDLE      = 3'd0;
    localparam [2:0] PF_A_REQ     = 3'd1;
    localparam [2:0] PF_A_DRAIN   = 3'd2;
    localparam [2:0] PF_B_REQ     = 3'd3;
    localparam [2:0] PF_B_DRAIN   = 3'd4;
    localparam integer READ_FIFO_PTR_WIDTH =
        (MAX_OUTSTANDING_READS <= 2) ? 1 : $clog2(MAX_OUTSTANDING_READS);
    localparam integer READ_FIFO_COUNT_WIDTH = READ_FIFO_PTR_WIDTH + 1;
    localparam [READ_FIFO_PTR_WIDTH-1:0] READ_FIFO_LAST =
        MAX_OUTSTANDING_READS - 1;

    reg [3:0] state_r;
    // Passive per-command profile used by VCS regressions. Indexes follow the
    // ST_* encoding below; the aggregate stalls split request arbitration,
    // response latency, and output writeback backpressure without changing
    // the command interface or FSM decisions.
    reg [31:0] perf_state_cycles [0:14];
    reg [31:0] perf_arbiter_stall_cycles;
    reg [31:0] perf_response_wait_cycles;
    reg [31:0] perf_writeback_wait_cycles;
    reg [31:0] perf_prefetch_a_req_cycles;
    reg [31:0] perf_prefetch_a_drain_cycles;
    reg [31:0] perf_prefetch_b_req_cycles;
    reg [31:0] perf_prefetch_b_drain_cycles;
    reg [31:0] perf_prefetch_overlap_cycles;
    reg [31:0] perf_prefetch_wait_cycles;
    reg [31:0] perf_prefetch_completed;
    reg [31:0] perf_a_tile_cache_hits;
    reg [2:0] prefetch_state_r;
    reg [2:0] prefetch_group_r;
    reg [15:0] prefetch_k_group_r;
    reg prefetch_buffer_r;
    reg [1:0] prefetch_valid_r;
    reg compute_buffer_r;
    reg prefetch_kick;
    reg [15:0] prefetch_kick_k_group;
    reg prefetch_kick_buffer;
    reg prefetch_consume;
    reg prefetch_consume_buffer;
    reg [READ_FIFO_COUNT_WIDTH-1:0] read_outstanding_count;
    reg [READ_FIFO_PTR_WIDTH-1:0] read_fifo_wr_ptr, read_fifo_rd_ptr;
    // {operand B, 4x4 group, K group, full bank-word address}. The fixed-latency
    // response path has no ID, so accepted request ownership is retained here.
    reg [52:0] read_response_meta_fifo [0:MAX_OUTSTANDING_READS-1];
    reg [READ_FIFO_COUNT_WIDTH-1:0] perf_outstanding_highwater;
    reg [31:0] perf_fifo_full_cycles;
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

    reg [31:0] a_tile_words_r [0:1][0:ARRAY_SIZE-1];
    reg [31:0] b_tile_words_r [0:1][0:ARRAY_SIZE-1];
    reg [31:0] a_tile_cache_words_r [0:A_TILE_CACHE_K_WORDS-1][0:ARRAY_SIZE-1];
    reg [ARRAY_GROUPS-1:0] a_cache_group_seen_r [0:A_TILE_CACHE_K_WORDS-1];
    reg [A_TILE_CACHE_K_WORDS-1:0] a_cache_valid_r;
    reg [31:0] a_cache_base_r;
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
    integer perf_i;
    integer cache_i;

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
    wire prefetch_active = (prefetch_state_r != PF_IDLE);
    wire prefetch_is_b_req = (prefetch_state_r == PF_B_REQ);
    wire prefetch_request_pending =
        ((prefetch_state_r == PF_A_REQ) && (prefetch_group_r < a_group_count)) ||
        ((prefetch_state_r == PF_B_REQ) && (prefetch_group_r < b_group_count));
    wire [31:0] prefetch_word_offset =
        (({29'd0,prefetch_group_r} * {16'd0,k_words_r}) +
         {16'd0,prefetch_k_group_r}) << 4;
    wire [31:0] prefetch_a_addr = a_tile_base_r + prefetch_word_offset;
    wire [31:0] prefetch_b_addr = b_tile_base_r + prefetch_word_offset;
    wire [31:0] prefetch_read_addr = prefetch_is_b_req ?
                                     prefetch_b_addr : prefetch_a_addr;
    wire banked_request_is_prefetch = prefetch_active;
    wire banked_request_is_b = prefetch_active ? prefetch_is_b_req :
                               (state_r == ST_B_REQ);
    wire [2:0] banked_request_group = prefetch_active ? prefetch_group_r :
                                      read_group_r;
    wire [15:0] banked_request_k_group = prefetch_active ?
                                         prefetch_k_group_r : k_group_r;
    wire banked_request_buffer = prefetch_active ? prefetch_buffer_r : 1'b0;
    wire a_cache_tag_match = ENABLE_A_TILE_CACHE &&
                             (k_words_r <= A_TILE_CACHE_K_WORDS) &&
                             (a_cache_base_r == a_tile_base_r);
    wire a_cache_initial_hit = a_cache_tag_match &&
                               a_cache_valid_r[k_group_r[3:0]];
    wire a_cache_prefetch_hit = ENABLE_A_TILE_CACHE &&
        (k_words_r <= A_TILE_CACHE_K_WORDS) &&
        (a_cache_base_r == a_tile_base_r) &&
        (prefetch_kick_k_group < A_TILE_CACHE_K_WORDS) &&
        a_cache_valid_r[prefetch_kick_k_group[3:0]];
    wire a_cache_initial_copy = (state_r == ST_A_REQ) &&
                                (read_group_r == 0) && a_cache_initial_hit;
    wire a_cache_prefetch_copy = prefetch_kick &&
                                 (prefetch_state_r == PF_IDLE) &&
                                 a_cache_prefetch_hit;
    wire bank_response_has_parity_error = |bank_parity_error;
    wire banked_read_accept = banked_read_valid && banked_ready;
    wire read_request_pending = prefetch_active ? prefetch_request_pending :
        (((state_r == ST_A_REQ) && !a_cache_initial_copy &&
          (read_group_r < a_group_count)) ||
         ((state_r == ST_B_REQ) && (read_group_r < b_group_count)));
    wire banked_response_accept = banked_rsp_valid &&
                                  (read_outstanding_count != 0);
    wire banked_response_fault = banked_response_accept &&
                                 bank_response_has_parity_error;
    wire banked_request_fault = banked_read_accept &&
                                banked_protection_error;
    wire read_fifo_push = banked_read_accept;
    wire read_fifo_pop = banked_response_accept;
    wire [READ_FIFO_COUNT_WIDTH-1:0] read_outstanding_next =
        read_outstanding_count +
        (read_fifo_push && !read_fifo_pop) -
        (read_fifo_pop && !read_fifo_push);
    wire prefetch_complete = (prefetch_state_r == PF_B_DRAIN) &&
                             (read_outstanding_next == 0);
    wire [READ_FIFO_PTR_WIDTH-1:0] read_fifo_wr_next =
        (read_fifo_wr_ptr == READ_FIFO_LAST) ?
        {READ_FIFO_PTR_WIDTH{1'b0}} : read_fifo_wr_ptr + 1'b1;
    wire [READ_FIFO_PTR_WIDTH-1:0] read_fifo_rd_next =
        (read_fifo_rd_ptr == READ_FIFO_LAST) ?
        {READ_FIFO_PTR_WIDTH{1'b0}} : read_fifo_rd_ptr + 1'b1;
    wire [52:0] response_meta = read_response_meta_fifo[read_fifo_rd_ptr];
    wire response_buffer = response_meta[52];
    wire response_operand_b = response_meta[51];
    wire [2:0] response_group = response_meta[50:48];
    wire [15:0] response_k_group = response_meta[47:32];
    wire [31:0] response_request_addr = response_meta[31:0];
    wire [ARRAY_GROUPS-1:0] a_cache_response_group_mask =
        {{(ARRAY_GROUPS-1){1'b0}},1'b1} << response_group;
    wire [ARRAY_GROUPS-1:0] a_cache_required_group_mask =
        {ARRAY_GROUPS{1'b1}} >> (ARRAY_GROUPS - a_group_count);
    wire [31:0] response_group_offset =
        (({29'd0,response_group} * {16'd0,k_words_r}) +
         {16'd0,response_k_group}) << 4;
    wire [31:0] response_expected_addr = response_operand_b ?
        (b_tile_base_r + response_group_offset) :
        (a_tile_base_r + response_group_offset);
    wire banked_response_context_fault = banked_response_accept &&
        (state_r != ST_ERROR_DRAIN) &&
        ((response_k_group >= k_words_r) ||
         (response_request_addr != response_expected_addr));
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
    assign perf_banked_wait =
        (((state_r == ST_A_WAIT) || (state_r == ST_B_WAIT) ||
          (state_r == ST_PREFETCH_WAIT)) &&
         (read_outstanding_count != 0) && !banked_rsp_valid);
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
        if (prefetch_active && prefetch_request_pending &&
            (read_outstanding_count < MAX_OUTSTANDING_READS) &&
            (state_r != ST_ERROR_DRAIN) && (state_r != ST_ERROR) &&
            !abort && !watchdog_expired && !banked_response_fault &&
            !banked_response_context_fault) begin
            banked_read_valid = 1'b1;
            banked_addr = prefetch_read_addr;
        end else if (!prefetch_active && (state_r == ST_A_REQ) &&
            !a_cache_initial_copy &&
            (read_group_r < a_group_count) &&
            (read_outstanding_count < MAX_OUTSTANDING_READS) &&
            !abort && !watchdog_expired && !banked_response_fault &&
            !banked_response_context_fault) begin
            banked_read_valid = 1'b1;
            banked_addr = a_read_addr;
        end else if (!prefetch_active && (state_r == ST_B_REQ) &&
                     (read_group_r < b_group_count) &&
                     (read_outstanding_count < MAX_OUTSTANDING_READS) &&
                     !abort && !watchdog_expired && !banked_response_fault &&
                     !banked_response_context_fault) begin
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
                a_tile_words_r[compute_buffer_r][(vector_i/4)*4+0],
                a_tile_words_r[compute_buffer_r][(vector_i/4)*4+1],
                a_tile_words_r[compute_buffer_r][(vector_i/4)*4+2],
                a_tile_words_r[compute_buffer_r][(vector_i/4)*4+3],
                vector_i%4,array_load_lane,transpose_a_r);
            array_load_b[vector_i*8 +: 8] = matrix_tile_element(
                b_tile_words_r[compute_buffer_r][(vector_i/4)*4+0],
                b_tile_words_r[compute_buffer_r][(vector_i/4)*4+1],
                b_tile_words_r[compute_buffer_r][(vector_i/4)*4+2],
                b_tile_words_r[compute_buffer_r][(vector_i/4)*4+3],
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

    // Background K-group fetch. It writes only the inactive operand buffer;
    // the response FIFO still provides the accepted-request ownership for
    // both initial reads and prefetch reads.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            prefetch_state_r <= PF_IDLE;
            prefetch_group_r <= 3'd0;
            prefetch_k_group_r <= 16'd0;
            prefetch_buffer_r <= 1'b0;
            prefetch_valid_r <= 2'b00;
        end else begin
            if (prefetch_consume)
                prefetch_valid_r[prefetch_consume_buffer] <= 1'b0;

            if (abort || watchdog_expired || banked_request_fault ||
                banked_response_fault || banked_response_context_fault ||
                (state_r == ST_ERROR_DRAIN) || (state_r == ST_ERROR)) begin
                prefetch_state_r <= PF_IDLE;
                prefetch_valid_r <= 2'b00;
            end else if (prefetch_kick && (prefetch_state_r == PF_IDLE)) begin
                prefetch_group_r <= 3'd0;
                prefetch_k_group_r <= prefetch_kick_k_group;
                prefetch_buffer_r <= prefetch_kick_buffer;
                prefetch_valid_r[prefetch_kick_buffer] <= 1'b0;
                prefetch_state_r <= a_cache_prefetch_hit ? PF_B_REQ : PF_A_REQ;
            end else begin
                case (prefetch_state_r)
                    PF_A_REQ: begin
                        if (banked_request_is_prefetch && banked_read_accept) begin
                            if (({29'd0,prefetch_group_r} + 32'd1) >= a_group_count)
                                prefetch_state_r <= PF_A_DRAIN;
                            else
                                prefetch_group_r <= prefetch_group_r + 1'b1;
                        end
                    end
                    PF_A_DRAIN: begin
                        if (read_outstanding_next == 0) begin
                            prefetch_group_r <= 3'd0;
                            prefetch_state_r <= PF_B_REQ;
                        end
                    end
                    PF_B_REQ: begin
                        if (banked_request_is_prefetch && banked_read_accept) begin
                            if (({29'd0,prefetch_group_r} + 32'd1) >= b_group_count)
                                prefetch_state_r <= PF_B_DRAIN;
                            else
                                prefetch_group_r <= prefetch_group_r + 1'b1;
                        end
                    end
                    PF_B_DRAIN: begin
                        if (read_outstanding_next == 0) begin
                            prefetch_valid_r[prefetch_buffer_r] <= 1'b1;
                            prefetch_state_r <= PF_IDLE;
                        end
                    end
                    default: prefetch_state_r <= PF_IDLE;
                endcase
            end
        end
    end

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
            perf_arbiter_stall_cycles <= 32'd0;
            perf_response_wait_cycles <= 32'd0;
            perf_writeback_wait_cycles <= 32'd0;
            perf_prefetch_a_req_cycles <= 32'd0;
            perf_prefetch_a_drain_cycles <= 32'd0;
            perf_prefetch_b_req_cycles <= 32'd0;
            perf_prefetch_b_drain_cycles <= 32'd0;
            perf_prefetch_overlap_cycles <= 32'd0;
            perf_prefetch_wait_cycles <= 32'd0;
            perf_prefetch_completed <= 32'd0;
            perf_a_tile_cache_hits <= 32'd0;
            compute_buffer_r <= 1'b0;
            prefetch_kick <= 1'b0;
            prefetch_kick_k_group <= 16'd0;
            prefetch_kick_buffer <= 1'b0;
            prefetch_consume <= 1'b0;
            prefetch_consume_buffer <= 1'b0;
            read_outstanding_count <= {READ_FIFO_COUNT_WIDTH{1'b0}};
            read_fifo_wr_ptr <= {READ_FIFO_PTR_WIDTH{1'b0}};
            read_fifo_rd_ptr <= {READ_FIFO_PTR_WIDTH{1'b0}};
            perf_outstanding_highwater <= {READ_FIFO_COUNT_WIDTH{1'b0}};
            perf_fifo_full_cycles <= 32'd0;
            for (perf_i = 0; perf_i <= ST_PREFETCH_WAIT; perf_i = perf_i + 1)
                perf_state_cycles[perf_i] <= 32'd0;
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
                a_tile_words_r[0][reset_i] <= 32'd0;
                a_tile_words_r[1][reset_i] <= 32'd0;
                b_tile_words_r[0][reset_i] <= 32'd0;
                b_tile_words_r[1][reset_i] <= 32'd0;
                bias_words_r[reset_i] <= 32'sd0;
            end
            a_cache_base_r <= 32'd0;
            a_cache_valid_r <= {A_TILE_CACHE_K_WORDS{1'b0}};
            for (cache_i = 0; cache_i < A_TILE_CACHE_K_WORDS; cache_i = cache_i + 1) begin
                a_cache_group_seen_r[cache_i] <= {ARRAY_GROUPS{1'b0}};
                for (reset_i = 0; reset_i < ARRAY_SIZE; reset_i = reset_i + 1)
                    a_tile_cache_words_r[cache_i][reset_i] <= 32'd0;
            end
        end else begin
            done <= 1'b0;
            prefetch_kick <= 1'b0;
            prefetch_consume <= 1'b0;

            // The banked SPAD has no response ready or transaction ID. Keep
            // accepted Matrix metadata in order until each registered
            // response arrives. A response can coincide with a new accept.
            if (read_fifo_push) begin
                read_response_meta_fifo[read_fifo_wr_ptr] <= {
                    banked_request_buffer, banked_request_is_b,
                    banked_request_group, banked_request_k_group, banked_addr
                };
                read_fifo_wr_ptr <= read_fifo_wr_next;
            end
            if (read_fifo_pop)
                read_fifo_rd_ptr <= read_fifo_rd_next;
            case ({read_fifo_push, read_fifo_pop})
                2'b10: read_outstanding_count <= read_outstanding_count + 1'b1;
                2'b01: read_outstanding_count <= read_outstanding_count - 1'b1;
                default: read_outstanding_count <= read_outstanding_count;
            endcase

            if (read_fifo_pop && !bank_response_has_parity_error &&
                !banked_response_context_fault &&
                (state_r != ST_ERROR_DRAIN) && !abort &&
                !watchdog_expired) begin
                if (response_operand_b) begin
                    b_tile_words_r[response_buffer][response_group*4+0] <= bank0_data;
                    b_tile_words_r[response_buffer][response_group*4+1] <= bank1_data;
                    b_tile_words_r[response_buffer][response_group*4+2] <= bank2_data;
                    b_tile_words_r[response_buffer][response_group*4+3] <= bank3_data;
                end else begin
                    a_tile_words_r[response_buffer][response_group*4+0] <= bank0_data;
                    a_tile_words_r[response_buffer][response_group*4+1] <= bank1_data;
                    a_tile_words_r[response_buffer][response_group*4+2] <= bank2_data;
                    a_tile_words_r[response_buffer][response_group*4+3] <= bank3_data;
                    if (a_cache_tag_match &&
                        (response_k_group < A_TILE_CACHE_K_WORDS)) begin
                        a_tile_cache_words_r[response_k_group[3:0]][response_group*4+0] <= bank0_data;
                        a_tile_cache_words_r[response_k_group[3:0]][response_group*4+1] <= bank1_data;
                        a_tile_cache_words_r[response_k_group[3:0]][response_group*4+2] <= bank2_data;
                        a_tile_cache_words_r[response_k_group[3:0]][response_group*4+3] <= bank3_data;
                        a_cache_group_seen_r[response_k_group[3:0]][response_group] <= 1'b1;
                        if (((a_cache_group_seen_r[response_k_group[3:0]] |
                              a_cache_response_group_mask) ==
                             a_cache_required_group_mask) &&
                            (response_group + 1'b1 >= a_group_count))
                            a_cache_valid_r[response_k_group[3:0]] <= 1'b1;
                    end
                end
            end
            if (a_cache_initial_copy) begin
                for (cache_i = 0; cache_i < ARRAY_SIZE; cache_i = cache_i + 1)
                    a_tile_words_r[compute_buffer_r][cache_i] <=
                        a_tile_cache_words_r[k_group_r[3:0]][cache_i];
            end
            if (a_cache_prefetch_copy) begin
                for (cache_i = 0; cache_i < ARRAY_SIZE; cache_i = cache_i + 1)
                    a_tile_words_r[prefetch_kick_buffer][cache_i] <=
                        a_tile_cache_words_r[prefetch_kick_k_group[3:0]][cache_i];
            end

            if ((state_r == ST_IDLE) && start)
                cycle_count <= 32'd0;
            else if (busy)
                cycle_count <= cycle_count + 1'b1;

            // Profile only while a command owns the controller. These
            // counters are observational: no counter feeds a ready, valid,
            // state transition, or arithmetic control signal.
            if ((state_r == ST_IDLE) && start) begin
                perf_arbiter_stall_cycles <= 32'd0;
                perf_response_wait_cycles <= 32'd0;
                perf_writeback_wait_cycles <= 32'd0;
                perf_prefetch_a_req_cycles <= 32'd0;
                perf_prefetch_a_drain_cycles <= 32'd0;
                perf_prefetch_b_req_cycles <= 32'd0;
                perf_prefetch_b_drain_cycles <= 32'd0;
                perf_prefetch_overlap_cycles <= 32'd0;
                perf_prefetch_wait_cycles <= 32'd0;
                perf_prefetch_completed <= 32'd0;
                perf_a_tile_cache_hits <= 32'd0;
                perf_outstanding_highwater <= {READ_FIFO_COUNT_WIDTH{1'b0}};
                perf_fifo_full_cycles <= 32'd0;
                for (perf_i = 0; perf_i <= ST_PREFETCH_WAIT; perf_i = perf_i + 1)
                    perf_state_cycles[perf_i] <= 32'd0;
            end else if (busy) begin
                if (state_r <= ST_PREFETCH_WAIT)
                    perf_state_cycles[state_r] <=
                        perf_state_cycles[state_r] + 1'b1;
                if (prefetch_state_r == PF_A_REQ)
                    perf_prefetch_a_req_cycles <=
                        perf_prefetch_a_req_cycles + 1'b1;
                if (prefetch_state_r == PF_A_DRAIN)
                    perf_prefetch_a_drain_cycles <=
                        perf_prefetch_a_drain_cycles + 1'b1;
                if (prefetch_state_r == PF_B_REQ)
                    perf_prefetch_b_req_cycles <=
                        perf_prefetch_b_req_cycles + 1'b1;
                if (prefetch_state_r == PF_B_DRAIN)
                    perf_prefetch_b_drain_cycles <=
                        perf_prefetch_b_drain_cycles + 1'b1;
                if ((state_r == ST_MAC) && prefetch_active)
                    perf_prefetch_overlap_cycles <=
                        perf_prefetch_overlap_cycles + 1'b1;
                if (state_r == ST_PREFETCH_WAIT)
                    perf_prefetch_wait_cycles <=
                        perf_prefetch_wait_cycles + 1'b1;
                if (prefetch_complete)
                    perf_prefetch_completed <= perf_prefetch_completed + 1'b1;
                if (a_cache_initial_copy || a_cache_prefetch_copy)
                    perf_a_tile_cache_hits <= perf_a_tile_cache_hits + 1'b1;
                if (read_outstanding_next > perf_outstanding_highwater)
                    perf_outstanding_highwater <= read_outstanding_next;
                if (read_request_pending &&
                    (read_outstanding_count == MAX_OUTSTANDING_READS))
                    perf_fifo_full_cycles <= perf_fifo_full_cycles + 1'b1;
                if ((banked_read_valid && !banked_ready) ||
                    (spad_valid && !spad_ready) ||
                    (line_valid && !line_ready))
                    perf_arbiter_stall_cycles <=
                        perf_arbiter_stall_cycles + 1'b1;
                if ((((state_r == ST_A_REQ) || (state_r == ST_A_WAIT) ||
                      (state_r == ST_B_REQ) || (state_r == ST_B_WAIT)) &&
                     (read_outstanding_count != 0) && !banked_rsp_valid) ||
                    ((state_r == ST_BIAS_WAIT) && !spad_rsp_valid))
                    perf_response_wait_cycles <=
                        perf_response_wait_cycles + 1'b1;
                if ((state_r == ST_WRITE) && !output_write_accepted)
                    perf_writeback_wait_cycles <=
                        perf_writeback_wait_cycles + 1'b1;
            end

            if (busy && abort && (state_r != ST_ERROR) &&
                (state_r != ST_ERROR_DRAIN)) begin
                error_code <= ERR_ABORT;
                state_r <= ST_ERROR_DRAIN;
            end else if (watchdog_expired && (state_r != ST_ERROR) &&
                         (state_r != ST_ERROR_DRAIN)) begin
                error_code <= ERR_WATCHDOG;
                state_r <= ST_ERROR_DRAIN;
            end else if (banked_request_fault) begin
                error_code <= ERR_PROTECTION;
                state_r <= ST_ERROR_DRAIN;
            end else if (banked_response_fault) begin
                error_code <= ERR_PARITY;
                state_r <= ST_ERROR_DRAIN;
            end else if (banked_response_context_fault) begin
                error_code <= ERR_CONFIG;
                state_r <= ST_ERROR_DRAIN;
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
                            a_cache_base_r <= src0_base;
                            a_cache_valid_r <= {A_TILE_CACHE_K_WORDS{1'b0}};
                            for (cache_i = 0; cache_i < A_TILE_CACHE_K_WORDS; cache_i = cache_i + 1)
                                a_cache_group_seen_r[cache_i] <= {ARRAY_GROUPS{1'b0}};
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
                            compute_buffer_r <= 1'b0;
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
                        if (a_cache_initial_copy) begin
                            read_group_r <= 3'd0;
                            state_r <= ST_B_REQ;
                        end else if (banked_read_accept) begin
                            if (({29'd0,read_group_r} + 32'd1) >= a_group_count) begin
                                state_r <= ST_A_WAIT;
                            end else begin
                                read_group_r <= read_group_r + 1'b1;
                            end
                        end
                    end

                    ST_A_WAIT: begin
                        if (read_outstanding_next == 0) begin
                            read_group_r <= 3'd0;
                            state_r <= ST_B_REQ;
                        end
                    end

                    ST_B_REQ: begin
                        if (banked_read_accept) begin
                            if (({29'd0,read_group_r} + 32'd1) >= b_group_count) begin
                                state_r <= ST_B_WAIT;
                            end else begin
                                read_group_r <= read_group_r + 1'b1;
                            end
                        end
                    end

                    ST_B_WAIT: begin
                        if (read_outstanding_next == 0) begin
                            read_group_r <= 3'd0;
                            if (bias_enable_r && !bias_loaded_r) begin
                                bias_index_r <= {(TILE_INDEX_WIDTH+1){1'b0}};
                                state_r <= ST_BIAS_REQ;
                            end else begin
                                if (k_words_r > 1) begin
                                    prefetch_kick <= 1'b1;
                                    prefetch_kick_k_group <= 16'd1;
                                    prefetch_kick_buffer <= 1'b1;
                                end
                                state_r <= ST_PREP_MAC;
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
                                    if ((k_group_r == 0) && (k_words_r > 1)) begin
                                        prefetch_kick <= 1'b1;
                                        prefetch_kick_k_group <= 16'd1;
                                        prefetch_kick_buffer <= 1'b1;
                                    end
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
                            end else if (prefetch_valid_r[~compute_buffer_r]) begin
                                k_group_r <= k_group_r + 1'b1;
                                compute_buffer_r <= ~compute_buffer_r;
                                prefetch_consume <= 1'b1;
                                prefetch_consume_buffer <= ~compute_buffer_r;
                                read_group_r <= 3'd0;
                                if (({16'd0,k_group_r} + 32'd2) < {16'd0,k_words_r}) begin
                                    prefetch_kick <= 1'b1;
                                    prefetch_kick_k_group <= k_group_r + 2'd2;
                                    prefetch_kick_buffer <= compute_buffer_r;
                                end
                                state_r <= ST_PREP_MAC;
                            end else begin
                                read_group_r <= 3'd0;
                                state_r <= ST_PREFETCH_WAIT;
                            end
                        end else begin
                            lane_r <= lane_r + 1'b1;
                        end
                    end

                    ST_PREFETCH_WAIT: begin
                        if (prefetch_valid_r[~compute_buffer_r]) begin
                            k_group_r <= k_group_r + 1'b1;
                            compute_buffer_r <= ~compute_buffer_r;
                            prefetch_consume <= 1'b1;
                            prefetch_consume_buffer <= ~compute_buffer_r;
                            read_group_r <= 3'd0;
                            if (({16'd0,k_group_r} + 32'd2) < {16'd0,k_words_r}) begin
                                prefetch_kick <= 1'b1;
                                prefetch_kick_k_group <= k_group_r + 2'd2;
                                prefetch_kick_buffer <= compute_buffer_r;
                            end
                            state_r <= ST_PREP_MAC;
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
                        compute_buffer_r <= 1'b0;
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
                            a_cache_base_r <= a_tile_base_r + matrix_tile_span_bytes;
                            a_cache_valid_r <= {A_TILE_CACHE_K_WORDS{1'b0}};
                            for (cache_i = 0; cache_i < A_TILE_CACHE_K_WORDS; cache_i = cache_i + 1)
                                a_cache_group_seen_r[cache_i] <= {ARRAY_GROUPS{1'b0}};
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
                            a_cache_base_r <= a_batch_base_r + src0_batch_stride_r;
                            a_cache_valid_r <= {A_TILE_CACHE_K_WORDS{1'b0}};
                            for (cache_i = 0; cache_i < A_TILE_CACHE_K_WORDS; cache_i = cache_i + 1)
                                a_cache_group_seen_r[cache_i] <= {ARRAY_GROUPS{1'b0}};
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

                    ST_ERROR_DRAIN: begin
                        if (read_outstanding_next == 0)
                            state_r <= ST_ERROR;
                    end

                    default: state_r <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
