`timescale 1ns / 1ps

// Ordered BF16/FP16 dot product with a non-fused FP32 accumulator.
// Packed words use format[15:0] for the even element and [31:16] for odd.
// Reads are issued A/B in word order. Two pair slots permit input prefetch to
// overlap the one-element-per-cycle, increasing-index accumulation sequence.
module ai_mixed_precision_dot_fp32_core (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        format_fp16,
    input  wire        abort,
    input  wire [31:0] src0_base,
    input  wire [31:0] src1_base,
    input  wire [31:0] dst_base,
    input  wire [15:0] length,
    input  wire [31:0] watchdog_limit,
    output reg         spad_valid,
    output reg         spad_write,
    output reg  [31:0] spad_addr,
    output reg  [31:0] spad_wdata,
    input  wire        spad_ready,
    input  wire        spad_rsp_valid,
    input  wire [31:0] spad_rdata,
    input  wire        spad_parity_error,
    input  wire        spad_protection_error,
    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [31:0] result,
    output reg  [31:0] cycle_count,
    output reg  [31:0] element_count
);
    localparam [3:0] ERR_NONE=4'd0, ERR_CONFIG=4'd1, ERR_ABORT=4'd3,
                     ERR_WATCHDOG=4'd4, ERR_PARITY=4'd5,
                     ERR_PROTECTION=4'd6;
    localparam [3:0] ST_IDLE=4'd0, ST_RUN=4'd1,
                     ST_WRITE=4'd6, ST_DONE=4'd7, ST_ERROR=4'd8;

    reg [3:0] state_r;
    reg [31:0] src0_r, src1_r, dst_r, watchdog_r;
    reg [15:0] length_r, request_word_index_r, response_word_index_r;
    reg request_is_b_r, response_is_b_r, format_fp16_r;
    reg [3:0] pending_error_r;
    reg [15:0] element_index_r;
    reg [15:0] memory_error_cutoff_r;
    reg memory_error_cutoff_valid_r;

    reg [31:0] pair_a_r [0:1];
    reg [31:0] pair_b_r [0:1];
    reg [1:0] pair_busy_r, pair_a_valid_r, pair_b_valid_r;
    reg [1:0] outstanding_reads_r;

    wire [16:0] words_needed = ({1'b0, length_r} + 17'd1) >> 1;
    wire request_slot = request_word_index_r[0];
    wire response_slot = response_word_index_r[0];
    wire compute_slot = element_index_r[1];

    wire watchdog_expired = busy && (state_r != ST_WRITE) &&
                            (watchdog_r != 0) && (cycle_count >= watchdog_r);
    wire request_in_range = ({1'b0, request_word_index_r} < words_needed);
    wire request_slot_available = request_is_b_r ? pair_busy_r[request_slot] :
                                                   !pair_busy_r[request_slot];
    wire read_fire = spad_valid && spad_ready && !spad_write;
    wire response_fire = spad_rsp_valid;
    wire response_parity_failure = response_fire && spad_parity_error;
    wire read_protection_failure = read_fire && spad_protection_error;
    wire first_memory_error_now = (pending_error_r == ERR_NONE) &&
                                  (response_parity_failure ||
                                   read_protection_failure);
    wire [15:0] memory_error_cutoff_now = response_parity_failure ?
        {response_word_index_r[14:0], 1'b0} :
        {request_word_index_r[14:0], 1'b0};
    wire pending_memory_error = memory_error_cutoff_valid_r &&
        ((pending_error_r == ERR_PARITY) ||
         (pending_error_r == ERR_PROTECTION));
    wire write_protection_failure = (state_r == ST_WRITE) && spad_valid &&
                                    spad_ready && spad_protection_error;
    wire immediate_cancel = abort || watchdog_expired ||
        (pending_error_r == ERR_ABORT) || (pending_error_r == ERR_WATCHDOG);
    wire outstanding_room = (outstanding_reads_r < 2) || response_fire;
    wire read_request_enable = (state_r == ST_RUN) && request_in_range &&
                               request_slot_available &&
                               (pending_error_r == ERR_NONE) && !abort &&
                               !watchdog_expired && outstanding_room &&
                               !(response_fire && spad_parity_error);
    wire [2:0] outstanding_after = {1'b0, outstanding_reads_r} +
                                   (read_fire ? 3'd1 : 3'd0) -
                                   (response_fire ? 3'd1 : 3'd0);

    wire [31:0] active_a_word = pair_a_r[compute_slot];
    wire [31:0] active_b_word = pair_b_r[compute_slot];
    wire [15:0] elem_a = element_index_r[0] ? active_a_word[31:16] :
                                                       active_a_word[15:0];
    wire [15:0] elem_b = element_index_r[0] ? active_b_word[31:16] :
                                                       active_b_word[15:0];
    wire [31:0] bf16_product_bits, fp16_product_bits;
    wire [31:0] product_bits = format_fp16_r ? fp16_product_bits :
                                                 bf16_product_bits;
    wire [31:0] accumulator_bits;
    wire last_element = (element_index_r == length_r - 16'd1);
    wire pair_ready = pair_a_valid_r[compute_slot] &&
                      pair_b_valid_r[compute_slot];
    wire compute_before_memory_error = pending_memory_error ?
        (element_index_r < memory_error_cutoff_r) :
        (first_memory_error_now && (element_index_r < memory_error_cutoff_now));
    wire compute_allowed = (pending_error_r == ERR_NONE) ||
                           compute_before_memory_error;
    wire compute_fire = (state_r == ST_RUN) && pair_ready &&
                        compute_allowed && !immediate_cancel &&
                        !write_protection_failure;
    wire compute_pair_last = compute_fire && (element_index_r[0] ||
                                               last_element);
    wire failure_active = (pending_error_r != ERR_NONE) || abort ||
                          watchdog_expired ||
                          (response_fire && spad_parity_error) ||
                          (read_fire && spad_protection_error) ||
                          write_protection_failure;

    ai_bf16_mul_fp32 u_mul (
        .a_bits(elem_a), .b_bits(elem_b), .result_bits(bf16_product_bits)
    );
    ai_fp16_mul_fp32 u_fp16_mul (
        .a_bits(elem_a), .b_bits(elem_b), .result_bits(fp16_product_bits)
    );
    ai_fp32_accumulator u_acc (
        .clk(clk), .rst_n(resetn), .clear(state_r == ST_IDLE && start &&
                    (length != 0) && (src0_base[1:0] == 0) &&
                    (src1_base[1:0] == 0) && (dst_base[1:0] == 0)),
        .accumulate(compute_fire), .product_bits(product_bits),
        .accumulator_bits(accumulator_bits)
    );

    // One request is presented at a time; after A0/B0 the stream can continue
    // at one accepted word per cycle as the two-cycle ordered responses drain.
    always @* begin
        spad_valid = 1'b0;
        spad_write = 1'b0;
        spad_addr = 32'b0;
        spad_wdata = 32'b0;
        if (state_r == ST_RUN && read_request_enable) begin
            spad_valid = 1'b1;
            if (request_is_b_r)
                spad_addr = src1_r + {request_word_index_r, 2'b00};
            else
                spad_addr = src0_r + {request_word_index_r, 2'b00};
        end else if (state_r == ST_WRITE) begin
            spad_valid = 1'b1;
            spad_write = 1'b1;
            spad_addr = dst_r;
            spad_wdata = accumulator_bits;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r <= ST_IDLE;
            src0_r <= 0; src1_r <= 0; dst_r <= 0; watchdog_r <= 0;
            length_r <= 0; request_word_index_r <= 0;
            response_word_index_r <= 0; element_index_r <= 0;
            memory_error_cutoff_r <= 0; memory_error_cutoff_valid_r <= 0;
            request_is_b_r <= 0; response_is_b_r <= 0;
            format_fp16_r <= 0; pending_error_r <= ERR_NONE;
            pair_busy_r <= 0; pair_a_valid_r <= 0; pair_b_valid_r <= 0;
            pair_a_r[0] <= 0; pair_a_r[1] <= 0;
            pair_b_r[0] <= 0; pair_b_r[1] <= 0;
            outstanding_reads_r <= 0;
            busy <= 0; done <= 0; error <= 0; error_code <= ERR_NONE;
            result <= 0; cycle_count <= 0; element_count <= 0;
        end else begin
            done <= 0;
            if ((state_r == ST_IDLE) && start) cycle_count <= 0;
            else if (busy) cycle_count <= cycle_count + 1'b1;

            case ({read_fire, response_fire})
                2'b10: if (outstanding_reads_r < 2)
                           outstanding_reads_r <= outstanding_reads_r + 1'b1;
                       else outstanding_reads_r <= outstanding_reads_r;
                2'b01: if (outstanding_reads_r != 0)
                           outstanding_reads_r <= outstanding_reads_r - 1'b1;
                       else outstanding_reads_r <= outstanding_reads_r;
                default: outstanding_reads_r <= outstanding_reads_r;
            endcase

            if (read_fire) begin
                if (!request_is_b_r) begin
                    request_is_b_r <= 1'b1;
                    pair_busy_r[request_slot] <= 1'b1;
                end else begin
                    request_is_b_r <= 1'b0;
                    request_word_index_r <= request_word_index_r + 1'b1;
                end
            end

            if (response_fire) begin
                if (!response_is_b_r) begin
                    if (!spad_parity_error) begin
                        pair_a_r[response_slot] <= spad_rdata;
                        pair_a_valid_r[response_slot] <= 1'b1;
                    end
                    response_is_b_r <= 1'b1;
                end else begin
                    if (!spad_parity_error) begin
                        pair_b_r[response_slot] <= spad_rdata;
                        pair_b_valid_r[response_slot] <= 1'b1;
                    end
                    response_is_b_r <= 1'b0;
                    response_word_index_r <= response_word_index_r + 1'b1;
                end
            end

            if (compute_pair_last) begin
                pair_busy_r[compute_slot] <= 1'b0;
                pair_a_valid_r[compute_slot] <= 1'b0;
                pair_b_valid_r[compute_slot] <= 1'b0;
            end

            if ((state_r == ST_RUN) && failure_active &&
                (pending_error_r == ERR_NONE)) begin
                if (response_parity_failure) begin
                    pending_error_r <= ERR_PARITY;
                    memory_error_cutoff_r <= memory_error_cutoff_now;
                    memory_error_cutoff_valid_r <= 1'b1;
                end else if (read_protection_failure) begin
                    pending_error_r <= ERR_PROTECTION;
                    memory_error_cutoff_r <= memory_error_cutoff_now;
                    memory_error_cutoff_valid_r <= 1'b1;
                end else if (write_protection_failure)
                    pending_error_r <= ERR_PROTECTION;
                else if (abort)
                    pending_error_r <= ERR_ABORT;
                else if (watchdog_expired)
                    pending_error_r <= ERR_WATCHDOG;
            end

            case (state_r)
                ST_IDLE: if (start) begin
                    format_fp16_r <= format_fp16;
                    src0_r <= src0_base; src1_r <= src1_base;
                    dst_r <= dst_base; length_r <= length;
                    watchdog_r <= watchdog_limit;
                    request_word_index_r <= 0; response_word_index_r <= 0;
                    request_is_b_r <= 0; response_is_b_r <= 0;
                    element_index_r <= 0; outstanding_reads_r <= 0;
                    memory_error_cutoff_r <= 0;
                    memory_error_cutoff_valid_r <= 1'b0;
                    pair_busy_r <= 0; pair_a_valid_r <= 0;
                    pair_b_valid_r <= 0; pending_error_r <= ERR_NONE;
                    element_count <= 0; result <= 0;
                    error <= 0; error_code <= ERR_NONE; busy <= 1;
                    if ((length == 0) || (src0_base[1:0] != 0) ||
                        (src1_base[1:0] != 0) || (dst_base[1:0] != 0)) begin
                        pending_error_r <= ERR_CONFIG;
                        state_r <= ST_ERROR;
                    end else state_r <= ST_RUN;
                end
                ST_RUN: begin
                    if (compute_fire) begin
                        element_count <= element_count + 1'b1;
                        // Keep the final writeback transition explicitly
                        // disjoint from a fault/cancel observed on this
                        // cycle.  The drain/error transition below then owns
                        // the command until accepted reads have retired.
                        if (last_element) begin
                            if ((pending_error_r == ERR_NONE) && !failure_active)
                                state_r <= ST_WRITE;
                        end else begin
                            element_index_r <= element_index_r + 1'b1;
                        end
                    end
                    if (failure_active && (outstanding_after == 0) &&
                        (immediate_cancel ||
                         (!pending_memory_error && !first_memory_error_now) ||
                         (pending_memory_error &&
                          (element_index_r >= memory_error_cutoff_r)) ||
                         (first_memory_error_now &&
                          (element_index_r >= memory_error_cutoff_now))))
                        state_r <= ST_ERROR;
                end
                ST_WRITE: if (spad_ready) begin
                    if (spad_protection_error) begin
                        pending_error_r <= ERR_PROTECTION;
                        state_r <= ST_ERROR;
                    end else begin
                        result <= accumulator_bits;
                        state_r <= ST_DONE;
                    end
                end
                ST_DONE: begin
                    busy <= 0; done <= 1; error <= 0;
                    error_code <= ERR_NONE; state_r <= ST_IDLE;
                end
                ST_ERROR: begin
                    busy <= 0; done <= 1; error <= 1;
                    error_code <= pending_error_r; state_r <= ST_IDLE;
                end
                default: state_r <= ST_IDLE;
            endcase
        end
    end
endmodule
