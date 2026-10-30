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
      cnm_request_count<=0;
      wait_a_state_cycles<=0;prefetch_a_state_cycles<=0;
    end else begin
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
      // Keep the parity indication active umºÛ[h‘éì¶»§q«^w../../block/dma/agent \
		+incdir+../fixtures \
		-Mdir=$(AI_DIGITS_RUN)/csrc -top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_DIGITS_RUN)/simv -l $(AI_DIGITS_RUN)/compile.log
	$(AI_DIGITS_RUN)/simv +ntb_random_seed=20261029 +AI_RANDOM_CASES=0 \
		+AI_SEED=20261029 +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) \
		+AI_DIGITS_INFERENCE \
		+AI_DIGITS_MEMORY=$(AI_DIGITS_RUN)/workload/digits_spad_writes.memh \
		+AI_DIGITS_EXPECTED=$(AI_DIGITS_RUN)/workload/digits_expected.memh \
		+AI_DIGITS_HIDDEN=$(AI_DIGITS_RUN)/workload/digits_hidden_expected.memh \
		+AI_DIGITS_RTL_CSV=$(AI_DIGITS_RUN)/rtl_logits.csv \
		-l $(AI_DIGITS_RUN)/run.log
	$(AI_DIGITS_PYTHON) ../../../../benchmark/digits/digits_quantized_golden.py \
		--model "$(AI_DIGITS_RUN)/model/digits_mlp_int8.npz" \
		--rtl-logits "$(AI_DIGITS_RUN)/rtl_logits.csv" \
		--out "$(AI_DIGITS_RUN)/golden_comparison.json"

# Paired TinyNPU conv1x_mini graph through production top, Matrix/SFU/int8
# engines, ABI-v7 command/completion queues, and an independent per-layer Golden.
AI_TINYNPU_CNN_RUN ?= /tmp/nmaforge_tinynpu_cnn_rtl_$(shell date +%Y%m%d_%H%M%S)
AI_TINYNPU_CNN_PYTHON ?= python3
.PHONY: ai_tinynpu_cnn_match
ai_tinynpu_cnn_match:
	test ! -e "$(AI_TINYNPU_CNN_RUN)"
	mkdir -p "$(AI_TINYNPU_CNN_RUN)"
	$(AI_TINYNPU_CNN_PYTHON) ../../../../benchmark/tinynpu/generate_nma_cnn_workload.py \
		--model "$(AI_TINYNPU_CNN_MODEL)" \
		--tiny-golden "$(AI_TINYNPU_CNN_GOLDEN)" \
		--out-dir "$(AI_TINYNPU_CNN_RUN)/workload"
	vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps +define+VCS \
		+incdir+../../../block/control/agent \
		+incdir+../../../block/dma/agent \
		+incdir+../fixtures \
		-Mdir=$(AI_TINYNPU_CNN_RUN)/csrc -top tb_ai_accel_smoke -f ai_accel.f \
		../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
		-o $(AI_TINYNPU_CNN_RUN)/simv -l $(AI_TINYNPU_CNN_RUN)/compile.log
	$(AI_TINYNPU_CNN_RUN)/simv +ntb_random_seed=20261029 +AI_RANDOM_CASES=0 \
		+AI_SEED=20261029 +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_TINYNPU_CNN_MATCH \
		+AI_TINYNPU_CNN_MEMORY=$(AI_TINYNPU_CNN_RUN)/workload/nma_cnn_spad.memh \
		+AI_TINYNPU_CNN_EXPECTED=$(AI_TINYNPU_CNN_RUN)/workload/nma_cnn_expected.memh \
		-l $(AI_TINYNPU_CNN_RUN)/run.log
	grep -q '^NMA_CNN_INFERENCE_PASS' $(AI_TINYNPU_CNN_RUN)/run.log

# Optional V3 subsystem stress: inject seeded read/write SLVERR at a random
# beat of multi-beat DMA bursts and check completion plus AXI drain-to-idle.
ai_dma_error_stress: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) \
		+ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +AI_DMA_ERROR_STRESS \
		-l ai_dma_error_stress.log

