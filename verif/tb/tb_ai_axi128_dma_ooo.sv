`timescale 1ns / 1ps

// Directed A6 transport test. The responder deliberately returns the second
// AR before the first, proving RID rather than FIFO response association.
module tb_ai_axi128_dma_ooo;
  reg clk=0, resetn=0, start=0, abort=0, store=0;
  reg [31:0] ext_addr=0, spad_addr=0; reg [15:0] length_words=0;
  reg [2:0] read_outstanding=3'd4;
  wire busy, done, error; wire [3:0] error_code;
  wire spad_valid, spad_write; wire [31:0] spad_addr_o, spad_wdata;
  reg spad_ready=1, spad_rsp_valid=0; reg [31:0] spad_rdata=0;
  reg spad_req_error=0, spad_rsp_error=0;
  wire [3:0] m_axi_arid; wire m_axi_arvalid; wire [31:0] m_axi_araddr;
  wire [7:0] m_axi_arlen; wire [2:0] m_axi_arsize; wire [1:0] m_axi_arburst; reg m_axi_arready=1;
  reg [3:0] m_axi_rid=0; reg [127:0] m_axi_rdata=0; reg [1:0] m_axi_rresp=0;
  reg m_axi_rvalid=0, m_axi_rlast=0; wire m_axi_rready;
  wire [3:0] m_axi_awid; wire m_axi_awvalid; wire [31:0] m_axi_awaddr;
  wire [7:0] m_axi_awlen; wire [2:0] m_axi_awsize; wire [1:0] m_axi_awburst; reg m_axi_awready=1;
  wire m_axi_wvalid; wire [127:0] m_axi_wdata; wire [15:0] m_axi_wstrb; wire m_axi_wlast; reg m_axi_wready=1;
  reg [3:0] m_axi_bid=0; reg [1:0] m_axi_bresp=0; reg m_axi_bvalid=0; wire m_axi_bready;
  wire [2:0] rd_outstanding, rd_highwater;

  reg [31:0] spad_mem [0:63];
  reg [3:0] saved_id [0:3]; reg [31:0] saved_addr [0:3];
  integer ar_count, i, phase, timeout;
  reg [3:0] saved_awid [0:3]; integer aw_count, b_phase;
  reg spad_read_pending; reg [31:0] spad_read_data_pending;

  always #5 clk=~clk;
  function [127:0] line_for;
    input [31:0] a;
    begin line_for={a+32'd12,a+32'd8,a+32'd4,a}; end
  endfunction

  ai_axi128_dma_ooo dut(.*);

  always @(posedge clk) begin
    if (spad_valid && spad_write && spad_ready) spad_mem[spad_addr_o[7:2]] <= spad_wdata;
    spad_rsp_valid <= 1'b0;
    if (spad_read_pending) begin
      spad_rsp_valid <= 1'b1; spad_rdata <= spad_read_data_pending;
      spad_read_pending <= 1'b0;
    end else if (spad_valid && !spad_write && spad_ready) begin
      spad_read_data_pending <= spad_mem[spad_addr_o[7:2]];
      spad_read_pending <= 1'b1;
    end
    if (m_axi_arvalid && m_axi_arready) begin
      saved_id[ar_count] <= m_axi_arid; saved_addr[ar_count] <= m_axi_araddr; ar_count <= ar_count+1;
    end
    if (m_axi_awvalid && m_axi_awready) begin saved_awid[aw_count] <= m_axi_awid; aw_count <= aw_count+1; end
  end

  always @(posedge clk) begin
    if (!resetn) begin m_axi_rvalid<=0; m_axi_rlast<=0; m_axi_rresp<=0; m_axi_rid<=0; m_axi_rdata<=0; phase<=0; end
    else if (m_axi_rvalid && m_axi_rready) begin m_axi_rvalid<=0; m_axi_rlast<=0; phase<=phase+1; end
    else if (!m_axi_rvalid && ar_count>=2 && phase==0) begin
      m_axi_rid<=saved_id[1]; m_axi_rdata<=line_for(saved_addr[1]); m_axi_rresp<=0; m_axi_rlast<=1; m_axi_rvalid<=1;
    end else if (!m_axi_rvalid && ar_count>=2 && phase==1) begin
      m_axi_rid<=saved_id[0]; m_axi_rdata<=line_for(saved_addr[0]); m_axi_rresp<=0; m_axi_rlast<=1; m_axi_rvalid<=1;
    end
  end
  always @(posedge clk) begin
    if (!resetn) begin m_axi_bvalid<=0; m_axi_bid<=0; m_axi_bresp<=0; b_phase<=0; end
    else if (m_axi_bvalid && m_axi_bready) begin m_axi_bvalid<=0; b_phase<=b_phase+1; end
    else if (!m_axi_bvalid && aw_count>=2 && b_phase==0) begin m_axi_bid<=saved_awid[1]; m_axi_bresp<=0; m_axi_bvalid<=1; end
    else if (!m_axi_bvalid && aw_count>=2 && b_phase==1) begin m_axi_bid<=saved_awid[0]; m_axi_bresp<=0; m_axi_bvalid<=1; end
  end

  task pulse_start; input do_store; input [31:0] ea; input [31:0] sa; input [15:0] words; begin
    @(negedge clk); store=do_store; ext_addr=ea; spad_addr=sa; length_words=words; start=1;
    @(negedge clk); start=0;
  end endtask
  task wait_done; begin
    timeout=0; while(!done && timeout<1000) begin @(posedge clk); timeout=timeout+1; end
    if(!done || error) begin
      $display("timeout state=%0d ar=%0d phase=%0d slots=%b lines=%b wrrem=%0d wb=%b",
        dut.state_r,ar_count,phase,dut.rd_slot_valid_r,dut.rd_slot_line_valid_r,dut.wr_remaining_r,dut.wr_pending_b_r);
      $fatal(1,"DMA completion error=%0d",error_code);
    end
  end endtask

  initial begin
    ar_count=0; aw_count=0; phase=0; b_phase=0; spad_read_pending=0;
    for(i=0;i<64;i=i+1) spad_mem[i]=0;
    repeat(4) @(posedge clk); resetn=1;
    pulse_start(0,32'h1000,0,8); wait_done();
    if(spad_mem[0]!==32'h1000 || spad_mem[1]!==32'h1004 || spad_mem[2]!==32'h1008 || spad_mem[3]!==32'h100c ||
       spad_mem[4]!==32'h1010 || spad_mem[5]!==32'h1014 || spad_mem[6]!==32'h1018 || spad_mem[7]!==32'h101c)
      $fatal(1,"RID reorder data mismatch");
    if(rd_highwater<2) $fatal(1,"two outstanding IDs were not observed");
    spad_mem[16]=32'ha; spad_mem[17]=32'hb; spad_mem[18]=32'hc; spad_mem[19]=32'hd; spad_mem[20]=32'he;
    pulse_start(1,32'h2000,32'h40,5); wait_done();
    if(aw_count<2 || b_phase<2) $fatal(1,"write BID reordering not exercised");
    $display("A6 AXI128 OOO DMA PASS: rd_highwater=%0d",rd_highwater); $finish;
  end
endmodule
