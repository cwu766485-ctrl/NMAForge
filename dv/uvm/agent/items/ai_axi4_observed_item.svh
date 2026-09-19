class ai_axi4_observed_item extends uvm_sequence_item;
    ai_axi_event_e kind; bit [3:0] id; bit [63:0] addr; bit [7:0] len;
    bit [2:0] size; bit [1:0] burst, resp; bit [127:0] data; bit [15:0] strb; bit last;
    `uvm_object_utils_begin(ai_axi4_observed_item)
        `uvm_field_enum(ai_axi_event_e, kind, UVM_DEFAULT) `uvm_field_int(id, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT) `uvm_field_int(len, UVM_DEFAULT)
        `uvm_field_int(size, UVM_DEFAULT) `uvm_field_int(burst, UVM_DEFAULT)
        `uvm_field_int(data, UVM_DEFAULT) `uvm_field_int(strb, UVM_DEFAULT)
        `uvm_field_int(last, UVM_DEFAULT) `uvm_field_int(resp, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "ai_axi4_observed_item"); super.new(name); endfunction
endclass
