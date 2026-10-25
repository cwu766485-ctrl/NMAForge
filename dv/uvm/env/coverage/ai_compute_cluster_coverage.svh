`uvm_analysis_imp_decl(_compute_coverage)
class ai_compute_cluster_coverage extends uvm_component;
    `uvm_component_utils(ai_compute_cluster_coverage)
    uvm_analysis_imp_compute_coverage #(ai_compute_cluster_obs, ai_compute_cluster_coverage) analysis_export;
    int engine_id;
    int active_count;
    int response_client;
    bit matrix_sfu_overlap;
    bit simultaneous_engine_requests;
    bit banked_request;
    bit cnm_request;

    covergroup cluster_cg;
        option.per_instance = 1;
        cp_engine: coverpoint engine_id iff (engine_id >= 0) {
            bins scalar = {0}; bins fp = {1}; bins cnm = {2}; bins matrix = {3};
            bins sfu = {4}; bins conv = {5}; bins kv = {6};
        }
        cp_active_count: coverpoint active_count {
            bins idle = {0}; bins single = {1}; bins multi = {[2:7]};
        }
        cp_matrix_sfu_overlap: coverpoint matrix_sfu_overlap { bins hit = {1}; }
        cp_simultaneous_engine_requests: coverpoint simultaneous_engine_requests { bins hit = {1}; }
        cp_banked_request: coverpoint banked_request { bins hit = {1}; }
        cp_cnm_request: coverpoint cnm_request { bins hit = {1}; }
        cp_response_client: coverpoint response_client iff (response_client >= 0) {
            bins descriptor = {0}; bins completion = {1}; bins core = {2};
            bins banked = {3}; bins dma = {4};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        cluster_cg = new();
    endfunction

    function automatic int decode_engine(bit [7:0] op);
        if (op >= 8'h10 && op <= 8'h15) return 0;
        if (op == 8'h50 || op == 8'h51) return 1;
        if (op == 8'h20 || op == 8'h21) return 2;
        if (op == 8'h30 || op == 8'h31) return 3;
        if (op >= 8'h32 && op <= 8'h39) return 4;
        if (op == 8'h16 || op == 8'h17) return 5;
        if (op == 8'h43 || op == 8'h44) return 6;
        return -1;
    endfunction

    function void write_compute_coverage(ai_compute_cluster_obs obs);
        engine_id = obs.launch_valid ? decode_engine(obs.launch_op) : -1;
        active_count = $countones(obs.engine_busy);
        matrix_sfu_overlap = obs.engine_busy[3] && obs.engine_busy[4];
        simultaneous_engine_requests = $countones(obs.engine_req_valid) > 1;
        banked_request = obs.banked_valid;
        cnm_request = |obs.cnm_valid;
        response_client = obs.rsp_valid ? obs.rsp_client : -1;
        if (obs.launch_valid || active_count > 0 || simultaneous_engine_requests ||
            banked_request || cnm_request || obs.rsp_valid)
            cluster_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("CLUSTER_COVERAGE", $sformatf("focused_compute_cg=%0.1f%%", cluster_cg.get_coverage()), UVM_LOW)
    endfunction
endclass
