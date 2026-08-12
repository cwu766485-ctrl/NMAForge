`timescale 1ns / 1ps

module tb_ai_a6_datapaths;
  reg clk=0, resetn=0;
  reg conv_start=0, kv_start=0; reg kv_op=0;
  wire cv, cw; wire [31:0] ca, cd; wire cb, cdone, ce; wire [3:0] cec; wire [31:0] cr,ccyc,cel;
  wire kvv, kvw; wire [31:0] kva, kvd; wire kvb, kvdone, kve; wire [3:0] kvec; wire [31:0] kvr,kvcyc,kvel;
  reg rsp_valid=0; reg [31:0] rsp_data=0; reg rsp_pending=0; reg [31:0] rsp_pending_data=0;
  reg [31:0] mem[0:511]; integer i, timeout;
  wire use_conv = cb;
  wire spv = use_conv ? cv : kvv; wire spw = use_conv ? cw : kvw;
  wire [31:0] spa = use_conv ? ca : kva; wire [31:0] spd = use_conv ? cd : kvd;
  always #5 clk=~clk;
  ai_conv3x3_linebuffer_core #(.MAX_WIDTH(8)) conv(
    .clk(clk),.resetn(resetn),.start(conv_start),.abort(1'b0),.op_mode(8'h16),.src0_base(32'd0),.src1_base(32'h100),.dst_base(32'h200),.height(16'd3),.width(16'd3),.watchdog_limit(32'd0),
    .spad_valid(cv),.spad_write(cw),.spad_addr(ca),.spad_wdata(cd),.spad_ready(1'b1),.spad_rsp_valid(rsp_valid),.spad_rdata(rsp_data),.spad_error(1'b0),.busy(cb),.done(cdone),.error(ce),.error_code(cec),.result(cr),.cycle_count(ccyc),.element_count(cel));
  ai_kv_cache_engine kv(
    .clk(clk),.resetn(resetn),.start(kv_start),.abort(1'b0),.op_mode(kv_op?8'h44:8'h43),.src0_base(kv_op?32'h400:32'h300),.dst_base(kv_op?32'h500:32'h400),.length(16'd4),.src0_stride(32'd64),.src1_stride(32'd16),.aux0({16'd2,16'd3}),.watchdog_limit(32'd0),
    .spad_valid(kvv),.spad_write(kvw),.spad_addr(kva),.spad_wdata(kvd),.spad_ready(1'b1),.spad_rsp_valid(rsp_valid),.spad_rdata(rsp_data),.spad_error(1'b0),.busy(kvb),.done(kvdone),.error(kve),.error_code(kvec),.result(kvr),.cycle_count(kvcyc),.element_count(kvel));
  always @(posedge clk) begin
    rsp_valid<=0;
    if(rsp_pending) begin rsp_valid<=1; rsp_data<=rsp_pending_data; rsp_pending<=0; end
    else if(spv && !spw) begin rsp_pending_data<=mem[spa[10:2]]; rsp_pending<=1; end
    if(spv && spw) mem[spa[10:2]]<=spd;
  end
  task wait_conv; begin timeout=0; while(!cdone && timeout<1000) begin @(posedge clk);timeout=timeout+1;end if(!cdone||ce)$fatal(1,"conv failure %d",cec); end endtask
  task wait_kv; begin timeout=0; while(!kvdone && timeout<1000) begin @(posedge clk);timeout=timeout+1;end if(!kvdone||kve)$fatal(1,"kv failure %d",kvec); end endtask
  initial begin
    for(i=0;i<512;i=i+1)mem[i]=0;
    for(i=0;i<9;i=i+1) begin mem[i]=i+1; mem[64+i]=1; end
    mem[192]=11;mem[193]=12;mem[194]=13;mem[195]=14;
    repeat(4)@(posedge clk);resetn=1;
    @(negedge clk);conv_start=1;@(negedge clk);conv_start=0;wait_conv();
    if(mem[128]!==45 || cel!==1)$fatal(1,"line-buffer convolution mismatch got=%0d",mem[128]);
    @(negedge clk);kv_op=0;kv_start=1;@(negedge clk);kv_start=0;wait_kv();
    if(mem[312]!==11||mem[313]!==12||mem[314]!==13||mem[315]!==14)$fatal(1,"kv write address mismatch");
    @(negedge clk);kv_op=1;kv_start=1;@(negedge clk);kv_start=0;wait_kv();
    if(mem[320]!==11||mem[321]!==12||mem[322]!==13||mem[323]!==14)$fatal(1,"kv read mismatch");
    $display("A6 CNN line-buffer + KV cache PASS");$finish;
  end
endmodule
