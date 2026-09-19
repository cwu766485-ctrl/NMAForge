class ai_axil_item extends uvm_sequence_item;
    rand bit is_write; rand bit [31:0] addr, data; rand bit [3:0] strb;
    bit [31:0] rdata; bit [1:0] resp; int unsigned latency_cycles;
    constraint c_aligned { addr[1:0] == 2'b00; }
    `uvm_object_utils_begin(ai_axil_item)
        `uvm_field_int(is_write, UVM_DEFAULT) `uvm_field_int(addr, UVM_DEFAULT)
        `uvm_field_int(data, UVM_DEFAULT) `uvm_field_int(strb, UVM_DEFAULT)
        `uvm_field_int(rdata, UVM_DEFAULT) `uvm_field_int(resp, UVM_DEFAULT)
        `uvm_field_int(latency_cycles, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "ai_axil_item"); super.new(name); endfunction
endclass
