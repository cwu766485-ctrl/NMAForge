`ifndef NMA_AXI_LITE_VIP_TEST_PKG_SV
`define NMA_AXI_LITE_VIP_TEST_PKG_SV

package nma_axi_lite_vip_test_pkg;
  import uvm_pkg::*;
  import tvip_axi_pkg::*;
  import tvip_axi_types_pkg::*;
  `include "uvm_macros.svh"

  class nma_axi_lite_csr_vip_test extends uvm_test;
    `uvm_component_utils(nma_axi_lite_csr_vip_test)

    tvip_axi_env           axi_env;
    tvip_axi_configuration axi_cfg;
    int unsigned           awvalid_without_w_cycles;
    int unsigned           wvalid_without_aw_cycles;
    int unsigned           bready_stall_cycles;
    int unsigned           rready_stall_cycles;

    function new(string name = "nma_axi_lite_csr_vip_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      string config_error;
      super.build_phase(phase);

      axi_cfg = tvip_axi_configuration::type_id::create("axi_cfg");
      if (!uvm_config_db#(tvip_axi_vif)::get(null, "", "vif_axi0", axi_cfg.vif)) begin
        `uvm_fatal("NMA_AXIL_VIP_NOVIF", "No canonical AXI VIP interface was published by the test top")
      end
      if (!axi_cfg.randomize() with {
        protocol == TVIP_AXI4LITE;
        address_width == 32;
        data_width == 32;
        id_width == 0;
        max_burst_length == 1;
        enable_region == 0;
        enable_exclusive == 0;
        awuser_width == 0;
        wuser_width == 0;
        buser_width == 0;
        aruser_width == 0;
        ruser_width == 0;
        reset_by_agent == 0;
      }) begin
        `uvm_fatal("NMA_AXIL_VIP_CFG_RANDOMIZE", "Could not randomize legal 32-bit AXI4-Lite master configuration")
      end
      axi_cfg.agent_mode = UVM_ACTIVE;
      // Start with response READY low. The access sequence raises it only
      // after its per-transaction delay, exercising real CSR response holds.
      axi_cfg.default_bready = 0;
      axi_cfg.default_rready = 0;
      if (!axi_cfg.validate_configuration(config_error)) begin
        `uvm_fatal("NMA_AXIL_VIP_CFG_INVALID", config_error)
      end

      axi_env = tvip_axi_env::type_id::create("axi_env", this);
      axi_env.add_master_configuration(axi_cfg);
    endfunction

    task automatic access_register(
      input bit is_write,
      input tvip_axi_address address,
      input tvip_axi_data write_data,
      input tvip_axi_strobe write_strobe,
      input tvip_axi_response expected_response,
      input tvip_axi_data expected_read_data,
      input string case_name,
      input int unsigned address_start_gap = 0,
      input int unsigned write_data_gap = 0,
      input int unsigned response_ready_gap = 0
    );
      tvip_axi_master_access_sequence access;
      access = tvip_axi_master_access_sequence::type_id::create(
        $sformatf("%s_access", case_name));
      access.set_sequencer(axi_env.master_agents[0].sequencer);

      if (is_write) begin
        if (!access.randomize() with {
          access_type == TVIP_AXI_WRITE_ACCESS;
          address == local::address;
          burst_length == 1;
          burst_size == 4;
          burst_type == TVIP_AXI_INCREMENTING_BURST;
          protection == '0;
          start_delay == local::address_start_gap;
          data[0] == local::write_data;
          strobe[0] == local::write_strobe;
          write_data_delay[0] == local::write_data_gap;
          response_ready_delay[0] == local::response_ready_gap;
        }) begin
          `uvm_fatal("NMA_AXIL_VIP_RANDOMIZE",
            $sformatf("Could not randomize write case %s", case_name))
        end
      end
      else begin
        if (!access.randomize() with {
          access_type == TVIP_AXI_READ_ACCESS;
          address == local::address;
          burst_length == 1;
          burst_size == 4;
          burst_type == TVIP_AXI_INCREMENTING_BURST;
          protection == '0;
          start_delay == local::address_start_gap;
          response_ready_delay[0] == local::response_ready_gap;
        }) begin
          `uvm_fatal("NMA_AXIL_VIP_RANDOMIZE",
            $sformatf("Could not randomize read case %s", case_name))
        end
      end

      access.start(axi_env.master_agents[0].sequencer);
      if (access.response.size() != 1 || access.response[0] !== expected_response) begin
        `uvm_error("NMA_AXIL_VIP_RESPONSE", $sformatf(
          "%s response count/value expected=1/%0b observed=%0d/%0b",
          case_name, expected_response, access.response.size(),
          access.response.size() ? access.response[0] : TVIP_AXI_DECODE_ERROR))
      end
      if (!is_write && (expected_response == TVIP_AXI_OKAY)) begin
        if (access.data.size() != 1 || access.data[0] !== expected_read_data) begin
          `uvm_error("NMA_AXIL_VIP_READ_DATA", $sformatf(
            "%s data expected=0x%0h observed=%0h beats=%0d",
            case_name, expected_read_data,
            access.data.size() ? access.data[0] : 'x, access.data.size()))
        end
      end
    endtask

    task automatic collect_pin_timing_evidence();
      forever begin
        @(axi_cfg.vif.monitor_cb);
        if ((axi_cfg.vif.monitor_cb.awvalid === 1'b1) &&
            (axi_cfg.vif.monitor_cb.wvalid === 1'b0))
          awvalid_without_w_cycles++;
        if ((axi_cfg.vif.monitor_cb.wvalid === 1'b1) &&
            (axi_cfg.vif.monitor_cb.awvalid === 1'b0))
          wvalid_without_aw_cycles++;
        if ((axi_cfg.vif.monitor_cb.bvalid === 1'b1) &&
            (axi_cfg.vif.monitor_cb.bready === 1'b0))
          bready_stall_cycles++;
        if ((axi_cfg.vif.monitor_cb.rvalid === 1'b1) &&
            (axi_cfg.vif.monitor_cb.rready === 1'b0))
          rready_stall_cycles++;
      end
    endtask

    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      wait (axi_cfg.vif.areset_n === 1'b1);
      fork
        collect_pin_timing_evidence();
      join_none

      access_register(0, 32'h0000_0044, '0, '0, TVIP_AXI_OKAY,
                      32'h1000_000a, "version_read", 0, 0, 3);
      access_register(1, 32'h0000_0008, 32'h0000_0034, 4'hf,
                      TVIP_AXI_OKAY, '0, "op_write", 0, 5, 4);
      access_register(0, 32'h0000_0008, '0, '0, TVIP_AXI_OKAY,
                      32'h0000_0034, "op_readback", 0, 0, 4);
      access_register(0, 32'h0000_0045, '0, '0, TVIP_AXI_SLAVE_ERROR,
                      '0, "unaligned_read");
      access_register(0, 32'h0000_0200, '0, '0, TVIP_AXI_SLAVE_ERROR,
                      '0, "unmapped_read");
      access_register(1, 32'h0000_0044, 32'hffff_ffff, 4'hf,
                      TVIP_AXI_SLAVE_ERROR, '0, "readonly_write");
      access_register(1, 32'h0000_0008, 32'h0000_0056, 4'h1,
                      TVIP_AXI_SLAVE_ERROR, '0, "partial_strobe_write", 5, 0, 3);
      access_register(1, 32'h0000_0200, 32'h0000_0001, 4'hf,
                      TVIP_AXI_SLAVE_ERROR, '0, "unmapped_write");
      repeat (2) @(posedge axi_cfg.vif.aclk);
      if ((awvalid_without_w_cycles == 0) || (wvalid_without_aw_cycles == 0) ||
          (bready_stall_cycles < 3) || (rready_stall_cycles < 3)) begin
        `uvm_error("NMA_AXIL_VIP_TIMING", $sformatf(
          "AXI-Lite timing evidence incomplete: AW-only=%0d W-only=%0d B-stall=%0d R-stall=%0d",
          awvalid_without_w_cycles, wvalid_without_aw_cycles,
          bready_stall_cycles, rready_stall_cycles))
      end
      else begin
        `uvm_info("NMA_AXIL_VIP_TIMING_PASS", $sformatf(
          "NMA_AXIL_VIP_TIMING_PASS: AW-only=%0d W-only=%0d B-stall=%0d R-stall=%0d",
          awvalid_without_w_cycles, wvalid_without_aw_cycles,
          bready_stall_cycles, rready_stall_cycles), UVM_NONE)
      end
      `uvm_info("NMA_AXIL_VIP_CSR_PASS",
        "NMA_AXIL_VIP_CSR_PASS: real ai_accel_top; 32-bit AXI4-Lite master; independent AW/W timing, B/R backpressure, legal read/write and five SLVERR cases",
        UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass
endpackage

`endif
