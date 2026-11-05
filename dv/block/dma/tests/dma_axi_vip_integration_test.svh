class dma_axi_vip_store_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_axi_vip_store_sequence)
    function new(string name = "dma_axi_vip_store_sequence"); super.new(name); endfunction

    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("store_req");
        start_item(req);
        req.ext_addr = 64'h0000_0002_D400_0C80;
        req.spad_addr = 32'h0000_0C80;
        req.length_words = 16'd4;
        req.row_words = 16'd4;
        req.row_count = '0;
        req.ext_stride = '0;
        req.spad_stride = '0;
        req.read_outstanding = 3'd1;
        req.store = 1'b1;
        req.gather_enable = 1'b0;
        req.gather_index_base = '0;
        req.expect_error = 1'b0;
        req.expected_error_code = '0;
        req.abort_after_cycles = 0;
        req.abort_after_aw = 1'b0;
        req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_axi_vip_readback_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_axi_vip_readback_sequence)
    function new(string name = "dma_axi_vip_readback_sequence"); super.new(name); endfunction

    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("readback_req");
        start_item(req);
        req.ext_addr = 64'h0000_0002_D400_0C80;
        req.spad_addr = 32'h0000_1400;
        req.length_words = 16'd4;
        req.row_words = 16'd4;
        req.row_count = '0;
        req.ext_stride = '0;
        req.spad_stride = '0;
        req.read_outstanding = 3'd1;
        req.store = 1'b0;
        req.gather_enable = 1'b0;
        req.gather_index_base = '0;
        req.expect_error = 1'b0;
        req.expected_error_code = '0;
        req.abort_after_cycles = 0;
        req.abort_after_aw = 1'b0;
        req.minimum_rd_highwater = 1;
        finish_item(req);
    endtask
endclass

