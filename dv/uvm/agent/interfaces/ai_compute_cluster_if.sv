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
    logic [31:0] launch_src0, launch_src1, launch_dst;
    logic [15:0] launch_length, launch_m, launch_n, launch_k;
    logic [4:0] launch_shift;
    logic [1:0] launch_activation;
    logic [31:0] launch_bias_base;
    logic launch_bias_enable;
    logic [7:0] launch_flags;
    logic [31:0] launch_aux0;
    logic [31:0] launch_src0_stride, launch_src1_stride, launch_dst_stride;
    logic [6:0] engine_busy;
    logic [6:0] engine_done;
    logic [6:0] engine_error;
    logic dut_abort_active;
    logic [6:0] engine_req_valid;
    logic [6:0] engine_req_ready;
    logic [6:0] engine_req_write;
    logic [223:0] engine_req_addr, engine_req_wdata;
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
    logic [31:0] matrix_line_addr;
    logic [127:0] matrix_line_wdata;
    logic [15:0] matrix_line_wstrb;
    logic dma_valid, dma_write, dma_ready;
    logic dma_line_valid, dma_line_write, dma_line_ready;
    logic matrix_prefetch_active;
    logic matrix_a_cache_hit;
    logic [31:0] matrix_a_cache_hits;
    logic [31:0] matrix_prefetch_overlap_cycles;
    logic [5:0] read_accept_mask;

    // Passive scratchpad transaction view consumed by the independent memory
    // image scoreboard. Host writes seed the image; scheduler writes update
    // it; tagged read responses are checked against their request-time snapshot.
    logic host_valid, host_write, host_access_ok;
    logic [31:0] host_addr, host_wdata;
    logic [3:0] host_wstrb;
    logic selected_spad_valid, selected_spad_write, selected_spad_ready;
    logic selected_spad_access_ok;
    logic [31:0] selected_spad_addr, selected_spad_wdata;
    logic selected_line_valid, selected_line_write, selected_line_ready;
    logic selected_line_access_ok;
    logic [31:0] selected_line_addr;
    logic [127:0] selected_line_wdata, selected_line_rdata;
    logic [15:0] selected_line_wstrb;
    logic selected_banked_valid, selected_banked_ready, selected_banked_access_ok;
    logic [31:0] selected_banked_addr;
    logic [31:0] banked_rdata[0:3];
    logic [3:0] selected_cnm_valid, selected_cnm_ready, selected_cnm_access_ok;
    logic [31:0] selected_cnm_addr[0:3];
    logic [31:0] cnm_rdata[0:3];
    logic selected_rsp_is_line, selected_rsp_error;
    logic [31:0] selected_rsp_rdata;

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
    integer engine_backpressure_cycles;
    logic [6:0] engine_backpressure_seen;
    integer multi_engine_abort_cycles;
    integer engine_launch_count[0:6];
    integer unsigned sim_cycles;

    // Launch and request-stability evidence is kept in the passive interface
    // so the real-top sequence can check sampling and backpressure behavior.
    integer unsigned launch_sample_count;
    logic [6:0] launch_sample_seen;
    logic [31:0] launch_snapshot_src0[0:6], launch_snapshot_src1[0:6];
    logic [31:0] launch_snapshot_dst[0:6], launch_snapshot_aux0[0:6];
    logic [31:0] launch_snapshot_src0_stride[0:6];
    logic [31:0] launch_snapshot_src1_stride[0:6];
    logic [31:0] launch_snapshot_dst_stride[0:6];
    logic [15:0] launch_snapshot_length[0:6];
    logic [15:0] launch_snapshot_m[0:6], launch_snapshot_n[0:6];
    logic [15:0] launch_snapshot_k[0:6];
    logic [4:0] launch_snapshot_shift[0:6];
    logic [1:0] launch_snapshot_activation[0:6];
    logic [31:0] launch_snapshot_bias_base[0:6];
    logic launch_snapshot_bias_enable[0:6];
    logic [7:0] launch_snapshot_flags[0:6];
    integer unsigned engine_req_stall_checks[0:6];
    integer unsigned engine_req_stall_cycles[0:6];
    logic [6:0] engine_req_stall_seen;
    integer unsigned engine_req_stability_violations;
    logic [6:0] req_stalled_previous, req_write_previous;
    logic [31:0] req_addr_previous[0:6], req_wdata_previous[0:6];
    integer unsigned matrix_banked_stall_checks;
    integer unsigned matrix_banked_stall_violations;
    logic matrix_banked_stalled_previous;
    logic [31:0] matrix_banked_addr_previous;
    integer unsigned matrix_line_stall_checks;
    integer unsigned matrix_line_stall_violations;
    logic matrix_line_stalled_previous;
    logic matrix_line_write_previous;
    logic [31:0] matrix_line_addr_previous;
    logic [127:0] matrix_line_wdata_previous;
    logic [15:0] matrix_line_wstrb_previous;
    integer unsigned cnm_stall_checks[0:3];
    integer unsigned cnm_stall_violations;
    logic [3:0] cnm_stalled_previous;
    logic [31:0] cnm_addr_previous[0:3];

    // Monotonic testbench clock counter for comparable wall-cycle timing.
    // It intentionally survives accelerator reset so recovery intervals remain
    // measurable in the same run.
    initial sim_cycles = 0;
    always @(posedge aclk) sim_cycles = sim_cycles + 1;

    initial begin
        integer e;
        launch_sample_count = 0;
        launch_sample_seen = '0;
        engine_req_stall_seen = '0;
        engine_req_stability_violations = 0;
        req_stalled_previous = '0;
        matrix_banked_stall_checks = 0;
        matrix_banked_stall_violations = 0;
        matrix_banked_stalled_previous = 1'b0;
        matrix_line_stall_checks = 0;
        matrix_line_stall_violations = 0;
        matrix_line_stalled_previous = 1'b0;
        cnm_stall_violations = 0;
        cnm_stalled_previous = '0;
        for (e = 0; e < 7; e++) begin
            engine_req_stall_checks[e] = 0;
            engine_req_stall_cycles[e] = 0;
            req_write_previous[e] = 1'b0;
            req_addr_previous[e] = '0;
            req_wdata_previous[e] = '0;
            launch_snapshot_src0[e] = '0;
            launch_snapshot_src1[e] = '0;
            launch_snapshot_dst[e] = '0;
            launch_snapshot_aux0[e] = '0;
            launch_snapshot_src0_stride[e] = '0;
            launch_snapshot_src1_stride[e] = '0;
            launch_snapshot_dst_stride[e] = '0;
            launch_snapshot_length[e] = '0;
            launch_snapshot_m[e] = '0;
            launch_snapshot_n[e] = '0;
            launch_snapshot_k[e] = '0;
            launch_snapshot_shift[e] = '0;
            launch_snapshot_activation[e] = '0;
            launch_snapshot_bias_base[e] = '0;
            launch_snapshot_bias_enable[e] = 1'b0;
            launch_snapshot_flags[e] = '0;
        end
        for (e = 0; e < 4; e++) begin
            cnm_stall_checks[e] = 0;
            cnm_addr_previous[e] = '0;
        end
    end

    // Check source-side payload stability through backpressure. Abort/reset
    // terminate the obligation according to the interface exception.
    always @(posedge aclk) begin : request_stability_monitor
        integer e;
        integer engine;
        if (!aresetn || dut_abort_active) begin
            req_stalled_previous = '0;
            matrix_banked_stalled_previous = 1'b0;
            matrix_line_stalled_previous = 1'b0;
            cnm_stalled_previous = '0;
        end else begin
            if (launch_valid) begin
                engine = engine_id(launch_op);
                if (engine >= 0) begin
                    launch_sample_count = launch_sample_count + 1;
                    launch_sample_seen[engine] = 1'b1;
                    launch_snapshot_src0[engine] = launch_src0;
                    launch_snapshot_src1[engine] = launch_src1;
                    launch_snapshot_dst[engine] = launch_dst;
                    launch_snapshot_length[engine] = launch_length;
                    launch_snapshot_m[engine] = launch_m;
                    launch_snapshot_n[engine] = launch_n;
                    launch_snapshot_k[engine] = launch_k;
                    launch_snapshot_shift[engine] = launch_shift;
                    launch_snapshot_activation[engine] = launch_activation;
                    launch_snapshot_bias_base[engine] = launch_bias_base;
                    launch_snapshot_bias_enable[engine] = launch_bias_enable;
                    launch_snapshot_flags[engine] = launch_flags;
                    launch_snapshot_aux0[engine] = launch_aux0;
                    launch_snapshot_src0_stride[engine] = launch_src0_stride;
                    launch_snapshot_src1_stride[engine] = launch_src1_stride;
                    launch_snapshot_dst_stride[engine] = launch_dst_stride;
                end
            end

            for (e = 0; e < 7; e++) begin
                if (req_stalled_previous[e]) begin
                    engine_req_stall_checks[e] = engine_req_stall_checks[e] + 1;
                    if (!engine_req_valid[e] ||
                        engine_req_write[e] !== req_write_previous[e] ||
                        engine_req_addr[e*32 +: 32] !== req_addr_previous[e] ||
                        engine_req_wdata[e*32 +: 32] !== req_wdata_previous[e])
                        engine_req_stability_violations = engine_req_stability_violations + 1;
                end
                req_stalled_previous[e] = engine_req_valid[e] && !engine_req_ready[e];
                if (req_stalled_previous[e]) begin
                    engine_req_stall_cycles[e] = engine_req_stall_cycles[e] + 1;
                    engine_req_stall_seen[e] = 1'b1;
                    req_write_previous[e] = engine_req_write[e];
                    req_addr_previous[e] = engine_req_addr[e*32 +: 32];
                    req_wdata_previous[e] = engine_req_wdata[e*32 +: 32];
                end
            end

            if (matrix_banked_stalled_previous) begin
                matrix_banked_stall_checks++;
                if (!matrix_request_valid ||
                    matrix_banked_req_addr !== matrix_banked_addr_previous)
                    matrix_banked_stall_violations++;
            end
            matrix_banked_stalled_previous = matrix_request_valid && !banked_ready;
            if (matrix_banked_stalled_previous)
                matrix_banked_addr_previous = matrix_banked_req_addr;

            if (matrix_line_stalled_previous) begin
                matrix_line_stall_checks++;
                if (!matrix_line_valid || matrix_line_write !== matrix_line_write_previous ||
                    matrix_line_addr !== matrix_line_addr_previous ||
                    matrix_line_wdata !== matrix_line_wdata_previous ||
                    matrix_line_wstrb !== matrix_line_wstrb_previous)
                    matrix_line_stall_violations++;
            end
            matrix_line_stalled_previous = matrix_line_valid && !matrix_line_ready;
            if (matrix_line_stalled_previous) begin
                matrix_line_write_previous = matrix_line_write;
                matrix_line_addr_previous = matrix_line_addr;
                matrix_line_wdata_previous = matrix_line_wdata;
                matrix_line_wstrb_previous = matrix_line_wstrb;
            end

            for (e = 0; e < 4; e++) begin
                if (cnm_stalled_previous[e]) begin
                    cnm_stall_checks[e]++;
                    if (!cnm_request_valid[e] ||
                        cnm_req_addr[e] !== cnm_addr_previous[e])
                        cnm_stall_violations++;
                end
                cnm_stalled_previous[e] = cnm_request_valid[e] && !cnm_request_ready[e];
                if (cnm_stalled_previous[e])
                    cnm_addr_previous[e] = cnm_req_addr[e];
            end
        end
    end

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
            engine_backpressure_cycles <= 0;
            engine_backpressure_seen <= 7'd0;
            multi_engine_abort_cycles <= 0;
            for (e = 0; e < 7; e = e + 1) engine_launch_count[e] <= 0;
        end else begin
            if ($countones(engine_busy) > 1) overlap_cycles <= overlap_cycles + 1;
            if ($countones(engine_req_valid) > 1)
                core_engine_collision_cycles <= core_engine_collision_cycles + 1;
            if (|(engine_req_valid & ~engine_req_ready)) begin
                engine_backpressure_cycles <= engine_backpressure_cycles + 1;
                engine_backpressure_seen <= engine_backpressure_seen |
                                            (engine_req_valid & ~engine_req_ready);
            end
            if (($countones(engine_busy) > 1) && dut_abort_active)
                multi_engine_abort_cycles <= multi_engine_abort_cycles + 1;
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
