`timescale 1ns/1ps

module tb_nma_axi_lite_vip;
  import uvm_pkg::*;
  import tvip_axi_pkg::*;
  import nma_axi_lite_vip_test_pkg::*;

  logic aclk = 1'b0;
  logic aresetn = 1'b0;
  logic irq;

  always #5ns aclk = ~aclk;

  tvip_axi_if axi_vif(aclk, aresetn);
  tvip_axi4lite_if #(
    .ADDRESS_WIDTH (32),
    .DATA_WIDTH    (32),
    .HAS_PROT      (1'b0)
  ) axil_pins(aclk, aresetn);

  tvip_axi4lite_master_pin_adapter axi4lite_adapter(axi_vif, axil_pins);

  ai_accel_top dut (
    .aclk              (aclk),
    .aresetn           (aresetn),
    .s_axi_awaddr      (axil_pins.awaddr),
    .s_axi_awvalid     (axil_pins.awvalid),
    .s_axi_awready     (axil_pins.awready),
    .s_axi_wdata       (axil_pins.wdata),
    .s_axi_wstrb       (axil_pins.wstrb),
    .s_axi_wvalid      (axil_pins.wvalid),
    .s_axi_wready      (axil_pins.wready),
    .s_axi_bresp       (axil_pins.bresp),
    .s_axi_bvalid      (axil_pins.bvalid),
    .s_axi_bready      (axil_pins.bready),
    .s_axi_araddr      (axil_pins.araddr),
    .s_axi_arvalid     (axil_pins.arvalid),
    .s_axi_arready     (axil_pins.arready),
    .s_axi_rdata       (axil_pins.rdata),
    .s_axi_rresp       (axil_pins.rresp),
    .s_axi_rvalid      (axil_pins.rvalid),
    .s_axi_rready      (axil_pins.rready),
    .irq               (irq),
    .m_axi_arready     (1'b0),
    .m_axi_rid         (4'b0),
    .m_axi_rdata       (128'b0),
    .m_axi_rresp       (2'b0),
    .m_axi_rvalid      (1'b0),
    .m_axi_rlast       (1'b0),
    .m_axi_awready     (1'b0),
    .m_axi_wready      (1'b0),
    .m_axi_bid         (4'b0),
    .m_axi_bresp       (2'b0),
    .m_axi_bvalid      (1'b0),
    .m_axi_arvalid     (),
    .m_axi_arid        (),
    .m_axi_araddr      (),
    .m_axi_arlen       (),
    .m_axi_arsize      (),
    .m_axi_arburst     (),
    .m_axi_arcache     (),
    .m_axi_arprot      (),
    .m_axi_arqos       (),
    .m_axi_arlock      (),
    .m_axi_rready      (),
    .m_axi_awvalid     (),
    .m_axi_awid        (),
    .m_axi_awaddr      (),
    .m_axi_awlen       (),
    .m_axi_awsize      (),
    .m_axi_awburst     (),
    .m_axi_awcache     (),
    .m_axi_awprot      (),
    .m_axi_awqos       (),
    .m_axi_awlock      (),
    .m_axi_wvalid      (),
    .m_axi_wdata       (),
    .m_axi_wstrb       (),
    .m_axi_wlast       (),
    .m_axi_bready      ()
  );

  initial begin
    repeat (8) @(posedge aclk);
    aresetn = 1'b1;
  end

  initial begin
    uvm_config_db#(tvip_axi_vif)::set(null, "", "vif_axi0", axi_vif);
    run_test();
  end
endmodule
