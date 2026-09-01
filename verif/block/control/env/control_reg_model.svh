// P0 RAL model for the software-visible control ABI.  It intentionally covers
// the registers exercised by the control block; tensor/DMA payload semantics
// are owned by their dedicated block/subsystem environments.
class control_reg32 extends uvm_reg;
    uvm_reg_field value;
    `uvm_object_utils(control_reg32)
    function new(string name = "control_reg32", string access = "RW", bit vol = 0);
        super.new(name, 32, UVM_NO_COVERAGE);
        value = uvm_reg_field::type_id::create("value");
        value.configure(this, 32, 0, access, vol, 32'h0, 1, 1, 1);
    endfunction
endclass

class control_reg_block extends uvm_reg_block;
    `uvm_object_utils(control_reg_block)
    control_reg32 ctrl, status, op, src0, src1, dst, quant;
    control_reg32 result, error, irq_status, irq_enable, version, cap;
    control_reg32 cmd_base, cmd_size, cmd_tail, doorbell, abort_reg;
    control_reg32 dma_ctrl, dma_cfg, abi_info, cap2;

    function new(string name = "control_reg_block"); super.new(name, UVM_NO_COVERAGE); endfunction
    function void add_reg(ref control_reg32 r, input string name, input string access,
                          input bit vol, input uvm_reg_addr_t addr);
        r = new(name, access, vol);
        r.configure(this, null, "");
        default_map.add_reg(r, addr, access);
    endfunction
    function void build();
        default_map = create_map("axi_lite", 'h0, 4, UVM_LITTLE_ENDIAN, 1);
        add_reg(ctrl,       "ctrl",       "RW", 0, CTRL);
        add_reg(status,     "status",     "RW", 1, STATUS);
        add_reg(op,         "op",         "RW", 0, OP);
        add_reg(src0,       "src0",       "RW", 0, SRC0);
        add_reg(src1,       "src1",       "RW", 0, SRC1);
        add_reg(dst,        "dst",        "RW", 0, DST);
        add_reg(quant,      "quant",      "RW", 0, QUANT);
        add_reg(result,     "result",     "RO", 1, RESULT);
        add_reg(error,      "error",      "RO", 1, ERROR);
        add_reg(irq_status, "irq_status", "RW", 1, IRQ_STATUS);
        add_reg(irq_enable, "irq_enable", "RW", 0, IRQ_ENABLE);
        add_reg(version,    "version",    "RO", 0, VERSION);
        add_reg(cap,        "cap",        "RO", 0, CAP);
        add_reg(cmd_base,   "cmd_base",   "RW", 0, CMD_BASE);
        add_reg(cmd_size,   "cmd_size",   "RW", 0, CMD_SIZE);
        add_reg(cmd_tail,   "cmd_tail",   "RW", 0, CMD_TAIL);
        add_reg(doorbell,   "doorbell",   "WO", 0, DOORBELL);
        add_reg(abort_reg,  "abort",      "WO", 0, ABORT);
        add_reg(dma_ctrl,   "dma_ctrl",   "RW", 0, DMA_CTRL);
        add_reg(dma_cfg,    "dma_cfg",    "RW", 0, DMA_CFG);
        add_reg(abi_info,   "abi_info",   "RO", 0, ABI_INFO);
        add_reg(cap2,       "cap2",       "RO", 0, CAP2);
        lock_model();
    endfunction
endclass

class control_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(control_reg_adapter)
    function new(string name = "control_reg_adapter");
        super.new(name); provides_responses = 0;
    endfunction
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        control_axil_item tr = control_axil_item::type_id::create("ral_axil_item");
        tr.is_write = (rw.kind == UVM_WRITE);
        tr.addr = rw.addr;
        tr.data = rw.data;
        tr.strb = rw.byte_en[3:0];
        tr.aw_delay = 0; tr.w_delay = 0; tr.bready_delay = 0; tr.rready_delay = 0;
        return tr;
    endfunction
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        control_axil_item tr;
        if (!$cast(tr, bus_item)) begin rw.status = UVM_NOT_OK; return; end
        rw.kind = tr.is_write ? UVM_WRITE : UVM_READ;
        rw.addr = tr.addr;
        rw.data = tr.is_write ? tr.data : tr.rdata;
        rw.byte_en = tr.strb;
        rw.status = (tr.resp == 2'b00) ? UVM_IS_OK : UVM_NOT_OK;
    endfunction
endclass
