`timescale 1ns/1ps
interface ai_cp_if(input logic clk);
  logic resetn, abort, submit, direct_start;
  logic [7:0] cfg_op;
  logic [31:0] cfg_src0, cfg_src1, cfg_dst, cfg_bias_base;
  logic [15:0] cfg_length, cfg_m, cfg_n, cfg_k;
  logic [4:0] cfg_shift;
  logic [1:0] cfg_activation;
  logic cfg_bias_enable;
  logic [4:0] test_case;
  logic [7:0] random_queue_count;
  logic [31:0] random_queue_error_mask;
  logic [63:0] random_queue_failure_kind;
  logic compute_abort_once;
  logic force_compute_error_once;
  logic force_stale_abort_code_once;
  logic abort_reset_recovery;
  // Testbench-only controls/counters for reset-at-each-completion-word sweep.
  logic partial_reset_sweep_active;
  logic [1:0] partial_reset_target_words;
  logic [2:0] partial_reset_write_count;
  logic partial_reset_done;
  logic [1:0] mixed_prefix_failure_kind;
  logic [2:0] mixed_abort_delay_cycles;
  logic [1:0] mixed_reset_target_words;
  logic mixed_reset_check_pending;
  logic mixed_hold_abort_completion;
  logic force_completion_backpressure;
  logic tile_start;
  logic [15:0] tile_count, tile_input_words, tile_output_words;
  logic [63:0] tile_ext_input_base, tile_ext_output_base;
  logic [31:0] tile_ext_input_stride, tile_ext_output_stride;
  logic [31:0] tile_buffer0_base, tile_buffer1_base, tile_output_offset;
  logic [63:0] cmdq_base; logic [31:0] cmdq_size,cmdq_tail;
  logic desc_external;
  logic cmdq_head_load; logic [31:0] cmdq_head_seed;
  logic [31:0] cplq_base,cplq_size,cplq_head;
  logic completion_protected;
  logic inject_illegal_fsm_state, illegal_fsm_state_recovered;
  logic [3:0] debug_state_r;
  logic inject_illegal_writer_state, illegal_writer_state_recovered;
  logic [1:0] debug_writer_state_r;
  logic cplq_tail_load; logic [31:0] cplq_tail_seed;
  logic fetch_busy,fetch_done,fetch_error;
  // TB endpoint scheduling hook and functional abort-route tag. 1 requests
  // an abort on the exact response cycle; coverage samples the retired owner.
  logic fetch_abort_at_done;
  logic [1:0] abort_cov_path;
  logic [7:0] desc_op; logic [15:0] desc_task_id;
  logic [31:0] desc_src0,desc_src1,desc_dst; logic [15:0] desc_length,desc_m,desc_n,desc_k;
  logic [4:0] desc_shift; logic [1:0] desc_activation; logic [31:0] desc_bias_base;
  logic desc_bias_enable; logic [7:0] desc_flags; logic [31:0] desc_aux0;
  logic [31:0] desc_src0_stride,desc_src1_stride,desc_dst_stride;
  logic [15:0] desc_batch_count,desc_head_count,desc_wait_mask,desc_signal_mask,desc_clear_mask;
  logic [7:0] desc_version;
  logic compute_busy,compute_done,compute_error; logic [3:0] compute_error_code;
  logic [31:0] compute_result,compute_cycles,compute_elements;
  logic dma_busy,dma_done,dma_error; logic [3:0] dma_error_code;
  logic tile_dma_start,tile_dma_store,tile_active;
  logic [63:0] tile_dma_ext_addr;
  logic [31:0] tile_dma_spad_addr;
  logic [15:0] tile_dma_length_words,tile_completed;
  logic [31:0] tile_perf_total,tile_perf_dma,tile_perf_compute;
  logic [31:0] tile_perf_overlap,tile_perf_stall;
  logic completion_busy,completion_done;
  logic fetch_start; logic [63:0] fetch_base; logic fetch_external;
  logic launch_valid; logic [7:0] launch_op; logic [15:0] launch_task_id;
  logic [31:0] launch_src0,launch_src1,launch_dst; logic [15:0] launch_length,launch_m,launch_n,launch_k;
  logic [4:0] launch_shift; logic [1:0] launch_activation; logic [31:0] launch_bias_base;
  logic launch_bias_enable; logic [7:0] launch_flags; logic [31:0] launch_aux0;
  logic [31:0] launch_src0_stride,launch_src1_stride,launch_dst_stride;
  logic [15:0] launch_batch_count,launch_head_count;
  logic completion_start; logic [31:0] completion_base,completion_index;
  logic [15:0] completion_task_id; logic [3:0] completion_status,completion_error;
  logic [31:0] completion_result,completion_elements;
  logic [31:0] cmdq_head,cplq_tail; logic busy,event_valid,event_error;
  logic [3:0] event_error_code; logic [31:0] event_result,event_cycles,event_elements;
  logic [15:0] dependency_events;
  logic cpl_spad_valid,cpl_spad_write; logic [31:0] cpl_spad_addr,cpl_spad_wdata;
  logic cpl_spad_ready,cpl_writer_busy,cpl_writer_done;

  typedef struct packed {
    logic [7:0] op; logic [15:0] task_id;
    logic [31:0] src0,src1,dst; logic [15:0] length,m,n,k;
    logic [4:0] shift; logic [1:0] activation; logic [31:0] bias_base;
    logic bias_enable; logic [7:0] flags; logic [31:0] aux0;
    logic [31:0] src0_stride,src1_stride,dst_stride;
    logic [15:0] batch_count,head_count,wait_mask,signal_mask,clear_mask;
    logic [7:0] version;
  } descriptor_t;
  descriptor_t desc_mem[4];

  property p_completion_write_stable;
    @(posedge clk) disable iff(!resetn)
      cpl_spad_valid && !cpl_spad_ready |=> cpl_spad_valid &&
        $stable({cpl_spad_write,cpl_spad_addr,cpl_spad_wdata});
  endproperty
  a_completion_write_stable: assert property(p_completion_write_stable)
    else $error("completion writer changed request under backpressure");

  property p_completion_tail_stable_until_commit;
    @(posedge clk) disable iff(!resetn)
      cpl_writer_busy && !completion_done |=> $stable(cplq_tail);
  endproperty
  a_completion_tail_stable_until_commit: assert property(p_completion_tail_stable_until_commit)
    else $error("CPLQ tail advanced before the completion writer finished");

  property p_completion_tail_advances_once;
    @(posedge clk) disable iff(!resetn)
      completion_done && !cplq_tail_load && cplq_size!=0 |=>
        cplq_tail == (($past(cplq_tail) >= $past(cplq_size)-1) ?
                      0 : $past(cplq_tail)+1);
  endproperty
  a_completion_tail_advances_once: assert property(p_completion_tail_advances_once)
    else $error("CPLQ tail did not advance exactly once after writer done");

  // CP_SUBMIT_GUARD (scenario 27) holds the completion writer in ST_CPL while
  // abort is pulsed. The in-flight four-word record must not be discarded.
  property p_abort_during_completion_does_not_truncate_record;
    @(posedge clk) disable iff(!resetn)
      (test_case==5'd27 && debug_state_r==4'd4 && abort && cpl_writer_busy &&
       cpl_spad_valid && !cpl_spad_ready) |=>
        (debug_state_r==4'd4 && cpl_writer_busy && $stable(cplq_tail) &&
         !launch_valid);
  endproperty
  a_abort_during_completion_does_not_truncate_record:
    assert property(p_abort_during_completion_does_not_truncate_record)
      else $error("abort truncated an in-flight completion record");

  // CP_FETCH_ABORT is scenario 17: an abort during descriptor fetch must not
  // permit a compute launch on the following cycle.
  property p_fetch_stage_abort_suppresses_launch;
    @(posedge clk) disable iff(!resetn)
      (test_case==5'd17 && abort) |=> !launch_valid;
  endproperty
  a_fetch_stage_abort_suppresses_launch: assert property(p_fetch_stage_abort_suppresses_launch)
    else $error("descriptor-fetch abort was followed by a compute launch");

  property p_compute_abort_stops_automatic_queue_advance;
    @(posedge clk) disable iff(!resetn)
      ((test_case==5'd18 || test_case==5'd19 || test_case==5'd20) &&
       compute_done && compute_error &&
       compute_error_code==4'd3) |=> !launch_valid;
  endproperty
  a_compute_abort_stops_automatic_queue_advance: assert property(p_compute_abort_stops_automatic_queue_advance)
    else $error("compute abort automatically launched another queued command");

  // Scenario 21 checks the legacy direct-start path: a compute failure is
  // reported as an event and must not create a CMDQ/CPLQ transaction.
  property p_direct_compute_error_is_event_only;
    @(posedge clk) disable iff(!resetn)
      (test_case==5'd21 && compute_done && compute_error &&
       compute_error_code==4'd5) |=>
        (event_valid && event_error && event_error_code==4'd5 &&
         !completion_start && !cpl_spad_valid && !cpl_writer_busy &&
         $stable({cmdq_head,cplq_tail}));
  endproperty
  a_direct_compute_error_is_event_only: assert property(p_direct_compute_error_is_event_only)
    else $error("direct compute failure created completion traffic or moved queue pointers");

  // An error code is meaningful only when compute_error is asserted. A stale
  // ERR_ABORT value on an otherwise successful response must not stop the
  // queued-command lifecycle or leak into the software event.
  property p_direct_stale_abort_code_is_ignored;
    @(posedge clk) disable iff(!resetn)
      (test_case==5'd21 && compute_done && !compute_error &&
       compute_error_code==4'd3) |=>
        (event_valid && !event_error && event_error_code==4'd0 &&
         !completion_start && !cpl_spad_valid && !cpl_writer_busy &&
         $stable({cmdq_head,cplq_tail}));
  endproperty
  a_direct_stale_abort_code_is_ignored: assert property(p_direct_stale_abort_code_is_ignored)
    else $error("stale ERR_ABORT code changed a successful direct-start result");
endinterface