# Activity-aware smoke: uses exactly the same top-level regression as
# ai_smoke, but writes a VCD only when explicitly requested.  Convert it on
# the Synopsys Linux environment with `make ai_smoke_saif` before DC power.
ACLK_PERIOD_NS ?= 10.0
ACLK_PERIOD_TAG := $(subst .,_,$(ACLK_PERIOD_NS))ns
VCD_FILE ?= ai_accel_smoke_$(ACLK_PERIOD_TAG).vcd
SAIF_FILE ?= ai_accel_smoke_$(ACLK_PERIOD_TAG).saif
SAIF_DC_FILE ?= $(basename $(SAIF_FILE))_dc.saif
SAIF_INSTANCE ?= tb_ai_accel_smoke/dut

ai_smoke_vcd: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=$(AI_RANDOM_CASES) +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) +VCD_FILE=$(VCD_FILE) -l ai_accel_smoke_vcd.log

ai_smoke_saif: ai_smoke_vcd
	vcd2saif -input $(VCD_FILE) -output $(SAIF_FILE) -instance $(SAIF_INSTANCE)
	$(PYTHON) ../../../../syn/normalize_saif_root.py --input $(SAIF_FILE) --output $(SAIF_DC_FILE) --testbench tb_ai_accel_smoke --dut dut --top ai_accel_top

ai_transformer: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_transformer.log

# Short Linux/VCS gate: all directed AXI/DMA/A4 tests with random compute
# cases disabled. Use this after an RTL edit before the seeded regression.
ai_quick: ai_comp
	./simv +ntb_random_seed=${SEED} +AI_RANDOM_CASES=0 +AI_SEED=$(AI_SEED) +ACLK_PERIOD_NS=$(ACLK_PERIOD_NS) -l ai_quick.log

# Integer reference model is intentionally a separate gate: it validates the
# documented A3/A4 fixed-point contract without claiming RTL coverage.
ai_a4_ref:
	$(PYTHON) ../../../block/compute/matrix/ref/ai_a3_reference.py --cases $(AI_REF_CASES) --seed $(AI_REF_SEED)

ai_precheck: ai_a4_ref ai_quick

# Focused Linux/VCS gates for the unified DMA and scratchpad line/RR arbiter.
ai_dma_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_axi128_dma ../../../../rtl/dma/ai_axi128_dma.v \
		../../../block/dma/tb/tb_ai_axi128_dma.sv -o simv_dma -l ai_dma_comp.log

ai_dma_run: ai_dma_comp
	./simv_dma -l ai_dma_run.log

ai_spad_arb_comp:
	vcs -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-top tb_ai_spad_arbiter_rr ../../../../rtl/memory/ai_spad_arbiter.v \
		../../../block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv -o simv_spad_arb \
		-l ai_spad_arb_comp.log

ai_spad_arb_run: ai_spad_arb_comp
	./simv_spad_arb -l ai_spad_arb_run.log
	@grep -q '3-client sustained SPAD round-robin PASS grants=10/10/10 max_wait=2' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter 3-client fairness marker missing"; exit 1; }
	@grep -q 'Seeded request-mode SPAD RR PASS' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter seeded request-mode fairness marker missing"; exit 1; }
	@grep -q 'CNM/DMA SPAD contention PASS cnm_grants=6 dma_line_grants=6' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter CNM/DMA contention marker missing"; exit 1; }
	@grep -q 'Scratchpad response parity alignment PASS' ai_spad_arb_run.log || \
		{ echo "SPAD arbiter response/parity marker missing"; exit 1; }
	./simv_spad_arb +SPAD_RR_MODE_CYCLES=10000 -l ai_spad_arb_10k_run.log
	@grep -q 'Seeded request-mode SPAD RR PASS cycles=10000' ai_spad_arb_10k_run.log || \
		{ echo "SPAD arbiter 10000-cycle seeded request-mode marker missing"; exit 1; }

