class ai_compute_cluster_e2e_test extends ai_base_test;
    `uvm_component_utils(ai_compute_cluster_e2e_test)
    virtual ai_compute_cluster_if compute_vif;

    function new(string name = "ai_compute_cluster_e2e_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_compute_cluster_if)::get(this, "", "compute_vif", compute_vif))
            `uvm_fatal("CLUSTER_NOVIF", "compute-cluster UVM test requires compute_vif")
    endfunction

    task run_phase(uvm_phase phase);
        ai_compute_cluster_e2e_seq seq;
        phase.raise_objection(this, "run real Matrix/SFU cluster and shared-SPAD test");
        seq = ai_compute_cluster_e2e_seq::type_id::create("compute_cluster_e2e_seq");
        seq.compute_vif = compute_vif;
        seq.start(env.axil_agent.sequencer);
        phase.drop_objection(this, "real compute cluster checks completed");
    endtask
endclass
