`timescale 1ns/1ps

// Passive observation surface for the real top-level compute cluster path.
// All observed signals are connected in tb_ai_accel_uvm; this interface never
// drives the DUT.
interface ai_compute_cluster_if(input logic aclk);
    logic aresetn;
    logic core_busy;
    logic processor_busy;
    logic launch_valid;
    logic [7:0] launch_op;
    logic [6:0] engine_busy;
    logic [6:0] engine_done;
    logic [6:0] engine_error;
    logic [6:0] engine_req_valid;
    logic [6:0] engine_req_ready;
    logic core_spad_valid;
    logic banked_valid;
    logic [3:0] cnm_valid;
    logic core_ready;
    logic banked_ready;
    logic [3:0] cnm_ready;
    logic rsp_valid;
    logic [2:0] rsp_client;
    logic [2:0] request_client;
    logic matrix_rsp_valid;
    logic [3:0] cnm_rsp_valid;
    logic [3:0] cnm_request_valid;
    logic [3:0] cnm_request_ready;
    logic matrix_request_valid;
    logic [3:0] cnm_accept_mask;
    logic [2:0] cnm_core_state;
    logic [11:0] cnm_lane_state;
    logic [31:0] cnm_req_addr[0:3];
    logic [31:0] matrix_banked_req_addr;
    logic parallel_queue_mode;
    logic desc_valid, desc_ready;
    logic cpl_valid, cpl_write, cpl_ready;
    logic core_spad_write;
    logic matrix_line_valid, matrix_line_write, matrix_line_ready;
    logic dma_valid, dma_write, dma_ready;
    logic dma_line_valid, dma_line_write, dma_line_ready;
    logic matrix_prefetch_active;
    logic matrix_a_cache_hit;
    logic [31:0] matrix_a_cache_hits;
    logic [31:0] matrix_prefetch_overlap_cycles;
    logic [5:0] read_accept_mask;

    integer overlap_cycles;
    integer core_engine_collision_cycles;
    integer shared_spad_contention_cycles;
    integer arb_banked_grants;
    integer arb_cnm_grants;
    integer arb_core_grants;
    integer matrix_cnm_overlap_cycles;
    integer matrix_cnm_shared_accept_cycles;
    integer matrix_tag_response_count;
    integer cnm_tag_response_count;
    logic [3:0] cnm_response_lane_seen;
    integer matrix_route_mismatch_count;
    integer cnm_route_mismatch_count;
    integer response_count;
    integer same_engine_launch_while_busy;
    integer engine_launch_count[0:6];

    always_comb begin
        read_accept_mask[0] = desc_valid && desc_ready;
        read_accept_mask[1] = cpl_valid && cpl_ready && !cpl_write;
        read_accept_mask[2] = (core_spad_valid && core_ready && !core_spad_write) ||
                              (matrix_line_valid && matrix_line_ready && !matrix_line_write);
        read_accept_mask[3] = banked_valid && banked_ready;
        read_accept_mask[4] = (dma_valid && dma_ready && !dma_write) ||
                              (dma_line_valid && dma_line_ready && !dma_line_write);
        cnm_accept_mask = cnm_valid & cnm_ready;
        read_accept_mask[5] = |cnm_accept_mask;
    end

    function automatic integer engine_id(input logic [7:0] op);
        if (op >= 8'h10 && op <= 8'h15) engine_id = 0;
        else if (op == 8'h50 || op == 8'h51) engine_id = 1;
        else if (op == 8'h20 || op == 8'h21) engine_id = 2;
        else if (op == 8'h30 || op == 8'h31) engine_id = 3;
        else if (op >= 8'h32 && op <= 8'h39) engine_id = 4;
        else if (op == 8'h16 || op == 8'h17) engine_id = 5;
        else if (op == 8'h43 || op == 8'h44) engine_id = 6;
        else engine_id = -1;
    endfunction

    always @(posedge aclk or negedge aresetn) begin
        integer e;
        if (!aresetn) begin
            overlap_cycles <= 0;
            core_engine_collision_cycles <= 0;
            shared_spad_contention_cycles <= 0;
            arb_banked_grants <= 0;
            arb_cnm_grants <= 0;
            arb_core_grants <= 0;
            matrix_cnm_overlap_cycles <= 0;
            matrix_cnm_shared_accept_cycles <= 0;
            matrix_tag_response_count <= 0;
            cnm_tag_response_count <= 0;
            cnm_response_lane_seen <= 4'd0;
            matrix_route_mismatch_count <= 0;
            cnm_route_mismatch_count <= 0;
            response_count <= 0;
            same_engine_launch_while_busy <= 0;
            for (e = 0; e < 7; e = e + 1) engine_launch_count[e] <= 0;
        end else begin
            if ($countones(engine_busy) > 1) overlap_cycles <= overlap_cycles + 1;
            if ($countones(engine_req_valid) > 1)
                core_engine_collision_cycles <= core_engine_collision_cycles + 1;
            if (core_spad_valid && banked_valid && !(core_ready && banked_ready))
                shared_spad_contention_cycles <= shared_spad_contention_cycles + 1;
            if (banked_valid && banked_ready) arb_banked_grants <= arb_banked_grants + 1;
            if (|cnm_valid && |cnm_ready) arb_cnm_grants <= arb_cnm_grants + 1;
            if (core_spad_valid && core_ready) arb_core_grants <= arb_core_grants + 1;
            if (rsp_valid) response_count <= response_count + 1;
            if (parallel_queue_mode && engine_busy[2] && engine_busy[3])
                matrix_cnm_overlap_cycles <= matrix_cnm_overlap_cycles + 1;
            // Observe both requesters before the single-owner arbiter. Its
            // selected outputs are mutually exclusive by construction.
            if (matrix_request_valid && (|cnm_request_valid) &&
                (banked_ready || (|cnm_request_ready)))
                matrix_cnm_shared_accept_cycles <= matrix_cnm_shared_accept_cycles + 1;
            if (rsp_valid && rsp_client == 3'd3) begin
                matrix_tag_response_count <= matrix_tag_response_count + 1;
                if (!matrix_rsp_valid || (|cnm_rsp_valid))
                    matrix_route_mismatch_count <= matrix_route_mismatch_count + 1;
            end
            if (rsp_valid && rsp_client == 3'd5) begin
                cnm_tag_response_count <= cnm_tag_response_count + 1;
                cnm_response_lane_seen <= cnm_response_lane_seen | cnm_rsp_valid;
                if (!(|cnm_rsp_valid) || matrix_rsp_valid)
                    cnm_route_mismatch_count <= cnm_route_mismatch_count + 1;
            end
            if (launch_valid) begin
                if (engine_id(launch_op) >= 0) begin
                    engine_launch_count[engine_id(launch_op)] <=
                        engine_launch_count[engine_id(launch_op)] + 1;
                    if (engine_busy[engine_id(launch_op)])
                        same_engine_launch_while_busy <= same_engine_launch_while_busy + 1;
                end
            end
        end
    end
endinterface
