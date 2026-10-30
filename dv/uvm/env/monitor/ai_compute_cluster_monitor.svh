class ai_compute_cluster_monitor extends uvm_component;
    `uvm_component_utils(ai_compute_cluster_monitor)
    virtual ai_compute_cluster_if vif;
    uvm_analysis_port #(ai_compute_cluster_obs) ap;
    string mutation_kind;
    bit mutation_injected;
    bit [6:0] missing_done_pending;
    bit [6:0] duplicate_done_pending;
    int mutation_engine;
    bit write_prefix_pending;
    bit response_epoch_pending;
    int response_epoch_client;
    int pending_read_count[0:4];
    int unsigned matrix_fault_cancel_count_seen;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_compute_cluster_if)::get(this, "", "compute_vif", vif))
            `uvm_fatal("NOCOMPUTEVIF", "compute-cluster monitor requires compute_vif")
        mutation_kind = "";
        mutation_injected = 1'b0;
        missing_done_pending = '0;
        duplicate_done_pending = '0;
        mutation_engine = 0;
        write_prefix_pending = 1'b0;
        response_epoch_pending = 1'b0;
        response_epoch_client = 0;
        matrix_fault_cancel_count_seen = 0;
        for (int client = 0; client < 5; client++) pending_read_count[client] = 0;
        void'($value$plusargs("CL_MUTATION=%s", mutation_kind));
        void'($value$plusargs("CL_MUTATION_ENGINE=%d", mutation_engine));
    endfunction

    task run_phase(uvm_phase phase);
        ai_compute_cluster_obs obs;
        int lane;
        bit flush_missing_done;
        bit [6:0] sampled_engine_done;
        forever begin
            @(posedge vif.aclk);
            flush_missing_done = (missing_done_pending != 0);
            sampled_engine_done = vif.engine_done;
            if (!vif.aresetn || vif.host_valid || vif.selected_spad_valid ||
                vif.selected_line_valid || vif.selected_banked_valid ||
                (|vif.selected_cnm_valid) || vif.launch_valid || (|vif.engine_busy) ||
                (|vif.engine_done) || (|vif.engine_error) ||
                (|vif.engine_req_valid) ||
                vif.core_spad_valid || vif.banked_valid ||
                (|vif.cnm_valid) || vif.rsp_valid || vif.matrix_rsp_valid ||
                (|vif.cnm_rsp_valid) || (|vif.read_accept_mask) || vif.cplq_full ||
                vif.matrix_prefetch_active || vif.matrix_a_cache_hit ||
                (vif.matrix_banked_fault_cancel_checks !=
                 matrix_fault_cancel_count_seen) ||
                (missing_done_pending != 0) || (duplicate_done_pending != 0) ||
                write_prefix_pending || response_epoch_pending) begin
                obs = ai_compute_cluster_obs::type_id::create("obs");
                obs.reset_active = !vif.aresetn;
                obs.core_busy = vif.core_busy;
                obs.cplq_full = vif.cplq_full;
                obs.launch_valid = vif.launch_valid;
                obs.launch_op = vif.launch_op;
                obs.engine_busy = vif.engine_busy;
                obs.engine_done = vif.engine_done;
                obs.engine_error = vif.engine_error;
                obs.engine_req_valid = vif.engine_req_valid;
                obs.engine_req_ready = vif.engine_req_ready;
                obs.engine_backpressure = |(vif.engine_req_valid & ~vif.engine_req_ready);
                obs.multi_engine_abort = (vif.dut_abort_active &&
                                          ($countones(vif.engine_busy) > 1));
                obs.core_spad_valid = vif.core_spad_valid;
                obs.banked_valid = vif.banked_valid;
                obs.cnm_valid = vif.cnm_valid;
                obs.matrix_prefetch_active = vif.matrix_prefetch_active;
                obs.matrix_a_cache_hit = vif.matrix_a_cache_hit;
                obs.matrix_banked_fault_cancel =
                    (vif.matrix_banked_fault_cancel_checks !=
                     matrix_fault_cancel_count_seen);
                matrix_fault_cancel_count_seen =
                    vif.matrix_banked_fault_cancel_checks;
                obs.rsp_valid = vif.rsp_valid;
                obs.rsp_client = vif.rsp_client;
                obs.request_client = vif.request_client;
                obs.matrix_rsp_valid = vif.matrix_rsp_valid;
                obs.cnm_rsp_valid = vif.cnm_rsp_valid;
                obs.cnm_accept_mask = vif.cnm_accept_mask;
                obs.read_accept_mask = vif.read_accept_mask;
                obs.host_valid = vif.host_valid;
                obs.host_write = vif.host_write;
                obs.host_access_ok = vif.host_access_ok;
                obs.host_addr = vif.host_addr;
                obs.host_wdata = vif.host_wdata;
                obs.host_wstrb = vif.host_wstrb;
                obs.selected_spad_valid = vif.selected_spad_valid;
                obs.selected_spad_write = vif.selected_spad_write;
                obs.selected_spad_ready = vif.selected_spad_ready;
                obs.selected_spad_access_ok = vif.selected_spad_access_ok;
                obs.selected_spad_addr = vif.selected_spad_addr;
                obs.selected_spad_wdata = vif.selected_spad_wdata;
                obs.selected_line_valid = vif.selected_line_valid;
                obs.selected_line_write = vif.selected_line_write;
                obs.selected_line_ready = vif.selected_line_ready;
                obs.selected_line_access_ok = vif.selected_line_access_ok;
                obs.selected_line_addr = vif.selected_line_addr;
                obs.selected_line_wdata = vif.selected_line_wdata;
                obs.selected_line_wstrb = vif.selected_line_wstrb;
                obs.selected_line_rdata = vif.selected_line_rdata;
                obs.selected_banked_valid = vif.selected_banked_valid;
                obs.selected_banked_ready = vif.selected_banked_ready;
                obs.selected_banked_access_ok = vif.selected_banked_access_ok;
                obs.selected_banked_addr = vif.selected_banked_addr;
                obs.matrix_banked_req_addr = vif.matrix_banked_req_addr;
                obs.selected_cnm_valid = vif.selected_cnm_valid;
                obs.selected_cnm_ready = vif.selected_cnm_ready;
                obs.selected_cnm_access_ok = vif.selected_cnm_access_ok;
                for (lane = 0; lane < 4; lane++) begin
                    obs.banked_rdata[lane] = vif.banked_rdata[lane];
                    obs.selected_cnm_addr[lane] = vif.selected_cnm_addr[lane];
                    obs.cnm_rdata[lane] = vif.cnm_rdata[lane];
                end
                obs.selected_rsp_is_line = vif.selected_rsp_is_line;
                obs.selected_rsp_error = vif.selected_rsp_error;
                obs.selected_rsp_rdata = vif.selected_rsp_rdata;

                if (!vif.aresetn) begin
                    if (mutation_kind == "response_epoch") begin
                        for (lane = 0; lane < 5; lane++) begin
                            if ((pending_read_count[lane] != 0) &&
                                !response_epoch_pending && !mutation_injected) begin
                                response_epoch_client = lane;
                                response_epoch_pending = 1'b1;
                            end
                        end
                    end
                    for (lane = 0; lane < 5; lane++) pending_read_count[lane] = 0;
                end else begin
                    if (vif.rsp_valid && (vif.rsp_client < 5) &&
                        (pending_read_count[vif.rsp_client] != 0))
                        pending_read_count[vif.rsp_client]--;
                    for (lane = 0; lane < 5; lane++)
                        if (vif.read_accept_mask[lane]) pending_read_count[lane]++;
                end

                if ((mutation_kind == "response_epoch") &&
                    response_epoch_pending && vif.aresetn) begin
                    // Inject an old-epoch response into the passive observation
                    // stream after reset has flushed its accepted request.
                    obs.rsp_valid = 1'b1;
                    obs.rsp_client = response_epoch_client[2:0];
                    obs.mutation_probe = 1'b1;
                    response_epoch_pending = 1'b0;
                    mutation_injected = 1'b1;
                    `uvm_info("CLUSTER_MUTATION_INJECTED", $sformatf(
                        "mutation=response_epoch passive response from prior reset epoch client=%0d",
                        response_epoch_client), UVM_LOW)
                end

                // Most checker-sensitivity mutations alter only the passive
                // transaction copy. The completion_error_code probe is a
                // separate testbench memory-image corruption in the sequence;
                // none of these probes mutate product RTL. Each run injects
                // one mutation.
                if (!mutation_injected) begin
                    case (mutation_kind)
                        "address": if (obs.selected_banked_valid && obs.selected_banked_ready) begin
                            obs.selected_banked_addr = obs.selected_banked_addr + 32'd4;
                            mutation_injected = 1'b1;
                        end
                        "data": if (obs.rsp_valid && obs.rsp_client == 3'd3) begin
                            obs.banked_rdata[0] = obs.banked_rdata[0] ^ 32'd1;
                            mutation_injected = 1'b1;
                        end
                        "owner": if (obs.rsp_valid && obs.rsp_client == 3'd3) begin
                            obs.rsp_client = 3'd5;
                            mutation_injected = 1'b1;
                        end
                        "wstrb": if (obs.selected_line_valid && obs.selected_line_ready &&
                                     obs.selected_line_write && obs.request_client == 3'd2) begin
                            obs.selected_line_wstrb[0] = ~obs.selected_line_wstrb[0];
                            mutation_injected = 1'b1;
                        end
                        "done": if ((obs.engine_busy == 7'd0) &&
                                    (obs.engine_done == 7'd0) &&
                                    (obs.engine_error == 7'd0) && !obs.reset_active) begin
                            obs.engine_done[mutation_engine] = 1'b1;
                            mutation_injected = 1'b1;
                        end
                        "missing_done": if (obs.engine_done[mutation_engine] && !obs.reset_active) begin
                            missing_done_pending[mutation_engine] = 1'b1;
                            obs.engine_done[mutation_engine] = 1'b0;
                            mutation_injected = 1'b1;
                        end
                        "duplicate_done": if ((duplicate_done_pending != 0) &&
                                               !(|(duplicate_done_pending & obs.engine_busy)) &&
                                               !obs.reset_active) begin
                            obs.engine_done = obs.engine_done | duplicate_done_pending;
                            duplicate_done_pending = '0;
                            mutation_injected = 1'b1;
                        end
                        "write_after_error": begin
                            if (write_prefix_pending && !obs.reset_active) begin
                                obs.selected_spad_valid = 1'b1;
                                obs.selected_spad_write = 1'b1;
                                obs.selected_spad_ready = 1'b1;
                                obs.selected_spad_access_ok = 1'b1;
                                obs.selected_spad_addr = 32'h0005_f000;
                                obs.selected_spad_wdata = 32'hbad0_0001;
                                obs.request_client = 3'd2;
                                obs.engine_req_valid = 7'b1 << mutation_engine;
                                obs.engine_req_ready = 7'b1 << mutation_engine;
                                obs.mutation_probe = 1'b1;
                                write_prefix_pending = 1'b0;
                                mutation_injected = 1'b1;
                            end else if ((|obs.engine_error) && !obs.reset_active) begin
                                for (lane = 0; lane < 7; lane++) begin
                                    if (obs.engine_error[lane]) begin
                                        mutation_engine = lane;
                                        write_prefix_pending = 1'b1;
                                        break;
                                    end
                                end
                            end
                        end
                        default: begin end
                    endcase
                    if (mutation_injected)
                        `uvm_info("CLUSTER_MUTATION_INJECTED", $sformatf(
                            "testbench observation mutation=%s engine=%0d",
                            mutation_kind, mutation_engine), UVM_LOW)
                end
                ap.write(obs);
                if ((mutation_kind == "duplicate_done") && !mutation_injected &&
                    sampled_engine_done[mutation_engine] && vif.aresetn)
                    duplicate_done_pending[mutation_engine] = 1'b1;
                if (flush_missing_done)
                    missing_done_pending = '0;
            end
        end
    endtask
endclass
