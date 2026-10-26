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
        if (env.compute_coverage.response_client_hits[4] == 0)
            `uvm_fatal("CLUSTER_DMA_RESPONSE", "real DMA SPAD-read response-client bin was not hit")
        if (env.compute_coverage.response_client_hits[1] != 0)
            `uvm_fatal("CLUSTER_CPL_RESPONSE_WAIVER", $sformatf(
                "completion writer unexpectedly issued %0d scratchpad reads; review the write-only waiver",
                env.compute_coverage.response_client_hits[1]))
        `uvm_info("CLUSTER_RESPONSE_CLIENT_DISPOSITION", $sformatf(
            "DMA read-response bin=%0d PASS; completion read-response bin=%0d WAIVED (completion writer is write-only)",
            env.compute_coverage.response_client_hits[4],
            env.compute_coverage.response_client_hits[1]), UVM_LOW)
        `uvm_info("CLUSTER_RECOVERY_DISPOSITION", $sformatf(
            "reset_dropped_accepted_reads=%0d stale_responses=%0d",
            env.compute_scoreboard.reset_dropped_reads,
            env.compute_scoreboard.stale_epoch_responses), UVM_LOW)
        phase.drop_objection(this, "real compute cluster checks completed");
    endtask
endclass
