`uvm_analysis_imp_decl(_ctrl)
class control_scoreboard extends uvm_component;
    `uvm_component_utils(control_scoreboard)
    uvm_analysis_imp_ctrl #(control_axil_item, control_scoreboard) ctrl_imp;
    int unsigned observed, okay, slverr;
    function new(string name, uvm_component parent);
        super.new(name, parent); ctrl_imp = new("ctrl_imp", this);
    endfunction
    function void write_ctrl(control_axil_item tr);
        observed++;
        if (tr.resp == 2'b00) okay++;
        else if (tr.resp == 2'b10) slverr++;
        else `uvm_error("AXIL_RESP", $sformatf("unsupported AXI-Lite response %0h at %08h", tr.resp, tr.addr))
        if (!tr.is_write && ((^tr.rdata) === 1'bx))
            `uvm_error("AXIL_X", $sformatf("X read data at %08h", tr.addr))
    endfunction
    function void report_phase(uvm_phase phase);
        `uvm_info("CTRL_SB", $sformatf("observed=%0d okay=%0d slverr=%0d", observed, okay, slverr), UVM_LOW)
    endfunction
endclass
