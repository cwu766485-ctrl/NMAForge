`timescale 1ns / 1ps

// Round 34 SFU streaming fast path.
//
// Executes the hot Transformer SFU opcodes with multiple outstanding reads on
// the existing 32-bit scheduler SPAD port.  ai_compute_spad_mux and
// ai_spad_arbiter already accept one core request per cycle and return read
// data in request order two cycles later; the legacy FSM waits for each
// response before issuing the next request.  No port, arbiter, descriptor or
// numeric contract changes: every output word is bit-identical to the legacy
// ai_tensor_sfu_core sequence (the parent selects this path only for
// configurations whose legacy semantics are reproduced exactly).
//
//   0x34 RESIDUAL_I32   x/y interleaved reads, one write per element
//   0x35 GELU_Q8_8      one read, one write per element
//   0x36 REQUANT_I8     one read per element; one write per element or per
//                       packed word (linear or Matrix-A tile order)
//   0x38 LAYERNORM_Q15  x read once into the row cache; gamma/beta prefetched
//                       while mean/variance/sqrt/reciprocal run; one write
//   0x32/0x39 SOFTMAX   x read once into the row cache; one exact row
//                       reciprocal replaces the per-element iterative divide
//
// Softmax quotient: q = floor(a / s) with a = exp << 15 <= 2^30 and
// 0 < s <= 256 * 32768 = 2^23.  With r = floor(2^56 / s), the estimate
// floor(a * r / 2^56) is q or q-1 (error < 2^30 / 2^56 < 1 / s), and one
// (q_est + 1) * s <= a test restores the exact legacy quotient.
module ai_tensor_sfu_stream #(
    parameter integer CACHE_DEPTH = 256,
    parameter integer CACHE_AW = 8
)(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        abort,
    input  wire [7:0]  op_mode,
    input  wire [31:0] src0_base,
    input  wire [31:0] src1_base,
    input  wire [31:0] beta_base,
    input  wire        beta_enable,
    input  wire        pack_enable,
    input  wire        pack_tile_a,
    input  wire [31:0] dst_base,
    input  wire [15:0] length,
    input  wire [15:0] n_size,
    input  wire [4:0]  scale_shift,
    input  wire [31:0] epsilon,
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

    // Shared iterative divider/square root owned by the parent core.
    output reg         div_start,
    output reg         div_accelerate,
    output reg  [63:0] div_dividend,
    output reg  [63:0] div_divisor,
    input  wire        div_done,
    input  wire        div_error,
    input  wire [63:0] div_quotient,
    output reg         sqrt_start,
    output reg  [63:0] sqrt_radicand,
    input  wire        sqrt_done,
    input  wire [31:0] sqrt_root,

    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [31:0] result,
    output reg  [31:0] cycle_count,
    output reg  [31:0] element_count
);
    localparam [7:0] OP_SOFTMAX_Q15        = 8'h32;
    localparam [7:0] OP_RESIDUAL_I32       = 8'h34;
    localparam [7:0] OP_GELU_Q8_8          = 8'h35;
    localparam [7:0] OP_REQUANT_I8         = 8'h36;
    localparam [7:0] OP_LAYERNORM_Q15      = 8'h38;
    localparam [7:0] OP_CAUSAL_SOFTMAX_Q15 = 8'h39;

    localparam [3:0] ERR_ABORT      = 4'd3;
    localparam [3:0] ERR_WATCHDOG   = 4'd4;
    localparam [3:0] ERR_PARITY     = 4'd5;
    localparam [3:0] ERR_PROTECTION = 4'd6;
    localparam [3:0] ERR_NUMERIC    = 4'd8;

    localparam [3:0] P_IDLE     = 4'd0;
    localparam [3:0] P_STREAM   = 4'd1;  // elementwise streaming
    localparam [3:0] P_XREAD    = 4'd2;  // LN/Softmax x row read
    localparam [3:0] P_LN_MEAN  = 4'd3;
    localparam [3:0] P_LN_VAR   = 4'd4;
    localparam [3:0] P_LN_MSQ   = 4'd5;
    localparam [3:0] P_LN_SQRT  = 4'd6;
    localparam [3:0] P_LN_INV   = 4'd7;
    localparam [3:0] P_SM_SUM   = 4'd8;
    localparam [3:0] P_SM_RECIP = 4'd9;
    localparam [3:0] P_OUT      = 4'd10; // cached-row output pipeline
    localparam [3:0] P_DRAIN    = 4'd11;
    localparam [3:0] P_FINISH   = 4'd12;
    localparam integer FIFO_DEPTH = 8;
    localparam integer SM_SHIFT = 56;

    reg [3:0]  phase_r;
    reg        div_wait_r, sqrt_wait_r;
    reg [7:0]  op_r;
    reg [31:0] src0_r, src1_r, beta_base_r, dst_r, epsilon_r, watchdog_r;
    reg [15:0] length_r, n_size_r;
    reg [4:0]  shift_r;
    reg        beta_en_r, pack_r, tile_a_r, use_gamma_r;
    reg [3:0]  pending_error_r;
    reg        error_pending_r;
    reg [4:0]  drain_timer_r;

    // ---------------------------------------------------------------- reads
    // Read program: elementwise ops interleave x (and y) per element; row
    // ops read x[0..L-1] then gamma[0..L-1] then beta[0..L-1].
    reg [17:0] rd_issued_r, rd_total_r, rsp_count_r;
    reg [4:0]  outstanding_r;
    reg [31:0] fifo_r [0:FIFO_DEPTH-1];
    reg [2:0]  fifo_head_r, fifo_tail_r;
    reg [3:0]  fifo_count_r;

    reg signed [31:0] x_cache [0:CACHE_DEPTH-1];
    reg signed [31:0] g_cache [0:CACHE_DEPTH-1];
    reg signed [31:0] b_cache [0:CACHE_DEPTH-1];

    wire is_residual = (op_r == OP_RESIDUAL_I32);
    wire is_gelu     = (op_r == OP_GELU_Q8_8);
    wire is_requant  = (op_r == OP_REQUANT_I8);
    wire is_ln       = (op_r == OP_LAYERNORM_Q15);
    wire is_softmax  = (op_r == OP_SOFTMAX_Q15) || (op_r == OP_CAUSAL_SOFTMAX_Q15);
    wire is_rowop    = is_ln || is_softmax;
    wire [1:0] operands = is_residual ? 2'd2 : 2'd1;

    // Read address for read number rd_issued_r.
    wire [17:0] len18 = {2'd0, length_r};
    wire [17:0] rd_elem_ew = is_residual ? {1'b0, rd_issued_r[17:1]} : rd_issued_r;
    wire        rd_is_y   = is_residual && rd_issued_r[0];
    wire [17:0] rd_seg1   = len18;                                  // gamma start
    wire [17:0] rd_seg2   = use_gamma_r ? (len18 << 1) : len18;     // beta start
    wire [1:0]  rd_seg    = !is_rowop ? 2'd0 :
                            (rd_issued_r < rd_seg1) ? 2'd0 :
                            (use_gamma_r && rd_issued_r < rd_seg2) ? 2'd1 : 2'd2;
    wire [17:0] rd_row_elem = (rd_seg == 2'd0) ? rd_issued_r :
                              (rd_seg == 2'd1) ? (rd_issued_r - rd_seg1) :
                                                 (rd_issued_r - rd_seg2);
    wire [31:0] rd_addr = !is_rowop ?
        ((rd_is_y ? src1_r : src0_r) + {12'd0, rd_elem_ew, 2'b00}) :
        ((rd_seg == 2'd0) ? src0_r : (rd_seg == 2'd1) ? src1_r : beta_base_r) +
        {12'd0, rd_row_elem, 2'b00};
    // Responses arrive in request order; for row ops their segment follows
    // the same program order.
    wire [1:0]  rsp_seg = (rsp_count_r < rd_seg1) ? 2'd0 :
                          (use_gamma_r && rsp_count_r < rd_seg2) ? 2'd1 : 2'd2;
    wire [17:0] rsp_row_elem = (rsp_seg == 2'd0) ? rsp_count_r :
                               (rsp_seg == 2'd1) ? (rsp_count_r - rd_seg1) :
                                                   (rsp_count_r - rd_seg2);
    wire reads_remaining = rd_issued_r < rd_total_r;
    // Elementwise reads are bounded by FIFO space; row reads land in caches.
    wire read_credit = is_rowop ? (outstanding_r < 5'd16) :
        ({1'b0, outstanding_r} + {2'd0, fifo_count_r} < FIFO_DEPTH);

    // ------------------------------------------------- elementwise compute
    reg [17:0] ew_elem_r;            // next element to compute
    reg        wr_valid_r;
    reg [31:0] wr_addr_r, wr_data_r;
    reg [2:0]  wr_elems_r;           // elements represented by staged write
    reg        wr_last_r;
    reg [31:0] pack_word_r;
    reg [15:0] pack_row_r, pack_k_group_r;
    reg [31:0] pack_group_base_r;

    wire signed [31:0] fifo_x = fifo_r[fifo_head_r];
    wire signed [31:0] fifo_y = fifo_r[fifo_head_r + 3'd1];

    // --------------------------------------------------- row-op registers
    reg [17:0] row_idx_r;              // var/sum iteration index
    reg signed [63:0] sum_x_r;
    reg [63:0] sum_sq_r, sum_exp_r, mean_sq_r, recip_r;
    reg signed [31:0] mean_r, max_r;
    reg [31:0] inv_r;
    // Output pipeline (stage A -> staged write).
    reg [17:0] out_idx_r;
    reg        sa_valid_r;
    reg [17:0] sa_idx_r;
    reg signed [31:0] sa_p1_r;          // LN post-gamma value
    reg signed [31:0] sa_beta_r;
    reg        sa_masked_r;
    reg [63:0] sa_qest_r, sa_a_r;

    // Shared combinational fixed-point arithmetic (identical to legacy).
    wire [31:0] m_exp_q15, m_requant, m_residual, m_gamma_scaled, m_norm, m_gelu, m_silu;
    reg  signed [31:0] m_softmax_delta, m_gamma_x, m_gamma, m_norm_x;
    reg  signed [31:0] m_res_x, m_res_y;
    reg  signed [63:0] m_gelu_product;
    ai_tensor_sfu_math math_u(
        .softmax_delta_q8_8(m_softmax_delta), .requant_value(fifo_x),
        .requant_shift(shift_r), .residual_x(fifo_x), .residual_y(fifo_y),
        .residual_shift(shift_r), .gamma_x(m_gamma_x), .gamma(m_gamma),
        .norm_x(sa_p1_r), .norm_inv_rms(inv_r), .norm_beta(sa_beta_r),
        .norm_add_beta(1'b1), .gelu_product(m_gelu_product),
        .silu_product(64'sd0), .softmax_exp_q15(m_exp_q15),
        .requant_i8_value(m_requant), .residual_value(m_residual),
        .gamma_scaled_value(m_gamma_scaled), .normalization_value(m_norm),
        .gelu_q8_8_value(m_gelu), .silu_q8_8_value(m_silu)
    );
    wire [31:0] gelu_piecewise = (fifo_x <= -32'sd512) ? 32'd0 :
                                 (fifo_x >= 32'sd512) ? fifo_x : m_gelu;

    // Cached-row operands for the next output element / iteration.
    wire [CACHE_AW-1:0] out_ci = out_idx_r[CACHE_AW-1:0];
    wire [CACHE_AW-1:0] row_ci = row_idx_r[CACHE_AW-1:0];
    wire signed [31:0] out_x_centered = x_cache[out_ci] - mean_r;     // 32-bit wrap
    wire signed [31:0] var_centered   = x_cache[row_ci] - mean_r;     // 32-bit wrap
    wire signed [63:0] var_product    = var_centered * var_centered;
    wire out_masked = (op_r == OP_CAUSAL_SOFTMAX_Q15) &&
                      (out_idx_r[15:0] > epsilon_r[15:0]);
    wire row_masked = (op_r == OP_CAUSAL_SOFTMAX_Q15) &&
                      (row_idx_r[15:0] > epsilon_r[15:0]);
    wire rsp_masked = (op_r == OP_CAUSAL_SOFTMAX_Q15) &&
                      (rsp_row_elem[15:0] > epsilon_r[15:0]);
    wire [63:0] sm_a = {m_exp_q15, 15'd0} & 64'h0000_7fff_ffff_ffff;
    wire [127:0] sm_prod = sm_a * recip_r;
    wire [63:0] sm_qest = sm_prod[SM_SHIFT +: 64];
    wire [127:0] sm_check = (sa_qest_r + 64'd1) * sum_exp_r;
    wire [63:0] sm_q = (sm_check[63:0] <= sa_a_r && sm_check[127:64] == 0) ?
                       (sa_qest_r + 64'd1) : sa_qest_r;
    wire [31:0] sm_out = (sm_q > 64'd32768) ? 32'd32768 : sm_q[31:0];

    always @(*) begin
        m_softmax_delta = 32'sd0; m_gamma_x = 32'sd0; m_gamma = 32'sd0;
        m_gelu_product = fifo_x * (fifo_x + 32'sd512);
        case (phase_r)
            P_XREAD:  m_softmax_delta = $signed(spad_rdata) - max_r;
            P_SM_SUM: m_softmax_delta = x_cache[row_ci] - max_r;
            P_OUT: begin
                m_softmax_delta = x_cache[out_ci] - max_r;
                m_gamma_x = out_x_centered;
                m_gamma = use_gamma_r ? g_cache[out_ci] : 32'sd32768;
            end
            default: begin end
        endcase
    end

    // Port: a staged write has priority; otherwise issue the next read.
    // valid/ready stability: a request presented without ready is presented
    // unchanged until accepted (req_hold_r records its kind).  The staged
    // write and the next read address are both stable while held, and a held
    // read cannot overflow the response FIFO because outstanding+buffered
    // words never grow without a new read being accepted.
    reg req_hold_r, req_hold_write_r;
    wire want_read = busy && !error_pending_r && reads_remaining && read_credit &&
                     (phase_r != P_DRAIN) && (phase_r != P_FINISH);
    always @(*) begin
        spad_valid = 1'b0; spad_write = 1'b0; spad_addr = 32'd0; spad_wdata = 32'd0;
        if (busy && !error_pending_r && req_hold_r) begin
            spad_valid = 1'b1; spad_write = req_hold_write_r;
            spad_addr = req_hold_write_r ? wr_addr_r : rd_addr;
            spad_wdata = req_hold_write_r ? wr_data_r : 32'd0;
        end else if (busy && !error_pending_r && wr_valid_r) begin
            spad_valid = 1'b1; spad_write = 1'b1;
            spad_addr = wr_addr_r; spad_wdata = wr_data_r;
        end else if (want_read) begin
            spad_valid = 1'b1; spad_addr = rd_addr;
        end
    end
    wire wr_fire = spad_valid && spad_write && spad_ready;
    wire rd_fire = spad_valid && !spad_write && spad_ready;
    wire wr_free = !wr_valid_r || wr_fire;

    // Elementwise output for the FIFO head.
    wire ew_operands_ready = fifo_count_r >= {2'd0, operands};
    wire [31:0] ew_value = is_residual ? m_residual :
                           is_gelu ? gelu_piecewise : m_requant;
    wire ew_last = (ew_elem_r == len18 - 18'd1);
    wire [31:0] pack_tile_word = pack_group_base_r + ({16'd0, pack_k_group_r} << 2) +
                                 {30'd0, pack_row_r[1:0]};
    wire [31:0] pack_word_index = tile_a_r ? pack_tile_word : {14'd0, ew_elem_r[17:2]};
    wire [31:0] pack_word_next = (ew_elem_r[1:0] == 2'd0) ? {24'd0, m_requant[7:0]} :
        (ew_elem_r[1:0] == 2'd1) ? {16'd0, m_requant[7:0], pack_word_r[7:0]} :
        (ew_elem_r[1:0] == 2'd2) ? {8'd0, m_requant[7:0], pack_word_r[15:0]} :
                                   {m_requant[7:0], pack_word_r[23:0]};
    wire watchdog_expired = busy && (watchdog_r != 0) && (cycle_count >= watchdog_r);

    integer i;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            phase_r <= P_IDLE; busy <= 1'b0; done <= 1'b0; error <= 1'b0;
            error_code <= 4'd0; result <= 32'd0; cycle_count <= 32'd0;
            element_count <= 32'd0; op_r <= 8'd0; src0_r <= 32'd0; src1_r <= 32'd0;
            beta_base_r <= 32'd0; dst_r <= 32'd0; epsilon_r <= 32'd1; watchdog_r <= 32'd0;
            length_r <= 16'd0; n_size_r <= 16'd0; shift_r <= 5'd0; beta_en_r <= 1'b0;
            pack_r <= 1'b0; tile_a_r <= 1'b0; use_gamma_r <= 1'b0;
            pending_error_r <= 4'd0; error_pending_r <= 1'b0; drain_timer_r <= 5'd0;
            rd_issued_r <= 18'd0; rd_total_r <= 18'd0; rsp_count_r <= 18'd0;
            outstanding_r <= 5'd0; fifo_head_r <= 3'd0; fifo_tail_r <= 3'd0;
            fifo_count_r <= 4'd0; ew_elem_r <= 18'd0; wr_valid_r <= 1'b0;
            wr_addr_r <= 32'd0; wr_data_r <= 32'd0; wr_elems_r <= 3'd0; wr_last_r <= 1'b0;
            pack_word_r <= 32'd0; pack_row_r <= 16'd0; pack_k_group_r <= 16'd0;
            pack_group_base_r <= 32'd0; row_idx_r <= 18'd0; sum_x_r <= 64'sd0;
            sum_sq_r <= 64'd0; sum_exp_r <= 64'd0; mean_sq_r <= 64'd0; recip_r <= 64'd0;
            mean_r <= 32'sd0; max_r <= 32'sh8000_0000; inv_r <= 32'd0;
            out_idx_r <= 18'd0; sa_valid_r <= 1'b0; sa_idx_r <= 18'd0; sa_p1_r <= 32'sd0;
            sa_beta_r <= 32'sd0; sa_masked_r <= 1'b0; sa_qest_r <= 64'd0; sa_a_r <= 64'd0;
            div_start <= 1'b0; div_accelerate <= 1'b0; div_dividend <= 64'd0;
            div_divisor <= 64'd0; sqrt_start <= 1'b0; sqrt_radicand <= 64'd0;
            div_wait_r <= 1'b0; sqrt_wait_r <= 1'b0;
            req_hold_r <= 1'b0; req_hold_write_r <= 1'b0;
        end else begin
            req_hold_r <= spad_valid && !spad_ready;
            if (spad_valid && !spad_ready) req_hold_write_r <= spad_write;
            done <= 1'b0; error <= 1'b0; div_start <= 1'b0; sqrt_start <= 1'b0;
            if (phase_r == P_IDLE && start) cycle_count <= 32'd0;
            else if (busy) cycle_count <= cycle_count + 32'd1;

            // ---------------- command snapshot
            if (phase_r == P_IDLE) begin
                busy <= 1'b0;
                if (start) begin
                    busy <= 1'b1; op_r <= op_mode; src0_r <= src0_base;
                    src1_r <= src1_base; beta_base_r <= beta_base; dst_r <= dst_base;
                    epsilon_r <= (op_mode == OP_CAUSAL_SOFTMAX_Q15) ? epsilon :
                                 (epsilon == 32'd0 ? 32'd1 : epsilon);
                    watchdog_r <= watchdog_limit; length_r <= length; n_size_r <= n_size;
                    shift_r <= scale_shift; beta_en_r <= beta_enable;
                    pack_r <= pack_enable && (op_mode == OP_REQUANT_I8);
                    tile_a_r <= pack_tile_a; error_code <= 4'd0; element_count <= 32'd0;
                    use_gamma_r <= (op_mode == OP_LAYERNORM_Q15) && (src1_base != 32'd0);
                    pending_error_r <= 4'd0; error_pending_r <= 1'b0;
                    rd_issued_r <= 18'd0; rsp_count_r <= 18'd0; outstanding_r <= 5'd0;
                    fifo_head_r <= 3'd0; fifo_tail_r <= 3'd0; fifo_count_r <= 4'd0;
                    ew_elem_r <= 18'd0; wr_valid_r <= 1'b0; pack_word_r <= 32'd0;
                    pack_row_r <= 16'd0; pack_k_group_r <= 16'd0; pack_group_base_r <= 32'd0;
                    row_idx_r <= 18'd0; sum_x_r <= 64'sd0; sum_sq_r <= 64'd0;
                    sum_exp_r <= 64'd0; max_r <= 32'sh8000_0000; mean_r <= 32'sd0;
                    out_idx_r <= 18'd0; sa_valid_r <= 1'b0; div_wait_r <= 1'b0;
                    sqrt_wait_r <= 1'b0;
                    if (op_mode == OP_RESIDUAL_I32)
                        rd_total_r <= {1'b0, length, 1'b0};
                    else if (op_mode == OP_LAYERNORM_Q15)
                        rd_total_r <= {2'd0, length} +
                            ((src1_base != 32'd0) ? {2'd0, length} : 18'd0) +
                            (beta_enable ? {2'd0, length} : 18'd0);
                    else
                        rd_total_r <= {2'd0, length};
                    phase_r <= ((op_mode == OP_LAYERNORM_Q15) ||
                                (op_mode == OP_SOFTMAX_Q15) ||
                                (op_mode == OP_CAUSAL_SOFTMAX_Q15)) ? P_XREAD : P_STREAM;
                end
            end else begin
                // ---------------- read issue / response bookkeeping
                if (rd_fire) begin
                    rd_issued_r <= rd_issued_r + 18'd1;
                    if (spad_protection_error && !error_pending_r) begin
                        error_pending_r <= 1'b1; pending_error_r <= ERR_PROTECTION;
                    end
                end
                if (wr_fire && spad_protection_error && !error_pending_r) begin
                    error_pending_r <= 1'b1; pending_error_r <= ERR_PROTECTION;
                end
                outstanding_r <= outstanding_r + (rd_fire ? 5'd1 : 5'd0) -
                                 (spad_rsp_valid && outstanding_r != 0 ? 5'd1 : 5'd0);
                if (spad_rsp_valid && outstanding_r != 0) begin
                    rsp_count_r <= rsp_count_r + 18'd1;
                    if (spad_parity_error && !error_pending_r) begin
                        error_pending_r <= 1'b1; pending_error_r <= ERR_PARITY;
                    end
                    if (!is_rowop) begin
                        fifo_r[fifo_tail_r] <= spad_rdata;
                        fifo_tail_r <= fifo_tail_r + 3'd1;
                    end else begin
                        case (rsp_seg)
                            2'd0: begin
                                x_cache[rsp_row_elem[CACHE_AW-1:0]] <= spad_rdata;
                                if (is_ln)
                                    sum_x_r <= sum_x_r + {{32{spad_rdata[31]}}, spad_rdata};
                                else if (!rsp_masked && $signed(spad_rdata) > max_r)
                                    max_r <= spad_rdata;
                            end
                            2'd1: g_cache[rsp_row_elem[CACHE_AW-1:0]] <= spad_rdata;
                            default: b_cache[rsp_row_elem[CACHE_AW-1:0]] <= spad_rdata;
                        endcase
                    end
                end

                // ---------------- staged write retirement
                if (wr_fire) begin
                    result <= wr_data_r;
                    element_count <= element_count + {29'd0, wr_elems_r};
                end

                // ---------------- error / abort handling
                if (phase_r != P_DRAIN && phase_r != P_FINISH &&
                    (abort || watchdog_expired || error_pending_r)) begin
                    pending_error_r <= abort ? ERR_ABORT :
                                       watchdog_expired ? ERR_WATCHDOG : pending_error_r;
                    error_pending_r <= 1'b1;
                    wr_valid_r <= 1'b0;
                    drain_timer_r <= 5'd0;
                    phase_r <= P_DRAIN;
                end else case (phase_r)
                    // -------------------------------- elementwise
                    P_STREAM: begin
                        if (wr_fire && wr_last_r) begin
                            wr_valid_r <= 1'b0;
                            phase_r <= P_FINISH;
                        end else begin
                            if (wr_fire) wr_valid_r <= 1'b0;
                            if (wr_free && ew_operands_ready && ew_elem_r < len18) begin
                                fifo_head_r <= fifo_head_r + {1'b0, operands};
                                fifo_count_r <= fifo_count_r - {2'd0, operands} +
                                    ((spad_rsp_valid && outstanding_r != 0) ? 4'd1 : 4'd0);
                                ew_elem_r <= ew_elem_r + 18'd1;
                                if (pack_r) begin
                                    pack_word_r <= pack_word_next;
                                    if (ew_elem_r[1:0] == 2'd3 || ew_last) begin
                                        wr_valid_r <= 1'b1;
                                        wr_addr_r <= dst_r + (pack_word_index << 2);
                                        wr_data_r <= pack_word_next;
                                        wr_elems_r <= {1'b0, ew_elem_r[1:0]} + 3'd1;
                                        wr_last_r <= ew_last;
                                        pack_word_r <= 32'd0;
                                        if (tile_a_r) begin
                                            if (pack_k_group_r == (n_size_r[15:2] - 16'd1)) begin
                                                pack_k_group_r <= 16'd0;
                                                pack_row_r <= pack_row_r + 16'd1;
                                                if (pack_row_r[1:0] == 2'd3)
                                                    pack_group_base_r <= pack_group_base_r +
                                                                         {16'd0, n_size_r};
                                            end else pack_k_group_r <= pack_k_group_r + 16'd1;
                                        end
                                    end
                                end else begin
                                    wr_valid_r <= 1'b1;
                                    wr_addr_r <= dst_r + {12'd0, ew_elem_r, 2'b00};
                                    wr_data_r <= ew_value;
                                    wr_elems_r <= 3'd1;
                                    wr_last_r <= ew_last;
                                end
                            end else begin
                                fifo_count_r <= fifo_count_r +
                                    ((spad_rsp_valid && outstanding_r != 0) ? 4'd1 : 4'd0);
                            end
                        end
                    end

                    // -------------------------------- row read (x)
                    P_XREAD: begin
                        if (rsp_count_r + ((spad_rsp_valid && outstanding_r != 0) ? 18'd1 : 18'd0)
                                >= len18) begin
                            row_idx_r <= 18'd0;
                            phase_r <= is_ln ? P_LN_MEAN : P_SM_SUM;
                        end
                    end

                    // -------------------------------- LayerNorm statistics
                    P_LN_MEAN: begin
                        if (!div_wait_r) begin
                            div_start <= 1'b1; div_accelerate <= 1'b1;
                            div_dividend <= sum_x_r[63] ? -sum_x_r : sum_x_r;
                            div_divisor <= {48'd0, length_r};
                            div_wait_r <= 1'b1;
                        end else if (div_done) begin
                            div_wait_r <= 1'b0;
                            if (div_error || div_quotient > 64'h0000_0000_8000_0000) begin
                                error_pending_r <= 1'b1; pending_error_r <= ERR_NUMERIC;
                            end else begin
                                mean_r <= sum_x_r[63] ? -$signed(div_quotient[31:0]) :
                                                        $signed(div_quotient[31:0]);
                                sum_sq_r <= 64'd0; row_idx_r <= 18'd0;
                                phase_r <= P_LN_VAR;
                            end
                        end
                    end
                    P_LN_VAR: begin
                        sum_sq_r <= sum_sq_r + var_product;
                        if (row_idx_r == len18 - 18'd1) phase_r <= P_LN_MSQ;
                        else row_idx_r <= row_idx_r + 18'd1;
                    end
                    P_LN_MSQ: begin
                        if (!div_wait_r) begin
                            div_start <= 1'b1; div_accelerate <= 1'b1;
                            div_dividend <= sum_sq_r; div_divisor <= {48'd0, length_r};
                            div_wait_r <= 1'b1;
                        end else if (div_done) begin
                            div_wait_r <= 1'b0;
                            if (div_error) begin
                                error_pending_r <= 1'b1; pending_error_r <= ERR_NUMERIC;
                            end else begin
                                mean_sq_r <= div_quotient;
                                phase_r <= P_LN_SQRT;
                            end
                        end
                    end
                    P_LN_SQRT: begin
                        if (!sqrt_wait_r) begin
                            sqrt_start <= 1'b1;
                            sqrt_radicand <= mean_sq_r + {32'd0, epsilon_r};
                            sqrt_wait_r <= 1'b1;
                        end else if (sqrt_done) begin
                            sqrt_wait_r <= 1'b0;
                            if (sqrt_root == 32'd0) begin
                                error_pending_r <= 1'b1; pending_error_r <= ERR_NUMERIC;
                            end else begin
                                div_divisor <= {32'd0, sqrt_root};
                                phase_r <= P_LN_INV;
                            end
                        end
                    end
                    P_LN_INV: begin
                        if (!div_wait_r) begin
                            div_start <= 1'b1; div_accelerate <= 1'b1;
                            div_dividend <= 64'h0000_0000_4000_0000;
                            div_wait_r <= 1'b1;
                        end else if (div_done) begin
                            div_wait_r <= 1'b0;
                            if (div_error) begin
                                error_pending_r <= 1'b1; pending_error_r <= ERR_NUMERIC;
                            end else begin
                                inv_r <= div_quotient[31:0];
                                out_idx_r <= 18'd0; sa_valid_r <= 1'b0;
                                phase_r <= P_OUT;
                            end
                        end
                    end

                    // -------------------------------- Softmax statistics
                    P_SM_SUM: begin
                        if (!row_masked) sum_exp_r <= sum_exp_r + {32'd0, m_exp_q15};
                        if (row_idx_r == len18 - 18'd1) phase_r <= P_SM_RECIP;
                        else row_idx_r <= row_idx_r + 18'd1;
                    end
                    P_SM_RECIP: begin
                        if (!div_wait_r) begin
                            if (sum_exp_r == 64'd0) begin
                                error_pending_r <= 1'b1; pending_error_r <= ERR_NUMERIC;
                            end else begin
                                div_start <= 1'b1; div_accelerate <= 1'b1;
                                div_dividend <= 64'd1 << SM_SHIFT;
                                div_divisor <= sum_exp_r;
                                div_wait_r <= 1'b1;
                            end
                        end else if (div_done) begin
                            div_wait_r <= 1'b0;
                            if (div_error) begin
                                error_pending_r <= 1'b1; pending_error_r <= ERR_NUMERIC;
                            end else begin
                                recip_r <= div_quotient;
                                out_idx_r <= 18'd0; sa_valid_r <= 1'b0;
                                phase_r <= P_OUT;
                            end
                        end
                    end

                    // -------------------------------- cached-row outputs
                    // LN waits for gamma/beta prefetch before the first output.
                    P_OUT: begin
                        if (wr_fire && wr_last_r) begin
                            wr_valid_r <= 1'b0;
                            phase_r <= P_FINISH;
                        end else begin
                            if (wr_free) begin
                                if (sa_valid_r) begin
                                    wr_valid_r <= 1'b1;
                                    wr_addr_r <= dst_r + {12'd0, sa_idx_r, 2'b00};
                                    wr_data_r <= is_ln ? m_norm :
                                                 (sa_masked_r ? 32'd0 : sm_out);
                                    wr_elems_r <= 3'd1;
                                    wr_last_r <= (sa_idx_r == len18 - 18'd1);
                                end else if (wr_fire) wr_valid_r <= 1'b0;
                            end
                            if ((!sa_valid_r || wr_free) && out_idx_r < len18 &&
                                (!is_ln || rsp_count_r >= rd_total_r)) begin
                                sa_valid_r <= 1'b1;
                                sa_idx_r <= out_idx_r;
                                sa_p1_r <= m_gamma_scaled;
                                sa_beta_r <= beta_en_r ? b_cache[out_ci] : 32'sd0;
                                sa_masked_r <= out_masked;
                                sa_a_r <= sm_a;
                                sa_qest_r <= sm_qest;
                                out_idx_r <= out_idx_r + 18'd1;
                            end else if (wr_free) begin
                                sa_valid_r <= 1'b0;
                            end
                        end
                    end

                    // -------------------------------- error drain
                    P_DRAIN: begin
                        drain_timer_r <= drain_timer_r + 5'd1;
                        if ((outstanding_r == 0 ||
                             (outstanding_r == 1 && spad_rsp_valid) ||
                             drain_timer_r == 5'd31) && !div_wait_r && !sqrt_wait_r) begin
                            busy <= 1'b0; done <= 1'b1; error <= 1'b1;
                            error_code <= pending_error_r;
                            phase_r <= P_IDLE;
                        end
                        if (div_wait_r && div_done) div_wait_r <= 1'b0;
                        if (sqrt_wait_r && sqrt_done) sqrt_wait_r <= 1'b0;
                    end

                    P_FINISH: begin
                        busy <= 1'b0; done <= 1'b1; error <= 1'b0;
                        phase_r <= P_IDLE;
                    end
                    default: phase_r <= P_IDLE;
                endcase
            end
        end
    end
endmodule
