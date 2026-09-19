package ai_accel_uvm_types_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam bit [31:0] CIMFORGE_REG_STATUS  = 32'h0000_0004;
    localparam bit [31:0] CIMFORGE_REG_VERSION = 32'h0000_0044;
    // The constant is intentionally checked by the first UVM sequence: a
    // version mismatch is an ABI failure, not a cosmetic metadata change.
    localparam bit [31:0] CIMFORGE_VERSION_A8  = 32'h1000_0008;
    localparam bit [31:0] CIMFORGE_SPAD_BASE   = 32'h0001_0000;

    typedef enum int { AXI_AR, AXI_R, AXI_AW, AXI_W, AXI_B } ai_axi_event_e;

    // Keep a single package namespace, but one transaction class per source
    // file.  This is the scalable UVM convention: packages define ownership
    // and compilation order; included files define one reusable class each.
    `include "items/ai_descriptor.svh"
    `include "items/ai_completion.svh"
    `include "items/ai_axil_item.svh"
    `include "items/ai_axi4_observed_item.svh"
endpackage
