package ai_parallel_compute_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class ai_parallel_compute_uvm_test extends uvm_test;
        `uvm_component_utils(ai_parallel_compute_uvm_test)

        virtual ai_parallel_compute_if vif;

        function new(string name="ai_parallel_compute_uvm_test", uvm_component parent=null);
            super.new(name,parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual ai_parallel_compute_if)::get(this,"","cl_vif",vif))
                `uvm_fatal("NOVIF","ai_parallel_compute_if was not configured")
        endfunction

        task run_phase(uvm_phase phase);
            phase.raise_objection(this,"run parallel dispatcher and SPAD MUX campaign");
            `uvm_info("PARALLEL_UVM","starting ordered dispatch/retirement, SPAD owner and recovery campaign",UVM_LOW)
            vif.run_campaign();
            `uvm_info("PARALLEL_UVM","all directed parallel compute scenarios passed",UVM_LOW)
            phase.drop_objection(this,"campaign complete");
        endtask
    endclass
endpackage
