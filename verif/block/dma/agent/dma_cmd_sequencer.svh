class dma_cmd_sequencer extends uvm_sequencer #(dma_cmd_item);
    `uvm_component_utils(dma_cmd_sequencer)
    function new(string name = "dma_cmd_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
