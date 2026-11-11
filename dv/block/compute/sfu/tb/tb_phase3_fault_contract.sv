`timescale 1ns/1ps
// Counterexample only: unchanged product scalar SFU + real scratchpad and
// protection. No proposed vector engine is instantiated or claimed verified.
module tb_phase3_fault_contract;
  reg clk=0;always #2 clk=~clk;
  reg resetn=0,start=0,abort=0;
  reg host_valid=0,host_write=0;
  reg [31:0] host_addr=0,host_wdata=0;
  wire [31:0] host_rdata;wire host_error,host_parity;
  wire req,wr;wire [31:0] addr,wdata;wire [31:0] data;
  wire parity;wire busy,done,error;wire [3:0] code;
  wire [31:0] result,cycles,elements;
  reg [1:0] read_valid=0;
  reg line_valid=0;reg [31:0] line_addr=32'h100;
  wire [127:0] line_data;wire [3:0] line_parity;wire line_error;
  integer writes=0,timeout=0;
  always @(posedge clk)begin
    if(!resetn)begin read_valid<=0;writes<=0;end
    else begin
      read_valid<={read_valid[0],req&&!wr};
      if(req&&wr)writes<=writes+1;
    end
  end
  ai_tensor_sfu_core sfu(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(8'h35),
    .src0_base(32'h100),.src1_base(32'd0),.beta_base(32'd0),.beta_enable(1'b0),
    .pack_enable(1'b0),.pack_tile_a(1'b0),.dst_base(32'h200),.length(16'd4),
    .m_size(16'd0),.n_size(16'd0),.scale_shift(5'd0),.epsilon(32'd1),.watchdog_limit(32'd0),
    .spad_valid(req),.spad_write(wr),.spad_addr(addr),.spad_wdata(wdata),
    .spad_ready(1'b1),.spad_rsp_valid(read_valid[1]),.spad_rdata(data),
    .spad_parity_error(parity),.spad_protection_error(1'b0),
    .busy(busy),.done(done),.error(error),.error_code(code),.result(result),
    .cycle_count(cycles),.element_count(elements));
  ai_scratchpad mem(
    .clk(clk),.resetn(resetn),.host_valid(host_valid),.host_write(host_write),
    .host_addr(host_addr),.host_wdata(host_wdata),.host_wstrb(4'hf),
    .host_rdata(host_rdata),.host_error(host_error),.host_parity_error(host_parity),
    .compute_valid(req),.compute_write(wr),.compute_addr(addr),.compute_wdata(wdata),
    .compute_rdata(data),.compute_parity_error(parity),
    .line_valid(line_valid),.line_write(1'b0),.line_addr(line_addr),
    .line_wdata(128'd0),.line_wstrb(16'd0),.line_rdata(line_data),
    .line_parity_error(line_parity),.line_error(line_error),
    .banked_read_valid(1'b0),.banked_addr(32'd0),.banked_data0(),.banked_data1(),
    .banked_data2(),.banked_data3(),.banked_parity_error(),.cnm_read_valid(4'd0),
    .cnm_addr0(32'd0),.cnm_addr1(32'd0),.cnm_addr2(32'd0),.cnm_addr3(32'd0),
    .cnm_data0(),.cnm_data1(),.cnm_data2(),.cnm_data3(),.cnm_parity_error());
  reg [31:0] check_addr=32'h100, check_bytes=4;wire allow;
  ai_spad_protection prot(
    .region0_base(32'h100),.region0_limit(32'h108),.region0_perm(4'hd),
    .region1_base(32'h108),.region1_limit(32'h110),.region1_perm(4'hd),
    .region2_base(32'd0),.region2_limit(32'd0),.region2_perm(4'd0),
    .region3_base(32'd0),.region3_limit(32'd0),.region3_perm(4'd0),
    .req_valid(1'b1),.req_addr(check_addr),.req_bytes(check_bytes),
    .req_write(1'b0),.req_execute(1'b1),.allow(allow));
  task host_store(input [31:0] a,input [31:0] d);
    begin @(negedge clk);host_valid=1;host_write=1;host_addr=a;host_wdata=d;
      @(negedge clk);host_valid=0;host_write=0;end
  endtask
  integer i;
  initial begin
    repeat(4)@(negedge clk);resetn=1;
    for(i=0;i<4;i=i+1)begin
      host_store('h100+i*4,32'd256);
      host_store('h200+i*4,32'hbad00000+i);
    end
    // Corrupt only input word1 parity, preserving its data.
    @(negedge clk);mem.bank1_parity[16]=~mem.bank1_parity[16];
    @(negedge clk);start=1;@(negedge clk);start=0;
    while(!done&&timeout<200)begin @(negedge clk);timeout=timeout+1;end
    if(!done||!error||code!=5||writes!=1||elements!=1)$fatal(1,"scalar prefix/error mismatch code=%d writes=%d",code,writes);
    if(mem.bank0[32]===32'hbad00000||mem.bank1[32]!==32'hbad00001||mem.bank2[32]!==32'hbad00002||mem.bank3[32]!==32'hbad00003)$fatal(1,"scalar prefix/suffix image mismatch");
    $display("PHASE3_SCALAR_PARITY_PREFIX_PASS committed_words=1 error=5 suffix_preserved=3");
    // Existing line path sees four parity bits together. Feeding its aggregate
    // error to scalar SFU before word0 retirement would lose that legal prefix.
    @(negedge clk);line_valid=1;@(negedge clk);line_valid=0;
    if(line_error||line_parity!==4'b0010||!(|line_parity))$fatal(1,"line parity counterexample invalid %b",line_parity);
    $display("PHASE3_LINE_PARITY_COUNTEREXAMPLE_PASS mask=0010 aggregate_error=1 original_prefix=1 naive_aggregate_prefix=0");
    for(i=0;i<4;i=i+1)begin check_addr='h100+i*4;check_bytes=4;#1;if(!allow)$fatal(1,"scalar permission");end
    check_addr='h100;check_bytes=16;#1;if(allow)$fatal(1,"line must not combine adjacent regions");
    $display("PHASE3_LINE_PROTECTION_COUNTEREXAMPLE_PASS scalar_allowed=4 line_allowed=0 adjacent_regions=2");
    $display("PHASE3_FAULT_CONTRACT_PASS unchanged_scalar_and_memory; vector RTL not admitted");$finish;
  end
endmodule
