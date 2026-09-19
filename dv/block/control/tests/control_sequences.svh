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
        read32(VERSION, data); expect_eq("VERSION", data, 32'h1000_0008);
        read32(CAP, data); expect_eq("CAP", data, 32'h001f_ff17);
        read32(ABI_INFO, data); expect_eq("ABI_INFO", data, 32'h1040_0207);
        read32(CAP2, data); expect_eq("CAP2", data, 32'h0000_003f);
        read32(OP, data); expect_eq("reset OP", data, 0);
        read32(IRQ_ENABLE, data); expect_eq("reset IRQ_ENABLE", data, 0);
        read32(STATUS, data); expect_eq("reset STATUS", data, 0);
    endtask
endclass

class control_protocol_seq extends control_base_seq;
    `uvm_object_utils(control_protocol_seq)
    function new(string name = "control_protocol_seq"); super.new(name); endfunction
    task body();
        bit [31:0] data;
        // AW-first, W-first, B back-pressure and R back-pressure.
        write32(OP, 32'h0000_0031, 4'hf, 2'b00, 0, 3, 2);
        read32(OP, data, 2'b00, 3); expect_eq("AW-first OP", data, 32'h31);
        write32(SRC0, 32'h1122_3344, 4'hf, 2'b00, 3, 0, 1);
        read32(SRC0, data); expect_eq("W-first SRC0", data, 32'h1122_3344);
        // Register writes are intentionally full-word-only in ABI v7.2.
        write32(OP, 32'hffff_ffff, 4'h3, 2'b10, 1, 2, 0);
        read32(OP, data); expect_eq("partial write preserved OP", data, 32'h31);
        write32(VERSION, 32'h0, 4'hf, 2'b10);
        read32(OP + 2, data, 2'b10);
        read32(32'h0000_0200, data, 2'b10);
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
