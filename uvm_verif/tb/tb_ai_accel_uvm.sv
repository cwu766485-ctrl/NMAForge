`timescale 1ns/1ps
module tb_ai_accel_uvm;
    import uvm_pkg::*;
    import ai_accel_uvm_types_pkg::*;
    import ai_accel_tests_pkg::*;
    logic aclk, aresetn, irq;
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

    axi_memory_model axi_mem_u (
        .clk(aclk), .resetn(aresetn), .arvalid(axi4.arvalid), .arid(axi4.arid), .araddr(axi4.araddr), .arlen(axi4.arlen), .arsize(axi4.arsize), .arburst(axi4.arburst), .arready(axi4.arready),
        .rid(axi4.rid), .rdata(axi4.rdata), .rresp(axi4.rresp), .rlast(axi4.rlast), .rvalid(axi4.rvalid), .rready(axi4.rready),
        .awvalid(axi4.awvalid), .awid(axi4.awid), .awaddr(axi4.awaddr), .awlen(axi4.awlen), .awsize(axi4.awsize), .awburst(axi4.awburst), .awready(axi4.awready),
        .wvalid(axi4.wvalid), .wdata(axi4.wdata), .wstrb(axi4.wstrb), .wlast(axi4.wlast), .wready(axi4.wready), .bresp(axi4.bresp), .bid(axi4.bid), .bvalid(axi4.bvalid), .bready(axi4.bready)
    );

    initial begin aclk = 0; forever #5 aclk = ~aclk; end
    initial begin aresetn = 0; repeat (8) @(posedge aclk); aresetn = 1; end
    initial begin
        uvm_config_db#(virtual ai_axil_if)::set(null, "*", "axil_vif", axil);
        uvm_config_db#(virtual ai_axi4_if)::set(null, "*", "axi4_vif", axi4);
        run_test();
    end
endmodule
