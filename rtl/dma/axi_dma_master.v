`timescale 1ns / 1ps

// ============================================================================
// axi_dma_master
// ----------------------------------------------------------------------------
// 加速器私有 DMA。它是 AXI master，可以主动访问外部 DDR/memory，同时通过
// spad_* 端口访问片上 scratchpad。
//
// 模式：
//   store = 0：load，外部 memory -> scratchpad，用于搬 input/weight。
//   store = 1：store，scratchpad -> 外部 memory，用于搬 output。
//
// 设计要点：
//   - 每个 beat 为 32-bit word，对应 AXI size=2。
//   - 支持最多 MAX_BURST_LEN 个 beat 的 INCR burst。
//   - 避免 AXI burst 跨 4KB 边界，因此每次 burst 长度会同时受 remaining
//     和 4KB boundary 限制。
//   - 当前设计是单 outstanding DMA，便于验证和理解。
// ============================================================================
module axi_dma_master #(
    parameter integer MAX_BURST_LEN = 64,
    parameter integer MAX_READ_OUTSTANDING = 4
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire        start,
    input  wire        abort,
    input  wire        store,
    input  wire [31:0] ext_addr,
    input  wire [31:0] spad_addr,
    input  wire [15:0] length_words,
    // 2D mode: transfer ROW_COUNT rows of ROW_WORDS words.  Strides are byte
    // distances between consecutive row starts.  ROW_COUNT=0 retains the
    // legacy one-dimensional LENGTH_WORDS transfer.
    input  wire [15:0] row_words,
    input  wire [15:0] row_count,
    input  wire [31:0] ext_stride,
    input  wire [31:0] spad_stride,
    // A4 gather loads use a scratchpad table of absolute DDR byte addresses,
    // one entry per destination row.  Read outstanding is clamped to 1..4.
    input  wire        gather_enable,
    input  wire [31:0] gather_index_base,
    input  wire [2:0]  read_outstanding,
    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,

    output reg         spad_valid,
    output reg         spad_write,
    output reg  [31:0] spad_addr_o,
    output reg  [31:0] spad_wdata,
    input  wire        spad_ready,
    input  wire        spad_rsp_valid,
    input  wire [31:0] spad_rdata,
    input  wire        spad_req_error,
    input  wire        spad_rsp_error,

    output reg         m_axi_arvalid,
    output reg  [31:0] m_axi_araddr,
    output reg  [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    output wire [1:0]  m_axi_arburst,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    input  wire        m_axi_rlast,
    output wire        m_axi_rready,

    output reg         m_axi_awvalid,
    output reg  [31:0] m_axi_awaddr,
    output reg  [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    output wire [1:0]  m_axi_awburst,
    input  wire        m_axi_awready,
    output reg         m_axi_wvalid,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready
);

    localparam [2:0] AXI_SIZE_32B = 3'd2;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;

    localparam [3:0] ERR_NONE   = 4'd0;
    localparam [3:0] ERR_CONFIG = 4'd1;
    localparam [3:0] ERR_AXI_RD = 4'd2;
    localparam [3:0] ERR_AXI_WR = 4'd3;
    localparam [3:0] ERR_SPAD   = 4'd4;
    localparam [3:0] ERR_ABORT  = 4'd5;

    localparam ST_IDLE     = 4'd0;
    localparam ST_RD_ADDR  = 4'd1;
    localparam ST_RD_DATA  = 4'd2;
    localparam ST_WR_ADDR  = 4'd3;
    localparam ST_WR_DATA  = 4'd4;
    localparam ST_WR_RESP  = 4'd5;
    localparam ST_DONE     = 4'd6;
    localparam ST_ERROR    = 4'd7;
    localparam ST_WR_READ  = 4'd8;
    localparam ST_WR_WAIT  = 4'd9;
    localparam ST_RD_DRAIN = 4'd10;
    localparam ST_RD_PIPE   = 4'd11;

    reg [3:0]  state_r;
    reg        store_r;
    reg [31:0] ext_addr_r;
    reg [31:0] spad_addr_r;
    reg [15:0] remaining_r;
    reg [15:0] row_words_r;
    reg [15:0] rows_remaining_r;
    reg [31:0] row_ext_base_r;
    reg [31:0] row_spad_base_r;
    reg [31:0] ext_stride_r;
    reg [31:0] spad_stride_r;
    reg [7:0]  burst_len_r;
    reg [7:0]  beat_idx_r;
    reg [31:0] spad_read_data_r;
    reg        abort_pending_r;
    reg        write_error_pending_r;
    reg [3:0]  deferred_write_error_r;
    reg gather_enable_r;
    reg [31:0] gather_index_base_r;
    reg [15:0] gather_row_index_r;
    reg gather_need_index_r;
    reg gather_wait_rsp_r;
    reg [2:0] read_limit_r;
    reg [31:0] plan_ext_addr_r;
    reg [31:0] plan_spad_addr_r;
    reg [31:0] plan_row_ext_base_r;
    reg [31:0] plan_row_spad_base_r;
    reg [15:0] plan_remaining_r;
    reg [15:0] plan_rows_remaining_r;
    reg planner_done_r;
    reg [31:0] rd_spad_fifo [0:MAX_READ_OUTSTANDING-1];
    reg [7:0] rd_len_fifo [0:MAX_READ_OUTSTANDING-1];
    reg [1:0] rd_head_r, rd_tail_r;
    reg [2:0] rd_count_r;
    reg [7:0] rd_beat_idx_r;

    localparam [15:0] MAX_BURST_WORDS = MAX_BURST_LEN;

    wire [7:0] remaining_limited_len;
    wire [7:0] boundary_limited_len;
    wire [10:0] words_to_4kb_boundary;
    wire [7:0] next_burst_len;
    wire       last_beat;
    wire       abort_active;
    wire [7:0] plan_remaining_limited_len;
    wire [10:0] plan_words_to_4kb_boundary;
    wire [7:0] plan_boundary_limited_len;
    wire [7:0] plan_next_burst_len;
    wire rd_expected_last = rd_beat_idx_r == (rd_len_fifo[rd_head_r] - 8'd1);
    wire rd_ar_fire = state_r == ST_RD_PIPE && m_axi_arvalid && m_axi_arready;
    wire rd_r_fire = (state_r == ST_RD_PIPE || state_r == ST_RD_DRAIN) &&
                     m_axi_rvalid && m_axi_rready;
    wire rd_pop = rd_r_fire && m_axi_rlast;

    // 计算下一次 AXI burst 的长度：
    //   1. 不能超过剩余 word 数；
    //   2. 不能超过 MAX_BURST_LEN；
    //   3. 不能跨 4KB 边界，这是 AXI 协议常见约束。
    assign remaining_limited_len = (remaining_r >= MAX_BURST_WORDS) ?
                                   MAX_BURST_WORDS[7:0] : remaining_r[7:0];
    assign words_to_4kb_boundary = 11'd1024 - {1'b0, ext_addr_r[11:2]};
    assign boundary_limited_len  = (words_to_4kb_boundary > {3'd0, MAX_BURST_WORDS[7:0]}) ?
                                   MAX_BURST_WORDS[7:0] : words_to_4kb_boundary[7:0];
    assign next_burst_len = (remaining_limited_len > boundary_limited_len) ?
                            boundary_limited_len : remaining_limited_len;
    assign plan_remaining_limited_len = (plan_remaining_r >= MAX_BURST_WORDS) ?
                                        MAX_BURST_WORDS[7:0] : plan_remaining_r[7:0];
    assign plan_words_to_4kb_boundary = 11'd1024 - {1'b0, plan_ext_addr_r[11:2]};
    assign plan_boundary_limited_len =
        (plan_words_to_4kb_boundary > {3'd0, MAX_BURST_WORDS[7:0]}) ?
        MAX_BURST_WORDS[7:0] : plan_words_to_4kb_boundary[7:0];
    assign plan_next_burst_len =
        (plan_remaining_limited_len > plan_boundary_limited_len) ?
        plan_boundary_limited_len : plan_remaining_limited_len;
    assign last_beat = (beat_idx_r == (burst_len_r - 8'd1));

    assign m_axi_arsize  = AXI_SIZE_32B;
    assign m_axi_arburst = AXI_BURST_INCR;
    assign m_axi_awsize  = AXI_SIZE_32B;
    assign m_axi_awburst = AXI_BURST_INCR;
    assign abort_active = abort_pending_r || abort;
    assign m_axi_rready  = (state_r == ST_RD_DRAIN) ||
                           ((state_r == ST_RD_PIPE) && rd_count_r != 0 &&
                            (abort_active || m_axi_rresp != AXI_RESP_OKAY ||
                             m_axi_rlast != rd_expected_last || spad_ready)) ||
                           ((state_r == ST_RD_DATA) &&
                            (abort_active || spad_ready));
    assign m_axi_wdata   = spad_read_data_r;
    assign m_axi_wstrb   = 4'hf;
    assign m_axi_wlast   = (state_r == ST_WR_DATA) && last_beat;
    assign m_axi_bready  = (state_r == ST_WR_RESP);

    // scratchpad 端口控制：
    //   load: AXI RDATA 有效时，把数据写入 scratchpad；
    //   store: 在 AXI WDATA 阶段，从 scratchpad 读数据并送到 AXI WDATA。
    always @(*) begin
        spad_valid = 1'b0;
        spad_write = 1'b0;
        spad_addr_o = spad_addr_r + ({24'd0, beat_idx_r} << 2);
        spad_wdata = 32'd0;

        if (state_r == ST_RD_PIPE && m_axi_rvalid && rd_count_r != 0 &&
            !abort_active && m_axi_rresp == AXI_RESP_OKAY &&
            (m_axi_rlast == rd_expected_last)) begin
            spad_valid = 1'b1;
            spad_write = 1'b1;
            spad_addr_o = rd_spad_fifo[rd_head_r] + ({24'd0, rd_beat_idx_r} << 2);
            spad_wdata = m_axi_rdata;
        end else if (state_r == ST_RD_PIPE && gather_enable_r &&
                     gather_need_index_r && !gather_wait_rsp_r &&
                     !m_axi_rvalid) begin
            spad_valid = 1'b1;
            spad_write = 1'b0;
            spad_addr_o = gather_index_base_r + ({16'd0, gather_row_index_r} << 2);
        end else if (state_r == ST_RD_DATA && m_axi_rvalid && !abort_active) begin
            spad_valid = 1'b1;
            spad_write = 1'b1;
            spad_wdata = m_axi_rdata;
        end else if (state_r == ST_WR_READ) begin
            spad_valid = 1'b1;
            spad_write = 1'b0;
        end
    end

    // DMA 主状态机：
    //   load 路径 : IDLE -> RD_ADDR -> RD_DATA -> DONE/下一 burst
    //   store 路径: IDLE -> WR_ADDR -> WR_DATA -> WR_RESP -> DONE/下一 burst
    //
    // AXI 的 valid/ready 握手在各状态里推进；任何 AXI response error 或
    // scratchpad parity/range error 都会进入 ST_ERROR。
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r       <= ST_IDLE;
            store_r       <= 1'b0;
            ext_addr_r    <= 32'd0;
            spad_addr_r   <= 32'd0;
            remaining_r   <= 16'd0;
            row_words_r   <= 16'd0;
            rows_remaining_r <= 16'd0;
            row_ext_base_r <= 32'd0;
            row_spad_base_r <= 32'd0;
            ext_stride_r <= 32'd0;
            spad_stride_r <= 32'd0;
            burst_len_r   <= 8'd0;
            beat_idx_r    <= 8'd0;
            spad_read_data_r <= 32'd0;
            abort_pending_r <= 1'b0;
            write_error_pending_r <= 1'b0;
            deferred_write_error_r <= ERR_NONE;
            gather_enable_r <= 1'b0;
            gather_index_base_r <= 32'd0;
            gather_row_index_r <= 16'd0;
            gather_need_index_r <= 1'b0;
            gather_wait_rsp_r <= 1'b0;
            read_limit_r <= 3'd1;
            plan_ext_addr_r <= 32'd0;
            plan_spad_addr_r <= 32'd0;
            plan_row_ext_base_r <= 32'd0;
            plan_row_spad_base_r <= 32'd0;
            plan_remaining_r <= 16'd0;
            plan_rows_remaining_r <= 16'd0;
            planner_done_r <= 1'b0;
            rd_head_r <= 2'd0;
            rd_tail_r <= 2'd0;
            rd_count_r <= 3'd0;
            rd_beat_idx_r <= 8'd0;
            busy          <= 1'b0;
            done          <= 1'b0;
            error         <= 1'b0;
            error_code    <= ERR_NONE;
            m_axi_arvalid <= 1'b0;
            m_axi_araddr  <= 32'd0;
            m_axi_arlen   <= 8'd0;
            m_axi_awvalid <= 1'b0;
            m_axi_awaddr  <= 32'd0;
            m_axi_awlen   <= 8'd0;
            m_axi_wvalid  <= 1'b0;
        end else begin
            done <= 1'b0;
            if (busy && abort)
                abort_pending_r <= 1'b1;

            case (state_r)
                ST_IDLE: begin
                    // start 到来时锁存外部地址、scratchpad 地址和搬运长度。
                    // 地址必须 32-bit 对齐，长度不能为 0。
                    busy          <= 1'b0;
                    error         <= 1'b0;
                    m_axi_arvalid <= 1'b0;
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    abort_pending_r <= 1'b0;
                    write_error_pending_r <= 1'b0;
                    deferred_write_error_r <= ERR_NONE;
                    rd_head_r <= 2'd0;
                    rd_tail_r <= 2'd0;
                    rd_count_r <= 3'd0;
                    rd_beat_idx_r <= 8'd0;
                    planner_done_r <= 1'b0;
                    gather_need_index_r <= 1'b0;
                    gather_wait_rsp_r <= 1'b0;
                    if (start) begin
                        busy        <= 1'b1;
                        store_r     <= store;
                        ext_addr_r  <= ext_addr;
                        spad_addr_r <= spad_addr;
                        row_words_r <= (row_count == 16'd0) ? length_words : row_words;
                        remaining_r <= (row_count == 16'd0) ? length_words : row_words;
                        rows_remaining_r <= (row_count == 16'd0) ? 16'd1 : row_count;
                        row_ext_base_r <= ext_addr;
                        row_spad_base_r <= spad_addr;
                        ext_stride_r <= (ext_stride == 32'd0) ?
                                        ({16'd0, ((row_count == 16'd0) ? length_words : row_words)} << 2) : ext_stride;
                        spad_stride_r <= (spad_stride == 32'd0) ?
                                         ({16'd0, ((row_count == 16'd0) ? length_words : row_words)} << 2) : spad_stride;
                        gather_enable_r <= gather_enable;
                        gather_index_base_r <= gather_index_base;
                        gather_row_index_r <= 16'd0;
                        read_limit_r <= (read_outstanding == 0) ? 3'd1 :
                                        (read_outstanding > MAX_READ_OUTSTANDING ?
                                         MAX_READ_OUTSTANDING[2:0] : read_outstanding);
                        plan_ext_addr_r <= ext_addr;
                        plan_spad_addr_r <= spad_addr;
                        plan_row_ext_base_r <= ext_addr;
                        plan_row_spad_base_r <= spad_addr;
                        plan_remaining_r <= (row_count == 16'd0) ? length_words : row_words;
                        plan_rows_remaining_r <= (row_count == 16'd0) ? 16'd1 : row_count;
                        gather_need_index_r <= gather_enable;
                        beat_idx_r  <= 8'd0;
                        error_code  <= ERR_NONE;
                        if (((row_count == 16'd0) ? length_words : row_words) == 16'd0 ||
                            (!gather_enable && ext_addr[1:0] != 2'b00) ||
                            (spad_addr[1:0] != 2'b00) ||
                            (ext_stride[1:0] != 2'b00) || (spad_stride[1:0] != 2'b00)) begin
                            error_code <= ERR_CONFIG;
                            state_r    <= ST_ERROR;
                        end else if (gather_enable &&
                                     (store || row_count == 0 || gather_index_base[1:0] != 0)) begin
                            error_code <= ERR_CONFIG;
                            state_r <= ST_ERROR;
                        end else if (store) begin
                            state_r <= ST_WR_ADDR;
                        end else begin
                            state_r <= ST_RD_PIPE;
                        end
                    end
                end
                ST_RD_PIPE: begin
                    // Independent address planner plus an ordered metadata
                    // FIFO.  All transactions use one AXI ID, so R bursts
                    // return in AR issue order and require no data reorder RAM.
                    if (gather_enable_r && gather_need_index_r &&
                        !gather_wait_rsp_r && !m_axi_rvalid && spad_ready)
                        gather_wait_rsp_r <= 1'b1;

                    if (gather_wait_rsp_r && spad_rsp_valid) begin
                        gather_wait_rsp_r <= 1'b0;
                        if (spad_rsp_error || spad_rdata[1:0] != 0) begin
                            error_code <= spad_rsp_error ? ERR_SPAD : ERR_CONFIG;
                            m_axi_arvalid <= 1'b0;
                            state_r <= (rd_count_r == 0) ? ST_ERROR : ST_RD_DRAIN;
                        end else begin
                            plan_ext_addr_r <= spad_rdata;
                            plan_remaining_r <= row_words_r;
                            gather_need_index_r <= 1'b0;
                        end
                    end

                    if (!m_axi_arvalid && !planner_done_r &&
                        !gather_need_index_r && !gather_wait_rsp_r &&
                        rd_count_r < read_limit_r && !abort_active) begin
                        m_axi_araddr <= plan_ext_addr_r;
                        m_axi_arlen <= plan_next_burst_len - 8'd1;
                        m_axi_arvalid <= 1'b1;
                    end

                    if (rd_ar_fire) begin
                        m_axi_arvalid <= 1'b0;
                        rd_spad_fifo[rd_tail_r] <= plan_spad_addr_r;
                        rd_len_fifo[rd_tail_r] <= m_axi_arlen + 8'd1;
                        rd_tail_r <= rd_tail_r + 1'b1;

                        if (plan_remaining_r == {8'd0, (m_axi_arlen + 8'd1)}) begin
                            if (plan_rows_remaining_r == 16'd1) begin
                                planner_done_r <= 1'b1;
                            end else begin
                                plan_rows_remaining_r <= plan_rows_remaining_r - 1'b1;
                                plan_row_spad_base_r <= plan_row_spad_base_r + spad_stride_r;
                                plan_spad_addr_r <= plan_row_spad_base_r + spad_stride_r;
                                if (gather_enable_r) begin
                                    gather_row_index_r <= gather_row_index_r + 1'b1;
                                    gather_need_index_r <= 1'b1;
                                end else begin
                                    plan_row_ext_base_r <= plan_row_ext_base_r + ext_stride_r;
                                    plan_ext_addr_r <= plan_row_ext_base_r + ext_stride_r;
                                    plan_remaining_r <= row_words_r;
                                end
                            end
                        end else begin
                            plan_remaining_r <= plan_remaining_r -
                                                {8'd0, (m_axi_arlen + 8'd1)};
                            plan_ext_addr_r <= plan_ext_addr_r +
                                               ({24'd0, (m_axi_arlen + 8'd1)} << 2);
                            plan_spad_addr_r <= plan_spad_addr_r +
                                                ({24'd0, (m_axi_arlen + 8'd1)} << 2);
                        end
                    end

                    if (rd_r_fire) begin
                        if (abort_active) begin
                            error_code <= ERR_ABORT;
                            m_axi_arvalid <= 1'b0;
                            planner_done_r <= 1'b1;
                            state_r <= (m_axi_rlast && rd_count_r == 1 &&
                                       !rd_ar_fire) ? ST_ERROR : ST_RD_DRAIN;
                        end else if (m_axi_rresp != AXI_RESP_OKAY ||
                                     m_axi_rlast != rd_expected_last ||
                                     spad_req_error) begin
                            error_code <= spad_req_error ? ERR_SPAD : ERR_AXI_RD;
                            m_axi_arvalid <= 1'b0;
                            planner_done_r <= 1'b1;
                            state_r <= (m_axi_rlast && rd_count_r == 1 &&
                                       !rd_ar_fire) ? ST_ERROR : ST_RD_DRAIN;
                        end else if (m_axi_rlast) begin
                            rd_head_r <= rd_head_r + 1'b1;
                            rd_beat_idx_r <= 8'd0;
                            if (planner_done_r && rd_count_r == 1 && !rd_ar_fire)
                                state_r <= ST_DONE;
                        end else begin
                            rd_beat_idx_r <= rd_beat_idx_r + 1'b1;
                        end
                    end

                    case ({rd_ar_fire, rd_pop})
                      2'b10: rd_count_r <= rd_count_r + 1'b1;
                      2'b01: rd_count_r <= rd_count_r - 1'b1;
                      default: rd_count_r <= rd_count_r;
                    endcase

                    if (abort_active && !rd_r_fire) begin
                        m_axi_arvalid <= 1'b0;
                        planner_done_r <= 1'b1;
                        error_code <= ERR_ABORT;
                        state_r <= (rd_count_r == 0) ? ST_ERROR : ST_RD_DRAIN;
                    end
                end
                ST_RD_ADDR: begin
                    // 发 AXI read address。arlen = burst_len - 1。
                    if (!m_axi_arvalid) begin
                        if (abort_active) begin
                            error_code <= ERR_ABORT;
                            state_r <= ST_ERROR;
                        end else begin
                            burst_len_r   <= next_burst_len;
                            beat_idx_r    <= 8'd0;
                            m_axi_araddr  <= ext_addr_r;
                            m_axi_arlen   <= next_burst_len - 8'd1;
                            m_axi_arvalid <= 1'b1;
                        end
                    end else if (abort_active && !m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        error_code <= ERR_ABORT;
                        state_r <= ST_ERROR;
                    end else if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        state_r       <= abort_active ? ST_RD_DRAIN : ST_RD_DATA;
                    end
                end
                ST_RD_DATA: begin
                    // 接收 AXI read data，并同步写入 scratchpad。
                    // 同时检查 rresp 和 rlast 是否符合本次 burst 的预期。
                    if (abort_active) begin
                        error_code <= ERR_ABORT;
                        if (m_axi_rvalid && m_axi_rlast)
                            state_r <= ST_ERROR;
                        else
                            state_r <= ST_RD_DRAIN;
                    end else if (m_axi_rvalid && spad_ready) begin
                        if ((m_axi_rresp != AXI_RESP_OKAY) || (m_axi_rlast != last_beat)) begin
                            error_code <= ERR_AXI_RD;
                            state_r    <= m_axi_rlast ? ST_ERROR : ST_RD_DRAIN;
                        end else if (spad_req_error) begin
                            error_code <= ERR_SPAD;
                            state_r    <= m_axi_rlast ? ST_ERROR : ST_RD_DRAIN;
                        end else if (last_beat) begin
                            remaining_r <= remaining_r - {8'd0, burst_len_r};
                            if (remaining_r == {8'd0, burst_len_r}) begin
                                if (rows_remaining_r == 16'd1) begin
                                    state_r <= ST_DONE;
                                end else begin
                                    row_ext_base_r <= row_ext_base_r + ext_stride_r;
                                    row_spad_base_r <= row_spad_base_r + spad_stride_r;
                                    ext_addr_r <= row_ext_base_r + ext_stride_r;
                                    spad_addr_r <= row_spad_base_r + spad_stride_r;
                                    remaining_r <= row_words_r;
                                    rows_remaining_r <= rows_remaining_r - 16'd1;
                                    state_r <= ST_RD_ADDR;
                                end
                            end else begin
                                ext_addr_r  <= ext_addr_r + ({24'd0, burst_len_r} << 2);
                                spad_addr_r <= spad_addr_r + ({24'd0, burst_len_r} << 2);
                                state_r <= ST_RD_ADDR;
                            end
                        end else begin
                            beat_idx_r <= beat_idx_r + 8'd1;
                        end
                    end
                end
                ST_RD_DRAIN: begin
                    // Stop issuing AR and drain every accepted same-ID burst
                    // before exposing done/error to software.
                    m_axi_arvalid <= 1'b0;
                    if (rd_r_fire && m_axi_rlast) begin
                        rd_head_r <= rd_head_r + 1'b1;
                        rd_beat_idx_r <= 8'd0;
                        rd_count_r <= rd_count_r - 1'b1;
                        if (rd_count_r == 1)
                            state_r <= ST_ERROR;
                    end else if (rd_r_fire) begin
                        rd_beat_idx_r <= rd_beat_idx_r + 1'b1;
                    end else if (rd_count_r == 0) begin
                        state_r <= ST_ERROR;
                    end
                end
                ST_WR_ADDR: begin
                    // 发 AXI write address。地址握手完成后开始写数据 beat。
                    if (!m_axi_awvalid) begin
                        if (abort_active) begin
                            error_code <= ERR_ABORT;
                            state_r <= ST_ERROR;
                        end else begin
                            burst_len_r   <= next_burst_len;
                            beat_idx_r    <= 8'd0;
                            m_axi_awaddr  <= ext_addr_r;
                            m_axi_awlen   <= next_burst_len - 8'd1;
                            m_axi_awvalid <= 1'b1;
                        end
                    end else if (abort_active && !m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        error_code <= ERR_ABORT;
                        state_r <= ST_ERROR;
                    end else if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        state_r       <= ST_WR_READ;
                    end
                end
                ST_WR_READ: begin
                    // Request one synchronous scratchpad word.  WVALID is
                    // asserted for the following cycle, when registered data
                    // is available on m_axi_wdata.
                    if (spad_ready)
                        state_r <= ST_WR_WAIT;
                end
                ST_WR_WAIT: begin
                    if (spad_rsp_valid) begin
                        if (spad_rsp_error) begin
                            // AW is already committed.  Defer the local error
                            // until every W beat and the B response complete.
                            write_error_pending_r <= 1'b1;
                            deferred_write_error_r <= ERR_SPAD;
                        end
                        // The response data is valid whenever spad_rsp_valid
                        // is high.  Preserve it even while recording an error;
                        // this also avoids propagating an idle X on the error
                        // sideband into an otherwise valid AXI write beat.
                        spad_read_data_r <= spad_rdata;
                        m_axi_wvalid <= 1'b1;
                        state_r <= ST_WR_DATA;
                    end
                end
                ST_WR_DATA: begin
                    // 写数据阶段。m_axi_wdata 直接来自 spad_rdata，
                    // 每个 beat 推进 scratchpad 地址和 AXI beat index。
                    if (m_axi_wready) begin
                        if (last_beat) begin
                            m_axi_wvalid <= 1'b0;
                            state_r      <= ST_WR_RESP;
                        end else begin
                            beat_idx_r <= beat_idx_r + 8'd1;
                            m_axi_wvalid <= 1'b0;
                            state_r <= ST_WR_READ;
                        end
                    end
                end
                ST_WR_RESP: begin
                    // 等待 AXI write response。OKAY 后进入下一 burst 或 DONE。
                    if (m_axi_bvalid) begin
                        if (abort_active) begin
                            error_code <= ERR_ABORT;
                            state_r <= ST_ERROR;
                        end else if (m_axi_bresp != AXI_RESP_OKAY) begin
                            error_code <= ERR_AXI_WR;
                            state_r    <= ST_ERROR;
                        end else if (write_error_pending_r) begin
                            error_code <= deferred_write_error_r;
                            state_r <= ST_ERROR;
                        end else begin
                            remaining_r <= remaining_r - {8'd0, burst_len_r};
                            if (remaining_r == {8'd0, burst_len_r}) begin
                                if (rows_remaining_r == 16'd1) begin
                                    state_r <= ST_DONE;
                                end else begin
                                    row_ext_base_r <= row_ext_base_r + ext_stride_r;
                                    row_spad_base_r <= row_spad_base_r + spad_stride_r;
                                    ext_addr_r <= row_ext_base_r + ext_stride_r;
                                    spad_addr_r <= row_spad_base_r + spad_stride_r;
                                    remaining_r <= row_words_r;
                                    rows_remaining_r <= rows_remaining_r - 16'd1;
                                    state_r <= ST_WR_ADDR;
                                end
                            end else begin
                                ext_addr_r  <= ext_addr_r + ({24'd0, burst_len_r} << 2);
                                spad_addr_r <= spad_addr_r + ({24'd0, burst_len_r} << 2);
                                state_r <= ST_WR_ADDR;
                            end
                        end
                    end
                end
                ST_DONE: begin
                    busy       <= 1'b0;
                    done       <= 1'b1;
                    error      <= 1'b0;
                    error_code <= ERR_NONE;
                    state_r    <= ST_IDLE;
                end
                ST_ERROR: begin
                    busy          <= 1'b0;
                    done          <= 1'b1;
                    error         <= 1'b1;
                    m_axi_arvalid <= 1'b0;
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    abort_pending_r <= 1'b0;
                    write_error_pending_r <= 1'b0;
                    state_r       <= ST_IDLE;
                end
                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
