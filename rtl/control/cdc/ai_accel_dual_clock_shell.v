`timescale 1ns / 1ps

// Command/completion CDC protocol shell.
//
// This is an integration boundary, not a replacement for ai_accel_top.  The
// current product top remains single-clock.  A ctrl-domain publisher presents
// an immutable command configuration snapshot with ctrl_cmd_valid and holds
// every payload input stable until ctrl_cmd_ready.  The shell atomically
// delivers it to the compute domain.  The compute side uses the reverse FIFO
// for software-visible completion/event state.
//
// Command lifecycle and CMDQ_HEAD/CPLQ_TAIL ownership stay in
// ai_command_processor.  In particular, the completion writer remains in the
// compute domain; this shell transfers its already-published event/state only.
module ai_accel_dual_clock_shell #(
    parameter integer CMD_PACKET_WIDTH = 1024,
    parameter integer CPL_PACKET_WIDTH = 256,
    parameter integer FIFO_DEPTH       = 16
)(
    // Control-domain command snapshot publisher.
    input  wire        ctrl_clk,
    input  wire        ctrl_resetn,
    input  wire        ctrl_cmd_valid,
    output wire        ctrl_cmd_ready,
    input  wire [15:0] ctrl_cmd_sequence,
    input  wire        ctrl_abort,
    input  wire        ctrl_submit,
    input  wire        ctrl_direct_start,
    input  wire        ctrl_tile_start,
    input  wire [63:0] ctrl_cmdq_base,
    input  wire [31:0] ctrl_cmdq_size,
    input  wire [31:0] ctrl_cmdq_tail,
    input  wire        ctrl_desc_external,
    input  wire        ctrl_cmdq_head_load,
    input  wire [31:0] ctrl_cmdq_head_seed,
    input  wire [31:0] ctrl_cplq_base,
    input  wire [31:0] ctrl_cplq_size,
    input  wire [31:0] ctrl_cplq_head,
    input  wire        ctrl_completion_protected,
    input  wire        ctrl_cplq_tail_load,
    input  wire [31:0] ctrl_cplq_tail_seed,
    input  wire [7:0]  ctrl_cfg_op,
    input  wire [31:0] ctrl_cfg_src0,
    input  wire [31:0] ctrl_cfg_src1,
    input  wire [31:0] ctrl_cfg_dst,
    input  wire [15:0] ctrl_cfg_length,
    input  wire [15:0] ctrl_cfg_m,
    input  wire [15:0] ctrl_cfg_n,
    input  wire [15:0] ctrl_cfg_k,
    input  wire [4:0]  ctrl_cfg_shift,
    input  wire [1:0]  ctrl_cfg_activation,
    input  wire [31:0] ctrl_cfg_bias_base,
    input  wire        ctrl_cfg_bias_enable,
    input  wire [15:0] ctrl_tile_count,
    input  wire [63:0] ctrl_tile_ext_input_base,
    input  wire [63:0] ctrl_tile_ext_output_base,
    input  wire [31:0] ctrl_tile_ext_input_stride,
    input  wire [31:0] ctrl_tile_ext_output_stride,
    input  wire [31:0] ctrl_tile_buffer0_base,
    input  wire [31:0] ctrl_tile_buffer1_base,
    input  wire [31:0] ctrl_tile_output_offset,
    input  wire [15:0] ctrl_tile_input_words,
    input  wire [15:0] ctrl_tile_output_words,

    // Compute-domain command consumer.  Connect these fields to the command
    // processor only after the surrounding compute fabric is in this domain.
    input  wire        compute_clk,
    input  wire        compute_resetn,
    output wire        compute_cmd_valid,
    input  wire        compute_cmd_ready,
    output wire [7:0]  compute_cmd_packet_version,
    output wire [15:0] compute_cmd_sequence,
    output wire        compute_abort,
    output wire        compute_submit,
    output wire        compute_direct_start,
    output wire        compute_tile_start,
    output wire [63:0] compute_cmdq_base,
    output wire [31:0] compute_cmdq_size,
    output wire [31:0] compute_cmdq_tail,
    output wire        compute_desc_external,
    output wire        compute_cmdq_head_load,
    output wire [31:0] compute_cmdq_head_seed,
    output wire [31:0] compute_cplq_base,
    output wire [31:0] compute_cplq_size,
    output wire [31:0] compute_cplq_head,
    output wire        compute_completion_protected,
    output wire        compute_cplq_tail_load,
    output wire [31:0] compute_cplq_tail_seed,
    output wire [7:0]  compute_cfg_op,
    output wire [31:0] compute_cfg_src0,
    output wire [31:0] compute_cfg_src1,
    output wire [31:0] compute_cfg_dst,
    output wire [15:0] compute_cfg_length,
    output wire [15:0] compute_cfg_m,
    output wire [15:0] compute_cfg_n,
    output wire [15:0] compute_cfg_k,
    output wire [4:0]  compute_cfg_shift,
    output wire [1:0]  compute_cfg_activation,
    output wire [31:0] compute_cfg_bias_base,
    output wire        compute_cfg_bias_enable,
    output wire [15:0] compute_tile_count,
    output wire [63:0] compute_tile_ext_input_base,
    output wire [63:0] compute_tile_ext_output_base,
    output wire [31:0] compute_tile_ext_input_stride,
    output wire [31:0] compute_tile_ext_output_stride,
    output wire [31:0] compute_tile_buffer0_base,
    output wire [31:0] compute_tile_buffer1_base,
    output wire [31:0] compute_tile_output_offset,
    output wire [15:0] compute_tile_input_words,
    output wire [15:0] compute_tile_output_words,

    // Compute-domain event publisher.
    input  wire        compute_cpl_valid,
    output wire        compute_cpl_ready,
    input  wire [15:0] compute_event_sequence,
    input  wire        compute_event_valid,
    input  wire        compute_event_error,
    input  wire [3:0]  compute_event_error_code,
    input  wire [31:0] compute_event_result,
    input  wire [31:0] compute_event_cycles,
    input  wire [31:0] compute_event_elements,
    input  wire [31:0] compute_cmdq_head,
    input  wire [31:0] compute_cplq_tail,
    input  wire [15:0] compute_dependency_events,
    input  wire        compute_busy,

    // Control-domain completion/event consumer.
    output wire        ctrl_cpl_valid,
    input  wire        ctrl_cpl_ready,
    output wire [7:0]  ctrl_cpl_packet_version,
    output wire [15:0] ctrl_event_sequence,
    output wire        ctrl_event_valid,
    output wire        ctrl_event_error,
    output wire [3:0]  ctrl_event_error_code,
    output wire [31:0] ctrl_event_result,
    output wire [31:0] ctrl_event_cycles,
    output wire [31:0] ctrl_event_elements,
    output wire [31:0] ctrl_cmdq_head,
    output wire [31:0] ctrl_cplq_tail,
    output wire [15:0] ctrl_dependency_events,
    output wire        ctrl_busy
);
    localparam integer CMD_PAYLOAD_WIDTH = 864;
    localparam integer CPL_PAYLOAD_WIDTH = 207;

    wire [CMD_PACKET_WIDTH-1:0] ctrl_cmd_packet;
    wire [CMD_PACKET_WIDTH-1:0] compute_cmd_packet;
    wire [CPL_PACKET_WIDTH-1:0] compute_cpl_packet;
    wire [CPL_PACKET_WIDTH-1:0] ctrl_cpl_packet;

    // Packet v1 has an explicit version and sequence tag.  The most
    // significant bits are reserved and forced to zero for forward ABI growth.
    assign ctrl_cmd_packet = {
        {(CMD_PACKET_WIDTH-CMD_PAYLOAD_WIDTH){1'b0}},
        8'h01, ctrl_cmd_sequence,
        ctrl_abort, ctrl_submit, ctrl_direct_start, ctrl_tile_start,
        ctrl_cmdq_base, ctrl_cmdq_size, ctrl_cmdq_tail, ctrl_desc_external,
        ctrl_cmdq_head_load, ctrl_cmdq_head_seed,
        ctrl_cplq_base, ctrl_cplq_size, ctrl_cplq_head,
        ctrl_completion_protected, ctrl_cplq_tail_load, ctrl_cplq_tail_seed,
        ctrl_cfg_op, ctrl_cfg_src0, ctrl_cfg_src1, ctrl_cfg_dst,
        ctrl_cfg_length, ctrl_cfg_m, ctrl_cfg_n, ctrl_cfg_k,
        ctrl_cfg_shift, ctrl_cfg_activation, ctrl_cfg_bias_base,
        ctrl_cfg_bias_enable,
        ctrl_tile_count, ctrl_tile_ext_input_base, ctrl_tile_ext_output_base,
        ctrl_tile_ext_input_stride, ctrl_tile_ext_output_stride,
        ctrl_tile_buffer0_base, ctrl_tile_buffer1_base, ctrl_tile_output_offset,
        ctrl_tile_input_words, ctrl_tile_output_words
    };

    assign {
        compute_cmd_packet_version, compute_cmd_sequence,
        compute_abort, compute_submit, compute_direct_start, compute_tile_start,
        compute_cmdq_base, compute_cmdq_size, compute_cmdq_tail,
        compute_desc_external, compute_cmdq_head_load, compute_cmdq_head_seed,
        compute_cplq_base, compute_cplq_size, compute_cplq_head,
        compute_completion_protected, compute_cplq_tail_load, compute_cplq_tail_seed,
        compute_cfg_op, compute_cfg_src0, compute_cfg_src1, compute_cfg_dst,
        compute_cfg_length, compute_cfg_m, compute_cfg_n, compute_cfg_k,
        compute_cfg_shift, compute_cfg_activation, compute_cfg_bias_base,
        compute_cfg_bias_enable,
        compute_tile_count, compute_tile_ext_input_base, compute_tile_ext_output_base,
        compute_tile_ext_input_stride, compute_tile_ext_output_stride,
        compute_tile_buffer0_base, compute_tile_buffer1_base, compute_tile_output_offset,
        compute_tile_input_words, compute_tile_output_words
    } = compute_cmd_packet[CMD_PAYLOAD_WIDTH-1:0];

    assign compute_cpl_packet = {
        {(CPL_PACKET_WIDTH-CPL_PAYLOAD_WIDTH){1'b0}},
        8'h01, compute_event_sequence,
        compute_event_valid, compute_event_error, compute_event_error_code,
        compute_event_result, compute_event_cycles, compute_event_elements,
        compute_cmdq_head, compute_cplq_tail, compute_dependency_events, compute_busy
    };

    assign {
        ctrl_cpl_packet_version, ctrl_event_sequence,
        ctrl_event_valid, ctrl_event_error, ctrl_event_error_code,
        ctrl_event_result, ctrl_event_cycles, ctrl_event_elements,
        ctrl_cmdq_head, ctrl_cplq_tail, ctrl_dependency_events, ctrl_busy
    } = ctrl_cpl_packet[CPL_PAYLOAD_WIDTH-1:0];

    ai_ctrl_compute_cdc #(
        .CMD_DATA_WIDTH(CMD_PACKET_WIDTH),
        .CPL_DATA_WIDTH(CPL_PACKET_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) cdc_u (
        .ctrl_clk(ctrl_clk), .ctrl_resetn(ctrl_resetn),
        .ctrl_cmd_valid(ctrl_cmd_valid), .ctrl_cmd_ready(ctrl_cmd_ready),
        .ctrl_cmd_data(ctrl_cmd_packet),
        .ctrl_cpl_valid(ctrl_cpl_valid), .ctrl_cpl_ready(ctrl_cpl_ready),
        .ctrl_cpl_data(ctrl_cpl_packet),
        .compute_clk(compute_clk), .compute_resetn(compute_resetn),
        .compute_cmd_valid(compute_cmd_valid), .compute_cmd_ready(compute_cmd_ready),
        .compute_cmd_data(compute_cmd_packet),
        .compute_cpl_valid(compute_cpl_valid), .compute_cpl_ready(compute_cpl_ready),
        .compute_cpl_data(compute_cpl_packet)
    );
endmodule
