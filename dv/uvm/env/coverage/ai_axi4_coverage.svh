class ai_axi4_coverage extends uvm_subscriber #(ai_axi4_observed_item);
    `uvm_component_utils(ai_axi4_coverage)
    covergroup cg with function sample(
        ai_axi_event_e kind,
        bit [3:0] id,
        bit [2:0] size,
        bit [7:0] len
    );
        // Keep this typed as the five-value protocol-event enum. Converting it
        // to int creates a 32-bit coverpoint with many meaningless auto bins.
        cp_kind: coverpoint kind {
            bins read_address  = {AXI_AR};
            bins read_data     = {AXI_R};
            bins write_address = {AXI_AW};
            bins write_data    = {AXI_W};
            bins write_response= {AXI_B};
        }

        cp_id: coverpoint id {
            bins desc      = {0};
            bins dma       = {[1:4]};
            bins write_rsp = {[8:11]};
            bins other     = default;
        }

        // AxSIZE/AxLEN are meaningful only on address-channel events. The
        // passive monitor leaves these fields at zero on R/W/B observations.
        cp_address_kind: coverpoint kind
            iff ((kind == AXI_AR) || (kind == AXI_AW)) {
            bins read_address  = {AXI_AR};
            bins write_address = {AXI_AW};
        }

        cp_size: coverpoint size
            iff ((kind == AXI_AR) || (kind == AXI_AW)) {
            bins narrow32 = {3'd2};
            bins wide128  = {3'd4};
            illegal_bins unsupported = default;
        }

        cp_len: coverpoint len
            iff ((kind == AXI_AR) || (kind == AXI_AW)) {
            bins single = {8'd0};
            bins burst  = {[8'd1:8'd15]};
            illegal_bins exceeds_16_beats = {[8'd16:8'd255]};
        }

        kind_x_size: cross cp_address_kind, cp_size;
    endgroup
    function new(string name,uvm_component parent); super.new(name,parent); cg=new(); endfunction
    function void write(ai_axi4_observed_item t); cg.sample(t.kind,t.id,t.size,t.len); endfunction
endclass
