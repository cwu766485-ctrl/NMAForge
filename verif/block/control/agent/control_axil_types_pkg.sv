package control_axil_types_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam bit [31:0] CTRL       = 32'h0000_0000;
    localparam bit [31:0] STATUS     = 32'h0000_0004;
    localparam bit [31:0] OP         = 32'h0000_0008;
    localparam bit [31:0] SRC0       = 32'h0000_000c;
    localparam bit [31:0] SRC1       = 32'h0000_0010;
    localparam bit [31:0] DST        = 32'h0000_0014;
    localparam bit [31:0] QUANT      = 32'h0000_0028;
    localparam bit [31:0] RESULT     = 32'h0000_002c;
    localparam bit [31:0] ERROR      = 32'h0000_0030;
    localparam bit [31:0] IRQ_STATUS = 32'h0000_003c;
    localparam bit [31:0] IRQ_ENABLE = 32'h0000_0040;
    localparam bit [31:0] VERSION    = 32'h0000_0044;
    localparam bit [31:0] CAP        = 32'h0000_0048;
    localparam bit [31:0] CMD_BASE   = 32'h0000_0080;
    localparam bit [31:0] CMD_SIZE   = 32'h0000_0088;
    localparam bit [31:0] CMD_TAIL   = 32'h0000_00c8;
    localparam bit [31:0] DOORBELL   = 32'h0000_00a0;
    localparam bit [31:0] ABORT      = 32'h0000_00a4;
    localparam bit [31:0] DMA_CTRL   = 32'h0000_00b0;
    localparam bit [31:0] DMA_CFG    = 32'h0000_016c;
    localparam bit [31:0] ABI_INFO   = 32'h0000_01a0;
    localparam bit [31:0] CAP2       = 32'h0000_01a8;

    class control_axil_item extends uvm_sequence_item;
        rand bit is_write;
        rand bit [31:0] addr;
        rand bit [31:0] data;
        rand bit [3:0] strb;
        rand int unsigned aw_delay;
        rand int unsigned w_delay;
        rand int unsigned bready_delay;
        rand int unsigned rready_delay;
        bit [31:0] rdata;
        bit [1:0] resp;
        int unsigned latency_cycles;

        constraint c_delay { aw_delay inside {[0:3]}; w_delay inside {[0:3]};
                             bready_delay inside {[0:3]}; rready_delay inside {[0:3]}; }
        `uvm_object_utils_begin(control_axil_item)
            `uvm_field_int(is_write, UVM_DEFAULT)
            `uvm_field_int(addr, UVM_DEFAULT)
            `uvm_field_int(data, UVM_DEFAULT)
            `uvm_field_int(strb, UVM_DEFAULT)
            `uvm_field_int(aw_delay, UVM_DEFAULT)
            `uvm_field_int(w_delay, UVM_DEFAULT)
            `uvm_field_int(bready_delay, UVM_DEFAULT)
            `uvm_field_int(rready_delay, UVM_DEFAULT)
            `uvm_field_int(rdata, UVM_DEFAULT)
            `uvm_field_int(resp, UVM_DEFAULT)
            `uvm_field_int(latency_cycles, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name = "control_axil_item"); super.new(name); endfunction
    endclass
endpackage
