`timescale 1ns/1ps
// Preloaded-host operands -> stable raw accumulators. No SPAD/command timing.
module tb_stage_c_matched_service;
reg clk=0;always #5 clk=~clk;
reg resetn=0,clear=0,load=0,load_bank=0,mac=0,mac_bank=0;
reg [127:0] a=0,b=0;
wire [16383:0] accum;
wire signed [63:0] selected;
wire [31:0] result;
wire overflow;
reg [31:0] shared_image[0:20000];
reg [7:0] shared[0:20000];
reg [7:0] serviced_a[0:4095],serviced_b[0:4095];
reg [31:0] committed_output[0:16383];
integer shared_m,shared_n,shared_k,memory_read_cycles,memory_write_cycles,memory_read_bytes,memory_write_bytes;
reg shared_mode=0;
integer total_clock=0;
string output_path;integer out_fd;
always @(posedge clk)total_clock=total_clock+1;
ai_tensor_matrix_array #(.ARRAY_SIZE(16),.RESULT_INDEX_WIDTH(8)) dut(
 .clk(clk),.resetn(resetn),.clear_accumulators(clear),
 .buffer_write_valid(load),.buffer_write_bank(load_bank),.buffer_write_a(a),.buffer_write_b(b),
 .buffer_write_b_matrix(2048'd0),.mac_enable(mac),.mac_bank(mac_bank),.gemv_kfold_mode(1'b0),
 .result_index(8'd0),.result_bias(32'd0),.result_shift(5'd0),.result_activation(2'd0),
 .accumulator_vector(accum),.selected_accumulator(selected),.selected_result(result),.selected_overflow(overflow));
function automatic integer operand_a(input integer row,input integer k);
 if(shared_mode)operand_a=$signed(shared[row*shared_k+k]);
 else operand_a=((row*3+k*2+1)%9)-4;
endfunction
function automatic integer operand_b(input integer k,input integer col);
 if(shared_mode)operand_b=$signed(shared[shared_m*shared_k+k*shared_n+col]);
 else operand_b=((k*2-col*3+5)%9)-4;
endfunction
task automatic vectors(input integer tr,input integer tc,input integer kk,input integer m,input integer n);
 integer i;
 begin
  for(i=0;i<16;i=i+1)begin
   a[i*8+:8]=(tr+i<m)?serviced_a[i*shared_k+kk]:0;
   b[i*8+:8]=(tc+i<n)?serviced_b[kk*16+i]:0;
  end
 end
endtask
task automatic run(input integer m,input integer n,input integer k);
 integer tr,tc,kk,r,c,start,tiles,expected,checks;
 begin
  start=total_clock;tiles=0;checks=0;memory_read_cycles=0;memory_write_cycles=0;memory_read_bytes=0;memory_write_bytes=0;
  for(tr=0;tr<m;tr=tr+16)for(tc=0;tc<n;tc=tc+16)begin
   // Common single-outstanding 128-bit service: one issue + two response
   // clocks per padded operand line. No overlapping compute in this adapter.
   for(integer kk_line=0;kk_line<k;kk_line=kk_line+1)begin
    repeat(3)@(negedge clk);
    for(integer lane=0;lane<16;lane=lane+1)
     serviced_a[lane*k+kk_line]=(tr+lane<m)?operand_a(tr+lane,kk_line):0;
   end
   for(integer kk_line=0;kk_line<k;kk_line=kk_line+1)begin
    repeat(3)@(negedge clk);
    for(integer lane=0;lane<16;lane=lane+1)
     serviced_b[kk_line*16+lane]=(tc+lane<n)?operand_b(kk_line,tc+lane):0;
   end
   memory_read_cycles=memory_read_cycles+3*(k+k);
   memory_read_bytes=memory_read_bytes+16*(k+k);
   clear=1;load=0;mac=0;@(negedge clk);clear=0;
   load=1;load_bank=0;vectors(tr,tc,0,m,n);@(negedge clk);
   for(kk=0;kk<k;kk=kk+1)begin
    mac=1;mac_bank=kk%2;
    load=(kk+1<k);load_bank=(kk+1)%2;
    if(kk+1<k)vectors(tr,tc,kk+1,m,n);
    @(negedge clk);
   end
   mac=0;load=0;tiles=tiles+1;
   for(r=0;r<16 && tr+r<m;r=r+1)for(c=0;c<16 && tc+c<n;c=c+1)begin
    expected=0;
    for(kk=0;kk<k;kk=kk+1)expected=expected+operand_a(tr+r,kk)*operand_b(kk,tc+c);
    if($signed(accum[(r*16+c)*64+:64])!==64'(expected))
     $fatal(1,"array Golden mismatch %0dx%0dx%0d row=%0d col=%0d",m,n,k,tr+r,tc+c);

    checks=checks+1;
   end
   for(integer line=0;line<64;line=line+1)begin
    @(negedge clk);
    for(integer lane=0;lane<4;lane=lane+1)begin
     committed_output[line*4+lane]=accum[(line*4+lane)*64+:32];
     if((tr+(line*4+lane)/16<m)&&(tc+(line*4+lane)%16<n))
      $fdisplay(out_fd,"%08h",committed_output[line*4+lane]);
    end
   end
   memory_write_cycles=memory_write_cycles+64;memory_write_bytes=memory_write_bytes+1024;
  end
  if(total_clock-start!=tiles*(k+2)+memory_read_cycles+memory_write_cycles)$fatal(1,"array cycle closure");
  $display("STAGE_C_SERVICE phases_read=%0d phases_write=%0d read_bytes=%0d write_bytes=%0d total=%0d",memory_read_cycles,memory_write_cycles,memory_read_bytes,memory_write_bytes,total_clock-start);
  $display("NMA_MATCHED_SERVICE_PASS shape=%0dx%0dx%0d clear=%0d preload=%0d execute=%0d total=%0d golden=%0d macs=%0d boundary=common_clocked_service dispatch=NA",
    m,n,k,tiles,tiles,tiles*k,total_clock-start,checks,m*n*k);
 end
endtask
initial begin
 string path;
 repeat(3)@(negedge clk);resetn=1;@(negedge clk);
 if(!$value$plusargs("SHARED_OPERANDS=%s",path))$fatal(1,"fixture required");
 if(!$value$plusargs("SHARED_OUTPUT=%s",output_path))$fatal(1,"output required");
 $readmemh(path,shared_image);shared_m=shared_image[0];shared_n=shared_image[1];shared_k=shared_image[2];
 for(integer i=0;i<shared_m*shared_k+shared_k*shared_n;i=i+1)shared[i]=shared_image[i+3];
 out_fd=$fopen(output_path,"w");shared_mode=1;run(shared_m,shared_n,shared_k);$fclose(out_fd);
 $finish;
end
endmodule
