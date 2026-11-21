`timescale 1ns/1ps
module tb_dams_svse;
  logic clk=0; always #5 clk=~clk;
  logic resetn=0, epoch=0, abort=0;
  logic iv,ir,gv,gr,dv; logic [1:0] eng; logic [7:0] tag,done_tag;
  logic [3:0] bm,deps; logic atomic;
  logic [1:0] ge; logic [7:0] gt; logic [3:0] gb; logic ga,busy;
  logic [3:0] dm; logic [31:0] ac,dc,ep;
  ai_dams_scheduler u(.clk,.resetn,.epoch_bump(epoch),.fault_abort(abort),
    .issue_valid(iv),.issue_ready(ir),.issue_engine(eng),.issue_tag(tag),
    .issue_dep_mask(deps),.issue_bank_mask(bm),.issue_atomic(atomic),
    .grant_valid(gv),.grant_ready(gr),.grant_engine(ge),.grant_tag(gt),
    .grant_bank_mask(gb),.grant_atomic(ga),.done_valid(dv),.done_tag,
    .busy,.done_mask(dm),.accepted_count(ac),.denied_count(dc),.epoch(ep));
  logic sf_iv,sf_ir,sf_ov,sf_or; logic signed [31:0] a,b,od;
  logic [1:0] op; logic [4:0] sh; logic oe; logic [31:0] sac,scc;
  ai_streaming_sfu s(.clk,.resetn,.epoch_bump(epoch),.in_valid(sf_iv),
    .in_ready(sf_ir),.in_a(a),.in_b(b),.op_mode(op),.shift(sh),
    .out_valid(sf_ov),.out_ready(sf_or),.out_data(od),.out_error(oe),
    .accepted_count(sac),.committed_count(scc));
  task automatic issue(input [7:0] t,input [3:0] banks);
    begin @(negedge clk); iv=1; tag=t; bm=banks; #1;
      if (!ir) $fatal(1,"expected issue accepted tag=%0h",t);
      @(posedge clk); #1; iv=0;
    end
  endtask
  initial begin
    iv=0; gr=1; dv=0; deps=0; bm=1; atomic=1; eng=0;
    sf_iv=0; sf_or=1; a=0; b=0; op=0; sh=0;
    #20 resetn=1;
    issue(8'h11,4'b0001);
    issue(8'h12,4'b0010);
    @(negedge clk); iv=1; tag=8'h13; bm=4'b0010; #1;
    if (ir) $fatal(1,"same-bank conflict admitted");
    @(posedge clk); #1; iv=0;
    if (ac != 2 || dc == 0) $fatal(1,"DAMS admission counters incorrect");
    @(negedge clk); dv=1; done_tag=8'h11; @(posedge clk); #1; dv=0;
    @(negedge clk); eng=1; tag=8'h14; deps=4'b0001; bm=4'b0100; iv=1; #1;
    if (!ir) $fatal(1,"completed dependency did not release issue");
    @(posedge clk); #1; iv=0;
    @(negedge clk); sf_iv=1; a=100; b=-40; op=0; sh=0;
    @(posedge clk); #1; sf_iv=0;
    if (!sf_ov || od !== 60) $fatal(1,"stream residual golden mismatch");
    @(negedge clk); sf_or=0; a=300; b=0; op=1; sh=0; sf_iv=1;
    if (sf_ir) $fatal(1,"input accepted while output is backpressured");
    @(posedge clk); #1; sf_iv=0;
    if (!sf_ov || od !== 60) $fatal(1,"output changed under backpressure");
    @(negedge clk); epoch=1; @(posedge clk); #1; epoch=0; sf_or=1;
    if (sf_ov || busy || ep != 1) $fatal(1,"epoch flush failed");
    @(negedge clk); sf_iv=1; a=300; b=0; op=1; sh=0;
    @(posedge clk); #1; sf_iv=0;
    if (!sf_ov || od !== 127) $fatal(1,"requant saturation golden mismatch");
    @(negedge clk); sf_or=1; @(posedge clk); #1;
    $display("DAMS_SVSE_PASS accepted=%0d denied=%0d",ac,dc); $finish;
  end
endmodule
