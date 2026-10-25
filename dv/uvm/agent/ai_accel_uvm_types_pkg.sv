package ai_accel_uvm_types_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam bit [31:0] CIMFORGE_REG_STATUS  = 32'h0000_0004;
    localparam bit [31:0] CIMFORGE_REG_IRQ_STATUS = 32'h0000_003c;
    localparam bit [31:0] CIMFORGE_REG_IRQ_ENABLE = 32'h0000_0040;
    localparam bit [31:0] CIMFORGE_REG_VERSION = 32'h0000_0044;
    // The current product RTL is A10 / ABI v7.4. A version mismatch is an
    // ABI failure, not a cosmetic metadata change.
    localparam bit [31:0] CIMFORGE_VERSION_A10 = 32'h1000_000a;
    localparam bit [31:0] CIMFORGE_SPAD_BASE   = 32'h0001_0000;

    // Queue and DMA register ABI used by the top-level UVM sequences.
    localparam bit [31:0] CIMFORGE_REG_CMDQ_BASE_LO = 32'h0000_0080;
    localparam bit [31:0] CIMFORGE_REG_CMDQ_SIZE    = 32'h0000_0088;
    localparam bit [31:0] CIMFORGE_REG_CMDQ_HEAD    = 32'h0000_008c;
    localparam bit [31:0] CIMFORGE_REG_CPLQ_BASE_LO = 32'h0000_0090;
    localparam bit [31:0] CIMFORGE_REG_CPLQ_SIZE    = 32'h0000_0098;
    localparam bit [31:0] CIMFORGE_REG_CPLQ_TAIL    = 32'h0000_009c;
    localparam bit [31:0] CIMFORGE_REG_DOORBELL     = 32'h0000_00a0;
    localparam bit [31:0] CIMFORGE_REG_ABORT        = 32'h0000_00a4;
    localparam bit [31:0] CIMFORGE_REG_WATCHDOG     = 32'h0000_00a8;
    localparam bit [31:0] CIMFORGE_REG_CMDQ_TAIL    = 32'h0000_00c8;
    localparam bit [31:0] CIMFORGE_REG_CPLQ_HEAD    = 32'h0000_00cc;
    localparam bit [31:0] CIMFORGE_REG_DMA_CTRL     = 32'h0000_00b0;
    localparam bit [31:0] CIMFORGE_REG_DMA_STATUS   = 32'h0000_00b4;
    localparam bit [31:0] CIMFORGE_REG_DMA_EXT_ADDR = 32'h0000_00b8;
    localparam bit [31:0] CIMFORGE_REG_DMA_SPAD_ADDR= 32'h0000_00bc;
    localparam bit [31:0] CIMFORGE_REG_DMA_LENGTH   = 32'h0000_00c0;

    // Dedicated V4 E2E lane check: 32-bit AXI transfers at non-128-bit-aligned
    // addresses, while keeping the external address 32-bit aligned.
    localparam bit [31:0] MIXED_E2E_NARROW_DDR_READ_ADDR  = 32'h0000_1ae4;
    localparam bit [31:0] MIXED_E2E_NARROW_DDR_WRITE_ADDR = 32'h0000_1afc;
    localparam bit [31:0] MIXED_E2E_NARROW_SPAD_ADDR      = 32'h0000_7c00;
    localparam bit [31:0] MIXED_E2E_NARROW_DATA           = 32'h1357_9bdf;

    typedef enum int { AXI_AR, AXI_R, AXI_AW, AXI_W, AXI_B } ai_axi_event_e;

    // Keep a single package namespace, but one transaction class per source
    // file.  This is the scalable UVM convention: packages define ownership
    // and compilation order; included files define one reusable class each.
    `include "items/ai_mixed_precision_vector_plan.svh"
    `include "items/ai_descriptor.svh"
    `include "items/ai_completion.svh"
    `include "items/ai_axil_item.svh"
    `include "items/ai_axi4_observed_item.svh"
    `include "items/ai_compute_cluster_obs.svh"
endpackage
