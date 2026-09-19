// Passive scratchpad monitor. It observes both DMA write interfaces after the
// model has supplied ready, then publishes a normalized stream of 32-bit words.
class dma_spad_monitor extends uvm_component;
    virtual ai_dma_spad_if vif;
    uvm_analysis_port #(dma_spad_write_item) write_ap;
    `uvm_component_utils(dma_spad_monitor)

    function new(string name = "dma_spad_monitor", uvm_component parent = null);
        super.new(name, parent);
        write_ap = new("write_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_dma_spad_if)::get(this, "", "spad_vif", vif))
            `uvm_fatal("NOVIF", "dma_spad_monitor needs spad_vif")
    endfunction

    task publish_word(bit [31:0] addr, bit [31:0] data);
        dma_spad_write_item item = dma_spad_write_item::type_id::create("observed_spad_write");
        item.addr = addr; item.data = data;
        write_ap.write(item);
    endtask

    task run_phase(uvm_phase phase);
        int lane;
        forever begin
            @(posedge vif.clk);
            if (vif.resetn) begin
                if (vif.spad_valid && vif.spad_ready && vif.spad_write)
                    publish_word(vif.spad_addr, vif.spad_wdata);
                if (vif.line_valid && vif.line_ready && vif.line_write)
                    for (lane = 0; lane < 4; lane++)
                        if (vif.line_wstrb[lane*4 +: 4] != 0)
                            publish_word(vif.line_addr + lane * 4, vif.line_wdata[lane*32 +: 32]);
            end
        end
    endtask
endclass
