`timescale 1ns/1ps
// Gate 0 counterexamples against unchanged production memory fabric + SFU.
// Matrix writes are driven through its real line admission port. No candidate
// cache datapath is installed. shadow[] is observation-only, never drives SFU.
module tb_stage_b_fault_contract;
reg clk=0; always #5 clk=~clk;
reg resetn=0, start=0;
reg [3:0] permission=0;
reg line_valid=0;
reg [31:0] line_addr=0;
reg [127:0] line_data=0;
wire line_ready,line_prot;
wire valid,write,ready,rsp_valid,prot,rsp_error,parity;
wire [31:0] addr,wdata,rdata;
wire busy,done,error;
wire [3:0] error_code;
wire [31:0] result,cycles,elements;
reg [31:0] shadow[0:31];
integer read_accepts=0,write_accepts=0;
always @(posedge clk)if(resetn)begin
 if(valid && ready && !write)read_accepts=read_accepts+1;
 if(valid && ready && write && !prot)write_accepts=write_accepts+1;
end
ai_accel_memory_fabric #(.WORDS_PER_BANK(8192),.SPAD_BYTES(131072)) fabric(
 .clk(clk),.resetn(resetn),
 .region0_base(32'd0),.region0_limit(32'd131072),.region0_perm(permission),
 .region1_base(32'd0),.region1_limit(32'd0),.region1_perm(4'd0),
 .region2_base(32'd0),.region2_limit(32'd0),.region2_perm(4'd0),
 .region3_base(32'd0),.region3_limit(32'd0),.region3_perm(4'd0),
 .host_valid(1'b0),.host_write(1'b0),.host_addr(32'd0),.host_wdata(32'd0),.host_wstrb(4'd0),
 .desc_valid(1'b0),.desc_addr(32'd0),
 .cpl_valid(1'b0),.cpl_write(1'b0),.cpl_addr(32'd0),.cpl_wdata(32'd0),
 .core_valid(valid),.core_write(write),.core_addr(addr),.core_wdata(wdata),.core_ready(ready),
 .core_line_valid(line_valid),.core_line_write(1'b1),.core_line_addr(line_addr),
 .core_line_wdata(line_data),.core_line_wstrb(16'hffff),.core_line_ready(line_ready),
 .banked_valid(1'b0),.banked_addr(32'd0),
 .cnm_valid(4'd0),.cnm_addr0(32'd0),.cnm_addr1(32'd0),.cnm_addr2(32'd0),.cnm_addr3(32'd0),
 .dma_valid(1'b0),.dma_write(1'b0),.dma_addr(32'd0),.dma_wdata(32'd0),
 .dma_line_valid(1'b0),.dma_line_write(1'b0),.dma_line_addr(32'd0),
 .dma_line_wdata(128'd0),.dma_line_wstrb(16'd0),
 .cpl_base(32'd0),.cpl_index(32'd0),
 .scheduler_rdata(rdata),.scheduler_parity_error(parity),
 .core_rsp_valid(rsp_valid),.core_rsp_error(rsp_error),
 .compute_protection_error(prot),.line_protection_error(line_prot)
 ,.host_rdata(),.host_error(),.host_parity_error(),.host_prot_allow()
 ,.desc_ready(),.cpl_ready(),.banked_ready(),.cnm_ready(),.dma_ready(),.dma_line_ready()
 ,.line_rdata(),.line_parity_error(),.line_raw_error()
 ,.banked_data0(),.banked_data1(),.banked_data2(),.banked_data3(),.banked_parity()
 ,.cnm_data0(),.cnm_data1(),.cnm_data2(),.cnm_data3(),.cnm_parity()
 ,.desc_rsp_valid(),.banked_rsp_valid(),.dma_rsp_valid(),.dma_line_rsp_valid()
 ,.desc_rsp_error(),.dma_rsp_error(),.request_client(),.rsp_client()
 ,.rsp_valid(),.rsp_error(),.rsp_is_line(),.rsp_rdata(),.cnm_rsp_valid()
 ,.banked_protection_error(),.cnm_protection_error(),.cpl_protection_error()
);
ai_tensor_sfu_core sfu(
 .clk(clk),.resetn(resetn),.start(start),.abort(1'b0),.op_mode(8'h36),
 .src0_base(32'd256),.src1_base(32'd0),.beta_base(32'd0),.beta_enable(1'b0),
 .pack_enable(1'b1),.pack_tile_a(1'b0),.dst_base(32'd512),.length(16'd32),
 .m_size(16'd4),.n_size(16'd8),.scale_shift(5'd0),.epsilon(32'd1),.watchdog_limit(32'd0),
 .spad_valid(valid),.spad_write(write),.spad_addr(addr),.spad_wdata(wdata),
 .spad_ready(ready),.spad_rsp_valid(rsp_valid),.spad_rdata(rdata),
 .spad_parity_error(parity || rsp_error),.spad_protection_error(prot),
 .busy(busy),.done(done),.error(error),.error_code(error_code),
 .result(result),.cycle_count(cycles),.element_count(elements)
);
function automatic [31:0] peek(input integer address);
 case((address>>2)&3)
  0:peek=fabric.spad_subsystem_u.scratchpad_u.bank0[address>>4];
  1:peek=fabric.spad_subsystem_u.scratchpad_u.bank1[address>>4];
  2:peek=fabric.spad_subsystem_u.scratchpad_u.bank2[address>>4];
  3:peek=fabric.spad_subsystem_u.scratchpad_u.bank3[address>>4];
 endcase
endfunction
task automatic line_write(input integer address,input [127:0] data,input bit expect_denied);
 begin
  @(negedge clk);line_valid=1;line_addr=address;line_data=data;
  #1;
  while(!line_ready)begin @(negedge clk);#1;end
  if(line_prot!==expect_denied)$fatal(1,"line permission mismatch");
  @(negedge clk);line_valid=0;
 end
endtask
task automatic load_source;
 integer i;
 begin
  for(i=0;i<32;i=i+1)shadow[i]=23+i;
  for(i=0;i<32;i=i+4)
   line_write(256+i*4,{shadow[i+3],shadow[i+2],shadow[i+1],shadow[i]},0);
  for(i=0;i<32;i=i+1)if(peek(256+i*4)!==shadow[i])$fatal(1,"line did not commit");
  for(i=0;i<8;i=i+4)line_write(512+i*4,{4{32'ha55aa55a}},0);
 end
endtask
task automatic run_requant(input [3:0] expected_error);
 integer timeout;
 begin
  read_accepts=0;write_accepts=0;
  @(negedge clk);start=1;
  @(negedge clk);start=0;
  timeout=0;
  while(!done && timeout<1000)begin @(negedge clk);timeout=timeout+1;end
  if(!done || busy || error!==(expected_error!=0) || (error && error_code!=expected_error))
   $fatal(1,"Requant status done=%b error=%b code=%0d",done,error,error_code);
  if(expected_error!=0 && write_accepts!=0)$fatal(1,"fault wrote an output");
  @(negedge clk);
 end
endtask
initial begin
 integer i;reg [31:0] expected;
 repeat(3)@(negedge clk);resetn=1;
 load_source();run_requant(0);
 if(read_accepts!=32 || write_accepts!=8)$fatal(1,"normal accepted counts");
 for(i=0;i<8;i=i+1)begin
  expected={shadow[4*i+3][7:0],shadow[4*i+2][7:0],shadow[4*i+1][7:0],shadow[4*i][7:0]};
  if(peek(512+4*i)!==expected)$fatal(1,"normal independent packed Golden");
 end
 $display("STAGE_B_REQUANT_GOLDEN_PASS reads=32 writes=8 producer_words=32 committed=1");
 load_source();
 // Unsignaled SRAM upset: no host/DMA/compute write transaction exists.
 @(negedge clk);
 fabric.spad_subsystem_u.scratchpad_u.bank0[16]=shadow[0]^32'd1;
 if(shadow[0]!=23 || peek(256)!=22)$fatal(1,"fault setup");
 run_requant(5);
 if(peek(512)!==32'ha55aa55a)$fatal(1,"parity output sentinel");
 $display("STAGE_B_PARITY_COUNTEREXAMPLE_PASS cache_copy=23 sram_word=22 original_parity_preserved=1 baseline_error=5 writes=0 snooped_write_events=0");
 load_source();
 @(negedge clk);permission=4'b1110; // enabled + execute + write; no read
 run_requant(6);
 if(peek(512)!==32'ha55aa55a)$fatal(1,"protection output sentinel");
 $display("STAGE_B_PROTECTION_COUNTEREXAMPLE_PASS producer_write_allowed=1 consumer_read_allowed=0 baseline_error=6 writes=0");
 // Ready is admission, not permission success: denied line must not commit.
 permission=4'b1101; // read+execute, no write
 line_write(256,{4{32'hdeadbeef}},1);
 if(peek(256)!==shadow[0])$fatal(1,"denied line changed SRAM");
 $display("STAGE_B_DENIED_WRITE_PASS ready=1 protection_error=1 committed=0");
 permission=0;load_source();run_requant(0);
 if(write_accepts!=8)$fatal(1,"recovery");
 $display("STAGE_B_GATE0_RTL_PASS normal=1 parity=1 protection=1 denied_write=1 recovery=1 product_rtl_unchanged=1");
 $finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
