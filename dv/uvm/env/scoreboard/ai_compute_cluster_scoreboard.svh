`uvm_analysis_imp_decl(_compute_cluster)
class ai_compute_cluster_scoreboard extends uvm_component;
    `uvm_component_utils(ai_compute_cluster_scoreboard)
    uvm_analysis_imp_compute_cluster #(ai_compute_cluster_obs, ai_compute_cluster_scoreboard) analysis_export;
    int unsigned observations;
    int unsigned busy_observations;
    int unsigned overlap_observations;
    int unsigned engine_done_events;
    int unsigned engine_error_events;
    int unsigned spad_responses;
    int unsigned accepted_reads;
    int unsigned orphan_responses;
    int unsigned reset_dropped_reads;
    int unsigned pending_reads[0:4];

    function new(string name, uvm_component parent);
        int client;
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        for (client = 0; client < 5; client++) pending_reads[client] = 0;
    endfunction

    function void write_compute_cluster(ai_compute_cluster_obs obs);
        int client;
        observations++;
        if (obs.reset_active) begin
            for (client = 0; client < 5; client++) begin
                if (pending_reads[client] != 0)
                    reset_dropped_reads += pending_reads[client];
                pending_reads[client] = 0;
            end
            return;
        end
        if (obs.core_busy !== (|obs.engine_busy))
            `uvm_error("CLUSTER_BUSY", $sformatf("core_busy=%b engine_busy=%07b", obs.core_busy, obs.engine_busy))
        if (|obs.engine_busy) busy_observations++;
        if ($countones(obs.engine_busy) > 1) overlap_observations++;
        if (|obs.engine_done) engine_done_events++;
        if (|obs.engine_error) engine_error_events++;
        if (obs.rsp_valid) begin
            spad_responses++;
            if (obs.rsp_client > 3'd4) begin
                orphan_responses++;
                `uvm_error("CLUSTER_RSP_CLIENT", $sformatf("response has illegal arbiter client=%0d", obs.rsp_client))
            end else if (pending_reads[obs.rsp_client] == 0) begin
                orphan_responses++;
                `uvm_error("CLUSTER_ORPHAN_RSP", $sformatf("response for client=%0d has no accepted read", obs.rsp_client))
            end else begin
                pending_reads[obs.rsp_client]--;
            end
        end
        for (client = 0; client < 5; client++) begin
            if (obs.read_accept_mask[client]) begin
                pending_reads[client]++;
                accepted_reads++;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        int client;
        super.report_phase(phase);
        for (client = 0; client < 5; client++) begin
            if (pending_reads[client] != 0)
                `uvm_error("CLUSTER_RSP_DRAIN", $sformatf("client=%0d has %0d accepted reads without responses at test end", client, pending_reads[client]))
        end
        `uvm_info("CLUSTER_SCOREBOARD", $sformatf(
            "observations=%0d busy=%0d overlap=%0d done=%0d errors=%0d reads=%0d responses=%0d orphan=%0d reset_dropped=%0d pending={%0d,%0d,%0d,%0d,%0d}",
            observations, busy_observations, overlap_observations,
            engine_done_events, engine_error_events, accepted_reads,
            spad_responses, orphan_responses, reset_dropped_reads,
            pending_reads[0], pending_reads[1], pending_reads[2],
            pending_reads[3], pending_reads[4]), UVM_LOW)
    endfunction
endclass
