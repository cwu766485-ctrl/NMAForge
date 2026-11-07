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

// Test-only response policy: delay write ID 8 longer than other write IDs so
// the VIP can produce a deterministic, legal cross-ID B reorder. The standard
// reactive slave sequence, memory model, driver, checker and scoreboard remain
// in use; only the response-start delay policy is specialized for this test.
class dma_axi_vip_reorder_slave_sequence extends tvip_axi_slave_default_sequence;
    `uvm_object_utils(dma_axi_vip_reorder_slave_sequence)

    function new(string name = "dma_axi_vip_reorder_slave_sequence");
        super.new(name);
    endfunction

    protected virtual function int get_response_start_delay(tvip_axi_slave_item item);
        if (item.is_write()) begin
            if (item.id == 4'd8) return 200;
            return 100;
        end
        return -1;
    endfunction
endclass

class dma_axi_vip_integration_test extends dma_block_base_test;
    virtual ai_dma_axi_if dma_vif;
    tvip_axi_vif vip_vif;
    tvip_axi_env vip_env;
    tvip_axi_configuration vip_cfg;
    int unsigned scenario_count;

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
        // This DUT instance is deliberately built with MAX_BURST_BEATS=2.
        // Keep the VIP legality profile aligned with the tested DUT config.
        vip_cfg.max_burst_length = 2;
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
            dma_axi_vip_reorder_slave_sequence::type_id::get()
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

    task run_command_case(uvm_sequence_base seq, string case_name);
        int unsigned errors_before;

        errors_before = uvm_report_server::get_server().get_severity_count(UVM_ERROR);
        seq.start(env.cmd_sqr);
        repeat (4) @(posedge dma_vif.clk);
        env.sb.check_complete();
        scenario_count++;
        if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) == errors_before)
            `uvm_info("DMA_AXI_VIP_CASE_PASS", $sformatf("case=%s index=%0d",
                      case_name, scenario_count), UVM_NONE)
        else
            `uvm_info("DMA_AXI_VIP_CASE_FAIL", $sformatf("case=%s index=%0d",
                      case_name, scenario_count), UVM_NONE)
    endtask

    task run_write_concurrency_case(uvm_sequence_base seq, string case_name,
                                    int unsigned expected_aw_before_first_b,
                                    output bit out_of_order_observed);
        bit sequence_done;
        bit first_b_seen;
        bit aw_fire;
        bit b_fire;
        int unsigned accepted_aw;
        tvip_axi_id accepted_aw_ids[$];
        tvip_axi_id returned_b_ids[$];
        sequence_done = 0;
        first_b_seen = 0;
        out_of_order_observed = 0;
        accepted_aw = 0;
        fork
            begin
                seq.start(env.cmd_sqr);
                sequence_done = 1;
            end
            begin
                while (!sequence_done) begin
                    @(posedge dma_vif.clk);
                    // Count both handshakes at this sampling edge before
                    // evaluating their relation. AW and B may legally fire
                    // together; checking B first creates a one-cycle race.
                    aw_fire = (vip_vif.awvalid === 1'b1 && vip_vif.awready === 1'b1);
                    b_fire = (vip_vif.bvalid === 1'b1 && vip_vif.bready === 1'b1);
                    if (aw_fire) begin
                        accepted_aw++;
                        accepted_aw_ids.push_back(vip_vif.awid);
                    end
                    if (b_fire) begin
                        if (!first_b_seen) begin
                            if (accepted_aw < expected_aw_before_first_b)
                                `uvm_error("DMA_AXI_VIP_WRITE_CONCURRENCY", $sformatf(
                                    "first B completed after only %0d AW handshakes; expected at least %0d",
                                    accepted_aw, expected_aw_before_first_b))
                            first_b_seen = 1;
                        end
                        returned_b_ids.push_back(vip_vif.bid);
                    end
                end
            end
        join
        repeat (4) @(posedge dma_vif.clk);
        env.sb.check_complete();
        if (!first_b_seen)
            `uvm_error("DMA_AXI_VIP_WRITE_CONCURRENCY", "write completed without observing a B handshake")
        if (accepted_aw != expected_aw_before_first_b)
            `uvm_error("DMA_AXI_VIP_WRITE_CONCURRENCY", $sformatf(
                "accepted AW count=%0d expected exactly %0d",
                accepted_aw, expected_aw_before_first_b))
        if (returned_b_ids.size() != expected_aw_before_first_b ||
            accepted_aw_ids.size() != expected_aw_before_first_b)
            `uvm_error("DMA_AXI_VIP_WRITE_CONCURRENCY", $sformatf(
                "captured AW/B IDs=%0d/%0d expected exactly %0d",
                accepted_aw_ids.size(), returned_b_ids.size(),
                expected_aw_before_first_b))
        else begin
            for (int index = 0; index < expected_aw_before_first_b; index++)
                if (returned_b_ids[index] != accepted_aw_ids[index])
                    out_of_order_observed = 1;
            `uvm_info("DMA_AXI_VIP_WRITE_TRIAL", $sformatf(
                "case=%s accepted_aw=%0d out_of_order=%0b AW=%p B=%p",
                case_name, accepted_aw, out_of_order_observed,
                accepted_aw_ids, returned_b_ids), UVM_LOW)
        end
    endtask

    task set_response_error(bit enable_error);
        vip_cfg.response_weight_okay = enable_error ? 0 : 1;
        vip_cfg.response_weight_exokay = 0;
        vip_cfg.response_weight_slave_error = enable_error ? 1 : 0;
        vip_cfg.response_weight_decode_error = 0;
    endtask

    function int unsigned checker_violation_count();
        tvip_axi_protocol_checker checker;
        int unsigned total;

        checker = vip_env.slave_protocol_checkers[0];
        total = checker.aw_stability_violation_count + checker.w_stability_violation_count +
                checker.b_stability_violation_count + checker.ar_stability_violation_count +
                checker.r_stability_violation_count + checker.aw_4kb_boundary_violation_count +
                checker.ar_4kb_boundary_violation_count + checker.aw_burst_legality_violation_count +
                checker.ar_burst_legality_violation_count + checker.aw_region_page_violation_count +
                checker.ar_region_page_violation_count + checker.max_outstanding_read_violation_count +
                checker.max_outstanding_write_violation_count + checker.wstrb_lane_violation_count +
                checker.wlast_violation_count + checker.rlast_violation_count +
                checker.unexpected_b_count + checker.unexpected_r_count + checker.reset_unknown_count;
        for (int i = 0; i < 5; i++) begin
            total += checker.control_unknown_count[i] + checker.payload_unknown_count[i] +
                     checker.reset_valid_violation_count[i] + checker.reset_exit_valid_violation_count[i];
        end
        return total;
    endfunction

    task run_phase(uvm_phase phase);
        uvm_sequence_base seq;
        tvip_axi_scoreboard vip_sb;
        tvip_axi_protocol_checker vip_checker;
        int unsigned request_count_before;
        int unsigned read_count_before;
        int unsigned errors_before_write_trials;
        int unsigned write_ooo_trials;
        bit write_ooo_observed;
        bit write_trial_ooo;
        bit [31:0] sentinel;

        phase.raise_objection(this);
        wait (dma_vif.resetn === 1'b1);
        @(posedge dma_vif.clk);
        scenario_count = 0;
        vip_sb = vip_env.slave_scoreboards[0];

        // Seed the same independent DDR oracle used by the block scoreboard.
        seed_pattern_region(64'h0000_0000_0000_1000, 32);

        seq = dma_load_ooo_sequence::type_id::create("load_ooo_seq");
        run_command_case(seq, "four_outstanding_load");

        // Store four SPAD words, then read the exact bytes back from the VIP's
        // sparse memory. The chosen external address makes the project oracle
        // agree with dma_memory_word(), so the existing data scoreboard checks
        // both the store payload and the subsequent memory readback.
        for (int i = 0; i < 4; i++)
            env.spad_model.preload_word(32'h0000_0C80 + i*4,
                                        dma_spad_source_word(32'h0000_0C80 + i*4));
        seq = dma_axi_vip_store_sequence::type_id::create("store");
        run_command_case(seq, "store");

        seq = dma_axi_vip_readback_sequence::type_id::create("readback_seq");
        run_command_case(seq, "vip_memory_readback");

        // 2-D and gather reads exercise non-contiguous DDR address generation
        // while the protocol VIP remains an unmodified reactive AXI slave.
        for (int row = 0; row < 3; row++)
            seed_pattern_region(64'h4000 + row*64'h40, 6);
        seq = dma_2d_load_sequence::type_id::create("load_2d_seq");
        run_command_case(seq, "two_dimensional_load");

        seed_pattern_region(64'h5000, 4);
        seed_pattern_region(64'h5100, 4);
        seed_pattern_region(64'h5200, 4);
        // The DUT fetches each gather row address from scratchpad. The row
        // address queue on the UVM command is scoreboard metadata only; it is
        // not a DUT pin and must not substitute for programming the index RAM.
        env.spad_model.preload_word(32'h1000, 32'h5000);
        env.spad_model.preload_word(32'h1004, 32'h5100);
        env.spad_model.preload_word(32'h1008, 32'h5200);
        seq = dma_gather_load_sequence::type_id::create("gather_load_seq");
        run_command_case(seq, "gather_load");

        seed_pattern_region(64'h9000, 16);
        seq = dma_narrow_load_sequence::type_id::create("narrow_load_seq");
        run_command_case(seq, "mixed_size_narrow_load");

        seed_pattern_region(64'h1fc0, 40);
        seq = dma_4k_load_sequence::type_id::create("load_4k_seq");
        run_command_case(seq, "four_kib_boundary_crossing");

        seed_pattern_region(64'h1ff0, 12);
        seq = dma_4k_edge_load_sequence::type_id::create("load_4k_edge_seq");
        run_command_case(seq, "four_kib_single_beat_edge");

        // Longer stores cover B-channel reordering and the DUT's four tagged
        // write slots. The project scoreboard checks every emitted data word.
        env.spad_model.preload_source_pattern(32'ha00, 16);
        set_delay_window(vip_cfg.response_start_delay, 20, 20);
        seq = dma_store_booo_sequence::type_id::create("store_booo_seq");
        run_command_case(seq, "multi_burst_store");

        env.spad_model.preload_source_pattern(32'h1c00, 32);
        // Four bursts each need scratchpad gather, AW and W time before their
        // B responses are allowed to start. Keep the response window closed
        // long enough to observe all four accepted AWs concurrently.
        set_delay_window(vip_cfg.response_start_delay, 100, 100);
        errors_before_write_trials = uvm_report_server::get_server().get_severity_count(UVM_ERROR);
        write_ooo_observed = 0;
        write_ooo_trials = 0;
        // OUT_OF_ORDER permits legal reordering; it does not force each
        // individual selection to be non-FIFO. Repeat the directed four-AW
        // pressure case until cross-ID B reordering is observed or the bounded
        // trial budget is exhausted.
        for (int trial = 0; trial < 16 && !write_ooo_observed; trial++) begin
            seq = dma_store_four_booo_sequence::type_id::create(
                $sformatf("store_four_booo_seq_%0d", trial));
            run_write_concurrency_case(seq, "four_outstanding_stores", 4, write_trial_ooo);
            write_ooo_observed |= write_trial_ooo;
            write_ooo_trials++;
            if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) !=
                errors_before_write_trials)
                break;
        end
        if (!write_ooo_observed)
            `uvm_error("DMA_AXI_VIP_WRITE_ORDER", $sformatf(
                "no cross-ID B reorder observed in %0d directed trials", write_ooo_trials))
        else
            `uvm_info("DMA_AXI_VIP_B_OOO_PASS", $sformatf(
                "observed cross-ID B reorder within %0d directed trials", write_ooo_trials), UVM_NONE)
        scenario_count++;
        if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) == errors_before_write_trials)
            `uvm_info("DMA_AXI_VIP_CASE_PASS", $sformatf(
                "case=four_outstanding_stores index=%0d trials=%0d", scenario_count,
                write_ooo_trials), UVM_NONE)
        else
            `uvm_info("DMA_AXI_VIP_CASE_FAIL", $sformatf(
                "case=four_outstanding_stores index=%0d trials=%0d", scenario_count,
                write_ooo_trials), UVM_NONE)
        set_delay_window(vip_cfg.response_start_delay, 3, 4);

        env.spad_model.preload_source_pattern(32'hc00, 5);
        env.spad_model.preload_source_pattern(32'hc30, 5);
        env.spad_model.preload_source_pattern(32'hc60, 5);
        seq = dma_2d_store_sequence::type_id::create("store_2d_seq");
        run_command_case(seq, "two_dimensional_store");

        // Tail lengths 1/2/3 require distinct partial WSTRB masks. The
        // independent project scoreboard also rejects missing/extra words.
        for (int tail_words = 1; tail_words <= 3; tail_words++) begin
            dma_short_tail_store_sequence tail_seq;
            bit [31:0] tail_spad;
            tail_spad = 32'h1800 + ((tail_words - 1) * 16);
            env.spad_model.preload_source_pattern(tail_spad, tail_words);
            tail_seq = dma_short_tail_store_sequence::type_id::create(
                $sformatf("tail_store_%0d_seq", tail_words));
            tail_seq.word_count = tail_words;
            tail_seq.ext_addr = 64'h8000 + ((tail_words - 1) * 16);
            tail_seq.spad_addr = tail_spad;
            run_command_case(tail_seq, $sformatf("tail_store_%0d_words", tail_words));
        end

        // Illegal project configuration must be rejected locally and emit no
        // AXI request; this is a DUT functional negative, not VIP error mode.
        request_count_before = vip_sb.request_count;
        seq = dma_config_error_sequence::type_id::create("config_error_seq");
        run_command_case(seq, "unaligned_configuration_rejected");
        if (vip_sb.request_count != request_count_before)
            `uvm_error("DMA_AXI_VIP_CONFIG_IO", $sformatf(
                "invalid command emitted AXI traffic: before=%0d after=%0d",
                request_count_before, vip_sb.request_count))

        // Inject SLVERR through the reusable VIP response policy. Verify the
        // DUT drains all accepted reads and does not partially commit data.
        for (int word = 0; word < 32; word++) begin
            sentinel = 32'hdada_0000 + word;
            env.spad_model.preload_word(32'hd00 + word*4, sentinel);
        end
        set_response_error(1'b1);
        set_delay_window(vip_cfg.response_start_delay, 20, 20);
        read_count_before = vip_sb.read_count;
        seq = dma_read_slverr_sequence::type_id::create("read_slverr_seq");
        run_command_case(seq, "read_slverr_drain");
        if ((vip_sb.read_count - read_count_before) < 4)
            `uvm_error("DMA_AXI_VIP_RSLVERR_DRAIN", $sformatf(
                "expected at least four completed read bursts, before=%0d after=%0d",
                read_count_before, vip_sb.read_count))
        for (int word = 0; word < 32; word++) begin
            sentinel = 32'hdada_0000 + word;
            if (env.spad_model.read_word(32'hd00 + word*4) !== sentinel)
                `uvm_error("DMA_AXI_VIP_RSLVERR_COMMIT", $sformatf(
                    "SLVERR load modified destination sentinel word %0d", word))
        end

        set_response_error(1'b0);
        set_delay_window(vip_cfg.response_start_delay, 3, 4);
        env.spad_model.preload_source_pattern(32'hf80, 4);
        set_response_error(1'b1);
        seq = dma_write_slverr_sequence::type_id::create("write_slverr_seq");
        run_command_case(seq, "write_slverr");

        // Delay reactive responses long enough for abort to occur with reads
        // and a write transaction outstanding, then require a clean drain.
        set_response_error(1'b0);
        set_delay_window(vip_cfg.response_start_delay, 20, 20);
        seed_pattern_region(64'h7000, 32);
        seq = dma_abort_read_sequence::type_id::create("abort_read_seq");
        run_command_case(seq, "abort_read_outstanding_drain");

        env.spad_model.preload_source_pattern(32'h1000, 16);
        seq = dma_abort_write_sequence::type_id::create("abort_write_seq");
        run_command_case(seq, "abort_write_response_drain");

        // Restore normal latency and exercise bounded response backpressure
        // with a required two-request read high-water mark.
        set_delay_window(vip_cfg.response_start_delay, 3, 8);
        set_delay_window(vip_cfg.arready_delay, 0, 4);
        seed_pattern_region(64'h8800, 24);
        seq = dma_backpressure_sequence::type_id::create("backpressure_seq");
        run_command_case(seq, "read_backpressure_outstanding");

        set_response_error(1'b0);
        set_delay_window(vip_cfg.response_start_delay, 3, 4);
        set_delay_window(vip_cfg.arready_delay, 0, 1);

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

        if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) == 0 &&
            scenario_count == 20 && vip_sb.mismatch_count == 0 &&
            vip_sb.outstanding_count == 0 && checker_violation_count() == 0) begin
            `uvm_info("DMA_AXI_VIP_PASS", $sformatf(
                "DUT=ai_axi128_dma role=active-slave width=64/128/id4 scenarios=%0d requests=%0d reads=%0d writes=%0d positive-negative-corner-matrix=PASS mismatches=%0d outstanding=%0d checker_violations=%0d",
                scenario_count,
                vip_sb.request_count, vip_sb.read_count, vip_sb.write_count,
                vip_sb.mismatch_count, vip_sb.outstanding_count, checker_violation_count()), UVM_NONE)
        end
        else begin
            `uvm_info("DMA_AXI_VIP_FAIL", $sformatf(
                "PASS suppressed: errors=%0d scenarios=%0d requests=%0d completed=%0d reads=%0d writes=%0d mismatches=%0d outstanding=%0d checker_violations=%0d",
                uvm_report_server::get_server().get_severity_count(UVM_ERROR),
                scenario_count, vip_sb.request_count, vip_sb.checked_count,
                vip_sb.read_count, vip_sb.write_count, vip_sb.mismatch_count,
                vip_sb.outstanding_count, checker_violation_count()), UVM_NONE)
        end
        phase.drop_objection(this);
    endtask
endclass
