`timescale 1ns / 1ps

// Dual-clock command-path integration wrapper.
//
// The ctrl-domain register/snapshot interface is intentionally the same as
// ai_accel_dual_clock_shell.  The shell is the only CDC boundary; all command
// processor, descriptor/fetch, compute, DMA, tile, and completion-writer
// signals below are compute-domain signals.
//
// IMPORTANT: ai_command_processor has no ready/valid command input of its own.
// The shell command packet is therefore accepted only while the processor is
// idle, and its control pulses are qualified with compute_cmd_valid.  A
// one-entry elastic buffer converts the processor's pulse-only event to
// ready/valid before it enters the reverse async FIFO.  The wrapper blocks a
// new command until the preceding event has entered that FIFO.
module ai_accel_dual_clock_command_path #(
    parameter integer CMD_PACKET_WIDTH = 1024,
    parameter integer CPL_PACKET_WIDTH = 256,
    parameter integer FIFO_DEPTH       = 16
)(
    // Control-domain shell interface (mirrors ai_accel_dual_clock_shell).
    input wire ctrl_clk, input wire ctrl_resetn,
    input wire ctrl_cmd_valid, output wire ctrl_cmd_ready,
    input wire [15:0] ctrl_cmd_sequence,
    input wire ctrl_abort, input wire ctrl_submit,
    input wire ctrl_direct_start, input wire ctrl_tile_start,
    input wire [63:0] ctrl_cmdq_base, input wire [31:0] ctrl_cmdq_size,
    input wire [31:0] ctrl_cmdq_tail, input wire ctrl_desc_external,
    input wire ctrl_cmdq_head_load, input wire [31:0] ctrl_cmdq_head_seed,
    input wire [31:0] ctrl_cplq_base, input wire [31:0] ctrl_cplq_size,
    input wire [31:0] ctrl_cplq_head, input wire ctrl_completion_protected,
    input wire ctrl_cplq_tail_load, input wire [31:0] ctrl_cplq_tail_seed,
    input wire [7:0] ctrl_cfg_op, input wire [31:0] ctrl_cfg_src0,
    input wire [31:0] ctrl_cfg_src1, input wire [31:0] ctrl_cfg_dst,
    input wire [15:0] ctrl_cfg_length, input wire [15:0] ctrl_cfg_m,
    input wire [15:0] ctrl_cfg_n, input wire [15:0] ctrl_cfg_k,
    input wire [4:0] ctrl_cfg_shift, input wire [1:0] ctrl_cfg_activation,
    input wire [31:0] ctrl_cfg_bias_base, input wire ctrl_cfg_bias_enable,
    input wire [15:0] ctrl_tile_count,
    input wire [63:0] ctrl_tile_ext_input_base,
    input wire [63:0] ctrl_tile_ext_output_base,
    input wire [31:0] ctrl_tile_ext_input_stride,
    input wire [31:0] ctrl_tile_ext_output_stride,
    input wire [31:0] ctrl_tile_buffer0_base,
    input wire [31:0] ctrl_tile_buffer1_base,
    input wire [31:0] ctrl_tile_output_offset,
    input wire [15:0] ctrl_tile_input_words,
    input wire [15:0] ctrl_tile_output_words,

    // Compute clock and externally-owned status/fetch/descriptor signals.
    input wire compute_clk, input wire compute_resetn,
    input wire compute_fetch_busy, input wire compute_fetch_done,
    input wire compute_fetch_error,
    input wire [7:0] compute_desc_op, input wire [15:0] compute_desc_task_id,
    input wire [31:0] compute_desc_src0, input wire [31:0] compute_desc_src1,
    input wire [31:0] compute_desc_dst, input wire [15:0] compute_desc_length,
    input wire [15:0] compute_desc_m, input wire [15:0] compute_desc_n,
    input wire [15:0] compute_desc_k, input wire [4:0] compute_desc_shift,
    input wire [1:0] compute_desc_activation,
    input wire [31:0] compute_desc_bias_base,
    input wire compute_desc_bias_enable, input wire [7:0] compute_desc_flags,
    input wire [31:0] compute_desc_aux0,
    input wire [31:0] compute_desc_src0_stride,
    input wire [31:0] compute_desc_src1_stride,
    input wire [31:0] compute_desc_dst_stride,
    input wire [15:0] compute_desc_batch_count,
    input wire [15:0] compute_desc_head_count,
    input wire [15:0] compute_desc_wait_mask,
    input wire [15:0] compute_desc_signal_mask,
    input wire [15:0] compute_desc_clear_mask,
    input wire [7:0] compute_desc_version,
    input wire compute_status_busy, input wire compute_status_done,
    input wire compute_status_error, input wire [3:0] compute_status_error_code,
    input wire [31:0] compute_status_result,
    input wire [31:0] compute_status_cycles,
    input wire [31:0] compute_status_elements,
    input wire compute_dma_busy, input wire compute_dma_done,
    input wire compute_dma_error, input wire [3:0] compute_dma_error_code,

    // Compute-domain command processor outputs.
    output wire compute_fetch_start, output wire [63:0] compute_fetch_base,
    output wire compute_fetch_external,
    output wire compute_launch_valid, output wire [7:0] compute_launch_op,
    output wire [15:0] compute_launch_task_id,
    output wire [31:0] compute_launch_src0, output wire [31:0] compute_launch_src1,
    output wire [31:0] compute_launch_dst, output wire [15:0] compute_launch_length,
    output wire [15:0] compute_launch_m, output wire [15:0] compute_launch_n,
    output wire [15:0] compute_launch_k, output wire [4:0] compute_launch_shift,
    output wire [1:0] compute_launch_activation,
    output wire [31:0] compute_launch_bias_base,
    output wire compute_launch_bias_enable, output wire [7:0] compute_launch_flags,
    output wire [31:0] compute_launch_aux0,
    output wire [31:0] compute_launch_src0_stride,
    output wire [31:0] compute_launch_src1_stride,
    output wire [31:0] compute_launch_dst_stride,
    output wire [15:0] compute_launch_batch_count,
    output wire [15:0] compute_launch_head_count,
    output wire compute_tile_dma_start, output wire compute_tile_dma_store,
    output wire [63:0] compute_tile_dma_ext_addr,
    output wire [31:0] compute_tile_dma_spad_addr,
    output wire [15:0] compute_tile_dma_length_words,
    output wire compute_tile_active,
    output wire [31:0] compute_tile_perf_total,
    output wire [31:0] compute_tile_perf_dma,
    output wire [31:0] compute_tile_perf_compute,
    output wire [31:0] compute_tile_perf_overlap,
    output wire [31:0] compute_tile_perf_stall,
    output wire [15:0] compute_tile_completed,

    // Completion-writer scratchpad client (compute domain).
    output wire compute_completion_spad_valid,
    output wire compute_completion_spad_write,
    output wire [31:0] compute_completion_spad_addr,
    output wire [31:0] compute_completion_spad_wdata,
    input wire compute_completion_spad_ready,

    // Optional visibility of lifecycle state in the compute domain.
    output wire compute_processor_busy,
    output wire [31:0] compute_cmdq_head,
    output wire [31:0] compute_cplq_tail,
    output wire [15:0] compute_dependency_events,
    output wire compute_event_overflow,

    // Control-domain completion/event consumer (mirrors shell outputs).
    output wire ctrl_cpl_valid, input wire ctrl_cpl_ready,
    output wire [7:0] ctrl_cpl_packet_version,
    output wire [15:0] ctrl_event_sequence,
    output wire ctrl_event_valid, output wire ctrl_event_error,
    output wire [3:0] ctrl_event_error_code,
    output wire [31:0] ctrl_event_result,
    output wire [31:0] ctrl_event_cycles,
    output wire [31:0] ctrl_event_elements,
    output wire [31:0] ctrl_cmdq_head,
    output wire [31:0] ctrl_cplq_tail,
    output wire [15:0] ctrl_dependency_events,
    output wire ctrl_busy
);
    wire compute_cmd_valid, compute_cmd_ready;
    wire [7:0] compute_cmd_packet_version;
    wire [15:0] compute_cmd_sequence;
    wire compute_abort, compute_submit, compute_direct_start, compute_tile_start;
    wire [63:0] compute_cmdq_base;
    wire [31:0] compute_cmdq_size, compute_cmdq_tail;
    wire compute_desc_external, compute_cmdq_head_load;
    wire [31:0] compute_cmdq_head_seed;
    wire [31:0] compute_cplq_base, compute_cplq_size, compute_cplq_head;
    wire compute_completion_protected, compute_cplq_tail_load;
    wire [31:0] compute_cplq_tail_seed;
    wire [7:0] compute_cfg_op;
    wire [31:0] compute_cfg_src0, compute_cfg_src1, compute_cfg_dst;
    wire [15:0] compute_cfg_length, compute_cfg_m, compute_cfg_n, compute_cfg_k;
    wire [4:0] compute_cfg_shift; wire [1:0] compute_cfg_activation;
    wire [31:0] compute_cfg_bias_base; wire compute_cfg_bias_enable;
    wire [15:0] compute_tile_count;
    wire [63:0] compute_tile_ext_input_base, compute_tile_ext_output_base;
    wire [31:0] compute_tile_ext_input_stride, compute_tile_ext_output_stride;
    wire [31:0] compute_tile_buffer0_base, compute_tile_buffer1_base;
    wire [31:0] compute_tile_output_offset;
    wire [15:0] compute_tile_input_words, compute_tile_output_words;

    wire processor_completion_start;
    wire [31:0] processor_completion_base, processor_completion_index;
    wire [15:0] processor_completion_task_id;
    wire [3:0] processor_completion_status, processor_completion_error;
    wire [31:0] processor_completion_result, processor_completion_elements;
    wire completion_busy, completion_done;
    wire processor_event_valid, processor_event_error;
    wire [3:0] processor_event_error_code;
    wire [31:0] processor_event_result, processor_event_cycles;
    wire [31:0] processor_event_elements;
    reg [15:0] event_sequence_r;
    wire [198:0] event_buffer_data;
    wire event_buffer_valid, event_buffer_ready;
    wire [15:0] buffered_event_sequence;
    wire buffered_event_valid, buffered_event_error;
    wire [3:0] buffered_event_error_code;
    wire [31:0] buffered_event_result, buffered_event_cycles;
    wire [31:0] buffered_event_elements, buffered_cmdq_head, buffered_cplq_tail;
    wire [15:0] buffered_dependency_events;
    wire buffered_busy;
    wire compute_launch_request = compute_submit || compute_direct_start ||
                                  compute_tile_start || compute_cmdq_head_load ||
                                  compute_cplq_tail_load;
    // ai_command_processor consumes control inputs as pulses.  A FIFO packet
    // may legally remain valid while the processor is busy, so only the
    // ready/valid handshake may publish its pulse fields into the processor.
    wire compute_command_fire = compute_cmd_valid && compute_cmd_ready;

    // A launch or debug pointer seed waits for an idle processor.  Pure
    // configuration updates (notably a software CPLQ_HEAD update) and abort
    // requests are allowed while it is busy, so queue flow control does not
    // stall behind a long compute operation.  No packet may overtake a
    // pending completion/event in the reverse direction.
    assign compute_cmd_ready = !event_buffer_valid && !processor_event_valid &&
                               (!compute_processor_busy || !compute_launch_request);

    always @(posedge compute_clk or negedge compute_resetn) begin
        if (!compute_resetn)
            event_sequence_r <= 16'd0;
        else if (compute_command_fire &&
                 (compute_submit || compute_direct_start || compute_tile_start))
            event_sequence_r <= compute_cmd_sequence;
    end

    ai_accel_dual_clock_shell #(
        .CMD_PACKET_WIDTH(CMD_PACKET_WIDTH),
        .CPL_PACKET_WIDTH(CPL_PACKET_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) shell_u (
        .ctrl_clk(ctrl_clk), .ctrl_resetn(ctrl_resetn),
        .ctrl_cmd_valid(ctrl_cmd_valid), .ctrl_cmd_ready(ctrl_cmd_ready),
        .ctrl_cmd_sequence(ctrl_cmd_sequence), .ctrl_abort(ctrl_abort),
        .ctrl_submit(ctrl_submit), .ctrl_direct_start(ctrl_direct_start),
        .ctrl_tile_start(ctrl_tile_start), .ctrl_cmdq_base(ctrl_cmdq_base),
        .ctrl_cmdq_size(ctrl_cmdq_size), .ctrl_cmdq_tail(ctrl_cmdq_tail),
        .ctrl_desc_external(ctrl_desc_external),
        .ctrl_cmdq_head_load(ctrl_cmdq_head_load),
        .ctrl_cmdq_head_seed(ctrl_cmdq_head_seed),
        .ctrl_cplq_base(ctrl_cplq_base), .ctrl_cplq_size(ctrl_cplq_size),
        .ctrl_cplq_head(ctrl_cplq_head),
        .ctrl_completion_protected(ctrl_completion_protected),
        .ctrl_cplq_tail_load(ctrl_cplq_tail_load),
        .ctrl_cplq_tail_seed(ctrl_cplq_tail_seed),
        .ctrl_cfg_op(ctrl_cfg_op), .ctrl_cfg_src0(ctrl_cfg_src0),
        .ctrl_cfg_src1(ctrl_cfg_src1), .ctrl_cfg_dst(ctrl_cfg_dst),
        .ctrl_cfg_length(ctrl_cfg_length), .ctrl_cfg_m(ctrl_cfg_m),
        .ctrl_cfg_n(ctrl_cfg_n), .ctrl_cfg_k(ctrl_cfg_k),
        .ctrl_cfg_shift(ctrl_cfg_shift), .ctrl_cfg_activation(ctrl_cfg_activation),
        .ctrl_cfg_bias_base(ctrl_cfg_bias_base),
        .ctrl_cfg_bias_enable(ctrl_cfg_bias_enable),
        .ctrl_tile_count(ctrl_tile_count),
        .ctrl_tile_ext_input_base(ctrl_tile_ext_input_base),
        .ctrl_tile_ext_output_base(ctrl_tile_ext_output_base),
        .ctrl_tile_ext_input_stride(ctrl_tile_ext_input_stride),
        .ctrl_tile_ext_output_stride(ctrl_tile_ext_output_stride),
        .ctrl_tile_buffer0_base(ctrl_tile_buffer0_base),
        .ctrl_tile_buffer1_base(ctrl_tile_buffer1_base),
        .ctrl_tile_output_offset(ctrl_tile_output_offset),
        .ctrl_tile_input_words(ctrl_tile_input_words),
        .ctrl_tile_output_words(ctrl_tile_output_words),
        .compute_clk(compute_clk), .compute_resetn(compute_resetn),
        .compute_cmd_valid(compute_cmd_valid), .compute_cmd_ready(compute_cmd_ready),
        .compute_cmd_packet_version(compute_cmd_packet_version),
        .compute_cmd_sequence(compute_cmd_sequence), .compute_abort(compute_abort),
        .compute_submit(compute_submit), .compute_direct_start(compute_direct_start),
        .compute_tile_start(compute_tile_start), .compute_cmdq_base(compute_cmdq_base),
        .compute_cmdq_size(compute_cmdq_size), .compute_cmdq_tail(compute_cmdq_tail),
        .compute_desc_external(compute_desc_external),
        .compute_cmdq_head_load(compute_cmdq_head_load),
        .compute_cmdq_head_seed(compute_cmdq_head_seed),
        .compute_cplq_base(compute_cplq_base), .compute_cplq_size(compute_cplq_size),
        .compute_cplq_head(compute_cplq_head),
        .compute_completion_protected(compute_completion_protected),
        .compute_cplq_tail_load(compute_cplq_tail_load),
        .compute_cplq_tail_seed(compute_cplq_tail_seed),
        .compute_cfg_op(compute_cfg_op), .compute_cfg_src0(compute_cfg_src0),
        .compute_cfg_src1(compute_cfg_src1), .compute_cfg_dst(compute_cfg_dst),
        .compute_cfg_length(compute_cfg_length), .compute_cfg_m(compute_cfg_m),
        .compute_cfg_n(compute_cfg_n), .compute_cfg_k(compute_cfg_k),
        .compute_cfg_shift(compute_cfg_shift),
        .compute_cfg_activation(compute_cfg_activation),
        .compute_cfg_bias_base(compute_cfg_bias_base),
        .compute_cfg_bias_enable(compute_cfg_bias_enable),
        .compute_tile_count(compute_tile_count),
        .compute_tile_ext_input_base(compute_tile_ext_input_base),
        .compute_tile_ext_output_base(compute_tile_ext_output_base),
        .compute_tile_ext_input_stride(compute_tile_ext_input_stride),
        .compute_tile_ext_output_stride(compute_tile_ext_output_stride),
        .compute_tile_buffer0_base(compute_tile_buffer0_base),
        .compute_tile_buffer1_base(compute_tile_buffer1_base),
        .compute_tile_output_offset(compute_tile_output_offset),
        .compute_tile_input_words(compute_tile_input_words),
        .compute_tile_output_words(compute_tile_output_words),
        .compute_cpl_valid(event_buffer_valid),
        .compute_cpl_ready(event_buffer_ready),
        .compute_event_sequence(buffered_event_sequence),
        .compute_event_valid(buffered_event_valid),
        .compute_event_error(buffered_event_error),
        .compute_event_error_code(buffered_event_error_code),
        .compute_event_result(buffered_event_result),
        .compute_event_cycles(buffered_event_cycles),
        .compute_event_elements(buffered_event_elements),
        .compute_cmdq_head(buffered_cmdq_head), .compute_cplq_tail(buffered_cplq_tail),
        .compute_dependency_events(buffered_dependency_events),
        .compute_busy(buffered_busy),
        .ctrl_cpl_valid(ctrl_cpl_valid), .ctrl_cpl_ready(ctrl_cpl_ready),
        .ctrl_cpl_packet_version(ctrl_cpl_packet_version),
        .ctrl_event_sequence(ctrl_event_sequence), .ctrl_event_valid(ctrl_event_valid),
        .ctrl_event_error(ctrl_event_error),
        .ctrl_event_error_code(ctrl_event_error_code),
        .ctrl_event_result(ctrl_event_result), .ctrl_event_cycles(ctrl_event_cycles),
        .ctrl_event_elements(ctrl_event_elements), .ctrl_cmdq_head(ctrl_cmdq_head),
        .ctrl_cplq_tail(ctrl_cplq_tail),
        .ctrl_dependency_events(ctrl_dependency_events), .ctrl_busy(ctrl_busy)
    );

    ai_command_processor command_processor_u(
        .clk(compute_clk), .resetn(compute_resetn),
        .abort(compute_command_fire && compute_abort),
        .submit(compute_command_fire && compute_submit),
        .direct_start(compute_command_fire && compute_direct_start),
        .tile_start(compute_command_fire && compute_tile_start),
        .cmdq_base(compute_cmdq_base), .cmdq_size(compute_cmdq_size),
        .cmdq_tail(compute_cmdq_tail), .desc_external(compute_desc_external),
        .cmdq_head_load(compute_command_fire && compute_cmdq_head_load),
        .cmdq_head_seed(compute_cmdq_head_seed), .cplq_base(compute_cplq_base),
        .cplq_size(compute_cplq_size), .cplq_head(compute_cplq_head),
        .completion_protected(compute_completion_protected),
        .cplq_tail_load(compute_command_fire && compute_cplq_tail_load),
        .cplq_tail_seed(compute_cplq_tail_seed), .cfg_op(compute_cfg_op),
        .cfg_src0(compute_cfg_src0), .cfg_src1(compute_cfg_src1),
        .cfg_dst(compute_cfg_dst), .cfg_length(compute_cfg_length),
        .cfg_m(compute_cfg_m), .cfg_n(compute_cfg_n), .cfg_k(compute_cfg_k),
        .cfg_shift(compute_cfg_shift), .cfg_activation(compute_cfg_activation),
        .cfg_bias_base(compute_cfg_bias_base),
        .cfg_bias_enable(compute_cfg_bias_enable), .tile_count(compute_tile_count),
        .tile_ext_input_base(compute_tile_ext_input_base),
        .tile_ext_output_base(compute_tile_ext_output_base),
        .tile_ext_input_stride(compute_tile_ext_input_stride),
        .tile_ext_output_stride(compute_tile_ext_output_stride),
        .tile_buffer0_base(compute_tile_buffer0_base),
        .tile_buffer1_base(compute_tile_buffer1_base),
        .tile_output_offset(compute_tile_output_offset),
        .tile_input_words(compute_tile_input_words),
        .tile_output_words(compute_tile_output_words),
        .fetch_busy(compute_fetch_busy), .fetch_done(compute_fetch_done),
        .fetch_error(compute_fetch_error), .desc_op(compute_desc_op),
        .desc_task_id(compute_desc_task_id), .desc_src0(compute_desc_src0),
        .desc_src1(compute_desc_src1), .desc_dst(compute_desc_dst),
        .desc_length(compute_desc_length), .desc_m(compute_desc_m),
        .desc_n(compute_desc_n), .desc_k(compute_desc_k),
        .desc_shift(compute_desc_shift), .desc_activation(compute_desc_activation),
        .desc_bias_base(compute_desc_bias_base),
        .desc_bias_enable(compute_desc_bias_enable), .desc_flags(compute_desc_flags),
        .desc_aux0(compute_desc_aux0),
        .desc_src0_stride(compute_desc_src0_stride),
        .desc_src1_stride(compute_desc_src1_stride),
        .desc_dst_stride(compute_desc_dst_stride),
        .desc_batch_count(compute_desc_batch_count),
        .desc_head_count(compute_desc_head_count),
        .desc_wait_mask(compute_desc_wait_mask),
        .desc_signal_mask(compute_desc_signal_mask),
        .desc_clear_mask(compute_desc_clear_mask), .desc_version(compute_desc_version),
        .compute_busy(compute_status_busy), .compute_done(compute_status_done),
        .compute_error(compute_status_error),
        .compute_error_code(compute_status_error_code),
        .compute_result(compute_status_result), .compute_cycles(compute_status_cycles),
        .compute_elements(compute_status_elements), .dma_busy(compute_dma_busy),
        .dma_done(compute_dma_done), .dma_error(compute_dma_error),
        .dma_error_code(compute_dma_error_code), .completion_busy(completion_busy),
        .completion_done(completion_done), .fetch_start(compute_fetch_start),
        .fetch_base(compute_fetch_base), .fetch_external(compute_fetch_external),
        .launch_valid(compute_launch_valid), .launch_op(compute_launch_op),
        .launch_task_id(compute_launch_task_id), .launch_src0(compute_launch_src0),
        .launch_src1(compute_launch_src1), .launch_dst(compute_launch_dst),
        .launch_length(compute_launch_length), .launch_m(compute_launch_m),
        .launch_n(compute_launch_n), .launch_k(compute_launch_k),
        .launch_shift(compute_launch_shift),
        .launch_activation(compute_launch_activation),
        .launch_bias_base(compute_launch_bias_base),
        .launch_bias_enable(compute_launch_bias_enable),
        .launch_flags(compute_launch_flags), .launch_aux0(compute_launch_aux0),
        .launch_src0_stride(compute_launch_src0_stride),
        .launch_src1_stride(compute_launch_src1_stride),
        .launch_dst_stride(compute_launch_dst_stride),
        .launch_batch_count(compute_launch_batch_count),
        .launch_head_count(compute_launch_head_count),
        .tile_dma_start(compute_tile_dma_start), .tile_dma_store(compute_tile_dma_store),
        .tile_dma_ext_addr(compute_tile_dma_ext_addr),
        .tile_dma_spad_addr(compute_tile_dma_spad_addr),
        .tile_dma_length_words(compute_tile_dma_length_words),
        .tile_active(compute_tile_active), .tile_perf_total(compute_tile_perf_total),
        .tile_perf_dma(compute_tile_perf_dma),
        .tile_perf_compute(compute_tile_perf_compute),
        .tile_perf_overlap(compute_tile_perf_overlap),
        .tile_perf_stall(compute_tile_perf_stall), .tile_completed(compute_tile_completed),
        .completion_start(processor_completion_start),
        .completion_base(processor_completion_base),
        .completion_index(processor_completion_index),
        .completion_task_id(processor_completion_task_id),
        .completion_status(processor_completion_status),
        .completion_error(processor_completion_error),
        .completion_result(processor_completion_result),
        .completion_elements(processor_completion_elements),
        .cmdq_head(compute_cmdq_head), .cplq_tail(compute_cplq_tail),
        .busy(compute_processor_busy), .event_valid(processor_event_valid),
        .event_error(processor_event_error),
        .event_error_code(processor_event_error_code),
        .event_result(processor_event_result), .event_cycles(processor_event_cycles),
        .event_elements(processor_event_elements),
        .dependency_events(compute_dependency_events)
    );

    // Capture the one-cycle processor event before the reverse FIFO applies
    // arbitrary ctrl-domain back-pressure.  A normal command cannot produce
    // a second event before this entry drains because compute_cmd_ready above
    // is held low while event_buffer_valid is asserted.
    ai_cdc_event_buffer #(.DATA_WIDTH(199)) event_buffer_u(
        .clk(compute_clk), .resetn(compute_resetn),
        .in_valid(processor_event_valid),
        .in_data({event_sequence_r, 1'b1, processor_event_error,
                  processor_event_error_code, processor_event_result,
                  processor_event_cycles, processor_event_elements,
                  compute_cmdq_head, compute_cplq_tail,
                  compute_dependency_events, compute_processor_busy}),
        .out_valid(event_buffer_valid), .out_ready(event_buffer_ready),
        .out_data(event_buffer_data), .overflow(compute_event_overflow)
    );

    assign {buffered_event_sequence, buffered_event_valid, buffered_event_error,
            buffered_event_error_code, buffered_event_result, buffered_event_cycles,
            buffered_event_elements, buffered_cmdq_head, buffered_cplq_tail,
            buffered_dependency_events, buffered_busy} = event_buffer_data;

    ai_completion_writer completion_writer_u(
        .clk(compute_clk), .resetn(compute_resetn),
        .start(processor_completion_start), .cplq_base(processor_completion_base),
        .cplq_index(processor_completion_index),
        .task_id(processor_completion_task_id), .status(processor_completion_status),
        .error_code(processor_completion_error), .result(processor_completion_result),
        .element_count(processor_completion_elements),
        .spad_valid(compute_completion_spad_valid),
        .spad_write(compute_completion_spad_write),
        .spad_addr(compute_completion_spad_addr),
        .spad_wdata(compute_completion_spad_wdata),
        .spad_ready(compute_completion_spad_ready),
        .busy(completion_busy), .done(completion_done)
    );
endmodule