# Standalone arbiter code-coverage capture.  Keep all generated artifacts in
# an isolated run directory so this gate does not overwrite the functional
# smoke executable or its logs.
SPAD_ARB_COV_RUN ?= /tmp/nmaforge_spad_arbiter_cov_$(shell date +%Y%m%d_%H%M%S)
SPAD_ARB_COV_METRICS := line+cond+tgl+branch+assert

.PHONY: ai_spad_arb_cov
ai_spad_arb_cov:
	test ! -e "$(SPAD_ARB_COV_RUN)"
	mkdir -p "$(SPAD_ARB_COV_RUN)"
	cd "$(SPAD_ARB_COV_RUN)" && $(VCS) -full64 -sverilog -timescale=1ns/1ns +define+VCS \
		-cm $(SPAD_ARB_COV_METRICS) -cm_dir coverage.vdb \
		-top tb_ai_spad_arbiter_rr $(CURDIR)/../../../../rtl/memory/ai_spad_arbiter.v \
		$(CURDIR)/../../../block/spad_arbiter/tb/tb_ai_spad_arbiter_rr.sv \
		-o simv -l compile.log
	cd "$(SPAD_ARB_COV_RUN)" && ./simv +SPAD_RR_MODE_CYCLES=10000 \
		-cm $(SPAD_ARB_COV_METRICS) -cm_dir coverage.vdb -l run.log
	grep -q '3-client sustained SPAD round-robin PASS grants=10/10/10 max_wait=2' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'Seeded request-mode SPAD RR PASS cycles=10000' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'CNM/DMA SPAD contention PASS cnm_grants=6 dma_line_grants=6' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'Scratchpad response parity alignment PASS' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'SPAD arbiter cursor fallback request forms PASS cases=12' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'SPAD arbiter descriptor/completion priority and response PASS' "$(SPAD_ARB_COV_RUN)/run.log"
	grep -q 'SPAD arbiter protection-error response alignment PASS' "$(SPAD_ARB_COV_RUN)/run.log"
	$(URG) -full64 -dir "$(SPAD_ARB_COV_RUN)/coverage.vdb" -format text \
		-report "$(SPAD_ARB_COV_RUN)/urg" -log "$(SPAD_ARB_COV_RUN)/urg.log"
	! grep -Eq 'UCAPI-DNYL|Design not loaded' "$(SPAD_ARB_COV_RUN)/urg.log"
	test -s "$(SPAD_ARB_COV_RUN)/urg/modinfo.txt"
	grep -Fq 'Failure               0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Incomplete            0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Without Attempts      0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Uncovered         0' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'Matches           2' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'ap_idle_decode_uses_default_client' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	grep -Fq 'ap_banked_response_metadata_is_valid' "$(SPAD_ARB_COV_RUN)/urg/asserts.txt"
	echo "SPAD_ARBITER_COVERAGE_PASS report=$(SPAD_ARB_COV_RUN)/urg"

ai_upgrade_vcs: ai_dma_run ai_spad_arb_run ai_quick

# Focused VCS tests.  Each target creates a separate executable, KDB and log,
# so a directed failure can be inspected in Verdi without rebuilding ai_smoke.
VCS_FOCUSED = vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ns +define+VCS

ai_a6_dma_comp:
	$(VCS_FOCUSED) -top tb_ai_axi128_dma ../../../../rtl/dma/ai_axi128_dma.v \
		../../../../rtl/dma/ai_dma_burst_planner.v \
		../../../../rtl/dma/ai_dma_read_slot_tracker.v \
		../../../../rtl/dma/ai_dma_write_response_tracker.v \
		../../../../rtl/dma/ai_dma_spad_transfer_adapter.v \
		../../../block/dma/tb/tb_ai_axi128_dma.sv -o simv_a6_dma -l ai_a6_dma_comp.log

