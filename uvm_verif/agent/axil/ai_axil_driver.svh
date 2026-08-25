class ai_axil_driver extends uvm_driver #(ai_axil_item);
    `uvm_component_utils(ai_axil_driver)
    virtual ai_axil_if vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_axil_if)::get(this, "", "axil_vif", vif)) `uvm_fatal("NOVIF", "ai_axil_driver requires axil_vif")
    endfunction
    task run_phase(uvm_phase phase);
        ai_axil_item req;
        forever begin seq_item_port.get_next_item(req); if (req.is_write) drive_write(req); else drive_read(req); seq_item_port.item_done(); end
    endtask
    task drive_write(ai_axil_item req);
        int unsigned cycles;
        wait (vif.aresetn === 1'b1); vif.bready <= 1'b1;
        @(negedge vif.aclk); vif.awaddr <= req.addr; vif.awvalid <= 1'b1; cycles=0;
        while (!vif.awready) begin @(negedge vif.aclk); cycles++; end
        @(negedge vif.aclk); vif.awvalid<=0; vif.wdata<=req.data; vif.wstrb<=req.strb; vif.wvalid<=1;
        while (!vif.wready) begin @(negedge vif.aclk); cycles++; end
        @(negedge vif.aclk); vif.wvalid<=0;
        while (!vif.bvalid) begin @(negedge vif.aclk); cycles++; end
        req.resp=vif.bresp; req.latency_cycles=cycles; @(negedge vif.aclk); vif.bready<=0;
    endtask
    task drive_read(ai_axil_item req);
        int unsigned cycles;
        wait (vif.aresetn === 1'b1);
        @(negedge vif.aclk); vif.araddr<=req.addr; vif.arvalid<=1; vif.rready<=1; cycles=0;
        while (!vif.arready) begin @(negedge vif.aclk); cycles++; end
        @(negedge vif.aclk); vif.arvalid<=0;
        while (!vif.rvalid) begin @(negedge vif.aclk); cycles++; end
        req.rdata=vif.rdata; req.resp=vif.rresp; req.latency_cycles=cycles; @(negedge vif.aclk); vif.rready<=0;
    endtask
endclass
