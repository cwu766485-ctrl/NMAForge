`timescale 1ns / 1ps

// Command lifecycle owner for direct, descriptor-queue, A2 tile and A4 macro jobs.
// Register programming remains in ai_accel_regs.  This module owns queue
// pointers, descriptor validation, compute launch, tile dependencies and
// completion ordering.
module ai_command_processor(
    input wire clk, input wire resetn,
    input wire abort,
    input wire submit, input wire direct_start, input wire tile_start,
    input wire [63:0] cmdq_base, input wire [31:0] cmdq_size,
    input wire [31:0] cmdq_tail, input wire desc_external,
    input wire cmdq_head_load, input wire [31:0] cmdq_head_seed,
    input wire [31:0] cplq_base, input wire [31:0] cplq_size,
    input wire [31:0] cplq_head, input wire completion_protected,
    input wire cplq_tail_load, input wire [31:0] cplq_tail_seed,

    input wire [7:0] cfg_op,
    input wire [31:0] cfg_src0, input wire [31:0] cfg_src1, input wire [31:0] cfg_dst,
    input wire [15:0] cfg_length, input wire [15:0] cfg_m, input wire [15:0] cfg_n, input wire [15:0] cfg_k,
    input wire [4:0] cfg_shift, input wire [1:0] cfg_activation,
    input wire [31:0] cfg_bias_base, input wire cfg_bias_enable,

    input wire [15:0] tile_count,
    input wire [63:0] tile_ext_input_base, input wire [63:0] tile_ext_output_base,
    input wire [31:0] tile_ext_input_stride, input wire [31:0] tile_ext_output_stride,
    input wire [31:0] tile_buffer0_base, input wire [31:0] tile_buffer1_base,
    input wire [31:0] tile_output_offset,
    input wire [15:0] tile_input_words, input wire [15:0] tile_output_words,

    input wire fetch_busy, input wire fetch_done, input wire fetch_error,
    input wire [7:0] desc_op, input wire [15:0] desc_task_id,
    input wire [31:0] desc_src0, input wire [31:0] desc_src1, input wire [31:0] desc_dst,
    input wire [15:0] desc_length, input wire [15:0] desc_m, input wire [15:0] desc_n, input wire [15:0] desc_k,
    input wire [4:0] desc_shift, input wire [1:0] desc_activation,
    input wire [31:0] desc_bias_base, input wire desc_bias_enable,
    input wire [7:0] desc_flags, input wire [31:0] desc_aux0,
    input wire [31:0] desc_src0_stride, input wire [31:0] desc_src1_stride,
    input wire [31:0] desc_dst_stride,
    input wire [15:0] desc_batch_count, input wire [15:0] desc_head_count,
    input wire [15:0] desc_wait_mask, input wire [15:0] desc_signal_mask,
    input wire [15:0] desc_clear_mask, input wire [7:0] desc_version,

    input wire compute_busy, input wire compute_done, input wire compute_error,
    input wire [3:0] compute_error_code,
    input wire [31:0] compute_result, input wire [31:0] compute_cycles,
    input wire [31:0] compute_elements,
    input wire dma_busy, input wire dma_done, input wire dma_error,
    input wire [3:0] dma_error_code,
    input wire completion_busy, input wire completion_done,

    output reg fetch_start, output reg [63:0] fetch_base, output reg fetch_external,
    output reg launch_valid, output reg [7:0] launch_op, output reg [15:0] launch_task_id,
    output reg [31:0] launch_src0, output reg [31:0] launch_src1, output reg [31:0] launch_dst,
    output reg [15:0] launch_length, output reg [15:0] launch_m, output reg [15:0] launch_n, output reg [15:0] launch_k,
    output reg [4:0] launch_shift, output reg [1:0] launch_activation,
    output reg [31:0] launch_bias_base, output reg launch_bias_enable,
    output reg [7:0] launch_flags, output reg [31:0] launch_aux0,
    output reg [31:0] launch_src0_stride, output reg [31:0] launch_src1_stride,
    output reg [31:0] launch_dst_stride,
    output reg [15:0] launch_batch_count, output reg [15:0] launch_head_count,

    output wire tile_dma_start, output wire tile_dma_store,
    output wire [63:0] tile_dma_ext_addr,
    output wire [31:0] tile_dma_spad_addr,
    output wire [15:0] tile_dma_length_words, output wire tile_active,
    output wire [31:0] tile_perf_total, output wire [31:0] tile_perf_dma,
    output wire [31:0] tile_perf_compute, output wire [31:0] tile_perf_overlap,
    output wire [31:0] tile_perf_stall, output wire [15:0] tile_completed,

    output reg completion_start, output wire [31:0] completion_base,
    output wire [31:0] completion_index,
    output reg [15:0] completion_task_id, output reg [3:0] completion_status,
    output reg [3:0] completion_error, output reg [31:0] completion_result,
    output reg [31:0] completion_elements,
    output reg [31:0] cmdq_head, output reg [31:0] cplq_tail,
    output reg busy, output reg event_valid, output reg event_error,
    output reg [3:0] event_error_code, output reg [31:0] event_result,
    output reg [31:0] event_cycles, output reg [31:0] event_elements,
    output reg [15:0] dependency_events
);
    localparam [3:0] ST_IDLE   = 4'd0;
    localparam [3:0] ST_FETCH  = 4'd1;
    localparam [3:0] ST_DECODE = 4'd2;
    localparam [3:0] ST_RUN    = 4'd3;
    localparam [3:0] ST_CPL    = 4'd4;
    localparam [3:0] ST_TILE   = 4'd5;

    localparam [3:0] ERR_ABORT      = 4'd3;
    localparam [3:0] ERR_FETCH      = 4'd6;
    localparam [3:0] ERR_DESC       = 4'd7;
    localparam [3:0] ERR_EMPTY      = 4'd8;
    localparam [3:0] ERR_CPL        = 4'd9;
    localparam [3:0] ERR_PROT       = 4'd10;
    localparam [3:0] ERR_DEPENDENCY = 4'd12;

    localparam [3:0] CPL_DONE  = 4'd1;
    localparam [3:0] CPL_ERROR = 4'd2;

    reg [3:0] state_r;
    reg queue_run_r, completion_required_r;
    reg pending_error_r;
    reg [3:0] pending_error_code_r;
    reg [31:0] pending_result_r, pending_cycles_r, pending_elements_r;
    reg [31:0] pending_tail_r;
    reg abort_pending_r;
    reg [15:0] pending_signal_mask_r;
    reg [15:0] dependency_wait_cycles_r;
    reg macro_active_r;
    reg macro_child_fetch_r;
    reg macro_child_external_r;
    reg [15:0] macro_parent_task_id_r;
    reg [15:0] macro_parent_signal_mask_r;
    reg [15:0] macro_child_count_r;
    reg [15:0] macro_child_index_r;
    reg [63:0] macro_child_base_r;
    reg [31:0] macro_cycles_r;
    reg [31:0] macro_elements_r;
    reg [31:0] macro_result_r;

    // Ring pointer arithmetic is shared by command and completion queues;
    // this module remains the sole owner of both pointer registers.
    wire [31:0] cmdq_head_index, cmdq_head_next;
    wire [31:0] cplq_tail_index, cplq_tail_next;
    ai_ring_pointer_next cmdq_pointer_u(
        .pointer(cmdq_head), .queue_size(cmdq_size),
        .index(cmdq_head_index), .next_pointer(cmdq_head_next)
    );
    ai_ring_pointer_next cplq_pointer_u(
        .pointer(cplq_tail), .queue_size(cplq_size),
        .index(cplq_tail_index), .next_pointer(cplq_tail_next)
    );

    wire cmdq_empty = cmdq_size != 0 && cmdq_head_index == cmdq_tail;
    wire cplq_full = cplq_size != 0 && cplq_tail_next == cplq_head;
    wire completion_available = cplq_size != 0 && !cplq_full && !completion_protected;
    wire scheduler_resources_idle = !fetch_busy && !compute_busy && !completion_busy && !dma_busy;
    wire dependencies_ready = (dependency_events & desc_wait_mask) == desc_wait_mask;
    wire macro_op, descriptor_invalid;
    wire direct_fp_dot_invalid =
        (cfg_length == 16'd0) || (cfg_m != 16'd1) || (cfg_n != 16'd1) ||
        (|cfg_src0[1:0]) || (|cfg_src1[1:0]) || (|cfg_dst[1:0]) ||
        (cfg_bias_base != 32'd0) || cfg_bias_enable ||
        (cfg_shift != 5'd0) || (cfg_activation != 2'd0);
    // Descriptor ABI validation is deliberately stateless.  Launch, queue
    // advancement and error-completion ownership remain in this FSM.
    ai_descriptor_validator descriptor_validator_u(
        .op(desc_op), .version(desc_version),
        .src0(desc_src0), .src1(desc_src1), .dst(desc_dst),
        .bias_base(desc_bias_base), .length(desc_length),
        .m_size(desc_m), .n_size(desc_n), .k_words(desc_k),
        .bias_enable(desc_bias_enable), .flags(desc_flags),
        .scale_shift(desc_shift), .activation(desc_activation),
        .aux0(desc_aux0), .src0_stride(desc_src0_stride),
        .src1_stride(desc_src1_stride), .dst_stride(desc_dst_stride),
        .batch_count(desc_batch_count), .head_count(desc_head_count),
        .macro_child_fetch(macro_child_fetch_r),
        .op_valid(), .is_macro(macro_op), .is_tensor_matrix(),
        .is_tensor_sfu(), .version_valid(), .dimensions_valid(),
        .alignment_error(),
        .descriptor_invalid(descriptor_invalid)
    );
    wire dependency_wait_timed_out = (dependency_wait_cycles_r == 16'hffff);

    wire tile_compute_start;
    wire [7:0] tile_launch_op;
    wire [31:0] tile_launch_src0, tile_launch_src1, tile_launch_dst;
    wire [15:0] tile_launch_length, tile_launch_m, tile_launch_n, tile_launch_k;
    wire [4:0] tile_launch_shift;
    wire [1:0] tile_launch_activation;
    wire [31:0] tile_launch_bias_base;
    wire tile_launch_bias_enable;
    wire tile_busy, tile_done, tile_error;
    wire [3:0] tile_error_code;
    wire [31:0] tile_result, tile_elements;

    assign completion_base = cplq_base;
    assign completion_index = cplq_tail_index;
    assign tile_active = (state_r == ST_TILE) || tile_busy;

    ai_tile_pipeline tile_pipeline_u(
        .clk(clk), .resetn(resetn),
        .start(tile_start && state_r == ST_IDLE && scheduler_resources_idle),
        .abort(abort), .tile_count(tile_count),
        .ext_input_base(tile_ext_input_base), .ext_output_base(tile_ext_output_base),
        .ext_input_stride(tile_ext_input_stride), .ext_output_stride(tile_ext_output_stride),
        .buffer0_base(tile_buffer0_base), .buffer1_base(tile_buffer1_base),
        .output_offset(tile_output_offset), .input_words(tile_input_words),
        .output_words(tile_output_words), .compute_op(cfg_op),
        .weight_base(cfg_src1), .compute_length(cfg_length), .compute_m(cfg_m),
        .compute_n(cfg_n), .compute_k(cfg_k), .compute_shift(cfg_shift),
        .compute_activation(cfg_activation), .compute_bias_base(cfg_bias_base),
        .compute_bias_enable(cfg_bias_enable),
        .dma_busy(dma_busy), .dma_done(dma_done), .dma_error(dma_error),
        .dma_error_code(dma_error_code), .dma_start(tile_dma_start),
        .dma_store(tile_dma_store), .dma_ext_addr(tile_dma_ext_addr),
        .dma_spad_addr(tile_dma_spad_addr), .dma_length_words(tile_dma_length_words),
        .compute_busy(compute_busy), .compute_done(compute_done),
        .compute_error(compute_error), .compute_error_code(compute_error_code),
        .compute_result(compute_result), .compute_elements(compute_elements),
        .compute_start(tile_compute_start), .launch_op(tile_launch_op),
        .launch_src0(tile_launch_src0), .launch_src1(tile_launch_src1),
        .launch_dst(tile_launch_dst), .launch_length(tile_launch_length),
        .launch_m(tile_launch_m), .launch_n(tile_launch_n), .launch_k(tile_launch_k),
        .launch_shift(tile_launch_shift), .launch_activation(tile_launch_activation),
        .launch_bias_base(tile_launch_bias_base), .launch_bias_enable(tile_launch_bias_enable),
        .busy(tile_busy), .done(tile_done), .error(tile_error),
        .error_code(tile_error_code), .result(tile_result),
        .element_count(tile_elements), .perf_total_cycles(tile_perf_total),
        .perf_dma_cycles(tile_perf_dma), .perf_compute_cycles(tile_perf_compute),
        .perf_overlap_cycles(tile_perf_overlap), .perf_stall_cycles(tile_perf_stall),
        .completed_tiles(tile_completed)
    );

    function [101:0] make_report;
      input is_error;
      input [3:0] code;
      input [31:0] result_value;
      input [31:0] cycles;
      input [31:0] elements;
      begin
        make_report = {1'b1, is_error, code, result_value, cycles, elements};
      end
    endfunction

    function [209:0] make_completion;
      input is_error;
      input [3:0] code;
      input [31:0] result_value;
      input [31:0] cycles;
      input [31:0] elements;
      begin
        make_completion = {1'b1, is_error ? CPL_ERROR : CPL_DONE, code,
                           result_value, elements, is_error, code,
                           result_value, cycles, elements, cplq_tail_next,
                           ST_CPL};
      end
    endfunction

    // Build the registered launch ABI as a pure value.  Callers perform one
    // nonblocking assignment, avoiding task side effects on module registers.
    function [392:0] make_launch;
      input [7:0]  op;
      input [15:0] task_id;
      input [31:0] src0;
      input [31:0] src1;
      input [31:0] dst;
      input [15:0] length;
      input [15:0] m_size;
      input [15:0] n_size;
      input [15:0] k_words;
      input [4:0]  scale_shift;
      input [1:0]  activation;
      input [31:0] bias_base;
      input        bias_enable;
      input [7:0]  flags;
      input [31:0] aux0;
      input [31:0] src0_stride;
      input [31:0] src1_stride;
      input [31:0] dst_stride;
      input [15:0] batch_count;
      input [15:0] head_count;
      begin
        make_launch = {1'b1, op, task_id, src0, src1, dst, length, m_size,
                       n_size, k_words, scale_shift, activation, bias_base,
                       bias_enable, flags, aux0, src0_stride, src1_stride,
                       dst_stride, batch_count == 0 ? 16'd1 : batch_count,
                       head_count == 0 ? 16'd1 : head_count};
      end
    endfunction

`define REPORT_EVENT(is_error, code, value, cycles, elements) \
    {event_valid, event_error, event_error_code, event_result, \
     event_cycles, event_elements} <= \
    make_report(is_error, code, value, cycles, elements)

