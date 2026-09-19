class ai_axil_sequencer extends uvm_sequencer #(ai_axil_item);
    `uvm_component_utils(ai_axil_sequencer)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
