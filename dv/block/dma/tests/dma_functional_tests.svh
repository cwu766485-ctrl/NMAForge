// Focused UVM sequences/tests for the remaining DMA block feature matrix.
// Each test is deliberately one command per simulation, which gives a clean
// reset of the AXI responder, a focused waveform and straightforward triage.

class dma_2d_load_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_2d_load_sequence)
    function new(string name = "dma_2d_load_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h4000; req.spad_addr = 32'h800;
        req.length_words = 0; req.row_words = 6; req.row_count = 3;
        req.ext_stride = 32'h40; req.spad_stride = 32'h30;
        req.read_outstanding = 2; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 1;
        finish_item(req);
    endtask
endclass

class dma_gather_load_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_gather_load_sequence)
    function new(string name = "dma_gather_load_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 0; req.spad_addr = 32'h900;
        req.length_words = 0; req.row_words = 4; req.row_count = 3;
        req.ext_stride = 0; req.spad_stride = 32'h20;
        req.read_outstanding = 2; req.store = 0; req.gather_enable = 1;
        req.gather_index_base = 32'h1000;
        req.gather_row_addr = '{32'h5000, 32'h5100, 32'h5200};
        req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 1;
        finish_item(req);
    endtask
endclass

class dma_store_booo_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_store_booo_sequence)
    function new(string name = "dma_store_booo_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h6000; req.spad_addr = 32'ha00;
        req.length_words = 16; req.row_words = 16; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 1; req.store = 1; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_2d_store_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_2d_store_sequence)
    function new(string name = "dma_2d_store_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h6800; req.spad_addr = 32'hc00;
        req.length_words = 0; req.row_words = 5; req.row_count = 3;
        req.ext_stride = 32'h40; req.spad_stride = 32'h30;
        req.read_outstanding = 1; req.store = 1; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_aw_stall_store_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_aw_stall_store_sequence)
    function new(string name = "dma_aw_stall_store_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h6c00; req.spad_addr = 32'hc80;
        req.length_words = 4; req.row_words = 4; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 1; req.store = 1; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_narrow_load_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_narrow_load_sequence)
    function new(string name = "dma_narrow_load_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        // The unaligned first three words require AXI SIZE=32 transfers;
        // the final four words switch to the 128-bit line path at 0x9010.
        req.ext_addr = 64'h9004; req.spad_addr = 32'hf00;
        req.length_words = 7; req.row_words = 7; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 2; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 1;
        finish_item(req);
    endtask
endclass

class dma_config_error_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_config_error_sequence)
    function new(string name = "dma_config_error_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        // DMA requires word-aligned DDR addresses. This must fail before AR.
        req.ext_addr = 64'h9802; req.spad_addr = 32'h1100;
        req.length_words = 4; req.row_words = 4; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 1; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 1; req.expected_error_code = 4'd1;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_4k_load_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_4k_load_sequence)
    function new(string name = "dma_4k_load_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h1fc0; req.spad_addr = 32'hb00;
        req.length_words = 40; req.row_words = 40; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 2; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 1;
        finish_item(req);
    endtask
endclass

class dma_abort_read_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_abort_read_sequence)
    function new(string name = "dma_abort_read_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h7000; req.spad_addr = 32'hd00;
        req.length_words = 32; req.row_words = 32; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 4; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 1; req.expected_error_code = 4'd5;
        // Four ARs are accepted before the responder can return R. Abort then
        // proves the RTL drains all accepted reads rather than losing them.
        req.abort_after_cycles = 10; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_read_slverr_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_read_slverr_sequence)
    function new(string name = "dma_read_slverr_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h7000; req.spad_addr = 32'hd00;
        req.length_words = 32; req.row_words = 32; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 4; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 1; req.expected_error_code = 4'd2;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_spad_error_drain_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_spad_error_drain_sequence)
    function new(string name = "dma_spad_error_drain_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h7c00; req.spad_addr = 32'h1200;
        req.length_words = 32; req.row_words = 32; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 4; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 1; req.expected_error_code = 4'd4;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_write_slverr_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_write_slverr_sequence)
    function new(string name = "dma_write_slverr_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h7400; req.spad_addr = 32'hf80;
        req.length_words = 4; req.row_words = 4; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 1; req.store = 1; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 1; req.expected_error_code = 4'd3;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_abort_write_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_abort_write_sequence)
    function new(string name = "dma_abort_write_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h7800; req.spad_addr = 32'h1000;
        req.length_words = 16; req.row_words = 16; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 1; req.store = 1; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 1; req.expected_error_code = 4'd5;
        req.abort_after_cycles = 0; req.abort_after_aw = 1;
        req.minimum_rd_highwater = 0;
        finish_item(req);
    endtask
endclass

class dma_backpressure_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_backpressure_sequence)
    function new(string name = "dma_backpressure_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req = dma_cmd_item::type_id::create("req");
        start_item(req);
        req.ext_addr = 64'h8800; req.spad_addr = 32'he00;
        req.length_words = 24; req.row_words = 24; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0;
        req.read_outstanding = 3; req.store = 0; req.gather_enable = 0;
        req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
        req.abort_after_cycles = 0; req.minimum_rd_highwater = 2;
        finish_item(req);
    endtask
endclass

class dma_2d_load_test extends dma_block_base_test;
    `uvm_component_utils(dma_2d_load_test)
    function new(string name = "dma_2d_load_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_2d_load_sequence seq = dma_2d_load_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.min_accepted_reads_before_response = 1;
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_gather_load_test extends dma_block_base_test;
    `uvm_component_utils(dma_gather_load_test)
    function new(string name = "dma_gather_load_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_gather_load_sequence seq = dma_gather_load_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.min_accepted_reads_before_response = 1;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        env.spad_model.preload_word(32'h1000, 32'h5000);
        env.spad_model.preload_word(32'h1004, 32'h5100);
        env.spad_model.preload_word(32'h1008, 32'h5200);
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_store_booo_test extends dma_block_base_test;
    `uvm_component_utils(dma_store_booo_test)
    function new(string name = "dma_store_booo_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_store_booo_sequence seq = dma_store_booo_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.min_accepted_writes_before_response = 2;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        env.spad_model.preload_source_pattern(32'ha00, 16);
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk);
        env.sb.check_complete(); env.axi_rsp.check_write_out_of_order();
        phase.drop_objection(this);
    endtask
endclass

class dma_4k_load_test extends dma_block_base_test;
    `uvm_component_utils(dma_4k_load_test)
    function new(string name = "dma_4k_load_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_4k_load_sequence seq = dma_4k_load_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.min_accepted_reads_before_response = 1;
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_2d_store_test extends dma_block_base_test;
    `uvm_component_utils(dma_2d_store_test)
    function new(string name = "dma_2d_store_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_2d_store_sequence seq = dma_2d_store_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.min_accepted_writes_before_response = 1;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        env.spad_model.preload_source_pattern(32'hc00, 5);
        env.spad_model.preload_source_pattern(32'hc30, 5);
        env.spad_model.preload_source_pattern(32'hc60, 5);
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_narrow_load_test extends dma_block_base_test;
    `uvm_component_utils(dma_narrow_load_test)
    function new(string name = "dma_narrow_load_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_narrow_load_sequence seq = dma_narrow_load_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.min_accepted_reads_before_response = 1;
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_config_error_test extends dma_block_base_test;
    `uvm_component_utils(dma_config_error_test)
    function new(string name = "dma_config_error_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_config_error_sequence seq = dma_config_error_sequence::type_id::create("seq");
        phase.raise_objection(this); seq.start(env.cmd_sqr);
        repeat(2) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        if (env.axi_rsp.accepted_ids.size() != 0 || env.axi_rsp.accepted_bids.size() != 0)
            `uvm_error("DMA_CONFIG_IO", "invalid configuration issued AXI traffic")
        phase.drop_objection(this);
    endtask
endclass

class dma_abort_read_test extends dma_block_base_test;
    `uvm_component_utils(dma_abort_read_test)
    function new(string name = "dma_abort_read_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_abort_read_sequence seq = dma_abort_read_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.min_accepted_reads_before_response = 4;
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_read_slverr_test extends dma_block_base_test;
    `uvm_component_utils(dma_read_slverr_test)
    function new(string name = "dma_read_slverr_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_read_slverr_sequence error_seq = dma_read_slverr_sequence::type_id::create("error_seq");
        dma_narrow_load_sequence recovery_seq = dma_narrow_load_sequence::type_id::create("recovery_seq");
        bit [31:0] sentinel;
        int unsigned word;
        phase.raise_objection(this);
        cfg.min_accepted_reads_before_response = 4;
        cfg.ooo_read_responses = 1;
        cfg.inject_read_error = 1;
        // Four 2-beat bursts are accepted. Newest-first response returns
        // this last burst first, so the error must prevent every SPAD commit.
        cfg.inject_read_error_addr = 64'h7060;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        for (word = 0; word < 32; word++) begin
            sentinel = 32'hdada_0000 + word;
            env.spad_model.preload_word(32'hd00 + word*4, sentinel);
        end

        error_seq.start(env.cmd_sqr);
        repeat (2) @(posedge env.cmd_drv.vif.clk);
        if (cfg.injected_read_error_responses != 1 ||
            env.axi_rsp.accepted_ids.size() != 4 ||
            env.axi_rsp.completed_ids.size() != 4 ||
            env.axi_rsp.pending_reads.size() != 0 || env.axi_rsp.active_read != null)
            `uvm_error("DMA_RRESP_DRAIN", $sformatf(
                "expected one SLVERR and 4/4 accepted/completed reads; injected=%0d accepted=%0d completed=%0d pending=%0d",
                cfg.injected_read_error_responses, env.axi_rsp.accepted_ids.size(),
                env.axi_rsp.completed_ids.size(), env.axi_rsp.pending_reads.size()))
        else
            `uvm_info("DMA_RRESP_DRAIN", "SLVERR reported ERR_AXI_RD after all four accepted reads drained", UVM_LOW)
        for (word = 0; word < 32; word++) begin
            sentinel = 32'hdada_0000 + word;
            if (env.spad_model.read_word(32'hd00 + word*4) !== sentinel)
                `uvm_error("DMA_RRESP_COMMIT", $sformatf(
                    "failed read modified SPAD sentinel at word %0d", word))
        end

        cfg.inject_read_error = 0;
        cfg.min_accepted_reads_before_response = 1;
        recovery_seq.start(env.cmd_sqr);
        repeat (3) @(posedge env.cmd_drv.vif.clk);
        env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_spad_error_drain_test extends dma_block_base_test;
    `uvm_component_utils(dma_spad_error_drain_test)
    function new(string name = "dma_spad_error_drain_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_spad_error_drain_sequence error_seq = dma_spad_error_drain_sequence::type_id::create("error_seq");
        dma_narrow_load_sequence recovery_seq = dma_narrow_load_sequence::type_id::create("recovery_seq");
        bit [31:0] sentinel;
        int unsigned word;
        phase.raise_objection(this);
        cfg.min_accepted_reads_before_response = 4;
        cfg.ooo_read_responses = 1;
        cfg.inject_spad_line_req_error = 1;
        cfg.injected_spad_line_req_errors = 0;
        cfg.injected_spad_line_req_addr = '0;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        for (word = 0; word < 32; word++) begin
            sentinel = 32'hface_0000 + word;
            env.spad_model.preload_word(32'h1200 + word*4, sentinel);
        end

        error_seq.start(env.cmd_sqr);
        repeat (2) @(posedge env.cmd_drv.vif.clk);
        if (cfg.injected_spad_line_req_errors != 1 ||
            // Newest-first returns the final 8-word burst first; its first
            // line is the destination base plus 24 words, not the base.
            cfg.injected_spad_line_req_addr != (32'h1200 + 24*4) ||
            env.axi_rsp.accepted_ids.size() != 4 ||
            env.axi_rsp.completed_ids.size() != 4 ||
            env.axi_rsp.pending_reads.size() != 0 || env.axi_rsp.active_read != null)
            `uvm_error("DMA_SPAD_ERROR_DRAIN", $sformatf(
                "expected one line-request error and 4/4 accepted/completed reads; injected=%0d accepted=%0d completed=%0d pending=%0d",
                cfg.injected_spad_line_req_errors, env.axi_rsp.accepted_ids.size(),
                env.axi_rsp.completed_ids.size(), env.axi_rsp.pending_reads.size()))
        else
            `uvm_info("DMA_SPAD_ERROR_DRAIN", "ERR_SPAD completed after all four accepted reads drained", UVM_LOW)

        for (word = 0; word < 32; word++) begin
            sentinel = 32'hface_0000 + word;
            if (env.spad_model.read_word(32'h1200 + word*4) !== sentinel)
                `uvm_error("DMA_SPAD_ERROR_COMMIT", $sformatf(
                    "failed load modified destination sentinel at word %0d", word))
        end

        cfg.inject_spad_line_req_error = 0;
        cfg.min_accepted_reads_before_response = 1;
        recovery_seq.start(env.cmd_sqr);
        repeat (3) @(posedge env.cmd_drv.vif.clk);
        env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_write_slverr_test extends dma_block_base_test;
    `uvm_component_utils(dma_write_slverr_test)
    function new(string name = "dma_write_slverr_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_write_slverr_sequence error_seq = dma_write_slverr_sequence::type_id::create("error_seq");
        dma_narrow_load_sequence recovery_seq = dma_narrow_load_sequence::type_id::create("recovery_seq");
        phase.raise_objection(this);
        cfg.min_accepted_writes_before_response = 1;
        cfg.inject_write_error = 1;
        cfg.injected_write_error_responses = 0;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        env.spad_model.preload_source_pattern(32'hf80, 4);

        error_seq.start(env.cmd_sqr);
        repeat (2) @(posedge env.cmd_drv.vif.clk);
        if (cfg.injected_write_error_responses != 1 ||
            env.axi_rsp.accepted_bids.size() != 1 ||
            env.axi_rsp.completed_bids.size() != 1 ||
            env.axi_rsp.accepted_bids[0] != env.axi_rsp.completed_bids[0] ||
            env.axi_rsp.active_write != null || env.axi_rsp.active_b != null ||
            env.axi_rsp.pending_b.size() != 0)
            `uvm_error("DMA_BRESP_DRAIN", $sformatf(
                "expected one SLVERR and exactly one accepted/completed W/B burst; injected=%0d AW/WLAST=%0d B=%0d pending_B=%0d",
                cfg.injected_write_error_responses, env.axi_rsp.accepted_bids.size(),
                env.axi_rsp.completed_bids.size(), env.axi_rsp.pending_b.size()))
        else
            `uvm_info("DMA_BRESP_DRAIN", "SLVERR reported ERR_AXI_WR after the accepted W/B burst drained exactly once", UVM_LOW)

        cfg.inject_write_error = 0;
        cfg.min_accepted_reads_before_response = 1;
        recovery_seq.start(env.cmd_sqr);
        repeat (3) @(posedge env.cmd_drv.vif.clk);
        env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_abort_write_test extends dma_block_base_test;
    `uvm_component_utils(dma_abort_write_test)
    function new(string name = "dma_abort_write_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_abort_write_sequence abort_seq = dma_abort_write_sequence::type_id::create("abort_seq");
        dma_narrow_load_sequence recovery_seq = dma_narrow_load_sequence::type_id::create("recovery_seq");
        phase.raise_objection(this);
        cfg.enable_backpressure = 1;
        cfg.write_response_delay_cycles = 8;
        cfg.min_accepted_writes_before_response = 1;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        env.spad_model.preload_source_pattern(32'h1000, 16);

        abort_seq.start(env.cmd_sqr);
        repeat (2) @(posedge env.cmd_drv.vif.clk);
        if (env.axi_rsp.accepted_bids.size() != 1 ||
            env.axi_rsp.completed_bids.size() != 1 ||
            env.axi_rsp.active_write != null || env.axi_rsp.active_b != null ||
            env.axi_rsp.pending_b.size() != 0)
            `uvm_error("DMA_WRITE_ABORT_DRAIN", $sformatf(
                "expected exactly one completed W/B burst after abort; AW/WLAST=%0d B=%0d pending_B=%0d",
                env.axi_rsp.accepted_bids.size(), env.axi_rsp.completed_bids.size(),
                env.axi_rsp.pending_b.size()))
        else
            `uvm_info("DMA_WRITE_ABORT_DRAIN", "accepted AW completed its W burst and B response before done", UVM_LOW)

        // A fresh command after the drained abort proves the DMA returned to
        // an operational idle state rather than stranding the write lifecycle.
        cfg.min_accepted_reads_before_response = 1;
        recovery_seq.start(env.cmd_sqr);
        repeat (3) @(posedge env.cmd_drv.vif.clk);
        env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_aw_stall_stability_test extends dma_block_base_test;
    `uvm_component_utils(dma_aw_stall_stability_test)
    function new(string name = "dma_aw_stall_stability_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_aw_stall_store_sequence store_seq = dma_aw_stall_store_sequence::type_id::create("store_seq");
        bit [80:0] held_payload;
        int unsigned timeout;
        int unsigned stall_cycle;
        phase.raise_objection(this);
        wait (env.cmd_drv.vif.resetn === 1'b1);
        // Arm the responder before the command can be published, eliminating
        // a race with its cycle-based default AWREADY generation.
        @(negedge env.cmd_drv.vif.clk);
        cfg.force_awready_low = 1;
        env.spad_model.preload_source_pattern(32'hc80, 4);

        fork
            store_seq.start(env.cmd_sqr);
            begin
                timeout = 0;
                while (env.axi_rsp.vif.awvalid !== 1'b1 && timeout < 4000) begin
                    @(negedge env.cmd_drv.vif.clk);
                    timeout++;
                end
                if (timeout == 4000) begin
                    `uvm_error("DMA_AW_STALL", "AWVALID did not assert while AWREADY was held low")
                    // Unblock the driver even on the failure path so the
                    // fork can join and report the test failure cleanly.
                    cfg.force_awready_low = 0;
                end else begin
                    if (env.axi_rsp.vif.awready !== 1'b0)
                        `uvm_error("DMA_AW_STALL", "AWREADY was not low when AWVALID first appeared")
                    held_payload = {env.axi_rsp.vif.awid, env.axi_rsp.vif.awaddr,
                                    env.axi_rsp.vif.awlen, env.axi_rsp.vif.awsize,
                                    env.axi_rsp.vif.awburst};
                    // Four full sampled cycles deliberately exercise the
                    // DUT's |=> $stable AW assertion, not a coincident pulse.
                    for (stall_cycle = 0; stall_cycle < 4; stall_cycle++) begin
                        @(negedge env.cmd_drv.vif.clk);
                        if (env.axi_rsp.vif.awready !== 1'b0 ||
                            env.axi_rsp.vif.awvalid !== 1'b1 ||
                            {env.axi_rsp.vif.awid, env.axi_rsp.vif.awaddr,
                             env.axi_rsp.vif.awlen, env.axi_rsp.vif.awsize,
                             env.axi_rsp.vif.awburst} !== held_payload)
                            `uvm_error("DMA_AW_STALL", $sformatf(
                                "AW not held stable during forced stall cycle %0d", stall_cycle))
                    end
                    cfg.force_awready_low = 0;
                end
            end
        join

        if (timeout < 4000) begin
            repeat (2) @(posedge env.cmd_drv.vif.clk);
            if (env.axi_rsp.accepted_bids.size() != 1 ||
                env.axi_rsp.completed_bids.size() != 1 ||
                env.axi_rsp.active_write != null || env.axi_rsp.active_b != null ||
                env.axi_rsp.pending_b.size() != 0)
                `uvm_error("DMA_AW_STALL_DRAIN", $sformatf(
                    "expected one completed AW/W/B transaction; accepted=%0d completed=%0d pending=%0d",
                    env.axi_rsp.accepted_bids.size(), env.axi_rsp.completed_bids.size(),
                    env.axi_rsp.pending_b.size()))
            env.sb.check_complete();
            `uvm_info("DMA_AW_STALL", "AW payload stayed stable through four forced stall cycles; store scoreboard completed", UVM_LOW)
        end
        phase.drop_objection(this);
    endtask
endclass

class dma_backpressure_test extends dma_block_base_test;
    `uvm_component_utils(dma_backpressure_test)
    function new(string name = "dma_backpressure_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_backpressure_sequence seq = dma_backpressure_sequence::type_id::create("seq");
        phase.raise_objection(this); cfg.enable_backpressure = 1;
        cfg.min_accepted_reads_before_response = 2; cfg.ooo_read_responses = 1;
        seq.start(env.cmd_sqr); repeat(3) @(posedge env.cmd_drv.vif.clk); env.sb.check_complete();
        phase.drop_objection(this);
    endtask
endclass

class dma_one_command_sequence extends uvm_sequence #(dma_cmd_item);
    dma_cmd_item item;
    `uvm_object_utils(dma_one_command_sequence)
    function new(string name = "dma_one_command_sequence"); super.new(name); endfunction
    task body();
        start_item(item);
        finish_item(item);
    endtask
endclass

// This test adds constrained-random legal 1-D loads/stores on top of the
// directed corner cases. A failing seed is emitted by VCS (+ntb_random_seed)
// and can be replayed through the Makefile's SEED variable.
class dma_random_stress_test extends dma_block_base_test;
    `uvm_component_utils(dma_random_stress_test)
    function new(string name = "dma_random_stress_test", uvm_component parent = null); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        dma_cmd_item req;
        dma_one_command_sequence seq;
        int unsigned case_index;
        phase.raise_objection(this);
        cfg.enable_backpressure = 1;
        cfg.min_accepted_reads_before_response = 1;
        cfg.min_accepted_writes_before_response = 1;
        wait (env.cmd_drv.vif.resetn === 1'b1);
        @(posedge env.cmd_drv.vif.clk);
        for (case_index = 0; case_index < 20; case_index++) begin
            req = dma_cmd_item::type_id::create($sformatf("random_req_%0d", case_index));
            if (!req.randomize() with {
                    ext_addr inside {[64'ha000:64'ha7f0]};
                    ext_addr[1:0] == 0;
                    spad_addr inside {[32'h1200:32'h1bf0]};
                    spad_addr[1:0] == 0;
                    length_words inside {[1:24]};
                    read_outstanding inside {[1:4]};
                    store inside {0, 1};
                })
                `uvm_fatal("RAND", "could not generate a legal DMA command")
            req.row_words = req.length_words; req.row_count = 0;
            req.ext_stride = 0; req.spad_stride = 0; req.gather_enable = 0;
            req.gather_index_base = 0; req.expect_error = 0; req.expected_error_code = 0;
            req.abort_after_cycles = 0; req.minimum_rd_highwater = 0;
            if (req.store)
                env.spad_model.preload_source_pattern(req.spad_addr, req.length_words);
            seq = dma_one_command_sequence::type_id::create($sformatf("seq_%0d", case_index));
            seq.item = req;
            seq.start(env.cmd_sqr);
            repeat (2) @(posedge env.cmd_drv.vif.clk);
            env.sb.check_complete();
            `uvm_info("DMA_RANDOM_CASE", $sformatf("case=%0d store=%0b words=%0d",
                      case_index, req.store, req.length_words), UVM_LOW)
        end
        phase.drop_objection(this);
    endtask
endclass