ai_a6_dma_run: ai_a6_dma_comp
	./simv_a6_dma -l ai_a6_dma_run.log

ai_a6_datapaths_comp:
	$(VCS_FOCUSED) -top tb_ai_a6_datapaths \
		../../../../rtl/compute/cnn/ai_conv3x3_linebuffer_core.v \
		../../../../rtl/compute/kv/ai_kv_cache_engine.v \
		../../../block/compute/cnn_kv/tb/tb_ai_a6_datapaths.sv -o simv_a6_datapaths -l ai_a6_datapaths_comp.log

ai_a6_datapaths_run: ai_a6_datapaths_comp
	./simv_a6_datapaths -l ai_a6_datapaths_run.log

ai_a7_vcs: ai_a6_dma_run ai_a6_datapaths_run ai_spad_arb_run

# A2.2 unit gate for the four independent bank-local controllers.
# This focused executable has occasionally been removed while its VCS .daidir
# cache remains (for example after a WSL/Windows file sync).  In that state VCS
# says the design is unchanged but does not recreate simv_cnm_a22.  Clear only
# this target's generated cache before compile; it does not touch ai_smoke.
ai_cnm_a22_comp:
	rm -rf simv_cnm_a22 simv_cnm_a22.daidir
	$(VCS_FOCUSED) -top tb_ai_banked_cnm_a22 \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_banked_cnm_a22.sv -o simv_cnm_a22 -l ai_cnm_a22_comp.log

ai_cnm_a22_run: ai_cnm_a22_comp
	./simv_cnm_a22 -l ai_cnm_a22_run.log

ai_cnm_a22: ai_cnm_a22_run

# Comparable VCS microbenchmarks: each A2/A3 case performs 64*L INT8 MACs.
ai_cnm_a2_gemv_bench_comp:
	rm -rf simv_cnm_a2_gemv_bench simv_cnm_a2_gemv_bench.daidir
	$(VCS_FOCUSED) -top tb_ai_cnm_a2_gemv_bench \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_cnm_a2_gemv_bench.sv -o simv_cnm_a2_gemv_bench -l ai_cnm_a2_gemv_bench_comp.log

ai_cnm_a2_gemv_bench_run: ai_cnm_a2_gemv_bench_comp
	./simv_cnm_a2_gemv_bench -l ai_cnm_a2_gemv_bench_run.log

ai_cnm_a2_gemv_bench: ai_cnm_a2_gemv_bench_run

# Seeded CNM oracle regression. Random signed bytes are generated from the
# address and seed, then independently reduced by the testbench reference.
CNM_RANDOM_SEEDS ?= 20261021 20261022 20261023
ifndef CNM_RANDOM_OUT_DIR
CNM_RANDOM_OUT_DIR := /tmp/nmaforge_cnm_random_$(shell date +%Y%m%d_%H%M%S)
endif
ai_cnm_random_compile:
	mkdir -p $(CNM_RANDOM_OUT_DIR)
	$(VCS_FOCUSED) -Mdir=$(CNM_RANDOM_OUT_DIR)/csrc -top tb_ai_banked_cnm_random \
		-cm line+cond+fsm+branch \
		-cm_hier $(CURDIR)/../../../block/compute/cnm/tb/cnm_random.cm_hier \
		-cm_dir $(CNM_RANDOM_OUT_DIR)/coverage.vdb \
		../../../../rtl/compute/cnm/ai_bank_pe.v \
		../../../../rtl/compute/cnm/ai_bank_local_controller.v \
		../../../../rtl/compute/cnm/ai_banked_cnm_core.v \
		../../../block/compute/cnm/tb/tb_ai_banked_cnm_random.sv \
		-o $(CNM_RANDOM_OUT_DIR)/simv -l $(CNM_RANDOM_OUT_DIR)/compile.log

