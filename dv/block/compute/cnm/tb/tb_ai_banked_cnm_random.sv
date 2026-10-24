`timescale 1ns/1ps

module tb_ai_banked_cnm_random;
  reg clk=0, resetn=0, start=0, abort=0;
  reg [7:0] op_mode=8'h20;
  reg [31:0] src0=0, src1=0, dst=32'h8000;
  reg [15:0] length=1;
  reg [4:0] scale_shift=0;
  reg [1:0] activation=0;
  reg [3:0] parity_error=0;
  reg inject_cnm_protection=0,inject_spad_protection=0;
  reg [31:0] watchdog_limit=0;
  reg spad_ready=1;
  wire [3:0] req;
  wire [31:0] a0,a1,a2,a3;
  reg [3:0] rsp_valid=0;
  reg [31:0] d0=0,d1=0,d2=0,d3=0;
  wire [31:0] result, cycles, elements;
  wire [31:0] local_acc, global_reduce, reads, prefetch, computes, rsp_wait;
  wire busy,done,error,spad_valid,spad_write;
  wire [3:0] error_code;
  wire [31:0] spad_addr,spad_wdata;
  wire cnm_protection_error=inject_cnm_protection && (|rsp_valid);
  wire spad_protection_error=inject_spad_protection && spad_valid && spad_ready;
  integer test_seed=20261021, initial_seed, case_id, errors=0,spad_write_count=0,timeout;
  integer cnm_request_count=0;
  always #5 clk=~clk;

  ai_banked_cnm_core dut(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(op_mode),
    .src0_base(src0),.src1_base(src1),.dst_base(dst),.length(length),
    .m_size(16'd1),.scale_shift(scale_shift),.activation(activation),
    .watchdog_limit(watchdog_limit),.cnm_req_valid(req),.cnm_addr0(a0),.cnm_addr1(a1),
    .cnm_addr2(a2),.cnm_addr3(a3),.cnm_req_ready(4'hf),.cnm_rsp_valid(rsp_valid),
    .cnm_data0(d0),.cnm_data1(d1),.cnm_data2(d2),.cnm_data3(d3),
    .cnm_parity_error(parity_error),.cnm_protection_error(cnm_protection_error),
    .spad_valid(spad_valid),.spad_write(spad_write),.spad_addr(spad_addr),
    .spad_wdata(spad_wdata),.spad_ready(spad_ready),.spad_protection_error(spad_protection_error),
    .busy(busy),.done(done),.error(error),.error_code(error_code),
    .result(result),.cycle_count(cycles),.element_count(elements),
    .local_accumulate_events(local_acc),.global_reduce_events(global_reduce),
    .banked_read_issue_events(reads),.prefetch_events(prefetch),
    .pipeline_compute_events(computes),.response_wait_cycles(rsp_wait)
  );

  function automatic [31:0] model_word(input [31:0] addr);
    reg [31:0] x;
    begin
      x = addr ^ (test_seed * 32'h9e3779b9);
      x = x ^ (x << 13);
      x = x ^ (x >> 17);
      x = x ^ (x << 5);
      model_word = x;
    end
  endfunction

  function automatic signed [31:0] dot4(input [31:0] a, input [31:0] b);
    reg signed [31:0] a0,a1,a2,a3,b0,b1,b2,b3;
    reg signed [31:0] p0,p1,p2,p3;
    begin
      a0=$signed(a[7:0]);   a1=$signed(a[15:8]);
      a2=$signed(a[23:16]); a3=$signed(a[31:24]);
      b0=$signed(b[7:0]);   b1=$signed(b[15:8]);
      b2=$signed(b[23:16]); b3=$signed(b[31:24]);
      p0=a0*b0; p1=a1*b1; p2=a2*b2; p3=a3*b3;
      dot4=p0+p1+p2+p3;
    end
  endfunction

  always @(posedge clk) begin
    if(!resetn) begin
      rsp_valid<=0;
      d0<=0;d1<=0;d2<=0;d3<=0;
      cnm_request_count<=0;
    end else begin
      rsp_valid <= req;
      cnm_request_count <= cnm_request_count + req[0] + req[1] + req[2] + req[3];
      if(req[0]) d0 <= model_word(a0);
      if(req[1]) d1 <= model_word(a1);
      if(req[2]) d2 <= model_word(a2);
      if(req[3]) d3 <= model_word(a3);
      if(spad_valid && spad_ready && !spad_protection_error)
        spad_write_count<=spad_write_count+1;
    end
  end

  task automatic run_case(input integer id, input [15:0] k_length);
    integer k,lane;
    reg [31:0] a_addr,b_addr;
    reg signed [63:0] expected_sum, expected_result;
    begin
      src0=32'h00001000+(id*32'h1000);
      src1=32'h00100000+(id*32'h1000);
      length=k_length;
      scale_shift=id%4;
      activation=id%2;
      expected_sum=0;
      for(k=0;k<k_length;k=k+1) begin
        for(lane=0;lane<4;lane=lane+1) begin
          a_addr=src0+(k*16)+(lane*4);
          b_addr=src1+(k*16)+(lane*4);
          expected_sum=expected_sum+dot4(model_word(a_addr),model_word(b_addr));
        end
      end
      expected_result=expected_sum >>> scale_shift;
      if(activation==1 && expected_result<0) expected_result=0;

      @(negedge clk); start=1;
      @(negedge clk); start=0;
      wait(done===1'b1);
      @(negedge clk);
      if(error || error_code!==4'd0 || busy)
        $fatal(1,"CNM random case=%0d unexpected completion error=%b code=%0d busy=%b",id,error,error_code,busy);
      if(result!==expected_result[31:0])
        $fatal(1,"CNM random case=%0d length=%0d result=%08x expected=%08x",id,k_length,result,expected_result[31:0]);
      if(elements!==32'd1 || local_acc!==4*k_length || global_reduce!==32'd1 ||
         reads!==8*k_length || prefetch!==4*(k_length-1) || computes!==4*k_length)
        $fatal(1,"CNM random case=%0d counters elements=%0d local=%0d global=%0d reads=%0d prefetch=%0d compute=%0d",
               id,elements,local_acc,global_reduce,reads,prefetch,computes);
    end
  endtask

  task automatic expect_cnm_error(input [3:0] expected_code,input integer fault_id);
    integer writes_before;
    begin
      writes_before=spad_write_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while(!done && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || !error || error_code!==expected_code || busy)
        $fatal(1,"CNM fault %0d done/error/code/busy=%b/%b/%0d/%b expected=%0d",
               fault_id,done,error,error_code,busy,expected_code);
      if(spad_write_count!=writes_before)
        $fatal(1,"CNM fault %0d committed output writes=%0d before=%0d",
               fault_id,spad_write_count,writes_before);
      @(negedge clk);
      abort=0;parity_error=0;inject_cnm_protection=0;
      inject_spad_protection=0;watchdog_limit=0;
      repeat(2) @(negedge clk);
    end
  endtask

  task automatic launch_abort_error;
    integer writes_before;
    begin
      writes_before=spad_write_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      if(!busy) $fatal(1,"CNM abort probe did not enter busy");
      abort=1;@(negedge clk);abort=0;
      timeout=0;
      while(!done && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || !error || error_code!==4'd3 || busy)
        $fatal(1,"CNM abort did not terminate code=%0d busy=%b",error_code,busy);
      if(spad_write_count!=writes_before)
        $fatal(1,"CNM abort committed an output write");
      repeat(2) @(negedge clk);
    end
  endtask

  task automatic check_reset_recovery;
    begin
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      if(!busy) $fatal(1,"CNM reset probe did not enter busy");
      // Assert reset while abort and three independent protection/parity
      // sources are active; asynchronous reset must clear the whole cluster.
      abort=1;parity_error=4'hf;inject_cnm_protection=1;
      inject_spad_protection=1;
      resetn=0;#1;
      if(busy || done || error || error_code!=0)
        $fatal(1,"CNM reset did not clear command status");
      repeat(3) @(negedge clk);resetn=1;
      abort=0;parity_error=0;inject_cnm_protection=0;inject_spad_protection=0;
      repeat(2) @(negedge clk);
      op_mode=8'h20;length=3;watchdog_limit=0;
      run_case(9,3);
    end
  endtask

  task automatic run_late_parity_fault;
    integer writes_before,issues_before;
    begin
      op_mode=8'h20;length=256;watchdog_limit=0;abort=0;
      parity_error=0;inject_cnm_protection=0;inject_spad_protection=0;
      writes_before=spad_write_count;
      issues_before=cnm_request_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while(cnm_request_count<issues_before+128 && timeout<20000) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(cnm_request_count<issues_before+128)
        $fatal(1,"CNM late parity probe failed to reach issue count=%0d",
               cnm_request_count-issues_before);
      // Keep the parity indication active until a returned bank response is
      // observed after at least sixteen A/B vector requests have progressed.
      parity_error=4'hf;
      timeout=0;
      while(!done && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      parity_error=0;
      if(!done || !error || error_code!=4'd5 || busy)
        $fatal(1,"CNM late parity result done/error/code/busy=%b/%b/%0d/%b",
               done,error,error_code,busy);
      if(spad_write_count!=writes_before)
        $fatal(1,"CNM late parity committed output writes=%0d before=%0d",
               spad_write_count,writes_before);
      repeat(2) @(negedge clk);
    end
  endtask

  initial begin
    if($value$plusargs("SEED=%d",test_seed)) begin end
    initial_seed=test_seed;
    repeat(3) @(negedge clk);
    resetn=1;
    for(case_id=1;case_id<=8;case_id=case_id+1)
      run_case(case_id,case_id);
    length=0;expect_cnm_error(4'd1,0);
    length=3;parity_error=4'hf;expect_cnm_error(4'd5,1);
    inject_cnm_protection=1;expect_cnm_error(4'd6,2);
    inject_spad_protection=1;expect_cnm_error(4'd6,3);
    watchdog_limit=1;expect_cnm_error(4'd4,4);
    launch_abort_error();
    // Abort dominates a simultaneous local parity/protection and SPAD
    // protection fault while the command is active.
    length=3;parity_error=4'hf;inject_cnm_protection=1;
    inject_spad_protection=1;abort=1;
    expect_cnm_error(4'd3,5);
    run_late_parity_fault();
    check_reset_recovery();
    if(errors) $fatal(1,"CNM random regression mismatches=%0d",errors);
    $display("CNM_RANDOM_PASS cases=10 faults=8 late_faults=1 reset_fault_combo=1 reset_recovery=1 seed=%0d",initial_seed);
    $finish;
  end
endmodule
