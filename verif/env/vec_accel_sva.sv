`ifndef VEC_ACCEL_SVA_SV
`define VEC_ACCEL_SVA_SV

// SVA checker for vec_accel_top.
//
// This module is verification-only. It checks the observable AHB-Lite response
// behavior and a few core-level state rules without changing the DUT RTL.
module vec_accel_sva #(
  parameter integer SRAM_WAIT_CYCLES = 1
)(
  input logic        hclk,
  input logic        hresetn,

  input logic        hsel,
  input logic        hready,
  input logic        hwrite,
  input logic [1:0]  htrans,
  input logic [2:0]  hsize,
  input logic [2:0]  hburst,
  input logic [31:0] haddr,
  input logic [31:0] hwdata,
  input logic        hready_resp,
  input logic [1:0]  hresp,
  input logic [31:0] hrdata,
  input logic        irq,

  input logic        core_busy,
  input logic        core_start,
  input logic        core_done,
  input logic        core_error,
  input logic        core_sram_req
);

  localparam [1:0] HTRANS_IDLE   = 2'b00;
  localparam [1:0] HTRANS_BUSY   = 2'b01;
  localparam [1:0] HTRANS_NONSEQ = 2'b10;
  localparam [1:0] HTRANS_SEQ    = 2'b11;

  localparam [2:0] HSIZE_BYTE = 3'b000;
  localparam [2:0] HSIZE_HALF = 3'b001;
  localparam [2:0] HSIZE_WORD = 3'b010;

  localparam [2:0] HBURST_SINGLE = 3'b000;
  localparam [2:0] HBURST_INCR   = 3'b001;
  localparam [2:0] HBURST_WRAP4  = 3'b010;
  localparam [2:0] HBURST_INCR4  = 3'b011;
  localparam [2:0] HBURST_WRAP8  = 3'b100;
  localparam [2:0] HBURST_INCR8  = 3'b101;
  localparam [2:0] HBURST_WRAP16 = 3'b110;
  localparam [2:0] HBURST_INCR16 = 3'b111;

  localparam [1:0] HRESP_OKAY  = 2'b00;
  localparam [1:0] HRESP_ERROR = 2'b01;

  localparam [7:0] ADDR_CTRL        = 8'h00;
  localparam [7:0] ADDR_STATUS      = 8'h04;
  localparam [7:0] ADDR_SRC0_BASE   = 8'h08;
  localparam [7:0] ADDR_SRC1_BASE   = 8'h0c;
  localparam [7:0] ADDR_DST_BASE    = 8'h10;
  localparam [7:0] ADDR_LENGTH      = 8'h14;
  localparam [7:0] ADDR_SCALE_SHIFT = 8'h18;
  localparam [7:0] ADDR_IRQ_STATUS  = 8'h1c;
  localparam [7:0] ADDR_RESULT      = 8'h20;
  localparam [7:0] ADDR_VERSION     = 8'h24;
  localparam [7:0] ADDR_CAPABILITY  = 8'h28;
  localparam [7:0] ADDR_ERROR_CODE  = 8'h2c;
  localparam [7:0] ADDR_CYCLE_COUNT = 8'h30;
  localparam [7:0] ADDR_ELEM_COUNT  = 8'h34;
  localparam [7:0] ADDR_SRC0_STRIDE = 8'h38;
  localparam [7:0] ADDR_SRC1_STRIDE = 8'h3c;
  localparam [7:0] ADDR_DST_STRIDE  = 8'h40;
  localparam [7:0] ADDR_CONFIG      = 8'h44;
  localparam [7:0] ADDR_IRQ_ENABLE  = 8'h48;
  localparam [7:0] ADDR_IRQ_MASK    = 8'h4c;
  localparam [7:0] ADDR_IRQ_CLEAR   = 8'h50;
  localparam [7:0] ADDR_NEURON_COUNT  = 8'h54;
  localparam [7:0] ADDR_NEURON_STRIDE = 8'h58;
  localparam [7:0] ADDR_NEURON_INDEX  = 8'h5c;
  localparam [7:0] ADDR_SOM_BEST_DIST = 8'h60;
  localparam [7:0] ADDR_SOM_WINNER    = 8'h64;

  localparam [7:0]   RESP_MAX_LATENCY_U8 = SRAM_WAIT_CYCLES + 3;
  localparam integer CORE_DONE_TIMEOUT = 1024;

  wire addr_phase_valid;
  wire reg_region;
  wire sram_region;
  wire valid_hsize;
  wire aligned_addr;
  wire supported_burst;
  wire reg_word_access;
  wire reg_known_addr;
  wire reg_writable_addr;
  wire reg_busy_write_error;
  wire reg_access_error;
  wire sram_access_error;
  wire expected_addr_error;
  wire request_start;

  reg        burst_active_r;
  reg [2:0]  burst_size_r;
  reg [2:0]  burst_type_r;
  reg [31:0] burst_next_addr_r;
  reg [4:0]  burst_left_r;
  reg        req_pending_r;
  reg        req_expect_error_r;
  reg [7:0]  req_latency_r;
  reg        core_watch_active_r;
  integer    core_watch_cnt_r;

  function automatic [31:0] size_bytes(input [2:0] size);
    begin
      case (size)
        HSIZE_BYTE: size_bytes = 32'd1;
        HSIZE_HALF: size_bytes = 32'd2;
        HSIZE_WORD: size_bytes = 32'd4;
        default:    size_bytes = 32'd0;
      endcase
    end
  endfunction

  function automatic [4:0] burst_total_beats(input [2:0] burst);
    begin
      case (burst)
        HBURST_INCR4:  burst_total_beats = 5'd4;
        HBURST_INCR8:  burst_total_beats = 5'd8;
        HBURST_INCR16: burst_total_beats = 5'd16;
        default:       burst_total_beats = 5'd0;
      endcase
    end
  endfunction

  assign addr_phase_valid = hsel && hready &&
                            ((htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ));
  assign request_start = addr_phase_valid && !req_pending_r;

  assign reg_region  = haddr[16];
  assign sram_region = !haddr[16];

  assign valid_hsize = (hsize == HSIZE_BYTE) ||
                       (hsize == HSIZE_HALF) ||
                       (hsize == HSIZE_WORD);
  assign aligned_addr = (hsize == HSIZE_BYTE) ||
                        ((hsize == HSIZE_HALF) && (haddr[0] == 1'b0)) ||
                        ((hsize == HSIZE_WORD) && (haddr[1:0] == 2'b00));
  assign supported_burst = (hburst == HBURST_SINGLE) ||
                           (hburst == HBURST_INCR)   ||
                           (hburst == HBURST_INCR4)  ||
                           (hburst == HBURST_INCR8)  ||
                           (hburst == HBURST_INCR16);

  assign reg_word_access = (hsize == HSIZE_WORD) && (haddr[1:0] == 2'b00);
  assign reg_known_addr = (haddr[7:0] == ADDR_CTRL)        ||
                          (haddr[7:0] == ADDR_STATUS)      ||
                          (haddr[7:0] == ADDR_SRC0_BASE)   ||
                          (haddr[7:0] == ADDR_SRC1_BASE)   ||
                          (haddr[7:0] == ADDR_DST_BASE)    ||
                          (haddr[7:0] == ADDR_LENGTH)      ||
                          (haddr[7:0] == ADDR_SCALE_SHIFT) ||
                          (haddr[7:0] == ADDR_IRQ_STATUS)  ||
                          (haddr[7:0] == ADDR_RESULT)      ||
                          (haddr[7:0] == ADDR_VERSION)     ||
                          (haddr[7:0] == ADDR_CAPABILITY)  ||
                          (haddr[7:0] == ADDR_ERROR_CODE)  ||
                          (haddr[7:0] == ADDR_CYCLE_COUNT) ||
                          (haddr[7:0] == ADDR_ELEM_COUNT)  ||
                          (haddr[7:0] == ADDR_SRC0_STRIDE) ||
                          (haddr[7:0] == ADDR_SRC1_STRIDE) ||
                          (haddr[7:0] == ADDR_DST_STRIDE)  ||
                          (haddr[7:0] == ADDR_CONFIG)      ||
                          (haddr[7:0] == ADDR_IRQ_ENABLE)  ||
                          (haddr[7:0] == ADDR_IRQ_MASK)    ||
                          (haddr[7:0] == ADDR_IRQ_CLEAR)   ||
                          (haddr[7:0] == ADDR_NEURON_COUNT) ||
                          (haddr[7:0] == ADDR_NEURON_STRIDE) ||
                          (haddr[7:0] == ADDR_NEURON_INDEX) ||
                          (haddr[7:0] == ADDR_SOM_BEST_DIST) ||
                          (haddr[7:0] == ADDR_SOM_WINNER);
  assign reg_writable_addr = (haddr[7:0] == ADDR_CTRL)        ||
                             (haddr[7:0] == ADDR_STATUS)      ||
                             (haddr[7:0] == ADDR_SRC0_BASE)   ||
                             (haddr[7:0] == ADDR_SRC1_BASE)   ||
                             (haddr[7:0] == ADDR_DST_BASE)    ||
                             (haddr[7:0] == ADDR_LENGTH)      ||
                             (haddr[7:0] == ADDR_SCALE_SHIFT) ||
                             (haddr[7:0] == ADDR_IRQ_STATUS)  ||
                             (haddr[7:0] == ADDR_SRC0_STRIDE) ||
                             (haddr[7:0] == ADDR_SRC1_STRIDE) ||
                             (haddr[7:0] == ADDR_DST_STRIDE)  ||
                             (haddr[7:0] == ADDR_CONFIG)      ||
                             (haddr[7:0] == ADDR_IRQ_ENABLE)  ||
                             (haddr[7:0] == ADDR_IRQ_MASK)    ||
                             (haddr[7:0] == ADDR_IRQ_CLEAR)   ||
                             (haddr[7:0] == ADDR_NEURON_COUNT) ||
                             (haddr[7:0] == ADDR_NEURON_STRIDE) ||
                             (haddr[7:0] == ADDR_NEURON_INDEX);
  assign reg_busy_write_error = hwrite && core_busy &&
                                !((haddr[7:0] == ADDR_STATUS) ||
                                  (haddr[7:0] == ADDR_IRQ_STATUS) ||
                                  (haddr[7:0] == ADDR_IRQ_MASK) ||
                                  (haddr[7:0] == ADDR_IRQ_CLEAR));
  assign reg_access_error = reg_region &&
                            (!reg_word_access ||
                             !reg_known_addr ||
                             (hwrite && !reg_writable_addr) ||
                             reg_busy_write_error);

  assign sram_access_error = sram_region &&
                             (core_busy ||
                              !valid_hsize ||
                              !aligned_addr ||
                              !supported_burst ||
                              ((htrans == HTRANS_SEQ) &&
                               (!burst_active_r ||
                                (haddr != burst_next_addr_r) ||
                                (hsize != burst_size_r))));

  assign expected_addr_error = reg_access_error || sram_access_error;

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      burst_active_r    <= 1'b0;
      burst_size_r      <= HSIZE_WORD;
      burst_type_r      <= HBURST_SINGLE;
      burst_next_addr_r <= 32'd0;
      burst_left_r      <= 5'd0;
    end else if (request_start && sram_region) begin
      if (sram_access_error) begin
        burst_active_r    <= 1'b0;
        burst_size_r      <= HSIZE_WORD;
        burst_type_r      <= HBURST_SINGLE;
        burst_next_addr_r <= 32'd0;
        burst_left_r      <= 5'd0;
      end else if (htrans == HTRANS_NONSEQ) begin
        burst_size_r      <= hsize;
        burst_type_r      <= hburst;
        burst_next_addr_r <= haddr + size_bytes(hsize);
        if (hburst == HBURST_SINGLE) begin
          burst_active_r <= 1'b0;
          burst_left_r   <= 5'd0;
        end else if (hburst == HBURST_INCR) begin
          burst_active_r <= 1'b1;
          burst_left_r   <= 5'd0;
        end else begin
          burst_active_r <= (burst_total_beats(hburst) > 5'd1);
          burst_left_r   <= burst_total_beats(hburst) - 5'd1;
        end
      end else begin
        burst_next_addr_r <= haddr + size_bytes(hsize);
        if (burst_type_r == HBURST_INCR) begin
          burst_active_r <= 1'b1;
        end else if (burst_left_r > 5'd1) begin
          burst_left_r   <= burst_left_r - 5'd1;
          burst_active_r <= 1'b1;
        end else begin
          burst_left_r   <= 5'd0;
          burst_active_r <= 1'b0;
        end
      end
    end
  end

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      req_pending_r      <= 1'b0;
      req_expect_error_r <= 1'b0;
      req_latency_r      <= 8'd0;
    end else begin
      if (req_pending_r) begin
        if (hready_resp) begin
          if (req_expect_error_r) begin
            assert (hresp == HRESP_ERROR)
            else $fatal(1, "SVA FAIL: illegal AHB request did not return ERROR");
          end else begin
            assert (hresp == HRESP_OKAY)
            else $fatal(1, "SVA FAIL: legal AHB request did not return OKAY");
          end
          req_pending_r <= 1'b0;
          req_latency_r <= 8'd0;
        end else begin
          assert (hresp == HRESP_OKAY)
          else $fatal(1, "SVA FAIL: hresp must remain OKAY while hready_resp is low");

          req_latency_r <= req_latency_r + 8'd1;
          assert (req_latency_r <= RESP_MAX_LATENCY_U8)
          else $fatal(1, "SVA FAIL: AHB response wait-state latency exceeded checker limit");
        end
      end

      if (request_start) begin
        req_pending_r      <= 1'b1;
        req_expect_error_r <= expected_addr_error;
        req_latency_r      <= 8'd0;
      end
    end
  end

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      core_watch_active_r <= 1'b0;
      core_watch_cnt_r    <= 0;
    end else begin
      if (core_start) begin
        core_watch_active_r <= 1'b1;
        core_watch_cnt_r    <= 0;
      end else if (core_watch_active_r && (core_done || core_error)) begin
        core_watch_active_r <= 1'b0;
        core_watch_cnt_r    <= 0;
      end else if (core_watch_active_r) begin
        core_watch_cnt_r <= core_watch_cnt_r + 1;
        assert (core_watch_cnt_r <= CORE_DONE_TIMEOUT)
        else $fatal(1, "SVA FAIL: core_start did not finish before timeout");
      end
    end
  end

  property p_no_x_on_response;
    @(posedge hclk) disable iff (!hresetn)
      hready_resp |-> (!$isunknown(hready_resp) && !$isunknown(hresp));
  endproperty

  property p_wait_state_returns_okay;
    @(posedge hclk) disable iff (!hresetn)
      !hready_resp |-> (hresp == HRESP_OKAY);
  endproperty

  property p_idle_busy_transfer_no_error;
    @(posedge hclk) disable iff (!hresetn)
      (hsel && hready && ((htrans == HTRANS_IDLE) || (htrans == HTRANS_BUSY))) |->
        (hresp == HRESP_OKAY);
  endproperty

  property p_core_request_only_when_busy;
    @(posedge hclk) disable iff (!hresetn)
      core_sram_req |-> core_busy;
  endproperty

  property p_core_done_not_busy;
    @(posedge hclk) disable iff (!hresetn)
      core_done |-> !core_busy;
  endproperty

  property p_core_error_reports_done;
    @(posedge hclk) disable iff (!hresetn)
      core_error |-> core_done;
  endproperty

  a_no_x_on_response:
    assert property (p_no_x_on_response)
    else $fatal(1, "SVA FAIL: hready_resp/hresp contains X/Z when response is ready");

  a_wait_state_returns_okay:
    assert property (p_wait_state_returns_okay)
    else $fatal(1, "SVA FAIL: hresp must remain OKAY while hready_resp is low");

  a_idle_busy_transfer_no_error:
    assert property (p_idle_busy_transfer_no_error)
    else $fatal(1, "SVA FAIL: IDLE/BUSY transfer produced ERROR response");

  a_core_request_only_when_busy:
    assert property (p_core_request_only_when_busy)
    else $fatal(1, "SVA FAIL: core drove SRAM request while not busy");

  a_core_done_not_busy:
    assert property (p_core_done_not_busy)
    else $fatal(1, "SVA FAIL: core_done and core_busy asserted together");

  a_core_error_reports_done:
    assert property (p_core_error_reports_done)
    else $fatal(1, "SVA FAIL: core_error must be reported together with core_done");

endmodule

`endif
