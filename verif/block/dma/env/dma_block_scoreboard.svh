class dma_block_scoreboard extends uvm_component;
    uvm_analysis_imp_cmd  #(dma_cmd_item, dma_block_scoreboard) cmd_imp;
    uvm_analysis_imp_spad #(dma_spad_write_item, dma_block_scoreboard) spad_imp;
    uvm_analysis_imp_axi  #(dma_axi_write_item, dma_block_scoreboard) axi_imp;
    dma_cmd_item active_cmd;
    bit seen_load_word[int unsigned];
    bit seen_store_word[int unsigned];
    int unsigned observed_load_words;
    int unsigned observed_store_words;
    bit cov_store, cov_gather, cov_is_2d, cov_crosses_4k;
    int unsigned cov_width_words, cov_outstanding;

    covergroup dma_cmd_cg;
        option.per_instance = 1;
        cp_direction: coverpoint cov_store { bins load = {0}; bins store = {1}; }
        cp_shape: coverpoint cov_is_2d { bins linear = {0}; bins two_d = {1}; }
        cp_gather: coverpoint cov_gather { bins disabled = {0}; bins enabled = {1}; }
        cp_length: coverpoint cov_width_words {
            bins short = {[1:3]}; bins line = {[4:16]}; bins multi = {[17:128]};
        }
        cp_outstanding: coverpoint cov_outstanding { bins one = {1}; bins many = {[2:3]}; bins four = {4}; }
        cp_4k: coverpoint cov_crosses_4k { bins no = {0}; bins yes = {1}; }
        x_load_modes: cross cp_direction, cp_shape, cp_gather;
    endgroup

    `uvm_component_utils(dma_block_scoreboard)

    function new(string name = "dma_block_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        cmd_imp = new("cmd_imp", this);
        spad_imp = new("spad_imp", this);
        axi_imp = new("axi_imp", this);
        dma_cmd_cg = new;
    endfunction

    function automatic int unsigned rows_for(dma_cmd_item item);
        return (item.row_count == 0) ? 1 : item.row_count;
    endfunction

    function automatic int unsigned words_for(dma_cmd_item item);
        return (item.row_count == 0) ? item.length_words : item.row_words;
    endfunction

    function automatic int unsigned total_words_for(dma_cmd_item item);
        return rows_for(item) * words_for(item);
    endfunction

    function automatic bit crosses_4k(dma_cmd_item item);
        int unsigned bytes;
        bytes = total_words_for(item) * 4;
        return ((item.ext_addr[11:0] + bytes) > 4096);
    endfunction

    function void write_cmd(dma_cmd_item item);
        active_cmd = dma_cmd_item::type_id::create("active_cmd");
        active_cmd.copy(item);
        active_cmd.gather_row_addr = item.gather_row_addr;
        seen_load_word.delete(); seen_store_word.delete();
        observed_load_words = 0; observed_store_words = 0;
        cov_store = item.store;
        cov_gather = item.gather_enable;
        cov_is_2d = (item.row_count != 0);
        cov_crosses_4k = crosses_4k(item);
        cov_width_words = words_for(item);
        cov_outstanding = item.read_outstanding;
        dma_cmd_cg.sample();
        `uvm_info("SB_CMD", $sformatf("%s rows=%0d words/row=%0d DDR 0x%0h SPAD 0x%0h",
                  item.store ? "store" : "load", rows_for(item), words_for(item),
                  item.ext_addr, item.spad_addr), UVM_LOW)
    endfunction

    function automatic bit expected_load(bit [31:0] actual_spad_addr,
                                         output bit [31:0] expected_data,
                                         output int unsigned logical_index);
        int unsigned row, col, words;
        bit [31:0] row_spad;
        bit [63:0] row_ext;
        expected_load = 0; expected_data = '0; logical_index = 0;
        if (active_cmd == null || active_cmd.store || active_cmd.expect_error) return 0;
        words = words_for(active_cmd);
        for (row = 0; row < rows_for(active_cmd); row++) begin
            row_spad = active_cmd.spad_addr + row * active_cmd.spad_stride;
            if (actual_spad_addr >= row_spad && actual_spad_addr < row_spad + words * 4 &&
                actual_spad_addr[1:0] == 0) begin
                col = (actual_spad_addr - row_spad) >> 2;
                if (active_cmd.gather_enable) begin
                    if (row >= active_cmd.gather_row_addr.size()) return 0;
                    row_ext = active_cmd.gather_row_addr[row];
                end else begin
                    row_ext = active_cmd.ext_addr + row * active_cmd.ext_stride;
                end
                expected_data = dma_memory_word(row_ext + col * 4);
                logical_index = row * words + col;
                return 1;
            end
        end
    endfunction

    function automatic bit expected_store(bit [63:0] actual_ext_addr,
                                          output bit [31:0] expected_data,
                                          output int unsigned logical_index);
        int unsigned row, col, words;
        bit [63:0] row_ext;
        bit [31:0] row_spad;
        expected_store = 0; expected_data = '0; logical_index = 0;
        if (active_cmd == null || !active_cmd.store || active_cmd.expect_error) return 0;
        words = words_for(active_cmd);
        for (row = 0; row < rows_for(active_cmd); row++) begin
            row_ext = active_cmd.ext_addr + row * active_cmd.ext_stride;
            row_spad = active_cmd.spad_addr + row * active_cmd.spad_stride;
            if (actual_ext_addr >= row_ext && actual_ext_addr < row_ext + words * 4 &&
                actual_ext_addr[1:0] == 0) begin
                col = (actual_ext_addr - row_ext) >> 2;
                expected_data = dma_spad_source_word(row_spad + col * 4);
                logical_index = row * words + col;
                return 1;
            end
        end
    endfunction

    function void write_spad(dma_spad_write_item item);
        bit [31:0] expected;
        int unsigned index;
        if (active_cmd == null || active_cmd.store) return;
        if (!expected_load(item.addr, expected, index)) begin
            if (!active_cmd.expect_error)
                `uvm_error("SB_SPAD_ADDR", $sformatf("unexpected SPAD write 0x%0h", item.addr))
            return;
        end
        if (seen_load_word.exists(index)) begin
            `uvm_error("SB_DUPLICATE", $sformatf("duplicate load word %0d", index))
            return;
        end
        if (item.data !== expected)
            `uvm_error("SB_LOAD_DATA", $sformatf("load word %0d SPAD=0x%08h expected=0x%08h",
                       index, item.data, expected))
        seen_load_word[index] = 1;
        observed_load_words++;
    endfunction

    function void write_axi(dma_axi_write_item item);
        bit [31:0] expected;
        int unsigned index;
        if (active_cmd == null || !active_cmd.store) return;
        if (!expected_store(item.addr, expected, index)) begin
            if (!active_cmd.expect_error)
                `uvm_error("SB_AXI_ADDR", $sformatf("unexpected DDR write 0x%0h", item.addr))
            return;
        end
        if (seen_store_word.exists(index)) begin
            `uvm_error("SB_STORE_DUP", $sformatf("duplicate store word %0d", index))
            return;
        end
        if (item.data !== expected)
            `uvm_error("SB_STORE_DATA", $sformatf("store word %0d DDR=0x%08h expected=0x%08h",
                       index, item.data, expected))
        seen_store_word[index] = 1;
        observed_store_words++;
    endfunction

    function void check_complete();
        int unsigned index, expected_count;
        if (active_cmd == null) begin
            `uvm_error("SB_NO_CMD", "no DMA command reached scoreboard")
            return;
        end
        if (active_cmd.expect_error) begin
            `uvm_info("SB_ABORT_PASS", "expected-error command reached completion; payload is intentionally not scored", UVM_LOW)
            return;
        end
        expected_count = total_words_for(active_cmd);
        if (active_cmd.store) begin
            if (observed_store_words != expected_count)
                `uvm_error("SB_STORE_COUNT", $sformatf("observed %0d store words, expected %0d",
                           observed_store_words, expected_count))
            for (index = 0; index < expected_count; index++)
                if (!seen_store_word.exists(index))
                    `uvm_error("SB_STORE_MISSING", $sformatf("missing store word %0d", index))
        end else begin
            if (observed_load_words != expected_count)
                `uvm_error("SB_LOAD_COUNT", $sformatf("observed %0d load words, expected %0d",
                           observed_load_words, expected_count))
            for (index = 0; index < expected_count; index++)
                if (!seen_load_word.exists(index))
                    `uvm_error("SB_LOAD_MISSING", $sformatf("missing load word %0d", index))
        end
        `uvm_info("SB_PASS", $sformatf("%s scoreboard matched %0d words",
                  active_cmd.store ? "SPAD-to-DDR" : "DDR-to-SPAD", expected_count), UVM_LOW)
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("DMA_COVERAGE", $sformatf("DMA command functional coverage = %0.2f%%",
                  dma_cmd_cg.get_inst_coverage()), UVM_LOW)
    endfunction
endclass
