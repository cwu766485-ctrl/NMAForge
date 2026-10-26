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
    int unsigned matrix_tag_responses;
    int unsigned cnm_tag_responses;
    int unsigned pending_reads[0:5];
    int unsigned cnm_pending_lane_reads[0:3];
    int unsigned cnm_lane_accepts[0:3];
    int unsigned cnm_lane_responses[0:3];

    function new(string name, uvm_component parent);
        int client;
        int lane;
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        for (client = 0; client < 6; client++) pending_reads[client] = 0;
        for (lane = 0; lane < 4; lane++) begin
            cnm_pending_lane_reads[lane] = 0;
            cnm_lane_accepts[lane] = 0;
            cnm_lane_responses[lane] = 0;
        end
    endfunction

    function void write_compute_cluster(ai_compute_cluster_obs obs);
        int client;
        int lane;
        observations++;
        if (obs.reset_active) begin
            for (client = 0; client < 6; client++) begin
                if (pending_reads[client] != 0)
                    reset_dropped_reads += pending_reads[client];
                pending_reads[client] = 0;
            end
            for (lane = 0; lane < 4; lane++) cnm_pending_lane_reads[lane] = 0;
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
            if (obs.rsp_client > 3'd5) begin
                orphan_responses++;
                `uvm_error("CLUSTER_RSP_CLIENT", $sformatf("response has illegal arbiter client=%0d", obs.rsp_client))
            end else if (pending_reads[obs.rsp_client] == 0) begin
                orphan_responses++;
                `uvm_error("CLUSTER_ORPHAN_RSP", $sformatf("response for client=%0d has no accepted read", obs.rsp_client))
            end else begin
                pending_reads[obs.rsp_client]--;
                if (obs.rsp_client == 3'd3) begin
                    matrix_tag_responses++;
                    if (!obs.matrix_rsp_valid || (|obs.cnm_rsp_valid))
                        `uvm_error("CLUSTER_MATRIX_RSP_ROUTE", $sformatf("Matrix tag routed incorrectly: matrix_valid=%b cnm_valid=%b", obs.matrix_rsp_valid, obs.cnm_rsp_valid))
                end else if (obs.rsp_client == 3'd5) begin
                    cnm_tag_responses++;
                    if (!(|obs.cnm_rsp_valid) || obs.matrix_rsp_valid)
                        `uvm_error("CLUSTER_CNM_RSP_ROUTE", $sformatf("CNM tag routed incorrectly: matrix_valid=%b cnm_valid=%b", obs.matrix_rsp_valid, obs.cnm_rsp_valid))
                end
            end
        end else if ((|obs.cnm_rsp_valid) || obs.matrix_rsp_valid) begin
            `uvm_error("CLUSTER_UNTAGGED_RSP", $sformatf("engine response route asserted without arbiter response: matrix=%b cnm=%b", obs.matrix_rsp_valid, obs.cnm_rsp_valid))
        end
        for (lane = 0; lane < 4; lane++) begin
            if (obs.cnm_rsp_valid[lane]) begin
                if (obs.rsp_client != 3'd5)
                    `uvm_error("CLUSTER_CNM_LANE_TAG", $sformatf("CNM lane %0d response has arbiter tag %0d", lane, obs.rsp_client))
                if (cnm_pending_lane_reads[lane] == 0)
                    `uvm_error("CLUSTER_CNM_ORPHAN_LANE", $sformatf("CNM lane %0d response has no accepted lane read", lane))
                else begin
                    cnm_pending_lane_reads[lane]--;
                    cnm_lane_responses[lane]++;
                end
            end
        end
        for (client = 0; client < 6; client++) begin
            if (obs.read_accept_mask[client]) begin
                pending_reads[client]++;
                accepted_reads++;
            end
        end
        for (lane = 0; lane < 4; lane++) begin
            if (obs.cnm_accept_mask[lane]) begin
                cnm_pending_lane_reads[lane]++;
                cnm_lane_accepts[lane]++;
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        int client;
        int lane;
        super.report_phase(phase);
        for (client = 0; client < 6; client++) begin
            if (pending_reads[client] != 0)
                `uvm_error("CLUSTER_RSP_DRAIN", $sformatf("client=%0d has %0d accepted reads without responses at test end", client, pending_reads[client]))
        end
        for (lane = 0; lane < 4; lane++) begin
            if (cnm_pending_lane_reads[lane] != 0)
                `uvm_error("CLUSTER_CNM_LANE_DRAIN", $sformatf("CNM lane=%0d has %0d accepted reads without response", lane, cnm_pending_lane_reads[lane]))
        end
        `uvm_info("CLUSTER_SCOREBOARD", $sformatf(
            "observations=%0d busy=%0d overlap=%0d done=%0d errors=%0d reads=%0d responses=%0d orphan=%0d reset_dropped=%0d matrix_rsp=%0d cnm_rsp=%0d cnm_lane_accepts={%0d,%0d,%0d,%0d} cnm_lane_responses={%0d,%0d,%0d,%0d} pending={%0d,%0d,%0d,%0d,%0d,%0d}",
            observations, busy_observations, overlap_observations,
            engine_done_events, engine_error_events, accepted_reads,
            spad_responses, orphan_responses, reset_dropped_reads,
            matrix_tag_responses, cnm_tag_responses,
            cnm_lane_accepts[0], cnm_lane_accepts[1], cnm_lane_accepts[2], cnm_lane_accepts[3],
            cnm_lane_responses[0], cnm_lane_responses[1], cnm_lane_responses[2], cnm_lane_responses[3],
            pending_reads[0], pending_reads[1], pending_reads[2],
            pending_reads[3], pending_reads[4], pending_reads[5]), UVM_LOW)
    endfunction
endclass
