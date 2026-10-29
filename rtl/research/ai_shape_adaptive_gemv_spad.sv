`timescale 1ns / 1ps

// Research integration wrapper for the shape-adaptive GEMV kernel.
// Inputs and outputs live in the same four-bank behavioral/XPM scratchpad
// used by the product path. The wrapper intentionally serializes scalar
// 32-bit requests through the production SPAD arbiter; this makes the memory
// cost visible instead of assuming an ideal conflict-free dual-operand feed.
module ai_shape_adaptive_gemv_spad #(
    parameter integer MAX_M = 16,
    parameter integer MAX_N = 16,
    parameter integer MAX_K = 128,
    parameter integer SPAD_WORDS_PER_BANK = 32768
) (
    input wire clk,
    input wire resetn,

    input wire host_valid,
    input wire host_write,
    input wire [31:0] host_addr,
    input wire [31:0] host_wdata,
    input wire [3:0] host_wstrb,
    output wire [31:0] host_rdata,
    output wire host_error,

    input wire start,
    input wire abort,
    input wire [1:0] mode_request,
    input wire prefetch_enable,
    input wire [4:0] m_size,
    input wire [4:0] n_size,
    input wire [7:0] k_size,
    input wire [31:0] a_base,
    input wire [31:0] b_base,
    input wire [31:0] result_base,

    // A second scheduler client models concurrent DMA traffic. It is routed
    // through the real round-robin arbiter and the same SPAD port.
    input wire contender_valid,
    input wire contender_write,
    input wire [31:0] contender_addr,
    input wire [31:0] contender_wdata,
    output wire contender_ready,
    output wire contender_rsp_valid,
    output wire [31:0] contender_rsp_rdata,
    output wire contender_rsp_error,

    output reg busy,
    output reg done,
    output reg error,
    output wire selected_gemv,
    output wire [4:0] selected_k_parallel,
    output reg [31:0] elapsed_cycles,
    output reg [31:0] spad_read_bytes,
    output reg [31:0] spad_write_bytes,
    output reg [31:0] arbiter_wait_cycles
);
    localparam [1:0] MODE_BASELINE = 2'd0;
    localparam [1:0] MODE_GEMV = 2'd1;
    localparam [1:0] MODE_STATIC = 2'd2;

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_READ_REQ   = 3'd1;
    localparam [2:0] ST_READ_WAIT  = 3'd2;
    localparam [2:0] ST_CORE_START = 3'd3;
    localparam [2:0] ST_CORE_WAIT  = 3'd4;
    localparam [2:0] ST_WRITE     = 3'd5;
    localparam [2:0] ST_FINISH    = 3'd6;

    localparam integer A_WIDTH = MAX_M*MAX_K*8;
    localparam integer B_WIDTH = MAX_K*MAX_N*8;
    localparam integer R_WIDTH = MAX_M*MAX_N*64;
    localparam integer SPAD_BYTES = 4*SPAD_WORDS_PER_BANK*4;

    reg [2:0] state_r;
    reg [4:0] m_r, n_r;
    reg [7:0] k_r;
    reg [31:0] a_base_r, b_base_r, result_base_r;
    reg [15:0] a_byte_count_r, b_byte_count_r, output_word_count_r;
    reg [15:0] a_words_r, b_words_r, total_read_words_r;
    reg [15:0] read_word_index_r;
    reg [15:0] output_word_index_r;
    reg abort_pending_r;
    reg [A_WIDTH-1:0] a_operand_r;
    reg [B_WIDTH-1:0] b_operand_r;

    wire kernel_start = (state_r == ST_CORE_START) && !abort;
    wire kernel_abort = abort || abort_pending_r;
    wire kernel_busy, kernel_done, kernel_error;
    wire [R_WIDTH-1:0] kernel_results;
    wire [31:0] kernel_cycles, kernel_macs;
    wire [31:0] kernel_output_index = output_word_index_r >> 1;
    wire [31:0] kernel_result_element_index =
        (kernel_output_index / n_r)*MAX_N + (kernel_output_index % n_r);
    wire [5:0] kernel_result_bit_index = output_word_index_r[0] ? 6'd32 : 6'd0;
    wire [31:0] core_wdata = kernel_results[
        kernel_result_element_index*64 + kernel_result_bit_index +: 32];

    wire core_valid = ((state_r == ST_READ_REQ) && !abort) ||
                      ((state_r == ST_WRITE) && !abort && !abort_pending_r);
    wire core_write = (state_r == ST_WRITE);
    wire [31:0] core_addr = (state_r == ST_WRITE) ?
                            (result_base_r + ({16'd0,output_word_index_r} << 2)) :
                            ((read_word_index_r < a_words_r) ?
                             (a_base_r + ({16'd0,read_word_index_r} << 2)) :
                             (b_base_r + ({16'd0,(read_word_index_r-a_words_r)} << 2)));
    wire [31:0] core_wdata_mux = core_write ? core_wdata : 32'd0;
    wire core_ready;
    wire [31:0] arb_rsp_rdata;
    wire arb_rsp_error;
    wire arb_rsp_valid;
    wire [2:0] arb_rsp_client;
    wire [2:0] request_client_unused;
    wire [3:0] cnm_ready_unused, cnm_rsp_valid_unused;
    wire desc_ready_unused, cpl_ready_unused, core_line_ready_unused;
    wire banked_ready_unused, dma_line_ready_unused;
    wire spad_valid, spad_write, spad_line_valid, spad_line_write;
    wire spad_banked_valid;
    wire [31:0] spad_addr, spad_wdata, spad_line_addr, spad_banked_addr;
    wire [127:0] spad_line_wdata;
    wire [15:0] spad_line_wstrb;
    wire [3:0] spad_cnm_valid;
    wire [31:0] spad_cnm_addr0, spad_cnm_addr1, spad_cnm_addr2, spad_cnm_addr3;
    wire [31:0] spad_rdata;
    wire spad_error, spad_parity_error, spad_line_error;
    wire [3:0] spad_line_parity_error;
    wire [127:0] spad_line_rdata;
    wire [31:0] spad_banked_data0, spad_banked_data1;
    wire [31:0] spad_banked_data2, spad_banked_data3;
    wire [3:0] spad_banked_parity_error;
    wire [31:0] spad_cnm_data0, spad_cnm_data1, spad_cnm_data2, spad_cnm_data3;
    wire [3:0] spad_cnm_parity_error;
    wire [3:0] dma_ready_unused;
    wire [31:0] compute_rdata;
    wire compute_parity_error;
    wire [31:0] host_unused;
    wire host_parity_unused;
    wire [127:0] line_unused;
    wire [3:0] line_parity_unused;
    wire line_error_unused;
    wire [31:0] banked_unused0, banked_unused1, banked_unused2, banked_unused3;
    wire [3:0] banked_parity_unused;
    wire [31:0] cnm_unused0, cnm_unused1, cnm_unused2, cnm_unused3;
    wire [3:0] cnm_parity_unused;
    wire [31:0] total_bytes_wide_a = {16'd0,m_size} * {16'd0,k_size};
    wire [31:0] total_bytes_wide_b = {16'd0,k_size} * {16'd0,n_size};
    wire [31:0] total_bytes_wide_r = {16'd0,m_size} * {16'd0,n_size} * 32'd8;
    wire [31:0] a_span = (total_bytes_wide_a + 32'd3) & 32'hffff_fffc;
    wire [31:0] b_span = (total_bytes_wide_b + 32'd3) & 32'hffff_fffc;
    wire [31:0] r_span = total_bytes_wide_r;
    wire [32:0] a_end = {1'b0,a_base} + {1'b0,a_span};
    wire [32:0] b_end = {1'b0,b_base} + {1'b0,b_span};
    wire [32:0] r_end = {1'b0,result_base} + {1'b0,r_span};
    wire ranges_overlap = ((a_base < b_end) && (b_base < a_end)) ||
                          ((a_base < r_end) && (result_base < a_end)) ||
                          ((b_base < r_end) && (result_base < b_end));
    wire start_config_error = (m_size == 0 || m_size > MAX_M ||
                               n_size == 0 || n_size > MAX_N ||
                               k_size == 0 || k_size > MAX_K ||
                               |a_base[1:0] || |b_base[1:0] ||
                               |result_base[1:0] ||
                               a_end > SPAD_BYTES || b_end > SPAD_BYTES ||
                               r_end > SPAD_BYTES || ranges_overlap);

    ai_shape_adaptive_gemv #(
        .MAX_M(MAX_M), .MAX_N(MAX_N), .MAX_K(MAX_K), .MAC_COUNT(256)
    ) u_kernel (
        .clk(clk), .resetn(resetn), .start(kernel_start),
        .abort(kernel_abort), .mode_request(mode_request),
        .prefetch_enable(prefetch_enable), .m_size(m_r), .n_size(n_r),
        .k_size(k_r), .a_operand(a_operand_r), .b_operand(b_operand_r),
        .busy(kernel_busy), .done(kernel_done), .error(kernel_error),
        .selected_gemv(selected_gemv),
        .selected_k_parallel(selected_k_parallel),
        .cycle_count(kernel_cycles), .useful_mac_count(kernel_macs),
        .result_vector(kernel_results)
    );

    ai_spad_arbiter u_arbiter (
        .clk(clk), .resetn(resetn),
        .desc_valid(1'b0), .desc_write(1'b0), .desc_addr(32'd0),
        .desc_wdata(32'd0), .desc_ready(desc_ready_unused),
        .cpl_valid(1'b0), .cpl_write(1'b0), .cpl_addr(32'd0),
        .cpl_wdata(32'd0), .cpl_ready(cpl_ready_unused),
        .core_valid(core_valid), .core_write(core_write),
        .core_addr(core_addr), .core_wdata(core_wdata_mux),
        .core_ready(core_ready),
        .core_line_valid(1'b0), .core_line_write(1'b0),
        .core_line_addr(32'd0), .core_line_wdata(128'd0),
        .core_line_wstrb(16'd0), .core_line_ready(core_line_ready_unused),
        .banked_valid(1'b0), .banked_addr(32'd0),
        .banked_ready(banked_ready_unused), .cnm_valid(4'd0),
        .cnm_addr0(32'd0), .cnm_addr1(32'd0), .cnm_addr2(32'd0),
        .cnm_addr3(32'd0), .cnm_ready(cnm_ready_unused),
        .dma_valid(contender_valid), .dma_write(contender_write),
        .dma_addr(contender_addr), .dma_wdata(contender_wdata),
        .dma_ready(contender_ready), .dma_line_valid(1'b0),
        .dma_line_write(1'b0), .dma_line_addr(32'd0),
        .dma_line_wdata(128'd0), .dma_line_wstrb(16'd0),
        .dma_line_ready(dma_line_ready_unused),
        .spad_valid(spad_valid), .spad_write(spad_write),
        .spad_addr(spad_addr), .spad_wdata(spad_wdata),
        .spad_line_valid(spad_line_valid), .spad_line_write(spad_line_write),
        .spad_line_addr(spad_line_addr), .spad_line_wdata(spad_line_wdata),
        .spad_line_wstrb(spad_line_wstrb),
        .spad_banked_valid(spad_banked_valid),
        .spad_banked_addr(spad_banked_addr), .spad_cnm_valid(spad_cnm_valid),
        .spad_cnm_addr0(spad_cnm_addr0), .spad_cnm_addr1(spad_cnm_addr1),
        .spad_cnm_addr2(spad_cnm_addr2), .spad_cnm_addr3(spad_cnm_addr3),
        .spad_rdata(spad_rdata), .spad_error(spad_error),
        .spad_parity_error(spad_parity_error),
        .spad_line_error(spad_line_error),
        .spad_line_parity_error(spad_line_parity_error),
        .rsp_valid(arb_rsp_valid), .rsp_client(arb_rsp_client),
        .rsp_is_line(), .cnm_rsp_valid(cnm_rsp_valid_unused),
        .request_client(request_client_unused), .rsp_rdata(arb_rsp_rdata),
        .rsp_error(arb_rsp_error)
    );

    ai_scratchpad #(
        .BANKS(4), .WORDS_PER_BANK(SPAD_WORDS_PER_BANK)
    ) u_spad (
        .clk(clk), .resetn(resetn),
        .host_valid(host_valid), .host_write(host_write),
        .host_addr(host_addr), .host_wdata(host_wdata),
        .host_wstrb(host_wstrb), .host_rdata(host_rdata),
        .host_error(host_error), .host_parity_error(host_parity_unused),
        .compute_valid(spad_valid), .compute_write(spad_write),
        .compute_addr(spad_addr), .compute_wdata(spad_wdata),
        .compute_rdata(compute_rdata),
        .compute_parity_error(compute_parity_error),
        .line_valid(spad_line_valid), .line_write(spad_line_write),
        .line_addr(spad_line_addr), .line_wdata(spad_line_wdata),
        .line_wstrb(spad_line_wstrb), .line_rdata(spad_line_rdata),
        .line_parity_error(spad_line_parity_error),
        .line_error(spad_line_error),
        .banked_read_valid(spad_banked_valid),
        .banked_addr(spad_banked_addr), .banked_data0(spad_banked_data0),
        .banked_data1(spad_banked_data1), .banked_data2(spad_banked_data2),
        .banked_data3(spad_banked_data3),
        .banked_parity_error(spad_banked_parity_error),
        .cnm_read_valid(spad_cnm_valid), .cnm_addr0(spad_cnm_addr0),
        .cnm_addr1(spad_cnm_addr1), .cnm_addr2(spad_cnm_addr2),
        .cnm_addr3(spad_cnm_addr3), .cnm_data0(spad_cnm_data0),
        .cnm_data1(spad_cnm_data1), .cnm_data2(spad_cnm_data2),
        .cnm_data3(spad_cnm_data3), .cnm_parity_error(spad_cnm_parity_error)
    );

    assign spad_rdata = compute_rdata;
    assign spad_parity_error = compute_parity_error;
    assign spad_error = 1'b0;
    assign contender_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd4);
    assign contender_rsp_rdata = arb_rsp_rdata;
    assign contender_rsp_error = contender_rsp_valid && arb_rsp_error;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r <= ST_IDLE;
            m_r <= 0;
            n_r <= 0;
            k_r <= 0;
            a_base_r <= 0;
            b_base_r <= 0;
            result_base_r <= 0;
            a_byte_count_r <= 0;
            b_byte_count_r <= 0;
            output_word_count_r <= 0;
            a_words_r <= 0;
            b_words_r <= 0;
            total_read_words_r <= 0;
            read_word_index_r <= 0;
            output_word_index_r <= 0;
            abort_pending_r <= 0;
            a_operand_r <= {A_WIDTH{1'b0}};
            b_operand_r <= {B_WIDTH{1'b0}};
            busy <= 0;
            done <= 0;
            error <= 0;
            elapsed_cycles <= 0;
            spad_read_bytes <= 0;
            spad_write_bytes <= 0;
            arbiter_wait_cycles <= 0;
        end else begin
            done <= 0;
            if (busy) begin
                elapsed_cycles <= elapsed_cycles + 1;
                if (core_valid && !core_ready)
                    arbiter_wait_cycles <= arbiter_wait_cycles + 1;
            end

            case (state_r)
                ST_IDLE: begin
                    busy <= 0;
                    abort_pending_r <= 0;
                    if (start) begin
                        error <= 0;
                        elapsed_cycles <= 0;
                        spad_read_bytes <= 0;
                        spad_write_bytes <= 0;
                        arbiter_wait_cycles <= 0;
                        if (start_config_error ||
                            (mode_request != MODE_BASELINE &&
                             mode_request != MODE_GEMV && mode_request != MODE_STATIC)) begin
                            error <= 1;
                            done <= 1;
                        end else if (abort) begin
                            error <= 1;
                            done <= 1;
                        end else begin
                            m_r <= m_size;
                            n_r <= n_size;
                            k_r <= k_size;
                            a_base_r <= a_base;
                            b_base_r <= b_base;
                            result_base_r <= result_base;
                            a_byte_count_r <= total_bytes_wide_a[15:0];
                            b_byte_count_r <= total_bytes_wide_b[15:0];
                            output_word_count_r <= (total_bytes_wide_r + 3) >> 2;
                            a_words_r <= (total_bytes_wide_a + 3) >> 2;
                            b_words_r <= (total_bytes_wide_b + 3) >> 2;
                            total_read_words_r <= ((total_bytes_wide_a + 3) >> 2) +
                                                  ((total_bytes_wide_b + 3) >> 2);
                            read_word_index_r <= 0;
                            output_word_index_r <= 0;
                            a_operand_r <= {A_WIDTH{1'b0}};
                            b_operand_r <= {B_WIDTH{1'b0}};
                            abort_pending_r <= 0;
                            busy <= 1;
                            state_r <= ST_READ_REQ;
                        end
                    end
                end
                ST_READ_REQ: begin
                    if (abort) begin
                        error <= 1;
                        busy <= 0;
                        done <= 1;
                        state_r <= ST_IDLE;
                    end else if (core_ready) begin
                        spad_read_bytes <= spad_read_bytes + 4;
                        state_r <= ST_READ_WAIT;
                    end
                end
                ST_READ_WAIT: begin
                    if (abort)
                        abort_pending_r <= 1;
                    if (arb_rsp_valid && arb_rsp_client == 3'd2) begin
                        if (abort || abort_pending_r || arb_rsp_error) begin
                            error <= 1;
                            busy <= 0;
                            done <= 1;
                            state_r <= ST_IDLE;
                            abort_pending_r <= 0;
                        end else begin
                            if (read_word_index_r < a_words_r) begin
                                if (((read_word_index_r*4)+0) < a_byte_count_r)
                                    a_operand_r[((((read_word_index_r*4)+0)/k_r)*MAX_K + (((read_word_index_r*4)+0)%k_r))*8 +: 8] <= arb_rsp_rdata[7:0];
                                if (((read_word_index_r*4)+1) < a_byte_count_r)
                                    a_operand_r[((((read_word_index_r*4)+1)/k_r)*MAX_K + (((read_word_index_r*4)+1)%k_r))*8 +: 8] <= arb_rsp_rdata[15:8];
                                if (((read_word_index_r*4)+2) < a_byte_count_r)
                                    a_operand_r[((((read_word_index_r*4)+2)/k_r)*MAX_K + (((read_word_index_r*4)+2)%k_r))*8 +: 8] <= arb_rsp_rdata[23:16];
                                if (((read_word_index_r*4)+3) < a_byte_count_r)
                                    a_operand_r[((((read_word_index_r*4)+3)/k_r)*MAX_K + (((read_word_index_r*4)+3)%k_r))*8 +: 8] <= arb_rsp_rdata[31:24];
                            end else begin
                                if ((((read_word_index_r-a_words_r)*4)+0) < b_byte_count_r)
                                    b_operand_r[((((read_word_index_r-a_words_r)*4)+0)/n_r*MAX_N + (((read_word_index_r-a_words_r)*4)+0)%n_r)*8 +: 8] <= arb_rsp_rdata[7:0];
                                if ((((read_word_index_r-a_words_r)*4)+1) < b_byte_count_r)
                                    b_operand_r[((((read_word_index_r-a_words_r)*4)+1)/n_r*MAX_N + (((read_word_index_r-a_words_r)*4)+1)%n_r)*8 +: 8] <= arb_rsp_rdata[15:8];
                                if ((((read_word_index_r-a_words_r)*4)+2) < b_byte_count_r)
                                    b_operand_r[((((read_word_index_r-a_words_r)*4)+2)/n_r*MAX_N + (((read_word_index_r-a_words_r)*4)+2)%n_r)*8 +: 8] <= arb_rsp_rdata[23:16];
                                if ((((read_word_index_r-a_words_r)*4)+3) < b_byte_count_r)
                                    b_operand_r[((((read_word_index_r-a_words_r)*4)+3)/n_r*MAX_N + (((read_word_index_r-a_words_r)*4)+3)%n_r)*8 +: 8] <= arb_rsp_rdata[31:24];
                            end
                            if (read_word_index_r + 1 >= total_read_words_r)
                                state_r <= ST_CORE_START;
                            else begin
                                read_word_index_r <= read_word_index_r + 1;
                                state_r <= ST_READ_REQ;
                            end
                        end
                    end
                end
                ST_CORE_START: begin
                    if (abort) begin
                        error <= 1;
                        busy <= 0;
                        done <= 1;
                        state_r <= ST_IDLE;
                    end else begin
                        state_r <= ST_CORE_WAIT;
                    end
                end
                ST_CORE_WAIT: begin
                    if (kernel_done) begin
                        if (abort || kernel_error) begin
                            error <= 1;
                            busy <= 0;
                            done <= 1;
                            state_r <= ST_IDLE;
                        end else begin
                            output_word_index_r <= 0;
                            state_r <= ST_WRITE;
                        end
                    end
                end
                ST_WRITE: begin
                    if (abort) begin
                        error <= 1;
                        busy <= 0;
                        done <= 1;
                        state_r <= ST_IDLE;
                    end else if (core_ready) begin
                        spad_write_bytes <= spad_write_bytes + 4;
                        if (output_word_index_r + 1 >= output_word_count_r) begin
                            state_r <= ST_FINISH;
                        end else begin
                            output_word_index_r <= output_word_index_r + 1;
                        end
                    end
                end
                ST_FINISH: begin
                    busy <= 0;
                    done <= 1;
                    state_r <= ST_IDLE;
                end
                default: begin
                    error <= 1;
                    busy <= 0;
                    done <= 1;
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
