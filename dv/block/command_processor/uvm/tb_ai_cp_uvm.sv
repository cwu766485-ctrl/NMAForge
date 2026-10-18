`timescale 1ns/1ps
module tb_ai_cp_uvm;
  import uvm_pkg::*;
  import ai_cp_uvm_pkg::*;
  typedef struct packed {
    logic [7:0] op;
    logic [15:0] task_id;
    logic [31:0] src0, src1, dst;
    logic [15:0] length, m, n, k;
    logic [4:0] shift;
    logic [1:0] activation;
    logic [31:0] bias_base;
    logic bias_enable;
    logic [7:0] flags;
    logic [31:0] aux0;
    logic [31:0] src0_stride, src1_stride, dst_stride;
    logic [15:0] batch_count, head_count, wait_mask, signal_mask, clear_mask;
    logic [7:0] version;
  } descriptor_t;
  bit clk=0;
  always #5 clk=~clk;
  ai_cp_if vif(clk);
  always @(posedge clk) begin
    if(!vif.resetn) begin
      if(vif.partial_reset_sweep_active)
        vif.partial_reset_done <= 1'b1;
      else if(!vif.partial_reset_sweep_active)
        vif.partial_reset_done <= 1'b0;
      vif.partial_reset_write_count <= 0;
    end else if((vif.test_case==CP_PARTIAL_RESET ||
                 (vif.test_case==CP_ABORT_RESET_PARTIAL &&
                  vif.partial_reset_sweep_active)) &&
                vif.cpl_spad_valid && vif.cpl_spad_ready) begin
      vif.partial_reset_write_count <= vif.partial_reset_write_count + 1'b1;
    end else if(!(vif.test_case==CP_PARTIAL_RESET ||
                  (vif.test_case==CP_ABORT_RESET_PARTIAL &&
                   vif.partial_reset_sweep_active))) begin
      vif.partial_reset_write_count <= 0;
      vif.partial_reset_done <= 1'b0;
    end
  end

  wire [31:0] cpl_base,cpl_index;
  wire writer_done,writer_busy;
  assign vif.completion_done=writer_done;
  assign vif.completion_busy=writer_busy;
  assign vif.cpl_writer_done=writer_done;
  assign vif.cpl_writer_busy=writer_busy;

  ai_command_processor u_cp(
    .clk(clk),.resetn(vif.resetn),.abort(vif.abort),.submit(vif.submit),.direct_start(vif.direct_start),.tile_start(vif.tile_start),
    .cmdq_base(vif.cmdq_base),.cmdq_size(vif.cmdq_size),.cmdq_tail(vif.cmdq_tail),.desc_external(vif.desc_external),
    .cmdq_head_load(vif.cmdq_head_load),.cmdq_head_seed(vif.cmdq_head_seed),
    .cplq_base(vif.cplq_base),.cplq_size(vif.cplq_size),.cplq_head(vif.cplq_head),.completion_protected(vif.completion_protected),
    .cplq_tail_load(vif.cplq_tail_load),.cplq_tail_seed(vif.cplq_tail_seed),
    .cfg_op(vif.cfg_op),.cfg_src0(vif.cfg_src0),.cfg_src1(vif.cfg_src1),.cfg_dst(vif.cfg_dst),.cfg_length(vif.cfg_length),.cfg_m(vif.cfg_m),.cfg_n(vif.cfg_n),.cfg_k(vif.cfg_k),
    .cfg_shift(vif.cfg_shift),.cfg_activation(vif.cfg_activation),.cfg_bias_base(vif.cfg_bias_base),.cfg_bias_enable(vif.cfg_bias_enable),
    .tile_count(vif.tile_count),.tile_ext_input_base(vif.tile_ext_input_base),.tile_ext_output_base(vif.tile_ext_output_base),
    .tile_ext_input_stride(vif.tile_ext_input_stride),.tile_ext_output_stride(vif.tile_ext_output_stride),
    .tile_buffer0_base(vif.tile_buffer0_base),.tile_buffer1_base(vif.tile_buffer1_base),.tile_output_offset(vif.tile_output_offset),
    .tile_input_words(vif.tile_input_words),.tile_output_words(vif.tile_output_words),
    .fetch_busy(vif.fetch_busy),.fetch_done(vif.fetch_done),.fetch_error(vif.fetch_error),
    .desc_op(vif.desc_op),.desc_task_id(vif.desc_task_id),.desc_src0(vif.desc_src0),.desc_src1(vif.desc_src1),.desc_dst(vif.desc_dst),
    .desc_length(vif.desc_length),.desc_m(vif.desc_m),.desc_n(vif.desc_n),.desc_k(vif.desc_k),.desc_shift(vif.desc_shift),.desc_activation(vif.desc_activation),
    .desc_bias_base(vif.desc_bias_base),.desc_bias_enable(vif.desc_bias_enable),.desc_flags(vif.desc_flags),.desc_aux0(vif.desc_aux0),
    .desc_src0_stride(vif.desc_src0_stride),.desc_src1_stride(vif.desc_src1_stride),.desc_dst_stride(vif.desc_dst_stride),
    .desc_batch_count(vif.desc_batch_count),.desc_head_count(vif.desc_head_count),.desc_wait_mask(vif.desc_wait_mask),
    .desc_signal_mask(vif.desc_signal_mask),.desc_clear_mask(vif.desc_clear_mask),.desc_version(vif.desc_version),
    .compute_busy(vif.compute_busy),.compute_done(vif.compute_done),.compute_error(vif.compute_error),.compute_error_code(vif.compute_error_code),
    .compute_result(vif.compute_result),.compute_cycles(vif.compute_cycles),.compute_elements(vif.compute_elements),
    .dma_busy(vif.dma_busy),.dma_done(vif.dma_done),.dma_error(vif.dma_error),.dma_error_code(vif.dma_error_code),
    .completion_busy(vif.completion_busy),.completion_done(vif.completion_done),
    .fetch_start(vif.fetch_start),.fetch_base(vif.fetch_base),.fetch_external(vif.fetch_external),
    .launch_valid(vif.launch_valid),.launch_op(vif.launch_op),.launch_task_id(vif.launch_task_id),.launch_src0(vif.launch_src0),.launch_src1(vif.launch_src1),.launch_dst(vif.launch_dst),
    .launch_length(vif.launch_length),.launch_m(vif.launch_m),.launch_n(vif.launch_n),.launch_k(vif.launch_k),.launch_shift(vif.launch_shift),.launch_activation(vif.launch_activation),
    .launch_bias_base(vif.launch_bias_base),.launch_bias_enable(vif.launch_bias_enable),.launch_flags(vif.launch_flags),.launch_aux0(vif.launch_aux0),
    .launch_src0_stride(vif.launch_src0_stride),.launch_src1_stride(vif.launch_src1_stride),.launch_dst_stride(vif.launch_dst_stride),
    .launch_batch_count(vif.launch_batch_count),.launch_head_count(vif.launch_head_count),
    .tile_dma_start(vif.tile_dma_start),.tile_dma_store(vif.tile_dma_store),.tile_dma_ext_addr(vif.tile_dma_ext_addr),
    .tile_dma_spad_addr(vif.tile_dma_spad_addr),.tile_dma_length_words(vif.tile_dma_length_words),.tile_active(vif.tile_active),
    .tile_perf_total(vif.tile_perf_total),.tile_perf_dma(vif.tile_perf_dma),.tile_perf_compute(vif.tile_perf_compute),
    .tile_perf_overlap(vif.tile_perf_overlap),.tile_perf_stall(vif.tile_perf_stall),.tile_completed(vif.tile_completed),
    .completion_start(vif.completion_start),.completion_base(cpl_base),.completion_index(cpl_index),
    .completion_task_id(vif.completion_task_id),.completion_status(vif.completion_status),.completion_error(vif.completion_error),
    .completion_result(vif.completion_result),.completion_elements(vif.completion_elements),.cmdq_head(vif.cmdq_head),.cplq_tail(vif.cplq_tail),
    .busy(vif.busy),.event_valid(vif.event_valid),.event_error(vif.event_error),.event_error_code(vif.event_error_code),.event_result(vif.event_result),
    .event_cycles(vif.event_cycles),.event_elements(vif.event_elements),.dependency_events(vif.dependency_events)
  );
  assign vif.debug_state_r = u_cp.state_r;
  assign vif.debug_writer_state_r = u_completion_writer.state_r;
  wire cplq_last_slot_transition =
      (u_cp.state_r==4'd4) && writer_done && u_cp.queue_run_r &&
      (u_cp.cmdq_head_index!=vif.cmdq_tail) &&
      (((u_cp.cplq_tail_next >= vif.cplq_size-1) ? 0 :
         u_cp.cplq_tail_next+1) == vif.cplq_head);
  property p_last_cplq_slot_holds_queued_command;
    @(posedge clk) disable iff(!vif.resetn)
      cplq_last_slot_transition |=>
        (u_cp.state_r==4'd0 && !vif.busy && !vif.fetch_start &&
         !vif.launch_valid && $stable(u_cp.cmdq_head));
  endproperty
  a_last_cplq_slot_holds_queued_command:
    assert property(p_last_cplq_slot_holds_queued_command)
      else $error("CP launched/advanced a queued command after the current completion filled CPLQ");
  c_last_cplq_slot_holds_queued_command:
    cover property(@(posedge clk) disable iff(!vif.resetn)
      cplq_last_slot_transition);

  // The completion writer's one-cycle done pulse should be consumed while the
  // CP owns ST_CPL. Guard this integration contract and track the correlated
  // completion_done/state URG vector; simulation coverage is not formal proof.
  property p_completion_done_owned_by_cpl_state;
    @(posedge clk) disable iff(!vif.resetn)
      vif.completion_done |-> (u_cp.state_r==4'd4);
  endproperty
  a_completion_done_owned_by_cpl_state:
    assert property(p_completion_done_owned_by_cpl_state)
      else $error("completion writer done pulse observed outside CP ST_CPL");
  c_completion_done_owned_by_cpl_state:
    cover property(@(posedge clk) disable iff(!vif.resetn)
      vif.completion_done && (u_cp.state_r==4'd4));

  // Fault-inject one illegal FSM encoding to exercise the defensive default
  // recovery branch; this is not an externally reachable protocol stimulus.
  always @(posedge vif.inject_illegal_fsm_state) begin
    force u_cp.state_r = 4'hf;
    @(posedge clk);
    @(negedge clk);
    release u_cp.state_r;
    vif.illegal_fsm_state_recovered=1'b1;
    @(negedge clk);
    vif.illegal_fsm_state_recovered=1'b0;
  end

  // Exercise the completion writer's defensive illegal-state recovery branch.
  // This is testbench fault injection, not a legal software-visible stimulus.
  always @(posedge vif.inject_illegal_writer_state) begin
    force u_completion_writer.state_r = 2'b11;
    @(posedge clk);
    @(negedge clk);
    release u_completion_writer.state_r;
    vif.illegal_writer_state_recovered=1'b1;
    @(negedge clk);
    vif.illegal_writer_state_recovered=1'b0;
  end

  ai_completion_writer u_completion_writer(
    .clk(clk),.resetn(vif.resetn),.start(vif.completion_start),.cplq_base(cpl_base),.cplq_index(cpl_index),
    .task_id(vif.completion_task_id),.status(vif.completion_status),.error_code(vif.completion_error),.result(vif.completion_result),
    .element_count(vif.completion_elements),.spad_valid(vif.cpl_spad_valid),.spad_write(vif.cpl_spad_write),
    .spad_addr(vif.cpl_spad_addr),.spad_wdata(vif.cpl_spad_wdata),.spad_ready(vif.cpl_spad_ready),.busy(writer_busy),.done(writer_done)
  );

  // Behavioral descriptor fetch, compute endpoint, and randomized SPAD grants.
  initial begin : model_endpoints
    descriptor_t d;
    int slot,delay_cycles,failure_index;
    logic [1:0] failure_kind;
    vif.fetch_done=0; vif.fetch_error=0; vif.fetch_busy=0;
    vif.compute_done=0; vif.compute_error=0; vif.compute_error_code=0;
    vif.force_stale_abort_code_once=0;
    vif.compute_busy=0;
    vif.tile_start=0;
    vif.cpl_spad_ready=0;
    vif.partial_reset_sweep_active=0;
    vif.partial_reset_target_words=2'd1;
    vif.partial_reset_write_count=0;
    vif.partial_reset_done=0;
    forever begin
      @(negedge clk);
      if(!vif.resetn) begin
        vif.fetch_done=0; vif.fetch_error=0; vif.fetch_busy=0;
        vif.fetch_abort_at_done=0;
        vif.compute_done=0; vif.compute_error=0; vif.compute_error_code=0;
        vif.force_stale_abort_code_once=0;
        vif.compute_busy=0;
        vif.cpl_spad_ready=0;
      end
      else begin
        if(vif.force_completion_backpressure)
          vif.cpl_spad_ready=0;
        else if((vif.test_case==CP_PARTIAL_RESET ||
                 (vif.test_case==CP_ABORT_RESET_PARTIAL &&
                  vif.partial_reset_sweep_active)) && !vif.partial_reset_done)
          vif.cpl_spad_ready=(vif.partial_reset_write_count <
                              vif.partial_reset_target_words);
        else if(vif.test_case==CP_ABORT_RESET_PARTIAL &&
                !vif.partial_reset_sweep_active &&
                vif.cpl_spad_addr[3:2]==2'd1)
          vif.cpl_spad_ready=0;
        else if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET &&
                vif.mixed_hold_abort_completion &&
                vif.cpl_spad_addr[3:2]==vif.mixed_reset_target_words &&
                vif.completion_error==4'd3)
          vif.cpl_spad_ready=0;
        else
          vif.cpl_spad_ready=($urandom_range(0,3)!=0);
        if(vif.fetch_start) begin
          // fetch_start is the request-acceptance point for this behavioral
          // endpoint. The state and response are all driven on negedges so
          // the CP samples a stable busy/done/abort tuple at the next posedge.
          vif.fetch_busy=1;
          slot=(vif.fetch_base-vif.cmdq_base)>>6;
          if(slot<0 || slot>3) slot=0;
          d=vif.desc_mem[slot];
          failure_kind=2'd0;
          failure_index=d.task_id-16'h2000;
          if(vif.test_case==CP_RANDOM_QUEUE && failure_index>=0 && failure_index<32)
            failure_kind=vif.random_queue_failure_kind[(failure_index*2) +: 2];
          if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET && d.task_id==16'h1400)
            failure_kind=vif.mixed_prefix_failure_kind;
          delay_cycles=(vif.test_case==CP_FETCH_ABORT) ? 4 : 2;
          fork begin
            repeat(delay_cycles) @(negedge clk);
            if(vif.resetn) begin
              vif.desc_op=d.op; vif.desc_task_id=d.task_id; vif.desc_src0=d.src0; vif.desc_src1=d.src1; vif.desc_dst=d.dst;
              vif.desc_length=d.length; vif.desc_m=d.m; vif.desc_n=d.n; vif.desc_k=d.k; vif.desc_shift=d.shift; vif.desc_activation=d.activation;
              vif.desc_bias_base=d.bias_base; vif.desc_bias_enable=d.bias_enable; vif.desc_flags=d.flags; vif.desc_aux0=d.aux0;
              vif.desc_src0_stride=d.src0_stride; vif.desc_src1_stride=d.src1_stride; vif.desc_dst_stride=d.dst_stride;
              vif.desc_batch_count=d.batch_count; vif.desc_head_count=d.head_count; vif.desc_wait_mask=d.wait_mask;
              vif.desc_signal_mask=d.signal_mask; vif.desc_clear_mask=d.clear_mask; vif.desc_version=d.version;
              vif.fetch_error=(vif.test_case==CP_FETCH_ERROR) ||
                              (vif.test_case==CP_FETCH_ERROR_NO_CPL) ||
                              ((vif.test_case==CP_MACRO_CHILDREN) &&
                               (d.task_id==16'h1552)) ||
                              ((vif.test_case==CP_RANDOM_QUEUE) && (failure_kind==2'd2)) ||
                              ((vif.test_case==CP_MIXED_ERROR_ABORT_RESET) &&
                               (d.task_id==16'h1400) && (failure_kind==2'd2));
              vif.fetch_done=1;
              if(vif.fetch_abort_at_done) vif.abort=1;
              @(negedge clk); vif.fetch_done=0; vif.fetch_error=0;
              vif.fetch_busy=0;
              if(vif.fetch_abort_at_done) begin
                vif.abort=0;
                vif.fetch_abort_at_done=0;
              end
            end
          end join_none
        end
        if(vif.launch_valid) begin
          delay_cycles=(vif.test_case==CP_TILE_PINGPONG) ? $urandom_range(3,7) : $urandom_range(2,4);
          failure_kind=2'd0;
          failure_index=vif.launch_task_id-16'h2000;
          if(vif.test_case==CP_RANDOM_QUEUE && failure_index>=0 && failure_index<32)
            failure_kind=vif.random_queue_failure_kind[(failure_index*2) +: 2];
          fork begin
            vif.compute_busy=1;
            if((vif.test_case==CP_COMPUTE_ABORT ||
                vif.test_case==CP_ABORT_RESET_PARTIAL ||
                vif.test_case==CP_MIXED_ERROR_ABORT_RESET) && vif.compute_abort_once) begin
              wait(vif.abort || !vif.resetn);
              if(vif.resetn) begin
                vif.compute_error=1;
                vif.compute_error_code=4'd3;
                vif.compute_done=1;
                vif.compute_busy=0;
                vif.compute_abort_once=0;
                @(negedge clk);
                vif.compute_done=0; vif.compute_error=0; vif.compute_error_code=0;
              end
            end else begin
              repeat(delay_cycles) @(negedge clk);
              if(vif.resetn) begin
                vif.compute_error=(vif.test_case==CP_COMPUTE_ERROR) ||
                                  ((vif.test_case==CP_MACRO_CHILDREN) &&
                                   vif.force_compute_error_once) ||
                                  ((vif.test_case==CP_DIRECT_START) &&
                                   vif.force_compute_error_once) ||
                                  ((vif.test_case==CP_RANDOM_QUEUE) && (failure_kind==2'd3));
                if(vif.test_case==CP_DIRECT_START && vif.force_stale_abort_code_once &&
                   !vif.compute_error)
                  vif.compute_error_code=4'd3;
                else
                  vif.compute_error_code=vif.compute_error ? 4'd5 : 4'd0;
                if((vif.test_case==CP_MACRO_CHILDREN ||
                    vif.test_case==CP_DIRECT_START) && vif.force_compute_error_once)
                  vif.force_compute_error_once=0;
                vif.compute_done=1;
                vif.compute_busy=0;
                @(negedge clk);
                vif.compute_done=0; vif.compute_error=0; vif.compute_error_code=0;
              end
            end
          end join_none
        end
      end
    end
  end

  initial begin
    vif.illegal_fsm_state_recovered=0;
    vif.illegal_writer_state_recovered=0;
  end

  // Behavioral DMA endpoint for the real tile scheduler. Delays vary per
  // transfer so load/compute/store overlap and both context owners are tested.
  initial begin : tile_dma_endpoint
    int delay_cycles;
    vif.dma_busy=0; vif.dma_done=0; vif.dma_error=0; vif.dma_error_code=0;
    forever begin
      @(negedge clk);
      if(!vif.resetn) begin
        vif.dma_busy=0; vif.dma_done=0; vif.dma_error=0; vif.dma_error_code=0;
      end else if(vif.tile_dma_start) begin
        delay_cycles=$urandom_range(2,6);
        begin : tile_dma_response
          bit inject_error;
          inject_error=(!vif.tile_dma_store && vif.force_tile_dma_error_once);
          if(inject_error) vif.force_tile_dma_error_once=0;
        fork begin
          vif.dma_busy=1;
          repeat(delay_cycles) @(negedge clk);
          if(vif.resetn) begin
            vif.dma_busy=0; vif.dma_done=1;
            vif.dma_error=inject_error;
            vif.dma_error_code=inject_error ? 4'hA : 4'd0;
            @(negedge clk);
            vif.dma_done=0; vif.dma_error=0; vif.dma_error_code=0;
          end
        end join_none
        end
      end
    end
  end
  initial begin
    uvm_config_db#(virtual ai_cp_if)::set(null,"*","vif",vif);
    run_test("ai_cp_test");
  end
endmodule
