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
        $fatal(1,"CNM rewÓ^­¢G§²ÚîÆ­yØ½™¥áÑÕÉ•Ìp($$µ5‘¥Èô¡%}%%QM}IU8¤½ÍÉŒ€µÑ½ÀÑ‰}…¥}…•±}Íµ½­”€µ˜…¥}…•°¹˜p($$¸¸¼¸¸¼¸¸½‰±½¬½‘µ„½•¹Ø½…á¥}µ•µ½Éå}µ½‘•°¹ÍØ€¸¸½Ñˆ½Ñ‰}…¥}…•±}Íµ½­”¹ÍØp($$µ¼€¡%}%%QM}IU8¤½Í¥µØ€µ°€¡%}%%QM}IU8¤½½µÁ¥±”¹±½œ($¡%}%%QM}IU8¤½Í¥µØ€­¹Ñ‰}É…¹‘½µ}Í••ôÈÀÈØÄÀÈä€­%}I9=5}MLôÀp($$­%}MôÈÀÈØÄÀÈä€­1-}AI%=}9Lô¡1-}AI%=}9L¤p($$­%}%%QM}%9I9p($$­%}%%QM}55=Idô¡%}%%QM}IU8¤½Ý½É­±½…½‘¥¥ÑÍ}ÍÁ…‘}ÝÉ¥Ñ•Ì¹µ•µ p($$­%}%%QM}aAQô¡%}%%QM}IU8¤½Ý½É­±½…½‘¥¥ÑÍ}•áÁ•Ñ•¹µ•µ p($$­%}%%QM}!%8ô¡%}%%QM}IU8¤½Ý½É­±½…½‘¥¥ÑÍ}¡¥‘‘•¹}•áÁ•Ñ•¹µ•µ p($$­%}%%QM}IQ1}MXô¡%}%%QM}IU8¤½ÉÑ±}±½¥ÑÌ¹ÍØp($$µ°€¡%}%%QM}IU8¤½ÉÕ¸¹±½œ($¡%}%%QM}AeQ!=8¤€¸¸¼¸¸¼¸¸¼¸¸½‰•¹¡µ…É¬½‘¥¥ÑÌ½‘¥¥ÑÍ}ÅÕ…¹Ñ¥é•‘}½±‘•¸¹Áäp($$´µµ½‘•°€ˆ¡%}%%QM}IU8¤½µ½‘•°½‘¥¥ÑÍ}µ±Á}¥¹Ðà¹¹Áèˆp($$´µÉÑ°µ±½¥ÑÌ€ˆ¡%}%%QM}IU8¤½ÉÑ±}±½¥ÑÌ¹ÍØˆp($$´µ½ÕÐ€ˆ¡%}%%QM}IU8¤½½±‘•¹}½µÁ…É¥Í½¸¹©Í½¸ˆ((ŒA…¥É•Q¥¹å9AT½¹ØÅá}µ¥¹¤É…Á Ñ¡É½Õ ÁÉ½‘ÕÑ¥½¸Ñ½À°5…ÑÉ¥à½MT½¥¹Ðà(Œ•¹¥¹•Ì°	$µØÜ½µµ…¹½½µÁ±•Ñ¥½¸ÅÕ•Õ•Ì°…¹…¸¥¹‘•Á•¹‘•¹ÐÁ•Èµ±…å•È½±‘•¸¸)%}Q%9e9AU}99}IU8€üô€½ÑµÀ½¹µ…™½É•}Ñ¥¹å¹ÁÕ}¹¹}ÉÑ±|¡Í¡•±°‘…Ñ”€¬•d•´•‘|• •4•L¤)%}Q%9e9AU}99}AeQ!=8€üôÁåÑ¡½¸Ì(¹A!=9dè…¥}Ñ¥¹å¹ÁÕ}¹¹}µ…Ñ )…¥}Ñ¥¹å¹ÁÕ}¹¹}µ…Ñ è(%Ñ•ÍÐ€„€µ”€ˆ¡%}Q%9e9AU}99}IU8¤ˆ(%µ­‘¥È€µÀ€ˆ¡%}Q%9e9AU}99}IU8¤ˆ($¡%}Q%9e9AU}99}AeQ!=8¤€¸¸¼¸¸¼¸¸¼¸¸½‰•¹¡µ…É¬½Ñ¥¹å¹ÁÔ½•¹•É…Ñ•}¹µ…}¹¹}Ý½É­±½…¹Áäp($$´µµ½‘•°€ˆ¡%}Q%9e9AU}99}5=0¤ˆp($$´µÑ¥¹äµ½±‘•¸€ˆ¡%}Q%9e9AU}99}=18¤ˆp($$´µ½ÕÐµ‘¥È€ˆ¡%}Q%9e9AU}99}IU8¤½Ý½É­±½…ˆ(%ÙÌ€µ™Õ±°ØÐ€µÍÙ•É¥±½œ€µ‘•‰Õ}…•ÍÌ­…±°€µ­‘ˆ€µÑ¥µ•Í…±”ôÅ¹Ì¼ÅÁÌ€­‘•™¥¹”­YLp($$­¥¹‘¥È¬¸¸¼¸¸¼¸¸½‰±½¬½½¹ÑÉ½°½…•¹Ðp($$­¥¹‘¥È¬¸¸¼¸¸¼¸¸½‰±½¬½‘µ„½…•¹Ðp($$­¥¹‘¥È¬¸¸½™¥áÑÕÉ•Ìp($$µ5‘¥Èô¡%}Q%9e9AU}99}IU8¤½ÍÉŒ€µÑ½ÀÑ‰}…¥}…•±}Íµ½­”€µ˜…¥}…•°¹˜p($$¸¸¼¸¸¼¸¸½‰±½¬½‘µ„½•¹Ø½…á¥}µ•µ½Éå}µ½‘•°¹ÍØ€¸¸½Ñˆ½Ñ‰}…¥}…•±}Íµ½­”¹ÍØp($$µ¼€¡%}Q%9e9AU}99}IU8¤½Í¥µØ€µ°€¡%}Q%9e9AU}99}IU8¤½½µÁ¥±”¹±½œ($¡%}Q%9e9AU}99}IU8¤½Í¥µØ€­¹Ñ‰}É…¹‘½µ}Í••ôÈÀÈØÄÀÈä€­%}I9=5}MLôÀp($$­%}MôÈÀÈØÄÀÈä€­1-}AI%=}9Lô¡1-}AI%=}9L¤€­%}Q%9e9AU}99}5Q p($$­%}Q%9e9AU}99}55=Idô¡%}Q%9e9AU}99}IU8¤½Ý½É­±½…½¹µ…}¹¹}ÍÁ…¹µ•µ p($$­%}Q%9e9AU}99}aAQô¡%}Q%9e9AU}99}IU8¤½Ý½É­±½…½¹µ…}¹¹}•áÁ•Ñ•¹µ•µ p($$µ°€¡%}Q%9e9AU}99}IU8¤½ÉÕ¸¹±½œ(%É•À€µÄ€y95}99}%9I9}AMLœ€¡%}Q%9e9AU}99}IU8¤½ÉÕ¸¹±½œ((Œ=ÁÑ¥½¹…°XÌÍÕ‰ÍåÍÑ•´ÍÑÉ•ÍÌè¥¹©•ÐÍ••‘•É•…½ÝÉ¥Ñ”M1YIH…Ð„É…¹‘½´(Œ‰•…Ð½˜µÕ±Ñ¤µ‰•…Ð5‰ÕÉÍÑÌ…¹¡•¬½µÁ±•Ñ¥½¸Á±ÕÌa$‘É…¥¸µÑ¼µ¥‘±”¸)…¥}‘µ…}•ÉÉ½É}ÍÑÉ•ÍÌè…¥}½µÀ($¸½Í¥µØ€­¹Ñ‰}É…¹‘½µ}Í••ô‘íMô€­%}I9=5}MLôÀ€­%}Mô¡%}M¤p($$­1-}AI%=}9Lô¡1-}AI%=}9L¤€­%}5}II=I}MQIMLp($$µ°…¥}‘µ…}•ÉÉ½É}ÍÑÉ•ÍÌ¹±½œ((ŒÑ¥Ù¥Ñäµ…Ý…É”Íµ½­”èÕÍ•Ì•á…Ñ±äÑ¡”Í…µ”Ñ½Àµ±•Ù•°É•É•ÍÍ¥½¸…Ì(Œ…¥}Íµ½­”°‰ÕÐÝÉ¥Ñ•Ì„Y½¹±äÝ¡•¸•áÁ±¥¥Ñ±äÉ•ÅÕ•ÍÑ•¸€½¹Ù•ÉÐ¥Ð½¸(ŒÑ¡”Må¹½ÁÍåÌ1¥¹Õà•¹Ù¥É½¹µ•¹ÐÝ¥Ñ µ…­”…¥}Íµ½­•}Í…¥™€‰•™½É”Á½Ý•È¸)1-}AI%=}9L€üô€ÄÀ¸À)1-}AI%=}Q€èô€¡ÍÕ‰ÍÐ€¸±|°¡1-}AI%=}9L¤¥¹Ì)Y}%1€üô…¥}…•±}Íµ½­•|¡1-}AI%=}Q¤¹Ù)M%}%1€üô…¥}…•±}Íµ½­•|¡1-}AI%=}Q¤¹Í…¥˜)M%}}%1€üô€¡‰…Í•¹…µ”€¡M%}%1¤¥}‘Œ¹Í…¥˜)M%}%9MQ9€üôÑ‰}…¥}…•±}Íµ½­”½‘ÕÐ()…¥}Íµ½­•}Ùè…¥}½µÀ($¸½Í¥µØ€­¹Ñ‰}É…¹‘½µ}Í••ô‘íMô€­%}I9=5}MLô¡%}I9=5}ML¤€­%}Mô¡%}M¤€­1-}AI%=}9Lô¡1-}AI%=}9L¤€­Y}%1ô¡Y}%1¤€µ°…¥}…•±}Íµ½­•}Ù¹±½œ()…¥}Íµ½­•}Í…¥˜è…¥}Íµ½­•}Ù(%ÙÉÍ…¥˜€µ¥¹ÁÕÐ€¡Y}%1¤€µ½ÕÑÁÕÐ€¡M%}%1¤€µ¥¹ÍÑ…¹”€¡M%}%9MQ9¤($¡AeQ!=8¤€¸¸¼¸¸¼¸¸¼¸¸½Íå¸½¹½Éµ…±¥é•}Í…¥™}É½½Ð¹Áä€´µ¥¹ÁÕÐ€¡M%}%1¤€´µ½ÕÑÁÕÐ€¡M%}}%1¤€´µÑ•ÍÑ‰•¹ Ñ‰}…¥}…•±}Íµ½­”€´µ‘ÕÐ‘ÕÐ€´µÑ½À…¥}…•±}Ñ½À()…¥}ÑÉ…¹Í™½Éµ•Èè…¥}½µÀ($¸½Í¥µØ€­¹Ñ‰}É…¹‘½µ}Í••ô‘íMô€­%}I9=5}MLôÀ€­%}Mô¡%}M¤€­1-}AI%=}9Lô¡1-}AI%=}9L¤€µ°…¥}ÑÉ…¹Í™½Éµ•È¹±½œ((ŒM¡½ÉÐ1¥¹Õà½YL…Ñ”è…±°‘¥É•Ñ•a$½5½ÐÑ•ÍÑÌÝ¥Ñ É…¹‘½´½µÁÕÑ”(Œ…Í•Ì‘¥Í…‰±•¸UÍ”Ñ¡¥Ì…™Ñ•È…¸IQ0•‘¥Ð‰•™½É”Ñ¡”Í••‘•É•É•ÍÍ¥½¸¸)…¥}ÅÕ¥¬è…¥}½µÀ($¸½Í¥µØ€­¹Ñ‰}É…¹‘½µ}Í••ô‘íMô€­%}I9=5}MLôÀ€­%}Mô¡%}M¤€­1-}AI%=}9Lô¡1-}AI%=}9L¤€µ°…¥}ÅÕ¥¬¹±½œ((Œ%¹Ñ••ÈÉ•™•É•¹”µ½‘•°¥Ì¥¹Ñ•¹Ñ¥½¹…±±ä„Í•Á…É…Ñ”…Ñ”è¥ÐÙ…±¥‘…Ñ•ÌÑ¡”(Œ‘½Õµ•¹Ñ•Ì½Ð™¥á•µÁ½¥¹Ð½¹ÑÉ…ÐÝ¥Ñ¡½ÕÐ±…¥µ¥¹œIQ0½Ù•É…”¸)…¥}„Ñ}É•˜è($¡AeQ!=8¤€¸¸¼¸¸¼¸¸½‰±½¬½½µÁÕÑ”½µ…ÑÉ¥à½É•˜½…¥}„Í}É•™•É•¹”¹Áä€´µ…Í•Ì€¡%}I}ML¤€´µÍ••€¡%}I}M¤()…¥}ÁÉ•¡•¬è…¥}„Ñ}É•˜…¥}ÅÕ¥¬((Œ½ÕÍ•1¥¹Õà½YL…Ñ•Ì™½ÈÑ¡”Õ¹¥™¥•5…¹ÍÉ…Ñ¡Á…±¥¹”½IH…É‰¥Ñ•È¸)…¥}‘µ…}½µÀè(%ÙÌ€µ™Õ±°ØÐ€µÍÙ•É¥±½œ€µÑ¥µ•Í…±”ôÅ¹Ì¼Å¹Ì€­‘•™¥¹”­YLp($$µÑ½ÀÑ‰}…¥}…á¤ÄÈá}‘µ„€¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½‘µ„½…¥}…á¤ÄÈá}‘µ„¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½‘µ„½Ñˆ½Ñ‰}…¥}…á¤ÄÈá}‘µ„¹ÍØ€µ¼Í¥µÙ}‘µ„€µ°…¥}‘µ…}½µÀ¹±½œ()…¥}‘µ…}ÉÕ¸è…¥}‘µ…}½µÀ($¸½Í¥µÙ}‘µ„€µ°…¥}‘µ…}ÉÕ¸¹±½œ()…¥}ÍÁ…‘}…É‰}½µÀè(%ÙÌ€µ™Õ±°ØÐ€µÍÙ•É¥±½œ€µÑ¥µ•Í…±”ôÅ¹Ì¼Å¹Ì€­‘•™¥¹”­YLp($$µÑ½ÀÑ‰}…¥}ÍÁ…‘}…É‰¥Ñ•É}ÉÈ€¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½µ•µ½Éä½…¥}ÍÁ…‘}…É‰¥Ñ•È¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½ÍÁ…‘}…É‰¥Ñ•È½Ñˆ½Ñ‰}…¥}ÍÁ…‘}…É‰¥Ñ•É}ÉÈ¹ÍØ€µ¼Í¥µÙ}ÍÁ…‘}…Éˆp($$µ°…¥}ÍÁ…‘}…É‰}½µÀ¹±½œ()…¥}ÍÁ…‘}…É‰}ÉÕ¸è…¥}ÍÁ…‘}…É‰}½µÀ($¸½Í¥µÙ}ÍÁ…‘}…Éˆ€µ°…¥}ÍÁ…‘}…É‰}ÉÕ¸¹±½œ(%É•À€µÄ€œÌµ±¥•¹ÐÍÕÍÑ…¥¹•MAÉ½Õ¹µÉ½‰¥¸AMLÉ…¹ÑÌôÄÀ¼ÄÀ¼ÄÀµ…á}Ý…¥ÐôÈœ…¥}ÍÁ…‘}…É‰}ÉÕ¸¹±½œñðp($%ì•¡¼€‰MA…É‰¥Ñ•È€Ìµ±¥•¹Ð™…¥É¹•ÍÌµ…É­•Èµ¥ÍÍ¥¹œˆì•á¥Ð€Äìô(%É•À€µÄ€M••‘•É•ÅÕ•ÍÐµµ½‘”MAIHAMLœ…¥}ÍÁ…‘}…É‰}ÉÕ¸¹±½œñðp($%ì•¡¼€‰MA…É‰¥Ñ•ÈÍ••‘•É•ÅÕ•ÍÐµµ½‘”™…¥É¹•ÍÌµ…É­•Èµ¥ÍÍ¥¹œˆì•á¥Ð€Äìô(%É•À€µÄ€94½5MA½¹Ñ•¹Ñ¥½¸AML¹µ}É…¹ÑÌôØ‘µ…}±¥¹•}É…¹ÑÌôØœ…¥}ÍÁ…‘}…É‰}ÉÕ¸¹±½œñðp($%ì•¡¼€‰MA…É‰¥Ñ•È94½5½¹Ñ•¹Ñ¥½¸µ…É­•Èµ¥ÍÍ¥¹œˆì•á¥Ð€Äìô(%É•À€µÄ€MÉ…Ñ¡Á…É•ÍÁ½¹Í”Á…É¥Ñä…±¥¹µ•¹ÐAMLœ…¥}ÍÁ…‘}…É‰}ÉÕ¸¹±½œñðp($%ì•¡¼€‰MA…É‰¥Ñ•ÈÉ•ÍÁ½¹Í”½Á…É¥Ñäµ…É­•Èµ¥ÍÍ¥¹œˆì•á¥Ð€Äìô($¸½Í¥µÙ}ÍÁ…‘}…Éˆ€­MA}II}5=}e1LôÄÀÀÀÀ€µ°…¥}ÍÁ…‘}…É‰|ÄÁ­}ÉÕ¸¹±½œ(%É•À€µÄ€M••‘•É•ÅÕ•ÍÐµµ½‘”MAIHAMLå±•ÌôÄÀÀÀÀœ…¥}ÍÁ…‘}…É‰|ÄÁ­}ÉÕ¸¹±½œñðp($%ì•¡¼€‰MA…É‰¥Ñ•È€ÄÀÀÀÀµå±”Í••‘•É•ÅÕ•ÍÐµµ½‘”µ…É­•Èµ¥ÍÍ¥¹œˆì•á¥Ð€Äìô((ŒMÑ…¹‘…±½¹”…É‰¥Ñ•È½‘”µ½Ù•É…”…ÁÑÕÉ”¸€-••À…±°•¹•É…Ñ•…ÉÑ¥™…ÑÌ¥¸(Œ…¸¥Í½±…Ñ•ÉÕ¸‘¥É•Ñ½ÉäÍ¼Ñ¡¥Ì…Ñ”‘½•Ì¹½Ð½Ù•ÉÝÉ¥Ñ”Ñ¡”™Õ¹Ñ¥½¹…°(ŒÍµ½­”•á•ÕÑ…‰±”½È¥ÑÌ±½Ì¸)MA}I	}=Y}IU8€üô€½ÑµÀ½¹µ…™½É•}ÍÁ…‘}…É‰¥Ñ•É}½Ù|¡Í¡•±°‘…Ñ”€¬•d•´•‘|• •4•L¤)MA}I	}=Y}5QI%L€èô±¥¹”­½¹­Ñ°­‰É…¹ ­…ÍÍ•ÉÐ((¹A!=9dè…¥}ÍÁ…‘}…É‰}½Ø)…¥}ÍÁ…‘}…É‰}½Øè(%Ñ•ÍÐ€„€µ”€ˆ¡MA}I	}=Y}IU8¤ˆ(%µ­‘¥È€µÀ€ˆ¡MA}I	}=Y}IU8¤ˆ(%€ˆ¡MA}I	}=Y}IU8¤ˆ€˜˜€¡YL¤€µ™Õ±°ØÐ€µÍÙ•É¥±½œ€µÑ¥µ•Í…±”ôÅ¹Ì¼Å¹Ì€­‘•™¥¹”­YLp($$µ´€¡MA}I	}=Y}5QI%L¤€µµ}‘¥È½Ù•É…”¹Ù‘ˆp($$µÑ½ÀÑ‰}…¥}ÍÁ…‘}…É‰¥Ñ•É}ÉÈ€¡UI%H¤¼¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½µ•µ½Éä½…¥}ÍÁ…‘}…É‰¥Ñ•È¹Øp($$¡UI%H¤¼¸¸¼¸¸¼¸¸½‰±½¬½ÍÁ…‘}…É‰¥Ñ•È½Ñˆ½Ñ‰}…¥}ÍÁ…‘}…É‰¥Ñ•É}ÉÈ¹ÍØp($$µ¼Í¥µØ€µ°½µÁ¥±”¹±½œ(%€ˆ¡MA}I	}=Y}IU8¤ˆ€˜˜€¸½Í¥µØ€­MA}II}5=}e1LôÄÀÀÀÀp($$µ´€¡MA}I	}=Y}5QI%L¤€µµ}‘¥È½Ù•É…”¹Ù‘ˆ€µ°ÉÕ¸¹±½œ(%É•À€µÄ€œÌµ±¥•¹ÐÍÕÍÑ…¥¹•MAÉ½Õ¹µÉ½‰¥¸AMLÉ…¹ÑÌôÄÀ¼ÄÀ¼ÄÀµ…á}Ý…¥ÐôÈœ€ˆ¡MA}I	}=Y}IU8¤½ÉÕ¸¹±½œˆ(%É•À€µÄ€M••‘•É•ÅÕ•ÍÐµµ½‘”MAIHAMLå±•ÌôÄÀÀÀÀœ€ˆ¡MA}I	}=Y}IU8¤½ÉÕ¸¹±½œˆ(%É•À€µÄ€94½5MA½¹Ñ•¹Ñ¥½¸AML¹µ}É…¹ÑÌôØ‘µ…}±¥¹•}É…¹ÑÌôØœ€ˆ¡MA}I	}=Y}IU8¤½ÉÕ¸¹±½œˆ(%É•À€µÄ€MÉ…Ñ¡Á…É•ÍÁ½¹Í”Á…É¥Ñä…±¥¹µ•¹ÐAMLœ€ˆ¡MA}I	}=Y}IU8¤½ÉÕ¸¹±½œˆ(%É•À€µÄ€MA…É‰¥Ñ•ÈÕÉÍ½È™…±±‰…¬É•ÅÕ•ÍÐ™½ÉµÌAML…Í•ÌôÄÈœ€ˆ¡MA}I	}=Y}IU8¤½ÉÕ¸¹±½œˆ(%É•À€µÄ€MA…É‰¥Ñ•È‘•ÍÉ¥ÁÑ½È½½µÁ±•Ñ¥½¸ÁÉ¥½É¥Ñä…¹É•ÍÁ½¹Í”AMLœ€ˆ¡MA}I	}=Y}IU8¤½ÉÕ¸¹±½œˆ(%É•À€µÄ€MA…É‰¥Ñ•ÈÁÉ½Ñ•Ñ¥½¸µ•ÉÉ½ÈÉ•ÍÁ½¹Í”…±¥¹µ•¹ÐAMLœ€ˆ¡MA}I	}=Y}IU8¤½ÉÕ¸¹±½œˆ($¡UI¤€µ™Õ±°ØÐ€µ‘¥È€ˆ¡MA}I	}=Y}IU8¤½½Ù•É…”¹Ù‘ˆˆ€µ™½Éµ…ÐÑ•áÐp($$µÉ•Á½ÉÐ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœˆ€µ±½œ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ¹±½œˆ($„É•À€µÄ€UA$µ9e1ñ•Í¥¸¹½Ð±½…‘•œ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ¹±½œˆ(%Ñ•ÍÐ€µÌ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½µ½‘¥¹™¼¹ÑáÐˆ(%É•À€µÄ€…¥±ÕÉ”€€€€€€€€€€€€€€€Àœ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½…ÍÍ•ÉÑÌ¹ÑáÐˆ(%É•À€µÄ€%¹½µÁ±•Ñ”€€€€€€€€€€€€Àœ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½…ÍÍ•ÉÑÌ¹ÑáÐˆ(%É•À€µÄ€]¥Ñ¡½ÕÐÑÑ•µÁÑÌ€€€€€€Àœ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½…ÍÍ•ÉÑÌ¹ÑáÐˆ(%É•À€µÄ€U¹½Ù•É•€€€€€€€€€Àœ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½…ÍÍ•ÉÑÌ¹ÑáÐˆ(%É•À€µÄ€5…Ñ¡•Ì€€€€€€€€€€€Èœ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½…ÍÍ•ÉÑÌ¹ÑáÐˆ(%É•À€µÄ€…Á}¥‘±•}‘•½‘•}ÕÍ•Í}‘•™…Õ±Ñ}±¥•¹Ðœ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½…ÍÍ•ÉÑÌ¹ÑáÐˆ(%É•À€µÄ€…Á}‰…¹­•‘}É•ÍÁ½¹Í•}µ•Ñ…‘…Ñ…}¥Í}Ù…±¥œ€ˆ¡MA}I	}=Y}IU8¤½ÕÉœ½…ÍÍ•ÉÑÌ¹ÑáÐˆ(%•¡¼€‰MA}I	%QI}=YI}AMLÉ•Á½ÉÐô¡MA}I	}=Y}IU8¤½ÕÉœˆ()…¥}ÕÁÉ…‘•}ÙÌè…¥}‘µ…}ÉÕ¸…¥}ÍÁ…‘}…É‰}ÉÕ¸…¥}ÅÕ¥¬((Œ½ÕÍ•YLÑ•ÍÑÌ¸€… Ñ…É•ÐÉ•…Ñ•Ì„Í•Á…É…Ñ”•á•ÕÑ…‰±”°-…¹±½œ°(ŒÍ¼„‘¥É•Ñ•™…¥±ÕÉ”…¸‰”¥¹ÍÁ•Ñ•¥¸Y•É‘¤Ý¥Ñ¡½ÕÐÉ•‰Õ¥±‘¥¹œ…¥}Íµ½­”¸)YM}=UM€ôÙÌ€µ™Õ±°ØÐ€µÍÙ•É¥±½œ€µ‘•‰Õ}…•ÍÌ­…±°€µ­‘ˆ€µÑ¥µ•Í…±”ôÅ¹Ì¼Å¹Ì€­‘•™¥¹”­YL()…¥}„Ù}‘µ…}½µÀè($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}…á¤ÄÈá}‘µ„€¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½‘µ„½…¥}…á¤ÄÈá}‘µ„¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½‘µ„½…¥}‘µ…}‰ÕÉÍÑ}Á±…¹¹•È¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½‘µ„½…¥}‘µ…}É•…‘}Í±½Ñ}ÑÉ…­•È¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½‘µ„½…¥}‘µ…}ÝÉ¥Ñ•}É•ÍÁ½¹Í•}ÑÉ…­•È¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½‘µ„½…¥}‘µ…}ÍÁ…‘}ÑÉ…¹Í™•É}…‘…ÁÑ•È¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½‘µ„½Ñˆ½Ñ‰}…¥}…á¤ÄÈá}‘µ„¹ÍØ€µ¼Í¥µÙ}„Ù}‘µ„€µ°…¥}„Ù}‘µ…}½µÀ¹±½œ()…¥}„Ù}‘µ…}ÉÕ¸è…¥}„Ù}‘µ…}½µÀ($¸½Í¥µÙ}„Ù}‘µ„€µ°…¥}„Ù}‘µ…}ÉÕ¸¹±½œ()…¥}„Ù}‘…Ñ…Á…Ñ¡Í}½µÀè($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}„Ù}‘…Ñ…Á…Ñ¡Ìp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹¸½…¥}½¹ØÍàÍ}±¥¹•‰Õ™™•É}½É”¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½­Ø½…¥}­Ù}…¡•}•¹¥¹”¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½½µÁÕÑ”½¹¹}­Ø½Ñˆ½Ñ‰}…¥}„Ù}‘…Ñ…Á…Ñ¡Ì¹ÍØ€µ¼Í¥µÙ}„Ù}‘…Ñ…Á…Ñ¡Ì€µ°…¥}„Ù}‘…Ñ…Á…Ñ¡Í}½µÀ¹±½œ()…¥}„Ù}‘…Ñ…Á…Ñ¡Í}ÉÕ¸è…¥}„Ù}‘…Ñ…Á…Ñ¡Í}½µÀ($¸½Í¥µÙ}„Ù}‘…Ñ…Á…Ñ¡Ì€µ°…¥}„Ù}‘…Ñ…Á…Ñ¡Í}ÉÕ¸¹±½œ()…¥}„Ý}ÙÌè…¥}„Ù}‘µ…}ÉÕ¸…¥}„Ù}‘…Ñ…Á…Ñ¡Í}ÉÕ¸…¥}ÍÁ…‘}…É‰}ÉÕ¸((ŒÈ¸ÈÕ¹¥Ð…Ñ”™½ÈÑ¡”™½ÕÈ¥¹‘•Á•¹‘•¹Ð‰…¹¬µ±½…°½¹ÑÉ½±±•ÉÌ¸(ŒQ¡¥Ì™½ÕÍ••á•ÕÑ…‰±”¡…Ì½…Í¥½¹…±±ä‰••¸É•µ½Ù•Ý¡¥±”¥ÑÌYL€¹‘…¥‘¥È(Œ…¡”É•µ…¥¹Ì€¡™½È•á…µÁ±”…™Ñ•È„]M0½]¥¹‘½ÝÌ™¥±”Íå¹Œ¤¸€%¸Ñ¡…ÐÍÑ…Ñ”YL(ŒÍ…åÌÑ¡”‘•Í¥¸¥ÌÕ¹¡…¹•‰ÕÐ‘½•Ì¹½ÐÉ•É•…Ñ”Í¥µÙ}¹µ}„ÈÈ¸€±•…È½¹±ä(ŒÑ¡¥ÌÑ…É•ÐÌ•¹•É…Ñ•…¡”‰•™½É”½µÁ¥±”ì¥Ð‘½•Ì¹½ÐÑ½Õ …¥}Íµ½­”¸)…¥}¹µ}„ÈÉ}½µÀè(%É´€µÉ˜Í¥µÙ}¹µ}„ÈÈÍ¥µÙ}¹µ}„ÈÈ¹‘…¥‘¥È($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}‰…¹­•‘}¹µ}„ÈÈp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­}Á”¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­}±½…±}½¹ÑÉ½±±•È¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­•‘}¹µ}½É”¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½½µÁÕÑ”½¹´½Ñˆ½Ñ‰}…¥}‰…¹­•‘}¹µ}„ÈÈ¹ÍØ€µ¼Í¥µÙ}¹µ}„ÈÈ€µ°…¥}¹µ}„ÈÉ}½µÀ¹±½œ()…¥}¹µ}„ÈÉ}ÉÕ¸è…¥}¹µ}„ÈÉ}½µÀ($¸½Í¥µÙ}¹µ}„ÈÈ€µ°…¥}¹µ}„ÈÉ}ÉÕ¸¹±½œ()…¥}¹µ}„ÈÈè…¥}¹µ}„ÈÉ}ÉÕ¸((Œ½µÁ…É…‰±”YLµ¥É½‰•¹¡µ…É­Ìè•… È½Ì…Í”Á•É™½ÉµÌ€ØÐ©0%9Pà5Ì¸)…¥}¹µ}„É}•µÙ}‰•¹¡}½µÀè(%É´€µÉ˜Í¥µÙ}¹µ}„É}•µÙ}‰•¹ Í¥µÙ}¹µ}„É}•µÙ}‰•¹ ¹‘…¥‘¥È($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}¹µ}„É}•µÙ}‰•¹ p($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­}Á”¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­}±½…±}½¹ÑÉ½±±•È¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­•‘}¹µ}½É”¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½½µÁÕÑ”½¹´½Ñˆ½Ñ‰}…¥}¹µ}„É}•µÙ}‰•¹ ¹ÍØ€µ¼Í¥µÙ}¹µ}„É}•µÙ}‰•¹ €µ°…¥}¹µ}„É}•µÙ}‰•¹¡}½µÀ¹±½œ()…¥}¹µ}„É}•µÙ}‰•¹¡}ÉÕ¸è…¥}¹µ}„É}•µÙ}‰•¹¡}½µÀ($¸½Í¥µÙ}¹µ}„É}•µÙ}‰•¹ €µ°…¥}¹µ}„É}•µÙ}‰•¹¡}ÉÕ¸¹±½œ()…¥}¹µ}„É}•µÙ}‰•¹ è…¥}¹µ}„É}•µÙ}‰•¹¡}ÉÕ¸((ŒM••‘•94½É…±”É•É•ÍÍ¥½¸¸I…¹‘½´Í¥¹•‰åÑ•Ì…É”•¹•É…Ñ•™É½´Ñ¡”(Œ…‘‘É•ÍÌ…¹Í••°Ñ¡•¸¥¹‘•Á•¹‘•¹Ñ±äÉ•‘Õ•‰äÑ¡”Ñ•ÍÑ‰•¹ É•™•É•¹”¸)95}I9=5}ML€üô€ÈÀÈØÄÀÈÄ€ÈÀÈØÄÀÈÈ€ÈÀÈØÄÀÈÌ)¥™¹‘•˜95}I9=5}=UQ}%H)95}I9=5}=UQ}%H€èô€½ÑµÀ½¹µ…™½É•}¹µ}É…¹‘½µ|¡Í¡•±°‘…Ñ”€¬•d•´•‘|• •4•L¤)•¹‘¥˜)…¥}¹µ}É…¹‘½µ}½µÁ¥±”è(%µ­‘¥È€µÀ€¡95}I9=5}=UQ}%H¤($¡YM}=UM¤€µ5‘¥Èô¡95}I9=5}=UQ}%H¤½ÍÉŒ€µÑ½ÀÑ‰}…¥}‰…¹­•‘}¹µ}É…¹‘½´p($$µ´±¥¹”­½¹­™Í´­‰É…¹ p($$µµ}¡¥•È€¡UI%H¤¼¸¸¼¸¸¼¸¸½‰±½¬½½µÁÕÑ”½¹´½Ñˆ½¹µ}É…¹‘½´¹µ}¡¥•Èp($$µµ}‘¥È€¡95}I9=5}=UQ}%H¤½½Ù•É…”¹Ù‘ˆp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­}Á”¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­}±½…±}½¹ÑÉ½±±•È¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½¹´½…¥}‰…¹­•‘}¹µ}½É”¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½½µÁÕÑ”½¹´½Ñˆ½Ñ‰}…¥}‰…¹­•‘}¹µ}É…¹‘½´¹ÍØp($$µ¼€¡95}I9=5}=UQ}%H¤½Í¥µØ€µ°€¡95}I9=5}=UQ}%H¤½½µÁ¥±”¹±½œ((¹A!=9dè…¥}¹µ}É…¹‘½µ}½µÁ¥±”…¥}¹µ}É…¹‘½µ}É•É•ÍÌ)…¥}¹µ}É…¹‘½µ}É•É•ÍÌè…¥}¹µ}É…¹‘½µ}½µÁ¥±”(%Í•Ð€µ”ì™½ÈÍ••¥¸€¡95}I9=5}ML¤ì‘¼p($$¡95}I9=5}=UQ}%H¤½Í¥µØ€­Mô‘Í••€µ´±¥¹”­½¹­™Í´­‰É…¹ p($$$µµ}‘¥È€¡95}I9=5}=UQ}%H¤½½Ù•É…”¹Ù‘ˆ€µµ}¹…µ”¹µ}Í••‘|‘Í••p($$$µ°€¡95}I9=5}=UQ}%H¤½ÉÕ¹}Í••‘|‘Í••¹±½œìp($%É•À€µÄ€‰y95}I9=5}AML½±‘•¹}…Í•ÌôÄÜ™…Õ±ÑÌôàÁ¡…Í•}…‰½ÉÐôØÁ¡…Í•}É•Í•ÐôØ±…Ñ•}™…Õ±ÑÌôÄÉ•Í•Ñ}™…Õ±Ñ}½µ‰¼ôÄÉ•Í•Ñ}É•½Ù•ÉäôÄÝ…¥Ñ}„ôÄÁÉ•™•Ñ¡}‰…­ÁÉ•ÍÍÕÉ”ôÄÍÑ…‰±•}ÍÑ…±°ôÄÉ•ÍÁ½¹Í•Í}‘É…¥¹•ôÄ™…ÍÑ}É•ÍÁ½¹Í”ôÄÍ••ô‘Í••ˆ€¡95}I9=5}=UQ}%H¤½ÉÕ¹}Í••‘|‘Í••¹±½œìp(%‘½¹”()…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹¡}½µÀè(%É´€µÉ˜Í¥µÙ}Ñ•¹Í½É}„Í}•µµ}‰•¹ Í¥µÙ}Ñ•¹Í½É}„Í}•µµ}‰•¹ ¹‘…¥‘¥È($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹ p($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½µ…ÑÉ¥à½…¥}Ñ•¹Í½É}µ…ÑÉ¥á}‘…Ñ…Á…Ñ ¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½µ…ÑÉ¥à½…¥}Ñ•¹Í½É}µ…ÑÉ¥á}…ÉÉ…ä¹ÍØp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½µÁÕÑ”½µ…ÑÉ¥à½…¥}Ñ•¹Í½É}µ…ÑÉ¥á}½É”¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½½µÁÕÑ”½µ…ÑÉ¥à½Ñˆ½Ñ‰}…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹ ¹ÍØ€µ¼Í¥µÙ}Ñ•¹Í½É}„Í}•µµ}‰•¹ €µ°…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹¡}½µÀ¹±½œ()…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹¡}ÉÕ¸è…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹¡}½µÀ($¸½Í¥µÙ}Ñ•¹Í½É}„Í}•µµ}‰•¹ €µ°…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹¡}ÉÕ¸¹±½œ()…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹ è…¥}Ñ•¹Í½É}„Í}•µµ}‰•¹¡}ÉÕ¸()…¥}¹µ}½µÁ…É”è…¥}¹µ}„É}•µÙ}‰•¹ …¥}Ñ•¹Í½É}„Í}•µµ}‰•¹ ((Œ94Í¥¹½™˜…Ñ”èµ¥É½…É¡¥Ñ•ÑÕÉ”Ñ¡É½Õ¡ÁÕÐ°MA…É‰¥ÑÉ…Ñ¥½¸Õ¹‘•È(Œ94½5½¹Ñ•¹Ñ¥½¸°Ñ¡•¸Ñ¡”™Õ±°a$½5½½µÁÕÑ”Íµ½­”É•É•ÍÍ¥½¸¸)…¥}¹µ}Í¥¹½™˜è…¥}¹µ}½µÁ…É”…¥}ÍÁ…‘}…É‰}ÉÕ¸…¥}Íµ½­”()…¥}…Íå¹}™¥™½}½µÀè($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}…Íå¹}™¥™¼p($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½¹ÑÉ½°½‘Œ½…¥}…Íå¹}™¥™¼¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½‘Œ½Ñˆ½Ñ‰}…¥}…Íå¹}™¥™¼¹ÍØ€µ¼Í¥µÙ}…Íå¹}™¥™¼€µ°…¥}…Íå¹}™¥™½}½µÀ¹±½œ()…¥}…Íå¹}™¥™½}ÉÕ¸è…¥}…Íå¹}™¥™½}½µÀ($¸½Í¥µÙ}…Íå¹}™¥™¼€µ°…¥}…Íå¹}™¥™½}ÉÕ¸¹±½œ()…¥}…Íå¹}™¥™¼è…¥}…Íå¹}™¥™½}ÉÕ¸()…¥}…Íå¹}™¥™½}É…¹‘½µ}½µÀè($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}…Íå¹}™¥™½}É…¹‘½´p($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½¹ÑÉ½°½‘Œ½…¥}…Íå¹}™¥™¼¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½‘Œ½Ñˆ½Ñ‰}…¥}…Íå¹}™¥™½}É…¹‘½´¹ÍØ€µ¼Í¥µÙ}…Íå¹}™¥™½}É…¹‘½´€µ°…¥}…Íå¹}™¥™½}É…¹‘½µ}½µÀ¹±½œ()…¥}…Íå¹}™¥™½}É…¹‘½µ}ÉÕ¸è…¥}…Íå¹}™¥™½}É…¹‘½µ}½µÀ($¸½Í¥µÙ}…Íå¹}™¥™½}É…¹‘½´€­Mô¡%}M¤€µ°…¥}…Íå¹}™¥™½}É…¹‘½µ}ÉÕ¸¹±½œ()…¥}…Íå¹}™¥™½}É…¹‘½´è…¥}…Íå¹}™¥™½}É…¹‘½µ}ÉÕ¸()…¥}…Íå¹}™¥™½}É•Í•Ñ}½µÀè($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}…Íå¹}™¥™½}É•Í•Ðp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½¹ÑÉ½°½‘Œ½…¥}…Íå¹}™¥™¼¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½‘Œ½Ñˆ½Ñ‰}…¥}…Íå¹}™¥™½}É•Í•Ð¹ÍØ€µ¼Í¥µÙ}…Íå¹}™¥™½}É•Í•Ð€µ°…¥}…Íå¹}™¥™½}É•Í•Ñ}½µÀ¹±½œ()…¥}…Íå¹}™¥™½}É•Í•Ñ}ÉÕ¸è…¥}…Íå¹}™¥™½}É•Í•Ñ}½µÀ($¸½Í¥µÙ}…Íå¹}™¥™½}É•Í•Ð€µ°…¥}…Íå¹}™¥™½}É•Í•Ñ}ÉÕ¸¹±½œ()…¥}…Íå¹}™¥™½}É•Í•Ðè…¥}…Íå¹}™¥™½}É•Í•Ñ}ÉÕ¸()…¥}ÑÉ±}½µÁÕÑ•}‘}½µÀè($¡YM}=UM¤€µÑ½ÀÑ‰}…¥}ÑÉ±}½µÁÕÑ•}‘Œp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½¹ÑÉ½°½‘Œ½…¥}…Íå¹}™¥™¼¹Øp($$¸¸¼¸¸¼¸¸¼¸¸½ÉÑ°½½¹ÑÉ½°½‘Œ½…¥}ÑÉ±}½µÁÕÑ•}‘Œ¹Øp($$¸¸¼¸¸¼¸¸½‰±½¬½‘Œ½Ñˆ½Ñ‰}…¥}ÑÉ±}½µÁÕÑ•}‘Œ¹ÍØ€µ¼Í¥µÙ}ÑÉ±}½µÁÕÑ•}‘Œ€µ°…¥}ÑÉ±}½µÁÕÑ•}‘}½µÀ¹±½œ()…¥}ÑÉ±}½µÁÕÑ•}‘}ÉÕ¸è…¥}ÑÉ±}½µÁÕÑ•}‘}½µÀ($¸½Í¥µÙ}ÑÉ±}½µÁÕÑ•}‘Œ€µ°…¥}ÑÉ±}½µÁÕÑ•}‘}ÉÕ¸¹±½œ()…¥}ÑÉ±}½µÁÕÑ•}‘Œè…¥}ÑÉ±}½µÁÕÑ•}‘}ÉÕ¸()±•…¸è(%É´€µÉ˜ÍÉŒÍ¥µØ¨€¨¹±½œÕ±¤¹­•ä€¨¹ÙÁÙ}¡‘ÉÌ¹ Y¨¹½Ù…Ì¨€¨¹‘…¥‘¥È€¨¹Ù‘ˆ€¨¹­•ä(