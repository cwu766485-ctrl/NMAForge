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

    // Full software-visible map used by the register-file address sweep.
    localparam bit [31:0] LENGTH=32'h018, M=32'h01c, N=32'h020, K=32'h024;
    localparam bit [31:0] CYCLES=32'h034, ELEMENTS=32'h038;
    localparam bit [31:0] CMD_HI=32'h084, CMD_HEAD=32'h08c;
    localparam bit [31:0] CPL_BASE=32'h090, CPL_HI=32'h094, CPL_SIZE=32'h098, CPL_TAIL=32'h09c;
    localparam bit [31:0] WATCHDOG=32'h0a8, CMD_CTRL=32'h0ac;
    localparam bit [31:0] DMA_STATUS=32'h0b4, DMA_EXT=32'h0b8, DMA_SPAD=32'h0bc;
    localparam bit [31:0] DMA_LEN=32'h0c0, DMA_ERROR=32'h0c4;
    localparam bit [31:0] CPL_HEAD=32'h0cc, QUEUE_STATUS=32'h0d0;
    localparam bit [31:0] R0_BASE=32'h0d4, R0_LIMIT=32'h0d8, R0_PERM=32'h0dc;
    localparam bit [31:0] R1_BASE=32'h0e0, R1_LIMIT=32'h0e4, R1_PERM=32'h0e8;
    localparam bit [31:0] R2_BASE=32'h0ec, R2_LIMIT=32'h0f0, R2_PERM=32'h0f4;
    localparam bit [31:0] R3_BASE=32'h0f8, R3_LIMIT=32'h0fc, R3_PERM=32'h100;
    localparam bit [31:0] DMA_ROW_WORDS=32'h104, DMA_ROW_COUNT=32'h108;
    localparam bit [31:0] DMA_EXT_STRIDE=32'h10c, DMA_SPAD_STRIDE=32'h110;
    localparam bit [31:0] BIAS_BASE=32'h114, POST_CTRL=32'h118;
    localparam bit [31:0] TILE_CTRL=32'h120, TILE_COUNT=32'h124;
    localparam bit [31:0] TILE_EXT_IN=32'h128, TILE_EXT_OUT=32'h12c;
    localparam bit [31:0] TILE_EXT_IN_STRIDE=32'h130, TILE_EXT_OUT_STRIDE=32'h134;
    localparam bit [31:0] TILE_BUF0=32'h138, TILE_BUF1=32'h13c;
    localparam bit [31:0] TILE_IN_WORDS=32'h140, TILE_OUT_WORDS=32'h144, TILE_OUT_OFFSET=32'h148;
    localparam bit [31:0] PERF_TOTAL=32'h14c, PERF_DMA=32'h150, PERF_COMPUTE=32'h154;
    localparam bit [31:0] PERF_OVERLAP=32'h158, PERF_STALL=32'h15c, TILE_COMPLETED=32'h160;
    localparam bit [31:0] SPAD_INFO=32'h164, EVENT_STATUS=32'h168;
    localparam bit [31:0] DMA_GATHER_INDEX=32'h170, PERF_CTRL=32'h174;
    localparam bit [31:0] PERF_MATRIX_CYCLES=32'h178, PERF_MATRIX_MAC_CYCLES=32'h17c;
    localparam bit [31:0] PERF_MATRIX_BANKED_STALL=32'h180, PERF_DMA_READ_BYTES=32'h184;
    localparam bit [31:0] PERF_DMA_WRITE_BYTES=32'h188, PERF_DMA_AR_COUNT=32'h18c;
    localparam bit [31:0] PERF_DMA_AW_COUNT=32'h190, PERF_DMA_RD_STATE=32'h194;
    localparam bit [31:0] PERF_DMA_R_STALL=32'h198, DMA_EXT_HI=32'h19c;
    localparam bit [31:0] ERROR_INFO=32'h1a4, TILE_EXT_IN_HI=32'h1ac, TILE_EXT_OUT_HI=32'h1b0;

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
