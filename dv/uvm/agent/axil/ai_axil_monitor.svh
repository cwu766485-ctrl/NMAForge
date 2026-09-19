class ai_axil_monitor extends uvm_component;
    `uvm_component_utils(ai_axil_monitor)
    virtual ai_axil_if vif; uvm_analysis_port #(ai_axil_item) ap;
    bit [31:0] write_addr, write_data, read_addr; bit [3:0] write_strb; bit got_aw, got_w, got_ar;
    function new(string name, uvm_component parent); super.new(name, parent); ap=new("ap",this); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_axil_if)::get(this,"","axil_vif",vif)) `uvm_fatal("NOVIF","ai_axil_monitor requires axil_vif")
    endfunction
    task run_phase(uvm_phase phase);
        ai_axil_item tr;
        forever begin
            @(posedge vif.aclk);
            if (!vif.aresetn) begin got_aw=0; got_w=0; got_ar=0; end else begin
                if (vif.awvalid&&vif.awready) begin write_addr=vif.awaddr; got_aw=1; end
                if (vif.wvalid&&vif.wready) begin write_data=vif.wdata; write_strb=vif.wstrb; got_w=1; end
                if (vif.bvalid&&vif.bready&&got_aw&&got_w) begin
                    tr=ai_axil_item::type_id::create("axil_write_seen"); tr.is_write=1; tr.addr=write_addr; tr.data=write_data; tr.strb=write_strb; tr.resp=vif.bresp; ap.write(tr); got_aw=0; got_w=0;
                end
                if (vif.arvalid&&vif.arready) begin read_addr=vif.araddr; got_ar=1; end
                if (vif.rvalid&&vif.rready&&got_ar) begin
                    tr=ai_axil_item::type_id::create("axil_read_seen"); tr.is_write=0; tr.addr=read_addr; tr.rdata=vif.rdata; tr.resp=vif.rresp; ap.write(tr); got_ar=0;
                end
            end
        end
    endtask
endclass
