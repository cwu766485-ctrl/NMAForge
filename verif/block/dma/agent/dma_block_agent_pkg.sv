package dma_block_agent_pkg;
    import uvm_pkg::*;
    import dma_block_types_pkg::*;
    `include "uvm_macros.svh"

    `include "dma_cmd_sequencer.svh"
    `include "dma_cmd_driver.svh"
    `include "dma_axi_read_responder.svh"
    `include "dma_spad_model.svh"
    `include "dma_axi_monitor.svh"
    `include "dma_spad_monitor.svh"
endpackage
