`timescale 1ns/1ps

module tb_ai_tensor_sfu_random;
  reg clk=0,resetn=0,start=0,abort=0;
  reg [7:0] op_mode=0;
  reg [31:0] src0_base=32'h100,src1_base=0,beta_base=32'h300;
  reg beta_enable=0,pack_enable=0;
  reg [31:0] dst_base=32'h400;
  reg [15:0] length=0;
  reg [4:0] scale_shift=0;
  reg [31:0] epsilon=1,watchdog_limit=0;
  wire spad_valid,spad_write;
  wire [31:0] spad_addr,spad_wdata;
  reg spad_ready=0,spad_rsp_valid=0;
  reg [31:0] spad_rdata=0;
  reg inject_parity=0,inject_protection=0;
  wire busy,done,error;
  wire [3:0] error_code;
  wire [31:0] result,cycle_count,element_count;

  reg [31:0] memory[0:1023];
  reg [31:0] expected[0:31];
  reg [31:0] pending_data=0;
  reg [3:0] response_delay=0;
  reg response_pending=0;
  reg [31:0] ready_lfsr=32'h1ace_b00c;
  integer read_count=0,response_count=0,write_count=0,total_write_count=0;
  integer expected_total_writes=0;
  integer ready_stall_count=0,max_response_delay=0;
  integer fd,case_count,case_id,i,timeout,rc;
  integer seed=20261021,initial_seed;
  integer op,length_i,shift_i,epsilon_i,beta_enable_i,pack_enable_i,query_i;
  integer signed input_x,input_y,input_beta;
  reg [31:0] expected_word,packed_word;
  reg [1023:0] vector_path;

  always #5 clk=~clk;

  ai_tensor_sfu_core dut(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(op_mode),
    .src0_base(src0_base),.src1_base(src1_base),.beta_base(beta_base),
    .beta_enable(beta_enable),.pack_enable(pack_enable),.dst_base(dst_base),
    .length(length),.scale_shift(scale_shift),.epsilon(epsilon),
    .watchdog_limit(watchdog_limit),.spad_valid(spad_valid),
    .spad_write(spad_write),.spad_addr(spad_addr),.spad_wdata(spad_wdata),
    .spad_ready(spad_ready),.spad_rsp_valid(spad_rsp_valid),
    .spad_rdata(spad_rdata),.spad_parity_error(inject_parity && spad_rsp_valid),
    .spad_protection_error(inject_protection && spad_valid && spad_ready),
    .busy(busy),.done(done),.error(error),
    .error_code(error_code),.result(result),.cycle_count(cycle_count),
    .element_count(element_count));

  // Ordered registered scratchpad model with randomized ready stalls and
  // deterministic 0..7 cycle read-response latency.
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      spad_ready<=0;spad_rsp_valid<=0;spad_rdata<=0;
      response_pending<=0;pending_data<=0;response_delay<=0;
      ready_lfsr<=32'h1ace_b00c;
      read_count<=0;response_count<=0;write_count<=0;total_write_count<=0;
      ready_stall_count<=0;max_response_delay<=0;
    end else begin
      ready_lfsr<={ready_lfsr[30:0],ready_lfsr[31]^ready_lfsr[21]^ready_lfsr[1]^ready_lfsr[0]};
      spad_ready<=ready_lfsr[0]|ready_lfsr[3];
      spad_rsp_valid<=0;
      if(spad_valid && !spad_ready) ready_stall_count<=ready_stall_count+1;
      if(response_pending) begin
        if(response_delay==0) begin
          spad_rsp_valid<=1;
          spad_rdata<=pending_data;
          response_pending<=0;
          response_count<=response_count+1;
        end else response_delay<=response_delay-1'b1;
      end else if(spad_valid && !spad_write && spad_ready) begin
        pending_data<=memory[spad_addr[11:2]];
        response_pending<=1;
        response_delay<=ready_lfsr[6:4];
        read_count<=read_count+1;
        if(ready_lfsr[6:4]>max_response_delay)
          max_response_delay<=ready_lfsr[6:4];
      end
      if(spad_valid && spad_write && spad_ready) begin
        memory[spad_addr[11:2]]<=spad_wdata;
        write_count<=write_count+1;
        total_write_count<=total_write_count+1;
      end
    end
  end

  task automatic run_vector;
    integer expected_writes,expected_elements,word_index,byte_index;
    begin
      rc=$fscanf(fd,"%h %d %d %d %d %d %d\n",op,length_i,shift_i,
                 epsilon_i,beta_enable_i,pack_enable_i,query_i);
      if(rc!=7) $fatal(1,"failed to read SFU case header %0d",case_id);
      op_mode=op[7:0];length=length_i[15:0];scale_shift=shift_i[4:0];
      epsilon=(op==8'h39)?query_i:epsilon_i;
      beta_enable=beta_enable_i[0];pack_enable=pack_enable_i[0];
      src0_base=32'h100;src1_base=32'h0;beta_base=32'h300;dst_base=32'h400;
      if(op==8'h33 || op==8'h34 || op==8'h38) src1_base=32'h200;
      for(i=0;i<length_i;i=i+1) begin
        rc=$fscanf(fd,"%d %d %d %h\n",input_x,input_y,input_beta,expected_word);
        if(rc!=4) $fatal(1,"failed to read SFU data case=%0d element=%0d",case_id,i);
        memory[(src0_base>>2)+i]=input_x;
        memory[(32'h200>>2)+i]=input_y;
        memory[(beta_base>>2)+i]=input_beta;
        expected[i]=expected_word;
      end
      for(i=0;i<32;i=i+1) memory[(dst_base>>2)+i]=32'hbad0_0000+i;

      expected_writes=(pack_enable && op==8'h36)?((length_i+3)/4):length_i;
      expected_elements=length_i;
      write_count=0;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while(!done && timeout<100000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || busy || error)
        $fatal(1,"SFU op=%02x length=%0d timeout/error=%b code=%0d cycles=%0d",
               op,length_i,error,error_code,cycle_count);
      if(element_count!==expected_elements || write_count!==expected_writes)
        $fatal(1,"SFU op=%02x length=%0d elements=%0d/%0d writes=%0d/%0d",
               op,length_i,element_count,expected_elements,write_count,expected_writes);

      if(pack_enable && op==8'h36) begin
        for(word_index=0;word_index<expected_writes;word_index=word_index+1) begin
          packed_word=0;
          for(byte_index=0;byte_index<4;byte_index=byte_index+1)
            if(word_index*4+byte_index<length_i)
              packed_word[byte_index*8+:8]=expected[word_index*4+byte_index][7:0];
          if(memory[(dst_base>>2)+word_index]!==packed_word)
            $fatal(1,"SFU packed requant op=%02x len=%0d word=%0d got=%08x expected=%08x",
                   op,length_i,word_index,memory[(dst_base>>2)+word_index],packed_word);
        end
      end else begin
        for(i=0;i<length_i;i=i+1)
          if(memory[(dst_base>>2)+i]!==expected[i])
            $fatal(1,"SFU op=%02x len=%0d elem=%0d got=%08x expected=%08x",
                   op,length_i,i,memory[(dst_base>>2)+i],expected[i]);
      end
      expected_total_writes=expected_total_writes+expected_writes;
      case_id=case_id+1;
    end
  endtask

  task automatic drain_sfu_response;
    begin
      timeout=0;
      while(response_pending && timeout<1000) begin @(negedge clk);timeout=timeout+1;end
      if(response_pending) $fatal(1,"SFU fault test left a SPAD response pending");
      repeat(2) @(negedge clk);
    end
  endtask

  task automatic expect_sfu_error(input [3:0] expected_code,input integer case_id);
    begin
      write_count=0;
      memory[dst_base>>2]=32'hface_cafe;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while(!done && timeout<10000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || !error || error_code!==expected_code || busy)
        $fatal(1,"SFU fault case=%0d done/error/code/busy=%b/%b/%0d/%b expected=%0d",
               case_id,done,error,error_code,busy,expected_code);
      if(write_count!=0 || memory[dst_base>>2]!==32'hface_cafe)
        $fatal(1,"SFU fault case=%0d committed write count=%0d data=%08x",
               case_id,write_count,memory[dst_base>>2]);
      @(negedge clk);
      abort=0;inject_parity=0;inject_protection=0;watchdog_limit=0;
      drain_sfu_response();
    end
  endtask

  task automatic launch_abort_error;
    begin
      write_count=0;memory[dst_base>>2]=32'hface_cafe;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while(!busy && timeout<1000) begin @(negedge clk);timeout=timeout+1;end
      if(!busy) $fatal(1,"SFU abort probe did not enter busy");
      abort=1;@(negedge clk);abort=0;
      timeout=0;
      while(!done && timeout<10000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || !error || error_code!==4'd3 || busy)
        $fatal(1,"SFU abort did not terminate cleanly code=%0d busy=%b",error_code,busy);
      if(write_count!=0 || memory[dst_base>>2]!==32'hface_cafe)
        $fatal(1,"SFU abort committed output");
      repeat(2) @(negedge clk);
      drain_sfu_response();
    end
  endtask

  task automatic check_reset_and_recovery;
    begin
      write_count=0;memory[dst_base>>2]=32'hface_cafe;
      op_mode=8'h36;length=4;src0_base=32'h100;dst_base=32'h400;
      watchdog_limit=0;abort=0;inject_parity=0;inject_protection=0;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      if(!busy) $fatal(1,"SFU reset probe did not enter busy");
      // Reset at an active request while abort, parity, and protection are
      // asserted together.
      abort=1;inject_parity=1;inject_protection=1;
      resetn=0;#1;
      if(busy || done || error || error_code!=0)
        $fatal(1,"SFU reset did not clear command status");
      repeat(3) @(negedge clk);resetn=1;
      abort=0;inject_parity=0;inject_protection=0;
      repeat(2) @(negedge clk);
      if(write_count!=0 || memory[dst_base>>2]!==32'hface_cafe)
        $fatal(1,"SFU reset probe committed an output");
    end
  endtask

  task automatic run_late_parity_fault;
    integer reads_before,writes_before,writes_at_fault;
    begin
      op_mode=8'h36;length=16;src0_base=32'h100;dst_base=32'h400;
      beta_enable=0;pack_enable=0;watchdog_limit=0;abort=0;
      inject_parity=0;inject_protection=0;
      for(i=0;i<16;i=i+1) begin
        memory[(src0_base>>2)+i]=i*31-177;
        memory[(dst_base>>2)+i]=32'hface_cafe;
      end
      read_count=0;response_count=0;write_count=0;
      reads_before=response_count;writes_before=write_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while(response_count<reads_before+8 && timeout<10000) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(response_count<reads_before+8 || !spad_rsp_valid)
        $fatal(1,"SFU late parity did not reach response 8 count=%0d rsp=%b",
               response_count,spad_rsp_valid);
      inject_parity=1;
      @(negedge clk);inject_parity=0;
      timeout=0;
      while(!done && timeout<10000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || !error || error_code!=4'd5 || busy)
        $fatal(1,"SFU late parity done/error/code/busy=%b/%b/%0d/%b",
               done,error,error_code,busy);
      writes_at_fault=write_count;
      if(writes_at_fault-writes_before!=element_count || element_count<7 ||
         element_count>=length)
        $fatal(1,"SFU late parity prefix writes=%0d elements=%0d",writes_at_fault,element_count);
      repeat(4) @(negedge clk);
      if(write_count!=writes_at_fault)
        $fatal(1,"SFU output continued after late parity %0d->%0d",writes_at_fault,write_count);
      drain_sfu_response();
    end
  endtask

  // Choose a real opcode whose normal execution reaches each encoded SFU
  // state.  These probes observe state_r; they do not force or deposit state
  // values into the DUT.
  function automatic [7:0] probe_opcode(input integer target_state);
    begin
      if(target_state>=1 && target_state<=9) probe_opcode=8'h32;
      else if(target_state>=10 && target_state<=22) probe_opcode=8'h33;
      else if(target_state==25 || target_state==26) probe_opcode=8'h34;
      else if(target_state==30 || target_state==31) probe_opcode=8'h35;
      else if(target_state>=32 && target_state<=40) probe_opcode=8'h38;
      else probe_opcode=8'h36;
    end
  endfunction

  task automatic reset_for_fsm_probe;
    begin
      @(negedge clk);resetn=0;#1;
      abort=0;start=0;inject_parity=0;inject_protection=0;
      if(busy || done || error || error_code!=0)
        $fatal(1,"SFU FSM probe reset did not clear status");
      repeat(2) @(negedge clk);resetn=1;
      repeat(2) @(negedge clk);
    end
  endtask

  task automatic prepare_fsm_probe(input integer target_state);
    integer j;
    begin
      op_mode=probe_opcode(target_state);
      length=(target_state==28)?16'd1:16'd2;
      src0_base=32'h100;
      src1_base=((op_mode==8'h34) ||
                 (op_mode==8'h33 && target_state>=20 && target_state<=21)) ?
                32'h200:32'd0;
      beta_base=32'h300;beta_enable=(op_mode==8'h38);pack_enable=0;
      dst_base=32'h400;scale_shift=0;epsilon=1;watchdog_limit=0;
      for(j=0;j<32;j=j+1) begin
        memory[(src0_base>>2)+j]=j+1;
        memory[(32'h200>>2)+j]=32'd32768;
        memory[(beta_base>>2)+j]=j+2;
      end
    end
  endtask

  task automatic reset_from_fsm_state(input integer target_state);
    integer spins;
    begin
      reset_for_fsm_probe();
      prepare_fsm_probe(target_state);
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      spins=0;
      while(dut.state_r!==target_state[5:0] && spins<20000) begin
        @(negedge clk);spins=spins+1;
      end
      if(dut.state_r!==target_state[5:0])
        $fatal(1,"SFU reset-coverage probe could not reach state %0d op=%02x current=%0d",
               target_state,op_mode,dut.state_r);
      // Asynchronous reset is asserted while the observed state is active.
      // The transition therefore exercises the RTL reset edge from this
      // actual state, including request, response, arithmetic, and writeback.
      resetn=0;#1;
      if(dut.state_r!==6'd0 || busy || done || error)
        $fatal(1,"SFU reset-coverage probe failed state=%0d",target_state);
      repeat(2) @(negedge clk);resetn=1;
      repeat(2) @(negedge clk);
    end
  endtask

  task automatic abort_from_fsm_state(input integer target_state);
    integer spins;
    begin
      reset_for_fsm_probe();
      prepare_fsm_probe(target_state);
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      spins=0;
      while(dut.state_r!==target_state[5:0] && spins<20000) begin
        @(negedge clk);spins=spins+1;
      end
      if(dut.state_r!==target_state[5:0])
        $fatal(1,"SFU abort-coverage probe could not reach state %0d op=%02x current=%0d",
               target_state,op_mode,dut.state_r);
      if(!busy)
        $fatal(1,"SFU abort-coverage probe reached non-busy state %0d",target_state);
      abort=1;
      @(negedge clk);abort=0;
      timeout=0;
      while(!done && timeout<1000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || !error || error_code!==4'd3 || busy)
        $fatal(1,"SFU abort-coverage state=%0d did not drain code=%0d busy=%b",
               target_state,error_code,busy);
      reset_for_fsm_probe();
    end
  endtask

  task automatic converge_fsm_transitions;
    integer state_id;
    begin
      // The production FSM contains 41 states.  Exercise reset-to-IDLE and
      // abort-to-ERROR from each reachable active state using valid operation
      // paths.  IDLE is the launch point; ERROR already returns to IDLE in the
      // ordinary fault scenarios above.
      for(state_id=1;state_id<=28;state_id=state_id+1)
        reset_from_fsm_state(state_id);
      for(state_id=30;state_id<=40;state_id=state_id+1)
        reset_from_fsm_state(state_id);

      for(state_id=1;state_id<=28;state_id=state_id+1)
        abort_from_fsm_state(state_id);
      for(state_id=30;state_id<=40;state_id=state_id+1)
        abort_from_fsm_state(state_id);
    end
  endtask

  task automatic run_rms_without_gamma;
    begin
      op_mode=8'h33;length=1;src0_base=32'h100;src1_base=0;
      beta_enable=0;pack_enable=0;dst_base=32'h400;watchdog_limit=0;
      memory[src0_base>>2]=32'd1;memory[dst_base>>2]=32'hface_cafe;
      write_count=0;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while(!done && timeout<10000) begin @(negedge clk);timeout=timeout+1;end
      if(!done || error || busy || element_count!=1 || write_count!=1 ||
         memory[dst_base>>2]===32'hface_cafe)
        $fatal(1,"SFU RMSNorm gamma-bypass path did not complete cleanly");
      expected_total_writes=expected_total_writes+1;
    end
  endtask

  initial begin
    if($value$plusargs("SEED=%d",seed)) begin end
    initial_seed=seed;
    if(!$value$plusargs("VECTORS=%s",vector_path))
      $fatal(1,"missing +VECTORS=<path>");
    fd=$fopen(vector_path,"r");
    if(fd==0) $fatal(1,"cannot open vector file %0s",vector_path);
    for(i=0;i<1024;i=i+1) memory[i]=0;
    rc=$fscanf(fd,"%d\n",case_count);
    if(rc!=1 || case_count!=64) $fatal(1,"expected 64 SFU vectors, got %0d",case_count);
    repeat(4) @(negedge clk);resetn=1;

    // Exercise command validation and lifecycle/error exits that numeric
    // vectors do not hit. The first valid vector after reset is the recovery
    // check and also verifies the ordinary data path still runs.
    converge_fsm_transitions();
    op_mode=8'h36;length=0;src0_base=32'h100;dst_base=32'h400;
    expect_sfu_error(4'd1,0);
    op_mode=8'hff;length=1;expect_sfu_error(4'd2,1);
    op_mode=8'h36;length=1;src0_base=32'h101;expect_sfu_error(4'd1,2);
    src0_base=32'h100;length=4;
    for(i=0;i<4;i=i+1) memory[(src0_base>>2)+i]=i*17-23;
    inject_protection=1;expect_sfu_error(4'd6,4);
    inject_parity=1;expect_sfu_error(4'd5,5);
    launch_abort_error();
    watchdog_limit=1;expect_sfu_error(4'd4,6);
    // Abort dominates simultaneous parity, protection, and watchdog inputs.
    watchdog_limit=1;inject_parity=1;inject_protection=1;abort=1;
    expect_sfu_error(4'd3,7);
    run_late_parity_fault();
    check_reset_and_recovery();
    run_rms_without_gamma();
    op_mode=8'h36;length=1;src0_base=32'h100;dst_base=32'h400;

    case_id=0;
    while(case_id<case_count) run_vector();
    $fclose(fd);
    if(read_count!=response_count || response_pending)
      $fatal(1,"SPAD response accounting reads=%0d responses=%0d pending=%b",
             read_count,response_count,response_pending);
    if(total_write_count!=expected_total_writes)
      $fatal(1,"SPAD write accounting actual=%0d expected=%0d",
             total_write_count,expected_total_writes);
    if(ready_stall_count==0 || max_response_delay==0)
      $fatal(1,"SFU random memory profile missed ready or response stalls");
    $display("SFU_RANDOM_LATENCY_PASS cases=%0d error_cases=8 late_faults=1 fault_abort_combo=1 reset_fault_combo=1 reset_recovery=1 fsm_reset_states=39 fsm_abort_states=39 rms_gamma_bypass=1 seed=%0d reads=%0d responses=%0d writes=%0d max_rsp_delay=%0d ready_stalls=%0d",
             case_count,initial_seed,read_count,response_count,total_write_count,max_response_delay,ready_stall_count);
    $finish;
  end
endmodule