.PHONY: ai_cnm_random_compile ai_cnm_random_regress
ai_cnm_random_regress: ai_cnm_random_compile
	@set -e; for seed in $(CNM_RANDOM_SEEDS); do \
		$(CNM_RANDOM_OUT_DIR)/simv +SEED=$$seed -cm line+cond+fsm+branch \
			-cm_dir $(CNM_RANDOM_OUT_DIR)/coverage.vdb -cm_name cnm_seed_$$seed \
			-l $(CNM_RANDOM_OUT_DIR)/run_seed_$$seed.log; \
		grep -q "^CNM_RANDOM_PASS golden_cases=17 faults=8 phase_abort=6 phase_reset=6 late_faults=1 reset_fault_combo=1 reset_recovery=1 wait_a=1 prefetch_backpressure=1 fast_response=1 seed=$$seed$$" $(CNM_RANDOM_OUT_DIR)/run_seed_$$seed.log; \
	done

ai_tensor_a3_gemm_bench_comp:
	rm -rf simv_tensor_a3_gemm_bench simv_tensor_a3_gemm_bench.daidir
	$(VCS_FOCUSED) -top tb_ai_tensor_a3_gemm_bench \
		../../../../rtl/compute/matrix/ai_tensor_matrix_datapath.v \
		../../../../rtl/compute/matrix/ai_tensor_matrix_array.sv \
		../../../../rtl/compute/matrix/ai_tensor_matrix_core.v \
		../../../block/compute/matrix/tb/tb_ai_tensor_a3_gemm_bench.sv -o simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_comp.log

ai_tensor_a3_gemm_bench_run: ai_tensor_a3_gemm_bench_comp
	./simv_tensor_a3_gemm_bench -l ai_tensor_a3_gemm_bench_run.log

ai_tensor_a3_gemm_bench: ai_tensor_a3_gemm_bench_run

ai_cnm_compare: ai_cnm_a2_gemv_bench ai_tensor_a3_gemm_bench

# CNM signoff gate: microarchitecture throughput, SPAD arbitration under
# CNM/DMA contention, then the full AXI/DMA/compute smoke regression.
ai_cnm_signoff: ai_cnm_compare ai_spad_arb_run ai_smoke

ai_async_fifo_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo.sv -o simv_async_fifo -l ai_async_fifo_comp.log

ai_async_fifo_run: ai_async_fifo_comp
	./simv_async_fifo -l ai_async_fifo_run.log

ai_async_fifo: ai_async_fifo_run

ai_async_fifo_random_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo_random \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo_random.sv -o simv_async_fifo_random -l ai_async_fifo_random_comp.log

ai_async_fifo_random_run: ai_async_fifo_random_comp
	./simv_async_fifo_random +SEED=$(AI_SEED) -l ai_async_fifo_random_run.log

ai_async_fifo_random: ai_async_fifo_random_run

ai_async_fifo_reset_comp:
	$(VCS_FOCUSED) -top tb_ai_async_fifo_reset \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../block/cdc/tb/tb_ai_async_fifo_reset.sv -o simv_async_fifo_reset -l ai_async_fifo_reset_comp.log

ai_async_fifo_reset_run: ai_async_fifo_reset_comp
	./simv_async_fifo_reset -l ai_async_fifo_reset_run.log

ai_async_fifo_reset: ai_async_fifo_reset_run

ai_ctrl_compute_cdc_comp:
	$(VCS_FOCUSED) -top tb_ai_ctrl_compute_cdc \
		../../../../rtl/control/cdc/ai_async_fifo.v \
		../../../../rtl/control/cdc/ai_ctrl_compute_cdc.v \
		../../../block/cdc/tb/tb_ai_ctrl_compute_cdc.sv -o simv_ctrl_compute_cdc -l ai_ctrl_compute_cdc_comp.log

ai_ctrl_compute_cdc_run: ai_ctrl_compute_cdc_comp
	./simv_ctrl_compute_cdc -l ai_ctrl_compute_cdc_run.log

ai_ctrl_compute_cdc: ai_ctrl_compute_cdc_run

clean:
	rm -rf csrc simv* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key
