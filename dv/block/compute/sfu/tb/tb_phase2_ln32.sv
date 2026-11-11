`timescale 1ns/1ps

module tb_phase2_ln32;
  reg clk=0,resetn=0,start=0,abort=0;
  reg [7:0] op_mode=0;
  reg [31:0] src0_base=32'h100,src1_base=0,beta_base=32'h300;
  reg beta_enable=0,pack_enable=0,pack_tile_a=0;
  reg [31:0] dst_base=32'h400;
  reg [15:0] length=0,m_size=0,n_size=0;
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
  integer done_count=0;
  always @(posedge clk)if(resetn && done)done_count=done_count+1;
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
    .beta_enable(beta_enable),.pack_enable(pack_enable),
    .pack_tile_a(pack_tile_a),.dst_base(dst_base),
    .length(length),.m_size(m_size),.n_size(n_size),
    .scale_shift(scale_shift),.epsilon(epsilon),
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
      if(spad_valid && spad_write && spad_ready && !inject_protection) begin
        memory[spad_addr[11:2]]<=spad_wdata;
        write_count<=write_count+1;
        total_write_count<=total_write_count+1;
      end
    end
  end

  reg stalled_r=0;reg [64:0] stalled_payload;
  always @(posedge clk)begin
    if(!resetn || abort || dut.watchdog_expired || done)stalled_r<=0;
    else begin
      if(stalled_r && (!spad_valid || {spad_write,spad_addr}!==stalled_payload[64:32] ||
          (spad_write && spad_wdata!==stalled_payload[31:0])))
        $fatal(1,"LN32 stalled payload changed");
      stalled_r<=spad_valid && !spad_ready;
      stalled_payload<={spad_write,spad_addr,spad_wdata};
    end
  end
  integer mean_fd,var_fd,count,j,probe_error,phase,kind,before_reads,before_responses;
  integer done_before,read_before,write_before,full_cases=0,fault_cases=0;
  reg [63:0] probe_value,probe_expected64;
  reg [31:0] probe_expected32;
  string folder;
  task automatic fresh;
    begin
      @(negedge clk);resetn=0;start=0;abort=0;inject_parity=0;inject_protection=0;
      repeat(3)@(negedge clk);resetn=1;
      op_mode=8'h38;length=32;src0_base='h100;src1_base='h200;
      beta_base='h300;beta_enable=1;dst_base='h400;epsilon=1;
      watchdog_limit=0;pack_enable=0;pack_tile_a=0;m_size=0;n_size=0;
      for(j=0;j<32;j=j+1)begin
        memory['h40+j]=j-17;memory['h80+j]=32768;
        memory['hc0+j]=j;memory['h100+j]='hbad00000+j;
      end
      repeat(2)@(negedge clk);
    end
  endtask
  task automatic launch;
    begin @(negedge clk);start=1;@(negedge clk);start=0;end
  endtask
  task automatic wait_state(input integer st);
    begin
      timeout=0;while(dut.state_r!==st && timeout<20000)begin @(negedge clk);timeout=timeout+1;end
      if(dut.state_r!==st)$fatal(1,"LN32 state unreachable target=%0d got=%0d",st,dut.state_r);
    end
  endtask
  task automatic finish_check(input integer code);
    begin
      timeout=0;while(!done && timeout<100000)begin @(negedge clk);timeout=timeout+1;end
      if(!done || busy || error!==(code!=0) || error_code!==code)
        $fatal(1,"LN32 completion expected=%0d got=%0d err=%b busy=%b",code,error_code,error,busy);
      write_before=write_count;
      repeat(20)@(negedge clk);
      if(write_count!=write_before || done_count!=done_before+1 || response_pending || read_count!=response_count)
        $fatal(1,"LN32 terminal ledger/pulse writes=%0d/%0d done=%0d/%0d reads=%0d/%0d",write_count,write_before,done_count,done_before+1,read_count,response_count);
    end
  endtask
  task automatic vector_case;
    begin
      fresh();rc=$fscanf(fd,"%d %d\n",case_id,epsilon_i);if(rc!=2)$fatal(1,"header");epsilon=epsilon_i;
      for(i=0;i<32;i=i+1)begin
        rc=$fscanf(fd,"%h %h %h %h\n",memory['h40+i],memory['h80+i],memory['hc0+i],expected[i]);if(rc!=4)$fatal(1,"data");
      end
      done_before=done_count;launch();finish_check(0);
      if(write_count!=32 || read_count!=160 || element_count!=32)$fatal(1,"LN32 mandatory access count r=%0d w=%0d",read_count,write_count);
      for(i=0;i<32;i=i+1)if(memory['h100+i]!==expected[i])$fatal(1,"LN32 Golden case=%0d word=%0d got=%h expected=%h",case_id,i,memory['h100+i],expected[i]);
      $display("PHASE2_LN32_VECTOR_PASS id=%0d cycles=%0d reads=%0d writes=%0d",case_id,cycle_count,read_count,write_count);full_cases=full_cases+1;
    end
  endtask
  initial begin
    if(!$value$plusargs("PHASE2_DIR=%s",folder))$fatal(1,"PHASE2_DIR missing");
    mean_fd=$fopen({folder,"/mean.txt"},"r");rc=$fscanf(mean_fd,"%d\n",count);
    for(i=0;i<count;i=i+1)begin
      fresh();rc=$fscanf(mean_fd,"%h %h %d\n",probe_value,probe_expected32,probe_error);if(rc!=3)$fatal(1,"mean input");
      launch(); // Deposit accumulator at its arithmetic boundary, not a reachable-input claim.
      dut.state_r=34;dut.sum_x_r=probe_value;
      @(negedge clk);timeout=0;
      while(dut.state_r==35 && timeout<1000)begin @(negedge clk);timeout=timeout+1;end
      if(probe_error)begin
        if(dut.state_r!=29 || error_code!=8)$fatal(1,"mean error v=%h state=%0d code=%0d",probe_value,dut.state_r,error_code);
      end else if(dut.state_r!=36 || dut.mean_r!==probe_expected32)$fatal(1,"mean mismatch v=%h got=%h expected=%h state=%0d",probe_value,dut.mean_r,probe_expected32,dut.state_r);
    end
    $display("PHASE2_LN32_MEAN_PASS cases=%0d",count);$fclose(mean_fd);
    var_fd=$fopen({folder,"/variance.txt"},"r");rc=$fscanf(var_fd,"%d\n",count);
    for(i=0;i<count;i=i+1)begin
      fresh();rc=$fscanf(var_fd,"%h %h\n",probe_value,probe_expected64);if(rc!=2)$fatal(1,"variance input");
      launch();dut.state_r=12;dut.sum_sq_r=probe_value;
      @(negedge clk);timeout=0;
      while(dut.state_r==13 && timeout<1000)begin @(negedge clk);timeout=timeout+1;end
      if(dut.state_r!=14 || dut.mean_sq_r!==probe_expected64)$fatal(1,"variance mismatch v=%h got=%h expected=%h",probe_value,dut.mean_sq_r,probe_expected64);
    end
    $display("PHASE2_LN32_VARIANCE_PASS cases=%0d",count);$fclose(var_fd);
    fd=$fopen({folder,"/vectors.txt"},"r");rc=$fscanf(fd,"%d\n",case_count);
    for(kind=0;kind<case_count;kind=kind+1)vector_case();$fclose(fd);
    // Every architecturally required pass, including fresh Gamma/Beta and output.
    for(kind=0;kind<2;kind=kind+1)for(phase=0;phase<6;phase=phase+1)begin
      if(kind==1 && phase==5)continue;
      fresh();done_before=done_count;launch();
      case(phase)0:wait_state(kind==0?32:33);1:wait_state(kind==0?36:37);
        2:wait_state(kind==0?18:19);3:wait_state(kind==0?20:21);
        4:wait_state(kind==0?39:40);5:wait_state(27);endcase
      if(kind==0)inject_protection=1;else inject_parity=1;
      finish_check(kind==0?6:5);
      for(i=0;i<32;i=i+1)if(memory['h100+i]!==('hbad00000+i))$fatal(1,"fault changed destination");
      $display("PHASE2_LN32_FAULT_PASS kind=%0d phase=%0d reads=%0d writes=%0d",kind,phase,read_count,write_count);fault_cases=fault_cases+1;
    end
    // Changed arithmetic boundaries and each memory phase: reset/abort/WDG.
    for(kind=0;kind<3;kind=kind+1)for(phase=0;phase<9;phase=phase+1)begin
      fresh();done_before=done_count;launch();
      case(phase)0:wait_state(34);1:wait_state(12);2:wait_state(32);3:wait_state(33);
       4:wait_state(36);5:wait_state(37);6:wait_state(20);7:wait_state(40);8:wait_state(27);endcase
      if(kind==0)begin abort=1;@(negedge clk);abort=0;finish_check(3);end
      else if(kind==1)begin
        resetn=0;#1;if(busy || done || error || dut.state_r!=0)$fatal(1,"reset did not clear");
        repeat(3)@(negedge clk);resetn=1;repeat(20)@(negedge clk);
        if(busy || done || write_count || done_count!=done_before || response_pending)$fatal(1,"reset stale epoch");
      end else begin force dut.watchdog_limit_r=32'd1;@(negedge clk);release dut.watchdog_limit_r;finish_check(4);end
    end
    // Abort after an accepted output preserves its Golden prefix, blocks suffix.
    fresh();done_before=done_count;launch();timeout=0;
    while(write_count<1 && timeout<10000)begin @(negedge clk);timeout=timeout+1;end
    if(write_count!=1)$fatal(1,"prefix not reached");if(memory['h100]!==32'hfffffffe)$fatal(1,"accepted prefix Golden expected -2 got=%h",memory['h100]);
    probe_expected32=memory['h100];abort=1;
    @(negedge clk);abort=0;finish_check(3);
    if(write_count!=1 || memory['h100]!==probe_expected32)$fatal(1,"accepted prefix changed");
    for(i=1;i<32;i=i+1)if(memory['h100+i]!==('hbad00000+i))$fatal(1,"suffix changed");
    // LN32 optional Gamma/Beta modes, independent constant-vector oracle.
    for(kind=0;kind<3;kind=kind+1)begin
      fresh();done_before=done_count;src1_base=(kind==2)?'h200:0;
      beta_enable=(kind==1);
      for(i=0;i<32;i=i+1)memory['h40+i]=-7;
      launch();finish_check(0);
      if(read_count!=((kind==0)?96:128) || write_count!=32)$fatal(1,"optional LN32 access count");
      for(i=0;i<32;i=i+1)if(memory['h100+i]!==((kind==1)?i:0))$fatal(1,"optional gamma/beta Golden");
    end
    // Clean same-vector recovery after all injected lifecycle events.
    fd=$fopen({folder,"/vectors.txt"},"r");rc=$fscanf(fd,"%d\n",count);vector_case();
    $display("PHASE2_LN32_DIRECTED_PASS vectors=%0d faults=%0d reset_abort_watchdog=27 accepted_prefix=1 optional_modes=3 stalled_payload=checked recovery=1",full_cases,fault_cases);$finish;
  end
endmodule
