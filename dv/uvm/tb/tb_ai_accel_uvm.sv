`timescale 1ns/1ps
module tb_ai_accel_uvm;
    import uvm_pkg::*;
    import ai_accel_uvm_types_pkg::*;
    import ai_accel_tests_pkg::*;
    logic aclk, aresetn, ddr_resetn, irq;
    logic allow_m_axi_error;
    ai_axil_if axil(aclk, aresetn);
    ai_axi4_if axi4(aclk, aresetn);

    ai_accel_top dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(axil.awaddr), .s_axi_awvalid(axil.awvalid), .s_axi_awready(axil.awready),
        .s_axi_wdata(axil.wdata), .s_axi_wstrb(axil.wstrb), .s_axi_wvalid(axil.wvalid), .s_axi_wready(axil.wready),
        .s_axi_bresp(axil.bresp), .s_axi_bvalid(axil.bvalid), .s_axi_bready(axil.bready),
        .s_axi_araddr(axil.araddr), .s_axi_arvalid(axil.arvalid), .s_axi_arready(axil.arready),
        .s_axi_rdata(axil.rdata), .s_axi_rresp(axil.rresp), .s_axi_rvalid(axil.rvalid), .s_axi_rready(axil.rready), .irq(irq),
        .m_axi_arvalid(axi4.arvalid), .m_axi_arid(axi4.arid), .m_axi_araddr(axi4.araddr), .m_axi_arlen(axi4.arlen), .m_axi_arsize(axi4.arsize), .m_axi_arburst(axi4.arburst),
        .m_axi_arcache(axi4.arcache), .m_axi_arprot(axi4.arprot), .m_axi_arqos(axi4.arqos), .m_axi_arlock(axi4.arlock), .m_axi_arready(axi4.arready),
        .m_axi_rid(axi4.rid), .m_axi_rdata(axi4.rdata), .m_axi_rresp(axi4.rresp), .m_axi_rlast(axi4.rlast), .m_axi_rvalid(axi4.rvalid), .m_axi_rready(axi4.rready),
        .m_axi_awvalid(axi4.awvalid), .m_axi_awid(axi4.awid), .m_axi_awaddr(axi4.awaddr), .m_axi_awlen(axi4.awlen), .m_axi_awsize(axi4.awsize), .m_axi_awburst(axi4.awburst),
        .m_axi_awcache(axi4.awcache), .m_axi_awprot(axi4.awprot), .m_axi_awqos(axi4.awqos), .m_axi_awlock(axi4.awlock), .m_axi_awready(axi4.awready),
        .m_axi_wdata(axi4.wdata), .m_axi_wstrb(axi4.wstrb), .m_axi_wlast(axi4.wlast), .m_axi_wvalid(axi4.wvalid), .m_axi_wready(axi4.wready),
        .m_axi_bid(axi4.bid), .m_axi_bresp(axi4.bresp), .m_axi_bvalid(axi4.bvalid), .m_axi_bready(axi4.bready)
    );

    // The small top-level DDR model can alias a high 64-bit address window
    // onto the same low-word backing array. This is enabled only here to test
    // v7 external macro child-list pointers with nonzero src1; the model's
    // default remains strict for standalone DMA block tests.
    axi_memory_model #(.ALLOW_HIGH_ADDR_ALIAS(1'b1)) axi_mem_u (
        .clk(aclk), .resetn(ddr_resetn), .arvalid(axi4.arvalid), .arid(axi4.arid), .araddr(axi4.araddr), .arlen(axi4.arlen), .arsize(axi4.arsize), .arburst(axi4.arburst), .arready(axi4.arready),
        .rid(axi4.rid), .rdata(axi4.rdata), .rresp(axi4.rresp), .rlast(axi4.rlast), .rvalid(axi4.rvalid), .rready(axi4.rready),
        .awvalid(axi4.awvalid), .awid(axi4.awid), .awaddr(axi4.awaddr), .awlen(axi4.awlen), .awsize(axi4.awsize), .awburst(axi4.awburst), .awready(axi4.awready),
        .wvalid(axi4.wvalid), .wdata(axi4.wdata), .wstrb(axi4.wstrb), .wlast(axi4.wlast), .wready(axi4.wready), .bresp(axi4.bresp), .bid(axi4.bid), .bvalid(axi4.bvalid), .bready(axi4.bready)
    );

    // Reuse the top-level protocol checker from the smoke environment so
    // queued UVM traffic is checked for valid stability, burst legality,
    // descriptor-window conflicts, and bounded command retirement.
    ai_accel_sva top_protocol_sva_u (
        .clk(aclk), .resetn(aresetn),
        .s_axi_awaddr(axil.awaddr), .s_axi_awvalid(axil.awvalid), .s_axi_awready(axil.awready),
        .s_axi_wdata(axil.wdata), .s_axi_wstrb(axil.wstrb), .s_axi_wvalid(axil.wvalid), .s_axi_wready(axil.wready),
        .s_axi_bresp(axil.bresp), .s_axi_bvalid(axil.bvalid), .s_axi_bready(axil.bready),
        .s_axi_araddr(axil.araddr), .s_axi_arvalid(axil.arvalid), .s_axi_arready(axil.arready),
        .s_axi_rdata(axil.rdata), .s_axi_rresp(axil.rresp), .s_axi_rvalid(axil.rvalid), .s_axi_rready(axil.rready),
        .m_axi_araddr(axi4.araddr), .m_axi_arlen(axi4.arlen), .m_axi_arsize(axi4.arsize), .m_axi_arburst(axi4.arburst),
        .m_axi_arvalid(axi4.arvalid), .m_axi_arready(axi4.arready), .m_axi_rresp(axi4.rresp),
        .m_axi_rvalid(axi4.rvalid), .m_axi_rlast(axi4.rlast), .m_axi_rready(axi4.rready),
        .m_axi_awaddr(axi4.awaddr), .m_axi_awlen(axi4.awlen), .m_axi_awvalid(axi4.awvalid), .m_axi_awready(axi4.awready),
        .m_axi_wdata(axi4.wdata), .m_axi_wstrb(axi4.wstrb), .m_axi_wlast(axi4.wlast),
        .m_axi_wvalid(axi4.wvalid), .m_axi_wready(axi4.wready), .m_axi_bresp(axi4.bresp),
        .m_axi_bvalid(axi4.bvalid), .m_axi_bready(axi4.bready),
        .dma_read_outstanding_cfg(dut.dma_read_outstanding_mux),
        .allow_m_axi_error(allow_m_axi_error),
        .doorbell_pulse(dut.doorbell_pulse), .desc_busy(dut.spad_desc_busy),
        .desc_base(dut.cmdq_desc_base), .host_valid(dut.spad_req_valid),
        .host_write(dut.reg_req_write_raw), .host_addr(dut.reg_req_addr_raw - dut.SPAD_BASE),
        .core_busy(dut.core_busy), .core_done(dut.core_done), .core_error(dut.core_error),
        .processor_event_valid(dut.processor_event_valid)
    );

    ai_axi_master_protocol_sva top_axi_master_protocol_sva_u (
        .clk(aclk), .resetn(aresetn),
        .arid(axi4.arid), .araddr(axi4.araddr), .arlen(axi4.arlen),
        .arsize(axi4.arsize), .arburst(axi4.arburst), .arcache(axi4.arcache),
        .arprot(axi4.arprot), .arqos(axi4.arqos), .arlock(axi4.arlock),
        .arvalid(axi4.arvalid), .arready(axi4.arready),
        .awid(axi4.awid), .awaddr(axi4.awaddr), .awlen(axi4.awlen),
        .awsize(axi4.awsize), .awburst(axi4.awburst), .awcache(axi4.awcache),
        .awprot(axi4.awprot), .awqos(axi4.awqos), .awlock(axi4.awlock),
        .awvalid(axi4.awvalid), .awready(axi4.awready),
        .wdata(axi4.wdata), .wstrb(axi4.wstrb), .wlast(axi4.wlast),
        .wvalid(axi4.wvalid), .wready(axi4.wready)
    );

    // Reuse the smoke test's engine-quiescence assertions in the randomized
    // top environment. These are verification-only observers; no DUT logic
    // or clocking is altered.
    ai_compute_activity_sva scalar_activity_sva (
        .clk(aclk), .resetn(aresetn),
        .wake(dut.core_start && !dut.banked_op && !dut.tensor_matrix_op &&
              !dut.tensor_sfu_op && !dut.conv_linebuffer_op && !dut.kv_cache_op),
        .busy(dut.scalar_busy), .done(dut.compute_cluster_u.core_u.done),
        .error(dut.compute_cluster_u.core_u.error), .spad_valid(dut.scalar_spad_valid),
        .cycle_count(dut.compute_cluster_u.core_u.cycle_count),
        .element_count(dut.compute_cluster_u.core_u.element_count)
    );

    ai_compute_activity_sva banked_cnm_activity_sva (
        .clk(aclk), .resetn(aresetn), .wake(dut.core_start && dut.banked_op),
        .busy(dut.banked_busy), .done(dut.compute_cluster_u.banked_core_u.done),
        .error(dut.compute_cluster_u.banked_core_u.error),
        .spad_valid(dut.banked_spad_valid || (|dut.cnm_read_valid)),
        .cycle_count(dut.compute_cluster_u.banked_core_u.cycle_count),
        .element_count(dut.compute_cluster_u.banked_core_u.element_count)
    );

    ai_compute_activity_sva matrix_activity_sva (
        .clk(aclk), .resetn(aresetn), .wake(dut.core_start && dut.tensor_matrix_op),
        .busy(dut.matrix_busy), .done(dut.compute_cluster_u.tensor_matrix_u.done),
        .error(dut.compute_cluster_u.tensor_matrix_u.error),
        .spad_valid(dut.matrix_spad_valid || dut.matrix_banked_read_valid || dut.matrix_line_valid),
        .cycle_count(dut.compute_cluster_u.tensor_matrix_u.cycle_count),
        .element_count(dut.compute_cluster_u.tensor_matrix_u.element_count)
    );

    ai_compute_activity_sva sfu_activity_sva (
        .clk(aclk), .resetn(aresetn), .wake(dut.core_start && dut.tensor_sfu_op),
        .busy(dut.sfu_busy), .done(dut.compute_cluster_u.tensor_sfu_u.done),
        .error(dut.compute_cluster_u.tensor_sfu_u.error), .spad_valid(dut.sfu_spad_valid),
        .cycle_count(dut.compute_cluster_u.tensor_sfu_u.cycle_count),
        .element_count(dut.compute_cluster_u.tensor_sfu_u.element_count)
    );

    ai_compute_activity_sva cnn_activity_sva (
        .clk(aclk), .resetn(aresetn), .wake(dut.core_start && dut.conv_linebuffer_op),
        .busy(dut.conv_busy), .done(dut.compute_cluster_u.conv_linebuffer_u.done),
        .error(dut.compute_cluster_u.conv_linebuffer_u.error), .spad_valid(dut.conv_spad_valid),
        .cycle_count(dut.compute_cluster_u.conv_linebuffer_u.cycle_count),
        .element_count(dut.compute_cluster_u.conv_linebuffer_u.element_count)
    );

    ai_compute_activity_sva kv_activity_sva (
        .clk(aclk), .resetn(aresetn), .wake(dut.core_start && dut.kv_cache_op),
        .busy(dut.kv_busy), .done(dut.compute_cluster_u.kv_cache_u.done),
        .error(dut.compute_cluster_u.kv_cache_u.error), .spad_valid(dut.kv_spad_valid),
        .cycle_count(dut.compute_cluster_u.kv_cache_u.cycle_count),
        .element_count(dut.compute_cluster_u.kv_cache_u.element_count)
    );

    ai_compute_activity_sva fp_activity_sva (
        .clk(aclk), .resetn(aresetn),
        .wake(dut.core_start && ((dut.launch_op == 8'h50) || (dut.launch_op == 8'h51))),
        .busy(dut.fp_busy), .done(dut.compute_cluster_u.fp_done),
        .error(dut.compute_cluster_u.fp_error), .spad_valid(dut.fp_spad_valid),
        .cycle_count(dut.compute_cluster_u.fp_cycle_count),
        .element_count(dut.compute_cluster_u.fp_element_count)
    );

    initial begin aclk = 0; forever #5 aclk = ~aclk; end
    initial begin
        aresetn = 0;
        ddr_resetn = 0;
        allow_m_axi_error = 1'b0;
        repeat (8) @(posedge aclk);
        aresetn = 1;
        ddr_resetn = 1;
    end
    initial begin
        uvm_config_db#(virtual ai_axil_if)::set(null, "*", "axil_vif", axil);
        uvm_config_db#(virtual ai_axi4_if)::set(null, "*", "axi4_vif", axi4);
        run_test();
    end
endmodule
