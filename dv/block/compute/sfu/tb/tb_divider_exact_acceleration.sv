`timescale 1ns/1ps
module tb_divider_exact_acceleration;
reg clk=0; always #5 clk=~clk;
reg resetn=0,start=0,accelerate=0;
reg [63:0] dividend=0,divisor=1;
wire busy,done,error;
wire [63:0] quotient,remainder;
integer i,b,j,count=0,timeout;
reg [63:0] x,y;
reg [63:0] rng=64'h1973a951b76c208d;
ai_unsigned_divider dut(.*);
task check(input [63:0] a,input [63:0] d);
 begin
  @(negedge clk); dividend=a;divisor=d;accelerate=1;start=1;
  @(negedge clk); start=0;timeout=0;
  while(!done && timeout<70) begin @(negedge clk);timeout=timeout+1;end
  if(!done) $fatal(1,"divider timeout");
  if(d==0) begin
   if(!error || quotient!==0 || remainder!==a) $fatal(1,"zero divisor contract");
  end else if(error || quotient!==(a/d) || remainder!==(a%d))
   $fatal(1,"exact mismatch a=%h d=%h q=%h r=%h",a,d,quotient,remainder);
  count=count+1;
 end
endtask
initial begin
 repeat(3) @(negedge clk);resetn=1;
 check(0,1);check(0,0);check(~64'd0,1);check(~64'd0,~64'd0);
 for(b=0;b<64;b=b+1) begin
  x=64'd1<<b;
  check(x,3);check(x-1,7);check(x,~64'd0);check(x|64'd1,x);
 end
 for(i=0;i<1000;i=i+1) begin
  rng=rng^(rng<<13);rng=rng^(rng>>7);rng=rng^(rng<<17);x=rng;
  rng=rng^(rng<<13);rng=rng^(rng>>7);rng=rng^(rng<<17);y=rng;
  check(x,y);
 end
 $display("DIVIDER_EXACT_ACCELERATION_PASS cases=%0d",count);$finish;
end
endmodule
