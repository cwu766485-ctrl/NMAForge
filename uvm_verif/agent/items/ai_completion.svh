class ai_completion extends uvm_sequence_item;
    bit [15:0] task_id; bit [3:0] status, error_code; bit [31:0] result, element_count;
    `uvm_object_utils_begin(ai_completion)
        `uvm_field_int(task_id, UVM_DEFAULT) `uvm_field_int(status, UVM_DEFAULT)
        `uvm_field_int(error_code, UVM_DEFAULT) `uvm_field_int(result, UVM_DEFAULT)
        `uvm_field_int(element_count, UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name = "ai_completion"); super.new(name); endfunction
endclass
