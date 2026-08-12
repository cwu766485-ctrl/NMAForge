class dma_cmd_driver extends uvm_driver #(dma_cmd_item);
    virtual ai_dma_ctrl_if vif;
    uvm_analysis_port #(dma_cmd_item) cmd_ap;
    `uvm_component_utils(dma_cmd_driver)

    function new(string name = "dma_cmd_driver", uvm_component parent = null);
        super.new(name, parent);
        cmd_ap = new("cmd_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_dma_ctrl_if)::get(this, "", "ctrl_vif", vif))
            `uvm_fatal("NOVIF", "dma_cmd_driver needs ctrl_vif")
    endfunction

    task run_phase(uvm_phase phase);
        dma_cmd_item req;
        drive_idle();
        forever begin
            seq_item_port.get_next_item(req);
            cmd_ap.write(req);
            drive_command(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_idle();
        vif.start             <= 1'b0;
        vif.abort             <= 1'b0;
        vif.store             <= 1'b0;
        vif.ext_addr          <= '0;
        vif.spad_addr         <= '0;
        vif.length_words      <= '0;
        vif.row_words         <= '0;
        vif.row_count         <= '0;
        vif.ext_stride        <= '0;
        vif.spad_stride       <= '0;
        vif.gather_enable     <= 1'b0;
        vif.gather_index_base <= '0;
        vif.read_outstanding  <= 3'd4;
    endtask

    task drive_command(dma_cmd_item req);
        int unsigned timeout;
        int unsigned active_cycles;
        bit abort_sent;
        // A UVM sequence may start at time zero.  Do not consume its one-cycle
        // start pulse while the DUT is still held in reset.
        wait (vif.resetn === 1'b1);
        @(posedge vif.clk);
        vif.store             <= req.store;
        vif.ext_addr          <= req.ext_addr;
        vif.spad_addr         <= req.spad_addr;
        vif.length_words      <= req.length_words;
        vif.row_words         <= req.row_words;
        vif.row_count         <= req.row_count;
        vif.ext_stride        <= req.ext_stride;
        vif.spad_stride       <= req.spad_stride;
        vif.gather_enable     <= req.gather_enable;
        vif.gather_index_base <= req.gather_index_base;
        vif.read_outstanding  <= req.read_outstanding;
        vif.start             <= 1'b1;
        @(posedge vif.clk);
        vif.start <= 1'b0;

        timeout = 0;
        active_cycles = 0;
        abort_sent = 0;
        // Error is not terminal for an abort: the RTL must still drain every
        // already accepted AXI response before it raises done.
        while (!vif.done && timeout < 4000) begin
            @(posedge vif.clk);
            timeout++;
            if (vif.busy) active_cycles++;
            if (!abort_sent && req.abort_after_cycles != 0 &&
                active_cycles >= req.abort_after_cycles) begin
                vif.abort <= 1'b1;
                abort_sent = 1'b1;
            end else begin
                vif.abort <= 1'b0;
            end
        end
        vif.abort <= 1'b0;
        if (timeout == 4000)
            `uvm_error("DMA_TIMEOUT", "DMA did not finish within 4000 clocks")
        else if (req.expect_error && (!vif.error || vif.error_code != req.expected_error_code))
            `uvm_error("DMA_EXPECTED_ERROR", $sformatf("expected error=1 code=0x%0h; got error=%0b code=0x%0h",
                       req.expected_error_code, vif.error, vif.error_code))
        else if (!req.expect_error && vif.error)
            `uvm_error("DMA_ERROR", $sformatf("DMA error_code=0x%0h", vif.error_code))
        else if (!req.expect_error && vif.rd_highwater < req.minimum_rd_highwater)
            `uvm_error("DMA_OUTSTANDING", $sformatf("read highwater=%0d, expected at least %0d",
                       vif.rd_highwater, req.minimum_rd_highwater))
        else
            `uvm_info(req.expect_error ? "DMA_ABORT_DONE" : "DMA_DONE",
                      $sformatf("DMA completed in %0d clocks; highwater=%0d error=0x%0h",
                                timeout, vif.rd_highwater, vif.error_code), UVM_LOW)
        drive_idle();
    endtask
endclass
