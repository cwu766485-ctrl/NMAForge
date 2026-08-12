`timescale 1ns/1ps

// Directed A2 GEMV benchmark.  Four output rows and a 4-bank INT8 layout
// give 64*L MACs per case, exactly matching tb_ai_tensor_a3_gemm_bench.
module tb_ai_cnm_a2_gemv_bench;
  reg clk=0, resetn=0, start=0, abort=0;
  reg [15:0] length=0;
  wire [3:0] req, rsp_valid;
  wire [31:0] a0,a1,a2,a3, result, cycles, elements;
  wire [31:0] local_acc, global_reduce, reads, prefetch, computes, rsp_wait;
  wire busy,done,error,spad_valid,spad_write;
  wire [31:0] spad_addr,spad_wdata;
  reg rsp=0;
  integer errors=0;
  integer expected_result, expected_local, expected_reads, expected_prefetch;

  always #5 clk=~clk;
  ai_banked_cnm_core dut(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(8'h21),
    .src0_base(32'h0000),.src1_base(32'h4000),.dst_base(32'h8000),
    .length(length),.m_size(16'd4),.scale_shift(5'd0),.activation(2'd0),.watchdog_limit(0),
    .cnm_req_valid(req),.cnm_addr0(a0),.cnm_addr1(a1),.cnm_addr2(a2),.cnm_addr3(a3),
    .cnm_req_ready(4'hf),.cnm_rsp_valid({4{rsp}}),
    // All operand bytes are +1.  One bank-local PE therefore retires +4
    // per K group; four banks yield +16 per GEMV output.
    .cnm_data0(32'h01010101),.cnm_data1(32'h01010101),
    .cnm_data2(32'h01010101),.cnm_data3(32'h01010101),
    .cnm_parity_error(4'd0),.cnm_protection_error(1'b0),
    .spad_valid(spad_valid),.spad_write(spad_write),.spad_addr(spad_addr),.spad_wdata(spad_wdata),
    .spad_ready(1'b1),.spad_protection_error(1'b0),.busy(busy),.done(done),.error(error),.error_code(),
    .result(result),.cycle_count(cycles),.element_count(elements),
    .local_accumulate_events(local_acc),.global_reduce_events(global_reduce),
    .banked_read_issue_events(reads),.prefetch_events(prefetch),
    .pipeline_compute_events(computes),.response_wait_cycles(rsp_wait)
  );
  always @(posedge clk) rsp <= |req;

  task run_case(input [15:0] l);
    begin
      length=l;
      expected_result=16*l;
      expected_local=16*l;       // 4 outputs * 4 banks * L groups
      expected_reads=32*l;       // 4 outputs * 4 banks * A/B * L groups
      expected_prefetch=16*(l-1);// 4 outputs * 4 banks * (L-1)
      @(posedge clk); start=1;
      @(posedge clk); start=0;
      wait(done); @(posedge clk);
      if(error || result!==expected_result || elements!==32'd4 ||
         local_acc!==expected_local || global_reduce!==32'd4 ||
         reads!==expected_reads || prefetch!==expected_prefetch || computes!==expected_local) begin
        $display("ERROR: A2 GEMV L=%0d result=%0d elem=%0d local=%0d global=%0d reads=%0d prefetch=%0d compute=%0d",
                 l,result,elements,local_acc,global_reduce,reads,prefetch,computes);
        errors=errors+1;
      end
      // 4 outputs * L K-groups * 16 INT8 MAC per group = 64L MACs.
      $display("BENCH: A2_GEMV L=%0d cycles=%0d outputs=%0d macs=%0d mac_per_cycle_x1000=%0d rsp_wait=%0d reads=%0d prefetch=%0d",
               l,cycles,elements,64*l,(64*l*1000)/cycles,rsp_wait,reads,prefetch);
    end
  endtask
  initial begin
    repeat(3) @(posedge clk); resetn=1;
    run_case(16); run_case(64); run_case(256);
    if(errors) $fatal(1,"A2 GEMV benchmark failed: %0d cases",errors);
    $display("PASS: A2 GEMV benchmark"); $finish;
  end
endmodule
