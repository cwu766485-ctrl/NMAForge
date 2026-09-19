`timescale 1ns/1ps
module tb_ai_banked_cnm_a22;
  reg clk=0, resetn=0, start=0, abort=0;
  reg [31:0] src0=0, src1=32'h100, dst=32'h200;
  wire [3:0] req; wire [31:0] a0,a1,a2,a3;
  reg rsp=0; reg [31:0] d0=0,d1=0,d2=0,d3=0;
  wire [31:0] r0,r1,r2,r3; wire [31:0] result,cycles,reads,prefetch,computes,waits,locals,global;
  wire busy,done,error,spv,spw; wire [31:0] spa,spdata; integer errors=0;
  always #5 clk=~clk;
  ai_banked_cnm_core dut(.clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(8'h20),.src0_base(src0),.src1_base(src1),.dst_base(dst),.length(16'd3),.m_size(16'd1),.scale_shift(5'd0),.activation(2'd0),.watchdog_limit(32'd0),.cnm_req_valid(req),.cnm_addr0(a0),.cnm_addr1(a1),.cnm_addr2(a2),.cnm_addr3(a3),.cnm_req_ready(4'hf),.cnm_rsp_valid({4{rsp}}),.cnm_data0(d0),.cnm_data1(d1),.cnm_data2(d2),.cnm_data3(d3),.cnm_parity_error(4'd0),.cnm_protection_error(1'b0),.spad_valid(spv),.spad_write(spw),.spad_addr(spa),.spad_wdata(spdata),.spad_ready(1'b1),.spad_protection_error(1'b0),.busy(busy),.done(done),.error(error),.error_code(),.result(result),.cycle_count(cycles),.element_count(),.local_accumulate_events(locals),.global_reduce_events(global),.banked_read_issue_events(reads),.prefetch_events(prefetch),.pipeline_compute_events(computes),.response_wait_cycles(waits));
  // A/B response is one cycle after each admitted four-lane request.  Data
  // differs by lane and K group, proving that no central row is broadcast.
  function automatic [31:0] model_word(input [31:0] addr);
    begin
      if (addr < 32'h100) model_word=32'h01010101;
      // The low four bytes select the physical lane.  Decode the K-group
      // from the aligned 16-byte tile address so bank1/2/3 see the same
      // logical B group as bank0 while still using independent addresses.
      else if (((addr-32'h100) & 32'hfffffff0)==32'd0) model_word=32'h01010101;
      else if (((addr-32'h100) & 32'hfffffff0)==32'd16) model_word=32'h02020202;
      else model_word=32'hffffffff;
    end
  endfunction
  always @(posedge clk) begin
    rsp <= |req;
    if (|req) begin
      // Register response data in the same cycle as the request admission;
      // the DUT consumes both on the following clock edge.
      d0 <= model_word(a0); d1 <= model_word(a1);
      d2 <= model_word(a2); d3 <= model_word(a3);
    end
  end
  initial begin
    repeat(3) @(posedge clk); resetn=1; @(posedge clk); start=1; @(posedge clk); start=0;
    wait(done); @(posedge clk);
    if(error) begin $display("ERROR: DUT raised error"); errors=errors+1; end
    if(result!==32'd32) begin $display("ERROR: result expected 32 got %0d",result); errors=errors+1; end
    if(locals!==32'd12) begin $display("ERROR: local expected 12 got %0d",locals); errors=errors+1; end
    if(global!==32'd1) begin $display("ERROR: global expected 1 got %0d",global); errors=errors+1; end
    if(reads!==32'd24) begin $display("ERROR: reads expected 24 got %0d",reads); errors=errors+1; end
    if(prefetch!==32'd8) begin $display("ERROR: prefetch expected 8 got %0d",prefetch); errors=errors+1; end
    if(computes!==32'd12) begin $display("ERROR: compute expected 12 got %0d",computes); errors=errors+1; end
    if(errors) $fatal(1,"CNM A2.2 failed: %0d mismatches",errors);
    $display("PASS: CNM A2.2 result=%0d cycles=%0d local_acc=%0d global_reduce=%0d reads=%0d prefetch=%0d compute=%0d rsp_wait=%0d",result,cycles,locals,global,reads,prefetch,computes,waits); $finish;
  end
endmodule
