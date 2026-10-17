class ai_external_macro_ddr_e2e_test extends ai_base_test;
    `uvm_component_utils(ai_external_macro_ddr_e2e_test)

    function new(string name = "ai_external_macro_ddr_e2e_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        uvm_config_db#(bit)::set(this, "env.scoreboard", "check_external_macro_fetch", 1'b1);
        uvm_config_db#(int unsigned)::set(this, "env.scoreboard", "expected_external_macro_fetch_count", 3);
        super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        ai_external_macro_ddr_e2e_seq seq;
        phase.raise_objection(this, "run ABI-v7 external macro child-list through top-level AXI");
        seq = ai_external_macro_ddr_e2e_seq::type_id::create("external_macro_ddr_e2e_seq");
        seq.start(env.axil_agent.sequencer);
        phase.drop_objection(this, "external macro E2E checks complete");
    endtask
endclass
