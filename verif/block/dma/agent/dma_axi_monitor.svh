// Passive bus monitor: separate from the active memory BFM so the scoreboard
// observes what the DUT actually put on the AXI pins.
class dma_axi_monitor extends uvm_component;
    virtual ai_dma_axi_if vif;
    uvm_analysis_port #(dma_axi_write_item) write_ap;
    dma_write_burst active_write;
    `uvm_component_utils(dma_axi_monitor)

    function new(string name = "dma_axi_monitor", uvm_component parent = null);
        super.new(name, parent);
        write_ap = new("write_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_dma_axi_if)::get(this, "", "axi_vif", vif))
            `uvm_fatal("NOVIF", "dma_axi_monitor needs axi_vif")
    endfunction

    task publish_words(dma_write_burst burst, bit [127:0] data, bit [15:0] strb);
        int lane;
        bit [63:0] aligned_addr;
        dma_axi_write_item item;
        aligned_addr = {burst.addr[63:4], 4'b0} + (burst.beat_index << burst.size);
        for (lane = 0; lane < 4; lane++) begin
            if (strb[lane*4 +: 4] != 0) begin
                item = dma_axi_write_item::type_id::create("observed_axi_write");
                item.addr = aligned_addr + lane * 4;
                item.data = data[lane*32 +: 32];
                write_ap.write(item);
            end
        end
    endtask

    task run_phase(uvm_phase phase);
        dma_write_burst accepted;
        forever begin
            @(posedge vif.clk);
            if (!vif.resetn) begin
                active_write = null;
            end else begin
                if (vif.awvalid && vif.awready) begin
                    if (active_write != null)
                        `uvm_error("MON_AW", "overlapping AW observed in single DMA write stream")
                    accepted = dma_write_burst::type_id::create("observed_aw");
                    accepted.id = vif.awid; accepted.addr = vif.awaddr;
                    accepted.len = vif.awlen; accepted.size = vif.awsize; accepted.beat_index = 0;
                    active_write = accepted;
                end
                if (vif.wvalid && vif.wready) begin
                    if (active_write == null)
                        `uvm_error("MON_W", "W observed before AW")
                    else begin
                        publish_words(active_write, vif.wdata, vif.wstrb);
                        if (vif.wlast) active_write = null;
                        else active_write.beat_index++;
                    end
                end
            end
        end
    endtask
endclass
