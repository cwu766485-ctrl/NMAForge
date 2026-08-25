class dma_read_burst extends uvm_object;
    bit [3:0]  id;
    bit [63:0] addr;
    bit [7:0]  len;
    bit [2:0]  size;
    int unsigned beat_index;
    `uvm_object_utils(dma_read_burst)
    function new(string name = "dma_read_burst"); super.new(name); endfunction
endclass

class dma_write_burst extends uvm_object;
    bit [3:0]  id;
    bit [63:0] addr;
    bit [7:0]  len;
    bit [2:0]  size;
    int unsigned beat_index;
    `uvm_object_utils(dma_write_burst)
    function new(string name = "dma_write_burst"); super.new(name); endfunction
endclass

// AXI4 slave BFM.  It deliberately decouples AR/R and AW/W/B.  Both response
// channels can be held, delayed, and returned newest-first, making protocol
// pressure a property of the UVM test rather than a coincidence of a direct TB.
class dma_axi_read_responder extends uvm_component;
    virtual ai_dma_axi_if vif;
    dma_block_cfg cfg;
    uvm_analysis_port #(dma_axi_write_item) write_ap;
    dma_read_burst pending_reads[$];
    dma_read_burst active_read;
    dma_write_burst active_write;
    dma_write_burst pending_b[$];
    dma_write_burst active_b;
    int unsigned accepted_ids[$];
    int unsigned completed_ids[$];
    int unsigned accepted_bids[$];
    int unsigned completed_bids[$];
    int unsigned cycle_count;
    int unsigned read_delay_count;
    int unsigned write_delay_count;
    bit read_window_primed;
    bit write_window_primed;
    `uvm_component_utils(dma_axi_read_responder)

    function new(string name = "dma_axi_read_responder", uvm_component parent = null);
        super.new(name, parent);
        write_ap = new("write_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_dma_axi_if)::get(this, "", "axi_vif", vif))
            `uvm_fatal("NOVIF", "dma_axi_read_responder needs axi_vif")
        if (!uvm_config_db#(dma_block_cfg)::get(this, "", "cfg", cfg))
            cfg = dma_block_cfg::type_id::create("cfg");
    endfunction

    function automatic bit allow_ready(int unsigned salt);
        if (!cfg.enable_backpressure) return 1'b1;
        // Deterministic, reproducible stalls; never leave a channel blocked
        // for more than one of every four cycles.
        return ((cycle_count + salt) % 4) != 0;
    endfunction

    function automatic bit [127:0] make_rdata(dma_read_burst burst);
        bit [63:0] beat_addr;
        beat_addr = burst.addr + (burst.beat_index << burst.size);
        if (burst.size == 3'd4)
            return {dma_memory_word(beat_addr + 64'd12), dma_memory_word(beat_addr + 64'd8),
                    dma_memory_word(beat_addr + 64'd4),  dma_memory_word(beat_addr)};
        // AXI narrow reads retain the natural 128-bit bus lane.  The DUT
        // records ARADDR[3:2] and selects this exact lane while draining.
        case (beat_addr[3:2])
            2'd0: return {96'd0, dma_memory_word(beat_addr)};
            2'd1: return {64'd0, dma_memory_word(beat_addr), 32'd0};
            2'd2: return {32'd0, dma_memory_word(beat_addr), 64'd0};
            default: return {dma_memory_word(beat_addr), 96'd0};
        endcase
    endfunction

    task drive_active_read();
        vif.rid    <= active_read.id;
        vif.rdata  <= make_rdata(active_read);
        vif.rresp  <= 2'b00;
        vif.rlast  <= (active_read.beat_index == active_read.len);
        vif.rvalid <= 1'b1;
    endtask

    task report_write_words(dma_write_burst burst, bit [127:0] data,
                            bit [15:0] strb);
        int lane;
        dma_axi_write_item item;
        bit [63:0] aligned_addr;
        aligned_addr = {burst.addr[63:4], 4'b0} + (burst.beat_index << burst.size);
        for (lane = 0; lane < 4; lane++) begin
            if (strb[lane*4 +: 4] != 4'b0) begin
                item = dma_axi_write_item::type_id::create($sformatf("axi_word_%0d", lane));
                item.addr = aligned_addr + (lane * 4);
                item.data = data[lane*32 +: 32];
                write_ap.write(item);
            end
        end
    endtask

    function void check_out_of_order();
        if (accepted_ids.size() < cfg.min_accepted_reads_before_response || completed_ids.size() == 0)
            `uvm_error("AXI_OOO", "response window did not reach its configured outstanding depth")
        else if (completed_ids[0] == accepted_ids[0])
            `uvm_error("AXI_OOO", "first completed burst was FIFO; expected an out-of-order return")
        else
            `uvm_info("AXI_OOO", $sformatf("accepted first ID=%0d, completed first ID=%0d",
                      accepted_ids[0], completed_ids[0]), UVM_LOW)
    endfunction

    function void check_write_out_of_order();
        if (accepted_bids.size() < cfg.min_accepted_writes_before_response || completed_bids.size() == 0)
            `uvm_error("AXI_BOOO", "write response window did not reach its configured depth")
        else if (completed_bids[0] == accepted_bids[0])
            `uvm_error("AXI_BOOO", "first BID completion was FIFO; expected newest-first")
        else
            `uvm_info("AXI_BOOO", $sformatf("accepted first BID=%0d, completed first BID=%0d",
                      accepted_bids[0], completed_bids[0]), UVM_LOW)
    endfunction

    task reset_bfm();
        pending_reads.delete(); pending_b.delete();
        active_read = null; active_write = null; active_b = null;
        accepted_ids.delete(); completed_ids.delete();
        accepted_bids.delete(); completed_bids.delete();
        read_window_primed = 0; write_window_primed = 0;
        cycle_count = 0; read_delay_count = 0; write_delay_count = 0;
        vif.arready <= 0; vif.rvalid <= 0; vif.rlast <= 0;
        vif.rid <= '0; vif.rdata <= '0; vif.rresp <= 0;
        vif.awready <= 0; vif.wready <= 0; vif.bvalid <= 0;
        vif.bid <= '0; vif.bresp <= 0;
    endtask

    task run_phase(uvm_phase phase);
        dma_read_burst rd;
        dma_write_burst wr;
        reset_bfm();
        forever begin
            @(posedge vif.clk);
            if (!vif.resetn) begin
                reset_bfm();
            end else begin
                cycle_count++;
                vif.arready <= allow_ready(0);
                vif.awready <= allow_ready(1);
                vif.wready  <= allow_ready(2);

                if (vif.arvalid && vif.arready) begin
                    rd = dma_read_burst::type_id::create("accepted_ar");
                    rd.id = vif.arid; rd.addr = vif.araddr; rd.len = vif.arlen;
                    rd.size = vif.arsize; rd.beat_index = 0;
                    pending_reads.push_back(rd); accepted_ids.push_back(rd.id);
                    `uvm_info("AXI_AR", $sformatf("AR id=%0d addr=0x%0h beats=%0d size=%0d",
                              rd.id, rd.addr, rd.len + 1, rd.size), UVM_MEDIUM)
                end
                if (vif.awvalid && vif.awready) begin
                    if (active_write != null)
                        `uvm_error("AXI_AW", "accepted a second AW before collecting the first W burst")
                    wr = dma_write_burst::type_id::create("accepted_aw");
                    wr.id = vif.awid; wr.addr = vif.awaddr; wr.len = vif.awlen;
                    wr.size = vif.awsize; wr.beat_index = 0;
                    active_write = wr;
                    `uvm_info("AXI_AW", $sformatf("AW id=%0d addr=0x%0h beats=%0d size=%0d",
                              wr.id, wr.addr, wr.len + 1, wr.size), UVM_MEDIUM)
                end
                if (vif.wvalid && vif.wready) begin
                    if (active_write == null) begin
                        `uvm_error("AXI_W", "W observed without an accepted AW")
                    end else begin
                        report_write_words(active_write, vif.wdata, vif.wstrb);
                        if (vif.wlast != (active_write.beat_index == active_write.len))
                            `uvm_error("AXI_WLAST", "WLAST does not match accepted AWLEN")
                        if (vif.wlast) begin
                            pending_b.push_back(active_write);
                            accepted_bids.push_back(active_write.id);
                            active_write = null;
                        end else begin
                            active_write.beat_index++;
                        end
                    end
                end

                if (vif.rvalid && vif.rready) begin
                    if (vif.rlast) begin
                        completed_ids.push_back(active_read.id);
                        vif.rvalid <= 0; vif.rlast <= 0; active_read = null;
                    end else begin
                        active_read.beat_index++;
                        drive_active_read();
                    end
                end
                if (vif.bvalid && vif.bready) begin
                    completed_bids.push_back(active_b.id);
                    vif.bvalid <= 0; active_b = null;
                end

                if (!vif.rvalid && active_read == null && pending_reads.size() != 0 &&
                    (read_window_primed || pending_reads.size() >= cfg.min_accepted_reads_before_response)) begin
                    if (read_delay_count < cfg.read_response_delay_cycles)
                        read_delay_count++;
                    else begin
                        read_window_primed = 1;
                        read_delay_count = 0;
                        active_read = cfg.ooo_read_responses ? pending_reads.pop_back() : pending_reads.pop_front();
                        drive_active_read();
                    end
                end
                if (!vif.bvalid && active_b == null && pending_b.size() != 0 &&
                    (write_window_primed || pending_b.size() >= cfg.min_accepted_writes_before_response)) begin
                    if (write_delay_count < cfg.write_response_delay_cycles)
                        write_delay_count++;
                    else begin
                        write_window_primed = 1;
                        write_delay_count = 0;
                        active_b = cfg.ooo_write_responses ? pending_b.pop_back() : pending_b.pop_front();
                        vif.bid <= active_b.id; vif.bresp <= 2'b00; vif.bvalid <= 1'b1;
                    end
                end
            end
        end
    endtask
endclass
