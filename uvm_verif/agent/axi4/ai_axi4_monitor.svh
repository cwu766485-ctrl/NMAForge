class ai_axi4_monitor extends uvm_component;
    `uvm_component_utils(ai_axi4_monitor)
    virtual ai_axi4_if vif; uvm_analysis_port #(ai_axi4_observed_item) ap;
    function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_axi4_if)::get(this,"","axi4_vif",vif)) `uvm_fatal("NOVIF","ai_axi4_monitor requires axi4_vif")
    endfunction
    task run_phase(uvm_phase phase);
        ai_axi4_observed_item tr;
        forever begin
            @(posedge vif.aclk);
            if (vif.aresetn) begin
                if(vif.arvalid&&vif.arready) begin tr=ai_axi4_observed_item::type_id::create("axi_ar_seen"); tr.kind=AXI_AR; tr.id=vif.arid; tr.addr=vif.araddr; tr.len=vif.arlen; tr.size=vif.arsize; tr.burst=vif.arburst; ap.write(tr); end
                if(vif.rvalid&&vif.rready) begin tr=ai_axi4_observed_item::type_id::create("axi_r_seen"); tr.kind=AXI_R; tr.id=vif.rid; tr.data=vif.rdata; tr.last=vif.rlast; tr.resp=vif.rresp; ap.write(tr); end
                if(vif.awvalid&&vif.awready) begin tr=ai_axi4_observed_item::type_id::create("axi_aw_seen"); tr.kind=AXI_AW; tr.id=vif.awid; tr.addr=vif.awaddr; tr.len=vif.awlen; tr.size=vif.awsize; tr.burst=vif.awburst; ap.write(tr); end
                if(vif.wvalid&&vif.wready) begin tr=ai_axi4_observed_item::type_id::create("axi_w_seen"); tr.kind=AXI_W; tr.data=vif.wdata; tr.strb=vif.wstrb; tr.last=vif.wlast; ap.write(tr); end
                if(vif.bvalid&&vif.bready) begin tr=ai_axi4_observed_item::type_id::create("axi_b_seen"); tr.kind=AXI_B; tr.id=vif.bid; tr.resp=vif.bresp; ap.write(tr); end
            end
        end
    endtask
endclass
