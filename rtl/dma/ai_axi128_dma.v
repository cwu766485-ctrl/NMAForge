`timescale 1ns / 1ps

// Unified payload DMA for the CIMForge AI accelerator.
//
// The external data path is 128-bit AXI4.  Reads use IDs 1..4 and a per-ID
// burst buffer, so completed bursts may return out of order.  Writes use IDs
// 8..11; AXI4 write data remains ordered, while B responses may return in any
// order.  Both directions issue up to MAX_BURST_BEATS beats per burst and
// split requests at 4-KiB boundaries.
//
// One-dimensional, strided two-dimensional, gather-load, and tile traffic all
// use this module.  Word-aligned external rows are accepted: short 32-bit
// alignment beats are emitted until a 16-byte boundary is reached, after which
// the transfer automatically uses 128-bit bursts.  A partial final line is
// represented by a full 128-bit read beat or by WSTRB on writes.
module ai_axi128_dma #(
    parameter integer MAX_OUTSTANDING = 4,
    parameter integer MAX_BURST_BEATS = 16,
    parameter integer AXI_ADDR_WIDTH = 64
)(
    input  wire         clk,
    input  wire         resetn,
    input  wire         start,
    input  wire         abort,
    input  wire         store,
    input  wire [AXI_ADDR_WIDTH-1:0] ext_addr,
    input  wire [31:0]  spad_addr,
    input  wire [15:0]  length_words,
    input  wire [15:0]  row_words,
    input  wire [15:0]  row_count,
    input  wire [31:0]  ext_stride,
    input  wire [31:0]  spad_stride,
    input  wire         gather_enable,
    input  wire [31:0]  gather_index_base,
    input  wire [2:0]   read_outstanding,
    output reg          busy,
    output reg          done,
    output reg          error,
    output reg  [3:0]   error_code,

    output reg          spad_valid,
    output reg          spad_write,
    output reg  [31:0]  spad_addr_o,
    output reg  [31:0]  spad_wdata,
    input  wire         spad_ready,
    input  wire         spad_rsp_valid,
    input  wire [31:0]  spad_rdata,
    input  wire         spad_req_error,
    input  wire         spad_rsp_error,
    output reg          spad_line_valid,
    output reg          spad_line_write,
    output reg  [31:0]  spad_line_addr,
    output reg  [127:0] spad_line_wdata,
    output reg  [15:0]  spad_line_wstrb,
    input  wire         spad_line_ready,
    input  wire         spad_line_rsp_valid,
    input  wire [127:0] spad_line_rdata,
    input  wire         spad_line_req_error,
    input  wire         spad_line_rsp_error,
    input  wire [3:0]   spad_line_parity_error,

    output reg  [3:0]   m_axi_arid,
    output reg          m_axi_arvalid,
    output reg  [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output reg  [7:0]   m_axi_arlen,
    output reg  [2:0]   m_axi_arsize,
    output wire [1:0]   m_axi_arburst,
    input  wire         m_axi_arready,
    input  wire [3:0]   m_axi_rid,
    input  wire [127:0] m_axi_rdata,
    input  wire [1:0]   m_axi_rresp,
    input  wire         m_axi_rvalid,
    input  wire         m_axi_rlast,
    output wire         m_axi_rready,

    output reg  [3:0]   m_axi_awid,
    output reg          m_axi_awvalid,
    output reg  [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg  [7:0]   m_axi_awlen,
    output reg  [2:0]   m_axi_awsize,
    output wire [1:0]   m_axi_awburst,
    input  wire         m_axi_awready,
    output reg          m_axi_wvalid,
    output reg  [127:0] m_axi_wdata,
    output reg  [15:0]  m_axi_wstrb,
    output wire         m_axi_wlast,
    input  wire         m_axi_wready,
    input  wire [3:0]   m_axi_bid,
    input  wire [1:0]   m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire         m_axi_bready,

    output wire [2:0]   rd_outstanding,
    output wire [2:0]   rd_highwater,
    output reg  [4:0]   r_beat_bytes,
    output reg  [4:0]   w_beat_bytes
);
    localparam [2:0] AXI_SIZE_32 = 3'd2;
    localparam [2:0] AXI_SIZE_128 = 3'd4;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;
    localparam [3:0] ERR_NONE=0, ERR_CONFIG=1, ERR_AXI_RD=2,
                     ERR_AXI_WR=3, ERR_SPAD=4, ERR_ABORT=5;
    localparam [3:0] ST_IDLE=0, ST_READ=1, ST_WRITE_PLAN=2,
                     ST_WRITE_GATHER=3, ST_WRITE_AW=4, ST_WRITE_W=5,
                     ST_WRITE_DRAIN=6, ST_DONE=7, ST_ERROR=8,
                     // Abort is not allowed to discard an AXI read response.
                     // This state accepts every already-issued read through
                     // RLAST, without committing it to scratchpad.
                     ST_ABORT_READ=9;

    reg [3:0] state_r;
    reg [2:0] read_limit_r;
    reg [2:0] rd_highwater_r;
    reg       abort_pending_r;

    // Common row/burst planner.  row_count==0 denotes a one-dimensional job.
    reg [AXI_ADDR_WIDTH-1:0] plan_ext_r, plan_row_ext_r;
    reg [31:0] plan_spad_r, plan_row_spad_r;
    reg [15:0] plan_remaining_r, plan_rows_remaining_r;
    reg [15:0] row_words_r;
    reg [31:0] ext_stride_r, spad_stride_r;
    reg        planner_done_r;
    reg        gather_enable_r, gather_need_index_r, gather_wait_rsp_r;
    reg [31:0] gather_index_base_r;
    reg [15:0] gather_row_index_r;

    // Four tagged read-burst slots.  The data RAM is statically sized for four
    // IDs; MAX_OUTSTANDING controls admission and is clamped to that range.
    reg [3:0]  rd_slot_valid_r;
    reg [3:0]  rd_slot_complete_r;
    reg [4:0]  rd_slot_expected_r [0:3];
    reg [4:0]  rd_slot_received_r [0:3];
    reg [15:0] rd_slot_words_r [0:3];
    reg [15:0] rd_slot_word_index_r [0:3];
    reg [31:0] rd_slot_spad_r [0:3];
    reg [3:0]  rd_slot_wide_r;
    reg [1:0]  rd_slot_narrow_lane_r [0:3];
    reg [127:0] rd_data_r [0:(4*MAX_BURST_BEATS)-1];

    // One write burst is gathered from the scalar scratchpad port at a time.
    // Up to four previously transmitted bursts may independently await B.
    reg [127:0] wr_data_r [0:MAX_BURST_BEATS-1];
    reg [15:0] wr_burst_words_r;
    reg [4:0]  wr_burst_beats_r;
    reg [15:0] wr_word_index_r;
    reg [4:0]  wr_beat_index_r;
    reg        wr_read_pending_r;
    reg        wr_read_line_r;
    reg [3:0]  wr_pending_b_r;
    reg [2:0]  wr_pending_count_r;
    reg [1:0]  wr_active_tag_r;

    integer i;
    reg [2:0] rd_count_comb;
    reg [1:0] rd_free_slot_comb, rd_drain_slot_comb;
    reg rd_free_found_comb, rd_drain_found_comb;
    reg [1:0] rd_rid_index_comb;
    reg rid_is_dma_comb;
    reg [1:0] wr_bid_index_comb, wr_free_tag_comb;
    reg bid_is_dma_comb, wr_free_found_comb;
    reg [8:0] boundary_beats_comb;
    reg [15:0] remaining_beats_comb;
    reg [4:0] plan_beats_comb;
    reg [15:0] plan_words_comb;
    reg [31:0] plan_bytes_comb;
    reg plan_wide_comb;
    reg [15:0] rd_drain_word_comb;
    reg [4:0] rd_drain_beat_comb;
    reg [1:0] rd_drain_lane_comb;
    reg [127:0] rd_drain_data_comb;
    reg [15:0] final_write_strobe_comb;
    reg [15:0] rd_drain_words_left_comb;
    reg [31:0] rd_drain_spad_addr_comb;
    reg rd_drain_line_comb;
    reg [15:0] wr_gather_words_left_comb;
    reg [31:0] wr_gather_spad_addr_comb;
    reg wr_gather_line_comb;

    wire ar_fire = m_axi_arvalid && m_axi_arready;
    wire r_fire = m_axi_rvalid && m_axi_rready;
    wire aw_fire = m_axi_awvalid && m_axi_awready;
    wire w_fire = m_axi_wvalid && m_axi_wready;
    wire b_fire = m_axi_bvalid && m_axi_bready;
    wire wlast_fire = w_fire && m_axi_wlast;

    always @(*) begin
        rd_count_comb = 0;
        rd_free_slot_comb = 0;
        rd_free_found_comb = 0;
        rd_drain_slot_comb = 0;
        rd_drain_found_comb = 0;
        for (i=0; i<4; i=i+1) begin
            if (rd_slot_valid_r[i])
                rd_count_comb = rd_count_comb + 1'b1;
            if (!rd_slot_valid_r[i] && !rd_free_found_comb &&
                i < MAX_OUTSTANDING) begin
                rd_free_found_comb = 1'b1;
                rd_free_slot_comb = i[1:0];
            end
            if (rd_slot_complete_r[i] && !rd_drain_found_comb) begin
                rd_drain_found_comb = 1'b1;
                rd_drain_slot_comb = i[1:0];
            end
        end

        rid_is_dma_comb = (m_axi_rid >= 4'd1) && (m_axi_rid <= 4'd4);
        rd_rid_index_comb = m_axi_rid - 4'd1;
        bid_is_dma_comb = (m_axi_bid >= 4'd8) && (m_axi_bid <= 4'd11);
        wr_bid_index_comb = m_axi_bid - 4'd8;

        wr_free_tag_comb = 0;
        wr_free_found_comb = 0;
        for (i=0; i<4; i=i+1) begin
            if (!wr_pending_b_r[i] && !wr_free_found_comb) begin
                wr_free_found_comb = 1'b1;
                wr_free_tag_comb = i[1:0];
            end
        end

        // Word-aligned but non-line-aligned rows use short 32-bit alignment
        // beats.  Once aligned, the planner switches to 128-bit bursts.
        plan_wide_comb = (plan_ext_r[3:0] == 0);
        boundary_beats_comb = (13'd4096 - {1'b0, plan_ext_r[11:0]}) >> 4;
        remaining_beats_comb = (plan_remaining_r + 16'd3) >> 2;
        if (!plan_wide_comb) begin
            plan_beats_comb = 1;
            plan_words_comb = 1;
            plan_bytes_comb = 4;
        end else begin
            if (remaining_beats_comb > MAX_BURST_BEATS)
                plan_beats_comb = MAX_BURST_BEATS;
            else
                plan_beats_comb = remaining_beats_comb[4:0];
            if (boundary_beats_comb < plan_beats_comb)
                plan_beats_comb = boundary_beats_comb[4:0];
            if (plan_remaining_r < ({11'd0, plan_beats_comb} << 2))
                plan_words_comb = plan_remaining_r;
            else
                plan_words_comb = ({11'd0, plan_beats_comb} << 2);
            plan_bytes_comb = {27'd0, plan_beats_comb} << 4;
        end

        rd_drain_word_comb = rd_slot_word_index_r[rd_drain_slot_comb];
        rd_drain_beat_comb = rd_drain_word_comb[15:2];
        rd_drain_lane_comb = rd_slot_wide_r[rd_drain_slot_comb] ?
                             rd_drain_word_comb[1:0] :
                             rd_slot_narrow_lane_r[rd_drain_slot_comb];
        rd_drain_data_comb =
            rd_data_r[(rd_drain_slot_comb * MAX_BURST_BEATS) +
                      rd_drain_beat_comb];
        rd_drain_words_left_comb =
            rd_slot_words_r[rd_drain_slot_comb] - rd_drain_word_comb;
        rd_drain_spad_addr_comb =
            rd_slot_spad_r[rd_drain_slot_comb] +
            ({16'd0, rd_drain_word_comb} << 2);
        rd_drain_line_comb = rd_drain_found_comb &&
                             rd_drain_spad_addr_comb[3:0] == 0 &&
                             rd_drain_word_comb[1:0] == 0 &&
                             rd_drain_words_left_comb >= 4;
        wr_gather_words_left_comb = wr_burst_words_r - wr_word_index_r;
        wr_gather_spad_addr_comb =
            plan_spad_r + ({16'd0, wr_word_index_r} << 2);
        wr_gather_line_comb = state_r == ST_WRITE_GATHER &&
                              wr_gather_spad_addr_comb[3:0] == 0 &&
                              wr_word_index_r[1:0] == 0 &&
                              wr_gather_words_left_comb >= 4;

        case (wr_burst_words_r[1:0])
          2'd1: final_write_strobe_comb = 16'h000f;
          2'd2: final_write_strobe_comb = 16'h00ff;
          2'd3: final_write_strobe_comb = 16'h0fff;
          default: final_write_strobe_comb = 16'hffff;
        endcase
    end

    assign m_axi_arburst = AXI_BURST_INCR;
    assign m_axi_awburst = AXI_BURST_INCR;
    assign m_axi_wlast = m_axi_wvalid &&
                         (wr_beat_index_r + 1'b1 >= wr_burst_beats_r);
    assign m_axi_rready = ((state_r == ST_READ) ||
                           (state_r == ST_ABORT_READ)) && rid_is_dma_comb &&
                          rd_slot_valid_r[rd_rid_index_comb] &&
                          ((state_r == ST_ABORT_READ) ||
                           !rd_slot_complete_r[rd_rid_index_comb]);
    assign m_axi_bready = bid_is_dma_comb &&
                          wr_pending_b_r[wr_bid_index_comb];
    assign rd_outstanding = rd_count_comb;
    assign rd_highwater = rd_highwater_r;

    always @(*) begin
        spad_valid = 1'b0;
        spad_write = 1'b0;
        spad_addr_o = 0;
        spad_wdata = 0;
        spad_line_valid = 1'b0;
        spad_line_write = 1'b0;
        spad_line_addr = 0;
        spad_line_wdata = 0;
        spad_line_wstrb = 0;
        if (state_r == ST_READ && rd_drain_line_comb) begin
            spad_line_valid = 1'b1;
            spad_line_write = 1'b1;
            spad_line_addr = rd_drain_spad_addr_comb;
            spad_line_wdata = rd_drain_data_comb;
            spad_line_wstrb = 16'hffff;
        end else if (state_r == ST_READ && rd_drain_found_comb) begin
            spad_valid = 1'b1;
            spad_write = 1'b1;
            spad_addr_o = rd_slot_spad_r[rd_drain_slot_comb] +
                          ({16'd0, rd_drain_word_comb} << 2);
            case (rd_drain_lane_comb)
              2'd0: spad_wdata = rd_drain_data_comb[31:0];
              2'd1: spad_wdata = rd_drain_data_comb[63:32];
              2'd2: spad_wdata = rd_drain_data_comb[95:64];
              default: spad_wdata = rd_drain_data_comb[127:96];
            endcase
        end else if (state_r == ST_READ && gather_need_index_r &&
                     !gather_wait_rsp_r) begin
            spad_valid = 1'b1;
            spad_write = 1'b0;
            spad_addr_o = gather_index_base_r +
                          ({16'd0, gather_row_index_r} << 2);
        end else if (state_r == ST_WRITE_GATHER && !wr_read_pending_r) begin
            if (wr_gather_line_comb) begin
                spad_line_valid = 1'b1;
                spad_line_write = 1'b0;
                spad_line_addr = wr_gather_spad_addr_comb;
            end else begin
                spad_valid = 1'b1;
                spad_write = 1'b0;
                spad_addr_o = wr_gather_spad_addr_comb;
            end
        end
    end

    always @(*) begin
        r_beat_bytes = 5'd16;
        if (rid_is_dma_comb &&
            (rd_slot_received_r[rd_rid_index_comb] + 1'b1 >=
             rd_slot_expected_r[rd_rid_index_comb]) &&
            rd_slot_words_r[rd_rid_index_comb][1:0] != 0)
            r_beat_bytes =
                {1'b0, rd_slot_words_r[rd_rid_index_comb][1:0], 2'b00};

        w_beat_bytes = 5'd16;
        if (m_axi_wlast && wr_burst_words_r[1:0] != 0)
            w_beat_bytes = {1'b0, wr_burst_words_r[1:0], 2'b00};
    end

    always @(posedge clk or negedge resetn) begin
      if (!resetn) begin
        state_r <= ST_IDLE;
        busy <= 0;
        done <= 0;
        error <= 0;
        error_code <= ERR_NONE;
        read_limit_r <= 3'd4;
        rd_highwater_r <= 0;
        abort_pending_r <= 1'b0;
        plan_ext_r <= 0;
        plan_spad_r <= 0;
        plan_row_ext_r <= 0;
        plan_row_spad_r <= 0;
        plan_remaining_r <= 0;
        plan_rows_remaining_r <= 0;
        row_words_r <= 0;
        ext_stride_r <= 0;
        spad_stride_r <= 0;
        planner_done_r <= 0;
        gather_enable_r <= 0;
        gather_need_index_r <= 0;
        gather_wait_rsp_r <= 0;
        gather_index_base_r <= 0;
        gather_row_index_r <= 0;
        rd_slot_valid_r <= 0;
        rd_slot_complete_r <= 0;
        rd_slot_wide_r <= 0;
        wr_burst_words_r <= 0;
        wr_burst_beats_r <= 0;
        wr_word_index_r <= 0;
        wr_beat_index_r <= 0;
        wr_read_pending_r <= 0;
        wr_read_line_r <= 0;
        wr_pending_b_r <= 0;
        wr_pending_count_r <= 0;
        wr_active_tag_r <= 0;
        m_axi_arid <= 0;
        m_axi_arvalid <= 0;
        m_axi_araddr <= 0;
        m_axi_arlen <= 0;
        m_axi_arsize <= AXI_SIZE_128;
        m_axi_awid <= 0;
        m_axi_awvalid <= 0;
        m_axi_awaddr <= 0;
        m_axi_awlen <= 0;
        m_axi_awsize <= AXI_SIZE_128;
        m_axi_wvalid <= 0;
        m_axi_wdata <= 0;
        m_axi_wstrb <= 0;
        for (i=0; i<4; i=i+1) begin
          rd_slot_expected_r[i] <= 0;
          rd_slot_received_r[i] <= 0;
          rd_slot_words_r[i] <= 0;
          rd_slot_word_index_r[i] <= 0;
          rd_slot_spad_r[i] <= 0;
          rd_slot_narrow_lane_r[i] <= 0;
        end
        end else begin
        done <= 1'b0;

        // Abort is sticky until an accepted write burst has been drained.
        // A read transfer has its own drain state below.  No new transaction
        // may be planned after this point.
        if (abort && busy) begin
          error <= 1'b1;
          error_code <= ERR_ABORT;
          if ((state_r == ST_WRITE_W) || (state_r == ST_WRITE_DRAIN) ||
              ((state_r == ST_WRITE_AW) && aw_fire))
            abort_pending_r <= 1'b1;
        end

        // B responses are independent of write-data issue and may be OoO.
        if (b_fire) begin
          wr_pending_b_r[wr_bid_index_comb] <= 1'b0;
          if (m_axi_bresp != AXI_RESP_OKAY) begin
            error <= 1'b1;
            error_code <= ERR_AXI_WR;
            state_r <= ST_ERROR;
          end
        end
        if (wlast_fire)
          wr_pending_b_r[wr_active_tag_r] <= 1'b1;
        case ({wlast_fire, b_fire})
          2'b10: wr_pending_count_r <= wr_pending_count_r + 1'b1;
          2'b01: wr_pending_count_r <= wr_pending_count_r - 1'b1;
          default: wr_pending_count_r <= wr_pending_count_r;
        endcase

        if ((spad_req_error || spad_rsp_error || spad_line_req_error ||
             (spad_line_rsp_valid &&
              (spad_line_rsp_error || |spad_line_parity_error))) && busy) begin
          error <= 1'b1;
          error_code <= ERR_SPAD;
          m_axi_arvalid <= 1'b0;
          m_axi_awvalid <= 1'b0;
          m_axi_wvalid <= 1'b0;
          state_r <= ST_ERROR;
        end else begin
          case (state_r)
            ST_IDLE: begin
              busy <= 1'b0;
              error <= 1'b0;
              error_code <= ERR_NONE;
              abort_pending_r <= 1'b0;
              m_axi_arvalid <= 1'b0;
              m_axi_awvalid <= 1'b0;
              m_axi_wvalid <= 1'b0;
              if (start) begin
                if (((row_count == 0) ? length_words : row_words) == 0 ||
                    spad_addr[1:0] != 0 ||
                    (!gather_enable && ext_addr[1:0] != 0) ||
                    (row_count != 0 &&
                     (ext_stride[1:0] != 0 || spad_stride[1:0] != 0)) ||
                    (gather_enable &&
                     (store || row_count == 0 ||
                      gather_index_base[1:0] != 0))) begin
                  error <= 1'b1;
                  error_code <= ERR_CONFIG;
                  state_r <= ST_ERROR;
                end else begin
                  busy <= 1'b1;
                  rd_highwater_r <= 0;
                  rd_slot_valid_r <= 0;
                  rd_slot_complete_r <= 0;
                  wr_pending_b_r <= 0;
                  wr_pending_count_r <= 0;
                  read_limit_r <= (read_outstanding == 0) ? 3'd1 :
                                  (read_outstanding > MAX_OUTSTANDING ?
                                   MAX_OUTSTANDING[2:0] : read_outstanding);
                  plan_ext_r <= ext_addr;
                  plan_spad_r <= spad_addr;
                  plan_row_ext_r <= ext_addr;
                  plan_row_spad_r <= spad_addr;
                  plan_remaining_r <= (row_count == 0) ?
                                      length_words : row_words;
                  plan_rows_remaining_r <= (row_count == 0) ?
                                           16'd1 : row_count;
                  row_words_r <= row_words;
                  ext_stride_r <= ext_stride;
                  spad_stride_r <= spad_stride;
                  planner_done_r <= 1'b0;
                  gather_enable_r <= gather_enable;
                  gather_need_index_r <= gather_enable;
                  gather_wait_rsp_r <= 1'b0;
                  gather_index_base_r <= gather_index_base;
                  gather_row_index_r <= 0;
                  state_r <= store ? ST_WRITE_PLAN : ST_READ;
                end
              end
            end

            ST_READ: begin
              if (gather_need_index_r && !gather_wait_rsp_r &&
                  !rd_drain_found_comb && spad_ready)
                gather_wait_rsp_r <= 1'b1;

              if (gather_wait_rsp_r && spad_rsp_valid) begin
                gather_wait_rsp_r <= 1'b0;
                if (spad_rdata[1:0] != 0) begin
                  error <= 1'b1;
                  error_code <= ERR_CONFIG;
                  state_r <= ST_ERROR;
                end else begin
                  plan_ext_r <= spad_rdata;
                  plan_row_ext_r <= spad_rdata;
                  plan_remaining_r <= row_words_r;
                  gather_need_index_r <= 1'b0;
                end
              end

              if (!m_axi_arvalid && !planner_done_r &&
                  !gather_need_index_r && !gather_wait_rsp_r &&
                  rd_free_found_comb && rd_count_comb < read_limit_r) begin
                m_axi_arid <= 4'd1 + {2'd0, rd_free_slot_comb};
                m_axi_araddr <= plan_ext_r;
                m_axi_arlen <= plan_beats_comb - 1'b1;
                m_axi_arsize <= plan_wide_comb ?
                                AXI_SIZE_128 : AXI_SIZE_32;
                m_axi_arvalid <= 1'b1;
              end

              if (ar_fire) begin
                rd_slot_valid_r[m_axi_arid-1'b1] <= 1'b1;
                rd_slot_complete_r[m_axi_arid-1'b1] <= 1'b0;
                rd_slot_expected_r[m_axi_arid-1'b1] <= m_axi_arlen + 1'b1;
                rd_slot_received_r[m_axi_arid-1'b1] <= 0;
                rd_slot_words_r[m_axi_arid-1'b1] <= plan_words_comb;
                rd_slot_word_index_r[m_axi_arid-1'b1] <= 0;
                rd_slot_spad_r[m_axi_arid-1'b1] <= plan_spad_r;
                rd_slot_wide_r[m_axi_arid-1'b1] <=
                    (m_axi_arsize == AXI_SIZE_128);
                rd_slot_narrow_lane_r[m_axi_arid-1'b1] <=
                    m_axi_araddr[3:2];
                m_axi_arvalid <= 1'b0;
                if (rd_count_comb + 1'b1 > rd_highwater_r)
                  rd_highwater_r <= rd_count_comb + 1'b1;

                if (plan_remaining_r == plan_words_comb) begin
                  if (plan_rows_remaining_r == 1) begin
                    planner_done_r <= 1'b1;
                  end else begin
                    plan_rows_remaining_r <= plan_rows_remaining_r - 1'b1;
                    plan_row_spad_r <= plan_row_spad_r + spad_stride_r;
                    plan_spad_r <= plan_row_spad_r + spad_stride_r;
                    if (gather_enable_r) begin
                      gather_row_index_r <= gather_row_index_r + 1'b1;
                      gather_need_index_r <= 1'b1;
                    end else begin
                      plan_row_ext_r <= plan_row_ext_r + ext_stride_r;
                      plan_ext_r <= plan_row_ext_r + ext_stride_r;
                      plan_remaining_r <= row_words_r;
                    end
                  end
                end else begin
                  plan_remaining_r <= plan_remaining_r - plan_words_comb;
                  plan_ext_r <= plan_ext_r + plan_bytes_comb;
                  plan_spad_r <= plan_spad_r +
                                 ({16'd0, plan_words_comb} << 2);
                end
              end

              if (r_fire) begin
                rd_data_r[(rd_rid_index_comb * MAX_BURST_BEATS) +
                          rd_slot_received_r[rd_rid_index_comb]]
                    <= m_axi_rdata;
                if (m_axi_rresp != AXI_RESP_OKAY ||
                    m_axi_rlast !=
                    (rd_slot_received_r[rd_rid_index_comb] + 1'b1 >=
                     rd_slot_expected_r[rd_rid_index_comb])) begin
                  error <= 1'b1;
                  error_code <= ERR_AXI_RD;
                  state_r <= ST_ERROR;
                end else if (m_axi_rlast) begin
                  rd_slot_complete_r[rd_rid_index_comb] <= 1'b1;
                end else begin
                  rd_slot_received_r[rd_rid_index_comb] <=
                      rd_slot_received_r[rd_rid_index_comb] + 1'b1;
                end
              end

              if (rd_drain_line_comb && spad_line_ready) begin
                if (rd_slot_word_index_r[rd_drain_slot_comb] + 4 >=
                    rd_slot_words_r[rd_drain_slot_comb]) begin
                  rd_slot_complete_r[rd_drain_slot_comb] <= 1'b0;
                  rd_slot_valid_r[rd_drain_slot_comb] <= 1'b0;
                end else begin
                  rd_slot_word_index_r[rd_drain_slot_comb] <=
                      rd_slot_word_index_r[rd_drain_slot_comb] + 4;
                end
              end else if (rd_drain_found_comb && !rd_drain_line_comb &&
                           spad_ready) begin
                if (rd_slot_word_index_r[rd_drain_slot_comb] + 1'b1 >=
                    rd_slot_words_r[rd_drain_slot_comb]) begin
                  rd_slot_complete_r[rd_drain_slot_comb] <= 1'b0;
                  rd_slot_valid_r[rd_drain_slot_comb] <= 1'b0;
                end else begin
                  rd_slot_word_index_r[rd_drain_slot_comb] <=
                      rd_slot_word_index_r[rd_drain_slot_comb] + 1'b1;
                end
              end

              if (planner_done_r && rd_count_comb == 0 &&
                  !m_axi_arvalid && !gather_wait_rsp_r)
                state_r <= ST_DONE;

              if (abort) begin
                // If AR or R handshakes on this same edge, the ordinary
                // bookkeeping above records the issued transaction; the
                // abort state drains it rather than losing the response.
                // Abort is the software-visible cause even if a response
                // error arrives on this final active cycle.
                error <= 1'b1;
                error_code <= ERR_ABORT;
                for (i=0; i<4; i=i+1) begin
                  if (rd_slot_complete_r[i])
                    rd_slot_valid_r[i] <= 1'b0;
                  rd_slot_complete_r[i] <= 1'b0;
                end
                if (r_fire && m_axi_rlast)
                  rd_slot_valid_r[rd_rid_index_comb] <= 1'b0;
                m_axi_arvalid <= 1'b0;
                state_r <= ST_ABORT_READ;
              end
            end

            ST_ABORT_READ: begin
              m_axi_arvalid <= 1'b0;
              // Responses are deliberately discarded after abort; only
              // their AXI completion (RLAST) matters to the DMA lifecycle.
              if (r_fire && m_axi_rlast)
                rd_slot_valid_r[rd_rid_index_comb] <= 1'b0;
              if (rd_count_comb == 0 && !m_axi_arvalid)
                state_r <= ST_ERROR;
            end

            ST_WRITE_PLAN: begin
              if (abort) begin
                m_axi_awvalid <= 1'b0;
                m_axi_wvalid <= 1'b0;
                state_r <= ST_ERROR;
              end else begin
                wr_burst_words_r <= plan_words_comb;
                wr_burst_beats_r <= plan_beats_comb;
                wr_word_index_r <= 0;
                wr_read_pending_r <= 1'b0;
                wr_read_line_r <= 1'b0;
                m_axi_awlen <= plan_beats_comb - 1'b1;
                m_axi_awsize <= plan_wide_comb ?
                                AXI_SIZE_128 : AXI_SIZE_32;
                state_r <= ST_WRITE_GATHER;
              end
            end

            ST_WRITE_GATHER: begin
              if (abort) begin
                m_axi_awvalid <= 1'b0;
                m_axi_wvalid <= 1'b0;
                state_r <= ST_ERROR;
              end else begin
              if (!wr_read_pending_r &&
                  ((wr_gather_line_comb && spad_line_ready) ||
                   (!wr_gather_line_comb && spad_ready))) begin
                wr_read_pending_r <= 1'b1;
                wr_read_line_r <= wr_gather_line_comb;
              end
              if (spad_line_rsp_valid && wr_read_pending_r &&
                  wr_read_line_r) begin
                wr_read_pending_r <= 1'b0;
                wr_data_r[wr_word_index_r[15:2]] <= spad_line_rdata;
                if (wr_word_index_r + 4 >= wr_burst_words_r)
                  state_r <= ST_WRITE_AW;
                else
                  wr_word_index_r <= wr_word_index_r + 4;
              end else if (spad_rsp_valid && wr_read_pending_r &&
                           !wr_read_line_r) begin
                wr_read_pending_r <= 1'b0;
                case (wr_word_index_r[1:0])
                  2'd0: wr_data_r[wr_word_index_r[15:2]][31:0] <= spad_rdata;
                  2'd1: wr_data_r[wr_word_index_r[15:2]][63:32] <= spad_rdata;
                  2'd2: wr_data_r[wr_word_index_r[15:2]][95:64] <= spad_rdata;
                  default: wr_data_r[wr_word_index_r[15:2]][127:96] <= spad_rdata;
                endcase
                if (wr_word_index_r + 1'b1 >= wr_burst_words_r)
                  state_r <= ST_WRITE_AW;
                else
                  wr_word_index_r <= wr_word_index_r + 1'b1;
              end
              end
            end

            ST_WRITE_AW: begin
              if (abort && !aw_fire) begin
                // AW has not been accepted, so it is safe to cancel it.
                m_axi_awvalid <= 1'b0;
                m_axi_wvalid <= 1'b0;
                state_r <= ST_ERROR;
              end else begin
              if (!m_axi_awvalid && wr_free_found_comb) begin
                m_axi_awid <= 4'd8 + {2'd0, wr_free_tag_comb};
                m_axi_awaddr <= plan_ext_r;
                m_axi_awvalid <= 1'b1;
              end
              if (aw_fire) begin
                wr_active_tag_r <= m_axi_awid - 4'd8;
                m_axi_awvalid <= 1'b0;
                wr_beat_index_r <= 0;
                if (m_axi_awsize == AXI_SIZE_32) begin
                  case (m_axi_awaddr[3:2])
                    2'd0: begin
                      m_axi_wdata <= {96'd0,wr_data_r[0][31:0]};
                      m_axi_wstrb <= 16'h000f;
                    end
                    2'd1: begin
                      m_axi_wdata <= {64'd0,wr_data_r[0][31:0],32'd0};
                      m_axi_wstrb <= 16'h00f0;
                    end
                    2'd2: begin
                      m_axi_wdata <= {32'd0,wr_data_r[0][31:0],64'd0};
                      m_axi_wstrb <= 16'h0f00;
                    end
                    default: begin
                      m_axi_wdata <= {wr_data_r[0][31:0],96'd0};
                      m_axi_wstrb <= 16'hf000;
                    end
                  endcase
                end else begin
                  m_axi_wdata <= wr_data_r[0];
                  m_axi_wstrb <= (wr_burst_beats_r == 1) ?
                                 final_write_strobe_comb : 16'hffff;
                end
                m_axi_wvalid <= 1'b1;
                state_r <= ST_WRITE_W;
              end
              end
            end

            ST_WRITE_W: begin
              if (w_fire) begin
                if (m_axi_wlast) begin
                  m_axi_wvalid <= 1'b0;
                  if (abort || abort_pending_r) begin
                    // AW was accepted, hence AXI requires the complete W
                    // burst and its B response before done/error is exposed.
                    state_r <= ST_WRITE_DRAIN;
                  end else if (plan_remaining_r == wr_burst_words_r) begin
                    if (plan_rows_remaining_r == 1) begin
                      planner_done_r <= 1'b1;
                      state_r <= ST_WRITE_DRAIN;
                    end else begin
                      plan_rows_remaining_r <=
                          plan_rows_remaining_r - 1'b1;
                      plan_row_ext_r <= plan_row_ext_r + ext_stride_r;
                      plan_ext_r <= plan_row_ext_r + ext_stride_r;
                      plan_row_spad_r <= plan_row_spad_r + spad_stride_r;
                      plan_spad_r <= plan_row_spad_r + spad_stride_r;
                      plan_remaining_r <= row_words_r;
                      state_r <= ST_WRITE_PLAN;
                    end
                  end else begin
                    plan_remaining_r <=
                        plan_remaining_r - wr_burst_words_r;
                    plan_ext_r <= plan_ext_r +
                                  ((m_axi_awsize == AXI_SIZE_128) ?
                                   ({27'd0, wr_burst_beats_r} << 4) :
                                   ({16'd0, wr_burst_words_r} << 2));
                    plan_spad_r <= plan_spad_r +
                                   ({16'd0, wr_burst_words_r} << 2);
                    state_r <= ST_WRITE_PLAN;
                  end
                end else begin
                  wr_beat_index_r <= wr_beat_index_r + 1'b1;
                  m_axi_wdata <= wr_data_r[wr_beat_index_r + 1'b1];
                  if (wr_beat_index_r + 2 >= wr_burst_beats_r)
                    m_axi_wstrb <= final_write_strobe_comb;
                  else
                    m_axi_wstrb <= 16'hffff;
                end
              end
            end

            ST_WRITE_DRAIN: begin
              if (wr_pending_count_r == 0)
                state_r <= (abort || abort_pending_r) ? ST_ERROR : ST_DONE;
            end

            ST_DONE: begin
              busy <= 1'b0;
              done <= 1'b1;
              state_r <= ST_IDLE;
            end

            ST_ERROR: begin
              busy <= 1'b0;
              done <= 1'b1;
              state_r <= ST_IDLE;
            end

            default: state_r <= ST_ERROR;
          endcase
        end
      end
    end
endmodule
