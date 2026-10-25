module tb_ai_parallel_compute_uvm;
    import uvm_pkg::*;
    import ai_parallel_compute_uvm_pkg::*;

    logic clk=1'b0;
    always #5 clk=~clk;

    ai_parallel_compute_if cl_if(clk);
    wire fetch_external;
    wire [31:0] completion_base, completion_index;
    wire [31:0] event_result, event_cycles, event_elements;
    wire [15:0] dependency_events;
    wire legacy_handoff;

    ai_parallel_compute_dispatcher dispatcher_dut (
        .clk(clk), .resetn(cl_if.resetn), .submit(cl_if.submit), .abort(cl_if.abort),
        .scheduler_ready(1'b1), .cmdq_base(64'h0000_0000_0000_1000), .cmdq_size(32'd8),
        .cmdq_tail(cl_if.cmdq_tail), .desc_external(1'b0),
        .cmdq_head_load(1'b0), .cmdq_head_seed(32'd0),
        .cplq_tail_load(1'b0), .cplq_tail_seed(32'd0),
        .cplq_base(32'h0000_8000), .cplq_size(cl_if.cplq_size), .cplq_head(cl_if.cplq_head),
        .completion_protected(1'b0), .sync_legacy_state(1'b0),
        .legacy_cmdq_head(32'd0), .legacy_cplq_tail(32'd0), .legacy_dependency_events(16'd0),
        .fetch_done(cl_if.fetch_done), .fetch_error(cl_if.fetch_error), .desc_op(cl_if.desc_op),
        .desc_task_id(cl_if.desc_task_id), .desc_src0(cl_if.desc_src0), .desc_src1(cl_if.desc_src1),
        .desc_dst(cl_if.desc_dst), .desc_length(cl_if.desc_length), .desc_m(cl_if.desc_m),
        .desc_n(cl_if.desc_n), .desc_k(cl_if.desc_k), .desc_shift(cl_if.desc_shift),
        .desc_activation(cl_if.desc_activation), .desc_bias_base(cl_if.desc_bias_base),
        .desc_bias_enable(cl_if.desc_bias_enable), .desc_flags(cl_if.desc_flags),
        .desc_aux0(cl_if.desc_aux0), .desc_src0_stride(cl_if.desc_src0_stride),
        .desc_src1_stride(cl_if.desc_src1_stride), .desc_dst_stride(cl_if.desc_dst_stride),
        .desc_batch_count(cl_if.desc_batch_count), .desc_head_count(cl_if.desc_head_count),
        .desc_wait_mask(cl_if.desc_wait_mask), .desc_signal_mask(cl_if.desc_signal_mask),
        .desc_clear_mask(cl_if.desc_clear_mask), .desc_version(cl_if.desc_version),
        .engine_busy(cl_if.engine_busy), .engine_done(cl_if.engine_done),
        .engine_error(cl_if.engine_error), .engine_error_code(cl_if.engine_error_code),
        .engine_result(cl_if.engine_result), .engine_cycles(cl_if.engine_cycles),
        .engine_elements(cl_if.engine_elements), .completion_busy(cl_if.completion_busy),
        .completion_done(cl_if.completion_done),
        .fetch_start(cl_if.fetch_start), .fetch_base(cl_if.fetch_base), .fetch_external(fetch_external),
        .launch_valid(cl_if.launch_valid), .launch_op(cl_if.launch_op),
        .launch_task_id(cl_if.launch_task_id), .launch_src0(cl_if.launch_src0),
        .launch_src1(cl_if.launch_src1), .launch_dst(cl_if.launch_dst),
        .launch_length(cl_if.launch_length), .launch_m(cl_if.launch_m), .launch_n(cl_if.launch_n),
        .launch_k(cl_if.launch_k), .launch_shift(cl_if.launch_shift),
        .launch_activation(cl_if.launch_activation), .launch_bias_base(cl_if.launch_bias_base),
        .launch_bias_enable(cl_if.launch_bias_enable), .launch_flags(cl_if.launch_flags),
        .launch_aux0(cl_if.launch_aux0), .launch_src0_stride(cl_if.launch_src0_stride),
        .launch_src1_stride(cl_if.launch_src1_stride), .launch_dst_stride(cl_if.launch_dst_stride),
        .launch_batch_count(cl_if.launch_batch_count), .launch_head_count(cl_if.launch_head_count),
        .completion_start(cl_if.completion_start), .completion_base(completion_base),
        .completion_index(completion_index), .completion_task_id(cl_if.completion_task_id),
        .completion_status(cl_if.completion_status), .completion_error_code(cl_if.completion_error_code),
        .completion_result(cl_if.completion_result), .completion_elements(cl_if.completion_elements),
        .cmdq_head(cl_if.cmdq_head), .cplq_tail(cl_if.cplq_tail), .busy(cl_if.dispatcher_busy),
        .event_valid(cl_if.event_valid), .event_error(cl_if.event_error),
        .event_error_code(cl_if.event_error_code), .event_result(event_result),
        .event_cycles(event_cycles), .event_elements(event_elements),
        .dependency_events(dependency_events), .legacy_handoff(legacy_handoff)
    );

    ai_compute_spad_mux compute_spad_mux_dut (
        .clk(clk), .resetn(cl_if.resetn), .req_valid(cl_if.req_valid),
        .req_write(cl_if.req_write), .req_addr(cl_if.req_addr), .req_wdata(cl_if.req_wdata),
        .req_ready(cl_if.req_ready), .spad_valid(cl_if.spad_valid), .spad_write(cl_if.spad_write),
        .spad_addr(cl_if.spad_addr), .spad_wdata(cl_if.spad_wdata), .spad_ready(cl_if.spad_ready),
        .spad_protection_error(1'b0), .req_protection_error(cl_if.req_protection_error),
        .rsp_valid(cl_if.rsp_valid), .rsp_rdata(cl_if.rsp_rdata), .rsp_error(cl_if.rsp_error),
        .rsp_parity_error(cl_if.rsp_parity_error), .engine_rsp_valid(cl_if.engine_rsp_valid),
        .engine_rsp_rdata(cl_if.engine_rsp_rdata), .engine_rsp_error(cl_if.engine_rsp_error)
    );

    assign cl_if.debug_fifo_done = {
        dispatcher_dut.fifo_done_r[7], dispatcher_dut.fifo_done_r[6],
        dispatcher_dut.fifo_done_r[5], dispatcher_dut.fifo_done_r[4],
        dispatcher_dut.fifo_done_r[3], dispatcher_dut.fifo_done_r[2],
        dispatcher_dut.fifo_done_r[1], dispatcher_dut.fifo_done_r[0]
    };
    assign cl_if.debug_fifo_count = dispatcher_dut.fifo_count_r;
    assign cl_if.debug_fifo_error = {
        dispatcher_dut.fifo_error_r[7], dispatcher_dut.fifo_error_r[6],
        dispatcher_dut.fifo_error_r[5], dispatcher_dut.fifo_error_r[4],
        dispatcher_dut.fifo_error_r[3], dispatcher_dut.fifo_error_r[2],
        dispatcher_dut.fifo_error_r[1], dispatcher_dut.fifo_error_r[0]
    };
    assign cl_if.debug_issue_state = dispatcher_dut.issue_state_r;
    assign cl_if.debug_engine_active = dispatcher_dut.engine_active_r;
    assign cl_if.debug_desc_invalid = dispatcher_dut.descriptor_invalid;
    assign cl_if.debug_cplq_full = dispatcher_dut.cplq_full;

    initial begin
        uvm_config_db#(virtual ai_parallel_compute_if)::set(null,"*","cl_vif",cl_if);
        run_test("ai_parallel_compute_uvm_test");
    end

    initial begin
        #2000000;
        $fatal(1,"parallel compute UVM watchdog expired");
    end
endmodule
