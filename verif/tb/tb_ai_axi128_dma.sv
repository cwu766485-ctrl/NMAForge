`timescale 1ns / 1ps

// Directed transport test for the unified DMA.  MAX_BURST_BEATS is reduced to
// four so a short test exercises multiple bursts.  The responder returns the
// second read burst before the first and reverses two B responses.
module tb_ai_axi128_dma;
  reg clk=0, resetn=0, start=0, abort=0, store=0;
  reg [63:0] ext_addr=0;
  reg [31:0] spad_addr=0;
  reg [15:0] length_words=0, row_words=0, row_count=0;
  reg [31:0] ext_stride=0, spad_stride=0;
  reg gather_enable=0;
  reg [31:0] gather_index_base=0;
  reg [2:0] read_outstanding=3'd4;
  wire busy, done, error;
  wire [3:0] error_code;
  wire spad_valid, spad_write;
  wire [31:0] spad_addr_o, spad_wdata;
  reg spad_ready=1, spad_rsp_valid=0;
  reg [31:0] spad_rdata=0;
  reg spad_req_error=0, spad_rsp_error=0;
  wire spad_line_valid, spad_line_write;
  wire [31:0] spad_line_addr;
  wire [127:0] spad_line_wdata;
  wire [15:0] spad_line_wstrb;
  reg spad_line_ready=1, spad_line_rsp_valid=0;
  reg [127:0] spad_line_rdata=0;
  reg spad_line_req_error=0, spad_line_rsp_error=0;
  reg [3:0] spad_line_parity_error=0;

  wire [3:0] m_axi_arid;
  wire m_axi_arvalid;
  wire [63:0] m_axi_araddr;
  wire [7:0] m_axi_arlen;
  wire [2:0] m_axi_arsize;
  wire [1:0] m_axi_arburst;
  reg m_axi_arready=1;
  reg [3:0] m_axi_rid=0;
  reg [127:0] m_axi_rdata=0;
  reg [1:0] m_axi_rresp=0;
  reg m_axi_rvalid=0, m_axi_rlast=0;
  wire m_axi_rready;

  wire [3:0] m_axi_awid;
  wire m_axi_awvalid;
  wire [63:0] m_axi_awaddr;
  wire [7:0] m_axi_awlen;
  wire [2:0] m_axi_awsize;
  wire [1:0] m_axi_awburst;
  reg m_axi_awready=1;
  wire m_axi_wvalid;
  wire [127:0] m_axi_wdata;
  wire [15:0] m_axi_wstrb;
  wire m_axi_wlast;
  reg m_axi_wready=1;
  reg [3:0] m_axi_bid=0;
  reg [1:0] m_axi_bresp=0;
  reg m_axi_bvalid=0;
  wire m_axi_bready;
  wire [2:0] rd_outstanding, rd_highwater;
  wire [4:0] r_beat_bytes, w_beat_bytes;

  reg [31:0] spad_mem [0:255];
  reg [3:0] saved_id [0:7];
  reg [63:0] saved_addr [0:7];
  reg [7:0] saved_len [0:7];
  reg [3:0] saved_awid [0:7];
  reg [7:0] saved_awlen [0:7];
  integer ar_count, aw_count, w_count;
  integer spad_line_write_count, spad_line_read_count;
  integer response_phase, response_beat, response_index;
  integer b_phase, timeout, i;
  reg response_active;
  reg spad_read_pending;
  reg spad_line_read_pending;
  reg [31:0] spad_line_read_addr_pending;
  reg [31:0] spad_read_data_pending;
  reg [15:0] final_wstrb_seen;

  always #5 clk=~clk;

  function [127:0] line_for;
    input [31:0] a;
    begin
      line_for={a+32'd12,a+32'd8,a+32'd4,a};
    end
  endfunction

  ai_axi128_dma #(
    .MAX_OUTSTANDING(4),
    .MAX_BURST_BEATS(4)
  ) dut(.*);

  always @(posedge clk) begin
    if (spad_line_valid && spad_line_write && spad_line_ready) begin
      spad_line_write_count <= spad_line_write_count + 1;
      if (|spad_line_wstrb[3:0])
        spad_mem[spad_line_addr[9:2]] <= spad_line_wdata[31:0];
      if (|spad_line_wstrb[7:4])
        spad_mem[spad_line_addr[9:2]+1] <= spad_line_wdata[63:32];
      if (|spad_line_wstrb[11:8])
        spad_mem[spad_line_addr[9:2]+2] <= spad_line_wdata[95:64];
      if (|spad_line_wstrb[15:12])
        spad_mem[spad_line_addr[9:2]+3] <= spad_line_wdata[127:96];
    end
    if (spad_valid && spad_write && spad_ready)
      spad_mem[spad_addr_o[9:2]] <= spad_wdata;
    spad_rsp_valid <= 1'b0;
    spad_line_rsp_valid <= 1'b0;
    if (spad_line_read_pending) begin
      spad_line_rsp_valid <= 1'b1;
      spad_line_rdata <= {spad_mem[spad_line_read_addr_pending[9:2]+3],
                          spad_mem[spad_line_read_addr_pending[9:2]+2],
                          spad_mem[spad_line_read_addr_pending[9:2]+1],
                          spad_mem[spad_line_read_addr_pending[9:2]]};
      spad_line_read_pending <= 1'b0;
    end else if (spad_line_valid && !spad_line_write && spad_line_ready) begin
      spad_line_read_count <= spad_line_read_count + 1;
      spad_line_read_pending <= 1'b1;
      spad_line_read_addr_pending <= spad_line_addr;
    end
    if (spad_read_pending) begin
      spad_rsp_valid <= 1'b1;
      spad_rdata <= spad_read_data_pending;
      spad_read_pending <= 1'b0;
    end else if (spad_valid && !spad_write && spad_ready) begin
      spad_read_data_pending <= spad_mem[spad_addr_o[9:2]];
      spad_read_pending <= 1'b1;
    end

    if (m_axi_arvalid && m_axi_arready) begin
      saved_id[ar_count] <= m_axi_arid;
      saved_addr[ar_count] <= m_axi_araddr;
      saved_len[ar_count] <= m_axi_arlen;
      ar_count <= ar_count+1;
    end
    if (m_axi_awvalid && m_axi_awready) begin
      saved_awid[aw_count] <= m_axi_awid;
      saved_awlen[aw_count] <= m_axi_awlen;
      aw_count <= aw_count+1;
    end
    if (m_axi_wvalid && m_axi_wready) begin
      w_count <= w_count+1;
      if (m_axi_wlast)
        final_wstrb_seen <= m_axi_wstrb;
    end
  end

  // Wait until three bursts are outstanding, then return burst 1, burst 0,
  // and burst 2.  Beats within one ID remain ordered as required by AXI4.
  always @(posedge clk) begin
    if (!resetn) begin
      m_axi_rvalid<=0;
      m_axi_rlast<=0;
      m_axi_rresp<=0;
      m_axi_rid<=0;
      m_axi_rdata<=0;
      response_phase<=0;
      response_beat<=0;
      response_index<=0;
      response_active<=0;
    end else if (m_axi_rvalid && m_axi_rready) begin
      if (m_axi_rlast) begin
        m_axi_rvalid<=0;
        m_axi_rlast<=0;
        response_active<=0;
        response_beat<=0;
        response_phase<=response_phase+1;
      end else begin
        response_beat<=response_beat+1;
        m_axi_rdata<=line_for(saved_addr[response_index]+
                              ((response_beat+1)*16));
        m_axi_rlast<=(response_beat+1>=saved_len[response_index]);
      end
    end else if (!m_axi_rvalid && !response_active &&
                 ar_count>=3 && response_phase<3) begin
      case (response_phase)
        0: response_index=1;
        1: response_index=0;
        default: response_index=2;
      endcase
      response_active<=1;
      response_beat<=0;
      m_axi_rid<=saved_id[response_index];
      m_axi_rdata<=line_for(saved_addr[response_index]);
      m_axi_rresp<=0;
      m_axi_rlast<=(saved_len[response_index]==0);
      m_axi_rvalid<=1;
    end
  end

  // Two transmitted write bursts receive B in reverse ID order.
  always @(posedge clk) begin
    if (!resetn) begin
      m_axi_bvalid<=0;
      m_axi_bid<=0;
      m_axi_bresp<=0;
      b_phase<=0;
    end else if (m_axi_bvalid && m_axi_bready) begin
      m_axi_bvalid<=0;
      b_phase<=b_phase+1;
    end else if (!m_axi_bvalid && aw_count>=2 && b_phase==0) begin
      m_axi_bid<=saved_awid[1];
      m_axi_bresp<=0;
      m_axi_bvalid<=1;
    end else if (!m_axi_bvalid && aw_count>=2 && b_phase==1) begin
      m_axi_bid<=saved_awid[0];
      m_axi_bresp<=0;
      m_axi_bvalid<=1;
    end
  end

  task pulse_start;
    input do_store;
    input [31:0] ea;
    input [31:0] sa;
    input [15:0] words;
    begin
      @(negedge clk);
      store=do_store;
      ext_addr=ea;
      spad_addr=sa;
      length_words=words;
      row_words=0;
      row_count=0;
      ext_stride=0;
      spad_stride=0;
      gather_enable=0;
      gather_index_base=0;
      start=1;
      @(negedge clk);
      start=0;
    end
  endtask

  task wait_done;
    begin
      timeout=0;
      while(!done && timeout<3000) begin
        @(posedge clk);
        timeout=timeout+1;
      end
      if(!done || error)
        $fatal(1,"DMA completion failed: timeout=%0d error=%0d code=%0d",
               timeout,error,error_code);
    end
  endtask

  initial begin
    ar_count=0;
    aw_count=0;
    w_count=0;
    response_phase=0;
    response_beat=0;
    response_index=0;
    response_active=0;
    b_phase=0;
    spad_read_pending=0;
    spad_line_read_pending=0;
    spad_line_read_addr_pending=0;
    final_wstrb_seen=0;
    spad_line_write_count=0;
    spad_line_read_count=0;
    for(i=0;i<256;i=i+1)
      spad_mem[i]=0;

    repeat(4) @(posedge clk);
    resetn=1;

    // 40 words produce three bursts (4, 4, and 2 beats) and cross 4 KiB
    // exactly between the first and second bursts.
    pulse_start(0,32'h0000_1fc0,0,40);
    wait_done();
    if (ar_count!=3 || saved_len[0]!=3 || saved_addr[1]!=32'h0000_2000)
      $fatal(1,"multi-beat or 4-KiB split mismatch");
    for(i=0;i<40;i=i+1)
      if(spad_mem[i]!==32'h0000_1fc0+(i*4))
        $fatal(1,"RID reorder data mismatch at word %0d",i);
    if(rd_highwater<3)
      $fatal(1,"three outstanding read bursts were not observed");
    if(spad_line_write_count!=10)
      $fatal(1,"expected ten 128-bit scratchpad line writes, got %0d",
             spad_line_write_count);

    // 19 words produce a four-beat burst and a three-word tail burst.
    for(i=0;i<19;i=i+1)
      spad_mem[64+i]=32'h9000_0000+i;
    spad_line_read_count=0;
    pulse_start(1,32'h0000_3000,32'h0000_0100,19);
    wait_done();
    if(aw_count!=2 || saved_awlen[0]!=3 || saved_awlen[1]!=0 ||
       w_count!=5 || b_phase<2 || final_wstrb_seen!=16'h0fff)
      $fatal(1,"write burst/tail/BID handling mismatch");
    if(spad_line_read_count!=4)
      $fatal(1,"expected four 128-bit scratchpad line reads, got %0d",
             spad_line_read_count);

    $display("Unified AXI128 DMA PASS: highwater=%0d",rd_highwater);
    $finish;
  end
endmodule
