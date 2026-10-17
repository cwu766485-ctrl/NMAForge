module cp_completion_ownership_formal_top (
    input logic clk,
    input logic resetn,
    input logic abort,
    input logic submit,
    input logic direct_start,
    input logic tile_start,
    input logic [63:0] cmdq_base,
    input logic [31:0] cmdq_size,
    input logic [31:0] cmdq_tail,
    input logic desc_external,
    input logic cmdq_head_load,
    input logic [31:0] cmdq_head_seed,
    input logic [31:0] cplq_base,
    input logic [31:0] cplq_size,
    input logic [31:0] cplq_head,
    input logic completion_protected,
    input logic cplq_tail_load,
    input logic [31:0] cplq_tail_seed,
    input logic [7:0] cfg_op,
    input logic [31:0] cfg_src0,
    input logic [31:0] cfg_src1,
    input logic [31:0] cfg_dst,
    input logic [15:0] cfg_length,
    input logic [15:0] cfg_m,
    input logic [15:0] cfg_n,
    input logic [15:0] cfg_k,
    input logic [4:0] cfg_shift,
    input logic [1:0] cfg_activation,
    input logic [31:0] cfg_bias_base,
    input logic cfg_bias_enable,
    input logic [15:0] tile_count,
    input logic [63:0] tile_ext_input_base,
    input logic [63:0] tile_ext_output_base,
    input logic [31:0] tile_ext_input_stride,
    input logic [31:0] tile_ext_output_stride,
    input logic [31:0] tile_buffer0_base,
    input logic [31:0] tile_buffer1_base,
    input logic [31:0] tile_output_offset,
    input logic [15:0] tile_input_words,
    input logic [15:0] tile_output_words,
    input logic fetch_busy,
    input logic fetch_done,
    input logic fetch_error,
    input logic [7:0] desc_op,
    input logic [15:0] desc_task_id,
    input logic [31:0] desc_src0,
    input logic [31:0] desc_src1,
    input logic [31:0] desc_dst,
    input logic [15:0] desc_length,
    input logic [15:0] desc_m,
    input logic [15:0] desc_n,
    input logic [15:0] desc_k,
    input logic [4:0] desc_shift,
    input logic [1:0] desc_activation,
    input logic [31:0] desc_bias_base,
    input logic desc_bias_enable,
    input logic [7:0] desc_flags,
    input logic [31:0] desc_aux0,
    input logic [31:0] desc_src0_stride,
    input logic [31:0] desc_src1_stride,
    input logic [31:0] desc_dst_stride,
    input logic [15:0] desc_batch_count,
    input logic [15:0] desc_head_count,
    input logic [15:0] desc_wait_mask,
    input logic [15:0] desc_signal_mask,
    input logic [15:0] desc_clear_mask,
    input logic [7:0] desc_version,
    input logic compute_busy,
    input logic compute_done,
    input logic compute_error,
    input logic [3:0] compute_error_code,
    input logic [31:0] compute_result,
    input logic [31:0] compute_cycles,
    input logic [31:0] compute_elements,
    input logic dma_busy,
    input logic dma_done,
    input logic dma_error,
    input logic [3:0] dma_error_code,
    input logic writer_spad_ready
);
    logic fetch_start;
    logic [63:0] fetch_base;
    logic fetch_external;
    logic launch_valid;
    logic completion_start;
    logic [31:0] completion_base;
    logic [31:0] completion_index;
    logic [15:0] completion_task_id;
    logic [3:0] completion_status;
    logic [3:0] completion_error;
    logic [31:0] completion_result;
    logic [31:0] completion_elements;
    logic [31:0] cmdq_head;
    logic [31:0] cplq_tail;
    logic busy;
    logic event_valid;
    logic event_error;
    logic [3:0] event_error_code;
    logic [31:0] event_result;
    logic [31:0] event_cycles;
    logic [31:0] event_elements;
    logic [15:0] dependency_events;
    logic completion_busy;
    logic completion_done;
    logic writer_busy;
    logic writer_done;
    logic writer_spad_valid;
    logic writer_spad_write;
    logic [31:0] writer_spad_addr;
    logic [31:0] writer_spad_wdata;
    logic tile_dma_start;
    logic tile_dma_store;
    logic [63:0] tile_dma_ext_addr;
    logic [31:0] tile_dma_spad_addr;
    logic [15:0] tile_dma_length_words;
    logic tile_active;
    logic [31:0] tile_perf_total;
    logic [31:0] tile_perf_dma;
    logic [31:0] tile_perf_compute;
    logic [31:0] tile_perf_overlap;
    logic [31:0] tile_perf_stall;
    logic [15:0] tile_completed;
    logic [7:0] launch_op;
    logic [15:0] launch_task_id;
    logic [31:0] launch_src0;
    logic [31:0] launch_src1;
    logic [31:0] launch_dst;
    logic [15:0] launch_length;
    logic [15:0] launch_m;
    logic [15:0] launch_n;
    logic [15:0] launch_k;
    logic [4:0] launch_shift;
    logic [1:0] launch_activation;
    logic [31:0] launch_bias_base;
    logic launch_bias_enable;
    logic [7:0] launch_flags;
    logic [31:0] launch_aux0;
    logic [31:0] launch_src0_stride;
    logic [31:0] launch_src1_stride;
    logic [31:0] launch_dst_stride;
    logic [15:0] launch_batch_count;
    logic [15:0] launch_head_count;

    // Only reset is constrained by the formal setup. Every CP input remains a
    // free primary input; completion_busy/done are fed solely by this writer.
    assign completion_busy = writer_busy;
    assign completion_done = writer_done;
    ai_command_processor u_cp (.*);

    ai_completion_writer u_writer (
        .clk(clk),
        .resetn(resetn),
        .start(completion_start),
        .cplq_base(completion_base),
        .cplq_index(completion_index),
        .task_id(completion_task_id),
        .status(completion_status),
        .error_code(completion_error),
        .result(completion_result),
        .element_count(completion_elements),
        .spad_valid(writer_spad_valid),
        .spad_write(writer_spad_write),
        .spad_addr(writer_spad_addr),
        .spad_wdata(writer_spad_wdata),
        .spad_ready(writer_spad_ready),
        .busy(writer_busy),
        .done(writer_done)
    );

    ap_completion_start_owned_by_cpl: assert property (
        @(posedge clk) disable iff (!resetn)
        completion_start |-> (u_cp.state_r == 4'd4));

    ap_completion_done_owned_by_cpl: assert property (
        @(posedge clk) disable iff (!resetn)
        writer_done |-> (u_cp.state_r == 4'd4));

    cp_completion_done_owned_by_cpl: cover property (
        @(posedge clk) disable iff (!resetn)
        writer_done && (u_cp.state_r == 4'd4));

    cp_completion_done_with_pending_command: cover property (
        @(posedge clk) disable iff (!resetn)
        writer_done && (u_cp.state_r == 4'd4) && u_cp.queue_run_r &&
        (u_cp.cmdq_head_index != cmdq_tail));
endmodule
