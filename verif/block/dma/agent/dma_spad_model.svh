class dma_spad_model extends uvm_component;
    virtual ai_dma_spad_if vif;
    dma_block_cfg cfg;
    uvm_analysis_port #(dma_spad_write_item) write_ap;
    bit [31:0] mem [int unsigned];
    int unsigned cycle_count;
    `uvm_component_utils(dma_spad_model)

    function new(string name = "dma_spad_model", uvm_component parent = null);
        super.new(name, parent);
        write_ap = new("write_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_dma_spad_if)::get(this, "", "spad_vif", vif))
            `uvm_fatal("NOVIF", "dma_spad_model needs spad_vif")
        if (!uvm_config_db#(dma_block_cfg)::get(this, "", "cfg", cfg))
            cfg = dma_block_cfg::type_id::create("cfg");
    endfunction

    function automatic bit [31:0] read_word(bit [31:0] addr);
        int unsigned key;
        key = addr >> 2;
        if (mem.exists(key)) return mem[key];
        return 32'd0;
    endfunction

    // Tests call these before issuing a store or gather command.  They model
    // software/DMA-produced scratchpad contents without peeking into the DUT.
    function void preload_word(bit [31:0] addr, bit [31:0] data);
        mem[addr >> 2] = data;
    endfunction

    function void preload_source_pattern(bit [31:0] base, int unsigned words);
        int unsigned index;
        for (index = 0; index < words; index++)
            preload_word(base + index * 4, dma_spad_source_word(base + index * 4));
    endfunction

    function automatic bit ready_now(int unsigned salt);
        if (!cfg.enable_backpressure) return 1'b1;
        return ((cycle_count + salt) % 4) != 0;
    endfunction

    task record_word(bit [31:0] addr, bit [31:0] data);
        dma_spad_write_item item;
        mem[addr >> 2] = data;
        item = dma_spad_write_item::type_id::create("spad_write");
        item.addr = addr;
        item.data = data;
        write_ap.write(item);
    endtask

    task run_phase(uvm_phase phase);
        int lane;
        bit [31:0] lane_addr;
        vif.spad_ready          <= 1'b0;
        vif.line_ready          <= 1'b0;
        vif.spad_rsp_valid      <= 1'b0;
        vif.spad_rdata          <= '0;
        vif.spad_req_error      <= 1'b0;
        vif.spad_rsp_error      <= 1'b0;
        vif.line_rsp_valid      <= 1'b0;
        vif.line_rdata          <= '0;
        vif.line_req_error      <= 1'b0;
        vif.line_rsp_error      <= 1'b0;
        vif.line_parity_error   <= '0;
        forever begin
            @(posedge vif.clk);
            vif.spad_rsp_valid <= 1'b0;
            vif.line_rsp_valid <= 1'b0;
            if (!vif.resetn) begin
                mem.delete();
                cycle_count = 0;
                vif.spad_ready <= 1'b0;
                vif.line_ready <= 1'b0;
            end else begin
                cycle_count++;
                vif.spad_ready <= ready_now(0);
                vif.line_ready <= ready_now(1);
                if (vif.spad_valid && vif.spad_ready) begin
                    if (vif.spad_write)
                        record_word(vif.spad_addr, vif.spad_wdata);
                    else begin
                        vif.spad_rdata <= read_word(vif.spad_addr);
                        vif.spad_rsp_valid <= 1'b1;
                    end
                end
                if (vif.line_valid && vif.line_ready) begin
                    if (vif.line_write) begin
                        for (lane = 0; lane < 4; lane++) begin
                            lane_addr = vif.line_addr + (lane * 4);
                            if (vif.line_wstrb[lane*4 +: 4] != 4'b0)
                                record_word(lane_addr, vif.line_wdata[lane*32 +: 32]);
                        end
                    end else begin
                        vif.line_rdata <= {read_word(vif.line_addr + 12), read_word(vif.line_addr + 8),
                                           read_word(vif.line_addr + 4), read_word(vif.line_addr)};
                        vif.line_rsp_valid <= 1'b1;
                    end
                end
            end
        end
    endtask
endclass
