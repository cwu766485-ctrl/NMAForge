class control_base_seq extends uvm_sequence #(control_axil_item);
    `uvm_object_utils(control_base_seq)
    virtual ai_control_status_if status_vif;
    function new(string name = "control_base_seq"); super.new(name); endfunction
    task automatic write32(input bit [31:0] addr, input bit [31:0] data,
                           input bit [3:0] strb = 4'hf, input bit [1:0] expected = 2'b00,
                           input int unsigned aw_delay = 0, input int unsigned w_delay = 0,
                           input int unsigned bready_delay = 0);
        control_axil_item tr = control_axil_item::type_id::create("write32");
        start_item(tr);
        tr.is_write = 1; tr.addr = addr; tr.data = data; tr.strb = strb;
        tr.aw_delay = aw_delay; tr.w_delay = w_delay; tr.bready_delay = bready_delay;
        tr.rready_delay = 0;
        finish_item(tr);
        if (tr.resp != expected)
            `uvm_error("AXIL_WRITE", $sformatf("addr=%08h expected BRESP=%0h got=%0h", addr, expected, tr.resp))
    endtask
    task automatic read32(input bit [31:0] addr, output bit [31:0] data,
                          input bit [1:0] expected = 2'b00, input int unsigned rready_delay = 0);
        control_axil_item tr = control_axil_item::type_id::create("read32");
        start_item(tr);
        tr.is_write = 0; tr.addr = addr; tr.data = '0; tr.strb = 4'hf;
        tr.aw_delay = 0; tr.w_delay = 0; tr.bready_delay = 0; tr.rready_delay = rready_delay;
        finish_item(tr);
        data = tr.rdata;
        if (tr.resp != expected)
            `uvm_error("AXIL_READ", $sformatf("addr=%08h expected RRESP=%0h got=%0h", addr, expected, tr.resp))
    endtask
    task automatic expect_eq(input string what, input bit [31:0] got, input bit [31:0] expected);
        if (got !== expected) `uvm_error("CTRL_CHECK", $sformatf("%s expected=%08h got=%08h", what, expected, got))
    endtask
endclass

class control_reset_version_seq extends control_base_seq;
    `uvm_object_utils(control_reset_version_seq)
    function new(string name = "control_reset_version_seq"); super.new(name); endfunction
    task body();
        bit [31:0] data;
        read32(VERSION, data); expect_eq("VERSION", data, 32'h1000_000a);
        read32(CAP, data); expect_eq("CAP", data, 32'h001f_ff17);
        read32(ABI_INFO, data); expect_eq("ABI_INFO", data, 32'h1040_0407);
        read32(CAP2, data); expect_eq("CAP2", data, 32'h0000_00ff);
        read32(OP, data); expect_eq("reset OP", data, 0);
        read32(IRQ_ENABLE, data); expect_eq("reset IRQ_ENABLE", data, 0);
        read32(STATUS, data); expect_eq("reset STATUS", data, 0);
    endtask
endclass

// Walk the complete architected register map and exercise each register-file
// storage/status path.  This complements protocol coverage: address-window
// bins alone do not prove the individual ABI decode arms.
class control_register_file_seq extends control_base_seq;
    `uvm_object_utils(control_register_file_seq)
    virtual ai_control_status_if status_vif;

    function new(string name = "control_register_file_seq"); super.new(name); endfunction

    function automatic bit [31:0] expected_storage_value(input bit [31:0] addr,
                                                           input bit [31:0] value);
        case (addr)
            OP: expected_storage_value = {24'd0, value[7:0]};
            IRQ_ENABLE, CMD_CTRL: expected_storage_value = {31'd0, value[0]};
            LENGTH, M, N, K, DMA_LEN, DMA_ROW_WORDS, DMA_ROW_COUNT,
            TILE_COUNT, TILE_IN_WORDS, TILE_OUT_WORDS:
                expected_storage_value = {16'd0, value[15:0]};
            QUANT: expected_storage_value = {25'd0, value[6:0]};
            POST_CTRL: expected_storage_value = {31'd0, value[0]};
            R0_PERM, R1_PERM, R2_PERM, R3_PERM:
                expected_storage_value = {28'd0, value[3:0]};
            default: expected_storage_value = value;
        endcase
    endfunction

    function automatic int unsigned pulse_count(input string pulse_name);
        case (pulse_name)
            "direct_start": pulse_count = status_vif.direct_start_count;
            "submit": pulse_count = status_vif.submit_count;
            "abort": pulse_count = status_vif.abort_count;
            "dma_start": pulse_count = status_vif.dma_start_count;
            "tile_start": pulse_count = status_vif.tile_start_count;
            "perf_clear": pulse_count = status_vif.perf_clear_count;
            "cmdq_head_load": pulse_count = status_vif.cmdq_head_load_count;
            "cplq_tail_load": pulse_count = status_vif.cplq_tail_load_count;
            default: pulse_count = '1;
        endcase
    endfunction

    task automatic check_pulse(input string pulse_name, input int unsigned old_count);
        repeat (3) @(negedge status_vif.clk);
        if (pulse_count(pulse_name) != old_count + 1)
            `uvm_error("REG_PULSE", $sformatf("%s pulse count expected %0d got %0d",
                      pulse_name, old_count + 1, pulse_count(pulse_name)))
    endtask

    task automatic drive_processor_event(input bit is_error, input bit [3:0] error_code,
                                         input bit [31:0] result_value);
        @(negedge status_vif.clk);
        status_vif.processor_event_error = is_error;
        status_vif.processor_event_error_code = error_code;
        status_vif.processor_event_result = result_value;
        status_vif.processor_event_cycles = 32'h0000_1234;
        status_vif.processor_event_elements = 32'h0000_0056;
        status_vif.processor_event_valid = 1;
        @(negedge status_vif.clk);
        status_vif.processor_event_valid = 0;
        status_vif.processor_event_error = 0;
    endtask

    task body();
        bit [31:0] writable_addrs[$];
        bit [31:0] data, got, expected;
        int unsigned i, addr, old_count;

        if (!uvm_config_db#(virtual ai_control_status_if)::get(null, "*", "status_vif", status_vif))
            `uvm_fatal("NOVIF", "control_register_file_seq requires status_vif")

        // Read/write storage registers: use nontrivial values while avoiding
        // command-launch and DMA-start bits.  Narrow fields are checked after
        // the documented truncation performed by the register file.
        writable_addrs = '{OP, SRC0, SRC1, DST, LENGTH, M, N, K, QUANT, IRQ_ENABLE,
                           CMD_BASE, CMD_HI, CMD_SIZE, CMD_TAIL, CMD_CTRL,
                           CPL_BASE, CPL_HI, CPL_SIZE, CPL_HEAD, WATCHDOG,
                           DMA_EXT, DMA_EXT_HI, DMA_SPAD, DMA_LEN,
                           DMA_ROW_WORDS, DMA_ROW_COUNT, DMA_EXT_STRIDE, DMA_SPAD_STRIDE,
                           DMA_GATHER_INDEX, BIAS_BASE, POST_CTRL, TILE_COUNT,
                           TILE_EXT_IN, TILE_EXT_OUT, TILE_EXT_IN_HI, TILE_EXT_OUT_HI,
                           TILE_EXT_IN_STRIDE, TILE_EXT_OUT_STRIDE, TILE_BUF0, TILE_BUF1,
                           TILE_IN_WORDS, TILE_OUT_WORDS, TILE_OUT_OFFSET,
                           R0_BASE, R0_LIMIT, R0_PERM, R1_BASE, R1_LIMIT, R1_PERM,
                           R2_BASE, R2_LIMIT, R2_PERM, R3_BASE, R3_LIMIT, R3_PERM};

        for (i = 0; i < writable_addrs.size(); i++) begin
            data = 32'h5a3c_9600 ^ (i * 32'h0101_0101);
            if (writable_addrs[i] == POST_CTRL) data[0] = i[0];
            write32(writable_addrs[i], data);
            read32(writable_addrs[i], got);
            expected = expected_storage_value(writable_addrs[i], data);
            expect_eq($sformatf("register storage %03h", writable_addrs[i]), got, expected);
        end

        // Special writable registers have side effects or field-specific
        // semantics, so check them independently rather than hiding those
        // behaviors in the generic storage loop.
        write32(CTRL, 32'h2); // IRQ enable without direct-start.
        read32(CTRL, got); expect_eq("CTRL irq-enable mirror", got, 32'h2);
        write32(DMA_CTRL, 32'h2); // Store mode only; START remains low.
        read32(DMA_CTRL, got); expect_eq("DMA_CTRL store-only", got, 32'h2);
        write32(DMA_CFG, 32'h0000_0401);
        read32(DMA_CFG, got); expect_eq("DMA_CFG read-only capability", got, 32'h0000_0403);
        write32(STATUS, 32'h0); write32(IRQ_STATUS, 32'h0);
        write32(DMA_STATUS, 32'h0); write32(ABORT, 32'h0); write32(TILE_CTRL, 32'h0);
        write32(PERF_CTRL, 32'h0);

        // Pulse-producing controls are observed at the DUT boundary.  The
        // block test intentionally leaves the consumers disconnected, so these
        // checks validate the register-file contract without launching engines.
        old_count = pulse_count("direct_start");
        write32(CTRL, 32'h1); check_pulse("direct_start", old_count);
        old_count = pulse_count("submit");
        write32(DOORBELL, 32'h1); check_pulse("submit", old_count);
        old_count = pulse_count("abort");
        write32(ABORT, 32'h1); check_pulse("abort", old_count);
        old_count = pulse_count("dma_start");
        write32(DMA_CTRL, 32'h3); check_pulse("dma_start", old_count);
        old_count = pulse_count("tile_start");
        write32(TILE_CTRL, 32'h1); check_pulse("tile_start", old_count);
        old_count = pulse_count("perf_clear");
        write32(PERF_CTRL, 32'h1); check_pulse("perf_clear", old_count);

        old_count = pulse_count("cmdq_head_load");
        write32(CMD_HEAD, 32'h3); check_pulse("cmdq_head_load", old_count);
        expect_eq("CMD_HEAD seed", status_vif.cmdq_head_seed, 32'h3);
        status_vif.processor_cmdq_head = 32'h3;
        read32(CMD_HEAD, got); expect_eq("CMD_HEAD sampled pointer", got, 32'h3);
        old_count = pulse_count("cplq_tail_load");
        write32(CPL_TAIL, 32'h2); check_pulse("cplq_tail_load", old_count);
        expect_eq("CPL_TAIL seed", status_vif.cplq_tail_seed, 32'h2);
        status_vif.processor_cplq_tail = 32'h2;
        read32(CPL_TAIL, got); expect_eq("CPL_TAIL sampled pointer", got, 32'h2);

        // Empty/full ring status is decoded from both software-owned and
        // processor-owned pointers; use a legal four-entry ring.
        write32(CMD_SIZE, 32'd4); write32(CMD_TAIL, 32'd0);
        write32(CPL_SIZE, 32'd4); write32(CPL_HEAD, 32'd1);
        status_vif.processor_cmdq_head = 0; status_vif.processor_cplq_tail = 0;
        read32(QUEUE_STATUS, got); expect_eq("queue empty plus completion full", got, 32'h5);
        write32(CMD_TAIL, 32'd1); write32(CPL_HEAD, 32'd2);
        read32(QUEUE_STATUS, got); expect_eq("queue nonempty and completion not full", got, 0);
        status_vif.processor_cplq_tail = 3; write32(CPL_HEAD, 32'd0);
        read32(QUEUE_STATUS, got); expect_eq("completion ring tail wrap/full", got, 32'h4);
        status_vif.processor_cplq_tail = 0;

        // DMA-only busy must independently lock configuration writes.  This
        // also covers the DMA half of cfg_locked rather than only CPU busy.
        status_vif.dma_busy = 1;
        write32(SRC0, 32'hdead_beef, 4'hf, 2'b10);
        status_vif.dma_busy = 0;

        // Processor and DMA feedback paths update sticky status, error source,
        // result/counters and IRQ.  Then verify W1C recovery on both domains.
        write32(IRQ_ENABLE, 32'h1);
        drive_processor_event(0, 0, 32'h1234_5678);
        read32(STATUS, got); expect_eq("successful processor done", got, 32'h2);
        read32(RESULT, got); expect_eq("processor result", got, 32'h1234_5678);
        read32(CYCLES, got); expect_eq("processor cycle count", got, 32'h1234);
        read32(ELEMENTS, got); expect_eq("processor element count", got, 32'h56);
        read32(ERROR_INFO, got); expect_eq("successful event source", got, 0);
        if (status_vif.irq !== 1'b1) `uvm_error("REG_IRQ", "processor completion did not assert IRQ")
        write32(IRQ_ENABLE, 32'h0);
        if (status_vif.irq !== 1'b0) `uvm_error("REG_IRQ", "IRQ enable did not mask sticky IRQ status")
        read32(IRQ_STATUS, got); expect_eq("IRQ status remains sticky while masked", got, 1);
        write32(IRQ_ENABLE, 32'h1);
        write32(STATUS, 32'h2); write32(IRQ_STATUS, 32'h1);
        read32(STATUS, got); expect_eq("processor done W1C", got, 0);
        if (status_vif.irq !== 1'b0) `uvm_error("REG_IRQ", "processor W1C did not clear IRQ")

        @(negedge status_vif.clk);
        status_vif.dma_error_code = 0; status_vif.dma_error = 0; status_vif.dma_done = 1;
        @(negedge status_vif.clk); status_vif.dma_done = 0;
        read32(DMA_STATUS, got); expect_eq("DMA successful completion status", got, 32'h2);
        write32(DMA_STATUS, 32'h2);
        read32(DMA_STATUS, got); expect_eq("DMA done-only W1C", got, 0);

        @(negedge status_vif.clk);
        status_vif.dma_error_code = 4'h9; status_vif.dma_error = 1; status_vif.dma_done = 1;
        @(negedge status_vif.clk); status_vif.dma_error = 0; status_vif.dma_done = 0;
        read32(DMA_STATUS, got); expect_eq("DMA done and error status", got, 32'h6);
        read32(DMA_ERROR, got); expect_eq("DMA error code", got, 32'h9);
        read32(ERROR_INFO, got); expect_eq("DMA error source", got, 32'h29);
        if (status_vif.irq !== 1'b1) `uvm_error("REG_IRQ", "DMA error did not assert IRQ")
        write32(DMA_STATUS, 32'h6); write32(STATUS, 32'h4); write32(IRQ_STATUS, 32'h1);
        read32(DMA_STATUS, got); expect_eq("DMA status W1C", got, 0);
        read32(ERROR_INFO, got); expect_eq("error source W1C", got, 0);
        if (status_vif.irq !== 1'b0) `uvm_error("REG_IRQ", "DMA W1C did not clear IRQ")

        // Exercise every implemented read mux arm, including read-only,
        // performance, queue, protection and 64-bit address-high registers.
        status_vif.processor_dependency_events = 16'hc35a;
        status_vif.tile_perf_total = 32'h1111_0001;
        status_vif.tile_perf_dma = 32'h2222_0002;
        status_vif.tile_perf_compute = 32'h3333_0003;
        status_vif.tile_perf_overlap = 32'h4444_0004;
        status_vif.tile_perf_stall = 32'h5555_0005;
        status_vif.tile_completed = 16'h6677;
        status_vif.perf_matrix_cycles = 32'h8888_0008;
        status_vif.perf_matrix_mac_cycles = 32'h9999_0009;
        status_vif.perf_matrix_banked_stall = 32'haaaa_000a;
        status_vif.perf_dma_read_bytes = 32'hbbbb_000b;
        status_vif.perf_dma_write_bytes = 32'hcccc_000c;
        status_vif.perf_dma_ar_count = 32'hdddd_000d;
        status_vif.perf_dma_aw_count = 32'heeee_000e;
        status_vif.perf_dma_r_stall = 32'hffff_000f;
        status_vif.perf_dma_rd_outstanding = 3'd3;
        status_vif.perf_dma_rd_highwater = 3'd5;

        for (addr = 0; addr <= CAP; addr += 4) read32(addr, got);
        for (addr = CMD_BASE; addr <= QUEUE_STATUS; addr += 4) read32(addr, got);
        for (addr = R0_BASE; addr <= POST_CTRL; addr += 4) read32(addr, got);
        for (addr = TILE_CTRL; addr <= TILE_EXT_OUT_HI; addr += 4) read32(addr, got);

        read32(SPAD_INFO, got); expect_eq("SPAD_INFO", got, 32'h0008_0000);
        read32(EVENT_STATUS, got); expect_eq("EVENT_STATUS", got, 32'h0000_c35a);
        read32(PERF_TOTAL, got); expect_eq("PERF_TOTAL", got, 32'h1111_0001);
        read32(PERF_MATRIX_CYCLES, got); expect_eq("PERF_MATRIX_CYCLES", got, 32'h8888_0008);
        read32(PERF_DMA_RD_STATE, got); expect_eq("PERF_DMA_RD_STATE", got, 32'h0000_002b);
        read32(ABI_INFO, got); expect_eq("ABI_INFO", got, 32'h1040_0407);
        read32(CAP2, got); expect_eq("CAP2", got, 32'h0000_00ff);
        write32(VERSION, 32'h0, 4'hf, 2'b10);
        write32(PERF_TOTAL, 32'h0, 4'hf, 2'b10);
    endtask
endclass

class control_protocol_seq extends control_base_seq;
    `uvm_object_utils(control_protocol_seq)
    function new(string name = "control_protocol_seq"); super.new(name); endfunction
    task body();
        bit [31:0] data;
        int unsigned strobe_mask;
        // AW-first, W-first, B back-pressure and R back-pressure.
        write32(OP, 32'h0000_0031, 4'hf, 2'b00, 0, 3, 2);
        read32(OP, data, 2'b00, 3); expect_eq("AW-first OP", data, 32'h31);
        write32(SRC0, 32'h1122_3344, 4'hf, 2'b00, 3, 0, 1);
        read32(SRC0, data); expect_eq("W-first SRC0", data, 32'h1122_3344);
        // Register writes are intentionally full-word-only in ABI v7.2.
        write32(OP, 32'hffff_ffff, 4'h3, 2'b10, 1, 2, 0);
        read32(OP, data); expect_eq("partial write preserved OP", data, 32'h31);

        // Every non-full WSTRB encoding is rejected by the register ABI.
        // Sampling is write-qualified in control_coverage, so this closes the
        // actual WSTRB bins rather than counting read transactions as strb=0.
        for (strobe_mask = 0; strobe_mask < 15; strobe_mask++) begin
            write32(OP, 32'hffff_ffff, strobe_mask[3:0], 2'b10);
        end
        read32(OP, data); expect_eq("all partial strobes preserve OP", data, 32'h31);

        write32(VERSION, 32'h0, 4'hf, 2'b10);
        read32(OP + 2, data, 2'b10);
        read32(32'h0000_0200, data, 2'b10);

        // Probe the register windows not reached by the existing directed
        // tests. These are read-only observations; 0x060 is intentionally
        // unmapped and must return SLVERR.
        read32(32'h0000_0060, data, 2'b10);
        read32(32'h0000_00e0, data);
        read32(32'h0000_0100, data);
        read32(32'h0000_0120, data);
        read32(32'h0000_0140, data);
        read32(32'h0000_0180, data);
    endtask
endclass

// Exercise address-channel VALID stability while the one-entry AXI-Lite
// adapter is busy with the previous request.  The normal agent serializes
// complete transactions, so a dedicated bus-level sequence is needed to put
// AW, W, and AR VALID high while the DUT's corresponding READY is low.
class control_channel_backpressure_seq extends control_base_seq;
    `uvm_object_utils(control_channel_backpressure_seq)
    virtual ai_axil_if axil_vif;

    function new(string name = "control_channel_backpressure_seq"); super.new(name); endfunction

    task automatic wait_b_handshake();
        int unsigned cycles;
        cycles = 0;
        do begin
            @(posedge axil_vif.aclk);
            cycles++;
            if (cycles >= 64)
                `uvm_fatal("AXIL_TIMEOUT", "raw B-channel backpressure test timed out")
        end while (!(axil_vif.bvalid && axil_vif.bready));
    endtask

    task automatic wait_w_handshake();
        int unsigned cycles;
        cycles = 0;
        do begin
            @(posedge axil_vif.aclk);
            cycles++;
            if (cycles >= 64)
                `uvm_fatal("AXIL_TIMEOUT", "raw W-channel backpressure test timed out")
        end while (!(axil_vif.wvalid && axil_vif.wready));
    endtask

    task automatic wait_aw_handshake();
        int unsigned cycles;
        cycles = 0;
        do begin
            @(posedge axil_vif.aclk);
            cycles++;
            if (cycles >= 64)
                `uvm_fatal("AXIL_TIMEOUT", "raw AW-channel backpressure test timed out")
        end while (!(axil_vif.awvalid && axil_vif.awready));
    endtask

    task body();
        bit [31:0] read_data;
        int unsigned cycles;
        if (!uvm_config_db#(virtual ai_axil_if)::get(null, "*", "axil_vif", axil_vif))
            `uvm_fatal("NOVIF", "control_channel_backpressure_seq requires axil_vif")

        wait (axil_vif.aresetn === 1'b1);
        @(negedge axil_vif.aclk);
        axil_vif.awvalid <= 0; axil_vif.wvalid <= 0; axil_vif.arvalid <= 0;
        axil_vif.bready <= 1; axil_vif.rready <= 1;

        // Accept the first AW only, then present the next AW while awready is
        // low.  Keep address/data stable until the prior B response retires.
        @(negedge axil_vif.aclk);
        axil_vif.awaddr <= OP; axil_vif.awvalid <= 1;
        wait_aw_handshake();
        @(negedge axil_vif.aclk);
        axil_vif.awaddr <= SRC0;
        repeat (2) @(posedge axil_vif.aclk);
        @(negedge axil_vif.aclk);
        axil_vif.wdata <= 32'h0000_0031; axil_vif.wstrb <= 4'hf; axil_vif.wvalid <= 1;
        wait_w_handshake();
        @(negedge axil_vif.aclk); axil_vif.wvalid <= 0;
        wait_b_handshake();
        wait_aw_handshake();
        @(negedge axil_vif.aclk); axil_vif.awvalid <= 0;
        axil_vif.wdata <= 32'h1122_3344; axil_vif.wvalid <= 1;
        wait_w_handshake();
        @(negedge axil_vif.aclk); axil_vif.wvalid <= 0;
        wait_b_handshake();

        // Accept the first W only, then hold the next W while wready is low.
        @(negedge axil_vif.aclk);
        axil_vif.wdata <= 32'h5566_7788; axil_vif.wstrb <= 4'hf; axil_vif.wvalid <= 1;
        wait_w_handshake();
        @(negedge axil_vif.aclk); axil_vif.wdata <= 32'hdead_beef;
        repeat (2) @(posedge axil_vif.aclk);
        @(negedge axil_vif.aclk); axil_vif.awaddr <= SRC1; axil_vif.awvalid <= 1;
        wait_aw_handshake();
        @(negedge axil_vif.aclk); axil_vif.awvalid <= 0;
        wait_b_handshake();
        wait_w_handshake();
        @(negedge axil_vif.aclk); axil_vif.wvalid <= 0; axil_vif.awaddr <= DST; axil_vif.awvalid <= 1;
        wait_aw_handshake();
        @(negedge axil_vif.aclk); axil_vif.awvalid <= 0;
        wait_b_handshake();

        // AR back-pressure: keep a second AR request stable while the first
        // register read is in flight, then retire both responses in order.
        @(negedge axil_vif.aclk); axil_vif.araddr <= VERSION; axil_vif.arvalid <= 1;
        wait (axil_vif.arready === 1'b1);
        @(posedge axil_vif.aclk);
        @(negedge axil_vif.aclk); axil_vif.araddr <= CAP;
        repeat (2) @(posedge axil_vif.aclk);
        cycles = 0;
        do begin
            @(posedge axil_vif.aclk);
            cycles++;
            if (cycles >= 64) `uvm_fatal("AXIL_TIMEOUT", "first raw R response timed out")
        end while (!(axil_vif.rvalid && axil_vif.rready));
        read_data = axil_vif.rdata;
        if (read_data !== 32'h1000_000a)
            `uvm_error("AXIL_READ", $sformatf("VERSION expected=1000000a got=%08h", read_data))
        wait (axil_vif.arready === 1'b1);
        @(posedge axil_vif.aclk);
        @(negedge axil_vif.aclk); axil_vif.arvalid <= 0;
        cycles = 0;
        do begin
            @(posedge axil_vif.aclk);
            cycles++;
            if (cycles >= 64) `uvm_fatal("AXIL_TIMEOUT", "second raw R response timed out")
        end while (!(axil_vif.rvalid && axil_vif.rready));
        read_data = axil_vif.rdata;
        if (read_data !== 32'h001f_ff17)
            `uvm_error("AXIL_READ", $sformatf("CAP expected=001fff17 got=%08h", read_data))
        @(negedge axil_vif.aclk);
        axil_vif.rready <= 0; axil_vif.bready <= 0;
    endtask
endclass

// Assert asynchronous reset from write/read FSM wait states, then prove that
// no stale AXI response leaks into the first transaction after reset release.
class control_inflight_reset_seq extends control_base_seq;
    `uvm_object_utils(control_inflight_reset_seq)
    virtual ai_axil_if axil_vif;

    function new(string name = "control_inflight_reset_seq"); super.new(name); endfunction

    task automatic arm_irq();
        write32(IRQ_ENABLE, 32'h1);
        @(negedge axil_vif.aclk);
        status_vif.processor_event_error <= 1'b1;
        status_vif.processor_event_error_code <= 4'h5;
        status_vif.processor_event_valid <= 1'b1;
        @(negedge axil_vif.aclk);
        status_vif.processor_event_error <= 1'b0;
        status_vif.processor_event_valid <= 1'b0;
        if (status_vif.irq !== 1'b1)
            `uvm_error("RESET_SETUP", "failed to assert IRQ before in-flight reset test")
    endtask

    task automatic reset_now_and_recover(input string phase_name);
        bit [31:0] data;
        if (status_vif.irq !== 1'b1)
            `uvm_error("RESET_SETUP", $sformatf("IRQ was not asserted before reset from %s", phase_name))
        status_vif.resetn <= 0;
        axil_vif.bready <= 0; axil_vif.rready <= 0;
        repeat (2) @(posedge axil_vif.aclk);
        if (axil_vif.bvalid !== 1'b0 || axil_vif.rvalid !== 1'b0)
            `uvm_error("RESET_RECOVERY", $sformatf("AXI response remained valid after reset from %s", phase_name))
        if (status_vif.irq !== 1'b0)
            `uvm_error("RESET_RECOVERY", $sformatf("IRQ was not cleared after reset from %s", phase_name))
        @(negedge axil_vif.aclk); status_vif.resetn <= 1;
        repeat (2) @(posedge axil_vif.aclk);
        read32(VERSION, data);
        expect_eq($sformatf("VERSION after reset from %s", phase_name), data, 32'h1000_000a);
    endtask

    task automatic reset_during_write(input int unsigned post_accept_cycles,
                                      input string phase_name);
        @(negedge axil_vif.aclk);
        axil_vif.bready <= 0;
        axil_vif.awaddr <= OP; axil_vif.awvalid <= 1;
        axil_vif.wdata <= 32'h0000_0007; axil_vif.wstrb <= 4'hf; axil_vif.wvalid <= 1;
        do @(posedge axil_vif.aclk);
        while (!(axil_vif.awvalid && axil_vif.awready && axil_vif.wvalid && axil_vif.wready));
        repeat (post_accept_cycles) @(posedge axil_vif.aclk);
        @(negedge axil_vif.aclk);
        axil_vif.awvalid <= 0; axil_vif.wvalid <= 0;
        reset_now_and_recover(phase_name);
    endtask

    task automatic reset_during_read(input int unsigned post_accept_cycles,
                                     input string phase_name);
        @(negedge axil_vif.aclk);
        axil_vif.rready <= 0; axil_vif.araddr <= VERSION; axil_vif.arvalid <= 1;
        do @(posedge axil_vif.aclk);
        while (!(axil_vif.arvalid && axil_vif.arready));
        repeat (post_accept_cycles) @(posedge axil_vif.aclk);
        @(negedge axil_vif.aclk);
        axil_vif.arvalid <= 0;
        reset_now_and_recover(phase_name);
    endtask

    task body();
        if (!uvm_config_db#(virtual ai_axil_if)::get(null, "*", "axil_vif", axil_vif))
            `uvm_fatal("NOVIF", "control_inflight_reset_seq requires axil_vif")
        if (!uvm_config_db#(virtual ai_control_status_if)::get(null, "*", "status_vif", status_vif))
            `uvm_fatal("NOVIF", "control_inflight_reset_seq requires status_vif")

        wait (status_vif.resetn === 1'b1);
        // WR_REQ, WR_RESP_ARM, and WR_RESP respectively.
        arm_irq();
        reset_during_write(1, "WR_REQ");
        arm_irq();
        reset_during_write(2, "WR_RESP_ARM");
        arm_irq();
        reset_during_write(3, "WR_RESP");
        // RD_REQ, RD_WAIT, and RD_WAIT2 respectively.
        arm_irq();
        reset_during_read(0, "RD_REQ");
        arm_irq();
        reset_during_read(1, "RD_WAIT");
        arm_irq();
        reset_during_read(2, "RD_WAIT2");
    endtask
endclass

class control_irq_error_seq extends control_base_seq;
    `uvm_object_utils(control_irq_error_seq)
    function new(string name = "control_irq_error_seq"); super.new(name); endfunction
    task body();
        bit [31:0] data;
        if (!uvm_config_db#(virtual ai_control_status_if)::get(null, "*", "status_vif", status_vif))
            `uvm_fatal("NOVIF", "control_irq_error_seq requires status_vif")
        write32(IRQ_ENABLE, 32'h1);
        @(negedge status_vif.clk);
        status_vif.processor_event_error = 1;
        status_vif.processor_event_error_code = 4'h5;
        status_vif.processor_event_result = 32'hcafe_1234;
        status_vif.processor_event_cycles = 32'd77;
        status_vif.processor_event_elements = 32'd19;
        status_vif.processor_event_valid = 1;
        @(negedge status_vif.clk);
        status_vif.processor_event_valid = 0;
        status_vif.processor_event_error = 0;
        read32(STATUS, data); expect_eq("event STATUS", data, 32'h0000_0006);
        read32(RESULT, data); expect_eq("event RESULT", data, 32'hcafe_1234);
        read32(ERROR, data); expect_eq("event ERROR", data, 32'h5);
        read32(IRQ_STATUS, data); expect_eq("event IRQ_STATUS", data, 32'h1);
        if (status_vif.irq !== 1'b1) `uvm_error("IRQ", "IRQ did not assert after processor error event")
        write32(STATUS, 32'h6);
        write32(IRQ_STATUS, 32'h1);
        read32(STATUS, data); expect_eq("W1C STATUS", data, 0);
        read32(IRQ_STATUS, data); expect_eq("W1C IRQ_STATUS", data, 0);
        if (status_vif.irq !== 1'b0) `uvm_error("IRQ", "IRQ did not deassert after W1C")
    endtask
endclass

class control_busy_abort_seq extends control_base_seq;
    `uvm_object_utils(control_busy_abort_seq)
    function new(string name = "control_busy_abort_seq"); super.new(name); endfunction
    task body();
        bit [31:0] data;
        if (!uvm_config_db#(virtual ai_control_status_if)::get(null, "*", "status_vif", status_vif))
            `uvm_fatal("NOVIF", "control_busy_abort_seq requires status_vif")
        status_vif.processor_busy = 1;
        write32(OP, 32'h7, 4'hf, 2'b10);
        write32(ABORT, 32'h1, 4'hf, 2'b00);
        status_vif.processor_busy = 0;
        read32(OP, data); expect_eq("locked OP remains reset", data, 0);
    endtask
endclass

class control_random_rw_seq extends control_base_seq;
    `uvm_object_utils(control_random_rw_seq)
    function new(string name = "control_random_rw_seq"); super.new(name); endfunction
    task body();
        bit [31:0] addresses [0:7]; bit [31:0] data, got; int unsigned i, sel;
        addresses[0]=OP; addresses[1]=SRC0; addresses[2]=SRC1; addresses[3]=DST;
        addresses[4]=CMD_BASE; addresses[5]=CMD_SIZE; addresses[6]=CMD_TAIL; addresses[7]=DMA_CFG;
        for (i=0; i<32; i++) begin
            sel = $urandom_range(0, 7); data = $urandom;
            `uvm_info("CTRL_RANDOM", $sformatf("iteration=%0d register_index=%0d addr=%08h", i, sel, addresses[sel]), UVM_HIGH)
            if (addresses[sel] == OP) data[31:8] = 0;
            if (addresses[sel] == DMA_CFG) data[31:11] = 0;
            write32(addresses[sel], data, 4'hf, 2'b00, $urandom_range(0,3), $urandom_range(0,3), $urandom_range(0,3));
            read32(addresses[sel], got, 2'b00, $urandom_range(0,3));
            if (addresses[sel] == OP) data = {24'd0, data[7:0]};
            // DMA_CFG[1] is a read-only indicator that the unified DMA is
            // wide-capable; the writable ABI fields are gather_enable[0]
            // and read_outstanding[10:8].
            if (addresses[sel] == DMA_CFG) data = {21'd0, data[10:8], 6'd0, 1'b1, data[0]};
            expect_eq($sformatf("random reg[%0d]", sel), got, data);
        end
    endtask
endclass
