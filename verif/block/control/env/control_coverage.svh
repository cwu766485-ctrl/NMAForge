`uvm_analysis_imp_decl(_cov)
class control_coverage extends uvm_component;
    `uvm_component_utils(control_coverage)
    uvm_analysis_imp_cov #(control_axil_item, control_coverage) cov_imp;
    bit sample_write; bit [8:0] sample_addr; bit [3:0] sample_strb; bit [1:0] sample_resp;
    covergroup cg;
        cp_dir: coverpoint sample_write;
        cp_window: coverpoint sample_addr[8:5] { bins control[] = {[0:13]}; bins invalid = default; }
        cp_strb: coverpoint sample_strb { bins full = {4'hf}; bins partial[] = {[0:14]}; }
        cp_resp: coverpoint sample_resp { bins okay = {2'b00}; bins slverr = {2'b10}; }
        cross_dir_resp: cross cp_dir, cp_resp;
    endgroup
    function new(string name, uvm_component parent);
        super.new(name, parent); cov_imp = new("cov_imp", this); cg = new;
    endfunction
    function void write_cov(control_axil_item tr);
        sample_write = tr.is_write; sample_addr = tr.addr[8:0];
        sample_strb = tr.strb; sample_resp = tr.resp; cg.sample();
    endfunction
    function void report_phase(uvm_phase phase);
        `uvm_info("CTRL_COVERAGE", $sformatf("AXI-Lite control functional coverage = %0.2f%%", cg.get_coverage()), UVM_LOW)
    endfunction
endclass
