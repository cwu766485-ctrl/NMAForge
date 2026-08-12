class ai_axi4_coverage extends uvm_subscriber #(ai_axi4_observed_item);
    `uvm_component_utils(ai_axi4_coverage)
    covergroup cg with function sample(int kind,bit [3:0] id,bit [2:0] size,bit [7:0] len);
        cp_kind:coverpoint kind; cp_id:coverpoint id {bins desc={0};bins dma={[1:4]};bins write_rsp={[8:11]};bins other=default;} cp_size:coverpoint size {bins narrow32={2};bins wide128={4};bins invalid=default;} cp_len:coverpoint len {bins single={0};bins burst={[1:15]};bins oversized={[16:255]};} kind_x_size:cross cp_kind,cp_size;
    endgroup
    function new(string name,uvm_component parent); super.new(name,parent); cg=new(); endfunction
    function void write(ai_axi4_observed_item t); cg.sample(int'(t.kind),t.id,t.size,t.len); endfunction
endclass