class dma_axi_vip_integration_test extends dma_block_base_test;
    virtual ai_dma_axi_if dma_vif;
    tvip_axi_vif vip_vif;
    tvip_axi_env vip_env;
    tvip_axi_configuration vip_cfg;

    `uvm_component_utils(dma_axi_vip_integration_test)

    function new(string name = "dma_axi_vip_integration_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void set_delay_window(tvip_delay_configuration delay_cfg,
                                   int unsigned min_delay,
                                   int unsigned max_delay);
        delay_cfg.min_delay = min_delay;
        delay_cfg.max_delay = max_delay;
        delay_cfg.mid_delay[0] = (min_delay == 0) ? 1 : min_delay;
        delay_cfg.mid_delay[1] = max_delay;
        delay_cfg.weight_zero_delay = (min_delay == 0) ? 6 : 0;
        delay_cfg.weight_short_delay = 3;
        delay_cfg.weight_long_delay = 1;
    endfunction

    virtual function void configure_cfg();
        cfg.external_axi_vip = 1'b1;
    endfunction

    function void build_phase(uvm_phase phase);
        string config_error;
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_dma_axi_if)::get(this, "", "axi_vif", dma_vif))
            `uvm_fatal("DMA_AXI_VIP_NOVIF", "DMA AXI interface was not configured")
        if (!uvm_config_db#(tvip_axi_vif)::get(this, "", "nma_axi_vip_vif", vip_vif))
            `uvm_fatal("DMA_AXI_VIP_NOVIF", "Protocol VIP interface was not configured")

        vip_cfg = tvip_axi_configuration::type_id::create("vip_cfg");
        vip_cfg.vif = vip_vif;
        vip_cfg.agent_mode = UVM_ACTIVE;
        vip_cfg.protocol = TVIP_AXI4;
        vip_cfg.id_width = 4;
        vip_cfg.address_width = 64;
        vip_cfg.data_width = 128;
        vip_cfg.strobe_width = 16;
        vip_cfg.max_burst_length = 16;
        vip_cfg.qos_range[0] = 0;
        vip_cfg.qos_range[1] = 0;
        vip_cfg.response_ordering = TVIP_AXI_OUT_OF_ORDER;
        vip_cfg.outstanding_responses = 4;
        vip_cfg.enable_response_interleaving = 0;
        vip_cfg.response_weight_okay = 1;
        vip_cfg.response_weight_exokay = 0;
        vip_cfg.response_weight_slave_error = 0;
        vip_cfg.response_weight_decode_error = 0;
        vip_cfg.default_awready = 1;
        vip_cfg.default_wready = 1;
        vip_cfg.default_arready = 1;
        vip_cfg.reset_by_agent = 0;
        set_delay_window(vip_cfg.request_start_delay, 0, 1);
        set_delay_window(vip_cfg.write_data_delay, 0, 1);
        set_delay_window(vip_cfg.response_start_delay, 3, 4);
        set_delay_window(vip_cfg.response_delay, 0, 1);
        set_delay_window(vip_cfg.awready_delay, 0, 1);
        set_delay_window(vip_cfg.wready_delay, 0, 1);
        set_delay_window(vip_cfg.bready_delay, 0, 1);
        set_delay_window(vip_cfg.arready_delay, 0, 1);
        set_delay_window(vip_cfg.rready_delay, 0, 1);
        vip_cfg.enable_memory_window = 1;
        vip_cfg.memory_window_base = '0;
        vip_cfg.memory_window_limit = 64'h0000_0003_0000_0000;
        vip_cfg.max_memory_bytes = 0;

        if (!vip_cfg.validate_configuration(config_error))
            `uvm_fatal("DMA_AXI_VIP_CFG", config_error)
        vip_env = tvip_axi_env::type_id::create("vip_env", this);
        vip_env.add_slave_configuration(vip_cfg);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_config_db#(uvm_object_wrapper)::set(
            vip_env.slave_agents[0].sequencer,
            "run_phase",
            "default_sequence",
            tvip_axi_slave_default_sequence::type_id::get()
        );
    endfunction

    function void seed_pattern_region(bit [63:0] base, int unsigned word_count);
        tvip_axi_status vip_status;
        tvip_axi_data line_data;
        tvip_axi_strobe line_strobe;
        bit [63:0] line_address;

        vip_status = vip_env.slave_agents[0].get_status();
        if (vip_status == null || vip_status.memory == null)
            `uvm_fatal("DMA_AXI_VIP_MEMORY", "VIP reactive memory was not built")

        line_strobe = '0;
        line_strobe[15:0] = '1;
        for (int unsigned word = 0; word < word_count; word += 4) begin
            line_address = base + (word * 4);
            line_data = '0;
            for (int lane = 0; lane < 4; lane++) begin
                line_data[lane*32 +: 32] = dma_memory_word(line_address + lane*4);
            end
            vip_status.memory.put(line_data, line_strobe, 16, tvip_axi_address'(line_address), 0);
        end
    endfunction

    function int unsigned checker_violation_count();
        tvip_axi_protocol_checker checker;
        int unsigned total;

        checker = vip_env.slave_protocol_checkers[0];
        total = checker.aw_stability_violation_count + checker.w_stability_violation_count +
                checker.b_stability_violation_count + checker.ar_stability_violation_count +
                checker.r_stability_violation_count + checker.aw_4kb_boundary_violation_count +
                checker.ar_4kb_boundary_violation_count + checker.aw_burst_legality_violation_count +
                checker.ar_burst_legality_violation_count + checker.wstrb_lane_violation_count +
                checker.wlast_violation_count + checker.rlast_violation_count +
                checker.unexpected_b_count + checker.unexpected_r_count + checker.reset_unknown_count;
        for (int i = 0; i < 5; i++) begin
            total += checker.control_unknown_count[i] + checker.payload_unknown_count[i] +
                     checker.reset_valid_violation_count[i] + checker.reset_exit_valid_violation_count[i];
        end
        return total;
    endfunction

    task run_phase(uvm_phase phase);
        dma_load_ooo_sequence load_seq;
        dma_axi_vip_store_sequence store_seq;
        dma_axi_vip_readback_sequence readback_seq;
        tvip_axi_scoreboard vip_sb;
        tvip_axi_protocol_checker vip_checker;

        phase.raise_objection(this);
        wait (dma_vif.resetn === 1'b1);
        @(posedge dma_vif.clk);

        // Seed the same independent DDR oracle used by the block scoreboard.
        seed_pattern_region(64'h0000_0000_0000_1000, 32);

        load_seq = dma_load_ooo_sequence::type_id::create("load_ooo_seq");
        load_seq.start(env.cmd_sqr);
        repeat (4) @(posedge dma_vif.clk);
        env.sb.check_complete();

        // Store four SPAD words, then read the exact bytes back from the VIP's
        // sparse memory. The chosen external address makes the project oracle
        // agree with dma_memory_word(), so the existing data scoreboard checks
        // both the store payload and the subsequent memory readback.
        for (int i = 0; i < 4; i++)
            env.spad_model.preload_word(32'h0000_0C80 + i*4,
                                        dma_spad_source_word(32'h0000_0C80 + i*4));
        store_seq = dma_axi_vip_store_sequence::type_id::create("store_seq");
        store_seq.start(env.cmd_sqr);
        repeat (4) @(posedge dma_vif.clk);
        env.sb.check_complete();

        readback_seq = dma_axi_vip_readback_sequence::type_id::create("readback_seq");
        readback_seq.start(env.cmd_sqr);
        repeat (4) @(posedge dma_vif.clk);
        env.sb.check_complete();

        vip_sb = vip_env.slave_scoreboards[0];
        vip_checker = vip_env.slave_protocol_checkers[0];
        if (vip_sb.mismatch_count != 0 || vip_sb.outstanding_count != 0 ||
            vip_sb.request_count != vip_sb.checked_count)
            `uvm_error("DMA_AXI_VIP_SB", $sformatf(
                "VIP scoreboard requests=%0d completed=%0d outstanding=%0d mismatches=%0d",
                vip_sb.request_count, vip_sb.checked_count, vip_sb.outstanding_count,
                vip_sb.mismatch_count))
        if (vip_checker.outstanding_read_count() != 0 ||
            vip_checker.outstanding_write_count() != 0 ||
            vip_checker.unmatched_write_data_count() != 0 ||
            vip_checker.pending_write_response_count() != 0 || checker_violation_count() != 0)
            `uvm_error("DMA_AXI_VIP_CHECKER", $sformatf(
                "checker outstanding read/write=%0d/%0d unmatched_w=%0d pending_b=%0d violations=%0d",
                vip_checker.outstanding_read_count(), vip_checker.outstanding_write_count(),
                vip_checker.unmatched_write_data_count(), vip_checker.pending_write_response_count(),
                checker_violation_count()))
        if (env.axi_rsp != null)
            `uvm_error("DMA_AXI_VIP_RESPONDER", "Legacy AXI responder must be disabled in VIP integration test")

        `uvm_info("DMA_AXI_VIP_PASS", $sformatf(
            "DUT=ai_axi128_dma role=active-slave width=64/128/id4 requests=%0d reads=%0d writes=%0d load-store-readback=PASS mismatches=%0d outstanding=%0d checker_violations=%0d",
            vip_sb.request_count, vip_sb.read_count, vip_sb.write_count,
            vip_sb.mismatch_count, vip_sb.outstanding_count, checker_violation_count()), UVM_NONE)
        phase.drop_objection(this);
    endtask
endclass
