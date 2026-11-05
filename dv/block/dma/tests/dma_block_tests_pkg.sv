package dma_block_tests_pkg;
    import uvm_pkg::*;
    import dma_block_types_pkg::*;
    import dma_block_agent_pkg::*;
    import dma_block_env_pkg::*;
`ifdef DMA_PROTOCOL_VIP
    import tvip_common_pkg::*;
    import tvip_axi_types_pkg::*;
    import tvip_axi_pkg::*;
`endif
    `include "uvm_macros.svh"

    `include "dma_block_base_test.svh"
    `include "dma_load_ooo_smoke_test.svh"
    `include "dma_functional_tests.svh"
`ifdef DMA_PROTOCOL_VIP
    `include "dma_axi_vip_integration_test.svh"
`endif
endpackage
