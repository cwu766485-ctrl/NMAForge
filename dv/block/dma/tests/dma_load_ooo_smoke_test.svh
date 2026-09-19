class dma_load_ooo_sequence extends uvm_sequence #(dma_cmd_item);
    `uvm_object_utils(dma_load_ooo_sequence)
    function new(string name = "dma_load_ooo_sequence"); super.new(name); endfunction
    task body();
        dma_cmd_item req;
        req = dma_cmd_item::type_id::create("load_ooo_req");
        start_item(req);
        req.ext_addr = 64'h0000_0000_0000_1000;
        req.spad_addr = 32'h0000_0200;
        // 32 words = eight 128-bit beats. With MAX_BURST_BEATS=2 this makes
        // four tagged ARs and exercises the full four-outstanding window.
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 16'd0;
        req.ext_stride = '0;
        req.spad_stride = '0;
        req.read_outstanding = 3'd4;
        req.store = 1'b0;
        req.gather_enable = 1'b0;
        req.gather_index_base = '0;
        req.expect_error = 1'b0;
        req.expected_error_code = '0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 4;
        finish_item(req);
    endtask
endclass

class dma_load_ooo_smoke_test extends dma_block_base_test;
    `uvm_component_utils(dma_load_ooo_smoke_test)
    function new(string name = "dma_load_ooo_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        dma_load_ooo_sequence seq;
        phase.raise_objection(this);
        cfg.ooo_read_responses = 1'b1;
        seq = dma_load_ooo_sequence::type_id::create("seq");
        seq.start(env.cmd_sqr);
        repeat (4) @(posedge env.cmd_drv.vif.clk);
        env.sb.check_complete();
        env.axi_rsp.check_out_of_order();
        phase.drop_objection(this);
    endtask
endclass
