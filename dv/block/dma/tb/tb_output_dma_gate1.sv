`timescale 1ns / 1ps

// Directed transport test for the unified DMA.  MAX_BURST_BEATS is reduced to
// four so a short test exercises multiple bursts.  The responder returns the
// second read burst before the first and reverses two B responses.
module tb_output_dma_gate1;
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

  integer partial_beats=0,split_aw=0,b_valid_wait=0;
  integer cycle=0,aw_stalls=0,w_stalls=0,b_wait=0,spad_stalls=0;
  integer aw_stability=0,w_stability=0,done_count=0,accepted_bytes=0;
  integer case_id=0,mode=0,beats_left=0,beat_index=0,bdelay=0;
  integer source_index=0,seen_aw=0,seen_w=0,seen_b=0;
  reg [63:0] write_addr;
  reg [3:0] response_id;
  reg [7:0] burst_len;
  reg [2:0] burst_size;
  reg [31:0] external_words[0:4095];
  reg [80:0] held_aw;
  reg [144:0] held_w;
  reg aw_held=0,w_held=0;
  reg pending_line=0,pending_scalar=0;
  reg [31:0] pending_addr=0;
  integer lane,addr_byte,source_byte,timeout2;
  function [31:0] source_word(input integer a);
    source_word=32'h7182c300 ^ (a*32'h10203);
  endfunction

  ai_axi128_dma_sva checks(
    .clk(clk),.resetn(resetn),.arid(m_axi_arid),.arvalid(m_axi_arvalid),
    .araddr(m_axi_araddr),.arlen(m_axi_arlen),.arsize(m_axi_arsize),.arburst(m_axi_arburst),.arready(m_axi_arready),
    .rid(m_axi_rid),.rvalid(m_axi_rvalid),.rlast(m_axi_rlast),.rready(m_axi_rready),
    .awid(m_axi_awid),.awvalid(m_axi_awvalid),.awaddr(m_axi_awaddr),.awlen(m_axi_awlen),.awsize(m_axi_awsize),.awburst(m_axi_awburst),.awready(m_axi_awready),
    .wvalid(m_axi_wvalid),.wdata(m_axi_wdata),.wstrb(m_axi_wstrb),.wlast(m_axi_wlast),.wready(m_axi_wready),
    .bid(m_axi_bid),.bresp(m_axi_bresp),.bvalid(m_axi_bvalid),.bready(m_axi_bready));
  covergroup output_handshake_cg @(posedge clk);
    option.per_instance=1;
    aw_stall:coverpoint (m_axi_awvalid && !m_axi_awready) iff(resetn) { bins hit={1}; }
    w_stall:coverpoint (m_axi_wvalid && !m_axi_wready) iff(resetn) { bins hit={1}; }
    partial:coverpoint (m_axi_wstrb!=16'hffff) iff(resetn && m_axi_wvalid && m_axi_wready) {bins hit={1};}
    b_error:coverpoint m_axi_bresp iff(resetn && m_axi_bvalid && m_axi_bready) {bins okay={0};bins slverr={2};}
    spad_wait:coverpoint (spad_line_valid && !spad_line_ready) iff(resetn) {bins hit={1};}
    split:coverpoint (m_axi_awaddr==64'h1000) iff(resetn && m_axi_awvalid && m_axi_awready) {bins hit={1};}
  endgroup
  output_handshake_cg cov=new;
  // Deterministic service: AW/W stalls last several actual valid edges.
  // Independent scoreboard is driven only by external accepted AW/W, not RTL state.
  always @(posedge clk) begin
    if(!resetn) begin
      cycle<=0;m_axi_bvalid<=0;m_axi_bresp<=0;
      spad_line_rsp_valid<=0;spad_rsp_valid<=0;
      pending_line<=0;pending_scalar<=0;beats_left=0;bdelay=0;
      aw_held<=0;w_held<=0;
    end else begin
      cycle<=cycle+1;
      m_axi_awready<=((cycle%9)>=4);
      m_axi_wready<=((cycle%7)>=3);
      spad_line_ready<=((cycle%6)>=2);spad_ready<=((cycle%6)>=2);
      spad_line_req_error<= ((mode==3 || (mode==7 && seen_aw>0)) && spad_line_valid);
      spad_req_error<= ((mode==3 || (mode==7 && seen_aw>0)) && spad_valid);
      spad_line_rsp_valid<=pending_line;spad_rsp_valid<=pending_scalar;
      spad_line_parity_error<=pending_line && (mode==4 || (mode==8 && seen_aw>0)) ? 4'b0001:0;
      pending_line<=0;pending_scalar<=0;
      if(pending_line)spad_line_rdata<={source_word(pending_addr+12),source_word(pending_addr+8),source_word(pending_addr+4),source_word(pending_addr)};
      if(pending_scalar)spad_rdata<=source_word(pending_addr);
      if(spad_line_valid && spad_line_ready && !spad_line_req_error)begin pending_line<=1;pending_addr<=spad_line_addr;end
      if(spad_valid && spad_ready && !spad_req_error)begin pending_scalar<=1;pending_addr<=spad_addr_o;end
      if(spad_line_valid && !spad_line_ready)spad_stalls++;
      if(aw_held)begin
        if(!m_axi_awvalid || {m_axi_awid,m_axi_awaddr,m_axi_awlen,m_axi_awsize,m_axi_awburst}!==held_aw)$fatal(1,"AW unstable");
        aw_stability++;
      end
      if(w_held)begin
        if(!m_axi_wvalid || {m_axi_wdata,m_axi_wstrb,m_axi_wlast}!==held_w)$fatal(1,"W unstable");
        w_stability++;
      end
      aw_held<=m_axi_awvalid && !m_axi_awready;
      w_held<=m_axi_wvalid && !m_axi_wready;
      held_aw<={m_axi_awid,m_axi_awaddr,m_axi_awlen,m_axi_awsize,m_axi_awburst};
      held_w<={m_axi_wdata,m_axi_wstrb,m_axi_wlast};
      if(m_axi_awvalid && !m_axi_awready)aw_stalls++;
      if(m_axi_wvalid && !m_axi_wready)w_stalls++;
      if(m_axi_bvalid && !m_axi_bready)b_valid_wait++;
      if(m_axi_awvalid && m_axi_awready)begin
        if(m_axi_awaddr==64'h1000)split_aw++;
        if(beats_left!=0 || bdelay || m_axi_bvalid)$fatal(1,"unexpected multiple write stream");
        if(m_axi_awaddr[11:0]+((m_axi_awlen+1)<<m_axi_awsize)>4096)$fatal(1,"4K crossing AW");
        write_addr=m_axi_awaddr;beats_left=m_axi_awlen+1;burst_len=m_axi_awlen;
        burst_size=m_axi_awsize;response_id=m_axi_awid;seen_aw++;
      end
      if(m_axi_wvalid && m_axi_wready)begin
        if(m_axi_wstrb!=16'hffff)partial_beats++;
        if(beats_left<=0)$fatal(1,"W without AW");
        if(m_axi_wlast!==(beats_left==1))$fatal(1,"WLAST mismatch");
        for(lane=0;lane<16;lane++)begin
          addr_byte=(write_addr & ~64'hf)+lane;
          if(m_axi_wstrb[lane])begin
            source_byte=spad_addr+addr_byte-ext_addr;
            if(addr_byte<ext_addr || addr_byte>=ext_addr+length_words*4)$fatal(1,"WSTRB outside output");
            if(m_axi_wdata[lane*8+:8]!==((source_word(source_byte & ~3) >> ((source_byte%4)*8)) & 255))$fatal(1,"independent W Golden");
            external_words[addr_byte/4][(addr_byte%4)*8+:8]=m_axi_wdata[lane*8+:8];accepted_bytes++;
          end
        end
        write_addr=write_addr+(1<<burst_size);beats_left--;seen_w++;
        if(beats_left==0)bdelay=6;
      end
      if(bdelay>0)begin
        b_wait++;bdelay--;
        if(bdelay==0)begin m_axi_bid<=response_id;m_axi_bresp<=mode==1 ? 2:0;m_axi_bvalid<=1;end
      end
      if(m_axi_bvalid && m_axi_bready)begin m_axi_bvalid<=0;seen_b++;end
      if(done)begin done_count++;if(beats_left || bdelay || m_axi_bvalid)$fatal(1,"done before B drain");end
    end
  end

  task run_case(input integer id,input integer inject,input integer words,input integer boundary);
    integer j,expected_bytes,snapshot;
    begin
      @(negedge clk);resetn=0;start=0;abort=0;mode=inject;
      m_axi_awready=0;m_axi_wready=0;spad_line_ready=0;spad_ready=0;
      spad_line_req_error=0;spad_req_error=0;spad_line_parity_error=0;
      seen_aw=0;seen_w=0;seen_b=0;done_count=0;accepted_bytes=0;
      aw_stalls=0;w_stalls=0;b_wait=0;spad_stalls=0;aw_stability=0;w_stability=0;
      ext_addr=boundary ? 64'hff0:64'h800;spad_addr=32'h100;length_words=words;store=1;
      for(j=0;j<4096;j++)external_words[j]=32'ha55aa55a;
      repeat(4)@(negedge clk);resetn=1;
      repeat(2)@(negedge clk);start=1;@(negedge clk);start=0;
      if(inject==2 || inject==5 || inject==6)begin
        if(inject==6)wait(bdelay>0); else wait(seen_w>0);
        @(negedge clk);
        if(inject==2)abort=1;
        else begin resetn=0;repeat(4)@(negedge clk);resetn=1;end
      end
      timeout2=0;
      if(inject!=5 && inject!=6)begin
        while(!done && timeout2<2000)begin @(negedge clk);timeout2++;end
        if(timeout2==2000)$fatal(1,"timeout case %0d",id);
        if(inject==0 && error)$fatal(1,"normal error");
        if(inject!=0 && !error)$fatal(1,"missing injected error");
        if(inject==1 && error_code!=3)$fatal(1,"BRESP error code");
        if((inject==3 || inject==4 || inject==7 || inject==8) && error_code!=4)$fatal(1,"SPAD error code");
        if(inject==2 && error_code!=5)$fatal(1,"abort code");
      end
      @(negedge clk);abort=0;
      snapshot=accepted_bytes;
      repeat(15)@(negedge clk);
      if(accepted_bytes!=snapshot)$fatal(1,"stale W after terminal");
      if(inject!=5 && inject!=6 && done_count!=1)$fatal(1,"completion count %0d",done_count);
      if(inject==0 && accepted_bytes!=words*4)$fatal(1,"missing output bytes");
      if((inject==3 || inject==4) && accepted_bytes!=0)$fatal(1,"SPAD fault leaked output");
      // Entire suffix and guards must remain sentinel; partial final WSTRB checked above.
      for(j=0;j<4096;j++)begin
        if(j*4>=ext_addr && j*4<ext_addr+accepted_bytes)begin
          if(external_words[j]!==source_word(spad_addr+j*4-ext_addr))$fatal(1,"visible prefix");
        end else if(external_words[j]!==32'ha55aa55a)$fatal(1,"sentinel suffix/guard");
      end
      if(inject==0 && (aw_stalls==0 || w_stalls==0 || b_wait==0 || spad_stalls==0 || aw_stability==0 || w_stability==0))$fatal(1,"vacuous stalls");
      $display("OUTPUT_DMA_CASE_PASS id=%0d mode=%0d bytes=%0d AW=%0d W=%0d B=%0d aw_stall=%0d w_stall=%0d b_delay=%0d spad_stall=%0d aw_stable=%0d w_stable=%0d done=%0d",id,inject,accepted_bytes,seen_aw,seen_w,seen_b,aw_stalls,w_stalls,b_wait,spad_stalls,aw_stability,w_stability,done_count);
    end
  endtask
  initial begin
    run_case(0,0,13,0); // partial final beat
    run_case(1,0,20,1); // 4K split
    run_case(2,1,8,0); // BRESP
    run_case(3,2,32,0); // accepted AW/W abort drain
    run_case(4,3,8,0); // request protection
    run_case(5,4,8,0); // response parity
    run_case(6,5,32,0); // reset outstanding AW
    run_case(7,0,13,0); // recovery
    run_case(8,6,32,0); // reset while B is outstanding/delayed
    run_case(9,0,13,0); // second recovery
    if(partial_beats==0 || split_aw==0)$fatal(1,"missing observed partial/split");
    run_case(10,7,32,0); // later burst protection after accepted prefix
    run_case(11,8,32,0); // later burst parity after accepted prefix
    $display("OUTPUT_DMA_COVERAGE partial_beats=%0d split_AW=%0d b_valid_wait=%0d functional=%0.2f",partial_beats,split_aw,b_valid_wait,cov.get_inst_coverage());
    $display("OUTPUT_DMA_GATE1_PASS cases=12 scoreboard=accepted_byte_prefix_sentinel");$finish;
  end
  initial begin #1000000;$fatal(1,"global timeout");end
endmodule
