class ai_version_smoke_test extends ai_base_test;
    `uvm_component_utils(ai_version_smoke_test)
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    task run_phase(uvm_phase phase);
        ai_version_smoke_seq seq;
        phase.raise_objection(this); seq=ai_version_smoke_seq::type_id::create("seq"); seq.start(env.axil_agent.sequencer); phase.drop_objection(this);
    endtask
endclass
