`uvm_analysis_imp_decl(_axil)
`uvm_analysis_imp_decl(_axi4)
class ai_accel_scoreboard extends uvm_component;
    `uvm_component_utils(ai_accel_scoreboard)
    uvm_analysis_imp_axil #(ai_axil_item,ai_accel_scoreboard) axil_imp;
    uvm_analysis_imp_axi4 #(ai_axi4_observed_item,ai_accel_scoreboard) axi4_imp;
    bit allow_error_responses; int unsigned axil_count,axi4_count;
    function new(string name,uvm_component parent); super.new(name,parent); axil_imp=new("axil_imp",this); axi4_imp=new("axi4_imp",this); endfunction
    function void write_axil(ai_axil_item tr); axil_count++; if((tr.resp!=0)&&!allow_error_responses) `uvm_error("AXIL_RESP",$sformatf("Unexpected AXI-Lite response addr=0x%08h resp=%0h",tr.addr,tr.resp)) endfunction
    function void write_axi4(ai_axi4_observed_item tr);
        axi4_count++;
        if((tr.kind==AXI_AR||tr.kind==AXI_AW)&&((tr.size!=3'd2&&tr.size!=3'd4)||tr.burst!=2'b01)) `uvm_error("AXI_CFG",$sformatf("Unsupported AXI request size=%0d burst=%0d",tr.size,tr.burst))
        if((tr.kind==AXI_R||tr.kind==AXI_B)&&(tr.resp!=0)&&!allow_error_responses) `uvm_error("AXI_RESP",$sformatf("Unexpected AXI response id=%0d resp=%0h",tr.id,tr.resp))
    endfunction
    function void report_phase(uvm_phase phase); `uvm_info("SB_SUMMARY",$sformatf("observed AXI-Lite=%0d AXI4=%0d",axil_count,axi4_count),UVM_LOW) endfunction
endclass
