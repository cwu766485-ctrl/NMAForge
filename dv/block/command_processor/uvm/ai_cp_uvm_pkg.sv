`timescale 1ns/1ps
package ai_cp_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  typedef enum int {CP_VALID=0,CP_INVALID,CP_WRAP,CP_DEPENDENCY,CP_RESET,
                    CP_RANDOM_STALL,CP_DEP_ABORT,CP_EMPTY,CP_CPL_FULL,
                    CP_FETCH_ERROR,CP_COMPUTE_ERROR,CP_PARTIAL_RESET,
                    CP_EXTERNAL_DESC,CP_DEP_TIMEOUT,CP_CONCURRENT_RING,
                    CP_TILE_PINGPONG,CP_RANDOM_QUEUE,CP_FETCH_ABORT,
                    CP_COMPUTE_ABORT,CP_ABORT_RESET_PARTIAL,
                    CP_MIXED_ERROR_ABORT_RESET,CP_DIRECT_START,CP_MACRO_CHILDREN,
                    CP_FETCH_ERROR_NO_CPL,CP_CPLQ_PRESSURE,
                    CP_COMPLETION_PROT_LATE,CP_FSM_FAULT_RECOVERY,
                    CP_SUBMIT_GUARD,CP_WRITER_FSM_FAULT_RECOVERY,
                    CP_ZERO_SIZE_EMPTY_FETCH,CP_CPLQ_LAST_SLOT_QUEUE} cp_case_e;
  class ai_cp_item extends uvm_sequence_item;
    rand cp_case_e scenario;
    `uvm_object_utils_begin(ai_cp_item)
      `uvm_field_enum(cp_case_e,scenario,UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name="ai_cp_item"); super.new(name); endfunction
  endclass
  class ai_cp_sequence extends uvm_sequence #(ai_cp_item);
    `uvm_object_utils(ai_cp_sequence)
    function new(string name="ai_cp_sequence"); super.new(name); endfunction
    task body();
      ai_cp_item r;
      cp_case_e cases[$]='{CP_VALID,CP_WRAP,CP_INVALID,CP_DEPENDENCY,
                           CP_RANDOM_STALL,CP_DEP_ABORT,CP_EMPTY,CP_CPL_FULL,
                           CP_RESET,CP_VALID,CP_FETCH_ERROR,CP_COMPUTE_ERROR,
                           CP_COMPUTE_ABORT,CP_PARTIAL_RESET,CP_EXTERNAL_DESC,CP_DEP_TIMEOUT,
                           CP_CONCURRENT_RING,CP_TILE_PINGPONG,CP_RANDOM_QUEUE,
                           CP_FETCH_ABORT,CP_ABORT_RESET_PARTIAL,
                           CP_MIXED_ERROR_ABORT_RESET,CP_DIRECT_START,
                           CP_MACRO_CHILDREN,CP_FETCH_ERROR_NO_CPL,
                           CP_CPLQ_PRESSURE,CP_COMPLETION_PROT_LATE,
                           CP_FSM_FAULT_RECOVERY,CP_SUBMIT_GUARD,
                           CP_WRITER_FSM_FAULT_RECOVERY,
                            CP_ZERO_SIZE_EMPTY_FETCH,CP_CPLQ_LAST_SLOT_QUEUE};
      int only_case;
      bit only_case_valid;
      only_case_valid = $value$plusargs("CP_ONLY_CASE=%d", only_case);
      if (only_case_valid) begin
        if (only_case < 0 || only_case > 30)
          `uvm_fatal("CP/SEQ",$sformatf("CP_ONLY_CASE=%0d is outside scenario range 0..30",only_case))
        r=ai_cp_item::type_id::create($sformatf("only_case_%0d",only_case));
        start_item(r); r.scenario=cp_case_e'(only_case); finish_item(r);
        `uvm_info("CP/SEQ",$sformatf("CP_ONLY_CASE=%0d dispatched; full-suite aggregate gates are skipped",only_case),UVM_LOW)
        return;
      end
      foreach(cases[i]) begin
        r=ai_cp_item::type_id::create($sformatf("case_%0d",i));
        start_item(r); r.scenario=cases[i]; finish_item(r);
      end
    endtask
  endclass
  class ai_cp_driver extends uvm_driver #(ai_cp_item);
    `uvm_component_utils(ai_cp_driver)
    virtual ai_cp_if vif;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual ai_cp_if)::get(this,"","vif",vif)) `uvm_fatal("CP/DRV","vif missing")
    endfunction
    task automatic pulse_submit();
      @(negedge vif.clk); vif.submit=1; @(negedge vif.clk); vif.submit=0;
    endtask
    task automatic descriptor(int slot, bit invalid=0, bit [15:0] wait_mask=0,
                               bit [15:0] signal_mask=0, bit custom_id_en=0,
                               bit [15:0] custom_id=0);
      vif.desc_mem[slot]='{op:invalid?8'hff:8'h10,
        task_id:custom_id_en?custom_id:(16'h1000+slot),src0:32'h100,src1:32'h200,dst:32'h300,
        length:16'd4,m:16'd1,n:16'd1,k:16'd4,shift:0,activation:0,bias_base:0,bias_enable:0,
        flags:0,aux0:0,src0_stride:0,src1_stride:0,dst_stride:0,batch_count:0,head_count:0,
        wait_mask:wait_mask,signal_mask:signal_mask,clear_mask:0,version:8'd7};
    endtask
    task automatic wait_idle();
      int limit=0, max_wait_cycles;
      max_wait_cycles=(vif.test_case==CP_DEP_TIMEOUT) ? 70000 : 1000;
      while((vif.busy || vif.cpl_writer_busy) && limit<max_wait_cycles) begin
        @(posedge vif.clk); limit++;
      end
      if(limit>=max_wait_cycles) `uvm_fatal("CP/DRV","timeout waiting for queues to drain")
      repeat(3) @(posedge vif.clk);
    endtask
    task automatic wait_cplq_tail(input logic [31:0] expected_tail);
      int limit=0;
      while(vif.cplq_tail!==expected_tail && limit<1000) begin
        @(posedge vif.clk); limit++;
      end
      if(vif.cplq_tail!==expected_tail)
        `uvm_fatal("CP/CPLQ",$sformatf("timeout waiting for CPLQ_TAIL=%0d; observed=%0d",
                                        expected_tail,vif.cplq_tail))
    endtask
    task automatic reset_cp();
      vif.submit=0; vif.abort=0; vif.direct_start=0;
      vif.tile_start=0;
      vif.force_compute_error_once=0;
      vif.force_stale_abort_code_once=0;
      vif.force_completion_backpressure=0;
      vif.cfg_op=8'h50;
      vif.cmdq_head_load=0; vif.cplq_tail_load=0;
      vif.resetn=0;
      vif.completion_protected=0;
      vif.inject_illegal_fsm_state=0;
      vif.inject_illegal_writer_state=0;
      repeat(3) @(negedge vif.clk);
      vif.resetn=1;
      repeat(3) @(posedge vif.clk);
    endtask
    task automatic launch_queue(int start_idx,int count);
      @(negedge vif.clk); vif.cmdq_head_seed=start_idx; vif.cmdq_head_load=1;
      vif.cplq_tail_seed=start_idx; vif.cplq_tail_load=1;
      @(negedge vif.clk); vif.cmdq_head_load=0; vif.cplq_tail_load=0;
      vif.cmdq_tail=(start_idx+count)%4; vif.cplq_head=start_idx;
      pulse_submit(); wait_idle();
    endtask
    task automatic check_v7_macro_fetch_sequence();
      int fetch_index,wait_cycles;
      logic [63:0] expected_base;
      for(fetch_index=0;fetch_index<4;fetch_index++) begin
        wait_cycles=0;
        while(vif.fetch_start!==1'b1 && wait_cycles<100) begin
          @(negedge vif.clk);
          wait_cycles++;
        end
        if(vif.fetch_start!==1'b1) begin
          `uvm_error("CP/MACRO_ADDR",
            $sformatf("timed out waiting for v7 macro fetch[%0d]",fetch_index))
          return;
        end
        expected_base=(fetch_index==0) ? 64'h0000_0001_0000_1000 :
                      (64'h0000_0001_0000_1040 + ((fetch_index-1)<<6));
        if(vif.fetch_base!==expected_base ||
           vif.fetch_external!==(fetch_index!=0))
          `uvm_error("CP/MACRO_ADDR",
            $sformatf("v7 macro fetch[%0d] base=%016h external=%b expected base=%016h external=%b",
                      fetch_index,vif.fetch_base,vif.fetch_external,
                      expected_base,(fetch_index!=0)))
        do @(negedge vif.clk); while(vif.fetch_start===1'b1);
      end
      `uvm_info("CP/MACRO_ADDR",
        "v7 parent fetch + three external child fetches used 64-bit aligned addresses",
        UVM_LOW)
    endtask
    task automatic run_phase(uvm_phase phase);
      ai_cp_item req;
      vif.resetn=0; vif.submit=0; vif.abort=0; vif.direct_start=0;
      vif.cmdq_head_load=0; vif.cplq_tail_load=0;
      vif.cmdq_base=64'h1000; vif.cmdq_size=4; vif.cmdq_tail=1;
      vif.desc_external=0;
      vif.cplq_base=32'h8000; vif.cplq_size=4; vif.cplq_head=0;
      vif.completion_protected=0;
      vif.inject_illegal_fsm_state=0;
      vif.illegal_fsm_state_recovered=0;
      vif.fetch_busy=0;
      vif.fetch_abort_at_done=0;
      vif.abort_cov_path=0;
      vif.compute_busy=0;
      vif.random_queue_count=0;
      vif.random_queue_error_mask=0;
      vif.compute_abort_once=0;
      vif.force_compute_error_once=0;
      vif.abort_reset_recovery=0;
      vif.mixed_prefix_failure_kind=0;
      vif.mixed_abort_delay_cycles=0;
      vif.mixed_reset_target_words=0;
      vif.mixed_reset_check_pending=0;
      vif.mixed_hold_abort_completion=0;
      vif.compute_result=32'hc0de0001; vif.compute_cycles=32'd17; vif.compute_elements=32'd4;
      vif.cfg_op=8'h50;
      vif.cfg_src0=32'd0; vif.cfg_src1=32'h0000_0200; vif.cfg_dst=32'd0;
      vif.cfg_length=16'd4;
      vif.cfg_m=16'd1; vif.cfg_n=16'd1; vif.cfg_k=16'd4;
      vif.cfg_shift=5'd0; vif.cfg_activation=2'd0;
      vif.cfg_bias_base=32'd0; vif.cfg_bias_enable=1'b0;
      repeat(4) @(negedge vif.clk); vif.resetn=1;
      forever begin
        seq_item_port.get_next_item(req);
        vif.abort_reset_recovery=0;
        vif.test_case=req.scenario;
        `uvm_info("CP/SCENARIO",$sformatf("starting scenario=%s enum=%0d",req.scenario.name(),req.scenario),UVM_LOW)
        case(req.scenario)
          CP_VALID: begin
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
            if(vif.cmdq_head!==1) `uvm_error("CP/DRV","command head did not advance exactly once")
          end
          CP_WRAP: begin
            descriptor(3); vif.cmdq_tail=1; vif.cplq_head=2;
            launch_queue(3,1);
            if(vif.cmdq_head!==0 || vif.cplq_tail!==0) `uvm_error("CP/DRV","ring pointers failed wrap")
          end
          CP_INVALID: begin
            descriptor(0,1); vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
          end
          CP_DEPENDENCY: begin
            descriptor(0,0,0,1); descriptor(1,0,1,0);
            vif.cmdq_tail=2; vif.cplq_head=0; launch_queue(0,2);
            if(vif.dependency_events[0]!==1'b1) `uvm_error("CP/DRV","dependency signal not retired")
          end
          CP_RANDOM_STALL: begin
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0; launch_queue(0,1);
          end
          CP_DEP_ABORT: begin
            // No producer publishes bit 1. The descriptor must remain blocked
            // in dependency decode until abort, then retire one ERR_ABORT CPL.
            reset_cp();
            descriptor(0,0,16'h0002,0);
            vif.cmdq_tail=1; vif.cplq_head=0;
            pulse_submit();
            repeat(8) @(posedge vif.clk);
            if(!vif.busy) `uvm_error("CP/DRV","unmet dependency did not hold command busy")
            if(vif.launch_valid) `uvm_error("CP/DRV","unmet dependency launched compute")
            if(vif.desc_wait_mask!==16'h0002)
              `uvm_error("CP/DRV","unmet dependency descriptor did not reach decode")
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait_idle();
          end
          CP_FETCH_ABORT: begin
            reset_cp();
            descriptor(0);
            vif.cmdq_tail=1; vif.cplq_head=0;
            @(negedge vif.clk); vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk); vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();
            wait(vif.fetch_start);
            if(!vif.busy || vif.launch_valid)
              `uvm_error("CP/DRV","command did not remain in fetch before abort")
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait_idle();
            if(vif.cmdq_head!==1 || vif.launch_valid)
              `uvm_error("CP/DRV","fetch-stage abort launched compute or advanced CMDQ incorrectly")
            // Same-cycle completion abort: the endpoint raises abort together
            // with fetch_done. This must take the ST_FETCH completion branch
            // with abort_pending still clear (not merely the sticky path above).
            reset_cp(); descriptor(0,0,0,0,1,16'h1702);
            vif.cmdq_tail=1; vif.cplq_head=0;
            vif.abort_cov_path=2'd1; vif.fetch_abort_at_done=1;
            pulse_submit(); wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.launch_valid ||
               vif.cpl_writer_busy || vif.abort_cov_path!==2'd1)
              `uvm_error("CP/DRV","same-cycle fetch-completion abort did not retire once without launch")
            vif.abort_cov_path=0;
            // Legacy cplq_size==0 route: abort is reported as an event only.
            reset_cp(); descriptor(0); vif.cmdq_size=0; vif.cplq_size=0; vif.cmdq_tail=1;
            pulse_submit(); wait(vif.fetch_start);
            @(negedge vif.clk); vif.abort=1; @(negedge vif.clk); vif.abort=0;
            wait(vif.event_valid===1'b1);
            if(!vif.event_valid || !vif.event_error || vif.event_error_code!==4'd3 ||
               vif.cpl_spad_valid || vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/NO_CPLQ","fetch abort without CPLQ did not produce only ERR_ABORT event")
            `uvm_info("CP/NO_CPLQ","fetch_abort_event=1 completion_write=0 launch=0",UVM_LOW)
            wait_idle();
            vif.cmdq_size=4; vif.cplq_size=4;

            // Exercise the separate ST_DECODE abort branch after the fetch
            // response has already advanced the processor out of ST_FETCH.
            // Zero-sized queues select the legacy event-only path.
            reset_cp(); descriptor(0,0,0,0,1,16'h1701);
            vif.cmdq_size=0; vif.cplq_size=0; vif.cmdq_tail=1;
            pulse_submit();
            wait(vif.fetch_done===1'b1);
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait(vif.event_valid===1'b1);
            if(!vif.event_error || vif.event_error_code!==4'd3 ||
               vif.event_result!==32'd0 || vif.event_cycles!==32'd0 ||
               vif.event_elements!==32'd0 || vif.cmdq_head!==32'd1 ||
               vif.cplq_tail!==32'd0 || vif.cpl_spad_valid ||
               vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/NO_CPLQ","decode-stage abort did not report only ERR_ABORT event")
            wait_idle();
            vif.cmdq_size=4; vif.cplq_size=4;
            `uvm_info("CP/NO_CPLQ","decode_abort_event=1 completion_write=0 launch=0 head_advance=1",UVM_LOW)
          end
          CP_COMPUTE_ABORT: begin
            reset_cp();
            descriptor(0,0,0,0,1,16'h1200);
            descriptor(1,0,0,0,1,16'h1201);
            vif.random_queue_count=0;
            vif.compute_abort_once=1;
            vif.cmdq_tail=2; vif.cplq_head=0;
            @(negedge vif.clk);
            vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();
            wait(vif.compute_busy);
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.launch_valid ||
               vif.compute_busy)
              `uvm_error("CP/DRV","compute abort did not stop after one command completion")

            // A second software doorbell resumes the still-published command.
            pulse_submit();
            wait_idle();
            if(vif.cmdq_head!==2 || vif.cplq_tail!==2 || vif.launch_valid ||
               vif.compute_busy)
              `uvm_error("CP/DRV","queued command did not recover after compute abort")
          end
          CP_ABORT_RESET_PARTIAL: begin
            int reset_words_target;
            int reset_words_observed;
            reset_cp();
            if(!$value$plusargs("CP_RESET_WORDS=%d",reset_words_target))
              reset_words_target=1;
            if(reset_words_target<0 || reset_words_target>3)
              `uvm_fatal("CP/ABORT_RESET_CFG",
                $sformatf("CP_RESET_WORDS=%0d is outside range 0..3",reset_words_target))
            vif.partial_reset_target_words=reset_words_target[1:0];
            vif.partial_reset_sweep_active=1'b1;
            descriptor(0,0,0,0,1,16'h1300);
            descriptor(1,0,0,0,1,16'h1301);
            vif.compute_abort_once=1;
            vif.cmdq_tail=2; vif.cplq_head=0;
            @(negedge vif.clk);
            vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();
            wait(vif.compute_busy);
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait(vif.cpl_spad_valid && !vif.cpl_spad_ready &&
                 vif.cpl_spad_addr[3:2]==reset_words_target[1:0]);
            @(negedge vif.clk);
            reset_words_observed=vif.partial_reset_write_count;
            if(reset_words_observed!=reset_words_target ||
               vif.completion_task_id!==16'h1300 ||
               vif.completion_error!==4'd3 || vif.completion_status!==4'd2 ||
               vif.cplq_tail!==0 || vif.cmdq_head!==1 || vif.launch_valid ||
               !vif.cpl_writer_busy || !vif.cpl_spad_valid || vif.cpl_spad_ready)
              `uvm_error("CP/ABORT_RESET",
                $sformatf("ERR_ABORT partial record mismatch words=%0d/%0d task=%04x error=%0d status=%0d tail=%0d head=%0d",
                  reset_words_observed,reset_words_target,vif.completion_task_id,
                  vif.completion_error,vif.completion_status,vif.cplq_tail,vif.cmdq_head))
            reset_cp();
            if(!vif.partial_reset_done || vif.partial_reset_write_count!=0 ||
               vif.busy || vif.cpl_writer_busy || vif.cpl_writer_done ||
               vif.cmdq_head!==0 || vif.cplq_tail!==0)
              `uvm_error("CP/ABORT_RESET","reset did not discard the partial abort completion")

            // Recover from reset with a fresh command and clean queue pointers.
            vif.test_case=CP_VALID;
            vif.abort_reset_recovery=1;
            descriptor(0);
            vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.busy ||
               vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/ABORT_RESET","post-reset command did not complete exactly once")
            `uvm_info("CP/ABORT_RESET_SWEEP",
              $sformatf("accepted_before_reset=%0d reset_cleared=1 queued_suppressed=1 recovery_completions=1 tail=1",
                        reset_words_observed),UVM_LOW)
            vif.partial_reset_sweep_active=1'b0;
          end
          CP_MIXED_ERROR_ABORT_RESET: begin
            int prefix_kind, abort_delay, reset_words_target;
            reset_cp();
            // Normal runs stay randomized. The coverage regression may force
            // representative values so all kind x delay-class bins are hit.
            if(!$value$plusargs("CP_MIXED_KIND=%d",prefix_kind))
              prefix_kind=$urandom_range(1,2); // invalid descriptor or fetch error
            if(!$value$plusargs("CP_MIXED_DELAY=%d",abort_delay))
              abort_delay=$urandom_range(0,5);
            if(!$value$plusargs("CP_MIXED_RESET_WORDS=%d",reset_words_target))
              reset_words_target=$urandom_range(0,3);
            if(prefix_kind<1 || prefix_kind>2 || abort_delay<0 || abort_delay>5 ||
               reset_words_target<0 || reset_words_target>3)
              `uvm_fatal("CP/MIXED_CFG",$sformatf("invalid kind=%0d delay=%0d reset_words=%0d",prefix_kind,abort_delay,reset_words_target))
            vif.mixed_prefix_failure_kind=prefix_kind[1:0];
            vif.mixed_abort_delay_cycles=abort_delay[2:0];
            vif.mixed_reset_target_words=reset_words_target[1:0];
            vif.mixed_hold_abort_completion=0;
            descriptor(0,(prefix_kind==1),0,0,1,16'h1400);
            descriptor(1,0,0,0,1,16'h1401);
            descriptor(2,0,0,0,1,16'h1402);
            vif.compute_abort_once=1;
            vif.cmdq_tail=3; vif.cplq_head=0;
            @(negedge vif.clk);
            vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();

            // Retire a randomized front-end error, then free its CPLQ slot.
            wait(vif.cplq_tail==1);
            @(negedge vif.clk); vif.cplq_head=1;
            vif.mixed_hold_abort_completion=1;
            wait(vif.compute_busy);
            repeat(abort_delay) @(negedge vif.clk);
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            // Exclude the previous completion's last-word request from the
            // wait; its valid/address may overlap the new writer start delta.
            wait(vif.cpl_writer_busy===1'b1 &&
                 vif.completion_task_id===16'h1401 &&
                 vif.completion_error===4'd3);
            // Sample after a full stable clock beat; the busy transition and
            // stale final-word address can otherwise coincide in one delta.
            @(posedge vif.clk); #1ps;
            wait(vif.cpl_spad_valid && !vif.cpl_spad_ready &&
                 vif.cpl_spad_addr[3:2]==reset_words_target[1:0]);
            @(negedge vif.clk);
            vif.mixed_reset_check_pending=1;
            if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2 ||
               vif.cplq_tail!==1 || vif.cmdq_head!==2 || vif.launch_valid)
              `uvm_error("CP/MIXED","abort completion did not stall at configured reset word or queued command advanced")

            reset_cp();
            if(vif.busy || vif.cpl_writer_busy || vif.cpl_writer_done ||
               vif.cmdq_head!==0 || vif.cplq_tail!==0)
              `uvm_error("CP/MIXED","reset did not clear partial completion and queue pointers")
            vif.mixed_reset_check_pending=0;
            vif.mixed_hold_abort_completion=0;
            vif.compute_abort_once=0;
            vif.abort_reset_recovery=1;
            descriptor(0,0,0,0,1,16'h1403);
            vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.busy ||
               vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/MIXED","post-reset recovery command did not retire exactly once")
            vif.abort_reset_recovery=0;
            `uvm_info("CP/MIXED",$sformatf("prefix_kind=%0d abort_delay=%0d reset_words=%0d queued_suppressed=1 recovery=1",
              prefix_kind,abort_delay,reset_words_target),UVM_LOW)
          end
          CP_DIRECT_START: begin
            int fmt, invalid_case;
            reset_cp();
            // Direct FP dot has no descriptor validator in front of it. Check
            // each independent invalid field for both BF16 and FP16 opcodes.
            for(fmt=0;fmt<2;fmt++) begin
              vif.cfg_op=(fmt==0) ? 8'h50 : 8'h51;
              for(invalid_case=0;invalid_case<10;invalid_case++) begin
                vif.cfg_src0=32'd0; vif.cfg_src1=32'h0000_0200; vif.cfg_dst=32'd0;
                vif.cfg_length=16'd4; vif.cfg_m=16'd1; vif.cfg_n=16'd1; vif.cfg_k=16'd4;
                vif.cfg_shift=5'd0; vif.cfg_activation=2'd0;
                vif.cfg_bias_base=32'd0; vif.cfg_bias_enable=1'b0;
                case(invalid_case)
                  0: vif.cfg_length=16'd0;
                  1: vif.cfg_m=16'd2;
                  2: vif.cfg_n=16'd2;
                  3: vif.cfg_src0=32'h0000_0101;
                  4: vif.cfg_src1=32'h0000_0201;
                  5: vif.cfg_dst=32'h0000_0301;
                  6: vif.cfg_bias_base=32'h0000_0400;
                  7: vif.cfg_bias_enable=1'b1;
                  8: vif.cfg_shift=5'd1;
                  9: vif.cfg_activation=2'd1;
                endcase
                @(negedge vif.clk); vif.direct_start=1;
                @(negedge vif.clk); vif.direct_start=0;
                wait(vif.event_valid===1'b1);
                if(!vif.event_error || vif.event_error_code!==4'd7 ||
                   vif.event_result!==32'd0 || vif.event_elements!==32'd0 ||
                   vif.launch_valid || vif.cmdq_head!==0 || vif.cplq_tail!==0)
                  `uvm_error("CP/DIRECT",$sformatf("invalid FP configuration reason %0d was not rejected",invalid_case))
                wait_idle();
              end
            end

            // A direct-start pulse is not queued while another scheduler
            // resource is active; software must issue a fresh request later.
            vif.cfg_op=8'h50; vif.cfg_src0=32'd0; vif.cfg_src1=32'h0000_0200;
            vif.cfg_dst=32'd0; vif.cfg_length=16'd0;
            vif.cfg_m=16'd1; vif.cfg_n=16'd1; vif.cfg_k=16'd4;
            vif.cfg_shift=5'd0; vif.cfg_activation=2'd0;
            vif.cfg_bias_base=32'd0; vif.cfg_bias_enable=1'b0;
            vif.compute_busy=1;
            @(negedge vif.clk); vif.direct_start=1;
            @(negedge vif.clk); vif.direct_start=0;
            repeat(2) @(negedge vif.clk);
            if(vif.launch_valid || vif.busy || vif.event_valid ||
               vif.cmdq_head!==0 || vif.cplq_tail!==0)
              `uvm_error("CP/DIRECT","direct-start was not suppressed while scheduler resources were busy")
            vif.compute_busy=0;
            vif.cfg_length=16'd4;
            repeat(2) @(negedge vif.clk);
            if(vif.launch_valid || vif.event_valid || vif.busy)
              `uvm_error("CP/DIRECT","busy-time direct-start was incorrectly queued for later replay")

            for(fmt=0;fmt<2;fmt++) begin
              vif.cfg_op=(fmt==0) ? 8'h50 : 8'h51;
              vif.cfg_src0=32'd0; vif.cfg_src1=32'h0000_0200; vif.cfg_dst=32'd0;
              vif.cfg_length=16'd4; vif.cfg_m=16'd1; vif.cfg_n=16'd1; vif.cfg_k=16'd4;
              vif.cfg_shift=5'd0; vif.cfg_activation=2'd0;
              vif.cfg_bias_base=32'd0; vif.cfg_bias_enable=1'b0;
              @(negedge vif.clk); vif.direct_start=1;
              @(negedge vif.clk); vif.direct_start=0;
              wait_idle();
            end

            // A legal non-FP opcode must use the generic direct-launch path;
            // the FP-only configuration validator must not reject it.
            vif.cfg_op=8'h10;
            vif.cfg_src0=32'd0; vif.cfg_src1=32'h0000_0200; vif.cfg_dst=32'd0;
            vif.cfg_length=16'd4; vif.cfg_m=16'd1; vif.cfg_n=16'd1; vif.cfg_k=16'd4;
            // INT8 accepts this scale shift, while it deliberately makes the
            // FP-only direct configuration predicate true.
            vif.cfg_shift=5'd1; vif.cfg_activation=2'd0;
            vif.cfg_bias_base=32'd0; vif.cfg_bias_enable=1'b0;
            @(negedge vif.clk); vif.direct_start=1;
            @(negedge vif.clk); vif.direct_start=0;
            wait_idle();

            // A valid direct-start has no descriptor/CPLQ lifecycle. If the
            // compute engine reports an error, software receives an event;
            // no completion writer transaction or queue-pointer update is
            // permitted.
            vif.force_compute_error_once=1;
            @(negedge vif.clk); vif.direct_start=1;
            @(negedge vif.clk); vif.direct_start=0;
            wait(vif.event_valid===1'b1);
            if(!vif.event_error || vif.event_error_code!==4'd5 ||
               vif.event_result!==32'hc0de0001 || vif.event_elements!==32'd4 ||
               vif.completion_start || vif.cpl_spad_valid || vif.cpl_writer_busy ||
               vif.cmdq_head!==32'd0 || vif.cplq_tail!==32'd0)
              `uvm_error("CP/DIRECT","direct compute error did not report ERR_COMPUTE without completion/queue side effects")
            wait_idle();
            if(vif.force_compute_error_once)
              `uvm_error("CP/DIRECT","direct compute-error injection was not consumed")
            if(vif.cmdq_head!==0 || vif.cplq_tail!==0 || vif.cpl_writer_busy ||
               vif.busy || vif.launch_valid)
              `uvm_error("CP/DIRECT","direct-start lifecycle changed queue pointers or failed to return idle")

            // Deliberately leave ERR_ABORT in the code bus while deasserting
            // compute_error. The status qualifier, not the stale code, must
            // decide whether queue execution aborts.
            vif.force_stale_abort_code_once=1;
            @(negedge vif.clk); vif.direct_start=1;
            @(negedge vif.clk); vif.direct_start=0;
            wait(vif.event_valid===1'b1);
            if(vif.event_error || vif.event_error_code!==4'd0 ||
               vif.event_result!==32'hc0de0001 || vif.event_elements!==32'd4 ||
               vif.completion_start || vif.cpl_spad_valid || vif.cpl_writer_busy ||
               vif.cmdq_head!==32'd0 || vif.cplq_tail!==32'd0)
              `uvm_error("CP/DIRECT","stale ERR_ABORT code was not ignored on successful response")
            wait_idle();
            vif.force_stale_abort_code_once=0;
            if(vif.cmdq_head!==0 || vif.cplq_tail!==0 || vif.cpl_writer_busy ||
               vif.busy || vif.launch_valid)
              `uvm_error("CP/DIRECT","stale abort-code response did not return to idle without queue side effects")
            `uvm_info("CP/DIRECT","invalid_rejected=20 launches=5 events=4 direct_error_events=1 stale_abort_code_ignored=1 valid_ops=INT8,BF16,FP16 direct_error_code=5 direct_no_cplq_write=1 queue_unchanged=1 reasons=10 blocked_busy=1 fp_predicate_true_nonfp_bypass=1 launch_shift=1 success=1",UVM_LOW)
          end
          CP_MACRO_CHILDREN: begin
            reset_cp();
            // ABI v7 macro addresses use {src1,src0}; flag[3] routes only
            // child descriptors externally while the parent remains in CMDQ.
            vif.cmdq_base=64'h0000_0001_0000_1000;
            descriptor(0,0,0,0,1,16'h1500);
            vif.desc_mem[0].op=8'h40;
            vif.desc_mem[0].version=8'd7;
            vif.desc_mem[0].length=16'd3;
            vif.desc_mem[0].src0=32'h1040;
            vif.desc_mem[0].src1=32'h0000_0001;
            vif.desc_mem[0].flags=8'h08;
            descriptor(1,0,0,0,1,16'h1511);
            descriptor(2,0,0,0,1,16'h1512);
            descriptor(3,0,0,0,1,16'h1513);
            vif.cmdq_tail=1; vif.cplq_head=0;
            fork
              check_v7_macro_fetch_sequence();
              launch_queue(0,1);
            join
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.busy ||
               vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/MACRO","three-child macro did not retire as one parent command")

            // A compute error on the first macro child must use the regular
            // completion path when completion storage is available.
            vif.cmdq_base=64'h1000;
            reset_cp();
            descriptor(0,0,0,0,1,16'h1540);
            vif.desc_mem[0].op=8'h40;
            vif.desc_mem[0].version=8'd4;
            vif.desc_mem[0].length=16'd3;
            vif.desc_mem[0].src0=32'h1040;
            descriptor(1,0,0,0,1,16'h1541);
            descriptor(2,0,0,0,1,16'h1542);
            descriptor(3,0,0,0,1,16'h1543);
            vif.cmdq_tail=1; vif.cplq_head=0;
            vif.force_compute_error_once=1;
            launch_queue(0,1);
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.busy ||
               vif.cpl_writer_busy || vif.launch_valid || vif.force_compute_error_once)
              `uvm_error("CP/MACRO","compute-error macro did not fail-stop and commit one error parent completion")

            // A later child-fetch failure must be attributed to the macro
            // parent, preserve the completed prefix counters, and suppress
            // all children after the failed fetch.
            reset_cp();
            vif.cmdq_base=64'h1000;
            descriptor(0,0,0,0,1,16'h1550);
            vif.desc_mem[0].op=8'h40;
            vif.desc_mem[0].version=8'd4;
            vif.desc_mem[0].length=16'd3;
            vif.desc_mem[0].src0=32'h1040;
            descriptor(1,0,0,0,1,16'h1551);
            descriptor(2,0,0,0,1,16'h1552);
            descriptor(3,0,0,0,1,16'h1553);
            vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.busy ||
               vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/MACRO","child-fetch-error macro did not retire one parent completion")

            // Abort while fetching the first macro child descriptor. The
            // error record remains owned by the macro parent task, not child.
            reset_cp(); descriptor(0,0,0,0,1,16'h1560);
            vif.desc_mem[0].op=8'h40; vif.desc_mem[0].version=8'd4;
            vif.desc_mem[0].length=16'd3; vif.desc_mem[0].src0=32'h1040;
            descriptor(1,0,0,0,1,16'h1561);
            descriptor(2,0,0,0,1,16'h1562);
            descriptor(3,0,0,0,1,16'h1563);
            vif.cmdq_tail=1; vif.cplq_head=0; vif.abort_cov_path=2'd2;
            pulse_submit();
            wait(vif.fetch_done===1'b1);
            wait(vif.fetch_start===1'b1);
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.launch_valid ||
               vif.cpl_writer_busy)
              `uvm_error("CP/MACRO","macro child-fetch abort launched a child or failed parent retirement")
            vif.abort_cov_path=0;

            // Abort in ST_DECODE after the first macro child fetch response.
            reset_cp(); descriptor(0,0,0,0,1,16'h1570);
            vif.desc_mem[0].op=8'h40; vif.desc_mem[0].version=8'd4;
            vif.desc_mem[0].length=16'd3; vif.desc_mem[0].src0=32'h1040;
            descriptor(1,0,0,0,1,16'h1571);
            descriptor(2,0,0,0,1,16'h1572);
            descriptor(3,0,0,0,1,16'h1573);
            vif.cmdq_tail=1; vif.cplq_head=0; vif.abort_cov_path=2'd3;
            pulse_submit();
            wait(vif.fetch_done===1'b1);
            @(posedge vif.clk);
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.launch_valid ||
               vif.cpl_writer_busy)
              `uvm_error("CP/MACRO","macro child-decode abort launched a child or failed parent retirement")
            vif.abort_cov_path=0;

            // Legacy no-CPLQ event path: a successful macro aggregates its
            // ordered children into one event without completion writeback.
            reset_cp();
            descriptor(0,0,0,0,1,16'h1520);
            vif.desc_mem[0].op=8'h40;
            vif.desc_mem[0].version=8'd4;
            vif.desc_mem[0].length=16'd3;
            vif.desc_mem[0].src0=32'h1040;
            descriptor(1,0,0,0,1,16'h1521);
            descriptor(2,0,0,0,1,16'h1522);
            descriptor(3,0,0,0,1,16'h1523);
            vif.cmdq_size=0; vif.cplq_size=0; vif.cmdq_tail=1; vif.cplq_head=0;
            pulse_submit();
            wait(vif.event_valid===1'b1);
            if(vif.event_error || vif.event_error_code!==4'd0 ||
               vif.event_result!==32'hc0de0001 || vif.event_cycles!==32'd51 ||
               vif.event_elements!==32'd12 || vif.cmdq_head!==32'd1 ||
               vif.cplq_tail!==32'd0 || vif.cpl_spad_valid ||
               vif.cpl_writer_busy || vif.launch_valid)
            `uvm_error("CP/NO_CPLQ","successful three-child macro without CPLQ did not emit one aggregate event")
            wait_idle();

            // The first child fails. The parent must report that error and
            // fail-stop without fetching or launching later children.
            reset_cp();
            descriptor(0,0,0,0,1,16'h1530);
            vif.desc_mem[0].op=8'h40;
            vif.desc_mem[0].version=8'd4;
            vif.desc_mem[0].length=16'd3;
            vif.desc_mem[0].src0=32'h1040;
            descriptor(1,0,0,0,1,16'h1531);
            descriptor(2,0,0,0,1,16'h1532);
            descriptor(3,0,0,0,1,16'h1533);
            vif.cmdq_size=0; vif.cplq_size=0; vif.cmdq_tail=1; vif.cplq_head=0;
            vif.force_compute_error_once=1;
            pulse_submit();
            wait(vif.event_valid===1'b1);
            if(!vif.event_error || vif.event_error_code!==4'd5 ||
               vif.event_result!==32'hc0de0001 || vif.event_cycles!==32'd17 ||
               vif.event_elements!==32'd4 || vif.cmdq_head!==32'd1 ||
               vif.cplq_tail!==32'd0 || vif.cpl_spad_valid ||
               vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/NO_CPLQ","macro child error without CPLQ did not fail-stop with one event")
            wait_idle();
            if(vif.force_compute_error_once)
              `uvm_error("CP/NO_CPLQ","macro compute-error injection was not consumed")
            vif.cmdq_size=4; vif.cplq_size=4;
            `uvm_info("CP/MACRO","children=3 parent_completion=5 compute_error_child_launches=1 fetch_error_child_launches=1 fetch_error_parent_completion=1 child_fetch_abort_parent=1 child_decode_abort_parent=1 no_cplq_success_children=3 no_cplq_error_stop=1",UVM_LOW)
          end
          CP_FETCH_ERROR_NO_CPL: begin
            reset_cp();
            descriptor(0,0,0,0,1,16'h1601);
            // Size-zero queues exercise the legacy pointer behavior preserved
            // by the RTL helper. This test does not declare it a new ABI rule.
            vif.cmdq_size=0; vif.cmdq_tail=1; vif.cplq_head=0; vif.cplq_size=0;
            @(negedge vif.clk); vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            @(negedge vif.clk); vif.cmdq_head_load=0;
            pulse_submit();
            wait(vif.event_valid===1'b1);
            if(!vif.event_error || vif.event_error_code!==4'd6 ||
               vif.event_result!==32'd0 || vif.event_elements!==32'd0 ||
               vif.cmdq_head!==32'd1 || vif.cplq_tail!==32'd0 ||
               vif.launch_valid || vif.cpl_spad_valid || vif.cpl_writer_busy)
              `uvm_error("CP/NO_CPLQ","disabled-CPLQ fetch error did not report one event without launch/writeback")
            wait_idle();
            vif.cmdq_size=4; vif.cplq_size=4;
            `uvm_info("CP/NO_CPLQ","fetch_error_event=1 launch=0 completion_write=0 head_advance=1",UVM_LOW)
            // Second legacy route: a fetched invalid descriptor reports ERR_DESC.
            reset_cp(); descriptor(0,1); vif.cmdq_size=0; vif.cplq_size=0; vif.cmdq_tail=1;
            // The fetch responder injects ERR_FETCH for CP_FETCH_ERROR_NO_CPL;
            // select the normal invalid-descriptor response for this second transaction.
            vif.test_case=CP_INVALID;
            pulse_submit(); wait(vif.event_valid===1'b1);
            if(!vif.event_valid || !vif.event_error || vif.event_error_code!==4'd7 ||
               vif.cpl_spad_valid || vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/NO_CPLQ",$sformatf("invalid descriptor without CPLQ: event_valid=%0b event_error=%0b code=%0d cpl_spad_valid=%0b cpl_writer_busy=%0b launch_valid=%0b cmdq_head=%0d",
                vif.event_valid,vif.event_error,vif.event_error_code,vif.cpl_spad_valid,
                vif.cpl_writer_busy,vif.launch_valid,vif.cmdq_head))
            `uvm_info("CP/NO_CPLQ","invalid_desc_event=1 completion_write=0 launch=0",UVM_LOW)
            wait_idle();
            vif.cmdq_size=4; vif.cplq_size=4;
          end
          CP_EMPTY: begin
            reset_cp();
            vif.cmdq_tail=0; vif.cplq_head=0;
            pulse_submit();
            repeat(3) @(posedge vif.clk);
            if(vif.busy || vif.launch_valid || vif.fetch_start)
              `uvm_error("CP/DRV","empty CMDQ was not rejected without launch/fetch")
          end
          CP_CPL_FULL: begin
            reset_cp();
            descriptor(0);
            vif.cmdq_tail=1; vif.cplq_head=1; // tail=0, next=1 => full
            pulse_submit();
            repeat(3) @(posedge vif.clk);
            if(vif.busy || vif.launch_valid || vif.fetch_start)
              `uvm_error("CP/DRV","full CPLQ was not rejected without launch/fetch")
          end
          CP_CPLQ_PRESSURE: begin
            reset_cp();
            @(negedge vif.clk);
            vif.cplq_head=0;
            descriptor(0,0,0,0,1,16'h3000);
            descriptor(1,0,0,0,1,16'h3001);
            descriptor(2,0,0,0,1,16'h3002);
            vif.cmdq_tail=3;
            pulse_submit();

            // Fill the 4-slot CPLQ to its 3-entry usable capacity.
            wait_cplq_tail(1);
            wait_cplq_tail(3);
            wait_idle();
            if(vif.cmdq_head!==3 || vif.cmdq_tail!==3 ||
               vif.cplq_tail!==3 || vif.busy || vif.cpl_writer_busy)
              `uvm_error("CP/CPLQ","completion ring did not reach full after three records")

            // Stream five more commands through the wrapped CMDQ. Each
            // command is published while CPLQ is full; it must remain idle
            // until software consumes one entry and re-rings the doorbell.
            for(int command_idx=3;command_idx<8;command_idx++) begin
              int slot;
              logic [31:0] expected_cpl_tail;
              @(negedge vif.clk);
              slot=command_idx%4;
              descriptor(slot,0,0,0,1,16'h3000+command_idx);
              vif.cmdq_tail=(command_idx+1)%4;
              expected_cpl_tail=(vif.cplq_tail+1)%4;

              repeat(6) begin
                @(posedge vif.clk);
                if(vif.fetch_start || vif.launch_valid || vif.completion_start ||
                   vif.cplq_tail!==((command_idx+0)%4) ||
                   vif.cmdq_head!==(command_idx%4))
                  `uvm_error("CP/CPLQ","published command advanced while CPLQ remained full")
              end

              @(negedge vif.clk);
              vif.cplq_head=(vif.cplq_head+1)%4;
              pulse_submit();
              wait_cplq_tail(expected_cpl_tail);
              wait_idle();
              if(vif.cmdq_head!==vif.cmdq_tail ||
                 ((vif.cplq_tail+1)%4)!==vif.cplq_head ||
                 vif.busy || vif.cpl_writer_busy || vif.launch_valid)
                `uvm_error("CP/CPLQ","queue did not re-fill and hold after recovery round")
            end

            if(vif.cmdq_head!==0 || vif.cmdq_tail!==0 || vif.cplq_tail!==0 ||
               vif.cplq_head!==1 || vif.busy || vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/CPLQ","repeated full/release/re-doorbell rounds ended at unexpected pointers")
            `uvm_info("CP/CPLQ","prefill=3 held=5 resumed=5 completions=8 cmdq_wraps=2 cplq_wraps=2",UVM_LOW)
          end
          CP_COMPLETION_PROT_LATE: begin
            reset_cp();
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            pulse_submit();
            wait(vif.launch_valid);
            wait(vif.compute_busy);
            @(negedge vif.clk);
            vif.completion_protected=1;
            wait(vif.event_valid===1'b1);
            if(!vif.event_error || vif.event_error_code!==4'd10 ||
               vif.event_result!==32'hc0de0001 || vif.event_cycles!==32'd17 ||
               vif.event_elements!==32'd4 || vif.cpl_spad_valid ||
               vif.cpl_writer_busy || vif.cplq_tail!==32'd0 ||
               vif.cmdq_head!==32'd1)
              `uvm_error("CP/CPL_PROTECTION","late completion protection did not reject writeback exactly once")
            `uvm_info("CP/CPL_PROTECTION","late_protection_abort=1 err_prot=1 completion_write=0 tail_unchanged=1",UVM_LOW)
            @(negedge vif.clk);
            vif.completion_protected=0;
            wait_idle();
          end
          CP_FSM_FAULT_RECOVERY: begin
            reset_cp();
            @(negedge vif.clk); vif.inject_illegal_fsm_state=1;
            wait(vif.illegal_fsm_state_recovered===1'b1);
            @(negedge vif.clk); vif.inject_illegal_fsm_state=0;
            repeat(2) @(posedge vif.clk);
            if(vif.debug_state_r!==4'd0 || vif.busy || vif.fetch_start ||
               vif.launch_valid || vif.event_valid || vif.cpl_spad_valid ||
               vif.cpl_writer_busy)
              `uvm_error("CP/FSM","illegal FSM state did not recover cleanly to IDLE")
            `uvm_info("CP/FSM","illegal_state_injected=1 recovered_idle=1 side_effects=0",UVM_LOW)
          end
          CP_SUBMIT_GUARD: begin
            int head_before,tail_before,wait_cycles;
            reset_cp();
            descriptor(0); descriptor(1); vif.cmdq_tail=2; vif.cplq_head=0;

            // First tuple: while the command is in ST_FETCH, a second
            // submit must be ignored and must not re-admit the same queue
            // entry or generate another fetch/launch side effect.
            pulse_submit();
            wait(vif.fetch_start===1'b1);
            if(vif.debug_state_r!==4'd1)
              `uvm_error("CP/SUBMIT_GUARD","initial submit did not enter ST_FETCH")
            head_before=vif.cmdq_head;
            pulse_submit();
            repeat(2) begin
              @(posedge vif.clk);
              if(vif.fetch_start || vif.launch_valid || vif.cmdq_head!==head_before)
                `uvm_error("CP/SUBMIT_GUARD","submit in ST_FETCH caused re-admission side effect")
            end
            wait_idle();
            if(vif.cmdq_head!==2)
              `uvm_error("CP/SUBMIT_GUARD","guarded fetch did not drain both queued commands")

            // Fourth tuple: keep the active descriptor blocked in ST_DECODE
            // with the next ring entry still queued. Resources are idle here,
            // so a fresh doorbell must still be ignored outside ST_IDLE.
            reset_cp();
            descriptor(0,0,16'h0002,0,1,16'h27d0); descriptor(1);
            vif.cmdq_tail=2; vif.cplq_head=0;
            pulse_submit();
            wait_cycles=0;
            while(vif.debug_state_r!==4'd2 && wait_cycles<100) begin
              @(posedge vif.clk); wait_cycles++;
            end
            if(wait_cycles>=100 || !vif.busy || vif.fetch_busy ||
               vif.compute_busy || vif.dma_busy)
              `uvm_fatal("CP/SUBMIT_GUARD","command did not reach idle-resource dependency wait")
            head_before=vif.cmdq_head; tail_before=vif.cplq_tail;
            pulse_submit();
            repeat(2) begin
              @(posedge vif.clk);
              if(vif.debug_state_r!==4'd2 || !vif.busy || vif.fetch_start ||
                 vif.launch_valid || vif.cmdq_head!==head_before ||
                 vif.cplq_tail!==tail_before)
                `uvm_error("CP/SUBMIT_GUARD","submit in idle-resource ST_DECODE caused re-admission")
            end
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.fetch_start ||
               vif.launch_valid || vif.cpl_writer_busy)
              `uvm_error("CP/SUBMIT_GUARD","decode submit-guard cleanup did not retire once")

            // Second tuple: force scheduler_resources_idle low at ST_IDLE.
            // The doorbell is ignored until the externally busy resource is
            // released, then a fresh submit must process normally.
            reset_cp();
            descriptor(0); descriptor(1); vif.cmdq_tail=2; vif.cplq_head=0;
            @(negedge vif.clk); vif.dma_busy=1;
            head_before=vif.cmdq_head;

            // A tile doorbell is also ignored while the command processor is
            // idle but a shared scheduler resource is busy. This exercises
            // the negative side of tile_start && scheduler_resources_idle.
            @(negedge vif.clk); vif.tile_start=1;
            @(negedge vif.clk); vif.tile_start=0;
            @(negedge vif.clk);
            if(vif.busy || vif.debug_state_r==4'd5 || vif.tile_active ||
               vif.tile_dma_start || vif.fetch_start || vif.launch_valid ||
               vif.cmdq_head!==head_before)
              `uvm_error("CP/SUBMIT_GUARD","tile_start while scheduler resource busy caused side effect")

            pulse_submit();
            repeat(3) begin
              @(posedge vif.clk);
              if(vif.fetch_start || vif.launch_valid || vif.cmdq_head!==head_before)
                `uvm_error("CP/SUBMIT_GUARD","submit while scheduler resource busy was admitted")
            end
            @(negedge vif.clk); vif.dma_busy=0;
            pulse_submit();
            wait_idle();
            if(vif.cmdq_head!==2 || vif.launch_valid)
              `uvm_error("CP/SUBMIT_GUARD","submit was not accepted after scheduler became idle")

            // Third tuple: abort is pulsed while the shared completion writer
            // is stalled in ST_CPL. The partially accepted record must remain
            // stable and later commit exactly once after backpressure clears.
            reset_cp();
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            @(negedge vif.clk); vif.force_completion_backpressure=1;
            pulse_submit();
            wait_cycles=0;
            while(!(vif.debug_state_r==4'd4 && vif.cpl_writer_busy &&
                    vif.cpl_spad_valid && !vif.cpl_spad_ready) && wait_cycles<1000) begin
              @(posedge vif.clk); wait_cycles++;
            end
            if(wait_cycles>=1000)
              `uvm_fatal("CP/SUBMIT_GUARD","completion writer did not reach the forced backpressure window")
            head_before=vif.cmdq_head; tail_before=vif.cplq_tail;
            @(negedge vif.clk); vif.abort=1;
            @(negedge vif.clk); vif.abort=0;
            repeat(2) begin
              @(posedge vif.clk);
              if(vif.debug_state_r!==4'd4 || !vif.cpl_writer_busy ||
                 vif.cplq_tail!==tail_before || vif.cmdq_head!==head_before ||
                 vif.launch_valid || !vif.cpl_spad_valid || vif.cpl_spad_ready)
                `uvm_error("CP/SUBMIT_GUARD","abort truncated or changed a stalled completion")
            end
            @(negedge vif.clk); vif.force_completion_backpressure=0;
            wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.busy ||
               vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/SUBMIT_GUARD","completion did not retire exactly once after ignored abort")
            `uvm_info("CP/SUBMIT_GUARD","fetch_resubmit_ignored=1 decode_resubmit_ignored=1 scheduler_busy_ignored=1 tile_busy_ignored=1 completion_abort_ignored=1 recovery=1",UVM_LOW)
          end
          CP_WRITER_FSM_FAULT_RECOVERY: begin
            reset_cp();
            vif.illegal_writer_state_recovered=0;
            @(negedge vif.clk); vif.inject_illegal_writer_state=1;
            wait(vif.debug_writer_state_r===2'b11);
            if(vif.cpl_writer_busy || vif.cpl_writer_done || vif.cpl_spad_valid ||
               vif.cplq_tail!==0 || vif.cmdq_head!==0)
              `uvm_error("CP/WRITER_FSM","illegal writer state produced a visible side effect")
            wait(vif.illegal_writer_state_recovered===1'b1);
            @(negedge vif.clk); vif.inject_illegal_writer_state=0;
            repeat(2) @(posedge vif.clk);
            if(vif.debug_writer_state_r!==2'd0 || vif.cpl_writer_busy ||
               vif.cpl_writer_done || vif.cpl_spad_valid ||
               vif.cplq_tail!==0 || vif.cmdq_head!==0)
              `uvm_error("CP/WRITER_FSM","illegal writer state did not recover to idle without side effects")

            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            pulse_submit(); wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.cpl_writer_busy ||
               vif.debug_writer_state_r!==2'd0)
              `uvm_error("CP/WRITER_FSM","valid completion did not recover after illegal-state injection")
            `uvm_info("CP/WRITER_FSM","illegal_state_injected=1 recovered_idle=1 side_effects=0 recovery_completion=1",UVM_LOW)
          end
          CP_ZERO_SIZE_EMPTY_FETCH: begin
            int fetch_wait_cycles;
            reset_cp();
            descriptor(0,0,0,0,1,16'h1900);
            vif.cmdq_size=0;
            vif.cmdq_tail=0;
            vif.cplq_size=4; vif.cplq_head=0;
            if(vif.cmdq_size!==0 || vif.cmdq_head!==0 || vif.cmdq_head!==vif.cmdq_tail)
              `uvm_error("CP/ZERO_SIZE_EMPTY","stimulus did not present size-zero equal-pointer CMDQ")
            pulse_submit();
            fetch_wait_cycles=0;
            while(vif.fetch_start!==1'b1 && fetch_wait_cycles<100) begin
              @(negedge vif.clk); fetch_wait_cycles++;
            end
            if(vif.fetch_start!==1'b1)
              `uvm_error("CP/ZERO_SIZE_EMPTY","size-zero equal-pointer submission did not fetch descriptor")
            else if(vif.fetch_base!==64'h1000 || vif.fetch_external!==1'b0)
              `uvm_error("CP/ZERO_SIZE_EMPTY","compatibility descriptor fetch used unexpected address or mode")
            wait_idle();
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.launch_valid ||
               vif.cpl_writer_busy || vif.cplq_size!==4)
              `uvm_error("CP/ZERO_SIZE_EMPTY","size-zero CMDQ did not complete normally with CPLQ tail=1")
            `uvm_info("CP/ZERO_SIZE_EMPTY","cmdq_size=0 equal_pointers=1 compatibility_fetch=1 completion_task_id=1900 CPLQ_tail=1",UVM_LOW)
          end
          CP_CPLQ_LAST_SLOT_QUEUE: begin
            reset_cp();
            vif.cmdq_size=4; vif.cplq_size=4;
            descriptor(0,0,0,0,1,16'h1910);
            descriptor(1,0,0,0,1,16'h1911);
            vif.cmdq_tail=2;
            vif.cplq_head=0;
            @(negedge vif.clk);
            vif.cplq_tail_seed=2;
            vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cplq_tail_load=0;

            // Two old records occupy a four-entry ring, leaving exactly one
            // usable completion slot for the two-command queue publication.
            pulse_submit();
            wait_cplq_tail(3);
            wait_idle();
            if(vif.cplq_head!==0 || vif.cmdq_head!==1 || vif.cmdq_tail!==2 ||
               ((vif.cplq_tail+1)%4)!==vif.cplq_head || vif.fetch_start ||
               vif.launch_valid || vif.busy || vif.cpl_writer_busy)
              `uvm_error("CP/CPLQ_LAST_SLOT","queue did not hold the second command when the first completion filled CPLQ")

            // Software consumes one record and re-rings the doorbell. The
            // remaining command must then retire exactly once across wrap.
            @(negedge vif.clk);
            vif.cplq_head=1;
            pulse_submit();
            wait_cplq_tail(0);
            wait_idle();
            if(vif.cplq_head!==1 || vif.cmdq_head!==2 || vif.cmdq_tail!==2 ||
               vif.cplq_tail!==0 || vif.busy || vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/CPLQ_LAST_SLOT","re-doorbell did not retire the held command exactly once")
            `uvm_info("CP/CPLQ_LAST_SLOT","queued=2 initial_free_slots=1 first_completion_filled_ring=1 second_held=1 red-doorbell_recovery=1 cpl_tail=2->3->0 cmdq_head=1->2",UVM_LOW)
          end
          CP_FETCH_ERROR: begin
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
          end
          CP_COMPUTE_ERROR: begin
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
          end
          CP_PARTIAL_RESET: begin
            int reset_words_target;
            int reset_words_observed;
            reset_cp();
            if(!$value$plusargs("CP_RESET_WORDS=%d",reset_words_target))
              reset_words_target=1;
            if(reset_words_target<0 || reset_words_target>3)
              `uvm_fatal("CP/PARTIAL_RESET_CFG",
                $sformatf("CP_RESET_WORDS=%0d is outside range 0..3",reset_words_target))
            vif.partial_reset_target_words=reset_words_target[1:0];
            vif.partial_reset_sweep_active=1'b1;
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            @(negedge vif.clk);
            vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();
            wait(vif.cpl_spad_valid && !vif.cpl_spad_ready &&
                 vif.cpl_spad_addr[3:2]==reset_words_target[1:0]);
            @(negedge vif.clk);
            reset_words_observed=vif.partial_reset_write_count;
            if(reset_words_observed!=reset_words_target)
              `uvm_error("CP/PARTIAL_RESET",
                $sformatf("accepted %0d completion words before reset; expected %0d",
                          reset_words_observed,reset_words_target))
            if(vif.cplq_tail!==0 || !vif.cpl_writer_busy || !vif.cpl_spad_valid ||
               vif.cpl_spad_ready)
              `uvm_error("CP/PARTIAL_RESET",
                "tail advanced or writer did not stall at the selected completion word")
            reset_cp();
            if(!vif.partial_reset_done || vif.partial_reset_write_count!=0 ||
               vif.busy || vif.cpl_writer_busy || vif.cpl_writer_done ||
               vif.cmdq_head!==0 || vif.cplq_tail!==0)
              `uvm_error("CP/PARTIAL_RESET",
                $sformatf("reset cleanup mismatch done=%b accepted=%0d cp_busy=%b writer_busy=%b writer_done=%b cmdq_head=%0d cplq_tail=%0d",
                  vif.partial_reset_done,vif.partial_reset_write_count,vif.busy,
                  vif.cpl_writer_busy,vif.cpl_writer_done,vif.cmdq_head,vif.cplq_tail))
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            launch_queue(0,1);
            if(vif.cmdq_head!==1 || vif.cplq_tail!==1 || vif.busy ||
               vif.cpl_writer_busy || vif.cpl_writer_done)
              `uvm_error("CP/PARTIAL_RESET",
                "post-reset recovery did not commit exactly one completion")
            `uvm_info("CP/PARTIAL_RESET",
              $sformatf("accepted_before_reset=%0d reset_cleared=1 recovery_completions=1 tail=1",
                        reset_words_observed),UVM_LOW)
            vif.partial_reset_sweep_active=1'b0;
          end
          CP_EXTERNAL_DESC: begin
            reset_cp();
            descriptor(0); vif.cmdq_tail=1; vif.cplq_head=0;
            vif.desc_external=1;
            launch_queue(0,1);
            vif.desc_external=0;
          end
          CP_DEP_TIMEOUT: begin
            reset_cp();
            descriptor(0,0,16'h0002,0);
            vif.cmdq_tail=1; vif.cplq_head=0;
            @(negedge vif.clk);
            vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();
            repeat(8) @(posedge vif.clk);
            if(!vif.busy || vif.launch_valid || vif.desc_wait_mask!==16'h0002)
              `uvm_error("CP/DRV","unmet dependency did not remain blocked before timeout")
            wait_idle();
            // Repeat the timeout through the legacy event route after reset.
            reset_cp(); descriptor(0,0,16'h0002,0); vif.cmdq_size=0; vif.cplq_size=0; vif.cmdq_tail=1;
            pulse_submit(); wait(vif.event_valid===1'b1);
            if(!vif.event_valid || !vif.event_error || vif.event_error_code!==4'd12 ||
               vif.cpl_spad_valid || vif.cpl_writer_busy || vif.launch_valid)
              `uvm_error("CP/NO_CPLQ","dependency timeout without CPLQ did not produce only ERR_DEPENDENCY event")
            `uvm_info("CP/NO_CPLQ","dep_timeout_event=1 completion_write=0 launch=0",UVM_LOW)
            wait_idle();
            vif.cmdq_size=4; vif.cplq_size=4;
          end
          CP_CONCURRENT_RING: begin
            reset_cp();
            descriptor(0); descriptor(1);
            vif.cmdq_tail=1; vif.cplq_head=0; vif.desc_external=0;
            @(negedge vif.clk);
            vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();
            wait(vif.launch_valid);
            @(negedge vif.clk); vif.cmdq_tail=2;
            wait(vif.cplq_tail==1);
            @(negedge vif.clk); vif.cplq_head=1;
            wait_idle();
            if(vif.cmdq_head!==2 || vif.cplq_tail!==2)
              `uvm_error("CP/DRV","concurrent CMDQ publish/CPLQ consume did not retire both entries")
          end
          CP_TILE_PINGPONG: begin
            reset_cp();
            vif.tile_count=3;
            vif.tile_ext_input_base=64'h0001_0000;
            vif.tile_ext_output_base=64'h0002_0000;
            vif.tile_ext_input_stride=32'h40;
            vif.tile_ext_output_stride=32'h10;
            vif.tile_buffer0_base=32'h400;
            vif.tile_buffer1_base=32'h800;
            vif.tile_output_offset=32'h20;
            vif.tile_input_words=4;
            vif.tile_output_words=1;
            @(negedge vif.clk); vif.tile_start=1;
            @(negedge vif.clk); vif.tile_start=0;
            wait_idle();
            if(vif.tile_completed!==3 || vif.tile_active)
              `uvm_error("CP/DRV","three-tile ping-pong job did not retire cleanly")
            if(vif.tile_perf_overlap==0)
              `uvm_error("CP/DRV","tile ping-pong job showed no DMA/compute overlap")
          end
          CP_RANDOM_QUEUE: begin
            int observed_cpl_tail, retired_count, delay_cycles;
            int total_commands, published_commands, producer_tail;
            logic [1:0] failure_kind;
            reset_cp();
            total_commands=$urandom_range(12,24);
            vif.random_queue_count=total_commands;
            vif.random_queue_error_mask=0;
            vif.random_queue_failure_kind=0;
            // Force every seed to mix descriptor, fetch, and compute errors
            // with successful work before randomizing subsequent outcomes.
            descriptor(0,1,0,0,1,16'h2000);
            vif.random_queue_error_mask[0]=1'b1;
            vif.random_queue_failure_kind[1:0]=2'd1;
            vif.cmdq_tail=1; vif.cplq_head=0;
            @(negedge vif.clk);
            vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk);
            vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            pulse_submit();
            published_commands=1; producer_tail=1;
            fork
              begin : producer_process
                while(published_commands<total_commands) begin
                  delay_cycles=$urandom_range(0,2);
                  repeat(delay_cycles) @(negedge vif.clk);
                  if(((producer_tail+1)%4)!=vif.cmdq_head) begin
                    case (published_commands)
                      1: failure_kind=2'd2; // fetch error
                      2: failure_kind=2'd3; // compute error
                      3: failure_kind=2'd0; // successful progress after errors
                      default: failure_kind=$urandom_range(0,3);
                    endcase
                    descriptor(producer_tail,(failure_kind==2'd1),0,0,1,
                               16'h2000+published_commands);
                    vif.random_queue_error_mask[published_commands]=(failure_kind==2'd1);
                    vif.random_queue_failure_kind[(published_commands*2) +: 2]=failure_kind;
                    producer_tail=(producer_tail+1)%4;
                    vif.cmdq_tail=producer_tail;
                    published_commands++;
                  end else begin
                    @(negedge vif.clk);
                  end
                end
              end
              begin : consumer_process
                observed_cpl_tail=0; retired_count=0;
                while(retired_count<total_commands) begin
                  @(negedge vif.clk);
                  if(vif.cplq_tail!=observed_cpl_tail) begin
                    observed_cpl_tail=vif.cplq_tail;
                    retired_count++;
                    repeat($urandom_range(0,2)) @(negedge vif.clk);
                    vif.cplq_head=observed_cpl_tail;
                  end
                end
              end
            join
            wait_idle();
            if(vif.cmdq_head!==(total_commands%4) ||
               vif.cplq_tail!==(total_commands%4) ||
               vif.cplq_head!==(total_commands%4))
              `uvm_error("CP/DRV","randomized ring traffic ended at unexpected pointers")
          end
          CP_RESET: begin
            descriptor(0); vif.cmdq_head_seed=0; vif.cmdq_head_load=1;
            vif.cplq_tail_seed=0; vif.cplq_tail_load=1;
            @(negedge vif.clk); vif.cmdq_head_load=0; vif.cplq_tail_load=0;
            vif.cmdq_tail=1; vif.cplq_head=0; pulse_submit();
            repeat(3) @(negedge vif.clk); vif.resetn=0; repeat(3) @(negedge vif.clk);
            vif.resetn=1; repeat(3) @(posedge vif.clk);
            if(vif.busy || vif.cpl_writer_busy) `uvm_error("CP/DRV","reset did not quiesce")
          end
        endcase
        seq_item_port.item_done();
      end
    endtask
  endclass

  class ai_cp_scoreboard extends uvm_component;
    `uvm_component_utils(ai_cp_scoreboard)
    virtual ai_cp_if vif; int launches, writes, completions, invalid_launches, dep_abort_records;
    int fetch_abort_records, fetch_abort_launches;
    int abort_reset_inputs, abort_reset_recovery_launches, abort_reset_recovery_records;
    int compute_abort_records, compute_abort_launches, compute_abort_inputs;
    int fetch_error_records, compute_error_records, partial_reset_records;
    int mixed_completion_starts, mixed_abort_inputs;
    int mixed_abort_words_accepted, mixed_reset_checks, mixed_recovery_records;
    int submit_guard_completion_index;
    int dependency_timeout_records, external_fetches;
    int concurrent_launches, concurrent_records, concurrent_completion_index;
    int direct_launches, direct_events, direct_invalid_events;
    int direct_compute_error_events;
    int direct_stale_abort_code_events;
    int macro_launches, macro_error_launches, macro_fetch_error_launches;
    int macro_completions, macro_error_completions, macro_fetch_error_completions;
    int macro_no_cplq_launches, macro_no_cplq_success_events, macro_no_cplq_error_events;
    int no_cplq_fetch_events, late_completion_protection_events;
    int tile_ctx_state[2], tile_ctx_tile[2];
    int tile_next_load, tile_next_compute, tile_next_store;
    int tile_loads, tile_computes, tile_stores, tile_overlap_cycles, tile_events;
    int tile_load_buffer_hits[2], tile_compute_buffer_hits[2], tile_store_buffer_hits[2];
    int tile_dma_owner, tile_compute_owner;
    bit tile_dma_pending, tile_dma_store_pending, tile_compute_pending, tile_model_started;
    logic [15:0] random_launch_expected[$], random_retire_expected[$];
    logic [1:0] random_outcome_expected[$], random_completion_kind;
    int random_fetch_index, random_launch_count, random_retire_count;
    int random_error_count, random_valid_count;
    int random_invalid_count, random_fetch_fail_count, random_compute_fail_count;
    bit random_model_started;
    int cplq_pressure_fetches, cplq_pressure_launches, cplq_pressure_completions;
    bit cplq_pressure_model_started;
    int cplq_last_slot_launches, cplq_last_slot_completions;
    int empty_rejects, cpl_full_rejects;
    int word_index; int writes_in_record; int dependency_completion_index;
    logic [31:0] tail_at_record_start, expected_tail_after_done;
    bit tail_commit_pending;
    logic [31:0] addr_q[$],data_q[$];
    function new(string n,uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); if(!uvm_config_db#(virtual ai_cp_if)::get(this,"","vif",vif)) `uvm_fatal("CP/MON","vif missing")
    endfunction
    task run_phase(uvm_phase phase);
      word_index=0; writes_in_record=0; dependency_completion_index=0;
      tail_at_record_start=0; expected_tail_after_done=0; tail_commit_pending=0;
      concurrent_launches=0; concurrent_records=0; concurrent_completion_index=0;
      compute_abort_records=0; compute_abort_launches=0; compute_abort_inputs=0;
      mixed_completion_starts=0; submit_guard_completion_index=0;
      mixed_abort_inputs=0;
      mixed_abort_words_accepted=0; mixed_reset_checks=0; mixed_recovery_records=0;
      direct_launches=0; direct_events=0; direct_invalid_events=0;
      direct_compute_error_events=0;
      direct_stale_abort_code_events=0;
      macro_launches=0; macro_error_launches=0; macro_fetch_error_launches=0;
      macro_completions=0; macro_error_completions=0;
      macro_fetch_error_completions=0;
      macro_no_cplq_launches=0; macro_no_cplq_success_events=0;
      macro_no_cplq_error_events=0;
      no_cplq_fetch_events=0;
      late_completion_protection_events=0;
      abort_reset_inputs=0; abort_reset_recovery_launches=0;
      abort_reset_recovery_records=0;
      tile_next_load=0; tile_next_compute=0; tile_next_store=0;
      tile_loads=0; tile_computes=0; tile_stores=0; tile_overlap_cycles=0; tile_events=0;
      foreach(tile_ctx_state[i]) begin
        tile_ctx_state[i]=0; tile_ctx_tile[i]=-1;
        tile_load_buffer_hits[i]=0; tile_compute_buffer_hits[i]=0; tile_store_buffer_hits[i]=0;
      end
      tile_dma_owner=-1; tile_compute_owner=-1;
      tile_dma_pending=0; tile_dma_store_pending=0; tile_compute_pending=0; tile_model_started=0;
      random_fetch_index=0; random_launch_count=0; random_retire_count=0;
      random_error_count=0; random_valid_count=0; random_completion_kind=0;
      random_invalid_count=0; random_fetch_fail_count=0; random_compute_fail_count=0;
      random_launch_expected.delete(); random_retire_expected.delete();
      random_outcome_expected.delete(); random_model_started=0;
      cplq_pressure_fetches=0; cplq_pressure_launches=0;
      cplq_pressure_completions=0; cplq_pressure_model_started=0;
      cplq_last_slot_launches=0; cplq_last_slot_completions=0;
      forever begin @(posedge vif.clk); if(vif.resetn) begin
        if(vif.test_case==CP_COMPUTE_ABORT && vif.compute_done &&
           vif.compute_error && vif.compute_error_code==4'd3)
          compute_abort_inputs++;
        if((vif.test_case==CP_ABORT_RESET_PARTIAL ||
            vif.test_case==CP_MIXED_ERROR_ABORT_RESET) && vif.compute_done &&
           vif.compute_error && vif.compute_error_code==4'd3)
          abort_reset_inputs++;
        if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET && vif.compute_done &&
           vif.compute_error && vif.compute_error_code==4'd3)
          mixed_abort_inputs++;
        if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET && vif.completion_start) begin
          logic [15:0] expected_task_id;
          case(mixed_completion_starts)
            0: begin
              expected_task_id=16'h1400;
              if(vif.mixed_prefix_failure_kind==2'd1 &&
                 (vif.completion_error!==4'd7 || vif.completion_status!==4'd2))
                `uvm_error("CP/MIXED","invalid-descriptor prefix start has wrong status/error")
              if(vif.mixed_prefix_failure_kind==2'd2 &&
                 (vif.completion_error!==4'd6 || vif.completion_status!==4'd2))
                `uvm_error("CP/MIXED","fetch-error prefix start has wrong status/error")
            end
            1: begin
              expected_task_id=16'h1401;
              if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                `uvm_error("CP/MIXED","compute-abort completion start has wrong status/error")
            end
            2: begin
              expected_task_id=16'h1403;
              if(vif.completion_error!==4'd0 || vif.completion_status!==4'd1)
                `uvm_error("CP/MIXED","post-reset recovery completion start has wrong status/error")
            end
            default: begin
              expected_task_id=16'hffff;
              `uvm_error("CP/MIXED","unexpected extra completion start")
            end
          endcase
          if(vif.completion_task_id!==expected_task_id)
            `uvm_error("CP/MIXED",$sformatf("completion start task ID got=%04x expected=%04x",
              vif.completion_task_id,expected_task_id))
          mixed_completion_starts++;
        end
        if(tail_commit_pending) begin
          if(vif.cplq_tail!==expected_tail_after_done)
            `uvm_error("CP/MON","CPLQ tail did not advance exactly once after four accepted words")
          tail_commit_pending=0;
        end
        if(vif.launch_valid) begin
          launches++;
          if(vif.test_case==CP_CPLQ_LAST_SLOT_QUEUE) begin
            if(vif.launch_task_id!==16'h1910 && vif.launch_task_id!==16'h1911)
              `uvm_error("CP/CPLQ_LAST_SLOT","unexpected command launched across last-slot pressure")
            cplq_last_slot_launches++;
          end
        end
        if(vif.test_case==CP_DIRECT_START && vif.launch_valid) begin
          if(vif.launch_op!==vif.cfg_op || vif.launch_task_id!==16'd0 ||
             vif.launch_src1!==32'h200 || vif.launch_length!==16'd4)
            `uvm_error("CP/DIRECT","direct launch did not preserve configured operation/operands")
          if(vif.launch_op==8'h10 && vif.launch_shift!==5'd1)
            `uvm_error("CP/DIRECT","non-FP predicate-bypass launch did not preserve INT8 shift")
          direct_launches++;
        end
        if(vif.test_case==CP_DIRECT_START && vif.event_valid) begin
          if((vif.cfg_op==8'h50 || vif.cfg_op==8'h51) &&
             (vif.cfg_length==0 || vif.cfg_m!=16'd1 || vif.cfg_n!=16'd1 ||
             (|vif.cfg_src0[1:0]) || (|vif.cfg_src1[1:0]) || (|vif.cfg_dst[1:0]) ||
             vif.cfg_bias_base!=32'd0 || vif.cfg_bias_enable ||
             vif.cfg_shift!=5'd0 || vif.cfg_activation!=2'd0)) begin
            if(!vif.event_error || vif.event_error_code!==4'd7 ||
               vif.event_result!==32'd0 || vif.event_elements!==32'd0)
              `uvm_error("CP/DIRECT","invalid direct FP configuration event did not report ERR_DESC")
            direct_invalid_events++;
          end else if(vif.event_error) begin
            if(vif.event_error_code!==4'd5 || vif.event_result!==32'hc0de0001 ||
               vif.event_elements!==32'd4 || vif.cpl_spad_valid ||
               vif.cpl_writer_busy || vif.cmdq_head!==32'd0 || vif.cplq_tail!==32'd0)
              `uvm_error("CP/DIRECT","direct compute-error event payload or no-completion contract mismatch")
            direct_compute_error_events++;
          end else begin
            if(vif.event_error || vif.event_result!==32'hc0de0001 ||
               vif.event_elements!==32'd4)
              `uvm_error("CP/DIRECT","direct completion event did not match the compute response")
            if(vif.force_stale_abort_code_once) begin
              if(vif.event_error_code!==4'd0 || vif.cpl_spad_valid || vif.cpl_writer_busy ||
                 vif.cmdq_head!==32'd0 || vif.cplq_tail!==32'd0)
                `uvm_error("CP/DIRECT","stale ERR_ABORT code leaked into event or queue side effects")
              direct_stale_abort_code_events++;
            end
            direct_events++;
          end
        end
        if(vif.test_case==CP_MACRO_CHILDREN && vif.cplq_size==0 && vif.event_valid) begin
          if(vif.event_result!==32'hc0de0001 || vif.cplq_tail!==32'd0 ||
             vif.cpl_spad_valid || vif.cpl_writer_busy)
            `uvm_error("CP/NO_CPLQ","macro event changed result/queue state or attempted completion writeback")
          if(!vif.event_error && vif.event_error_code===4'd0 &&
             vif.event_cycles===32'd51 && vif.event_elements===32'd12)
            macro_no_cplq_success_events++;
          else if(vif.event_error && vif.event_error_code===4'd5 &&
                  vif.event_cycles===32'd17 && vif.event_elements===32'd4)
            macro_no_cplq_error_events++;
          else
            `uvm_error("CP/NO_CPLQ","macro no-CPLQ event status or accumulated counters mismatch")
        end
        if(vif.test_case==CP_MACRO_CHILDREN && vif.launch_valid) begin
          if(vif.launch_op!==8'h10)
            `uvm_error("CP/MACRO","macro child launch opcode mismatch")
          else if(vif.launch_task_id>=16'h1511 && vif.launch_task_id<=16'h1513) begin
            if(macro_launches>=3 || vif.launch_task_id!==(16'h1511+macro_launches))
              `uvm_error("CP/MACRO","completion-enabled macro child launch count/order mismatch")
            macro_launches++;
          end else if(vif.launch_task_id>=16'h1541 && vif.launch_task_id<=16'h1543) begin
            if(macro_error_launches!=0 || vif.launch_task_id!==16'h1541)
              `uvm_error("CP/MACRO","compute-error macro launched a later child or used the wrong child ID")
            macro_error_launches++;
          end else if(vif.launch_task_id==16'h1551) begin
            if(macro_fetch_error_launches!=0)
              `uvm_error("CP/MACRO","child-fetch-error macro launched its first child more than once")
            macro_fetch_error_launches++;
          end else if(vif.launch_task_id==16'h1552 || vif.launch_task_id==16'h1553) begin
            `uvm_error("CP/MACRO","child-fetch-error macro launched a child after the failed descriptor fetch")
          end else begin
            case(macro_no_cplq_launches)
              0: if(vif.launch_task_id!==16'h1521)
                   `uvm_error("CP/NO_CPLQ","successful no-CPLQ macro launched the wrong first child")
              1: if(vif.launch_task_id!==16'h1522)
                   `uvm_error("CP/NO_CPLQ","successful no-CPLQ macro launched the wrong second child")
              2: if(vif.launch_task_id!==16'h1523)
                   `uvm_error("CP/NO_CPLQ","successful no-CPLQ macro launched the wrong third child")
              3: if(vif.launch_task_id!==16'h1531)
                   `uvm_error("CP/NO_CPLQ","failing no-CPLQ macro did not stop on its first child")
              default: `uvm_error("CP/NO_CPLQ","no-CPLQ macros launched an unexpected extra child")
            endcase
            macro_no_cplq_launches++;
          end
        end
        if(vif.abort_reset_recovery && vif.launch_valid)
          abort_reset_recovery_launches++;
        if(vif.test_case==CP_COMPUTE_ABORT && vif.launch_valid) begin
          logic [15:0] expected_abort_task_id;
          expected_abort_task_id=(compute_abort_launches==0) ? 16'h1200 : 16'h1201;
          if(compute_abort_launches>=2 || vif.launch_task_id!==expected_abort_task_id)
            `uvm_error("CP/ABORT","compute-abort recovery launch ID/order mismatch")
          compute_abort_launches++;
        end
        if(vif.test_case==CP_TILE_PINGPONG && !tile_model_started) begin
          tile_model_started=1;
          tile_next_load=0; tile_next_compute=0; tile_next_store=0;
          tile_loads=0; tile_computes=0; tile_stores=0; tile_overlap_cycles=0; tile_events=0;
          foreach(tile_ctx_state[i]) begin
            tile_ctx_state[i]=0; tile_ctx_tile[i]=-1;
            tile_load_buffer_hits[i]=0; tile_compute_buffer_hits[i]=0; tile_store_buffer_hits[i]=0;
          end
          tile_dma_pending=0; tile_compute_pending=0;
        end
        if(vif.test_case!=CP_TILE_PINGPONG) tile_model_started=0;
        if(vif.test_case==CP_RANDOM_QUEUE && !random_model_started) begin
          random_model_started=1;
          random_fetch_index=0; random_launch_count=0; random_retire_count=0;
          random_error_count=0; random_valid_count=0; random_completion_kind=0;
          random_invalid_count=0; random_fetch_fail_count=0; random_compute_fail_count=0;
          random_launch_expected.delete(); random_retire_expected.delete();
          random_outcome_expected.delete();
        end
        if(vif.test_case!=CP_RANDOM_QUEUE) random_model_started=0;
        if(vif.test_case==CP_CPLQ_PRESSURE && !cplq_pressure_model_started) begin
          cplq_pressure_model_started=1;
          cplq_pressure_fetches=0;
          cplq_pressure_launches=0;
          cplq_pressure_completions=0;
        end
        if(vif.test_case!=CP_CPLQ_PRESSURE) cplq_pressure_model_started=0;
        if(vif.test_case==CP_CPLQ_PRESSURE && vif.fetch_start) begin
          if(cplq_pressure_fetches>=8 ||
             vif.fetch_base!==vif.cmdq_base+((cplq_pressure_fetches%4)<<6))
            `uvm_error("CP/CPLQ","fetch order/address differs from pressure reference model")
          cplq_pressure_fetches++;
        end
        if(vif.test_case==CP_CPLQ_PRESSURE && vif.launch_valid) begin
          if(cplq_pressure_launches>=8 ||
             vif.launch_task_id!==(16'h3000+cplq_pressure_launches))
            `uvm_error("CP/CPLQ","launch order/task ID differs from pressure reference model")
          cplq_pressure_launches++;
        end
        if(vif.test_case==CP_RANDOM_QUEUE && vif.fetch_start) begin
          int expected_slot;
          logic [15:0] expected_task_id;
          logic [1:0] expected_outcome;
          expected_slot=random_fetch_index%4;
          if(random_fetch_index>=vif.random_queue_count)
            `uvm_error("CP/RING","fetched more descriptors than the producer published")
          expected_task_id=16'h2000+random_fetch_index;
          if(vif.fetch_base!==vif.cmdq_base+(expected_slot<<6))
            `uvm_error("CP/RING","descriptor fetch order/address differs from independent ring model")
          expected_outcome=vif.random_queue_failure_kind[(random_fetch_index*2) +: 2];
          random_outcome_expected.push_back(expected_outcome);
          case(expected_outcome)
            2'd0: begin
              random_valid_count++;
            end
            2'd1: begin
              random_error_count++; random_invalid_count++;
              if(!vif.random_queue_error_mask[random_fetch_index])
                `uvm_error("CP/RING","random descriptor error kind does not match invalid opcode stimulus")
            end
            2'd2: begin random_error_count++; random_fetch_fail_count++; end
            2'd3: begin
              random_error_count++; random_compute_fail_count++;
            end
          endcase
          if(expected_outcome==2'd0 || expected_outcome==2'd3) begin
            random_launch_expected.push_back(expected_task_id);
          end
          random_retire_expected.push_back(expected_task_id);
          random_fetch_index++;
        end
        if(vif.test_case==CP_RANDOM_QUEUE && vif.launch_valid) begin
          if(random_launch_expected.size()==0)
            `uvm_error("CP/RING","launch occurred without an accepted descriptor fetch")
          else begin
            logic [15:0] expected_task_id;
            expected_task_id=random_launch_expected.pop_front();
            if(vif.launch_task_id!==expected_task_id)
              `uvm_error("CP/RING","launch task ID/order differs from independent reference queue")
          end
          random_launch_count++;
        end
        if(vif.test_case==CP_TILE_PINGPONG && vif.dma_busy && vif.compute_busy)
          tile_overlap_cycles++;
        if(vif.test_case==CP_TILE_PINGPONG && vif.dma_done && tile_dma_pending) begin
          if(tile_dma_store_pending) begin
            if(tile_ctx_state[tile_dma_owner]!=5)
              `uvm_error("CP/TILE","store completion did not own a STORING context")
            tile_ctx_state[tile_dma_owner]=0;
            tile_ctx_tile[tile_dma_owner]=-1;
            tile_stores++;
          end else begin
            if(tile_ctx_state[tile_dma_owner]!=1)
              `uvm_error("CP/TILE","load completion did not own a LOADING context")
            tile_ctx_state[tile_dma_owner]=2;
          end
          tile_dma_pending=0;
        end
        if(vif.test_case==CP_TILE_PINGPONG && vif.compute_done && tile_compute_pending) begin
          if(tile_ctx_state[tile_compute_owner]!=3)
            `uvm_error("CP/TILE","compute completion did not own a COMPUTING context")
          tile_ctx_state[tile_compute_owner]=4;
          tile_compute_pending=0;
        end
        if(vif.test_case==CP_TILE_PINGPONG && vif.tile_dma_start) begin
          int owner;
          owner=-1;
          if(!vif.tile_dma_store) begin
            if(vif.tile_dma_spad_addr==vif.tile_buffer0_base) owner=0;
            if(vif.tile_dma_spad_addr==vif.tile_buffer1_base) owner=1;
            if(owner<0 || tile_ctx_state[owner]!=0)
              `uvm_error("CP/TILE","load attempted to acquire a non-empty/unknown buffer")
            if(vif.tile_dma_ext_addr !== vif.tile_ext_input_base +
               tile_next_load*vif.tile_ext_input_stride ||
               vif.tile_dma_length_words!==vif.tile_input_words)
              `uvm_error("CP/TILE","load request address/length did not match tile order")
            tile_dma_store_pending=0;
            if(owner>=0) begin
              tile_ctx_state[owner]=1; tile_ctx_tile[owner]=tile_next_load;
              tile_load_buffer_hits[owner]++; tile_dma_owner=owner;
            end
            tile_next_load++; tile_loads++;
          end else begin
            if(vif.tile_dma_spad_addr==vif.tile_buffer0_base+vif.tile_output_offset) owner=0;
            if(vif.tile_dma_spad_addr==vif.tile_buffer1_base+vif.tile_output_offset) owner=1;
            if(owner<0 || tile_ctx_state[owner]!=4 || tile_ctx_tile[owner]!=tile_next_store)
              `uvm_error("CP/TILE","store attempted before ordered compute retirement")
            if(vif.tile_dma_ext_addr !== vif.tile_ext_output_base +
               tile_next_store*vif.tile_ext_output_stride ||
               vif.tile_dma_length_words!==vif.tile_output_words)
              `uvm_error("CP/TILE","store request address/length did not match tile order")
            if(owner>=0) begin
              tile_ctx_state[owner]=5; tile_dma_owner=owner; tile_store_buffer_hits[owner]++;
            end
            tile_dma_store_pending=1; tile_next_store++;
          end
          if(tile_dma_pending) `uvm_error("CP/TILE","more than one tile DMA operation outstanding")
          tile_dma_pending=1;
        end
        if(vif.test_case==CP_TILE_PINGPONG && vif.launch_valid) begin
          int owner;
          owner=-1;
          if(vif.launch_src0==vif.tile_buffer0_base) owner=0;
          if(vif.launch_src0==vif.tile_buffer1_base) owner=1;
          if(owner<0 || tile_ctx_state[owner]!=2 || tile_ctx_tile[owner]!=tile_next_compute)
            `uvm_error("CP/TILE","compute launch did not own the next READY tile")
          if(owner>=0) begin
            tile_ctx_state[owner]=3; tile_compute_owner=owner;
            tile_compute_buffer_hits[owner]++;
          end
          if(vif.launch_op!==8'h50 || vif.launch_src1!==32'h200)
            `uvm_error("CP/TILE","tile compute launch lost operation/weight configuration")
          tile_compute_pending=1; tile_next_compute++; tile_computes++;
        end
        if(vif.test_case==CP_TILE_PINGPONG && vif.event_valid) begin
          if(vif.event_error || vif.event_elements!==32'd12)
            `uvm_error("CP/TILE","tile completion event reported an error or incorrect element total")
          tile_events++;
        end
        if(vif.test_case==CP_CONCURRENT_RING && vif.launch_valid)
          concurrent_launches++;
        if(vif.fetch_start && vif.test_case==CP_EXTERNAL_DESC) begin
          if(!vif.fetch_external)
            `uvm_error("CP/SB","external descriptor request did not set fetch_external")
          else external_fetches++;
        end
        if(vif.test_case==CP_INVALID && vif.launch_valid)
          `uvm_error("CP/SB","invalid descriptor reached compute launch")
        if((vif.test_case==CP_DEP_ABORT || vif.test_case==CP_FETCH_ERROR ||
            vif.test_case==CP_FETCH_ABORT) && vif.launch_valid)
          `uvm_error("CP/SB","aborted/dependency-blocked/fetch-error command launched compute")
        if(vif.test_case==CP_FETCH_ABORT && vif.launch_valid) fetch_abort_launches++;
        if((vif.test_case==CP_EMPTY || vif.test_case==CP_CPL_FULL) && vif.launch_valid)
          `uvm_error("CP/SB","rejected queue condition unexpectedly launched compute")
        if(vif.event_valid && vif.test_case==CP_EMPTY) begin
          if(!vif.event_error || vif.event_error_code!=4'd8)
            `uvm_error("CP/SB","empty CMDQ did not report ERR_EMPTY")
          else empty_rejects++;
        end
        if(vif.event_valid && vif.test_case==CP_CPL_FULL) begin
          if(!vif.event_error || vif.event_error_code!=4'd9)
            `uvm_error("CP/SB","full CPLQ did not report ERR_CPL")
          else cpl_full_rejects++;
        end
        if(vif.event_valid && vif.test_case==CP_FETCH_ERROR_NO_CPL) begin
          if(!vif.event_error || vif.event_error_code!==4'd6 ||
             vif.cmdq_head!==32'd1 || vif.cplq_tail!==32'd0)
            `uvm_error("CP/NO_CPLQ",$sformatf("event=%0b err=%0b code=%0h head=%0d cpl_tail=%0d cpl_size=%0d",
              vif.event_valid,vif.event_error,vif.event_error_code,vif.cmdq_head,
              vif.cplq_tail,vif.cplq_size))
          no_cplq_fetch_events++;
        end
        if(vif.event_valid && vif.test_case==CP_COMPLETION_PROT_LATE) begin
          if(!vif.event_error || vif.event_error_code!==4'd10 ||
             vif.event_result!==32'hc0de0001 || vif.event_cycles!==32'd17 ||
             vif.event_elements!==32'd4 || vif.cpl_spad_valid ||
             vif.cpl_writer_busy || vif.cplq_tail!==32'd0 || vif.cmdq_head!==32'd1)
            `uvm_error("CP/CPL_PROTECTION","protected in-flight completion did not preserve result and queue pointers")
          else late_completion_protection_events++;
        end
        if(vif.event_valid && vif.event_error && vif.event_error_code==7) begin
          if(vif.launch_valid) `uvm_error("CP/SB","invalid descriptor launched with validation error")
        end
        if(vif.cpl_spad_valid && vif.cpl_spad_ready) begin
          if(!vif.cpl_spad_write) `uvm_error("CP/MON","completion request was not a write")
          if(writes_in_record==0) begin
            tail_at_record_start=vif.cplq_tail;
            word_index=0;
          end
          if(vif.cplq_tail!==tail_at_record_start)
            `uvm_error("CP/MON","CPLQ tail advanced before all four word handshakes")
          if(vif.cpl_spad_addr !== vif.cplq_base + (vif.cplq_tail<<4) + (word_index<<2))
            `uvm_error("CP/MON",$sformatf("completion address word %0d got=%08x",word_index,vif.cpl_spad_addr))
          case(word_index)
            0: begin
              logic [15:0] expected_task_id;
              if(vif.test_case==CP_RANDOM_QUEUE) begin
                if(random_retire_expected.size()==0)
                  `uvm_error("CP/RING","completion retired without an accepted descriptor")
                else begin
                  expected_task_id=random_retire_expected.pop_front();
                  if(vif.completion_task_id!==expected_task_id)
                    `uvm_error("CP/RING","completion task ID/order differs from independent reference queue")
                end
                if(random_outcome_expected.size()==0)
                  `uvm_error("CP/RING","completion lacks a randomized descriptor outcome")
                else random_completion_kind=random_outcome_expected.pop_front();
                random_retire_count++;
              end
              case(vif.test_case)
                CP_WRAP: expected_task_id=16'h1003;
                CP_DEPENDENCY: expected_task_id=
                  (dependency_completion_index==0) ? 16'h1000 : 16'h1001;
                CP_CONCURRENT_RING: expected_task_id=
                  (concurrent_completion_index==0) ? 16'h1000 : 16'h1001;
                CP_COMPUTE_ABORT: expected_task_id=
                  (compute_abort_records==0) ? 16'h1200 : 16'h1201;
                CP_ABORT_RESET_PARTIAL: expected_task_id=16'h1300;
                CP_MACRO_CHILDREN: expected_task_id=
                  (macro_completions==0) ? 16'h1500 :
                  (macro_completions==1) ? 16'h1540 :
                  (macro_completions==2) ? 16'h1550 :
                  (macro_completions==3) ? 16'h1560 : 16'h1570;
                CP_CPLQ_PRESSURE: begin
                  expected_task_id=16'h3000+cplq_pressure_completions;
                  cplq_pressure_completions++;
                end
                CP_MIXED_ERROR_ABORT_RESET: begin
                  case(mixed_completion_starts)
                    1: expected_task_id=16'h1400;
                    2: expected_task_id=16'h1401;
                    3: expected_task_id=16'h1403;
                    default: expected_task_id=16'hffff;
                  endcase
                end
                CP_RANDOM_QUEUE: expected_task_id=16'h2000+random_retire_count-1;
                CP_SUBMIT_GUARD: begin
                  // The dependency-wait tuple is deliberately aborted after
                  // the ignored re-submit; give it a unique ID so it cannot
                  // be confused with either two-command queue-drain tuple.
                  case(submit_guard_completion_index)
                    0: expected_task_id=16'h1000;
                    1: expected_task_id=16'h1001;
                    2: expected_task_id=16'h27d0;
                    3: expected_task_id=16'h1000;
                    4: expected_task_id=16'h1001;
                    default: expected_task_id=16'h1000;
                  endcase
                  submit_guard_completion_index++;
                end
                CP_WRITER_FSM_FAULT_RECOVERY: expected_task_id=16'h1000;
                CP_ZERO_SIZE_EMPTY_FETCH: expected_task_id=16'h1900;
                CP_CPLQ_LAST_SLOT_QUEUE: begin
                  case(cplq_last_slot_completions)
                    0: expected_task_id=16'h1910;
                    1: expected_task_id=16'h1911;
                    default: expected_task_id=16'hffff;
                  endcase
                  cplq_last_slot_completions++;
                end
                CP_VALID,CP_INVALID,CP_RANDOM_STALL,CP_DEP_ABORT,CP_RESET,
                CP_FETCH_ERROR,CP_COMPUTE_ERROR,CP_PARTIAL_RESET,CP_EXTERNAL_DESC,
                CP_DEP_TIMEOUT:
                  expected_task_id=16'h1000;
                CP_FETCH_ABORT: expected_task_id=
                  (fetch_abort_records==0) ? 16'h1000 : 16'h1702;
                default: expected_task_id=16'hffff;
              endcase
              if(vif.test_case==CP_CONCURRENT_RING) concurrent_completion_index++;
              if(vif.completion_task_id!==expected_task_id)
                `uvm_error("CP/MON",$sformatf("unexpected completion task ID got=%04x expected=%04x",
                                               vif.completion_task_id,expected_task_id))
              if(vif.test_case==CP_DEPENDENCY) dependency_completion_index++;
              if(vif.cpl_spad_wdata !== {16'd0,vif.completion_task_id})
                `uvm_error("CP/MON","word0 task ID data mismatch")
              if((vif.test_case==CP_ABORT_RESET_PARTIAL ||
                  (vif.test_case==CP_MIXED_ERROR_ABORT_RESET &&
                   mixed_completion_starts==2)) &&
                 (vif.completion_error!==4'd3 || vif.completion_status!==4'd2))
                `uvm_error("CP/ABORT_RESET","partial completion word0 was not an ERR_ABORT record")
            end
            1: begin
              if(vif.cpl_spad_wdata !== {24'd0,vif.completion_error,vif.completion_status})
                `uvm_error("CP/MON","word1 status/error mismatch")
              if(vif.test_case==CP_MACRO_CHILDREN) begin
                if(macro_completions==0) begin
                  if(vif.completion_error!==4'd0 || vif.completion_status!==4'd1)
                    `uvm_error("CP/MACRO","successful macro parent did not commit success status")
                end else if(macro_completions==1) begin
                  if(vif.completion_error!==4'd5 || vif.completion_status!==4'd2)
                    `uvm_error("CP/MACRO","compute-error macro parent did not commit ERR_COMPUTE")
                  else macro_error_completions++;
                end else if(macro_completions==2) begin
                  if(vif.completion_error!==4'd6 || vif.completion_status!==4'd2)
                    `uvm_error("CP/MACRO","child-fetch-error macro parent did not commit ERR_FETCH")
                  else macro_fetch_error_completions++;
                end else if(macro_completions==3 || macro_completions==4) begin
                  if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                    `uvm_error("CP/MACRO","macro child abort did not commit parent ERR_ABORT")
                end else
                  `uvm_error("CP/MACRO","unexpected extra macro parent completion")
              end
              if(vif.test_case==CP_RANDOM_QUEUE) begin
                case(random_completion_kind)
                  2'd0: if(vif.completion_error!==4'd0 || vif.completion_status!==4'd1)
                    `uvm_error("CP/RING","random successful command did not retire success")
                  2'd1: if(vif.completion_error!==4'd7 || vif.completion_status!==4'd2)
                    `uvm_error("CP/RING","random invalid descriptor did not retire ERR_DESC")
                  2'd2: if(vif.completion_error!==4'd6 || vif.completion_status!==4'd2)
                    `uvm_error("CP/RING","random fetch failure did not retire ERR_FETCH")
                  2'd3: if(vif.completion_error!==4'd5 || vif.completion_status!==4'd2)
                    `uvm_error("CP/RING","random compute failure did not retire ERR_COMPUTE")
                endcase
              end else if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET) begin
                case(mixed_completion_starts-1)
                  0: begin
                    if(vif.mixed_prefix_failure_kind==2'd1 &&
                       (vif.completion_error!==4'd7 || vif.completion_status!==4'd2))
                      `uvm_error("CP/MIXED","random invalid descriptor did not retire ERR_DESC")
                    if(vif.mixed_prefix_failure_kind==2'd2 &&
                       (vif.completion_error!==4'd6 || vif.completion_status!==4'd2))
                      `uvm_error("CP/MIXED","random fetch failure did not retire ERR_FETCH")
                  end
                  1: if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                    `uvm_error("CP/MIXED","compute abort did not report ERR_ABORT")
                  2: if(vif.completion_error!==4'd0 || vif.completion_status!==4'd1)
                    `uvm_error("CP/MIXED","post-reset recovery did not report success")
                  default: `uvm_error("CP/MIXED","unexpected mixed-scenario status word")
                endcase
              end else if(vif.test_case==CP_ABORT_RESET_PARTIAL) begin
                if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                  `uvm_error("CP/ABORT_RESET",
                    "partially written reset-sweep record was not ERR_ABORT")
              end else if(vif.test_case==CP_INVALID) begin
                if(vif.completion_error!==4'd7 || vif.completion_status!==4'd2)
                  `uvm_error("CP/MON","invalid descriptor did not retire ERR_DESC completion")
              end else if(vif.test_case==CP_DEP_ABORT) begin
                if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                  `uvm_error("CP/MON","dependency-wait abort did not retire ERR_ABORT completion")
                else dep_abort_records++;
              end else if(vif.test_case==CP_FETCH_ABORT) begin
                if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                  `uvm_error("CP/MON","fetch-stage abort did not retire ERR_ABORT completion")
                else fetch_abort_records++;
              end else if(vif.test_case==CP_FETCH_ERROR) begin
                if(vif.completion_error!==4'd6 || vif.completion_status!==4'd2)
                  `uvm_error("CP/MON","fetch failure did not retire ERR_FETCH completion")
                else fetch_error_records++;
              end else if(vif.test_case==CP_COMPUTE_ERROR) begin
                if(vif.completion_error!==4'd5 || vif.completion_status!==4'd2)
                  `uvm_error("CP/MON","compute error code/status did not reach completion")
                else compute_error_records++;
              end else if(vif.test_case==CP_COMPUTE_ABORT) begin
                if(compute_abort_records==0) begin
                  if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                    `uvm_error("CP/ABORT","aborted command did not retire ERR_ABORT")
                end else if(compute_abort_records==1) begin
                  if(vif.completion_error!==4'd0 || vif.completion_status!==4'd1)
                    `uvm_error("CP/ABORT","resumed command did not retire success")
                end else begin
                  `uvm_error("CP/ABORT","unexpected extra completion after abort recovery")
                end
                compute_abort_records++;
              end else if(vif.test_case==CP_SUBMIT_GUARD &&
                          submit_guard_completion_index==3) begin
                if(vif.completion_error!==4'd3 || vif.completion_status!==4'd2)
                  `uvm_error("CP/SUBMIT_GUARD","decode re-submit cleanup did not retire ERR_ABORT")
              end else if(vif.test_case==CP_DEP_TIMEOUT) begin
                if(vif.completion_error!==4'd12 || vif.completion_status!==4'd2)
                  `uvm_error("CP/MON","dependency timeout did not retire ERR_DEPENDENCY completion")
                else dependency_timeout_records++;
              end else if(vif.test_case==CP_CONCURRENT_RING) begin
                if(vif.completion_error!==4'd0 || vif.completion_status!==4'd1)
                  `uvm_error("CP/MON","concurrent queue entry did not complete successfully")
                else concurrent_records++;
              end else if(vif.test_case==CP_MACRO_CHILDREN) begin
                // The two macro parent status cases were checked above.
              end else if(vif.completion_error!==4'd0 || vif.completion_status!==4'd1)
                `uvm_error("CP/MON","successful command did not retire a success completion")
            end
            2: if(vif.cpl_spad_wdata !== vif.completion_result) `uvm_error("CP/MON","word2 result mismatch")
            3: if(vif.cpl_spad_wdata !== vif.completion_elements) `uvm_error("CP/MON","word3 element count mismatch")
          endcase
          word_index=(word_index+1)%4; writes_in_record++;
          if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET &&
             vif.completion_task_id==16'h1401 && vif.completion_error==4'd3)
            mixed_abort_words_accepted++;
          if(writes_in_record==4) writes_in_record=0;
          addr_q.push_back(vif.cpl_spad_addr); data_q.push_back(vif.cpl_spad_wdata); writes++;
        end
        if(vif.cpl_writer_done) begin
          if(writes_in_record!=0) `uvm_error("CP/MON","writer done without four accepted words")
          if(vif.abort_reset_recovery) abort_reset_recovery_records++;
          if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET && vif.abort_reset_recovery)
            mixed_recovery_records++;
          expected_tail_after_done=(tail_at_record_start>=vif.cplq_size-1) ?
                                   0 : tail_at_record_start+1;
          tail_commit_pending=1;
          if(vif.test_case==CP_MACRO_CHILDREN) macro_completions++;
          completions++;
        end
      end else begin
        if(vif.test_case==CP_MIXED_ERROR_ABORT_RESET && vif.mixed_reset_check_pending) begin
          if(mixed_abort_words_accepted!=vif.mixed_reset_target_words)
            `uvm_error("CP/MIXED",$sformatf("scoreboard accepted %0d abort words before reset; expected %0d",
              mixed_abort_words_accepted,vif.mixed_reset_target_words))
          mixed_reset_checks++;
          mixed_abort_words_accepted=0;
          vif.mixed_reset_check_pending=0;
        end
        if(writes_in_record!=0) partial_reset_records++;
        word_index=0; writes_in_record=0; tail_at_record_start=0;
        tail_commit_pending=0;
      end end
    endtask
    function void check_phase(uvm_phase phase);
      int only_case;
      super.check_phase(phase);
      if ($value$plusargs("CP_ONLY_CASE=%d", only_case)) begin
        `uvm_info("CP/SB",$sformatf("CP_ONLY_CASE=%0d: skipping full-suite aggregate gates; per-case checks remained active",only_case),UVM_LOW)
        return;
      end
      if(completions*4 > writes) `uvm_error("CP/SB","writer completion count exceeds accepted completion words")
      if(launches<6) `uvm_error("CP/SB","too few valid launches observed")
      if(completions<7) `uvm_error("CP/SB","expected queued success/error completion records were not observed")
      if(dep_abort_records!=1) `uvm_error("CP/SB","expected exactly one dependency-wait abort completion")
      if(fetch_abort_records!=2 || fetch_abort_launches!=0)
        `uvm_error("CP/SB","fetch-stage abort must retire exactly once without compute launch")
      if(compute_abort_records!=2 || compute_abort_launches!=2 || compute_abort_inputs!=1)
        `uvm_error("CP/ABORT","compute abort and resumed command must each launch/retire exactly once")
      if(fetch_error_records!=1) `uvm_error("CP/SB","expected exactly one fetch-error completion")
      if(compute_error_records!=1) `uvm_error("CP/SB","expected exactly one compute-error completion")
      if(partial_reset_records!=(vif.mixed_reset_target_words==0 ? 2 : 3))
        `uvm_error("CP/SB","partial-completion reset count did not match the configured mixed reset word index")
      if(abort_reset_inputs!=2 || abort_reset_recovery_launches!=2 ||
         abort_reset_recovery_records!=2)
        `uvm_error("CP/ABORT_RESET","directed and mixed abort/reset scenarios must each produce one abort and one recovery")
      if(mixed_completion_starts!=3)
        `uvm_error("CP/MIXED","randomized error/abort/reset sequence did not observe all three completion attempts")
      if(mixed_abort_inputs!=1)
        `uvm_error("CP/MIXED","randomized scenario did not exercise exactly one compute-abort event")
      if(mixed_reset_checks!=1 || mixed_recovery_records!=1 || mixed_abort_words_accepted!=0)
        `uvm_error("CP/MIXED","reset word count or exactly-once recovery completion did not match")
      if(dependency_timeout_records!=1) `uvm_error("CP/SB","expected exactly one dependency-timeout completion")
      if(external_fetches!=1) `uvm_error("CP/SB","expected one external descriptor fetch request")
      if(concurrent_launches!=2 || concurrent_records!=2)
        `uvm_error("CP/SB","concurrent producer/consumer case did not launch and retire exactly two records")
      if(direct_launches!=5 || direct_events!=4 || direct_invalid_events!=20 ||
         direct_compute_error_events!=1 || direct_stale_abort_code_events!=1)
        `uvm_error("CP/DIRECT","direct-start must reject invalid FP configurations, complete valid INT8/BF16/FP16, report one compute error, and ignore stale ERR_ABORT when compute_error=0")
      if(macro_launches!=3 || macro_error_launches!=1 ||
         macro_fetch_error_launches!=1 || macro_completions!=5 ||
         macro_error_completions!=1 || macro_fetch_error_completions!=1)
        `uvm_error("CP/MACRO","success, compute-error, and child-fetch-error macros did not produce expected child launches and parent completions")
      if(macro_no_cplq_launches!=4 || macro_no_cplq_success_events!=1 ||
         macro_no_cplq_error_events!=1)
        `uvm_error("CP/NO_CPLQ","macro event-only paths must launch 3 success children, stop after 1 error child, and report one event each")
      if(no_cplq_fetch_events!=1)
        `uvm_error("CP/NO_CPLQ","expected exactly one fetch-error event with completion queue disabled")
      if(late_completion_protection_events!=1)
        `uvm_error("CP/CPL_PROTECTION","expected exactly one late-protection completion event")
      if(cplq_pressure_fetches!=8 || cplq_pressure_launches!=8 ||
         cplq_pressure_completions!=8)
        `uvm_error("CP/CPLQ","repeated full/hold/resume pressure did not preserve all eight commands")
      if(cplq_last_slot_launches!=2 || cplq_last_slot_completions!=2)
        `uvm_error("CP/CPLQ_LAST_SLOT","one-free-slot batch did not launch and retire exactly two commands")
      `uvm_info("CP/CPLQ",$sformatf("fetches=%0d launches=%0d completions=%0d",
        cplq_pressure_fetches,cplq_pressure_launches,cplq_pressure_completions),UVM_LOW)
      `uvm_info("CP/CPLQ_LAST_SLOT","one-free-slot batch passed; second descriptor remained queued until CPLQ consume and re-doorbell",UVM_LOW)
      if(tile_loads!=3 || tile_computes!=3 || tile_stores!=3 || tile_events!=1 || tile_next_load!=3 ||
         tile_next_compute!=3 || tile_next_store!=3)
        `uvm_error("CP/TILE","three-tile load/compute/store lifecycle did not complete exactly once")
      foreach(tile_ctx_state[i]) begin
        if(tile_ctx_state[i]!=0) `uvm_error("CP/TILE","tile context was not returned to EMPTY")
        if(tile_load_buffer_hits[i]==0 || tile_compute_buffer_hits[i]==0 || tile_store_buffer_hits[i]==0)
          `uvm_error("CP/TILE","ping-pong did not exercise load/compute/store ownership on both buffers")
      end
      if(tile_overlap_cycles==0) `uvm_error("CP/TILE","checker observed no simultaneous DMA/compute activity")
      `uvm_info("CP/TILE",$sformatf("tiles=%0d/%0d/%0d events=%0d overlap=%0d load_buf=%0d/%0d compute_buf=%0d/%0d store_buf=%0d/%0d",
        tile_loads,tile_computes,tile_stores,tile_events,tile_overlap_cycles,
        tile_load_buffer_hits[0],tile_load_buffer_hits[1],
        tile_compute_buffer_hits[0],tile_compute_buffer_hits[1],
        tile_store_buffer_hits[0],tile_store_buffer_hits[1]),UVM_LOW)
      `uvm_info("CP/NO_CPLQ",$sformatf("macro_success_events=%0d macro_error_events=%0d macro_child_launches=%0d",
        macro_no_cplq_success_events,macro_no_cplq_error_events,macro_no_cplq_launches),UVM_LOW)
      if(random_fetch_index!=vif.random_queue_count ||
         (random_valid_count+random_compute_fail_count)!=random_launch_count ||
         (random_valid_count+random_error_count)!=vif.random_queue_count ||
         random_retire_count!=vif.random_queue_count ||
         random_launch_expected.size()!=0 || random_retire_expected.size()!=0 ||
         random_outcome_expected.size()!=0 || random_error_count==0 || random_valid_count==0 ||
         random_invalid_count==0 || random_fetch_fail_count==0 || random_compute_fail_count==0)
        `uvm_error("CP/RING","independent randomized fetch/launch/retire model did not drain exactly")
      `uvm_info("CP/RING",$sformatf("expected=%0d accepted=%0d launches=%0d retired=%0d valid=%0d errors=%0d launch_pending=%0d retire_pending=%0d",
        vif.random_queue_count,
        random_fetch_index,random_launch_count,random_retire_count,
        random_valid_count,random_error_count,
        random_launch_expected.size(),random_retire_expected.size()),UVM_LOW)
      `uvm_info("CP/RING",$sformatf("random_outcomes desc=%0d fetch=%0d compute=%0d success=%0d",
        random_invalid_count,random_fetch_fail_count,random_compute_fail_count,random_valid_count),UVM_LOW)
      if(empty_rejects!=1) `uvm_error("CP/SB","expected one ERR_EMPTY queue rejection")
      if(cpl_full_rejects!=1) `uvm_error("CP/SB","expected one ERR_CPL full-queue rejection")
      `uvm_info("CP/ABORT",$sformatf("compute_abort_inputs=%0d launches=%0d completions=%0d",
        compute_abort_inputs,compute_abort_launches,compute_abort_records),UVM_LOW)
      `uvm_info("CP/ABORT_RESET",$sformatf("abort_inputs=%0d recovery_launches=%0d recovery_completions=%0d partial_resets=%0d",
        abort_reset_inputs,abort_reset_recovery_launches,abort_reset_recovery_records,
        partial_reset_records),UVM_LOW)
      `uvm_info("CP/MIXED",$sformatf("abort_inputs=%0d prefix_kind=%0d abort_delay=%0d reset_words=%0d completion_starts=%0d queued_suppressed=1 recovery=1",
        mixed_abort_inputs,vif.mixed_prefix_failure_kind,vif.mixed_abort_delay_cycles,
        vif.mixed_reset_target_words,mixed_completion_starts),UVM_LOW)
      `uvm_info("CP/SB",$sformatf("launches=%0d completion_writes=%0d completions=%0d dep_abort=%0d empty=%0d cpl_full=%0d",
        launches,writes,completions,dep_abort_records,empty_rejects,cpl_full_rejects),UVM_LOW)
    endfunction
  endclass
  class ai_cp_coverage extends uvm_component;
    `uvm_component_utils(ai_cp_coverage)
    int unsigned scenario_hits[31]; int unsigned stall_hits[2]; int unsigned word_hits[4];
    int unsigned dep_wait_cycles, dep_timeout_wait_cycles;
    virtual ai_cp_if vif; int last_scenario; bit scenario_seen;
    covergroup abort_timing_cg with function sample(int unsigned path,
                                                     int unsigned owner,
                                                     int unsigned error_code);
      cp_abort_timing_path: coverpoint path {
        bins direct_fetch_done_abort={1};
        bins macro_child_fetch_abort={2};
        bins macro_child_decode_abort={3};
      }
      cp_abort_owner: coverpoint owner {
        bins direct_task={1}; bins macro_fetch_parent={2}; bins macro_decode_parent={3};
      }
      cp_abort_error: coverpoint error_code { bins err_abort={3}; }
    endgroup
    covergroup cp_cg with function sample(int unsigned scenario,int unsigned launched,
                                         int unsigned err,int unsigned req_stall,int unsigned word_index,
                                         int unsigned mixed_kind,int unsigned mixed_delay,
                                         int unsigned mixed_reset_words,
                                         int unsigned direct_fp_invalid_rejected,
                                         int unsigned direct_fp_format,int unsigned direct_opcode,
                                         int unsigned direct_fp_validation_event,
                                         int unsigned direct_compute_error_event,
                                         int unsigned direct_stale_abort_code_ignored);
      cp_scenario: coverpoint scenario {
        bins valid={0}; bins invalid={1}; bins wrap={2}; bins dependency={3};
        bins reset={4}; bins random_stall={5}; bins dependency_abort={6};
        bins empty_cmdq={7}; bins full_cplq={8};
        bins fetch_error={9}; bins compute_error={10};
        bins partial_completion_reset={11};
        bins external_descriptor={12}; bins dependency_timeout={13};
        bins concurrent_ring_publish_consume={14};
        bins tile_pingpong_buffer_ownership={15};
        bins randomized_ring_reference_model={16};
        bins fetch_stage_abort={17};
        bins compute_abort_queue_resume={18};
        bins abort_completion_reset_recovery={19};
        bins randomized_error_abort_reset_recovery={20};
        bins direct_register_start={21};
        bins macro_child_sequence={22};
        bins fetch_error_without_completion_queue={23};
        bins cplq_full_hold_resume={24};
        bins completion_protection_changes_inflight={25};
        bins illegal_fsm_state_fault_recovery={26};
        bins submit_admission_guard={27};
        bins completion_writer_illegal_state_recovery={28};
        bins zero_size_empty_cmdq_compat_fetch={29};
        bins queued_batch_holds_at_last_cplq_slot={30};
      }
      cp_mixed_kind: coverpoint mixed_kind iff (scenario==20) {
        bins invalid_descriptor={1}; bins fetch_error={2};
      }
      cp_mixed_delay: coverpoint mixed_delay iff (scenario==20) {
        bins same_cycle={0}; bins short_delay={[1:2]}; bins long_delay={[3:5]};
      }
      cp_mixed_reset_words: coverpoint mixed_reset_words iff (scenario==20) {
        bins zero_words={0}; bins one_word={1}; bins two_words={2}; bins three_words={3};
      }
      cp_mixed_error_abort_cross: cross cp_mixed_kind,cp_mixed_delay iff (scenario==20);
      cp_mixed_kind_delay_reset_cross: cross cp_mixed_kind,cp_mixed_delay,cp_mixed_reset_words
        iff (scenario==20);
      cp_direct_fp_format: coverpoint direct_fp_format iff (direct_fp_validation_event) {
        bins bf16={0}; bins fp16={1};
      }
      cp_direct_fp_validation: coverpoint direct_fp_invalid_rejected iff (direct_fp_validation_event) {
        bins not_rejected={0}; bins rejected={1};
      }
      cp_direct_fp_format_validation: cross cp_direct_fp_format,cp_direct_fp_validation
        iff (direct_fp_validation_event);
      cp_direct_compute_error_event: coverpoint direct_compute_error_event iff (scenario==21) {
        bins no_compute_error={0}; bins compute_error_without_completion={1};
      }
      cp_direct_stale_abort_code_ignored: coverpoint direct_stale_abort_code_ignored iff (scenario==21) {
        bins stale_abort_code_ignored={1};
        ignore_bins not_stale_abort_response={0};
      }
      cp_direct_opcode: coverpoint direct_opcode iff (scenario==21 && launched) {
        bins int8_vdot={8'h10}; bins bf16_dot={8'h50}; bins fp16_dot={8'h51};
      }
      cp_launch: coverpoint launched {bins no={0};bins yes={1};}
      cp_error: coverpoint err {bins success={0};bins descriptor={7};bins other={[1:6],[8:15]};}
      cp_stall: coverpoint req_stall {bins none={0};bins stalled={1};}
      cp_word: coverpoint word_index {bins words[]={[0:3]};}
    endgroup
    function new(string n,uvm_component p);
      super.new(n,p); cp_cg=new(); abort_timing_cg=new();
      foreach(scenario_hits[i]) scenario_hits[i]=0;
      foreach(stall_hits[i]) stall_hits[i]=0;
      foreach(word_hits[i]) word_hits[i]=0;
      last_scenario=-1; scenario_seen=0; dep_wait_cycles=0; dep_timeout_wait_cycles=0;
    endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); if(!uvm_config_db#(virtual ai_cp_if)::get(this,"","vif",vif)) `uvm_fatal("CP/COV","vif missing"); endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        if(vif.resetn) begin
          cp_cg.sample(vif.test_case,vif.launch_valid,vif.event_valid?vif.event_error_code:0,
                       vif.cpl_spad_valid&&!vif.cpl_spad_ready,
                       vif.cpl_spad_valid&&vif.cpl_spad_ready?vif.cpl_spad_addr[3:2]:0,
                       vif.mixed_prefix_failure_kind,vif.mixed_abort_delay_cycles,
                       vif.mixed_reset_target_words,
                       vif.test_case==CP_DIRECT_START && vif.event_valid &&
                        vif.event_error && vif.event_error_code==4'd7,
                        vif.cfg_op==8'h51,
                        vif.cfg_op,
                        vif.test_case==CP_DIRECT_START && vif.event_valid &&
                         ((vif.cfg_op==8'h50) || (vif.cfg_op==8'h51)),
                       vif.test_case==CP_DIRECT_START && vif.event_valid &&
                        vif.event_error && vif.event_error_code==4'd5,
                       vif.test_case==CP_DIRECT_START && vif.force_stale_abort_code_once &&
                        vif.event_valid && !vif.event_error && vif.event_error_code==4'd0);
          if(vif.cpl_writer_done && vif.abort_cov_path!=0)
            abort_timing_cg.sample(
              vif.abort_cov_path,
              (vif.completion_task_id==16'h1702) ? 1 :
              ((vif.completion_task_id==16'h1560) ? 2 :
               ((vif.completion_task_id==16'h1570) ? 3 : 0)),
              vif.completion_error);
          if((vif.test_case<31) && (!scenario_seen || (vif.test_case!=last_scenario))) begin
            scenario_hits[vif.test_case]++;
            last_scenario=vif.test_case;
            scenario_seen=1;
          end
          if(vif.test_case==CP_DEP_ABORT && vif.busy &&
             vif.desc_wait_mask==16'h0002 && !vif.launch_valid)
            dep_wait_cycles++;
          if(vif.test_case==CP_DEP_TIMEOUT && vif.busy &&
             vif.desc_wait_mask==16'h0002 && !vif.launch_valid)
            dep_timeout_wait_cycles++;
          stall_hits[vif.cpl_spad_valid&&!vif.cpl_spad_ready]++;
          if(vif.cpl_spad_valid&&vif.cpl_spad_ready) word_hits[vif.cpl_spad_addr[3:2]]++;
        end
      end
    endtask
    function void check_phase(uvm_phase phase);
      int scenario_bins_hit, scenario_visits;
      int only_case;
      super.check_phase(phase);
      if ($value$plusargs("CP_ONLY_CASE=%d", only_case)) begin
        `uvm_info("CP/COV",$sformatf("CP_ONLY_CASE=%0d: skipping full-suite coverage gates; sampling remained active",only_case),UVM_LOW)
        return;
      end
      scenario_bins_hit=0; scenario_visits=0;
      foreach(scenario_hits[i]) begin
        if(scenario_hits[i]) scenario_bins_hit++;
        scenario_visits+=scenario_hits[i];
      end
      foreach(scenario_hits[i]) if(!scenario_hits[i]) `uvm_error("CP/COV",$sformatf("scenario bin %0d not hit",i))
      if(dep_wait_cycles<4) `uvm_error("CP/COV","dependency wait was not held for the expected cycles")
      if(dep_timeout_wait_cycles<65535)
        `uvm_error("CP/COV","dependency timeout did not exercise the full wait counter range")
      if(abort_timing_cg.get_coverage()<100.0)
        `uvm_error("CP/COV","fetch/macro abort timing functional bins did not all hit")
      foreach(stall_hits[i]) if(!stall_hits[i]) `uvm_error("CP/COV",$sformatf("backpressure bin %0d not hit",i))
      foreach(word_hits[i]) if(!word_hits[i]) `uvm_error("CP/COV",$sformatf("completion word bin %0d not hit",i))
      `uvm_info("CP/COV",$sformatf("scenario_bins=%0d/31 scenario_visits=%0d dep_wait_cycles=%0d dep_timeout_cycles=%0d stall_cycles=%0d/%0d words=%0d/%0d/%0d/%0d",
        scenario_bins_hit,scenario_visits,
        dep_wait_cycles,
        dep_timeout_wait_cycles,
        stall_hits[1],stall_hits[0]+stall_hits[1],word_hits[0],word_hits[1],word_hits[2],word_hits[3]),UVM_LOW)
      `uvm_info("CP/ABORT_COV","route_bins=3/3 direct_fetch_done=1 macro_child_fetch_parent=1 macro_child_decode_parent=1 ERR_ABORT=3",UVM_LOW)
    endfunction
  endclass
  class ai_cp_env extends uvm_env;
    `uvm_component_utils(ai_cp_env)
    uvm_sequencer#(ai_cp_item) sequencer; ai_cp_driver driver; ai_cp_scoreboard scoreboard; ai_cp_coverage coverage;
    function new(string n,uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase); sequencer=uvm_sequencer#(ai_cp_item)::type_id::create("sequencer",this);
      driver=ai_cp_driver::type_id::create("driver",this); scoreboard=ai_cp_scoreboard::type_id::create("scoreboard",this); coverage=ai_cp_coverage::type_id::create("coverage",this);
    endfunction
    function void connect_phase(uvm_phase phase); super.connect_phase(phase); driver.seq_item_port.connect(sequencer.seq_item_export); endfunction
  endclass
  class ai_cp_test extends uvm_test;
    `uvm_component_utils(ai_cp_test)
    ai_cp_env env; function new(string n,uvm_component p); super.new(n,p); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); env=ai_cp_env::type_id::create("env",this); endfunction
    task run_phase(uvm_phase phase); ai_cp_sequence seq; phase.raise_objection(this); seq=ai_cp_sequence::type_id::create("seq"); seq.start(env.sequencer); repeat(20) @(posedge env.driver.vif.clk); phase.drop_objection(this); endtask
  endclass
endpackage
