class ai_version_smoke_seq extends uvm_sequence #(ai_axil_item);
    `uvm_object_utils(ai_version_smoke_seq)

    function new(string name = "ai_version_smoke_seq");
        super.new(name);
    endfunction

    task body();
        ai_axil_item req = ai_axil_item::type_id::create("read_version");

        start_item(req);
        req.is_write = 0;
        req.addr     = CIMFORGE_REG_VERSION;
        req.data     = '0;
        req.strb     = '0;
        finish_item(req);

        if (req.resp != 0) begin
            `uvm_error("VERSION", $sformatf("VERSION read response=%0h", req.resp))
        end else if (req.rdata != CIMFORGE_VERSION_A10) begin
            `uvm_error("VERSION", $sformatf(
                "VERSION expected=0x%08h got=0x%08h",
                CIMFORGE_VERSION_A10, req.rdata))
        end else begin
            `uvm_info("VERSION", $sformatf(
                "NMAForge A10 VERSION=0x%08h", req.rdata), UVM_LOW)
        end
    endtask
endclass
