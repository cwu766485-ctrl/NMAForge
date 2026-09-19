class control_axil_sequencer extends uvm_sequencer #(control_axil_item);
    `uvm_component_utils(control_axil_sequencer)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
