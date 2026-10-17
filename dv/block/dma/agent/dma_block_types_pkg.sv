package dma_block_types_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class dma_block_cfg extends uvm_object;
        bit ooo_read_responses = 1;
        bit ooo_write_responses = 1;
        bit enable_backpressure = 0;
        // Directed block test holds AWREADY low before publishing its store.
        bit force_awready_low = 0;
        // Subsystem tests connect the DUT to the real arbiter/scratchpad and
        // therefore disable the block-level behavioral SPAD responder.
        bit external_spad_model = 0;
        int unsigned ar_stall_cycles = 0;
        // Keep the first responses back until this many ARs are accepted.
        // The default deliberately fills the DMA's four tagged read slots.
        int unsigned min_accepted_reads_before_response = 4;
        int unsigned min_accepted_writes_before_response = 1;
        int unsigned read_response_delay_cycles = 0;
        int unsigned write_response_delay_cycles = 0;
        // Optional deterministic AXI RRESP fault injection used by subsystem
        // stress tests. The address is the byte address of an AXI read beat.
        bit inject_read_error;
        bit [63:0] inject_read_error_addr;
        int unsigned injected_read_error_responses;
        // Assert a one-shot SPAD line-request protection error on the first
        // valid destination write, before its accepting clock edge.
        bit inject_spad_line_req_error;
        int unsigned injected_spad_line_req_errors;
        bit [31:0] injected_spad_line_req_addr;
        // Optional deterministic AXI BRESP fault injection. The block-level
        // write-SLVERR test uses a single-burst store and checks one response.
        bit inject_write_error;
        int unsigned injected_write_error_responses;
        `uvm_object_utils(dma_block_cfg)
        function new(string name = "dma_block_cfg"); super.new(name); endfunction
    endclass

    class dma_cmd_item extends uvm_sequence_item;
        rand bit [63:0] ext_addr;
        rand bit [31:0] spad_addr;
        rand bit [15:0] length_words;
        rand bit [15:0] row_words;
        rand bit [15:0] row_count;
        rand bit [31:0] ext_stride;
        rand bit [31:0] spad_stride;
        rand bit [2:0]  read_outstanding;
        rand bit store;
        bit gather_enable;
        bit [31:0] gather_index_base;
        // Test-controlled external addresses returned by the SPAD gather
        // index table.  The hardware sees only the table in scratchpad.
        bit [31:0] gather_row_addr[$];
        bit expect_error;
        bit [3:0] expected_error_code;
        int unsigned abort_after_cycles;
        // Assert abort on the cycle after the first accepted AXI write address.
        bit abort_after_aw;
        int unsigned minimum_rd_highwater;
        `uvm_object_utils_begin(dma_cmd_item)
            `uvm_field_int(ext_addr, UVM_DEFAULT)
            `uvm_field_int(spad_addr, UVM_DEFAULT)
            `uvm_field_int(length_words, UVM_DEFAULT)
            `uvm_field_int(row_words, UVM_DEFAULT)
            `uvm_field_int(row_count, UVM_DEFAULT)
            `uvm_field_int(ext_stride, UVM_DEFAULT)
            `uvm_field_int(spad_stride, UVM_DEFAULT)
            `uvm_field_int(read_outstanding, UVM_DEFAULT)
            `uvm_field_int(store, UVM_DEFAULT)
            `uvm_field_int(gather_enable, UVM_DEFAULT)
            `uvm_field_int(gather_index_base, UVM_DEFAULT)
            `uvm_field_int(expect_error, UVM_DEFAULT)
            `uvm_field_int(expected_error_code, UVM_DEFAULT)
            `uvm_field_int(abort_after_cycles, UVM_DEFAULT)
            `uvm_field_int(abort_after_aw, UVM_DEFAULT)
            `uvm_field_int(minimum_rd_highwater, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name = "dma_cmd_item"); super.new(name); endfunction
    endclass

    class dma_spad_write_item extends uvm_sequence_item;
        bit [31:0] addr;
        bit [31:0] data;
        `uvm_object_utils_begin(dma_spad_write_item)
            `uvm_field_int(addr, UVM_DEFAULT)
            `uvm_field_int(data, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name = "dma_spad_write_item"); super.new(name); endfunction
    endclass

    class dma_axi_write_item extends uvm_sequence_item;
        bit [63:0] addr;
        bit [31:0] data;
        `uvm_object_utils_begin(dma_axi_write_item)
            `uvm_field_int(addr, UVM_DEFAULT)
            `uvm_field_int(data, UVM_DEFAULT)
        `uvm_object_utils_end
        function new(string name = "dma_axi_write_item"); super.new(name); endfunction
    endclass

    function automatic bit [31:0] dma_spad_source_word(bit [31:0] byte_addr);
        dma_spad_source_word = 32'h5a00_0000 + (byte_addr >> 2);
    endfunction

    function automatic bit [31:0] dma_memory_word(bit [63:0] byte_addr);
        dma_memory_word = 32'ha500_0000 + (byte_addr >> 2);
    endfunction
endpackage