`define START_COMPLETION(is_error, code, value, cycles, elements) \
    {completion_start, completion_status, completion_error, \
     completion_result, completion_elements, pending_error_r, \
     pending_error_code_r, pending_result_r, pending_cycles_r, \
     pending_elements_r, pending_tail_r, state_r} <= \
    make_completion(is_error, code, value, cycles, elements)

    always @(posedge clk or negedge resetn) begin
      if (!resetn) begin
        state_r <= ST_IDLE;
        queue_run_r <= 1'b0;
        completion_required_r <= 1'b0;
        fetch_start <= 1'b0;
        launch_valid <= 1'b0;
        completion_start <= 1'b0;
        fetch_base <= 64'd0;
        fetch_external <= 1'b0;
        cmdq_head <= 32'd0;
        cplq_tail <= 32'd0;
        busy <= 1'b0;
        event_valid <= 1'b0;
        event_error <= 1'b0;
        event_error_code <= 4'd0;
        event_result <= 32'd0;
        event_cycles <= 32'd0;
        event_elements <= 32'd0;
        launch_task_id <= 16'd0;
        launch_op <= 8'd0;
        launch_src0 <= 32'd0;
        launch_src1 <= 32'd0;
        launch_dst <= 32'd0;
        launch_length <= 16'd0;
        launch_m <= 16'd0;
        launch_n <= 16'd0;
        launch_k <= 16'd0;
        launch_shift <= 5'd0;
        launch_activation <= 2'd0;
        launch_bias_base <= 32'd0;
        launch_bias_enable <= 1'b0;
        launch_flags <= 8'd0;
        launch_aux0 <= 32'd0;
        launch_src0_stride <= 32'd0;
        launch_src1_stride <= 32'd0;
        launch_dst_stride <= 32'd0;
        launch_batch_count <= 16'd1;
        launch_head_count <= 16'd1;
        completion_task_id <= 16'd0;
        completion_status <= 4'd0;
        completion_error <= 4'd0;
        completion_result <= 32'd0;
        completion_elements <= 32'd0;
        pending_error_r <= 1'b0;
        pending_error_code_r <= 4'd0;
        pending_result_r <= 32'd0;
        pending_cycles_r <= 32'd0;
        pending_elements_r <= 32'd0;
        pending_tail_r <= 32'd0;
        abort_pending_r <= 1'b0;
        pending_signal_mask_r <= 16'd0;
        dependency_wait_cycles_r <= 16'd0;
        dependency_events <= 16'd0;
        macro_active_r <= 1'b0;
        macro_child_fetch_r <= 1'b0;
        macro_child_external_r <= 1'b0;
        macro_parent_task_id_r <= 16'd0;
        macro_parent_signal_mask_r <= 16'd0;
        macro_child_count_r <= 16'd0;
        macro_child_index_r <= 16'd0;
        macro_child_base_r <= 32'd0;
        macro_cycles_r <= 32'd0;
        macro_elements_r <= 32'd0;
        macro_result_r <= 32'd0;
      end else begin
        fetch_start <= 1'b0;
        launch_valid <= 1'b0;
        completion_start <= 1'b0;
        event_valid <= 1'b0;

        if (cmdq_head_load)
          cmdq_head <= cmdq_head_seed;
        else if ((state_r == ST_IDLE && submit && scheduler_resources_idle &&
                  !(cmdq_size != 0 && cmdq_empty) &&
                  !(cmdq_size != 0 && !completion_available)) ||
                 (state_r == ST_CPL && completion_done && queue_run_r &&
                  cmdq_head_index != cmdq_tail &&
                  !((cplq_tail_next >= cplq_size-1 ? 0 : cplq_tail_next+1) == cplq_head)))
          cmdq_head <= cmdq_head_next;
        if (cplq_tail_load)
          cplq_tail <= cplq_tail_seed;
        else if (state_r == ST_CPL && completion_done)
          cplq_tail <= pending_tail_r;
        if (state_r == ST_IDLE ||
            (state_r == ST_FETCH && fetch_done && (abort_pending_r || abort)) ||
            (state_r == ST_DECODE && (abort_pending_r || abort)) ||
            (state_r == ST_RUN && compute_done) ||
            (state_r == ST_TILE && tile_done))
          abort_pending_r <= 1'b0;
        else if (abort && state_r != ST_CPL)
          abort_pending_r <= 1'b1;

        case (state_r)
          ST_IDLE: begin
            busy <= 1'b0;
            queue_run_r <= 1'b0;
            macro_active_r <= 1'b0;
            macro_child_fetch_r <= 1'b0;
            if (tile_start && scheduler_resources_idle) begin
              busy <= 1'b1;
              completion_required_r <= 1'b0;
              state_r <= ST_TILE;
            end else if (direct_start && scheduler_resources_idle &&
                         (cfg_op == 8'h50 || cfg_op == 8'h51) &&
                         direct_fp_dot_invalid) begin
              // Direct-register FP dot has no descriptor word to validate.
              // Reject unsupported dimensions/configuration through the same
              // legacy descriptor/configuration error event path.
              completion_required_r <= 1'b0;
              `REPORT_EVENT(1'b1, ERR_DESC, 0, 0, 0);
              busy <= 1'b0;
            end else if (direct_start && scheduler_resources_idle) begin
              busy <= 1'b1;
              completion_required_r <= 1'b0;
              {launch_valid, launch_op, launch_task_id, launch_src0,
               launch_src1, launch_dst, launch_length, launch_m, launch_n,
               launch_k, launch_shift, launch_activation, launch_bias_base,
               launch_bias_enable, launch_flags, launch_aux0,
               launch_src0_stride, launch_src1_stride, launch_dst_stride,
               launch_batch_count, launch_head_count} <=
              make_launch(cfg_op, 16'd0, cfg_src0, cfg_src1, cfg_dst,
                           cfg_length, cfg_m, cfg_n, cfg_k, cfg_shift,
                           cfg_activation, cfg_bias_base, cfg_bias_enable,
                           {7'd0, cfg_bias_enable}, 32'd1, 32'd0, 32'd0,
                           32'd0, 16'd1, 16'd1);
              pending_signal_mask_r <= 16'd0;
              state_r <= ST_RUN;
            end else if (submit && scheduler_resources_idle) begin
              busy <= 1'b1;
              completion_required_r <= (cplq_size != 0);
              if (cmdq_size != 0 && cmdq_empty) begin
                `REPORT_EVENT(1'b1, ERR_EMPTY, 0, 0, 0);
                busy <= 1'b0;
              end else if (cmdq_size != 0 && !completion_available) begin
                `REPORT_EVENT(1'b1, completion_protected ? ERR_PROT : ERR_CPL, 0, 0, 0);
                busy <= 1'b0;
              end else begin
                queue_run_r <= (cmdq_size != 0);
                macro_child_fetch_r <= 1'b0;
                fetch_base <= cmdq_base + (cmdq_head_index << 6);
                fetch_external <= desc_external;
                fetch_start <= 1'b1;
                state_r <= ST_FETCH;
              end
            end
          end

          ST_FETCH: if (fetch_done) begin
            if (abort_pending_r || abort) begin
              completion_task_id <= macro_active_r ? macro_parent_task_id_r : desc_task_id;
              queue_run_r <= 1'b0;
              macro_active_r <= 1'b0;
              if (completion_required_r && completion_available)
                `START_COMPLETION(1'b1, ERR_ABORT, macro_result_r,
                                 macro_cycles_r, macro_elements_r);
              else begin
                `REPORT_EVENT(1'b1, ERR_ABORT, macro_result_r,
                       macro_cycles_r, macro_elements_r);
                busy <= 1'b0;
                state_r <= ST_IDLE;
              end
            end else if (fetch_error) begin
              completion_task_id <= macro_active_r ? macro_parent_task_id_r : desc_task_id;
              macro_active_r <= 1'b0;
              if (completion_required_r && completion_available)
                `START_COMPLETION(1'b1, ERR_FETCH, macro_result_r,
                                 macro_cycles_r, macro_elements_r);
              else begin
                `REPORT_EVENT(1'b1, ERR_FETCH, macro_result_r,
                       macro_cycles_r, macro_elements_r);
                busy <= 1'b0;
                state_r <= ST_IDLE;
              end
            end else begin
              dependency_wait_cycles_r <= 16'd0;
              state_r <= ST_DECODE;
            end
          end

          ST_DECODE: begin
            if (abort_pending_r || abort) begin
              completion_task_id <= macro_active_r ? macro_parent_task_id_r : desc_task_id;
              queue_run_r <= 1'b0;
              macro_active_r <= 1'b0;
              if (completion_required_r && completion_available)
                `START_COMPLETION(1'b1, ERR_ABORT, macro_result_r,
                                 macro_cycles_r, macro_elements_r);
              else begin
                `REPORT_EVENT(1'b1, ERR_ABORT, macro_result_r,
                       macro_cycles_r, macro_elements_r);
                busy <= 1'b0;
                state_r <= ST_IDLE;
              end
            end else if (descriptor_invalid) begin
              completion_task_id <= macro_active_r ? macro_parent_task_id_r : desc_task_id;
              macro_active_r <= 1'b0;
              if (completion_required_r && completion_available)
                `START_COMPLETION(1'b1, ERR_DESC, macro_result_r,
                                 macro_cycles_r, macro_elements_r);
              else begin
                `REPORT_EVENT(1'b1, ERR_DESC, macro_result_r,
                       macro_cycles_r, macro_elements_r);
                busy <= 1'b0;
                state_r <= ST_IDLE;
              end
            end else if (!dependencies_ready) begin
              if (dependency_wait_timed_out) begin
                completion_task_id <= macro_active_r ? macro_parent_task_id_r : desc_task_id;
                macro_active_r <= 1'b0;
                if (completion_required_r && completion_available)
                  `START_COMPLETION(1'b1, ERR_DEPENDENCY, dependency_events,
                                   macro_cycles_r, macro_elements_r);
                else begin
                  `REPORT_EVENT(1'b1, ERR_DEPENDENCY, dependency_events,
                         macro_cycles_r, macro_elements_r);
                  busy <= 1'b0;
                  state_r <= ST_IDLE;
                end
              end else begin
                dependency_wait_cycles_r <= dependency_wait_cycles_r + 1'b1;
              end
            end else if (macro_op) begin
              // Descriptor v4 uses src0 as the child-list base; ABI v7 uses
              // {src1,src0} as a 64-bit base. The list is 64-byte aligned,
              // length is the child count, and flag[3] selects external-memory
              // versus scratchpad children.
              // The parent owns one completion; children execute in order and
              // fail-stop without publishing intermediate completions.
              macro_active_r <= 1'b1;
              macro_parent_task_id_r <= desc_task_id;
              macro_parent_signal_mask_r <= desc_signal_mask;
              macro_child_count_r <= desc_length;
              macro_child_index_r <= 16'd0;
              macro_child_base_r <= desc_version == 8'd7 ?
                                    {desc_src1, desc_src0} :
                                    {32'd0, desc_src0};
              macro_child_external_r <= desc_flags[3];
              macro_cycles_r <= 32'd0;
              macro_elements_r <= 32'd0;
              macro_result_r <= 32'd0;
              dependency_events <= dependency_events & ~desc_clear_mask;
              completion_task_id <= desc_task_id;
              macro_child_fetch_r <= 1'b1;
              fetch_base <= desc_version == 8'd7 ?
                            {desc_src1, desc_src0} :
                            {32'd0, desc_src0};
              fetch_external <= desc_flags[3];
              fetch_start <= 1'b1;
              dependency_wait_cycles_r <= 16'd0;
              state_r <= ST_FETCH;
            end else if (!compute_busy) begin
              {launch_valid, launch_op, launch_task_id, launch_src0,
               launch_src1, launch_dst, launch_length, launch_m, launch_n,
               launch_k, launch_shift, launch_activation, launch_bias_base,
               launch_bias_enable, launch_flags, launch_aux0,
               launch_src0_stride, launch_src1_stride, launch_dst_stride,
               launch_batch_count, launch_head_count} <=
              make_launch(desc_op, desc_task_id, desc_src0, desc_src1, desc_dst,
                           desc_length, desc_m, desc_n, desc_k, desc_shift,
                          desc_activation, desc_bias_base, desc_bias_enable,
                          desc_flags, desc_aux0, desc_src0_stride,
                          desc_src1_stride, desc_dst_stride, desc_batch_count,
                          desc_head_count);
              pending_signal_mask_r <= desc_signal_mask;
              dependency_events <= dependency_events & ~desc_clear_mask;
              completion_task_id <= desc_task_id;
              state_r <= ST_RUN;
            end
          end

          ST_RUN: if (compute_done) begin
            if (!compute_error)
              dependency_events <= dependency_events | pending_signal_mask_r;
            if (compute_error && compute_error_code == ERR_ABORT)
              queue_run_r <= 1'b0;
            if (macro_active_r) begin
              macro_cycles_r <= macro_cycles_r + compute_cycles;
              macro_elements_r <= macro_elements_r + compute_elements;
              macro_result_r <= compute_result;
              completion_task_id <= macro_parent_task_id_r;
              if (compute_error) begin
                macro_active_r <= 1'b0;
                if (completion_required_r && completion_available)
                  `START_COMPLETION(1'b1, compute_error_code, compute_result,
                                   macro_cycles_r + compute_cycles,
                                   macro_elements_r + compute_elements);
                else begin
                  `REPORT_EVENT(1'b1, compute_error_code, compute_result,
                         macro_cycles_r + compute_cycles,
                         macro_elements_r + compute_elements);
                  busy <= 1'b0;
                  state_r <= ST_IDLE;
                end
              end else if (macro_child_index_r + 1'b1 < macro_child_count_r) begin
                macro_child_index_r <= macro_child_index_r + 1'b1;
                macro_child_fetch_r <= 1'b1;
                fetch_base <= macro_child_base_r +
                              ({48'd0, macro_child_index_r + 1'b1} << 6);
                fetch_external <= macro_child_external_r;
                fetch_start <= 1'b1;
                dependency_wait_cycles_r <= 16'd0;
                state_r <= ST_FETCH;
              end else begin
                macro_active_r <= 1'b0;
                dependency_events <= (dependency_events | pending_signal_mask_r) |
                                     macro_parent_signal_mask_r;
                if (completion_required_r && completion_available)
                  `START_COMPLETION(1'b0, 0, compute_result,
                                   macro_cycles_r + compute_cycles,
                                   macro_elements_r + compute_elements);
                else begin
                  `REPORT_EVENT(1'b0, 0, compute_result,
                         macro_cycles_r + compute_cycles,
                         macro_elements_r + compute_elements);
                  busy <= 1'b0;
                  state_r <= ST_IDLE;
                end
              end
            end else if (completion_required_r) begin
              if (completion_available)
                `START_COMPLETION(compute_error,
                                 compute_error ? compute_error_code : 0,
                                 compute_result, compute_cycles, compute_elements);
              else begin
                `REPORT_EVENT(1'b1, completion_protected ? ERR_PROT : ERR_CPL,
                       compute_result, compute_cycles, compute_elements);
                busy <= 1'b0;
                state_r <= ST_IDLE;
              end
            end else begin
              `REPORT_EVENT(compute_error, compute_error ? compute_error_code : 0,
                     compute_result, compute_cycles, compute_elements);
              busy <= 1'b0;
              state_r <= ST_IDLE;
            end
          end

          ST_CPL: if (completion_done) begin
            `REPORT_EVENT(pending_error_r, pending_error_code_r, pending_result_r,
                   pending_cycles_r, pending_elements_r);
            if (queue_run_r && cmdq_head_index != cmdq_tail &&
                !((cplq_tail_next >= cplq_size-1 ? 0 : cplq_tail_next+1) == cplq_head)) begin
              macro_child_fetch_r <= 1'b0;
              fetch_base <= cmdq_base + (cmdq_head_index << 6);
              fetch_external <= desc_external;
              fetch_start <= 1'b1;
              state_r <= ST_FETCH;
            end else begin
              busy <= 1'b0;
              queue_run_r <= 1'b0;
              state_r <= ST_IDLE;
            end
          end

          ST_TILE: begin
            busy <= 1'b1;
            if (tile_done) begin
              `REPORT_EVENT(tile_error, tile_error ? tile_error_code : 0,
                     tile_result, tile_perf_total, tile_elements);
              busy <= 1'b0;
              state_r <= ST_IDLE;
            end
          end

          default: state_r <= ST_IDLE;
        endcase

        // The tile pipeline is a sub-scheduler of this command processor.
        // Its compute pulse uses the same launch interface as direct/CMDQ work.
        if (tile_compute_start) begin
          {launch_valid, launch_op, launch_task_id, launch_src0,
           launch_src1, launch_dst, launch_length, launch_m, launch_n,
           launch_k, launch_shift, launch_activation, launch_bias_base,
           launch_bias_enable, launch_flags, launch_aux0,
           launch_src0_stride, launch_src1_stride, launch_dst_stride,
           launch_batch_count, launch_head_count} <=
          make_launch(tile_launch_op, 16'd0, tile_launch_src0,
                      tile_launch_src1, tile_launch_dst, tile_launch_length,
                      tile_launch_m, tile_launch_n, tile_launch_k,
                      tile_launch_shift, tile_launch_activation,
                      tile_launch_bias_base, tile_launch_bias_enable,
                      {7'd0, tile_launch_bias_enable}, 32'd1, 32'd0, 32'd0,
                      32'd0, 16'd1, 16'd1);
          pending_signal_mask_r <= 16'd0;
        end
      end
    end

`undef REPORT_EVENT
`undef START_COMPLETION
endmodule
