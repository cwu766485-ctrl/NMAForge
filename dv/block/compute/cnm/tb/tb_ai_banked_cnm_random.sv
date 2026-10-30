`timescale 1ns/1ps

module tb_ai_banked_cnm_random;
  localparam [2:0] ST_A_REQ=3'd1,ST_B_REQ=3'd2,ST_WAIT_A=3'd3;
  localparam [2:0] ST_WAIT_B=3'd4,ST_DONE=3'd5,ST_PREFETCH_A=3'd7;
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
  reg [3:0] accepted_req_d1=0;
  reg [31:0] d0_d1=0,d1_d1=0,d2_d1=0,d3_d1=0;
  reg [3:0] cnm_req_ready=4'hf;
  reg [3:0] stalled_prev=0;
  reg [31:0] stalled_addr0=0,stalled_addr1=0,stalled_addr2=0,stalled_addr3=0;
  reg prefetch_backpressure=0;
  reg extra_response_delay=1;
  wire [3:0] accepted_req=req & cnm_req_ready;
  wire [31:0] result, cycles, elements;
  wire [31:0] local_acc, global_reduce, reads, prefetch, computes, rsp_wait;
  wire busy,done,error,spad_valid,spad_write;
  wire [3:0] error_code;
  wire [31:0] spad_addr,spad_wdata;
  wire cnm_protection_error=inject_cnm_protection && (|rsp_valid);
  wire spad_protection_error=inject_spad_protection && spad_valid && spad_ready;
  integer test_seed=20261021, initial_seed, case_id, errors=0,spad_write_count=0,timeout;
  integer cnm_request_count=0;
  integer wait_a_state_cycles=0,prefetch_a_state_cycles=0;
  always #5 clk=~clk;

  // Exercise the legal request/response contract: only accepted reads return,
  // responses preserve bank order, and selected prefetch requests can be
  // backpressured for one cycle without changing their address.
  always @(*) begin
    cnm_req_ready=4'hf;
    if(prefetch_backpressure) begin
      if(dut.lc0.state_r==3'd4 && rsp_valid[0] &&
         dut.lc0.k_r!=(dut.lc0.length_r-1'b1)) cnm_req_ready[0]=1'b0;
      if(dut.lc1.state_r==3'd4 && rsp_valid[1] &&
         dut.lc1.k_r!=(dut.lc1.length_r-1'b1)) cnm_req_ready[1]=1'b0;
      if(dut.lc2.state_r==3'd4 && rsp_valid[2] &&
         dut.lc2.k_r!=(dut.lc2.length_r-1'b1)) cnm_req_ready[2]=1'b0;
      if(dut.lc3.state_r==3'd4 && rsp_valid[3] &&
         dut.lc3.k_r!=(dut.lc3.length_r-1'b1)) cnm_req_ready[3]=1'b0;
    end
  end

  ai_banked_cnm_core dut(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(op_mode),
    .src0_base(src0),.src1_base(src1),.dst_base(dst),.length(length),
    .m_size(16'd1),.scale_shift(scale_shift),.activation(activation),
    .watchdog_limit(watchdog_limit),.cnm_req_valid(req),.cnm_addr0(a0),.cnm_addr1(a1),
    .cnm_addr2(a2),.cnm_addr3(a3),.cnm_req_ready(cnm_req_ready),.cnm_rsp_valid(rsp_valid),
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
      rsp_valid<=0;accepted_req_d1<=0;
      d0<=0;d1<=0;d2<=0;d3<=0;
      d0_d1<=0;d1_d1<=0;d2_d1<=0;d3_d1<=0;
      stalled_prev<=0;
      stalled_addr0<=0;stalled_addr1<=0;stalled_addr2<=0;stalled_addr3<=0;
      cnm_request_count<=0;
      wait_a_state_cycles<=0;prefetch_a_state_cycles<=0;
    end else begin
      if(stalled_prev[0] && (!req[0] || a0!==stalled_addr0))
        $fatal(1,"CNM lane 0 request changed while backpressured");
      if(stalled_prev[1] && (!req[1] || a1!==stalled_addr1))
        $fatal(1,"CNM lane 1 request changed while backpressured");
      if(stalled_prev[2] && (!req[2] || a2!==stalled_addr2))
        $fatal(1,"CNM lane 2 request changed while backpressured");
      if(stalled_prev[3] && (!req[3] || a3!==stalled_addr3))
        $fatal(1,"CNM lane 3 request changed while backpressured");
      stalled_prev<=req & ~cnm_req_ready;
      if(req[0] && !cnm_req_ready[0]) stalled_addr0<=a0;
      if(req[1] && !cnm_req_ready[1]) stalled_addr1<=a1;
      if(req[2] && !cnm_req_ready[2]) stalled_addr2<=a2;
      if(req[3] && !cnm_req_ready[3]) stalled_addr3<=a3;
      rsp_valid <= extra_response_delay ? accepted_req_d1 : accepted_req;
      accepted_req_d1 <= accepted_req;
      if(extra_response_delay) begin
        d0<=d0_d1;d1<=d1_d1;d2<=d2_d1;d3<=d3_d1;
      end else begin
        if(accepted_req[0]) d0<=model_word(a0);
        if(accepted_req[1]) d1<=model_word(a1);
        if(accepted_req[2]) d2<=model_word(a2);
        if(accepted_req[3]) d3<=model_word(a3);
      end
      cnm_request_count <= cnm_request_count + accepted_req[0] + accepted_req[1] + accepted_req[2] + accepted_req[3];
      if(accepted_req[0]) d0_d1 <= model_word(a0);
      if(accepted_req[1]) d1_d1 <= model_word(a1);
      if(accepted_req[2]) d2_d1 <= model_word(a2);
      if(accepted_req[3]) d3_d1 <= model_word(a3);
      wait_a_state_cycles<=wait_a_state_cycles+
        ((dut.lc0.state_r==3'd3)?1:0)+((dut.lc1.state_r==3'd3)?1:0)+
        ((dut.lc2.state_r==3'd3)?1:0)+((dut.lc3.state_r==3'd3)?1:0);
      prefetch_a_state_cycles<=prefetch_a_state_cycles+
        ((dut.lc0.state_r==3'd7)?1:0)+((dut.lc1.state_r==3'd7)?1:0)+
        ((dut.lc2.state_r==3'd7)?1:0)+((dut.lc3.state_r==3'd7)?1:0);
      if(spad_valid && spad_ready && !spad_protection_error)
        spad_write_count<=spad_write_count+1;
    end
  end

  task automatic run_case(input integer id, input [15:0] k_length,
                          input integer backpressure_mode,input integer extra_delay_mode);
    integer k,lane,wait_a_before,prefetch_before;
    reg [31:0] a_addr,b_addr;
    reg signed [63:0] expected_sum, expected_result;
    begin
      src0=32'h00001000+(id*32'h1000);
      src1=32'h00100000+(id*32'h1000);
      length=k_length;
      scale_shift=id%4;
      activation=id%2;
      prefetch_backpressure=(backpressure_mode!=0);
      extra_response_delay=(extra_delay_mode!=0);
      wait_a_before=wait_a_state_cycles;
      prefetch_before=prefetch_a_state_cycles;
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
      if(extra_delay_mode && wait_a_state_cycles==wait_a_before)
        $fatal(1,"CNM random case=%0d failed to exercise delayed A response state",id);
      if(backpressure_mode && prefetch_a_state_cycles-prefetch_before!=4*(k_length-1))
        $fatal(1,"CNM random case=%0d prefetch backpressure holds=%0d expected=%0d",
               id,prefetch_a_state_cycles-prefetch_before,4*(k_length-1));
      prefetch_backpressure=0;
      extra_response_delay=1;
    end
  endtask

  task automatic abort_at_local_phase(input [2:0] target_state,input integer id);
    integer local_timeout,writes_before;
    begin
      op_mode=8'h20;length=(target_state==ST_DONE)?16'd1:16'd4;
      watchdog_limit=0;parity_error=0;inject_cnm_protection=0;
      inject_spad_protection=0;extra_response_delay=1;
      prefetch_backpressure=(target_state==ST_PREFETCH_A);
      writes_before=spad_write_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      local_timeout=0;
      while(dut.lc0.state_r!=target_state && local_timeout<10000) begin
        @(negedge clk);local_timeout=local_timeout+1;
      end
      if(dut.lc0.state_r!=target_state)
        $fatal(1,"CNM phase Abort id=%0d failed to reach local state=%0d current=%0d",
               id,target_state,dut.lc0.state_r);
      abort=1;@(negedge clk);abort=0;prefetch_backpressure=0;
      local_timeout=0;
      while(!done && local_timeout<10000) begin @(negedge clk);local_timeout=local_timeout+1;end
      if(!done || !error || error_code!==4'd3 || busy)
        $fatal(1,"CNM phase Abort id=%0d code/done/error/busy=%0d/%b/%b/%b",
               id,error_code,done,error,busy);
      if(spad_write_count!=writes_before)
        $fatal(1,"CNM phase Abort id=%0d committed output write",id);
      repeat(4) @(negedge clk);
    end
  endtask

  task automatic reset_at_local_phase(input [2:0] target_state,input integer id);
    integer local_timeout,writes_before;
    begin
      op_mode=8'h20;length=(target_state==ST_DONE)?16'd1:16'd4;
      watchdog_limit=0;abort=0;parity_error=0;inject_cnm_protection=0;
      inject_spad_protection=0;extra_response_delay=1;
      prefetch_backpressure=(target_state==ST_PREFETCH_A);
      writes_before=spad_write_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      local_timeout=0;
      while(dut.lc0.state_r!=target_state && local_timeout<10000) begin
        @(negedge clk);local_timeout=local_timeout+1;
      end
      if(dut.lc0.state_r!=target_state)
        $fatal(1,"CNM phase Reset id=%0d failed to reach local state=%0d current=%0d",
               id,target_state,dut.lc0.state_r);
      resetn=0;#1;prefetch_backpressure=0;
      if(busy || done || error || error_code!=0 ||
         dut.lc0.state_r!=3'd0 || dut.lc1.state_r!=3'd0 ||
         dut.lc2.state_r!=3'd0 || dut.lc3.state_r!=3'd0)
        $fatal(1,"CNM phase Reset id=%0d failed to clear the core",id);
      repeat(3) @(negedge clk);resetn=1;
      repeat(2) @(negedge clk);
      if(spad_write_count!=writes_before)
        $fatal(1,"CNM phase Reset id=%0d committed output write",id);
      run_case(20+id,3,0,1);
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

  task automatic expect_abort_over_expired_watchdog;
    integer writes_before;
    begin
      op_mode=8'h20;length=3;watchdog_limit=32'd1;
      abort=0;parity_error=0;inject_cnm_protection=0;
      inject_spad_protection=0;writes_before=spad_write_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((!busy || cycles<watchdog_limit) && timeout<2000) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!busy || cycles<watchdog_limit)
        $fatal(1,"CNM priority probe missed expiry busy=%b cycles=%0d watchdog=%0d done=%b error=%b state=%0d timeout=%0d",
               busy,cycles,watchdog_limit,done,error,dut.state_r,timeout);
      // The command is still active on this cycle. Assert Abort before the
      // next sampling edge so it competes with the already-expired watchdog.
      abort=1;
      @(negedge clk);abort=0;
      timeout=0;
      while(!done && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || !error || error_code!==4'd3 || busy)
        $fatal(1,"CNM Abort/watchdog priority code=%0d expected=3",error_code);
      if(spad_write_count!=writes_before)
        $fatal(1,"CNM Abort/watchdog priority committed an output write");
      watchdog_limit=0;
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
      run_case(9,3,0,1);
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
      run_case(case_id,case_id,0,1);
    run_case(10,4,1,1);
    run_case(11,3,0,0);
    abort_at_local_phase(ST_A_REQ,0);
    abort_at_local_phase(ST_B_REQ,1);
    abort_at_local_phase(ST_WAIT_A,2);
    abort_at_local_phase(ST_WAIT_B,3);
    abort_at_local_phase(ST_PREFETCH_A,4);
    abort_at_local_phase(ST_DONE,5);
    reset_at_local_phase(ST_A_REQ,0);
    reset_at_local_phase(ST_B_REQ,1);
    reset_at_local_phase(ST_WAIT_A,2);
    reset_at_local_phase(ST_WAIT_B,3);
    reset_at_local_phase(ST_PREFETCH_A,4);
    reset_at_local_phase(ST_DONE,5);
    length=0;expect_cnm_error(4'd1,0);
    if(dut.local_start || dut.local_busy!==4'b0000 ||
       dut.lc0.state_r!=3'd0 || dut.lc1.state_r!=3'd0 ||
       dut.lc2.state_r!=3'd0 || dut.lc3.state_r!=3'd0)
      $fatal(1,"CNM zero-length descriptor reached a bank-local controller");
    length=3;parity_error=4'hf;expect_cnm_error(4'd5,1);
    inject_cnm_protection=1;expect_cnm_error(4'd6,2);
    inject_spad_protection=1;expect_cnm_error(4'd6,3);
    watchdog_limit=1;expect_cnm_error(4'd4,4);
    expect_abort_over_expired_watchdog();
    launch_abort_error();
    // Abort dominates a simultaneous local parity/protection and SPAD
    // protection fault while the command is active.
    length=3;parity_error=4'hf;inject_cnm_protection=1;
    inject_spad_protection=1;abort=1;
    expect_cnm_error(4'd3,5);
    run_late_parity_fault();
    check_reset_recovery();
    if((|accepted_req_d1) || (|rsp_valid))
      $fatal(1,"CNM test ended with accepted reads lacking drained responses");
    if(errors) $fatal(1,"CNM random regression mismatches=%0d",errors);
    $display("CNM_RANDOM_PASS golden_cases=17 faults=8 phase_abort=6 phase_reset=6 late_faults=1 reset_fault_combo=1 reset_recovery=1 wait_a=1 prefetch_backpressure=1 stable_stall=1 responses_drained=1 fast_response=1 seed=%0d",initial_seed);
    $finish;
  end
endmodule
