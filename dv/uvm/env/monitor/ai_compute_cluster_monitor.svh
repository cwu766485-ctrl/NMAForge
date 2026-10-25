class ai_compute_cluster_monitor extends uvm_component;
    `uvm_component_utils(ai_compute_cluster_monitor)
    virtual ai_compute_cluster_if vif;
    uvm_analysis_port #(ai_compute_cluster_obs) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_compute_cluster_if)::get(this, "", "compute_vif", vif))
            `uvm_fatal("NOCOMPUTEVIF", "compute-cluster monitor requires compute_vif")
    endfunction

    task run_phase(uvm_phase phase);
        ai_compute_cluster_obs obs;
        forever begin
            @(posedge vif.aclk);
            if (!vif.aresetn || vif.launch_valid || (|vif.engine_busy) ||
                (|vif.engine_done) || (|vif.engine_req_valid) ||
                vif.core_spad_valid || vif.banked_valid ||
                (|vif.cnm_valid) || vif.rsp_valid || (|vif.read_accept_mask)) begin
                obs = ai_compute_cluster_obs::type_id::create("obs");
                obs.reset_active = !vif.aresetn;
                obs.core_busy = vif.core_busy;
                obs.launch_valid = vif.launch_valid;
                obs.launch_op = vif.launch_op;
                obs.engine_busy = vif.engine_busy;
                obs.engine_done = vif.engine_done;
                obs.engine_error = vif.engine_error;
                obs.engine_req_valid = vif.engine_req_valid;
                obs.core_spad_valid = vif.core_spad_valid;
                obs.banked_valid = vif.banked_valid;
                obs.cnm_valid = vif.cnm_valid;
                obs.rsp_valid = vif.rsp_valid;
                obs.rsp_client = vif.rsp_client;
                obs.request_client = vif.request_client;
                obs.read_accept_mask = vif.read_accept_mask;
                ap.write(obs);
            end
        end
    endtask
endclass
