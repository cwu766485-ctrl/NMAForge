`timescale 1ns/1ps
module tb_svse_product_adapter;
  logic clk=0,resetn=0,start=0; always #5 clk=~clk;
  logic [1:0] op; logic [4:0] shift; logic [31:0] aa,bb,dd,rdata,wdata,addr,result;
  logic valid,write,ready,rsp_valid,busy,done,error; logic [31:0] mem[0:255]; logic pending; logic [7:0] pending_addr;
  wire [31:0] product_residual, product_requant;
  ai_tensor_sfu_math product_math(
    .softmax_delta_q8_8(0), .requant_value(32'sd4096), .requant_shift(5'd5),
    .residual_x(32'sd120), .residual_y(32'sd20), .residual_shift(5'd0),
    .gamma_x(0), .gamma(0), .norm_x(0), .norm_inv_rms(0), .norm_beta(0),
    .norm_add_beta(1'b0), .gelu_product(64'd0), .silu_product(64'd0),
    .softmax_exp_q15(), .requant_i8_value(product_requant),
    .residual_value(product_residual), .gamma_scaled_value(),
    .normalization_value(), .gelu_q8_8_value(), .silu_q8_8_value());
  ai_streaming_sfu_spad_adapter dut(.clk,.resetn,.start,.op_mode(op),.shift,
    .src0_base(aa),.src1_base(bb),.dst_base(dd),.spad_valid(valid),.spad_write(write),
    .spad_addr(addr),.spad_wdata(wdata),.spad_ready(ready),.spad_rsp_valid(rsp_valid),
    .spad_rdata(rdata),.busy,.done,.error,.result);
  always @(posedge clk) begin
    rsp_valid<=pending; pending<=0; if(pending) rdata<=mem[pending_addr];
    if(valid&&!write&&ready) begin pending<=1; pending_addr<=addr[9:2]; end
    if(valid&&write&&ready) mem[addr[9:2]]<=wdata;
  end
  initial begin
    ready=1; rsp_valid=0; pending=0; rdata=0; aa=32'h40; bb=32'h80; dd=32'hc0;
    mem[16]=32'sd120; mem[32]=32'sd20; repeat(2) @(posedge clk); resetn=1;
    @(posedge clk); op=0; shift=0; start=1; @(posedge clk); start=0; wait(done); #1;
    if(mem[48]!==product_residual||result!==product_residual) $fatal(1,"RESIDUAL mismatch");
    mem[16]=32'sd4096; dd=32'hc4; @(posedge clk); op=1; shift=5; start=1; @(posedge clk); start=0; wait(done); #1;
    if(mem[49]!==product_requant||result!==product_requant) $fatal(1,"REQUANT mismatch");
    $display("SVSE_PRODUCT_ADAPTER_PASS residual=%0d requant=%0d",$signed(mem[48]),$signed(mem[49])); $finish;
  end
endmodule
