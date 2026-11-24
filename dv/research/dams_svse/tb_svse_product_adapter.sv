`timescale 1ns/1ps
module tb_svse_product_adapter;
  localparam integer LEN=4;
  localparam [7:0] OP_RESIDUAL=8'h34, OP_REQUANT=8'h36;
  logic clk=0,resetn=0,start=0,abort=0,epoch_bump=0; always #5 clk=~clk;
  logic [7:0] op_prod; logic [1:0] op_svse; logic [4:0] shift;
  logic [31:0] aa,bb,dd;
  logic p_valid,p_write,p_ready,p_rsp_valid,p_parity,p_prot,p_busy,p_done,p_error;
  logic [3:0] p_error_code; logic [31:0] p_addr,p_wdata,p_rdata,p_cycles,p_elements,p_result;
  logic s_valid,s_write,s_ready,s_rsp_valid,s_parity,s_prot,s_busy,s_done,s_error;
  logic [3:0] s_error_code; logic [31:0] s_addr,s_wdata,s_rdata,s_cycles,s_ra,s_wa,s_stall,s_rspwait;
  logic [31:0] p_mem[0:255],s_mem[0:255];
  integer cycle=0,p_reads=0,p_writes=0,s_reads=0,s_writes=0;
  logic p_seen_done=0,s_seen_done=0;
  integer p_pending=0,s_pending=0; integer p_addr_pending=0,s_addr_pending=0;
  integer p_delay=0,s_delay=0; integer mode_num=0;

  ai_tensor_sfu_core product_u(.clk,.resetn,.start,.abort,.op_mode(op_prod),
    .src0_base(aa),.src1_base(bb),.beta_base(32'd0),.beta_enable(1'b0),.pack_enable(1'b0),.pack_tile_a(1'b0),
    .input_tile_a(1'b0),.src0_stride(32'd0),
    .dst_base(dd),.length(16'(LEN)),.m_size(16'd0),.n_size(16'd0),.scale_shift(shift),.epsilon(32'd1),.watchdog_limit(32'd0),
    .spad_valid(p_valid),.spad_write(p_write),.spad_addr(p_addr),.spad_wdata(p_wdata),
    .spad_ready(p_ready),.spad_rsp_valid(p_rsp_valid),.spad_rdata(p_rdata),
    .spad_parity_error(p_parity),.spad_protection_error(p_prot),.busy(p_busy),.done(p_done),
    .error(p_error),.error_code(p_error_code),.result(p_result),.cycle_count(p_cycles),.element_count(p_elements));

  ai_streaming_sfu_spad_adapter #(.MAX_LEN(16)) svse_u(.clk,.resetn,.start,.abort,.epoch_bump,
    .op_mode(op_svse),.shift,.src0_base(aa),.src1_base(bb),.dst_base(dd),.length(16'(LEN)),
    .spad_valid(s_valid),.spad_write(s_write),.spad_addr(s_addr),.spad_wdata(s_wdata),
    .spad_ready(s_ready),.spad_rsp_valid(s_rsp_valid),.spad_rdata(s_rdata),
    .spad_parity_error(s_parity),.spad_protection_error(s_prot),.busy(s_busy),.done(s_done),
    .error(s_error),.error_code(s_error_code),.cycle_count(s_cycles),.read_accept_count(s_ra),
    .write_accept_count(s_wa),.request_stall_count(s_stall),.response_wait_count(s_rspwait));

  assign p_ready = ((cycle % 5) != 2);
  assign s_ready = ((cycle % 5) != 2);
  always @(posedge clk) begin
    cycle<=cycle+1;
    if(p_done) p_seen_done<=1;
    if(s_done) s_seen_done<=1;
    p_rsp_valid<=0; s_rsp_valid<=0;
    if(p_pending!=0) begin p_pending<=p_pending-1; if(p_pending==1) begin p_rsp_valid<=1; p_rdata<=p_mem[p_addr_pending]; end end
    if(s_pending!=0) begin s_pending<=s_pending-1; if(s_pending==1) begin s_rsp_valid<=1; s_rdata<=s_mem[s_addr_pending]; end end
    if(p_valid&&p_ready) begin
      if(p_write) begin p_mem[p_addr[9:2]]<=p_wdata; p_writes<=p_writes+1; end
      else begin p_reads<=p_reads+1; p_pending<=2; p_addr_pending<=p_addr[9:2]; end
    end
    if(s_valid&&s_ready) begin
      if(s_write) begin s_mem[s_addr[9:2]]<=s_wdata; s_writes<=s_writes+1; end
      else begin s_reads<=s_reads+1; s_pending<=2; s_addr_pending<=s_addr[9:2]; end
    end
  end

  task automatic init_vectors(input integer mode);
    integer i;
    begin
      for(i=0;i<256;i=i+1) begin p_mem[i]=0; s_mem[i]=0; end
      for(i=0;i<LEN;i=i+1) begin
        if(mode==0) begin p_mem[16+i]=i*31-50; s_mem[16+i]=i*31-50; p_mem[32+i]=70-i*9; s_mem[32+i]=70-i*9; end
        else begin p_mem[16+i]=(i==0)?4096:(i==1)?-4096:(i==2)?12345:32'h80000000; s_mem[16+i]=p_mem[16+i]; end
      end
      p_reads=0;p_writes=0;s_reads=0;s_writes=0;p_pending=0;s_pending=0;
      aa=32'h40;bb=32'h80;dd=32'hc0;shift=(mode==0)?0:5;
      op_prod=(mode==0)?OP_RESIDUAL:OP_REQUANT;op_svse=(mode==0)?2'd0:2'd1;
    end
  endtask

  task automatic run_pair(input integer mode);
    integer begin_cycle,i;
    begin
      init_vectors(mode); p_seen_done=0;s_seen_done=0;begin_cycle=cycle;
      @(negedge clk); start=1; @(negedge clk); start=0;
      wait(p_seen_done && s_seen_done); #1;
      for(i=0;i<LEN;i=i+1) if(p_mem[48+i]!==s_mem[48+i]) $fatal(1,"A/B memory mismatch mode=%0d index=%0d product=%h svse=%h",mode,i,p_mem[48+i],s_mem[48+i]);
      if(p_error||s_error) $fatal(1,"unexpected engine error product=%0d svse=%0d",p_error_code,s_error_code);
      $display("SVSE_AB_PASS mode=%0d product_cycles=%0d svse_cycles=%0d product_reads=%0d svse_reads=%0d product_writes=%0d svse_writes=%0d svse_req_stall=%0d svse_rsp_wait=%0d",mode,p_cycles,s_cycles,p_reads,s_reads,p_writes,s_writes,s_stall,s_rspwait);
    end
  endtask

  task automatic run_abort_read_drain;
    integer i;
    begin
      init_vectors(1); for(i=0;i<LEN;i=i+1) s_mem[48+i]=32'h5a5a5a5a;
      s_seen_done=0; @(negedge clk); start=1; @(negedge clk); start=0;
      wait(s_ra==1); @(negedge clk); abort=1; @(negedge clk); abort=0;
      wait(s_seen_done); #1;
      if(!s_error || s_error_code!=4'd3 || s_wa!=0 || s_mem[48]!==32'h5a5a5a5a)
        $fatal(1,"abort-read drain contract failed code=%0d reads=%0d writes=%0d",s_error_code,s_ra,s_wa);
      $display("SVSE_ABORT_READ_DRAIN_PASS accepted_reads=%0d committed_writes=%0d",s_ra,s_wa);
    end
  endtask

  task automatic run_abort_write_prefix;
    integer i, prefix;
    begin
      init_vectors(1); for(i=0;i<LEN;i=i+1) s_mem[48+i]=32'h5a5a5a5a;
      s_seen_done=0; @(negedge clk); start=1; @(negedge clk); start=0;
      wait(s_wa==1); @(negedge clk); abort=1; @(negedge clk); abort=0;
      wait(s_seen_done); #1;
      prefix=s_wa;
      if(!s_error || s_error_code!=4'd3 || prefix<1 || prefix>2 || s_writes!=prefix)
        $fatal(1,"abort-write prefix count/code mismatch code=%0d prefix=%0d ext_writes=%0d",s_error_code,prefix,s_writes);
      for(i=0;i<LEN;i=i+1) begin
        if(i<prefix && s_mem[48+i]!==((i==0 || i==2)?32'sd127:-32'sd128)) $fatal(1,"abort prefix data mismatch word=%0d data=%h",i,s_mem[48+i]);
        if(i>=prefix && s_mem[48+i]!==32'h5a5a5a5a) $fatal(1,"abort write created hole/tail word=%0d",i);
      end
      $display("SVSE_ABORT_WRITE_PREFIX_PASS committed_prefix=%0d",prefix);
    end
  endtask

  task automatic run_epoch_read_drain;
    integer i;
    begin
      init_vectors(1); for(i=0;i<LEN;i=i+1) s_mem[48+i]=32'h6b6b6b6b;
      s_seen_done=0;
      @(negedge clk); start=1; @(negedge clk); start=0;
      wait(s_ra==1); @(negedge clk); epoch_bump=1; @(negedge clk); epoch_bump=0;
      wait(s_seen_done); #1;
      if(!s_error || s_error_code!=4'd3 || s_wa!=0 || s_mem[48]!==32'h6b6b6b6b)
        $fatal(1,"epoch read drain failed code=%0d writes=%0d",s_error_code,s_wa);
      $display("SVSE_EPOCH_READ_DRAIN_PASS accepted_reads=%0d",s_ra);
    end
  endtask

  initial begin
    p_rsp_valid=0;s_rsp_valid=0;p_rdata=0;s_rdata=0;p_parity=0;p_prot=0;s_parity=0;s_prot=0;
    repeat(3) @(negedge clk); resetn=1;
    run_pair(0); run_pair(1); run_abort_read_drain(); run_abort_write_prefix(); run_epoch_read_drain();
    $display("SVSE_VECTOR_AB_PASS"); $finish;
  end
  initial begin repeat(50000) @(posedge clk); $fatal(1,"TB timeout p_busy=%b s_busy=%b pstate=%0d sstate=%0d",p_busy,s_busy,product_u.state_r,svse_u.state_r); end
endmodule
