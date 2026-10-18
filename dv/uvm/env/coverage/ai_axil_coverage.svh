class ai_axil_coverage extends uvm_subscriber #(ai_axil_item);
    `uvm_component_utils(ai_axil_coverage)
    covergroup cg with function sample(bit is_write,bit [31:0] address,bit [1:0] response);
        cp_direction:coverpoint is_write; cp_region:coverpoint address[19:16] {bins regs={0};bins spad={[1:8]};bins other=default;}
        cp_response:coverpoint response {
            bins okay = {2'b00};
            bins slverr = {2'b10};
            // DECERR is legal AXI, but this DUT-facing boundary has no
            // interconnect decoder; unmapped peripheral accesses return SLVERR.
            ignore_bins decerr = {2'b11};
            illegal_bins exokay = {2'b01};
        }
        direction_x_region:cross cp_direction,cp_region;
    endgroup
    function new(string name,uvm_component parent); super.new(name,parent); cg=new(); endfunction
    function void write(ai_axil_item t); cg.sample(t.is_write,t.addr,t.resp); endfunction
endclass
