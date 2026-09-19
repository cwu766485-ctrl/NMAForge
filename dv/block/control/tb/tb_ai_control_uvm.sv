`timescale 1ns/1ps
module tb_ai_control_uvm;
    import uvm_pkg::*;
    import control_tests_pkg::*;

    logic aclk = 0;
    logic aresetn = 0;
    always #5 aclk = ~aclk;
    initial begin repeat (5) @(posedge aclk); aresetn = 1; end

    ai_axil_if axil(aclk, aresetn);
    ai_control_status_if status(aclk);

    wire reg_req_valid, reg_req_write;
    wire [31:0] reg_req_addr, reg_req_wdata, reg_rsp_rdata;
    wire [3:0] reg_req_wstrb;
    wire reg_rsp_error;

    axi_lite_reg_if axi_lite_u (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(axil.awaddr), .s_axi_awvalid(axil.awvalid), .s_axi_awready(axil.awready),
        .s_axi_wdata(axil.wdata), .s_axi_wstrb(axil.wstrb), .s_axi_wvalid(axil.wvalid), .s_axi_wready(axil.wready),
        .s_axi_bresp(axil.bresp), .s_axi_bvalid(axil.bvalid), .s_axi_bready(axil.bready),
        .s_axi_araddr(axil.araddr), .s_axi_arvalid(axil.arvalid), .s_axi_arready(axil.arready),
        .s_axi_rdata(axil.rdata), .s_axi_rresp(axil.rresp), .s_axi_rvalid(axil.rvalid), .s_axi_rready(axil.rready),
        .reg_req_valid(reg_req_valid), .reg_req_write(reg_req_write), .reg_req_addr(reg_req_addr),
        .reg_req_wdata(reg_req_wdata), .reg_req_wstrb(reg_req_wstrb),
        .reg_rsp_rdata(reg_rsp_rdata), .reg_rsp_error(reg_rsp_error)
    );

    ai_accel_regs #(.SPAD_BYTES(32'd524288)) regs_u (
        .clk(aclk), .resetn(aresetn),
        .reg_req_valid(reg_req_valid), .reg_req_write(reg_req_write), .reg_req_addr(reg_req_addr),
        .reg_req_wdata(reg_req_wdata), .reg_req_wstrb(reg_req_wstrb),
        .reg_rsp_rdata(reg_rsp_rdata), .reg_rsp_error(reg_rsp_error),
        .processor_busy(status.processor_busy), .processor_event_valid(status.processor_event_valid),
        .processor_event_error(status.processor_event_error), .processor_event_error_code(status.processor_event_error_code),
        .processor_event_result(status.processor_event_result), .processor_event_cycles(status.processor_event_cycles),
        .processor_event_elements(status.processor_event_elements), .processor_cmdq_head(status.processor_cmdq_head),
        .processor_cplq_tail(status.processor_cplq_tail), .processor_dependency_events(status.processor_dependency_events),
        .dma_busy(status.dma_busy), .dma_done(status.dma_done), .dma_error(status.dma_error), .dma_error_code(status.dma_error_code),
        .direct_start(status.direct_start), .submit(status.submit), .core_abort(status.core_abort),
        .dma_start(status.dma_start), .dma_store(status.dma_store), .tile_start(status.tile_start), .perf_clear(status.perf_clear),
        // Configuration outputs are intentionally open in this register-file
        // block test; their consumers are verified at subsystem/top level.
        .dma_ext_addr(), .dma_spad_addr(), .dma_length_words(), .dma_row_words(), .dma_row_count(),
        .dma_ext_stride(), .dma_spad_stride(), .dma_gather_enable(), .dma_gather_index_base(), .dma_read_outstanding(),
        .op_mode(), .src0_base(), .src1_base(), .dst_base(), .length(), .m_size(), .n_size(), .k_words(),
        .scale_shift(), .activation(), .watchdog_limit(), .bias_base(), .bias_enable(),
        .tile_count(), .tile_ext_input_base(), .tile_ext_output_base(), .tile_ext_input_stride(), .tile_ext_output_stride(),
        .tile_buffer0_base(), .tile_buffer1_base(), .tile_output_offset(), .tile_input_words(), .tile_output_words(),
        .region0_base(), .region0_limit(), .region0_perm(), .region1_base(), .region1_limit(), .region1_perm(),
        .region2_base(), .region2_limit(), .region2_perm(), .region3_base(), .region3_limit(), .region3_perm(),
        .cmdq_base(), .cmdq_size(), .cmdq_tail(), .cmdq_external(), .cmdq_head_load(), .cmdq_head_seed(),
        .cplq_base(), .cplq_size(), .cplq_head(), .cplq_tail_load(), .cplq_tail_seed(),
        .tile_perf_total(status.tile_perf_total), .tile_perf_dma(status.tile_perf_dma), .tile_perf_compute(status.tile_perf_compute),
        .tile_perf_overlap(status.tile_perf_overlap), .tile_perf_stall(status.tile_perf_stall), .tile_completed(status.tile_completed),
        .perf_matrix_cycles(status.perf_matrix_cycles), .perf_matrix_mac_cycles(status.perf_matrix_mac_cycles),
        .perf_matrix_banked_stall(status.perf_matrix_banked_stall), .perf_dma_read_bytes(status.perf_dma_read_bytes),
        .perf_dma_write_bytes(status.perf_dma_write_bytes), .perf_dma_ar_count(status.perf_dma_ar_count),
        .perf_dma_aw_count(status.perf_dma_aw_count), .perf_dma_r_stall(status.perf_dma_r_stall),
        .perf_dma_rd_outstanding(status.perf_dma_rd_outstanding), .perf_dma_rd_highwater(status.perf_dma_rd_highwater),
        .irq(status.irq)
    );

    ai_axil_control_sva sva_u (
        .aclk(aclk), .aresetn(aresetn),
        .awaddr(axil.awaddr), .awvalid(axil.awvalid), .awready(axil.awready),
        .wdata(axil.wdata), .wstrb(axil.wstrb), .wvalid(axil.wvalid), .wready(axil.wready),
        .bresp(axil.bresp), .bvalid(axil.bvalid), .bready(axil.bready),
        .araddr(axil.araddr), .arvalid(axil.arvalid), .arready(axil.arready),
        .rdata(axil.rdata), .rresp(axil.rresp), .rvalid(axil.rvalid), .rready(axil.rready),
        .reg_req_valid(reg_req_valid), .reg_req_write(reg_req_write), .reg_req_addr(reg_req_addr),
        .reg_req_wdata(reg_req_wdata), .core_abort(status.core_abort), .irq(status.irq)
    );

    initial begin
        uvm_config_db#(virtual ai_axil_if)::set(null, "*", "axil_vif", axil);
        uvm_config_db#(virtual ai_control_status_if)::set(null, "*", "status_vif", status);
        run_test();
    end
endmodule
