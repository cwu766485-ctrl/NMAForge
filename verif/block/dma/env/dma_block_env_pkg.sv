package dma_block_env_pkg;
    import uvm_pkg::*;
    import dma_block_types_pkg::*;
    import dma_block_agent_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_cmd)
    `uvm_analysis_imp_decl(_spad)
    `uvm_analysis_imp_decl(_axi)
    `include "dma_block_scoreboard.svh"
    `include "dma_block_env.svh"
endpackage
