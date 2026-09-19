class control_axil_driver extends uvm_driver #(control_axil_item);
    `uvm_component_utils(control_axil_driver)
    virtual ai_axil_if vif;
    localparam int unsigned MAX_HANDSHAKE_WAIT = 256;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_axil_if)::get(this, "", "axil_vif", vif))
            `uvm_fatal("NOVIF", "control_axil_driver requires axil_vif")
    endfunction

    task run_phase(uvm_phase phase);
        control_axil_item req;
        forever begin
            seq_item_port.get_next_item(req);
            if (req.is_write) drive_write(req); else drive_read(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_write(control_axil_item req);
        int unsigned cycles;
        bit b_seen;
        wait (vif.aresetn === 1'b1);
        cycles = 0; b_seen = 0;
        vif.bready <= 0;
        fork
            begin
                repeat (req.aw_delay + 1) @(negedge vif.aclk);
                vif.awaddr <= req.addr; vif.awvalid <= 1;
                while (!vif.awready) begin
                    @(negedge vif.aclk); cycles++;
                    if (cycles >= MAX_HANDSHAKE_WAIT)
                        `uvm_fatal("AXIL_TIMEOUT", $sformatf("AW timeout addr=%08h", req.addr))
                end
                @(negedge vif.aclk); vif.awvalid <= 0;
            end
            begin
                repeat (req.w_delay + 1) @(negedge vif.aclk);
                vif.wdata <= req.data; vif.wstrb <= req.strb; vif.wvalid <= 1;
                while (!vif.wready) begin
                    @(negedge vif.aclk); cycles++;
                    if (cycles >= MAX_HANDSHAKE_WAIT)
                        `uvm_fatal("AXIL_TIMEOUT", $sformatf("W timeout addr=%08h", req.addr))
                end
                @(negedge vif.aclk); vif.wvalid <= 0;
            end
            begin
                repeat (req.bready_delay + 1) @(negedge vif.aclk);
                vif.bready <= 1;
                while (!(vif.bvalid && vif.bready)) begin
                    @(negedge vif.aclk); cycles++;
                    if (cycles >= MAX_HANDSHAKE_WAIT)
                        `uvm_fatal("AXIL_TIMEOUT", $sformatf("B timeout addr=%08h aw_delay=%0d w_delay=%0d awvalid/ready=%0b/%0b wvalid/ready=%0b/%0b bvalid/ready=%0b/%0b", req.addr, req.aw_delay, req.w_delay, vif.awvalid, vif.awready, vif.wvalid, vif.wready, vif.bvalid, vif.bready))
                end
                req.resp = vif.bresp; b_seen = 1;
            end
        join
        if (!b_seen) `uvm_fatal("AXIL_TIMEOUT", "write response was not observed")
        req.latency_cycles = cycles;
        @(negedge vif.aclk); vif.bready <= 0;
    endtask

    task drive_read(control_axil_item req);
        int unsigned cycles;
        bit r_seen;
        wait (vif.aresetn === 1'b1);
        cycles = 0; r_seen = 0;
        vif.rready <= 0;
        fork
            begin
                @(negedge vif.aclk);
                vif.araddr <= req.addr; vif.arvalid <= 1;
                while (!vif.arready) begin
                    @(negedge vif.aclk); cycles++;
                    if (cycles >= MAX_HANDSHAKE_WAIT)
                        `uvm_fatal("AXIL_TIMEOUT", $sformatf("AR timeout addr=%08h", req.addr))
                end
                @(negedge vif.aclk); vif.arvalid <= 0;
            end
            begin
                repeat (req.rready_delay + 1) @(negedge vif.aclk);
                vif.rready <= 1;
                while (!(vif.rvalid && vif.rready)) begin
                    @(negedge vif.aclk); cycles++;
                    if (cycles >= MAX_HANDSHAKE_WAIT)
                        `uvm_fatal("AXIL_TIMEOUT", $sformatf("R timeout addr=%08h rready_delay=%0d", req.addr, req.rready_delay))
                end
                req.rdata = vif.rdata; req.resp = vif.rresp; r_seen = 1;
            end
        join
        if (!r_seen) `uvm_fatal("AXIL_TIMEOUT", "read response was not observed")
        req.latency_cycles = cycles;
        @(negedge vif.aclk); vif.rready <= 0;
    endtask
endclass
