`timescale 1ns / 1ps

// Single-lane, ordered BF16/FP16 dot product with a non-fused FP32 accumulator.
// Packed words use format[15:0] for the even element and format[31:16] for odd.
// At most one scratchpad read is outstanding; each A word is followed by its
// B word, then the valid lanes are accumulated in increasing element order.
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
    localparam [3:0] ERR_NONE = 4'd0, ERR_CONFIG = 4'd1,
                     ERR_ABORT = 4'd3, ERR_WATCHDOG = 4'd4,
                     ERR_PARITY = 4'd5, ERR_PROTECTION = 4'd6;
    localparam [3:0] ST_IDLE=0, ST_READ_A=1, ST_WAIT_A=2,
                     ST_READ_B=3, ST_WAIT_B=4, ST_CALC=5,
                     ST_WRITE=6, ST_DONE=7, ST_ERROR=8;

    reg [3:0] state_r;
    reg [31:0] src0_r, src1_r, dst_r, watchdog_r;
    reg [15:0] length_r;
    reg [15:0] word_index_r, element_index_r;
    reg [31:0] a_word_r, b_word_r;
    reg format_fp16_r;
    reg [3:0] pending_error_r;
    reg read_protection_error_r;

    // Once the final output request is presented, ready/valid requires it to
    // remain stable until acceptance. Treat entering ST_WRITE as the commit
    // boundary: abort/watchdog can cancel computation before it, but cannot
    // turn an accepted output write into a failed completion.
    wire watchdog_expired = busy && (state_r != ST_WRITE) &&
                            (watchdog_r != 0) &&
                            (cycle_count >= watchdog_r);
    wire [15:0] elem_a = element_index_r[0] ? a_word_r[31:16] : a_word_r[15:0];
    wire [15:0] elem_b = element_index_r[0] ? b_word_r[31:16] : b_word_r[15:0];
    wire [31:0] bf16_product_bits;
    wire [31:0] fp16_product_bits;
    wire [31:0] product_bits = format_fp16_r ? fp16_product_bits :
                                                 bf16_product_bits;
    wire [31:0] accumulator_bits;
    wire last_element = (element_index_r == length_r - 16'd1);

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
        .accumulate(state_r == ST_CALC && pending_error_r == ERR_NONE &&
                    !abort && !watchdog_expired),
        .product_bits(product_bits), .accumulator_bits(accumulator_bits)
    );

    // Suppress an unaccepted request immediately when cancellation is visible.
    // Once accepted, the corresponding WAIT state is retained until response.
    always @* begin
        spad_valid = 1'b0;
        spad_write = 1'b0;
        spad_addr = 32'b0;
        spad_wdata = 32'b0;
        case (state_r)
            ST_READ_A: begin
                if ((pending_error_r == ERR_NONE) && !abort &&
                    !watchdog_expired) begin
                    spad_valid = 1'b1;
                    spad_addr = src0_r + ({word_index_r, 2'b00});
                end
            end
            ST_READ_B: begin
                if ((pending_error_r == ERR_NONE) && !abort &&
                    !watchdog_expired) begin
                    spad_valid = 1'b1;
                    spad_addr = src1_r + ({word_index_r, 2'b00});
                end
            end
            ST_WRITE: begin
                spad_valid = 1'b1;
                spad_write = 1'b1;
                spad_addr = dst_r;
                spad_wdata = accumulator_bits;
            end
            default: begin end
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r <= ST_IDLE;
            src0_r <= 0; src1_r <= 0; dst_r <= 0; watchdog_r <= 0;
            length_r <= 0; word_index_r <= 0; element_index_r <= 0;
            a_word_r <= 0; b_word_r <= 0;
            format_fp16_r <= 1'b0;
            pending_error_r <= ERR_NONE; read_protection_error_r <= 1'b0;
            busy <= 1'b0; done <= 1'b0; error <= 1'b0;
            error_code <= ERR_NONE; result <= 0; cycle_count <= 0;
            element_count <= 0;
        end else begin
            done <= 1'b0;
            if ((state_r == ST_IDLE) && start) cycle_count <= 0;
            else if (busy) cycle_count <= cycle_count + 1'b1;

            // Cancellation/errors stop new traffic. If a read was accepted,
            // retain its WAIT state and consume exactly that response first.
            if (busy && (state_r != ST_WRITE) &&
                (abort || watchdog_expired) &&
                (pending_error_r == ERR_NONE))
                pending_error_r <= abort ? ERR_ABORT : ERR_WATCHDOG;

            case (state_r)
                ST_IDLE: if (start) begin
                    format_fp16_r <= format_fp16;
                    src0_r <= src0_base; src1_r <= src1_base;
                    dst_r <= dst_base; length_r <= length;
                    watchdog_r <= watchdog_limit;
                    word_index_r <= 0; element_index_r <= 0;
                    pending_error_r <= ERR_NONE; element_count <= 0;
                    result <= 0; error <= 0; error_code <= ERR_NONE;
                    busy <= 1'b1;
                    if ((length == 0) || (src0_base[1:0] != 0) ||
                        (src1_base[1:0] != 0) || (dst_base[1:0] != 0)) begin
                        pending_error_r <= ERR_CONFIG;
                        state_r <= ST_ERROR;
                    end else state_r <= ST_READ_A;
                end
                ST_READ_A: begin
                    if ((pending_error_r != ERR_NONE) || abort ||
                        watchdog_expired) begin
                        state_r <= ST_ERROR;
                    end else if (spad_ready) begin
                        read_protection_error_r <= spad_protection_error;
                        if (spad_protection_error) pending_error_r <= ERR_PROTECTION;
                        state_r <= ST_WAIT_A;
                    end
                end
                ST_WAIT_A: if (spad_rsp_valid) begin
                    if (pending_error_r != ERR_NONE || abort || watchdog_expired ||
                        spad_parity_error || read_protection_error_r) begin
                        if (pending_error_r == ERR_NONE)
                            pending_error_r <= spad_parity_error ? ERR_PARITY :
                                               (read_protection_error_r ? ERR_PROTECTION :
                                                (abort ? ERR_ABORT : ERR_WATCHDOG));
                        state_r <= ST_ERROR;
                    end else begin
                        a_word_r <= spad_rdata;
                        state_r <= ST_READ_B;
                    end
                end
                ST_READ_B: begin
                    if ((pending_error_r != ERR_NONE) || abort ||
                        watchdog_expired) begin
                        state_r <= ST_ERROR;
                    end else if (spad_ready) begin
                        read_protection_error_r <= spad_protection_error;
                        if (spad_protection_error) pending_error_r <= ERR_PROTECTION;
                        state_r <= ST_WAIT_B;
                    end
                end
                ST_WAIT_B: if (spad_rsp_valid) begin
                    if (pending_error_r != ERR_NONE || abort || watchdog_expired ||
                        spad_parity_error || read_protection_error_r) begin
                        if (pending_error_r == ERR_NONE)
                            pending_error_r <= spad_parity_error ? ERR_PARITY :
                                               (read_protection_error_r ? ERR_PROTECTION :
                                                (abort ? ERR_ABORT : ERR_WATCHDOG));
                        state_r <= ST_ERROR;
                    end else begin
                        b_word_r <= spad_rdata;
                        state_r <= ST_CALC;
                    end
                end
                ST_CALC: begin
                    if (abort || watchdog_expired || pending_error_r != ERR_NONE)
                        state_r <= ST_ERROR;
                    else begin
                        element_count <= element_count + 1'b1;
                        if (last_element) begin
                            // Accumulator updates on this edge; write state
                            // begins next cycle so it sees the updated sum.
                            state_r <= ST_WRITE;
                        end else if (element_index_r[0]) begin
                            word_index_r <= word_index_r + 1'b1;
                            element_index_r <= element_index_r + 1'b1;
                            state_r <= ST_READ_A;
                        end else begin
                            element_index_r <= element_index_r + 1'b1;
                            state_r <= ST_CALC;
                        end
                    end
                end
                ST_WRITE: begin
                    if (spad_ready) begin
                        if (spad_protection_error) begin
                            pending_error_r <= ERR_PROTECTION;
                            state_r <= ST_ERROR;
                        end else begin
                            result <= accumulator_bits;
                            state_r <= ST_DONE;
                        end
                    end
                end
                ST_DONE: begin
                    busy <= 1'b0; done <= 1'b1; error <= 1'b0;
                    error_code <= ERR_NONE; state_r <= ST_IDLE;
                end
                ST_ERROR: begin
                    busy <= 1'b0; done <= 1'b1; error <= 1'b1;
                    error_code <= pending_error_r;
                    state_r <= ST_IDLE;
                end
                default: state_r <= ST_IDLE;
            endcase
        end
    end
endmodule
