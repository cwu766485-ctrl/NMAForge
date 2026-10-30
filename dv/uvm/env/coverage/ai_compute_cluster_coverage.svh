`uvm_analysis_imp_decl(_compute_coverage)
class ai_compute_cluster_coverage extends uvm_component;
    `uvm_component_utils(ai_compute_cluster_coverage)
    uvm_analysis_imp_compute_coverage #(ai_compute_cluster_obs, ai_compute_cluster_coverage) analysis_export;
    int engine_id;
    int active_count;
    int response_client;
    bit matrix_sfu_overlap;
    bit simultaneous_engine_requests;
    bit engine_backpressure;
    bit multi_engine_abort;
    bit banked_request;
    bit cnm_request;
    bit matrix_prefetch_active;
    bit matrix_a_cache_hit;
    bit matrix_banked_fault_cancel;
    bit cplq_full;
    int response_route;
    bit cnm_lane0_response;
    bit cnm_lane1_response;
    bit cnm_lane2_response;
    bit cnm_lane3_response;
    int unsigned response_client_hits[0:5];
    int unsigned matrix_banked_fault_cancel_hits;
    int unsigned cplq_full_hits;

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
        cp_engine_backpressure: coverpoint engine_backpressure { bins hit = {1}; }
        cp_multi_engine_abort: coverpoint multi_engine_abort { bins hit = {1}; }
        cp_banked_request: coverpoint banked_request { bins hit = {1}; }
        cp_cnm_request: coverpoint cnm_request { bins hit = {1}; }
        cp_matrix_prefetch_active: coverpoint matrix_prefetch_active { bins hit = {1}; }
        cp_matrix_a_cache_hit: coverpoint matrix_a_cache_hit { bins hit = {1}; }
        cp_matrix_banked_fault_cancel: coverpoint matrix_banked_fault_cancel {
            bins parity_response_cancels_held_unaccepted_read = {1};
        }
        cp_cplq_full: coverpoint cplq_full {
            bins full_completion_queue = {1};
        }
        cp_response_client: coverpoint response_client iff (response_client >= 0) {
            bins descriptor = {0};
            // ai_completion_writer only emits SPAD writes (spad_write=spad_valid),
            // so a completion read response cannot occur in this interface contract.
            // Keep the runtime zero-hit checker and disposition log; exclude only
            // this structurally inapplicable read-response bin from applicable coverage.
            ignore_bins completion_read_response_not_applicable = {1};
            bins core = {2};
            bins banked = {3}; bins dma = {4}; bins cnm = {5};
        }
        cp_response_route: coverpoint response_route iff ((response_client == 3) || (response_client == 5)) {
            bins matrix_only = {2}; bins cnm_only = {1};
            illegal_bins dropped_or_aliased = {0, 3};
        }
        cp_cnm_lane0_response: coverpoint cnm_lane0_response iff (response_client == 5) { bins hit = {1}; }
        cp_cnm_lane1_response: coverpoint cnm_lane1_response iff (response_client == 5) { bins hit = {1}; }
        cp_cnm_lane2_response: coverpoint cnm_lane2_response iff (response_client == 5) { bins hit = {1}; }
        cp_cnm_lane3_response: coverpoint cnm_lane3_response iff (response_client == 5) { bins hit = {1}; }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        cluster_cg = new();
        matrix_banked_fault_cancel_hits = 0;
        cplq_full_hits = 0;
        foreach (response_client_hits[i]) response_client_hits[i] = 0;
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
        // Sensitivity probes alter the passive observation copy to verify a
        // checker. They are not legal DUT stimulus and must not contaminate
        // functional coverage bins or hit illegal bins.
        if (obs.mutation_probe) return;
        engine_id = obs.launch_valid ? decode_engine(obs.launch_op) : -1;
        active_count = $countones(obs.engine_busy);
        matrix_sfu_overlap = obs.engine_busy[3] && obs.engine_busy[4];
        simultaneous_engine_requests = $countones(obs.engine_req_valid) > 1;
        engine_backpressure = obs.engine_backpressure;
        multi_engine_abort = obs.multi_engine_abort;
        banked_request = obs.banked_valid;
        cnm_request = |obs.cnm_valid;
        matrix_prefetch_active = obs.matrix_prefetch_active;
        matrix_a_cache_hit = obs.matrix_a_cache_hit;
        matrix_banked_fault_cancel = obs.matrix_banked_fault_cancel;
        cplq_full = obs.cplq_full;
        if (matrix_banked_fault_cancel)
            matrix_banked_fault_cancel_hits++;
        if (cplq_full)
            cplq_full_hits++;
        response_client = obs.rsp_valid ? obs.rsp_client : -1;
        if (obs.rsp_valid && obs.rsp_client <= 3'd5)
            response_client_hits[obs.rsp_client]++;
        response_route = {obs.matrix_rsp_valid, (|obs.cnm_rsp_valid)};
        cnm_lane0_response = obs.cnm_rsp_valid[0];
        cnm_lane1_response = obs.cnm_rsp_valid[1];
        cnm_lane2_response = obs.cnm_rsp_valid[2];
        cnm_lane3_response = obs.cnm_rsp_valid[3];
        if (obs.launch_valid || active_count > 0 || simultaneous_engine_requests ||
            banked_request || cnm_request || obs.rsp_valid ||
            engine_backpressure || multi_engine_abort ||
            matrix_prefetch_active || matrix_a_cache_hit ||
            matrix_banked_fault_cancel || cplq_full)
            cluster_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("CLUSTER_COVERAGE", $sformatf(
            "focused_compute_cg_applicable=%0.1f%% response_clients={desc:%0d,cpl_read:%0d(N/A),core:%0d,banked:%0d,dma:%0d,cnm:%0d} matrix_banked_fault_cancel=%0d cplq_full=%0d",
            cluster_cg.get_coverage(), response_client_hits[0], response_client_hits[1],
            response_client_hits[2], response_client_hits[3], response_client_hits[4],
            response_client_hits[5], matrix_banked_fault_cancel_hits,
            cplq_full_hits), UVM_LOW)
    endfunction
endclass
