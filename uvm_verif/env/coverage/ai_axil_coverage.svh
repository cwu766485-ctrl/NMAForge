class ai_axil_coverage extends uvm_subscriber #(ai_axil_item);
    `uvm_component_utils(ai_axil_coverage)
    covergroup cg with function sample(bit is_write,bit [31:0] address,bit [1:0] response);
        cp_direction:coverpoint is_write; cp_region:coverpoint address[19:16] {bins regs={0};bins spad={[1:8]};bins other=default;} cp_response:coverpoint response; direction_x_region:cross cp_direction,cp_region;
    endgroup
    function new(string name,uvm_component parent); super.new(name,parent); cg=new(); endfunction
    function void write(ai_axil_item t); cg.sample(t.is_write,t.addr,t.resp); endfunction
endclass
