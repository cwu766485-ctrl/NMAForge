`timescale 1ns / 1ps

// A3 4x4 tensor matrix engine.
//
// Scratchpad layout is tile-major.  One aligned 16-byte banked read returns
// four 32-bit words.  For A, bank r holds four consecutive K elements of row
// r; for B, bank c holds four consecutive K elements of column c.  Four lane
// cycles therefore update all sixteen C[r][c] accumulators with sixteen INT8
// multipliers per cycle.  TRANSPOSE_A/B transpose each packed 4x4 K slice in
// the address-generator boundary without copying a complete matrix.
//
// M and N are multiples of four.  K_WORDS is K/4.  B is supplied in the
// accelerator's column-vector tile layout; software/DMA is responsible for
// global tensor tiling while the hardware handles local transpose, batch
// strides, bias, requantization and activation.
module ai_tensor_matrix_core(
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
    // Passive A5 observability signals; they do not change the data path.
    output wire         perf_mac_active,
    output wire         perf_banked_wait
);
    localparam [7:0] OP_TENSOR_GEMM       = 8'h30;
    localparam [7:0] OP_TENSOR_BATCH_GEMM = 8'h31;

    localparam [3:0] ERR_CONFIG     = 4'd1;
    localparam [3:0] ERR_OP         = 4'd2;
    localparam [3:0] ERR_ABORT      = 4'd3;
    localparam [3:0] ERR_WATCHDOG   = 4'd4;
    localparam [3:0] ERR_PARITY     = 4'd5;
    localparam [3:0] ERR_PROTECTION = 4'd6;

    // A request state owns a banked/SPAD request; its paired wait state owns
    // the registered response.  ST_MAC may issue one prefetch at a time.
    localparam [4:0] ST_IDLE          = 5'd0;
    localparam [4:0] ST_A_REQ         = 5'd1;
    localparam [4:0] ST_A_WAIT        = 5'd2;
    localparam [4:0] ST_B_REQ         = 5'd3;
    localparam [4:0] ST_B_WAIT        = 5'd4;
    localparam [4:0] ST_BIAS_REQ      = 5'd5;
    localparam [4:0] ST_BIAS_WAIT     = 5'd6;
    localparam [4:0] ST_MAC           = 5'd7;
    localparam [4:0] ST_WRITE         = 5'd8;
    localparam [4:0] ST_NEXT          = 5'd9;
    localparam [4:0] ST_DONE          = 5'd10;
    localparam [4:0] ST_ERROR         = 5'd11;
    localparam [4:0] ST_PREFETCH_WAIT = 5'd12;

    reg [4:0] state_r;
    reg [15:0] m_r, n_r, k_words_r;
    reg [31:0] instance_count_r, instance_r;
    reg [15:0] row_tile_r, col_tile_r, k_group_r;
    reg [1:0] lane_r, bias_idx_r;
    reg [3:0] write_idx_r;
    reg transpose_a_r, transpose_b_r, bias_enable_r, bias_loaded_r;
    reg [4:0] scale_shift_r;
    reg [1:0] activation_r;
    reg [31:0] watchdog_limit_r;
    reg [31:0] a_batch_base_r, b_batch_base_r, dst_batch_base_r;
    reg [31:0] a_tile_base_r, b_tile_base_r;
    reg [31:0] dst_row_tile_base_r, dst_tile_base_r;
    reg [31:0] bias_tile_base_r;
    reg [31:0] src0_batch_stride_r, src1_batch_stride_r, dst_batch_stride_r;
    reg [31:0] dst_row_stride_r;
    reg [31:0] a0_r, a1_r, a2_r, a3_r;
    reg [31:0] b0_r, b1_r, b2_r, b3_r;
    // One-entry ping-pong operand buffer.  During the four MAC lanes of K
    // group i it opportunistically fetches the A/B words for K group i+1.
    // The core only consumes the buffer after both responses arrive, so the
    // registered scratchpad read contract remains unchanged.
    reg [31:0] pre_a0_r, pre_a1_r, pre_a2_r, pre_a3_r;
    reg [31:0] pre_b0_r, pre_b1_r, pre_b2_r, pre_b3_r;
    reg prefetch_a_pending_r, prefetch_b_pending_r;
    reg prefetch_a_valid_r, prefetch_b_valid_r;
    reg signed [31:0] bias0_r, bias1_r, bias2_r, bias3_r;
    reg signed [63:0] acc_r [0:15];
    integer i;

    wire [15:0] m_tiles = m_r >> 2;
    wire [15:0] n_tiles = n_r >> 2;
    wire [31:0] k_tile_bytes = {12'd0, k_words_r, 4'b0000};
    wire [31:0] a_read_addr = a_tile_base_r + ({16'd0, k_group_r} << 4);
    wire [31:0] b_read_addr = b_tile_base_r + ({16'd0, k_group_r} << 4);
    wire [31:0] next_a_read_addr = a_tile_base_r + ({16'd0, k_group_r + 1'b1} << 4);
    wire [31:0] next_b_read_addr = b_tile_base_r + ({16'd0, k_group_r + 1'b1} << 4);
    wire [31:0] write_row_offset = (write_idx_r[3:2] == 2'd0) ? 32'd0 :
                                   (write_idx_r[3:2] == 2'd1) ? dst_row_stride_r :
                                   (write_idx_r[3:2] == 2'd2) ? (dst_row_stride_r << 1) :
                                                                ((dst_row_stride_r << 1) + dst_row_stride_r);
    wire [31:0] write_row_addr = dst_tile_base_r + write_row_offset;
    wire line_store_eligible = write_row_addr[3:0] == 4'd0;
    wire valid_operation = (op_mode == OP_TENSOR_GEMM) ||
                           (op_mode == OP_TENSOR_BATCH_GEMM);
    wire invalid_dimensions = (m_size == 0) || (n_size == 0) ||
                              (k_words == 0) || |m_size[1:0] || |n_size[1:0];
    wire invalid_alignment = |src0_base[3:0] || |src1_base[3:0] ||
                             |dst_base[1:0] || (bias_enable && |bias_base[1:0]);
    wire last_k_group = (k_group_r == k_words_r - 1'b1);
    wire has_next_k_group = !last_k_group;
    wire bank_response_has_parity_error = |bank_parity_error;
    wire watchdog_expired = busy && (watchdog_limit_r != 0) &&
                              (cycle_count >= watchdog_limit_r);
    wire output_write_accepted = (line_store_eligible && line_ready) ||
                                 (!line_store_eligible && spad_ready);
    wire output_write_has_protection_error =
        (line_store_eligible && line_protection_error) ||
        (!line_store_eligible && spad_protection_error);
    assign perf_mac_active = state_r == ST_MAC;
    assign perf_banked_wait = (state_r == ST_A_WAIT) || (state_r == ST_B_WAIT) ||
                              (state_r == ST_PREFETCH_WAIT);
    assign line_write = 1'b1;
    assign line_wstrb = 16'hffff;

    // Arithmetic is stateless and isolated from the request/response FSM.
    // Keep the local product array so the existing accumulator update loop
    // retains its exact cycle and index behavior.
    wire signed [15:0] product [0:15];
    wire [31:0] post_scalar, post0, post1, post2, post3;
    wire signed [31:0] scalar_bias = (write_idx_r[1:0] == 2'd0) ? bias0_r :
                                     (write_idx_r[1:0] == 2'd1) ? bias1_r :
                                     (write_idx_r[1:0] == 2'd2) ? bias2_r : bias3_r;
    ai_tensor_matrix_datapath datapath_u(
        .a0(a0_r), .a1(a1_r), .a2(a2_r), .a3(a3_r),
        .b0(b0_r), .b1(b1_r), .b2(b2_r), .b3(b3_r), .lane(lane_r),
        .transpose_a(transpose_a_r), .transpose_b(transpose_b_r),
        .mac_enable(state_r == ST_MAC),
        .a_lane0(), .a_lane1(), .a_lane2(), .a_lane3(),
        .b_lane0(), .b_lane1(), .b_lane2(), .b_lane3(),
        .product0(product[0]), .product1(product[1]),
        .product2(product[2]), .product3(product[3]),
        .product4(product[4]), .product5(product[5]),
        .product6(product[6]), .product7(product[7]),
        .product8(product[8]), .product9(product[9]),
        .product10(product[10]), .product11(product[11]),
        .product12(product[12]), .product13(product[13]),
        .product14(product[14]), .product15(product[15]),
        .acc0(acc_r[write_idx_r]), .acc1(acc_r[write_idx_r+1]),
        .acc2(acc_r[write_idx_r+2]), .acc3(acc_r[write_idx_r+3]),
        .bias0(bias0_r), .bias1(bias1_r), .bias2(bias2_r), .bias3(bias3_r),
        .bias_enable(bias_enable_r), .scale_shift(scale_shift_r),
        .activation(activation_r), .scalar_acc(acc_r[write_idx_r]),
        .scalar_bias(bias_enable_r ? scalar_bias : 32'sd0),
        .post_scalar(post_scalar), .post0(post0), .post1(post1),
        .post2(post2), .post3(post3)
    );

    always @(*) begin
        banked_read_valid = (state_r == ST_A_REQ) || (state_r == ST_B_REQ);
        banked_addr = (state_r == ST_A_REQ) ? a_read_addr : b_read_addr;
        // The two operands share the one banked port.  A is requested first,
        // then B only after A has been captured.  If RAM latency exceeds the
        // four MAC lanes, ST_PREFETCH_WAIT safely finishes the transaction.
        if ((state_r == ST_MAC || state_r == ST_PREFETCH_WAIT) &&
            has_next_k_group) begin
            if (!prefetch_a_valid_r && !prefetch_a_pending_r) begin
                banked_read_valid = 1'b1;
                banked_addr = next_a_read_addr;
            end else if (prefetch_a_valid_r && !prefetch_b_valid_r &&
                         !prefetch_b_pending_r) begin
                banked_read_valid = 1'b1;
                banked_addr = next_b_read_addr;
            end
        end
        spad_valid = (state_r == ST_BIAS_REQ) ||
                     ((state_r == ST_WRITE) && !line_store_eligible);
        spad_write = (state_r == ST_WRITE) && !line_store_eligible;
        spad_addr = (state_r == ST_BIAS_REQ) ?
                    (bias_tile_base_r + ({30'd0,bias_idx_r} << 2)) :
                    (write_row_addr + ({30'd0,write_idx_r[1:0]} << 2));
        spad_wdata = post_scalar;
        // One complete output row is committed per scratchpad transaction.
        // The former scalar path required sixteen grants per 4x4 tile.
        line_valid = (state_r == ST_WRITE) && line_store_eligible;
        line_addr = write_row_addr;
        line_wdata = {post3, post2, post1, post0};
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r<=ST_IDLE; busy<=0; done<=0; error<=0; error_code<=0;
            result<=0; cycle_count<=0; element_count<=0; m_r<=0; n_r<=0;
            k_words_r<=0; instance_count_r<=0; instance_r<=0; row_tile_r<=0;
            col_tile_r<=0; k_group_r<=0; lane_r<=0; bias_idx_r<=0;
            write_idx_r<=0; transpose_a_r<=0; transpose_b_r<=0;
            bias_enable_r<=0; bias_loaded_r<=0; scale_shift_r<=0;
            activation_r<=0; watchdog_limit_r<=0; a_batch_base_r<=0;
            b_batch_base_r<=0; dst_batch_base_r<=0; a_tile_base_r<=0;
            b_tile_base_r<=0; dst_row_tile_base_r<=0; dst_tile_base_r<=0;
            bias_tile_base_r<=0; src0_batch_stride_r<=0;
            src1_batch_stride_r<=0; dst_batch_stride_r<=0;
            dst_row_stride_r<=0; a0_r<=0; a1_r<=0; a2_r<=0; a3_r<=0;
            b0_r<=0; b1_r<=0; b2_r<=0; b3_r<=0;
            pre_a0_r<=0; pre_a1_r<=0; pre_a2_r<=0; pre_a3_r<=0;
            pre_b0_r<=0; pre_b1_r<=0; pre_b2_r<=0; pre_b3_r<=0;
            prefetch_a_pending_r<=0; prefetch_b_pending_r<=0;
            prefetch_a_valid_r<=0; prefetch_b_valid_r<=0;
            bias0_r<=0; bias1_r<=0; bias2_r<=0; bias3_r<=0;
            for (i=0;i<16;i=i+1) acc_r[i]<=0;
        end else begin
            done <= 1'b0;
            if (state_r==ST_IDLE && start)
                cycle_count <= 0;
            else if (busy)
                cycle_count <= cycle_count + 1'b1;

            if (busy && abort && state_r != ST_ERROR) begin
                error_code <= ERR_ABORT;
                state_r <= ST_ERROR;
            end else if (watchdog_expired && state_r != ST_ERROR) begin
                error_code <= ERR_WATCHDOG;
                state_r <= ST_ERROR;
            end else case (state_r)
                ST_IDLE: begin
                    busy<=0; error<=0; error_code<=0;
                    if (start) begin
                        m_r<=m_size; n_r<=n_size; k_words_r<=k_words;
                        instance_count_r<=instance_count==0 ? 32'd1 : instance_count;
                        transpose_a_r<=transpose_a; transpose_b_r<=transpose_b;
                        bias_enable_r<=bias_enable; scale_shift_r<=scale_shift;
                        activation_r<=activation; watchdog_limit_r<=watchdog_limit;
                        a_batch_base_r<=src0_base; b_batch_base_r<=src1_base;
                        dst_batch_base_r<=dst_base; a_tile_base_r<=src0_base;
                        b_tile_base_r<=src1_base; dst_row_tile_base_r<=dst_base;
                        dst_tile_base_r<=dst_base; bias_tile_base_r<=bias_base;
                        src0_batch_stride_r<=src0_batch_stride==0 ?
                            ((m_size>>2)*k_words*16) : src0_batch_stride;
                        src1_batch_stride_r<=src1_batch_stride==0 ?
                            ((n_size>>2)*k_words*16) : src1_batch_stride;
                        dst_batch_stride_r<=dst_batch_stride==0 ?
                            (m_size*n_size*4) : dst_batch_stride;
                        dst_row_stride_r<={14'd0,n_size,2'b00};
                        instance_r<=0; row_tile_r<=0; col_tile_r<=0; k_group_r<=0;
                        lane_r<=0; bias_idx_r<=0; write_idx_r<=0;
                        bias_loaded_r<=0; element_count<=0;
                        prefetch_a_pending_r<=0; prefetch_b_pending_r<=0;
                        prefetch_a_valid_r<=0; prefetch_b_valid_r<=0;
                        for (i=0;i<16;i=i+1) acc_r[i]<=0;
                        busy<=1;
                        if (!valid_operation) begin
                            error_code<=ERR_OP; state_r<=ST_ERROR;
                        end else if (invalid_dimensions || invalid_alignment) begin
                            error_code<=ERR_CONFIG; state_r<=ST_ERROR;
                        end else begin
                            state_r<=ST_A_REQ;
                        end
                    end
                end

                ST_A_REQ: if (banked_ready) begin
                    if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_A_WAIT;
                end
                ST_A_WAIT: if (banked_rsp_valid) begin
                    if (bank_response_has_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        a0_r<=bank0_data; a1_r<=bank1_data; a2_r<=bank2_data; a3_r<=bank3_data;
                        state_r<=ST_B_REQ;
                    end
                end
                ST_B_REQ: if (banked_ready) begin
                    if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_B_WAIT;
                end
                ST_B_WAIT: if (banked_rsp_valid) begin
                    if (bank_response_has_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        b0_r<=bank0_data; b1_r<=bank1_data; b2_r<=bank2_data; b3_r<=bank3_data;
                        prefetch_a_pending_r<=0; prefetch_b_pending_r<=0;
                        prefetch_a_valid_r<=0; prefetch_b_valid_r<=0;
                        lane_r<=0;
                        if (bias_enable_r && !bias_loaded_r) begin
                            bias_idx_r<=0; state_r<=ST_BIAS_REQ;
                        end else state_r<=ST_MAC;
                    end
                end
                ST_BIAS_REQ: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else state_r<=ST_BIAS_WAIT;
                end
                ST_BIAS_WAIT: if (spad_rsp_valid) begin
                    if (spad_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        case (bias_idx_r)
                            2'd0: bias0_r<=spad_rdata;
                            2'd1: bias1_r<=spad_rdata;
                            2'd2: bias2_r<=spad_rdata;
                            default: bias3_r<=spad_rdata;
                        endcase
                        if (bias_idx_r==2'd3) begin bias_loaded_r<=1; lane_r<=0; state_r<=ST_MAC; end
                        else begin bias_idx_r<=bias_idx_r+1'b1; state_r<=ST_BIAS_REQ; end
                    end
                end
                ST_MAC: begin
                    // Accept prefetch responses while useful MAC work is
                    // still being performed.  There can be only one request
                    // in flight on this port, hence pending A has priority.
                    if (has_next_k_group && banked_ready &&
                        !prefetch_a_valid_r && !prefetch_a_pending_r) begin
                        if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                        else prefetch_a_pending_r <= 1'b1;
                    end
                    else if (has_next_k_group && banked_ready && prefetch_a_valid_r &&
                             !prefetch_b_valid_r && !prefetch_b_pending_r) begin
                        if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                        else prefetch_b_pending_r <= 1'b1;
                    end
                    if (banked_rsp_valid && prefetch_a_pending_r) begin
                        if (bank_response_has_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                        else begin
                            pre_a0_r<=bank0_data; pre_a1_r<=bank1_data;
                            pre_a2_r<=bank2_data; pre_a3_r<=bank3_data;
                            prefetch_a_pending_r<=0; prefetch_a_valid_r<=1;
                        end
                    end else if (banked_rsp_valid && prefetch_b_pending_r) begin
                        if (bank_response_has_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                        else begin
                            pre_b0_r<=bank0_data; pre_b1_r<=bank1_data;
                            pre_b2_r<=bank2_data; pre_b3_r<=bank3_data;
                            prefetch_b_pending_r<=0; prefetch_b_valid_r<=1;
                        end
                    end
                    for (i=0;i<16;i=i+1)
                        acc_r[i] <= acc_r[i] + {{48{product[i][15]}},product[i]};
                    if (lane_r==2'd3) begin
                        lane_r<=0;
                        if (last_k_group) begin write_idx_r<=0; state_r<=ST_WRITE; end
                        // A3.1: with the registered one-cycle SRAM model,
                        // the B prefetch response for K+1 arrives on this
                        // final MAC lane.  Consume it immediately with the
                        // already-captured A prefetch rather than spending a
                        // full ST_PREFETCH_WAIT bubble before K+1 can start.
                        else if (prefetch_a_valid_r && banked_rsp_valid &&
                                 prefetch_b_pending_r) begin
                            if (bank_response_has_parity_error) begin
                                error_code<=ERR_PARITY; state_r<=ST_ERROR;
                            end else begin
                                a0_r<=pre_a0_r; a1_r<=pre_a1_r;
                                a2_r<=pre_a2_r; a3_r<=pre_a3_r;
                                b0_r<=bank0_data; b1_r<=bank1_data;
                                b2_r<=bank2_data; b3_r<=bank3_data;
                                prefetch_a_valid_r<=0;
                                prefetch_b_pending_r<=0;
                                prefetch_b_valid_r<=0;
                                k_group_r<=k_group_r+1'b1;
                                state_r<=ST_MAC;
                            end
                        end else state_r<=ST_PREFETCH_WAIT;
                    end else lane_r<=lane_r+1'b1;
                end
                ST_PREFETCH_WAIT: begin
                    if (banked_ready && !prefetch_a_valid_r && !prefetch_a_pending_r) begin
                        if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                        else prefetch_a_pending_r <= 1'b1;
                    end
                    else if (banked_ready && prefetch_a_valid_r &&
                             !prefetch_b_valid_r && !prefetch_b_pending_r) begin
                        if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                        else prefetch_b_pending_r <= 1'b1;
                    end
                    if (banked_rsp_valid && prefetch_a_pending_r) begin
                        if (bank_response_has_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                        else begin
                            pre_a0_r<=bank0_data; pre_a1_r<=bank1_data;
                            pre_a2_r<=bank2_data; pre_a3_r<=bank3_data;
                            prefetch_a_pending_r<=0; prefetch_a_valid_r<=1;
                        end
                    end else if (banked_rsp_valid && prefetch_b_pending_r) begin
                        if (bank_response_has_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                        else begin
                            pre_b0_r<=bank0_data; pre_b1_r<=bank1_data;
                            pre_b2_r<=bank2_data; pre_b3_r<=bank3_data;
                            prefetch_b_pending_r<=0; prefetch_b_valid_r<=1;
                        end
                    end
                    if (prefetch_a_valid_r && prefetch_b_valid_r) begin
                        a0_r<=pre_a0_r; a1_r<=pre_a1_r; a2_r<=pre_a2_r; a3_r<=pre_a3_r;
                        b0_r<=pre_b0_r; b1_r<=pre_b1_r; b2_r<=pre_b2_r; b3_r<=pre_b3_r;
                        prefetch_a_valid_r<=0; prefetch_b_valid_r<=0;
                        k_group_r<=k_group_r+1'b1; lane_r<=0; state_r<=ST_MAC;
                    end
                end
                ST_WRITE: if (output_write_accepted) begin
                    if (output_write_has_protection_error) begin
                        error_code<=ERR_PROTECTION; state_r<=ST_ERROR;
                    end
                    else begin
                        result<=line_store_eligible ? line_wdata[127:96] :
                                                     spad_wdata;
                        element_count<=element_count+
                                       (line_store_eligible ? 4 : 1);
                        if (line_store_eligible) begin
                            if (write_idx_r==4'd12) state_r<=ST_NEXT;
                            else write_idx_r<=write_idx_r+4;
                        end else begin
                            if (write_idx_r==4'd15) state_r<=ST_NEXT;
                            else write_idx_r<=write_idx_r+1'b1;
                        end
                    end
                end
                ST_NEXT: begin
                    k_group_r<=0; lane_r<=0; write_idx_r<=0; bias_loaded_r<=0;
                    prefetch_a_pending_r<=0; prefetch_b_pending_r<=0;
                    prefetch_a_valid_r<=0; prefetch_b_valid_r<=0;
                    for (i=0;i<16;i=i+1) acc_r[i]<=0;
                    if (col_tile_r+1'b1 < n_tiles) begin
                        col_tile_r<=col_tile_r+1'b1;
                        b_tile_base_r<=b_tile_base_r+k_tile_bytes;
                        dst_tile_base_r<=dst_tile_base_r+32'd16;
                        bias_tile_base_r<=bias_tile_base_r+32'd16;
                        state_r<=ST_A_REQ;
                    end else if (row_tile_r+1'b1 < m_tiles) begin
                        row_tile_r<=row_tile_r+1'b1; col_tile_r<=0;
                        a_tile_base_r<=a_tile_base_r+k_tile_bytes;
                        b_tile_base_r<=b_batch_base_r;
                        dst_row_tile_base_r<=dst_row_tile_base_r+(dst_row_stride_r<<2);
                        dst_tile_base_r<=dst_row_tile_base_r+(dst_row_stride_r<<2);
                        bias_tile_base_r<=bias_base;
                        state_r<=ST_A_REQ;
                    end else if (instance_r+1'b1 < instance_count_r) begin
                        instance_r<=instance_r+1'b1; row_tile_r<=0; col_tile_r<=0;
                        a_batch_base_r<=a_batch_base_r+src0_batch_stride_r;
                        b_batch_base_r<=b_batch_base_r+src1_batch_stride_r;
                        dst_batch_base_r<=dst_batch_base_r+dst_batch_stride_r;
                        a_tile_base_r<=a_batch_base_r+src0_batch_stride_r;
                        b_tile_base_r<=b_batch_base_r+src1_batch_stride_r;
                        dst_row_tile_base_r<=dst_batch_base_r+dst_batch_stride_r;
                        dst_tile_base_r<=dst_batch_base_r+dst_batch_stride_r;
                        bias_tile_base_r<=bias_base;
                        state_r<=ST_A_REQ;
                    end else state_r<=ST_DONE;
                end
                ST_DONE: begin busy<=0; done<=1; error<=0; state_r<=ST_IDLE; end
                ST_ERROR: begin busy<=0; done<=1; error<=1; state_r<=ST_IDLE; end
                default: state_r<=ST_IDLE;
            endcase
        end
    end
endmodule
