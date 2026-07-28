`timescale 1ns / 1ps

// A6 data-plane DMA.  This module deliberately has a small, explicit
// transaction scoreboard instead of assuming AXI read-response order.
//
// Each read request transfers one 128-bit line (four scratchpad words).  Up
// to four lines carry different AXI IDs simultaneously.  R responses may
// return in any order; their RID selects the owning line buffer and the
// buffer is then drained through the single scalar scratchpad arbiter port.
// A line-at-a-time issue policy also makes every request naturally 4-KiB safe.
//
// AXI4 W has no WID, so write-data beats are sent in AW issue order.  Four
// write IDs may nevertheless be awaiting independently returned B responses.
module ai_axi128_dma_ooo #(
    parameter integer MAX_OUTSTANDING = 4
)(
    input  wire         clk,
    input  wire         resetn,
    input  wire         start,
    input  wire         abort,
    input  wire         store,
    input  wire [31:0]  ext_addr,
    input  wire [31:0]  spad_addr,
    input  wire [15:0]  length_words,
    input  wire [2:0]   read_outstanding,
    output reg          busy,
    output reg          done,
    output reg          error,
    output reg [3:0]    error_code,

    output reg          spad_valid,
    output reg          spad_write,
    output reg [31:0]   spad_addr_o,
    output reg [31:0]   spad_wdata,
    input  wire         spad_ready,
    input  wire         spad_rsp_valid,
    input  wire [31:0]  spad_rdata,
    input  wire         spad_req_error,
    input  wire         spad_rsp_error,

    output reg [3:0]    m_axi_arid,
    output reg          m_axi_arvalid,
    output reg [31:0]   m_axi_araddr,
    output wire [7:0]   m_axi_arlen,
    output wire [2:0]   m_axi_arsize,
    output wire [1:0]   m_axi_arburst,
    input  wire         m_axi_arready,
    input  wire [3:0]   m_axi_rid,
    input  wire [127:0] m_axi_rdata,
    input  wire [1:0]   m_axi_rresp,
    input  wire         m_axi_rvalid,
    input  wire         m_axi_rlast,
    output wire         m_axi_rready,

    output reg [3:0]    m_axi_awid,
    output reg          m_axi_awvalid,
    output reg [31:0]   m_axi_awaddr,
    output wire [7:0]   m_axi_awlen,
    output wire [2:0]   m_axi_awsize,
    output wire [1:0]   m_axi_awburst,
    input  wire         m_axi_awready,
    output reg          m_axi_wvalid,
    output reg [127:0] m_axi_wdata,
    output reg [15:0]  m_axi_wstrb,
    output wire         m_axi_wlast,
    input  wire         m_axi_wready,
    input  wire [3:0]   m_axi_bid,
    input  wire [1:0]   m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire         m_axi_bready,

    output wire [2:0]   rd_outstanding,
    output wire [2:0]   rd_highwater
);
    localparam [2:0] AXI_SIZE_128B = 3'd4;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [1:0] AXI_RESP_OKAY = 2'b00;
    localparam [3:0] ERR_NONE=0, ERR_CONFIG=1, ERR_AXI_RD=2,
                     ERR_AXI_WR=3, ERR_SPAD=4, ERR_ABORT=5;
    localparam [2:0] ST_IDLE=0, ST_READ=1, ST_WRITE_GATHER=2,
                     ST_WRITE_AW=3, ST_WRITE_W=4, ST_WRITE_DRAIN=5,
                     ST_DONE=6, ST_ERROR=7;

    reg [2:0] state_r;
    reg [31:0] issue_ext_r, issue_spad_r;
    reg [15:0] issue_remaining_r;
    reg [2:0] read_limit_r;
    reg [2:0] rd_highwater_r;
    reg [3:0] rd_slot_valid_r;
    reg [3:0] rd_slot_line_valid_r;
    reg [15:0] rd_slot_words_r [0:3];
    reg [31:0] rd_slot_spad_r [0:3];
    reg [127:0] rd_slot_data_r [0:3];
    reg [2:0] rd_slot_lane_r [0:3];
    reg [2:0] rd_slot_lanes_r [0:3];

    reg [31:0] wr_ext_r, wr_spad_r;
    reg [15:0] wr_remaining_r;
    reg [2:0] wr_gather_lane_r, wr_gather_lanes_r;
    reg [127:0] wr_line_r;
    reg [3:0] wr_pending_b_r;
    reg [1:0] wr_next_tag_r;
    reg [3:0] wr_active_id_r;
    reg [2:0] wr_pending_count_r;
    reg       wr_read_pending_r;

    integer i;
    reg [2:0] rd_count_comb;
    reg [1:0] rd_free_slot_comb;
    reg rd_free_found_comb;
    reg [1:0] rd_drain_slot_comb;
    reg rd_drain_found_comb;
    reg [1:0] rd_rid_index;
    reg rid_is_dma;
    reg [1:0] wr_bid_index;
    reg bid_is_dma;
    reg [2:0] issue_lanes_comb;
    reg [15:0] wr_remaining_after_comb;

    always @(*) begin
        rd_count_comb = 3'd0;
        rd_free_slot_comb = 2'd0;
        rd_free_found_comb = 1'b0;
        rd_drain_slot_comb = 2'd0;
        rd_drain_found_comb = 1'b0;
        for (i=0; i<4; i=i+1) begin
            if (rd_slot_valid_r[i]) rd_count_comb = rd_count_comb + 1'b1;
            if (!rd_slot_valid_r[i] && !rd_free_found_comb) begin
                rd_free_found_comb = 1'b1;
                rd_free_slot_comb = i[1:0];
            end
            if (rd_slot_line_valid_r[i] && !rd_drain_found_comb) begin
                rd_drain_found_comb = 1'b1;
                rd_drain_slot_comb = i[1:0];
            end
        end
        rid_is_dma = (m_axi_rid >= 4'd1) && (m_axi_rid <= 4'd4);
        rd_rid_index = m_axi_rid - 4'd1;
        bid_is_dma = (m_axi_bid >= 4'd8) && (m_axi_bid <= 4'd11);
        wr_bid_index = m_axi_bid - 4'd8;
        issue_lanes_comb = (issue_remaining_r >= 16'd4) ? 3'd4 : issue_remaining_r[2:0];
        wr_remaining_after_comb = wr_remaining_r - {13'd0, wr_gather_lanes_r};
    end

    assign m_axi_arlen = 8'd0;
    assign m_axi_arsize = AXI_SIZE_128B;
    assign m_axi_arburst = AXI_BURST_INCR;
    assign m_axi_awlen = 8'd0;
    assign m_axi_awsize = AXI_SIZE_128B;
    assign m_axi_awburst = AXI_BURST_INCR;
    assign m_axi_wlast = m_axi_wvalid;
    // Ready is intentionally ID-aware.  Responses from another master (such
    // as descriptor fetch RID=0) are left for the top-level demultiplexer.
    assign m_axi_rready = (state_r == ST_READ) && rid_is_dma &&
                          rd_slot_valid_r[rd_rid_index] &&
                          !rd_slot_line_valid_r[rd_rid_index];
    assign m_axi_bready = bid_is_dma && wr_pending_b_r[wr_bid_index];
    assign rd_outstanding = rd_count_comb;
    assign rd_highwater = rd_highwater_r;

    always @(*) begin
        spad_valid = 1'b0;
        spad_write = 1'b0;
        spad_addr_o = 32'd0;
        spad_wdata = 32'd0;
        if (state_r == ST_READ && rd_drain_found_comb) begin
            spad_valid = 1'b1;
            spad_write = 1'b1;
            spad_addr_o = rd_slot_spad_r[rd_drain_slot_comb] +
                          ({29'd0, rd_slot_lane_r[rd_drain_slot_comb]} << 2);
            case (rd_slot_lane_r[rd_drain_slot_comb])
              3'd0: spad_wdata = rd_slot_data_r[rd_drain_slot_comb][31:0];
              3'd1: spad_wdata = rd_slot_data_r[rd_drain_slot_comb][63:32];
              3'd2: spad_wdata = rd_slot_data_r[rd_drain_slot_comb][95:64];
              default: spad_wdata = rd_slot_data_r[rd_drain_slot_comb][127:96];
            endcase
        end else if (state_r == ST_WRITE_GATHER && !wr_read_pending_r) begin
            spad_valid = 1'b1;
            spad_write = 1'b0;
            spad_addr_o = wr_spad_r + ({29'd0, wr_gather_lane_r} << 2);
        end
    end

    always @(posedge clk or negedge resetn) begin
      if (!resetn) begin
        state_r <= ST_IDLE; busy <= 1'b0; done <= 1'b0; error <= 1'b0;
        error_code <= ERR_NONE; issue_ext_r <= 0; issue_spad_r <= 0;
        issue_remaining_r <= 0; read_limit_r <= 3'd4; rd_highwater_r <= 0;
        rd_slot_valid_r <= 0; rd_slot_line_valid_r <= 0;
        wr_ext_r <= 0; wr_spad_r <= 0; wr_remaining_r <= 0;
        wr_gather_lane_r <= 0; wr_gather_lanes_r <= 0; wr_line_r <= 0;
        wr_pending_b_r <= 0; wr_next_tag_r <= 0; wr_active_id_r <= 0;
        wr_pending_count_r <= 0; wr_read_pending_r <= 1'b0;
        m_axi_arvalid <= 0; m_axi_arid <= 0; m_axi_araddr <= 0;
        m_axi_awvalid <= 0; m_axi_awid <= 0; m_axi_awaddr <= 0;
        m_axi_wvalid <= 0; m_axi_wdata <= 0; m_axi_wstrb <= 0;
        for (i=0; i<4; i=i+1) begin
          rd_slot_words_r[i] <= 0; rd_slot_spad_r[i] <= 0;
          rd_slot_data_r[i] <= 0; rd_slot_lane_r[i] <= 0; rd_slot_lanes_r[i] <= 0;
        end
      end else begin
        done <= 1'b0;
        if ((spad_req_error || spad_rsp_error) && busy) begin
          error <= 1'b1; error_code <= ERR_SPAD; state_r <= ST_ERROR;
        end else if (abort && busy) begin
          error <= 1'b1; error_code <= ERR_ABORT; state_r <= ST_ERROR;
          m_axi_arvalid <= 1'b0; m_axi_awvalid <= 1'b0; m_axi_wvalid <= 1'b0;
        end else begin
          case (state_r)
            ST_IDLE: begin
              busy <= 1'b0; error <= 1'b0; error_code <= ERR_NONE;
              m_axi_arvalid <= 1'b0; m_axi_awvalid <= 1'b0; m_axi_wvalid <= 1'b0;
              if (start) begin
                if (length_words == 0 || ext_addr[3:0] != 0 || spad_addr[1:0] != 0) begin
                  error <= 1'b1; error_code <= ERR_CONFIG; state_r <= ST_ERROR;
                end else begin
                  busy <= 1'b1; rd_slot_valid_r <= 0; rd_slot_line_valid_r <= 0;
                  rd_highwater_r <= 0; wr_pending_b_r <= 0; wr_pending_count_r <= 0;
                  read_limit_r <= (read_outstanding == 0) ? 3'd1 :
                                  (read_outstanding > 3'd4 ? 3'd4 : read_outstanding);
                  if (!store) begin
                    issue_ext_r <= ext_addr; issue_spad_r <= spad_addr;
                    issue_remaining_r <= length_words; state_r <= ST_READ;
                  end else begin
                    wr_ext_r <= ext_addr; wr_spad_r <= spad_addr;
                    wr_remaining_r <= length_words; wr_next_tag_r <= 0;
                    wr_gather_lane_r <= 0;
                    wr_gather_lanes_r <= (length_words >= 4) ? 3'd4 : length_words[2:0];
                    wr_line_r <= 0; wr_read_pending_r <= 1'b0; state_r <= ST_WRITE_GATHER;
                  end
                end
              end
            end
            ST_READ: begin
              // Issue a distinct-ID line when a slot is available.  ARVALID
              // is held stable until its handshake.
              if (!m_axi_arvalid && issue_remaining_r != 0 && rd_free_found_comb &&
                  rd_count_comb < read_limit_r) begin
                m_axi_arid <= {1'b0, rd_free_slot_comb} + 4'd1;
                m_axi_araddr <= issue_ext_r;
                m_axi_arvalid <= 1'b1;
              end
              if (m_axi_arvalid && m_axi_arready) begin
                rd_slot_valid_r[m_axi_arid[1:0]-1'b1] <= 1'b1;
                rd_slot_line_valid_r[m_axi_arid[1:0]-1'b1] <= 1'b0;
                rd_slot_spad_r[m_axi_arid[1:0]-1'b1] <= issue_spad_r;
                rd_slot_lanes_r[m_axi_arid[1:0]-1'b1] <= issue_lanes_comb;
                rd_slot_lane_r[m_axi_arid[1:0]-1'b1] <= 0;
                issue_ext_r <= issue_ext_r + 32'd16;
                issue_spad_r <= issue_spad_r + 32'd16;
                issue_remaining_r <= issue_remaining_r - issue_lanes_comb;
                m_axi_arvalid <= 1'b0;
              end
              if (m_axi_rvalid && m_axi_rready) begin
                if (m_axi_rresp != AXI_RESP_OKAY || !m_axi_rlast) begin
                  error <= 1'b1; error_code <= ERR_AXI_RD; state_r <= ST_ERROR;
                end else begin
                  rd_slot_data_r[rd_rid_index] <= m_axi_rdata;
                  rd_slot_line_valid_r[rd_rid_index] <= 1'b1;
                  rd_slot_lane_r[rd_rid_index] <= 0;
                end
              end
              if (rd_drain_found_comb && spad_ready) begin
                if (rd_slot_lane_r[rd_drain_slot_comb] + 1'b1 >= rd_slot_lanes_r[rd_drain_slot_comb]) begin
                  rd_slot_line_valid_r[rd_drain_slot_comb] <= 1'b0;
                  rd_slot_valid_r[rd_drain_slot_comb] <= 1'b0;
                end else begin
                  rd_slot_lane_r[rd_drain_slot_comb] <= rd_slot_lane_r[rd_drain_slot_comb] + 1'b1;
                end
              end
              if (rd_count_comb > rd_highwater_r) rd_highwater_r <= rd_count_comb;
              if (issue_remaining_r == 0 && rd_count_comb == 0 && !m_axi_arvalid) state_r <= ST_DONE;
            end
            ST_WRITE_GATHER: begin
              if (!wr_read_pending_r && spad_ready) begin
                wr_read_pending_r <= 1'b1;
              end
              if (spad_rsp_valid && wr_read_pending_r) begin
                wr_read_pending_r <= 1'b0;
                case (wr_gather_lane_r)
                  0: wr_line_r[31:0] <= spad_rdata;
                  1: wr_line_r[63:32] <= spad_rdata;
                  2: wr_line_r[95:64] <= spad_rdata;
                  default: wr_line_r[127:96] <= spad_rdata;
                endcase
                if (wr_gather_lane_r + 1'b1 >= wr_gather_lanes_r) begin
                  state_r <= ST_WRITE_AW;
                end else begin
                  wr_gather_lane_r <= wr_gather_lane_r + 1'b1;
                end
              end
            end
            ST_WRITE_AW: begin
              if (!m_axi_awvalid && wr_pending_count_r < 3'd4) begin
                m_axi_awid <= 4'd8 + {2'd0, wr_next_tag_r};
                m_axi_awaddr <= wr_ext_r;
                m_axi_awvalid <= 1'b1;
              end
              if (m_axi_awvalid && m_axi_awready) begin
                wr_active_id_r <= m_axi_awid;
                m_axi_awvalid <= 1'b0;
                m_axi_wdata <= wr_line_r;
                case (wr_gather_lanes_r)
                  1: m_axi_wstrb <= 16'h000f;
                  2: m_axi_wstrb <= 16'h00ff;
                  3: m_axi_wstrb <= 16'h0fff;
                  default: m_axi_wstrb <= 16'hffff;
                endcase
                m_axi_wvalid <= 1'b1;
                state_r <= ST_WRITE_W;
              end
            end
            ST_WRITE_W: begin
              if (m_axi_wvalid && m_axi_wready) begin
                m_axi_wvalid <= 1'b0;
                wr_pending_b_r[wr_active_id_r[1:0]] <= 1'b1;
                wr_pending_count_r <= wr_pending_count_r + 1'b1;
                wr_next_tag_r <= wr_next_tag_r + 1'b1;
                wr_ext_r <= wr_ext_r + 32'd16;
                wr_spad_r <= wr_spad_r + ({29'd0, wr_gather_lanes_r} << 2);
                wr_remaining_r <= wr_remaining_r - wr_gather_lanes_r;
                if (wr_remaining_r == wr_gather_lanes_r) state_r <= ST_WRITE_DRAIN;
                else begin
                  wr_gather_lane_r <= 0;
                  wr_gather_lanes_r <= (wr_remaining_after_comb >= 16'd4) ? 3'd4 :
                                        wr_remaining_after_comb[2:0];
                  wr_line_r <= 0;
                  wr_read_pending_r <= 1'b0;
                  state_r <= ST_WRITE_GATHER;
                end
              end
            end
            ST_WRITE_DRAIN: begin
              if (wr_pending_count_r == 0) state_r <= ST_DONE;
            end
            ST_DONE: begin
              busy <= 1'b0; done <= 1'b1; state_r <= ST_IDLE;
            end
            ST_ERROR: begin
              busy <= 1'b0; done <= 1'b1; state_r <= ST_IDLE;
            end
          endcase
          if (m_axi_bvalid && m_axi_bready) begin
            wr_pending_b_r[wr_bid_index] <= 1'b0;
            wr_pending_count_r <= wr_pending_count_r - 1'b1;
            if (m_axi_bresp != AXI_RESP_OKAY) begin
              error <= 1'b1; error_code <= ERR_AXI_WR; state_r <= ST_ERROR;
            end
          end
        end
      end
    end
endmodule
