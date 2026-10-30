class dma_spad_subsystem_monitor extends uvm_component;
    virtual ai_dma_spad_system_if vif;
    bit [31:0] expected_cnm_mem[bit [31:0]];
    bit [31:0] expected_core_data[$];
    logic [31:0] expected_cnm_lane_data0[$];
    logic [31:0] expected_cnm_lane_data1[$];
    logic [31:0] expected_cnm_lane_data2[$];
    logic [31:0] expected_cnm_lane_data3[$];
    bit expected_cnm_lane_protection0[$];
    bit expected_cnm_lane_protection1[$];
    bit expected_cnm_lane_protection2[$];
    bit expected_cnm_lane_protection3[$];
    bit expected_cnm_lane_parity0[$];
    bit expected_cnm_lane_parity1[$];
    bit expected_cnm_lane_parity2[$];
    bit expected_cnm_lane_parity3[$];
    int unsigned core_reads_accepted;
    int unsigned core_responses_checked;
    int unsigned core_grants_under_contention;
    int unsigned core_grants_isolated;
    int unsigned dma_grants_under_contention;
    int unsigned dma_grants_isolated;
    int unsigned desc_priority_grants;
    int unsigned cpl_priority_grants;
    int unsigned fp_reads_accepted;
    int unsigned fp_responses_checked;
    int unsigned fp_writes_accepted;
    int unsigned fp_grants_under_contention;
    int unsigned fp_dma_grants_under_contention;
    int unsigned fp_outstanding_reads;
    int unsigned fp_peak_outstanding_reads;
    int unsigned dma_write_grants;
    int unsigned cnm_lane_reads_accepted[4];
    int unsigned cnm_lane_responses_checked[4];
    bit cnm_outstanding_read_observed;
    bit expected_cnm_protection_fault;
    bit expected_cnm_parity_fault;
    bit expected_cnm_parity_pending;
    bit [31:0] expected_cnm_parity_addr;
    int unsigned cnm_spad_writes_accepted;
    int unsigned cnm_grants_under_contention;
    int unsigned cnm_dma_grants_under_contention;
    int unsigned cnm_request_stall_cycles;
    int unsigned cnm_stall_streak;
    int unsigned cnm_max_stall_streak;
    int unsigned cnm_grants_after_stall;
    int unsigned cov_grant_client;
    bit cov_contended;
    int unsigned cov_cnm_gemv_k;
    int unsigned cov_cnm_gemv_m;
    int unsigned cov_cnm_protection_source;
    int unsigned cov_cnm_parity_lane;
    bit cov_cnm_parity_dma_overlap;
    int unsigned cov_cnm_reset_phase;
    bit cov_cnm_dma_error_overlap;
    bit cov_cnm_dma_error_drained;
    int unsigned cov_cnm_dma_error_case;
    bit cov_cnm_dma_abort_overlap;
    bit cov_cnm_dma_abort_drained;
    bit cov_cnm_dma_abort_no_commit;
    int unsigned cov_cnm_dma_abort_highwater;
    bit cov_cnm_parity_dma_abort_overlap;
    bit cov_cnm_parity_dma_abort_drained;
    bit cov_cnm_parity_abort_reset_event;
    int unsigned cov_cnm_parity_abort_reset_timing;
    int unsigned cov_cnm_parity_abort_reset_highwater;
    bit cov_cnm_dma_write_abort_overlap;
    bit cov_cnm_dma_write_abort_drained;
    bit cov_cnm_dma_write_abort_single_burst;
    int unsigned cov_dma_reset_phase;
    int unsigned cov_dma_cnm_reset_read_highwater;
    int unsigned cov_dma_cnm_reset_phase;

    covergroup arbiter_cg;
        option.per_instance = 1;
        cp_client: coverpoint cov_grant_client {
            bins core = {3'd2};
            bins cnm  = {3'd3};
            bins dma  = {3'd4};
        }
        cp_contended: coverpoint cov_contended {
            bins isolated = {0};
            bins shared   = {1};
        }
        client_x_contention: cross cp_client, cp_contended;
    endgroup

    covergroup cnm_gemv_shape_cg;
        option.per_instance = 1;
        cp_k: coverpoint cov_cnm_gemv_k {
            bins k1 = {1};
            bins k2 = {2};
            bins k8 = {8};
            bins k9 = {9};
        }
        cp_m: coverpoint cov_cnm_gemv_m {
            bins m2 = {2};
            bins m3 = {3};
            bins m4 = {4};
        }
        k_x_m: cross cp_k, cp_m;
    endgroup

    covergroup cnm_protection_source_cg;
        option.per_instance = 1;
        cp_source: coverpoint cov_cnm_protection_source {
            bins source_a = {0};
            bins source_b = {1};
            bins destination_write_permission = {2};
        }
    endgroup

    covergroup cnm_parity_contention_cg;
        option.per_instance = 1;
        cp_lane: coverpoint cov_cnm_parity_lane {
            bins lane0 = {0};
            bins lane1 = {1};
            bins lane2 = {2};
            bins lane3 = {3};
        }
        cp_dma_overlap: coverpoint cov_cnm_parity_dma_overlap {
            bins dma_overlap = {1};
        }
        lane_x_dma_overlap: cross cp_lane, cp_dma_overlap;
    endgroup

    covergroup cnm_reset_phase_cg;
        option.per_instance = 1;
        cp_phase: coverpoint cov_cnm_reset_phase {
            bins accepted_read_outstanding = {0};
            bins all_reads_returned_prewrite = {1};
        }
    endgroup

    covergroup dma_reset_phase_cg;
        option.per_instance = 1;
        cp_phase: coverpoint cov_dma_reset_phase {
            bins all_four_ar_before_any_r = {0};
            bins first_r_beat_accepted_next_stalled = {1};
        }
    endgroup

    covergroup dma_cnm_shared_reset_cg;
        option.per_instance = 1;
        cp_dma_read_highwater: coverpoint cov_dma_cnm_reset_read_highwater {
            bins four_reads_outstanding = {4};
        }
        cp_cnm_reset_phase: coverpoint cov_dma_cnm_reset_phase {
            bins accepted_read_outstanding = {0};
            bins all_reads_returned_prewrite = {1};
        }
        dma_x_cnm_reset_phase: cross cp_dma_read_highwater, cp_cnm_reset_phase;
    endgroup

    covergroup cnm_dma_error_overlap_cg;
        option.per_instance = 1;
        cp_scenario: coverpoint cov_cnm_dma_error_case {
            bins error_before_any_successful_burst = {0};
            bins error_after_one_successful_burst = {1};
            bins error_after_two_successful_bursts = {2};
            bins error_after_three_successful_bursts = {3};
        }
        cp_error_during_cnm_busy: coverpoint cov_cnm_dma_error_overlap {
            bins observed = {1};
        }
        cp_dma_error_drained: coverpoint cov_cnm_dma_error_drained {
            bins drained = {1};
        }
        overlap_x_drain: cross cp_error_during_cnm_busy, cp_dma_error_drained;
        scenario_x_drain: cross cp_scenario, cp_dma_error_drained;
    endgroup

    covergroup cnm_dma_abort_overlap_cg;
        option.per_instance = 1;
        cp_abort_during_cnm_busy: coverpoint cov_cnm_dma_abort_overlap {
            bins observed = {1};
        }
        cp_dma_abort_drained: coverpoint cov_cnm_dma_abort_drained {
            bins drained = {1};
        }
        cp_no_dma_spad_commit: coverpoint cov_cnm_dma_abort_no_commit {
            bins no_commit = {1};
        }
        cp_read_highwater: coverpoint cov_cnm_dma_abort_highwater {
            bins four_outstanding = {4};
        }
        abort_x_drain: cross cp_abort_during_cnm_busy, cp_dma_abort_drained;
        drain_x_no_commit: cross cp_dma_abort_drained, cp_no_dma_spad_commit;
    endgroup

    covergroup cnm_parity_dma_abort_cg;
        option.per_instance = 1;
        cp_parity_during_abort_drain: coverpoint cov_cnm_parity_dma_abort_overlap {
            bins observed = {1};
        }
        cp_abort_fully_drained: coverpoint cov_cnm_parity_dma_abort_drained {
            bins drained = {1};
        }
        parity_abort_x_drain: cross cp_parity_during_abort_drain,
                                   cp_abort_fully_drained;
    endgroup

    covergroup cnm_parity_abort_reset_cg;
        option.per_instance = 1;
        cp_fault_abort_reset: coverpoint cov_cnm_parity_abort_reset_event {
            bins parity_during_abort_drain_then_reset = {1};
        }
        cp_reset_timing: coverpoint cov_cnm_parity_abort_reset_timing {
            bins same_cycle = {0};
            bins delayed_1_to_3_cycles = {1};
        }
        cp_dma_read_highwater: coverpoint cov_cnm_parity_abort_reset_highwater {
            bins four_reads_outstanding = {4};
        }
        fault_abort_reset_x_timing: cross cp_fault_abort_reset,
                                         cp_reset_timing,
                                         cp_dma_read_highwater;
    endgroup

    covergroup cnm_dma_write_abort_cg;
        option.per_instance = 1;
        cp_cnm_during_pending_b: coverpoint cov_cnm_dma_write_abort_overlap {
            bins observed = {1};
        }
        cp_b_response_drained: coverpoint cov_cnm_dma_write_abort_drained {
            bins drained = {1};
        }
        cp_one_accepted_burst: coverpoint cov_cnm_dma_write_abort_single_burst {
            bins one_burst = {1};
        }
        overlap_x_drain: cross cp_cnm_during_pending_b, cp_b_response_drained;
        drain_x_single_burst: cross cp_b_response_drained, cp_one_accepted_burst;
    endgroup

    `uvm_component_utils(dma_spad_subsystem_monitor)

    function new(string name = "dma_spad_subsystem_monitor", uvm_component parent = null);
        super.new(name, parent);
        arbiter_cg = new;
        cnm_gemv_shape_cg = new;
        cnm_protection_source_cg = new;
        cnm_parity_contention_cg = new;
        cnm_reset_phase_cg = new;
        dma_reset_phase_cg = new;
        dma_cnm_shared_reset_cg = new;
        cnm_dma_error_overlap_cg = new;
        cnm_dma_abort_overlap_cg = new;
        cnm_parity_dma_abort_cg = new;
        cnm_parity_abort_reset_cg = new;
        cnm_dma_write_abort_cg = new;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_dma_spad_system_if)::get(
                this, "", "spad_system_vif", vif))
            `uvm_fatal("NOVIF", "DMA-SPAD monitor needs spad_system_vif")
    endfunction

    function automatic bit [31:0] expected_pattern(bit [31:0] addr);
        return 32'hc001_0000 ^ (addr >> 2);
    endfunction

    function void set_expected_cnm_word(bit [31:0] addr, bit [31:0] data);
        expected_cnm_mem[addr] = data;
    endfunction

    function void expect_cnm_protection_fault(bit enable);
        expected_cnm_protection_fault = enable;
    endfunction

    function void expect_cnm_parity_fault(bit enable, bit [31:0] addr);
        expected_cnm_parity_fault = enable;
        expected_cnm_parity_pending = enable;
        expected_cnm_parity_addr = addr;
    endfunction

    function void sample_cnm_gemv_shape(int unsigned k, int unsigned m);
        cov_cnm_gemv_k = k;
        cov_cnm_gemv_m = m;
        cnm_gemv_shape_cg.sample();
    endfunction

    function void sample_cnm_protection_source(int unsigned source_index);
        cov_cnm_protection_source = source_index;
        cnm_protection_source_cg.sample();
    endfunction

    function void sample_cnm_reset_phase(int unsigned phase_index);
        cov_cnm_reset_phase = phase_index;
        cnm_reset_phase_cg.sample();
    endfunction

    function void sample_dma_reset_phase(int unsigned phase_index);
        cov_dma_reset_phase = phase_index;
        dma_reset_phase_cg.sample();
    endfunction

    function void sample_dma_cnm_shared_reset(int unsigned read_highwater,
                                              int unsigned cnm_phase);
        cov_dma_cnm_reset_read_highwater = read_highwater;
        cov_dma_cnm_reset_phase = cnm_phase;
        dma_cnm_shared_reset_cg.sample();
    endfunction

    function void sample_cnm_dma_error_overlap(int unsigned scenario,
                                               bit error_overlap,
                                               bit drained);
        cov_cnm_dma_error_case = scenario;
        cov_cnm_dma_error_overlap = error_overlap;
        cov_cnm_dma_error_drained = drained;
        cnm_dma_error_overlap_cg.sample();
    endfunction

    function void sample_cnm_dma_abort_overlap(bit abort_overlap,
                                               bit drained,
                                               bit no_commit,
                                               int unsigned read_highwater);
        cov_cnm_dma_abort_overlap = abort_overlap;
        cov_cnm_dma_abort_drained = drained;
        cov_cnm_dma_abort_no_commit = no_commit;
        cov_cnm_dma_abort_highwater = read_highwater;
        cnm_dma_abort_overlap_cg.sample();
    endfunction

    function void sample_cnm_parity_dma_abort(bit overlap, bit dma_drained);
        cov_cnm_parity_dma_abort_overlap = overlap;
        cov_cnm_parity_dma_abort_drained = dma_drained;
        cnm_parity_dma_abort_cg.sample();
    endfunction

    function void sample_cnm_parity_abort_reset(bit observed,
                                                int unsigned reset_timing,
                                                int unsigned read_highwater);
        cov_cnm_parity_abort_reset_event = observed;
        cov_cnm_parity_abort_reset_timing = reset_timing;
        cov_cnm_parity_abort_reset_highwater = read_highwater;
        cnm_parity_abort_reset_cg.sample();
    endfunction

    function void sample_cnm_dma_write_abort(bit overlap, bit drained,
                                             bit single_burst);
        cov_cnm_dma_write_abort_overlap = overlap;
        cov_cnm_dma_write_abort_drained = drained;
        cov_cnm_dma_write_abort_single_burst = single_burst;
        cnm_dma_write_abort_cg.sample();
    endfunction

    function void sample_cnm_parity_contention(int unsigned lane, bit dma_overlap);
        cov_cnm_parity_lane = lane;
        cov_cnm_parity_dma_overlap = dma_overlap;
        cnm_parity_contention_cg.sample();
    endfunction

    function automatic logic [31:0] expected_cnm_word(bit [31:0] addr);
        if (expected_cnm_mem.exists(addr))
            return expected_cnm_mem[addr];
        return 32'hxxxx_xxxx;
    endfunction

    task run_phase(uvm_phase phase);
        bit dma_request_pending;
        bit any_data_grant;
        bit core_request_pending;
        bit cnm_request_pending;
        logic [31:0] expected_cnm_word_value;
        logic [31:0] observed_cnm_word;
        bit expected_cnm_protection_error_value;
        bit expected_cnm_response_error;
        bit expected_cnm_parity_error_value;
        bit expected_cnm_response_parity_error;
        bit cnm_response_has_expectation;
        int lane;
        forever begin
            @(posedge vif.clk);
            if (!vif.resetn) begin
                expected_core_data.delete();
                expected_cnm_mem.delete();
                expected_cnm_lane_data0.delete();
                expected_cnm_lane_data1.delete();
                expected_cnm_lane_data2.delete();
                expected_cnm_lane_data3.delete();
                expected_cnm_lane_protection0.delete();
                expected_cnm_lane_protection1.delete();
                expected_cnm_lane_protection2.delete();
                expected_cnm_lane_protection3.delete();
                expected_cnm_lane_parity0.delete();
                expected_cnm_lane_parity1.delete();
                expected_cnm_lane_parity2.delete();
                expected_cnm_lane_parity3.delete();
                expected_cnm_parity_fault = 1'b0;
                expected_cnm_parity_pending = 1'b0;
                expected_cnm_parity_addr = '0;
                core_reads_accepted = 0;
                core_responses_checked = 0;
                core_grants_under_contention = 0;
                core_grants_isolated = 0;
                dma_grants_under_contention = 0;
                dma_grants_isolated = 0;
                desc_priority_grants = 0;
                cpl_priority_grants = 0;
                fp_reads_accepted = 0;
                fp_responses_checked = 0;
                fp_writes_accepted = 0;
                fp_grants_under_contention = 0;
                fp_dma_grants_under_contention = 0;
                fp_outstanding_reads = 0;
                fp_peak_outstanding_reads = 0;
                dma_write_grants = 0;
                for (lane = 0; lane < 4; lane++) begin
                    cnm_lane_reads_accepted[lane] = 0;
                    cnm_lane_responses_checked[lane] = 0;
                end
                cnm_outstanding_read_observed = 0;
                cnm_spad_writes_accepted = 0;
                cnm_grants_under_contention = 0;
                cnm_dma_grants_under_contention = 0;
                cnm_request_stall_cycles = 0;
                cnm_stall_streak = 0;
                cnm_max_stall_streak = 0;
                cnm_grants_after_stall = 0;
            end else begin
                dma_request_pending = vif.dma_valid || vif.dma_line_valid;
                core_request_pending = vif.cnm_mode ? vif.cnm_spad_valid :
                                       vif.fp_mode ? vif.fp_req_valid : vif.core_valid;
                cnm_request_pending = |vif.cnm_req_valid;
                any_data_grant = 0;
                if (cnm_request_pending && !(|vif.cnm_req_ready)) begin
                    cnm_request_stall_cycles++;
                    cnm_stall_streak++;
                    if (cnm_stall_streak > cnm_max_stall_streak)
                        cnm_max_stall_streak = cnm_stall_streak;
                end else if (!cnm_request_pending) begin
                    cnm_stall_streak = 0;
                end

                if (vif.desc_valid && vif.desc_ready) begin
                    desc_priority_grants++;
                    if (vif.core_ready || (|vif.cnm_req_ready) || vif.dma_ready || vif.dma_line_ready)
                        `uvm_error("SPAD_DESC_PRIORITY", "descriptor grant overlapped a data-plane grant")
                end
                if (vif.cpl_valid && vif.cpl_ready) begin
                    cpl_priority_grants++;
                    if (vif.core_ready || (|vif.cnm_req_ready) || vif.dma_ready || vif.dma_line_ready)
                        `uvm_error("SPAD_CPL_PRIORITY", "completion grant overlapped a data-plane grant")
                end

                if (core_request_pending && vif.core_ready) begin
                    any_data_grant = 1;
                    if (vif.fp_mode) begin
                        if (vif.fp_req_write) begin
                            fp_writes_accepted++;
                        end else begin
                            fp_reads_accepted++;
                            if (dma_request_pending)
                                fp_grants_under_contention++;
                        end
                    end else if (vif.cnm_mode) begin
                        if (vif.cnm_spad_write)
                            cnm_spad_writes_accepted++;
                        else
                            `uvm_error("SPAD_CNM_OP", "real CNM core scheduler-port request was unexpectedly a read")
                    end else begin
                        if (vif.core_write) begin
                            `uvm_error("SPAD_CORE_OP", "subsystem stimulus unexpectedly issued a core write")
                        end else begin
                            expected_core_data.push_back(expected_pattern(vif.core_addr));
                            core_reads_accepted++;
                        end
                    end
                    cov_grant_client = 3'd2;
                    cov_contended = dma_request_pending;
                    arbiter_cg.sample();
                    if (dma_request_pending)
                        core_grants_under_contention++;
                    else
                        core_grants_isolated++;
                end

                if ((|vif.cnm_req_valid) && (|vif.cnm_req_ready)) begin
                    any_data_grant = 1;
                    if (cnm_stall_streak != 0)
                        cnm_grants_after_stall++;
                    cnm_stall_streak = 0;
                    expected_cnm_protection_error_value =
                        (vif.cnm_req_valid[0] && (vif.cnm_addr0 > 32'd4092)) ||
                        (vif.cnm_req_valid[1] && (vif.cnm_addr1 > 32'd4092)) ||
                        (vif.cnm_req_valid[2] && (vif.cnm_addr2 > 32'd4092)) ||
                        (vif.cnm_req_valid[3] && (vif.cnm_addr3 > 32'd4092));
                    if (expected_cnm_protection_error_value && !expected_cnm_protection_fault)
                        `uvm_error("SPAD_CNM_ADDR", "unexpected out-of-range CNM request outside protection test")
                    for (lane = 0; lane < 4; lane++) begin
                        if (vif.cnm_req_valid[lane] && vif.cnm_req_ready[lane]) begin
                            expected_cnm_word_value = '0;
                            expected_cnm_parity_error_value = 1'b0;
                            if (!expected_cnm_protection_error_value) begin
                                case (lane)
                                    0: begin
                                        expected_cnm_word_value = expected_cnm_word(vif.cnm_addr0);
                                        expected_cnm_parity_error_value = expected_cnm_parity_fault &&
                                            expected_cnm_parity_pending &&
                                            (vif.cnm_addr0 == expected_cnm_parity_addr);
                                    end
                                    1: begin
                                        expected_cnm_word_value = expected_cnm_word(vif.cnm_addr1);
                                        expected_cnm_parity_error_value = expected_cnm_parity_fault &&
                                            expected_cnm_parity_pending &&
                                            (vif.cnm_addr1 == expected_cnm_parity_addr);
                                    end
                                    2: begin
                                        expected_cnm_word_value = expected_cnm_word(vif.cnm_addr2);
                                        expected_cnm_parity_error_value = expected_cnm_parity_fault &&
                                            expected_cnm_parity_pending &&
                                            (vif.cnm_addr2 == expected_cnm_parity_addr);
                                    end
                                    default: begin
                                        expected_cnm_word_value = expected_cnm_word(vif.cnm_addr3);
                                        expected_cnm_parity_error_value = expected_cnm_parity_fault &&
                                            expected_cnm_parity_pending &&
                                            (vif.cnm_addr3 == expected_cnm_parity_addr);
                                    end
                                endcase
                                if (expected_cnm_parity_error_value)
                                    expected_cnm_parity_pending = 1'b0;
                                if ((^expected_cnm_word_value) === 1'bx)
                                    `uvm_error("SPAD_CNM_ADDR", $sformatf(
                                        "CNM lane %0d requested unexpected address 0x%08h",
                                        lane, lane == 0 ? vif.cnm_addr0 : lane == 1 ? vif.cnm_addr1 :
                                        lane == 2 ? vif.cnm_addr2 : vif.cnm_addr3))
                            end
                            case (lane)
                                0: begin
                                    expected_cnm_lane_data0.push_back(expected_cnm_word_value);
                                    expected_cnm_lane_protection0.push_back(expected_cnm_protection_error_value);
                                    expected_cnm_lane_parity0.push_back(expected_cnm_parity_error_value);
                                end
                                1: begin
                                    expected_cnm_lane_data1.push_back(expected_cnm_word_value);
                                    expected_cnm_lane_protection1.push_back(expected_cnm_protection_error_value);
                                    expected_cnm_lane_parity1.push_back(expected_cnm_parity_error_value);
                                end
                                2: begin
                                    expected_cnm_lane_data2.push_back(expected_cnm_word_value);
                                    expected_cnm_lane_protection2.push_back(expected_cnm_protection_error_value);
                                    expected_cnm_lane_parity2.push_back(expected_cnm_parity_error_value);
                                end
                                default: begin
                                    expected_cnm_lane_data3.push_back(expected_cnm_word_value);
                                    expected_cnm_lane_protection3.push_back(expected_cnm_protection_error_value);
                                    expected_cnm_lane_parity3.push_back(expected_cnm_parity_error_value);
                                end
                            endcase
                            cnm_lane_reads_accepted[lane]++;
                        end
                    end
                    cov_grant_client = 3'd3;
                    cov_contended = dma_request_pending;
                    arbiter_cg.sample();
                    if (dma_request_pending)
                        cnm_grants_under_contention++;
                end

                if (|vif.cnm_rsp_valid) begin
                    for (lane = 0; lane < 4; lane++) begin
                        if (vif.cnm_rsp_valid[lane]) begin
                            cnm_response_has_expectation = 1'b1;
                            observed_cnm_word = '0;
                            case (lane)
                                0: begin
                                    if ((expected_cnm_lane_data0.size() == 0) ||
                                        (expected_cnm_lane_protection0.size() == 0) ||
                                        (expected_cnm_lane_parity0.size() == 0)) begin
                                        `uvm_error("SPAD_CNM_RSP", "lane 0 response has no accepted request")
                                        cnm_response_has_expectation = 1'b0;
                                    end else begin
                                        expected_cnm_word_value = expected_cnm_lane_data0.pop_front();
                                        expected_cnm_response_error = expected_cnm_lane_protection0.pop_front();
                                        expected_cnm_response_parity_error = expected_cnm_lane_parity0.pop_front();
                                        observed_cnm_word = vif.cnm_data0;
                                    end
                                end
                                1: begin
                                    if ((expected_cnm_lane_data1.size() == 0) ||
                                        (expected_cnm_lane_protection1.size() == 0) ||
                                        (expected_cnm_lane_parity1.size() == 0)) begin
                                        `uvm_error("SPAD_CNM_RSP", "lane 1 response has no accepted request")
                                        cnm_response_has_expectation = 1'b0;
                                    end else begin
                                        expected_cnm_word_value = expected_cnm_lane_data1.pop_front();
                                        expected_cnm_response_error = expected_cnm_lane_protection1.pop_front();
                                        expected_cnm_response_parity_error = expected_cnm_lane_parity1.pop_front();
                                        observed_cnm_word = vif.cnm_data1;
                                    end
                                end
                                2: begin
                                    if ((expected_cnm_lane_data2.size() == 0) ||
                                        (expected_cnm_lane_protection2.size() == 0) ||
                                        (expected_cnm_lane_parity2.size() == 0)) begin
                                        `uvm_error("SPAD_CNM_RSP", "lane 2 response has no accepted request")
                                        cnm_response_has_expectation = 1'b0;
                                    end else begin
                                        expected_cnm_word_value = expected_cnm_lane_data2.pop_front();
                                        expected_cnm_response_error = expected_cnm_lane_protection2.pop_front();
                                        expected_cnm_response_parity_error = expected_cnm_lane_parity2.pop_front();
                                        observed_cnm_word = vif.cnm_data2;
                                    end
                                end
                                default: begin
                                    if ((expected_cnm_lane_data3.size() == 0) ||
                                        (expected_cnm_lane_protection3.size() == 0) ||
                                        (expected_cnm_lane_parity3.size() == 0)) begin
                                        `uvm_error("SPAD_CNM_RSP", "lane 3 response has no accepted request")
                                        cnm_response_has_expectation = 1'b0;
                                    end else begin
                                        expected_cnm_word_value = expected_cnm_lane_data3.pop_front();
                                        expected_cnm_response_error = expected_cnm_lane_protection3.pop_front();
                                        expected_cnm_response_parity_error = expected_cnm_lane_parity3.pop_front();
                                        observed_cnm_word = vif.cnm_data3;
                                    end
                                end
                            endcase
                            if (cnm_response_has_expectation &&
                                (vif.cnm_protection_error !== expected_cnm_response_error))
                                `uvm_error("SPAD_CNM_RSP_ERR", $sformatf(
                                    "CNM lane %0d response protection=%0b expected=%0b",
                                    lane, vif.cnm_protection_error, expected_cnm_response_error))
                            if (cnm_response_has_expectation && expected_cnm_response_error &&
                                !expected_cnm_protection_fault)
                                `uvm_error("SPAD_CNM_RSP_ERR", "out-of-range response occurred outside protection test")
                            if (cnm_response_has_expectation &&
                                (vif.cnm_parity_error[lane] !== expected_cnm_response_parity_error))
                                `uvm_error("SPAD_CNM_RSP_PARITY", $sformatf(
                                    "CNM lane %0d response parity=%0b expected=%0b",
                                    lane, vif.cnm_parity_error[lane], expected_cnm_response_parity_error))
                            if (cnm_response_has_expectation && !expected_cnm_response_error &&
                                observed_cnm_word !== expected_cnm_word_value)
                                `uvm_error("SPAD_CNM_DATA", $sformatf(
                                    "lane %0d response=0x%08h expected=0x%08h",
                                    lane, observed_cnm_word, expected_cnm_word_value))
                            cnm_lane_responses_checked[lane]++;
                        end
                    end
                end

                if ((vif.dma_valid && vif.dma_ready) ||
                    (vif.dma_line_valid && vif.dma_line_ready)) begin
                    any_data_grant = 1;
                    cov_grant_client = 3'd4;
                    cov_contended = core_request_pending || cnm_request_pending;
                    arbiter_cg.sample();
                    if (core_request_pending || cnm_request_pending)
                        dma_grants_under_contention++;
                    else
                        dma_grants_isolated++;
                    if (vif.fp_mode && core_request_pending)
                        fp_dma_grants_under_contention++;
                    if (cnm_request_pending)
                        cnm_dma_grants_under_contention++;
                end
                if (vif.dma_valid && vif.dma_ready && vif.dma_write)
                    dma_write_grants++;

                if (vif.core_ready && vif.dma_ready)
                    `uvm_error("SPAD_DUAL_GRANT", "scalar core and DMA were both granted on the single scheduler port")
                if (vif.core_ready && vif.dma_line_ready)
                    `uvm_error("SPAD_DUAL_GRANT", "core and DMA line were both granted on the single scheduler port")
                if (vif.dma_ready && vif.dma_line_ready)
                    `uvm_error("SPAD_DUAL_GRANT", "DMA scalar and line requests were both granted together")
                if ((|vif.cnm_req_ready) && (vif.dma_ready || vif.dma_line_ready || vif.core_ready))
                    `uvm_error("SPAD_DUAL_GRANT", "CNM and another scheduler data client were granted together")

                if (vif.fp_mode && vif.fp_rsp_valid) begin
                    if (fp_outstanding_reads == 0)
                        `uvm_error("SPAD_FP_RSP", "real FP core response has no accepted read")
                    if (vif.fp_rsp_error)
                        `uvm_error("SPAD_FP_RSP_ERR", "real FP operand read returned parity/protection error")
                    fp_responses_checked++;
                end else if (!vif.fp_mode && vif.core_rsp_valid) begin
                    bit [31:0] expected;
                    if (expected_core_data.size() == 0) begin
                        `uvm_error("SPAD_CORE_RSP", "core response has no accepted read request")
                    end else begin
                        expected = expected_core_data.pop_front();
                        if (vif.core_rsp_error)
                            `uvm_error("SPAD_CORE_ERR", "legal core read returned a protection/parity error")
                        if (vif.core_rdata !== expected)
                            `uvm_error("SPAD_CORE_DATA", $sformatf(
                                "core response data=0x%08h expected=0x%08h",
                                vif.core_rdata, expected))
                        core_responses_checked++;
                    end
                end

                if (vif.fp_mode) begin
                    case ({(vif.fp_req_valid && vif.fp_req_ready && !vif.fp_req_write),
                           vif.fp_rsp_valid})
                        2'b10: fp_outstanding_reads++;
                        2'b01: if (fp_outstanding_reads != 0) fp_outstanding_reads--;
                        default: begin end
                    endcase
                    if (fp_outstanding_reads > fp_peak_outstanding_reads)
                        fp_peak_outstanding_reads = fp_outstanding_reads;
                end

                // Keep this explicit: a request may wait behind the other
                // client, but it must not be acknowledged without a grant.
                if (vif.request_client == 3'd2 && !vif.core_ready && any_data_grant)
                    `uvm_error("SPAD_CLIENT_TAG", "arbiter client tag disagrees with granted requester")
                if ((|vif.cnm_req_ready) && vif.request_client != 3'd5)
                    `uvm_error("SPAD_CLIENT_TAG", "CNM grant has the wrong arbiter client tag")

                // Record an unmatched accepted read only after this cycle's
                // response processing, avoiding a transient counter-update race.
                if (expected_cnm_lane_data0.size() || expected_cnm_lane_data1.size() ||
                    expected_cnm_lane_data2.size() || expected_cnm_lane_data3.size())
                    cnm_outstanding_read_observed = 1'b1;
            end
        end
    endtask

    function void check_complete(int unsigned expected_reads);
        if (core_reads_accepted != expected_reads)
            `uvm_error("SPAD_CORE_COUNT", $sformatf("accepted %0d core reads, expected %0d",
                       core_reads_accepted, expected_reads))
        if (core_responses_checked != expected_reads || expected_core_data.size() != 0)
            `uvm_error("SPAD_CORE_DRAIN", $sformatf("checked %0d responses, expected %0d; pending=%0d",
                       core_responses_checked, expected_reads, expected_core_data.size()))
        if (core_grants_under_contention == 0 || dma_grants_under_contention == 0 ||
            core_grants_isolated == 0 || dma_grants_isolated == 0)
            `uvm_error("SPAD_GRANT_COVERAGE", $sformatf(
                "expected core/DMA isolated and contended grants; core=%0d/%0d dma=%0d/%0d",
                core_grants_isolated, core_grants_under_contention,
                dma_grants_isolated, dma_grants_under_contention))
        if (desc_priority_grants == 0 || cpl_priority_grants == 0)
            `uvm_error("SPAD_CONTROL_PRIORITY", $sformatf("expected descriptor/completion grants, got desc=%0d cpl=%0d",
                       desc_priority_grants, cpl_priority_grants))
        `uvm_info("DMA_SPAD_COVERAGE", $sformatf(
            "core reads=%0d responses=%0d grants isolated/contended core=%0d/%0d dma=%0d/%0d; desc/cpl priority=%0d/%0d; arbiter coverage=%0.2f%%",
            core_reads_accepted, core_responses_checked,
            core_grants_isolated, core_grants_under_contention,
            dma_grants_isolated, dma_grants_under_contention,
            desc_priority_grants, cpl_priority_grants, arbiter_cg.get_inst_coverage()), UVM_LOW)
    endfunction

    function void check_fp_complete(int unsigned expected_reads,
                                    int unsigned expected_writes,
                                    bit [31:0] expected_result,
                                    bit require_dma_contention = 1'b1);
        if (fp_reads_accepted != expected_reads || fp_responses_checked != expected_reads ||
            fp_outstanding_reads != 0)
            `uvm_error("SPAD_FP_DRAIN", $sformatf(
                "FP read accepts/responses=%0d/%0d expected=%0d outstanding=%0d",
                fp_reads_accepted, fp_responses_checked, expected_reads, fp_outstanding_reads))
        if (fp_writes_accepted != expected_writes)
            `uvm_error("SPAD_FP_WRITE", $sformatf("FP write accepts=%0d expected=%0d",
                       fp_writes_accepted, expected_writes))
        if (fp_peak_outstanding_reads != 2)
            `uvm_error("SPAD_FP_OUTSTANDING", $sformatf(
                "expected to observe the specified two-read overlap, peak=%0d",
                fp_peak_outstanding_reads))
        if (require_dma_contention &&
            (fp_grants_under_contention == 0 || fp_dma_grants_under_contention == 0))
            `uvm_error("SPAD_FP_DMA_CONTENTION", $sformatf(
                "real FP/DMA overlap not observed; FP contended grants=%0d DMA contended grants=%0d",
                fp_grants_under_contention, fp_dma_grants_under_contention))
        `uvm_info("SPAD_FP_DMA_PASS", $sformatf(
            "real FP core shared DMA arbiter: reads=%0d responses=%0d writes=%0d peak_outstanding=%0d FP/DMA_contended_grants=%0d/%0d; result=0x%08h",
            fp_reads_accepted, fp_responses_checked, fp_writes_accepted,
            fp_peak_outstanding_reads, fp_grants_under_contention,
            fp_dma_grants_under_contention, expected_result), UVM_LOW)
    endfunction

    function void reset_fp_stats();
        fp_reads_accepted = 0;
        fp_responses_checked = 0;
        fp_writes_accepted = 0;
        fp_grants_under_contention = 0;
        fp_dma_grants_under_contention = 0;
        fp_outstanding_reads = 0;
        fp_peak_outstanding_reads = 0;
    endfunction

    function void check_cnm_complete(int unsigned expected_reads_per_lane,
                                     int unsigned expected_writes,
                                     bit [31:0] expected_result,
                                     bit require_scheduler_contention = 1'b1);
        int lane;
        if (vif.cnm_result !== expected_result)
            `uvm_error("SPAD_CNM_RESULT", $sformatf(
                "CNM result=0x%08h expected=0x%08h", vif.cnm_result, expected_result))
        for (lane = 0; lane < 4; lane++) begin
            if (cnm_lane_reads_accepted[lane] != expected_reads_per_lane ||
                cnm_lane_responses_checked[lane] != expected_reads_per_lane)
                `uvm_error("SPAD_CNM_DRAIN", $sformatf(
                    "lane %0d reads/responses=%0d/%0d expected=%0d",
                    lane, cnm_lane_reads_accepted[lane],
                    cnm_lane_responses_checked[lane], expected_reads_per_lane))
        end
        if (expected_cnm_lane_data0.size() || expected_cnm_lane_data1.size() ||
            expected_cnm_lane_data2.size() || expected_cnm_lane_data3.size())
            `uvm_error("SPAD_CNM_DRAIN", $sformatf(
                "unmatched expected lane responses remain: %0d/%0d/%0d/%0d",
                expected_cnm_lane_data0.size(), expected_cnm_lane_data1.size(),
                expected_cnm_lane_data2.size(), expected_cnm_lane_data3.size()))
        if (cnm_spad_writes_accepted != expected_writes)
            `uvm_error("SPAD_CNM_WRITE", $sformatf(
                "CNM result writes=%0d expected=%0d", cnm_spad_writes_accepted, expected_writes))
        if (require_scheduler_contention) begin
            if (cnm_dma_grants_under_contention == 0)
                `uvm_error("SPAD_CNM_DMA_CONTENTION", $sformatf(
                    "no DMA grant was observed while CNM was requesting: CNM=%0d DMA=%0d",
                    cnm_grants_under_contention, cnm_dma_grants_under_contention))
            if (cnm_request_stall_cycles == 0)
                `uvm_error("SPAD_CNM_STALL", "CNM request was never backpressured in the contention scenario")
            if (cnm_grants_after_stall == 0 || cnm_max_stall_streak > 4)
                `uvm_error("SPAD_CNM_FAIRNESS", $sformatf(
                    "CNM did not make bounded progress after backpressure: grants_after_stall=%0d max_consecutive_stall=%0d",
                    cnm_grants_after_stall, cnm_max_stall_streak))
        end
        `uvm_info("SPAD_CNM_DMA_PASS", $sformatf(
            "real CNM lane traffic: per-lane reads/responses=%0d, result writes=%0d, accepted-under-overlap CNM/DMA grants=%0d/%0d, stalls=%0d, max stall streak=%0d, grants after stall=%0d, expected result=0x%08h",
            expected_reads_per_lane, cnm_spad_writes_accepted,
            cnm_grants_under_contention, cnm_dma_grants_under_contention,
            cnm_request_stall_cycles, cnm_max_stall_streak, cnm_grants_after_stall,
            expected_result), UVM_LOW)
    endfunction

    function void reset_cnm_stats();
        int lane;
        expected_cnm_lane_data0.delete();
        expected_cnm_lane_data1.delete();
        expected_cnm_lane_data2.delete();
        expected_cnm_lane_data3.delete();
        expected_cnm_lane_protection0.delete();
        expected_cnm_lane_protection1.delete();
        expected_cnm_lane_protection2.delete();
        expected_cnm_lane_protection3.delete();
        expected_cnm_lane_parity0.delete();
        expected_cnm_lane_parity1.delete();
        expected_cnm_lane_parity2.delete();
        expected_cnm_lane_parity3.delete();
        for (lane = 0; lane < 4; lane++) begin
            cnm_lane_reads_accepted[lane] = 0;
            cnm_lane_responses_checked[lane] = 0;
        end
        cnm_outstanding_read_observed = 0;
        cnm_spad_writes_accepted = 0;
        cnm_grants_under_contention = 0;
        cnm_dma_grants_under_contention = 0;
        cnm_request_stall_cycles = 0;
        cnm_stall_streak = 0;
        cnm_max_stall_streak = 0;
        cnm_grants_after_stall = 0;
    endfunction
endclass

class dma_spad_subsystem_test extends dma_block_base_test;
    virtual ai_dma_spad_system_if sys_vif;
    dma_spad_subsystem_monitor cont_mon;
    localparam int unsigned CORE_READS_PER_PHASE = 96;
    bit saw_axi_read_before_subsystem_reset;
    bit saw_axi_write_before_subsystem_reset;
    int unsigned cov_rready_stall_cycles;
    bit cov_rready_stall_completed;
    bit rready_stall_only;
    bit banked_owner_only;
    bit banked_reset_only;
    bit banked_contention_only;
    bit banked_core_reset_only;
    int unsigned cov_banked_reset_flushed;
    int unsigned cov_banked_reset_recovered;
    bit cov_banked_core_pair_accepted;
    bit cov_banked_core_response_pair_checked;
    bit cov_banked_core_reset_pair_accepted;
    bit cov_banked_core_reset_first_response_checked;
    bit cov_banked_core_reset_pending_banked_flushed;
    bit cov_banked_core_reset_recovery_pair_checked;
    int unsigned rready_stall_cycles_requested;

    covergroup dma_rready_stall_cg;
        option.per_instance = 1;
        cp_stall_cycles: coverpoint cov_rready_stall_cycles {
            bins sixteen_cycles = {16};
            bins sixty_four_cycles = {64};
            bins three_hundred_cycles = {300};
        }
        cp_completed: coverpoint cov_rready_stall_completed {
            bins completed_after_release = {1};
        }
        stall_x_completion: cross cp_stall_cycles, cp_completed;
    endgroup

    covergroup banked_reset_epoch_cg;
        option.per_instance = 1;
        cp_accepted_read_flushed: coverpoint cov_banked_reset_flushed {
            bins accepted_banked_read_flushed = {1};
        }
        cp_recovery_read: coverpoint cov_banked_reset_recovered {
            bins banked_read_after_reset = {1};
        }
        flush_x_recovery: cross cp_accepted_read_flushed, cp_recovery_read;
    endgroup

    covergroup banked_core_contention_cg;
        option.per_instance = 1;
        cp_pair_accepted: coverpoint cov_banked_core_pair_accepted {
            bins both_clients_accepted = {1};
        }
        cp_owner_data_checked: coverpoint cov_banked_core_response_pair_checked {
            bins both_tagged_responses_checked = {1};
        }
        accepted_x_checked: cross cp_pair_accepted, cp_owner_data_checked;
    endgroup

    covergroup banked_core_reset_epoch_cg;
        option.per_instance = 1;
        cp_pair_accepted: coverpoint cov_banked_core_reset_pair_accepted {
            bins core_then_banked_accepted = {1};
        }
        cp_first_owner_checked: coverpoint cov_banked_core_reset_first_response_checked {
            bins first_response_owner_and_data_checked = {1};
        }
        cp_pending_banked_flushed: coverpoint cov_banked_core_reset_pending_banked_flushed {
            bins banked_response_flushed = {1};
        }
        cp_recovery_pair_checked: coverpoint cov_banked_core_reset_recovery_pair_checked {
            bins both_owners_recovered = {1};
        }
        accepted_x_flush_x_recovery: cross cp_pair_accepted,
                                             cp_pending_banked_flushed,
                                             cp_recovery_pair_checked;
    endgroup

    `uvm_component_utils(dma_spad_subsystem_test)

    function new(string name = "dma_spad_subsystem_test", uvm_component parent = null);
        super.new(name, parent);
        dma_rready_stall_cg = new;
        banked_reset_epoch_cg = new;
        banked_core_contention_cg = new;
        banked_core_reset_epoch_cg = new;
    endfunction

    task run_dma_rready_stall();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        int unsigned accepted_base, completed_base, wait_cycles, stall_cycles;
        int unsigned errors_before;
        bit seq_done, found_rvalid, released;
        logic [3:0] held_rid;
        logic [127:0] held_rdata;
        logic [1:0] held_rresp;
        logic held_rlast;

        released = 0;
        seq_done = 0;
        found_rvalid = 0;
        errors_before = uvm_report_server::get_server().get_severity_count(UVM_ERROR);
        stall_cycles = 0;
        rready_stall_cycles_requested = 16;
        void'($value$plusargs("A10_RREADY_STALL_CYCLES=%d", rready_stall_cycles_requested));
        if (!(rready_stall_cycles_requested inside {16, 64, 300}))
            `uvm_fatal("DMA_RREADY_STALL", $sformatf(
                "unsupported stall length %0d; supported profiles are 16, 64, and 300 cycles",
                rready_stall_cycles_requested))
        cov_rready_stall_cycles = 0;
        cov_rready_stall_completed = 0;
        req = dma_cmd_item::type_id::create("dma_rready_stall_req");
        req.ext_addr = 64'h0000_fa00;
        req.spad_addr = 32'h0800;
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 4;
        seq = dma_one_command_sequence::type_id::create("dma_rready_stall_seq");
        seq.item = req;
        accepted_base = env.axi_rsp.accepted_ids.size();
        completed_base = env.axi_rsp.completed_ids.size();
        cfg.min_accepted_reads_before_response = 4;
        cfg.inject_read_error = 0;
        cfg.inject_write_error = 0;
        // Arm the stall before the responder can assert its first RVALID.
        // Waiting for RVALID and only then forcing RREADY races the first
        // accepting edge in VCS and can duplicate beat zero on release.
        if (!uvm_hdl_force("tb_ai_dma_spad_subsystem_uvm.dma_dut.m_axi_rready", 1'b0))
            `uvm_fatal("DMA_RREADY_STALL", "failed to force the DUT-side RREADY net low")

        fork
            begin
                fork : bounded_rready_sequence
                    begin
                        seq.start(env.cmd_sqr);
                        seq_done = 1;
                    end
                    begin
                        repeat (20000) @(posedge sys_vif.clk);
                        if (!seq_done)
                            `uvm_error("DMA_RREADY_STALL", "DMA sequence exceeded 20000-cycle watchdog")
                    end
                join_any
                disable bounded_rready_sequence;
            end
            begin : find_and_hold_rvalid
                wait_cycles = 0;
                while (!found_rvalid && wait_cycles < 10000) begin
                    @(negedge sys_vif.clk);
                    wait_cycles++;
                    if (env.axi_rsp.vif.rvalid === 1'b1) begin
                        found_rvalid = 1;
                        held_rid = env.axi_rsp.vif.rid;
                        held_rdata = env.axi_rsp.vif.rdata;
                        held_rresp = env.axi_rsp.vif.rresp;
                        held_rlast = env.axi_rsp.vif.rlast;
                    end
                end
                if (!found_rvalid) begin
                    `uvm_error("DMA_RREADY_STALL", "RVALID did not assert within 10000 cycles")
                end else begin
                    for (int unsigned cycle = 0; cycle < rready_stall_cycles_requested; cycle++) begin
                        @(posedge sys_vif.clk);
                        #1;
                        stall_cycles++;
                        if (env.axi_rsp.vif.rready !== 1'b0 ||
                            env.axi_rsp.vif.rvalid !== 1'b1 ||
                            {env.axi_rsp.vif.rid, env.axi_rsp.vif.rdata,
                             env.axi_rsp.vif.rresp, env.axi_rsp.vif.rlast} !==
                            {held_rid, held_rdata, held_rresp, held_rlast})
                            `uvm_error("DMA_RREADY_STALL", $sformatf(
                                "R channel changed during stall cycle %0d", cycle + 1))
                    end
                end
                if (!uvm_hdl_release("tb_ai_dma_spad_subsystem_uvm.dma_dut.m_axi_rready"))
                    `uvm_fatal("DMA_RREADY_STALL", "failed to release the DUT-side RREADY net")
                released = 1;
            end
        join
        if (!released &&
            !uvm_hdl_release("tb_ai_dma_spad_subsystem_uvm.dma_dut.m_axi_rready"))
            `uvm_fatal("DMA_RREADY_STALL", "failed to clean up the DUT-side RREADY force")
        cfg.min_accepted_reads_before_response = 2;
        if (found_rvalid) begin
            cov_rready_stall_cycles = stall_cycles;
            wait_cycles = 0;
            while (!seq_done && wait_cycles < 10000) begin
                @(posedge sys_vif.clk);
                wait_cycles++;
            end
            if (!seq_done)
                `uvm_error("DMA_RREADY_STALL", "DMA sequence did not complete within 10000 cycles after release")
            repeat (2) @(posedge sys_vif.clk);
            if (env.axi_rsp.active_read != null || env.axi_rsp.pending_reads.size() != 0 ||
                (env.axi_rsp.completed_ids.size() - completed_base) != 4 ||
                (env.axi_rsp.accepted_ids.size() - accepted_base) != 4 ||
                env.cmd_drv.vif.busy || env.cmd_drv.vif.rd_outstanding != 0)
                `uvm_error("DMA_RREADY_STALL", $sformatf(
                    "post-release drain incomplete accepted/completed=%0d/%0d live=%0b pending=%0d busy/outstanding=%0b/%0d",
                    env.axi_rsp.accepted_ids.size() - accepted_base,
                    env.axi_rsp.completed_ids.size() - completed_base,
                    env.axi_rsp.active_read != null, env.axi_rsp.pending_reads.size(),
                    env.cmd_drv.vif.busy, env.cmd_drv.vif.rd_outstanding))
            env.sb.check_complete();
            for (int unsigned word = 0; word < 32; word++) begin
                bit [31:0] value;
                host_read_word(req.spad_addr + word * 4, value);
                if (value !== dma_memory_word(req.ext_addr + word * 4))
                    `uvm_error("DMA_RREADY_STALL", $sformatf(
                        "SPAD word %0d=0x%08h expected=0x%08h", word, value,
                        dma_memory_word(req.ext_addr + word * 4)))
            end
            cov_rready_stall_completed = 1;
            dma_rready_stall_cg.sample();
            if (uvm_report_server::get_server().get_severity_count(UVM_ERROR) == errors_before)
                `uvm_info("DMA_RREADY_STALL_PASS", $sformatf(
                    "%0d-cycle AXI RREADY stall held R payload stable; DMA drained and 32 SPAD words matched the memory oracle",
                    rready_stall_cycles_requested), UVM_LOW)
            else
                `uvm_error("DMA_RREADY_STALL", "scenario failed; PASS marker suppressed")
        end
    endtask

    task run_banked_response_owner_probe();
        bit [31:0] expected_lane[4];
        bit grant_seen;
        bit response_seen;
        int unsigned poll;

        grant_seen = 1'b0;
        response_seen = 1'b0;
        for (int unsigned lane = 0; lane < 4; lane++)
            expected_lane[lane] = 32'hc001_0000 ^ ((32'h100 + (lane * 4)) >> 2);

        // Permit the four aligned physical banks for execute/read.  The
        // request then traverses the real production arbiter and SRAM read
        // pipeline; only the requester itself is testbench driven.
        @(negedge sys_vif.clk);
        sys_vif.region0_base <= 32'h0000_0100;
        sys_vif.region0_limit <= 32'h0000_0200;
        sys_vif.region0_perm <= 4'b1101;
        repeat (2) @(posedge sys_vif.clk);

        @(negedge sys_vif.clk);
        sys_vif.banked_addr <= 32'h0000_0100;
        sys_vif.banked_valid <= 1'b1;
        for (poll = 0; poll < 32; poll++) begin
            @(posedge sys_vif.clk);
            if (sys_vif.banked_ready) begin
                if (sys_vif.request_client !== 3'd3)
                    `uvm_fatal("SPAD_BANKED_OWNER", $sformatf(
                        "banked request granted with request_client=%0d",
                        sys_vif.request_client))
                grant_seen = 1'b1;
                break;
            end
        end
        if (!grant_seen)
            `uvm_fatal("SPAD_BANKED_OWNER", "real banked requester was not granted")

        @(negedge sys_vif.clk);
        sys_vif.banked_valid <= 1'b0;
        for (poll = 0; poll < 16; poll++) begin
            @(posedge sys_vif.clk);
            #1;
            if (sys_vif.banked_rsp_valid) begin
                if (!sys_vif.arb_rsp_valid ||
                    sys_vif.arb_rsp_client !== 3'd3 ||
                    sys_vif.arb_rsp_is_line !== 1'b0 ||
                    sys_vif.desc_rsp_valid || sys_vif.core_rsp_valid ||
                    sys_vif.dma_rsp_valid || sys_vif.dma_line_rsp_valid ||
                    (|sys_vif.cnm_rsp_valid))
                    `uvm_fatal("SPAD_BANKED_OWNER", $sformatf(
                        "response owner mismatch: arb_valid=%0b client=%0d line=%0b desc=%0b core=%0b dma=%0b dma_line=%0b cnm=%b",
                        sys_vif.arb_rsp_valid, sys_vif.arb_rsp_client,
                        sys_vif.arb_rsp_is_line, sys_vif.desc_rsp_valid,
                        sys_vif.core_rsp_valid, sys_vif.dma_rsp_valid,
                        sys_vif.dma_line_rsp_valid, sys_vif.cnm_rsp_valid))
                if (sys_vif.banked_data0 !== expected_lane[0] ||
                    sys_vif.banked_data1 !== expected_lane[1] ||
                    sys_vif.banked_data2 !== expected_lane[2] ||
                    sys_vif.banked_data3 !== expected_lane[3])
                    `uvm_fatal("SPAD_BANKED_OWNER", $sformatf(
                        "banked read data mismatch: got={%08h,%08h,%08h,%08h} expected={%08h,%08h,%08h,%08h}",
                        sys_vif.banked_data3, sys_vif.banked_data2,
                        sys_vif.banked_data1, sys_vif.banked_data0,
                        expected_lane[3], expected_lane[2],
                        expected_lane[1], expected_lane[0]))
                response_seen = 1'b1;
                break;
            end
        end
        if (!response_seen)
            `uvm_fatal("SPAD_BANKED_OWNER", "tagged banked response did not return")
        // Keep the run phase active through the next sampling edge.  The
        // registered response is asserted after its launching edge and the
        // assertion samples it at the following positive edge.
        @(posedge sys_vif.clk);
        #1;
        @(negedge sys_vif.clk);
        sys_vif.region0_perm <= 4'b0000;
        `uvm_info("SPAD_BANKED_OWNER_PASS", $sformatf(
            "real ai_accel_memory_fabric banked request grant/response owner tag=3; aligned row=0x100; four bank words match the independent host-write image"), UVM_LOW)
    endtask

    task run_banked_core_owner_contention();
        bit [31:0] expected_core;
        bit [31:0] expected_lane[4];
        bit core_accept_seen;
        bit banked_accept_seen;
        bit core_response_seen;
        bit banked_response_seen;

        expected_core = 32'hc001_0000 ^ (32'h17c >> 2);
        for (int unsigned lane = 0; lane < 4; lane++)
            expected_lane[lane] = 32'hc001_0000 ^ ((32'h100 + (lane * 4)) >> 2);
        core_accept_seen = 1'b0;
        banked_accept_seen = 1'b0;
        core_response_seen = 1'b0;
        banked_response_seen = 1'b0;
        cov_banked_core_pair_accepted = 0;
        cov_banked_core_response_pair_checked = 0;

        // The reset value of data_rr_r gives the scalar core the first turn;
        // accepting it advances arbitration to the banked Matrix-like client.
        // Both addresses are independently initialized in the SPAD image.
        @(negedge sys_vif.clk);
        sys_vif.region0_base <= 32'h0000_0100;
        sys_vif.region0_limit <= 32'h0000_0200;
        sys_vif.region0_perm <= 4'b1101;
        repeat (2) @(posedge sys_vif.clk);

        @(negedge sys_vif.clk);
        sys_vif.core_write <= 1'b0;
        sys_vif.core_addr <= 32'h0000_017c;
        sys_vif.core_valid <= 1'b1;
        sys_vif.banked_addr <= 32'h0000_0100;
        sys_vif.banked_valid <= 1'b1;

        @(posedge sys_vif.clk);
        if (!sys_vif.core_ready || sys_vif.banked_ready ||
            sys_vif.request_client !== 3'd2)
            `uvm_fatal("SPAD_BANKED_CORE_CONTENTION", $sformatf(
                "first arbitration turn mismatch: core_ready=%0b banked_ready=%0b requester=%0d",
                sys_vif.core_ready, sys_vif.banked_ready, sys_vif.request_client))
        core_accept_seen = 1'b1;

        @(negedge sys_vif.clk);
        sys_vif.core_valid <= 1'b0;
        @(posedge sys_vif.clk);
        if (!sys_vif.banked_ready || sys_vif.core_ready ||
            sys_vif.request_client !== 3'd3)
            `uvm_fatal("SPAD_BANKED_CORE_CONTENTION", $sformatf(
                "banked turn after core acceptance mismatch: core_ready=%0b banked_ready=%0b requester=%0d",
                sys_vif.core_ready, sys_vif.banked_ready, sys_vif.request_client))
        banked_accept_seen = 1'b1;
        #1;
        if (!sys_vif.core_rsp_valid || !sys_vif.arb_rsp_valid ||
            sys_vif.arb_rsp_client !== 3'd2 || sys_vif.arb_rsp_is_line ||
            sys_vif.banked_rsp_valid || sys_vif.dma_rsp_valid ||
            sys_vif.dma_line_rsp_valid || sys_vif.desc_rsp_valid ||
            (|sys_vif.cnm_rsp_valid) ||
            sys_vif.core_rsp_error || sys_vif.arb_rsp_error ||
            sys_vif.core_rdata !== expected_core)
            `uvm_fatal("SPAD_BANKED_CORE_CONTENTION", $sformatf(
                "core response owner/data mismatch: arb=%0b client=%0d core=%0b banked=%0b data=%08h expected=%08h error=%0b",
                sys_vif.arb_rsp_valid, sys_vif.arb_rsp_client,
                sys_vif.core_rsp_valid, sys_vif.banked_rsp_valid,
                sys_vif.core_rdata, expected_core, sys_vif.arb_rsp_error))
        core_response_seen = 1'b1;

        @(negedge sys_vif.clk);
        sys_vif.banked_valid <= 1'b0;
        @(posedge sys_vif.clk);
        #1;
        if (!sys_vif.banked_rsp_valid || !sys_vif.arb_rsp_valid ||
            sys_vif.arb_rsp_client !== 3'd3 || sys_vif.arb_rsp_is_line ||
            sys_vif.core_rsp_valid || sys_vif.dma_rsp_valid ||
            sys_vif.dma_line_rsp_valid || sys_vif.desc_rsp_valid ||
            (|sys_vif.cnm_rsp_valid) || sys_vif.arb_rsp_error ||
            sys_vif.banked_data0 !== expected_lane[0] ||
            sys_vif.banked_data1 !== expected_lane[1] ||
            sys_vif.banked_data2 !== expected_lane[2] ||
            sys_vif.banked_data3 !== expected_lane[3])
            `uvm_fatal("SPAD_BANKED_CORE_CONTENTION", $sformatf(
                "banked response owner/data mismatch: arb=%0b client=%0d core=%0b banked=%0b lanes={%08h,%08h,%08h,%08h}",
                sys_vif.arb_rsp_valid, sys_vif.arb_rsp_client,
                sys_vif.core_rsp_valid, sys_vif.banked_rsp_valid,
                sys_vif.banked_data3, sys_vif.banked_data2,
                sys_vif.banked_data1, sys_vif.banked_data0))
        banked_response_seen = 1'b1;
        // Keep the run phase alive through the assertion sampling edge after
        // the registered response becomes visible to the UVM task.
        @(posedge sys_vif.clk);
        #1;

        if (!(core_accept_seen && banked_accept_seen &&
              core_response_seen && banked_response_seen))
            `uvm_fatal("SPAD_BANKED_CORE_CONTENTION",
                "contention scenario did not observe both accepted requests and tagged responses")
        cov_banked_core_pair_accepted = 1;
        cov_banked_core_response_pair_checked = 1;
        banked_core_contention_cg.sample();
        @(negedge sys_vif.clk);
        sys_vif.region0_perm <= 4'b0000;
        `uvm_info("SPAD_BANKED_CORE_CONTENTION_PASS",
            "simultaneous scalar and banked reads were serialized by the real arbiter; each response retained its owner and Golden data",
            UVM_LOW)
    endtask

    task run_banked_core_reset_epoch();
        bit [31:0] expected_core;
        bit [31:0] expected_lane[4];
        bit core_accept_seen;
        bit banked_accept_seen;
        bit first_core_owner;
        bit first_response_seen;
        bit reset_asserted;
        bit reset_released;
        bit recovery_core_accept_seen;
        bit recovery_banked_accept_seen;
        bit recovery_first_core_owner;
        bit recovery_first_response_seen;
        bit recovery_core_response_seen;
        bit recovery_banked_response_seen;
        int unsigned poll;

        expected_core = 32'hc001_0000 ^ (32'h17c >> 2);
        for (int unsigned lane = 0; lane < 4; lane++)
            expected_lane[lane] = 32'hc001_0000 ^ ((32'h100 + (lane * 4)) >> 2);
        core_accept_seen = 1'b0;
        banked_accept_seen = 1'b0;
        first_core_owner = 1'b0;
        first_response_seen = 1'b0;
        reset_asserted = 1'b0;
        reset_released = 1'b0;
        recovery_core_accept_seen = 1'b0;
        recovery_banked_accept_seen = 1'b0;
        recovery_first_core_owner = 1'b0;
        recovery_first_response_seen = 1'b0;
        recovery_core_response_seen = 1'b0;
        recovery_banked_response_seen = 1'b0;
        cov_banked_core_reset_pair_accepted = 0;
        cov_banked_core_reset_first_response_checked = 0;
        cov_banked_core_reset_pending_banked_flushed = 0;
        cov_banked_core_reset_recovery_pair_checked = 0;

        // The subsystem setup may have advanced the data round-robin pointer.
        // Establish a fresh epoch to discard any setup traffic. The focused
        // pair below follows whichever legal client the arbiter selects first.
        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b1;
        reset_asserted = 1'b0;
        for (poll = 0; poll < 8; poll++) begin
            @(negedge sys_vif.clk);
            #1;
            if (sys_vif.subsystem_reset_ack === 1'b1) begin
                reset_asserted = 1'b1;
                break;
            end
        end
        if (!reset_asserted || sys_vif.resetn !== 1'b0)
            `uvm_fatal("SPAD_BANKED_CORE_RESET", "initial epoch reset assertion timed out")
        repeat (2) @(posedge sys_vif.clk);
        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b0;
        reset_released = 1'b0;
        for (poll = 0; poll < 8; poll++) begin
            @(negedge sys_vif.clk);
            #1;
            if (sys_vif.subsystem_reset_ack === 1'b0) begin
                reset_released = 1'b1;
                break;
            end
        end
        if (!reset_released || sys_vif.resetn !== 1'b1)
            `uvm_fatal("SPAD_BANKED_CORE_RESET", "initial epoch reset release timed out")

        // Use the real fabric and round-robin arbiter, with a legal shared
        // execute/read window and independently initialized SPAD words.
        @(negedge sys_vif.clk);
        sys_vif.region0_base <= 32'h0000_0100;
        sys_vif.region0_limit <= 32'h0000_0200;
        sys_vif.region0_perm <= 4'b1101;
        repeat (2) @(posedge sys_vif.clk);

        // Keep both requests asserted. The other client must be accepted on
        // the following round-robin turn, coincident with the first response.
        @(negedge sys_vif.clk);
        sys_vif.core_write <= 1'b0;
        sys_vif.core_addr <= 32'h0000_017c;
        sys_vif.core_valid <= 1'b1;
        sys_vif.banked_addr <= 32'h0000_0100;
        sys_vif.banked_valid <= 1'b1;
        @(posedge sys_vif.clk);
        if (sys_vif.core_ready && !sys_vif.banked_ready &&
            sys_vif.request_client === 3'd2) begin
            core_accept_seen = 1'b1;
            first_core_owner = 1'b1;
        end else if (sys_vif.banked_ready && !sys_vif.core_ready &&
                     sys_vif.request_client === 3'd3) begin
            banked_accept_seen = 1'b1;
            first_core_owner = 1'b0;
        end else
            `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                "arbiter did not grant exactly one requester: core_valid=%0b core_ready=%0b banked_valid=%0b banked_ready=%0b requester=%0d",
                sys_vif.core_valid, sys_vif.core_ready, sys_vif.banked_valid,
                sys_vif.banked_ready, sys_vif.request_client))
        if (!first_core_owner)
            `uvm_fatal("SPAD_BANKED_CORE_RESET",
                "fresh reset epoch did not start at Core; cannot establish the directed pending-Banked reset case")

        @(negedge sys_vif.clk);
        if (first_core_owner)
            sys_vif.core_valid <= 1'b0;
        else
            sys_vif.banked_valid <= 1'b0;
        @(posedge sys_vif.clk);
        if (first_core_owner) begin
            if (!sys_vif.banked_ready || sys_vif.core_ready ||
                sys_vif.request_client !== 3'd3)
                `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                    "Banked requester was not accepted on the turn after Core: requester=%0d core_ready=%0b banked_ready=%0b",
                    sys_vif.request_client, sys_vif.core_ready, sys_vif.banked_ready))
            banked_accept_seen = 1'b1;
        end else begin
            if (!sys_vif.core_ready || sys_vif.banked_ready ||
                sys_vif.request_client !== 3'd2)
                `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                    "Core requester was not accepted on the turn after Banked: requester=%0d core_ready=%0b banked_ready=%0b",
                    sys_vif.request_client, sys_vif.core_ready, sys_vif.banked_ready))
            core_accept_seen = 1'b1;
        end
        #1;
        if (first_core_owner) begin
            if (!sys_vif.core_rsp_valid || !sys_vif.arb_rsp_valid ||
                sys_vif.arb_rsp_client !== 3'd2 || sys_vif.arb_rsp_is_line ||
                sys_vif.banked_rsp_valid || sys_vif.dma_rsp_valid ||
                sys_vif.dma_line_rsp_valid || sys_vif.desc_rsp_valid ||
                (|sys_vif.cnm_rsp_valid) || sys_vif.arb_rsp_error ||
                sys_vif.core_rsp_error || sys_vif.core_rdata !== expected_core)
                `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                    "Core-first response owner/data mismatch while Banked is pending: owner=%0d core_rsp=%0b banked_rsp=%0b data=%08h expected=%08h error=%0b",
                    sys_vif.arb_rsp_client, sys_vif.core_rsp_valid,
                    sys_vif.banked_rsp_valid, sys_vif.core_rdata,
                    expected_core, sys_vif.arb_rsp_error))
        end else if (!sys_vif.banked_rsp_valid || !sys_vif.arb_rsp_valid ||
                     sys_vif.arb_rsp_client !== 3'd3 || sys_vif.arb_rsp_is_line ||
                     sys_vif.core_rsp_valid || sys_vif.dma_rsp_valid ||
                     sys_vif.dma_line_rsp_valid || sys_vif.desc_rsp_valid ||
                     (|sys_vif.cnm_rsp_valid) || sys_vif.arb_rsp_error ||
                     sys_vif.banked_data0 !== expected_lane[0] ||
                     sys_vif.banked_data1 !== expected_lane[1] ||
                     sys_vif.banked_data2 !== expected_lane[2] ||
                     sys_vif.banked_data3 !== expected_lane[3]) begin
            `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                "Banked-first response owner/data mismatch: owner=%0d core_rsp=%0b banked_rsp=%0b lanes={%08h,%08h,%08h,%08h}",
                sys_vif.arb_rsp_client, sys_vif.core_rsp_valid,
                sys_vif.banked_rsp_valid, sys_vif.banked_data3,
                sys_vif.banked_data2, sys_vif.banked_data1,
                sys_vif.banked_data0))
        end
        first_response_seen = 1'b1;
        cov_banked_core_reset_pair_accepted = core_accept_seen && banked_accept_seen;
        cov_banked_core_reset_first_response_checked = first_response_seen;

        // The second read has been accepted into the registered response
        // stage, but its banked response is not visible yet. Assert the shared
        // reset request before the next active edge and check the old epoch is
        // discarded rather than delivered after release.
        sys_vif.core_valid <= 1'b0;
        sys_vif.banked_valid <= 1'b0;
        sys_vif.subsystem_reset_req <= 1'b1;
        for (poll = 0; poll < 8; poll++) begin
            @(negedge sys_vif.clk);
            #1;
            if (sys_vif.subsystem_reset_ack === 1'b1) begin
                reset_asserted = 1'b1;
                break;
            end
        end
        if (!reset_asserted || sys_vif.resetn !== 1'b0)
            `uvm_fatal("SPAD_BANKED_CORE_RESET", "shared reset assertion handshake timed out")
        repeat (2) begin
            @(posedge sys_vif.clk);
            #1;
            if (sys_vif.arb_rsp_valid !== 1'b0 ||
                sys_vif.banked_rsp_valid !== 1'b0 ||
                sys_vif.desc_rsp_valid !== 1'b0 ||
                sys_vif.core_rsp_valid !== 1'b0 ||
                sys_vif.dma_rsp_valid !== 1'b0 ||
                sys_vif.dma_line_rsp_valid !== 1'b0 ||
                (|sys_vif.cnm_rsp_valid))
                `uvm_fatal("SPAD_BANKED_CORE_RESET",
                    "fabric response owner remained active during shared reset")
        end

        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b0;
        for (poll = 0; poll < 8; poll++) begin
            @(negedge sys_vif.clk);
            #1;
            if (sys_vif.subsystem_reset_ack === 1'b0) begin
                reset_released = 1'b1;
                break;
            end
        end
        if (!reset_released || sys_vif.resetn !== 1'b1)
            `uvm_fatal("SPAD_BANKED_CORE_RESET", "shared reset release handshake timed out")

        repeat (4) begin
            @(posedge sys_vif.clk);
            #1;
            if (sys_vif.arb_rsp_valid !== 1'b0 ||
                sys_vif.banked_rsp_valid !== 1'b0 ||
                sys_vif.desc_rsp_valid !== 1'b0 ||
                sys_vif.core_rsp_valid !== 1'b0 ||
                sys_vif.dma_rsp_valid !== 1'b0 ||
                sys_vif.dma_line_rsp_valid !== 1'b0 ||
                (|sys_vif.cnm_rsp_valid))
                `uvm_fatal("SPAD_BANKED_CORE_RESET",
                    "pre-reset Banked owner leaked into the post-reset quiet interval")
        end
        cov_banked_core_reset_pending_banked_flushed = 1;

        // Exercise both owners again in the new epoch and compare each result
        // to the independent initialized memory image.
        @(negedge sys_vif.clk);
        sys_vif.core_valid <= 1'b1;
        sys_vif.core_addr <= 32'h0000_017c;
        sys_vif.banked_valid <= 1'b1;
        sys_vif.banked_addr <= 32'h0000_0100;
        @(posedge sys_vif.clk);
        if (sys_vif.core_ready && !sys_vif.banked_ready &&
            sys_vif.request_client === 3'd2) begin
            recovery_core_accept_seen = 1'b1;
            recovery_first_core_owner = 1'b1;
        end else if (sys_vif.banked_ready && !sys_vif.core_ready &&
                     sys_vif.request_client === 3'd3) begin
            recovery_banked_accept_seen = 1'b1;
            recovery_first_core_owner = 1'b0;
        end else
            `uvm_fatal("SPAD_BANKED_CORE_RESET", "recovery arbiter did not grant exactly one requester")
        if (!recovery_first_core_owner)
            `uvm_fatal("SPAD_BANKED_CORE_RESET",
                "post-reset recovery did not restart at Core as required by the reset arbitration contract")

        @(negedge sys_vif.clk);
        if (recovery_first_core_owner)
            sys_vif.core_valid <= 1'b0;
        else
            sys_vif.banked_valid <= 1'b0;
        @(posedge sys_vif.clk);
        if (recovery_first_core_owner) begin
            if (!sys_vif.banked_ready || sys_vif.core_ready ||
                sys_vif.request_client !== 3'd3)
                `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                    "Banked recovery requester was not accepted after Core: requester=%0d core_ready=%0b banked_ready=%0b",
                    sys_vif.request_client, sys_vif.core_ready, sys_vif.banked_ready))
            recovery_banked_accept_seen = 1'b1;
        end else begin
            if (!sys_vif.core_ready || sys_vif.banked_ready ||
                sys_vif.request_client !== 3'd2)
                `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                    "Core recovery requester was not accepted after Banked: requester=%0d core_ready=%0b banked_ready=%0b",
                    sys_vif.request_client, sys_vif.core_ready, sys_vif.banked_ready))
            recovery_core_accept_seen = 1'b1;
        end
        #1;
        if (recovery_first_core_owner) begin
            if (!sys_vif.core_rsp_valid || !sys_vif.arb_rsp_valid ||
                sys_vif.arb_rsp_client !== 3'd2 || sys_vif.arb_rsp_is_line ||
                sys_vif.arb_rsp_error || sys_vif.core_rsp_error ||
                sys_vif.core_rdata !== expected_core || sys_vif.banked_rsp_valid ||
                sys_vif.dma_rsp_valid || sys_vif.dma_line_rsp_valid ||
                sys_vif.desc_rsp_valid || (|sys_vif.cnm_rsp_valid))
                `uvm_fatal("SPAD_BANKED_CORE_RESET", $sformatf(
                    "Core recovery response owner/data mismatch: arb=%0b client=%0d core=%0b banked=%0b data=%08h expected=%08h",
                    sys_vif.arb_rsp_valid, sys_vif.arb_rsp_client,
                    sys_vif.core_rsp_valid, sys_vif.banked_rsp_valid,
                    sys_vif.core_rdata, expected_core))
            recovery_core_response_seen = 1'b1;
        end else begin
            if (!sys_vif.banked_rsp_valid || !sys_vif.arb_rsp_valid ||
                sys_vif.arb_rsp_client !== 3'd3 || sys_vif.arb_rsp_is_line ||
                sys_vif.arb_rsp_error || sys_vif.core_rsp_valid ||
                sys_vif.dma_rsp_valid || sys_vif.dma_line_rsp_valid ||
                sys_vif.desc_rsp_valid || (|sys_vif.cnm_rsp_valid) ||
                sys_vif.banked_data0 !== expected_lane[0] ||
                sys_vif.banked_data1 !== expected_lane[1] ||
                sys_vif.banked_data2 !== expected_lane[2] ||
                sys_vif.banked_data3 !== expected_lane[3])
                `uvm_fatal("SPAD_BANKED_CORE_RESET", "Banked recovery response owner/data mismatch")
            recovery_banked_response_seen = 1'b1;
        end
        recovery_first_response_seen = 1'b1;

        @(negedge sys_vif.clk);
        sys_vif.core_valid <= 1'b0;
        sys_vif.banked_valid <= 1'b0;
        @(posedge sys_vif.clk);
        #1;
        if (recovery_first_core_owner) begin
            if (!sys_vif.banked_rsp_valid || !sys_vif.arb_rsp_valid ||
                sys_vif.arb_rsp_client !== 3'd3 || sys_vif.arb_rsp_is_line ||
                sys_vif.core_rsp_valid || sys_vif.dma_rsp_valid ||
                sys_vif.dma_line_rsp_valid || sys_vif.desc_rsp_valid ||
                (|sys_vif.cnm_rsp_valid) || sys_vif.arb_rsp_error ||
                sys_vif.banked_data0 !== expected_lane[0] ||
                sys_vif.banked_data1 !== expected_lane[1] ||
                sys_vif.banked_data2 !== expected_lane[2] ||
                sys_vif.banked_data3 !== expected_lane[3])
                `uvm_fatal("SPAD_BANKED_CORE_RESET", "Banked recovery response owner/data mismatch")
            recovery_banked_response_seen = 1'b1;
        end else begin
            if (!sys_vif.core_rsp_valid || !sys_vif.arb_rsp_valid ||
                sys_vif.arb_rsp_client !== 3'd2 || sys_vif.arb_rsp_is_line ||
                sys_vif.banked_rsp_valid || sys_vif.dma_rsp_valid ||
                sys_vif.dma_line_rsp_valid || sys_vif.desc_rsp_valid ||
                (|sys_vif.cnm_rsp_valid) || sys_vif.arb_rsp_error ||
                sys_vif.core_rdata !== expected_core)
                `uvm_fatal("SPAD_BANKED_CORE_RESET", "Core recovery response owner/data mismatch")
            recovery_core_response_seen = 1'b1;
        end

        // Retain the visible response through assertion sampling, then report
        // the directed coverage sample and release the temporary permission.
        @(posedge sys_vif.clk);
        #1;
        if (!(recovery_core_accept_seen && recovery_banked_accept_seen &&
              recovery_first_response_seen &&
              recovery_core_response_seen && recovery_banked_response_seen))
            `uvm_fatal("SPAD_BANKED_CORE_RESET", "post-reset owner recovery was incomplete")
        cov_banked_core_reset_recovery_pair_checked = 1;
        banked_core_reset_epoch_cg.sample();
        @(negedge sys_vif.clk);
        sys_vif.region0_perm <= 4'b0000;
        `uvm_info("SPAD_BANKED_CORE_RESET_EPOCH_PASS",
            "simultaneous Core/Banked requests retained owner through one response, reset flushed the pending Banked response, and both owners recovered with Golden data",
            UVM_LOW)
    endtask

    task run_banked_response_reset_epoch();
        bit [31:0] expected_lane[4];
        bit accepted_before_reset;
        bit reset_asserted;
        bit reset_released;
        bit recovery_grant_seen;
        bit recovery_response_seen;
        int unsigned poll;

        accepted_before_reset = 1'b0;
        reset_asserted = 1'b0;
        reset_released = 1'b0;
        recovery_grant_seen = 1'b0;
        recovery_response_seen = 1'b0;
        cov_banked_reset_flushed = 0;
        cov_banked_reset_recovered = 0;
        for (int unsigned lane = 0; lane < 4; lane++)
            expected_lane[lane] = 32'hc001_0000 ^ ((32'h100 + (lane * 4)) >> 2);

        @(negedge sys_vif.clk);
        sys_vif.region0_base <= 32'h0000_0100;
        sys_vif.region0_limit <= 32'h0000_0200;
        sys_vif.region0_perm <= 4'b1101;
        repeat (2) @(posedge sys_vif.clk);

        // Accept one real banked read, then request reset before the registered
        // arbiter response stage can emit its owner/data pulse.
        @(negedge sys_vif.clk);
        sys_vif.banked_addr <= 32'h0000_0100;
        sys_vif.banked_valid <= 1'b1;
        for (poll = 0; poll < 32; poll++) begin
            @(posedge sys_vif.clk);
            if (sys_vif.banked_ready) begin
                if (sys_vif.request_client !== 3'd3)
                    `uvm_fatal("SPAD_BANKED_RESET", $sformatf(
                        "banked request granted with request_client=%0d",
                        sys_vif.request_client))
                accepted_before_reset = 1'b1;
                #1;
                if (sys_vif.arb_rsp_valid !== 1'b0 ||
                    sys_vif.banked_rsp_valid !== 1'b0)
                    `uvm_fatal("SPAD_BANKED_RESET",
                        "response was already visible before reset request; pending-response test is invalid")
                // The top-level reset driver samples this request on the
                // upcoming falling edge and asynchronously clears the fabric's
                // registered owner/response stages before the next SPAD edge.
                sys_vif.banked_valid <= 1'b0;
                sys_vif.subsystem_reset_req <= 1'b1;
                break;
            end
        end
        if (!accepted_before_reset)
            `uvm_fatal("SPAD_BANKED_RESET", "banked read was not accepted")

        for (poll = 0; poll < 8; poll++) begin
            @(negedge sys_vif.clk);
            #1;
            if (sys_vif.subsystem_reset_ack === 1'b1) begin
                reset_asserted = 1'b1;
                break;
            end
        end
        if (!reset_asserted || sys_vif.resetn !== 1'b0)
            `uvm_fatal("SPAD_BANKED_RESET", "shared reset assertion handshake timed out")
        repeat (2) begin
            @(posedge sys_vif.clk);
            #1;
            if (sys_vif.arb_rsp_valid !== 1'b0 ||
                sys_vif.banked_rsp_valid !== 1'b0 ||
                sys_vif.desc_rsp_valid !== 1'b0 ||
                sys_vif.core_rsp_valid !== 1'b0 ||
                sys_vif.dma_rsp_valid !== 1'b0 ||
                sys_vif.dma_line_rsp_valid !== 1'b0 ||
                (|sys_vif.cnm_rsp_valid))
                `uvm_fatal("SPAD_BANKED_RESET",
                    "stale fabric response was visible while reset was asserted")
        end

        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b0;
        for (poll = 0; poll < 8; poll++) begin
            @(negedge sys_vif.clk);
            #1;
            if (sys_vif.subsystem_reset_ack === 1'b0) begin
                reset_released = 1'b1;
                break;
            end
        end
        if (!reset_released || sys_vif.resetn !== 1'b1)
            `uvm_fatal("SPAD_BANKED_RESET", "shared reset release handshake timed out")

        // A quiet interval after release distinguishes a flushed response from
        // a delayed stale response that could be misattributed to recovery.
        repeat (4) begin
            @(posedge sys_vif.clk);
            #1;
            if (sys_vif.arb_rsp_valid !== 1'b0 ||
                sys_vif.banked_rsp_valid !== 1'b0 ||
                sys_vif.desc_rsp_valid !== 1'b0 ||
                sys_vif.core_rsp_valid !== 1'b0 ||
                sys_vif.dma_rsp_valid !== 1'b0 ||
                sys_vif.dma_line_rsp_valid !== 1'b0 ||
                (|sys_vif.cnm_rsp_valid))
                `uvm_fatal("SPAD_BANKED_RESET",
                    "pre-reset banked response leaked into the post-reset quiet interval")
        end
        cov_banked_reset_flushed = 1;

        // Issue fresh work on the same owner port and verify tag, exclusion,
        // four-bank data, and the normal SVA sampling edge after recovery.
        @(negedge sys_vif.clk);
        sys_vif.banked_addr <= 32'h0000_0100;
        sys_vif.banked_valid <= 1'b1;
        for (poll = 0; poll < 32; poll++) begin
            @(posedge sys_vif.clk);
            if (sys_vif.banked_ready) begin
                if (sys_vif.request_client !== 3'd3)
                    `uvm_fatal("SPAD_BANKED_RESET", $sformatf(
                        "recovery request granted with request_client=%0d",
                        sys_vif.request_client))
                recovery_grant_seen = 1'b1;
                break;
            end
        end
        if (!recovery_grant_seen)
            `uvm_fatal("SPAD_BANKED_RESET", "post-reset banked recovery read was not granted")

        @(negedge sys_vif.clk);
        sys_vif.banked_valid <= 1'b0;
        for (poll = 0; poll < 16; poll++) begin
            @(posedge sys_vif.clk);
            #1;
            if (sys_vif.banked_rsp_valid) begin
                if (!sys_vif.arb_rsp_valid ||
                    sys_vif.arb_rsp_client !== 3'd3 ||
                    sys_vif.arb_rsp_is_line !== 1'b0 ||
                    sys_vif.desc_rsp_valid || sys_vif.core_rsp_valid ||
                    sys_vif.dma_rsp_valid || sys_vif.dma_line_rsp_valid ||
                    (|sys_vif.cnm_rsp_valid))
                    `uvm_fatal("SPAD_BANKED_RESET", $sformatf(
                        "recovery response owner mismatch: valid=%0b client=%0d line=%0b",
                        sys_vif.arb_rsp_valid, sys_vif.arb_rsp_client,
                        sys_vif.arb_rsp_is_line))
                if (sys_vif.banked_data0 !== expected_lane[0] ||
                    sys_vif.banked_data1 !== expected_lane[1] ||
                    sys_vif.banked_data2 !== expected_lane[2] ||
                    sys_vif.banked_data3 !== expected_lane[3])
                    `uvm_fatal("SPAD_BANKED_RESET", $sformatf(
                        "recovery data mismatch: got={%08h,%08h,%08h,%08h} expected={%08h,%08h,%08h,%08h}",
                        sys_vif.banked_data3, sys_vif.banked_data2,
                        sys_vif.banked_data1, sys_vif.banked_data0,
                        expected_lane[3], expected_lane[2],
                        expected_lane[1], expected_lane[0]))
                recovery_response_seen = 1'b1;
                break;
            end
        end
        if (!recovery_response_seen)
            `uvm_fatal("SPAD_BANKED_RESET", "no tagged banked response after reset recovery")
        @(posedge sys_vif.clk);
        #1;
        cov_banked_reset_recovered = 1;
        banked_reset_epoch_cg.sample();
        @(negedge sys_vif.clk);
        sys_vif.region0_perm <= 4'b0000;
        `uvm_info("SPAD_BANKED_RESET_EPOCH_PASS", $sformatf(
            "accepted banked read flushed by reset with no stale response; tag-3 four-bank read recovers and matches independent image"), UVM_LOW)
    endtask

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg.external_spad_model = 1;
        cfg.enable_backpressure = 1;
        cfg.ooo_read_responses = 1;
        cfg.ooo_write_responses = 1;
        cfg.min_accepted_reads_before_response = 2;
        cfg.min_accepted_writes_before_response = 2;
        if (!uvm_config_db#(virtual ai_dma_spad_system_if)::get(
                this, "", "spad_system_vif", sys_vif))
            `uvm_fatal("NOVIF", "DMA-SPAD subsystem test needs spad_system_vif")
        uvm_config_db#(virtual ai_dma_spad_system_if)::set(
            this, "cont_mon", "spad_system_vif", sys_vif);
        cont_mon = dma_spad_subsystem_monitor::type_id::create("cont_mon", this);
    endfunction

    task host_write_word(bit [31:0] addr, bit [31:0] data);
        @(negedge sys_vif.clk);
        sys_vif.host_valid <= 1'b1;
        sys_vif.host_write <= 1'b1;
        sys_vif.host_addr <= addr;
        sys_vif.host_wdata <= data;
        sys_vif.host_wstrb <= 4'hf;
        @(posedge sys_vif.clk);
        @(negedge sys_vif.clk);
        sys_vif.host_valid <= 1'b0;
        sys_vif.host_write <= 1'b0;
        sys_vif.host_wstrb <= '0;
    endtask

    task host_read_word(bit [31:0] addr, output bit [31:0] data);
        @(negedge sys_vif.clk);
        sys_vif.host_valid <= 1'b1;
        sys_vif.host_write <= 1'b0;
        sys_vif.host_addr <= addr;
        sys_vif.host_wstrb <= '0;
        @(posedge sys_vif.clk);
        @(negedge sys_vif.clk);
        sys_vif.host_valid <= 1'b0;
        repeat (2) @(posedge sys_vif.clk);
        #1;
        if (sys_vif.host_error)
            `uvm_error("SPAD_HOST_READ", $sformatf("host read error at 0x%08h", addr))
        data = sys_vif.host_rdata;
    endtask

    task run_dma_reset_recovery(bit after_first_beat, bit overlap_cnm,
                                int unsigned cnm_reset_phase);
        dma_cmd_item req;
        dma_one_command_sequence seq;
        bit [31:0] expected_cnm_result, cnm_result_readback;
        int unsigned saved_core_reads, saved_core_responses;
        int unsigned saved_core_contended, saved_core_isolated;
        int unsigned saved_dma_contended, saved_dma_isolated;
        int unsigned saved_desc_grants, saved_cpl_grants, saved_dma_writes;
        int unsigned accepted_base, completed_base;
        int unsigned wait_cycles, cnm_wait_cycles;
        bit phase_seen, cancelled_seq_done;
        bit cnm_phase_seen, cnm_all_reads_returned, cnm_read_outstanding;
        if (overlap_cnm && after_first_beat)
            `uvm_fatal("DMA_CNM_RESET_CONFIG",
                "CNM overlap reset currently requires the all-R-before-response-stall DMA phase")
        if (cnm_reset_phase > 1)
            `uvm_fatal("DMA_CNM_RESET_CONFIG",
                $sformatf("invalid CNM shared-reset phase %0d", cnm_reset_phase))

        saved_core_reads = cont_mon.core_reads_accepted;
        saved_core_responses = cont_mon.core_responses_checked;
        saved_core_contended = cont_mon.core_grants_under_contention;
        saved_core_isolated = cont_mon.core_grants_isolated;
        saved_dma_contended = cont_mon.dma_grants_under_contention;
        saved_dma_isolated = cont_mon.dma_grants_isolated;
        saved_desc_grants = cont_mon.desc_priority_grants;
        saved_cpl_grants = cont_mon.cpl_priority_grants;
        saved_dma_writes = cont_mon.dma_write_grants;

        if (overlap_cnm) begin
            cont_mon.reset_cnm_stats();
            preload_cnm_operands(expected_cnm_result);
            host_write_word(32'h02a8, 32'hcafe_a8a8);
        end

        req = dma_cmd_item::type_id::create(after_first_beat ? "dma_reset_beat_req" : "dma_reset_ar_req");
        req.ext_addr = after_first_beat ? 64'h0000_f800 : 64'h0000_f600;
        req.spad_addr = after_first_beat ? 32'h0d80 : 32'h0d00;
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 4;
        seq = dma_one_command_sequence::type_id::create(after_first_beat ? "dma_reset_beat_seq" : "dma_reset_ar_seq");
        seq.item = req;
        accepted_base = env.axi_rsp.accepted_ids.size();
        completed_base = env.axi_rsp.completed_ids.size();
        env.axi_rsp.hold_read_responses = 1'b1;
        cfg.min_accepted_reads_before_response = 4;
        phase_seen = 0;
        cancelled_seq_done = 0;
        fork
            begin seq.start(env.cmd_sqr); cancelled_seq_done = 1; end
        join_none
        // Queue/class fields do not reliably wake a procedural wait expression
        // on all simulators. Poll at the clock boundary so the setup check is
        // deterministic and bounded.
        wait_cycles = 0;
        while (!phase_seen && wait_cycles < 500) begin
            @(posedge sys_vif.clk);
            #1;
            wait_cycles++;
            if (env.axi_rsp.accepted_ids.size() >= accepted_base + 4) begin
                if (!after_first_beat) begin
                    phase_seen = (env.axi_rsp.completed_ids.size() == completed_base);
                end else begin
                    // Allow the first response to start only after all four
                    // reads are accepted; then stop RREADY immediately after
                    // its first beat handshake.
                    env.axi_rsp.hold_read_responses = 1'b0;
                    if (env.axi_rsp.active_read != null &&
                        env.axi_rsp.active_read.beat_index == 1) begin
                        env.axi_rsp.vif.hold_rready_low();
                        phase_seen = 1;
                    end
                end
            end
        end
        if (!phase_seen) begin
            `uvm_error("DMA_RESET_SETUP", $sformatf("reset phase %0d not observed; accepted=%0d active=%0b pending=%0d",
                after_first_beat, env.axi_rsp.accepted_ids.size() - accepted_base,
                env.axi_rsp.active_read != null, env.axi_rsp.pending_reads.size()))
            if (after_first_beat) env.axi_rsp.vif.release_rready();
            env.axi_rsp.hold_read_responses = 1'b0;
            cfg.min_accepted_reads_before_response = 2;
            return;
        end
        if (env.cmd_drv.vif.rd_outstanding !== 3'd4)
            `uvm_error("DMA_RESET_SETUP", $sformatf("expected four DMA read slots outstanding, saw %0d",
                env.cmd_drv.vif.rd_outstanding))
        cont_mon.sample_dma_reset_phase(after_first_beat ? 1 : 0);

        if (overlap_cnm) begin
            @(negedge sys_vif.clk);
            sys_vif.cnm_op_mode <= 8'h20;
            sys_vif.cnm_src0_base <= 32'h0100;
            sys_vif.cnm_src1_base <= 32'h0200;
            sys_vif.cnm_dst_base <= 32'h02a8;
            sys_vif.cnm_length <= 16'd8;
            sys_vif.cnm_m_size <= 16'd1;
            sys_vif.cnm_scale_shift <= 5'd0;
            sys_vif.cnm_activation <= 2'd0;
            sys_vif.cnm_watchdog_limit <= 32'd10000;
            sys_vif.cnm_abort <= 1'b0;
            sys_vif.cnm_mode <= 1'b1;
            @(negedge sys_vif.clk);
            sys_vif.cnm_start <= 1'b1;
            @(negedge sys_vif.clk);
            sys_vif.cnm_start <= 1'b0;

            cnm_phase_seen = 1'b0;
            cnm_wait_cycles = 0;
            while (!cnm_phase_seen && cnm_wait_cycles < 200) begin
                @(posedge sys_vif.clk);
                #1;
                cnm_wait_cycles++;
                cnm_all_reads_returned = 1'b1;
                for (int lane = 0; lane < 4; lane++) begin
                    if (cont_mon.cnm_lane_reads_accepted[lane] != 16 ||
                        cont_mon.cnm_lane_responses_checked[lane] != 16)
                        cnm_all_reads_returned = 1'b0;
                end
                cnm_read_outstanding =
                    cont_mon.expected_cnm_lane_data0.size() != 0 ||
                    cont_mon.expected_cnm_lane_data1.size() != 0 ||
                    cont_mon.expected_cnm_lane_data2.size() != 0 ||
                    cont_mon.expected_cnm_lane_data3.size() != 0;
                if (cnm_reset_phase == 1) begin
                    cnm_phase_seen = cnm_all_reads_returned &&
                        sys_vif.cnm_busy === 1'b1 &&
                        sys_vif.cnm_spad_valid === 1'b0 &&
                        cont_mon.cnm_spad_writes_accepted == 0;
                end else begin
                    cnm_phase_seen = cnm_read_outstanding &&
                        sys_vif.cnm_busy === 1'b1;
                end
                cnm_phase_seen = cnm_phase_seen &&
                    env.cmd_drv.vif.busy === 1'b1 &&
                    env.cmd_drv.vif.rd_outstanding === 3'd4 &&
                    env.axi_rsp.completed_ids.size() == completed_base;
            end
            if (!cnm_phase_seen) begin
                `uvm_error("DMA_CNM_RESET_SETUP", $sformatf(
                    "overlap phase=%0d not observed: CNM reads/responses=%0d/%0d,%0d/%0d,%0d/%0d,%0d/%0d busy=%0b pending=%0b writes=%0d DMA busy/outstanding=%0b/%0d completed=%0d base=%0d",
                    cnm_reset_phase,
                    cont_mon.cnm_lane_reads_accepted[0], cont_mon.cnm_lane_responses_checked[0],
                    cont_mon.cnm_lane_reads_accepted[1], cont_mon.cnm_lane_responses_checked[1],
                    cont_mon.cnm_lane_reads_accepted[2], cont_mon.cnm_lane_responses_checked[2],
                    cont_mon.cnm_lane_reads_accepted[3], cont_mon.cnm_lane_responses_checked[3],
                    sys_vif.cnm_busy, cnm_read_outstanding, cont_mon.cnm_spad_writes_accepted,
                    env.cmd_drv.vif.busy, env.cmd_drv.vif.rd_outstanding,
                    env.axi_rsp.completed_ids.size(), completed_base))
            end else begin
                cont_mon.sample_cnm_reset_phase(cnm_reset_phase);
                cont_mon.sample_dma_cnm_shared_reset(env.cmd_drv.vif.rd_outstanding,
                                                      cnm_reset_phase);
                if (cnm_reset_phase == 1)
                    `uvm_info("DMA_CNM_RESET_SETUP",
                        "observed four DMA reads outstanding while CNM completed all operand reads and awaited result write",
                        UVM_LOW)
                else
                    `uvm_info("DMA_CNM_RESET_SETUP",
                        "observed four DMA reads outstanding while CNM had an accepted SPAD read without its response",
                        UVM_LOW)
            end
        end
        sys_vif.subsystem_reset_req <= 1'b1;
        fork : wait_dma_reset_assert
            begin wait (sys_vif.subsystem_reset_ack === 1'b1); end
            begin repeat (10) @(posedge sys_vif.clk); end
        join_any
        disable wait_dma_reset_assert;
        if (sys_vif.subsystem_reset_ack !== 1'b1)
            `uvm_error("DMA_RESET_TIMEOUT", "shared subsystem reset assertion was not acknowledged")
        repeat (2) @(posedge sys_vif.clk);
        #1;
        if (env.cmd_drv.vif.busy !== 1'b0 || env.cmd_drv.vif.rd_outstanding !== 0 ||
            env.axi_rsp.active_read != null || env.axi_rsp.pending_reads.size() != 0)
            `uvm_error("DMA_RESET_STATE", $sformatf("reset did not clear busy/outstanding/responder active/pending: %0b/%0d/%0b/%0d",
                env.cmd_drv.vif.busy, env.cmd_drv.vif.rd_outstanding,
                env.axi_rsp.active_read != null, env.axi_rsp.pending_reads.size()))
        if (overlap_cnm &&
            (sys_vif.cnm_busy !== 1'b0 || sys_vif.cnm_done !== 1'b0 ||
             sys_vif.cnm_error !== 1'b0 || sys_vif.cnm_req_valid !== 4'b0 ||
             sys_vif.cnm_rsp_valid !== 4'b0 || sys_vif.cnm_spad_valid !== 1'b0))
            `uvm_error("DMA_CNM_RESET_STATE", $sformatf(
                "shared reset did not clear CNM busy/done/error/req/rsp/write=%0b/%0b/%0b/%b/%b/%0b",
                sys_vif.cnm_busy, sys_vif.cnm_done, sys_vif.cnm_error,
                sys_vif.cnm_req_valid, sys_vif.cnm_rsp_valid, sys_vif.cnm_spad_valid))
        if (after_first_beat) env.axi_rsp.vif.release_rready();
        env.axi_rsp.hold_read_responses = 1'b0;
        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b0;
        wait (sys_vif.subsystem_reset_ack === 1'b0);
        repeat (4) begin
            @(posedge sys_vif.clk); #1;
            if (env.cmd_drv.vif.busy || env.cmd_drv.vif.rd_outstanding != 0 ||
                env.axi_rsp.active_read != null || env.axi_rsp.pending_reads.size() != 0 ||
                sys_vif.dma_valid || sys_vif.dma_line_valid || sys_vif.arb_rsp_valid)
                `uvm_error("DMA_RESET_STALE", $sformatf("stale DMA/SPAD activity after reset release: busy/outstanding/active/pending/dma/line/rsp=%0b/%0d/%0b/%0d/%0b/%0b/%0b",
                    env.cmd_drv.vif.busy, env.cmd_drv.vif.rd_outstanding,
                    env.axi_rsp.active_read != null, env.axi_rsp.pending_reads.size(),
                    sys_vif.dma_valid, sys_vif.dma_line_valid, sys_vif.arb_rsp_valid))
            if (overlap_cnm &&
                (sys_vif.cnm_busy || sys_vif.cnm_done || sys_vif.cnm_error ||
                 sys_vif.cnm_req_valid != 4'b0 || sys_vif.cnm_rsp_valid != 4'b0 ||
                 sys_vif.cnm_spad_valid || cont_mon.cnm_spad_writes_accepted != 0))
                `uvm_error("DMA_CNM_RESET_STALE", $sformatf(
                    "stale CNM activity after shared reset: busy/done/error/req/rsp/write=%0b/%0b/%0b/%b/%b/%0d",
                    sys_vif.cnm_busy, sys_vif.cnm_done, sys_vif.cnm_error,
                    sys_vif.cnm_req_valid, sys_vif.cnm_rsp_valid,
                    cont_mon.cnm_spad_writes_accepted))
        end
        if (!cancelled_seq_done) begin
            fork : wait_dma_cancel_sequence
                begin wait (cancelled_seq_done === 1'b1); end
                begin repeat (100) @(posedge sys_vif.clk); end
            join_any
            disable wait_dma_cancel_sequence;
            if (!cancelled_seq_done)
                `uvm_error("DMA_RESET_CANCEL", "cancelled DMA sequence did not return after reset")
        end
        if (env.axi_rsp.accepted_ids.size() || env.axi_rsp.active_read != null ||
            env.axi_rsp.pending_reads.size() != 0)
            `uvm_error("DMA_RESET_STATE", "responder transaction history/live queues were not cleared by reset")
        if (overlap_cnm) begin
            if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
                cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
                `uvm_error("DMA_CNM_RESET_STALE", "CNM response expectations survived shared reset")
            for (int lane = 0; lane < 4; lane++) begin
                if (cont_mon.cnm_lane_reads_accepted[lane] != 0 ||
                    cont_mon.cnm_lane_responses_checked[lane] != 0)
                    `uvm_error("DMA_CNM_RESET_STALE", $sformatf(
                        "post-reset CNM lane %0d traffic=%0d/%0d expected=0/0", lane,
                        cont_mon.cnm_lane_reads_accepted[lane],
                        cont_mon.cnm_lane_responses_checked[lane]))
            end
            host_read_word(32'h02a8, cnm_result_readback);
            if (cnm_result_readback !== 32'hcafe_a8a8)
                `uvm_error("DMA_CNM_RESET_STALE", $sformatf(
                    "CNM reset-time result changed sentinel=0x%08h expected=0xcafea8a8",
                    cnm_result_readback))
        end
        cont_mon.core_reads_accepted = saved_core_reads;
        cont_mon.core_responses_checked = saved_core_responses;
        cont_mon.core_grants_under_contention = saved_core_contended;
        cont_mon.core_grants_isolated = saved_core_isolated;
        cont_mon.dma_grants_under_contention = saved_dma_contended;
        cont_mon.dma_grants_isolated = saved_dma_isolated;
        cont_mon.desc_priority_grants = saved_desc_grants;
        cont_mon.cpl_priority_grants = saved_cpl_grants;
        cont_mon.dma_write_grants = saved_dma_writes;
        cfg.min_accepted_reads_before_response = 2;

        req = dma_cmd_item::type_id::create("dma_reset_recovery_req");
        req.ext_addr = 64'h0000_f900;
        req.spad_addr = after_first_beat ? 32'h0e80 : 32'h0e00;
        req.length_words = 16'd32; req.row_words = 16'd32; req.row_count = 0;
        req.ext_stride = 0; req.spad_stride = 0; req.read_outstanding = 3'd4;
        req.store = 0; req.gather_enable = 0; req.gather_index_base = 0;
        req.expect_error = 0; req.expected_error_code = 0; req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 2;
        seq = dma_one_command_sequence::type_id::create("dma_reset_recovery_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        env.sb.check_complete();
        for (int unsigned word = 0; word < 32; word++) begin
            bit [31:0] value;
            host_read_word(req.spad_addr + word * 4, value);
            if (value !== dma_memory_word(req.ext_addr + word * 4))
                `uvm_error("DMA_RESET_RECOVERY", $sformatf("recovery word %0d=0x%08h expected=0x%08h",
                    word, value, dma_memory_word(req.ext_addr + word * 4)))
        end

        if (overlap_cnm) begin
            cont_mon.reset_cnm_stats();
            preload_cnm_operands(expected_cnm_result);
            @(negedge sys_vif.clk);
            sys_vif.cnm_op_mode <= 8'h20;
            sys_vif.cnm_src0_base <= 32'h0100;
            sys_vif.cnm_src1_base <= 32'h0200;
            sys_vif.cnm_dst_base <= 32'h02a8;
            sys_vif.cnm_length <= 16'd8;
            sys_vif.cnm_m_size <= 16'd1;
            sys_vif.cnm_scale_shift <= 5'd0;
            sys_vif.cnm_activation <= 2'd0;
            sys_vif.cnm_watchdog_limit <= 32'd10000;
            sys_vif.cnm_abort <= 1'b0;
            sys_vif.cnm_mode <= 1'b1;
            run_real_cnm_engine(expected_cnm_result);
            for (int lane = 0; lane < 4; lane++) begin
                if (cont_mon.cnm_lane_reads_accepted[lane] != 16 ||
                    cont_mon.cnm_lane_responses_checked[lane] != 16)
                    `uvm_error("DMA_CNM_RESET_RECOVERY", $sformatf(
                        "recovery CNM lane %0d reads/responses=%0d/%0d expected=16/16",
                        lane, cont_mon.cnm_lane_reads_accepted[lane],
                        cont_mon.cnm_lane_responses_checked[lane]))
            end
            if (cont_mon.cnm_spad_writes_accepted != 1)
                `uvm_error("DMA_CNM_RESET_RECOVERY", $sformatf(
                    "recovery CNM result writes=%0d expected=1",
                    cont_mon.cnm_spad_writes_accepted))
            host_read_word(32'h02a8, cnm_result_readback);
            if (cnm_result_readback !== expected_cnm_result)
                `uvm_error("DMA_CNM_RESET_RECOVERY", $sformatf(
                    "recovery CNM result=0x%08h expected=0x%08h",
                    cnm_result_readback, expected_cnm_result))
            else
                `uvm_info("DMA_CNM_RESET_RECOVERY_PASS",
                    "shared reset cancelled DMA/CNM together; both engines completed fresh work after recovery",
                    UVM_LOW)
        end
    endtask

    task preload_scratchpad();
        int unsigned index;
        bit [31:0] addr;
        for (index = 0; index < 32; index++) begin
            addr = 32'h100 + (index * 4);
            host_write_word(addr, 32'hc001_0000 ^ (addr >> 2));
            addr = 32'h600 + (index * 4);
            host_write_word(addr, dma_spad_source_word(addr));
        end
        host_write_word(32'h800, 32'hd15c_0001);
        host_write_word(32'h900, 32'h0);
    endtask

    task run_core_read_traffic(int unsigned request_count);
        int unsigned sent;
        bit [31:0] addr;
        sent = 0;
        addr = 32'h100 + ($urandom_range(0, 31) * 4);
        @(negedge sys_vif.clk);
        sys_vif.core_write <= 1'b0;
        sys_vif.core_addr <= addr;
        sys_vif.core_valid <= 1'b1;
        while (sent < request_count) begin
            @(posedge sys_vif.clk);
            if (sys_vif.core_ready) begin
                sent++;
                @(negedge sys_vif.clk);
                if (sent < request_count) begin
                    addr = 32'h100 + ($urandom_range(0, 31) * 4);
                    sys_vif.core_addr <= addr;
                end else begin
                    sys_vif.core_valid <= 1'b0;
                end
            end
        end
    endtask

    task run_descriptor_priority_probe();
        @(negedge sys_vif.clk);
        wait (sys_vif.dma_valid || sys_vif.dma_line_valid);
        sys_vif.desc_addr <= 32'h800;
        sys_vif.desc_valid <= 1'b1;
        @(posedge sys_vif.clk);
        if (!sys_vif.desc_ready || sys_vif.core_ready ||
            sys_vif.dma_ready || sys_vif.dma_line_ready)
            `uvm_error("SPAD_DESC_PRIORITY", "descriptor did not take priority over pending data clients")
        @(negedge sys_vif.clk);
        sys_vif.desc_valid <= 1'b0;
        wait (sys_vif.desc_rsp_valid);
        #1;
        if (sys_vif.desc_rsp_error || sys_vif.arb_rsp_rdata !== 32'hd15c_0001)
            `uvm_error("SPAD_DESC_RSP", $sformatf("descriptor response error=%0b data=0x%08h",
                       sys_vif.desc_rsp_error, sys_vif.arb_rsp_rdata))
    endtask

    task run_completion_priority_probe();
        @(negedge sys_vif.clk);
        wait (sys_vif.dma_valid || sys_vif.dma_line_valid);
        sys_vif.cpl_addr <= 32'h900;
        sys_vif.cpl_wdata <= 32'hcafe_2026;
        sys_vif.cpl_write <= 1'b1;
        sys_vif.cpl_valid <= 1'b1;
        @(posedge sys_vif.clk);
        if (!sys_vif.cpl_ready || sys_vif.core_ready ||
            sys_vif.dma_ready || sys_vif.dma_line_ready)
            `uvm_error("SPAD_CPL_PRIORITY", "completion did not take priority over pending data clients")
        @(negedge sys_vif.clk);
        sys_vif.cpl_valid <= 1'b0;
        sys_vif.cpl_write <= 1'b0;
    endtask

    task run_dma_command(bit store, bit [63:0] ext_addr, bit [31:0] spad_addr);
        dma_cmd_item req;
        dma_one_command_sequence seq;
        req = dma_cmd_item::type_id::create(store ? "store_req" : "load_req");
        req.ext_addr = ext_addr;
        req.spad_addr = spad_addr;
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = store ? 3'd1 : 3'd4;
        req.store = store;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = store ? 0 : 2;
        seq = dma_one_command_sequence::type_id::create(store ? "store_seq" : "load_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        repeat (3) @(posedge sys_vif.clk);
        env.sb.check_complete();
        if (store)
            env.axi_rsp.check_write_out_of_order();
        else
            env.axi_rsp.check_out_of_order();
    endtask

    task run_dma_store_with_aw_stall(bit [63:0] ext_addr, bit [31:0] spad_addr);
        logic [80:0] stalled_aw_payload;
        int unsigned checked_stall_cycles;
        int unsigned timeout_cycles;

        checked_stall_cycles = 0;
        timeout_cycles = 0;
        // Use the responder's clocked configuration hook instead of forcing
        // the interface signal; this avoids racing its AWREADY NBA driver.
        @(negedge sys_vif.clk);
        env.axi_rsp.cfg.force_awready_low = 1'b1;
        fork
            run_dma_command(1'b1, ext_addr, spad_addr);
            begin : check_aw_stall_window
                while (env.axi_rsp.vif.awvalid !== 1'b1 && timeout_cycles < 10000) begin
                    @(negedge sys_vif.clk);
                    timeout_cycles++;
                end
                if (timeout_cycles == 10000) begin
                    `uvm_error("DMA_AW_STALL", "AWVALID did not assert during the forced AWREADY-low window")
                end else begin
                    if (env.axi_rsp.vif.awready !== 1'b0)
                        `uvm_error("DMA_AW_STALL", "AWREADY was not held low when AWVALID asserted")
                    stalled_aw_payload = {
                        env.axi_rsp.vif.awid, env.axi_rsp.vif.awaddr,
                        env.axi_rsp.vif.awlen, env.axi_rsp.vif.awsize,
                        env.axi_rsp.vif.awburst
                    };
                    // Sample away from the responder/DUT active clock edge.
                    repeat (4) begin
                        @(negedge sys_vif.clk);
                        checked_stall_cycles++;
                        if (env.axi_rsp.vif.awready !== 1'b0 ||
                            env.axi_rsp.vif.awvalid !== 1'b1 ||
                            {env.axi_rsp.vif.awid, env.axi_rsp.vif.awaddr,
                             env.axi_rsp.vif.awlen, env.axi_rsp.vif.awsize,
                             env.axi_rsp.vif.awburst} !== stalled_aw_payload)
                            `uvm_error("DMA_AW_STALL", $sformatf(
                                "AW payload changed during responder-held stall cycle %0d",
                                checked_stall_cycles))
                    end
                end
                env.axi_rsp.cfg.force_awready_low = 1'b0;
            end
        join

        if (checked_stall_cycles == 4)
            `uvm_info("DMA_AW_STALL_PASS",
                "AW payload remained stable for four subsystem-level stalled cycles; store completed", UVM_LOW)
        else
            `uvm_error("DMA_AW_STALL", $sformatf(
                "observed %0d forced AW stall cycles; expected four", checked_stall_cycles))
    endtask

    task run_dma_expected_read_error();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        req = dma_cmd_item::type_id::create("axi_read_error_req");
        req.ext_addr = 64'h0000_f000;
        req.spad_addr = 32'h0a00;
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 1;
        req.expected_error_code = 4'd2;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 4;
        seq = dma_one_command_sequence::type_id::create("axi_read_error_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        env.sb.check_complete();
    endtask

    task run_dma_expected_abort_drain();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        req = dma_cmd_item::type_id::create("cnm_overlap_abort_req");
        req.ext_addr = 64'h0000_f400;
        req.spad_addr = 32'h0a00;
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 1;
        req.expected_error_code = 4'd5;
        req.abort_after_cycles = 8;
        req.minimum_rd_highwater = 4;
        seq = dma_one_command_sequence::type_id::create("cnm_overlap_abort_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        env.sb.check_complete();
    endtask

    task run_dma_expected_write_abort_drain();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        req = dma_cmd_item::type_id::create("cnm_overlap_write_abort_req");
        req.ext_addr = 64'h0000_f500;
        req.spad_addr = 32'h0a00;
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd1;
        req.store = 1;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 1;
        req.expected_error_code = 4'd5;
        req.abort_after_cycles = 0;
        req.abort_after_aw = 1'b1;
        req.minimum_rd_highwater = 0;
        seq = dma_one_command_sequence::type_id::create("cnm_overlap_write_abort_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        env.sb.check_complete();
    endtask

    // Small, non-contiguous rows make the stride behavior visible in both
    // address generation and scoreboard word accounting without overlapping
    // the original 32-word scenarios.
    task run_dma_2d_load();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        req = dma_cmd_item::type_id::create("two_d_load_req");
        req.ext_addr = 64'h0000_d000;
        req.spad_addr = 32'hb00;
        req.length_words = 16'd8;
        req.row_words = 16'd4;
        req.row_count = 16'd2;
        req.ext_stride = 32'h40;
        req.spad_stride = 32'h20;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 1;
        seq = dma_one_command_sequence::type_id::create("two_d_load_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        // start() returns only after the command driver observes done.
        env.sb.check_complete();
    endtask

    task run_dma_gather_load();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        bit [31:0] gather_rows[2];
        int unsigned row;
        // The real DMA fetches one 32-bit external byte address per row from
        // this table via the host/SPAD-backed fabric interface.
        gather_rows[0] = 32'h0000_e000;
        gather_rows[1] = 32'h0000_e080;
        for (row = 0; row < 2; row++)
            host_write_word(32'hc00 + row * 4, gather_rows[row]);

        req = dma_cmd_item::type_id::create("gather_load_req");
        req.ext_addr = 64'h0000_e000;
        req.spad_addr = 32'hc20;
        req.length_words = 16'd8;
        req.row_words = 16'd4;
        req.row_count = 16'd2;
        req.ext_stride = 0;
        req.spad_stride = 32'h20;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 1;
        req.gather_index_base = 32'hc00;
        req.gather_row_addr.delete();
        for (row = 0; row < 2; row++)
            req.gather_row_addr.push_back(gather_rows[row]);
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 1;
        seq = dma_one_command_sequence::type_id::create("gather_load_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        // Do not let the next command replace active_cmd until this one is
        // fully complete and all eight writes have reached the scoreboard.
        env.sb.check_complete();
    endtask

    task run_dma_short_outstanding_load();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        // A two-word command may be issued as one AXI burst, so do not leave
        // the BFM waiting for the subsystem-wide two-burst response window.
        cfg.min_accepted_reads_before_response = 1;
        req = dma_cmd_item::type_id::create("short_outstanding_load_req");
        req.ext_addr = 64'h0000_d200;
        req.spad_addr = 32'hd00;
        req.length_words = 16'd2;
        req.row_words = 16'd2;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd2;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 0;
        seq = dma_one_command_sequence::type_id::create("short_outstanding_load_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        env.sb.check_complete();
        cfg.min_accepted_reads_before_response = 2;
    endtask

    task run_dma_2d_store();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        int unsigned row;
        int unsigned word;
        bit [31:0] spad_word_addr;
        // Populate each non-overlapping source row with the same deterministic
        // data pattern consumed by the external-SPAD scoreboard model.
        for (row = 0; row < 2; row++) begin
            for (word = 0; word < 4; word++) begin
                spad_word_addr = 32'h700 + row * 32'h20 + word * 4;
                host_write_word(spad_word_addr, dma_spad_source_word(spad_word_addr));
            end
        end

        req = dma_cmd_item::type_id::create("two_d_store_req");
        req.ext_addr = 64'h0000_e400;
        req.spad_addr = 32'h700;
        req.length_words = 16'd8;
        req.row_words = 16'd4;
        req.row_count = 16'd2;
        req.ext_stride = 32'h40;
        req.spad_stride = 32'h20;
        req.read_outstanding = 3'd1;
        req.store = 1;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 0;
        seq = dma_one_command_sequence::type_id::create("two_d_store_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        env.sb.check_complete();
        env.axi_rsp.check_write_out_of_order();
    endtask

    task run_dma_4k_boundary_load();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        req = dma_cmd_item::type_id::create("boundary_4k_load_req");
        req.ext_addr = 64'h0000_0ff0;
        req.spad_addr = 32'he00;
        req.length_words = 16'd16;
        req.row_words = 16'd16;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = 0;
        req.minimum_rd_highwater = 2;
        seq = dma_one_command_sequence::type_id::create("boundary_4k_load_seq");
        seq.item = req;
        seq.start(env.cmd_sqr);
        env.sb.check_complete();
        env.axi_rsp.check_out_of_order();
    endtask

    task preload_fp_contention_operands(bit format_fp16, bit [31:0] dst_addr);
        int unsigned word_index;
        bit [31:0] packed_a;
        bit [31:0] packed_b;
        // Identical values in both halfwords keep the packing order irrelevant:
        // 64 products of 1.0 * 2.0 produce exactly FP32 128.0.
        packed_a = format_fp16 ? 32'h3c00_3c00 : 32'h3f80_3f80;
        packed_b = 32'h4000_4000;
        for (word_index = 0; word_index < 32; word_index++) begin
            host_write_word(32'h100 + word_index * 4, packed_a);
            host_write_word(32'h180 + word_index * 4, packed_b);
        end
        host_write_word(dst_addr, 32'h0);
    endtask

    task run_real_fp_engine(bit format_fp16);
        @(negedge sys_vif.clk);
        sys_vif.fp_start <= 1'b1;
        @(negedge sys_vif.clk);
        sys_vif.fp_start <= 1'b0;
        fork : wait_for_fp_completion
            begin
                wait (sys_vif.fp_done === 1'b1);
            end
            begin
                repeat (10000) @(posedge sys_vif.clk);
                `uvm_error("SPAD_FP_TIMEOUT", "real FP core did not complete under DMA contention")
            end
        join_any
        disable wait_for_fp_completion;
        #1;
        if (sys_vif.fp_busy || sys_vif.fp_error ||
            sys_vif.fp_result !== 32'h4300_0000 ||
            sys_vif.fp_element_count != 64)
            `uvm_error("SPAD_FP_RESULT", $sformatf(
                "real %s dot busy=%0b error=%0b code=%0h result=0x%08h elements=%0d cycles=%0d",
                format_fp16 ? "FP16" : "BF16",
                sys_vif.fp_busy, sys_vif.fp_error, sys_vif.fp_error_code,
                sys_vif.fp_result, sys_vif.fp_element_count, sys_vif.fp_cycle_count))
    endtask

    task run_fp_format_dma_contention(bit format_fp16, bit [31:0] dst_addr);
        bit [31:0] result_readback;
        preload_fp_contention_operands(format_fp16, dst_addr);
        repeat (3) @(posedge sys_vif.clk);
        @(negedge sys_vif.clk);
        sys_vif.fp_src0_base <= 32'h100;
        sys_vif.fp_src1_base <= 32'h180;
        sys_vif.fp_dst_base <= dst_addr;
        sys_vif.fp_length <= 16'd64;
        sys_vif.fp_format_fp16 <= format_fp16;
        sys_vif.fp_watchdog_limit <= 32'd10000;
        sys_vif.fp_abort <= 1'b0;
        sys_vif.fp_mode <= 1'b1;

        `uvm_info("DMA_SPAD", $sformatf(
            "starting real %s dot RTL concurrently with DDR-to-SPAD DMA",
            format_fp16 ? "FP16" : "BF16"), UVM_LOW)
        fork
            run_real_fp_engine(format_fp16);
            run_dma_command(1'b0, 64'h0000_f000, 32'h400);
        join

        cont_mon.check_fp_complete(64, 1, 32'h4300_0000);
        host_read_word(dst_addr, result_readback);
        if (result_readback !== 32'h4300_0000)
            `uvm_error("SPAD_FP_WRITEBACK", $sformatf(
                "%s result in real scratchpad=0x%08h expected=0x43000000",
                format_fp16 ? "FP16" : "BF16", result_readback))
        else
            `uvm_info("SPAD_FP_WRITEBACK_PASS", $sformatf(
                "real %s result was committed to the shared scratchpad",
                format_fp16 ? "FP16" : "BF16"), UVM_LOW)
        @(negedge sys_vif.clk);
        sys_vif.fp_mode <= 1'b0;
    endtask

    task run_fp_dma_contention();
        run_fp_format_dma_contention(1'b0, 32'h200);
        cont_mon.reset_fp_stats();
        run_fp_format_dma_contention(1'b1, 32'h204);
    endtask

    task monitor_fp_dma_error_overlap(output int unsigned overlap_cycles,
                                      output int unsigned error_overlap_cycles);
        overlap_cycles = 0;
        error_overlap_cycles = 0;
        while (!sys_vif.fp_done) begin
            @(posedge sys_vif.clk);
            if (sys_vif.fp_busy && env.cmd_drv.vif.busy)
                overlap_cycles++;
            if (sys_vif.fp_busy && env.cmd_drv.vif.busy && env.cmd_drv.vif.error)
                error_overlap_cycles++;
        end
    endtask

    task run_fp_dma_read_error_contention(bit format_fp16, bit [31:0] dst_addr);
        int unsigned accepted_before, completed_before;
        int unsigned dma_writes_before;
        int unsigned busy_overlap_cycles, error_overlap_cycles;
        bit [31:0] result_readback;

        preload_fp_contention_operands(format_fp16, dst_addr);
        repeat (3) @(posedge sys_vif.clk);
        @(negedge sys_vif.clk);
        sys_vif.fp_src0_base <= 32'h100;
        sys_vif.fp_src1_base <= 32'h180;
        sys_vif.fp_dst_base <= dst_addr;
        sys_vif.fp_length <= 16'd64;
        sys_vif.fp_format_fp16 <= format_fp16;
        sys_vif.fp_watchdog_limit <= 32'd10000;
        sys_vif.fp_abort <= 1'b0;
        sys_vif.fp_mode <= 1'b1;

        cfg.min_accepted_reads_before_response = 4;
        cfg.read_response_delay_cycles = 48;
        cfg.inject_read_error = 1'b1;
        cfg.inject_read_error_addr = 64'h0000_f060;
        cfg.injected_read_error_responses = 0;
        accepted_before = env.axi_rsp.accepted_ids.size();
        completed_before = env.axi_rsp.completed_ids.size();
        dma_writes_before = cont_mon.dma_write_grants;
        cont_mon.reset_fp_stats();

        `uvm_info("DMA_SPAD", $sformatf(
            "starting real %s dot with four-outstanding DMA read SLVERR and drain",
            format_fp16 ? "FP16" : "BF16"), UVM_LOW)
        fork
            run_real_fp_engine(format_fp16);
            run_dma_expected_read_error();
            monitor_fp_dma_error_overlap(busy_overlap_cycles, error_overlap_cycles);
        join

        if (env.axi_rsp.accepted_ids.size() - accepted_before != 4 ||
            env.axi_rsp.completed_ids.size() - completed_before != 4 ||
            cfg.injected_read_error_responses != 1)
            `uvm_error("DMA_ERR_DRAIN", $sformatf(
                "expected 4 accepted/drained bursts and one injected SLVERR; accepted=%0d completed=%0d injected=%0d",
                env.axi_rsp.accepted_ids.size() - accepted_before,
                env.axi_rsp.completed_ids.size() - completed_before,
                cfg.injected_read_error_responses))
        if (env.cmd_drv.vif.rd_highwater < 4 || env.cmd_drv.vif.rd_outstanding != 0 ||
            env.cmd_drv.vif.busy || env.axi_rsp.active_read != null ||
            env.axi_rsp.pending_reads.size() != 0)
            `uvm_error("DMA_ERR_IDLE", $sformatf(
                "read error did not drain to idle: highwater=%0d outstanding=%0d busy=%0b active=%0b pending=%0d",
                env.cmd_drv.vif.rd_highwater, env.cmd_drv.vif.rd_outstanding,
                env.cmd_drv.vif.busy, env.axi_rsp.active_read != null,
                env.axi_rsp.pending_reads.size()))
        if (cont_mon.dma_write_grants != dma_writes_before)
            `uvm_error("DMA_ERR_COMMIT", $sformatf(
                "DMA committed %0d SPAD writes from a read-error command",
                cont_mon.dma_write_grants - dma_writes_before))
        if (busy_overlap_cycles == 0 || error_overlap_cycles == 0)
            `uvm_error("DMA_FP_ERR_OVERLAP", $sformatf(
                "FP/DMA did not overlap through error drain: busy=%0d error=%0d cycles",
                busy_overlap_cycles, error_overlap_cycles))

        cont_mon.check_fp_complete(64, 1, 32'h4300_0000, 1'b0);
        host_read_word(dst_addr, result_readback);
        if (result_readback !== 32'h4300_0000)
            `uvm_error("SPAD_FP_ERROR_CONCURRENT_RESULT", $sformatf(
                "%s result during DMA read error=0x%08h expected=0x43000000",
                format_fp16 ? "FP16" : "BF16", result_readback))
        `uvm_info("DMA_SPAD_ERR_DRAIN_PASS", $sformatf(
            "%s + DMA SLVERR: accepted/drained=4/4, peak outstanding=%0d, overlap busy/error=%0d/%0d cycles; FP result=0x%08h",
            format_fp16 ? "FP16" : "BF16", env.cmd_drv.vif.rd_highwater,
            busy_overlap_cycles, error_overlap_cycles, result_readback), UVM_LOW)

        cfg.inject_read_error = 1'b0;
        cfg.read_response_delay_cycles = 0;
        cfg.min_accepted_reads_before_response = 2;
        @(negedge sys_vif.clk);
        sys_vif.fp_mode <= 1'b0;

        // A clean command immediately after the SLVERR campaign proves both
        // the DMA and the responder can be reused without a reset.
        run_dma_command(1'b0, 64'h0000_f080, 32'h0a00);
        host_read_word(32'h0a00, result_readback);
        if (result_readback !== dma_memory_word(64'h0000_f080))
            `uvm_error("DMA_ERR_RECOVERY", $sformatf(
                "post-error load data=0x%08h expected=0x%08h",
                result_readback, dma_memory_word(64'h0000_f080)))
        else
            `uvm_info("DMA_ERR_RECOVERY_PASS", "clean DMA load passed immediately after the drained SLVERR command", UVM_LOW)
    endtask

    task monitor_cnm_dma_error_overlap(output int unsigned overlap_cycles,
                                       output int unsigned error_overlap_cycles);
        overlap_cycles = 0;
        error_overlap_cycles = 0;
        wait (sys_vif.cnm_busy === 1'b1);
        while (sys_vif.cnm_done !== 1'b1) begin
            @(posedge sys_vif.clk);
            if (sys_vif.cnm_busy && env.cmd_drv.vif.busy)
                overlap_cycles++;
            if (sys_vif.cnm_busy && env.cmd_drv.vif.busy && env.cmd_drv.vif.error)
                error_overlap_cycles++;
        end
    endtask

    task monitor_cnm_dma_abort_overlap(output int unsigned abort_overlap_cycles);
        abort_overlap_cycles = 0;
        wait (sys_vif.cnm_busy === 1'b1);
        while (sys_vif.cnm_done !== 1'b1) begin
            @(negedge sys_vif.clk);
            if (sys_vif.cnm_busy && env.cmd_drv.vif.busy &&
                env.cmd_drv.vif.abort)
                abort_overlap_cycles++;
        end
    endtask

    task run_cnm_dma_read_error_case(int unsigned successful_bursts_before_error);
        bit [31:0] expected_result, result_readback;
        int unsigned accepted_before, completed_before;
        int unsigned dma_writes_before;
        int unsigned busy_overlap_cycles, error_overlap_cycles;
        int unsigned committed_word_count;
        int unsigned expected_commit_start;
        bit [31:0] observed_word;
        bit dma_drained;

        cont_mon.reset_cnm_stats();
        for (int word_index = 0; word_index < 32; word_index++)
            host_write_word(32'h0a00 + word_index * 4, 32'hdeadcafe);
        preload_cnm_operands(expected_result);
        host_write_word(32'h02ac, 32'hcafe_acac);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h02ac;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;

        cfg.min_accepted_reads_before_response = 4;
        if (successful_bursts_before_error > 3)
            `uvm_fatal("SPAD_CNM_DMA_ERR_CFG", $sformatf(
                "successful bursts before injected error must be 0..3, got %0d",
                successful_bursts_before_error))

        // Keep all four reads outstanding, then inject SLVERR at each possible
        // position in the responder's newest-first response order.
        // Give the four ARs time to enter the responder before an early/middle
        // error can stop issue. The final error position naturally arrives
        // later in the response stream, so it needs less initial delay.
        cfg.read_response_delay_cycles = (successful_bursts_before_error < 3) ? 8 : 4;
        cfg.inject_read_error = 1'b1;
        case (successful_bursts_before_error)
            0: cfg.inject_read_error_addr = 64'h0000_f060;
            1: cfg.inject_read_error_addr = 64'h0000_f040;
            2: cfg.inject_read_error_addr = 64'h0000_f020;
            3: cfg.inject_read_error_addr = 64'h0000_f000;
            default: `uvm_fatal("SPAD_CNM_DMA_ERR_CFG", "invalid error position")
        endcase
        cfg.injected_read_error_responses = 0;
        accepted_before = env.axi_rsp.accepted_ids.size();
        completed_before = env.axi_rsp.completed_ids.size();
        dma_writes_before = cont_mon.dma_write_grants;

        `uvm_info("SPAD_CNM_DMA_ERR_SETUP",
            "starting real four-lane CNM while a four-outstanding DMA read receives SLVERR", UVM_LOW)
        fork
            run_real_cnm_engine(expected_result);
            run_dma_expected_read_error();
            monitor_cnm_dma_error_overlap(busy_overlap_cycles, error_overlap_cycles);
        join

        dma_drained = (env.axi_rsp.accepted_ids.size() - accepted_before == 4) &&
                      (env.axi_rsp.completed_ids.size() - completed_before == 4) &&
                      (cfg.injected_read_error_responses == 1) &&
                      (env.cmd_drv.vif.rd_highwater >= 4) &&
                      (env.cmd_drv.vif.rd_outstanding == 0) &&
                      !env.cmd_drv.vif.busy && (env.axi_rsp.active_read == null) &&
                      (env.axi_rsp.pending_reads.size() == 0);
        if (!dma_drained)
            `uvm_error("SPAD_CNM_DMA_ERR_DRAIN", $sformatf(
                "DMA SLVERR drain failed: accepted/completed=%0d/%0d injected=%0d highwater=%0d outstanding=%0d busy=%0b active=%0b pending=%0d",
                env.axi_rsp.accepted_ids.size() - accepted_before,
                env.axi_rsp.completed_ids.size() - completed_before,
                cfg.injected_read_error_responses, env.cmd_drv.vif.rd_highwater,
                env.cmd_drv.vif.rd_outstanding, env.cmd_drv.vif.busy,
                env.axi_rsp.active_read != null, env.axi_rsp.pending_reads.size()))
        if (successful_bursts_before_error == 0 &&
            cont_mon.dma_write_grants != dma_writes_before)
            `uvm_error("SPAD_CNM_DMA_ERR_COMMIT", $sformatf(
                "first-response SLVERR committed %0d scalar DMA SPAD writes",
                cont_mon.dma_write_grants - dma_writes_before))
        if (busy_overlap_cycles == 0 || error_overlap_cycles == 0)
            `uvm_error("SPAD_CNM_DMA_ERR_OVERLAP", $sformatf(
                "CNM/DMA did not overlap through the SLVERR window: busy=%0d error=%0d cycles",
                busy_overlap_cycles, error_overlap_cycles))

        // Every error after at least one successful burst must exercise real
        // scheduler contention while CNM is requesting SPAD access.
        cont_mon.check_cnm_complete(16, 1, expected_result,
                                    (successful_bursts_before_error != 0));
        if (sys_vif.cnm_error || sys_vif.cnm_error_code != 0)
            `uvm_error("SPAD_CNM_DMA_ERR_STATUS", $sformatf(
                "DMA SLVERR corrupted CNM completion: error=%0b code=%0h",
                sys_vif.cnm_error, sys_vif.cnm_error_code))
        host_read_word(32'h02ac, result_readback);
        if (result_readback !== expected_result)
            `uvm_error("SPAD_CNM_DMA_ERR_RESULT", $sformatf(
                "CNM result during DMA SLVERR=0x%08h expected=0x%08h",
                result_readback, expected_result))

        committed_word_count = 0;
        expected_commit_start = 32 - (successful_bursts_before_error * 8);
        for (int word_index = 0; word_index < 32; word_index++) begin
            host_read_word(32'h0a00 + word_index * 4, observed_word);
            if (word_index < expected_commit_start) begin
                if (observed_word !== 32'hdeadcafe)
                    `uvm_error("SPAD_CNM_DMA_ERR_PREFIX", $sformatf(
                        "unreturned/failed word %0d changed to 0x%08h (expected sentinel)",
                        word_index, observed_word))
            end else if (observed_word === dma_memory_word(64'h0000_f000 + word_index * 4)) begin
                committed_word_count++;
            end else begin
                `uvm_error("SPAD_CNM_DMA_ERR_DATA", $sformatf(
                    "expected prior-success data at SPAD word[%0d], got 0x%08h",
                    word_index, observed_word))
            end
        end
        if (committed_word_count != successful_bursts_before_error * 8)
            `uvm_error("SPAD_CNM_DMA_ERR_COMMIT_COUNT", $sformatf(
                "successful bursts before error=%0d; committed words=%0d expected=%0d",
                successful_bursts_before_error, committed_word_count,
                successful_bursts_before_error * 8))
        if (successful_bursts_before_error != 0) begin
            if (cont_mon.cnm_dma_grants_under_contention == 0)
                `uvm_error("SPAD_CNM_DMA_ERR_CONTENTION",
                    "successful DMA burst data did not receive a grant while CNM was requesting")
        end

        cont_mon.sample_cnm_dma_error_overlap(
            successful_bursts_before_error,
            (busy_overlap_cycles != 0 && error_overlap_cycles != 0), dma_drained);
        `uvm_info("SPAD_CNM_DMA_ERR_CASE_PASS", $sformatf(
            "CNM/DMA SLVERR after %0d successful newest-first bursts: accepted/drained=4/4 overlap busy/error=%0d/%0d cycles; committed words=%0d; CNM result=0x%08h; CNM/DMA contended grants=%0d",
            successful_bursts_before_error,
            busy_overlap_cycles, error_overlap_cycles, committed_word_count,
            result_readback, cont_mon.cnm_dma_grants_under_contention), UVM_LOW)

        cfg.inject_read_error = 1'b0;
        cfg.read_response_delay_cycles = 0;
        cfg.min_accepted_reads_before_response = 2;
        @(negedge sys_vif.clk);
        sys_vif.cnm_mode <= 1'b0;

        // Prove the errored DMA lifecycle and responder can be reused without
        // reset while retaining a result from the overlapping CNM task.
        run_dma_command(1'b0, 64'h0000_f080, 32'h0a00);
        host_read_word(32'h0a00, result_readback);
        if (result_readback !== dma_memory_word(64'h0000_f080))
            `uvm_error("SPAD_CNM_DMA_ERR_RECOVERY", $sformatf(
                "post-SLVERR DMA recovery data=0x%08h expected=0x%08h",
                result_readback, dma_memory_word(64'h0000_f080)))
        else
            `uvm_info("SPAD_CNM_DMA_ERR_RECOVERY_PASS",
                "DMA accepted a clean load immediately after the concurrent CNM/SLVERR scenario", UVM_LOW)
    endtask

    task run_cnm_dma_abort_drain_case();
        bit [31:0] expected_result, result_readback, observed_word;
        int unsigned accepted_before, completed_before;
        int unsigned dma_writes_before;
        int unsigned abort_overlap_cycles;
        bit dma_drained;
        bit no_dma_commit;

        cont_mon.reset_cnm_stats();
        for (int word_index = 0; word_index < 32; word_index++)
            host_write_word(32'h0a00 + word_index * 4, 32'hdeadcafe);
        preload_cnm_operands(expected_result);
        host_write_word(32'h02ac, 32'hcafe_acac);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h02ac;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;

        // Hold the first AXI response until after the command driver's abort
        // pulse. Four accepted reads must then be returned and drained, while
        // the concurrent CNM operation continues to use the shared SPAD.
        cfg.inject_read_error = 1'b0;
        cfg.min_accepted_reads_before_response = 4;
        cfg.read_response_delay_cycles = 24;
        accepted_before = env.axi_rsp.accepted_ids.size();
        completed_before = env.axi_rsp.completed_ids.size();
        dma_writes_before = cont_mon.dma_write_grants;

        `uvm_info("SPAD_CNM_DMA_ABORT_SETUP",
            "starting real four-lane CNM while a four-outstanding DMA load is aborted before its first response", UVM_LOW)
        fork
            run_real_cnm_engine(expected_result);
            run_dma_expected_abort_drain();
            monitor_cnm_dma_abort_overlap(abort_overlap_cycles);
        join

        dma_drained = (env.axi_rsp.accepted_ids.size() - accepted_before == 4) &&
                      (env.axi_rsp.completed_ids.size() - completed_before == 4) &&
                      (env.cmd_drv.vif.rd_highwater >= 4) &&
                      (env.cmd_drv.vif.rd_outstanding == 0) &&
                      !env.cmd_drv.vif.busy && (env.axi_rsp.active_read == null) &&
                      (env.axi_rsp.pending_reads.size() == 0);
        no_dma_commit = (cont_mon.dma_write_grants == dma_writes_before);
        if (!dma_drained)
            `uvm_error("SPAD_CNM_DMA_ABORT_DRAIN", $sformatf(
                "DMA abort drain failed: accepted/completed=%0d/%0d highwater=%0d outstanding=%0d busy=%0b active=%0b pending=%0d",
                env.axi_rsp.accepted_ids.size() - accepted_before,
                env.axi_rsp.completed_ids.size() - completed_before,
                env.cmd_drv.vif.rd_highwater, env.cmd_drv.vif.rd_outstanding,
                env.cmd_drv.vif.busy, env.axi_rsp.active_read != null,
                env.axi_rsp.pending_reads.size()))
        if (!no_dma_commit)
            `uvm_error("SPAD_CNM_DMA_ABORT_COMMIT", $sformatf(
                "aborted DMA committed %0d SPAD write grants",
                cont_mon.dma_write_grants - dma_writes_before))
        if (abort_overlap_cycles == 0)
            `uvm_error("SPAD_CNM_DMA_ABORT_OVERLAP",
                "DMA abort pulse was not observed while CNM remained busy")

        cont_mon.check_cnm_complete(16, 1, expected_result, 0);
        if (sys_vif.cnm_error || sys_vif.cnm_error_code != 0)
            `uvm_error("SPAD_CNM_DMA_ABORT_CNM_STATUS", $sformatf(
                "DMA abort corrupted CNM completion: error=%0b code=%0h",
                sys_vif.cnm_error, sys_vif.cnm_error_code))
        host_read_word(32'h02ac, result_readback);
        if (result_readback !== expected_result)
            `uvm_error("SPAD_CNM_DMA_ABORT_CNM_RESULT", $sformatf(
                "CNM result during DMA abort=0x%08h expected=0x%08h",
                result_readback, expected_result))

        for (int word_index = 0; word_index < 32; word_index++) begin
            host_read_word(32'h0a00 + word_index * 4, observed_word);
            if (observed_word !== 32'hdeadcafe)
                `uvm_error("SPAD_CNM_DMA_ABORT_SENTINEL", $sformatf(
                    "aborted DMA changed destination word %0d to 0x%08h",
                    word_index, observed_word))
        end
        cont_mon.sample_cnm_dma_abort_overlap(
            (abort_overlap_cycles != 0), dma_drained, no_dma_commit,
            env.cmd_drv.vif.rd_highwater);
        `uvm_info("SPAD_CNM_DMA_ABORT_PASS", $sformatf(
            "CNM remained correct during DMA abort: abort/CNM overlap=%0d cycles; accepted/drained reads=4/4; highwater=%0d; DMA SPAD commits=0",
            abort_overlap_cycles, env.cmd_drv.vif.rd_highwater), UVM_LOW)

        cfg.read_response_delay_cycles = 0;
        cfg.min_accepted_reads_before_response = 2;
        @(negedge sys_vif.clk);
        sys_vif.cnm_mode <= 1'b0;
        // Reuse the DMA/responder without reset after the abort-drain path.
        run_dma_command(1'b0, 64'h0000_f480, 32'h0a00);
        host_read_word(32'h0a00, result_readback);
        if (result_readback !== dma_memory_word(64'h0000_f480))
            `uvm_error("SPAD_CNM_DMA_ABORT_RECOVERY", $sformatf(
                "post-abort DMA load data=0x%08h expected=0x%08h",
                result_readback, dma_memory_word(64'h0000_f480)))
        else
            `uvm_info("SPAD_CNM_DMA_ABORT_RECOVERY_PASS",
                "clean DMA load passed immediately after concurrent CNM abort-drain without reset", UVM_LOW)
    endtask

    task run_cnm_dma_write_abort_drain_case();
        bit [31:0] expected_result, result_readback;
        int unsigned accepted_before, completed_before;
        int unsigned cnm_dma_grants_before;
        int unsigned overlap_cycles, dma_setup_cycles, cnm_setup_cycles;
        bit write_drained, single_burst;

        cont_mon.reset_cnm_stats();
        preload_cnm_operands(expected_result);
        for (int word_index = 0; word_index < 32; word_index++)
            host_write_word(32'h0a00 + word_index * 4,
                            dma_spad_source_word(32'h0a00 + word_index * 4));
        host_write_word(32'h02b0, 32'hcafe_ba10);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h02b0;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;

        // Delay B after the first accepted write burst. The real CNM starts
        // as soon as DMA becomes active so both clients use the shared SPAD;
        // CNM must remain correct while DMA drains the accepted AW/W/B path.
        cfg.inject_write_error = 1'b0;
        cfg.write_response_delay_cycles = 64;
        cfg.min_accepted_writes_before_response = 1;
        accepted_before = env.axi_rsp.accepted_bids.size();
        completed_before = env.axi_rsp.completed_bids.size();
        cnm_dma_grants_before = cont_mon.cnm_dma_grants_under_contention;
        overlap_cycles = 0;
        dma_setup_cycles = 0;
        cnm_setup_cycles = 0;

        `uvm_info("SPAD_CNM_DMA_WRITE_ABORT_SETUP",
            "starting real CNM with DMA store; abort follows accepted AW and waits for matching delayed B",
            UVM_LOW)
        fork
            run_real_cnm_engine(expected_result);
            begin : start_dma_while_cnm_requests
                while (!(|sys_vif.cnm_req_valid) && dma_setup_cycles < 500) begin
                    @(posedge sys_vif.clk);
                    #1;
                    dma_setup_cycles++;
                end
                if (dma_setup_cycles >= 500)
                    `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_SETUP", "CNM did not issue its first SPAD request")
                else
                    run_dma_expected_write_abort_drain();
            end
            begin : monitor_cnm_dma_write_drain
                while (!sys_vif.cnm_busy && cnm_setup_cycles < 1000) begin
                    @(posedge sys_vif.clk);
                    #1;
                    cnm_setup_cycles++;
                end
                if (cnm_setup_cycles >= 1000) begin
                    `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_SETUP", "CNM did not become active")
                end else begin
                    while (!sys_vif.cnm_done) begin
                        @(posedge sys_vif.clk);
                        if (sys_vif.cnm_busy && env.cmd_drv.vif.busy &&
                            ((env.axi_rsp.active_write != null) ||
                             (env.axi_rsp.accepted_bids.size() > accepted_before &&
                              env.axi_rsp.completed_bids.size() == completed_before)))
                            overlap_cycles++;
                    end
                end
            end
        join
        #1;

        single_burst = (env.axi_rsp.accepted_bids.size() - accepted_before == 1);
        write_drained = single_burst &&
                        (env.axi_rsp.completed_bids.size() - completed_before == 1) &&
                        (env.axi_rsp.pending_b.size() == 0) &&
                        (env.axi_rsp.active_b == null) &&
                        (env.axi_rsp.active_write == null) &&
                        !env.cmd_drv.vif.busy;
        if (!write_drained)
            `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_DRAIN", $sformatf(
                "expected one accepted/completed write burst and idle DMA after ERR_ABORT sequence check; accepted/completed=%0d/%0d pending=%0d active_b=%0b active_write=%0b busy=%0b",
                env.axi_rsp.accepted_bids.size() - accepted_before,
                env.axi_rsp.completed_bids.size() - completed_before,
                env.axi_rsp.pending_b.size(), env.axi_rsp.active_b != null,
                env.axi_rsp.active_write != null, env.cmd_drv.vif.busy))
        if (overlap_cycles == 0)
            `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_OVERLAP",
                "CNM did not overlap a DMA write-burst or pending-B drain cycle")
        if (cont_mon.cnm_dma_grants_under_contention == cnm_dma_grants_before)
            `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_CONTENTION",
                "CNM received no shared-SPAD grant while DMA also requested the fabric")

        cont_mon.check_cnm_complete(16, 1, expected_result);
        if (sys_vif.cnm_error || sys_vif.cnm_error_code != 0)
            `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_CNM_STATUS", $sformatf(
                "DMA write abort corrupted CNM completion: error=%0b code=%0h",
                sys_vif.cnm_error, sys_vif.cnm_error_code))
        host_read_word(32'h02b0, result_readback);
        if (result_readback !== expected_result)
            `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_CNM_RESULT", $sformatf(
                "CNM result during DMA write abort=0x%08h expected=0x%08h",
                result_readback, expected_result))

        cont_mon.sample_cnm_dma_write_abort(
            (overlap_cycles != 0), write_drained, single_burst);
        if (cont_mon.cnm_dma_write_abort_cg.get_coverage() < 100.0)
            `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_COV",
                "CNM/write-abort drain cross coverage bin missed")
        else
            `uvm_info("SPAD_CNM_DMA_WRITE_ABORT_PASS", $sformatf(
                "CNM shared-SPAD result passed while DMA aborted after AW; one B response drained, overlap=%0d cycles, contended CNM grants=%0d",
                overlap_cycles,
                cont_mon.cnm_dma_grants_under_contention - cnm_dma_grants_before), UVM_LOW)

        cfg.write_response_delay_cycles = 0;
        cfg.min_accepted_writes_before_response = 1;
        @(negedge sys_vif.clk);
        sys_vif.cnm_mode <= 1'b0;
        run_dma_command(1'b0, 64'h0000_f580, 32'h0b00);
        host_read_word(32'h0b00, result_readback);
        if (result_readback !== dma_memory_word(64'h0000_f580))
            `uvm_error("SPAD_CNM_DMA_WRITE_ABORT_RECOVERY", $sformatf(
                "post-abort DMA load data=0x%08h expected=0x%08h",
                result_readback, dma_memory_word(64'h0000_f580)))
        else
            `uvm_info("SPAD_CNM_DMA_WRITE_ABORT_RECOVERY_PASS",
                "DMA accepted a clean load after concurrent CNM/write-abort drain without reset", UVM_LOW)
    endtask

    function automatic int signed cnm_dot4_reference(bit [31:0] act_word,
                                                       bit [31:0] weight_word);
        int signed sum;
        int signed act_value, weight_value;
        sum = 0;
        for (int byte_index = 0; byte_index < 4; byte_index++) begin
            act_value = $signed(act_word[byte_index*8 +: 8]);
            weight_value = $signed(weight_word[byte_index*8 +: 8]);
            sum += act_value * weight_value;
        end
        return sum;
    endfunction

    task preload_cnm_operands(output bit [31:0] expected_result);
        int unsigned k_index;
        int unsigned lane;
        int unsigned byte_index;
        bit [31:0] lane_addr;
        bit [31:0] packed_a, packed_b;
        int signed act_value, weight_value, expected_sum;
        expected_sum = 0;
        for (k_index = 0; k_index < 8; k_index++) begin
            for (lane = 0; lane < 4; lane++) begin
                packed_a = '0;
                packed_b = '0;
                for (byte_index = 0; byte_index < 4; byte_index++) begin
                    // Keep the random values small so the independent golden
                    // sum cannot overflow the CNM's signed 64-bit accumulator.
                    act_value = $urandom_range(0, 8) - 4;
                    weight_value = $urandom_range(0, 8) - 4;
                    packed_a[byte_index*8 +: 8] = act_value[7:0];
                    packed_b[byte_index*8 +: 8] = weight_value[7:0];
                end
                lane_addr = 32'h0100 + k_index * 16 + lane * 4;
                host_write_word(lane_addr, packed_a);
                cont_mon.set_expected_cnm_word(lane_addr, packed_a);
                lane_addr = 32'h0200 + k_index * 16 + lane * 4;
                host_write_word(lane_addr, packed_b);
                cont_mon.set_expected_cnm_word(lane_addr, packed_b);
                expected_sum += cnm_dot4_reference(packed_a, packed_b);
            end
        end
        host_write_word(32'h0280, 32'd0);
        host_write_word(32'h0284, 32'd0);
        expected_result = expected_sum[31:0];
    endtask

    task run_real_cnm_engine(bit [31:0] expected_result);
        @(negedge sys_vif.clk);
        sys_vif.cnm_start <= 1'b1;
        @(negedge sys_vif.clk);
        sys_vif.cnm_start <= 1'b0;
        fork : wait_for_cnm_completion
            begin
                wait (sys_vif.cnm_done === 1'b1);
            end
            begin
                repeat (200) @(posedge sys_vif.clk);
                `uvm_error("SPAD_CNM_TIMEOUT", $sformatf(
                    "real four-bank CNM core did not complete; busy=%0b done=%0b error=%0b code=%0h req=%b ready=%b rsp=%b spad_valid=%0b spad_ready=%0b",
                    sys_vif.cnm_busy, sys_vif.cnm_done, sys_vif.cnm_error,
                    sys_vif.cnm_error_code, sys_vif.cnm_req_valid,
                    sys_vif.cnm_req_ready, sys_vif.cnm_rsp_valid,
                    sys_vif.cnm_spad_valid, sys_vif.core_ready))
            end
        join_any
        disable wait_for_cnm_completion;
        #1;
        if (sys_vif.cnm_busy || sys_vif.cnm_error ||
            sys_vif.cnm_result !== expected_result || sys_vif.cnm_element_count != 1 ||
            sys_vif.cnm_global_reduce_events != 1 ||
            sys_vif.cnm_banked_read_issue_events != 64)
            `uvm_error("SPAD_CNM_RESULT", $sformatf(
                "CNM busy=%0b error=%0b code=%0h result=0x%08h expected=0x%08h elements=%0d reductions=%0d reads=%0d cycles=%0d",
                sys_vif.cnm_busy, sys_vif.cnm_error, sys_vif.cnm_error_code,
                sys_vif.cnm_result, expected_result, sys_vif.cnm_element_count,
                sys_vif.cnm_global_reduce_events, sys_vif.cnm_banked_read_issue_events,
                sys_vif.cnm_cycle_count))
    endtask

    task run_cnm_abort_after_read_response();
        bit [31:0] result_readback;
        int unsigned abort_rsp_threshold;
        cont_mon.reset_cnm_stats();
        abort_rsp_threshold = $urandom_range(1, 8);
        host_write_word(32'h02a0, 32'hface_baad);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h02a0;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;

        `uvm_info("SPAD_CNM_ABORT_SETUP", $sformatf(
            "seed-random early-abort threshold=%0d checked responses per lane (full K=8,M=1 traffic is 16/lane)",
            abort_rsp_threshold), UVM_LOW)
        @(negedge sys_vif.clk);
        sys_vif.cnm_start <= 1'b1;
        @(negedge sys_vif.clk);
        sys_vif.cnm_start <= 1'b0;
        fork : wait_for_cnm_response_before_abort
            begin
                wait (cont_mon.cnm_lane_responses_checked[0] >= abort_rsp_threshold &&
                      cont_mon.cnm_lane_responses_checked[1] >= abort_rsp_threshold &&
                      cont_mon.cnm_lane_responses_checked[2] >= abort_rsp_threshold &&
                      cont_mon.cnm_lane_responses_checked[3] >= abort_rsp_threshold);
            end
            begin
                repeat (100) @(posedge sys_vif.clk);
                `uvm_error("SPAD_CNM_ABORT_SETUP", $sformatf(
                    "threshold=%0d checked responses/lane timed out at %0d/%0d/%0d/%0d",
                    abort_rsp_threshold, cont_mon.cnm_lane_responses_checked[0],
                    cont_mon.cnm_lane_responses_checked[1], cont_mon.cnm_lane_responses_checked[2],
                    cont_mon.cnm_lane_responses_checked[3]))
            end
        join_any
        disable wait_for_cnm_response_before_abort;

        @(negedge sys_vif.clk);
        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_responses_checked[lane] < abort_rsp_threshold)
                `uvm_error("SPAD_CNM_ABORT_SETUP", $sformatf(
                    "lane %0d checked responses=%0d below selected threshold=%0d at abort",
                    lane, cont_mon.cnm_lane_responses_checked[lane], abort_rsp_threshold))
        end
        `uvm_info("SPAD_CNM_ABORT_TRIGGER", $sformatf(
            "asserting abort at threshold=%0d; accepted reads=%0d/%0d/%0d/%0d checked responses=%0d/%0d/%0d/%0d",
            abort_rsp_threshold, cont_mon.cnm_lane_reads_accepted[0],
            cont_mon.cnm_lane_reads_accepted[1], cont_mon.cnm_lane_reads_accepted[2],
            cont_mon.cnm_lane_reads_accepted[3], cont_mon.cnm_lane_responses_checked[0],
            cont_mon.cnm_lane_responses_checked[1], cont_mon.cnm_lane_responses_checked[2],
            cont_mon.cnm_lane_responses_checked[3]), UVM_LOW)
        sys_vif.cnm_abort <= 1'b1;
        @(negedge sys_vif.clk);
        sys_vif.cnm_abort <= 1'b0;
        fork : wait_for_cnm_abort_completion
            begin
                wait (sys_vif.cnm_done === 1'b1);
            end
            begin
                repeat (100) @(posedge sys_vif.clk);
                `uvm_error("SPAD_CNM_ABORT_TIMEOUT", $sformatf(
                    "CNM abort did not complete at threshold=%0d; busy=%0b done=%0b error=%0b code=%0h checked responses=%0d/%0d/%0d/%0d",
                    abort_rsp_threshold, sys_vif.cnm_busy, sys_vif.cnm_done,
                    sys_vif.cnm_error, sys_vif.cnm_error_code,
                    cont_mon.cnm_lane_responses_checked[0], cont_mon.cnm_lane_responses_checked[1],
                    cont_mon.cnm_lane_responses_checked[2], cont_mon.cnm_lane_responses_checked[3]))
            end
        join_any
        disable wait_for_cnm_abort_completion;
        repeat (2) @(posedge sys_vif.clk);
        #1;

        if (sys_vif.cnm_busy || !sys_vif.cnm_error || sys_vif.cnm_error_code != 4'd3)
            `uvm_error("SPAD_CNM_ABORT_STATUS", $sformatf(
                "expected completed ERR_ABORT=3; busy=%0b error=%0b code=%0h",
                sys_vif.cnm_busy, sys_vif.cnm_error, sys_vif.cnm_error_code))
        if (cont_mon.cnm_spad_writes_accepted != 0)
            `uvm_error("SPAD_CNM_ABORT_WRITE", $sformatf(
                "aborted CNM committed %0d result writes",
                cont_mon.cnm_spad_writes_accepted))
        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_reads_accepted[lane] == 0 ||
                cont_mon.cnm_lane_reads_accepted[lane] != cont_mon.cnm_lane_responses_checked[lane])
                `uvm_error("SPAD_CNM_ABORT_DRAIN", $sformatf(
                    "lane %0d abort traffic reads/responses=%0d/%0d",
                    lane, cont_mon.cnm_lane_reads_accepted[lane],
                    cont_mon.cnm_lane_responses_checked[lane]))
        end
        if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
            cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
            `uvm_error("SPAD_CNM_ABORT_DRAIN", "accepted CNM reads remained without matching responses after abort")
        host_read_word(32'h02a0, result_readback);
        if (result_readback !== 32'hface_baad)
            `uvm_error("SPAD_CNM_ABORT_WRITE", $sformatf(
                "aborted CNM changed destination to 0x%08h; expected sentinel 0xfacebaad",
                result_readback))
        else
            `uvm_info("SPAD_CNM_ABORT_PASS", $sformatf(
                "CNM abort retired ERR_ABORT=3 at selected threshold=%0d; reads=%0d/%0d/%0d/%0d responses=%0d/%0d/%0d/%0d, no result write",
                abort_rsp_threshold, cont_mon.cnm_lane_reads_accepted[0],
                cont_mon.cnm_lane_reads_accepted[1], cont_mon.cnm_lane_reads_accepted[2],
                cont_mon.cnm_lane_reads_accepted[3], cont_mon.cnm_lane_responses_checked[0],
                cont_mon.cnm_lane_responses_checked[1], cont_mon.cnm_lane_responses_checked[2],
                cont_mon.cnm_lane_responses_checked[3]), UVM_LOW)
    endtask

    task run_cnm_recovery_after_abort(bit [31:0] expected_result);
        bit [31:0] result_readback;
        host_write_word(32'h02a4, 32'hdead_4bad);
        cont_mon.reset_cnm_stats();
        @(negedge sys_vif.clk);
        sys_vif.cnm_dst_base <= 32'h02a4;
        run_real_cnm_engine(expected_result);
        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_reads_accepted[lane] != 16 ||
                cont_mon.cnm_lane_responses_checked[lane] != 16)
                `uvm_error("SPAD_CNM_RECOVERY_DRAIN", $sformatf(
                    "lane %0d recovery reads/responses=%0d/%0d expected=16/16",
                    lane, cont_mon.cnm_lane_reads_accepted[lane],
                    cont_mon.cnm_lane_responses_checked[lane]))
        end
        if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
            cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
            `uvm_error("SPAD_CNM_RECOVERY_DRAIN", "recovery left unmatched CNM response data")
        if (cont_mon.cnm_spad_writes_accepted != 1)
            `uvm_error("SPAD_CNM_RECOVERY_WRITE", $sformatf(
                "recovery result writes=%0d expected=1", cont_mon.cnm_spad_writes_accepted))
        host_read_word(32'h02a4, result_readback);
        if (result_readback !== expected_result)
            `uvm_error("SPAD_CNM_RECOVERY_WRITE", $sformatf(
                "recovery result readback=0x%08h expected=0x%08h",
                result_readback, expected_result))
        else
            `uvm_info("SPAD_CNM_RECOVERY_PASS", $sformatf(
                "CNM accepted a clean task after abort without reset; result=0x%08h",
                result_readback), UVM_LOW)
    endtask

    task run_cnm_reset_recovery(bit reset_after_all_reads);
        bit [31:0] expected_result, result_readback;
        bit reset_phase_seen;
        int unsigned reset_phase_index;
        string reset_phase_name;
        int unsigned saved_core_reads, saved_core_responses;
        int unsigned saved_core_contended, saved_core_isolated;
        int unsigned saved_dma_contended, saved_dma_isolated;
        int unsigned saved_desc_grants, saved_cpl_grants;
        if (cont_mon.expected_core_data.size() != 0)
            `uvm_error("SPAD_CNM_RESET_SETUP", $sformatf(
                "unrelated scalar core response expectations would be cleared by reset: %0d",
                cont_mon.expected_core_data.size()))
        // Preserve only pre-reset aggregate counters consumed by the final
        // check_complete. Do not restore response queues, oracle contents, or
        // outstanding state; those must remain cleared by reset and are
        // checked/rebuilt below.
        saved_core_reads = cont_mon.core_reads_accepted;
        saved_core_responses = cont_mon.core_responses_checked;
        saved_core_contended = cont_mon.core_grants_under_contention;
        saved_core_isolated = cont_mon.core_grants_isolated;
        saved_dma_contended = cont_mon.dma_grants_under_contention;
        saved_dma_isolated = cont_mon.dma_grants_isolated;
        saved_desc_grants = cont_mon.desc_priority_grants;
        saved_cpl_grants = cont_mon.cpl_priority_grants;
        // The responder clears its live transaction queues on reset. Keep the
        // historical evidence sticky so a later reset-phase scenario does not
        // mistake that expected cleanup for missing AXI exercise.
        saw_axi_read_before_subsystem_reset = saw_axi_read_before_subsystem_reset ||
                                              (env.axi_rsp.accepted_ids.size() != 0);
        saw_axi_write_before_subsystem_reset = saw_axi_write_before_subsystem_reset ||
                                               (env.axi_rsp.accepted_bids.size() != 0);
        if (!saw_axi_read_before_subsystem_reset || !saw_axi_write_before_subsystem_reset)
            `uvm_error("DMA_SPAD_AXI_SETUP", $sformatf(
                "before subsystem reset expected historical AXI read/write evidence; AR=%0d AW/W=%0d",
                env.axi_rsp.accepted_ids.size(), env.axi_rsp.accepted_bids.size()))
        cont_mon.reset_cnm_stats();
        preload_cnm_operands(expected_result);
        host_write_word(32'h02a8, 32'hcafe_a8a8);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h02a8;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;

        reset_phase_index = reset_after_all_reads ? 1 : 0;
        reset_phase_name = reset_after_all_reads ? "all_reads_returned_prewrite" :
                                                   "accepted_read_outstanding";
        `uvm_info("SPAD_CNM_RESET_SETUP", $sformatf(
            "starting real CNM before subsystem reset request; reset phase=%s",
            reset_phase_name), UVM_LOW)
        @(negedge sys_vif.clk);
        sys_vif.cnm_start <= 1'b1;
        @(negedge sys_vif.clk);
        sys_vif.cnm_start <= 1'b0;
        reset_phase_seen = 1'b0;
        fork : wait_for_cnm_reset_phase
            begin
                if (reset_after_all_reads) begin
                    wait (cont_mon.cnm_lane_reads_accepted[0] == 16 &&
                          cont_mon.cnm_lane_reads_accepted[1] == 16 &&
                          cont_mon.cnm_lane_reads_accepted[2] == 16 &&
                          cont_mon.cnm_lane_reads_accepted[3] == 16 &&
                          cont_mon.cnm_lane_responses_checked[0] == 16 &&
                          cont_mon.cnm_lane_responses_checked[1] == 16 &&
                          cont_mon.cnm_lane_responses_checked[2] == 16 &&
                          cont_mon.cnm_lane_responses_checked[3] == 16 &&
                          sys_vif.cnm_busy === 1'b1 &&
                          sys_vif.cnm_spad_valid === 1'b0 &&
                          cont_mon.cnm_spad_writes_accepted == 0);
                end else begin
                    wait (cont_mon.cnm_outstanding_read_observed === 1'b1);
                end
                reset_phase_seen = 1'b1;
            end
            begin
                repeat (100) @(posedge sys_vif.clk);
                `uvm_error("SPAD_CNM_RESET_SETUP", $sformatf(
                    "reset phase %s not observed; reads=%0d/%0d/%0d/%0d responses=%0d/%0d/%0d/%0d busy=%0b spad_valid=%0b writes=%0d",
                    reset_phase_name,
                    cont_mon.cnm_lane_reads_accepted[0], cont_mon.cnm_lane_reads_accepted[1],
                    cont_mon.cnm_lane_reads_accepted[2], cont_mon.cnm_lane_reads_accepted[3],
                    cont_mon.cnm_lane_responses_checked[0], cont_mon.cnm_lane_responses_checked[1],
                    cont_mon.cnm_lane_responses_checked[2], cont_mon.cnm_lane_responses_checked[3],
                    sys_vif.cnm_busy, sys_vif.cnm_spad_valid, cont_mon.cnm_spad_writes_accepted))
            end
        join_any
        disable wait_for_cnm_reset_phase;
        if (!reset_phase_seen) begin
            `uvm_error("SPAD_CNM_RESET_SETUP", $sformatf(
                "reset phase %s was not observed before timeout",
                reset_phase_name))
            return;
        end else if (reset_after_all_reads) begin
            for (int lane = 0; lane < 4; lane++) begin
                if (cont_mon.cnm_lane_reads_accepted[lane] != 16 ||
                    cont_mon.cnm_lane_responses_checked[lane] != 16)
                    `uvm_error("SPAD_CNM_RESET_SETUP", $sformatf(
                        "prewrite reset lane %0d reads/responses=%0d/%0d expected=16/16",
                        lane, cont_mon.cnm_lane_reads_accepted[lane],
                        cont_mon.cnm_lane_responses_checked[lane]))
            end
            if (sys_vif.cnm_busy !== 1'b1 || sys_vif.cnm_spad_valid !== 1'b0 ||
                cont_mon.cnm_spad_writes_accepted != 0)
                `uvm_error("SPAD_CNM_RESET_SETUP", $sformatf(
                    "prewrite reset must precede result request acceptance: busy=%0b spad_valid=%0b writes=%0d",
                    sys_vif.cnm_busy, sys_vif.cnm_spad_valid,
                    cont_mon.cnm_spad_writes_accepted))
            `uvm_info("SPAD_CNM_RESET_SETUP",
                "observed all 16 reads/responses on every lane, CNM busy, and no result write before reset", UVM_LOW)
        end else begin
            if (!cont_mon.cnm_outstanding_read_observed)
                `uvm_error("SPAD_CNM_RESET_SETUP", "reset test did not observe an accepted read without a matching response")
            `uvm_info("SPAD_CNM_RESET_SETUP", $sformatf(
                "observed accepted CNM read outstanding before reset; accepted=%0d/%0d/%0d/%0d responses=%0d/%0d/%0d/%0d",
                cont_mon.cnm_lane_reads_accepted[0], cont_mon.cnm_lane_reads_accepted[1],
                cont_mon.cnm_lane_reads_accepted[2], cont_mon.cnm_lane_reads_accepted[3],
                cont_mon.cnm_lane_responses_checked[0], cont_mon.cnm_lane_responses_checked[1],
                cont_mon.cnm_lane_responses_checked[2], cont_mon.cnm_lane_responses_checked[3]), UVM_LOW)
        end
        cont_mon.sample_cnm_reset_phase(reset_phase_index);

        // Request at the current safe sampling edge. The TB top asserts the
        // shared reset on its next falling edge and acknowledges that phase.
        sys_vif.subsystem_reset_req <= 1'b1;
        fork : wait_for_subsystem_reset_assert
            begin
                wait (sys_vif.subsystem_reset_ack === 1'b1);
            end
            begin
                repeat (10) @(posedge sys_vif.clk);
                `uvm_error("SPAD_CNM_RESET_TIMEOUT", "testbench did not acknowledge subsystem reset assertion")
            end
        join_any
        disable wait_for_subsystem_reset_assert;
        if (sys_vif.subsystem_reset_ack !== 1'b1) begin
            `uvm_error("SPAD_CNM_RESET_TIMEOUT", "subsystem reset assertion handshake timed out")
            sys_vif.subsystem_reset_req <= 1'b0;
            return;
        end

        repeat (2) @(posedge sys_vif.clk);
        #1;
        if (sys_vif.cnm_busy !== 1'b0 || sys_vif.cnm_done !== 1'b0 ||
            sys_vif.cnm_error !== 1'b0 || sys_vif.cnm_req_valid !== 4'b0 ||
            sys_vif.cnm_rsp_valid !== 4'b0 || sys_vif.cnm_spad_valid !== 1'b0)
            `uvm_error("SPAD_CNM_RESET_STATE", $sformatf(
                "during reset CNM busy/done/error/req/rsp/spad_valid=%0b/%0b/%0b/%b/%b/%0b",
                sys_vif.cnm_busy, sys_vif.cnm_done, sys_vif.cnm_error,
                sys_vif.cnm_req_valid, sys_vif.cnm_rsp_valid, sys_vif.cnm_spad_valid))

        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b0;
        fork : wait_for_subsystem_reset_release
            begin
                wait (sys_vif.subsystem_reset_ack === 1'b0);
            end
            begin
                repeat (10) @(posedge sys_vif.clk);
                `uvm_error("SPAD_CNM_RESET_TIMEOUT", "testbench did not acknowledge subsystem reset release")
            end
        join_any
        disable wait_for_subsystem_reset_release;
        if (sys_vif.subsystem_reset_ack !== 1'b0) begin
            `uvm_error("SPAD_CNM_RESET_TIMEOUT", "subsystem reset release handshake timed out")
            return;
        end

        // Let any stale bank response or write attempt become observable
        // before repopulating either scratchpad data or the monitor oracle.
        repeat (4) begin
            @(posedge sys_vif.clk);
            #1;
            if (sys_vif.cnm_busy || sys_vif.cnm_done || sys_vif.cnm_error ||
                sys_vif.cnm_req_valid != 4'b0 || sys_vif.cnm_rsp_valid != 4'b0 ||
                sys_vif.cnm_spad_valid || cont_mon.cnm_spad_writes_accepted != 0)
                `uvm_error("SPAD_CNM_RESET_STALE", $sformatf(
                    "stale CNM activity after reset release: busy/done/error/req/rsp/write=%0b/%0b/%0b/%b/%b/%0d",
                    sys_vif.cnm_busy, sys_vif.cnm_done, sys_vif.cnm_error,
                    sys_vif.cnm_req_valid, sys_vif.cnm_rsp_valid,
                    cont_mon.cnm_spad_writes_accepted))
        end
        if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
            cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
            `uvm_error("SPAD_CNM_RESET_STALE", $sformatf(
                "response expectation queues not cleared by reset: %0d/%0d/%0d/%0d",
                cont_mon.expected_cnm_lane_data0.size(), cont_mon.expected_cnm_lane_data1.size(),
                cont_mon.expected_cnm_lane_data2.size(), cont_mon.expected_cnm_lane_data3.size()))
        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_reads_accepted[lane] != 0 ||
                cont_mon.cnm_lane_responses_checked[lane] != 0)
                `uvm_error("SPAD_CNM_RESET_STALE", $sformatf(
                    "post-reset stale lane %0d traffic: accepted/responses=%0d/%0d",
                    lane, cont_mon.cnm_lane_reads_accepted[lane],
                    cont_mon.cnm_lane_responses_checked[lane]))
        end
        host_read_word(32'h02a8, result_readback);
        if (result_readback !== 32'hcafe_a8a8)
            `uvm_error("SPAD_CNM_RESET_STALE", $sformatf(
                "reset-time CNM changed sentinel to 0x%08h expected=0xcafea8a8", result_readback))

        cont_mon.core_reads_accepted = saved_core_reads;
        cont_mon.core_responses_checked = saved_core_responses;
        cont_mon.core_grants_under_contention = saved_core_contended;
        cont_mon.core_grants_isolated = saved_core_isolated;
        cont_mon.dma_grants_under_contention = saved_dma_contended;
        cont_mon.dma_grants_isolated = saved_dma_isolated;
        cont_mon.desc_priority_grants = saved_desc_grants;
        cont_mon.cpl_priority_grants = saved_cpl_grants;

        // Reset clears the monitor's address oracle, so rewrite and register
        // all operands before proving the core can complete again without a
        // second reset.
        cont_mon.reset_cnm_stats();
        preload_cnm_operands(expected_result);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h02a8;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;
        run_real_cnm_engine(expected_result);

        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_reads_accepted[lane] != 16 ||
                cont_mon.cnm_lane_responses_checked[lane] != 16)
                `uvm_error("SPAD_CNM_RESET_RECOVERY", $sformatf(
                    "post-reset lane %0d reads/responses=%0d/%0d expected=16/16",
                    lane, cont_mon.cnm_lane_reads_accepted[lane],
                    cont_mon.cnm_lane_responses_checked[lane]))
        end
        if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
            cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
            `uvm_error("SPAD_CNM_RESET_RECOVERY", "post-reset CNM left unmatched response expectations")
        if (cont_mon.cnm_spad_writes_accepted != 1)
            `uvm_error("SPAD_CNM_RESET_RECOVERY", $sformatf(
                "post-reset CNM result writes=%0d expected=1", cont_mon.cnm_spad_writes_accepted))
        host_read_word(32'h02a8, result_readback);
        if (result_readback !== expected_result)
            `uvm_error("SPAD_CNM_RESET_RECOVERY", $sformatf(
                "post-reset CNM result=0x%08h expected=0x%08h", result_readback, expected_result))
        else
        `uvm_info("SPAD_CNM_RESET_RECOVERY_PASS", $sformatf(
            "CNM recovered after %s reset: lane reads/responses=16/16 each, one result write, result=0x%08h",
            reset_phase_name,
                result_readback), UVM_LOW)
    endtask

    task toggle_cnm_parity_bit(bit [31:0] byte_addr);
        string hdl_path;
        uvm_hdl_data_t hdl_value;
        bit original_value;
        int unsigned bank_index;
        int unsigned row_index;

        // VCS behavioral scratchpad stores one parity bit beside each
        // 32-bit word. Keep this fault injection in the testbench only.
        bank_index = (byte_addr >> 2) & 32'h3;
        row_index = (byte_addr >> 4) & 32'hff;
        hdl_path = $sformatf(
            "tb_ai_dma_spad_subsystem_uvm.memory_fabric_dut.spad_subsystem_u.scratchpad_u.bank%0d_parity[%0d]",
            bank_index, row_index);
        if (!uvm_hdl_read(hdl_path, hdl_value))
            `uvm_fatal("SPAD_PARITY_BACKDOOR", $sformatf("cannot read parity bit at %s", hdl_path))
        original_value = hdl_value[0];
        hdl_value[0] = ~original_value;
        if (!uvm_hdl_deposit(hdl_path, hdl_value))
            `uvm_fatal("SPAD_PARITY_BACKDOOR", $sformatf("cannot deposit parity bit at %s", hdl_path))
        if (!uvm_hdl_read(hdl_path, hdl_value) || hdl_value[0] !== ~original_value)
            `uvm_fatal("SPAD_PARITY_BACKDOOR", $sformatf("parity bit did not toggle at %s", hdl_path))
        `uvm_info("SPAD_PARITY_BACKDOOR", $sformatf(
            "toggled behavioral scratchpad parity at address=0x%08h bank=%0d row=%0d",
            byte_addr, bank_index, row_index), UVM_LOW)
    endtask

    task run_cnm_parity_fault_contention();
        bit [31:0] expected_result;
        bit [31:0] result_readback;
        bit [31:0] fault_addr;
        bit [31:0] fault_dst;
        bit [31:0] dst_sentinel;
        int unsigned lane;
        int unsigned dma_contended_before;
        int unsigned cnm_contended_before;

        cont_mon.expect_cnm_protection_fault(1'b0);
        sys_vif.region0_base <= '0;
        sys_vif.region0_limit <= '0;
        sys_vif.region0_perm <= '0;
        for (lane = 0; lane < 4; lane++) begin
            cont_mon.reset_cnm_stats();
            preload_cnm_operands(expected_result);
            fault_addr = 32'h0100 + lane * 4;
            fault_dst = 32'h0380;
            dst_sentinel = 32'hcafe_9000 | lane;
            host_write_word(fault_dst, dst_sentinel);
            toggle_cnm_parity_bit(fault_addr);
            cont_mon.expect_cnm_parity_fault(1'b1, fault_addr);

            @(negedge sys_vif.clk);
            sys_vif.cnm_op_mode <= 8'h20;
            sys_vif.cnm_src0_base <= 32'h0100;
            sys_vif.cnm_src1_base <= 32'h0200;
            sys_vif.cnm_dst_base <= fault_dst;
            sys_vif.cnm_length <= 16'd8;
            sys_vif.cnm_m_size <= 16'd1;
            sys_vif.cnm_scale_shift <= 5'd0;
            sys_vif.cnm_activation <= 2'd0;
            sys_vif.cnm_watchdog_limit <= 32'd10000;
            sys_vif.cnm_abort <= 1'b0;
            sys_vif.cnm_mode <= 1'b1;
            dma_contended_before = cont_mon.dma_grants_under_contention;
            cnm_contended_before = cont_mon.cnm_grants_under_contention;

            // Launch a real DMA load first, then run CNM while DMA is active.
            fork
                begin
                    run_dma_command(1'b0, 64'h0000_f400 + lane * 64'h100,
                                    32'h0600 + lane * 32'h80);
                end
                begin : start_cnm_after_dma_grant
                    // The DMA's first ready/grant is a short combinational
                    // pulse and can occur before this forked process begins
                    // waiting. A fixed six-cycle offset is inside the
                    // deterministic 32-word transfer window; the monitored
                    // grant counters below prove that actual overlap occurs.
                    repeat (6) @(posedge sys_vif.clk);
                    @(negedge sys_vif.clk);
                    sys_vif.cnm_start <= 1'b1;
                    @(negedge sys_vif.clk);
                    sys_vif.cnm_start <= 1'b0;
                    fork : wait_for_cnm_parity_error
                        begin
                            wait (sys_vif.cnm_done === 1'b1);
                        end
                        begin
                            repeat (300) @(posedge sys_vif.clk);
                            `uvm_error("SPAD_CNM_PARITY_TIMEOUT", $sformatf(
                                "lane %0d parity case timed out; busy/done/error/code=%0b/%0b/%0b/%0h",
                                lane, sys_vif.cnm_busy, sys_vif.cnm_done,
                                sys_vif.cnm_error, sys_vif.cnm_error_code))
                        end
                    join_any
                    disable wait_for_cnm_parity_error;
                end
            join
            #1;

            if (sys_vif.cnm_busy || !sys_vif.cnm_error || sys_vif.cnm_error_code != 4'd5)
                `uvm_error("SPAD_CNM_PARITY_STATUS", $sformatf(
                    "lane %0d parity error must retire ERR_PARITY=5; busy/error/code=%0b/%0b/%0h",
                    lane, sys_vif.cnm_busy, sys_vif.cnm_error, sys_vif.cnm_error_code))
            if (cont_mon.expected_cnm_parity_pending)
                `uvm_error("SPAD_CNM_PARITY_INJECT", $sformatf(
                    "lane %0d parity-faulted word 0x%08h was not accepted", lane, fault_addr))
            if ((cont_mon.dma_grants_under_contention - dma_contended_before) == 0 ||
                (cont_mon.cnm_grants_under_contention - cnm_contended_before) == 0)
                `uvm_error("SPAD_CNM_PARITY_CONTENTION", $sformatf(
                    "lane %0d parity case did not observe both sides granted under contention", lane))
            if (cont_mon.cnm_spad_writes_accepted != 0)
                `uvm_error("SPAD_CNM_PARITY_WRITE", $sformatf(
                    "lane %0d parity failure accepted %0d result writes",
                    lane, cont_mon.cnm_spad_writes_accepted))

            // Other local lanes may already have accepted reads when the
            // faulting lane reports parity. Drain every accepted response.
            fork : wait_for_cnm_parity_drain
                begin
                    wait (!cont_mon.expected_cnm_parity_pending &&
                          cont_mon.cnm_lane_reads_accepted[0] > 0 &&
                          cont_mon.cnm_lane_reads_accepted[0] == cont_mon.cnm_lane_responses_checked[0] &&
                          cont_mon.cnm_lane_reads_accepted[1] > 0 &&
                          cont_mon.cnm_lane_reads_accepted[1] == cont_mon.cnm_lane_responses_checked[1] &&
                          cont_mon.cnm_lane_reads_accepted[2] > 0 &&
                          cont_mon.cnm_lane_reads_accepted[2] == cont_mon.cnm_lane_responses_checked[2] &&
                          cont_mon.cnm_lane_reads_accepted[3] > 0 &&
                          cont_mon.cnm_lane_reads_accepted[3] == cont_mon.cnm_lane_responses_checked[3] &&
                          cont_mon.expected_cnm_lane_data0.size() == 0 &&
                          cont_mon.expected_cnm_lane_data1.size() == 0 &&
                          cont_mon.expected_cnm_lane_data2.size() == 0 &&
                          cont_mon.expected_cnm_lane_data3.size() == 0);
                end
                begin
                    repeat (500) @(posedge sys_vif.clk);
                    `uvm_error("SPAD_CNM_PARITY_DRAIN", $sformatf(
                        "lane %0d parity drain timeout; accepted/responses=%0d/%0d,%0d/%0d,%0d/%0d,%0d/%0d",
                        lane, cont_mon.cnm_lane_reads_accepted[0], cont_mon.cnm_lane_responses_checked[0],
                        cont_mon.cnm_lane_reads_accepted[1], cont_mon.cnm_lane_responses_checked[1],
                        cont_mon.cnm_lane_reads_accepted[2], cont_mon.cnm_lane_responses_checked[2],
                        cont_mon.cnm_lane_reads_accepted[3], cont_mon.cnm_lane_responses_checked[3]))
                end
            join_any
            disable wait_for_cnm_parity_drain;

            for (int drain_lane = 0; drain_lane < 4; drain_lane++) begin
                if (cont_mon.cnm_lane_reads_accepted[drain_lane] == 0 ||
                    cont_mon.cnm_lane_reads_accepted[drain_lane] !=
                    cont_mon.cnm_lane_responses_checked[drain_lane])
                    `uvm_error("SPAD_CNM_PARITY_DRAIN", $sformatf(
                        "lane %0d parity fault left lane %0d reads/responses=%0d/%0d",
                        lane, drain_lane, cont_mon.cnm_lane_reads_accepted[drain_lane],
                        cont_mon.cnm_lane_responses_checked[drain_lane]))
            end
            if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
                cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size() ||
                cont_mon.expected_cnm_lane_parity0.size() || cont_mon.expected_cnm_lane_parity1.size() ||
                cont_mon.expected_cnm_lane_parity2.size() || cont_mon.expected_cnm_lane_parity3.size())
                `uvm_error("SPAD_CNM_PARITY_DRAIN", "parity-fault case left unmatched response expectations")

            host_read_word(fault_dst, result_readback);
            if (result_readback !== dst_sentinel)
                `uvm_error("SPAD_CNM_PARITY_WRITE", $sformatf(
                    "lane %0d parity fault changed destination 0x%08h to 0x%08h expected=0x%08h",
                    lane, fault_dst, result_readback, dst_sentinel))

            // Restore the parity metadata and prove clean recovery without reset.
            toggle_cnm_parity_bit(fault_addr);
            cont_mon.expect_cnm_parity_fault(1'b0, '0);
            preload_cnm_operands(expected_result);
            cont_mon.reset_cnm_stats();
            @(negedge sys_vif.clk);
            sys_vif.cnm_src0_base <= 32'h0100;
            sys_vif.cnm_src1_base <= 32'h0200;
            sys_vif.cnm_dst_base <= fault_dst;
            run_real_cnm_engine(expected_result);
            for (int recovery_lane = 0; recovery_lane < 4; recovery_lane++) begin
                if (cont_mon.cnm_lane_reads_accepted[recovery_lane] != 16 ||
                    cont_mon.cnm_lane_responses_checked[recovery_lane] != 16)
                    `uvm_error("SPAD_CNM_PARITY_RECOVERY", $sformatf(
                        "fault lane %0d recovery lane %0d reads/responses=%0d/%0d expected=16/16",
                        lane, recovery_lane, cont_mon.cnm_lane_reads_accepted[recovery_lane],
                        cont_mon.cnm_lane_responses_checked[recovery_lane]))
            end
            host_read_word(fault_dst, result_readback);
            if (result_readback !== expected_result)
                `uvm_error("SPAD_CNM_PARITY_RECOVERY", $sformatf(
                    "lane %0d clean recovery result=0x%08h expected=0x%08h",
                    lane, result_readback, expected_result))
            cont_mon.sample_cnm_parity_contention(lane, 1'b1);
            `uvm_info("SPAD_CNM_PARITY_PASS", $sformatf(
                "lane %0d parity error retired ERR_PARITY=5 under DMA contention; reads drained, destination preserved, clean recovery=0x%08h",
                lane, result_readback), UVM_LOW)
        end

        if (cont_mon.cnm_parity_contention_cg.get_coverage() < 100.0)
            `uvm_error("SPAD_CNM_PARITY_COVERAGE", $sformatf(
                "lane x DMA-contention parity coverage=%0.2f%% expected=100%%",
                cont_mon.cnm_parity_contention_cg.get_coverage()))
        else
            `uvm_info("SPAD_CNM_PARITY_COVERAGE", $sformatf(
                "CNM parity-fault lane x DMA-contention cross=%0.2f%%",
                cont_mon.cnm_parity_contention_cg.get_coverage()), UVM_LOW)
    endtask

    task run_cnm_parity_fault_during_dma_abort();
        bit [31:0] expected_result, result_readback;
        bit [31:0] fault_addr, fault_dst, dst_sentinel;
        int unsigned accepted_before, completed_before, dma_writes_before;
        int unsigned overlap_cycles, setup_cycles;
        bit dma_drained;

        cont_mon.expect_cnm_protection_fault(1'b0);
        cont_mon.reset_cnm_stats();
        preload_cnm_operands(expected_result);
        fault_addr = 32'h0100;
        fault_dst = 32'h0380;
        dst_sentinel = 32'hcafe_a10d;
        host_write_word(fault_dst, dst_sentinel);
        toggle_cnm_parity_bit(fault_addr);
        cont_mon.expect_cnm_parity_fault(1'b1, fault_addr);
        for (int word_index = 0; word_index < 32; word_index++)
            host_write_word(32'h0a00 + word_index * 4, 32'hdeadcafe);

        // Four accepted reads are held until DMA abort is underway. CNM then
        // retires its independent parity error during the DMA abort drain.
        cfg.inject_read_error = 1'b0;
        cfg.min_accepted_reads_before_response = 4;
        cfg.read_response_delay_cycles = 48;
        accepted_before = env.axi_rsp.accepted_ids.size();
        completed_before = env.axi_rsp.completed_ids.size();
        dma_writes_before = cont_mon.dma_write_grants;
        overlap_cycles = 0;
        setup_cycles = 0;

        fork
            run_dma_expected_abort_drain();
            begin : launch_cnm_after_dma_abort
                while (env.axi_rsp.accepted_ids.size() < accepted_before + 4 &&
                       setup_cycles < 500) begin
                    @(posedge sys_vif.clk);
                    #1;
                    setup_cycles++;
                end
                if (setup_cycles >= 500) begin
                    `uvm_error("SPAD_PARITY_ABORT_SETUP", "DMA did not accept four reads")
                end else begin
                    repeat (5) @(posedge sys_vif.clk);
                    @(negedge sys_vif.clk);
                    sys_vif.cnm_op_mode <= 8'h20;
                    sys_vif.cnm_src0_base <= 32'h0100;
                    sys_vif.cnm_src1_base <= 32'h0200;
                    sys_vif.cnm_dst_base <= fault_dst;
                    sys_vif.cnm_length <= 16'd8;
                    sys_vif.cnm_m_size <= 16'd1;
                    sys_vif.cnm_scale_shift <= 5'd0;
                    sys_vif.cnm_activation <= 2'd0;
                    sys_vif.cnm_watchdog_limit <= 32'd10000;
                    sys_vif.cnm_abort <= 1'b0;
                    sys_vif.cnm_mode <= 1'b1;
                    sys_vif.cnm_start <= 1'b1;
                    @(negedge sys_vif.clk);
                    sys_vif.cnm_start <= 1'b0;
                    fork : wait_cnm_parity_done
                        begin wait (sys_vif.cnm_done === 1'b1); end
                        begin
                            repeat (500) @(posedge sys_vif.clk);
                            `uvm_error("SPAD_PARITY_ABORT_TIMEOUT", "CNM parity error timed out")
                        end
                    join_any
                    disable wait_cnm_parity_done;
                end
            end
            begin : monitor_abort_error_overlap
                wait (sys_vif.cnm_busy === 1'b1);
                while (sys_vif.cnm_done !== 1'b1) begin
                    @(posedge sys_vif.clk);
                    if (sys_vif.cnm_busy && env.cmd_drv.vif.busy &&
                        env.cmd_drv.vif.error)
                        overlap_cycles++;
                end
            end
        join
        #1;

        dma_drained =
            (env.axi_rsp.accepted_ids.size() - accepted_before == 4) &&
            (env.axi_rsp.completed_ids.size() - completed_before == 4) &&
            (env.cmd_drv.vif.rd_highwater >= 4) &&
            (env.cmd_drv.vif.rd_outstanding == 0) && !env.cmd_drv.vif.busy &&
            (env.axi_rsp.active_read == null) && (env.axi_rsp.pending_reads.size() == 0);
        if (!dma_drained)
            `uvm_error("SPAD_PARITY_ABORT_DRAIN", $sformatf(
                "DMA accepted/completed=%0d/%0d highwater=%0d outstanding=%0d busy=%0b active=%0b pending=%0d",
                env.axi_rsp.accepted_ids.size() - accepted_before,
                env.axi_rsp.completed_ids.size() - completed_before,
                env.cmd_drv.vif.rd_highwater, env.cmd_drv.vif.rd_outstanding,
                env.cmd_drv.vif.busy, env.axi_rsp.active_read != null,
                env.axi_rsp.pending_reads.size()))
        if (overlap_cycles == 0)
            `uvm_error("SPAD_PARITY_ABORT_OVERLAP",
                "CNM parity error did not overlap DMA abort/error drain")
        if (cont_mon.dma_write_grants != dma_writes_before)
            `uvm_error("SPAD_PARITY_ABORT_COMMIT", "aborted DMA committed SPAD data")
        if (sys_vif.cnm_busy || !sys_vif.cnm_error || sys_vif.cnm_error_code != 4'd5 ||
            cont_mon.expected_cnm_parity_pending || cont_mon.cnm_spad_writes_accepted != 0)
            `uvm_error("SPAD_PARITY_ABORT_CNM", $sformatf(
                "expected drained CNM ERR_PARITY=5 without result write; busy/error/code/pending/writes=%0b/%0b/%0h/%0b/%0d",
                sys_vif.cnm_busy, sys_vif.cnm_error, sys_vif.cnm_error_code,
                cont_mon.expected_cnm_parity_pending, cont_mon.cnm_spad_writes_accepted))

        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_reads_accepted[lane] == 0 ||
                cont_mon.cnm_lane_reads_accepted[lane] !=
                cont_mon.cnm_lane_responses_checked[lane])
                `uvm_error("SPAD_PARITY_ABORT_RESP", $sformatf(
                    "CNM lane %0d accepted/returned=%0d/%0d", lane,
                    cont_mon.cnm_lane_reads_accepted[lane],
                    cont_mon.cnm_lane_responses_checked[lane]))
        end
        if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
            cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size() ||
            cont_mon.expected_cnm_lane_parity0.size() || cont_mon.expected_cnm_lane_parity1.size() ||
            cont_mon.expected_cnm_lane_parity2.size() || cont_mon.expected_cnm_lane_parity3.size())
            `uvm_error("SPAD_PARITY_ABORT_RESP", "unmatched CNM response expectations remain")

        host_read_word(fault_dst, result_readback);
        if (result_readback !== dst_sentinel)
            `uvm_error("SPAD_PARITY_ABORT_SENTINEL", "CNM parity fault changed result sentinel")
        for (int word_index = 0; word_index < 32; word_index++) begin
            host_read_word(32'h0a00 + word_index * 4, result_readback);
            if (result_readback !== 32'hdeadcafe)
                `uvm_error("SPAD_PARITY_ABORT_SENTINEL", $sformatf(
                    "aborted DMA changed SPAD word %0d to 0x%08h", word_index, result_readback))
        end
        cont_mon.sample_cnm_parity_dma_abort((overlap_cycles != 0), dma_drained);
        if (cont_mon.cnm_parity_dma_abort_cg.get_coverage() < 100.0)
            `uvm_error("SPAD_PARITY_ABORT_COV", "parity x abort-drain coverage bin missed")

        toggle_cnm_parity_bit(fault_addr);
        cont_mon.expect_cnm_parity_fault(1'b0, '0);
        cfg.read_response_delay_cycles = 0;
        cfg.min_accepted_reads_before_response = 2;
        @(negedge sys_vif.clk);
        sys_vif.cnm_mode <= 1'b0;
        run_dma_command(1'b0, 64'h0000_f480, 32'h0a00);
        host_read_word(32'h0a00, result_readback);
        if (result_readback !== dma_memory_word(64'h0000_f480))
            `uvm_error("SPAD_PARITY_ABORT_RECOVERY", "DMA did not recover without reset")

        cont_mon.reset_cnm_stats();
        preload_cnm_operands(expected_result);
        @(negedge sys_vif.clk);
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= fault_dst;
        sys_vif.cnm_mode <= 1'b1;
        run_real_cnm_engine(expected_result);
        host_read_word(fault_dst, result_readback);
        if (result_readback !== expected_result)
            `uvm_error("SPAD_PARITY_ABORT_RECOVERY", $sformatf(
                "CNM recovery result=0x%08h expected=0x%08h",
                result_readback, expected_result))
        `uvm_info("SPAD_PARITY_ABORT_PASS", $sformatf(
            "CNM ERR_PARITY retired during DMA abort drain (%0d cycles); both engines recovered without reset",
            overlap_cycles), UVM_LOW)
    endtask

    task run_cnm_parity_abort_reset_recovery();
        dma_cmd_item req;
        dma_one_command_sequence seq;
        bit [31:0] expected_cnm_result, readback;
        bit [31:0] fault_addr, cnm_dst, dma_dst;
        bit [31:0] cnm_sentinel, dma_sentinel;
        int unsigned accepted_base, completed_base, dma_writes_base;
        int unsigned saved_core_reads, saved_core_responses;
        int unsigned saved_core_contended, saved_core_isolated;
        int unsigned saved_dma_contended, saved_dma_isolated;
        int unsigned saved_desc_grants, saved_cpl_grants, saved_dma_writes;
        int unsigned saved_fp_reads, saved_fp_responses, saved_fp_writes;
        int unsigned saved_fp_contended, saved_fp_dma_contended;
        int unsigned saved_fp_peak_outstanding;
        int unsigned abort_after_cycles, cnm_launch_skew, reset_delay_cycles;
        int signed reset_delay_override;
        int unsigned wait_cycles, reset_timing_class, drain_cycles;
        bit dma_seq_done, abort_seen, all_dma_reads_accepted;
        bit cnm_done_seen, reset_assert_ack, reset_release_ack;
        bit fault_abort_reset_observed;
        bit reset_delay_override_used;

        // Preserve pre-reset monitor evidence: the shared reset also resets
        // the monitor's cumulative counters along with the DUT and responder.
        saved_core_reads = cont_mon.core_reads_accepted;
        saved_core_responses = cont_mon.core_responses_checked;
        saved_core_contended = cont_mon.core_grants_under_contention;
        saved_core_isolated = cont_mon.core_grants_isolated;
        saved_dma_contended = cont_mon.dma_grants_under_contention;
        saved_dma_isolated = cont_mon.dma_grants_isolated;
        saved_desc_grants = cont_mon.desc_priority_grants;
        saved_cpl_grants = cont_mon.cpl_priority_grants;
        saved_dma_writes = cont_mon.dma_write_grants;
        saved_fp_reads = cont_mon.fp_reads_accepted;
        saved_fp_responses = cont_mon.fp_responses_checked;
        saved_fp_writes = cont_mon.fp_writes_accepted;
        saved_fp_contended = cont_mon.fp_grants_under_contention;
        saved_fp_dma_contended = cont_mon.fp_dma_grants_under_contention;
        saved_fp_peak_outstanding = cont_mon.fp_peak_outstanding_reads;

        cont_mon.expect_cnm_protection_fault(1'b0);
        sys_vif.region0_base <= '0;
        sys_vif.region0_limit <= '0;
        sys_vif.region0_perm <= '0;
        cont_mon.reset_cnm_stats();
        preload_cnm_operands(expected_cnm_result);

        fault_addr = 32'h0100;
        cnm_dst = 32'h0380;
        dma_dst = 32'h0a00;
        cnm_sentinel = 32'hcafe_a10e;
        dma_sentinel = 32'hdeadcafe;
        host_write_word(cnm_dst, cnm_sentinel);
        toggle_cnm_parity_bit(fault_addr);
        cont_mon.expect_cnm_parity_fault(1'b1, fault_addr);
        for (int word_index = 0; word_index < 32; word_index++)
            host_write_word(dma_dst + word_index * 4, dma_sentinel);

        // Hold all accepted AXI reads so the DMA stays in abort-drain while
        // the real CNM reports its parity error. A randomized abort age,
        // CNM launch skew, and reset delay vary the cross-layer timing.
        abort_after_cycles = $urandom_range(16, 28);
        cnm_launch_skew = $urandom_range(0, 3);
        reset_delay_override_used = $test$plusargs("SPAD_PARITY_ABORT_RESET_DELAY");
        if (reset_delay_override_used) begin
            if (!$value$plusargs("SPAD_PARITY_ABORT_RESET_DELAY=%d", reset_delay_override))
                `uvm_fatal("SPAD_PARITY_ABORT_RESET_DELAY",
                    "plusarg must be +SPAD_PARITY_ABORT_RESET_DELAY=<integer 0..3>")
            if (reset_delay_override < 0 || reset_delay_override > 3)
                `uvm_fatal("SPAD_PARITY_ABORT_RESET_DELAY",
                    $sformatf("delay cycles %0d is out of range; legal range is 0..3", reset_delay_override))
            reset_delay_cycles = reset_delay_override;
        end else begin
            reset_delay_cycles = $urandom_range(0, 3);
        end
        `uvm_info("SPAD_PARITY_ABORT_RESET_DELAY",
            $sformatf("reset delay=%0d cycles (override=%0b)",
                reset_delay_cycles, reset_delay_override_used), UVM_LOW)
        reset_timing_class = (reset_delay_cycles == 0) ? 0 : 1;
        cfg.inject_read_error = 1'b0;
        cfg.min_accepted_reads_before_response = 4;
        cfg.read_response_delay_cycles = 0;
        if (env.axi_rsp.active_read != null || env.axi_rsp.pending_reads.size() != 0)
            `uvm_error("SPAD_PARITY_ABORT_RESET_SETUP",
                "responder had live reads before starting held-response DMA")
        env.axi_rsp.hold_read_responses = 1'b1;

        req = dma_cmd_item::type_id::create("parity_abort_reset_dma_req");
        req.ext_addr = 64'h0000_f400;
        req.spad_addr = dma_dst;
        req.length_words = 16'd32;
        req.row_words = 16'd32;
        req.row_count = 0;
        req.ext_stride = 0;
        req.spad_stride = 0;
        req.read_outstanding = 3'd4;
        req.store = 0;
        req.gather_enable = 0;
        req.gather_index_base = 0;
        req.expect_error = 0;
        req.expected_error_code = 0;
        req.abort_after_cycles = abort_after_cycles;
        req.minimum_rd_highwater = 4;
        seq = dma_one_command_sequence::type_id::create("parity_abort_reset_dma_seq");
        seq.item = req;

        accepted_base = env.axi_rsp.accepted_ids.size();
        completed_base = env.axi_rsp.completed_ids.size();
        dma_writes_base = cont_mon.dma_write_grants;
        dma_seq_done = 0;
        abort_seen = 0;
        all_dma_reads_accepted = 0;
        fork
            begin
                seq.start(env.cmd_sqr);
                dma_seq_done = 1;
            end
        join_none

        wait_cycles = 0;
        while (!all_dma_reads_accepted && wait_cycles < 500) begin
            @(posedge sys_vif.clk);
            #1;
            wait_cycles++;
            all_dma_reads_accepted =
                (env.axi_rsp.accepted_ids.size() >= accepted_base + 4);
        end
        if (!all_dma_reads_accepted)
            `uvm_error("SPAD_PARITY_ABORT_RESET_SETUP",
                "DMA did not accept four read bursts before the setup timeout")

        wait_cycles = 0;
        while (all_dma_reads_accepted && !abort_seen && wait_cycles < 500) begin
            @(posedge sys_vif.clk);
            #1;
            wait_cycles++;
            abort_seen = (env.cmd_drv.vif.abort === 1'b1);
        end
        if (!abort_seen)
            `uvm_error("SPAD_PARITY_ABORT_RESET_SETUP",
                $sformatf("DMA abort pulse not observed; target age=%0d cycles", abort_after_cycles))

        repeat (cnm_launch_skew) @(posedge sys_vif.clk);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= cnm_dst;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;
        sys_vif.cnm_start <= 1'b1;
        @(negedge sys_vif.clk);
        sys_vif.cnm_start <= 1'b0;

        cnm_done_seen = 0;
        fork : wait_for_parity_error_before_reset
            begin
                wait (sys_vif.cnm_done === 1'b1);
                cnm_done_seen = 1;
            end
            begin
                repeat (500) @(posedge sys_vif.clk);
            end
        join_any
        disable wait_for_parity_error_before_reset;
        if (!cnm_done_seen)
            `uvm_error("SPAD_PARITY_ABORT_RESET_TIMEOUT",
                "CNM parity-fault operation did not retire before reset")
        #1;

        if (!abort_seen || env.axi_rsp.accepted_ids.size() - accepted_base != 4 ||
            env.axi_rsp.completed_ids.size() != completed_base ||
            env.cmd_drv.vif.rd_outstanding != 4 || !env.cmd_drv.vif.busy ||
            env.cmd_drv.vif.rd_highwater < 4)
            `uvm_error("SPAD_PARITY_ABORT_RESET_DMA_STATE", $sformatf(
                "expected abort-draining DMA with 4 reads outstanding; abort=%0b accepted/completed=%0d/%0d outstanding/highwater/busy=%0d/%0d/%0b",
                abort_seen, env.axi_rsp.accepted_ids.size() - accepted_base,
                env.axi_rsp.completed_ids.size() - completed_base,
                env.cmd_drv.vif.rd_outstanding, env.cmd_drv.vif.rd_highwater,
                env.cmd_drv.vif.busy))
        if (!cnm_done_seen || sys_vif.cnm_busy || !sys_vif.cnm_error ||
            sys_vif.cnm_error_code != 4'd5 || cont_mon.expected_cnm_parity_pending ||
            cont_mon.cnm_spad_writes_accepted != 0)
            `uvm_error("SPAD_PARITY_ABORT_RESET_CNM_STATE", $sformatf(
                "expected retired ERR_PARITY without write; done/busy/error/code/pending/writes=%0b/%0b/%0b/%0h/%0b/%0d",
                sys_vif.cnm_done, sys_vif.cnm_busy, sys_vif.cnm_error,
                sys_vif.cnm_error_code, cont_mon.expected_cnm_parity_pending,
                cont_mon.cnm_spad_writes_accepted))

        // CNM may retire its parity error before requests accepted by the
        // other bank lanes have returned. Drain those responses before reset.
        drain_cycles = 0;
        while (drain_cycles < 500 &&
               (cont_mon.cnm_lane_reads_accepted[0] != cont_mon.cnm_lane_responses_checked[0] ||
                cont_mon.cnm_lane_reads_accepted[1] != cont_mon.cnm_lane_responses_checked[1] ||
                cont_mon.cnm_lane_reads_accepted[2] != cont_mon.cnm_lane_responses_checked[2] ||
                cont_mon.cnm_lane_reads_accepted[3] != cont_mon.cnm_lane_responses_checked[3] ||
                cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
                cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())) begin
            @(posedge sys_vif.clk);
            #1;
            drain_cycles++;
        end
        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_reads_accepted[lane] == 0 ||
                cont_mon.cnm_lane_reads_accepted[lane] !=
                cont_mon.cnm_lane_responses_checked[lane])
                `uvm_error("SPAD_PARITY_ABORT_RESET_DRAIN", $sformatf(
                    "CNM lane %0d accepted/returned=%0d/%0d after %0d drain cycles", lane,
                    cont_mon.cnm_lane_reads_accepted[lane],
                    cont_mon.cnm_lane_responses_checked[lane], drain_cycles))
        end
        if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
            cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
            `uvm_error("SPAD_PARITY_ABORT_RESET_DRAIN",
                "CNM response expectations were not empty before reset")
        if (cont_mon.dma_write_grants != dma_writes_base)
            `uvm_error("SPAD_PARITY_ABORT_RESET_COMMIT",
                "aborted DMA committed data to the scratchpad")

        fault_abort_reset_observed = abort_seen && cnm_done_seen &&
            sys_vif.cnm_error && (sys_vif.cnm_error_code == 4'd5) &&
            (env.cmd_drv.vif.rd_outstanding == 4) && env.cmd_drv.vif.busy;
        if (fault_abort_reset_observed)
            cont_mon.sample_cnm_parity_abort_reset(
                1'b1, reset_timing_class, env.cmd_drv.vif.rd_highwater);
        else
            `uvm_error("SPAD_PARITY_ABORT_RESET_COV",
                "fault/abort/reset event was not valid for coverage sampling")

        repeat (reset_delay_cycles) begin
            @(posedge sys_vif.clk);
            #1;
            if (!env.cmd_drv.vif.busy || env.cmd_drv.vif.rd_outstanding != 4 ||
                sys_vif.cnm_error !== 1'b1)
                `uvm_error("SPAD_PARITY_ABORT_RESET_SETUP",
                    "DMA abort drain or CNM parity status disappeared before reset")
        end
        reset_assert_ack = 0;
        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b1;
        fork : wait_for_parity_abort_reset_assert
            begin
                wait (sys_vif.subsystem_reset_ack === 1'b1);
                reset_assert_ack = 1;
            end
            begin
                repeat (10) @(posedge sys_vif.clk);
            end
        join_any
        disable wait_for_parity_abort_reset_assert;
        if (!reset_assert_ack)
            `uvm_error("SPAD_PARITY_ABORT_RESET_ACK",
                "shared subsystem reset did not assert before timeout")
        repeat (2) @(posedge sys_vif.clk);
        #1;
        if (env.cmd_drv.vif.busy !== 1'b0 || env.cmd_drv.vif.rd_outstanding != 0 ||
            sys_vif.cnm_busy !== 1'b0 || sys_vif.cnm_done !== 1'b0 ||
            sys_vif.cnm_error !== 1'b0 || env.axi_rsp.active_read != null ||
            env.axi_rsp.pending_reads.size() != 0)
            `uvm_error("SPAD_PARITY_ABORT_RESET_STATE", $sformatf(
                "shared reset failed to clear DMA/CNM/responder; dma=%0b/%0d cnm=%0b/%0b/%0b active=%0b pending=%0d",
                env.cmd_drv.vif.busy, env.cmd_drv.vif.rd_outstanding,
                sys_vif.cnm_busy, sys_vif.cnm_done, sys_vif.cnm_error,
                env.axi_rsp.active_read != null, env.axi_rsp.pending_reads.size()))

        env.axi_rsp.hold_read_responses = 1'b0;
        cfg.min_accepted_reads_before_response = 2;
        @(negedge sys_vif.clk);
        sys_vif.subsystem_reset_req <= 1'b0;
        reset_release_ack = 0;
        fork : wait_for_parity_abort_reset_release
            begin
                wait (sys_vif.subsystem_reset_ack === 1'b0);
                reset_release_ack = 1;
            end
            begin
                repeat (10) @(posedge sys_vif.clk);
            end
        join_any
        disable wait_for_parity_abort_reset_release;
        if (!reset_release_ack)
            `uvm_error("SPAD_PARITY_ABORT_RESET_ACK",
                "shared subsystem reset did not release before timeout")
        if (!dma_seq_done) begin
            fork : wait_for_cancelled_dma_sequence
                begin wait (dma_seq_done === 1'b1); end
                begin repeat (100) @(posedge sys_vif.clk); end
            join_any
            disable wait_for_cancelled_dma_sequence;
            if (!dma_seq_done)
                `uvm_error("SPAD_PARITY_ABORT_RESET_CANCEL",
                    "reset did not return the cancelled DMA sequence")
        end

        repeat (4) begin
            @(posedge sys_vif.clk);
            #1;
            if (env.cmd_drv.vif.busy || env.cmd_drv.vif.rd_outstanding != 0 ||
                env.axi_rsp.active_read != null || env.axi_rsp.pending_reads.size() != 0 ||
                sys_vif.dma_valid || sys_vif.dma_line_valid || sys_vif.arb_rsp_valid ||
                sys_vif.cnm_busy || sys_vif.cnm_done || sys_vif.cnm_error ||
                sys_vif.cnm_req_valid != 4'b0 || sys_vif.cnm_rsp_valid != 4'b0 ||
                sys_vif.cnm_spad_valid)
                `uvm_error("SPAD_PARITY_ABORT_RESET_STALE",
                    "stale DMA/CNM/SPAD activity remained after shared reset")
        end
        if (env.axi_rsp.accepted_ids.size() || env.axi_rsp.active_read != null ||
            env.axi_rsp.pending_reads.size() != 0)
            `uvm_error("SPAD_PARITY_ABORT_RESET_RESPONDER",
                "AXI responder retained accepted traffic after shared reset")

        // The host scratchpad read port shares scheduler admission with the
        // live DMA request. Check sentinels after reset has removed that
        // requester, not while abort-drain is intentionally holding it busy.
        host_read_word(cnm_dst, readback);
        if (readback !== cnm_sentinel)
            `uvm_error("SPAD_PARITY_ABORT_RESET_SENTINEL", $sformatf(
                "CNM parity error changed result sentinel to 0x%08h", readback))
        for (int word_index = 0; word_index < 32; word_index++) begin
            host_read_word(dma_dst + word_index * 4, readback);
            if (readback !== dma_sentinel)
                `uvm_error("SPAD_PARITY_ABORT_RESET_SENTINEL", $sformatf(
                    "DMA destination word %0d changed across reset to 0x%08h",
                    word_index, readback))
        end

        // The reset monitor clears cumulative counters. Restore pre-reset
        // evidence so run_phase's original core/DMA completion checks remain
        // meaningful; CNM per-operation counters intentionally start fresh.
        cont_mon.core_reads_accepted = saved_core_reads;
        cont_mon.core_responses_checked = saved_core_responses;
        cont_mon.core_grants_under_contention = saved_core_contended;
        cont_mon.core_grants_isolated = saved_core_isolated;
        cont_mon.dma_grants_under_contention = saved_dma_contended;
        cont_mon.dma_grants_isolated = saved_dma_isolated;
        cont_mon.desc_priority_grants = saved_desc_grants;
        cont_mon.cpl_priority_grants = saved_cpl_grants;
        cont_mon.dma_write_grants = saved_dma_writes;
        cont_mon.fp_reads_accepted = saved_fp_reads;
        cont_mon.fp_responses_checked = saved_fp_responses;
        cont_mon.fp_writes_accepted = saved_fp_writes;
        cont_mon.fp_grants_under_contention = saved_fp_contended;
        cont_mon.fp_dma_grants_under_contention = saved_fp_dma_contended;
        cont_mon.fp_peak_outstanding_reads = saved_fp_peak_outstanding;

        toggle_cnm_parity_bit(fault_addr);
        cont_mon.expect_cnm_parity_fault(1'b0, '0);
        cont_mon.reset_cnm_stats();
        host_read_word(cnm_dst, readback);
        if (readback !== cnm_sentinel)
            `uvm_error("SPAD_PARITY_ABORT_RESET_SENTINEL",
                "CNM result sentinel changed across shared reset")
        for (int word_index = 0; word_index < 32; word_index++) begin
            host_read_word(dma_dst + word_index * 4, readback);
            if (readback !== dma_sentinel)
                `uvm_error("SPAD_PARITY_ABORT_RESET_SENTINEL", $sformatf(
                    "DMA destination word %0d changed across reset to 0x%08h",
                    word_index, readback))
        end

        run_dma_command(1'b0, 64'h0000_f900, 32'h0e00);
        for (int word_index = 0; word_index < 32; word_index++) begin
            host_read_word(32'h0e00 + word_index * 4, readback);
            if (readback !== dma_memory_word(64'h0000_f900 + word_index * 4))
                `uvm_error("SPAD_PARITY_ABORT_RESET_RECOVERY", $sformatf(
                    "DMA recovery word %0d=0x%08h expected=0x%08h", word_index,
                    readback, dma_memory_word(64'h0000_f900 + word_index * 4)))
        end

        preload_cnm_operands(expected_cnm_result);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= cnm_dst;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;
        run_real_cnm_engine(expected_cnm_result);
        cont_mon.check_cnm_complete(16, 1, expected_cnm_result, 1'b0);
        host_read_word(cnm_dst, readback);
        if (readback !== expected_cnm_result)
            `uvm_error("SPAD_PARITY_ABORT_RESET_RECOVERY", $sformatf(
                "CNM recovery result=0x%08h expected=0x%08h",
                readback, expected_cnm_result))

        @(negedge sys_vif.clk);
        sys_vif.cnm_mode <= 1'b0;
        cfg.read_response_delay_cycles = 0;
        cfg.min_accepted_reads_before_response = 2;
        `uvm_info("SPAD_PARITY_ABORT_RESET_PASS", $sformatf(
            "parity error retired during DMA abort drain; shared reset after %0d cycle(s); both engines recovered (abort age=%0d, launch skew=%0d)",
            reset_delay_cycles, abort_after_cycles, cnm_launch_skew), UVM_LOW)
    endtask

    task run_cnm_protection_error_recovery();
        bit [31:0] result_readback;
        bit [31:0] recovery_expected;
        bit [31:0] legal_b_word;
        bit [31:0] protected_dst;
        bit [31:0] fault_dst;
        int unsigned expected_write_requests;
        int fault_source;
        legal_b_word = 32'h0101_0101;
        protected_dst = 32'h02b0;

        // OOB reads return a tagged response so each CNM requester can retire;
        // a region-protected destination must never assert the SRAM write enable.
        // Exercise both source read channels: A is checked before B, while B
        // proves the valid A response retires before the protected B response.
        // The destination case denies writes to an in-range word, allowing a
        // host-readable sentinel to detect an illegal physical SRAM commit.
        cont_mon.expect_cnm_protection_fault(1'b1);
        for (int lane = 0; lane < 4; lane++) begin
            host_write_word(32'h0400 + lane * 4, legal_b_word);
            cont_mon.set_expected_cnm_word(32'h0400 + lane * 4, legal_b_word);
        end
        host_write_word(protected_dst, 32'hcafe_6bad);

        for (fault_source = 0; fault_source < 3; fault_source++) begin
            cont_mon.reset_cnm_stats();
            fault_dst = protected_dst;
            expected_write_requests = (fault_source == 2) ? 1 : 0;
            if (fault_source == 2) begin
                // Read/execute is allowed, but this region denies writes.
                sys_vif.region0_base <= 32'h0000;
                sys_vif.region0_limit <= 32'h1000;
                sys_vif.region0_perm <= 4'b1101;
            end else begin
                sys_vif.region0_base <= '0;
                sys_vif.region0_limit <= '0;
                sys_vif.region0_perm <= '0;
            end
            @(negedge sys_vif.clk);
            sys_vif.cnm_op_mode <= 8'h20;
            sys_vif.cnm_src0_base <= (fault_source == 0) ? 32'h1180 : 32'h0400;
            sys_vif.cnm_src1_base <= (fault_source == 1) ? 32'h1180 : 32'h0400;
            sys_vif.cnm_dst_base <= fault_dst;
            sys_vif.cnm_length <= 16'd1;
            sys_vif.cnm_m_size <= 16'd1;
            sys_vif.cnm_scale_shift <= 5'd0;
            sys_vif.cnm_activation <= 2'd0;
            sys_vif.cnm_watchdog_limit <= 32'd1000;
            sys_vif.cnm_abort <= 1'b0;
            sys_vif.cnm_mode <= 1'b1;
            @(negedge sys_vif.clk);
            sys_vif.cnm_start <= 1'b1;
            @(negedge sys_vif.clk);
            sys_vif.cnm_start <= 1'b0;

            fork : wait_for_cnm_protection_error
                begin
                    wait (sys_vif.cnm_done === 1'b1);
                end
                begin
                    repeat (100) @(posedge sys_vif.clk);
                    `uvm_error("SPAD_CNM_PROTECTION_TIMEOUT", $sformatf(
                        "CNM source-%0d protection case timed out; busy=%0b done=%0b error=%0b code=%0h",
                        fault_source, sys_vif.cnm_busy, sys_vif.cnm_done,
                        sys_vif.cnm_error, sys_vif.cnm_error_code))
                end
            join_any
            disable wait_for_cnm_protection_error;
            #1;

            if (sys_vif.cnm_busy || !sys_vif.cnm_error || sys_vif.cnm_error_code != 4'd6)
                `uvm_error("SPAD_CNM_PROTECTION_STATUS", $sformatf(
                    "out-of-range CNM source-%0d must retire ERR_PROTECTION=6; busy/error/code=%0b/%0b/%0h result=0x%08h",
                    fault_source, sys_vif.cnm_busy, sys_vif.cnm_error,
                    sys_vif.cnm_error_code, sys_vif.cnm_result))
            if (cont_mon.cnm_spad_writes_accepted != expected_write_requests)
                `uvm_error("SPAD_CNM_PROTECTION_WRITE", $sformatf(
                    "protected CNM fault-%0d accepted write requests=%0d expected=%0d",
                    fault_source, cont_mon.cnm_spad_writes_accepted, expected_write_requests))
            for (int lane = 0; lane < 4; lane++) begin
                if (cont_mon.cnm_lane_reads_accepted[lane] !=
                    cont_mon.cnm_lane_responses_checked[lane])
                    `uvm_error("SPAD_CNM_PROTECTION_DRAIN", $sformatf(
                        "source-%0d lane %0d protected reads/responses=%0d/%0d",
                        fault_source, lane, cont_mon.cnm_lane_reads_accepted[lane],
                        cont_mon.cnm_lane_responses_checked[lane]))
            end
            if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
                cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
                `uvm_error("SPAD_CNM_PROTECTION_DRAIN", $sformatf(
                    "source-%0d protected CNM command left unmatched responses", fault_source))
            host_read_word(fault_dst, result_readback);
            if (result_readback !== 32'hcafe_6bad)
                `uvm_error("SPAD_CNM_PROTECTION_WRITE", $sformatf(
                    "fault-%0d changed protected destination 0x%08h to 0x%08h",
                    fault_source, fault_dst, result_readback))
            cont_mon.sample_cnm_protection_source(fault_source);
        end
        if (cont_mon.cnm_protection_source_cg.get_coverage() < 100.0)
            `uvm_error("SPAD_CNM_PROTECTION_COVERAGE", $sformatf(
                "source protection coverage=%0.2f%% expected 100%%",
                cont_mon.cnm_protection_source_cg.get_coverage()))
        else
            `uvm_info("SPAD_CNM_PROTECTION_COVERAGE", $sformatf(
                "A/B out-of-range source and denied destination-write bins=%0.2f%%",
                cont_mon.cnm_protection_source_cg.get_coverage()), UVM_LOW)

        // A legal task immediately after the fault must still complete
        // without resetting the shared SPAD/DMA subsystem.
        cont_mon.expect_cnm_protection_fault(1'b0);
        sys_vif.region0_perm <= 4'b1111;
        preload_cnm_operands(recovery_expected);
        cont_mon.reset_cnm_stats();
        @(negedge sys_vif.clk);
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h02a4;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        run_real_cnm_engine(recovery_expected);
        for (int lane = 0; lane < 4; lane++) begin
            if (cont_mon.cnm_lane_reads_accepted[lane] != 16 ||
                cont_mon.cnm_lane_responses_checked[lane] != 16)
                `uvm_error("SPAD_CNM_PROTECTION_RECOVERY", $sformatf(
                    "lane %0d recovery reads/responses=%0d/%0d expected=16/16",
                    lane, cont_mon.cnm_lane_reads_accepted[lane],
                    cont_mon.cnm_lane_responses_checked[lane]))
        end
        if (cont_mon.cnm_spad_writes_accepted != 1)
            `uvm_error("SPAD_CNM_PROTECTION_RECOVERY", $sformatf(
                "post-protection recovery writes=%0d expected=1",
                cont_mon.cnm_spad_writes_accepted))
        host_read_word(32'h02a4, result_readback);
        if (result_readback !== recovery_expected)
            `uvm_error("SPAD_CNM_PROTECTION_RECOVERY", $sformatf(
                "post-protection recovery readback=0x%08h expected=0x%08h",
                result_readback, recovery_expected))
        else
            `uvm_info("SPAD_CNM_PROTECTION_PASS", $sformatf(
                "out-of-range A/B sources and denied destination write retired ERR_PROTECTION with storage preserved; clean recovery returned 0x%08h",
                result_readback), UVM_LOW)
    endtask

    task run_cnm_gemv_shape_sweep();
        int unsigned k_sweep[0:3];
        int unsigned k_index, lane, row_index, byte_index;
        int unsigned m_size, expected_lane_reads;
        int unsigned m_order[0:2], swap_index, swap_value;
        int signed act_value, weight_value, row_sum;
        bit [31:0] src0_base, src1_base, dst_base;
        bit [31:0] packed_a, packed_b, result_readback;
        bit [31:0] a_words[0:8][0:3];
        bit [31:0] expected_results[0:3];

        k_sweep[0] = 1;
        k_sweep[1] = 2;
        k_sweep[2] = 8;
        k_sweep[3] = 9;
        `uvm_info("SPAD_CNM_GEMV_SHAPE", "starting real CNM GEMV K={1,2,8,9}; each K runs M={2,3,4} in seed-random order", UVM_LOW)

        for (int sweep_index = 0; sweep_index < 4; sweep_index++) begin
            m_order[0] = 2;
            m_order[1] = 3;
            m_order[2] = 4;
            // Fisher-Yates shuffle preserves every M bin while randomizing
            // the order independently for each K shape.
            for (int shuffle_index = 2; shuffle_index > 0; shuffle_index--) begin
                swap_index = $urandom_range(0, shuffle_index);
                swap_value = m_order[shuffle_index];
                m_order[shuffle_index] = m_order[swap_index];
                m_order[swap_index] = swap_value;
            end

            for (int m_case = 0; m_case < 3; m_case++) begin
            m_size = m_order[m_case];
            src0_base = 32'h0a00;
            src1_base = 32'h0b00;
            dst_base = 32'h0e00 + sweep_index * 32'h0080 + m_case * 32'h0010;
            expected_lane_reads = 2 * k_sweep[sweep_index] * m_size;
            cont_mon.reset_cnm_stats();

            // A is shared across output rows; B is laid out row-major with
            // one packed dot4 word per k/lane, matching the core's contract.
            for (k_index = 0; k_index < k_sweep[sweep_index]; k_index++) begin
                for (lane = 0; lane < 4; lane++) begin
                    packed_a = '0;
                    for (byte_index = 0; byte_index < 4; byte_index++) begin
                        act_value = $urandom_range(0, 8) - 4;
                        packed_a[byte_index*8 +: 8] = act_value[7:0];
                    end
                    a_words[k_index][lane] = packed_a;
                    host_write_word(src0_base + k_index * 16 + lane * 4, packed_a);
                    cont_mon.set_expected_cnm_word(src0_base + k_index * 16 + lane * 4, packed_a);
                end
            end

            for (row_index = 0; row_index < m_size; row_index++) begin
                expected_results[row_index] = '0;
                row_sum = 0;
                for (k_index = 0; k_index < k_sweep[sweep_index]; k_index++) begin
                    for (lane = 0; lane < 4; lane++) begin
                        packed_b = '0;
                        for (byte_index = 0; byte_index < 4; byte_index++) begin
                            weight_value = $urandom_range(0, 8) - 4;
                            packed_b[byte_index*8 +: 8] = weight_value[7:0];
                        end
                        host_write_word(src1_base + row_index * (k_sweep[sweep_index] * 16) +
                                        k_index * 16 + lane * 4, packed_b);
                        cont_mon.set_expected_cnm_word(
                            src1_base + row_index * (k_sweep[sweep_index] * 16) +
                            k_index * 16 + lane * 4, packed_b);
                        row_sum += cnm_dot4_reference(a_words[k_index][lane], packed_b);
                    end
                end
                expected_results[row_index] = row_sum[31:0];
                host_write_word(dst_base + row_index * 4, 32'hface_0000 | row_index);
            end

            @(negedge sys_vif.clk);
            sys_vif.cnm_op_mode <= 8'h21;
            sys_vif.cnm_src0_base <= src0_base;
            sys_vif.cnm_src1_base <= src1_base;
            sys_vif.cnm_dst_base <= dst_base;
            sys_vif.cnm_length <= k_sweep[sweep_index];
            sys_vif.cnm_m_size <= m_size;
            sys_vif.cnm_scale_shift <= 5'd0;
            sys_vif.cnm_activation <= 2'd0;
            sys_vif.cnm_watchdog_limit <= 32'd10000;
            sys_vif.cnm_abort <= 1'b0;
            sys_vif.cnm_mode <= 1'b1;
            `uvm_info("SPAD_CNM_GEMV_CASE", $sformatf(
                "launching real GEMV case K=%0d M=%0d src0=0x%08h src1=0x%08h dst=0x%08h expected per-lane reads=%0d",
                k_sweep[sweep_index], m_size, src0_base, src1_base, dst_base,
                expected_lane_reads), UVM_LOW)

            @(negedge sys_vif.clk);
            cont_mon.sample_cnm_gemv_shape(k_sweep[sweep_index], m_size);
            sys_vif.cnm_start <= 1'b1;
            @(negedge sys_vif.clk);
            sys_vif.cnm_start <= 1'b0;
            fork : wait_for_cnm_gemv_completion
                begin
                    wait (sys_vif.cnm_done === 1'b1);
                end
                begin
                    repeat (2000) @(posedge sys_vif.clk);
                    `uvm_error("SPAD_CNM_GEMV_TIMEOUT", $sformatf(
                        "real CNM GEMV timeout K=%0d M=%0d busy=%0b done=%0b error=%0b code=%0h",
                        k_sweep[sweep_index], m_size, sys_vif.cnm_busy,
                        sys_vif.cnm_done, sys_vif.cnm_error, sys_vif.cnm_error_code))
                end
            join_any
            disable wait_for_cnm_gemv_completion;
            #1;

            if (sys_vif.cnm_busy || sys_vif.cnm_done !== 1'b1 || sys_vif.cnm_error ||
                sys_vif.cnm_element_count != m_size ||
                sys_vif.cnm_global_reduce_events != m_size ||
                sys_vif.cnm_banked_read_issue_events != 8 * k_sweep[sweep_index] * m_size)
                `uvm_error("SPAD_CNM_GEMV_STATUS", $sformatf(
                    "K=%0d M=%0d busy=%0b done=%0b error=%0b code=%0h elements=%0d reductions=%0d read_issues=%0d expected_read_issues=%0d",
                    k_sweep[sweep_index], m_size, sys_vif.cnm_busy, sys_vif.cnm_done,
                    sys_vif.cnm_error, sys_vif.cnm_error_code, sys_vif.cnm_element_count,
                    sys_vif.cnm_global_reduce_events, sys_vif.cnm_banked_read_issue_events,
                    8 * k_sweep[sweep_index] * m_size))

            for (lane = 0; lane < 4; lane++) begin
                if (cont_mon.cnm_lane_reads_accepted[lane] != expected_lane_reads ||
                    cont_mon.cnm_lane_responses_checked[lane] != expected_lane_reads)
                    `uvm_error("SPAD_CNM_GEMV_DRAIN", $sformatf(
                        "K=%0d M=%0d lane %0d reads/responses=%0d/%0d expected=%0d/%0d",
                        k_sweep[sweep_index], m_size, lane,
                        cont_mon.cnm_lane_reads_accepted[lane],
                        cont_mon.cnm_lane_responses_checked[lane],
                        expected_lane_reads, expected_lane_reads))
            end
            if (cont_mon.expected_cnm_lane_data0.size() || cont_mon.expected_cnm_lane_data1.size() ||
                cont_mon.expected_cnm_lane_data2.size() || cont_mon.expected_cnm_lane_data3.size())
                `uvm_error("SPAD_CNM_GEMV_DRAIN", $sformatf(
                    "K=%0d M=%0d response queues not empty: %0d/%0d/%0d/%0d",
                    k_sweep[sweep_index], m_size, cont_mon.expected_cnm_lane_data0.size(),
                    cont_mon.expected_cnm_lane_data1.size(), cont_mon.expected_cnm_lane_data2.size(),
                    cont_mon.expected_cnm_lane_data3.size()))
            if (cont_mon.cnm_spad_writes_accepted != m_size)
                `uvm_error("SPAD_CNM_GEMV_WRITE", $sformatf(
                    "K=%0d M=%0d accepted result writes=%0d expected=%0d",
                    k_sweep[sweep_index], m_size, cont_mon.cnm_spad_writes_accepted, m_size))

            for (row_index = 0; row_index < m_size; row_index++) begin
                host_read_word(dst_base + row_index * 4, result_readback);
                if (result_readback !== expected_results[row_index])
                    `uvm_error("SPAD_CNM_GEMV_RESULT", $sformatf(
                        "K=%0d M=%0d row %0d result=0x%08h expected=0x%08h",
                        k_sweep[sweep_index], m_size, row_index,
                        result_readback, expected_results[row_index]))
            end
            `uvm_info("SPAD_CNM_GEMV_PASS", $sformatf(
                "real GEMV K=%0d M=%0d passed: per-lane reads/responses=%0d/%0d, result writes=%0d, reductions=%0d",
                k_sweep[sweep_index], m_size, expected_lane_reads,
                expected_lane_reads, cont_mon.cnm_spad_writes_accepted,
                sys_vif.cnm_global_reduce_events), UVM_LOW)
            end
        end
        `uvm_info("SPAD_CNM_GEMV_COVERAGE", $sformatf(
            "GEMV shape cross coverage (K bins {1,2,8,9} x M bins {2,3,4})=%0.2f%%; shape-only, no byte-tail/lane-mask claim",
            cont_mon.cnm_gemv_shape_cg.get_inst_coverage()), UVM_LOW)
    endtask

    task run_cnm_dma_contention();
        bit [31:0] result_readback;
        bit [31:0] expected_cnm_result;
        int unsigned dma_start_skew;
        preload_cnm_operands(expected_cnm_result);
        repeat (3) @(posedge sys_vif.clk);
        @(negedge sys_vif.clk);
        sys_vif.cnm_op_mode <= 8'h20;
        sys_vif.cnm_src0_base <= 32'h0100;
        sys_vif.cnm_src1_base <= 32'h0200;
        sys_vif.cnm_dst_base <= 32'h0280;
        sys_vif.cnm_length <= 16'd8;
        sys_vif.cnm_m_size <= 16'd1;
        sys_vif.cnm_scale_shift <= 5'd0;
        sys_vif.cnm_activation <= 2'd0;
        sys_vif.cnm_watchdog_limit <= 32'd10000;
        sys_vif.cnm_abort <= 1'b0;
        sys_vif.cnm_mode <= 1'b1;

        dma_start_skew = $urandom_range(0, 3);
        `uvm_info("DMA_SPAD", $sformatf(
            "starting DDR-to-SPAD DMA %0d cycles after random-data CNM request (expected=0x%08h)",
            dma_start_skew, expected_cnm_result), UVM_LOW)
        fork
            run_real_cnm_engine(expected_cnm_result);
            begin
                wait (|sys_vif.cnm_req_valid);
                repeat (dma_start_skew) @(posedge sys_vif.clk);
                run_dma_command(1'b0, 64'h0000_f200, 32'h0400);
            end
        join

        cont_mon.check_cnm_complete(16, 1, expected_cnm_result);
        host_read_word(32'h0280, result_readback);
        if (result_readback !== expected_cnm_result[31:0])
            `uvm_error("SPAD_CNM_WRITEBACK", $sformatf(
                "CNM result in real scratchpad=0x%08h, expected=0x%08h",
                result_readback, expected_cnm_result[31:0]))
        else
            `uvm_info("SPAD_CNM_WRITEBACK_PASS", "real four-bank CNM result committed and read back from shared scratchpad", UVM_LOW)

        // Repeat the same real CNM operation while DMA reads the scratchpad
        // and writes the result to DDR. This complements the DDR-to-SPAD load
        // overlap above and exercises the opposite direction of shared-memory
        // contention while reusing the same randomized, address-indexed oracle.
        cont_mon.reset_cnm_stats();
        @(negedge sys_vif.clk);
        sys_vif.cnm_dst_base <= 32'h0284;
        dma_start_skew = $urandom_range(0, 3);
        `uvm_info("DMA_SPAD", $sformatf(
            "starting SPAD-to-DDR DMA %0d cycles after random-data CNM request (expected=0x%08h)",
            dma_start_skew, expected_cnm_result), UVM_LOW)
        fork
            run_real_cnm_engine(expected_cnm_result);
            begin
                wait (|sys_vif.cnm_req_valid);
                repeat (dma_start_skew) @(posedge sys_vif.clk);
                run_dma_command(1'b1, 64'h0000_f300, 32'h0600);
            end
        join

        cont_mon.check_cnm_complete(16, 1, expected_cnm_result);
        host_read_word(32'h0284, result_readback);
        if (result_readback !== expected_cnm_result[31:0])
            `uvm_error("SPAD_CNM_STORE_WRITEBACK", $sformatf(
                "CNM result during DMA store=0x%08h, expected=0x%08h",
                result_readback, expected_cnm_result[31:0]))
        else
            `uvm_info("SPAD_CNM_DMA_STORE_PASS", "CNM writeback and DMA SPAD-to-DDR store both completed with shared-SPAD checking", UVM_LOW)

        // Keep the legacy contention phase deterministic with respect to its
        // grant-coverage checks, then exercise AW backpressure in isolation.
        run_dma_store_with_aw_stall(64'h0000_f400, 32'h0600);

        run_cnm_abort_after_read_response();
        run_cnm_recovery_after_abort(expected_cnm_result);
        run_cnm_reset_recovery(1'b0);
        run_cnm_reset_recovery(1'b1);
        run_cnm_protection_error_recovery();
        run_cnm_parity_fault_contention();
        run_cnm_parity_fault_during_dma_abort();
        run_cnm_parity_abort_reset_recovery();
        for (int unsigned successful_bursts = 0; successful_bursts < 4;
             successful_bursts++)
            run_cnm_dma_read_error_case(successful_bursts);
        run_cnm_dma_abort_drain_case();
        run_cnm_dma_write_abort_drain_case();

        run_cnm_gemv_shape_sweep();

        @(negedge sys_vif.clk);
        sys_vif.cnm_mode <= 1'b0;
    endtask

    task run_phase(uvm_phase phase);
        bit [31:0] readback;
        int unsigned cnm_reset_phase_first;
        rready_stall_only = $test$plusargs("A10_RREADY_STALL_ONLY");
        banked_owner_only = $test$plusargs("A10_BANKED_OWNER_ONLY");
        banked_reset_only = $test$plusargs("A10_BANKED_RESET_ONLY");
        banked_contention_only = $test$plusargs("A10_BANKED_CONTENTION_ONLY");
        banked_core_reset_only = $test$plusargs("A10_BANKED_CORE_RESET_ONLY");
        phase.raise_objection(this);
        wait (sys_vif.resetn === 1'b1);
        preload_scratchpad();

        if (rready_stall_only) begin
            run_dma_rready_stall();
            phase.drop_objection(this);
            return;
        end

        if (banked_owner_only) begin
            run_banked_response_owner_probe();
            phase.drop_objection(this);
            return;
        end

        if (banked_reset_only) begin
            run_banked_response_reset_epoch();
            phase.drop_objection(this);
            return;
        end

        if (banked_contention_only) begin
            run_banked_core_owner_contention();
            phase.drop_objection(this);
            return;
        end

        if (banked_core_reset_only) begin
            run_banked_core_reset_epoch();
            phase.drop_objection(this);
            return;
        end

        // Focused regression for the in-repository ai_accel_memory_fabric.
        // Hold real DMA traffic across external R-channel reset, then overlap
        // a real CNM request with that traffic so reset lands while the
        // fabric's registered SPAD response/owner pipeline has an accepted
        // read outstanding. Keep this opt-in branch separate from the broad
        // subsystem test so unrelated protection scenarios do not mask this
        // specific reset contract.
        if ($test$plusargs("A10_MEMORY_FABRIC_RESET_ONLY")) begin
            `uvm_info("MEMORY_FABRIC_RESET_ONLY",
                "running in-repository ai_accel_memory_fabric reset and epoch checks",
                UVM_LOW)
            run_dma_reset_recovery(1'b0, 1'b0, 1);
            run_dma_reset_recovery(1'b1, 1'b0, 1);
            run_dma_reset_recovery(1'b0, 1'b1, 0);
            run_dma_reset_recovery(1'b0, 1'b1, 1);
            `uvm_info("MEMORY_FABRIC_RESET_ONLY_PASS",
                "DMA AR/R reset, partial-read reset, accepted SPAD-read owner flush, and post-reset DMA/CNM recovery passed",
                UVM_LOW)
            phase.drop_objection(this);
            return;
        end

        `uvm_info("DMA_SPAD", "starting DDR-to-real-SPAD load under scalar compute contention", UVM_LOW)
        fork
            run_dma_command(1'b0, 64'h0000_a000, 32'h400);
            run_core_read_traffic(CORE_READS_PER_PHASE);
            begin
                run_descriptor_priority_probe();
                run_completion_priority_probe();
            end
        join

        `uvm_info("DMA_SPAD", "starting real-SPAD-to-DDR store under scalar compute contention", UVM_LOW)
        fork
            run_dma_command(1'b1, 64'h0000_b000, 32'h600);
            run_core_read_traffic(CORE_READS_PER_PHASE);
        join

        `uvm_info("DMA_SPAD", "starting isolated DDR-to-SPAD baseline without a compute requester", UVM_LOW)
        run_dma_command(1'b0, 64'h0000_c000, 32'h400);

        `uvm_info("DMA_SPAD", "starting strided 2D DDR-to-SPAD load", UVM_LOW)
        run_dma_2d_load();

        `uvm_info("DMA_SPAD", "starting gather DDR-to-SPAD load using host-preloaded index table", UVM_LOW)
        run_dma_gather_load();

        `uvm_info("DMA_SPAD", "starting short two-word DDR-to-SPAD load with two read slots", UVM_LOW)
        run_dma_short_outstanding_load();

        `uvm_info("DMA_SPAD", "starting non-overlapping two-row SPAD-to-DDR store", UVM_LOW)
        run_dma_2d_store();

        `uvm_info("DMA_SPAD", "starting 16-word DDR-to-SPAD load across a 4KiB boundary", UVM_LOW)
        run_dma_4k_boundary_load();

        `uvm_info("DMA_SPAD", "starting real FP/DMA shared-SPAD contention check", UVM_LOW)
        run_fp_dma_contention();

        `uvm_info("DMA_SPAD", "starting concurrent FP/DMA SLVERR drain and recovery checks", UVM_LOW)
        run_fp_dma_read_error_contention(1'b0, 32'h208);
        cont_mon.reset_fp_stats();
        run_fp_dma_read_error_contention(1'b1, 32'h20c);

        `uvm_info("DMA_SPAD", "starting real CNM/DMA banked-port contention check", UVM_LOW)
        run_cnm_dma_contention();

        repeat (4) @(posedge sys_vif.clk);
        cont_mon.check_complete(2 * CORE_READS_PER_PHASE);
        host_read_word(32'h900, readback);
        if (readback !== 32'hcafe_2026)
            `uvm_error("SPAD_CPL_READBACK", $sformatf("completion writeback=0x%08h expected=0xcafe2026", readback))
        else
            `uvm_info("SPAD_CPL_READBACK_PASS", "completion-priority write was visible through the host readback port", UVM_LOW)
        if ((!saw_axi_read_before_subsystem_reset && env.axi_rsp.accepted_ids.size() == 0) ||
            (!saw_axi_write_before_subsystem_reset && env.axi_rsp.accepted_bids.size() == 0))
            `uvm_error("DMA_SPAD_AXI", "subsystem scenario did not exercise both AXI read and write channels")
        `uvm_info("DMA_SPAD", "starting subsystem reset with four accepted DMA reads before any R beat", UVM_LOW)
        run_dma_reset_recovery(1'b0, 1'b0, 1);
        `uvm_info("DMA_SPAD", "starting subsystem reset after first R beat with next beat stalled", UVM_LOW)
        run_dma_reset_recovery(1'b1, 1'b0, 1);
        cnm_reset_phase_first = $urandom_range(0, 1);
        `uvm_info("DMA_SPAD", "starting shared-reset phase pair in randomized order while four DMA reads remain outstanding", UVM_LOW)
        run_dma_reset_recovery(1'b0, 1'b1, cnm_reset_phase_first);
        run_dma_reset_recovery(1'b0, 1'b1, cnm_reset_phase_first ^ 1);
        `uvm_info("DMA_SPAD", "starting independent AXI RREADY backpressure completion check", UVM_LOW)
        run_dma_rready_stall();
        `uvm_info("DMA_SPAD", "DMA/SPAD subsystem scoreboard and contention checks completed", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass
